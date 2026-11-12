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

end XML3_Parser.Contexts;
