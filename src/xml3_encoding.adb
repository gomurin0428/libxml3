package body XML3_Encoding with SPARK_Mode is
   function Upper (C : Character) return Character is
     (if C in 'a' .. 'z'
      then Character'Val (Character'Pos (C) - 32) else C);

   function Equal_Name (Left, Right : String) return Boolean
     with Global => null
   is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      for K in 0 .. Left'Length - 1 loop
         if Upper (Left (Left'First + K)) /= Right (Right'First + K) then
            return False;
         end if;
      end loop;
      return True;
   end Equal_Name;

   function Classify (Name : String) return Encoding_Kind is
   begin
      for Item of Known_Names loop
         if Equal_Name (Name, Item.Value (1 .. Item.Length)) then
            return Item.Kind;
         end if;
      end loop;
      return Unsupported;
   end Classify;

   function Valid_Name (Name : String) return Boolean is
   begin
      if Name'Length = 0 or else Upper (Name (Name'First)) not in 'A' .. 'Z' then
         return False;
      end if;
      for C of Name loop
         if Upper (C) not in 'A' .. 'Z' and then C not in '0' .. '9'
           and then C /= '.' and then C /= '_' and then C /= '-'
         then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Name;

   function Declaration_Matches
     (Name : String; Kind : Concrete_Encoding) return Boolean
   is
      Declared : constant Encoding_Kind := Classify (Name);
   begin
      return Declared = Kind
        or else (Declared = UTF16 and then Kind in UTF16LE .. UTF16BE);
   end Declaration_Matches;

   function Detect
     (Input : String; Requested : Encoding_Kind) return Encoding_Info
   is
      Result : Encoding_Info;
      LE_BOM : constant Boolean := Input'Length >= 2
        and then Input (1) = Character'Val (16#FF#)
        and then Input (2) = Character'Val (16#FE#);
      BE_BOM : constant Boolean := Input'Length >= 2
        and then Input (1) = Character'Val (16#FE#)
        and then Input (2) = Character'Val (16#FF#);
      UTF8_BOM : constant Boolean := Input'Length >= 3
        and then Input (1) = Character'Val (16#EF#)
        and then Input (2) = Character'Val (16#BB#)
        and then Input (3) = Character'Val (16#BF#);
   begin
      Result.Explicit := Requested /= Unspecified;
      if Requested /= Unspecified then
         --  The pinned libxml2 built-in UTF-16 handler is little-endian.
         Result.Kind := (if Requested = UTF16 then UTF16LE else Requested);
      elsif LE_BOM then
         Result.Kind := UTF16LE;
         Result.Auto_Detected := True;
      elsif BE_BOM then
         Result.Kind := UTF16BE;
         Result.Auto_Detected := True;
      elsif UTF8_BOM then
         Result.Auto_Detected := True;
      elsif Input'Length >= 4 then
         if Input (1 .. 4) = '<' & Character'Val (0) & '?' & Character'Val (0) then
            Result.Kind := UTF16LE;
            Result.Auto_Detected := True;
         elsif Input (1 .. 4) = Character'Val (0) & '<' & Character'Val (0) & '?' then
            Result.Kind := UTF16BE;
            Result.Auto_Detected := True;
         end if;
      end if;
      if Result.Kind = UTF8 and then UTF8_BOM then
         Result.Skip := 3;
      elsif (Result.Kind = UTF16LE and then LE_BOM)
        or else (Result.Kind = UTF16BE and then BE_BOM)
      then
         Result.Skip := 2;
      end if;
      return Result;
   end Detect;

   function Read_UTF16_Unit
     (First, Second : Character; Little_Endian : Boolean) return UTF16_Unit is
     (if Little_Endian then Character'Pos (First) + Character'Pos (Second) * 256
      else Character'Pos (First) * 256 + Character'Pos (Second));

   procedure Decode_UTF16_Pair
     (High, Low : UTF16_Unit; Have_Low : Boolean;
      Code, Consumed : out Natural)
   is
   begin
      Code := 0;
      Consumed := 0;
      if High in 16#D800# .. 16#DBFF# then
         if not Have_Low or else Low not in 16#DC00# .. 16#DFFF# then
            return;
         end if;
         Code := 16#10000# + (High - 16#D800#) * 1024 + Low - 16#DC00#;
         Consumed := 4;
      elsif High not in 16#DC00# .. 16#DFFF# then
         Code := High;
         Consumed := 2;
      end if;
   end Decode_UTF16_Pair;

   procedure Decode_UTF16
     (Input : String;
      Little_Endian : Boolean;
      Output : out String;
      Length : out XML3_Text.Byte_Count;
      Status : out Conversion_Status;
      Error_Position : out Natural;
      Measure_Only : Boolean := False)
   is
      I : Positive := 1;
      C, Consumed : Natural;
      High, Low : UTF16_Unit;
      Have_Low : Boolean;
      Width : Positive range 1 .. 4;

      function Unit_At (Position : Positive) return Natural
        with Pre => Position in Input'Range
          and then Position < Input'Last,
          Post => Unit_At'Result <= 16#FFFF#
      is
      begin
         return Read_UTF16_Unit
           (Input (Position), Input (Position + 1), Little_Endian);
      end Unit_At;
   begin
      Output := (others => Character'Val (0));
      Length := 0;
      Status := Success;
      Error_Position := 0;
      while I <= Input'Length loop
         pragma Loop_Invariant (I in 1 .. Input'Length + 1);
         pragma Loop_Invariant (if not Measure_Only then Length <= Output'Length);
         pragma Loop_Variant (Increases => I);
         Error_Position := I;
         Status := Invalid_Encoding;
         if Input'Length - I < 1 then
            return;
         end if;
         High := Unit_At (I);
         Have_Low := High in 16#D800# .. 16#DBFF#
           and then Input'Length - I >= 3;
         Low := (if Have_Low then Unit_At (I + 2) else 0);
         Decode_UTF16_Pair (High, Low, Have_Low, C, Consumed);
         if Consumed = 0 then
            return;
         end if;
         Width := XML3_Text.UTF8_Width (C);
         if Width > XML3_Text.Max_Bytes - Length
           or else (not Measure_Only and then Width > Output'Length - Length)
         then
            Status := Output_Too_Small;
            return;
         end if;
         if not Measure_Only then
            Output (Length + 1 .. Length + Width) := XML3_Text.UTF8_Image (C);
         end if;
         Length := Length + Width;
         I := I + Consumed;
      end loop;
      Status := Success;
      Error_Position := 0;
   end Decode_UTF16;
end XML3_Encoding;
