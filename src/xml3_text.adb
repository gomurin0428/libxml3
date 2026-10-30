package body XML3_Text with SPARK_Mode is
   function Location_At
     (Input : String; Byte_Position : Natural) return Text_Location
   is
      Count : constant Natural := Natural'Min
        (Input'Length, (if Byte_Position = 0 then 0 else Byte_Position - 1));
      Result : Text_Location;
   begin
      for Offset in 1 .. Count loop
         pragma Loop_Invariant
           (Result.Line <= Offset and then Result.Column <= Offset);
         declare
            Byte : constant Character := Input (Input'First + (Offset - 1));
         begin
            if Byte = Character'Val (10) then
               Result.Line := Result.Line + 1;
               Result.Column := 1;
            elsif Character'Pos (Byte) not in 16#80# .. 16#BF# then
               Result.Column := Result.Column + 1;
            end if;
         end;
      end loop;
      return Result;
   end Location_At;

   function Find_Entity (Name : String) return Entity_Kind is
   begin
      for Kind in Predefined_Entity_Kind loop
         if Name = Entity_Name (Kind) then
            return Kind;
         end if;
      end loop;
      return No_Entity;
   end Find_Entity;

   function UTF8_Image (Code : Natural) return String is
   begin
      if Code < 16#80# then
         return (1 => Character'Val (Code));
      elsif Code < 16#800# then
         return Character'Val (16#C0# + Code / 64)
           & Character'Val (16#80# + Code mod 64);
      elsif Code < 16#10000# then
         return Character'Val (16#E0# + Code / 4096)
           & Character'Val (16#80# + (Code / 64) mod 64)
           & Character'Val (16#80# + Code mod 64);
      else
         return Character'Val (16#F0# + Code / 262_144)
           & Character'Val (16#80# + (Code / 4096) mod 64)
           & Character'Val (16#80# + (Code / 64) mod 64)
           & Character'Val (16#80# + Code mod 64);
      end if;
   end UTF8_Image;

   function XML_Char (C : Natural) return Boolean is
     (C = 9 or C = 10 or C = 13
      or (C in 16#20# .. 16#D7FF#)
      or (C in 16#E000# .. 16#FFFD#)
      or (C in 16#10000# .. 16#10FFFF#));

   function XML_Blank (C : Natural) return Boolean is
     (C in 9 | 10 | 13 | 32);

   -- Historical XML ranges from libxml2 2.15.4; not current NCName rules.
   function XML_Base_Char (C : Natural) return Boolean is
     (C in 16#41# .. 16#5A# | 16#61# .. 16#7A#
        | 16#C0# .. 16#D6# | 16#D8# .. 16#F6#
        | 16#F8# .. 16#FF# | 16#100# .. 16#131#
        | 16#134# .. 16#13E# | 16#141# .. 16#148#
        | 16#14A# .. 16#17E# | 16#180# .. 16#1C3#
        | 16#1CD# .. 16#1F0# | 16#1F4# .. 16#1F5#
        | 16#1FA# .. 16#217# | 16#250# .. 16#2A8#
        | 16#2BB# .. 16#2C1# | 16#386#
        | 16#388# .. 16#38A# | 16#38C#
        | 16#38E# .. 16#3A1# | 16#3A3# .. 16#3CE#
        | 16#3D0# .. 16#3D6# | 16#3DA#
        | 16#3DC# | 16#3DE#
        | 16#3E0# | 16#3E2# .. 16#3F3#
        | 16#401# .. 16#40C# | 16#40E# .. 16#44F#
        | 16#451# .. 16#45C# | 16#45E# .. 16#481#
        | 16#490# .. 16#4C4# | 16#4C7# .. 16#4C8#
        | 16#4CB# .. 16#4CC# | 16#4D0# .. 16#4EB#
        | 16#4EE# .. 16#4F5# | 16#4F8# .. 16#4F9#
        | 16#531# .. 16#556# | 16#559#
        | 16#561# .. 16#586# | 16#5D0# .. 16#5EA#
        | 16#5F0# .. 16#5F2# | 16#621# .. 16#63A#
        | 16#641# .. 16#64A# | 16#671# .. 16#6B7#
        | 16#6BA# .. 16#6BE# | 16#6C0# .. 16#6CE#
        | 16#6D0# .. 16#6D3# | 16#6D5#
        | 16#6E5# .. 16#6E6# | 16#905# .. 16#939#
        | 16#93D# | 16#958# .. 16#961#
        | 16#985# .. 16#98C# | 16#98F# .. 16#990#
        | 16#993# .. 16#9A8# | 16#9AA# .. 16#9B0#
        | 16#9B2# | 16#9B6# .. 16#9B9#
        | 16#9DC# .. 16#9DD# | 16#9DF# .. 16#9E1#
        | 16#9F0# .. 16#9F1# | 16#A05# .. 16#A0A#
        | 16#A0F# .. 16#A10# | 16#A13# .. 16#A28#
        | 16#A2A# .. 16#A30# | 16#A32# .. 16#A33#
        | 16#A35# .. 16#A36# | 16#A38# .. 16#A39#
        | 16#A59# .. 16#A5C# | 16#A5E#
        | 16#A72# .. 16#A74# | 16#A85# .. 16#A8B#
        | 16#A8D# | 16#A8F# .. 16#A91#
        | 16#A93# .. 16#AA8# | 16#AAA# .. 16#AB0#
        | 16#AB2# .. 16#AB3# | 16#AB5# .. 16#AB9#
        | 16#ABD# | 16#AE0#
        | 16#B05# .. 16#B0C# | 16#B0F# .. 16#B10#
        | 16#B13# .. 16#B28# | 16#B2A# .. 16#B30#
        | 16#B32# .. 16#B33# | 16#B36# .. 16#B39#
        | 16#B3D# | 16#B5C# .. 16#B5D#
        | 16#B5F# .. 16#B61# | 16#B85# .. 16#B8A#
        | 16#B8E# .. 16#B90# | 16#B92# .. 16#B95#
        | 16#B99# .. 16#B9A# | 16#B9C#
        | 16#B9E# .. 16#B9F# | 16#BA3# .. 16#BA4#
        | 16#BA8# .. 16#BAA# | 16#BAE# .. 16#BB5#
        | 16#BB7# .. 16#BB9# | 16#C05# .. 16#C0C#
        | 16#C0E# .. 16#C10# | 16#C12# .. 16#C28#
        | 16#C2A# .. 16#C33# | 16#C35# .. 16#C39#
        | 16#C60# .. 16#C61# | 16#C85# .. 16#C8C#
        | 16#C8E# .. 16#C90# | 16#C92# .. 16#CA8#
        | 16#CAA# .. 16#CB3# | 16#CB5# .. 16#CB9#
        | 16#CDE# | 16#CE0# .. 16#CE1#
        | 16#D05# .. 16#D0C# | 16#D0E# .. 16#D10#
        | 16#D12# .. 16#D28# | 16#D2A# .. 16#D39#
        | 16#D60# .. 16#D61# | 16#E01# .. 16#E2E#
        | 16#E30# | 16#E32# .. 16#E33#
        | 16#E40# .. 16#E45# | 16#E81# .. 16#E82#
        | 16#E84# | 16#E87# .. 16#E88#
        | 16#E8A# | 16#E8D#
        | 16#E94# .. 16#E97# | 16#E99# .. 16#E9F#
        | 16#EA1# .. 16#EA3# | 16#EA5#
        | 16#EA7# | 16#EAA# .. 16#EAB#
        | 16#EAD# .. 16#EAE# | 16#EB0#
        | 16#EB2# .. 16#EB3# | 16#EBD#
        | 16#EC0# .. 16#EC4# | 16#F40# .. 16#F47#
        | 16#F49# .. 16#F69# | 16#10A0# .. 16#10C5#
        | 16#10D0# .. 16#10F6# | 16#1100#
        | 16#1102# .. 16#1103# | 16#1105# .. 16#1107#
        | 16#1109# | 16#110B# .. 16#110C#
        | 16#110E# .. 16#1112# | 16#113C#
        | 16#113E# | 16#1140#
        | 16#114C# | 16#114E#
        | 16#1150# | 16#1154# .. 16#1155#
        | 16#1159# | 16#115F# .. 16#1161#
        | 16#1163# | 16#1165#
        | 16#1167# | 16#1169#
        | 16#116D# .. 16#116E# | 16#1172# .. 16#1173#
        | 16#1175# | 16#119E#
        | 16#11A8# | 16#11AB#
        | 16#11AE# .. 16#11AF# | 16#11B7# .. 16#11B8#
        | 16#11BA# | 16#11BC# .. 16#11C2#
        | 16#11EB# | 16#11F0#
        | 16#11F9# | 16#1E00# .. 16#1E9B#
        | 16#1EA0# .. 16#1EF9# | 16#1F00# .. 16#1F15#
        | 16#1F18# .. 16#1F1D# | 16#1F20# .. 16#1F45#
        | 16#1F48# .. 16#1F4D# | 16#1F50# .. 16#1F57#
        | 16#1F59# | 16#1F5B#
        | 16#1F5D# | 16#1F5F# .. 16#1F7D#
        | 16#1F80# .. 16#1FB4# | 16#1FB6# .. 16#1FBC#
        | 16#1FBE# | 16#1FC2# .. 16#1FC4#
        | 16#1FC6# .. 16#1FCC# | 16#1FD0# .. 16#1FD3#
        | 16#1FD6# .. 16#1FDB# | 16#1FE0# .. 16#1FEC#
        | 16#1FF2# .. 16#1FF4# | 16#1FF6# .. 16#1FFC#
        | 16#2126# | 16#212A# .. 16#212B#
        | 16#212E# | 16#2180# .. 16#2182#
        | 16#3041# .. 16#3094# | 16#30A1# .. 16#30FA#
        | 16#3105# .. 16#312C# | 16#AC00# .. 16#D7A3#);

   function XML_Combining (C : Natural) return Boolean is
     (C in 16#300# .. 16#345# | 16#360# .. 16#361#
        | 16#483# .. 16#486# | 16#591# .. 16#5A1#
        | 16#5A3# .. 16#5B9# | 16#5BB# .. 16#5BD#
        | 16#5BF# | 16#5C1# .. 16#5C2#
        | 16#5C4# | 16#64B# .. 16#652#
        | 16#670# | 16#6D6# .. 16#6DC#
        | 16#6DD# .. 16#6DF# | 16#6E0# .. 16#6E4#
        | 16#6E7# .. 16#6E8# | 16#6EA# .. 16#6ED#
        | 16#901# .. 16#903# | 16#93C#
        | 16#93E# .. 16#94C# | 16#94D#
        | 16#951# .. 16#954# | 16#962# .. 16#963#
        | 16#981# .. 16#983# | 16#9BC#
        | 16#9BE# | 16#9BF#
        | 16#9C0# .. 16#9C4# | 16#9C7# .. 16#9C8#
        | 16#9CB# .. 16#9CD# | 16#9D7#
        | 16#9E2# .. 16#9E3# | 16#A02#
        | 16#A3C# | 16#A3E#
        | 16#A3F# | 16#A40# .. 16#A42#
        | 16#A47# .. 16#A48# | 16#A4B# .. 16#A4D#
        | 16#A70# .. 16#A71# | 16#A81# .. 16#A83#
        | 16#ABC# | 16#ABE# .. 16#AC5#
        | 16#AC7# .. 16#AC9# | 16#ACB# .. 16#ACD#
        | 16#B01# .. 16#B03# | 16#B3C#
        | 16#B3E# .. 16#B43# | 16#B47# .. 16#B48#
        | 16#B4B# .. 16#B4D# | 16#B56# .. 16#B57#
        | 16#B82# .. 16#B83# | 16#BBE# .. 16#BC2#
        | 16#BC6# .. 16#BC8# | 16#BCA# .. 16#BCD#
        | 16#BD7# | 16#C01# .. 16#C03#
        | 16#C3E# .. 16#C44# | 16#C46# .. 16#C48#
        | 16#C4A# .. 16#C4D# | 16#C55# .. 16#C56#
        | 16#C82# .. 16#C83# | 16#CBE# .. 16#CC4#
        | 16#CC6# .. 16#CC8# | 16#CCA# .. 16#CCD#
        | 16#CD5# .. 16#CD6# | 16#D02# .. 16#D03#
        | 16#D3E# .. 16#D43# | 16#D46# .. 16#D48#
        | 16#D4A# .. 16#D4D# | 16#D57#
        | 16#E31# | 16#E34# .. 16#E3A#
        | 16#E47# .. 16#E4E# | 16#EB1#
        | 16#EB4# .. 16#EB9# | 16#EBB# .. 16#EBC#
        | 16#EC8# .. 16#ECD# | 16#F18# .. 16#F19#
        | 16#F35# | 16#F37#
        | 16#F39# | 16#F3E#
        | 16#F3F# | 16#F71# .. 16#F84#
        | 16#F86# .. 16#F8B# | 16#F90# .. 16#F95#
        | 16#F97# | 16#F99# .. 16#FAD#
        | 16#FB1# .. 16#FB7# | 16#FB9#
        | 16#20D0# .. 16#20DC# | 16#20E1#
        | 16#302A# .. 16#302F# | 16#3099#
        | 16#309A#);

   function XML_Digit (C : Natural) return Boolean is
     (C in 16#30# .. 16#39# | 16#660# .. 16#669# | 16#6F0# .. 16#6F9#
        | 16#966# .. 16#96F# | 16#9E6# .. 16#9EF# | 16#A66# .. 16#A6F#
        | 16#AE6# .. 16#AEF# | 16#B66# .. 16#B6F# | 16#BE7# .. 16#BEF#
        | 16#C66# .. 16#C6F# | 16#CE6# .. 16#CEF# | 16#D66# .. 16#D6F#
        | 16#E50# .. 16#E59# | 16#ED0# .. 16#ED9# | 16#F20# .. 16#F29#);

   function XML_Extender (C : Natural) return Boolean is
     (C in 16#B7# | 16#2D0# .. 16#2D1# | 16#387# | 16#640# | 16#E46#
        | 16#EC6# | 16#3005# | 16#3031# .. 16#3035#
        | 16#309D# .. 16#309E# | 16#30FC# .. 16#30FE#);

   function XML_Ideographic (C : Natural) return Boolean is
     (C in 16#3007# | 16#3021# .. 16#3029# | 16#4E00# .. 16#9FA5#);

   function XML_Pubid_Char (C : Natural) return Boolean is
     (C <= 127 and then Character'Val (C) in
        ' ' | Character'Val (10) | Character'Val (13)
        | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
        | '-' | Character'Val (39) | '(' | ')' | '+' | ',' | '.' | '/'
        | ':' | '=' | '?' | ';' | '!' | '*' | '#' | '@' | '$' | '_' | '%');

   function NCName_Start (C : Natural) return Boolean is
     (C in 16#41# .. 16#5A# or C = 16#5F# or C in 16#61# .. 16#7A#
      or C in 16#C0# .. 16#D6# or C in 16#D8# .. 16#F6#
      or C in 16#F8# .. 16#2FF# or C in 16#370# .. 16#37D#
      or C in 16#37F# .. 16#1FFF# or C in 16#200C# .. 16#200D#
      or C in 16#2070# .. 16#218F# or C in 16#2C00# .. 16#2FEF#
      or C in 16#3001# .. 16#D7FF# or C in 16#F900# .. 16#FDCF#
      or C in 16#FDF0# .. 16#FFFD# or C in 16#10000# .. 16#EFFFF#);

   function Name_Character
     (Code : Natural; Initial : Boolean; Allow_Colon : Boolean := True)
      return Boolean is
     ((Allow_Colon and then Code = Character'Pos (':'))
      or else NCName_Start (Code)
      or else (not Initial and then
        (Code in 16#2D# .. 16#2E# | 16#30# .. 16#39# | 16#B7#
           | 16#300# .. 16#36F# | 16#203F# .. 16#2040#)));

   function Name_Width
     (Input : String; First : Positive; Initial : Boolean) return Natural
   is
      C, B, Extra, Minimum : Natural;
   begin
      if First > Input'Last then
         return 0;
      end if;
      B := Character'Pos (Input (First));
      if B < 128 then
         C := B;
         Extra := 0;
         Minimum := 0;
      elsif B in 16#C2# .. 16#DF# then
         C := B - 16#C0#;
         Extra := 1;
         Minimum := 16#80#;
      elsif B in 16#E0# .. 16#EF# then
         C := B - 16#E0#;
         Extra := 2;
         Minimum := 16#800#;
      elsif B in 16#F0# .. 16#F4# then
         C := B - 16#F0#;
         Extra := 3;
         Minimum := 16#10000#;
      else
         return 0;
      end if;
      if Extra > Input'Last - First then
         return 0;
      end if;
      for J in 1 .. Extra loop
         pragma Loop_Invariant (C <= 16#10FFFF#);
         B := Character'Pos (Input (First + J));
         if B not in 16#80# .. 16#BF#
           or else C > (16#10FFFF# - (B - 16#80#)) / 64
         then
            return 0;
         end if;
         C := C * 64 + B - 16#80#;
      end loop;
      if C < Minimum then
         return 0;
      end if;
      if Name_Character (C, Initial, Allow_Colon => False) then
         return Extra + 1;
      end if;
      return 0;
   end Name_Width;

   function Valid_Name
     (Input : String; Kind : Name_Kind; Allow_Space : Boolean) return Boolean
   is
      Position : Positive := 1;
      Last : Natural := Input'Last;
      Initial : Boolean := True;
      Colon_Seen : Boolean := False;
      Width : Natural;
      function Blank (C : Character) return Boolean is
        (XML_Blank (Character'Pos (C)));
   begin
      if Allow_Space then
         while Position <= Last and then Blank (Input (Position)) loop
            pragma Loop_Invariant (Position in 1 .. Input'Length + 1);
            pragma Loop_Variant (Increases => Position);
            Position := Position + 1;
         end loop;
         while Last >= Position and then Blank (Input (Last)) loop
            pragma Loop_Invariant (Last <= Input'Last);
            pragma Loop_Variant (Decreases => Last);
            Last := Last - 1;
         end loop;
      end if;
      if Position > Last then
         return False;
      end if;
      while Position <= Last loop
         pragma Loop_Invariant (Position in 1 .. Input'Length + 1);
         pragma Loop_Variant (Increases => Position);
         if Input (Position) = ':' then
            if Kind = NCName
              or else (Kind = QName and then (Initial or else Colon_Seen))
            then
               return False;
            end if;
            Colon_Seen := True;
            Initial := Kind = QName;
            Position := Position + 1;
         else
            Width := Name_Width
              (Input, Position, Initial and then Kind /= NMToken);
            if Width = 0 or else Width > Last - Position + 1 then
               return False;
            end if;
            Initial := False;
            Position := Position + Width;
         end if;
      end loop;
      return not Initial;
   end Valid_Name;

   procedure Validate_UTF8
     (Input : String;
      Kind : out Text_Error_Kind;
      Error_Position : out Natural;
      XML_Only : Boolean := True)
   is
      I : Positive := Input'First;
      C, B, Extra, Minimum : Natural;
   begin
      Kind := No_Text_Error;
      Error_Position := 0;
      while I <= Input'Last loop
         pragma Loop_Invariant (I in Input'First .. Input'Last + 1);
         pragma Loop_Variant (Increases => I);
         B := Character'Pos (Input (I));
         if B < 128 then
            C := B;
            Extra := 0;
            Minimum := 0;
         elsif B in 16#C2# .. 16#DF# then
            C := B - 16#C0#;
            Extra := 1;
            Minimum := 16#80#;
         elsif B in 16#E0# .. 16#EF# then
            C := B - 16#E0#;
            Extra := 2;
            Minimum := 16#800#;
         elsif B in 16#F0# .. 16#F4# then
            C := B - 16#F0#;
            Extra := 3;
            Minimum := 16#10000#;
         else
            Kind := Invalid_UTF8;
            Error_Position := I;
            return;
         end if;
         if Extra > Input'Last - I then
            Kind := Invalid_UTF8;
            Error_Position := I;
            return;
         end if;
         for J in 1 .. Extra loop
            pragma Loop_Invariant (C <= 16#10FFFF#);
            B := Character'Pos (Input (I + J));
            if B not in 16#80# .. 16#BF# then
               Kind := Invalid_UTF8;
               Error_Position := I;
               return;
            end if;
            if C > (16#10FFFF# - (B - 16#80#)) / 64 then
               Kind := Invalid_UTF8;
               Error_Position := I;
               return;
            end if;
            C := C * 64 + B - 16#80#;
         end loop;
         if C < Minimum then
            Kind := Invalid_UTF8;
            Error_Position := I;
            return;
         elsif C in 16#D800# .. 16#DFFF# then
            Kind := Invalid_UTF8;
            Error_Position := I;
            return;
         elsif XML_Only and then not XML_Char (C) then
            Kind := Invalid_XML_Character;
            Error_Position := I;
            return;
         end if;
         I := I + Extra + 1;
      end loop;
   end Validate_UTF8;

   function Valid_UTF8 (Input : String) return Boolean is
      Kind : Text_Error_Kind;
      Error_Position : Natural;
   begin
      Validate_UTF8 (Input, Kind, Error_Position);
      return Kind = No_Text_Error;
   end Valid_UTF8;

   procedure Decode
     (Input      : String;
      Attribute  : Boolean;
      References : Boolean;
      Output     : out String;
      Length     : out Byte_Count;
      Valid      : out Boolean;
      Normalize_Line_Endings : Boolean := True)
   is
      I : Positive := Input'First;
      J : Positive;
      Code : Natural;
      Base : Positive;
      Digit : Natural;
      Start : Positive;
      Bytes : Natural;
      C : Character;
      Entity : Entity_Kind;
   begin
      Output := (others => Character'Val (0));
      Length := 0;
      Valid := False;
      if not Valid_UTF8 (Input) then
         return;
      end if;
      while I <= Input'Last loop
         pragma Loop_Invariant (I in Input'First .. Input'Last + 1);
         pragma Loop_Invariant (Length <= I - Input'First);
         pragma Loop_Invariant (Length <= Output'Length);
         pragma Loop_Variant (Increases => I);
         C := Input (I);
         if C = '&' and References then
            J := I + 1;
            while J <= Input'Last and then Input (J) /= ';' loop
               pragma Loop_Invariant (J in I + 1 .. Input'Last + 1);
               pragma Loop_Variant (Increases => J);
               J := J + 1;
            end loop;
            if J > Input'Last then
               return;
            end if;
            Entity := Find_Entity (Input (I + 1 .. J - 1));
            if Entity /= No_Entity then
               Code := Character'Pos (Entity_Value (Entity));
            elsif I + 2 < J and then Input (I + 1) = '#' then
               Start := I + 2;
               Base := 10;
               if Input (Start) = 'x' then
                  Base := 16;
                  Start := Start + 1;
               end if;
               if Start = J then
                  return;
               end if;
               Code := 0;
               for K in Start .. J - 1 loop
                  pragma Loop_Invariant (Code <= 16#10FFFF#);
                  C := Input (K);
                  if C in '0' .. '9' then
                     Digit := Character'Pos (C) - Character'Pos ('0');
                  elsif Base = 16 and C in 'a' .. 'f' then
                     Digit := Character'Pos (C) - Character'Pos ('a') + 10;
                  elsif Base = 16 and C in 'A' .. 'F' then
                     Digit := Character'Pos (C) - Character'Pos ('A') + 10;
                  else
                     return;
                  end if;
                  if Code > (16#10FFFF# - Digit) / Base then
                     return;
                  end if;
                  Code := Code * Base + Digit;
               end loop;
            else
               return;
            end if;
            if not XML_Char (Code) then
               return;
            end if;
            Bytes := UTF8_Width (Code);
            if Bytes > J - I + 1 or else Bytes > Output'Length - Length then
               return;
            end if;
            Output (Length + 1 .. Length + Bytes) := UTF8_Image (Code);
            Length := Length + Bytes;
            I := J + 1;
         else
            if Normalize_Line_Endings and then C = Character'Val (13) then
               if I < Input'Last and then Input (I + 1) = Character'Val (10) then
                  I := I + 1;
               end if;
               C := Character'Val (10);
            end if;
            if Attribute and then (C = Character'Val (9) or C = Character'Val (10)) then
               C := ' ';
            end if;
            Length := Length + 1;
            Output (Length) := C;
            I := I + 1;
         end if;
      end loop;
      Valid := True;
   end Decode;
end XML3_Text;
