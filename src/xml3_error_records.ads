with Interfaces.C;
with System;
with XML3_Native_Memory;
with XML3_Text;

package XML3_Error_Records with SPARK_Mode is
   use type System.Address;
   use type Interfaces.C.int;

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
end XML3_Error_Records;
