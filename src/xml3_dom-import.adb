with XML3_DOM_Allocation;

package body XML3_DOM.Import with SPARK_Mode is
   use type XML3_DOM_Allocation.Import_Maps_Access;
   use type XML3_DOM_Allocation.Node_Map_Array;
   use type XML3_DOM_Allocation.Namespace_Map_Array;
   pragma Unevaluated_Use_Of_Old (Allow);

   function Mapped_Node
     (Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Node_Ref) return Node_Ref
     with Pre => Item <= Node_Ref (Maps.Capacity),
       Post => (if Item = Null_Node then
                  Mapped_Node'Result = Null_Node
                else Mapped_Node'Result = Maps.Nodes (Positive (Item)));

   function Mapped_Node
     (Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Node_Ref) return Node_Ref
   is
   begin
      if Item = Null_Node then
         return Null_Node;
      end if;
      return Maps.Nodes (Positive (Item));
   end Mapped_Node;

   function Mapped_Namespace
     (Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Namespace_Ref) return Namespace_Ref
     with Pre => Item <= Namespace_Ref (Maps.Capacity),
       Post => (if Item = Null_Namespace then
                  Mapped_Namespace'Result = Null_Namespace
                else
                  Mapped_Namespace'Result =
                    Maps.Namespaces (Positive (Item)));

   function Mapped_Namespace
     (Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Namespace_Ref) return Namespace_Ref
   is
   begin
      if Item = Null_Namespace then
         return Null_Namespace;
      end if;
      return Maps.Namespaces (Positive (Item));
   end Mapped_Namespace;

   function Mapped_Pin
     (Item : Owner_Ref; New_Owner : Owner_Ref) return Owner_Ref is
     (if Item = Null_Owner then Null_Owner else New_Owner);

   function Node_Map_Contains
     (Maps : XML3_DOM_Allocation.Import_Maps;
      Count : Natural;
      Value : Node_Ref) return Boolean
   is (for some I in 1 .. Count => Maps.Nodes (I) = Value)
     with Ghost, Pre => Count <= Maps.Capacity,
       Annotate => (GNATprove, Inline_For_Proof);

   function Namespace_Map_Contains
     (Maps : XML3_DOM_Allocation.Import_Maps;
      Count : Natural;
      Value : Namespace_Ref) return Boolean
   is (for some I in 1 .. Count => Maps.Namespaces (I) = Value)
     with Ghost, Pre => Count <= Maps.Capacity,
       Annotate => (GNATprove, Inline_For_Proof);

   procedure Build_Node_Map
     (Destination : State;
      Maps : XML3_DOM_Allocation.Import_Maps_Access;
      Source_Count : Positive;
      Destination_Count : Natural)
     with Global => null,
       Pre => Maps /= null
         and then Source_Count <= Maps.Capacity
         and then Destination_Count <= Natural (Capacity_Of (Destination))
         and then Source_Count <=
           Natural (Capacity_Of (Destination)) - Destination_Count,
       Post => Maps.Namespaces = Maps.Namespaces'Old
         and then (for all I in 1 .. Source_Count =>
           Maps.Nodes (I) in 1 .. Node_Ref (Capacity_Of (Destination)))
         and then
           (for all I in 1 .. Source_Count =>
             (for all J in 1 .. Source_Count =>
               (if I < J then Maps.Nodes (I) < Maps.Nodes (J))))
         and then
           (for all I in 1 .. Source_Count =>
             Maps.Nodes (I) > Node_Ref (Destination_Count)
             or else Destination.Graph.Nodes
               (Positive (Maps.Nodes (I))).State = Unused)
         and then
           (if Natural (Maps.Nodes (Source_Count)) > Destination_Count then
              Natural (Maps.Nodes (Source_Count)) - Destination_Count <= Source_Count
              and then (for all I in 1 .. Source_Count =>
                (if I > Source_Count -
                    (Natural (Maps.Nodes (Source_Count)) - Destination_Count) then
                   Maps.Nodes (I) = Node_Ref
                     (Natural (Maps.Nodes (Source_Count)) - (Source_Count - I)))));

   procedure Build_Node_Map
     (Destination : State;
      Maps : XML3_DOM_Allocation.Import_Maps_Access;
      Source_Count : Positive;
      Destination_Count : Natural)
   is
      Filled : Natural := 0;
   begin
      for Slot in 1 .. Destination_Count loop
         pragma Loop_Invariant (Filled <= Source_Count);
         pragma Loop_Invariant
           (for all I in 1 .. Filled =>
              Maps.Nodes (I) in 1 .. Node_Ref (Slot - 1)
              and then Destination.Graph.Nodes
                (Positive (Maps.Nodes (I))).State = Unused);
         pragma Loop_Invariant
           (for all I in 1 .. Filled =>
              (for all J in 1 .. Filled =>
                 (if I < J then Maps.Nodes (I) < Maps.Nodes (J))));
         exit when Filled = Source_Count;
         if Destination.Graph.Nodes (Slot).State = Unused then
            Filled := Filled + 1;
            Maps.Nodes (Filled) := Node_Ref (Slot);
         end if;
      end loop;
      pragma Assert
        (for all I in 1 .. Filled =>
           Maps.Nodes (I) in 1 .. Node_Ref (Destination_Count)
           and then Destination.Graph.Nodes
             (Positive (Maps.Nodes (I))).State = Unused);
      if Filled < Source_Count then
         for I in Filled + 1 .. Source_Count loop
            Maps.Nodes (I) := Node_Ref (Destination_Count + (I - Filled));
            pragma Loop_Invariant
              (for all J in 1 .. Filled =>
                 Maps.Nodes (J) in 1 .. Node_Ref (Destination_Count)
                 and then Destination.Graph.Nodes
                   (Positive (Maps.Nodes (J))).State = Unused);
            pragma Loop_Invariant
              (for all J in Filled + 1 .. I =>
                 Maps.Nodes (J) =
                   Node_Ref (Destination_Count + (J - Filled)));
            pragma Loop_Invariant
              (for all J in 1 .. I =>
                 (for all K in 1 .. I =>
                    (if J < K then Maps.Nodes (J) < Maps.Nodes (K))));
         end loop;
      end if;
      pragma Assert
        (if Filled = Source_Count then
           Natural (Maps.Nodes (Source_Count)) <= Destination_Count
         else Natural (Maps.Nodes (Source_Count)) =
           Destination_Count + (Source_Count - Filled));
   end Build_Node_Map;

   procedure Build_Namespace_Map
     (Destination : State;
      Maps : XML3_DOM_Allocation.Import_Maps_Access;
      Source_Count : Positive;
      Destination_Count : Natural)
     with Global => null,
       Pre => Maps /= null
         and then Source_Count <= Maps.Capacity
         and then Destination_Count <= Natural (Capacity_Of (Destination))
         and then Source_Count <=
           Natural (Capacity_Of (Destination)) - Destination_Count,
       Post => Maps.Nodes = Maps.Nodes'Old
         and then (for all I in 1 .. Source_Count =>
           Maps.Namespaces (I) in
             1 .. Namespace_Ref (Capacity_Of (Destination)))
         and then
           (for all I in 1 .. Source_Count =>
             (for all J in 1 .. Source_Count =>
               (if I < J then
                  Maps.Namespaces (I) < Maps.Namespaces (J))))
         and then
           (for all I in 1 .. Source_Count =>
             Maps.Namespaces (I) > Namespace_Ref (Destination_Count)
             or else Destination.Graph.Namespaces
               (Positive (Maps.Namespaces (I))).State = Unused)
         and then
           (if Natural (Maps.Namespaces (Source_Count)) > Destination_Count then
              Natural (Maps.Namespaces (Source_Count)) - Destination_Count <= Source_Count
              and then (for all I in 1 .. Source_Count =>
                (if I > Source_Count -
                    (Natural (Maps.Namespaces (Source_Count)) - Destination_Count) then
                   Maps.Namespaces (I) = Namespace_Ref
                     (Natural (Maps.Namespaces (Source_Count)) - (Source_Count - I)))));

   procedure Build_Namespace_Map
     (Destination : State;
      Maps : XML3_DOM_Allocation.Import_Maps_Access;
      Source_Count : Positive;
      Destination_Count : Natural)
   is
      Filled : Natural := 0;
   begin
      for Slot in 1 .. Destination_Count loop
         pragma Loop_Invariant (Filled <= Source_Count);
         pragma Loop_Invariant
           (for all I in 1 .. Filled =>
              Maps.Namespaces (I) in 1 .. Namespace_Ref (Slot - 1)
              and then Destination.Graph.Namespaces
                (Positive (Maps.Namespaces (I))).State = Unused);
         pragma Loop_Invariant
           (for all I in 1 .. Filled =>
              (for all J in 1 .. Filled =>
                 (if I < J then Maps.Namespaces (I) < Maps.Namespaces (J))));
         exit when Filled = Source_Count;
         if Destination.Graph.Namespaces (Slot).State = Unused then
            Filled := Filled + 1;
            Maps.Namespaces (Filled) := Namespace_Ref (Slot);
         end if;
      end loop;
      pragma Assert
        (for all I in 1 .. Filled =>
           Maps.Namespaces (I) in 1 .. Namespace_Ref (Destination_Count)
           and then Destination.Graph.Namespaces
             (Positive (Maps.Namespaces (I))).State = Unused);
      if Filled < Source_Count then
         for I in Filled + 1 .. Source_Count loop
            Maps.Namespaces (I) := Namespace_Ref (Destination_Count + (I - Filled));
            pragma Loop_Invariant
              (for all J in 1 .. Filled =>
                 Maps.Namespaces (J) in 1 .. Namespace_Ref (Destination_Count)
                 and then Destination.Graph.Namespaces
                   (Positive (Maps.Namespaces (J))).State = Unused);
            pragma Loop_Invariant
              (for all J in Filled + 1 .. I =>
                 Maps.Namespaces (J) =
                   Namespace_Ref (Destination_Count + (J - Filled)));
            pragma Loop_Invariant
              (for all J in 1 .. I =>
                 (for all K in 1 .. I =>
                    (if J < K then Maps.Namespaces (J) < Maps.Namespaces (K))));
         end loop;
      end if;
      pragma Assert
        (if Filled = Source_Count then
           Natural (Maps.Namespaces (Source_Count)) <= Destination_Count
         else Natural (Maps.Namespaces (Source_Count)) =
           Destination_Count + (Source_Count - Filled));
   end Build_Namespace_Map;

   function Imported_Node
     (Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Node_Ref;
      New_Owner : Owner_Ref) return Node_View
     with Global => null, Pre => Valid (Source)
       and then Is_Arena (Source)
       and then Item in 1 .. Node_Ref (Node_Count (Source))
       and then Maps.Capacity >= Node_Count (Source)
       and then Maps.Capacity >= Namespace_Count (Source)
       and then Item <= Node_Ref (Maps.Capacity)
       and then New_Owner /= Null_Owner,
       Post => Imported_Node'Result.State = Live
         and then Imported_Node'Result.Kind = Node (Source, Item).Kind
         and then Imported_Node'Result.Facade =
           Node (Source, Item).Facade
         and then Imported_Node'Result.Name = Node (Source, Item).Name
         and then Imported_Node'Result.Name_Length =
           Node (Source, Item).Name_Length
         and then Imported_Node'Result.Content =
           Node (Source, Item).Content
         and then Imported_Node'Result.Content_Length =
           Node (Source, Item).Content_Length
         and then Imported_Node'Result.Parent =
           Mapped_Node (Maps, Node (Source, Item).Parent)
         and then Imported_Node'Result.First_Child =
           Mapped_Node (Maps, Node (Source, Item).First_Child)
         and then Imported_Node'Result.Last_Child =
           Mapped_Node (Maps, Node (Source, Item).Last_Child)
         and then Imported_Node'Result.Previous =
           Mapped_Node (Maps, Node (Source, Item).Previous)
         and then Imported_Node'Result.Next =
           Mapped_Node (Maps, Node (Source, Item).Next)
         and then Imported_Node'Result.Sibling_Order =
           Node (Source, Item).Sibling_Order
         and then Imported_Node'Result.First_Prop =
           Mapped_Node (Maps, Node (Source, Item).First_Prop)
         and then Imported_Node'Result.Last_Prop =
           Mapped_Node (Maps, Node (Source, Item).Last_Prop)
         and then Imported_Node'Result.First_Namespace =
           Mapped_Namespace (Maps, Node (Source, Item).First_Namespace)
         and then Imported_Node'Result.Last_Namespace =
           Mapped_Namespace (Maps, Node (Source, Item).Last_Namespace)
         and then Imported_Node'Result.Document =
           Mapped_Node (Maps, Node (Source, Item).Document)
         and then Imported_Node'Result.Namespace =
           Mapped_Namespace (Maps, Node (Source, Item).Namespace)
         and then Imported_Node'Result.Owner = New_Owner
         and then Imported_Node'Result.Ns_Pin =
           Mapped_Pin (Node (Source, Item).Ns_Pin, New_Owner)
         and then Imported_Node'Result.Doc_Pin =
           Mapped_Pin (Node (Source, Item).Doc_Pin, New_Owner)
         and then Imported_Node'Result.Content_Pin =
           Mapped_Pin (Node (Source, Item).Content_Pin, New_Owner)
         and then Imported_Node'Result.Tree_Rank =
           Node (Source, Item).Tree_Rank;

   function Imported_Node
     (Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Node_Ref;
      New_Owner : Owner_Ref) return Node_View
   is
      Original : constant Node_View := Node (Source, Item);
   begin
      pragma Assert (Node_Links_Valid (Source.Graph, Positive (Item)));
      pragma Assert
        (Node_Siblings_Valid (Source.Graph, Positive (Item)));
      pragma Assert
        (Node_Children_Valid (Source.Graph, Positive (Item)));
      pragma Assert
        (Node_Namespaces_Valid (Source.Graph, Positive (Item)));
      pragma Assert
        (Node_Pins_Valid (Source.Graph, Positive (Item)));
      pragma Assert
        (Original.Parent = Null_Node
         or else Original.Parent <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.First_Child = Null_Node
         or else Original.First_Child <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.Last_Child = Null_Node
         or else Original.Last_Child <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.Previous = Null_Node
         or else Original.Previous <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.Next = Null_Node
         or else Original.Next <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.First_Prop = Null_Node
         or else Original.First_Prop <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.Last_Prop = Null_Node
         or else Original.Last_Prop <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.Document = Null_Node
         or else Original.Document <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.First_Namespace = Null_Namespace
         or else Original.First_Namespace <=
           Namespace_Ref (Namespace_Count (Source)));
      pragma Assert
        (Original.Last_Namespace = Null_Namespace
         or else Original.Last_Namespace <=
           Namespace_Ref (Namespace_Count (Source)));
      pragma Assert
        (Original.First_Namespace = Null_Namespace
         or else Original.First_Namespace in
           1 .. Namespace_Ref (Namespace_Count (Source)));
      pragma Assert
        (Original.Last_Namespace = Null_Namespace
         or else Original.Last_Namespace in
           1 .. Namespace_Ref (Namespace_Count (Source)));
      pragma Assert
        (Original.Namespace = Null_Namespace
         or else Original.Namespace <=
           Namespace_Ref (Namespace_Count (Source)));
      return
        (State => Live,
         Kind => Original.Kind,
         Facade => Original.Facade,
         Name => Original.Name,
         Name_Length => Original.Name_Length,
         Content => Original.Content,
         Content_Length => Original.Content_Length,
         Parent => Mapped_Node (Maps, Original.Parent),
         First_Child => Mapped_Node (Maps, Original.First_Child),
         Last_Child => Mapped_Node (Maps, Original.Last_Child),
         Previous => Mapped_Node (Maps, Original.Previous),
         Next => Mapped_Node (Maps, Original.Next),
         Sibling_Order => Original.Sibling_Order,
         First_Prop => Mapped_Node (Maps, Original.First_Prop),
         Last_Prop => Mapped_Node (Maps, Original.Last_Prop),
         First_Namespace => Mapped_Namespace (Maps, Original.First_Namespace),
         Last_Namespace => Mapped_Namespace (Maps, Original.Last_Namespace),
         Document => Mapped_Node (Maps, Original.Document),
         Namespace => Mapped_Namespace (Maps, Original.Namespace),
         Owner => New_Owner,
         Ns_Pin => Mapped_Pin (Original.Ns_Pin, New_Owner),
         Doc_Pin => Mapped_Pin (Original.Doc_Pin, New_Owner),
         Content_Pin => Mapped_Pin (Original.Content_Pin, New_Owner),
         Tree_Rank => Original.Tree_Rank);
   end Imported_Node;

   function Imported_Namespace
     (Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Namespace_Ref;
      New_Owner : Owner_Ref) return Namespace_View
     with Global => null, Pre => Valid (Source)
       and then Is_Arena (Source)
       and then Item in 1 .. Namespace_Ref (Namespace_Count (Source))
       and then Maps.Capacity >= Node_Count (Source)
       and then Maps.Capacity >= Namespace_Count (Source)
       and then Item <= Namespace_Ref (Maps.Capacity)
       and then New_Owner /= Null_Owner,
       Post => Imported_Namespace'Result.State = Live
         and then Imported_Namespace'Result.Facade =
           Namespace (Source, Item).Facade
         and then Imported_Namespace'Result.Href =
           Namespace (Source, Item).Href
         and then Imported_Namespace'Result.Href_Length =
           Namespace (Source, Item).Href_Length
         and then Imported_Namespace'Result.Prefix =
           Namespace (Source, Item).Prefix
         and then Imported_Namespace'Result.Prefix_Length =
           Namespace (Source, Item).Prefix_Length
         and then Imported_Namespace'Result.Parent =
           Mapped_Node (Maps, Namespace (Source, Item).Parent)
         and then Imported_Namespace'Result.Previous =
           Mapped_Namespace (Maps, Namespace (Source, Item).Previous)
         and then Imported_Namespace'Result.Next =
           Mapped_Namespace (Maps, Namespace (Source, Item).Next)
         and then Imported_Namespace'Result.Owner = New_Owner
         and then Imported_Namespace'Result.Attached =
           Namespace (Source, Item).Attached
         and then Imported_Namespace'Result.Sibling_Order =
           Namespace (Source, Item).Sibling_Order;

   function Imported_Namespace
     (Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Item : Namespace_Ref;
      New_Owner : Owner_Ref) return Namespace_View
   is
      Original : constant Namespace_View := Namespace (Source, Item);
   begin
      pragma Assert
        (Namespace_Links_Valid
           (Source.Graph, Positive (Item)));
      pragma Assert
        (Original.Next = Null_Namespace
         or else Allocated_Namespace (Source.Graph, Original.Next));
      pragma Assert
        (Original.Previous = Null_Namespace
         or else Allocated_Namespace (Source.Graph, Original.Previous));
      pragma Assert
        (Original.Parent = Null_Node
         or else Original.Parent <= Node_Ref (Node_Count (Source)));
      pragma Assert
        (Original.Next = Null_Namespace
         or else Original.Next <=
           Namespace_Ref (Namespace_Count (Source)));
      pragma Assert
        (Original.Previous = Null_Namespace
         or else Original.Previous <=
           Namespace_Ref (Namespace_Count (Source)));
      return
        (State => Live,
         Facade => Original.Facade,
         Href => Original.Href,
         Href_Length => Original.Href_Length,
         Prefix => Original.Prefix,
         Prefix_Length => Original.Prefix_Length,
         Owner => New_Owner,
         Parent => Mapped_Node (Maps, Original.Parent),
         Next => Mapped_Namespace (Maps, Original.Next),
         Previous => Mapped_Namespace (Maps, Original.Previous),
         Sibling_Order => Original.Sibling_Order,
         Attached => Original.Attached);
   end Imported_Namespace;

   procedure Install_Nodes
     (Destination : in out State;
      Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Old_Node_Used : Natural;
      Old_Namespace_Used : Natural;
      Old_Owner_Used : Natural;
      Source_Count : Positive;
      New_Node_Used : Natural;
      Owner_Slot : Owner_Ref;
      New_Owner_Used : Natural)
     with Global => null,
       Pre => Valid (Destination)
         and then Valid (Source)
         and then Is_Arena (Source)
         and then Source_Count = Node_Count (Source)
         and then Maps.Capacity >= Source_Count
         and then Maps.Capacity >= Namespace_Count (Source)
         and then Old_Node_Used = Node_Count (Destination)
         and then Old_Node_Used < Natural'Last
         and then Old_Namespace_Used = Namespace_Count (Destination)
         and then Old_Owner_Used = Owner_Count (Destination)
         and then (for all I in 1 .. Source_Count =>
           Maps.Nodes (I) in 1 .. Node_Ref (Capacity_Of (Destination)))
         and then (for all I in 1 .. Source_Count =>
           (for all J in 1 .. Source_Count =>
             (if I < J then Maps.Nodes (I) < Maps.Nodes (J))))
         and then (for all I in 1 .. Source_Count =>
           Maps.Nodes (I) > Node_Ref (Old_Node_Used)
           or else Node (Destination, Maps.Nodes (I)).State = Unused)
         and then New_Node_Used >= Old_Node_Used
         and then New_Node_Used - Old_Node_Used <= Source_Count
         and then (for all I in 1 .. Source_Count =>
           (if I > Source_Count - (New_Node_Used - Old_Node_Used) then
              Maps.Nodes (I) = Node_Ref (New_Node_Used - (Source_Count - I))))
         and then New_Node_Used <= Capacity_Of (Destination)
         and then Owner_Slot in 1 .. Owner_Ref (Capacity_Of (Destination))
         and then (Owner_Slot > Owner_Ref (Old_Owner_Used)
           or else Owner (Destination, Owner_Slot).State = Unused)
         and then New_Owner_Used >= Old_Owner_Used
         and then New_Owner_Used <= Capacity_Of (Destination)
         and then New_Owner_Used >= Natural (Owner_Slot),
       Post => Well_Sized (Destination)
         and then Capacity_Of (Destination) = Capacity_Of (Destination)'Old
         and then Node_Count (Destination) = New_Node_Used
         and then Namespace_Count (Destination) = Old_Namespace_Used
         and then Owner_Count (Destination) = New_Owner_Used
         and then (for all I in 1 .. Old_Node_Used =>
           (if Destination.Graph.Nodes'Old (I).State in Live | Tombstone then
              Destination.Graph.Nodes (I) = Destination.Graph.Nodes'Old (I)))
         and then (for all I in 1 .. Old_Owner_Used =>
           (if Destination.Graph.Owners'Old (I).State in Live | Releasing then
              Destination.Graph.Owners (I) = Destination.Graph.Owners'Old (I)))
         and then (for all I in 1 .. Source_Count =>
           Node (Destination, Maps.Nodes (I)) =
             Imported_Node (Source, Maps, Node_Ref (I), Owner_Slot))
         and then (for all I in 1 .. Capacity_Of (Destination) =>
           (if not Node_Map_Contains
               (Maps, Source_Count, Node_Ref (I)) then
              Destination.Graph.Nodes (I) =
                Destination.Graph.Nodes'Old (I)))
         and then (for all I in 1 .. Capacity_Of (Destination) =>
           Destination.Graph.Namespaces (I) =
             Destination.Graph.Namespaces'Old (I))
         and then Owner (Destination, Owner_Slot) =
           (State => Live,
            Address => Owner (Source, 1).Address,
            References => Source_Count,
            Reservations => 0,
            Release_Emitted => False)
         and then (for all I in 1 .. Capacity_Of (Destination) =>
           (if Owner_Ref (I) /= Owner_Slot then
              Destination.Graph.Owners (I) =
                Destination.Graph.Owners'Old (I)))
         and then Destination.Effects.Dirty
         and then Destination.Effects.Phase = Destination'Old.Effects.Phase
         and then Destination.Effects.Cursor = Destination'Old.Effects.Cursor
         and then Destination.Effects.Active_Release =
           Destination'Old.Effects.Active_Release
         and then Destination.Effects.Released_Through =
           Destination'Old.Effects.Released_Through;

   procedure Install_Nodes
     (Destination : in out State;
      Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Old_Node_Used : Natural;
      Old_Namespace_Used : Natural;
      Old_Owner_Used : Natural;
      Source_Count : Positive;
      New_Node_Used : Natural;
      Owner_Slot : Owner_Ref;
      New_Owner_Used : Natural)
   is
      Before : constant State := Destination with Ghost;
   begin
      Destination.Graph.Node_Used := New_Node_Used;
      Destination.Graph.Owner_Used := New_Owner_Used;
      Destination.Graph.Owners (Positive (Owner_Slot)) :=
        (State => Live,
         Address => Owner (Source, 1).Address,
         References => Source_Count,
         Reservations => 0,
         Release_Emitted => False);
      Destination.Effects.Dirty := True;

      for I in 1 .. Source_Count loop
         pragma Loop_Invariant
           (for all J in 1 .. Old_Node_Used =>
             (if Before.Graph.Nodes (J).State in Live | Tombstone then
                Destination.Graph.Nodes (J) = Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (for all J in 1 .. Capacity_Of (Destination) =>
              (if not Node_Map_Contains
                  (Maps, Source_Count, Node_Ref (J)) then
                 Destination.Graph.Nodes (J) =
                   Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (for all J in 1 .. I - 1 =>
              Node (Destination, Maps.Nodes (J)) =
                Imported_Node
                  (Source, Maps, Node_Ref (J), Owner_Slot));
         Destination.Marks (Positive (Maps.Nodes (I))) := False;
         Destination.Graph.Nodes (Positive (Maps.Nodes (I))) :=
           Imported_Node
             (Source, Maps, Node_Ref (I), Owner_Slot);
      end loop;
   end Install_Nodes;

   procedure Install_Namespaces
     (Destination : in out State;
      Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Old_Namespace_Used : Natural;
      Source_Count : Positive;
      New_Namespace_Used : Natural;
      New_Owner : Owner_Ref)
     with Global => null,
       Pre => Well_Sized (Destination)
         and then Valid (Source)
         and then Is_Arena (Source)
         and then Source_Count = Namespace_Count (Source)
         and then Maps.Capacity >= Source_Count
         and then Maps.Capacity >= Node_Count (Source)
         and then New_Owner in 1 .. Owner_Ref (Owner_Count (Destination))
         and then Old_Namespace_Used = Namespace_Count (Destination)
         and then Old_Namespace_Used < Natural'Last
         and then (for all I in 1 .. Source_Count =>
           Maps.Namespaces (I) in
             1 .. Namespace_Ref (Capacity_Of (Destination)))
         and then (for all I in 1 .. Source_Count =>
           (for all J in 1 .. Source_Count =>
             (if I < J then Maps.Namespaces (I) < Maps.Namespaces (J))))
         and then (for all I in 1 .. Source_Count =>
           Maps.Namespaces (I) > Namespace_Ref (Old_Namespace_Used)
           or else Namespace
             (Destination, Maps.Namespaces (I)).State = Unused)
         and then New_Namespace_Used >= Old_Namespace_Used
         and then New_Namespace_Used - Old_Namespace_Used <= Source_Count
         and then (for all I in 1 .. Source_Count =>
           (if I > Source_Count - (New_Namespace_Used - Old_Namespace_Used) then
              Maps.Namespaces (I) = Namespace_Ref (New_Namespace_Used - (Source_Count - I))))
         and then New_Namespace_Used <= Capacity_Of (Destination),
       Post => Well_Sized (Destination)
         and then Capacity_Of (Destination) = Capacity_Of (Destination)'Old
         and then Node_Count (Destination) = Node_Count (Destination)'Old
         and then Owner_Count (Destination) = Owner_Count (Destination)'Old
         and then Destination.Effects = Destination'Old.Effects
         and then Namespace_Count (Destination) = New_Namespace_Used
         and then (for all I in 1 .. Old_Namespace_Used =>
           (if Destination.Graph.Namespaces'Old (I).State = Live then
              Destination.Graph.Namespaces (I) =
                Destination.Graph.Namespaces'Old (I)))
         and then (for all I in 1 .. Source_Count =>
           Namespace (Destination, Maps.Namespaces (I)) =
             Imported_Namespace
               (Source, Maps, Namespace_Ref (I),
                New_Owner))
         and then (for all I in 1 .. Capacity_Of (Destination) =>
           (if not Namespace_Map_Contains
               (Maps, Source_Count, Namespace_Ref (I)) then
              Destination.Graph.Namespaces (I) =
                Destination.Graph.Namespaces'Old (I)))
         and then (for all I in 1 .. Capacity_Of (Destination) =>
           Destination.Graph.Nodes (I) =
             Destination.Graph.Nodes'Old (I))
         and then (for all I in 1 .. Capacity_Of (Destination) =>
           Destination.Graph.Owners (I) =
             Destination.Graph.Owners'Old (I));

   procedure Install_Namespaces
     (Destination : in out State;
      Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      Old_Namespace_Used : Natural;
      Source_Count : Positive;
      New_Namespace_Used : Natural;
      New_Owner : Owner_Ref)
   is
      Before : constant State := Destination with Ghost;
   begin
      Destination.Graph.Ns_Used := New_Namespace_Used;
      for I in 1 .. Source_Count loop
         pragma Loop_Invariant
           (for all J in 1 .. Old_Namespace_Used =>
             (if Before.Graph.Namespaces (J).State = Live then
                Destination.Graph.Namespaces (J) =
                  Before.Graph.Namespaces (J)));
         pragma Loop_Invariant
           (for all J in 1 .. Capacity_Of (Destination) =>
              (if not Namespace_Map_Contains
                  (Maps, Source_Count, Namespace_Ref (J)) then
                 Destination.Graph.Namespaces (J) =
                   Before.Graph.Namespaces (J)));
         pragma Loop_Invariant
           (for all J in 1 .. I - 1 =>
              Namespace (Destination, Maps.Namespaces (J)) =
                Imported_Namespace
                  (Source, Maps, Namespace_Ref (J),
                   New_Owner));
         Destination.Graph.Namespaces (Positive (Maps.Namespaces (I))) :=
           Imported_Namespace
             (Source, Maps, Namespace_Ref (I), New_Owner);
      end loop;
   end Install_Namespaces;

   function Previous_Entries_Preserved (Before, After : State) return Boolean is
     (Capacity_Of (Before) = Capacity_Of (After)
      and then Node_Count (Before) <= Node_Count (After)
      and then Namespace_Count (Before) <= Namespace_Count (After)
      and then Owner_Count (Before) <= Owner_Count (After)
      and then (for all I in 1 .. Node_Count (Before) =>
        (if Before.Graph.Nodes (I).State in Live | Tombstone then
           After.Graph.Nodes (I) = Before.Graph.Nodes (I)))
      and then (for all I in 1 .. Namespace_Count (Before) =>
        (if Before.Graph.Namespaces (I).State = Live then
           After.Graph.Namespaces (I) = Before.Graph.Namespaces (I)))
      and then (for all I in 1 .. Owner_Count (Before) =>
        (if Before.Graph.Owners (I).State in Live | Releasing then
           After.Graph.Owners (I) = Before.Graph.Owners (I))))
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After),
       Annotate => (GNATprove, Inline_For_Proof);

   procedure Preserve_Previous_Links (Before, After : State)
     with Ghost, Global => null,
       Pre => Valid (Before) and then Well_Sized (After)
         and then Previous_Entries_Preserved (Before, After),
       Post =>
         (for all I in 1 .. Node_Count (Before) =>
           (if After.Graph.Nodes (I) = Before.Graph.Nodes (I) then
              Node_Links_Valid (After.Graph, I)))
         and then (for all I in 1 .. Namespace_Count (Before) =>
           (if After.Graph.Namespaces (I) = Before.Graph.Namespaces (I) then
              Namespace_Links_Valid (After.Graph, I)));

   procedure Preserve_Previous_Links (Before, After : State) is
   begin
      for I in 1 .. Node_Count (Before) loop
         if After.Graph.Nodes (I) = Before.Graph.Nodes (I) then
            pragma Assert (Node_Pins_Valid (Before.Graph, I));
            pragma Assert (Node_Siblings_Valid (Before.Graph, I));
            pragma Assert (Node_Children_Valid (Before.Graph, I));
            pragma Assert (Node_Namespaces_Valid (Before.Graph, I));
            pragma Assert (Node_Pins_Valid (After.Graph, I));
            pragma Assert (Node_Siblings_Valid (After.Graph, I));
            pragma Assert (Node_Children_Valid (After.Graph, I));
            pragma Assert (Node_Namespaces_Valid (After.Graph, I));
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             (if After.Graph.Nodes (J) = Before.Graph.Nodes (J) then
                Node_Links_Valid (After.Graph, J)));
      end loop;
      for I in 1 .. Namespace_Count (Before) loop
         if After.Graph.Namespaces (I) = Before.Graph.Namespaces (I) then
            pragma Assert (Namespace_Links_Valid (Before.Graph, I));
            pragma Assert (Namespace_Links_Valid (After.Graph, I));
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             (if After.Graph.Namespaces (J) = Before.Graph.Namespaces (J) then
                Namespace_Links_Valid (After.Graph, J)));
      end loop;
   end Preserve_Previous_Links;

   function Transfer_Layout
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref) return Boolean is
     (Previous_Entries_Preserved (Before, After)
      and then New_Owner in 1 .. Owner_Ref (Owner_Count (After))
      and then Owner_Count (After) =
        Natural'Max (Owner_Count (Before), Natural (New_Owner))
      and then (if New_Owner <= Owner_Ref (Owner_Count (Before)) then
        Owner (Before, New_Owner).State = Unused
        else New_Owner = Owner_Ref (Owner_Count (Before)) + 1)
      and then Owner (After, New_Owner) =
        (State => Live, Address => Owner (Source, 1).Address,
         References => Node_Count (Source), Reservations => 0,
         Release_Emitted => False)
      and then (for all I in 1 .. Owner_Count (Before) =>
        (if Owner_Ref (I) /= New_Owner then
           After.Graph.Owners (I) = Before.Graph.Owners (I)))
      and then Node_Count (Before) < Natural'Last
      and then Node_Count (After) - Node_Count (Before) <= Node_Count (Source)
      and then (for all I in 1 .. Node_Count (Source) =>
        (if I > Node_Count (Source) - (Node_Count (After) - Node_Count (Before)) then
           Maps.Nodes (I) = Node_Ref (Node_Count (After) - (Node_Count (Source) - I))))
      and then (for all I in 1 .. Node_Count (Source) =>
        Maps.Nodes (I) in 1 .. Node_Ref (Node_Count (After))
        and then Node (After, Maps.Nodes (I)) =
          Imported_Node (Source, Maps, Node_Ref (I), New_Owner))
      and then (for all I in 1 .. Node_Count (Source) =>
        (for all J in 1 .. Node_Count (Source) =>
          (if I < J then Maps.Nodes (I) < Maps.Nodes (J))))
      and then (for all I in 1 .. Capacity_Of (After) =>
        (if not Node_Map_Contains (Maps, Node_Count (Source), Node_Ref (I)) then
           After.Graph.Nodes (I) = Before.Graph.Nodes (I)))
      and then (if Namespace_Count (Source) = 0 then
        Namespace_Count (After) = Namespace_Count (Before)
        else Namespace_Count (Before) < Natural'Last
          and then Namespace_Count (After) - Namespace_Count (Before) <=
            Namespace_Count (Source)
          and then (for all I in 1 .. Namespace_Count (Source) =>
            (if I > Namespace_Count (Source) -
                (Namespace_Count (After) - Namespace_Count (Before)) then
               Maps.Namespaces (I) = Namespace_Ref
                 (Namespace_Count (After) - (Namespace_Count (Source) - I)))))
      and then (for all I in 1 .. Namespace_Count (Source) =>
        Maps.Namespaces (I) in 1 .. Namespace_Ref (Namespace_Count (After))
        and then Namespace (After, Maps.Namespaces (I)) =
          Imported_Namespace (Source, Maps, Namespace_Ref (I), New_Owner))
      and then (for all I in 1 .. Namespace_Count (Source) =>
        (for all J in 1 .. Namespace_Count (Source) =>
          (if I < J then Maps.Namespaces (I) < Maps.Namespaces (J))))
      and then (for all I in 1 .. Capacity_Of (After) =>
        (if not Namespace_Map_Contains
            (Maps, Namespace_Count (Source), Namespace_Ref (I)) then
           After.Graph.Namespaces (I) = Before.Graph.Namespaces (I))))
     with Ghost, Global => null,
       Pre => Valid (Before) and then Well_Sized (After)
         and then Valid (Source) and then Is_Arena (Source)
         and then Maps.Capacity >= Node_Count (Source)
         and then Maps.Capacity >= Namespace_Count (Source),
       Annotate => (GNATprove, Inline_For_Proof);

   procedure Extend_Node_Links
     (G : Graph_State; First, Last : Positive)
     with Ghost, Global => null,
       Pre => Well_Sized (G) and then First <= Last and then Last <= G.Node_Used
         and then Node_Links_Valid (G, Last)
         and then (for all J in First .. Last - 1 => Node_Links_Valid (G, J)),
       Post => (for all J in First .. Last => Node_Links_Valid (G, J));

   procedure Extend_Node_Links
     (G : Graph_State; First, Last : Positive) is
   begin
      pragma Assert (for all J in First .. Last => Node_Pins_Valid (G, J));
      pragma Assert (for all J in First .. Last => Node_Siblings_Valid (G, J));
      pragma Assert (for all J in First .. Last => Node_Children_Valid (G, J));
      pragma Assert (for all J in First .. Last => Node_Namespaces_Valid (G, J));
   end Extend_Node_Links;

   procedure Prove_Transferred_Links
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref)
     with Ghost, Global => null,
       Pre => Valid (Before) and then Well_Sized (After)
         and then Valid (Source) and then Is_Arena (Source)
         and then Maps.Capacity >= Node_Count (Source)
         and then Maps.Capacity >= Namespace_Count (Source)
         and then Transfer_Layout (Before, After, Source, Maps, New_Owner),
       Post => Links_Valid (After) and then Pins_In_Range (After)
         and then (if Facades_Present (Before) then Facades_Present (After));

   procedure Prove_Transferred_Links
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref) is
   begin
      Preserve_Previous_Links (Before, After);
      for I in 1 .. Node_Count (Source) loop
         pragma Assert (Node_Pins_Valid (Source.Graph, I));
         pragma Assert (Node_Siblings_Valid (Source.Graph, I));
         pragma Assert (Node_Children_Valid (Source.Graph, I));
         pragma Assert (Node_Namespaces_Valid (Source.Graph, I));
         pragma Assert (Node_Pins_Valid (After.Graph, Positive (Maps.Nodes (I))));
         pragma Assert (Node_Siblings_Valid (After.Graph, Positive (Maps.Nodes (I))));
         pragma Assert (Node_Children_Valid (After.Graph, Positive (Maps.Nodes (I))));
         pragma Assert (Node_Namespaces_Valid (After.Graph, Positive (Maps.Nodes (I))));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Node_Links_Valid (After.Graph, Positive (Maps.Nodes (J))));
      end loop;
      for I in 1 .. Namespace_Count (Source) loop
         pragma Assert (Namespace_Links_Valid (Source.Graph, I));
         pragma Assert (Namespace_Links_Valid (After.Graph, Positive (Maps.Namespaces (I))));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              Namespace_Links_Valid (After.Graph, Positive (Maps.Namespaces (J))));
      end loop;
      for I in 1 .. Node_Count (Before) loop
         pragma Assert (Node_Links_Valid (After.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (After.Graph, J));
      end loop;
      for I in Node_Count (Before) + 1 .. Node_Count (After) loop
         pragma Assert
           (Maps.Nodes (Node_Count (Source) - (Node_Count (After) - I)) = Node_Ref (I));
         pragma Assert (Node_Links_Valid (After.Graph, I));
         Extend_Node_Links (After.Graph, Node_Count (Before) + 1, I);
         pragma Loop_Invariant
           (for all J in Node_Count (Before) + 1 .. I => Node_Links_Valid (After.Graph, J));
      end loop;
      for I in 1 .. Namespace_Count (Before) loop
         pragma Assert (Namespace_Links_Valid (After.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (After.Graph, J));
      end loop;
      if Namespace_Count (Source) > 0 then
         for I in Namespace_Count (Before) + 1 .. Namespace_Count (After) loop
            pragma Assert
              (Maps.Namespaces (Namespace_Count (Source) -
                (Namespace_Count (After) - I)) = Namespace_Ref (I));
            pragma Assert (Namespace_Links_Valid (After.Graph, I));
            pragma Loop_Invariant
              (for all J in 1 .. I => Namespace_Links_Valid (After.Graph, J));
         end loop;
      end if;
      pragma Assert (Links_Valid (After));
      for N in Node_Ref range 1 .. Node_Ref (Node_Count (After)) loop
         pragma Assert (Node_Pins_Valid (After.Graph, Positive (N)));
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. N =>
             (if Node (After, J).State = Live then
                Node (After, J).Owner <= Owner_Ref (Owner_Count (After))
                and then Node (After, J).Ns_Pin <= Owner_Ref (Owner_Count (After))
                and then Node (After, J).Doc_Pin <= Owner_Ref (Owner_Count (After))
                and then Node (After, J).Content_Pin <= Owner_Ref (Owner_Count (After))));
      end loop;
      pragma Assert (Pins_In_Range (After));
      if Facades_Present (Before) then
         pragma Assert
           (for all I in 1 .. Node_Count (Source) =>
              Node (After, Maps.Nodes (I)).Facade /= System.Null_Address);
         for N in Node_Ref range 1 .. Node_Ref (Node_Count (After)) loop
            if Node (After, N).State in Live | Tombstone then
               if N <= Node_Ref (Node_Count (Before))
                 and then Node (Before, N).State in Live | Tombstone
               then
                  pragma Assert (Node (After, N) = Node (Before, N));
               else
                  if N > Node_Ref (Node_Count (Before)) then
                     pragma Assert
                       (Maps.Nodes (Node_Count (Source) -
                         (Node_Count (After) - Natural (N))) = N);
                  end if;
                  pragma Assert (Node_Map_Contains (Maps, Node_Count (Source), N));
               end if;
               pragma Assert (Node (After, N).Facade /= System.Null_Address);
            end if;
            pragma Loop_Invariant
              (for all J in Node_Ref range 1 .. N =>
                (if Node (After, J).State in Live | Tombstone then
                   Node (After, J).Facade /= System.Null_Address));
         end loop;
         pragma Assert
           (for all I in 1 .. Namespace_Count (Source) =>
              Namespace (After, Maps.Namespaces (I)).Facade /= System.Null_Address);
         for N in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (After)) loop
            if Namespace (After, N).State = Live then
               if N <= Namespace_Ref (Namespace_Count (Before))
                 and then Namespace (Before, N).State = Live
               then
                  pragma Assert (Namespace (After, N) = Namespace (Before, N));
               else
                  if N > Namespace_Ref (Namespace_Count (Before)) then
                     pragma Assert
                       (Maps.Namespaces (Namespace_Count (Source) -
                         (Namespace_Count (After) - Natural (N))) = N);
                  end if;
                  pragma Assert
                    (Namespace_Map_Contains (Maps, Namespace_Count (Source), N));
               end if;
               pragma Assert (Namespace (After, N).Facade /= System.Null_Address);
            end if;
            pragma Loop_Invariant
              (for all J in Namespace_Ref range 1 .. N =>
                (if Namespace (After, J).State = Live then
                   Namespace (After, J).Facade /= System.Null_Address));
         end loop;
      end if;
      pragma Assert
        (if Facades_Present (Before) then Facades_Present (After));
   end Prove_Transferred_Links;

   procedure Count_Unchanged_Holders
     (Before, After : State; B : Owner_Ref)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then Node_Count (Before) <= Node_Count (After)
         and then Node_Count (Before) < Natural'Last
         and then (for all I in 1 .. Node_Count (Before) =>
           Holds (Before.Graph.Nodes (I), B) = Holds (After.Graph.Nodes (I), B))
         and then (for all I in Node_Count (Before) + 1 .. Node_Count (After) =>
           not Holds (After.Graph.Nodes (I), B)),
       Post => Holder_Count (Snapshot_Nodes (Before), B, Node_Count (Before)) =
         Holder_Count (Snapshot_Nodes (After), B, Node_Count (After));

   procedure Count_Unchanged_Holders
     (Before, After : State; B : Owner_Ref) is
   begin
      for I in 1 .. Node_Count (After) loop
         pragma Loop_Invariant
           (Holder_Count (Snapshot_Nodes (After), B, I) =
              Holder_Count (Snapshot_Nodes (Before), B,
                Natural'Min (I, Node_Count (Before))));
      end loop;
   end Count_Unchanged_Holders;

   procedure Count_Imported_Holders
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref)
     with Ghost, Global => null,
       Pre => Valid (Before) and then Well_Sized (After)
         and then Valid (Source) and then Is_Arena (Source)
         and then Maps.Capacity >= Node_Count (Source)
         and then Maps.Capacity >= Namespace_Count (Source)
         and then Transfer_Layout (Before, After, Source, Maps, New_Owner),
       Post => Holder_Count (Snapshot_Nodes (After), New_Owner, Node_Count (After)) =
         Node_Count (Source);

   procedure Count_Imported_Holders
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref) is
      Consumed : Natural := 0;
   begin
      for I in 1 .. Node_Count (Before) loop
         pragma Assert (Node_Pins_Valid (Before.Graph, I));
         pragma Assert (not Holds (Before.Graph.Nodes (I), New_Owner));
         pragma Loop_Invariant
           (for all J in 1 .. I => not Holds (Before.Graph.Nodes (J), New_Owner));
      end loop;
      for I in 1 .. Node_Count (After) loop
         if Consumed < Node_Count (Source)
           and then Maps.Nodes (Consumed + 1) = Node_Ref (I)
         then
            Consumed := Consumed + 1;
            pragma Assert (Holds (After.Graph.Nodes (I), New_Owner));
         else
            pragma Assert
              (for all J in 1 .. Node_Count (Source) => Maps.Nodes (J) /= Node_Ref (I));
            pragma Assert (not Node_Map_Contains (Maps, Node_Count (Source), Node_Ref (I)));
            if I > Node_Count (Before) then
               pragma Assert
                 (Maps.Nodes (Node_Count (Source) - (Node_Count (After) - I)) = Node_Ref (I));
            end if;
            pragma Assert (I <= Node_Count (Before));
            pragma Assert (After.Graph.Nodes (I) = Before.Graph.Nodes (I));
            pragma Assert (not Holds (After.Graph.Nodes (I), New_Owner));
         end if;
         pragma Loop_Invariant (Consumed <= Node_Count (Source) and then Consumed <= I);
         pragma Loop_Invariant
           (for all J in 1 .. Node_Count (Source) =>
             (if J <= Consumed then Maps.Nodes (J) <= Node_Ref (I)
              else Maps.Nodes (J) > Node_Ref (I)));
         pragma Loop_Invariant
           (Holder_Count (Snapshot_Nodes (After), New_Owner, I) = Consumed);
      end loop;
      if Consumed < Node_Count (Source) then
         pragma Assert (Maps.Nodes (Consumed + 1) in 1 .. Node_Ref (Node_Count (After)));
         pragma Assert (Maps.Nodes (Consumed + 1) > Node_Ref (Node_Count (After)));
      end if;
      pragma Assert (Consumed = Node_Count (Source));
   end Count_Imported_Holders;

   procedure Prove_Transferred_Pins
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref)
     with Ghost, Global => null,
       Pre => Valid (Before) and then Well_Sized (After)
         and then Valid (Source) and then Is_Arena (Source)
         and then Maps.Capacity >= Node_Count (Source)
         and then Maps.Capacity >= Namespace_Count (Source)
         and then Transfer_Layout (Before, After, Source, Maps, New_Owner),
       Post => Pin_Equation (After);

   procedure Prove_Transferred_Pins
     (Before, After, Source : State;
      Maps : XML3_DOM_Allocation.Import_Maps;
      New_Owner : Owner_Ref) is
   begin
      Count_Imported_Holders (Before, After, Source, Maps, New_Owner);
      for B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (After)) loop
         if B /= New_Owner and then Owner (After, B).State = Live then
            pragma Assert (B <= Owner_Ref (Owner_Count (Before)));
            pragma Assert (Owner (After, B) = Owner (Before, B));
            pragma Assert
              (for all J in 1 .. Node_Count (Source) =>
                 not Holds (Node (After, Maps.Nodes (J)), B));
            for I in 1 .. Node_Count (Before) loop
               if Before.Graph.Nodes (I).State = Live then
                  pragma Assert (After.Graph.Nodes (I) = Before.Graph.Nodes (I));
               elsif After.Graph.Nodes (I).State = Live then
                  pragma Assert
                    (Node_Map_Contains (Maps, Node_Count (Source), Node_Ref (I)));
                  pragma Assert (not Holds (After.Graph.Nodes (I), B));
               end if;
               pragma Loop_Invariant
                 (for all J in 1 .. I =>
                   Holds (Before.Graph.Nodes (J), B) = Holds (After.Graph.Nodes (J), B));
            end loop;
            for I in Node_Count (Before) + 1 .. Node_Count (After) loop
               pragma Assert
                 (Maps.Nodes (Node_Count (Source) - (Node_Count (After) - I)) =
                   Node_Ref (I));
               pragma Assert (not Holds (After.Graph.Nodes (I), B));
               pragma Loop_Invariant
                 (for all J in Node_Count (Before) + 1 .. I =>
                    not Holds (After.Graph.Nodes (J), B));
            end loop;
            Count_Unchanged_Holders (Before, After, B);
         end if;
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             (if Owner (After, K).State = Live then
               Owner (After, K).Reservations <= Owner (After, K).References
               and then Owner (After, K).References - Owner (After, K).Reservations =
                 Holder_Count (Snapshot_Nodes (After), K, Node_Count (After))));
      end loop;
   end Prove_Transferred_Pins;

   procedure Adopt
     (Destination : in out State; Source : in out State_Access;
      Root : out Node_Ref; Status : out Import_Status)
   is
      Destination_Nodes : constant Natural := Node_Count (Destination);
      Destination_Namespaces : constant Natural :=
        Namespace_Count (Destination);
      Destination_Owners : constant Natural := Owner_Count (Destination);
      Source_Nodes : constant Natural := Node_Count (Source.all);
      Source_Namespaces : constant Natural := Namespace_Count (Source.all);
      Destination_Before : constant State := Destination with Ghost;
      Map_Capacity : constant Positive :=
        Positive (Natural'Max (Source_Nodes, Source_Namespaces));
      Maps : XML3_DOM_Allocation.Import_Maps_Access := null;
      Owner_Slot : Natural := 0;
      New_Node_Used : Natural;
      New_Namespace_Used : Natural;
      New_Owner_Used : Natural;
   begin
      Root := Null_Node;
      Status := Limit_Exceeded;
      if Source_Nodes > Natural (Capacity_Of (Destination)) - Destination_Nodes
        or else Source_Namespaces >
          Natural (Capacity_Of (Destination)) - Destination_Namespaces
        or else Destination_Owners = Natural (Capacity_Of (Destination))
      then
         return;
      end if;

      Maps := XML3_DOM_Allocation.Allocate_Maps (Map_Capacity);
      if Maps = null then
         Status := No_Memory;
         return;
      end if;

      for I in 1 .. Destination_Owners loop
         pragma Loop_Invariant (Owner_Slot = 0);
         if Destination.Graph.Owners (I).State = Unused then
            Owner_Slot := I;
            exit;
         end if;
      end loop;
      if Owner_Slot = 0 then
         Owner_Slot := Destination_Owners + 1;
      end if;
      pragma Assert (Owner_Slot in 1 .. Destination_Owners + 1);
      pragma Assert (Owner_Slot in 1 .. Capacity_Of (Destination));
      pragma Assert
        (Owner_Slot > Destination_Owners
         or else Destination_Before.Graph.Owners (Owner_Slot).State = Unused);

      Build_Node_Map
        (Destination, Maps, Positive (Source_Nodes), Destination_Nodes);
      if Source_Namespaces > 0 then
         Build_Namespace_Map
           (Destination, Maps, Positive (Source_Namespaces),
            Destination_Namespaces);
      end if;

      New_Node_Used :=
        Natural'Max (Destination_Nodes, Natural (Maps.Nodes (Source_Nodes)));
      if Source_Namespaces = 0 then
         New_Namespace_Used := Destination_Namespaces;
      else
         New_Namespace_Used :=
           Natural'Max
             (Destination_Namespaces,
              Natural (Maps.Namespaces (Source_Namespaces)));
      end if;
      New_Owner_Used := Natural'Max (Destination_Owners, Owner_Slot);

      pragma Assert (Maps.Nodes (Source_Nodes) <= Node_Ref (New_Node_Used));
      pragma Assert
        (for all I in 1 .. Source_Nodes =>
           Maps.Nodes (I) <= Maps.Nodes (Source_Nodes));
      pragma Assert
        (for all I in 1 .. Source_Nodes =>
           Maps.Nodes (I) in 1 .. Node_Ref (New_Node_Used));

      if Source_Namespaces > 0 then
         pragma Assert
           (Maps.Namespaces (Source_Namespaces) <= Namespace_Ref (New_Namespace_Used));
         pragma Assert
           (for all I in 1 .. Source_Namespaces =>
              Maps.Namespaces (I) <= Maps.Namespaces (Source_Namespaces));
         pragma Assert
           (for all I in 1 .. Source_Namespaces =>
              Maps.Namespaces (I) in 1 .. Namespace_Ref (New_Namespace_Used));
      end if;

      pragma Assert (New_Node_Used - Destination_Nodes <= Source_Nodes);
      pragma Assert
        (for all I in 1 .. Source_Nodes =>
          (if I > Source_Nodes - (New_Node_Used - Destination_Nodes) then
             Maps.Nodes (I) = Node_Ref (New_Node_Used - (Source_Nodes - I))));
      Install_Nodes
        (Destination, Source.all, Maps.all, Destination_Nodes,
         Destination_Namespaces, Destination_Owners, Positive (Source_Nodes),
         New_Node_Used, Owner_Ref (Owner_Slot), New_Owner_Used);
      if Source_Namespaces > 0 then
         pragma Assert (New_Namespace_Used - Destination_Namespaces <= Source_Namespaces);
         pragma Assert
           (for all I in 1 .. Source_Namespaces =>
             (if I > Source_Namespaces - (New_Namespace_Used - Destination_Namespaces) then
                Maps.Namespaces (I) =
                  Namespace_Ref (New_Namespace_Used - (Source_Namespaces - I))));
         Install_Namespaces
           (Destination, Source.all, Maps.all, Destination_Namespaces,
            Positive (Source_Namespaces), New_Namespace_Used,
            Owner_Ref (Owner_Slot));
      end if;

      pragma Assert (Well_Sized (Destination));
      pragma Assert (Capacity_Of (Destination) = Capacity_Of (Destination_Before));
      pragma Assert (Node_Count (Destination) >= Node_Count (Destination_Before));
      pragma Assert (Namespace_Count (Destination) >= Namespace_Count (Destination_Before));
      pragma Assert (Owner_Count (Destination) >= Owner_Count (Destination_Before));
      pragma Assert (Previous_Entries_Preserved (Destination_Before, Destination));
      pragma Assert (Owner_Ref (Owner_Slot) in 1 .. Owner_Ref (Owner_Count (Destination)));
      pragma Assert (Owner_Count (Destination) =
        Natural'Max (Owner_Count (Destination_Before), Natural (Owner_Ref (Owner_Slot))));
      pragma Assert ((if Owner_Ref (Owner_Slot) <= Owner_Ref (Owner_Count (Destination_Before)) then
        Owner (Destination_Before, Owner_Ref (Owner_Slot)).State = Unused
        else Owner_Ref (Owner_Slot) = Owner_Ref (Owner_Count (Destination_Before)) + 1));
      pragma Assert (Owner (Destination, Owner_Ref (Owner_Slot)) =
        (State => Live, Address => Owner (Source.all, 1).Address,
         References => Node_Count (Source.all), Reservations => 0,
         Release_Emitted => False));
      pragma Assert ((for all I in 1 .. Owner_Count (Destination_Before) =>
        (if Owner_Ref (I) /= Owner_Ref (Owner_Slot) then
           Destination.Graph.Owners (I) = Destination_Before.Graph.Owners (I))));
      pragma Assert (Node_Count (Destination_Before) < Natural'Last);
      pragma Assert (Node_Count (Destination) - Node_Count (Destination_Before) <= Node_Count (Source.all));
      pragma Assert ((for all I in 1 .. Node_Count (Source.all) =>
        (if I > Node_Count (Source.all) - (Node_Count (Destination) - Node_Count (Destination_Before)) then
           Maps.all.Nodes (I) = Node_Ref (Node_Count (Destination) - (Node_Count (Source.all) - I)))));
      pragma Assert ((for all I in 1 .. Node_Count (Source.all) =>
        Maps.all.Nodes (I) in 1 .. Node_Ref (Node_Count (Destination))
        and then Node (Destination, Maps.all.Nodes (I)) =
          Imported_Node (Source.all, Maps.all, Node_Ref (I), Owner_Ref (Owner_Slot))));
      pragma Assert ((for all I in 1 .. Node_Count (Source.all) =>
        (for all J in 1 .. Node_Count (Source.all) =>
          (if I < J then Maps.all.Nodes (I) < Maps.all.Nodes (J)))));
      pragma Assert ((for all I in 1 .. Capacity_Of (Destination) =>
        (if not Node_Map_Contains (Maps.all, Node_Count (Source.all), Node_Ref (I)) then
           Destination.Graph.Nodes (I) = Destination_Before.Graph.Nodes (I))));
      pragma Assert ((if Namespace_Count (Source.all) = 0 then
        Namespace_Count (Destination) = Namespace_Count (Destination_Before)
        else Namespace_Count (Destination_Before) < Natural'Last
          and then Namespace_Count (Destination) - Namespace_Count (Destination_Before) <=
            Namespace_Count (Source.all)
          and then (for all I in 1 .. Namespace_Count (Source.all) =>
            (if I > Namespace_Count (Source.all) -
                (Namespace_Count (Destination) - Namespace_Count (Destination_Before)) then
               Maps.all.Namespaces (I) = Namespace_Ref
                 (Namespace_Count (Destination) - (Namespace_Count (Source.all) - I))))));
      pragma Assert ((for all I in 1 .. Namespace_Count (Source.all) =>
        Maps.all.Namespaces (I) in 1 .. Namespace_Ref (Namespace_Count (Destination))
        and then Namespace (Destination, Maps.all.Namespaces (I)) =
          Imported_Namespace (Source.all, Maps.all, Namespace_Ref (I), Owner_Ref (Owner_Slot))));
      pragma Assert ((for all I in 1 .. Namespace_Count (Source.all) =>
        (for all J in 1 .. Namespace_Count (Source.all) =>
          (if I < J then Maps.all.Namespaces (I) < Maps.all.Namespaces (J)))));
      pragma Assert ((for all I in 1 .. Capacity_Of (Destination) =>
        (if not Namespace_Map_Contains
            (Maps.all, Namespace_Count (Source.all), Namespace_Ref (I)) then
           Destination.Graph.Namespaces (I) = Destination_Before.Graph.Namespaces (I))));
      pragma Assert (Transfer_Layout
        (Destination_Before, Destination, Source.all, Maps.all, Owner_Ref (Owner_Slot)));
      Prove_Transferred_Links
        (Destination_Before, Destination, Source.all, Maps.all, Owner_Ref (Owner_Slot));
      Prove_Transferred_Pins
        (Destination_Before, Destination, Source.all, Maps.all, Owner_Ref (Owner_Slot));
      for B in 1 .. Owner_Count (Destination) loop
         pragma Assert (not Destination.Graph.Owners (B).Release_Emitted);
         pragma Loop_Invariant
           (for all K in 1 .. B => not Destination.Graph.Owners (K).Release_Emitted);
      end loop;
      pragma Assert (Effects_Valid (Destination));
      pragma Assert (Pins_In_Range (Destination));
      pragma Assert (Pin_Equation (Destination));
      pragma Assert (Links_Valid (Destination));
      pragma Assert (Facades_Present (Destination));
      pragma Assert (Can_Edit (Destination));
      pragma Assert (Valid (Destination));

      Root := Maps.Nodes (1);
      pragma Assert
        (Node (Destination, Root).Kind = Document_Node
         and then Node (Destination, Root).Document = Root);
      XML3_DOM_Allocation.Free_Maps (Maps);
      XML3_DOM_Allocation.Free_State (Source);
      Status := Imported;
   end Adopt;
end XML3_DOM.Import;
