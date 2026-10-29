package XML3_Text with SPARK_Mode is
   Max_Bytes : constant := Integer'Last - 16;
   subtype Byte_Count is Natural range 0 .. Max_Bytes;
   type Text_Error_Kind is (No_Text_Error, Invalid_UTF8, Invalid_XML_Character);
   type Name_Kind is (XML_Name, NCName, QName, NMToken);

   function UTF8_Width (Code : Natural) return Positive is
     (if Code < 16#80# then 1 elsif Code < 16#800# then 2
      elsif Code < 16#10000# then 3 else 4)
     with Global => null, Pre => Code <= 16#10FFFF#,
       Post => UTF8_Width'Result in 1 .. 4;

   function UTF8_Image (Code : Natural) return String
     with Global => null,
       Pre => Code <= 16#10FFFF# and then Code not in 16#D800# .. 16#DFFF#,
       Post => UTF8_Image'Result'First = 1
         and then UTF8_Image'Result'Length = UTF8_Width (Code);

   function Valid_Name
     (Input : String; Kind : Name_Kind; Allow_Space : Boolean) return Boolean
     with Global => null,
       Pre => Input'First = 1 and then Input'Last in 0 .. Max_Bytes;

   function XML_Char (C : Natural) return Boolean with Global => null;

   function XML_Blank (C : Natural) return Boolean with Global => null;

   function XML_Base_Char (C : Natural) return Boolean with Global => null;

   function XML_Combining (C : Natural) return Boolean with Global => null;

   function XML_Digit (C : Natural) return Boolean with Global => null;

   function XML_Extender (C : Natural) return Boolean with Global => null;

   function XML_Ideographic (C : Natural) return Boolean with Global => null;

   function XML_Pubid_Char (C : Natural) return Boolean with Global => null;

   procedure Validate_UTF8
     (Input : String;
      Kind : out Text_Error_Kind;
      Error_Position : out Natural;
      XML_Only : Boolean := True)
     with Global => null,
       Pre => Input'First >= 1
         and then Input'Last in 0 .. Max_Bytes
         and then Input'First <= Max_Bytes + 1,
       Post => (if Kind = No_Text_Error then Error_Position = 0
                else Error_Position in Input'First .. Input'Last);

   function Name_Width
     (Input : String; First : Positive; Initial : Boolean) return Natural
     with Global => null,
       Pre => Input'First = 1 and then Input'Length <= Max_Bytes
         and then First <= Input'Length + 1,
       Post => Name_Width'Result <= 4
         and Name_Width'Result <= Input'Length - (First - 1);

   function Valid_UTF8 (Input : String) return Boolean
     with Global => null,
       Pre => Input'First >= 1
         and then Input'Last in 0 .. Max_Bytes
         and then Input'First <= Max_Bytes + 1;

   procedure Decode
     (Input      : String;
      Attribute  : Boolean;
      References : Boolean;
      Output     : out String;
      Length     : out Byte_Count;
      Valid      : out Boolean;
      Normalize_Line_Endings : Boolean := True)
     with Global => null, Always_Terminates,
       Pre => Input'First >= 1
         and then Input'Last in 0 .. Max_Bytes
         and then Input'First <= Max_Bytes + 1
         and then Output'First = 1
         and then Output'Length = Input'Length,
       Post => Length <= Output'Length;
end XML3_Text;
