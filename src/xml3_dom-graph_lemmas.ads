private package XML3_DOM.Graph_Lemmas with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Release_Pin (Item : in out Owner_View)
   with Global => null,
     Pre => Item.State = Live and then not Item.Release_Emitted
       and then Item.References > Item.Reservations,
     Post => Item =
       (Item'Old with delta References => Item.References'Old - 1,
          State => (if Item.References'Old = 1 then Releasing else Live))
       and then (if Item.State = Releasing then
         Item.References = 0 and then Item.Reservations = 0);

   procedure Same_Holder_Count
     (Left, Right : Node_View_Array; B : Owner_Ref; N : Natural)
   with Ghost, Global => null,
     Pre => Left'First = 1 and then Right'First = 1
       and then N <= Left'Last and then N <= Right'Last
       and then (for all I in 1 .. N =>
         Holds (Left (I), B) = Holds (Right (I), B)),
     Post => Holder_Count (Left, B, N) = Holder_Count (Right, B, N),
     Subprogram_Variant => (Decreases => N);

   procedure Same_Ancestor
     (Left, Right : Node_View_Array; Used : Natural; Candidate, N : Node_Ref)
   with Ghost, Global => null,
     Pre => Left'First = 1 and then Right'First = 1
       and then Used <= Left'Last and then Used <= Right'Last
       and then Candidate in 1 .. Node_Ref (Used)
       and then N in 1 .. Node_Ref (Used)
       and then (for all I in 1 .. Used =>
         Left (I).State = Right (I).State
         and then Left (I).Parent = Right (I).Parent
         and then Left (I).Tree_Rank = Right (I).Tree_Rank),
     Post => Ancestor_In_Nodes (Left, Used, Candidate, N) =
       Ancestor_In_Nodes (Right, Used, Candidate, N),
     Subprogram_Variant => (Decreases => Left (Positive (N)).Tree_Rank);

   procedure Retained_Ancestor
     (Original, Remaining : Node_View_Array; Used : Natural;
      Candidate, N : Node_Ref)
   with Ghost, Global => null,
     Pre => Original'First = 1 and then Remaining'First = 1
       and then Used <= Original'Last and then Used <= Remaining'Last
       and then Candidate in 1 .. Node_Ref (Used)
       and then N in 1 .. Node_Ref (Used)
       and then (for all I in 1 .. Used =>
         (if Remaining (I).State = Live then
           Original (I).State = Live
           and then Original (I).Parent = Remaining (I).Parent
           and then Original (I).Tree_Rank = Remaining (I).Tree_Rank)),
     Post => (if Ancestor_In_Nodes (Remaining, Used, Candidate, N) then
       Ancestor_In_Nodes (Original, Used, Candidate, N)),
     Subprogram_Variant =>
       (Decreases => Remaining (Positive (N)).Tree_Rank);

   procedure Changed_Holder_Count
     (Left, Right : Node_View_Array;
      B : Owner_Ref;
      N : Natural;
      Changed : Positive)
   with Ghost, Global => null,
     Pre => Left'First = 1 and then Right'First = 1
       and then N <= Left'Last and then N <= Right'Last
       and then Changed <= N
       and then (for all I in 1 .. N =>
         (if I /= Changed then
            Holds (Left (I), B) = Holds (Right (I), B))),
     Post =>
       (if Holds (Left (Changed), B) = Holds (Right (Changed), B)
        then Holder_Count (Left, B, N) = Holder_Count (Right, B, N)
        elsif Holds (Right (Changed), B)
        then Holder_Count (Right, B, N) =
          Holder_Count (Left, B, N) + 1
        else Holder_Count (Left, B, N) =
          Holder_Count (Right, B, N) + 1),
     Subprogram_Variant => (Decreases => N);

   function Positive_Holder_Count_Witness
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural; I : Positive)
      return Boolean
   with Ghost, Global => null,
     Pre => Nodes'First = 1 and then N <= Nodes'Last and then I <= N
       and then Holds (Nodes (I), B),
     Post => Positive_Holder_Count_Witness'Result
       and then Holder_Count (Nodes, B, N) >= 1,
     Subprogram_Variant => (Decreases => N);

   procedure Zero_Holder_Count
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural)
   with Ghost, Global => null,
     Pre => Nodes'First = 1 and then N <= Nodes'Last
       and then (for all I in 1 .. N => not Holds (Nodes (I), B)),
     Post => Holder_Count (Nodes, B, N) = 0,
     Subprogram_Variant => (Decreases => N);

   procedure Preserve_Pin_Equation (Before, After : State)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Pin_Equation (Before)
       and then Node_Count (Before) = Node_Count (After)
       and then Owner_Count (Before) = Owner_Count (After)
       and then (for all B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (Before)) =>
         (Owner (Before, B).State = Live) = (Owner (After, B).State = Live)
         and then Owner (Before, B).References = Owner (After, B).References
         and then Owner (Before, B).Reservations = Owner (After, B).Reservations)
       and then (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (Before)) =>
         (Same_Pins (Node (Before, N), Node (After, N))
          or else (Node (Before, N).State /= Live and then Node (After, N).State /= Live))),
     Post => Pin_Equation (After);

   function Namespace_Parent_Preserved (Before, After : Node_View) return Boolean is
     (Before.State not in Live | Tombstone or else
       (After.State in Live | Tombstone and then Before.Kind = After.Kind
        and then Before.Owner = After.Owner
        and then Before.First_Namespace = After.First_Namespace
        and then Before.Last_Namespace = After.Last_Namespace))
     with Ghost, Annotate => (GNATprove, Inline_For_Proof);

   procedure Preserve_Namespace_Links (Before, After : Graph_State)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Node_Used <= After.Node_Used
       and then Before.Owner_Used <= After.Owner_Used
       and then (for all I in 1 .. Before.Ns_Used =>
         Namespace_Links_Valid (Before, I)
         and then Before.Namespaces (I) = After.Namespaces (I))
       and then (for all I in 1 .. Before.Ns_Used =>
         (if Before.Namespaces (I).State = Live
           and then Before.Namespaces (I).Owns_Reservation
          then After.Owners
            (Positive (Before.Namespaces (I).Owner)).State = Live
            and then After.Owners
              (Positive (Before.Namespaces (I).Owner)).Reservations > 0
            and then (if Before.Namespaces (I).Parent /= Null_Node then
              After.Nodes
                (Positive (Before.Namespaces (I).Parent)).State = Live)))
       and then (for all I in 1 .. Before.Node_Used =>
         Namespace_Parent_Preserved (Before.Nodes (I), After.Nodes (I)))
       and then (for all I in 1 .. Before.Owner_Used =>
         (if Before.Owners (I).State in Live | Releasing then
           After.Owners (I).State in Live | Releasing)),
     Post => (for all I in 1 .. After.Ns_Used => Namespace_Links_Valid (After, I));

   procedure Copied_Links_Lemma (Before, After : Graph_State)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Node_Used = After.Node_Used
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Owner_Used = After.Owner_Used
       and then (for all I in 1 .. Before.Node_Used =>
         Node_Links_Valid (Before, I) and then Before.Nodes (I) = After.Nodes (I))
       and then (for all I in 1 .. Before.Ns_Used =>
         Before.Namespaces (I) = After.Namespaces (I))
       and then (for all I in 1 .. Before.Owner_Used =>
         Before.Owners (I) = After.Owners (I)),
     Post => (for all I in 1 .. After.Node_Used => Node_Links_Valid (After, I));

   --  One step of an owner-count loop while editing with projection
   --  pending: only owner B changed, its Release_Emitted flag did not, and
   --  a releasing B holds nothing.  Effects_Valid carries over.
   procedure Owner_Step_Effects (Before, After : State; B : Positive)
   with Ghost, Global => null,
     Pre => Effects_Valid (Before)
       and then After.Effects = Before.Effects
       and then Before.Effects.Phase = Editing
       and then Before.Effects.Dirty
       and then After.Graph.Node_Used = Before.Graph.Node_Used
       and then After.Graph.Ns_Used = Before.Graph.Ns_Used
       and then After.Graph.Owner_Used = Before.Graph.Owner_Used
       and then After.Capacity = Before.Capacity
       and then B in 1 .. Before.Graph.Owner_Used
       and then (for all K in 1 .. Before.Graph.Owner_Used =>
         (if K /= B then After.Graph.Owners (K) = Before.Graph.Owners (K)))
       and then After.Graph.Owners (B).Release_Emitted =
         Before.Graph.Owners (B).Release_Emitted
       and then (if After.Graph.Owners (B).State = Releasing then
         After.Graph.Owners (B).References = 0
         and then After.Graph.Owners (B).Reservations = 0),
     Post => Effects_Valid (After);

   --  Facades survive when every slot keeps its facade, no slot becomes
   --  Live or Tombstone, and no namespace becomes Live.
   procedure Facades_Frame (Before, After : State)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then After.Graph.Node_Used = Before.Graph.Node_Used
       and then After.Graph.Ns_Used = Before.Graph.Ns_Used
       and then (for all I in 1 .. After.Graph.Node_Used =>
         (if After.Graph.Nodes (I).State in Live | Tombstone then
           Before.Graph.Nodes (I).State in Live | Tombstone
           and then After.Graph.Nodes (I).Facade =
             Before.Graph.Nodes (I).Facade))
       and then (for all I in 1 .. After.Graph.Ns_Used =>
         (if After.Graph.Namespaces (I).State = Live then
           Before.Graph.Namespaces (I).State = Live
           and then After.Graph.Namespaces (I).Facade =
             Before.Graph.Namespaces (I).Facade)),
     Post => (if Facades_Present (Before) then Facades_Present (After));

   --  The tree-link fields of a node: everything Node_Siblings_Valid and
   --  Node_Children_Valid read.
   function Same_Tree_Links (Left, Right : Node_View) return Boolean is
     (Left.State = Right.State and then Left.Kind = Right.Kind
      and then Left.Parent = Right.Parent
      and then Left.First_Child = Right.First_Child
      and then Left.Last_Child = Right.Last_Child
      and then Left.Previous = Right.Previous
      and then Left.Next = Right.Next
      and then Left.Sibling_Order = Right.Sibling_Order
      and then Left.First_Prop = Right.First_Prop
      and then Left.Last_Prop = Right.Last_Prop
      and then Left.Tree_Rank = Right.Tree_Rank)
     with Ghost, Global => null;

   --  Sibling and child validity of node I only depend on tree links.
   procedure Tree_Links_Frame (Before, After : Graph_State; I : Positive)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then After.Node_Used = Before.Node_Used
       and then I <= Before.Node_Used
       and then (for all J in 1 .. Before.Node_Used =>
         Same_Tree_Links (Before.Nodes (J), After.Nodes (J)))
       and then Node_Siblings_Valid (Before, I)
       and then Node_Children_Valid (Before, I),
     Post => Node_Siblings_Valid (After, I)
       and then Node_Children_Valid (After, I);

   --  The owner facts of Namespace_Links_Valid that callers of
   --  Preserve_Namespace_Links need, in raw form.
   procedure Namespace_Owners_Live (S : Graph_State)
   with Ghost, Global => null,
     Pre => Well_Sized (S)
       and then (for all I in 1 .. S.Ns_Used => Namespace_Links_Valid (S, I)),
     Post => (for all I in 1 .. S.Ns_Used =>
       (if S.Namespaces (I).State = Live
          and then S.Namespaces (I).Owns_Reservation
        then S.Owners (Positive (S.Namespaces (I).Owner)).State = Live
          and then S.Owners (Positive (S.Namespaces (I).Owner)).Reservations > 0
          and then (if S.Namespaces (I).Parent /= Null_Node then
            S.Nodes (Positive (S.Namespaces (I).Parent)).State = Live)));

   --  Unlinking N changes no slot state and no parent link except N's own.
   procedure Unlinked_Fields (Before, After : State; N : Node_Ref)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Node_Count (After) = Node_Count (Before)
       and then N in 1 .. Node_Ref (Node_Count (Before))
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (After)) =>
         Node (After, I) = Unlinked_View (Before, N, I)),
     Post => (for all I in 1 .. After.Graph.Node_Used =>
       After.Graph.Nodes (I).State = Before.Graph.Nodes (I).State
       and then After.Graph.Nodes (I).Tree_Rank =
         Before.Graph.Nodes (I).Tree_Rank
       and then After.Graph.Nodes (I).Parent =
         (if I = Positive (N) then Null_Node
          else Before.Graph.Nodes (I).Parent));

   --  Per-pin liveness from the "every held owner is live" form.
   procedure Held_Pins_Live (S : Graph_State; I : Positive)
   with Ghost, Global => null,
     Pre => Well_Sized (S) and then I <= S.Node_Used
       and then S.Nodes (I).State = Live
       and then S.Nodes (I).Owner in 1 .. Owner_Ref (S.Owner_Used)
       and then S.Nodes (I).Ns_Pin <= Owner_Ref (S.Owner_Used)
       and then S.Nodes (I).Doc_Pin <= Owner_Ref (S.Owner_Used)
       and then S.Nodes (I).Content_Pin <= Owner_Ref (S.Owner_Used)
       and then S.Nodes (I).Name_Pin <= Owner_Ref (S.Owner_Used)
       and then (for all B in Owner_Ref range 1 .. Owner_Ref (S.Owner_Used) =>
         (if Holds (S.Nodes (I), B) then Live_Owner (S, B))),
     Post => Live_Owner (S, S.Nodes (I).Owner)
       and then (S.Nodes (I).Ns_Pin = 0 or else Live_Owner (S, S.Nodes (I).Ns_Pin))
       and then (S.Nodes (I).Doc_Pin = 0 or else Live_Owner (S, S.Nodes (I).Doc_Pin))
       and then (S.Nodes (I).Content_Pin = 0
                 or else Live_Owner (S, S.Nodes (I).Content_Pin))
       and then (S.Nodes (I).Name_Pin = 0
                 or else Live_Owner (S, S.Nodes (I).Name_Pin));

   --  Facades only depend on the graph.
   procedure Facades_Same_Graph (Before, After : State)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Same_Graph (Before, After),
     Post => Facades_Present (After) = Facades_Present (Before);

   --  The four link properties of one node of a valid state.
   procedure Node_Links_Of (S : State; I : Positive)
   with Ghost, Global => null,
     Pre => Valid (S) and then I <= S.Graph.Node_Used,
     Post => Node_Pins_Valid (S.Graph, I)
       and then Node_Siblings_Valid (S.Graph, I)
       and then Node_Children_Valid (S.Graph, I)
       and then Node_Namespaces_Valid (S.Graph, I);

   --  Preserve_Namespace_Links with element-wise frame conditions: the
   --  owner and parent facts it needs are derived here, per namespace.
   procedure Namespace_Links_Frame (Before, After : Graph_State)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Node_Used <= After.Node_Used
       and then Before.Owner_Used <= After.Owner_Used
       and then (for all I in 1 .. Before.Ns_Used =>
         Namespace_Links_Valid (Before, I)
         and then Before.Namespaces (I) = After.Namespaces (I))
       and then (for all I in 1 .. Before.Node_Used =>
         (if Before.Nodes (I).State = Live then After.Nodes (I).State = Live)
         and then Namespace_Parent_Preserved (Before.Nodes (I), After.Nodes (I)))
       and then (for all K in 1 .. Before.Owner_Used =>
         (if Before.Owners (K).State = Live
            and then Before.Owners (K).Reservations > 0
          then After.Owners (K).State = Live
            and then After.Owners (K).Reservations > 0)
         and then (if Before.Owners (K).State in Live | Releasing then
           After.Owners (K).State in Live | Releasing)),
     Post => (for all I in 1 .. After.Ns_Used => Namespace_Links_Valid (After, I));

   --  The range properties that follow from valid links.
   procedure Ranges_From_Links (S : State)
   with Ghost, Global => null,
     Pre => Well_Sized (S)
       and then (for all I in 1 .. S.Graph.Node_Used =>
         Node_Links_Valid (S.Graph, I))
       and then (for all I in 1 .. S.Graph.Ns_Used =>
         Namespace_Links_Valid (S.Graph, I)),
     Post => Pins_In_Range (S) and then Projection_Links_In_Range (S);

   --  Unlink's accessor-form field facts, in raw array form.
   procedure Unlink_Fields_Raw (Before, After : State; N : Node_Ref)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Node_Count (After) = Node_Count (Before)
       and then N in 1 .. Node_Ref (Node_Count (Before))
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (After)) =>
         Node (After, I).State = Node (Before, I).State
         and then Node (After, I).Tree_Rank = Node (Before, I).Tree_Rank
         and then Node (After, I).Parent =
           (if I = N then Null_Node else Node (Before, I).Parent)),
     Post => (for all I in 1 .. After.Graph.Node_Used =>
       After.Graph.Nodes (I).State = Before.Graph.Nodes (I).State
       and then After.Graph.Nodes (I).Tree_Rank =
         Before.Graph.Nodes (I).Tree_Rank
       and then After.Graph.Nodes (I).Parent =
         (if I = Positive (N) then Null_Node
          else Before.Graph.Nodes (I).Parent));

end XML3_DOM.Graph_Lemmas;
