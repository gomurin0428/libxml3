with Interfaces.C;

--  RFC 3986 URI references as libxml2 2.15.4 parses them
--  (xmlParse3986URIReference): which bytes of the input make up each
--  component of the xmlURI.  The adapter copies or unescapes the spans
--  into the public struct.  The input is the bytes before the
--  terminating NUL; positions past it read as NUL, where libxml2 stops.
package XML3_URIs with SPARK_Mode is
   use type Interfaces.C.int;

   --  xmlURI.cleanup flags.
   Allow_Unwise : constant := 1;
   No_Unescape : constant := 2;
   Allow_UCS_Char : constant := 4;

   --  xmlURI.port values: no port, and an authority without a server.
   Port_Empty : constant Interfaces.C.int := 0;
   Port_Empty_Server : constant Interfaces.C.int := -1;

   --  The bytes First .. Last of the input; an absent component has no
   --  string (NULL in the struct).
   type Span is record
      Present : Boolean := False;
      First : Positive := 1;
      Last : Natural := 0;
   end record;

   No_Span : constant Span := (Present => False, First => 1, Last => 0);

   function Valid_Span (S : Span; Length : Natural) return Boolean is
     (not S.Present
      or else (S.First <= Length + 1 and then S.Last <= Length
               and then S.Last >= S.First - 1))
   with Global => null, Pre => Length < Natural'Last;

   --  The components the parse sets.  Query also gives query_raw.
   type Parts is record
      Scheme, Server, User, Path, Query, Fragment : Span := No_Span;
      Port : Interfaces.C.int := Port_Empty;
   end record;

   function Valid_Parts (P : Parts; Length : Natural) return Boolean is
     (Valid_Span (P.Scheme, Length) and then Valid_Span (P.Server, Length)
      and then Valid_Span (P.User, Length) and then Valid_Span (P.Path, Length)
      and then Valid_Span (P.Query, Length)
      and then Valid_Span (P.Fragment, Length))
   with Global => null, Pre => Length < Natural'Last;

   --  xmlParse3986URIReference: an absolute URI, or else a relative
   --  reference, with the struct's cleanup flags.  Port is the struct's
   --  port before the parse: libxml2 never resets it, so a reused struct
   --  keeps it unless the parse sets one.  Ok is False when neither form
   --  matches the whole input; the components are then all absent.
   --  Detached is a parse without a struct (xmlParseURIReference with a
   --  NULL uri), where libxml2's xmlIsUnreserved accepts no character.
   procedure Parse
     (Input : String; Cleanup : Interfaces.C.int; Port : Interfaces.C.int;
      Result : out Parts; Ok : out Boolean; Detached : Boolean := False)
   with Global => null,
     Pre => Input'First = 1 and then Input'Last >= 0
       and then Input'Last < Natural'Last - 3,
     Post => Valid_Parts (Result, Input'Last)
       and then (if not Ok then
                   Result.Scheme = No_Span and then Result.Server = No_Span
                   and then Result.User = No_Span
                   and then Result.Path = No_Span
                   and then Result.Query = No_Span
                   and then Result.Fragment = No_Span);

   --  libxml2's xmlNormalizePath, used by xmlBuildURI (Is_File False) and
   --  for file system paths (Is_File True), on Path (1 .. Last) in place,
   --  as libxml2 runs it on its buffer: separators are collapsed, "."
   --  segments removed, ".." removes the previous segment, an extraneous
   --  ".." of an absolute path is dropped and a leading one of a relative
   --  path kept.  libxml2's way of telling the two apart (it looks at the
   --  byte at its output position) is kept.  An empty file path becomes
   --  ".".  Last is the new length; the bytes after it are not used.
   procedure Normalize_Path
     (Path : in out String; Length : Natural; Is_File : Boolean;
      Last : out Natural)
   with Global => null,
     Pre => Path'First = 1 and then Path'Last >= 1
       and then Length <= Path'Last and then Path'Last < Natural'Last - 3,
     Post => Last <= Natural'Max (Length, 1) and then Last <= Path'Last;

   --  xmlSaveUri's escaping: whether a byte of each component is written
   --  as it is (otherwise as %XX with uppercase hexadecimal digits).
   type Save_Component is
     (Opaque_Part, User_Part, Authority_Part, Path_Part, Query_Part,
      Fragment_Part);

   function Kept (Component : Save_Component; C : Character) return Boolean;

end XML3_URIs;
