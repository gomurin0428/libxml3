package body XML3_Text.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type System.Address;
   use type Native.Byte_Count;

   procedure Duplicate (Input : String; Result : out System.Address) is
   begin
      Native.Allocate (Native.Byte_Count (Input'Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      Native.Write_String (Result, 0, Input);
      Native.Write_Byte (Result, Input'Length, Character'Val (0));
   end Duplicate;
end XML3_Text.Buffers;
