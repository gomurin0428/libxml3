package body XML3_Text.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

   procedure Concatenate
     (Left, Right : String; Has_Left, Has_Right : Boolean;
      Result : out System.Address; Status : out Concatenate_Status)
   is
      Length : Byte_Count;
   begin
      Result := System.Null_Address;
      Status := No_Input;
      if not Has_Left and then not Has_Right then
         return;
      end if;
      Status := Limit_Exceeded;
      if not Fits (Left'Length, Right'Length) then
         return;
      end if;
      Length := Left'Length + Right'Length;
      Status := No_Memory;
      Native.Allocate (Native.Byte_Count (Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      Native.Write_String (Result, 0, Left);
      Native.Write_String (Result, Left'Length, Right);
      Native.Write_Byte (Result, Length, Character'Val (0));
      Status := Copied;
   end Concatenate;

   procedure Duplicate (Input : String; Result : out System.Address) is
      Status : Concatenate_Status;
   begin
      Concatenate (Input, "", True, False, Result, Status);
      if Status /= Copied then
         Result := System.Null_Address;
      end if;
   end Duplicate;
end XML3_Text.Buffers;
