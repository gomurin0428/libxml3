with XML3_DOM;
with XML3_Native_Memory;
with System;

package XML3_DOM_Bridge with SPARK_Mode is
   use XML3_DOM;
   use type System.Address;

   function Facades_Present (S : State) return Boolean is
     ((for all N in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
        (if Node (S, N).State in Live | Tombstone then
           Node (S, N).Facade /= System.Null_Address))
      and then (for all N in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) =>
        (if Namespace (S, N).State = Live then
           Namespace (S, N).Facade /= System.Null_Address)))
     with Ghost, Global => null, Pre => Well_Sized (S);

   procedure Synchronize (S : in out State)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Valid (S) and then Can_Edit (S) and then Facades_Present (S),
       Post => Valid (S) and then Can_Edit (S)
         and then not Projection_Required (S)
         and then Live_Entries_Preserved (S'Old, S),
       Always_Terminates;
end XML3_DOM_Bridge;
