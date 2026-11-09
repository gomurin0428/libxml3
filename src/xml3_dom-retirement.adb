with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
with XML3_DOM.Links; use XML3_DOM.Links;
with XML3_DOM.Marking; use XML3_DOM.Marking;
with XML3_DOM.Freeing; use XML3_DOM.Freeing;
package body XML3_DOM.Retirement with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Free_Subtree (S : in out State; Root : Node_Ref) is
      Prepared : Boolean;
      Before : constant State := S with Ghost;
      Original_Namespaces : constant Namespace_View_Array :=
        Snapshot_Namespaces (S) with Ghost;
   begin
      Prepare_Subtree (S, Root, 0, Prepared);
      Namespace_Frame (S, Original_Namespaces);
      pragma Assert (Prepared);
      pragma Assert (Same_Used_Entries (Before, S));
      for I in 1 .. S.Graph.Node_Used loop
         if Node (S, Node_Ref (I)).State = Live then
            Same_Ancestor
              (Snapshot_Nodes (Before), Snapshot_Nodes (S),
               Node_Count (S), Root, Node_Ref (I));
            pragma Assert
              (Ancestor (Before, Root, Node_Ref (I)) =
                 Ancestor (S, Root, Node_Ref (I)));
         end if;
         pragma Assert
           (S.Marks (I) =
              (Node (Before, Node_Ref (I)).State = Live
               and then Ancestor (Before, Root, Node_Ref (I))));
         pragma Loop_Invariant (Same_Used_Entries (Before, S));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              S.Marks (J) =
                (Node (Before, Node_Ref (J)).State = Live
                 and then Ancestor (Before, Root, Node_Ref (J))));
      end loop;
      if Node (S, Root).Parent = Null_Node
        and then Node (S, Root).First_Child = Null_Node
        and then Node (S, Root).First_Prop = Null_Node
      then
         for I in 1 .. S.Graph.Node_Used loop
            if S.Graph.Nodes (I).State = Live then
               Leaf_Ancestor_Lemma (S, Root, Node_Ref (I));
            end if;
            pragma Assert
              (S.Marks (I) = (Node_Ref (I) = Root));
            pragma Loop_Invariant
              (for all J in 1 .. I =>
                S.Marks (J) = (Node_Ref (J) = Root));
         end loop;
      end if;
      declare
         Prepared_Namespaces : constant Namespace_View_Array :=
           Snapshot_Namespaces (S) with Ghost;
      begin
         pragma Assert (Prepared_Namespaces = Original_Namespaces);
         Free_Marked_Subtree (S, Root);
         Compose_Namespace_Snapshots
           (Snapshot_Namespaces (S), Prepared_Namespaces,
            Original_Namespaces);
      end;
      pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
      pragma Assert (Facades_Preserved (Before, S));
   end Free_Subtree;

   procedure Free_Subtree_With_Namespaces
     (S : in out State; Root : Node_Ref)
   is
      Before : constant State := S with Ghost;
      Parent : Node_Ref;
      Retained : Boolean;
   begin
      for I in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (S))
      loop
         if Namespace (S, I).State = Live
           and then Namespace (S, I).Attached
         then
            Parent := Namespace (S, I).Parent;
            if Parent in 1 .. Node_Ref (Node_Count (S))
              and then Node (S, Parent).State = Live
            then
               Same_Ancestor
                 (Snapshot_Nodes (Before), Snapshot_Nodes (S),
                  Node_Count (Before), Root, Parent);
               if Is_Ancestor (S, Root, Parent) then
                  Retained := Namespace (S, I).Owns_Reservation;
                  pragma Assert
                    (Namespace_Links_Valid (S.Graph, Positive (I)));
                  pragma Assert
                    (for all J in Namespace_Ref range
                      1 .. Namespace_Ref (Namespace_Count (S)) =>
                        (if not Namespace (S, J).Attached then
                           Namespace (S, I).Previous /= J
                           and then Namespace (S, I).Next /= J));
                  Detach_Namespace_Declaration (S, I);
                  if Retained then
                     Release_Namespace_Reservation (S, I);
                  end if;
               end if;
            end if;
         end if;
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant
           (Node_Count (S) = Node_Count (Before)
            and then Namespace_Count (S) = Namespace_Count (Before)
            and then Owner_Count (S) = Owner_Count (Before));
         pragma Loop_Invariant (Capacity_Of (S) = Capacity_Of (Before));
         pragma Loop_Invariant
           (for all B in Owner_Ref range
             1 .. Owner_Ref (Owner_Count (Before)) =>
               (if Owner (Before, B).State /= Live then
                 Owner (S, B) = Owner (Before, B)));
         pragma Loop_Invariant (Facades_Preserved (Before, S));
         pragma Loop_Invariant
           (if Facades_Present (Before) then Facades_Present (S));
         pragma Loop_Invariant
           (for all J in Node_Ref range
             1 .. Node_Ref (Node_Count (Before)) =>
               Node (S, J).State = Node (Before, J).State
               and then Node (S, J).Parent = Node (Before, J).Parent
               and then Node (S, J).Tree_Rank = Node (Before, J).Tree_Rank
               and then Node (S, J) =
                 (Node (Before, J) with delta
                    First_Namespace => Node (S, J).First_Namespace,
                    Last_Namespace => Node (S, J).Last_Namespace));
         pragma Loop_Invariant
           (for all J in Node_Ref range
             1 .. Node_Ref (Node_Count (Before)) =>
               (if Node (Before, J).State /= Live
                 or else not Ancestor (Before, Root, J)
                then Node (S, J) = Node (Before, J)));
         pragma Loop_Invariant
           (for all J in Namespace_Ref range
             1 .. Namespace_Ref (Namespace_Count (S)) =>
               (if J > I then
                 Namespace (S, J) = (Namespace (Before, J) with delta
                   Previous => Namespace (S, J).Previous,
                   Next => Namespace (S, J).Next)));
         pragma Loop_Invariant
           (for all J in Namespace_Ref range
             1 .. Namespace_Ref (Namespace_Count (S)) =>
               (if Namespace (Before, J).State = Live
                 and then Namespace (Before, J).Parent /= Null_Node
                 and then Namespace (Before, J).Parent in
                   1 .. Node_Ref (Node_Count (Before))
                 and then Node
                   (Before, Namespace (Before, J).Parent).State = Live
                 and then Ancestor
                   (Before, Root, Namespace (Before, J).Parent)
                 and then J <= I
                then Namespace (S, J).Parent = Null_Node
                  and then Namespace (S, J).Next = Null_Namespace
                  and then Namespace (S, J).Previous = Null_Namespace
                  and then not Namespace (S, J).Attached
                  and then not Namespace (S, J).Owns_Reservation));
         pragma Loop_Invariant
           (for all J in Namespace_Ref range
             1 .. Namespace_Ref (Namespace_Count (S)) =>
               (if J <= I
                 and then Namespace (Before, J).State = Live
                 and then
                   (Namespace (Before, J).Parent = Null_Node
                    or else Namespace (Before, J).Parent not in
                      1 .. Node_Ref (Node_Count (Before))
                    or else Node
                      (Before, Namespace (Before, J).Parent).State /= Live
                    or else not Ancestor
                      (Before, Root, Namespace (Before, J).Parent))
                then Namespace (S, J).State = Namespace (Before, J).State
                  and then Namespace (S, J).Parent =
                    Namespace (Before, J).Parent
                  and then Namespace (S, J).Owns_Reservation =
                    Namespace (Before, J).Owns_Reservation));
      end loop;
      for I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
         if Node (S, I).State = Live then
            Same_Ancestor
              (Snapshot_Nodes (Before), Snapshot_Nodes (S),
               Node_Count (Before), Root, I);
         end if;
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. I =>
            (if Node (Before, J).State = Live then
               Ancestor (Before, Root, J) = Ancestor (S, Root, J)));
      end loop;
      pragma Assert (Retained_Declarations_Clear (S, Root));
      Free_Subtree (S, Root);
      pragma Assert
        (for all I in Namespace_Ref range
          1 .. Namespace_Ref (Namespace_Count (S)) =>
            (if Namespace (Before, I).State = Live
              and then Namespace (Before, I).Parent /= Null_Node
              and then Namespace (Before, I).Parent in
                1 .. Node_Ref (Node_Count (Before))
              and then Node
                (Before, Namespace (Before, I).Parent).State = Live
              and then Ancestor
                (Before, Root, Namespace (Before, I).Parent)
             then Namespace (S, I).Parent = Null_Node
               and then Namespace (S, I).Next = Null_Namespace
               and then Namespace (S, I).Previous = Null_Namespace
               and then not Namespace (S, I).Attached
               and then not Namespace (S, I).Owns_Reservation));
   end Free_Subtree_With_Namespaces;

   procedure Empty_Attribute_Content_Lemma (S : State; Attribute : Node_Ref) is
   begin
      for I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
         if Node (S, I).State = Live then
            Leaf_Has_No_Child (S, Attribute, I);
         end if;
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. I =>
              (if Node (S, J).State = Live then
                 Node (S, J).Parent /= Attribute));
      end loop;
   end Empty_Attribute_Content_Lemma;

   procedure Retire_Attribute_Children
     (S : in out State; Attribute, Keep : Node_Ref)
   is
      Before : constant State := S with Ghost;
      Before_Attribute : Node_View := Node (S, Attribute) with Ghost;
   begin
      for I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
         pragma Assert
           (if Text_Attribute_Content (Before, Attribute) then
              Text_Attribute_Content (S, Attribute)
              and then Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         if Node (S, I).State = Live
           and then Node (S, I).Kind /= Attribute_Node
           and then Node (S, I).Parent = Attribute
           and then I /= Keep
         then
            pragma Assert (Node_Siblings_Valid (S.Graph, Positive (I)));
            pragma Assert
              (Node (S, Attribute).Tree_Rank < Node (S, I).Tree_Rank);
            pragma Assert (not Ancestor (S, I, Attribute));
            pragma Assert
              (if Keep /= Null_Node then not Ancestor (S, I, Keep));
            Before_Attribute := Node (S, Attribute);
            if Text_Attribute_Content (S, Attribute) then
               pragma Assert (Node (S, I).Kind = Text_Node);
               pragma Assert (Node (S, I).First_Child = Null_Node);
               pragma Assert (Node (S, I).First_Prop = Null_Node);
               pragma Assert (Node (S, I).First_Namespace = Null_Namespace);
               for E in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
                  if Node (S, E).State = Live
                    and then E /= I
                  then
                     Leaf_Ancestor_Lemma (S, I, E);
                  end if;
                  pragma Loop_Invariant
                    (for all J in Node_Ref range 1 .. E =>
                      (if Node (S, J).State = Live
                        and then J /= I then
                          not Ancestor (S, I, J)));
               end loop;
               Leaf_Retained_Declarations_Lemma (S, I);
               pragma Assert
                 (if Text_Attribute_Content (Before, Attribute) then
                    Snapshot_Namespaces (S) =
                      Snapshot_Namespaces (Before));
               Free_Subtree (S, I);
               pragma Assert
                 (if Text_Attribute_Content (Before, Attribute) then
                    Snapshot_Namespaces (S) =
                      Snapshot_Namespaces (Before));
            elsif Node (S, I).First_Child = Null_Node
              and then Node (S, I).First_Prop = Null_Node
              and then Node (S, I).First_Namespace = Null_Namespace
            then
               pragma Assert (not Text_Attribute_Content (Before, Attribute));
               Leaf_Retained_Declarations_Lemma (S, I);
               Free_Subtree (S, I);
            else
               pragma Assert (not Text_Attribute_Content (Before, Attribute));
               Free_Subtree_With_Namespaces (S, I);
            end if;
            pragma Assert
              (Node (S, Attribute) =
                 (Before_Attribute with delta
                    First_Child => Node (S, Attribute).First_Child,
                    Last_Child => Node (S, Attribute).Last_Child));
         end if;
         pragma Assert
           (if Text_Attribute_Content (Before, Attribute) then
              Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant (Node_Count (S) = Node_Count (Before));
         pragma Loop_Invariant
           (Namespace_Count (S) = Namespace_Count (Before));
         pragma Loop_Invariant (Owner_Count (S) = Owner_Count (Before));
         pragma Loop_Invariant
           (for all B in Owner_Ref range
             1 .. Owner_Ref (Owner_Count (Before)) =>
               (if Owner (Before, B).State /= Live then
                 Owner (S, B) = Owner (Before, B)));
         pragma Loop_Invariant
           (if Text_Attribute_Content (Before, Attribute) then
             Text_Attribute_Content (S, Attribute)
             and then Snapshot_Namespaces (S) = Snapshot_Namespaces (Before)
             and then (for all J in Node_Ref range
               1 .. Node_Ref (Node_Count (Before)) =>
                 (if J /= Attribute and then Node (Before, J).Parent /= Attribute
                  then Node (S, J) = Node (Before, J)))
             and then (for all B in Owner_Ref range
               1 .. Owner_Ref (Owner_Count (Before)) =>
                 Owner (S, B).Reservations = Owner (Before, B).Reservations)
             and then (for all J in Node_Ref range
               1 .. Node_Ref (Node_Count (Before)) =>
                 (if Node (Before, J).State = Live
                   and then Node (Before, J).Kind = Element_Node then
                     Node (S, J) = Node (Before, J))));
         pragma Loop_Invariant (Facades_Preserved (Before, S));
         pragma Loop_Invariant
           (if Facades_Present (Before) then Facades_Present (S));
         pragma Loop_Invariant
           (Node (S, Attribute) = (Node (Before, Attribute) with delta
             First_Child => Node (S, Attribute).First_Child,
             Last_Child => Node (S, Attribute).Last_Child));
         pragma Loop_Invariant
           (if Keep /= Null_Node then
             Node (S, Keep) = (Node (Before, Keep) with delta
               Previous => Node (S, Keep).Previous,
               Next => Node (S, Keep).Next));
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. I =>
             (if Node (S, J).State = Live
               and then Node (S, J).Kind /= Attribute_Node
               and then Node (S, J).Parent = Attribute then J = Keep));
      end loop;
      pragma Assert (Node_Children_Valid
        (S.Graph, Positive (Attribute)));
      if Keep = Null_Node then
         pragma Assert (Node (S, Attribute).First_Child = Null_Node);
         pragma Assert (Node (S, Attribute).Last_Child = Null_Node);
      else
         pragma Assert
           (Node_Siblings_Valid (S.Graph, Positive (Keep)));
         pragma Assert (Node (S, Keep).Previous = Null_Node);
         pragma Assert (Node (S, Keep).Next = Null_Node);
         pragma Assert (Node (S, Attribute).First_Child = Keep);
         pragma Assert (Node (S, Attribute).Last_Child = Keep);
      end if;
   end Retire_Attribute_Children;

   procedure Retire_One_Element_Child
     (S : in out State; Element, Child, Keep : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Element in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Element).State = Live
       and then Node (S, Element).Kind = Element_Node
       and then Node_Siblings_Valid (S.Graph, Positive (Element))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Child /= Keep
       and then Node (S, Child).State = Live
       and then Node (S, Child).Parent = Element
       and then Node (S, Child).Kind /= Attribute_Node
       and then Node_Siblings_Valid (S.Graph, Positive (Child))
       and then (Keep = Null_Node or else
         (Keep in 1 .. Node_Ref (Node_Count (S))
          and then Node (S, Keep).State = Live
          and then Node (S, Keep).Parent = Element
          and then Node_Siblings_Valid (S.Graph, Positive (Keep)))),
     Post => Valid (S) and then Can_Edit (S)
       and then Node (S, Child).State = Tombstone
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Capacity_Of (S) = Capacity_Of (S'Old)
       and then Node_Count (S) = Node_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           (if Owner (S'Old, B).State /= Live then
             Owner (S, B) = Owner (S'Old, B)))
       and then Facades_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S'Old)) =>
           (if Node (S'Old, I).State = Live
             and then Ancestor (S'Old, Child, I)
            then Node (S, I).State = Tombstone
            else Node (S, I) = Unlinked_View (S'Old, Child, I)))
       and then Node (S, Element) = Unlinked_View (S'Old, Child, Element)
       and then Node (S, Element) =
         (Node (S'Old, Element) with delta
            First_Child => Node (S, Element).First_Child,
            Last_Child => Node (S, Element).Last_Child)
       and then (if Keep /= Null_Node then
         Node (S, Keep) = Unlinked_View (S'Old, Child, Keep)
         and then Node (S, Keep) =
           (Node (S'Old, Keep) with delta
              Previous => Node (S, Keep).Previous,
              Next => Node (S, Keep).Next));

   procedure Retire_One_Element_Child
     (S : in out State; Element, Child, Keep : Node_Ref)
   is
      Expected_Element : constant Node_View :=
        Unlinked_View (S, Child, Element) with Ghost;
      Expected_Keep : constant Node_View :=
        (if Keep = Null_Node then Node (S, Element)
         else Unlinked_View (S, Child, Keep)) with Ghost;
   begin
      pragma Assert
        (Expected_Element = (Node (S, Element) with delta
           First_Child => Expected_Element.First_Child,
           Last_Child => Expected_Element.Last_Child));
      pragma Assert
        (if Keep /= Null_Node then
          Expected_Keep = (Node (S, Keep) with delta
            Previous => Expected_Keep.Previous,
            Next => Expected_Keep.Next));
      Free_Subtree_With_Namespaces (S, Child);
      pragma Assert (Node (S, Element) = Expected_Element);
      pragma Assert
        (if Keep /= Null_Node then Node (S, Keep) = Expected_Keep);
   end Retire_One_Element_Child;

   procedure Retire_Element_Children
     (S : in out State; Element, Keep : Node_Ref)
   is
      Before : constant State := S with Ghost;
   begin
      for I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
         if Node (S, I).State = Live
           and then Node (S, I).Kind /= Attribute_Node
           and then Node (S, I).Parent = Element
           and then I /= Keep
         then
            pragma Assert (Node_Siblings_Valid (S.Graph, Positive (I)));
            pragma Assert
              (Node_Siblings_Valid (S.Graph, Positive (Element)));
            pragma Assert
              (if Keep /= Null_Node then
                 Node_Siblings_Valid (S.Graph, Positive (Keep)));
            pragma Assert
              (Node (S, Element).Tree_Rank < Node (S, I).Tree_Rank);
            pragma Assert (not Ancestor (S, I, Element));
            pragma Assert
              (if Keep /= Null_Node then not Ancestor (S, I, Keep));
            for J in Node_Ref range 1 .. Node_Ref (Node_Count (S)) loop
               Retained_Ancestor
                 (Snapshot_Nodes (Before), Snapshot_Nodes (S),
                  Node_Count (S), I, J);
               pragma Assert
                 (if J /= Element and then J /= Keep
                   and then Node (Before, J).State = Live
                   and then (for all C in Node_Ref range
                     1 .. Node_Ref (Node_Count (Before)) =>
                       not (Node (Before, C).State = Live
                         and then Node (Before, C).Kind /= Attribute_Node
                         and then Node (Before, C).Parent = Element
                         and then C /= Keep
                         and then (J = C or else Ancestor (Before, C, J))))
                  then not Ancestor (S, I, J)
                    and then Unlinked_View (S, I, J) = Node (Before, J));
               pragma Loop_Invariant
                 (for all K in Node_Ref range 1 .. J =>
                   (if K /= Element and then K /= Keep
                     and then Node (Before, K).State = Live
                     and then (for all C in Node_Ref range
                       1 .. Node_Ref (Node_Count (Before)) =>
                         not (Node (Before, C).State = Live
                           and then Node (Before, C).Kind /= Attribute_Node
                           and then Node (Before, C).Parent = Element
                           and then C /= Keep
                           and then
                             (K = C or else Ancestor (Before, C, K))))
                    then not Ancestor (S, I, K)
                      and then Unlinked_View (S, I, K) = Node (Before, K)));
            end loop;
            Retire_One_Element_Child (S, Element, I, Keep);
         end if;
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant (Node_Count (S) = Node_Count (Before));
         pragma Loop_Invariant
           (Namespace_Count (S) = Namespace_Count (Before));
         pragma Loop_Invariant (Owner_Count (S) = Owner_Count (Before));
         pragma Loop_Invariant
           (for all J in Node_Ref range
             1 .. Node_Ref (Node_Count (S)) =>
               (if Node (S, J).State = Live then
                 Node (Before, J).State = Live
                 and then Node (S, J).Parent = Node (Before, J).Parent
                 and then Node (S, J).Tree_Rank = Node (Before, J).Tree_Rank
                 and then Node (S, J).Kind = Node (Before, J).Kind));
         pragma Loop_Invariant
           (for all B in Owner_Ref range
             1 .. Owner_Ref (Owner_Count (Before)) =>
               (if Owner (Before, B).State /= Live then
                 Owner (S, B) = Owner (Before, B)));
         pragma Loop_Invariant (Facades_Preserved (Before, S));
         pragma Loop_Invariant
           (if Facades_Present (Before) then Facades_Present (S));
         pragma Loop_Invariant
           (Node (S, Element) = (Node (Before, Element) with delta
             First_Child => Node (S, Element).First_Child,
             Last_Child => Node (S, Element).Last_Child));
         pragma Loop_Invariant
           (if Keep /= Null_Node then
             Node (S, Keep) = (Node (Before, Keep) with delta
               Previous => Node (S, Keep).Previous,
               Next => Node (S, Keep).Next));
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. I =>
             (if Node (S, J).State = Live
               and then Node (S, J).Kind /= Attribute_Node
               and then Node (S, J).Parent = Element
              then J = Keep));
         pragma Loop_Invariant
           (for all J in Node_Ref range
             1 .. Node_Ref (Node_Count (S)) =>
               (if J /= Element and then J /= Keep
                 and then Node (Before, J).State = Live
                 and then (for all C in Node_Ref range
                   1 .. Node_Ref (Node_Count (Before)) =>
                     not (Node (Before, C).State = Live
                       and then Node (Before, C).Kind /= Attribute_Node
                       and then Node (Before, C).Parent = Element
                       and then C /= Keep
                       and then (J = C or else
                         Ancestor (Before, C, J))))
                then Node (S, J) = Node (Before, J)));
      end loop;
      Node_Links_Of (S, Positive (Element));
      pragma Assert (Node_Children_Valid (S.Graph, Positive (Element)));
      if Keep /= Null_Node then
         Node_Links_Of (S, Positive (Keep));
      end if;
      --  A first child or a previous sibling of Keep would be another live
      --  non-attribute child of Element, and Keep is the only one left.
      pragma Assert
        (if Node (S, Element).First_Child /= Null_Node then
           Node (S, Node (S, Element).First_Child).State = Live
           and then Node (S, Node (S, Element).First_Child).Kind /=
             Attribute_Node
           and then Node (S, Node (S, Element).First_Child).Parent = Element);
      pragma Assert
        (if Node (S, Element).First_Child /= Null_Node then
           Node (S, Element).First_Child = Keep);
      if Keep = Null_Node then
         pragma Assert (Node (S, Element).First_Child = Null_Node);
         pragma Assert (Node (S, Element).Last_Child = Null_Node);
      else
         pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Keep)));
         pragma Assert (Node (S, Keep).Parent = Element);
         pragma Assert
           (if Node (S, Keep).Previous /= Null_Node then
              Node (S, Node (S, Keep).Previous).State = Live
              and then Node (S, Node (S, Keep).Previous).Kind /=
                Attribute_Node
              and then Node (S, Node (S, Keep).Previous).Parent = Element
              and then Node (S, Keep).Previous /= Keep);
         pragma Assert
           (if Node (S, Keep).Previous /= Null_Node then
              Node (S, Keep).Previous = Keep);
         pragma Assert (Node (S, Keep).Previous = Null_Node);
         pragma Assert
           (if Node (S, Keep).Next /= Null_Node then
              Node (S, Node (S, Keep).Next).State = Live
              and then Node (S, Node (S, Keep).Next).Kind /= Attribute_Node
              and then Node (S, Node (S, Keep).Next).Parent = Element
              and then Node (S, Keep).Next /= Keep);
         pragma Assert
           (if Node (S, Keep).Next /= Null_Node then
              Node (S, Keep).Next = Keep);
         pragma Assert (Node (S, Keep).Next = Null_Node);
         pragma Assert (Node (S, Element).First_Child = Keep);
         pragma Assert (Node (S, Element).Last_Child = Keep);
      end if;
   end Retire_Element_Children;

end XML3_DOM.Retirement;
