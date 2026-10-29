package body XML3_Text.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;

   function Character_In_Range
     (Code : Interfaces.C.unsigned; Group : System.Address) return Boolean
   is
      Item : Native.Character_Range_Group;
      Short_Range : constant Boolean := Code < 16#10000#;
      Stride : constant Native.Positive_Byte_Count :=
        (if Short_Range then Native.Short_Range_Bytes else Native.Long_Range_Bytes);
      Count : Interfaces.C.int;
      Ranges : System.Address;
   begin
      if Group = System.Null_Address then
         return False;
      end if;
      Native.Read_Character_Range_Group (Group, Item);
      if Short_Range then
         Count := Item.Short_Count;
         Ranges := Item.Short_Ranges;
      else
         Count := Item.Long_Count;
         Ranges := Item.Long_Ranges;
      end if;
      if Count <= 0 or else Ranges = System.Null_Address
        or else Native.Byte_Count (Count) > Native.Byte_Count'Last / Stride
      then
         return False;
      end if;
      declare
         Low : Natural := 0;
         High : Natural := Natural (Count);
         Mid : Natural;
         Range_Low, Range_High : Interfaces.C.unsigned;
      begin
         while Low < High loop
            pragma Loop_Invariant (Low <= High and then High <= Natural (Count));
            pragma Loop_Variant (Decreases => High - Low);
            Mid := Low + (High - Low - 1) / 2;
            Native.Read_Character_Range
              (Ranges, Mid, Short_Range, Range_Low, Range_High);
            if Code < Range_Low then
               High := Mid;
            elsif Code > Range_High then
               Low := Mid + 1;
            else
               return True;
            end if;
         end loop;
      end;
      return False;
   end Character_In_Range;

   function Matches_Literal (Item : System.Address; Pattern : String)
     return Boolean
     with Global => (Input => Native.Foreign_Memory),
       Pre => Pattern'First = 1 and then Pattern'Last in 0 .. Max_Bytes
   is
      Current : Character;
   begin
      if Item = System.Null_Address then
         return False;
      end if;
      for I in Pattern'Range loop
         Current := Native.Byte_At (Item, I - 1);
         if Current = Character'Val (0) or else Current /= Pattern (I) then
            return False;
         end if;
      end loop;
      return Native.Byte_At (Item, Pattern'Length) = Character'Val (0);
   end Matches_Literal;

   function Is_XHTML (System_ID, Public_ID : System.Address) return Integer is
   begin
      if System_ID = System.Null_Address and then Public_ID = System.Null_Address then
         return -1;
      end if;
      if Matches_Literal (Public_ID, "-//W3C//DTD XHTML 1.0 Strict//EN")
        or else Matches_Literal (Public_ID, "-//W3C//DTD XHTML 1.0 Frameset//EN")
        or else Matches_Literal (Public_ID, "-//W3C//DTD XHTML 1.0 Transitional//EN")
        or else Matches_Literal
          (System_ID, "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd")
        or else Matches_Literal
          (System_ID, "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd")
        or else Matches_Literal
          (System_ID, "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
      then
         return 1;
      end if;
      return 0;
   end Is_XHTML;

   function Special_Image (Item : Character; Attribute, Quotes : Boolean)
     return String
     with Global => null,
       Post => Special_Image'Result'Length in 1 .. 6
   is
   begin
      case Item is
         when '<' => return "&lt;";
         when '>' => return "&gt;";
         when '&' => return "&amp;";
         when '"' =>
            return (if Attribute or else Quotes then "&quot;" else """");
         when Character'Val (9) =>
            return (if Attribute then "&#9;" else (1 => Item));
         when Character'Val (10) =>
            return (if Attribute then "&#10;" else (1 => Item));
         when Character'Val (13) => return "&#13;";
         when others => return (1 => Item);
      end case;
   end Special_Image;

   function Character_Reference (Code : Natural) return String is
      Hex : constant String := "0123456789ABCDEF";
      Buffer : String (1 .. 6) := (others => '0');
      First : Positive := Buffer'Last;
      Value : Natural := Code;
   begin
      loop
         pragma Loop_Invariant (First in Buffer'Range);
         pragma Loop_Variant (Decreases => Value);
         Buffer (First) := Hex ((Value mod 16) + 1);
         Value := Value / 16;
         exit when Value = 0 or else First = Buffer'First;
         First := First - 1;
      end loop;
      return "&#x" & Buffer (First .. Buffer'Last) & ";";
   end Character_Reference;

   function Image_Width (Item : Character; Non_ASCII : Boolean) return Positive
     with Global => null, Post => Image_Width'Result in 1 .. 4
   is
   begin
      if not Non_ASCII then
         return 1;
      end if;
      case Character'Pos (Item) is
         when 16#C2# .. 16#DF# => return 2;
         when 16#E0# .. 16#EF# => return 3;
         when 16#F0# .. 16#F4# => return 4;
         when others => return 1;
      end case;
   end Image_Width;

   function Escaped_Image (Input : String; Attribute, Quotes : Boolean)
     return String
     with Global => null, Pre => Input'Length in 1 .. 4
       and then Input'First >= 1 and then Input'Last <= Max_Bytes,
       Post => Escaped_Image'Result'Length <= 10
   is
      Code, Byte : Natural;
   begin
      if Input'Length = 1 then
         return Special_Image (Input (Input'First), Attribute, Quotes);
      end if;
      Code := Character'Pos (Input (Input'First)) mod 2 ** (7 - Input'Length);
      for I in Input'First + 1 .. Input'Last loop
         Byte := Character'Pos (Input (I)) mod 64;
         if Code > (16#10FFFF# - Byte) / 64 then
            return "";
         end if;
         Code := Code * 64 + Byte;
      end loop;
      if Code > 16#10FFFF# then
         return "";
      end if;
      return Character_Reference (Code);
   end Escaped_Image;

   procedure Escape_Special
     (Input : String; Result : out System.Address; Status : out Escape_Status;
      Limit : Byte_Count := Max_Bytes;
      Non_ASCII, Attribute : Boolean := False; Quotes : Boolean := True)
   is
      Length, Position : Byte_Count := 0;
      Kind : Text_Error_Kind;
      Error : Natural;
      Base : System.Address;
      I, Width : Natural;
   begin
      Result := System.Null_Address;
      Status := Invalid_Text;
      Validate_UTF8 (Input, Kind, Error);
      if Kind /= No_Text_Error then
         return;
      end if;
      Status := Escape_Limit_Exceeded;
      I := 1;
      while I <= Input'Last loop
         pragma Loop_Invariant (Length <= Limit);
         pragma Loop_Invariant (I in 1 .. Input'Last + 1);
         pragma Loop_Variant (Increases => I);
         Width := Image_Width (Input (I), Non_ASCII);
         if Width > Input'Last - I + 1 then
            Status := Invalid_Text;
            return;
         end if;
         declare
            Image : constant String := Escaped_Image
              (Input (I .. I + Width - 1), Attribute, Quotes);
         begin
            if Image'Length = 0 then
               Status := Invalid_Text;
               return;
            elsif Image'Length > Limit - Length then
               return;
            end if;
            Length := Length + Image'Length;
         end;
         I := I + Width;
      end loop;
      Status := Escape_No_Memory;
      Native.Allocate (Native.Byte_Count (Length) + 1, Base);
      if Base = System.Null_Address then
         return;
      end if;
      I := 1;
      while I <= Input'Last loop
         pragma Loop_Invariant (Position <= Length);
         pragma Loop_Invariant (I in 1 .. Input'Last + 1);
         pragma Loop_Variant (Increases => I);
         Width := Image_Width (Input (I), Non_ASCII);
         if Width > Input'Last - I + 1 then
            Native.Free (Base);
            Status := Invalid_Text;
            return;
         end if;
         declare
            Image : constant String := Escaped_Image
              (Input (I .. I + Width - 1), Attribute, Quotes);
         begin
            if Image'Length = 0 then
               Native.Free (Base);
               Status := Invalid_Text;
               return;
            elsif Image'Length > Length - Position then
               Native.Free (Base);
               Status := Escape_Limit_Exceeded;
               return;
            end if;
            Native.Write_String (Base, Position, Image);
            Position := Position + Image'Length;
         end;
         I := I + Width;
      end loop;
      Native.Write_Byte (Base, Position, Character'Val (0));
      Result := Base;
      Status := Escaped;
   end Escape_Special;

   function UTF8_Lead_Size (Item : System.Address) return Integer is
   begin
      if Item = System.Null_Address then
         return -1;
      end if;
      case Character'Pos (Native.Byte_At (Item, 0)) is
         when 0 .. 16#7F# => return 1;
         when 16#C2# .. 16#DF# => return 2;
         when 16#E0# .. 16#EF# => return 3;
         when 16#F0# .. 16#F4# => return 4;
         when others => return -1;
      end case;
   end UTF8_Lead_Size;

   procedure Compare_UTF8_Character
     (Left, Right : System.Address; Result : out Integer; Invalid : out Boolean)
   is
      Width : Integer;
      Code : Integer;
      pragma Unreferenced (Code);
      Decoded : Natural;
   begin
      Invalid := False;
      if Left = System.Null_Address then
         Result := (if Right = System.Null_Address then 0 else -1);
         return;
      elsif Right = System.Null_Address then
         Result := 1;
         return;
      end if;
      Width := UTF8_Lead_Size (Left);
      if Width < 1 then
         Result := -1;
         Invalid := True;
         return;
      end if;
      Result := Compare_Bounded (Left, Right, Width, Ignore_Case => False);
      if Result = 0 then
         Get_UTF8_Char (Left, Width, Code, Decoded);
         if Decoded = 0 then
            Result := -1;
            Invalid := True;
         end if;
      end if;
   end Compare_UTF8_Character;

   procedure Copy_Span
     (Item : System.Address; Start, Length : Byte_Count;
      Result : out System.Address; Status : out Slice_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Item /= System.Null_Address and then Length <= Max_Bytes - Start,
       Post => Status in Sliced | No_Memory
         and then (if Status = Sliced then Result /= System.Null_Address
                   else Result = System.Null_Address);

   procedure Copy_Span
     (Item : System.Address; Start, Length : Byte_Count;
      Result : out System.Address; Status : out Slice_Status)
   is
      Current : Character;
   begin
      Status := No_Memory;
      Native.Allocate (Native.Byte_Count (Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      for Index in 0 .. Length - 1 loop
         Current := Native.Byte_At (Item, Start + Index);
         Native.Write_Byte (Result, Index, Current);
      end loop;
      Native.Write_Byte (Result, Length, Character'Val (0));
      Status := Sliced;
   end Copy_Span;

   procedure Copy_UTF8_Prefix
     (Item : System.Address; Characters : Integer;
      Result : out System.Address; Status : out Slice_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Size : Byte_Count;
      Encoding : UTF8_Status;
   begin
      Result := System.Null_Address;
      Status := No_Slice;
      if Item = System.Null_Address or else Characters < 0 then
         return;
      end if;
      Measure_UTF8_Prefix (Item, Characters, Size, Encoding, Last);
      case Encoding is
         when UTF8_Valid => Copy_Span (Item, 0, Size, Result, Status);
         when UTF8_Invalid => null;
         when UTF8_Limit_Exceeded => Status := Slice_Limit_Exceeded;
      end case;
   end Copy_UTF8_Prefix;

   procedure Copy_UTF8_Slice
     (Item : System.Address; Start, Characters : Integer;
      Result : out System.Address; Status : out Slice_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Position : Byte_Count;
      Found : Search_Status;
   begin
      Result := System.Null_Address;
      Status := No_Slice;
      if Item = System.Null_Address or else Start < 0 or else Characters < 0 then
         return;
      end if;
      Find_UTF8_Position (Item, Start, Position, Found, Last);
      case Found is
         when Matched =>
            Copy_UTF8_Prefix
              (Native.Offset (Item, Native.Byte_Count (Position)), Characters,
               Result, Status, Last - Position);
         when No_Match => null;
         when Search_Limit_Exceeded => Status := Slice_Limit_Exceeded;
      end case;
   end Copy_UTF8_Slice;

   procedure Scan_UTF8
     (Item : System.Address; Stop_After : Integer;
      Length, Offset : out Byte_Count; Status : out UTF8_Status; Last : Byte_Count;
      Pattern : String := "")
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Length <= Offset and then Offset <= Last
         and then (if Status /= UTF8_Valid then Length = 0 and Offset = 0)
         and then (if Item = System.Null_Address then Status = UTF8_Invalid);

   procedure Check_UTF8
     (Item : System.Address; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Length : Byte_Count;
      pragma Unreferenced (Length);
   begin
      Count_UTF8 (Item, Length, Status, Last);
   end Check_UTF8;

   procedure Count_UTF8
     (Item : System.Address; Length : out Byte_Count; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Offset : Byte_Count;
      pragma Unreferenced (Offset);
   begin
      Scan_UTF8 (Item, -1, Length, Offset, Status, Last);
   end Count_UTF8;

   procedure Measure_UTF8_Prefix
     (Item : System.Address; Characters : Integer;
      Size : out Byte_Count; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Length : Byte_Count;
      pragma Unreferenced (Length);
   begin
      Size := 0;
      Status := UTF8_Valid;
      if Item = System.Null_Address or else Characters <= 0 then
         return;
      end if;
      Scan_UTF8 (Item, Characters, Length, Size, Status, Last);
   end Measure_UTF8_Prefix;

   procedure Find_UTF8_Position
     (Item : System.Address; Index : Integer;
      Position : out Byte_Count; Status : out Search_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Length, Offset : Byte_Count;
      Result : UTF8_Status;
   begin
      Position := 0;
      Status := No_Match;
      if Index < 0 then
         return;
      end if;
      Scan_UTF8 (Item, Index, Length, Offset, Result, Last);
      if Result = UTF8_Valid and then Length = Index then
         Position := Offset;
         Status := Matched;
      elsif Result = UTF8_Limit_Exceeded then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_UTF8_Position;

   procedure Find_UTF8_Character
     (Item, Pattern : System.Address;
      Index : out Byte_Count; Status : out Search_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Size, Length, Position : Byte_Count;
      Encoding : UTF8_Status;
      Bytes : String (1 .. 4) := (others => Character'Val (0));
   begin
      Index := 0;
      Status := No_Match;
      if Item = System.Null_Address or else Pattern = System.Null_Address then
         return;
      end if;
      Measure_UTF8_Prefix (Pattern, 1, Size, Encoding, 4);
      if Encoding /= UTF8_Valid then
         return;
      elsif Size = 0 then
         if Native.Byte_At (Item, 0) /= Character'Val (0) then
            Status := Matched;
         end if;
         return;
      end if;
      for J in 1 .. Size loop
         Bytes (J) := Native.Byte_At (Pattern, J - 1);
      end loop;
      Scan_UTF8 (Item, -1, Length, Position, Encoding, Last, Bytes (1 .. Size));
      if Encoding = UTF8_Valid
        and then Native.Byte_At (Item, Position) /= Character'Val (0)
      then
         Index := Length;
         Status := Matched;
      elsif Encoding = UTF8_Limit_Exceeded then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_UTF8_Character;

   procedure Scan_UTF8
     (Item : System.Address; Stop_After : Integer;
      Length, Offset : out Byte_Count; Status : out UTF8_Status; Last : Byte_Count;
      Pattern : String := "")
   is
      Position : Natural := 0;
      Count : Natural := 0;
      Bytes : String (1 .. 4) := (others => Character'Val (0));
      B : Natural;
      Width : Positive range 1 .. 4;
      Kind : Text_Error_Kind;
      Error_Position : Natural;
   begin
      Length := 0;
      Offset := 0;
      Status := UTF8_Invalid;
      if Item = System.Null_Address then
         return;
      end if;
      while Position <= Last loop
         pragma Loop_Invariant (Position <= Last + 4);
         pragma Loop_Invariant (Count <= Position);
         pragma Loop_Variant (Increases => Position);
         if Count = Stop_After then
            Length := Count;
            Offset := Position;
            Status := UTF8_Valid;
            return;
         end if;
         Bytes (1) := Native.Byte_At (Item, Position);
         B := Character'Pos (Bytes (1));
         if B = 0 then
            Length := Count;
            Offset := Position;
            Status := UTF8_Valid;
            return;
         elsif B < 128 then
            Width := 1;
         elsif B in 16#C2# .. 16#DF# then
            Width := 2;
         elsif B in 16#E0# .. 16#EF# then
            Width := 3;
         elsif B in 16#F0# .. 16#F4# then
            Width := 4;
         else
            return;
         end if;
         for Continuation in 1 .. Width - 1 loop
            if Continuation > Last - Position then
               Status := UTF8_Limit_Exceeded;
               return;
            end if;
            pragma Assert (Position + Continuation <= Last);
            Bytes (Continuation + 1) := Native.Byte_At (Item, Position + Continuation);
            if Character'Pos (Bytes (Continuation + 1)) not in 16#80# .. 16#BF# then
               return;
            end if;
         end loop;
         if Width > 1 then
            Validate_UTF8 (Bytes (1 .. Width), Kind, Error_Position, XML_Only => False);
            if Kind /= No_Text_Error then
               return;
            end if;
         end if;
         if Pattern'Length > 0 and then Bytes (1 .. Width) = Pattern then
            Length := Count;
            Offset := Position;
            Status := UTF8_Valid;
            return;
         end if;
         Position := Position + Width;
         Count := Count + 1;
      end loop;
      Status := UTF8_Limit_Exceeded;
   end Scan_UTF8;

   procedure Get_UTF8_Char
     (Item : System.Address; Available : Integer;
      Code : out Integer; Width : out Natural)
   is
      B : Natural;
      C : Natural;
      Minimum : Natural;
      Needed : Positive range 2 .. 4;
   begin
      Code := -1;
      Width := 0;
      if Item = System.Null_Address or else Available < 1 then
         return;
      end if;
      B := Character'Pos (Native.Byte_At (Item, 0));
      if B < 128 then
         Code := B;
         Width := 1;
         return;
      elsif B in 16#C2# .. 16#DF# then
         Needed := 2;
         C := B - 16#C0#;
         Minimum := 16#80#;
      elsif B in 16#E0# .. 16#EF# then
         Needed := 3;
         C := B - 16#E0#;
         Minimum := 16#800#;
      elsif B in 16#F0# .. 16#F4# then
         Needed := 4;
         C := B - 16#F0#;
         Minimum := 16#10000#;
      else
         return;
      end if;
      if Available < Needed then
         return;
      end if;
      for J in 1 .. Needed - 1 loop
         pragma Loop_Invariant (C <= 16#10FFFF#);
         B := Character'Pos (Native.Byte_At (Item, J));
         if B not in 16#80# .. 16#BF#
           or else C > (16#10FFFF# - (B - 16#80#)) / 64
         then
            return;
         end if;
         C := C * 64 + B - 16#80#;
      end loop;
      if C < Minimum or else C in 16#D800# .. 16#DFFF# then
         return;
      end if;
      Code := C;
      Width := Needed;
   end Get_UTF8_Char;

   function Valid_Name
     (Source : System.Address; Source_Length : Natural;
      Allow_Colon : Boolean) return Boolean
   is
      I : Natural := 0;
      Width : Natural;
      Code : Integer;
      pragma Unreferenced (Code);
      Initial : Boolean := True;
      Window : String (1 .. 4) := (others => Character'Val (0));
   begin
      if Source_Length = 0 or else Source = System.Null_Address then
         return False;
      end if;
      while I < Source_Length loop
         pragma Loop_Variant (Increases => I);
         Get_UTF8_Char
           (Native.Offset (Source, Native.Byte_Count (I)),
            Natural'Min (4, Source_Length - I), Code, Width);
         if Width = 0 then
            return False;
         end if;
         for J in 0 .. Width - 1 loop
            Window (J + 1) := Native.Byte_At (Source, I + J);
         end loop;
         if Window (1) = ':' then
            if not Allow_Colon then
               return False;
            end if;
         elsif XML3_Text.Name_Width (Window (1 .. Width), 1, Initial) /= Width then
            return False;
         end if;
         Initial := False;
         I := I + Width;
      end loop;
      return True;
   end Valid_Name;

   procedure Read_Length
     (Item : System.Address; Last : Byte_Count;
      Length : out Byte_Count; Found : out Boolean)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Item /= System.Null_Address,
       Post => Length <= Last and then (if not Found then Length = 0)
   is
   begin
      Length := 0;
      Found := False;
      for Index in 0 .. Last loop
         if Native.Byte_At (Item, Index) = Character'Val (0) then
            Length := Index;
            Found := True;
            return;
         end if;
      end loop;
   end Read_Length;

   procedure Measure
     (Item : System.Address; Length : out Byte_Count; Success : out Boolean;
      Last : Byte_Count := Max_Bytes)
   is
   begin
      if Item = System.Null_Address then
         Length := 0;
         Success := True;
      else
         Read_Length (Item, Last, Length, Success);
      end if;
   end Measure;

   procedure Build_Append
     (Item, Addition : System.Address; Length : Integer; Terminated : Boolean;
      Result : out System.Address; Status : out Append_Status; Limit : Byte_Count)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Unchanged then Result = Item
                elsif Status = Appended then Result /= System.Null_Address
                else Result = System.Null_Address)
   is
      Prefix_Length : Byte_Count := 0;
      Added_Length : Byte_Count;
      Found : Boolean;
      Current : Character;
   begin
      Result := System.Null_Address;
      Status := Unchanged;
      if Addition = System.Null_Address or else (not Terminated and then Length = 0) then
         Result := Item;
         return;
      elsif not Terminated and then Length < 0 then
         Status := Invalid_Length;
         return;
      end if;
      Status := Append_Limit_Exceeded;
      if Terminated then
         Read_Length (Addition, Limit, Added_Length, Found);
         if not Found then
            return;
         end if;
      elsif Length > Limit then
         return;
      else
         Added_Length := Length;
      end if;
      if Added_Length = 0 and then Item /= System.Null_Address then
         Result := Item;
         Status := Unchanged;
         return;
      end if;
      if Item /= System.Null_Address then
         Read_Length (Item, Limit - Added_Length, Prefix_Length, Found);
         if not Found then
            return;
         end if;
      end if;
      Status := Append_No_Memory;
      Native.Allocate (Native.Byte_Count (Prefix_Length + Added_Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      if Item /= System.Null_Address then
         for Index in 0 .. Prefix_Length - 1 loop
            Current := Native.Byte_At (Item, Index);
            Native.Write_Byte (Result, Index, Current);
         end loop;
      end if;
      for Index in 0 .. Added_Length - 1 loop
         Current := Native.Byte_At (Addition, Index);
         Native.Write_Byte (Result, Prefix_Length + Index, Current);
      end loop;
      Native.Write_Byte (Result, Prefix_Length + Added_Length, Character'Val (0));
      Status := Appended;
   end Build_Append;

   procedure Append
     (Item, Addition : System.Address; Length : Integer; Terminated : Boolean;
      Result : out System.Address; Status : out Append_Status;
      Limit : Byte_Count := Max_Bytes)
   is
   begin
      Build_Append (Item, Addition, Length, Terminated, Result, Status, Limit);
      if Status /= Unchanged and then Item /= System.Null_Address then
         Native.Free (Item);
      end if;
   end Append;

   procedure Slice
     (Item : System.Address; Start, Length : Integer;
      Result : out System.Address; Status : out Slice_Status)
   is
   begin
      Result := System.Null_Address;
      Status := No_Slice;
      if Item = System.Null_Address or else Start < 0 or else Length < 0 then
         return;
      elsif Start >= Max_Bytes or else Length > Max_Bytes - Start then
         Status := Slice_Limit_Exceeded;
         return;
      end if;
      for Index in 0 .. Start loop
         if Native.Byte_At (Item, Index) = Character'Val (0) then
            return;
         end if;
      end loop;
      Copy_Span (Item, Start, Length, Result, Status);
   end Slice;

   procedure Find_Byte
     (Item : System.Address; Value : Character;
      Position : out Byte_Count; Status : out Search_Status)
   is
      Current : Character;
   begin
      Position := 0;
      Status := No_Match;
      if Item = System.Null_Address or else Value = Character'Val (0) then
         return;
      end if;
      for Index in 0 .. Max_Bytes - 1 loop
         Current := Native.Byte_At (Item, Index);
         if Current = Character'Val (0) then
            return;
         elsif Current = Value then
            Position := Index;
            Status := Matched;
            return;
         end if;
      end loop;
      if Native.Byte_At (Item, Max_Bytes) /= Character'Val (0) then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_Byte;

   --  The pinned reference also maps '[' to '{'.
   function Case_Map (Item : Character) return Character is
     (if Item in 'A' .. 'Z' or else Item = '['
      then Character'Val (Character'Pos (Item) + 32) else Item);

   procedure Find_Substring
     (Item, Pattern : System.Address; Ignore_Case : Boolean;
      Position : out Byte_Count; Status : out Search_Status)
   is
      First, Current, Expected : Character;
   begin
      Position := 0;
      Status := No_Match;
      if Item = System.Null_Address or else Pattern = System.Null_Address then
         return;
      end if;
      First := Native.Byte_At (Pattern, 0);
      if First = Character'Val (0) then
         Status := Matched;
         return;
      elsif Ignore_Case then
         First := Case_Map (First);
      end if;
      for Start in 0 .. Max_Bytes - 1 loop
         Current := Native.Byte_At (Item, Start);
         if Current = Character'Val (0) then
            return;
         elsif Ignore_Case then
            Current := Case_Map (Current);
         end if;
         if Current = First then
            for Index in 1 .. Max_Bytes - Start loop
               Expected := Native.Byte_At (Pattern, Index);
               if Expected = Character'Val (0) then
                  Position := Start;
                  Status := Matched;
                  return;
               end if;
               Current := Native.Byte_At (Item, Start + Index);
               if Current = Character'Val (0) then
                  return;
               elsif Start + Index = Max_Bytes then
                  Status := Search_Limit_Exceeded;
                  return;
               end if;
               if Ignore_Case then
                  Current := Case_Map (Current);
                  Expected := Case_Map (Expected);
               end if;
               exit when Current /= Expected;
            end loop;
         end if;
      end loop;
      if Native.Byte_At (Item, Max_Bytes) /= Character'Val (0) then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_Substring;

   procedure Compare_Scan
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean;
      Result : out Integer; Complete : out Boolean)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Result in -255 .. 255
   is
      L, R : Character;
   begin
      Result := 0;
      Complete := True;
      if Length <= 0 or else Left = Right then
         return;
      elsif Left = System.Null_Address then
         Result := -1;
         return;
      elsif Right = System.Null_Address then
         Result := 1;
         return;
      end if;
      for Index in 0 .. Length - 1 loop
         L := Native.Byte_At (Left, Index);
         R := Native.Byte_At (Right, Index);
         if Ignore_Case then
            L := Case_Map (L);
            R := Case_Map (R);
         end if;
         if L /= R then
            Result := Character'Pos (L) - Character'Pos (R);
            return;
         elsif L = Character'Val (0) then
            return;
         end if;
      end loop;
      Complete := False;
   end Compare_Scan;

   function Compare_Bounded
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean)
      return Integer
   is
      Result : Integer;
      Complete : Boolean;
   begin
      Compare_Scan (Left, Right, Length, Ignore_Case, Result, Complete);
      if Complete then
         return Result;
      else
         return 0;
      end if;
   end Compare_Bounded;

   procedure Compare_Terminated
     (Left, Right : System.Address; Ignore_Case : Boolean;
      Result : out Integer; Limit_Exceeded : out Boolean;
      Last : Byte_Count := Max_Bytes)
   is
      Complete : Boolean;
   begin
      Compare_Scan (Left, Right, Last + 1, Ignore_Case, Result, Complete);
      Limit_Exceeded := not Complete;
      if Limit_Exceeded then
         Result := -1;
      end if;
   end Compare_Terminated;

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
