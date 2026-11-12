with System;
with XML3_Native_Memory;

--  How libxml2 2.15.4 turns the filename of xmlSaveFile (and its
--  variants) into a path for its default output callback.  A name
--  without a URI scheme is URI-unescaped as a whole; a "file:" URI is
--  unescaped after its "file://localhost", "file://" or "file:" prefix;
--  any other scheme is used literally.  After unescaping, "-" means
--  standard output.  Unlike libxml2, a name without a scheme is unescaped
--  even when it is not a valid URI reference.
package XML3_File_Paths with SPARK_Mode is
   use type System.Address;

   type Path_Plan is record
      Unescape : Boolean := False;
      --  Bytes of the name before the path (the "file:" prefix).
      Skip : Natural := 0;
      --  The name has no scheme, so "-" after unescaping is standard
      --  output.
      May_Be_Standard : Boolean := False;
   end record;

   procedure Plan
     (Name : System.Address; Length : Natural; Result : out Path_Plan)
   with Global => (Input => XML3_Native_Memory.Foreign_Memory),
     Pre => Name /= System.Null_Address,
     Post => Result.Skip <= Length;

   --  The path of an input file (xmlReadFile, xmlParseFile): only a
   --  "file:" URI is unescaped after its prefix, as xmlFdOpen does; any
   --  other name is used literally.  "-" is handled by the caller.
   procedure Plan_Input
     (Name : System.Address; Length : Natural; Result : out Path_Plan)
   with Global => (Input => XML3_Native_Memory.Foreign_Memory),
     Pre => Name /= System.Null_Address,
     Post => Result.Skip <= Length and then not Result.May_Be_Standard;

   --  Whether the NUL-terminated Path, Length bytes long, is "-".
   function Is_Standard (Path : System.Address; Length : Natural)
     return Boolean
   with Global => (Input => XML3_Native_Memory.Foreign_Memory),
     Pre => Path /= System.Null_Address;

end XML3_File_Paths;
