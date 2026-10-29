with XML3_Text.Buffers;

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

   procedure Build
     (Name, Prefix : String; Original, Buffer : System.Address;
      Has_Prefix : Boolean; Capacity : Integer;
      Result : out System.Address; Status : out Build_Status)
   is
      Needed : Byte_Count;
      Target : System.Address := Buffer;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Original = System.Null_Address or else Capacity < 0 then
         return;
      end if;
      if not Has_Prefix then
         Result := Original;
         Status := Built;
         return;
      end if;
      if Name'Length > Max_Bytes - Prefix'Length - 2 then
         Status := Limit_Exceeded;
         return;
      end if;
      Needed := Name'Length + Prefix'Length + 2;
      if Target = System.Null_Address or else Capacity < Needed then
         Native.Allocate (Native.Byte_Count (Needed), Target);
         if Target = System.Null_Address then
            Status := No_Memory;
            return;
         end if;
      end if;
      Native.Write_String (Target, 0, Prefix);
      Native.Write_Byte (Target, Prefix'Length, ':');
      Native.Write_String (Target, Prefix'Length + 1, Name);
      Native.Write_Byte (Target, Needed - 1, Character'Val (0));
      Result := Target;
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
