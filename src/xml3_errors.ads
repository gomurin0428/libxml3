with Interfaces;
with Interfaces.C;
with System;

package XML3_Errors is

   function Get_Last_Error return System.Address
     with Export, Convention => C, External_Name => "xmlGetLastError";

   procedure Reset_Last_Error
     with Export, Convention => C, External_Name => "xmlResetLastError";

   procedure Reset_Error (Error : System.Address)
     with Export, Convention => C, External_Name => "xmlResetError";

   function Copy_Error
     (From : System.Address;
      To   : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCopyError";

   procedure Set_Error
     (Domain  : Interfaces.C.int;
      Code    : Interfaces.C.int;
      Level   : Interfaces.C.int;
      Line    : Interfaces.C.int;
      Int1    : Interfaces.C.int;
      Int2    : Interfaces.C.int;
      Message : System.Address;
      File    : System.Address;
      Str1    : System.Address;
      Str2    : System.Address;
      Str3    : System.Address);

   procedure Report
     (Domain        : Natural;
      Code          : Natural;
      Level         : Natural;
      Byte_Position : Natural;
      Int1          : Integer;
      Input         : String;
      File          : System.Address);

   procedure Report_Simple
     (Domain : Interfaces.C.int;
      Code   : Interfaces.C.int;
      Level  : Interfaces.C.int;
      File   : System.Address);

   function Last_Error_Is_OOM return Boolean;

   --  xmlStructuredErrorFunc.
   type Structured_Handler is access procedure
     (Data : System.Address; Error : System.Address)
     with Convention => C;

   procedure Set_Structured_Error_Func
     (Data : System.Address; Handler : Structured_Handler)
     with Export, Convention => C,
       External_Name => "xmlSetStructuredErrorFunc";

   --  A read through a parser context: until End_Context_Read, published
   --  errors name the context, are copied into its lastError (Target) and
   --  counted in its own error mark as they are published, as libxml2
   --  records them in ctxt->lastError, and go to its handler as
   --  Select_Handler decides.  While a handler runs, no read is current,
   --  so the library calls it makes are not attributed to the context.
   type Context_Read is record
      Context : System.Address := System.Null_Address;
      Handler : Structured_Handler := null;
      Data : System.Address := System.Null_Address;
      Options : Interfaces.C.int := 0;
      Target : System.Address := System.Null_Address;
   end record;

   --  The read's own error mark (XML3_Error_Records.Error_Mark from zero)
   --  and whether a copy into its lastError failed.
   type Read_Outcome is record
      Serial, Fatal_Serial, Error_Serial : Interfaces.Unsigned_64 := 0;
      Error_Code : Interfaces.C.int := 0;
      Copy_Failed : Boolean := False;
   end record;

   --  The read state saved for nesting.
   type Saved_Read is record
      Read : Context_Read;
      Outcome : Read_Outcome;
   end record;

   procedure Begin_Context_Read
     (Read : Context_Read; Previous : out Saved_Read);

   procedure End_Context_Read
     (Previous : Saved_Read; Outcome : out Read_Outcome);

   --  Hands the errors published while this thread held the DOM lock to
   --  their handlers; called once the lock is released.
   procedure Dispatch_Deferred;

   --  The fields of the thread's error mark (XML3_Error_Records.Error_Mark).
   procedure Current_Mark
     (Serial, Fatal_Serial, Error_Serial : out Interfaces.Unsigned_64;
      Error_Code : out Interfaces.C.int);

   procedure Destroy_State (State : System.Address)
     with Convention => C;

end XML3_Errors;
