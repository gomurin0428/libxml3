with System;
with XML3_Native_Memory;

package XML3_Text.QNames with SPARK_Mode is
   use type System.Address;
   type Split_Status is (No_Prefix, Split_Done, No_Memory);
   type Build_Status is (Built, Invalid_Argument, No_Memory, Limit_Exceeded);

   procedure Build
     (Name, Prefix : String; Original, Buffer : System.Address;
      Has_Prefix : Boolean; Capacity : Integer;
      Result : out System.Address; Status : out Build_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Name'First = 1 and then Name'Last in 0 .. Max_Bytes
         and then Prefix'First = 1 and then Prefix'Last in 0 .. Max_Bytes,
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
     (Input : String; Prefix, Local : out System.Address;
      Status : out Split_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input'First = 1 and then Input'Last in 0 .. Max_Bytes,
       Post => (if Status = Split_Done then
         Prefix /= System.Null_Address and then Local /= System.Null_Address
         else Prefix = System.Null_Address and then Local = System.Null_Address);
end XML3_Text.QNames;
