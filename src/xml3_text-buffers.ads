with System;
with XML3_Native_Memory;

package XML3_Text.Buffers with SPARK_Mode is
   use type System.Address;

   type Concatenate_Status is (Copied, No_Input, No_Memory, Limit_Exceeded);

   type Search_Status is (No_Match, Matched, Search_Limit_Exceeded);

   procedure Find_Byte
     (Item : System.Address; Value : Character;
      Position : out Byte_Count; Status : out Search_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Matched then
         Item /= System.Null_Address and then Value /= Character'Val (0)
           and then Position < Max_Bytes
         else Position = 0);

   function Compare_Bounded
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean)
      return Integer
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Compare_Bounded'Result in -255 .. 255;

   function Fits (Left_Length, Right_Length : Natural) return Boolean is
     (Left_Length <= Max_Bytes
      and then Right_Length <= Max_Bytes - Left_Length)
     with Global => null;

   procedure Concatenate
     (Left, Right : String; Has_Left, Has_Right : Boolean;
      Result : out System.Address; Status : out Concatenate_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => (Has_Left or else Left'Length = 0)
         and then (Has_Right or else Right'Length = 0),
       Post => (if Status = Copied then Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Duplicate (Input : String; Result : out System.Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input'Length <= Max_Bytes;
end XML3_Text.Buffers;
