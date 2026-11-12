with Interfaces;
with Interfaces.C;
with XML3_Error_Records;

--  The state decisions of the parser context API of libxml2 2.15.4
--  (xmlNewParserCtxt, xmlCtxtUseOptions, xmlCtxtSetOptions,
--  xmlCtxtGetOptions, xmlCtxtReset and the xmlCtxtRead* functions).  The
--  adapter keeps the public struct; what it stores is decided here.
package XML3_Parser.Contexts with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.C.int;
   subtype Error_Mark is XML3_Error_Records.Error_Mark;

   --  ctxt->options of a new context: XML_PARSE_NODICT.
   Initial_Options : constant Interfaces.C.int := 16#1000#;

   --  The options a context stores: every xmlParserOption of 2.15.4 but
   --  XML_PARSE_XINCLUDE, XML_PARSE_NOXINCNODE and XML_PARSE_NOBASEFIX,
   --  which the parser does not handle.
   All_Mask : constant Interfaces.Unsigned_32 := 16#07FB_7BFF#;

   --  The options xmlCtxtUseOptions can only enable: NOERROR, NOWARNING,
   --  NONET, NSCLEAN, NOCDATA, COMPACT, OLD10, HUGE, OLDSAX, IGNORE_ENC
   --  and BIG_LINES.
   Keep_Mask : constant Interfaces.Unsigned_32 := 16#007B_6860#;

   --  xmlCtxtGetOptions, xmlCtxtUseOptions and xmlCtxtSetOptions answer
   --  -1 for a missing context.
   Missing_Context : constant Interfaces.C.int := -1;

   --  The bits of a C int, and the C int of 32 bits.
   function Bits (Value : Interfaces.C.int) return Interfaces.Unsigned_32 is
     (if Value >= 0 then Interfaces.Unsigned_32 (Value)
      else Interfaces.Unsigned_32
             (Long_Long_Integer (Value) + 2 ** 32))
   with Global => null;

   function To_Int (Value : Interfaces.Unsigned_32) return Interfaces.C.int is
     (if Value <= 16#7FFF_FFFF# then Interfaces.C.int (Value)
      else Interfaces.C.int (Long_Long_Integer (Value) - 2 ** 32))
   with Global => null;

   --  The options a context holds after xmlCtxtUseOptions (Keep) or
   --  xmlCtxtSetOptions: the kept options of Current, and every known
   --  option of Requested.  No unknown bit is ever stored.
   function Stored_Bits
     (Current, Requested : Interfaces.C.int; Keep : Boolean)
      return Interfaces.Unsigned_32
   is
     ((if Keep then Bits (Current) and Keep_Mask else 0)
      or (Bits (Requested) and All_Mask))
   with Global => null,
     Post => (Stored_Bits'Result and not All_Mask) = 0;

   function Stored
     (Current, Requested : Interfaces.C.int; Keep : Boolean)
      return Interfaces.C.int
   is
     (To_Int (Stored_Bits (Current, Requested, Keep)))
   with Global => null;

   --  Their result: the unknown options of Requested, 0 when there are
   --  none.
   function Unknown_Bits
     (Requested : Interfaces.C.int) return Interfaces.Unsigned_32
   is
     (Bits (Requested) and not All_Mask)
   with Global => null,
     Post => (Unknown_Bits'Result and All_Mask) = 0;

   function Unknown (Requested : Interfaces.C.int) return Interfaces.C.int is
     (To_Int (Unknown_Bits (Requested)))
   with Global => null,
     Post => (Unknown'Result = 0) = (Unknown_Bits (Requested) = 0);

   --  The well-formedness flag and the error number of a context.
   type Context_State is record
      Well_Formed : Interfaces.C.int := 1;
      Err_No : Interfaces.C.int := 0;
   end record;

   --  A new or reset context: well-formed, XML_ERR_OK.
   Clean : constant Context_State := (Well_Formed => 1, Err_No => 0);

   --  The context after a read, given the thread's error marks before and
   --  after it: a fatal error clears the well-formedness flag, and the
   --  code of the last error of level XML_ERR_ERROR or above becomes the
   --  error number.  Warnings change neither, as in xmlCtxtVErr.
   function After_Read
     (State : Context_State; Before, After : Error_Mark) return Context_State
   is
     ((Well_Formed =>
         (if After.Fatal_Serial /= Before.Fatal_Serial then 0
          else State.Well_Formed),
       Err_No =>
         (if After.Error_Serial /= Before.Error_Serial then After.Error_Code
          else State.Err_No)))
   with Global => null,
     Post => (if After.Fatal_Serial = Before.Fatal_Serial
              and then After.Error_Serial = Before.Error_Serial
              then After_Read'Result = State);

   --  The read published an error (of any level), which the context copies
   --  into its lastError.
   function Adopts (Before, After : Error_Mark) return Boolean is
     (Before.Serial /= After.Serial)
   with Global => null;

   --  The context after its lastError could not be copied: the copy
   --  failed for want of memory, which the context records as
   --  xmlCtxtErrMemory does.
   function After_Copy_Failure return Context_State is
     ((Well_Formed => 0, Err_No => XML3_Error_Records.Out_Of_Memory_Code))
   with Global => null;

   --  What a context records beyond its public fields, as libxml2's
   --  xmlCtxtVErr and xmlNsErr update it: nsWellFormed, cleared by a
   --  namespace error, and disableSAX, 1 after a fatal error (the parser
   --  then only stops reporting to SAX) and 2 when the parser stopped
   --  for good.
   subtype Stop_Level is Interfaces.C.int range 0 .. 2;

   type Parse_Flags is record
      Ns_Well_Formed : Interfaces.C.int := 1;
      Disable_SAX : Stop_Level := 0;
   end record;

   --  A new or reset context.
   Running : constant Parse_Flags := (Ns_Well_Formed => 1, Disable_SAX => 0);

   Namespace_Domain : constant Interfaces.C.int := 3;
   Internal_Error_Code : constant Interfaces.C.int := 1;
   Entity_Loop_Code : constant Interfaces.C.int := 89;
   Resource_Limit_Code : constant Interfaces.C.int := 114;
   Argument_Code : constant Interfaces.C.int := 115;
   System_Code : constant Interfaces.C.int := 116;

   --  xmlIsCatastrophicError: a fatal memory, internal, argument, system
   --  or I/O failure.
   function Catastrophic (Level, Code : Interfaces.C.int) return Boolean is
     (Level = XML3_Error_Records.Fatal_Level
      and then (Code in Internal_Error_Code | Argument_Code | System_Code
                  | XML3_Error_Records.Out_Of_Memory_Code
                or else Code in 1500 .. 1599))
   with Global => null;

   --  The flags after an error of Domain, Level and Code is published
   --  during a read: a namespace error (xmlNsErr, level XML_ERR_ERROR)
   --  clears nsWellFormed; a catastrophic error, a resource limit or an
   --  entity loop stops the parser for good, any other fatal error
   --  disables SAX (the parser does not recover); warnings and stopped
   --  parsers change nothing else.
   function After_Error
     (Flags : Parse_Flags; Domain, Level, Code : Interfaces.C.int)
      return Parse_Flags
   is
     ((Ns_Well_Formed =>
         (if Domain = Namespace_Domain
            and then Level = XML3_Error_Records.Error_Level
          then 0 else Flags.Ns_Well_Formed),
       Disable_SAX =>
         (if Level < XML3_Error_Records.Error_Level or else Flags.Disable_SAX = 2
          then Flags.Disable_SAX
          elsif Catastrophic (Level, Code) or else Code = Resource_Limit_Code
            or else Code = Entity_Loop_Code
          then 2
          elsif Level >= XML3_Error_Records.Fatal_Level then 1
          else Flags.Disable_SAX)))
   with Global => null,
     Post => (if Level < XML3_Error_Records.Error_Level
              then After_Error'Result.Disable_SAX = Flags.Disable_SAX)
       and then (if Flags.Disable_SAX = 2
                 then After_Error'Result.Disable_SAX = 2);

   --  xmlCtxtGetStatus bits.
   Not_Well_Formed_Bit : constant Interfaces.C.int := 1;
   Not_Ns_Well_Formed_Bit : constant Interfaces.C.int := 2;
   DTD_Validation_Failed_Bit : constant Interfaces.C.int := 4;
   Catastrophic_Error_Bit : constant Interfaces.C.int := 8;

   --  xmlCtxtGetStatus, from the context's wellFormed, flags, lastError
   --  and whether its options ask for DTD validation (the parser never
   --  validates, so a validation never fails otherwise).
   function Status
     (Well_Formed : Interfaces.C.int; Flags : Parse_Flags;
      Last_Level, Last_Code : Interfaces.C.int; Validate : Boolean)
      return Interfaces.C.int
   is
     (if Catastrophic (Last_Level, Last_Code) then
        Catastrophic_Error_Bit + Not_Well_Formed_Bit + Not_Ns_Well_Formed_Bit
        + (if Validate then DTD_Validation_Failed_Bit else 0)
      else
        (if Well_Formed = 0 then Not_Well_Formed_Bit else 0)
        + (if Flags.Ns_Well_Formed = 0 then Not_Ns_Well_Formed_Bit else 0))
   with Global => null,
     Post => Status'Result in 0 .. 15;

   --  XML_PARSE_DTDVALID, which sets ctxt->validate.
   DTD_Valid_Option : constant Interfaces.Unsigned_32 := 16#10#;

   function Validates (Options : Interfaces.C.int) return Boolean is
     ((Bits (Options) and DTD_Valid_Option) /= 0)
   with Global => null;

   --  xmlStopParser: the parser stops for good; a context that recorded no
   --  error yet records XML_ERR_USER_STOP and is no longer well-formed.
   User_Stop_Code : constant Interfaces.C.int := 111;

   function After_Stop (State : Context_State) return Context_State is
     (if State.Err_No = 0 then (Well_Formed => 0, Err_No => User_Stop_Code)
      else State)
   with Global => null;

   --  A push parser context (xmlCreatePushParserCtxt) has no options:
   --  libxml2 clears XML_PARSE_NODICT.
   Push_Options : constant Interfaces.C.int := 0;

   --  The options a push input is parsed with: the context's, without
   --  XML_PARSE_NODICT, which only selects how libxml2 stores names and
   --  which a context made by xmlNewParserCtxt keeps through
   --  xmlCtxtResetPush.
   function Push_Parse_Options (Options : Interfaces.C.int)
     return Interfaces.C.int
   is
     (To_Int (Bits (Options) and not Bits (Initial_Options)))
   with Global => null;

   --  xmlParseChunk without a push input, a NULL context, a negative size
   --  or NULL bytes of a positive size: XML_ERR_ARGUMENT.
   Argument_Error : constant Interfaces.C.int := Argument_Code;

   --  What xmlParseChunk answers after it ran: the error number when the
   --  context is no longer well-formed, otherwise XML_ERR_OK.
   function Chunk_Result (State : Context_State) return Interfaces.C.int is
     (if State.Well_Formed = 0 then State.Err_No else 0)
   with Global => null;

end XML3_Parser.Contexts;
