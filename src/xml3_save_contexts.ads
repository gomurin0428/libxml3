with Interfaces;
with Interfaces.C;
with XML3_Serialization;

--  The decisions of the xmlsave.h save context of libxml2 2.15.4: which
--  options are supported and how they shape the output, which indent
--  strings are accepted, and the output buffer behind the context (when
--  its bytes reach the target, and the results of xmlSaveFlush,
--  xmlSaveClose and xmlSaveFinish).  The adapter keeps the context and
--  calls the target; what it does is decided here.
package XML3_Save_Contexts with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.C.int;

   --  xmlSaveOption bits.
   Format_Bit : constant Interfaces.Unsigned_32 := 16#001#;
   No_Declaration_Bit : constant Interfaces.Unsigned_32 := 16#002#;
   No_Empty_Bit : constant Interfaces.Unsigned_32 := 16#004#;
   XHTML_Bit : constant Interfaces.Unsigned_32 := 16#010#;
   As_HTML_Bit : constant Interfaces.Unsigned_32 := 16#040#;
   Whitespace_Bit : constant Interfaces.Unsigned_32 := 16#080#;
   No_Indent_Bit : constant Interfaces.Unsigned_32 := 16#200#;

   function Bits (Value : Interfaces.C.int) return Interfaces.Unsigned_32 is
     (if Value >= 0 then Interfaces.Unsigned_32 (Value)
      else Interfaces.Unsigned_32 (Long_Long_Integer (Value) + 2 ** 32))
   with Global => null;

   --  XML_SAVE_XHTML, XML_SAVE_AS_HTML and, without XML_SAVE_FORMAT,
   --  XML_SAVE_WSNONSIG select output this serializer does not produce;
   --  a context with them is refused.  Other unknown bits are ignored, as
   --  libxml2 ignores them; XML_SAVE_AS_XML, XML_SAVE_NO_XHTML,
   --  XML_SAVE_EMPTY and XML_SAVE_INDENT already describe the output.
   function Supported (Options : Interfaces.C.int) return Boolean is
     ((Bits (Options) and (XHTML_Bit or As_HTML_Bit)) = 0
      and then ((Bits (Options) and Whitespace_Bit) = 0
                or else (Bits (Options) and Format_Bit) /= 0))
   with Global => null;

   function Formatted (Options : Interfaces.C.int) return Boolean is
     ((Bits (Options) and Format_Bit) /= 0)
   with Global => null;

   --  The output style of the options with the default indent.
   function Style_For
     (Options : Interfaces.C.int) return XML3_Serialization.Output_Style
   is
     ((Declaration => (Bits (Options) and No_Declaration_Bit) = 0,
       Empty_Tags => (Bits (Options) and No_Empty_Bit) = 0,
       Indent => (Bits (Options) and No_Indent_Bit) = 0,
       Indent_Unit => (others => ' '),
       Unit_Size => 2))
   with Global => null;

   --  xmlSaveSetIndentString accepts 1 to 60 bytes.
   function Indent_Accepted (Length : Natural) return Boolean is
     (Length in XML3_Serialization.Indent_Size)
   with Global => null;

   --  The diagnostics of a refused context: an encoding the serializer
   --  cannot produce is XML_FROM_OUTPUT / XML_ERR_UNSUPPORTED_ENCODING at
   --  XML_ERR_ERROR, as libxml2 reports an unknown encoding; refused
   --  options are XML_FROM_OUTPUT / XML_ERR_ARGUMENT at XML_ERR_FATAL.
   Output_Domain : constant Interfaces.C.int := 7;
   Unsupported_Encoding_Code : constant Interfaces.C.int := 32;
   Unsupported_Encoding_Level : constant Interfaces.C.int := 2;
   Unsupported_Option_Code : constant Interfaces.C.int := 115;
   Unsupported_Option_Level : constant Interfaces.C.int := 3;

   --  xmlSaveFinish of a missing context: XML_ERR_INTERNAL_ERROR.
   Missing_Context_Finish : constant Interfaces.C.int := 1;

   --  The output buffer: the bytes written to the target so far (capped
   --  at INT_MAX) and the first error, an xmlParserErrors value or 0.
   subtype Count is Interfaces.C.int range 0 .. Interfaces.C.int'Last;

   type Output_State is record
      Written : Count := 0;
      Error : Count := 0;
   end record;

   --  Pending bytes reach the target once there are MINLEN (4000) of them.
   Min_Length : constant := 4000;

   function Must_Write (Pending : Natural) return Boolean is
     (Pending >= Min_Length)
   with Global => null;

   Internal_Error_Code : constant Count := 1;
   No_Memory_Code : constant Count := 2;
   Write_Error_Code : constant Count := 1546;
   Unknown_IO_Code : constant Count := 1500;

   --  The bytes of a write the target took, given its result for
   --  Requested bytes; none for a failed write.
   function Taken (Result : Interfaces.C.int; Requested : Natural)
     return Natural
   is
     (if Result <= 0 then 0
      elsif Natural (Result) > Requested then Requested
      else Natural (Result))
   with Global => null,
     Post => Taken'Result <= Requested;

   --  The state after the target answered Result for Requested bytes.  A
   --  negative result is an error (-1 is XML_IO_WRITE, others the negated
   --  code).  In the writes made while bytes are added (Strict), a target
   --  that took nothing or more than it was given is an internal error;
   --  a flush accepts any count.
   function After_Write
     (State : Output_State; Result : Interfaces.C.int; Requested : Natural;
      Strict : Boolean) return Output_State
   is
     (if Result < 0 then
        (Written => State.Written,
         Error =>
           (if Result = -1 or else Result = Interfaces.C.int'First
            then Write_Error_Code else -Result))
      elsif Strict and then (Result = 0 or else Natural (Result) > Requested)
      then (Written => State.Written, Error => Internal_Error_Code)
      else
        (Written =>
           (if State.Written > Count'Last - Result then Count'Last
            else State.Written + Result),
         Error => State.Error))
   with Global => null,
     Post => (if Result < 0 then After_Write'Result.Error /= 0)
       and then After_Write'Result.Written >= State.Written;

   --  xmlIsCatastrophicError at XML_ERR_FATAL.
   function Catastrophic (Code : Count) return Boolean is
     (Code in 1 | 2 | 115 | 116 | 1500 .. 1599)
   with Global => null;

   --  The error after the close callback answered Code: a failure is kept
   --  unless the buffer already holds a catastrophic error.
   function After_Close
     (State : Output_State; Code : Interfaces.C.int) return Output_State
   is
     ((Written => State.Written,
       Error =>
         (if Code /= 0 and then not Catastrophic (State.Error) then
            (if Code < 0 then Unknown_IO_Code else Code)
          else State.Error)))
   with Global => null;

   --  xmlOutputBufferClose: the negated error, or the bytes written.
   function Close_Result (State : Output_State) return Interfaces.C.int is
     (if State.Error /= 0 then -State.Error else State.Written)
   with Global => null,
     Post => (Close_Result'Result < 0) = (State.Error /= 0);

   --  xmlSaveFinish: XML_ERR_OK or the buffer's error.
   function Finish_Code (State : Output_State) return Interfaces.C.int is
     (State.Error)
   with Global => null,
     Post => Finish_Code'Result >= 0;

end XML3_Save_Contexts;
