with XML3_Text.Buffers;
with System.Storage_Elements;

package body XML3_Text.QNames with SPARK_Mode is
   package Native renames XML3_Native_Memory;

   procedure Locate_Prefix
     (Input : System.Address; Count : out Byte_Count; Local : out System.Address;
      Status : out Prefix_Status; Last : Byte_Count := Max_Bytes)
   is
      Item : Character;
   begin
      Count := 0;
      Local := System.Null_Address;
      Status := Prefix_Absent;
      if Input = System.Null_Address then
         return;
      end if;
      for Index in 0 .. Last loop
         Item := Native.Byte_At (Input, Index);
         if Item = Character'Val (0) then
            return;
         elsif Item = ':' then
            if Index = 0 then
               return;
            elsif Index = Last then
               Status := Prefix_Limit_Exceeded;
               return;
            elsif Native.Byte_At (Input, Index + 1) = Character'Val (0) then
               return;
            end if;
            Count := Index;
            Local := Native.Offset (Input, Native.Byte_Count (Index + 1));
            Status := Prefix_Found;
            return;
         end if;
      end loop;
      Status := Prefix_Limit_Exceeded;
   end Locate_Prefix;

   procedure Compare
     (Prefix, Name, Value : System.Address; Status : out Comparison_Status)
   is
      Offset : Byte_Count := 0;
      Left, Right : Character;
   begin
      Status := Different;
      if Prefix = System.Null_Address and then Name = Value then
         Status := Same;
         return;
      elsif Name = System.Null_Address or else Value = System.Null_Address then
         return;
      end if;
      if Prefix /= System.Null_Address then
         for Index in 0 .. Max_Bytes loop
            Left := Native.Byte_At (Prefix, Index);
            if Left = Character'Val (0) then
               if Index = 0 then
                  return;
               elsif Index = Max_Bytes then
                  Status := Comparison_Limit_Exceeded;
                  return;
               elsif Native.Byte_At (Value, Index) /= ':' then
                  return;
               end if;
               Offset := Index + 1;
               exit;
            elsif Index = Max_Bytes then
               Status := Comparison_Limit_Exceeded;
               return;
            elsif Left /= Native.Byte_At (Value, Index) then
               return;
            end if;
         end loop;
      end if;
      for Index in 0 .. Max_Bytes - Offset loop
         Left := Native.Byte_At (Name, Index);
         Right := Native.Byte_At (Value, Offset + Index);
         if Left /= Right then
            return;
         elsif Left = Character'Val (0) then
            Status := Same;
            return;
         end if;
      end loop;
      Status := Comparison_Limit_Exceeded;
   end Compare;

   function Overlaps
     (Left, Right : System.Address; Left_Length, Right_Length : Byte_Count)
      return Boolean
     with Global => null
   is
      use type System.Storage_Elements.Integer_Address;
      subtype Address_Number is System.Storage_Elements.Integer_Address;
      A : constant Address_Number := Native.Address_Value (Left);
      B : constant Address_Number := Native.Address_Value (Right);
   begin
      return Left_Length > 0 and then Right_Length > 0
        and then (if A <= B then B - A < Address_Number (Left_Length)
                  else A - B < Address_Number (Right_Length));
   end Overlaps;

   procedure Build
     (Name, Prefix, Buffer : System.Address; Capacity : Integer;
      Result : out System.Address; Status : out Build_Status;
      Limit : Byte_Count := Max_Bytes)
   is
      Needed, Name_Length, Prefix_Length : Byte_Count;
      Measured, Use_Buffer, Temporary : Boolean;
      Target : System.Address := Buffer;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Name = System.Null_Address or else Capacity < 0 then
         return;
      end if;
      if Prefix = System.Null_Address then
         Result := Name;
         Status := Built;
         return;
      end if;
      Status := Limit_Exceeded;
      if Limit < 2 then
         return;
      end if;
      XML3_Text.Buffers.Measure (Name, Name_Length, Measured, Last => Limit - 2);
      if not Measured then
         return;
      end if;
      XML3_Text.Buffers.Measure
        (Prefix, Prefix_Length, Measured, Last => Limit - Name_Length - 2);
      if not Measured then
         return;
      end if;
      Needed := Name_Length + Prefix_Length + 2;
      Use_Buffer := Buffer /= System.Null_Address and then Capacity >= Needed;
      Temporary := Use_Buffer and then
        (Overlaps (Buffer, Name, Needed, Name_Length)
         or else Overlaps (Buffer, Prefix, Needed, Prefix_Length));
      if not Use_Buffer or else Temporary then
         Native.Allocate (Native.Byte_Count (Needed), Target);
         if Target = System.Null_Address then
            Status := No_Memory;
            return;
         end if;
      end if;
      for Index in 0 .. Prefix_Length - 1 loop
         Native.Write_Byte (Target, Index, Native.Byte_At (Prefix, Index));
      end loop;
      Native.Write_Byte (Target, Prefix_Length, ':');
      for Index in 0 .. Name_Length - 1 loop
         Native.Write_Byte
           (Target, Prefix_Length + 1 + Index, Native.Byte_At (Name, Index));
      end loop;
      Native.Write_Byte (Target, Needed - 1, Character'Val (0));
      if Temporary then
         Native.Copy_Bytes (Target, Buffer, Needed);
         Native.Free (Target);
         Result := Buffer;
      else
         Result := Target;
      end if;
      Status := Built;
   end Build;

   function Prefix_Length (Input : String) return Byte_Count is
   begin
      for I in Input'Range loop
         pragma Loop_Invariant (for all J in 1 .. I - 1 => Input (J) /= ':');
         if Input (I) = ':' then
            return (if I > 1 and then I < Input'Last then I - 1 else 0);
         end if;
      end loop;
      return 0;
   end Prefix_Length;

   procedure Split
     (Input : System.Address; Prefix, Local : out System.Address;
      Status : out Split_Status; Last : Byte_Count := Max_Bytes)
   is
      Length, Local_Length : Byte_Count;
      Ignored_Local : System.Address;
      pragma Unreferenced (Ignored_Local);
      Located : Prefix_Status;
      Measured : Boolean;
      Copied : XML3_Text.Buffers.Slice_Status;
      use type XML3_Text.Buffers.Slice_Status;
      Prefix_Buffer, Local_Buffer : System.Address := System.Null_Address;
   begin
      Prefix := System.Null_Address;
      Local := System.Null_Address;
      Status := No_Prefix;
      Locate_Prefix (Input, Length, Ignored_Local, Located, Last);
      if Located = Prefix_Limit_Exceeded then
         Status := Split_Limit_Exceeded;
         return;
      elsif Located = Prefix_Absent then
         return;
      end if;
      XML3_Text.Buffers.Measure
        (Input, Local_Length, Measured, Last => Last, Start => Length + 1);
      if not Measured then
         Status := Split_Limit_Exceeded;
         return;
      elsif Local_Length = 0 then
         return;
      end if;
      Status := No_Memory;
      XML3_Text.Buffers.Copy_Span (Input, 0, Length, Prefix_Buffer, Copied);
      if Copied /= XML3_Text.Buffers.Sliced then
         return;
      end if;
      XML3_Text.Buffers.Copy_Span
        (Input, Length + 1, Local_Length, Local_Buffer, Copied);
      if Copied /= XML3_Text.Buffers.Sliced then
         Native.Free (Prefix_Buffer);
         return;
      end if;
      Prefix := Prefix_Buffer;
      Local := Local_Buffer;
      Status := Split_Done;
   end Split;
end XML3_Text.QNames;
