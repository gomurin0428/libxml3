with XML3_DOM;
with XML3_Native_Memory;
with System;

package XML3_DOM_Bridge with SPARK_Mode is
   use XML3_DOM;
   use type System.Address;

   function Facades_Present (S : State) return Boolean
     renames XML3_DOM.Facades_Present;

   procedure Synchronize (S : in out State)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Valid (S) and then Can_Edit (S) and then Facades_Present (S),
       Post => Valid (S) and then Can_Edit (S)
         and then not Projection_Required (S)
         and then Facades_Present (S)
         and then Live_Entries_Preserved (S'Old, S),
       Always_Terminates;
end XML3_DOM_Bridge;
