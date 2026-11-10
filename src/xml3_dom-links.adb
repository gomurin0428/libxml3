package body XML3_DOM.Links with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Unlink_Lemma (Before, After : State; N : Node_Ref) is
   begin
      for I in 1 .. Before.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Siblings_Valid (Before.Graph, Positive (N)));
         pragma Assert (Node_Pins_Valid (After.Graph, I));
         pragma Assert (Node_Siblings_Valid (After.Graph, I));
         pragma Assert (Node_Children_Valid (After.Graph, I));
         pragma Assert (Node_Namespaces_Valid (After.Graph, I));
         pragma Loop_Invariant
           (for all K in 1 .. I => Node_Links_Valid (After.Graph, K));
      end loop;
   end Unlink_Lemma;

   procedure Unlink_Tail_Lemma
     (S : State; Parent, Child : Node_Ref; Property : Boolean)
   is
      Item : constant Node_View := Node (S, Child);
      Tail : constant Node_Ref :=
        (if Property then Node (S, Parent).Last_Prop
         else Node (S, Parent).Last_Child);
   begin
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Child)));
      pragma Assert
        (if Item.Parent = Parent and then Item.Next = Null_Node then
           (if Property then Node (S, Parent).Last_Prop = Child
            else Node (S, Parent).Last_Child = Child));
      pragma Assert
        (if Item.Parent = Parent and then Item.Next = Null_Node then
           Tail = Child);
      pragma Assert
        (not (Item.Parent = Parent and then Item.Next = Null_Node));
      pragma Assert
        (if Property then
           Unlinked_View (S, Child, Parent).Last_Prop =
             Node (S, Parent).Last_Prop
         else
           Unlinked_View (S, Child, Parent).Last_Child =
             Node (S, Parent).Last_Child);
      pragma Assert
        (if Tail /= Null_Node then
           Unlinked_View (S, Child, Tail).Sibling_Order =
             Node (S, Tail).Sibling_Order);
   end Unlink_Tail_Lemma;

   procedure Append_Lemma
     (Before, After : State; Parent, Child : Node_Ref; Position : Natural)
   is
   begin
      for I in 1 .. Before.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Siblings_Valid (Before.Graph, Positive (Child)));
         pragma Assert (Node_Children_Valid (Before.Graph, Positive (Parent)));
         pragma Assert (Node_Pins_Valid (After.Graph, I));
         pragma Assert (Node_Siblings_Valid (After.Graph, I));
         pragma Assert (Node_Children_Valid (After.Graph, I));
         pragma Assert (Node_Namespaces_Valid (After.Graph, I));
         pragma Loop_Invariant
           (for all K in 1 .. I => Node_Links_Valid (After.Graph, K));
      end loop;
   end Append_Lemma;

   procedure Append_Child_Links
     (S : in out State; Parent, Child : Node_Ref; Position : Natural)
   is
      Before : constant State := S with Ghost;
      Parent_Item : Node_View := S.Graph.Nodes (Positive (Parent));
      Child_Item : Node_View := S.Graph.Nodes (Positive (Child));
      Property : constant Boolean := Child_Item.Kind = Attribute_Node;
      Last : constant Node_Ref :=
        (if Property then Parent_Item.Last_Prop else Parent_Item.Last_Child);
   begin
      pragma Assert (Node_Siblings_Valid (Before.Graph, Positive (Child)));
      pragma Assert (Node_Children_Valid (Before.Graph, Positive (Parent)));
      pragma Assert
        ((Parent_Item.First_Child = Null_Node) =
           (Parent_Item.Last_Child = Null_Node));
      pragma Assert
        ((Parent_Item.First_Prop = Null_Node) =
           (Parent_Item.Last_Prop = Null_Node));
      pragma Assert
        (Last = Null_Node or else
          (Last in 1 .. Node_Ref (Node_Count (S))
           and then Node (S, Last).Sibling_Order < Position));
      Child_Item.Parent := Parent;
      Child_Item.Previous := Last;
      Child_Item.Next := Null_Node;
      Child_Item.Sibling_Order := Position;
      if Last = Null_Node then
         if Property then Parent_Item.First_Prop := Child;
         else Parent_Item.First_Child := Child;
         end if;
      else
         S.Graph.Nodes (Positive (Last)).Next := Child;
      end if;
      if Property then Parent_Item.Last_Prop := Child;
      else Parent_Item.Last_Child := Child;
      end if;
      S.Graph.Nodes (Positive (Parent)) := Parent_Item;
      S.Graph.Nodes (Positive (Child)) := Child_Item;
      pragma Assert (for all I in 1 .. S.Graph.Ns_Used =>
        S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      pragma Assert (for all I in 1 .. S.Graph.Owner_Used =>
        S.Graph.Owners (I) = Before.Graph.Owners (I));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
          Same_Pins (Node (S, I), Node (Before, I)));
      pragma Assert
        (if Property then
           Node (S, Parent).Last_Prop = Child
             and then Node (S, Child).Next = Null_Node
         else
           Node (S, Parent).Last_Child = Child
             and then Node (S, Child).Next = Null_Node);
      pragma Assert (Pins_In_Range (S));
      Append_Lemma (Before, S, Parent, Child, Position);
      Preserve_Pin_Equation (Before, S);
      Preserve_Namespace_Links (Before.Graph, S.Graph);
   end Append_Child_Links;

   procedure Replace_Lemma
     (Before, After : State; Parent, New_Child, Old_Child : Node_Ref)
   is
   begin
      for I in 1 .. Before.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert
           (Node_Siblings_Valid (Before.Graph, Positive (Old_Child)));
         pragma Assert
           (Node_Siblings_Valid (Before.Graph, Positive (New_Child)));
         pragma Assert
           (Node_Children_Valid (Before.Graph, Positive (Parent)));
         pragma Assert (Node_Pins_Valid (After.Graph, I));
         pragma Assert (Node_Siblings_Valid (After.Graph, I));
         pragma Assert (Node_Children_Valid (After.Graph, I));
         pragma Assert (Node_Namespaces_Valid (After.Graph, I));
         pragma Loop_Invariant
           (for all K in 1 .. I => Node_Links_Valid (After.Graph, K));
      end loop;
   end Replace_Lemma;

   procedure Replace_Child_Links
     (S : in out State; Parent, New_Child, Old_Child : Node_Ref)
   is
      Before : constant State := S with Ghost;
      Parent_Item : Node_View := S.Graph.Nodes (Positive (Parent));
      New_Item : Node_View := S.Graph.Nodes (Positive (New_Child));
      Old_Item : Node_View := S.Graph.Nodes (Positive (Old_Child));
      Old_Previous : constant Node_Ref := Old_Item.Previous;
      Old_Next : constant Node_Ref := Old_Item.Next;
   begin
      pragma Assert (Old_Item.Parent = Parent);
      pragma Assert (Old_Item.Kind = Element_Node);
      pragma Assert (New_Item.Parent = Null_Node);
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Parent)));
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Old_Child)));
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (New_Child)));
      pragma Assert (Node_Children_Valid (S.Graph, Positive (Parent)));
      if Old_Item.Previous /= Null_Node then
         pragma Assert (Old_Item.Previous <= Node_Ref (Node_Count (S)));
         pragma Assert
           (Node_Siblings_Valid (S.Graph, Positive (Old_Item.Previous)));
      end if;
      if Old_Item.Next /= Null_Node then
         pragma Assert (Old_Item.Next <= Node_Ref (Node_Count (S)));
         pragma Assert
           (Node_Siblings_Valid (S.Graph, Positive (Old_Item.Next)));
      end if;
      pragma Assert
        ((Old_Item.Previous = Null_Node) =
           (Parent_Item.First_Child = Old_Child));
      pragma Assert
        ((Old_Item.Next = Null_Node) =
           (Parent_Item.Last_Child = Old_Child));
      pragma Assert
        (Old_Item.Previous = Null_Node
         or else Old_Item.Previous /= Old_Child);
      pragma Assert
        (Old_Item.Next = Null_Node or else Old_Item.Next /= Old_Child);
      pragma Assert
        (Old_Item.Previous = Null_Node or else Old_Item.Previous /= New_Child);
      pragma Assert
        (Old_Item.Next = Null_Node or else Old_Item.Next /= New_Child);
      pragma Assert (Old_Item.Previous /= Parent);
      pragma Assert (Old_Item.Next /= Parent);
      pragma Assert
        (Old_Item.Previous = Null_Node
         or else Old_Item.Next = Null_Node
         or else Old_Item.Previous /= Old_Item.Next);
      New_Item.Parent := Parent;
      New_Item.Previous := Old_Item.Previous;
      New_Item.Next := Old_Item.Next;
      New_Item.Sibling_Order := Old_Item.Sibling_Order;
      if Old_Item.Previous = Null_Node then
         Parent_Item.First_Child := New_Child;
      else
         pragma Assert (Old_Item.Previous <= Node_Ref (Node_Count (S)));
         S.Graph.Nodes (Positive (Old_Item.Previous)).Next := New_Child;
      end if;
      if Old_Item.Next = Null_Node then
         Parent_Item.Last_Child := New_Child;
      else
         pragma Assert (Old_Item.Next <= Node_Ref (Node_Count (S)));
         S.Graph.Nodes (Positive (Old_Item.Next)).Previous := New_Child;
      end if;
      Old_Item.Parent := Null_Node;
      Old_Item.Previous := Null_Node;
      Old_Item.Next := Null_Node;
      S.Graph.Nodes (Positive (Parent)) := Parent_Item;
      S.Graph.Nodes (Positive (New_Child)) := New_Item;
      S.Graph.Nodes (Positive (Old_Child)) := Old_Item;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant
           (for all K in 1 .. I =>
             S.Graph.Nodes (K) =
               Replaced_View
                 (Before, Parent, New_Child, Old_Child, Node_Ref (K)));
         if Node_Ref (I) = New_Child
           or else Node_Ref (I) = Old_Child
           or else Node_Ref (I) = Parent
           or else (Old_Previous /= Null_Node
             and then Node_Ref (I) = Old_Previous)
           or else (Old_Next /= Null_Node
             and then Node_Ref (I) = Old_Next)
         then
            pragma Assert
              (S.Graph.Nodes (I) =
                 Replaced_View
                   (Before, Parent, New_Child, Old_Child, Node_Ref (I)));
         else
            pragma Assert
              (S.Graph.Nodes (I) =
                 Replaced_View
                   (Before, Parent, New_Child, Old_Child, Node_Ref (I)));
         end if;
      end loop;
      pragma Assert
        (for all I in 1 .. S.Capacity =>
           S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      Replace_Lemma (Before, S, Parent, New_Child, Old_Child);
      pragma Assert
        (for all I in 1 .. S.Graph.Ns_Used =>
           S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           Namespace_Parent_Preserved
             (Before.Graph.Nodes (I), S.Graph.Nodes (I)));
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      Preserve_Pin_Equation (Before, S);
   end Replace_Child_Links;

   procedure Tail_Order_Bound
     (S : State; Parent, N : Node_Ref)
   is
      Current : Node_Ref := N;
   begin
      while Node (S, Current).Next /= Null_Node loop
         pragma Loop_Variant
           (Decreases => Natural'Last -
              Node (S, Current).Sibling_Order);
         pragma Loop_Invariant
           (Current in 1 .. Node_Ref (Node_Count (S)));
         pragma Loop_Invariant (Node (S, Current).State = Live);
         pragma Loop_Invariant (Node (S, Current).Parent = Parent);
         pragma Loop_Invariant (Node (S, Current).Kind /= Attribute_Node);
         pragma Loop_Invariant
           (if Current /= N then
              Node (S, Current).Previous /= Null_Node);
         pragma Loop_Invariant
           (Node (S, N).Sibling_Order <= Node (S, Current).Sibling_Order);
         pragma Loop_Invariant
           (if Current /= N then
              Node (S, N).Sibling_Order <
                Node (S, Current).Sibling_Order);
         pragma Assert (Node_Siblings_Valid
           (S.Graph, Positive (Current)));
         Current := Node (S, Current).Next;
      end loop;
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Current)));
      pragma Assert
        (Current = Node (S, Parent).Last_Child);
   end Tail_Order_Bound;

   procedure Placed_Lemma
     (Before, After : State; Parent, Child, Old_Last, Previous, Next : Node_Ref;
      Threshold, Old_Order : Natural)
   is
      N : Node_View;
   begin
      for I in 1 .. Before.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Siblings_Valid (Before.Graph, I));
         pragma Assert (Node_Children_Valid (Before.Graph, I));
         if Before.Graph.Nodes (I).State = Live
           and then Before.Graph.Nodes (I).Parent = Parent
           and then Before.Graph.Nodes (I).Kind /= Attribute_Node
         then
            Tail_Order_Bound (Before, Parent, Node_Ref (I));
            if Before.Graph.Nodes (I).Next /= Null_Node then
               Tail_Order_Bound
                 (Before, Parent, Before.Graph.Nodes (I).Next);
            end if;
            if Before.Graph.Nodes (I).Previous /= Null_Node then
               Tail_Order_Bound
                 (Before, Parent, Before.Graph.Nodes (I).Previous);
            end if;
         end if;
         pragma Assert (Node_Pins_Valid (After.Graph, I));
         N := After.Graph.Nodes (I);
         pragma Assert (N.State = Before.Graph.Nodes (I).State);
         pragma Assert (N.Parent = Before.Graph.Nodes (I).Parent);
         pragma Assert (N.Tree_Rank = Before.Graph.Nodes (I).Tree_Rank);
         pragma Assert (N.Kind = Before.Graph.Nodes (I).Kind);
         if N.State = Live then
            if N.Parent = Null_Node then
               pragma Assert (N.Previous = Null_Node and N.Next = Null_Node);
            else
               pragma Assert (Live_Node (After.Graph, N.Parent));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Parent)).Tree_Rank <
                    N.Tree_Rank and then N.Parent /= Node_Ref (I));
            end if;
            if N.Previous /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.Previous));
               pragma Assert (N.Previous /= Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Previous)).Next =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Previous)).Parent =
                    N.Parent);
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Previous)).Sibling_Order <
                    N.Sibling_Order);
               pragma Assert
                 ((After.Graph.Nodes (Positive (N.Previous)).Kind =
                     Attribute_Node) = (N.Kind = Attribute_Node));
            end if;
         end if;
         if N.State = Live and then N.Next /= Null_Node then
            pragma Assert (Live_Node (After.Graph, N.Next));
            pragma Assert
              (After.Graph.Nodes (Positive (N.Next)).Previous = Node_Ref (I));
         end if;
         pragma Loop_Invariant
           (for all K in 1 .. I =>
             (if After.Graph.Nodes (K).State = Live then
               (if After.Graph.Nodes (K).Previous /= Null_Node then
                 Live_Node (After.Graph, After.Graph.Nodes (K).Previous)
                 and then After.Graph.Nodes
                   (Positive (After.Graph.Nodes (K).Previous)).Sibling_Order <
                     After.Graph.Nodes (K).Sibling_Order)
               and then (if After.Graph.Nodes (K).Next /= Null_Node then
                 Live_Node (After.Graph, After.Graph.Nodes (K).Next)
                 and then After.Graph.Nodes
                   (Positive (After.Graph.Nodes (K).Next)).Previous =
                     Node_Ref (K))));
      end loop;
      for I in 1 .. After.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Siblings_Valid (Before.Graph, I));
         pragma Assert (Node_Children_Valid (Before.Graph, I));
         pragma Assert (Node_Pins_Valid (After.Graph, I));
         N := After.Graph.Nodes (I);
         pragma Assert (N.State = Before.Graph.Nodes (I).State);
         pragma Assert (N.Parent = Before.Graph.Nodes (I).Parent);
         pragma Assert (N.Tree_Rank = Before.Graph.Nodes (I).Tree_Rank);
         pragma Assert (N.Kind = Before.Graph.Nodes (I).Kind);
         if N.State = Live then
            if N.Parent = Null_Node then
               pragma Assert (N.Previous = Null_Node and N.Next = Null_Node);
            else
               pragma Assert (Live_Node (After.Graph, N.Parent));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Parent)).Tree_Rank <
                    N.Tree_Rank and then N.Parent /= Node_Ref (I));
            end if;
            if N.Previous /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.Previous));
               pragma Assert (N.Previous /= Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Previous)).Next =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Previous)).Parent =
                    N.Parent);
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Previous)).Sibling_Order <
                    N.Sibling_Order);
               pragma Assert
                 ((After.Graph.Nodes (Positive (N.Previous)).Kind =
                     Attribute_Node) = (N.Kind = Attribute_Node));
            end if;
            if N.Next /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.Next));
               pragma Assert (N.Next /= Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Next)).Previous =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Next)).Parent = N.Parent);
               pragma Assert
                 ((After.Graph.Nodes (Positive (N.Next)).Kind =
                     Attribute_Node) = (N.Kind = Attribute_Node));
            end if;
            if N.Parent /= Null_Node and then N.Previous = Null_Node then
               pragma Assert
                 ((if N.Kind = Attribute_Node then
                     After.Graph.Nodes (Positive (N.Parent)).First_Prop
                   else After.Graph.Nodes (Positive (N.Parent)).First_Child)
                    = Node_Ref (I));
            end if;
            if N.Parent /= Null_Node and then N.Next = Null_Node then
               pragma Assert
                 ((if N.Kind = Attribute_Node then
                     After.Graph.Nodes (Positive (N.Parent)).Last_Prop
                   else After.Graph.Nodes (Positive (N.Parent)).Last_Child)
                    = Node_Ref (I));
            end if;
         end if;
         if N.State = Live and then N.Next /= Null_Node then
            pragma Assert
              (After.Graph.Nodes (Positive (N.Next)).Sibling_Order >
                 N.Sibling_Order);
         end if;
         pragma Assert (Node_Siblings_Valid (After.Graph, I));
         if N.State = Live then
            pragma Assert ((N.First_Child = Null_Node) =
                             (N.Last_Child = Null_Node));
            if N.First_Child /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.First_Child));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.First_Child)).Previous = 0);
               pragma Assert
                 (After.Graph.Nodes (Positive (N.First_Child)).Parent =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.First_Child)).Kind /=
                    Attribute_Node);
            end if;
            if N.Last_Child /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.Last_Child));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Last_Child)).Next = 0);
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Last_Child)).Parent =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Last_Child)).Kind /=
                    Attribute_Node);
            end if;
            pragma Assert ((N.First_Prop = Null_Node) =
                             (N.Last_Prop = Null_Node));
            if N.First_Prop /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.First_Prop));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.First_Prop)).Previous = 0);
               pragma Assert
                 (After.Graph.Nodes (Positive (N.First_Prop)).Parent =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.First_Prop)).Kind =
                    Attribute_Node);
            end if;
            if N.Last_Prop /= Null_Node then
               pragma Assert (Live_Node (After.Graph, N.Last_Prop));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Last_Prop)).Next = 0);
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Last_Prop)).Parent =
                    Node_Ref (I));
               pragma Assert
                 (After.Graph.Nodes (Positive (N.Last_Prop)).Kind =
                    Attribute_Node);
            end if;
         end if;
         pragma Assert (Node_Children_Valid (After.Graph, I));
         pragma Assert (Node_Namespaces_Valid (After.Graph, I));
         pragma Loop_Invariant
           (for all K in 1 .. I => Node_Links_Valid (After.Graph, K));
      end loop;
   end Placed_Lemma;

   procedure Place_Tail_Sibling
     (S : in out State; Parent, Child, Old_Last, Previous, Next : Node_Ref;
      Threshold, Old_Order : Natural)
   is
      Before : constant State := S with Ghost;
      Item : Node_View;
      Original_Order : Natural;
   begin
      pragma Assert
        (Placement_Ready
           (Before, Parent, Child, Old_Last, Previous, Next, Threshold, Old_Order));
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (S.Graph.Nodes (I) = Before.Graph.Nodes (I));
         pragma Assert (Node_Siblings_Valid (Before.Graph, I));
         Item := S.Graph.Nodes (I);
         Original_Order := Item.Sibling_Order;
         if Node_Ref (I) = Child then
            Item.Previous := Previous;
            Item.Next := Next;
            Item.Sibling_Order := Threshold;
         elsif Node_Ref (I) = Parent then
            if Previous = Null_Node then
               Item.First_Child := Child;
            end if;
            Item.Last_Child := Old_Last;
         elsif Node_Ref (I) = Old_Last then
            if Next = Old_Last then
               Item.Previous := Child;
            end if;
            Item.Next := Null_Node;
         elsif Previous /= Null_Node and then Node_Ref (I) = Previous then
            Item.Next := Child;
         elsif Node_Ref (I) = Next then
            Item.Previous := Child;
         end if;
         if Node_Ref (I) /= Child and then Node_Ref (I) /= Parent
           and then Item.State = Live
           and then Item.Parent = Parent
           and then Item.Kind /= Attribute_Node
           and then Original_Order >= Threshold
           and then Original_Order < Old_Order
         then
            Item.Sibling_Order := Original_Order + 1;
         end if;
         S.Graph.Nodes (I) := Item;
         pragma Assert
           (S.Graph.Nodes (I) =
              Placed_View
                (Before, Parent, Child, Old_Last, Previous, Next,
                 Threshold, Old_Order, Node_Ref (I)));
         pragma Loop_Invariant
           (for all K in 1 .. I =>
              S.Graph.Nodes (K) =
                Placed_View
                  (Before, Parent, Child, Old_Last, Previous, Next,
                   Threshold, Old_Order, Node_Ref (K)));
         pragma Loop_Invariant
           (for all K in 1 .. S.Graph.Node_Used =>
             (if K > I then S.Graph.Nodes (K) = Before.Graph.Nodes (K)));
         pragma Loop_Invariant
           (for all K in 1 .. S.Graph.Node_Used =>
             Namespace_Parent_Preserved
               (Before.Graph.Nodes (K), S.Graph.Nodes (K)));
         pragma Loop_Invariant
           (for all K in 1 .. S.Graph.Node_Used =>
             S.Graph.Nodes (K).State = Before.Graph.Nodes (K).State
               and then S.Graph.Nodes (K).Facade =
                 Before.Graph.Nodes (K).Facade);
      end loop;
      S.Effects.Dirty := True;
      Placed_Lemma
        (Before, S, Parent, Child, Old_Last, Previous, Next,
         Threshold, Old_Order);
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      Preserve_Pin_Equation (Before, S);
   end Place_Tail_Sibling;

   procedure Leaf_Has_No_Child (S : State; Root, N : Node_Ref) is
   begin
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (N)));
      if Node (S, N).Parent = Root
        and then Node (S, N).Previous /= Null_Node
      then
         Leaf_Has_No_Child (S, Root, Node (S, N).Previous);
      end if;
   end Leaf_Has_No_Child;

   procedure Leaf_Ancestor_Lemma (S : State; Root, N : Node_Ref) is
   begin
      Leaf_Has_No_Child (S, Root, N);
      if N = Root then
         pragma Assert (Ancestor (S, Root, N));
      elsif Node (S, N).Parent = Null_Node then
         pragma Assert (not Ancestor (S, Root, N));
      else
         pragma Assert (Node_Siblings_Valid (S.Graph, Positive (N)));
         pragma Assert (Node (S, N).Parent /= Root);
         Leaf_Ancestor_Lemma (S, Root, Node (S, N).Parent);
         pragma Assert (not Ancestor (S, Root, Node (S, N).Parent));
         pragma Assert (not Ancestor (S, Root, N));
      end if;
   end Leaf_Ancestor_Lemma;

   procedure Empty_Namespace_List_Lemma
     (S : State; Root : Node_Ref; Ns : Namespace_Ref)
   is
   begin
      pragma Assert (Namespace_Links_Valid (S.Graph, Positive (Ns)));
      if Namespace (S, Ns).Parent = Root
        and then Namespace (S, Ns).Previous /= Null_Namespace
      then
         Empty_Namespace_List_Lemma (S, Root, Namespace (S, Ns).Previous);
      end if;
   end Empty_Namespace_List_Lemma;

   procedure Replaced_Namespace_Fields
     (Before, After : State; Parent, New_Child, Old_Child : Node_Ref) is
   begin
      for I in 1 .. After.Graph.Node_Used loop
         pragma Assert
           (Node (After, Node_Ref (I)) =
              Replaced_View (Before, Parent, New_Child, Old_Child, Node_Ref (I)));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Namespace_Parent_Preserved
                (Before.Graph.Nodes (J), After.Graph.Nodes (J)));
      end loop;
   end Replaced_Namespace_Fields;

end XML3_DOM.Links;
