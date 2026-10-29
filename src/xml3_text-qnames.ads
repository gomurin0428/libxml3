with System;
with XML3_Native_Memory;

package XML3_Text.QNames with SPARK_Mode is
   use type System.Address;
   type Split_Status is (No_Prefix, Split_Done, No_Memory, Split_Limit_Exceeded);
   type Build_Status is (Built, Invalid_Argument, No_Memory, Limit_Exceeded);

   type Comparison_Status is (Different, Same, Comparison_Limit_Exceeded);

   type Prefix_Status is (Prefix_Absent, Prefix_Found, Prefix_Limit_Exceeded);

   procedure Locate_Prefix
     (Input : System.Address; Count : out Byte_Count; Local : out System.Address;
      Status : out Prefix_Status; Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Prefix_Found then
         Input /= System.Null_Address and then Count > 0 and then Count < Last
         else Count = 0 and then Local = System.Null_Address)
         and then (if Input = System.Null_Address then Status = Prefix_Absent);

   procedure Compare
     (Prefix, Name, Value : System.Address; Status : out Comparison_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Same then
         (Prefix = System.Null_Address and then Name = Value)
           or else (Name /= System.Null_Address and then
                    Value /= System.Null_Address));

   procedure Build
     (Name, Prefix, Buffer : System.Address; Capacity : Integer;
      Result : out System.Address; Status : out Build_Status;
      Limit : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Built then Result /= System.Null_Address
         else Result = System.Null_Address);

   function Prefix_Length (Input : String) return Byte_Count
     with Global => null,
       Pre => Input'First = 1 and then Input'Last in 0 .. Max_Bytes,
       Post => (if Prefix_Length'Result /= 0 then
         Prefix_Length'Result + 1 < Input'Length
         and then Input (Prefix_Length'Result + 1) = ':'
         and then (for all I in 1 .. Prefix_Length'Result => Input (I) /= ':'));

   procedure Split
     (Input : System.Address; Prefix, Local : out System.Address;
      Status : out Split_Status; Last : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Split_Done then
         Prefix /= System.Null_Address and then Local /= System.Null_Address
         else Prefix = System.Null_Address and then Local = System.Null_Address)
         and then (if Input = System.Null_Address then Status = No_Prefix);
end XML3_Text.QNames;
