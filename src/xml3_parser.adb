package body XML3_Parser with SPARK_Mode is
   function Space (C : Character) return Boolean is
     (C = ' ' or C = Character'Val (9) or C = Character'Val (10)
      or C = Character'Val (13));

   function Name_Start (C : Character) return Boolean is
     (C in 'a' .. 'z' or C in 'A' .. 'Z' or C = '_');

   function Name_Char (C : Character) return Boolean is
     (Name_Start (C) or C in '0' .. '9' or C = '-' or C = '.');

   function Layout (Nodes : Node_Array; Count : Node_Id; Size : Offset)
                    return Boolean is
     (for all K in 1 .. Count =>
       Nodes (K).Parent < K
       and Nodes (K).Name_Last <= Size
       and Nodes (K).Value_Last <= Size
       and Nodes (K).Name_First <= Nodes (K).Name_Last + 1
       and Nodes (K).Value_First <= Nodes (K).Value_Last + 1)
     with Ghost;

   procedure Parse
     (Input  : String;
      Nodes  : out Node_Array;
      Count  : out Node_Id;
      Root   : out Node_Id;
      Status : out Parse_Status)
   is
      P : Position := 1;
      Depth : Natural range 0 .. Max_Depth := 0;
      Stack : array (Positive range 1 .. Max_Depth) of Node_Id := (others => 0);
      NF, VF : Position;
      NL, VL : Offset;
      Saved : Position;
      Parent : Node_Id;
      Element : Node_Id;
      Quote : Character;
      Closed : Boolean;
      Seen_Encoding, Seen_Standalone : Boolean;

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
      is
      begin
         First := P;
         if Name_Start (Peek) then
            P := P + 1;
            while P <= Input'Last and then
              (Name_Char (Input (P)) or else (Qualified and then Input (P) = ':'))
            loop
               pragma Loop_Invariant (P in First + 1 .. Input'Length + 1);
               pragma Loop_Variant (Increases => P);
               P := P + 1;
            end loop;
         end if;
         Last := P - 1;
      end Read_Name;

      procedure Read_Quoted (First : out Position; Last : out Offset)
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then P <= Input'Length + 1,
          Post => P in P'Old .. Input'Length + 1
            and Last <= Input'Length and First <= Last + 1
      is
         Q : constant Character := Peek;
      begin
         First := P;
         Last := P - 1;
         if Q /= '"' and Q /= Character'Val (39) then
            Status := Malformed;
            return;
         end if;
         P := P + 1;
         First := P;
         while P <= Input'Last and then Input (P) /= Q loop
            pragma Loop_Invariant (P in First .. Input'Length + 1);
            pragma Loop_Variant (Increases => P);
            if Input (P) = '<' then
               Status := Malformed;
               Last := P - 1;
               return;
            end if;
            P := P + 1;
         end loop;
         Last := P - 1;
         if P > Input'Last then
            Status := Malformed;
         else
            P := P + 1;
         end if;
      end Read_Quoted;

      function Value_OK (First : Position; Last : Offset; Attr : Boolean)
                         return Boolean
        with Pre => Input'First = 1 and Input'Length <= XML3_Text.Max_Bytes
          and First <= Last + 1 and Last <= Input'Length
      is
         Value : constant String (1 .. Last - First + 1) := Input (First .. Last);
         Unused_Result : String (1 .. Value'Length);
         Unused_Length : XML3_Text.Byte_Count;
         Valid : Boolean;
      begin
         XML3_Text.Decode (Value, Attr, True, Unused_Result, Unused_Length, Valid);
         return Valid;
      end Value_OK;

      procedure Add
        (Kind : Node_Kind; Owner : Node_Id;
         Name_First : Position; Name_Last : Offset;
         Value_First : Position; Value_Last : Offset)
        with Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
          and then Layout (Nodes, Count, Input'Length)
          and then Owner <= Count
          and then Name_First <= Name_Last + 1 and then Name_Last <= Input'Length
          and then Value_First <= Value_Last + 1 and then Value_Last <= Input'Length,
          Post => Layout (Nodes, Count, Input'Length)
            and Count >= Count'Old
            and (if Status = Success then Count = Count'Old + 1)
            and (for all K in 1 .. Count'Old => Nodes (K) = Nodes'Old (K))
      is
      begin
         if Count = Max_Nodes then
            Status := Limit_Exceeded;
            return;
         end if;
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
      is
      begin
         Read_Name (Name_First, Name_Last);
         Value_First := P;
         Value_Last := P - 1;
         Skip_Space;
         if Peek /= '=' then
            Status := Malformed;
            return;
         end if;
         P := P + 1;
         Skip_Space;
         Read_Quoted (Value_First, Value_Last);
      end Pseudo_Attribute;
   begin
      Nodes := (others => (others => <>));
      Count := 0;
      Root := 0;
      Status := Success;
      if not XML3_Text.Valid_UTF8 (Input) then
         Status := Malformed;
         return;
      end if;
      if At_Text (Character'Val (16#EF#) & Character'Val (16#BB#) & Character'Val (16#BF#)) then
         P := P + 3;
      end if;
      if At_Text ("<?xml") then
         Saved := P;
         P := P + 5;
         if Space (Peek) then
            Skip_Space;
            Pseudo_Attribute (NF, NL, VF, VL);
            if Status /= Success then
               return;
            end if;
            if Input (NF .. NL) /= "version" or Input (VF .. VL) /= "1.0" then
               Status := Unsupported;
               return;
            end if;
            Seen_Encoding := False;
            Seen_Standalone := False;
            while not At_Text ("?>") loop
               pragma Loop_Invariant (P <= Input'Length + 1);
               pragma Loop_Variant (Increases => P);
               if not Space (Peek) then
                  Status := Malformed;
                  return;
               end if;
               Skip_Space;
               exit when At_Text ("?>");
               Pseudo_Attribute (NF, NL, VF, VL);
               if Status /= Success then
                  return;
               end if;
               if Input (NF .. NL) = "encoding" and not Seen_Encoding and not Seen_Standalone then
                  if Input (VF .. VL) /= "UTF-8" and Input (VF .. VL) /= "utf-8" then
                     Status := Unsupported;
                     return;
                  end if;
                  Seen_Encoding := True;
               elsif Input (NF .. NL) = "standalone" and not Seen_Standalone then
                  if Input (VF .. VL) /= "yes" and Input (VF .. VL) /= "no" then
                     Status := Malformed;
                     return;
                  end if;
                  Seen_Standalone := True;
               else
                  Status := Malformed;
                  return;
               end if;
            end loop;
            P := P + 2;
         else
            P := Saved;
         end if;
      end if;

      while P <= Input'Last loop
         pragma Loop_Invariant (P <= Input'Length + 1);
         pragma Loop_Invariant (Layout (Nodes, Count, Input'Length));
         pragma Loop_Invariant (Root <= Count);
         pragma Loop_Invariant (for all D in 1 .. Depth => Stack (D) in 1 .. Count);
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
                  return;
               end if;
               P := P + 1;
            end loop;
            VL := P - 1;
            if not Value_OK (VF, VL, False) then
               Status := Malformed;
               return;
            end if;
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
            if not At_Text ("-->") then
               Status := Malformed;
               return;
            end if;
            P := P + 3;
            Add (Comment_Node, Parent, 1, 0, VF, VL);
         elsif At_Text ("<![CDATA[") then
            if Depth = 0 then
               Status := Malformed;
               return;
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
               return;
            end if;
            P := P + 3;
            Add (CData_Node, Parent, 1, 0, VF, VL);
         elsif At_Text ("<?") then
            P := P + 2;
            Read_Name (NF, NL);
            if NL < NF then
               Status := Malformed;
               return;
            end if;
            if NL - NF = 2 and then
              (Input (NF) = 'x' or Input (NF) = 'X') and then
              (Input (NF + 1) = 'm' or Input (NF + 1) = 'M') and then
              (Input (NL) = 'l' or Input (NL) = 'L')
            then
               Status := Malformed;
               return;
            end if;
            if not At_Text ("?>") and not Space (Peek) then
               Status := Malformed;
               return;
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
               return;
            end if;
            P := P + 2;
            Add (PI_Node, Parent, NF, NL, VF, VL);
         elsif At_Text ("</") then
            if Depth = 0 then
               Status := Malformed;
               return;
            end if;
            P := P + 2;
            Read_Name (NF, NL, Qualified => True);
            if NF > NL or else
              Input (NF .. NL) /= Input (Nodes (Parent).Name_First .. Nodes (Parent).Name_Last)
            then
               Status := Malformed;
               return;
            end if;
            Skip_Space;
            if Peek /= '>' then
               Status := Malformed;
               return;
            end if;
            P := P + 1;
            Depth := Depth - 1;
         elsif At_Text ("<!") then
            Status := Unsupported;
            return;
         else
            P := P + 1;
            Read_Name (NF, NL, Qualified => True);
            if NF > NL or else (Depth = 0 and Root /= 0) then
               Status := Malformed;
               return;
            end if;
            if Depth = Max_Depth then
               Status := Limit_Exceeded;
               return;
            end if;
            Add (Element_Node, Parent, NF, NL, 1, 0);
            if Status /= Success then
               return;
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
                  return;
               end if;
               Read_Name (NF, NL, Qualified => True);
               if NF > NL then
                  Status := Malformed;
                  return;
               end if;
               for K in Element + 1 .. Count loop
                  if Nodes (K).Kind = Attribute_Node and then
                    Input (NF .. NL) = Input (Nodes (K).Name_First .. Nodes (K).Name_Last)
                  then
                     Status := Malformed;
                     return;
                  end if;
               end loop;
               Skip_Space;
               if Peek /= '=' then
                  Status := Malformed;
                  return;
               end if;
               P := P + 1;
               Skip_Space;
               Quote := Peek;
               if Quote /= '"' and Quote /= Character'Val (39) then
                  Status := Malformed;
                  return;
               end if;
               Read_Quoted (VF, VL);
               if Status /= Success then
                  return;
               end if;
               if not Value_OK (VF, VL, True) then
                  Status := Malformed;
                  return;
               end if;
               Add (Attribute_Node, Element, NF, NL, VF, VL);
               if Status /= Success then
                  return;
               end if;
            end loop;
            if not Closed then
               Depth := Depth + 1;
               Stack (Depth) := Element;
            end if;
         end if;
         if Status /= Success then
            return;
         end if;
      end loop;
      if Root = 0 or Depth /= 0 then
         Status := Malformed;
      end if;
   end Parse;
end XML3_Parser;
