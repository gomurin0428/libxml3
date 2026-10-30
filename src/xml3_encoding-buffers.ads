with System;
with XML3_Native_Memory;

package XML3_Encoding.Buffers with SPARK_Mode is
   use type System.Address;

   type Conversion_Result is
     (Converted, Invalid_UTF16, Conversion_No_Memory, Conversion_Limit_Exceeded);

   procedure Convert_UTF16
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Little_Endian : Boolean; Result : out System.Address;
      Length : out XML3_Text.Byte_Count; Status : out Conversion_Result;
      Limit : XML3_Text.Byte_Count := XML3_Text.Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input /= System.Null_Address,
       Post => (if Status = Converted then Result /= System.Null_Address
                  and then Length <= Limit
                else Result = System.Null_Address and then Length = 0);

   function Classify_Bytes (Name : System.Address) return Encoding_Kind
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Name = System.Null_Address then
         Classify_Bytes'Result = Unspecified
         else Classify_Bytes'Result /= Unspecified);
end XML3_Encoding.Buffers;
