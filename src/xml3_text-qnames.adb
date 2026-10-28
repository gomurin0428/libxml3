with XML3_Text.Buffers;

package body XML3_Text.QNames with SPARK_Mode is
   package Native renames XML3_Native_Memory;

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
     (Input : String; Prefix, Local : out System.Address;
      Status : out Split_Status)
   is
      Length : constant Byte_Count := Prefix_Length (Input);
      Prefix_Buffer, Local_Buffer : System.Address := System.Null_Address;
   begin
      Prefix := System.Null_Address;
      Local := System.Null_Address;
      Status := No_Prefix;
      if Length = 0 then
         return;
      end if;
      Status := No_Memory;
      XML3_Text.Buffers.Duplicate (Input (1 .. Length), Prefix_Buffer);
      if Prefix_Buffer = System.Null_Address then
         return;
      end if;
      XML3_Text.Buffers.Duplicate
        (Input (Length + 2 .. Input'Last), Local_Buffer);
      if Local_Buffer = System.Null_Address then
         Native.Free (Prefix_Buffer);
         return;
      end if;
      Prefix := Prefix_Buffer;
      Local := Local_Buffer;
      Status := Split_Done;
   end Split;
end XML3_Text.QNames;
