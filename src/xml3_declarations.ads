with XML3_Encoding;

--  The encoding libxml2 2.15.4 records in a parsed document (doc->encoding,
--  set from xmlGetActualEncoding when the parse ends): the encoding given
--  to the read, in libxml2's name for it; otherwise the encoding the XML
--  declaration names, exactly as written; otherwise none.
package XML3_Declarations with SPARK_Mode is
   use type XML3_Encoding.Encoding_Kind;

   --  The value of the encoding pseudo-attribute of the XML declaration
   --  that begins Input, a document the parser accepted (its text in
   --  UTF-8, after any byte order mark).  Found is False when Input has no
   --  XML declaration or the declaration names no encoding.
   procedure Find_Encoding
     (Input : String; Found : out Boolean; First : out Positive;
      Last : out Natural)
   with Global => null,
     Pre => Input'First = 1 and then Input'Last >= 0
       and then Input'Last < Natural'Last,
     Post => (if Found then First in Input'Range and then Last in Input'Range
                and then First <= Last);

   type Encoding_Source is (No_Encoding, Declared_Name, Requested_Name);

   --  Where the document's encoding comes from, given the encoding the
   --  read was asked for and whether the declaration names one.
   function Source
     (Requested : XML3_Encoding.Encoding_Kind; Declared : Boolean)
      return Encoding_Source
   is
     (if Requested in XML3_Encoding.Concrete_Encoding
        or else Requested = XML3_Encoding.UTF16
      then Requested_Name
      elsif Declared then Declared_Name
      else No_Encoding)
   with Global => null;

   --  libxml2's name of a requested encoding (its handler's name).
   function Requested_Text (Requested : XML3_Encoding.Encoding_Kind)
     return String
   is
     (case Requested is
        when XML3_Encoding.UTF16 => "UTF-16",
        when XML3_Encoding.UTF16LE => "UTF-16LE",
        when XML3_Encoding.UTF16BE => "UTF-16BE",
        when others => "UTF-8")
   with Global => null,
     Post => Requested_Text'Result'Length in 5 .. 8
       and then Requested_Text'Result'First = 1;

end XML3_Declarations;
