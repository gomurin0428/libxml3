with System;
with XML3_Native_Memory;

package XML3_Text.Buffers with SPARK_Mode is
   procedure Duplicate (Input : String; Result : out System.Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input'Length <= Max_Bytes;
end XML3_Text.Buffers;
