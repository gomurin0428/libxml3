package body XML3_Text with SPARK_Mode is
   function XML_Char (C : Natural) return Boolean is
     (C = 9 or C = 10 or C = 13
      or (C in 16#20# .. 16#D7FF#)
      or (C in 16#E000# .. 16#FFFD#)
      or (C in 16#10000# .. 16#10FFFF#));

   function NCName_Start (C : Natural) return Boolean is
     (C in 16#41# .. 16#5A# or C = 16#5F# or C in 16#61# .. 16#7A#
      or C in 16#C0# .. 16#D6# or C in 16#D8# .. 16#F6#
      or C in 16#F8# .. 16#2FF# or C in 16#370# .. 16#37D#
      or C in 16#37F# .. 16#1FFF# or C in 16#200C# .. 16#200D#
      or C in 16#2070# .. 16#218F# or C in 16#2C00# .. 16#2FEF#
      or C in 16#3001# .. 16#D7FF# or C in 16#F900# .. 16#FDCF#
      or C in 16#FDF0# .. 16#FFFD# or C in 16#10000# .. 16#EFFFF#);

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
      if NCName_Start (C) or else
        (not Initial and then
          (C = 16#2D# or C = 16#2E# or C in 16#30# .. 16#39#
           or C = 16#B7# or C in 16#300# .. 16#36F#
           or C in 16#203F# .. 16#2040#))
      then
         return Extra + 1;
      end if;
      return 0;
   end Name_Width;

   function Valid_UTF8 (Input : String) return Boolean is
      I : Positive := 1;
      C, B, Extra, Minimum : Natural;
   begin
      while I <= Input'Last loop
         pragma Loop_Invariant (I in 1 .. Input'Length + 1);
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
            return False;
         end if;
         if Extra > Input'Last - I then
            return False;
         end if;
         for J in 1 .. Extra loop
            pragma Loop_Invariant (C <= 16#10FFFF#);
            B := Character'Pos (Input (I + J));
            if B not in 16#80# .. 16#BF# then
               return False;
            end if;
            if C > (16#10FFFF# - (B - 16#80#)) / 64 then
               return False;
            end if;
            C := C * 64 + B - 16#80#;
         end loop;
         if C < Minimum or else not XML_Char (C) then
            return False;
         end if;
         I := I + Extra + 1;
      end loop;
      return True;
   end Valid_UTF8;

   procedure Decode
     (Input      : String;
      Attribute  : Boolean;
      References : Boolean;
      Output     : out String;
      Length     : out Byte_Count;
      Valid      : out Boolean)
   is
      I : Positive := 1;
      J : Positive;
      Code : Natural;
      Base : Positive;
      Digit : Natural;
      Start : Positive;
      Bytes : Natural;
      C : Character;
   begin
      Output := (others => Character'Val (0));
      Length := 0;
      Valid := False;
      if not Valid_UTF8 (Input) then
         return;
      end if;
      while I <= Input'Last loop
         pragma Loop_Invariant (I in 1 .. Input'Length + 1);
         pragma Loop_Invariant (Length < I);
         pragma Loop_Invariant (Length <= Output'Length);
         pragma Loop_Variant (Increases => I);
         C := Input (I);
         if C = '&' and References then
            J := I + 1;
            while J <= Input'Last and then Input (J) /= ';' loop
               pragma Loop_Invariant (J in I + 1 .. Input'Length + 1);
               pragma Loop_Variant (Increases => J);
               J := J + 1;
            end loop;
            if J > Input'Last then
               return;
            end if;
            if Input (I .. J) = "&lt;" then
               Code := 60;
            elsif Input (I .. J) = "&gt;" then
               Code := 62;
            elsif Input (I .. J) = "&amp;" then
               Code := 38;
            elsif Input (I .. J) = "&apos;" then
               Code := 39;
            elsif Input (I .. J) = "&quot;" then
               Code := 34;
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
            if Code <= 16#7F# then
               Bytes := 1;
            elsif Code <= 16#7FF# then
               Bytes := 2;
            elsif Code <= 16#FFFF# then
               Bytes := 3;
            else
               Bytes := 4;
            end if;
            if Bytes > J - I + 1 or else Bytes > Output'Length - Length then
               return;
            end if;
            case Bytes is
               when 1 =>
                  Output (Length + 1) := Character'Val (Code);
               when 2 =>
                  Output (Length + 1) := Character'Val (16#C0# + Code / 64);
                  Output (Length + 2) := Character'Val (16#80# + Code mod 64);
               when 3 =>
                  Output (Length + 1) := Character'Val (16#E0# + Code / 4096);
                  Output (Length + 2) := Character'Val (16#80# + (Code / 64) mod 64);
                  Output (Length + 3) := Character'Val (16#80# + Code mod 64);
               when others =>
                  Output (Length + 1) := Character'Val (16#F0# + Code / 262_144);
                  Output (Length + 2) := Character'Val (16#80# + (Code / 4096) mod 64);
                  Output (Length + 3) := Character'Val (16#80# + (Code / 64) mod 64);
                  Output (Length + 4) := Character'Val (16#80# + Code mod 64);
            end case;
            Length := Length + Bytes;
            I := J + 1;
         else
            if C = Character'Val (13) then
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
