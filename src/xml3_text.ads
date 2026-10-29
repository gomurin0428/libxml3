package XML3_Text with SPARK_Mode is
   Max_Bytes : constant := Integer'Last - 16;
   subtype Byte_Count is Natural range 0 .. Max_Bytes;
   type Text_Error_Kind is (No_Text_Error, Invalid_UTF8, Invalid_XML_Character);
   type Name_Kind is (XML_Name, NCName, QName, NMToken);

   type Entity_Kind is
     (No_Entity, Entity_Lt, Entity_Gt, Entity_Amp, Entity_Apos, Entity_Quot);
   subtype Predefined_Entity_Kind is Entity_Kind range Entity_Lt .. Entity_Quot;

   function Entity_Name (Kind : Predefined_Entity_Kind) return String is
     (case Kind is
         when Entity_Lt => "lt", when Entity_Gt => "gt", when Entity_Amp => "amp",
         when Entity_Apos => "apos", when Entity_Quot => "quot")
     with Global => null,
       Post => Entity_Name'Result'First = 1 and Entity_Name'Result'Length in 2 .. 4;

   function Entity_Value (Kind : Predefined_Entity_Kind) return Character is
     (case Kind is
         when Entity_Lt => '<', when Entity_Gt => '>', when Entity_Amp => '&',
         when Entity_Apos => Character'Val (39), when Entity_Quot => '"')
     with Global => null;

   function Find_Entity (Name : String) return Entity_Kind
     with Global => null,
       Post => (if Find_Entity'Result /= No_Entity then
                  Name = Entity_Name (Find_Entity'Result));

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

   function Name_Character
     (Code : Natural; Initial : Boolean; Allow_Colon : Boolean := True)
      return Boolean
     with Global => null;

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
