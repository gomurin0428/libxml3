package XML3_DOM.Releases with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Take_Release
     (S : in out State; B : out Owner_Ref; Address : out System.Address)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S) and then not Projection_Required (S),
     Post => Valid (S) and then not Projection_Required (S)
       and then Live_Entries_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then (if B = Null_Owner then Can_Edit (S)
           and then Address = System.Null_Address and then Same_Graph (S, S'Old)
         else Phase (S) = Release_Pending
           and then B = Active_Release (S)
           and then Release_Cursor (S) = Natural (B)
           and then Release_Cursor (S) > Release_Cursor (S'Old)
           and then B in 1 .. Owner_Ref (Owner_Count (S))
           and then Owner (S, B).State = Releasing
           and then Owner (S, B).References = 0
           and then Owner (S, B).Reservations = 0
           and then Owner (S, B).Release_Emitted
           and then not Owner (S'Old, B).Release_Emitted
           and then Address = Owner (S, B).Address);

   procedure Acknowledge_Release (S : in out State; B : Owner_Ref)
   with Global => null,
     Pre => Valid (S) and then Phase (S) = Release_Pending
       and then B = Active_Release (S)
       and then B in 1 .. Owner_Ref (Owner_Count (S))
       and then Owner (S, B).State = Releasing
       and then Owner (S, B).References = 0
       and then Owner (S, B).Reservations = 0
       and then Owner (S, B).Release_Emitted,
     Post => Valid (S) and then Can_Edit (S)
       and then not Projection_Required (S)
       and then Live_Entries_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then Release_Cursor (S) = Release_Cursor (S)'Old
       and then Owner (S, B).State = Unused
       and then (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (Node (S, N).State = Unused or else Node (S, N).Owner /= B))
       and then (for all N in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) =>
         (Namespace (S, N).State = Unused or else Namespace (S, N).Owner /= B));

end XML3_DOM.Releases;
