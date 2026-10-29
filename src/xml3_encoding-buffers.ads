with System;
with XML3_Native_Memory;

package XML3_Encoding.Buffers with SPARK_Mode is
   use type System.Address;

   function Classify_Bytes (Name : System.Address) return Encoding_Kind
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Name = System.Null_Address then
         Classify_Bytes'Result = Unspecified
         else Classify_Bytes'Result /= Unspecified);
end XML3_Encoding.Buffers;
