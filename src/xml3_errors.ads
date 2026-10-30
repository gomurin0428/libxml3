with Interfaces.C;
with System;
with XML3_Error_Records;

package XML3_Errors is

   subtype Error_Record is XML3_Error_Records.Error_Record;

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
