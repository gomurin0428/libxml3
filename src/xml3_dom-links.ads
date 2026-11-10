with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
private package XML3_DOM.Links with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Unlink_Lemma (Before, After : State; N : Node_Ref)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then Before.Capacity = After.Capacity
         and then Before.Graph.Node_Used = After.Graph.Node_Used
         and then Before.Graph.Owner_Used = After.Graph.Owner_Used
         and then Before.Graph.Ns_Used = After.Graph.Ns_Used
         and then (for all I in 1 .. Before.Capacity =>
           Before.Graph.Owners (I) = After.Graph.Owners (I))
         and then Before.Graph.Namespaces = After.Graph.Namespaces
         and then N in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then Before.Graph.Nodes (Positive (N)).State = Live
         and then (for all I in 1 .. Before.Graph.Node_Used =>
           Node_Links_Valid (Before.Graph, I))
         and then (for all I in 1 .. Before.Graph.Node_Used =>
           After.Graph.Nodes (I) = Unlinked_View (Before, N, Node_Ref (I))),
       Post => Before.Graph.Namespaces = After.Graph.Namespaces
         and then (for all I in 1 .. After.Graph.Node_Used =>
           Node_Links_Valid (After.Graph, I)
           and then After.Graph.Nodes (I) = Unlinked_View (Before, N, Node_Ref (I)));

   procedure Unlink_Tail_Lemma
     (S : State; Parent, Child : Node_Ref; Property : Boolean)
   with Ghost, Global => null,
     Pre => Valid (S)
       and then Parent in 1 .. Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Parent /= Child
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live
       and then Property = (Node (S, Child).Kind = Attribute_Node)
       and then (declare
         Tail : constant Node_Ref :=
           (if Property then Node (S, Parent).Last_Prop
            else Node (S, Parent).Last_Child);
        begin Tail = Null_Node or else
          (Tail in 1 .. Node_Ref (Node_Count (S)) and then Tail /= Child)),
     Post => (declare
       Tail : constant Node_Ref :=
         (if Property then Node (S, Parent).Last_Prop
          else Node (S, Parent).Last_Child);
      begin
        (if Property then
           Unlinked_View (S, Child, Parent).Last_Prop = Tail
         else
           Unlinked_View (S, Child, Parent).Last_Child = Tail)
        and then (if Tail /= Null_Node then
          Unlinked_View (S, Child, Tail).Sibling_Order =
            Node (S, Tail).Sibling_Order));

   function Appended_View
     (S : State; Parent, Child, I : Node_Ref; Position : Natural) return Node_View
   is
     (declare
        Original : constant Node_View := Node (S, I);
        P : constant Node_View := Node (S, Parent);
        Property : constant Boolean := Node (S, Child).Kind = Attribute_Node;
        Last : constant Node_Ref := (if Property then P.Last_Prop else P.Last_Child);
      begin
        (if I = Child then
           (Original with delta Parent => Parent, Previous => Last,
              Next => 0, Sibling_Order => Position)
         elsif I = Parent then
           (Original with delta
              First_Child =>
                (if not Property and then P.First_Child = 0 then Child else P.First_Child),
              Last_Child => (if Property then P.Last_Child else Child),
              First_Prop =>
                (if Property and then P.First_Prop = 0 then Child else P.First_Prop),
              Last_Prop => (if Property then Child else P.Last_Prop))
         elsif I = Last then
           (Original with delta Next => Child)
         else Original))
     with Ghost, Pre => Well_Sized (S)
       and then Parent in 1 .. Node_Ref (S.Graph.Node_Used)
       and then Child in 1 .. Node_Ref (S.Graph.Node_Used)
       and then I in 1 .. Node_Ref (S.Graph.Node_Used);

   procedure Append_Lemma
     (Before, After : State; Parent, Child : Node_Ref; Position : Natural)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then Before.Graph.Node_Used = After.Graph.Node_Used
         and then Before.Graph.Owner_Used = After.Graph.Owner_Used
         and then Before.Graph.Ns_Used = After.Graph.Ns_Used
         and then (for all I in 1 .. Before.Graph.Owner_Used =>
           Before.Graph.Owners (I) = After.Graph.Owners (I))
         and then (for all I in 1 .. Before.Graph.Ns_Used =>
           Before.Graph.Namespaces (I) = After.Graph.Namespaces (I))
         and then Parent in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then Child in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then Parent /= Child
         and then Before.Graph.Nodes (Positive (Parent)).State = Live
         and then Before.Graph.Nodes (Positive (Child)).State = Live
         and then Before.Graph.Nodes (Positive (Child)).Parent = 0
         and then (for all I in 1 .. Before.Graph.Node_Used =>
           Node_Links_Valid (Before.Graph, I))
         and then Before.Graph.Nodes (Positive (Parent)).Tree_Rank <
           Before.Graph.Nodes (Positive (Child)).Tree_Rank
         and then (declare
           P : constant Node_View := Before.Graph.Nodes (Positive (Parent));
           Last : constant Node_Ref :=
             (if Before.Graph.Nodes (Positive (Child)).Kind = Attribute_Node
              then P.Last_Prop else P.Last_Child);
         begin Last = 0 or else
           Before.Graph.Nodes (Positive (Last)).Sibling_Order < Position)
         and then (for all I in 1 .. Before.Graph.Node_Used =>
           After.Graph.Nodes (I) = Appended_View (Before, Parent, Child, Node_Ref (I), Position)),
       Post => (for all I in 1 .. After.Graph.Node_Used =>
           Node_Links_Valid (After.Graph, I))
         and then (for all I in 1 .. After.Graph.Node_Used =>
           After.Graph.Nodes (I).State = Before.Graph.Nodes (I).State
             and then After.Graph.Nodes (I).Facade =
               Before.Graph.Nodes (I).Facade
             and then After.Graph.Nodes (I).Document =
               Before.Graph.Nodes (I).Document
             and then After.Graph.Nodes (I).Doc_Pin =
               Before.Graph.Nodes (I).Doc_Pin
             and then Same_Pins
               (Before.Graph.Nodes (I), After.Graph.Nodes (I)));

   procedure Append_Child_Links
     (S : in out State; Parent, Child : Node_Ref; Position : Natural)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Parent /= Child
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live
       and then Node (S, Child).Parent = Null_Node
       and then Node (S, Parent).Tree_Rank < Node (S, Child).Tree_Rank
       and then (declare
         Property : constant Boolean :=
           Node (S, Child).Kind = Attribute_Node;
         Last : constant Node_Ref :=
           (if Property then Node (S, Parent).Last_Prop
            else Node (S, Parent).Last_Child);
        begin Last = Null_Node or else
          (Last in 1 .. Node_Ref (Node_Count (S))
           and then Node (S, Last).Sibling_Order < Position)),
     Post => Valid (S) and then Can_Edit (S)
       and then S.Capacity = S.Capacity'Old
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then S.Marks = S.Marks'Old
       and then S.Effects = S.Effects'Old
       and then (for all I in Namespace_Ref range
         1 .. Namespace_Ref (Namespace_Count (S)) =>
           Namespace (S, I) = Namespace (S'Old, I))
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then (for all I in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S)) =>
           Owner (S, I) = Owner (S'Old, I))
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I) = Appended_View (S'Old, Parent, Child, I, Position)
             and then Same_Pins (Node (S, I), Node (S'Old, I))
             and then Node (S, I).Kind = Node (S'Old, I).Kind
             and then Node (S, I).Facade = Node (S'Old, I).Facade
             and then Node (S, I).Document = Node (S'Old, I).Document)
       and then (if Node (S'Old, Child).Kind = Attribute_Node
         then Node (S, Parent).Last_Prop = Child
           and then Node (S, Child).Next = Null_Node
         else Node (S, Parent).Last_Child = Child
           and then Node (S, Child).Next = Null_Node)
       and then Node (S, Child).Parent = Parent;

   function Replaced_View
     (S : State; Parent, New_Child, Old_Child, I : Node_Ref) return Node_View
   is
     (declare
        Original : constant Node_View := Node (S, I);
        P : constant Node_View := Node (S, Parent);
        O : constant Node_View := Node (S, Old_Child);
      begin
        (if I = New_Child then
           (Original with delta
              Parent => Parent,
              Previous => O.Previous,
              Next => O.Next,
              Sibling_Order => O.Sibling_Order)
         elsif I = Old_Child then
           (Original with delta Parent => Null_Node, Previous => Null_Node,
              Next => Null_Node)
         elsif I = Parent then
           (Original with delta
              First_Child =>
                (if P.First_Child = Old_Child then New_Child else P.First_Child),
              Last_Child =>
                (if P.Last_Child = Old_Child then New_Child else P.Last_Child))
         elsif I = O.Previous then
           (Original with delta Next => New_Child)
         elsif I = O.Next then
           (Original with delta Previous => New_Child)
         else Original))
     with Ghost,
       Pre => Well_Sized (S)
         and then Parent in 1 .. Node_Ref (S.Graph.Node_Used)
         and then New_Child in 1 .. Node_Ref (S.Graph.Node_Used)
         and then Old_Child in 1 .. Node_Ref (S.Graph.Node_Used)
         and then I in 1 .. Node_Ref (S.Graph.Node_Used);

   --  Replacing a child only moves tree links; the namespace fields of
   --  every node are unchanged.
   procedure Replaced_Namespace_Fields
     (Before, After : State; Parent, New_Child, Old_Child : Node_Ref)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then After.Graph.Node_Used = Before.Graph.Node_Used
         and then Parent in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then New_Child in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then Old_Child in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (After)) =>
           Node (After, I) =
             Replaced_View (Before, Parent, New_Child, Old_Child, I)),
       Post => (for all I in 1 .. After.Graph.Node_Used =>
         Namespace_Parent_Preserved
           (Before.Graph.Nodes (I), After.Graph.Nodes (I)));

   procedure Replace_Lemma
     (Before, After : State; Parent, New_Child, Old_Child : Node_Ref)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then Before.Capacity = After.Capacity
         and then Before.Graph.Node_Used = After.Graph.Node_Used
         and then Before.Graph.Owner_Used = After.Graph.Owner_Used
         and then Before.Graph.Ns_Used = After.Graph.Ns_Used
         and then (for all I in 1 .. Before.Capacity =>
           Before.Graph.Owners (I) = After.Graph.Owners (I)
           and then Before.Graph.Namespaces (I) = After.Graph.Namespaces (I))
         and then Parent in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then New_Child in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then Old_Child in 1 .. Node_Ref (Before.Graph.Node_Used)
         and then Parent /= New_Child
         and then Parent /= Old_Child
         and then New_Child /= Old_Child
         and then Before.Graph.Nodes (Positive (Parent)).State = Live
         and then Before.Graph.Nodes (Positive (New_Child)).State = Live
         and then Before.Graph.Nodes (Positive (New_Child)).Parent = Null_Node
         and then Before.Graph.Nodes (Positive (Old_Child)).State = Live
         and then Before.Graph.Nodes (Positive (Old_Child)).Kind = Element_Node
         and then Before.Graph.Nodes (Positive (Old_Child)).Parent = Parent
         and then Before.Graph.Nodes (Positive (Parent)).Kind = Document_Node
         and then Before.Graph.Nodes (Positive (New_Child)).Kind = Element_Node
         and then Before.Graph.Nodes (Positive (Parent)).Tree_Rank <
           Before.Graph.Nodes (Positive (New_Child)).Tree_Rank
         and then (for all I in 1 .. Before.Graph.Node_Used =>
           Node_Links_Valid (Before.Graph, I))
         and then (for all I in 1 .. Before.Graph.Node_Used =>
           After.Graph.Nodes (I) =
             Replaced_View (Before, Parent, New_Child, Old_Child, Node_Ref (I))),
       Post => (for all I in 1 .. After.Graph.Node_Used =>
           Node_Links_Valid (After.Graph, I))
         and then (for all I in 1 .. After.Graph.Node_Used =>
           After.Graph.Nodes (I).State = Before.Graph.Nodes (I).State
             and then After.Graph.Nodes (I).Document =
               Before.Graph.Nodes (I).Document
             and then After.Graph.Nodes (I).Doc_Pin =
               Before.Graph.Nodes (I).Doc_Pin);

   procedure Replace_Child_Links
     (S : in out State; Parent, New_Child, Old_Child : Node_Ref)
     with Global => null,
       Pre => Valid (S) and then Can_Edit (S)
         and then Parent in 1 .. Node_Ref (Node_Count (S))
         and then New_Child in 1 .. Node_Ref (Node_Count (S))
         and then Old_Child in 1 .. Node_Ref (Node_Count (S))
         and then Parent /= New_Child
         and then Parent /= Old_Child
         and then New_Child /= Old_Child
         and then Node (S, Parent).State = Live
         and then Node (S, Parent).Kind = Document_Node
         and then Node (S, New_Child).State = Live
         and then Node (S, New_Child).Kind = Element_Node
         and then Node (S, New_Child).Parent = Null_Node
         and then Node (S, Old_Child).State = Live
         and then Node (S, Old_Child).Kind = Element_Node
         and then Node (S, Old_Child).Parent = Parent
         and then Node (S, Parent).Tree_Rank <
           Node (S, New_Child).Tree_Rank
         and then (for all I in 1 .. Node_Count (S) =>
           Node_Links_Valid (S.Graph, I)),
       Post => (declare
         Before_Namespaces : constant Namespace_View_Array :=
           Snapshot_Namespaces (S)'Old;
         Before_Owners : constant Owner_View_Array := Snapshot_Owners (S)'Old;
       begin Valid (S) and then Can_Edit (S)
         and then S.Capacity = S'Old.Capacity
         and then Same_Marks (S, S'Old)
         and then Node_Count (S) = Node_Count (S'Old)
         and then Namespace_Count (S) = Namespace_Count (S'Old)
         and then Owner_Count (S) = Owner_Count (S'Old)
         and then S.Effects = S'Old.Effects
         and then (for all I in 1 .. S.Capacity =>
           S.Graph.Namespaces (I) = Before_Namespaces (I)
           and then S.Graph.Owners (I) = Before_Owners (I))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S)) =>
             Namespace (S, I) = Namespace (S'Old, I))
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S)) =>
             Node (S, I).State = Node (S'Old, I).State
             and then Node (S, I).Facade = Node (S'Old, I).Facade
             and then Node (S, I).Document = Node (S'Old, I).Document
             and then Node (S, I).Doc_Pin = Node (S'Old, I).Doc_Pin)
         and then Node (S, New_Child).Parent = Parent
         and then Node (S, New_Child).State = Live
         and then Node (S, Old_Child) =
           Unlinked_View (S'Old, Old_Child, Old_Child)
         and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I) =
             Replaced_View (S'Old, Parent, New_Child, Old_Child, I)));

   function Placed_View
     (S : State; Parent, Child, Old_Last, Previous, Next : Node_Ref;
      Threshold, Old_Order : Natural; I : Node_Ref) return Node_View
   is
     (declare
        Original : constant Node_View := Node (S, I);
        Shifted : constant Boolean :=
          Original.State = Live
            and then Original.Parent = Parent
            and then Original.Kind /= Attribute_Node
            and then Original.Sibling_Order >= Threshold
            and then Original.Sibling_Order < Old_Order;
      begin
        (if I = Child then
           (Original with delta
              Previous => Previous, Next => Next,
              Sibling_Order => Threshold)
         elsif I = Parent then
           (Original with delta
              First_Child => (if Previous = Null_Node
                              then Child else Original.First_Child),
              Last_Child => Old_Last)
         elsif I = Old_Last then
           (Original with delta
              Previous => (if Next = Old_Last then Child
                           else Original.Previous),
              Next => Null_Node,
              Sibling_Order => (if Shifted
                                then Original.Sibling_Order + 1
                                else Original.Sibling_Order))
         elsif Previous /= Null_Node and then I = Previous then
           (Original with delta
              Next => Child,
              Sibling_Order => (if Shifted
                                then Original.Sibling_Order + 1
                                else Original.Sibling_Order))
         elsif Next /= Null_Node and then I = Next then
           (Original with delta
              Previous => Child,
              Sibling_Order => (if Shifted
                                then Original.Sibling_Order + 1
                                else Original.Sibling_Order))
         elsif Shifted then
           (Original with delta Sibling_Order =>
              Original.Sibling_Order + 1)
         else Original))
     with Ghost, Global => null,
       Pre => Well_Sized (S)
         and then Parent in 1 .. Node_Ref (Node_Count (S))
         and then Child in 1 .. Node_Ref (Node_Count (S))
         and then Old_Last in 1 .. Node_Ref (Node_Count (S))
         and then (Previous = Null_Node
           or else Previous in 1 .. Node_Ref (Node_Count (S)))
         and then Next in 1 .. Node_Ref (Node_Count (S))
         and then I in 1 .. Node_Ref (Node_Count (S));

   procedure Tail_Order_Bound
     (S : State; Parent, N : Node_Ref)
   with Ghost, Global => null,
     Pre => Valid (S) and then Parent in 1 .. Node_Ref (Node_Count (S))
       and then N in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Parent).State = Live
       and then Node (S, Parent).Last_Child /= Null_Node
       and then Node (S, N).State = Live
       and then Node (S, N).Parent = Parent
       and then Node (S, N).Kind /= Attribute_Node,
     Post => Node (S, N).Sibling_Order <=
         Node (S, Node (S, Parent).Last_Child).Sibling_Order
       and then (if N /= Node (S, Parent).Last_Child then
         Node (S, N).Sibling_Order <
           Node (S, Node (S, Parent).Last_Child).Sibling_Order)
       and then (if N /= Node (S, Parent).Last_Child then
         Node (S, Node (S, Parent).Last_Child).Previous /= Null_Node);

   function Placement_Ready
     (S : State; Parent, Child, Old_Last, Previous, Next : Node_Ref;
      Threshold, Old_Order : Natural) return Boolean
   is
     (Parent in 1 .. Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Old_Last in 1 .. Node_Ref (Node_Count (S))
       and then Next in 1 .. Node_Ref (Node_Count (S))
       and then (Previous = Null_Node
         or else Previous in 1 .. Node_Ref (Node_Count (S)))
       and then Parent /= Child and then Parent /= Old_Last
       and then Parent /= Previous and then Parent /= Next
       and then Child /= Old_Last and then Child /= Previous
       and then Child /= Next and then Previous /= Next
       and then Old_Last /= Previous
       and then Node (S, Parent).State = Live
       and then Node (S, Parent).Last_Child = Child
       and then Node (S, Parent).First_Child /= Child
       and then Node (S, Child).State = Live
       and then Node (S, Child).Kind /= Attribute_Node
       and then Node (S, Child).Parent = Parent
       and then Node (S, Child).Previous = Old_Last
       and then Node (S, Child).Next = Null_Node
       and then Node (S, Old_Last).State = Live
       and then Node (S, Old_Last).Kind /= Attribute_Node
       and then Node (S, Old_Last).Parent = Parent
       and then Node (S, Old_Last).Next = Child
       and then Node (S, Next).State = Live
       and then Node (S, Next).Kind /= Attribute_Node
       and then Node (S, Next).Parent = Parent
       and then Node (S, Next).Previous = Previous
       and then (if Previous = Null_Node then
         Node (S, Parent).First_Child = Next
         else Node (S, Previous).State = Live
           and then Node (S, Previous).Kind /= Attribute_Node
           and then Node (S, Previous).Parent = Parent
           and then Node (S, Previous).Next = Next
           and then Node (S, Previous).Sibling_Order < Threshold)
       and then Old_Order = Node (S, Child).Sibling_Order
       and then Threshold <= Node (S, Next).Sibling_Order
       and then Node (S, Next).Sibling_Order < Old_Order)
     with Ghost, Global => null, Pre => Well_Sized (S);

   procedure Placed_Lemma
     (Before, After : State; Parent, Child, Old_Last, Previous, Next : Node_Ref;
      Threshold, Old_Order : Natural)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Graph.Node_Used = After.Graph.Node_Used
       and then Before.Graph.Ns_Used = After.Graph.Ns_Used
       and then Before.Graph.Owner_Used = After.Graph.Owner_Used
       and then Before.Capacity = After.Capacity
       and then Valid (Before)
       and then Before.Marks = After.Marks
       and then (for all I in 1 .. Before.Graph.Ns_Used =>
         Before.Graph.Namespaces (I) = After.Graph.Namespaces (I))
       and then (for all I in 1 .. Before.Graph.Owner_Used =>
         Before.Graph.Owners (I) = After.Graph.Owners (I))
       and then Placement_Ready
         (Before, Parent, Child, Old_Last, Previous, Next, Threshold, Old_Order)
       and then (for all I in 1 .. Before.Graph.Node_Used =>
         Node_Links_Valid (Before.Graph, I))
       and then (for all I in 1 .. Before.Graph.Node_Used =>
         After.Graph.Nodes (I) =
           Placed_View
             (Before, Parent, Child, Old_Last, Previous, Next,
              Threshold, Old_Order, Node_Ref (I))),
     Post => (for all I in 1 .. After.Graph.Node_Used =>
         Node_Links_Valid (After.Graph, I));

   procedure Place_Tail_Sibling
     (S : in out State; Parent, Child, Old_Last, Previous, Next : Node_Ref;
      Threshold, Old_Order : Natural)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Placement_Ready
         (S, Parent, Child, Old_Last, Previous, Next, Threshold, Old_Order),
     Post => Valid (S) and then Can_Edit (S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then S.Effects.Dirty
       and then S.Capacity = S.Capacity'Old
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then Snapshot_Owners (S) = Snapshot_Owners (S)'Old
       and then Snapshot_Marks (S) = Snapshot_Marks (S)'Old
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I) =
             Placed_View
               (S'Old, Parent, Child, Old_Last, Previous, Next,
                Threshold, Old_Order, I))
       and then (if Previous = Null_Node then
         Node (S, Parent).First_Child = Child
       else True)
       and then Node (S, Parent).Last_Child = Old_Last
       and then Node (S, Child).Parent = Parent
       and then (if Previous = Null_Node then
         Node (S, Child).Previous = Null_Node
       else Node (S, Child).Previous = Previous)
       and then Node (S, Child).Next = Next;

   procedure Leaf_Has_No_Child (S : State; Root, N : Node_Ref)
   with Ghost, Global => null,
     Pre => Valid (S)
       and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).First_Child = Null_Node
       and then Node (S, Root).First_Prop = Null_Node
       and then N in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, N).State = Live,
     Post => Node (S, N).Parent /= Root,
     Subprogram_Variant => (Decreases => Node (S, N).Sibling_Order);

   procedure Leaf_Ancestor_Lemma (S : State; Root, N : Node_Ref)
   with Ghost, Global => null,
     Pre => Valid (S)
       and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).First_Child = Null_Node
       and then Node (S, Root).First_Prop = Null_Node
       and then N in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, N).State = Live,
     Post => Ancestor (S, Root, N) = (Root = N),
     Subprogram_Variant => (Decreases => Node (S, N).Tree_Rank);

   procedure Empty_Namespace_List_Lemma
     (S : State; Root : Node_Ref; Ns : Namespace_Ref)
   with Ghost, Global => null,
     Pre => Valid (S) and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).First_Namespace = Null_Namespace
       and then Ns in 1 .. Namespace_Ref (Namespace_Count (S))
       and then Namespace (S, Ns).State = Live,
     Post => Namespace (S, Ns).Parent /= Root,
     Subprogram_Variant => (Decreases => Namespace (S, Ns).Sibling_Order);

end XML3_DOM.Links;
