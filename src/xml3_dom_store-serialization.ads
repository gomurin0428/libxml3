with System;
with XML3_DOM_Constructors;
with XML3_Native_Memory;

package XML3_DOM_Store.Serialization with SPARK_Mode is
   procedure Dump
     (S : Store; Document, Encoding : System.Address;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status;
      Formatted : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Length <= Integer'Last - 1
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address
         else Result = System.Null_Address and then Length = 0);
end XML3_DOM_Store.Serialization;
