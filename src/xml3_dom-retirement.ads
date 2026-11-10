package XML3_DOM.Retirement with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Free_Subtree
     (S : in out State; Root : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S) and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live
       and then Retained_Declarations_Clear (S, Root),
     Post => Valid (S) and then Can_Edit (S)
       and then Node (S, Root).State = Tombstone
       and then Facades_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then S.Capacity = S'Old.Capacity
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           (if Owner (S'Old, B).State /= Live then
             Owner (S, B) = Owner (S'Old, B)))
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S'Old)) =>
         (if Node (S'Old, I).State = Live
           and then Ancestor (S'Old, Root, I)
          then Node (S, I).State = Tombstone
          else Node (S, I) = Unlinked_View (S'Old, Root, I)))
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           Owner (S, B).Reservations = Owner (S'Old, B).Reservations
           and then (if Owner (S'Old, B).State = Live
             and then Owner (S'Old, B).Reservations > 0 then
             Owner (S, B).State = Live))
       and then (if Node (S'Old, Root).Parent = Null_Node
         and then Node (S'Old, Root).First_Child = Null_Node
         and then Node (S'Old, Root).First_Prop = Null_Node then
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S'Old)) =>
             (if I /= Root then Node (S, I) = Node (S'Old, I)))
           and then (for all B in Owner_Ref range
             1 .. Owner_Ref (Owner_Count (S'Old)) =>
               (if not Holds (Node (S'Old, Root), B) then
                 Owner (S, B) = Owner (S'Old, B))));

   procedure Free_Subtree_With_Namespaces
     (S : in out State; Root : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live,
     Post => Valid (S) and then Can_Edit (S)
       and then Node (S, Root).State = Tombstone
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
             and then Ancestor (S'Old, Root, I)
            then Node (S, I).State = Tombstone
            else Node (S, I) = Unlinked_View (S'Old, Root, I)))
       and then (for all I in Namespace_Ref range
         1 .. Namespace_Ref (Namespace_Count (S'Old)) =>
           (if Namespace (S'Old, I).State = Live
             and then Namespace (S'Old, I).Parent /= Null_Node
             and then Namespace (S'Old, I).Parent in
               1 .. Node_Ref (Node_Count (S'Old))
             and then Node
               (S'Old, Namespace (S'Old, I).Parent).State = Live
             and then Ancestor
               (S'Old, Root, Namespace (S'Old, I).Parent)
            then Namespace (S, I).Parent = Null_Node
              and then Namespace (S, I).Next = Null_Namespace
              and then Namespace (S, I).Previous = Null_Namespace
              and then not Namespace (S, I).Attached
              and then not Namespace (S, I).Owns_Reservation))
       and then (if Node (S'Old, Root).Parent = Null_Node
         and then Node (S'Old, Root).First_Child = Null_Node
         and then Node (S'Old, Root).First_Prop = Null_Node then
           (for all I in Node_Ref range
             1 .. Node_Ref (Node_Count (S'Old)) =>
               (if I /= Root then Node (S, I) = Node (S'Old, I))));

   procedure Empty_Attribute_Content_Lemma (S : State; Attribute : Node_Ref)
     with Ghost, Global => null,
       Pre => Valid (S)
         and then Attribute in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, Attribute).State = Live
         and then Node (S, Attribute).Kind = Attribute_Node
         and then Node (S, Attribute).First_Child = Null_Node
         and then Node (S, Attribute).First_Prop = Null_Node,
       Post => Text_Attribute_Content (S, Attribute);

   procedure Retire_Attribute_Children
     (S : in out State; Attribute, Keep : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Attribute in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Attribute).State = Live
       and then Node (S, Attribute).Kind = Attribute_Node
       and then (Keep = Null_Node or else
         (Keep in 1 .. Node_Ref (Node_Count (S))
          and then Node (S, Keep).State = Live
          and then Node (S, Keep).Kind /= Attribute_Node
          and then Node (S, Keep).Parent = Attribute)),
     Post => Valid (S) and then Can_Edit (S)
       and then Facades_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           (if Owner (S'Old, B).State /= Live then
             Owner (S, B) = Owner (S'Old, B)))
       and then (if Text_Attribute_Content (S'Old, Attribute) then
         Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S'Old)) =>
             (if I /= Attribute and then Node (S'Old, I).Parent /= Attribute
              then Node (S, I) = Node (S'Old, I)))
         and then (for all B in Owner_Ref range
           1 .. Owner_Ref (Owner_Count (S'Old)) =>
             Owner (S, B).Reservations = Owner (S'Old, B).Reservations)
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S'Old)) =>
             (if Node (S'Old, I).State = Live
               and then Node (S'Old, I).Kind = Element_Node then
                 Node (S, I) = Node (S'Old, I))))
       and then Node (S, Attribute) =
         (Node (S'Old, Attribute) with delta First_Child => Keep,
           Last_Child => Keep)
       and then (if Keep /= Null_Node then Node (S, Keep) =
         (Node (S'Old, Keep) with delta Previous => Null_Node,
           Next => Null_Node))
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (if Node (S, I).State = Live
           and then Node (S, I).Kind /= Attribute_Node
           and then Node (S, I).Parent = Attribute then I = Keep));

   procedure Retire_Element_Children
     (S : in out State; Element, Keep : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Element in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Element).State = Live
       and then Node (S, Element).Kind = Element_Node
       and then (Keep = Null_Node or else
         (Keep in 1 .. Node_Ref (Node_Count (S))
          and then Node (S, Keep).State = Live
          and then Node (S, Keep).Kind /= Attribute_Node
          and then Node (S, Keep).Parent = Element)),
     Post => Valid (S) and then Can_Edit (S)
       and then Facades_Preserved (S'Old, S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then (for all B in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S'Old)) =>
           (if Owner (S'Old, B).State /= Live then
             Owner (S, B) = Owner (S'Old, B)))
       and then Node (S, Element) =
         (Node (S'Old, Element) with delta
            First_Child => Node (S, Element).First_Child,
            Last_Child => Node (S, Element).Last_Child)
       and then (if Keep = Null_Node then
         Node (S, Element).First_Child = Null_Node
           and then Node (S, Element).Last_Child = Null_Node
       else
         Node (S, Element).First_Child = Keep
           and then Node (S, Element).Last_Child = Keep
           and then Node (S, Keep) =
             (Node (S'Old, Keep) with delta
                Previous => Null_Node, Next => Null_Node))
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           (if Node (S, I).State = Live
             and then Node (S, I).Parent = Element
             and then Node (S, I).Kind /= Attribute_Node
            then I = Keep))
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           (if I /= Element and then I /= Keep
             and then Node (S'Old, I).State = Live
             and then (for all C in Node_Ref range
               1 .. Node_Ref (Node_Count (S'Old)) =>
                 not (Node (S'Old, C).State = Live
                   and then Node (S'Old, C).Kind /= Attribute_Node
                   and then Node (S'Old, C).Parent = Element
                   and then C /= Keep
                   and then (I = C or else Ancestor (S'Old, C, I))))
            then Node (S, I) = Node (S'Old, I)));

end XML3_DOM.Retirement;
