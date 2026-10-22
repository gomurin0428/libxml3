package XML3_Text with SPARK_Mode is
   Max_Bytes : constant := 65_536;
   subtype Byte_Count is Natural range 0 .. Max_Bytes;

   function Valid_UTF8 (Input : String) return Boolean
     with Global => null,
       Pre => Input'First = 1 and Input'Length <= Max_Bytes;

   procedure Decode
     (Input      : String;
      Attribute  : Boolean;
      References : Boolean;
      Output     : out String;
      Length     : out Byte_Count;
      Valid      : out Boolean)
     with Global => null, Always_Terminates,
       Pre => Input'First = 1 and Input'Length <= Max_Bytes
         and Output'First = 1 and Output'Length = Input'Length,
       Post => Length <= Output'Length;
end XML3_Text;
