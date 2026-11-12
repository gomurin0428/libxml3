with Interfaces;
with Interfaces.C;
with System;
with XML3_Native_Memory;
with XML3_Text;

package XML3_Error_Records with SPARK_Mode is
   use type System.Address;
   use type Interfaces.C.int;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;

   type Error_Record is record
      Domain  : Interfaces.C.int := 0;
      Code    : Interfaces.C.int := 0;
      Message : System.Address := System.Null_Address;
      Level   : Interfaces.C.int := 0;
      File    : System.Address := System.Null_Address;
      Line    : Interfaces.C.int := 0;
      Str1    : System.Address := System.Null_Address;
      Str2    : System.Address := System.Null_Address;
      Str3    : System.Address := System.Null_Address;
      Int1    : Interfaces.C.int := 0;
      Int2    : Interfaces.C.int := 0;
      Ctxt    : System.Address := System.Null_Address;
      Node    : System.Address := System.Null_Address;
   end record with Convention => C;

   Empty_Record : constant Error_Record := (others => <>);

   function Same_Metadata (Left, Right : Error_Record) return Boolean is
     (Left.Domain = Right.Domain and then Left.Code = Right.Code
      and then Left.Level = Right.Level and then Left.Line = Right.Line
      and then Left.Int1 = Right.Int1 and then Left.Int2 = Right.Int2
      and then Left.Ctxt = Right.Ctxt and then Left.Node = Right.Node)
     with Global => null;

   function Same_String_Presence (Left, Right : Error_Record) return Boolean is
     ((Left.Message = System.Null_Address) = (Right.Message = System.Null_Address)
      and then (Left.File = System.Null_Address) = (Right.File = System.Null_Address)
      and then (Left.Str1 = System.Null_Address) = (Right.Str1 = System.Null_Address)
      and then (Left.Str2 = System.Null_Address) = (Right.Str2 = System.Null_Address)
      and then (Left.Str3 = System.Null_Address) = (Right.Str3 = System.Null_Address))
     with Global => null;

   --  Non-NULL strings must be distinct allocations owned by Item.
   procedure Release (Item : in out Error_Record)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Item = Empty_Record;

   --  Source strings stay borrowed; Target owns all successful copies.
   procedure Clone
     (Source : Error_Record; Target : in out Error_Record; Success : out Boolean;
      Limit : XML3_Text.Byte_Count := XML3_Text.Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Target = Empty_Record,
       Post => (if Success then Same_Metadata (Source, Target)
                  and then Same_String_Presence (Source, Target)
                else Target = Empty_Record);

   Memory_Domain : constant Interfaces.C.int := 6;
   Out_Of_Memory_Code : constant Interfaces.C.int := 2;
   Fatal_Level : constant Interfaces.C.int := 3;

   function Out_Of_Memory (Message : System.Address) return Error_Record is
     ((Domain => Memory_Domain, Code => Out_Of_Memory_Code,
       Level => Fatal_Level, Message => Message, others => <>))
     with Global => null;

   --  A slot publishes one record per thread.  An emergency record carries a
   --  borrowed static message, so it must never go through owning release;
   --  a normal record owns its five strings.
   type Error_Slot is record
      Error     : aliased Error_Record := Empty_Record;
      Emergency : Boolean := False;
   end record;

   Empty_Slot : constant Error_Slot :=
     (Error => Empty_Record, Emergency => False);

   --  Releases the owned strings of a normal record and only zeroes an
   --  emergency one, because its message belongs to the static table.
   procedure Clear_Slot (Slot : in out Error_Slot)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Slot = Empty_Slot;

   --  Moves an owning record into the slot; Replacement is left empty so the
   --  strings have exactly one owner.
   procedure Install (Slot : in out Error_Slot; Replacement : in out Error_Record)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Slot.Error = Replacement'Old and then not Slot.Emergency
         and then Replacement = Empty_Record;

   --  Fills a record with the out-of-memory diagnostic; Message stays borrowed.
   procedure Fill_Out_Of_Memory
     (Item : out Error_Record; Message : System.Address)
     with Global => null,
       Post => Item = Out_Of_Memory (Message);

   procedure Install_Out_Of_Memory
     (Slot : in out Error_Slot; Message : System.Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Slot.Emergency and then Slot.Error = Out_Of_Memory (Message);

   --  Ordered decision of xmlCopyError before any copy is attempted.
   type Copy_Decision is (Reject, Already_Copied, Clone_Source);

   function Decide_Copy
     (From_Null, To_Null, Same, To_Emergency : Boolean) return Copy_Decision
   is
     (if From_Null or else To_Null then Reject
      elsif Same then Already_Copied
      elsif To_Emergency then Reject
      else Clone_Source)
     with Global => null;

   --  Which record xmlGetLastError publishes.
   type Last_Error_Source is (No_Error, Slot_Record, Emergency_Record);

   function Select_Last_Error
     (Has_Slot : Boolean; Code : Interfaces.C.int; Emergency_Active : Boolean)
      return Last_Error_Source
   is
     (if Has_Slot and then Code /= 0 then Slot_Record
      elsif Emergency_Active then Emergency_Record
      else No_Error)
     with Global => null;

   --  What a thread has raised so far.  Every published error advances
   --  Serial; Fatal_Serial and Error_Serial are the serials of the last
   --  error of level XML_ERR_FATAL and of level XML_ERR_ERROR or above, and
   --  Error_Code is the code of the latter.  A parser context compares the
   --  marks taken before and after a read.
   type Error_Mark is record
      Serial : Interfaces.Unsigned_64 := 0;
      Fatal_Serial : Interfaces.Unsigned_64 := 0;
      Error_Serial : Interfaces.Unsigned_64 := 0;
      Error_Code : Interfaces.C.int := 0;
   end record;

   Error_Level : constant Interfaces.C.int := 2;

   --  The mark after an error of Level and Code is published.
   function Advanced
     (Mark : Error_Mark; Level, Code : Interfaces.C.int) return Error_Mark
   is
     ((Serial => Mark.Serial + 1,
       Fatal_Serial =>
         (if Level >= Fatal_Level then Mark.Serial + 1 else Mark.Fatal_Serial),
       Error_Serial =>
         (if Level >= Error_Level then Mark.Serial + 1 else Mark.Error_Serial),
       Error_Code => (if Level >= Error_Level then Code else Mark.Error_Code)))
     with Global => null,
       Post => Advanced'Result.Serial /= Mark.Serial
         and then (Advanced'Result.Fatal_Serial /= Mark.Fatal_Serial)
                    = (Level >= Fatal_Level
                       and then Mark.Fatal_Serial /= Mark.Serial + 1)
         and then (Advanced'Result.Error_Serial /= Mark.Error_Serial)
                    = (Level >= Error_Level
                       and then Mark.Error_Serial /= Mark.Serial + 1);

   --  Which structured handler hears a published error, as libxml2's
   --  xmlCtxtVErr and xmlVRaiseError choose: during a read through a parser
   --  context with an error handler (xmlCtxtSetErrorHandler), that handler,
   --  unless the context's options include XML_PARSE_NOERROR, or the error
   --  is a warning and they include XML_PARSE_NOWARNING; otherwise the
   --  thread's handler (xmlSetStructuredErrorFunc), if any.
   type Handler_Choice is (No_Handler, Context_Handler, Global_Handler);

   No_Error_Option : constant Interfaces.Unsigned_32 := 16#20#;
   No_Warning_Option : constant Interfaces.Unsigned_32 := 16#40#;
   Warning_Level : constant Interfaces.C.int := 1;

   function Option_Bits (Options : Interfaces.C.int)
     return Interfaces.Unsigned_32
   is
     (if Options >= 0 then Interfaces.Unsigned_32 (Options)
      else Interfaces.Unsigned_32 (Long_Long_Integer (Options) + 2 ** 32))
     with Global => null;

   function Select_Handler
     (Context_Set : Boolean; Options : Interfaces.C.int;
      Level : Interfaces.C.int; Global_Set : Boolean) return Handler_Choice
   is
     (if Context_Set
        and then (Option_Bits (Options) and No_Error_Option) = 0
        and then (Level /= Warning_Level
                  or else (Option_Bits (Options) and No_Warning_Option) = 0)
      then Context_Handler
      elsif Global_Set then Global_Handler
      else No_Handler)
     with Global => null,
       Post => (if Select_Handler'Result = Context_Handler then Context_Set)
         and then (if Select_Handler'Result = Global_Handler then Global_Set)
         and then (if Select_Handler'Result = No_Handler
                   then not Global_Set);
end XML3_Error_Records;
