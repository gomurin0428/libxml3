package body XML3_URIs with SPARK_Mode is

   NUL : constant Character := Character'Val (0);

   function Is_Alpha (C : Character) return Boolean is
     (C in 'a' .. 'z' | 'A' .. 'Z');

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   function Is_Hex (C : Character) return Boolean is
     (C in '0' .. '9' | 'a' .. 'f' | 'A' .. 'F');

   function Is_Sub_Delim (C : Character) return Boolean is
     (C in '!' | '$' | '&' | '(' | ')' | '*' | '+' | ',' | ';' | '='
         | ''');

   function Is_Strictly_Unreserved (C : Character) return Boolean is
     (Is_Alpha (C) or else Is_Digit (C) or else C in '-' | '.' | '_' | '~');

   function Is_Unwise (C : Character) return Boolean is
     (C in '{' | '}' | '|' | '\' | '^' | '[' | ']' | '`');

   --  ISA_UCSCHAR without the terminating NUL, which libxml2 would also
   --  accept (and read past) when only XML_URI_ALLOW_UCSCHAR is set.
   function Is_UCS_Char (C : Character) return Boolean is
     (C /= NUL
      and then (Character'Pos (C) <= 16#20# or else Character'Pos (C) >= 16#7F#
                or else C in '<' | '>' | '"' | '{' | '}' | '|' | '\' | '^'
                           | '`'));

   --  The uri.c IS_UNRESERVED and IS_RESERVED of xmlSaveUri.
   function Is_Mark_Unreserved (C : Character) return Boolean is
     (Is_Alpha (C) or else Is_Digit (C)
      or else C in '-' | '_' | '.' | '!' | '~' | '*' | ''' | '(' | ')');

   function Is_Reserved (C : Character) return Boolean is
     (C in ';' | '/' | '?' | ':' | '@' | '&' | '=' | '+' | '$' | ','
         | '[' | ']');

   function Kept (Component : Save_Component; C : Character) return Boolean
   is
     (Is_Mark_Unreserved (C)
      or else (case Component is
                 when Opaque_Part | Query_Part | Fragment_Part =>
                   Is_Reserved (C),
                 when User_Part =>
                   C in ';' | ':' | '&' | '=' | '+' | '$' | ',',
                 when Authority_Part =>
                   C in '$' | ',' | ';' | ':' | '@' | '&' | '=' | '+',
                 when Path_Part =>
                   C in '/' | ';' | '@' | '&' | '=' | '+' | '$' | ','));

   procedure Parse
     (Input : String; Cleanup : Interfaces.C.int; Port : Interfaces.C.int;
      Result : out Parts; Ok : out Boolean; Detached : Boolean := False)
   is
      Length : constant Natural range 0 .. Natural'Last - 4 := Input'Last;
      Unwise_Allowed : constant Boolean := Cleanup mod 2 = 1;
      UCS_Allowed : constant Boolean :=
        not Unwise_Allowed and then (Cleanup / 4) mod 2 = 1;

      subtype Position is Positive range 1 .. Length + 1;

      function Char (I : Positive) return Character is
        (if I in Input'Range then Input (I) else NUL)
      with Post => (if Char'Result /= NUL then I <= Length);

      function Unreserved (I : Position) return Boolean is
        (not Detached
         and then (Is_Strictly_Unreserved (Char (I))
                   or else (Unwise_Allowed and then Is_Unwise (Char (I)))
                   or else (UCS_Allowed and then Is_UCS_Char (Char (I)))))
      with Post => (if Unreserved'Result then I <= Length);

      function Pct_Encoded (I : Position) return Boolean is
        (Char (I) = '%' and then Is_Hex (Char (I + 1))
         and then Is_Hex (Char (I + 2)))
      with Post => (if Pct_Encoded'Result then I + 2 <= Length);

      function Pchar (I : Position) return Boolean is
        (Unreserved (I) or else Pct_Encoded (I)
         or else Is_Sub_Delim (Char (I)) or else Char (I) in ':' | '@')
      with Post => (if Pchar'Result then I <= Length);

      --  NEXT: past a percent-encoded byte or one character.  Every caller
      --  has accepted the character at I, so a '%' there is encoded.
      function Next (I : Position) return Position is
        (if Char (I) = '%' and then I + 2 <= Length then I + 3 else I + 1)
      with Pre => I <= Length,
        Post => Next'Result > I;

      Cur : Position := 1;
      R : Parts;

      procedure Clean
      with Post => Valid_Parts (R, Length)
        and then R.Scheme = No_Span and then R.Server = No_Span
        and then R.User = No_Span and then R.Path = No_Span
        and then R.Query = No_Span and then R.Fragment = No_Span
      is
      begin
         R.Scheme := No_Span;
         R.Server := No_Span;
         R.User := No_Span;
         R.Path := No_Span;
         R.Query := No_Span;
         R.Fragment := No_Span;
      end Clean;

      function Span_Of (First : Position; Last : Natural) return Span is
        ((Present => True, First => First, Last => Last))
      with Pre => Last <= Length and then Last >= First - 1,
        Post => Valid_Span (Span_Of'Result, Length);

      procedure Parse_Scheme (Good : out Boolean)
      with Pre => Valid_Parts (R, Length),
        Post => Cur >= Cur'Old and then Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         Good := False;
         if not Is_Alpha (Char (Cur)) then
            return;
         end if;
         Cur := Cur + 1;
         while Is_Alpha (Char (Cur)) or else Is_Digit (Char (Cur))
           or else Char (Cur) in '+' | '-' | '.'
         loop
            pragma Loop_Invariant (Cur in Start + 1 .. Length);
            pragma Loop_Variant (Increases => Cur);
            Cur := Cur + 1;
         end loop;
         R.Scheme := Span_Of (Start, Cur - 1);
         Good := True;
      end Parse_Scheme;

      procedure Parse_Fragment
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         while Pchar (Cur) or else Char (Cur) in '/' | '?' | '[' | ']' loop
            pragma Loop_Invariant (Cur in Start .. Length);
            pragma Loop_Variant (Increases => Cur);
            Cur := Next (Cur);
         end loop;
         R.Fragment := Span_Of (Start, Cur - 1);
      end Parse_Fragment;

      procedure Parse_Query
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         while Pchar (Cur) or else Char (Cur) in '/' | '?' loop
            pragma Loop_Invariant (Cur in Start .. Length);
            pragma Loop_Variant (Increases => Cur);
            Cur := Next (Cur);
         end loop;
         R.Query := Span_Of (Start, Cur - 1);
      end Parse_Query;

      procedure Parse_Port (Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Value : Interfaces.C.int := 0;
         Digit : Interfaces.C.int;
      begin
         Good := False;
         if not Is_Digit (Char (Cur)) then
            return;
         end if;
         while Is_Digit (Char (Cur)) loop
            pragma Loop_Invariant (Cur <= Length and then Value >= 0);
            pragma Loop_Variant (Increases => Cur);
            Digit := Interfaces.C.int
              (Character'Pos (Char (Cur)) - Character'Pos ('0'));
            if Value > Interfaces.C.int'Last / 10 then
               return;
            end if;
            Value := Value * 10;
            if Value > Interfaces.C.int'Last - Digit then
               return;
            end if;
            Value := Value + Digit;
            Cur := Cur + 1;
         end loop;
         R.Port := Value;
         Good := True;
      end Parse_Port;

      procedure Parse_Host (Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         Good := False;
         if Char (Cur) = '[' then
            Cur := Cur + 1;
            while Char (Cur) /= ']' and then Char (Cur) /= NUL loop
               pragma Loop_Invariant (Cur in Start + 1 .. Length);
               pragma Loop_Variant (Increases => Cur);
               Cur := Cur + 1;
            end loop;
            if Char (Cur) /= ']' then
               return;
            end if;
            Cur := Cur + 1;
         else
            --  libxml2 first tries an IPv4 address, but the attempt never
            --  succeeds (it does not step over the second and third dots),
            --  so every host is read as a registered name.
            while Unreserved (Cur) or else Pct_Encoded (Cur)
              or else Is_Sub_Delim (Char (Cur))
            loop
               pragma Loop_Invariant (Cur in Start .. Length);
               pragma Loop_Variant (Increases => Cur);
               Cur := Next (Cur);
            end loop;
         end if;
         R.Server :=
           (if Cur /= Start then Span_Of (Start, Cur - 1) else No_Span);
         Good := True;
      end Parse_Host;

      procedure Parse_Authority (Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         --  userinfo "@", or none.
         while Unreserved (Cur) or else Pct_Encoded (Cur)
           or else Is_Sub_Delim (Char (Cur)) or else Char (Cur) = ':'
         loop
            pragma Loop_Invariant (Cur in Start .. Length);
            pragma Loop_Variant (Increases => Cur);
            Cur := Next (Cur);
         end loop;
         if Char (Cur) = '@' then
            R.User := Span_Of (Start, Cur - 1);
            Cur := Cur + 1;
         else
            Cur := Start;
         end if;
         Parse_Host (Good);
         if not Good then
            return;
         end if;
         if Char (Cur) = ':' then
            Cur := Cur + 1;
            Parse_Port (Good);
         end if;
      end Parse_Authority;

      --  xmlParse3986Segment: a non-empty segment unless Empty allows none;
      --  Forbid ends it (NUL for none).
      procedure Parse_Segment
        (Forbid : Character; Empty : Boolean; Good : out Boolean)
      with Post => Cur >= Cur'Old
      is
         Start : constant Position := Cur;
      begin
         if not Pchar (Cur) or else Char (Cur) = Forbid then
            Good := Empty;
            return;
         end if;
         Cur := Next (Cur);
         while Pchar (Cur) and then Char (Cur) /= Forbid loop
            pragma Loop_Invariant (Cur in Start + 1 .. Length);
            pragma Loop_Variant (Increases => Cur);
            Cur := Next (Cur);
         end loop;
         Good := True;
      end Parse_Segment;

      --  The "/" segment repetition shared by the path forms.
      procedure Parse_More_Segments
      with Post => Cur >= Cur'Old
      is
         Start : constant Position := Cur;
         Good : Boolean;
      begin
         while Char (Cur) = '/' loop
            pragma Loop_Invariant (Cur in Start .. Length);
            pragma Loop_Variant (Increases => Cur);
            Cur := Cur + 1;
            Parse_Segment (NUL, True, Good);
         end loop;
      end Parse_More_Segments;

      procedure Set_Path (Start : Position)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
      begin
         R.Path :=
           (if Cur /= Start and then Cur > Start
            then Span_Of (Start, Cur - 1) else No_Span);
      end Set_Path;

      procedure Parse_Path_Ab_Empty
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         Parse_More_Segments;
         Set_Path (Start);
      end Parse_Path_Ab_Empty;

      --  Called at a "/".
      procedure Parse_Path_Absolute
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
         Good : Boolean;
      begin
         if Cur <= Length then
            Cur := Cur + 1;
         end if;
         Parse_Segment (NUL, False, Good);
         if Good then
            Parse_More_Segments;
         end if;
         Set_Path (Start);
      end Parse_Path_Absolute;

      procedure Parse_Path_Rootless (Forbid : Character; Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
         Start : constant Position := Cur;
      begin
         Parse_Segment (Forbid, False, Good);
         if not Good then
            return;
         end if;
         Parse_More_Segments;
         Set_Path (Start);
      end Parse_Path_Rootless;

      --  The optional query and fragment, then the end of the input.
      procedure Parse_Tail (Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
      begin
         if Char (Cur) = '?' then
            Cur := Cur + 1;
            Parse_Query;
         end if;
         if Char (Cur) = '#' then
            Cur := Cur + 1;
            Parse_Fragment;
         end if;
         Good := Cur > Length;
         if not Good then
            Clean;
         end if;
      end Parse_Tail;

      procedure Parse_Absolute (Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
      begin
         Parse_Scheme (Good);
         if not Good then
            return;
         end if;
         if Char (Cur) /= ':' then
            Good := False;
            return;
         end if;
         Cur := Cur + 1;
         if Char (Cur) = '/' and then Char (Cur + 1) = '/' then
            Cur := Cur + 2;
            Parse_Authority (Good);
            if not Good then
               return;
            end if;
            if not R.Server.Present and then R.Port = Port_Empty then
               R.Port := Port_Empty_Server;
            end if;
            Parse_Path_Ab_Empty;
         elsif Char (Cur) = '/' then
            Parse_Path_Absolute;
         elsif Pchar (Cur) then
            Parse_Path_Rootless (NUL, Good);
            if not Good then
               return;
            end if;
         else
            R.Path := No_Span;
         end if;
         Parse_Tail (Good);
      end Parse_Absolute;

      procedure Parse_Relative (Good : out Boolean)
      with Pre => Valid_Parts (R, Length), Post => Valid_Parts (R, Length)
      is
      begin
         if Char (Cur) = '/' and then Char (Cur + 1) = '/' then
            Cur := Cur + 2;
            Parse_Authority (Good);
            if not Good then
               return;
            end if;
            Parse_Path_Ab_Empty;
         elsif Char (Cur) = '/' then
            Parse_Path_Absolute;
         elsif Pchar (Cur) then
            Parse_Path_Rootless (':', Good);
            if not Good then
               return;
            end if;
         else
            R.Path := No_Span;
         end if;
         Parse_Tail (Good);
      end Parse_Relative;
   begin
      R := (Port => Port, others => No_Span);
      Parse_Absolute (Ok);
      if not Ok then
         Clean;
         Cur := 1;
         Parse_Relative (Ok);
         if not Ok then
            Clean;
         end if;
      end if;
      Result := R;
   end Parse;

   procedure Normalize_Path
     (Path : in out String; Length : Natural; Is_File : Boolean;
      Last : out Natural)
   is
      Cur : Positive := 1;
      Out_Pos : Positive := 1;
      Segments : Integer := 0;
      Done : Boolean := False;

      --  The byte at I as libxml2 reads its buffer: what is there now up
      --  to the original length, then the terminating NUL.
      function Byte (I : Positive) return Character is
        (if I <= Length and then I in Path'Range then Path (I) else NUL);

      function Is_Separator (C : Character) return Boolean is (C = '/');
   begin
      Last := 0;
      if Length = 0 then
         --  An empty path is returned as it is, even a file path.
         return;
      end if;
      if Is_Separator (Byte (Cur)) then
         Cur := Cur + 1;
         Path (Out_Pos) := '/';
         Out_Pos := Out_Pos + 1;
      end if;
      while not Done and then Byte (Cur) /= NUL loop
         pragma Loop_Invariant (Out_Pos <= Cur and then Cur <= Length);
         pragma Loop_Invariant (Segments in -Cur .. Cur);
         pragma Loop_Variant (Increases => Cur);
         declare
            Start : constant Positive := Cur with Ghost;
            Handled : Boolean := False;
         begin
            --  Collapse separators.
            while Is_Separator (Byte (Cur)) loop
               pragma Loop_Invariant (Cur in Start .. Length);
               pragma Loop_Variant (Increases => Cur);
               Cur := Cur + 1;
            end loop;
            if Byte (Cur) = '.' then
               if Byte (Cur + 1) = NUL then
                  --  "." at the end.
                  Done := True;
                  Handled := True;
               elsif Is_Separator (Byte (Cur + 1)) then
                  --  "./"
                  Cur := Cur + 2;
                  Handled := True;
               elsif Byte (Cur + 1) = '.'
                 and then (Byte (Cur + 2) = NUL
                           or else Is_Separator (Byte (Cur + 2)))
               then
                  if Segments > 0 then
                     --  ".." removes the last segment.  (A segment was
                     --  written, so the output is not empty; libxml2 has
                     --  no check here.)
                     while Out_Pos > 1 loop
                        pragma Loop_Invariant (Out_Pos in 2 .. Cur);
                        pragma Loop_Variant (Decreases => Out_Pos);
                        Out_Pos := Out_Pos - 1;
                        exit when Out_Pos = 1
                          or else Is_Separator (Path (Out_Pos - 1));
                     end loop;
                     Segments := Segments - 1;
                     if Byte (Cur + 2) = NUL then
                        Done := True;
                     else
                        Cur := Cur + 3;
                     end if;
                     Handled := True;
                  elsif Byte (Out_Pos) = '/' then
                     --  An extraneous ".." of an absolute path (libxml2
                     --  looks at the byte at its output position).
                     if Byte (Cur + 2) = NUL then
                        Done := True;
                     else
                        Cur := Cur + 3;
                     end if;
                     Handled := True;
                  else
                     --  "../" kept at the start of a relative path.
                     Segments := Segments - 1;
                  end if;
               end if;
            end if;
            if not Handled then
               --  Copy the segment and its separator.
               while Byte (Cur) /= NUL and then not Is_Separator (Byte (Cur)) loop
                  pragma Loop_Invariant
                    (Out_Pos <= Cur and then Cur in Start .. Length);
                  pragma Loop_Variant (Increases => Cur);
                  Path (Out_Pos) := Byte (Cur);
                  Out_Pos := Out_Pos + 1;
                  Cur := Cur + 1;
               end loop;
               if Byte (Cur) /= NUL then
                  Cur := Cur + 1;
                  Path (Out_Pos) := '/';
                  Out_Pos := Out_Pos + 1;
               end if;
               Segments := Segments + 1;
            end if;
            exit when Done or else Cur > Length;
            pragma Assert (Cur > Start);
         end;
      end loop;
      if Is_File and then Out_Pos = 1 then
         --  An empty file path becomes ".".
         Path (Out_Pos) := '.';
         Out_Pos := Out_Pos + 1;
      end if;
      Last := Out_Pos - 1;
   end Normalize_Path;

end XML3_URIs;
