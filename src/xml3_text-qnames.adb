package body XML3_Text.QNames with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

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
      Local_Length : Natural;
      Prefix_Buffer, Local_Buffer : System.Address := System.Null_Address;
   begin
      Prefix := System.Null_Address;
      Local := System.Null_Address;
      Status := No_Prefix;
      if Length = 0 then
         return;
      end if;
      Local_Length := Input'Length - Length - 1;
      Status := No_Memory;
      Native.Allocate (Native.Byte_Count (Length) + 1, Prefix_Buffer);
      if Prefix_Buffer = System.Null_Address then
         return;
      end if;
      Native.Allocate (Native.Byte_Count (Local_Length) + 1, Local_Buffer);
      if Local_Buffer = System.Null_Address then
         Native.Free (Prefix_Buffer);
         return;
      end if;
      Native.Write_String (Prefix_Buffer, 0, Input (1 .. Length));
      Native.Write_Byte (Prefix_Buffer, Length, Character'Val (0));
      Native.Write_String (Local_Buffer, 0, Input (Length + 2 .. Input'Last));
      Native.Write_Byte (Local_Buffer, Local_Length, Character'Val (0));
      Prefix := Prefix_Buffer;
      Local := Local_Buffer;
      Status := Split_Done;
   end Split;
end XML3_Text.QNames;
