with XML3_DOM_Allocation;
with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
with XML3_DOM.Links; use XML3_DOM.Links;
with XML3_DOM.Projection; use XML3_DOM.Projection;
with XML3_DOM.Marking; use XML3_DOM.Marking;
with XML3_DOM.Freeing; use XML3_DOM.Freeing;

package body XML3_DOM with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   function Ancestor (S : State; Candidate, N : Node_Ref) return Boolean is
   begin
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (N)));
      return Ancestor_In_Nodes
        (Snapshot_Nodes (S), Node_Count (S), Candidate, N);
   end Ancestor;

   function Is_Ancestor
     (S : State; Candidate, N : Node_Ref) return Boolean
   is
      Current : Node_Ref := N;
      Remaining : Natural := Node (S, N).Tree_Rank;
   begin
      while Current /= Null_Node loop
         pragma Loop_Variant (Decreases => Remaining);
         pragma Loop_Invariant
           (Ancestor (S, Candidate, N) =
             (Current /= Null_Node and then Ancestor (S, Candidate, Current)));
         pragma Loop_Invariant
           (Current = Null_Node
            or else (Current <= Node_Ref (Node_Count (S))
              and then Node (S, Current).State = Live
              and then Node (S, Current).Tree_Rank = Remaining));
         if Current = Candidate then
            return True;
         end if;
         pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Current)));
         Current := S.Graph.Nodes (Positive (Current)).Parent;
         if Current /= Null_Node then
            pragma Assert (Current <= Node_Ref (Node_Count (S)));
            pragma Assert (S.Graph.Nodes (Positive (Current)).State = Live);
            Remaining := S.Graph.Nodes (Positive (Current)).Tree_Rank;
         else
            Remaining := 0;
         end if;
      end loop;
      return False;
   end Is_Ancestor;

   procedure Initialize
     (Current : out State_Access;
      Capacity : Positive;
      Success : out Boolean)
   is
      Fresh : State_Access := XML3_DOM_Allocation.Allocate_State (Capacity);
   begin
      if Fresh = null then
         Current := null;
         Success := False;
         return;
      end if;
      Fresh.Effects := (others => <>);
      Fresh.Graph.Node_Used := 0;
      Fresh.Graph.Ns_Used := 0;
      Fresh.Graph.Owner_Used := 0;
      for I in 1 .. Capacity loop
         pragma Loop_Variant (Increases => I);
         Fresh.Graph.Nodes (I) := (others => <>);
         Fresh.Graph.Namespaces (I) := (others => <>);
         Fresh.Graph.Owners (I) := (others => <>);
      end loop;
      Current := Fresh;
      Success := True;
   end Initialize;

   procedure Ensure_Capacity
     (Current : in out State_Access;
      Nodes_Needed : Natural;
      Namespaces_Needed : Natural;
      Owners_Needed : Natural;
      Success : out Boolean)
   is
      Needed : Natural :=
        Natural'Max (Nodes_Needed,
          Natural'Max (Namespaces_Needed, Owners_Needed));
   begin
      if Needed = 0 then
         Needed := 1;
      end if;
      Reserve (Current, Positive (Needed), Success);
   end Ensure_Capacity;

   procedure Reserve
     (Current : in out State_Access;
      Needed  : Positive;
      Success : out Boolean)
   is
      New_Capacity : Positive := Needed;
      Fresh : State_Access := null;
   begin
      if Current.Capacity >= Needed then
         Success := True;
         pragma Assert (Well_Sized (Current.Graph));
         return;
      end if;
      if Current.Capacity <= Positive'Last / 2 then
         New_Capacity := Positive'Max (Needed, Current.Capacity * 2);
      end if;
      Fresh := XML3_DOM_Allocation.Allocate_State (New_Capacity);
      if Fresh = null then
         Success := False;
         pragma Assert (Well_Sized (Current.Graph));
         return;
      end if;
      for I in 1 .. New_Capacity loop
         pragma Loop_Variant (Increases => I);
         Fresh.Graph.Nodes (I) := (others => <>);
         Fresh.Graph.Namespaces (I) := (others => <>);
         Fresh.Graph.Owners (I) := (others => <>);
      end loop;
      Fresh.Effects := Current.Effects;
      Fresh.Graph.Node_Used := Current.Graph.Node_Used;
      Fresh.Graph.Ns_Used := Current.Graph.Ns_Used;
      Fresh.Graph.Owner_Used := Current.Graph.Owner_Used;
      for I in 1 .. Current.Capacity loop
         pragma Loop_Invariant
           (for all K in 1 .. I - 1 =>
             Fresh.Graph.Nodes (K) = Current.Graph.Nodes (K)
             and then Fresh.Graph.Namespaces (K) = Current.Graph.Namespaces (K)
             and then Fresh.Graph.Owners (K) = Current.Graph.Owners (K));
         pragma Loop_Variant (Increases => I);
         Fresh.Graph.Nodes (I) := Current.Graph.Nodes (I);
         Fresh.Graph.Namespaces (I) := Current.Graph.Namespaces (I);
         Fresh.Graph.Owners (I) := Current.Graph.Owners (I);
      end loop;
      pragma Assert (Same_Used_Entries (Current.all, Fresh.all));
      Preserve_Pin_Equation (Current.all, Fresh.all);
      Preserve_Namespace_Links (Current.Graph, Fresh.Graph);
      Copied_Links_Lemma (Current.Graph, Fresh.Graph);
      pragma Assert (Valid (Fresh.all));
      declare
         Old : State_Access := Current;
      begin
         Current := Fresh;
         pragma Assert (Valid (Current.all));
         Fresh := null;
         XML3_DOM_Allocation.Free_State (Old);
         pragma Assert (Valid (Current.all));
         pragma Assert (Well_Sized (Current.Graph));
      end;
      Success := True;
   end Reserve;

   procedure Register_Owner
     (S : in out State;
      Address : System.Address;
      B : out Owner_Ref;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Slot : Natural := 0;
   begin
      for I in 1 .. S.Graph.Owner_Used loop
         if S.Graph.Owners (I).State = Unused then
            Slot := I;
            exit;
         end if;
      end loop;
      if Address = System.Null_Address
        or else (Slot = 0 and then S.Graph.Owner_Used >= S.Capacity)
      then
         B := Null_Owner;
         Success := False;
         return;
      end if;
      declare
         Target : constant Owner_Ref :=
           Owner_Ref (if Slot = 0 then S.Graph.Owner_Used + 1 else Slot);
      begin
         for I in 1 .. S.Graph.Node_Used loop
            pragma Assert (Node_Pins_Valid (S.Graph, I));
            pragma Assert (not Holds (S.Graph.Nodes (I), Target));
            pragma Loop_Invariant
              (for all K in 1 .. I => not Holds (S.Graph.Nodes (K), Target));
         end loop;
         for I in 1 .. S.Graph.Ns_Used loop
            pragma Assert (Namespace_Links_Valid (S.Graph, I));
            pragma Assert
              (if S.Graph.Namespaces (I).State = Live then
                 S.Graph.Namespaces (I).Owner /= Target);
            pragma Loop_Invariant
              (for all K in 1 .. I =>
                 (if S.Graph.Namespaces (K).State = Live then
                    S.Graph.Namespaces (K).Owner /= Target));
         end loop;
         Zero_Holder_Count (Snapshot_Nodes (S), Target, S.Graph.Node_Used);
      end;
      if Slot = 0 then
         S.Graph.Owner_Used := S.Graph.Owner_Used + 1;
         Slot := S.Graph.Owner_Used;
      end if;
      B := Owner_Ref (Slot);
      S.Effects.Dirty := True;
      S.Graph.Owners (Slot) :=
        (State => Live, Address => Address, References => 1,
         Reservations => 1, Release_Emitted => False);
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all K in 1 .. I => Node_Links_Valid (S.Graph, K));
      end loop;
      Success := True;
      pragma Assert (S.Graph.Owners (Slot).Address = Address);
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (I) = Before.Graph.Nodes (I));
      pragma Assert
        (for all I in 1 .. S.Graph.Ns_Used =>
           S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      pragma Assert (Well_Sized (S));
      pragma Assert (Effects_Valid (S));
      pragma Assert (Pins_In_Range (S));
      pragma Assert (Pin_Equation (S));
      pragma Assert (Links_Valid (S));
      pragma Assert (Can_Edit (S));
      pragma Assert
        (if Success then
           B in 1 .. Owner_Ref (Owner_Count (S))
           and then Owner (S, B).State = Live
           and then Owner (S, B).References = 1
           and then Owner (S, B).Reservations = 1
           and then Owner (S, B).Address = Address
           and then not Namespace_Reservation_Held (S, B)
           and then (for all I in Namespace_Ref range
             1 .. Namespace_Ref (Namespace_Count (S)) =>
               (if Namespace (S, I).State = Live
                then Namespace (S, I).Owner /= B))
         else B = Null_Owner);
      pragma Assert (S.Capacity = Before.Capacity);
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert (Namespace_Count (S) = Namespace_Count (Before));
      pragma Assert
        (if Success then
           Owner_Count (S) =
             Natural'Max (Owner_Count (Before), Natural (B))
           and then
             (if Natural (B) <= Owner_Count (Before)
              then Owner (Before, B).State = Unused
              else Owner_Count (S) > Owner_Count (Before)
                and then B = Owner_Ref (Owner_Count (S)))
         else Owner_Count (S) = Owner_Count (Before)
           and then Projection_Required (S) = Projection_Required (Before));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (Before)) =>
           Node (S, I) = Node (Before, I));
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             Namespace (S, I) = Namespace (Before, I));
      pragma Assert
        (if Success then
           (for all B0 in Owner_Ref range 1 .. Owner_Ref (Owner_Count (Before)) =>
              (if B0 /= B then Owner (S, B0) = Owner (Before, B0)))
           and then Owner (S, B).Address /= System.Null_Address
         else Same_Used_Entries (Before, S));
      pragma Assert
        (if Facades_Present (Before) then Facades_Present (S));
   end Register_Owner;

   procedure Register_Node
     (S : in out State;
      Kind : Node_Kind;
      Facade : System.Address;
      Own : Owner_Ref;
      Doc_Pin : Owner_Ref;
      N : out Node_Ref;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Slot : Natural := 0;
   begin
      for I in 1 .. S.Graph.Node_Used loop
         if S.Graph.Nodes (I).State = Unused then
            Slot := I;
            exit;
         end if;
      end loop;
      if (Slot = 0 and then S.Graph.Node_Used >= S.Capacity)
        or else S.Graph.Owners (Positive (Own)).Reservations = 0
        or else S.Graph.Owners (Positive (Own)).References = Natural'Last
        or else (Doc_Pin /= Null_Owner and then Doc_Pin /= Own
          and then S.Graph.Owners (Positive (Doc_Pin)).References = Natural'Last)
      then
         N := Null_Node;
         Success := False;
         return;
      end if;
      if Slot = 0 then
         S.Graph.Node_Used := S.Graph.Node_Used + 1;
         Slot := S.Graph.Node_Used;
      end if;
      S.Effects.Dirty := True;
      N := Node_Ref (Slot);
      S.Graph.Nodes (Slot) :=
        (State => Live, Kind => Kind, Facade => Facade,
         Name => System.Null_Address, Name_Length => 0,
         Content => System.Null_Address, Content_Length => 0,
         Parent => Null_Node, First_Child => Null_Node,
         Last_Child => Null_Node, Previous => Null_Node,
         Next => Null_Node, First_Prop => Null_Node,
         Sibling_Order => 0,
         Last_Prop => Null_Node, Document => Null_Node,
         First_Namespace => Null_Namespace,
         Last_Namespace => Null_Namespace,
         Namespace => Null_Namespace, Owner => Own,
         Ns_Pin => Null_Owner, Doc_Pin => Doc_Pin,
         Content_Pin => Null_Owner, Name_Pin => Null_Owner,
         Tree_Rank => 0, Source_Line => 0);
      S.Graph.Owners (Positive (Own)).References :=
        S.Graph.Owners (Positive (Own)).References + 1;
      if Doc_Pin /= Null_Owner and then Doc_Pin /= Own then
         S.Graph.Owners (Positive (Doc_Pin)).References :=
           S.Graph.Owners (Positive (Doc_Pin)).References + 1;
      end if;
      for B in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) loop
         Changed_Holder_Count
           (Snapshot_Nodes (Before), Snapshot_Nodes (S), B,
            S.Graph.Node_Used, Positive (Slot));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             (S.Graph.Owners (Positive (K)).State /= Live
              or else
                (S.Graph.Owners (Positive (K)).References
                   - S.Graph.Owners (Positive (K)).Reservations =
                 Holder_Count (Snapshot_Nodes (S), K, S.Graph.Node_Used))));
      end loop;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert
           (if I <= Before.Graph.Node_Used then Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all K in 1 .. I => Node_Links_Valid (S.Graph, K));
      end loop;
      Success := True;
      pragma Assert
        (S.Graph.Owners (Positive (Own)).State = Live
         and then S.Graph.Owners (Positive (Own)).References =
           Before.Graph.Owners (Positive (Own)).References + 1
         and then S.Graph.Owners (Positive (Own)).Reservations =
           Before.Graph.Owners (Positive (Own)).Reservations
         and then S.Graph.Owners (Positive (Own)).Address =
           Before.Graph.Owners (Positive (Own)).Address);
      pragma Assert
        (for all I in 1 .. Before.Graph.Node_Used =>
           (if I /= Slot then
              S.Graph.Nodes (I) = Before.Graph.Nodes (I)));
      pragma Assert
        (for all I in 1 .. Before.Graph.Ns_Used =>
           S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      pragma Assert
        (if Doc_Pin = Null_Owner then
           (for all K in 1 .. Before.Graph.Owner_Used =>
              (if K /= Positive (Own) then
                 S.Graph.Owners (K) = Before.Graph.Owners (K))));
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      pragma Assert (Well_Sized (S));
      pragma Assert (Effects_Valid (S));
      pragma Assert (Pins_In_Range (S));
      pragma Assert (Pin_Equation (S));
      pragma Assert (Links_Valid (S));
   end Register_Node;

   procedure Release_Reservation
     (S : in out State; B : Owner_Ref)
   is
      Before : constant State := S with Ghost;
      Item : Owner_View := S.Graph.Owners (Positive (B));
   begin
      Item.Reservations := Item.Reservations - 1;
      Item.References := Item.References - 1;
      if Item.References = 0 then
         pragma Assert (Item.Reservations = 0);
         pragma Assert
           (Holder_Count (Snapshot_Nodes (S), B, S.Graph.Node_Used) = 0);
         Item.State := Releasing;
         Item.Release_Emitted := False;
      end if;
      S.Effects.Dirty := True;
      S.Graph.Owners (Positive (B)) := Item;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         if Holds (S.Graph.Nodes (I), B) then
            pragma Assert (Positive_Holder_Count_Witness
              (Snapshot_Nodes (S), B, S.Graph.Node_Used, I));
            pragma Assert (Item.State = Live);
         end if;
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      pragma Assert
        (for all I in 1 .. Before.Graph.Node_Used =>
           S.Graph.Nodes (I) = Before.Graph.Nodes (I));
      pragma Assert
        (for all I in 1 .. Before.Graph.Ns_Used =>
           S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      pragma Assert
        (for all K in 1 .. Before.Graph.Owner_Used =>
           (if K /= Positive (B) then
              S.Graph.Owners (K) = Before.Graph.Owners (K)));
   end Release_Reservation;

   procedure Release_Namespace_Reservation
     (S : in out State; N : Namespace_Ref)
   is
      Before : constant State := S with Ghost;
      B : constant Owner_Ref := S.Graph.Namespaces (Positive (N)).Owner;
      Item : Namespace_View := S.Graph.Namespaces (Positive (N));
   begin
      Item.Owns_Reservation := False;
      S.Graph.Namespaces (Positive (N)) := Item;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Namespace_Links_Valid (Before.Graph, Positive (N)));
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (Before.Graph, I));
         pragma Assert (Namespace_Links_Valid (Before.Graph, Positive (N)));
         pragma Assert (Namespace_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (S.Graph, J));
      end loop;
      Release_Reservation (S, B);
   end Release_Namespace_Reservation;

   procedure Begin_Projection (S : in out State) is
   begin
      S.Effects :=
        (Phase => Projecting_Nodes, Dirty => True, Cursor => 0,
         Released_Through => 0, Active_Release => Null_Owner);
   end Begin_Projection;

   procedure Next_Node_Projection (S : in out State; N : out Node_Ref) is
   begin
      while S.Effects.Cursor < S.Graph.Node_Used loop
         pragma Loop_Variant (Increases => S.Effects.Cursor);
         pragma Loop_Invariant (Valid (S) and then Phase (S) = Projecting_Nodes);
         pragma Loop_Invariant (Same_Graph (S, S'Loop_Entry));
         pragma Loop_Invariant (S.Effects.Cursor >= S.Effects.Cursor'Loop_Entry);
         S.Effects.Cursor := S.Effects.Cursor + 1;
         if S.Graph.Nodes (S.Effects.Cursor).State in Live | Tombstone then
            N := Node_Ref (S.Effects.Cursor);
            S.Effects.Phase := Node_Projection_Pending;
            return;
         end if;
      end loop;
      N := Null_Node;
      S.Effects.Cursor := 0;
      S.Effects.Phase := Projecting_Namespaces;
   end Next_Node_Projection;

   function Namespace_Release_Required (S : State; N : Namespace_Ref) return Boolean is
   begin
      pragma Assert (Namespace_Links_Valid (S.Graph, Positive (N)));
      return Owner (S, Namespace (S, N).Owner).State = Releasing;
   end Namespace_Release_Required;

   procedure Next_Namespace_Projection (S : in out State; N : out Namespace_Ref) is
   begin
      while S.Effects.Cursor < S.Graph.Ns_Used loop
         pragma Loop_Variant (Increases => S.Effects.Cursor);
         pragma Loop_Invariant (Valid (S) and then Phase (S) = Projecting_Namespaces);
         pragma Loop_Invariant (Same_Graph (S, S'Loop_Entry));
         pragma Loop_Invariant (S.Effects.Cursor >= S.Effects.Cursor'Loop_Entry);
         S.Effects.Cursor := S.Effects.Cursor + 1;
         if S.Graph.Namespaces (S.Effects.Cursor).State = Live then
            N := Namespace_Ref (S.Effects.Cursor);
            S.Effects.Phase := Namespace_Projection_Pending;
            return;
         end if;
      end loop;
      N := Null_Namespace;
      S.Effects :=
        (Phase => Editing, Dirty => False, Cursor => 0,
         Released_Through => 0, Active_Release => Null_Owner);
   end Next_Namespace_Projection;

   procedure Acknowledge_Projection (S : in out State) is
   begin
      S.Effects.Phase :=
        (if S.Effects.Phase = Node_Projection_Pending
         then Projecting_Nodes else Projecting_Namespaces);
   end Acknowledge_Projection;

   procedure Register_Namespace
     (S : in out State;
      Facade : System.Address;
      Href : System.Address;
      Href_Length : Natural;
      Prefix : System.Address;
      Prefix_Length : Natural;
      Own : Owner_Ref;
      Ns : out Namespace_Ref;
      Success : out Boolean;
      Owns_Reservation : Boolean := False)
   is
      Before : constant State := S with Ghost;
      Slot : Natural := 0;
   begin
      for I in 1 .. S.Graph.Ns_Used loop
         if S.Graph.Namespaces (I).State = Unused then
            Slot := I;
            exit;
         end if;
      end loop;
      if Facade = System.Null_Address
        or else (Slot = 0 and then S.Graph.Ns_Used >= S.Capacity)
      then
         Ns := Null_Namespace;
         Success := False;
         return;
      end if;
      if Slot = 0 then
         S.Graph.Ns_Used := S.Graph.Ns_Used + 1;
         Slot := S.Graph.Ns_Used;
      end if;
      S.Effects.Dirty := True;
      Ns := Namespace_Ref (Slot);
      S.Graph.Namespaces (Slot) :=
        (State => Live, Facade => Facade, Href => Href,
         Href_Length => Href_Length, Prefix => Prefix,
         Prefix_Length => Prefix_Length, Owner => Own,
         Parent => Null_Node, Next => Null_Namespace, Previous => Null_Namespace,
         Sibling_Order => 0, Attached => False,
         Owns_Reservation => Owns_Reservation);
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         if I /= Slot then
            pragma Assert (Namespace_Links_Valid (Before.Graph, I));
         end if;
         pragma Assert (Namespace_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (S.Graph, J));
      end loop;
      Success := True;
      pragma Assert
        (for all I in 1 .. Before.Graph.Node_Used =>
           S.Graph.Nodes (I) = Before.Graph.Nodes (I));
      pragma Assert
        (for all B in 1 .. Before.Graph.Owner_Used =>
           S.Graph.Owners (B) = Before.Graph.Owners (B));
   end Register_Namespace;

   procedure Namespace_Append_Lemma
     (Before, After : Graph_State; Element : Node_Ref; Ns : Namespace_Ref)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Node_Used = After.Node_Used
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Owner_Used = After.Owner_Used
       and then Element in 1 .. Node_Ref (Before.Node_Used)
       and then Ns in 1 .. Namespace_Ref (Before.Ns_Used)
       and then Before.Nodes (Positive (Element)).State = Live
       and then Before.Nodes (Positive (Element)).Kind = Element_Node
       and then Before.Namespaces (Positive (Ns)).State = Live
       and then not Before.Namespaces (Positive (Ns)).Attached
       and then
         (Before.Namespaces (Positive (Ns)).Owner =
            Before.Nodes (Positive (Element)).Owner
          or else Before.Namespaces (Positive (Ns)).Owns_Reservation)
       and then (for all I in 1 .. Before.Owner_Used =>
         Before.Owners (I) = After.Owners (I))
       and then (for all I in 1 .. Before.Node_Used =>
         Node_Links_Valid (Before, I))
       and then (for all I in 1 .. Before.Ns_Used =>
         Namespace_Links_Valid (Before, I))
       and then (declare
         P : constant Node_View := Before.Nodes (Positive (Element));
         Last : constant Namespace_Ref := P.Last_Namespace;
       begin
         (Last = 0 or else
           Before.Namespaces (Positive (Last)).Sibling_Order < Natural'Last)
         and then (for all I in 1 .. Before.Node_Used =>
           After.Nodes (I) =
             (if I = Positive (Element) then
               (Before.Nodes (I) with delta
                 First_Namespace => (if Last = 0 then Ns else P.First_Namespace),
                 Last_Namespace => Ns)
              else Before.Nodes (I)))
         and then (for all I in 1 .. Before.Ns_Used =>
           After.Namespaces (I) =
             (if I = Positive (Ns) then
               (Before.Namespaces (I) with delta
                 Parent => Element, Previous => Last, Attached => True,
                 Sibling_Order => (if Last = 0 then
                   Before.Namespaces (I).Sibling_Order
                   else Before.Namespaces (Positive (Last)).Sibling_Order + 1))
              elsif Namespace_Ref (I) = Last then
                (Before.Namespaces (I) with delta Next => Ns)
              else Before.Namespaces (I)))),
     Post => (for all I in 1 .. After.Node_Used => Node_Links_Valid (After, I))
       and then (for all I in 1 .. After.Ns_Used =>
         Namespace_Links_Valid (After, I));

   procedure Namespace_Append_Lemma
     (Before, After : Graph_State; Element : Node_Ref; Ns : Namespace_Ref)
   is
   begin
      for I in 1 .. Before.Node_Used loop
         pragma Assert (Node_Links_Valid (Before, I));
         pragma Assert (Node_Namespaces_Valid (Before, Positive (Element)));
         pragma Assert (Namespace_Links_Valid (Before, Positive (Ns)));
         pragma Assert (Node_Pins_Valid (After, I));
         pragma Assert (Node_Siblings_Valid (After, I));
         pragma Assert (Node_Children_Valid (After, I));
         pragma Assert (Node_Namespaces_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (After, J));
      end loop;
      for I in 1 .. Before.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (Before, I));
         pragma Assert (Node_Namespaces_Valid (Before, Positive (Element)));
         pragma Assert (Namespace_Links_Valid (Before, Positive (Ns)));
         pragma Assert (Namespace_Links_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (After, J));
      end loop;
   end Namespace_Append_Lemma;

   procedure Attach_Namespace
     (S : in out State; Element : Node_Ref; Ns : Namespace_Ref;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Parent_Item : Node_View := S.Graph.Nodes (Positive (Element));
      Ns_Item : Namespace_View := S.Graph.Namespaces (Positive (Ns));
      Last : Namespace_Ref := Parent_Item.Last_Namespace;
   begin
      if Parent_Item.Kind /= Element_Node or else Ns_Item.Attached
        or else
          (Ns_Item.Owner /= Parent_Item.Owner
           and then not Ns_Item.Owns_Reservation)
        or else (Last /= Null_Namespace and then
          (Last > Namespace_Ref (S.Graph.Ns_Used) or else
           S.Graph.Namespaces (Positive (Last)).Sibling_Order = Natural'Last))
      then
         Success := False;
         return;
      end if;
      S.Effects.Dirty := True;
      if Last = Null_Namespace then
         Parent_Item.First_Namespace := Ns;
      else
         S.Graph.Namespaces (Positive (Last)).Next := Ns;
         Ns_Item.Sibling_Order := S.Graph.Namespaces (Positive (Last)).Sibling_Order + 1;
      end if;
      Parent_Item.Last_Namespace := Ns;
      Ns_Item.Parent := Element;
      Ns_Item.Previous := Last;
      Ns_Item.Attached := True;
      S.Graph.Nodes (Positive (Element)) := Parent_Item;
      S.Graph.Namespaces (Positive (Ns)) := Ns_Item;
      Preserve_Pin_Equation (Before, S);
      Namespace_Append_Lemma (Before.Graph, S.Graph, Element, Ns);
      Success := True;
      pragma Assert (Valid (S));
   end Attach_Namespace;

   procedure Namespace_Detach_Lemma
     (Before, After : Graph_State; Ns : Namespace_Ref)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Node_Used = After.Node_Used
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Owner_Used = After.Owner_Used
       and then Before.Owners = After.Owners
       and then Ns in 1 .. Namespace_Ref (Before.Ns_Used)
       and then Before.Namespaces (Positive (Ns)).State = Live
       and then Before.Namespaces (Positive (Ns)).Attached
       and then (for all I in 1 .. Before.Node_Used => Node_Links_Valid (Before, I))
       and then (for all I in 1 .. Before.Ns_Used => Namespace_Links_Valid (Before, I))
       and then (declare
         N : constant Namespace_View := Before.Namespaces (Positive (Ns));
       begin
         (for all I in 1 .. Before.Node_Used =>
           After.Nodes (I) =
             (if Node_Ref (I) = N.Parent then
               (Before.Nodes (I) with delta
                 First_Namespace => (if N.Previous = 0 then N.Next
                                     else Before.Nodes (I).First_Namespace),
                 Last_Namespace => (if N.Next = 0 then N.Previous
                                    else Before.Nodes (I).Last_Namespace))
              else Before.Nodes (I)))
         and then (for all I in 1 .. Before.Ns_Used =>
           After.Namespaces (I) =
             (if Namespace_Ref (I) = Ns then
               (Before.Namespaces (I) with delta Parent => 0, Next => 0,
                 Previous => 0, Attached => False)
              elsif Namespace_Ref (I) = N.Previous then
               (Before.Namespaces (I) with delta Next => N.Next)
              elsif Namespace_Ref (I) = N.Next then
               (Before.Namespaces (I) with delta Previous => N.Previous)
              else Before.Namespaces (I)))),
     Post => (for all I in 1 .. After.Node_Used => Node_Links_Valid (After, I))
       and then (for all I in 1 .. After.Ns_Used => Namespace_Links_Valid (After, I));

   procedure Namespace_Detach_Lemma
     (Before, After : Graph_State; Ns : Namespace_Ref)
   is
   begin
      pragma Assert (Namespace_Links_Valid (Before, Positive (Ns)));
      for I in 1 .. Before.Node_Used loop
         pragma Assert (Node_Links_Valid (Before, I));
         pragma Assert (Node_Pins_Valid (Before, I));
         pragma Assert (Node_Siblings_Valid (Before, I));
         pragma Assert (Node_Children_Valid (Before, I));
         pragma Assert (Node_Namespaces_Valid (Before, I));
         pragma Assert (Node_Pins_Valid (After, I));
         pragma Assert (Node_Siblings_Valid (After, I));
         pragma Assert (Node_Children_Valid (After, I));
         if After.Nodes (I).State in Live | Tombstone then
            if After.Nodes (I).First_Namespace /= Null_Namespace then
               pragma Assert (Allocated_Namespace
                 (Before, After.Nodes (I).First_Namespace));
               pragma Assert (Namespace_Links_Valid
                 (Before, Positive (After.Nodes (I).First_Namespace)));
            end if;
            if After.Nodes (I).Last_Namespace /= Null_Namespace then
               pragma Assert (Allocated_Namespace
                 (Before, After.Nodes (I).Last_Namespace));
               pragma Assert (Namespace_Links_Valid
                 (Before, Positive (After.Nodes (I).Last_Namespace)));
            end if;
         end if;
         pragma Assert (Node_Namespaces_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (After, J));
      end loop;
      for I in 1 .. Before.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (Before, I));
         pragma Assert (Namespace_Links_Valid (Before, Positive (Ns)));
         if After.Namespaces (I).State = Live then
            if After.Namespaces (I).Parent /= Null_Node then
               pragma Assert (Node_Namespaces_Valid
                 (Before, Positive (After.Namespaces (I).Parent)));
            end if;
            if After.Namespaces (I).Previous /= Null_Namespace then
               pragma Assert (Namespace_Links_Valid
                 (Before, Positive (After.Namespaces (I).Previous)));
            end if;
            if After.Namespaces (I).Next /= Null_Namespace then
               pragma Assert (Namespace_Links_Valid
                 (Before, Positive (After.Namespaces (I).Next)));
            end if;
         end if;
         pragma Assert (Namespace_Links_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (After, J));
      end loop;
   end Namespace_Detach_Lemma;

   procedure Detach_Namespace_Declaration
     (S : in out State; Ns : Namespace_Ref)
   is
      Before_State : constant State := S with Ghost;
      Before : constant Graph_State := S.Graph with Ghost;
      Item : Namespace_View := S.Graph.Namespaces (Positive (Ns));
      Parent_Item : Node_View;
      Previous : constant Namespace_Ref := Item.Previous;
      Next : constant Namespace_Ref := Item.Next;
   begin
      pragma Assert (Item.Parent in 1 .. Node_Ref (S.Graph.Node_Used));
      pragma Assert
        (Previous = Null_Namespace
         or else Previous in 1 .. Namespace_Ref (S.Graph.Ns_Used));
      pragma Assert
        (Next = Null_Namespace
         or else Next in 1 .. Namespace_Ref (S.Graph.Ns_Used));
      pragma Assert (Namespace_Links_Valid (Before, Positive (Ns)));
      pragma Assert (Previous /= Ns and then Next /= Ns);
      pragma Assert
        (Previous = Null_Namespace or else Next = Null_Namespace
         or else Previous /= Next);
      Parent_Item := S.Graph.Nodes (Positive (Item.Parent));
      if Previous = Null_Namespace then
         Parent_Item.First_Namespace := Next;
      else
         S.Graph.Namespaces (Positive (Previous)).Next := Next;
         pragma Assert
           (S.Graph.Namespaces (Positive (Previous)).Next = Next);
      end if;
      if Next = Null_Namespace then
         Parent_Item.Last_Namespace := Previous;
      else
         S.Graph.Namespaces (Positive (Next)).Previous := Previous;
         pragma Assert
           (S.Graph.Namespaces (Positive (Next)).Previous = Previous);
      end if;
      S.Graph.Nodes (Positive (Item.Parent)) := Parent_Item;
      Item.Parent := Null_Node;
      Item.Next := Null_Namespace;
      Item.Previous := Null_Namespace;
      Item.Attached := False;
      S.Graph.Namespaces (Positive (Ns)) := Item;
      S.Effects.Dirty := True;
      Preserve_Pin_Equation (Before_State, S);
      Namespace_Detach_Lemma (Before, S.Graph, Ns);
      pragma Assert (Valid (S) and then Can_Edit (S));
   end Detach_Namespace_Declaration;

   procedure Set_Node_Projection
     (S : in out State;
      N : Node_Ref;
      Name : System.Address;
      Name_Length : Natural;
      Content : System.Address;
      Content_Length : Natural;
      Document : Node_Ref;
      Namespace : Namespace_Ref;
      Namespace_Pin : Owner_Ref;
      Doc_Pin : Owner_Ref;
      Content_Pin : Owner_Ref;
      Name_Pin : Owner_Ref;
      Success : out Boolean)
   is
      Proposed : constant Node_View := Projected_View
        (Node (S, N), Name, Name_Length, Content, Content_Length,
         Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin, Name_Pin);
   begin
      if not Projection_Allowed (S, N, Proposed) then
         Success := False;
         return;
      end if;
      Set_Node_Projection_Internal
        (S, N, Name, Name_Length, Content, Content_Length,
         Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin, Name_Pin,
         Success);
   end Set_Node_Projection;

   function Unlinked_View (S : State; N, I : Node_Ref) return Node_View is
     (declare
        Item : constant Node_View := Node (S, N);
        Original : constant Node_View := Node (S, I);
      begin
        (if Item.Parent = 0 then Original
         elsif I = N then
           (Original with delta Parent => 0, Previous => 0, Next => 0)
         else
           (Original with delta
             Previous => (if I = Item.Next then Item.Previous else Original.Previous),
             Next => (if I = Item.Previous then Item.Next else Original.Next),
             First_Child =>
               (if I = Item.Parent and then Item.Previous = 0
                 and then Item.Kind /= Attribute_Node
                then Item.Next else Original.First_Child),
             Last_Child =>
               (if I = Item.Parent and then Item.Next = 0
                 and then Item.Kind /= Attribute_Node
                then Item.Previous else Original.Last_Child),
             First_Prop =>
               (if I = Item.Parent and then Item.Previous = 0
                 and then Item.Kind = Attribute_Node
                then Item.Next else Original.First_Prop),
             Last_Prop =>
               (if I = Item.Parent and then Item.Next = 0
                 and then Item.Kind = Attribute_Node
                then Item.Previous else Original.Last_Prop))));

   procedure Unlink (S : in out State; N : Node_Ref) is
      Before : constant State := S with Ghost;
      Item : Node_View := S.Graph.Nodes (Positive (N));
      Parent_Is_Properties : Boolean;
   begin
      pragma Assert (Node_Links_Valid (S.Graph, Positive (N)));
      if Item.Parent = Null_Node then
         return;
      end if;
      if Item.Parent > Node_Ref (S.Graph.Node_Used)
        or else Item.Previous > Node_Ref (S.Graph.Node_Used)
        or else Item.Next > Node_Ref (S.Graph.Node_Used)
      then
         return;
      end if;
      Parent_Is_Properties := Item.Kind = Attribute_Node;
      pragma Assert (Node_Links_Valid (S.Graph, Positive (Item.Parent)));
      if Item.Previous /= 0 then
         pragma Assert (Node_Links_Valid (S.Graph, Positive (Item.Previous)));
      end if;
      if Item.Next /= 0 then
         pragma Assert (Node_Links_Valid (S.Graph, Positive (Item.Next)));
      end if;
      pragma Assert (Item.Previous /= Item.Parent);
      pragma Assert (Item.Next /= Item.Parent);
      pragma Assert (Item.Previous = 0 or else Item.Previous /= Item.Next);

      S.Effects.Dirty := True;
      if Item.Previous /= Null_Node then
         S.Graph.Nodes (Positive (Item.Previous)).Next := Item.Next;
      elsif Parent_Is_Properties then
         S.Graph.Nodes (Positive (Item.Parent)).First_Prop := Item.Next;
      else
         S.Graph.Nodes (Positive (Item.Parent)).First_Child := Item.Next;
      end if;

      if Item.Next /= Null_Node then
         S.Graph.Nodes (Positive (Item.Next)).Previous := Item.Previous;
      elsif Parent_Is_Properties then
         S.Graph.Nodes (Positive (Item.Parent)).Last_Prop := Item.Previous;
      else
         S.Graph.Nodes (Positive (Item.Parent)).Last_Child := Item.Previous;
      end if;
      Item.Parent := Null_Node;
      Item.Previous := Null_Node;
      Item.Next := Null_Node;
      S.Graph.Nodes (Positive (N)) := Item;
      Unlink_Lemma (Before, S, N);
      Preserve_Pin_Equation (Before, S);
      pragma Assert (Snapshot_Owners (S) = Snapshot_Owners (Before));
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      pragma Assert (Well_Sized (S));
      pragma Assert (Valid (S));
      pragma Assert (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
      pragma Assert (Snapshot_Marks (S) = Snapshot_Marks (Before));
      Unlinked_Fields (Before, S, N);
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I).State = Node (Before, I).State
           and then Node (S, I).Tree_Rank = Node (Before, I).Tree_Rank
           and then Node (S, I).Parent =
             (if I = N then Null_Node else Node (Before, I).Parent));
   end Unlink;

   procedure Leaf_Retained_Declarations_Lemma (S : State; Root : Node_Ref) is
   begin
      for I in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) loop
         if Namespace (S, I).State = Live
           and then Namespace (S, I).Owns_Reservation
           and then Namespace (S, I).Parent /= Null_Node
         then
            Empty_Namespace_List_Lemma (S, Root, I);
            Leaf_Ancestor_Lemma (S, Root, Namespace (S, I).Parent);
         end if;
         pragma Loop_Invariant
           (for all J in Namespace_Ref range 1 .. I =>
             (if Namespace (S, J).State = Live
               and then Namespace (S, J).Owns_Reservation
               and then Namespace (S, J).Parent /= Null_Node
              then not Ancestor (S, Root, Namespace (S, J).Parent)));
      end loop;
   end Leaf_Retained_Declarations_Lemma;

   procedure Attach_Child
     (S : in out State; Parent, Child : Node_Ref; Success : out Boolean)
   is
   begin
      Attach (S, Parent, Child, False, Success);
   end Attach_Child;

   procedure Insert_Sibling
     (S : in out State; Sibling, Child : Node_Ref; Before : Boolean;
      Success : out Boolean)
   is
      Parent : Node_Ref;
      Attached : Boolean;
      Old_Last : Node_Ref;
      Previous : Node_Ref;
      Next : Node_Ref;
      Threshold : Natural;
      Old_Order : Natural;
   begin
      Success := False;
      if Sibling = Child
        or else Node (S, Sibling).Kind = Attribute_Node
        or else Node (S, Child).Kind = Attribute_Node
      then
         return;
      end if;
      Parent := Node (S, Sibling).Parent;
      if Parent = Null_Node
        or else Node (S, Parent).State /= Live
        or else Node (S, Parent).Kind not in
          Document_Node | Element_Node | Attribute_Node
        or else (Node (S, Parent).Kind = Attribute_Node
          and then Node (S, Child).Kind /= Text_Node)
      then
         return;
      end if;
      if Before then
         if Node (S, Child).Parent = Parent
           and then Node (S, Child).Next = Sibling
         then
            Success := True;
            return;
         end if;
      elsif Node (S, Child).Parent = Parent
        and then Node (S, Child).Previous = Sibling
      then
         Success := True;
         return;
      end if;
      Attach_Child (S, Parent, Child, Attached);
      if not Attached then
         return;
      end if;
      pragma Assert (Node (S, Child).Parent = Parent);
      pragma Assert (Node (S, Sibling).Parent = Parent);
      pragma Assert (Child <= Node_Ref (S.Graph.Node_Used));
      pragma Assert (Parent <= Node_Ref (S.Graph.Node_Used));
      pragma Assert (Node (S, Parent).Last_Child = Child);
      pragma Assert (Node (S, Child).Next = Null_Node);
      if (Before and then Node (S, Child).Next = Sibling)
        or else ((not Before) and then Node (S, Child).Previous = Sibling)
      then
         Success := True;
         return;
      end if;
      Old_Last := Node (S, Child).Previous;
      Previous := (if Before then Node (S, Sibling).Previous else Sibling);
      Next := (if Before then Sibling else Node (S, Sibling).Next);
      Old_Order := Node (S, Child).Sibling_Order;
      Tail_Order_Bound (S, Parent, Sibling);
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Sibling)));
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Child)));
      pragma Assert (Node_Children_Valid (S.Graph, Positive (Parent)));
      pragma Assert (Sibling /= Node (S, Parent).Last_Child);
      pragma Assert (Node (S, Child).Previous /= Null_Node);
      pragma Assert (Node (S, Sibling).Next /= Null_Node);
      pragma Assert (Parent /= Child);
      pragma Assert (Parent /= Sibling);
      pragma Assert (Old_Last /= Previous);
      Threshold := (if Before then Node (S, Sibling).Sibling_Order
                    else Node (S, Sibling).Sibling_Order + 1);
      pragma Assert (Old_Last /= Null_Node);
      pragma Assert (Next /= Null_Node);
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Next)));
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Old_Last)));
      if Previous /= Null_Node then
         pragma Assert (Node_Siblings_Valid (S.Graph, Positive (Previous)));
      end if;
      Tail_Order_Bound (S, Parent, Next);
      Place_Tail_Sibling
        (S, Parent, Child, Old_Last, Previous, Next, Threshold, Old_Order);
      Success := True;
   end Insert_Sibling;

   procedure Replace_Root
     (S : in out State; Doc, Root : Node_Ref;
      Previous : out Node_Ref; Success : out Boolean)
   is
      Current : Node_Ref := Node (S, Doc).First_Child;
      Old_Root : Node_Ref := Null_Node;
      Remaining : Natural := Node_Count (S);
      Malformed : Boolean := False;
   begin
      Previous := Null_Node;
      Success := False;
      if Node (S, Doc).Kind /= Document_Node
        or else Node (S, Root).Kind /= Element_Node
      then
         return;
      end if;
      while Current /= Null_Node and then Remaining > 0 loop
         pragma Loop_Variant (Decreases => Remaining);
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant
           (Old_Root = Null_Node
            or else (Old_Root in 1 .. Node_Ref (Node_Count (S))
              and then Node (S, Old_Root).Parent = Doc));
         if Current > Node_Ref (Node_Count (S))
           or else Node (S, Current).State /= Live
           or else Node (S, Current).Parent /= Doc
         then
            Malformed := True;
            exit;
         end if;
         if Node (S, Current).Kind = Element_Node then
            if Old_Root /= Null_Node then
               Malformed := True;
               exit;
            end if;
            Old_Root := Current;
         end if;
         Current := Node (S, Current).Next;
         Remaining := Remaining - 1;
      end loop;
      if Current /= Null_Node then
         Malformed := True;
      end if;
      if Malformed then
         return;
      end if;
      if Root = Old_Root then
         pragma Assert (Node (S, Root).Parent = Doc);
         Previous := Root;
         Success := True;
         return;
      end if;
      if Node (S, Root).Parent = Doc then
         return;
      end if;
      pragma Assert (Node (S, Root).Parent /= Doc);
      if Old_Root /= Null_Node then
         pragma Assert (Node (S, Old_Root).Parent = Doc);
         pragma Assert
           (Node_Siblings_Valid (S.Graph, Positive (Root)));
         pragma Assert
           (Node_Siblings_Valid (S.Graph, Positive (Old_Root)));
         pragma Assert (Node (S, Root).Previous /= Old_Root);
         pragma Assert (Node (S, Root).Next /= Old_Root);
         pragma Assert
           (Unlinked_View (S, Root, Old_Root).Previous =
              Node (S, Old_Root).Previous
            and then Unlinked_View (S, Root, Old_Root).Next =
              Node (S, Old_Root).Next
            and then Unlinked_View (S, Root, Old_Root).Sibling_Order =
              Node (S, Old_Root).Sibling_Order);
      end if;
      Attach (S, Doc, Root, False, Success, Old_Root);
      if Success then
         pragma Assert (Node (S, Root).Parent = Doc);
         Previous := Old_Root;
      end if;
   end Replace_Root;

   procedure Attach_Property
     (S : in out State; Element, Attribute : Node_Ref; Success : out Boolean)
   is
   begin
      Attach (S, Element, Attribute, True, Success);
   end Attach_Property;

   procedure Merge_Text
     (S : in out State; Target, Source : Node_Ref;
      Content : System.Address; Length : Natural; Content_Owner : Owner_Ref;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Original_Namespaces : constant Namespace_View_Array :=
        Snapshot_Namespaces (S) with Ghost;
      T : constant Node_View := Node (S, Target);
      C : constant Node_View := Node (S, Source);
      Proposed : constant Node_View := Projected_View
        (T, T.Name, T.Name_Length, Content, Length, T.Document, T.Namespace,
         T.Ns_Pin, T.Doc_Pin, Content_Owner, T.Name_Pin);
      Prepared : Boolean;
   begin
      Success := False;
      pragma Assert (Snapshot_Namespaces (Before) = Original_Namespaces);
      if Target = Source or else T.Kind /= Text_Node or else C.Kind /= Text_Node
        or else T.First_Child /= Null_Node or else T.First_Prop /= Null_Node
        or else C.First_Child /= Null_Node or else C.First_Prop /= Null_Node
        or else T.First_Namespace /= Null_Namespace
        or else C.First_Namespace /= Null_Namespace
        or else (C.Document /= Null_Node and then C.Document /= T.Document)
        or else Content = System.Null_Address
        or else Content_Owner = Null_Owner
        or else Content_Owner > Owner_Ref (Owner_Count (S))
        or else Owner (S, Content_Owner).State /= Live
        or else Owner (S, Content_Owner).Reservations = 0
        or else C.Content_Length > Natural'Last - T.Content_Length
        or else Length /= T.Content_Length + C.Content_Length
        or else Length = Natural'Last
        or else not Projection_Allowed (S, Target, Proposed)
      then
         return;
      end if;
      Prepare_Subtree (S, Source, 0, Prepared);
      pragma Assert (Prepared);
      Same_Graph_Snapshots (Before, S);
      pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
      if S.Marks (Positive (Target)) then
         return;
      end if;

      declare
         Projection_Namespaces : constant Namespace_View_Array :=
           Snapshot_Namespaces (S) with Ghost;
      begin
         Set_Node_Projection_Internal
           (S, Target, T.Name, T.Name_Length, Content, Length,
            T.Document, T.Namespace, T.Ns_Pin, T.Doc_Pin, Content_Owner,
            T.Name_Pin, Success);
         pragma Assert (Success);
         Compose_Namespace_Snapshots
           (Original_Namespaces, Projection_Namespaces,
            Snapshot_Namespaces (S));
         pragma Assert
           (for all I in 1 .. S.Graph.Node_Used =>
             S.Marks (I) = (Node_Ref (I) = Source));
         Marked_Text_Declarations_Clear (S, Source);
         pragma Assert (Snapshot_Namespaces (S) = Projection_Namespaces);
         Free_Marked_Subtree (S, Source);
         pragma Assert (Snapshot_Namespaces (S) = Projection_Namespaces);
         Compose_Namespace_Snapshots
           (Original_Namespaces, Projection_Namespaces,
            Snapshot_Namespaces (S));
      end;
      pragma Assert (Snapshot_Namespaces (S) = Original_Namespaces);
   end Merge_Text;

end XML3_DOM;
