with System;
with XML3_DOM;
with XML3_DOM_Constructors;
with XML3_Native_Memory;

package XML3_Serialization with SPARK_Mode is
   use type System.Address;
   use type XML3_DOM.Node_Ref;
   use type XML3_DOM_Constructors.Construction_Status;

   Max_Output_Bytes : constant := Integer'Last - 1;

   procedure Render
     (Tree : XML3_DOM.State; Document : XML3_DOM.Node_Ref;
      Encoding : String; Result : out System.Address;
      Length : out Natural;
      Status : out XML3_DOM_Constructors.Construction_Status;
      Default_Encoding, Formatted : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => XML3_DOM.Valid (Tree)
         and then Document in
           1 .. XML3_DOM.Node_Ref (XML3_DOM.Capacity_Of (Tree)),
       Post => Length <= Max_Output_Bytes
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address
         else Result = System.Null_Address and then Length = 0);
end XML3_Serialization;
