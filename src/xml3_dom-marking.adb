with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
with XML3_DOM.Links; use XML3_DOM.Links;
with XML3_DOM.Projection; use XML3_DOM.Projection;
package body XML3_DOM.Marking with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Compose_Namespace_Snapshots
     (Left, Middle, Right : Namespace_View_Array) is
   begin
      for I in Left'Range loop
         pragma Assert (Left (I) = Middle (I));
         pragma Assert (Middle (I) = Right (I));
         pragma Loop_Invariant
           (for all J in Left'First .. I => Left (J) = Right (J));
      end loop;
   end Compose_Namespace_Snapshots;

   procedure Namespace_Array_Equality
     (Left, Right : Namespace_View_Array) is
   begin
      for I in Left'Range loop
         pragma Assert (Left (I) = Right (I));
         pragma Loop_Invariant
           (for all J in Left'First .. I => Left (J) = Right (J));
      end loop;
   end Namespace_Array_Equality;

   procedure Namespace_Frame
     (S : State; Original : Namespace_View_Array) is
   begin
      Namespace_Array_Equality (S.Graph.Namespaces, Original);
      Namespace_Array_Equality (Snapshot_Namespaces (S), Original);
   end Namespace_Frame;

   procedure Unchanged_Graph_Namespaces (Before, After : State) is
   begin
      for I in 1 .. Before.Capacity loop
         pragma Assert
           (After.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             After.Graph.Namespaces (J) = Before.Graph.Namespaces (J));
      end loop;
   end Unchanged_Graph_Namespaces;

   procedure Compose_Mark_Snapshots (Left, Middle, Right : Mark_Array) is
   begin
      for I in Left'Range loop
         pragma Assert (Left (I) = Middle (I));
         pragma Assert (Middle (I) = Right (I));
         pragma Loop_Invariant
           (for all J in Left'First .. I => Left (J) = Right (J));
      end loop;
   end Compose_Mark_Snapshots;

   procedure Mark_Frame (S : State; Original : Mark_Array) is
   begin
      for I in 1 .. S.Capacity loop
         pragma Assert (S.Marks (I) = Original (I));
         pragma Loop_Invariant
           (for all J in 1 .. I => S.Marks (J) = Original (J));
      end loop;
   end Mark_Frame;

   procedure Preserve_Marked_State
     (Before, After : Node_View_Array;
      Before_Marks, After_Marks : Mark_Array; Used : Natural;
      Target_Doc : Node_Ref) is
   begin
      for I in 1 .. Used loop
         pragma Assert (Before (I).State = After (I).State);
         pragma Assert (Before (I).Document = After (I).Document);
         pragma Assert (Before_Marks (I) = After_Marks (I));
         pragma Assert (if After_Marks (I) then Before (I).State = Live);
         pragma Assert
           (if After_Marks (I) then Before (I).Document = Null_Node
             or else Before (I).Document = Target_Doc);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             (if After_Marks (J) then After (J).State = Live
               and then (After (J).Document = Null_Node
                 or else After (J).Document = Target_Doc)));
      end loop;
   end Preserve_Marked_State;

   procedure Same_Graph_Snapshots (Left, Right : State) is
   begin
      for I in 1 .. Left.Capacity loop
         pragma Assert
           (Snapshot_Nodes (Left) (I) = Node (Left, Node_Ref (I)));
         pragma Assert
           (Snapshot_Nodes (Right) (I) = Node (Right, Node_Ref (I)));
         pragma Assert
           (Snapshot_Nodes (Left) (I) = Snapshot_Nodes (Right) (I));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Snapshot_Nodes (Left) (J) = Snapshot_Nodes (Right) (J)
              and then Snapshot_Namespaces (Left) (J) =
                Snapshot_Namespaces (Right) (J));
      end loop;
   end Same_Graph_Snapshots;

   procedure Prepare_Subtree
     (S : in out State; Root : Node_Ref; Lift : Natural;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Original_Namespaces : constant Namespace_View_Array :=
        S.Graph.Namespaces with Ghost;
      Is_Leaf : constant Boolean :=
        S.Graph.Nodes (Positive (Root)).First_Child = Null_Node
        and then S.Graph.Nodes (Positive (Root)).First_Prop = Null_Node;
   begin
      Unchanged_Graph_Namespaces (S, Before);
      Success := True;
      for I in 1 .. S.Graph.Node_Used loop
         if S.Graph.Nodes (I).State /= Live then
            S.Marks (I) := False;
         elsif Is_Leaf then
            Leaf_Ancestor_Lemma (S, Root, Node_Ref (I));
            S.Marks (I) := Node_Ref (I) = Root;
         else
            S.Marks (I) := Is_Ancestor (S, Root, Node_Ref (I));
         end if;
         Namespace_Frame (S, Original_Namespaces);
         if S.Marks (I) and then S.Graph.Nodes (I).Tree_Rank > Natural'Last - Lift then
            pragma Assert (Lift /= 0);
            pragma Assert (Before.Graph = S.Graph);
            pragma Assert (S.Graph = Before.Graph);
            Success := False;
            exit;
         end if;
         pragma Loop_Invariant (Success);
         pragma Loop_Invariant (Before.Graph = S.Graph);
         pragma Loop_Invariant (S.Graph = Before.Graph);
         pragma Loop_Invariant (S.Graph.Namespaces = Original_Namespaces);
         pragma Loop_Invariant (Valid (S));
         pragma Loop_Invariant
           (Is_Leaf = (S.Graph.Nodes (Positive (Root)).First_Child = Null_Node
             and then S.Graph.Nodes (Positive (Root)).First_Prop = Null_Node));
         pragma Loop_Invariant
           (if Is_Leaf then
             (for all J in 1 .. I => S.Marks (J) = (Node_Ref (J) = Root)));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             S.Marks (J) = (S.Graph.Nodes (J).State = Live and then
               Ancestor (S, Root, Node_Ref (J)))
             and then (if S.Marks (J) then
               S.Graph.Nodes (J).Tree_Rank <= Natural'Last - Lift));
      end loop;
      if Success then
         pragma Assert (Ancestor (S, Root, Root));
         pragma Assert (S.Marks (Positive (Root)));
         for I in 1 .. S.Graph.Node_Used loop
            pragma Assert (Node_Siblings_Valid (S.Graph, I));
            pragma Assert
              (if S.Graph.Nodes (I).State = Live and then S.Graph.Nodes (I).Parent /= 0
                and then Node_Ref (I) /= Root
               then Ancestor (S, Root, Node_Ref (I)) =
                 Ancestor (S, Root, S.Graph.Nodes (I).Parent));
            pragma Loop_Invariant (S.Marks (Positive (Root)));
            pragma Loop_Invariant (Before.Graph = S.Graph);
            pragma Loop_Invariant (S.Graph = Before.Graph);
            pragma Loop_Invariant
              (for all J in 1 .. I =>
                (if S.Graph.Nodes (J).State = Live and then S.Graph.Nodes (J).Parent /= 0
                  and then Node_Ref (J) /= Root
                 then S.Graph.Nodes (J).Parent <= Node_Ref (S.Graph.Node_Used)
                   and then S.Marks (J) = S.Marks (Positive (S.Graph.Nodes (J).Parent))));
         end loop;
         pragma Assert
           (if S.Graph.Nodes (Positive (Root)).First_Child = Null_Node
             and then S.Graph.Nodes (Positive (Root)).First_Prop = Null_Node then
               (for all I in 1 .. S.Graph.Node_Used =>
                 S.Marks (I) = (Node_Ref (I) = Root)));
         Namespace_Frame (S, Original_Namespaces);
         pragma Assert (S.Graph.Namespaces = Original_Namespaces);
         Unchanged_Graph_Namespaces (Before, S);
         pragma Assert_And_Cut
           (S.Effects = Before.Effects and then Valid (S)
            and then S.Graph = Before.Graph
            and then S.Graph.Nodes = Before.Graph.Nodes
            and then (if Lift = 0 then Success)
            and then (for all I in 1 .. S.Capacity =>
              S.Graph.Namespaces (I) = Before.Graph.Namespaces (I))
            and then S.Graph.Namespaces = Before.Graph.Namespaces
            and then S.Graph.Owners = Before.Graph.Owners
            and then S.Graph.Node_Used = Before.Graph.Node_Used
            and then S.Graph.Ns_Used = Before.Graph.Ns_Used
            and then S.Graph.Owner_Used = Before.Graph.Owner_Used
            and then (if Success
              and then S.Graph.Nodes (Positive (Root)).First_Child = Null_Node
              and then S.Graph.Nodes (Positive (Root)).First_Prop = Null_Node then
                (for all I in 1 .. S.Graph.Node_Used =>
                  S.Marks (I) = (Node_Ref (I) = Root)))
            and then (if Success then S.Marks (Positive (Root))
              and then (for all I in 1 .. S.Graph.Node_Used =>
                S.Marks (I) = (S.Graph.Nodes (I).State = Live and then
                  Ancestor (S, Root, Node_Ref (I)))
                and then (if S.Marks (I) then
                  S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Lift)
                and then (if S.Graph.Nodes (I).State = Live
                  and then S.Graph.Nodes (I).Parent /= 0 and then Node_Ref (I) /= Root
                  then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
                     and then S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent))))));
         return;
      end if;
      pragma Assert (not Success and then Lift /= 0);
      Namespace_Frame (S, Original_Namespaces);
      pragma Assert (S.Graph.Namespaces = Original_Namespaces);
      Unchanged_Graph_Namespaces (Before, S);
      pragma Assert_And_Cut
        (S.Effects = Before.Effects and then Valid (S)
         and then S.Graph = Before.Graph
         and then S.Graph.Nodes = Before.Graph.Nodes
         and then (if Lift = 0 then Success)
         and then (for all I in 1 .. S.Capacity =>
           S.Graph.Namespaces (I) = Before.Graph.Namespaces (I))
         and then S.Graph.Namespaces = Before.Graph.Namespaces
         and then S.Graph.Owners = Before.Graph.Owners
         and then S.Graph.Node_Used = Before.Graph.Node_Used
         and then S.Graph.Ns_Used = Before.Graph.Ns_Used
         and then S.Graph.Owner_Used = Before.Graph.Owner_Used
         and then (if Success
           and then S.Graph.Nodes (Positive (Root)).First_Child = Null_Node
           and then S.Graph.Nodes (Positive (Root)).First_Prop = Null_Node then
             (for all I in 1 .. S.Graph.Node_Used =>
               S.Marks (I) = (Node_Ref (I) = Root)))
         and then (not Success or else (S.Marks (Positive (Root))
           and then (for all I in 1 .. S.Graph.Node_Used =>
             S.Marks (I) = (S.Graph.Nodes (I).State = Live and then
               Ancestor (S, Root, Node_Ref (I)))
             and then (if S.Marks (I) then
               S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Lift)
             and then (if S.Graph.Nodes (I).State = Live
               and then S.Graph.Nodes (I).Parent /= 0 and then Node_Ref (I) /= Root
               then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
                  and then S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent)))))));
   end Prepare_Subtree;

   procedure Lift_Marked (S : in out State; Lift : Natural) is
      Before : constant State := S with Ghost;
   begin
      for I in 1 .. S.Graph.Node_Used loop
         if S.Marks (I) then
            S.Graph.Nodes (I).Tree_Rank := S.Graph.Nodes (I).Tree_Rank + Lift;
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Node_Used =>
             S.Graph.Nodes (J) = (Before.Graph.Nodes (J) with delta Tree_Rank =>
               Before.Graph.Nodes (J).Tree_Rank
                 + (if J <= I and then S.Marks (J) then Lift else 0)));
      end loop;
      Preserve_Pin_Equation (Before, S);
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (I).State = Before.Graph.Nodes (I).State
           and then Namespace_Parent_Preserved
             (Before.Graph.Nodes (I), S.Graph.Nodes (I)));
      pragma Assert (S.Graph.Owners = Before.Graph.Owners);
      pragma Assert (S.Graph.Namespaces = Before.Graph.Namespaces);
      Namespace_Links_Frame (Before.Graph, S.Graph);
   end Lift_Marked;

   procedure Set_Marked_Document
     (S : in out State; Target_Doc : Node_Ref; Target_B : Owner_Ref)
   is
      Before : constant State := S with Ghost;
      Original_Namespaces : constant Namespace_View_Array :=
        Snapshot_Namespaces (S) with Ghost;
      Original_Marks : constant Mark_Array := S.Marks with Ghost;
      Original_Target_References : constant Natural :=
        S.Graph.Owners (Positive (Target_B)).References with Ghost;
   begin
      pragma Assert (Before.Marks = Original_Marks);
      pragma Assert (Snapshot_Namespaces (Before) = Original_Namespaces);
      for I in 0 .. S.Graph.Node_Used loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant
           (Snapshot_Namespaces (S) = Original_Namespaces);
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant
           (S.Capacity = Before.Capacity
            and then S.Graph.Node_Used = Before.Graph.Node_Used
            and then S.Graph.Ns_Used = Before.Graph.Ns_Used
            and then S.Graph.Owner_Used = Before.Graph.Owner_Used);
         pragma Loop_Invariant (S.Marks = Original_Marks);
         pragma Loop_Invariant
           (for all J in Namespace_Ref range
             1 .. Namespace_Ref (Namespace_Count (S)) =>
               Namespace (S, J) = Namespace (Before, J));
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Node_Used =>
             S.Graph.Nodes (J) =
               (if J <= I and then Before.Marks (J) then
                  (Before.Graph.Nodes (J) with delta
                     Document => Target_Doc, Doc_Pin => Target_B)
                else Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Node_Used =>
             (if J > I and then S.Marks (J) then
                S.Graph.Nodes (J).State = Live
                  and then (S.Graph.Nodes (J).Document = Null_Node
                    or else S.Graph.Nodes (J).Document = Target_Doc)));
         pragma Loop_Invariant
           (Node (S, Target_Doc).Kind = Document_Node
            and then Node (S, Target_Doc).State in Live | Tombstone
            and then Node (S, Target_Doc).Owner = Target_B
            and then Owner (S, Target_B).State = Live);
         pragma Loop_Invariant
           (Long_Long_Integer
              (S.Graph.Owners (Positive (Target_B)).References)
            <= Long_Long_Integer (Original_Target_References)
              + Long_Long_Integer (I));
         if I < S.Graph.Node_Used
           and then S.Marks (Positive (I + 1))
         then
            declare
               Index : constant Positive := Positive (I + 1);
               Item : constant Node_View := S.Graph.Nodes (Index);
               Proposed : constant Node_View := Projected_View
                 (Item, Item.Name, Item.Name_Length, Item.Content,
                  Item.Content_Length, Target_Doc, Item.Namespace,
                  Item.Ns_Pin, Target_B, Item.Content_Pin, Item.Name_Pin);
               Iteration_Before : constant State := S with Ghost;
               Iteration_Namespaces : constant Namespace_View_Array :=
                 Snapshot_Namespaces (S) with Ghost;
               Iteration_Marks : constant Mark_Array :=
                 S.Marks with Ghost;
               OK : Boolean;
            begin
               pragma Assert
                 (Node_Ref (Index) in 1 .. Node_Ref (Node_Count (S)));
               pragma Assert (Node_Pins_Valid (S.Graph, Index));
               pragma Assert (Item.State = Live);
               pragma Assert
                 (Item.Document = Null_Node
                   or else Item.Document = Target_Doc);
               pragma Assert (Proposed.Document = Target_Doc);
               pragma Assert (Proposed.Doc_Pin = Target_B);
               pragma Assert
                 (Proposed.Document <= Node_Ref (Node_Count (S)));
               pragma Assert
                 (Proposed.Doc_Pin <= Owner_Ref (Owner_Count (S)));
               pragma Assert
                 (Long_Long_Integer
                    (S.Graph.Owners (Positive (Target_B)).References)
                  < Long_Long_Integer (Natural'Last));
               pragma Assert
                 (for all B in Owner_Ref range
                    1 .. Owner_Ref (Owner_Count (S)) =>
                      (if B /= Target_B then
                         not Holds (Proposed, B) or else Holds (Item, B)));
               pragma Assert
                 (for all B in Owner_Ref range
                    1 .. Owner_Ref (Owner_Count (S)) =>
                      (Holds (Node (S, Node_Ref (Index)), B)
                       or else not Holds (Proposed, B)
                       or else Owner (S, B).References < Natural'Last));
               pragma Assert
                 (Node (S, Proposed.Document).Owner = Proposed.Doc_Pin);
               pragma Assert (Owner (S, Proposed.Doc_Pin).State = Live);
               pragma Assert
                 (Projection_Pins_Allowed
                    (S, Node_Ref (Index), Proposed));
               Set_Node_Projection_Internal
                 (S, Node_Ref (Index), Item.Name, Item.Name_Length,
                  Item.Content, Item.Content_Length, Target_Doc,
                  Item.Namespace, Item.Ns_Pin, Target_B, Item.Content_Pin,
                  Item.Name_Pin, OK);
               pragma Assert (OK);
               pragma Assert (Snapshot_Namespaces (S) = Iteration_Namespaces);
               pragma Assert (S.Marks = Iteration_Marks);
               Compose_Namespace_Snapshots
                 (Snapshot_Namespaces (S), Iteration_Namespaces,
                  Original_Namespaces);
               Namespace_Frame (S, Original_Namespaces);
               Compose_Mark_Snapshots
                 (Original_Marks, Iteration_Marks, S.Marks);
               Mark_Frame (S, Original_Marks);
               pragma Assert
                 (for all J in 1 .. S.Graph.Node_Used =>
                    S.Graph.Nodes (J) =
                      (if J = Index then Proposed
                       else Iteration_Before.Graph.Nodes (J)));
               pragma Assert (S.Marks = Original_Marks);
            end;
            pragma Assert (S.Marks = Original_Marks);
         else
            pragma Assert (S.Marks = Original_Marks);
         end if;
         pragma Assert (S.Marks = Original_Marks);
      end loop;
      pragma Assert (S.Marks = Before.Marks);
      pragma Assert (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
   end Set_Marked_Document;

   procedure Relink_Marked_Subtree
     (S : in out State; Parent, Child : Node_Ref; Property : Boolean;
      Append_Order, Rank_Lift : Natural; Replaced : Node_Ref)
   is
      Before : constant State := S with Ghost;
      Detached : State (Before.Capacity) with Ghost;
      Parent_Item : Node_View := S.Graph.Nodes (Positive (Parent));
      Child_Item : Node_View := S.Graph.Nodes (Positive (Child));
      Original_Last : constant Node_Ref :=
        (if Property then Node (S, Parent).Last_Prop
         else Node (S, Parent).Last_Child) with Ghost;
      Original_Last_Order : constant Natural :=
        (if Original_Last = Null_Node then 0
         else Node (S, Original_Last).Sibling_Order) with Ghost;
   begin
      pragma Assert (not S.Marks (Positive (Parent)));
      pragma Assert (S.Marks (Positive (Child)));
      pragma Assert (Node (S, Parent).Tree_Rank = Parent_Item.Tree_Rank);
      pragma Assert (Node (S, Child).Tree_Rank = Child_Item.Tree_Rank);
      if Replaced = Null_Node then
         Unlink_Tail_Lemma (Before, Parent, Child, Property);
         pragma Assert
           (if Property then
              Unlinked_View (Before, Child, Parent).Last_Prop = Original_Last
            else
              Unlinked_View (Before, Child, Parent).Last_Child = Original_Last);
         pragma Assert
           (if Original_Last /= Null_Node then
              Unlinked_View (Before, Child, Original_Last).Sibling_Order =
                Original_Last_Order);
      end if;
      S.Effects.Dirty := True;
      Unlink (S, Child);
      pragma Assert (S.Marks = Before.Marks);
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I).State = Node (Before, I).State
           and then Node (S, I).Tree_Rank = Node (Before, I).Tree_Rank
           and then Node (S, I).Parent =
             (if I = Child then Null_Node else Node (Before, I).Parent));
      Unlink_Fields_Raw (Before, S, Child);
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (I).State = Before.Graph.Nodes (I).State
           and then S.Graph.Nodes (I).Tree_Rank =
             Before.Graph.Nodes (I).Tree_Rank
           and then S.Graph.Nodes (I).Parent =
             (if I = Positive (Child) then Null_Node
              else Before.Graph.Nodes (I).Parent));
      pragma Assert
        (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
      if Replaced = Null_Node then
         pragma Assert
           ((if Property then Node (S, Parent).Last_Prop
             else Node (S, Parent).Last_Child) = Original_Last);
         pragma Assert
           (if Original_Last /= Null_Node then
              Node (S, Original_Last).Sibling_Order = Original_Last_Order);
      end if;
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S)) =>
             Namespace (S, I) = Namespace (Before, I));
      pragma Assert
        (for all I in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S)) =>
           Owner (S, I) = Owner (Before, I));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Same_Pins (Node (S, I), Node (Before, I))
             and then Node (S, I).Kind = Node (Before, I).Kind
             and then Node (S, I).Facade = Node (Before, I).Facade
             and then Node (S, I).Document = Node (Before, I).Document);
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      pragma Assert (not S.Marks (Positive (Parent)));
      pragma Assert (S.Marks (Positive (Child)));
      pragma Assert (Node (S, Parent).Tree_Rank = Parent_Item.Tree_Rank);
      pragma Assert (Node (S, Child).Tree_Rank = Child_Item.Tree_Rank);
      --  Unlinking only cut Child from its parent and kept every rank, so
      --  every other live node still shares its parent's mark.
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           (if S.Marks (I) then
              S.Graph.Nodes (I).State = Live
              and then S.Graph.Nodes (I).Tree_Rank <=
                Natural'Last - Rank_Lift));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           (if Node (S, I).State = Live
              and then Node (S, I).Parent /= Null_Node
            then Node (S, I).Parent <= Node_Ref (Node_Count (S))
              and then S.Marks (Positive (I)) =
                S.Marks (Positive (Node (S, I).Parent))));
      Lift_Marked (S, Rank_Lift);
      pragma Assert
        (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S)) =>
             Namespace (S, I) = Namespace (Before, I));
      pragma Assert
        (for all I in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S)) =>
           Owner (S, I) = Owner (Before, I));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Same_Pins (Node (S, I), Node (Before, I))
             and then Node (S, I).Kind = Node (Before, I).Kind
             and then Node (S, I).Facade = Node (Before, I).Facade
             and then Node (S, I).Document = Node (Before, I).Document);
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      pragma Assert (Node (S, Parent).Tree_Rank = Parent_Item.Tree_Rank);
      pragma Assert
        (Node (S, Child).Tree_Rank = Child_Item.Tree_Rank + Rank_Lift);
      if Replaced = Null_Node then
         pragma Assert
           ((if Property then Node (S, Parent).Last_Prop
             else Node (S, Parent).Last_Child) = Original_Last);
         pragma Assert
           (if Original_Last /= Null_Node then
              Node (S, Original_Last).Sibling_Order = Original_Last_Order);
      end if;
      pragma Assert
        (S.Capacity = Before.Capacity
         and then (for all I in 1 .. S.Capacity =>
           S.Marks (I) = Before.Marks (I)));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      pragma Assert (Node (S, Parent).Tree_Rank < Node (S, Child).Tree_Rank);
      if Replaced = Null_Node then
         pragma Assert
           (Original_Last = Null_Node or else
             (Original_Last in 1 .. Node_Ref (Node_Count (Before))
              and then Original_Last /= Child
              and then Node (Before, Original_Last).Sibling_Order <
                Append_Order));
         Append_Child_Links (S, Parent, Child, Append_Order);
         pragma Assert
           (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         pragma Assert
           (if Property then
              Node (S, Parent).Last_Prop = Child
                and then Node (S, Child).Next = Null_Node
            else
              Node (S, Parent).Last_Child = Child
                and then Node (S, Child).Next = Null_Node);
      else
         Detached := S;
         pragma Assert (Valid (S));
         pragma Assert (Can_Edit (S));
         pragma Assert (Parent in 1 .. Node_Ref (Node_Count (S)));
         pragma Assert (Child in 1 .. Node_Ref (Node_Count (S)));
         pragma Assert (Replaced in 1 .. Node_Ref (Node_Count (S)));
         pragma Assert (Parent /= Child and then Parent /= Replaced);
         pragma Assert (Child /= Replaced);
         pragma Assert (Node (S, Parent).State = Live);
         pragma Assert (Node (S, Parent).Kind = Document_Node);
         pragma Assert (Node (S, Child).State = Live);
         pragma Assert (Node (S, Child).Kind = Element_Node);
         pragma Assert (Node (S, Child).Parent = Null_Node);
         pragma Assert (Node (S, Replaced).State = Live);
         pragma Assert (Node (S, Replaced).Kind = Element_Node);
         pragma Assert (Node (S, Replaced).Parent = Parent);
         pragma Assert
           (Node (S, Parent).Tree_Rank < Node (S, Child).Tree_Rank);
         pragma Assert
           (for all I in 1 .. Node_Count (S) =>
             Node_Links_Valid (S.Graph, I));
         Replace_Child_Links (S, Parent, Child, Replaced);
         Replaced_Namespace_Fields (Detached, S, Parent, Child, Replaced);
         pragma Assert
           (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         pragma Assert
           (Node (S, Child).Previous =
              Unlinked_View (Before, Child, Replaced).Previous
            and then Node (S, Child).Next =
              Unlinked_View (Before, Child, Replaced).Next
            and then Node (S, Child).Sibling_Order =
              Unlinked_View (Before, Child, Replaced).Sibling_Order);
         Preserve_Pin_Equation (Detached, S);
         pragma Assert
           (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         Namespace_Owners_Live (Detached.Graph);
         Preserve_Namespace_Links (Detached.Graph, S.Graph);
         pragma Assert
           (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
      end if;
      pragma Assert
        (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
      pragma Assert
        (if not Property and then Replaced = Null_Node
          and then Node (Before, Child).Parent = Null_Node
         then
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              Node (S, I).First_Prop = Node (Before, I).First_Prop
              and then Node (S, I).First_Namespace =
                Node (Before, I).First_Namespace
              and then (if I /= Parent then
                Node (S, I).First_Child = Node (Before, I).First_Child)));
      pragma Assert (Node (S, Child).Parent = Parent);
      pragma Assert
        (if Replaced /= Null_Node then
           Replaced in 1 .. Node_Ref (Node_Count (S))
             and then Node (S, Replaced).State = Live
             and then Node (S, Replaced).Parent = Null_Node
             and then Node (S, Replaced).Previous = Null_Node
             and then Node (S, Replaced).Next = Null_Node
             and then Node (S, Child).Previous =
               Unlinked_View (Before, Child, Replaced).Previous
             and then Node (S, Child).Next =
               Unlinked_View (Before, Child, Replaced).Next
             and then Node (S, Child).Sibling_Order =
               Unlinked_View (Before, Child, Replaced).Sibling_Order);
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S)) =>
             Namespace (S, I) = Namespace (Before, I));
      pragma Assert
        (for all I in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S)) =>
           Owner (S, I) = Owner (Before, I));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Same_Pins (Node (S, I), Node (Before, I))
             and then Node (S, I).Kind = Node (Before, I).Kind
             and then Node (S, I).Facade = Node (Before, I).Facade
             and then Node (S, I).Document = Node (Before, I).Document);
      pragma Assert (Valid (S));
      pragma Assert (Can_Edit (S));
      pragma Assert (S.Capacity = Before.Capacity);
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert (Namespace_Count (S) = Namespace_Count (Before));
      pragma Assert (Owner_Count (S) = Owner_Count (Before));
      pragma Assert (S.Marks = Before.Marks);
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Same_Pins (Node (S, I), Node (Before, I))
             and then Node (S, I).Kind = Node (Before, I).Kind
             and then Node (S, I).Facade = Node (Before, I).Facade
             and then (if I /= Child and then I /= Replaced then
               Node (S, I).Parent = Node (Before, I).Parent)
             and then Node (S, I).Document = Node (Before, I).Document);
      pragma Assert
        (if Replaced = Null_Node then
           (if Property then
              Node (S, Parent).Last_Prop = Child
                and then Node (S, Child).Next = Null_Node
            else
              Node (S, Parent).Last_Child = Child
                and then Node (S, Child).Next = Null_Node));
      pragma Assert
        (Valid (Before) and then Can_Edit (Before)
         and then Parent in 1 .. Node_Ref (Node_Count (Before))
         and then Child in 1 .. Node_Ref (Node_Count (Before)));
      pragma Assert_And_Cut
        (Valid (Before) and then Can_Edit (Before)
         and then Parent in 1 .. Node_Ref (Node_Count (Before))
         and then Child in 1 .. Node_Ref (Node_Count (Before))
         and then Valid (S) and then Can_Edit (S)
         and then S.Capacity = Before.Capacity
         and then Snapshot_Namespaces (S) = Snapshot_Namespaces (Before)
         and then Node_Count (S) = Node_Count (Before)
         and then Namespace_Count (S) = Namespace_Count (Before)
         and then Owner_Count (S) = Owner_Count (Before)
         and then S.Marks = Before.Marks
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S)) =>
             Same_Pins (Node (S, I), Node (Before, I))
               and then Node (S, I).Kind = Node (Before, I).Kind
               and then Node (S, I).Facade = Node (Before, I).Facade
               and then (if I /= Child and then I /= Replaced then
                 Node (S, I).Parent = Node (Before, I).Parent)
               and then Node (S, I).Document = Node (Before, I).Document)
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S)) =>
             Namespace (S, I) = Namespace (Before, I))
         and then (for all I in Owner_Ref range
           1 .. Owner_Ref (Owner_Count (S)) =>
             Owner (S, I) = Owner (Before, I))
         and then (if not Property and then Replaced = Null_Node
           and then Node (Before, Child).Parent = Null_Node then
             (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
               Node (S, I).First_Prop = Node (Before, I).First_Prop
               and then Node (S, I).First_Namespace =
                 Node (Before, I).First_Namespace
               and then (if I /= Parent then
                 Node (S, I).First_Child = Node (Before, I).First_Child)))
         and then Node (S, Child).Parent = Parent
         and then (if Replaced = Null_Node then
           (if Property then
              Node (S, Parent).Last_Prop = Child
                and then Node (S, Child).Next = Null_Node
            else
              Node (S, Parent).Last_Child = Child
                and then Node (S, Child).Next = Null_Node))
         and then (if Replaced /= Null_Node then
           Replaced in 1 .. Node_Ref (Node_Count (S))
             and then Node (S, Replaced).State = Live
             and then Node (S, Replaced).Parent = Null_Node
             and then Node (S, Replaced).Previous = Null_Node
             and then Node (S, Replaced).Next = Null_Node
             and then Node (S, Child).Previous =
               Unlinked_View (Before, Child, Replaced).Previous
             and then Node (S, Child).Next =
               Unlinked_View (Before, Child, Replaced).Next
             and then Node (S, Child).Sibling_Order =
               Unlinked_View (Before, Child, Replaced).Sibling_Order));
   end Relink_Marked_Subtree;

   procedure Check_Attachment
     (S : State; Parent, Child : Node_Ref; Property : Boolean;
      Replaced : Node_Ref; Already_Attached : out Boolean;
      Append_Order, Rank_Lift : out Natural;
      Target_Doc : out Node_Ref; Target_B : out Owner_Ref;
      Success : out Boolean)
   is
      Parent_Item : constant Node_View := S.Graph.Nodes (Positive (Parent));
      Child_Item : constant Node_View := S.Graph.Nodes (Positive (Child));
      Last : Node_Ref;
      Remaining : Natural := S.Capacity;
   begin
      pragma Assert (Node_Links_Valid (S.Graph, Positive (Parent)));
      Already_Attached := False;
      Append_Order := 0;
      Rank_Lift := 0;
      Target_Doc :=
        (if Parent_Item.Kind = Document_Node
         then Parent else Parent_Item.Document);
      Target_B := Null_Owner;
      Success := False;

      if Target_Doc /= Null_Node then
         pragma Assert (Target_Doc <= Node_Ref (S.Graph.Node_Used));
         pragma Assert (Node_Pins_Valid (S.Graph, Positive (Parent)));
         Target_B := S.Graph.Nodes (Positive (Target_Doc)).Owner;
         pragma Assert
           (Target_B =
              (if Parent_Item.Kind = Document_Node
               then Parent_Item.Owner else Parent_Item.Doc_Pin));
         if Target_B = Null_Owner
           or else Target_B > Owner_Ref (S.Graph.Owner_Used)
           or else S.Graph.Owners (Positive (Target_B)).State /= Live
         then
            return;
         end if;
      end if;

      if Replaced /= Null_Node
        and then
          (Parent_Item.Kind /= Document_Node
           or else Child_Item.Kind /= Element_Node
           or else Replaced > Node_Ref (S.Graph.Node_Used)
           or else Replaced = Parent
           or else Replaced = Child
           or else S.Graph.Nodes (Positive (Replaced)).State /= Live
           or else S.Graph.Nodes (Positive (Replaced)).Kind /= Element_Node
           or else S.Graph.Nodes (Positive (Replaced)).Parent /= Parent)
      then
         return;
      end if;

      if Parent = Child or else Is_Ancestor (S, Child, Parent)
        or else (Property /= (Child_Item.Kind = Attribute_Node))
        or else Child_Item.Kind = Document_Node
        or else (Property and then Parent_Item.Kind /= Element_Node)
        or else (not Property and then
          Parent_Item.Kind not in Document_Node | Element_Node | Attribute_Node)
        or else (Parent_Item.Kind = Attribute_Node
          and then Child_Item.Kind /= Text_Node)
        or else (Parent_Item.Kind = Document_Node
          and then Child_Item.Kind not in Element_Node | Comment_Node
            | Processing_Instruction_Node)
      then
         return;
      end if;

      Last := (if Property then Parent_Item.Last_Prop else Parent_Item.Last_Child);
      Already_Attached := Replaced = Null_Node
        and then Child_Item.Parent = Parent and then Last = Child;
      if not Already_Attached then
         if Replaced = Null_Node and then Last /= Null_Node
           and then S.Graph.Nodes (Positive (Last)).Sibling_Order = Natural'Last
         then
            return;
         end if;

         Append_Order := (if Replaced /= Null_Node then
            S.Graph.Nodes (Positive (Replaced)).Sibling_Order
           elsif Last = Null_Node then 0
           else S.Graph.Nodes (Positive (Last)).Sibling_Order + 1);
         if Child_Item.Tree_Rank <= Parent_Item.Tree_Rank then
            if Parent_Item.Tree_Rank = Natural'Last then
               return;
            end if;
            Rank_Lift := Parent_Item.Tree_Rank + 1 - Child_Item.Tree_Rank;
         end if;
         pragma Assert (Parent_Item.Tree_Rank < Child_Item.Tree_Rank + Rank_Lift);

         if Parent_Item.Kind = Document_Node and then Child_Item.Kind = Element_Node then
            Last := Parent_Item.First_Child;
            while Last /= Null_Node and then Remaining > 0 loop
               pragma Loop_Variant (Decreases => Remaining);
               if Last > Node_Ref (S.Graph.Node_Used) then
                  return;
               end if;
               if S.Graph.Nodes (Positive (Last)).Kind = Element_Node
                 and then Last /= Child and then Last /= Replaced
               then
                  return;
               end if;
               Last := S.Graph.Nodes (Positive (Last)).Next;
               Remaining := Remaining - 1;
            end loop;
            if Last /= Null_Node then
               return;
            end if;
         end if;
      end if;

      pragma Assert (not Ancestor (S, Child, Parent));
      Success := True;
   end Check_Attachment;

   procedure Prepare_Attachment
     (S : in out State; Parent, Child : Node_Ref; Property : Boolean;
      Replaced : Node_Ref; Already_Attached : out Boolean;
      Append_Order, Rank_Lift : out Natural;
      Target_Doc : out Node_Ref; Target_B : out Owner_Ref;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S) with Ghost;
      Original_Namespaces : constant Namespace_View_Array :=
        Snapshot_Namespaces (S) with Ghost;
      --  Ordering facts from Check_Attachment, as scalars.
      Child_Rank, Parent_Rank, Last_Order : Natural := 0 with Ghost;
      Last_Ref : Node_Ref := Null_Node with Ghost;
   begin
      pragma Assert (Original_Nodes = Snapshot_Nodes (Before));
      pragma Assert (Node_Links_Valid (S.Graph, Positive (Parent)));
      pragma Assert (Node_Links_Valid (S.Graph, Positive (Child)));
      Check_Attachment
        (S, Parent, Child, Property, Replaced, Already_Attached,
         Append_Order, Rank_Lift, Target_Doc, Target_B, Success);
      pragma Assert (Same_Graph (S, Before));
      pragma Assert (S.Graph.Nodes = Before.Graph.Nodes);
      Child_Rank := Node (S, Child).Tree_Rank;
      Parent_Rank := Node (S, Parent).Tree_Rank;
      Last_Ref :=
        (if Property then Node (S, Parent).Last_Prop
         else Node (S, Parent).Last_Child);
      Last_Order :=
        (if Last_Ref in 1 .. Node_Ref (Node_Count (S))
         then Node (S, Last_Ref).Sibling_Order else 0);
      pragma Assert
        (if Success and then not Already_Attached then
           Rank_Lift <= Natural'Last - Child_Rank
           and then Parent_Rank < Child_Rank + Rank_Lift
           and then (if Replaced = Null_Node then
             Last_Ref = Null_Node or else
               (Last_Ref in 1 .. Node_Ref (Node_Count (S))
                and then Last_Ref /= Child
                and then Last_Order < Append_Order)));
      pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
      Same_Graph_Snapshots (S, Before);
      if not Success then
         pragma Assert (Same_Graph (S, Before));
         pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
      else
         Prepare_Subtree (S, Child, Rank_Lift, Success);
         pragma Assert (Same_Graph (S, Before));
         Same_Graph_Snapshots (S, Before);
         pragma Assert (S.Graph.Nodes'First = Before.Graph.Nodes'First);
         pragma Assert (S.Graph.Nodes'Last = Before.Graph.Nodes'Last);
         pragma Assert (for all I in S.Graph.Nodes'Range =>
           S.Graph.Nodes (I) = Before.Graph.Nodes (I));
         pragma Assert (S.Graph.Nodes = Before.Graph.Nodes);
         pragma Assert (Valid (S) and then Can_Edit (S));
         pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
         if not Success then
            pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
            pragma Assert (Same_Graph (S, Before));
            pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
         else
            pragma Assert
              (for all I in 1 .. S.Graph.Node_Used =>
                (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
            if Target_Doc /= Null_Node then
               pragma Assert
                 (S.Graph.Owners (Positive (Target_B)).State = Live);
            end if;
            for I in 0 .. S.Graph.Node_Used loop
               pragma Loop_Variant (Increases => I);
               pragma Loop_Invariant (Success);
               pragma Loop_Invariant
                 (for all J in 1 .. I =>
                   (if S.Marks (J) then
                      S.Graph.Nodes (J).Document = Null_Node
                        or else S.Graph.Nodes (J).Document = Target_Doc));
               if I < S.Graph.Node_Used
                 and then S.Marks (Positive (I + 1))
                 and then S.Graph.Nodes (Positive (I + 1)).Document /= Null_Node
                 and then S.Graph.Nodes (Positive (I + 1)).Document /= Target_Doc
               then
                  Success := False;
                  pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
                  pragma Assert (Same_Graph (S, Before));
                  pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
                  exit;
               end if;
            end loop;
            if Success and then Target_Doc /= Null_Node
              and then S.Graph.Owners (Positive (Target_B)).References >
                Natural'Last - S.Graph.Node_Used
            then
               Success := False;
               pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
               pragma Assert (Same_Graph (S, Before));
               pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
            end if;
         end if;
      end if;
      pragma Assert (Same_Graph (S, Before));
      Same_Graph_Snapshots (S, Before);
      if Success then
         if Target_Doc /= Null_Node then
            pragma Assert
              (S.Graph.Owners (Positive (Target_B)).References <=
                 Natural'Last - S.Graph.Node_Used);
         end if;
         pragma Assert
           (for all I in 1 .. S.Graph.Node_Used =>
             (if S.Marks (I) then
                S.Graph.Nodes (I).Document = Null_Node
                  or else S.Graph.Nodes (I).Document = Target_Doc));
         Same_Ancestor
           (Snapshot_Nodes (Before), Snapshot_Nodes (S),
            Node_Count (S), Child, Parent);
         pragma Assert (not Ancestor (S, Child, Parent));
      end if;
      pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I) = Node (Before, I));
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert
        (Node (S, Child).Tree_Rank = Child_Rank
         and then Node (S, Parent).Tree_Rank = Parent_Rank
         and then (if Property then Node (S, Parent).Last_Prop
                   else Node (S, Parent).Last_Child) = Last_Ref
         and then (if Last_Ref in 1 .. Node_Ref (Node_Count (S)) then
           Node (S, Last_Ref).Sibling_Order = Last_Order));
      pragma Assert
        (if Success and then not Already_Attached then
           Rank_Lift <= Natural'Last - Node (S, Child).Tree_Rank
           and then Node (S, Parent).Tree_Rank <
             Node (S, Child).Tree_Rank + Rank_Lift
           and then (if Replaced = Null_Node then
             (declare
                Last : constant Node_Ref :=
                  (if Property then Node (S, Parent).Last_Prop
                   else Node (S, Parent).Last_Child);
              begin Last = Null_Node or else
                (Last in 1 .. Node_Ref (Node_Count (S))
                 and then Last /= Child
                 and then Node (S, Last).Sibling_Order < Append_Order))));
   end Prepare_Attachment;

   procedure Attach
     (S : in out State; Parent, Child : Node_Ref;
      Property : Boolean; Success : out Boolean;
      Replaced : Node_Ref := Null_Node)
   is
      Append_Order : Natural := 0;
      Rank_Lift : Natural := 0;
      Already_Attached : Boolean;
      Target_Doc : Node_Ref;
      Target_B : Owner_Ref := Null_Owner;
      Before : constant State := S with Ghost;
      Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S) with Ghost;
      Original_Namespaces : constant Namespace_View_Array :=
        Snapshot_Namespaces (S) with Ghost;
   begin
      pragma Assert (Original_Nodes = Snapshot_Nodes (Before));
      Prepare_Attachment
        (S, Parent, Child, Property, Replaced, Already_Attached,
         Append_Order, Rank_Lift, Target_Doc, Target_B, Success);
      pragma Assert (Same_Graph (S, Before));
      Same_Graph_Snapshots (Before, S);
      if not Success then
         pragma Assert (Same_Graph (S, Before));
         pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
      else
         declare
            Previous_Namespaces : constant Namespace_View_Array :=
              Snapshot_Namespaces (S) with Ghost;
            Previous_Nodes : constant Node_View_Array := S.Graph.Nodes with Ghost;
            Previous_Marks : constant Mark_Array := S.Marks with Ghost;
            Previous_Used : constant Natural := S.Graph.Node_Used with Ghost;
         begin
            pragma Assert
              (for all I in 1 .. Previous_Used =>
                (if Previous_Marks (I) then Previous_Nodes (I).State = Live
                  and then (Previous_Nodes (I).Document = Null_Node
                    or else Previous_Nodes (I).Document = Target_Doc)));
            if not Already_Attached then
               pragma Assert
                 (for all I in 1 .. S.Graph.Node_Used =>
                   (if S.Marks (I) then
                      S.Graph.Nodes (I).Document = Null_Node
                        or else S.Graph.Nodes (I).Document = Target_Doc));
               Same_Ancestor
                 (Snapshot_Nodes (Before), Snapshot_Nodes (S),
                  Node_Count (S), Child, Parent);
               pragma Assert
                 (not Ancestor_In_Nodes
                    (Snapshot_Nodes (S), Node_Count (S), Child, Parent));
               pragma Assert (not Ancestor (S, Child, Parent));
               pragma Assert (not S.Marks (Positive (Parent)));
               pragma Assert (S.Marks (Positive (Child)));
               pragma Assert
                 (Previous_Namespaces = Snapshot_Namespaces (S));
               pragma Assert (Previous_Marks = S.Marks);
               Relink_Marked_Subtree
                 (S, Parent, Child, Property, Append_Order, Rank_Lift, Replaced);
               pragma Assert
                 (Snapshot_Namespaces (S) = Previous_Namespaces);
               pragma Assert (S.Marks = Previous_Marks);
            end if;
            Compose_Namespace_Snapshots
              (Snapshot_Namespaces (Before), Previous_Namespaces,
               Snapshot_Namespaces (S));
            Preserve_Marked_State
              (Previous_Nodes, S.Graph.Nodes, Previous_Marks, S.Marks,
               Previous_Used, Target_Doc);
            pragma Assert (S.Marks = Previous_Marks);
            pragma Assert (S.Graph.Node_Used = Previous_Used);
         end;
         pragma Assert
           (if not Property and then Replaced = Null_Node
             and then Node (Before, Child).Parent = Null_Node then
               (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
                  Node (S, I).First_Prop = Node (Before, I).First_Prop
                  and then Node (S, I).First_Namespace =
                    Node (Before, I).First_Namespace
                  and then (if I /= Parent then
                    Node (S, I).First_Child = Node (Before, I).First_Child)));
         pragma Assert
           (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         pragma Assert (Node (S, Child).Parent = Parent);
         pragma Assert (Valid (S) and then Can_Edit (S));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Namespace_Count (S)) =>
                Namespace (S, I) = Namespace (Before, I));
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              Node (S, I).State = Node (Before, I).State
                and then Node (S, I).Facade = Node (Before, I).Facade);
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              (if I /= Child and then I /= Replaced then
                 Node (S, I).Parent = Node (Before, I).Parent));
         declare
            Previous_Namespaces : constant Namespace_View_Array :=
              Snapshot_Namespaces (S) with Ghost;
         begin
            if Target_Doc /= Null_Node then
               pragma Assert (Target_Doc <= Node_Ref (Node_Count (S)));
               pragma Assert (Node (S, Target_Doc).Kind = Document_Node);
               pragma Assert (Node (S, Target_Doc).State in Live | Tombstone);
               pragma Assert (Node (S, Target_Doc).Owner = Target_B);
               pragma Assert (Target_B <= Owner_Ref (Owner_Count (S)));
               pragma Assert
                 (S.Graph.Owners (Positive (Target_B)).References <=
                    Natural'Last - S.Graph.Node_Used);
               pragma Assert (Owner (S, Target_B).State = Live);
               pragma Assert
                 (for all J in 1 .. S.Graph.Node_Used =>
                   (if S.Marks (J) then S.Graph.Nodes (J).State = Live));
               pragma Assert
                 (for all J in 1 .. S.Graph.Node_Used =>
                   (if S.Marks (J) then
                      S.Graph.Nodes (J).Document = Null_Node
                        or else S.Graph.Nodes (J).Document = Target_Doc));
               Set_Marked_Document (S, Target_Doc, Target_B);
               pragma Assert
                 (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
               pragma Assert
                 (for all I in 1 .. S.Graph.Node_Used =>
                   (if S.Marks (I) then
                      S.Graph.Nodes (I).Document = Target_Doc
                        and then S.Graph.Nodes (I).Doc_Pin = Target_B));
            else
               pragma Assert
                 (for all I in 1 .. S.Graph.Node_Used =>
                   (if S.Marks (I) then
                      S.Graph.Nodes (I).Document = Null_Node));
            end if;
            Compose_Namespace_Snapshots
              (Snapshot_Namespaces (Before), Previous_Namespaces,
               Snapshot_Namespaces (S));
         end;
         pragma Assert (Node (S, Child).Parent = Parent);
         pragma Assert (Node_Children_Valid (S.Graph, Positive (Parent)));
         pragma Assert
           (if Replaced = Null_Node then
              (if Property then
                 Node (S, Parent).Last_Prop = Child
                   and then Node (S, Child).Next = Null_Node
               else
                 Node (S, Parent).Last_Child = Child
                   and then Node (S, Child).Next = Null_Node));
         Success := True;
         pragma Assert
           (if not Property and then Replaced = Null_Node
             and then Node (Before, Child).Parent = Null_Node then
               (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
                  Node (S, I).First_Prop = Node (Before, I).First_Prop
                  and then Node (S, I).First_Namespace =
                    Node (Before, I).First_Namespace
                  and then (if I /= Parent then
                    Node (S, I).First_Child = Node (Before, I).First_Child)));
         pragma Assert
           (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         pragma Assert
           (if Facades_Present (Before) then Facades_Present (S));
         pragma Assert (Valid (S));
         pragma Assert (Can_Edit (S));
         pragma Assert
           (S.Capacity = Before.Capacity
            and then Node_Count (S) = Node_Count (Before)
            and then Namespace_Count (S) = Namespace_Count (Before)
            and then Owner_Count (S) = Owner_Count (Before));
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              Node (S, I).State = Node (Before, I).State);
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              Node (S, I).Facade = Node (Before, I).Facade
                and then Node (S, I).Kind = Node (Before, I).Kind);
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              Node (S, I).Kind = Original_Nodes (Positive (I)).Kind);
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              (if I /= Child and then I /= Replaced then
                 Node (S, I).Parent = Node (Before, I).Parent));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Namespace_Count (S)) =>
                Namespace (S, I) = Namespace (Before, I));
         pragma Assert
           (if Replaced /= Null_Node then
              Replaced in 1 .. Node_Ref (Node_Count (S))
                and then Node (S, Replaced).State = Live
                and then Node (S, Replaced).Parent = Null_Node
                and then Node (S, Replaced).Previous = Null_Node
                and then Node (S, Replaced).Next = Null_Node
                and then Node (S, Child).Previous =
                  Unlinked_View (Before, Child, Replaced).Previous
                and then Node (S, Child).Next =
                  Unlinked_View (Before, Child, Replaced).Next
                and then Node (S, Child).Sibling_Order =
                  Unlinked_View (Before, Child, Replaced).Sibling_Order);
         pragma Assert
           (Target_Doc = (if Node (Before, Parent).Kind = Document_Node
                          then Parent else Node (Before, Parent).Document));
         pragma Assert
           (if Target_Doc /= Null_Node then
              Target_B = Node (Before, Target_Doc).Owner);
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
              (if Snapshot_Marks (S) (Positive (I)) then
                 Node (S, I).Document = Target_Doc
                   and then (Target_Doc = Null_Node
                     or else Node (S, I).Doc_Pin = Target_B)));
         pragma Assert
           (if not Property and then Node (Before, Parent).Kind = Attribute_Node
             and then Text_Attribute_Content (Before, Parent)
             and then Node (Before, Child).Kind = Text_Node
             and then Node (Before, Child).Parent = Null_Node
             and then Node (Before, Child).First_Child = Null_Node
             and then Node (Before, Child).First_Prop = Null_Node
             and then Node (Before, Child).First_Namespace = Null_Namespace
            then Replaced = Null_Node);
         for I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
            if Node (S, I).State = Live and then Node (S, I).Parent = Parent
              and then Node (S, I).Kind /= Attribute_Node
            then
               if I /= Child then
                  pragma Assert
                    (if not Property
                       and then Node (Before, Parent).Kind = Attribute_Node
                       and then Text_Attribute_Content (Before, Parent)
                       and then Node (Before, Child).Kind = Text_Node
                       and then Node (Before, Child).Parent = Null_Node
                       and then Node (Before, Child).First_Child = Null_Node
                       and then Node (Before, Child).First_Prop = Null_Node
                       and then Node (Before, Child).First_Namespace =
                         Null_Namespace
                     then Node (Before, I).Parent = Parent);
                  pragma Assert
                    (if not Property
                       and then Node (Before, Parent).Kind = Attribute_Node
                       and then Text_Attribute_Content (Before, Parent)
                       and then Node (Before, Child).Kind = Text_Node
                       and then Node (Before, Child).Parent = Null_Node
                       and then Node (Before, Child).First_Child = Null_Node
                       and then Node (Before, Child).First_Prop = Null_Node
                       and then Node (Before, Child).First_Namespace =
                         Null_Namespace
                     then Node (Before, I).Kind = Text_Node);
               end if;
               pragma Assert
                 (if not Property
                    and then Node (Before, Parent).Kind = Attribute_Node
                    and then Text_Attribute_Content (Before, Parent)
                    and then Node (Before, Child).Kind = Text_Node
                    and then Node (Before, Child).Parent = Null_Node
                    and then Node (Before, Child).First_Child = Null_Node
                    and then Node (Before, Child).First_Prop = Null_Node
                    and then Node (Before, Child).First_Namespace =
                      Null_Namespace
                  then Node (S, I).Kind = Text_Node);
               pragma Assert
                 (if not Property
                    and then Node (Before, Parent).Kind = Attribute_Node
                    and then Text_Attribute_Content (Before, Parent)
                    and then Node (Before, Child).Kind = Text_Node
                    and then Node (Before, Child).Parent = Null_Node
                    and then Node (Before, Child).First_Child = Null_Node
                    and then Node (Before, Child).First_Prop = Null_Node
                    and then Node (Before, Child).First_Namespace =
                      Null_Namespace
                  then Node (S, I).First_Child = Null_Node);
               pragma Assert
                 (if not Property
                    and then Node (Before, Parent).Kind = Attribute_Node
                    and then Text_Attribute_Content (Before, Parent)
                    and then Node (Before, Child).Kind = Text_Node
                    and then Node (Before, Child).Parent = Null_Node
                    and then Node (Before, Child).First_Child = Null_Node
                    and then Node (Before, Child).First_Prop = Null_Node
                    and then Node (Before, Child).First_Namespace =
                      Null_Namespace
                  then Node (S, I).First_Prop = Null_Node);
               pragma Assert
                 (if not Property
                    and then Node (Before, Parent).Kind = Attribute_Node
                    and then Text_Attribute_Content (Before, Parent)
                    and then Node (Before, Child).Kind = Text_Node
                    and then Node (Before, Child).Parent = Null_Node
                    and then Node (Before, Child).First_Child = Null_Node
                    and then Node (Before, Child).First_Prop = Null_Node
                    and then Node (Before, Child).First_Namespace =
                      Null_Namespace
                  then Node (S, I).First_Namespace = Null_Namespace);
            end if;
            pragma Loop_Invariant
              (if not Property
                 and then Node (Before, Parent).Kind = Attribute_Node
                 and then Text_Attribute_Content (Before, Parent)
                 and then Node (Before, Child).Kind = Text_Node
                 and then Node (Before, Child).Parent = Null_Node
                 and then Node (Before, Child).First_Child = Null_Node
                 and then Node (Before, Child).First_Prop = Null_Node
                 and then Node (Before, Child).First_Namespace = Null_Namespace
               then
                 (for all J in Node_Ref range 1 .. I =>
                   (if Node (S, J).State = Live
                     and then Node (S, J).Parent = Parent
                     and then Node (S, J).Kind /= Attribute_Node then
                       Node (S, J).Kind = Text_Node
                       and then Node (S, J).First_Child = Null_Node
                       and then Node (S, J).First_Prop = Null_Node
                       and then Node (S, J).First_Namespace = Null_Namespace)));
         end loop;
         pragma Assert
           (if not Property and then Node (Before, Parent).Kind = Attribute_Node
             and then Text_Attribute_Content (Before, Parent)
             and then Node (Before, Child).Kind = Text_Node
             and then Node (Before, Child).Parent = Null_Node
             and then Node (Before, Child).First_Child = Null_Node
             and then Node (Before, Child).First_Prop = Null_Node
             and then Node (Before, Child).First_Namespace = Null_Namespace
            then Text_Attribute_Content (S, Parent));
         pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
      end if;
      pragma Assert (if not Success then Same_Graph (S, Before));
      pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
   end Attach;

end XML3_DOM.Marking;
