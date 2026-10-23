package body XML3_Parser with SPARK_Mode is
   use type XML3_Text.Text_Error_Kind;
   use type XML3_Encoding.Encoding_Kind;

   function Space (C : Character) return Boolean is
     (C = ' ' or C = Character'Val (9) or C = Character'Val (10)
      or C = Character'Val (13));

   function Layout (Nodes : Node_Array; Count : Node_Id; Size : Offset)
                    return Boolean is
     (Nodes'First = 1
      and then Count <= Nodes'Last
      and then (for all K in 1 .. Count =>
       Nodes (K).Parent < K
       and then Nodes (K).Name_Last <= Size
       and then Nodes (K).Value_Last <= Size
       and then Nodes (K).Name_First <= Nodes (K).Name_Last + 1
       and then Nodes (K).Value_First <= Nodes (K).Value_Last + 1))
     with Ghost;

   procedure Parse
     (Input  : String;
      Scratch : in out String;
      Nodes  : out Node_Array;
      Count  : out Node_Id;
      Root   : out Node_Id;
      Status : out Parse_Status;
      Huge   : Boolean;
      Diagnostic : out Diagnostic_Info;
      Encoding : XML3_Encoding.Encoding_Info := (others => <>))
   is
      P : Position := 1;
      Error_Position : Positive range 1 .. Input'Length + 1 := 1;
      Encoding_Warning : Natural range 0 .. Input'Length + 1 := 0;
      Depth : Natural range 0 .. Max_Depth := 0;
      Stack : array (Positive range 1 .. Max_Depth) of Node_Id := (others => 0);
      Body_Pending : Boolean := True;
      NF, VF : Position;
      NL, VL : Offset;
      Value_Length : XML3_Text.Byte_Count;
      Value_Valid : Boolean;
      Component_First : Position;
      Name_Limit : constant Natural :=
        (if Huge then Huge_Max_Name_Length else Normal_Max_Name_Length);
      Value_Limit : constant Natural :=
        (if Huge then Huge_Max_Value_Length else Normal_Max_Value_Length);
      Saved : Position;
      Parent : Node_Id;
      Element : Node_Id;
      Quote : Character;
      Closed : Boolean;
      Duplicate : Boolean;
      Seen_Encoding, Seen_Standalone : Boolean;
      Text_Error : XML3_Text.Text_Error_Kind;
      Text_Error_Position : Natural;

      function Line_At (Location : Position) return Natural
        with Pre => Input'First = 1
          and then Input'Length <= XML3_Text.Max_Bytes
          and then Location <= Input'Length + 1,
          Post => Line_At'Result in 1 .. Location
      is
         I : Position := 1;
         Line : Natural := 1;
      begin
         while I < Location and then I <= Input'Last loop
            pragma Loop_Invariant (I in 1 .. Location);
            pragma Loop_Invariant (Line in 1 .. I);
            pragma Loop_Variant (Increases => I);
            if Input (I) = Character'Val (10) then
               Line := Line + 1;
            end if;
            I := I + 1;
         end loop;
         return Line;
      end Line_At;

      procedure Set_Diagnostic
        (Code : Natural; Location : Position; Domain : Natural := 1;
         Level : Natural := 3; First : Integer := 0; Second : Integer := 0)
        with Pre => Input'First = 1
          and then Input'Length <= XML3_Text.Max_Bytes
          and then Location <= Input'Length + 1,
          Post => Diagnostic.Byte_Position = Location
      is
      begin
         Error_Position := Location;
         Diagnostic :=
           (Domain => Domain, Code => Code, Level => Level,
            Byte_Position => Location, Int1 => First, Int2 => Second);
      end Set_Diagnostic;

      procedure Set_Reference_Diagnostic
        (First : Position; Last : Offset)
        with Pre => Input'First = 1
          and then Input'Length <= XML3_Text.Max_Bytes
          and then Last <= Input'Length
          and then First <= Last + 1,
          Post => Diagnostic.Byte_Position in 1 .. Input'Length + 1
      is
         I : Position := First;
         Name_Start : Position;
         Name_End : Position;
         Width : Natural;
         Base : Natural;
         Code : Natural;
         Digit : Natural;
         Bad : Boolean;
      begin
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
         while I <= Last loop
            pragma Loop_Invariant (I in First .. Last + 1);
            pragma Loop_Variant (Increases => I);
            if Input (I) /= '&' then
               I := I + 1;
            else
               Name_Start := I + 1;
               if Name_Start > Input'Length then
                  Set_Diagnostic (68, Name_Start);
                  return;
               elsif Input (Name_Start) = '#' then
                  Name_Start := Name_Start + 1;
                  Base := 10;
                  if Name_Start <= Last and then Input (Name_Start) = 'x' then
                     Base := 16;
                     Name_Start := Name_Start + 1;
                  end if;
                  Name_End := I + 1;
                  while Name_End <= Last and then Input (Name_End) /= ';' loop
                     pragma Loop_Invariant (Name_End in I + 1 .. Last + 1);
                     pragma Loop_Variant (Increases => Name_End);
                     Name_End := Name_End + 1;
                  end loop;
                  Code := 0;
                  Bad := Name_Start >= Name_End;
                  if not Bad then
                     for K in Name_Start .. Name_End - 1 loop
                        pragma Loop_Invariant (Code <= 16#10FFFF#);
                        if Input (K) in '0' .. '9' then
                           Digit := Character'Pos (Input (K))
                             - Character'Pos ('0');
                        elsif Base = 16 and then Input (K) in 'a' .. 'f' then
                           Digit := Character'Pos (Input (K))
                             - Character'Pos ('a') + 10;
                        elsif Base = 16 and then Input (K) in 'A' .. 'F' then
                           Digit := Character'Pos (Input (K))
                             - Character'Pos ('A') + 10;
                        else
                           Set_Diagnostic (9, K);
                           return;
                        end if;
                        if Code > (16#10FFFF# - Digit) / Base then
                           Set_Diagnostic (9, K);
                           return;
                        end if;
                        Code := Code * Base + Digit;
                     end loop;
                  end if;
                  if not Bad and then Name_End <= Last
                    and then XML3_Text.XML_Char (Code)
                  then
                     I := Name_End + 1;
                  else
                     Set_Diagnostic
                       (9, (if Name_End <= Last then Name_End + 1 else Last + 1),
                        First => Code);
                     return;
                  end if;
               elsif XML3_Text.Name_Width (Input, Name_Start, True) = 0 then
                  Set_Diagnostic (68, Name_Start);
                  return;
               else
                  Name_End := Name_Start;
                  Width := XML3_Text.Name_Width (Input, Name_End, True);
                  Name_End := Name_End + Width;
                  while Name_End <= Last and then Input (Name_End) /= ';' loop
                     pragma Loop_Invariant (Name_End in Name_Start + 1 .. Last + 1);
                     pragma Loop_Variant (Increases => Name_End);
                     Width := XML3_Text.Name_Width (Input, Name_End, False);
                     if Width = 0 then
                        Set_Diagnostic (23, Name_End);
                        return;
                     end if;
                     Name_End := Name_End + Width;
                  end loop;
                  if Name_End > Last then
                     Set_Diagnostic (23, Last + 1);
                     return;
                  elsif Input (Name_Start .. Name_End - 1) /= "lt"
                    and then Input (Name_Start .. Name_End - 1) /= "gt"
                    and then Input (Name_Start .. Name_End - 1) /= "amp"
                    and then Input (Name_Start .. Name_End - 1) /= "apos"
                    and then Input (Name_Start .. Name_End - 1) /= "quot"
                  then
                     Set_Diagnostic (26, Name_End + 1);
                     return;
                  else
                     I := Name_End + 1;
                  end if;
               end if;
            end if;
         end loop;
      end Set_Reference_Diagnostic;

      function Peek return Character is
        (if P <= Input'Last then Input (P) else Character'Val (0))
        with Pre => Input'First = 1 and Input'Length <= XML3_Text.Max_Bytes;

      function At_Text (Text : String) return Boolean is
        (Text'Length <= Input'Length and then
         P <= Input'Length - Text'Length + 1 and then
         Input (P .. P + Text'Length - 1) = Text)
        with Pre => Input'First = 1 and Input'Length <= XML3_Text.Max_Bytes;

      procedure Skip_Space
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then P <= Input'Length + 1,
          Post => P in P'Old .. Input'Length + 1
            and (if P'Old <= Input'Last and then Space (Input (P'Old)) then P > P'Old)
      is
      begin
         while P <= Input'Last and then Space (Input (P)) loop
            pragma Loop_Invariant (P in P'Loop_Entry .. Input'Length + 1);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
      end Skip_Space;

      procedure Read_Name (First : out Position; Last : out Offset;
                           Qualified : Boolean := False)
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then P <= Input'Length + 1,
          Post => P in P'Old .. Input'Length + 1
            and First = P'Old and Last = P - 1
            and Diagnostic.Byte_Position in 1 .. Input'Length + 1
      is
         Width : Natural;
         Component_Size : Natural;
      begin
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
         First := P;
         Component_First := P;
         while P <= Input'Last loop
            pragma Loop_Invariant (P in First .. Input'Length + 1);
            pragma Loop_Invariant (Component_First in First .. P);
            pragma Loop_Invariant
              (Diagnostic.Byte_Position in 1 .. Input'Length + 1);
            pragma Loop_Variant (Increases => P);
            Width := XML3_Text.Name_Width (Input, P, P = First);
            if Width /= 0 then
               P := P + Width;
            elsif Qualified and then P > First and then Input (P) = ':' then
               Component_Size := P - Component_First;
               if Component_Size > Name_Limit then
                  Status := Limit_Exceeded;
                  Set_Diagnostic (110, P);
               end if;
               Component_First := P + 1;
               P := P + 1;
            else
               exit;
            end if;
         end loop;
         Last := P - 1;
         Component_Size := P - Component_First;
         if Component_Size > Name_Limit then
            Status := Limit_Exceeded;
            Set_Diagnostic (110, P);
         end if;
      end Read_Name;

      procedure Read_Quoted (First : out Position; Last : out Offset)
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then P <= Input'Length + 1,
          Post => P in P'Old .. Input'Length + 1
            and Last <= Input'Length and First <= Last + 1
            and Diagnostic.Byte_Position in 1 .. Input'Length + 1
      is
         Q : constant Character := Peek;
      begin
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
         First := P;
         Last := P - 1;
         if Q /= '"' and Q /= Character'Val (39) then
            Status := Malformed;
            Set_Diagnostic (41, P);
            return;
         end if;
         P := P + 1;
         First := P;
         while P <= Input'Last and then Input (P) /= Q loop
            pragma Loop_Invariant (P in First .. Input'Length + 1);
            pragma Loop_Variant (Increases => P);
            if Input (P) = '<' then
               Status := Malformed;
               Set_Diagnostic (38, P);
               Last := P - 1;
               return;
            end if;
            P := P + 1;
         end loop;
         Last := P - 1;
         if P > Input'Last then
            Status := Malformed;
            Set_Diagnostic (34, P);
         else
            P := P + 1;
         end if;
      end Read_Quoted;

      procedure Validate_Value
        (First : Position; Last : Offset; Attr, References : Boolean;
         Owner : Node_Id; Valid : out Boolean)
        with Pre => Input'First = 1
          and then Input'Length <= XML3_Text.Max_Bytes
          and then First <= Last + 1
          and then Last <= Input'Length
          and then Owner <= Count
          and then Layout (Nodes, Count, Input'Length)
          and then Scratch'First = 1
          and then Scratch'Length = Input'Length,
          Post => Diagnostic.Byte_Position in 1 .. Input'Length + 1
      is
         Character_Error : XML3_Text.Text_Error_Kind;
         Character_Position : Natural;
      begin
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
         Value_Length := 0;
         XML3_Text.Validate_UTF8
           (Input (First .. Last), Character_Error, Character_Position);
         if Character_Error = XML3_Text.Invalid_XML_Character then
            Status := Malformed;
            declare
               Character_Value : Integer := 0;
            begin
               if Character_Position in Input'Range
                 and then Character'Pos (Input (Character_Position)) < 128
               then
                  Character_Value :=
                    Character'Pos (Input (Character_Position));
               end if;
            Set_Diagnostic
              (9, Position (Character_Position),
               First => Character_Value);
            end;
            Valid := False;
            return;
         end if;
         XML3_Text.Decode
           (Input (First .. Last), Attr, References,
            Scratch (1 .. Last - First + 1), Value_Length, Valid);
         if Valid and then Value_Length > Value_Limit then
            Status := Limit_Exceeded;
            Set_Diagnostic (114, First);
         elsif not Valid and then References then
            Set_Reference_Diagnostic (First, Last);
         end if;
      end Validate_Value;

      procedure Add
        (Kind : Node_Kind; Owner : Node_Id;
         Name_First : Position; Name_Last : Offset;
         Value_First : Position; Value_Last : Offset)
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then Layout (Nodes, Count, Input'Length)
          and then Scratch'First = 1
          and then Scratch'Length = Input'Length
          and then Owner <= Count
          and then Name_First <= Name_Last + 1 and then Name_Last <= Input'Length
          and then Value_First <= Value_Last + 1 and then Value_Last <= Input'Length,
          Post => Layout (Nodes, Count, Input'Length)
            and then Count >= Count'Old
            and then (if Status = Success then Count = Count'Old + 1)
            and then Count'Old <= Nodes'Last
            and then (for all K in 1 .. Count'Old => Nodes (K) = Nodes'Old (K))
            and then Diagnostic.Byte_Position in 1 .. Input'Length + 1
      is
      begin
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
         Validate_Value
           (Value_First, Value_Last,
            Kind = Attribute_Node, Kind = Attribute_Node or Kind = Text_Node,
            Owner, Value_Valid);
         if Status /= Success then
            return;
         elsif not Value_Valid then
            Status := Malformed;
            if Diagnostic.Code = 0 then
               Set_Diagnostic (9, Value_First);
            end if;
            return;
         end if;
         if Count = Max_Nodes then
            Status := Limit_Exceeded;
            Set_Diagnostic (114, Value_First);
            return;
         elsif Count >= Nodes'Last then
            Status := Arena_Exhausted;
            return;
         end if;
         pragma Assert (Count < Nodes'Last);
         Count := Count + 1;
         Nodes (Count) := (Kind, Owner, Name_First, Name_Last, Value_First, Value_Last);
      end Add;

      procedure Pseudo_Attribute
        (Name_First : out Position; Name_Last : out Offset;
         Value_First : out Position; Value_Last : out Offset)
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then P <= Input'Length + 1,
          Post => P in P'Old .. Input'Length + 1
            and (if Status = Success then P > P'Old)
            and Name_First <= Name_Last + 1 and Name_Last <= Input'Length
            and Value_First <= Value_Last + 1 and Value_Last <= Input'Length
            and Diagnostic.Byte_Position in 1 .. Input'Length + 1
      is
      begin
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
         Name_First := P;
         Name_Last := P - 1;
         Value_First := P;
         Value_Last := P - 1;
         Read_Name (Name_First, Name_Last);
         if Status /= Success then
            return;
         end if;
         Value_First := P;
         Value_Last := P - 1;
         Skip_Space;
         if Peek /= '=' then
            Status := Malformed;
            Set_Diagnostic (41, P);
            return;
         end if;
         P := P + 1;
         Skip_Space;
         Read_Quoted (Value_First, Value_Last);
      end Pseudo_Attribute;
   begin
      Diagnostic := (Domain => 1, Code => 0, Level => 0,
                     Byte_Position => 1, Int1 => 0, Int2 => 0);
      Parse_Body : loop
         pragma Loop_Invariant
           (Diagnostic.Byte_Position in 1 .. Input'Length + 1);
         pragma Loop_Variant (Decreases => Body_Pending);
      Nodes := (others => (others => <>));
      Count := 0;
      Root := 0;
      Status := Success;
      Diagnostic := (Domain => 1, Code => 0, Level => 0,
                     Byte_Position => 1, Int1 => 0, Int2 => 0);
      Scratch := (others => Character'Val (0));
      XML3_Text.Validate_UTF8
        (Input, Text_Error, Text_Error_Position);
      if Text_Error = XML3_Text.Invalid_UTF8 then
         Status := Malformed;
         Set_Diagnostic
           (81, Position (Text_Error_Position), Domain => 8);
         exit Parse_Body;
      end if;
      if At_Text ("<?xml") then
         Saved := P;
         P := P + 5;
         if Space (Peek) then
            Skip_Space;
            Pseudo_Attribute (NF, NL, VF, VL);
            if Status /= Success then
               exit Parse_Body;
            end if;
            if Input (NF .. NL) /= "version" or Input (VF .. VL) /= "1.0" then
               Status := Unsupported;
               Set_Diagnostic (32, P);
               exit Parse_Body;
            end if;
            Seen_Encoding := False;
            Seen_Standalone := False;
            while not At_Text ("?>") loop
               pragma Loop_Invariant (P <= Input'Length + 1);
               pragma Loop_Invariant
                 (Diagnostic.Byte_Position in 1 .. Input'Length + 1);
               pragma Loop_Variant (Increases => P);
               if not Space (Peek) then
                  Status := Malformed;
                  Set_Diagnostic (57, P);
                  exit Parse_Body;
               end if;
               Skip_Space;
               exit when At_Text ("?>");
               Pseudo_Attribute (NF, NL, VF, VL);
               if Status /= Success then
                  exit Parse_Body;
               end if;
               if Input (NF .. NL) = "encoding" and not Seen_Encoding and not Seen_Standalone then
                  if not XML3_Encoding.Valid_Name (Input (VF .. VL)) then
                     Status := Malformed;
                     Set_Diagnostic (79, VF);
                     exit Parse_Body;
                  elsif Encoding.Explicit then
                     null;
                  elsif Encoding.Auto_Detected then
                     if not XML3_Encoding.Declaration_Matches
                       (Input (VF .. VL), Encoding.Kind)
                     then
                        Encoding_Warning := P;
                     end if;
                  elsif XML3_Encoding.Classify (Input (VF .. VL)) =
                    XML3_Encoding.Unsupported
                  then
                     Status := Unsupported;
                     Set_Diagnostic (32, P);
                     exit Parse_Body;
                  elsif not XML3_Encoding.Declaration_Matches
                    (Input (VF .. VL), Encoding.Kind)
                  then
                     Status := Malformed;
                     Set_Diagnostic (81, P);
                     exit Parse_Body;
                  end if;
                  Seen_Encoding := True;
               elsif Input (NF .. NL) = "standalone" and not Seen_Standalone then
                  if Input (VF .. VL) /= "yes" and Input (VF .. VL) /= "no" then
                     Status := Malformed;
                     Set_Diagnostic (78, P);
                     exit Parse_Body;
                  end if;
                  Seen_Standalone := True;
               else
                  Status := Malformed;
                  Set_Diagnostic (68, P);
                  exit Parse_Body;
               end if;
            end loop;
            P := P + 2;
      else
         P := Saved;
      end if;
   end if;

      Diagnostic := (Domain => 1, Code => 0, Level => 0,
                     Byte_Position => 1, Int1 => 0, Int2 => 0);
      while P <= Input'Last loop
            pragma Loop_Invariant (P <= Input'Length + 1);
            pragma Loop_Invariant
              (Diagnostic.Byte_Position in 1 .. Input'Length + 1);
            pragma Loop_Invariant (Layout (Nodes, Count, Input'Length));
            pragma Loop_Invariant (Root <= Count);
            pragma Loop_Invariant (for all D in 1 .. Depth => Stack (D) in 1 .. Count);
            pragma Loop_Invariant
              (if Depth > 0 then Stack (Depth) in 1 .. Count);
         pragma Loop_Variant (Increases => P);
         Parent := (if Depth = 0 then 0 else Stack (Depth));
         if Peek /= '<' then
            VF := P;
            while P <= Input'Last and then Input (P) /= '<' loop
               pragma Loop_Invariant (P in VF .. Input'Length + 1);
               pragma Loop_Invariant (VF <= Input'Last and then Input (VF) /= '<');
               pragma Loop_Variant (Increases => P);
               if At_Text ("]]>") or else (Depth = 0 and not Space (Input (P))) then
                  Status := Malformed;
                  Set_Diagnostic
                    ((if At_Text ("]]>") then 62
                      elsif Root /= 0 then 5 else 4), P);
                  exit Parse_Body;
               end if;
               P := P + 1;
            end loop;
            VL := P - 1;
            if Depth /= 0 then
               Add (Text_Node, Parent, 1, 0, VF, VL);
            end if;
         elsif At_Text ("<!--") then
            P := P + 4;
            VF := P;
            while P <= Input'Last and then not At_Text ("--") loop
               pragma Loop_Invariant (P in VF .. Input'Length + 1);
               pragma Loop_Variant (Increases => P);
               P := P + 1;
            end loop;
            VL := P - 1;
            if At_Text ("--") and then not At_Text ("-->") then
               Status := Malformed;
               Set_Diagnostic (80, P);
               exit Parse_Body;
            end if;
            if not At_Text ("-->") then
               Status := Malformed;
               Set_Diagnostic (45, P);
               exit Parse_Body;
            end if;
            P := P + 3;
            Add (Comment_Node, Parent, 1, 0, VF, VL);
         elsif At_Text ("<![CDATA[") then
            if Depth = 0 then
               Status := Malformed;
               Set_Diagnostic (62, P);
               exit Parse_Body;
            end if;
            P := P + 9;
            VF := P;
            while P <= Input'Last and then not At_Text ("]]>") loop
               pragma Loop_Invariant (P in VF .. Input'Length + 1);
               pragma Loop_Variant (Increases => P);
               P := P + 1;
            end loop;
            VL := P - 1;
            if not At_Text ("]]>") then
               Status := Malformed;
               Set_Diagnostic (63, P);
               exit Parse_Body;
            end if;
            P := P + 3;
            Add (CData_Node, Parent, 1, 0, VF, VL);
         elsif At_Text ("<?") then
            P := P + 2;
            Read_Name (NF, NL);
            if Status /= Success then
               exit Parse_Body;
            end if;
            if NL < NF then
               Status := Malformed;
               Set_Diagnostic (68, P);
               exit Parse_Body;
            end if;
            if NL - NF = 2 and then
              (Input (NF) = 'x' or Input (NF) = 'X') and then
              (Input (NF + 1) = 'm' or Input (NF + 1) = 'M') and then
              (Input (NL) = 'l' or Input (NL) = 'L')
            then
               Status := Malformed;
               Set_Diagnostic (64, P);
               exit Parse_Body;
            end if;
            if not At_Text ("?>") and not Space (Peek) then
               Status := Malformed;
               Set_Diagnostic (47, P);
               exit Parse_Body;
            end if;
            Skip_Space;
            VF := P;
            while P <= Input'Last and then not At_Text ("?>") loop
               pragma Loop_Invariant (P in VF .. Input'Length + 1);
               pragma Loop_Variant (Increases => P);
               P := P + 1;
            end loop;
            VL := P - 1;
            if not At_Text ("?>") then
               Status := Malformed;
               Set_Diagnostic (47, P);
               exit Parse_Body;
            end if;
            P := P + 2;
            Add (PI_Node, Parent, NF, NL, VF, VL);
         elsif At_Text ("</") then
            if Depth = 0 then
               Status := Malformed;
               Set_Diagnostic (77, P);
               exit Parse_Body;
            end if;
            P := P + 2;
            Read_Name (NF, NL, Qualified => True);
            if Status /= Success then
               exit Parse_Body;
            end if;
            if NF > NL or else
              Input (NF .. NL) /= Input (Nodes (Parent).Name_First .. Nodes (Parent).Name_Last)
            then
               if Peek = '>' then
                  P := P + 1;
               end if;
               Status := Malformed;
               Set_Diagnostic
                 (76, P, First => Line_At (Nodes (Parent).Name_First));
               exit Parse_Body;
            end if;
            Skip_Space;
            if Peek /= '>' then
               Status := Malformed;
               Set_Diagnostic
                 (73, P, First => Line_At (Nodes (Parent).Name_First));
               exit Parse_Body;
            end if;
            P := P + 1;
            Depth := Depth - 1;
         elsif At_Text ("<!") then
            Status := Unsupported;
            Set_Diagnostic (115, P);
            exit Parse_Body;
         else
            P := P + 1;
            Read_Name (NF, NL, Qualified => True);
            if Status /= Success then
               exit Parse_Body;
            end if;
            if NF > NL or else (Depth = 0 and Root /= 0) then
               Status := Malformed;
               Set_Diagnostic
                 ((if Root /= 0 then 5 else 68),
                 (if Root /= 0 then NF - 1 else P));
               exit Parse_Body;
            end if;
            if Depth = (if Huge then Huge_Max_Depth else Normal_Max_Depth) then
               Status := Limit_Exceeded;
               Set_Diagnostic (114, P);
               exit Parse_Body;
            end if;
            Add (Element_Node, Parent, NF, NL, 1, 0);
            if Status /= Success then
               exit Parse_Body;
            end if;
            Element := Count;
            if Root = 0 then
               Root := Element;
            end if;
            Closed := False;
            loop
               pragma Loop_Invariant (P <= Input'Length + 1);
               pragma Loop_Invariant (Layout (Nodes, Count, Input'Length));
               pragma Loop_Invariant (P >= P'Loop_Entry);
               pragma Loop_Invariant (Element in 1 .. Count);
               pragma Loop_Invariant (Root in 1 .. Count);
               pragma Loop_Invariant (for all D in 1 .. Depth => Stack (D) in 1 .. Count);
               pragma Loop_Variant (Increases => P);
               Saved := P;
               Skip_Space;
               if At_Text ("/>") then
                  P := P + 2;
                  Closed := True;
                  exit;
               elsif Peek = '>' then
                  P := P + 1;
                  exit;
               elsif P = Saved then
                  Status := Malformed;
                  Set_Diagnostic
                    (73, P, First => Line_At (Nodes (Element).Name_First));
                  exit Parse_Body;
               end if;
               Read_Name (NF, NL, Qualified => True);
               if Status /= Success then
                  exit Parse_Body;
               end if;
               if NF > NL then
                  Status := Malformed;
                  Set_Diagnostic (39, P);
                  exit Parse_Body;
               end if;
               Duplicate := False;
               for K in Element + 1 .. Count loop
                  if Nodes (K).Kind = Attribute_Node and then
                    Input (NF .. NL) = Input (Nodes (K).Name_First .. Nodes (K).Name_Last)
                  then
                     Duplicate := True;
                  end if;
               end loop;
               Skip_Space;
               if Peek /= '=' then
                  Status := Malformed;
                  Set_Diagnostic (41, P);
                  exit Parse_Body;
               end if;
               P := P + 1;
               Skip_Space;
               Quote := Peek;
               if Quote /= '"' and Quote /= Character'Val (39) then
                  Status := Malformed;
                  Set_Diagnostic
                    (73, P, First => Line_At (Nodes (Element).Name_First));
                  exit Parse_Body;
               end if;
               Read_Quoted (VF, VL);
               if Status /= Success then
                  if Diagnostic.Code = 34 then
                     Set_Diagnostic
                       (73, P, First => Line_At (Nodes (Element).Name_First));
                  end if;
                  exit Parse_Body;
               end if;
               if Duplicate then
                  Status := Malformed;
                  Set_Diagnostic (42, P);
                  exit Parse_Body;
               end if;
               Add (Attribute_Node, Element, NF, NL, VF, VL);
               if Status /= Success then
                  exit Parse_Body;
               end if;
            end loop;
            if not Closed then
               if Depth >= Max_Depth then
                  Status := Limit_Exceeded;
                  Set_Diagnostic (114, P);
                  exit Parse_Body;
               end if;
               Depth := Depth + 1;
               Stack (Depth) := Element;
            end if;
         end if;
         if Status /= Success then
            exit Parse_Body;
         end if;
         Diagnostic := (Domain => 1, Code => 0, Level => 0,
                        Byte_Position => 1, Int1 => 0, Int2 => 0);
      end loop;
      if Root = 0 or Depth /= 0 then
         Status := Malformed;
         Set_Diagnostic
           ((if Root = 0 then 4 else 77), Input'Length + 1,
            First => (if Depth = 0 then 0
                      else Line_At (Nodes (Stack (Depth)).Name_First)));
      end if;
         Body_Pending := False;
         exit Parse_Body;
      end loop Parse_Body;
      Diagnostic.Byte_Position := Error_Position;
      if Status = Success and then Encoding_Warning /= 0 then
         Set_Diagnostic (113, Encoding_Warning, Level => 1);
      end if;
   end Parse;
end XML3_Parser;
