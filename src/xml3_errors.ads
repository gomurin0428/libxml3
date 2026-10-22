with Interfaces.C;
with System;

package XML3_Errors is

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
   end record
     with Convention => C;

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

   procedure Destroy_State (State : System.Address)
     with Convention => C;

end XML3_Errors;
