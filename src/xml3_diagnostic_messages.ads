with Interfaces.C;

package XML3_Diagnostic_Messages with SPARK_Mode, Pure is
   use type Interfaces.C.int;

   type Message_Kind is
     (Empty, Start, Name, Tag, Comment, CData, PI, UTF8, Namespace, No_Memory,
      Internal, Unsupported, Extra_Content, Invalid_Character,
      Character_Reference, Entity_Semicolon, Entity, External_Entity, Encoding,
      Encoding_Name, Encoding_Mismatch, Attribute_Value, Attribute_Unclosed,
      Attribute_Required, Start_Tag, End_Tag, Reserved_Name, Name_Length,
      Resource, Standalone, XML_Declaration, Comment_Hyphen, Quote,
      CData_Position, Equal, Duplicate_Attribute, Generic_Error);

   --  Code-specific messages win over the domain fallbacks.
   function Kind_For
     (Code, Domain : Interfaces.C.int; Has_Input : Boolean := False)
      return Message_Kind
   is
     (case Code is
        when 1 => Internal,
        when 2 => No_Memory,
        when 4 => (if Has_Input then Start else Empty),
        when 5 => Extra_Content,
        when 6 .. 8 => Character_Reference,
        when 9 => Invalid_Character,
        when 23 => Entity_Semicolon,
        when 26 | 27 => Entity,
        when 29 => External_Entity,
        when 32 => Encoding,
        when 34 | 40 => Attribute_Unclosed,
        when 38 => Quote,
        when 39 => Attribute_Required,
        when 41 => Attribute_Value,
        when 42 => Duplicate_Attribute,
        when 45 => Comment,
        when 47 => PI,
        when 57 => XML_Declaration,
        when 62 => CData_Position,
        when 63 => CData,
        when 64 => Reserved_Name,
        when 68 => Name,
        when 73 => Start_Tag,
        when 75 => Equal,
        when 76 => Tag,
        when 77 => End_Tag,
        when 78 => Standalone,
        when 79 => Encoding_Name,
        when 80 => Comment_Hyphen,
        when 81 => UTF8,
        when 110 => Name_Length,
        when 113 => Encoding_Mismatch,
        when 114 => Resource,
        when 115 => Unsupported,
        when others =>
          (if Domain = 8 then UTF8
           elsif Domain = 3 then Namespace
           else Generic_Error))
   with Global => null;
end XML3_Diagnostic_Messages;
