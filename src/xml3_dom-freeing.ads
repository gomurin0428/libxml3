private package XML3_DOM.Freeing with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   function Retired_View (Item : Node_View) return Node_View is
     ((Item with delta State => Tombstone,
       Parent => 0, First_Child => 0, Last_Child => 0,
       Previous => 0, Next => 0, First_Prop => 0, Last_Prop => 0,
       Document => 0, Namespace => 0, Ns_Pin => 0, Doc_Pin => 0,
       Content_Pin => 0, Name_Pin => 0,
       Content => System.Null_Address, Content_Length => 0));

   procedure Retire_Node (S : in out State; N : Node_Ref)
   with Global => null,
     Pre => Well_Sized (S) and then Effects_Valid (S)
       and then Can_Edit (S) and then Projection_Required (S)
       and then Pins_In_Range (S) and then Pin_Equation (S)
       and then N in 1 .. Node_Ref (S.Graph.Node_Used)
       and then S.Graph.Nodes (Positive (N)).State = Live
       and then (for all I in 1 .. S.Graph.Node_Used => Node_Pins_Valid (S.Graph, I)),
     Post => S.Effects = S.Effects'Old and then Well_Sized (S)
       and then Effects_Valid (S) and then Pins_In_Range (S) and then Pin_Equation (S)
       and then S.Graph.Node_Used = S.Graph.Node_Used'Old
       and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
       and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
       and then S.Graph.Namespaces = S.Graph.Namespaces'Old
       and then S.Marks = S.Marks'Old
       and then S.Capacity = S.Capacity'Old
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (S.Graph.Owner_Used) =>
           (if not Holds (S.Graph.Nodes'Old (Positive (N)), B) then
             S.Graph.Owners (Positive (B)) =
               S.Graph.Owners'Old (Positive (B))))
       and then (for all B in 1 .. S.Graph.Owner_Used =>
         (if S.Graph.Owners'Old (B).State /= Live then
           S.Graph.Owners (B) = S.Graph.Owners'Old (B)))
       and then (for all J in 1 .. S.Capacity =>
         S.Graph.Nodes (J) =
           (if J = Positive (N)
            then Retired_View (S.Graph.Nodes'Old (J))
            else S.Graph.Nodes'Old (J)))
       and then (for all I in 1 .. S.Graph.Owner_Used =>
         (if S.Graph.Owners'Old (I).State in Live | Releasing then
           S.Graph.Owners (I).State in Live | Releasing))
       and then (for all I in 1 .. S.Graph.Owner_Used =>
         S.Graph.Owners (I).Reservations =
           S.Graph.Owners'Old (I).Reservations
         and then (if S.Graph.Owners'Old (I).State = Live
           and then S.Graph.Owners'Old (I).Reservations > 0 then
           S.Graph.Owners (I).State = Live))
       and then (for all I in 1 .. S.Graph.Node_Used => Node_Pins_Valid (S.Graph, I))
       and then (if Facades_Present (S'Old) then Facades_Present (S));

   procedure Retired_Links_Lemma
     (Before, After : Graph_State; Marks : Mark_Array)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Node_Used = After.Node_Used
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Owner_Used = After.Owner_Used
       and then Marks'First = 1 and then Marks'Last >= Before.Node_Used
       and then (for all I in 1 .. Before.Ns_Used =>
         Before.Namespaces (I) = After.Namespaces (I))
       and then (for all I in 1 .. Before.Node_Used =>
         Node_Links_Valid (Before, I)
         and then Node_Pins_Valid (After, I)
         and then (if Marks (I) then Before.Nodes (I).State = Live)
         and then After.Nodes (I) =
           (if Marks (I) then Retired_View (Before.Nodes (I))
            else Before.Nodes (I))
         and then (if Before.Nodes (I).State = Live
           and then Before.Nodes (I).Parent /= 0
           then Marks (I) = Marks (Positive (Before.Nodes (I).Parent)))),
     Post => (for all I in 1 .. After.Node_Used => Node_Links_Valid (After, I));

   procedure Marked_Text_Declarations_Clear (S : State; Root : Node_Ref)
     with Ghost, Global => null,
       Pre => Valid (S)
         and then Root in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, Root).State = Live
         and then Node (S, Root).Kind = Text_Node
         and then (for all I in 1 .. S.Graph.Node_Used =>
           S.Marks (I) = (Node_Ref (I) = Root)),
       Post => (for all I in 1 .. S.Graph.Ns_Used =>
         (if S.Graph.Namespaces (I).State = Live
           and then S.Graph.Namespaces (I).Owns_Reservation
           and then S.Graph.Namespaces (I).Parent /= Null_Node then
             not S.Marks (Positive (S.Graph.Namespaces (I).Parent))));

   procedure Free_Marked_Subtree (S : in out State; Root : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live
       and then S.Marks (Positive (Root))
       and then (for all I in 1 .. S.Graph.Ns_Used =>
         (if S.Graph.Namespaces (I).State = Live
           and then S.Graph.Namespaces (I).Owns_Reservation
           and then S.Graph.Namespaces (I).Parent /= Null_Node
          then not S.Marks (Positive (S.Graph.Namespaces (I).Parent))))
       and then (for all I in 1 .. S.Graph.Node_Used =>
         (if S.Marks (I) then S.Graph.Nodes (I).State = Live)
         and then (if S.Graph.Nodes (I).State = Live
           and then S.Graph.Nodes (I).Parent /= Null_Node
           and then Node_Ref (I) /= Root then
             S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent)))),
     Post => Valid (S) and then Can_Edit (S)
       and then S.Capacity = S'Old.Capacity
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           (if Owner (S'Old, B).State /= Live then
             Owner (S, B) = Owner (S'Old, B)))
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then Same_Marks (S, S'Old)
       and then (if (for all I in 1 .. S.Graph.Node_Used =>
         S.Marks (I) = (Node_Ref (I) = Root)) then
           (for all B in Owner_Ref range
             1 .. Owner_Ref (Owner_Count (S'Old)) =>
               (if not Holds (Node (S'Old, Root), B) then
                 Owner (S, B) = Owner (S'Old, B))))
       and then Node (S, Root).State = Tombstone
       and then Projection_Required (S)
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (if S.Marks (Positive (I)) then Node (S, I).State = Tombstone
          else Node (S, I) = Unlinked_View (S'Old, Root, I)))
       and then Facades_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then (if Node (S'Old, Root).Parent = Null_Node
         and then (for all I in 1 .. S.Graph.Node_Used =>
           S.Marks (I) = (Node_Ref (I) = Root)) then
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S'Old)) =>
             (if I /= Root then Node (S, I) = Node (S'Old, I))))
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           Owner (S, B).Reservations = Owner (S'Old, B).Reservations
           and then (if Owner (S'Old, B).State = Live
             and then Owner (S'Old, B).Reservations > 0 then
             Owner (S, B).State = Live));

end XML3_DOM.Freeing;
