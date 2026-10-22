package XML3_Text with SPARK_Mode is
   Max_Bytes : constant := Integer'Last - 16;
   subtype Byte_Count is Natural range 0 .. Max_Bytes;

   function Name_Width
     (Input : String; First : Positive; Initial : Boolean) return Natural
     with Global => null,
       Pre => Input'First = 1 and then Input'Length <= Max_Bytes
         and then First <= Input'Length + 1,
       Post => Name_Width'Result <= 4
         and Name_Width'Result <= Input'Length - (First - 1);

   function Valid_UTF8 (Input : String) return Boolean
     with Global => null,
       Pre => Input'Last in 0 .. Max_Bytes
         and Input'First <= Max_Bytes + 1;

   procedure Decode
     (Input      : String;
      Attribute  : Boolean;
      References : Boolean;
      Output     : out String;
      Length     : out Byte_Count;
      Valid      : out Boolean)
     with Global => null, Always_Terminates,
       Pre => Input'Last in 0 .. Max_Bytes
         and Input'First <= Max_Bytes + 1
         and Output'First = 1 and Output'Length = Input'Length,
       Post => Length <= Output'Length;
end XML3_Text;
