with XML3_DOM_Allocation;

package body XML3_DOM with SPARK_Mode is

   procedure Release_Pin (Item : in out Owner_View)
   with Global => null,
     Pre => Item.State = Live and then not Item.Release_Emitted
       and then Item.References > Item.Reservations,
     Post => Item =
       (Item'Old with delta References => Item.References'Old - 1,
          State => (if Item.References'Old = 1 then Releasing else Live))
       and then (if Item.State = Releasing then
         Item.References = 0 and then Item.Reservations = 0);

   procedure Release_Pin (Item : in out Owner_View) is
   begin
      Item.References := Item.References - 1;
      if Item.References = 0 then
         Item.State := Releasing;
      end if;
   end Release_Pin;

   procedure Same_Holder_Count
     (Left, Right : Node_View_Array; B : Owner_Ref; N : Natural)
   with Ghost, Global => null,
     Pre => Left'First = 1 and then Right'First = 1
       and then N <= Left'Last and then N <= Right'Last
       and then (for all I in 1 .. N =>
         Holds (Left (I), B) = Holds (Right (I), B)),
     Post => Holder_Count (Left, B, N) = Holder_Count (Right, B, N),
     Subprogram_Variant => (Decreases => N);

   procedure Same_Holder_Count
     (Left, Right : Node_View_Array; B : Owner_Ref; N : Natural)
   is
   begin
      if N > 0 then
         Same_Holder_Count (Left, Right, B, N - 1);
      end if;
   end Same_Holder_Count;

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

   procedure Same_Ancestor
     (Left, Right : Node_View_Array; Used : Natural; Candidate, N : Node_Ref)
   is
      P : constant Node_Ref := Left (Positive (N)).Parent;
   begin
      if Left (Positive (N)).State = Live and then Candidate /= N
        and then P in 1 .. Node_Ref (Used)
        and then Left (Positive (P)).State = Live
        and then Left (Positive (P)).Tree_Rank < Left (Positive (N)).Tree_Rank
      then
         Same_Ancestor (Left, Right, Used, Candidate, P);
      end if;
   end Same_Ancestor;

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

   procedure Changed_Holder_Count
     (Left, Right : Node_View_Array;
      B : Owner_Ref;
      N : Natural;
      Changed : Positive)
   is
   begin
      if N > Changed then
         Changed_Holder_Count (Left, Right, B, N - 1, Changed);
         pragma Assert (Holds (Left (N), B) = Holds (Right (N), B));
      elsif N > 0 then
         Same_Holder_Count (Left, Right, B, N - 1);
      end if;
   end Changed_Holder_Count;

   function Positive_Holder_Count_Witness
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural; I : Positive)
      return Boolean
   with Ghost, Global => null,
     Pre => Nodes'First = 1 and then N <= Nodes'Last and then I <= N
       and then Holds (Nodes (I), B),
     Post => Positive_Holder_Count_Witness'Result
       and then Holder_Count (Nodes, B, N) >= 1,
     Subprogram_Variant => (Decreases => N);

   function Positive_Holder_Count_Witness
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural; I : Positive)
      return Boolean
   is
   begin
      if I = N then
         return True;
      end if;
      return Positive_Holder_Count_Witness (Nodes, B, N - 1, I);
   end Positive_Holder_Count_Witness;

   procedure Zero_Holder_Count
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural)
   with Ghost, Global => null,
     Pre => Nodes'First = 1 and then N <= Nodes'Last
       and then (for all I in 1 .. N => not Holds (Nodes (I), B)),
     Post => Holder_Count (Nodes, B, N) = 0,
     Subprogram_Variant => (Decreases => N);

   procedure Zero_Holder_Count
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural)
   is
   begin
      if N > 0 then
         Zero_Holder_Count (Nodes, B, N - 1);
      end if;
   end Zero_Holder_Count;

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

   procedure Preserve_Pin_Equation (Before, After : State) is
   begin
      for B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (Before)) loop
         Same_Holder_Count
           (Snapshot_Nodes (Before), Snapshot_Nodes (After), B,
            Node_Count (Before));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             Holder_Count (Snapshot_Nodes (Before), K, Node_Count (Before)) =
             Holder_Count (Snapshot_Nodes (After), K, Node_Count (After)));
      end loop;
   end Preserve_Pin_Equation;

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
       and then (for all I in 1 .. Before.Node_Used =>
         Namespace_Parent_Preserved (Before.Nodes (I), After.Nodes (I)))
       and then (for all I in 1 .. Before.Owner_Used =>
         (if Before.Owners (I).State in Live | Releasing then
           After.Owners (I).State in Live | Releasing)),
     Post => (for all I in 1 .. After.Ns_Used => Namespace_Links_Valid (After, I));

   procedure Preserve_Namespace_Links (Before, After : Graph_State) is
   begin
      for I in 1 .. Before.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (Before, I));
         if Before.Namespaces (I).State = Live
           and then Before.Namespaces (I).Parent /= 0
         then
            pragma Assert (Namespace_Parent_Preserved
              (Before.Nodes (Positive (Before.Namespaces (I).Parent)),
               After.Nodes (Positive (Before.Namespaces (I).Parent))));
         end if;
         pragma Assert (Namespace_Links_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (After, J));
      end loop;
   end Preserve_Namespace_Links;

   function Ancestor (S : State; Candidate, N : Node_Ref) return Boolean is
   begin
      if Candidate = N then
         return True;
      end if;
      if Node (S, N).Parent = Null_Node then
         return False;
      end if;
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (N)));
      return Ancestor (S, Candidate, Node (S, N).Parent);
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

   procedure Copied_Links_Lemma (Before, After : Graph_State) is
   begin
      for I in 1 .. Before.Node_Used loop
         pragma Assert (Node_Links_Valid (Before, I));
         pragma Assert (Node_Links_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (After, J));
      end loop;
   end Copied_Links_Lemma;

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
         return;
      end if;
      if Current.Capacity <= Positive'Last / 2 then
         New_Capacity := Positive'Max (Needed, Current.Capacity * 2);
      end if;
      Fresh := XML3_DOM_Allocation.Allocate_State (New_Capacity);
      if Fresh = null then
         Success := False;
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
         Content_Pin => Null_Owner, Tree_Rank => 0);
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

   procedure Take_Release
     (S : in out State; B : out Owner_Ref; Address : out System.Address)
   is
      Before : constant State := S with Ghost;
   begin
      while S.Effects.Released_Through < S.Graph.Owner_Used loop
         pragma Loop_Variant (Increases => S.Effects.Released_Through);
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant (not S.Effects.Dirty);
         pragma Loop_Invariant (Facades_Present (S) = Facades_Present (Before));
         pragma Loop_Invariant (Same_Graph (S, Before));
         pragma Loop_Invariant
           (S.Effects.Released_Through >= Before.Effects.Released_Through);
         S.Effects.Released_Through := S.Effects.Released_Through + 1;
         B := Owner_Ref (S.Effects.Released_Through);
         if S.Graph.Owners (Positive (B)).State = Releasing then
            Address := S.Graph.Owners (Positive (B)).Address;
            S.Graph.Owners (Positive (B)).Release_Emitted := True;
            S.Effects.Active_Release := B;
            S.Effects.Phase := Release_Pending;
            for I in 1 .. S.Graph.Node_Used loop
               pragma Assert (Node_Links_Valid (Before.Graph, I));
               pragma Assert (Node_Links_Valid (S.Graph, I));
               pragma Loop_Invariant
                 (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
            end loop;
            Preserve_Namespace_Links (Before.Graph, S.Graph);
            return;
         end if;
      end loop;
      B := Null_Owner;
      Address := System.Null_Address;
   end Take_Release;

   procedure Acknowledge_Release (S : in out State; B : Owner_Ref) is
      Before : constant State := S with Ghost;
   begin
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Pins_Valid (Before.Graph, I));
         pragma Assert (if S.Graph.Nodes (I).State = Live then
           not Holds (S.Graph.Nodes (I), B));
         if S.Graph.Nodes (I).Owner = B then
            pragma Assert (S.Graph.Nodes (I).State /= Live);
            S.Graph.Nodes (I) := (others => <>);
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Node_Used =>
             (Before.Graph.Nodes (J).State = Live) =
               (S.Graph.Nodes (J).State = Live)
             and then (if Before.Graph.Nodes (J).State = Live then
               S.Graph.Nodes (J) = Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Node_Used =>
             S.Graph.Nodes (J) =
               (if J <= I and then Before.Graph.Nodes (J).Owner = B
                then (others => <>) else Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (if Facades_Present (Before) then Facades_Present (S));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         if S.Graph.Namespaces (I).Owner = B then
            S.Graph.Namespaces (I) := (others => <>);
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Ns_Used =>
             S.Graph.Namespaces (J) =
               (if J <= I and then Before.Graph.Namespaces (J).Owner = B
                then (others => <>) else Before.Graph.Namespaces (J)));
         pragma Loop_Invariant
           (if Facades_Present (Before) then Facades_Present (S));
      end loop;
      S.Graph.Owners (Positive (B)) := (others => <>);
      S.Effects.Active_Release := Null_Owner;
      S.Effects.Phase := Editing;
      Preserve_Pin_Equation (Before, S);
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert (Node_Pins_Valid (S.Graph, I));
         pragma Assert (Node_Siblings_Valid (S.Graph, I));
         pragma Assert (Node_Children_Valid (S.Graph, I));
         pragma Assert (Node_Namespaces_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (Before.Graph, I));
         pragma Assert (Namespace_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (S.Graph, J));
      end loop;
   end Acknowledge_Release;

   procedure Register_Namespace
     (S : in out State;
      Facade : System.Address;
      Href : System.Address;
      Href_Length : Natural;
      Prefix : System.Address;
      Prefix_Length : Natural;
      Own : Owner_Ref;
      Ns : out Namespace_Ref;
      Success : out Boolean)
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
         Sibling_Order => 0, Attached => False);
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
       and then Before.Namespaces (Positive (Ns)).Owner =
         Before.Nodes (Positive (Element)).Owner
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
        or else Ns_Item.Owner /= Parent_Item.Owner
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

   procedure Set_Node_Projection_Internal
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
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Old_Item : constant Node_View := S.Graph.Nodes (Positive (N));
      New_Item : constant Node_View := Projected_View
        (Old_Item, Name, Name_Length, Content, Content_Length,
         Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin);
   begin
      if not Projection_Pins_Allowed (S, N, New_Item) then
         Success := False;
         return;
      end if;
      pragma Assert (Projection_Pins_Allowed (Before, N, New_Item));
      pragma Assert (Node_Pins_Valid (S.Graph, Positive (N)));
      S.Effects.Dirty := True;
      S.Graph.Nodes (Positive (N)) := New_Item;
      for B in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) loop
         Changed_Holder_Count
           (Snapshot_Nodes (Before), Snapshot_Nodes (S), B,
            S.Graph.Node_Used, Positive (N));
         if not Holds (Old_Item, B) and then Holds (New_Item, B) then
            S.Graph.Owners (Positive (B)).References :=
              S.Graph.Owners (Positive (B)).References + 1;
         elsif Holds (Old_Item, B) and then not Holds (New_Item, B) then
            pragma Assert (Positive_Holder_Count_Witness
              (Snapshot_Nodes (Before), B, S.Graph.Node_Used, Positive (N)));
            pragma Assert (S.Graph.Owners (Positive (B)).References >
              S.Graph.Owners (Positive (B)).Reservations);
            Release_Pin (S.Graph.Owners (Positive (B)));
         end if;
         pragma Loop_Invariant (S.Graph.Node_Used = Before.Graph.Node_Used);
         pragma Loop_Invariant (S.Graph.Owner_Used = Before.Graph.Owner_Used);
         pragma Loop_Invariant (S.Graph.Ns_Used = Before.Graph.Ns_Used);
         pragma Loop_Invariant
           (S.Effects = (Before.Effects with delta Dirty => True));
         pragma Loop_Invariant
           (for all K in 1 .. S.Graph.Owner_Used =>
             not S.Graph.Owners (K).Release_Emitted
             and then (if S.Graph.Owners (K).State = Releasing then
               S.Graph.Owners (K).References = 0
               and then S.Graph.Owners (K).Reservations = 0));
         pragma Loop_Invariant (Effects_Valid (S));
         pragma Loop_Invariant
           (for all J in 1 .. S.Capacity =>
             S.Graph.Nodes (J) =
               (if J = Positive (N) then New_Item else Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (for all J in 1 .. S.Capacity =>
             S.Graph.Namespaces (J) = Before.Graph.Namespaces (J));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) =>
             (if K > B then
               S.Graph.Owners (Positive (K)) = Before.Graph.Owners (Positive (K))));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             (if Holds (Old_Item, K) = Holds (New_Item, K) then
                S.Graph.Owners (Positive (K)) = Before.Graph.Owners (Positive (K))
              else S.Graph.Owners (Positive (K)).Address =
                Before.Graph.Owners (Positive (K)).Address
                and then S.Graph.Owners (Positive (K)).Reservations =
                  Before.Graph.Owners (Positive (K)).Reservations
                and then (if Holds (New_Item, K) then
                  S.Graph.Owners (Positive (K)).State = Live
                  and then S.Graph.Owners (Positive (K)).References =
                    Before.Graph.Owners (Positive (K)).References + 1
                  else S.Graph.Owners (Positive (K)).References =
                    Before.Graph.Owners (Positive (K)).References - 1
                  and then S.Graph.Owners (Positive (K)).State =
                    (if S.Graph.Owners (Positive (K)).References > 0
                     then Live else Releasing))));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             (Before.Graph.Owners (Positive (K)).State /= Live
              or else
                (S.Graph.Owners (Positive (K)).Reservations
                   <= S.Graph.Owners (Positive (K)).References
                 and then S.Graph.Owners (Positive (K)).References
                   - S.Graph.Owners (Positive (K)).Reservations =
                 Holder_Count (Snapshot_Nodes (S), K, S.Graph.Node_Used))));
      end loop;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         for K in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) loop
            if Holds (S.Graph.Nodes (I), K) then
               pragma Assert (Before.Graph.Owners (Positive (K)).State = Live);
               pragma Assert (Positive_Holder_Count_Witness
                 (Snapshot_Nodes (S), K, S.Graph.Node_Used, I));
               pragma Assert (S.Graph.Owners (Positive (K)).References > 0);
               pragma Assert (S.Graph.Owners (Positive (K)).State = Live);
            end if;
            pragma Loop_Invariant
              (for all B in Owner_Ref range 1 .. K =>
                (if Holds (S.Graph.Nodes (I), B) then Live_Owner (S.Graph, B)));
         end loop;
         pragma Assert (Node_Pins_Valid (S.Graph, I));
         pragma Assert (Node_Siblings_Valid (S.Graph, I));
         pragma Assert (Node_Children_Valid (S.Graph, I));
         pragma Assert (Node_Namespaces_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      Success := True;
      Preserve_Namespace_Links (Before.Graph, S.Graph);
      pragma Assert (Valid (S) and then Can_Edit (S));
      pragma Assert (Projection_Pins_Allowed (Before, N, New_Item));
      pragma Assert (Snapshot_Marks (S) = Snapshot_Marks (Before));
      pragma Assert (Release_Cursor (S) = Release_Cursor (Before));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          S.Graph.Nodes (I) =
            (if I = Positive (N) then New_Item else Before.Graph.Nodes (I)));
      pragma Assert
        (for all I in 1 .. S.Graph.Ns_Used =>
          S.Graph.Namespaces (I) = Before.Graph.Namespaces (I));
      pragma Assert
        (for all B in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) =>
          (if Holds (Old_Item, B) = Holds (New_Item, B) then
            S.Graph.Owners (Positive (B)) = Before.Graph.Owners (Positive (B))
           else S.Graph.Owners (Positive (B)).Address =
             Before.Graph.Owners (Positive (B)).Address
             and then S.Graph.Owners (Positive (B)).Reservations =
               Before.Graph.Owners (Positive (B)).Reservations
             and then not S.Graph.Owners (Positive (B)).Release_Emitted
             and then S.Graph.Owners (Positive (B)).State =
               (if S.Graph.Owners (Positive (B)).References = 0 then Releasing else Live)));
      pragma Assert
        (for all B in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) =>
          Long_Long_Integer (S.Graph.Owners (Positive (B)).References)
            + Boolean'Pos (Holds (Old_Item, B)) =
              Long_Long_Integer (Before.Graph.Owners (Positive (B)).References)
                + Boolean'Pos (Holds (New_Item, B)));
   end Set_Node_Projection_Internal;

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
      Success : out Boolean)
   is
      Proposed : constant Node_View := Projected_View
        (Node (S, N), Name, Name_Length, Content, Content_Length,
         Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin);
   begin
      if not Projection_Allowed (S, N, Proposed) then
         Success := False;
         return;
      end if;
      Set_Node_Projection_Internal
        (S, N, Name, Name_Length, Content, Content_Length,
         Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin, Success);
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
   end Unlink;

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
             and then After.Graph.Nodes (I).Document =
               Before.Graph.Nodes (I).Document
             and then After.Graph.Nodes (I).Doc_Pin =
               Before.Graph.Nodes (I).Doc_Pin
             and then Same_Pins
               (Before.Graph.Nodes (I), After.Graph.Nodes (I)));

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
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S)) =>
             Node (S, I).State = Node (S'Old, I).State
             and then Node (S, I).Document = Node (S'Old, I).Document
             and then Node (S, I).Doc_Pin = Node (S'Old, I).Doc_Pin)
         and then Node (S, New_Child).Parent = Parent
         and then Node (S, New_Child).State = Live
         and then Node (S, Old_Child) =
           Unlinked_View (S'Old, Old_Child, Old_Child)
         and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I) =
             Replaced_View (S'Old, Parent, New_Child, Old_Child, I)));

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

   procedure Leaf_Has_No_Child (S : State; Root, N : Node_Ref) is
   begin
      pragma Assert (Node_Siblings_Valid (S.Graph, Positive (N)));
      if Node (S, N).Parent = Root
        and then Node (S, N).Previous /= Null_Node
      then
         Leaf_Has_No_Child (S, Root, Node (S, N).Previous);
      end if;
   end Leaf_Has_No_Child;

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

   procedure Prepare_Subtree
     (S : in out State; Root : Node_Ref; Lift : Natural;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live,
     Post => S.Effects = S.Effects'Old and then Valid (S)
       and then S.Graph = S.Graph'Old
       and then S.Graph.Nodes = S.Graph.Nodes'Old
       and then (if Lift = 0 then Success)
       and then S.Graph.Namespaces = S.Graph.Namespaces'Old
       and then S.Graph.Owners = S.Graph.Owners'Old
       and then S.Graph.Node_Used = S.Graph.Node_Used'Old
       and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
       and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
       and then (if Success then S.Marks (Positive (Root))
         and then (for all I in 1 .. S.Graph.Node_Used =>
           S.Marks (I) = (S.Graph.Nodes (I).State = Live and then
             Ancestor (S, Root, Node_Ref (I)))
           and then (if S.Marks (I) then
             S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Lift)
           and then (if S.Graph.Nodes (I).State = Live
             and then S.Graph.Nodes (I).Parent /= 0 and then Node_Ref (I) /= Root
             then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
                and then S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent)))));

   procedure Prepare_Subtree
     (S : in out State; Root : Node_Ref; Lift : Natural;
      Success : out Boolean)
   is
   begin
      for I in 1 .. S.Graph.Node_Used loop
         S.Marks (I) := S.Graph.Nodes (I).State = Live
           and then Is_Ancestor (S, Root, Node_Ref (I));
         if S.Marks (I) and then S.Graph.Nodes (I).Tree_Rank > Natural'Last - Lift then
            Success := False;
            return;
         end if;
         pragma Loop_Invariant (Valid (S));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             S.Marks (J) = (S.Graph.Nodes (J).State = Live and then
               Ancestor (S, Root, Node_Ref (J)))
             and then (if S.Marks (J) then
               S.Graph.Nodes (J).Tree_Rank <= Natural'Last - Lift));
      end loop;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Siblings_Valid (S.Graph, I));
         pragma Assert
           (if S.Graph.Nodes (I).State = Live and then S.Graph.Nodes (I).Parent /= 0
             and then Node_Ref (I) /= Root
            then Ancestor (S, Root, Node_Ref (I)) =
              Ancestor (S, Root, S.Graph.Nodes (I).Parent));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             (if S.Graph.Nodes (J).State = Live and then S.Graph.Nodes (J).Parent /= 0
               and then Node_Ref (J) /= Root
              then S.Graph.Nodes (J).Parent <= Node_Ref (S.Graph.Node_Used)
                and then S.Marks (J) = S.Marks (Positive (S.Graph.Nodes (J).Parent))));
      end loop;
      Success := True;
   end Prepare_Subtree;

   procedure Lift_Marked (S : in out State; Lift : Natural)
   with Global => null,
     Pre => Valid (S)
       and then (for all I in 1 .. S.Graph.Node_Used =>
         (if S.Marks (I) then S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Lift)
         and then (if S.Graph.Nodes (I).State = Live and then S.Graph.Nodes (I).Parent /= 0
           then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
             and then S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent)))),
     Post => S.Effects = S.Effects'Old and then Valid (S) and then S.Marks = S.Marks'Old
       and then S.Graph.Node_Used = S.Graph.Node_Used'Old
       and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
       and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
       and then S.Graph.Owners = S.Graph.Owners'Old
       and then S.Graph.Namespaces = S.Graph.Namespaces'Old
       and then (for all I in 1 .. S.Graph.Node_Used =>
         S.Graph.Nodes (I) = (S.Graph.Nodes'Old (I) with delta Tree_Rank =>
           S.Graph.Nodes'Old (I).Tree_Rank + (if S.Marks (I) then Lift else 0)));

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
      Preserve_Namespace_Links (Before.Graph, S.Graph);
   end Lift_Marked;

   procedure Set_Marked_Document
     (S : in out State; Target_Doc : Node_Ref; Target_B : Owner_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Target_Doc in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Target_Doc).Kind = Document_Node
       and then Node (S, Target_Doc).State in Live | Tombstone
       and then Target_B in 1 .. Owner_Ref (Owner_Count (S))
       and then Node (S, Target_Doc).Owner = Target_B
       and then Owner (S, Target_B).State = Live
       and then Owner (S, Target_B).References <=
         Natural'Last - Node_Count (S)
       and then (for all I in 1 .. Node_Count (S) =>
         (if S.Marks (I) then
            Node (S, Node_Ref (I)).State = Live
              and then (Node (S, Node_Ref (I)).Document = Null_Node
                or else Node (S, Node_Ref (I)).Document = Target_Doc))),
     Post => (declare
       Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S)'Old;
       Original_Marks : constant Mark_Array := Snapshot_Marks (S)'Old;
     begin Valid (S) and then Can_Edit (S)
       and then S.Capacity = S.Capacity'Old
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then S.Marks = S.Marks'Old
       and then (for all I in 1 .. Node_Count (S) =>
         (if S.Marks (I) then
            S.Graph.Nodes (I).Document = Target_Doc
              and then S.Graph.Nodes (I).Doc_Pin = Target_B))
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           S.Graph.Nodes (Positive (I)) =
             (if Original_Marks (Positive (I)) then
                (Original_Nodes (Positive (I)) with delta
                   Document => Target_Doc, Doc_Pin => Target_B)
              else Original_Nodes (Positive (I)))));

   procedure Set_Marked_Document
     (S : in out State; Target_Doc : Node_Ref; Target_B : Owner_Ref)
   is
      Before : constant State := S with Ghost;
      Original_Target_References : constant Natural :=
        S.Graph.Owners (Positive (Target_B)).References with Ghost;
   begin
      for I in 0 .. S.Graph.Node_Used loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant
           (S.Capacity = Before.Capacity
            and then S.Graph.Node_Used = Before.Graph.Node_Used
            and then S.Graph.Ns_Used = Before.Graph.Ns_Used
            and then S.Graph.Owner_Used = Before.Graph.Owner_Used
            and then S.Marks = Before.Marks);
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
                  Item.Ns_Pin, Target_B, Item.Content_Pin);
               Iteration_Before : constant State := S with Ghost;
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
                  OK);
               pragma Assert (OK);
               pragma Assert
                 (for all J in 1 .. S.Graph.Node_Used =>
                    S.Graph.Nodes (J) =
                      (if J = Index then Proposed
                       else Iteration_Before.Graph.Nodes (J)));
            end;
         end if;
      end loop;
   end Set_Marked_Document;

   procedure Attach
     (S : in out State; Parent, Child : Node_Ref;
      Property : Boolean; Success : out Boolean;
      Replaced : Node_Ref := Null_Node)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (S.Graph.Node_Used)
       and then Child in 1 .. Node_Ref (S.Graph.Node_Used)
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live,
     Post => (declare
       Target_Doc : constant Node_Ref :=
         (if Node (S'Old, Parent).Kind = Document_Node
          then Parent else Node (S'Old, Parent).Document);
     begin (if not Success then Same_Graph (S, S'Old))
       and then Valid (S) and then Can_Edit (S)
         and then S.Capacity = S'Old.Capacity
         and then Node_Count (S) = Node_Count (S'Old)
         and then Namespace_Count (S) = Namespace_Count (S'Old)
         and then Owner_Count (S) = Owner_Count (S'Old)
         and then (if Success then Node (S, Child).Parent = Parent
           and then (if Replaced /= Null_Node then
             Replaced in 1 .. Node_Ref (Node_Count (S))
             and then Node (S, Replaced).State = Live
             and then Node (S, Replaced).Parent = Null_Node
             and then Node (S, Replaced).Previous = Null_Node
             and then Node (S, Replaced).Next = Null_Node
             and then Node (S, Child).Previous =
               Unlinked_View (S'Old, Child, Replaced).Previous
             and then Node (S, Child).Next =
               Unlinked_View (S'Old, Child, Replaced).Next
             and then Node (S, Child).Sibling_Order =
               Unlinked_View (S'Old, Child, Replaced).Sibling_Order)
         and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           (if Snapshot_Marks (S) (Positive (I)) then
              Node (S, I).Document = Target_Doc
              and then (Target_Doc = Null_Node
                or else Node (S, I).Doc_Pin =
                  Node (S'Old,
                    (if Node (S'Old, Parent).Kind = Document_Node
                     then Parent else Node (S'Old, Parent).Document)).Owner)))
       ));

   procedure Attach
     (S : in out State; Parent, Child : Node_Ref;
      Property : Boolean; Success : out Boolean;
      Replaced : Node_Ref := Null_Node)
   is
      Parent_Item : Node_View := S.Graph.Nodes (Positive (Parent));
      Child_Item : Node_View := S.Graph.Nodes (Positive (Child));
      Last : Node_Ref;
      Remaining : Natural := S.Capacity;
      Append_Order : Natural := 0;
      Rank_Lift : Natural := 0;
      Already_Attached : Boolean;
      Target_Doc : constant Node_Ref :=
        (if Parent_Item.Kind = Document_Node
         then Parent else Parent_Item.Document);
      Target_B : Owner_Ref := Null_Owner;
      Before : constant State := S with Ghost;
      Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S) with Ghost;
      Original_Target_References : Natural := 0 with Ghost;
      Detached : State (Before.Capacity) with Ghost;
   begin
      pragma Assert (Original_Nodes = Snapshot_Nodes (Before));
      pragma Assert (Node_Links_Valid (S.Graph, Positive (Parent)));
      pragma Assert (Node_Links_Valid (S.Graph, Positive (Child)));
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
            Success := False;
            pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
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
         Success := False;
         pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
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
         Success := False;
         pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
         return;
      end if;
      Last := (if Property then Parent_Item.Last_Prop else Parent_Item.Last_Child);
      Already_Attached := Replaced = Null_Node
        and then Child_Item.Parent = Parent and then Last = Child;
      if not Already_Attached then
      if Replaced = Null_Node and then Last /= 0
        and then S.Graph.Nodes (Positive (Last)).Sibling_Order = Natural'Last
      then
         Success := False;
         pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
         return;
      end if;
      Append_Order := (if Replaced /= Null_Node then
         S.Graph.Nodes (Positive (Replaced)).Sibling_Order
        elsif Last = 0 then 0
        else S.Graph.Nodes (Positive (Last)).Sibling_Order + 1);
      if Child_Item.Tree_Rank <= Parent_Item.Tree_Rank then
         if Parent_Item.Tree_Rank = Natural'Last then
            Success := False;
            pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
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
               Success := False;
               pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
               return;
            end if;
            if S.Graph.Nodes (Positive (Last)).Kind = Element_Node
              and then Last /= Child and then Last /= Replaced
            then
               Success := False;
               pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
               return;
            end if;
            Last := S.Graph.Nodes (Positive (Last)).Next;
            Remaining := Remaining - 1;
         end loop;
         if Last /= Null_Node then
            Success := False;
            pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
            return;
         end if;
      end if;
      pragma Assert (not Ancestor (S, Child, Parent));
      pragma Assert (not Ancestor_In_Nodes
        (Snapshot_Nodes (S), Node_Count (S), Child, Parent));
      Same_Ancestor
        (Snapshot_Nodes (S), Snapshot_Nodes (Before), Node_Count (S), Child, Parent);
      pragma Assert (not Ancestor_In_Nodes
        (Snapshot_Nodes (Before), Node_Count (Before), Child, Parent));
      pragma Assert (S.Graph.Nodes = Before.Graph.Nodes);
      end if;
      pragma Assert (S.Graph.Nodes = Before.Graph.Nodes);
      Prepare_Subtree (S, Child, Rank_Lift, Success);
      pragma Assert (S.Graph.Nodes'First = Before.Graph.Nodes'First);
      pragma Assert (S.Graph.Nodes'Last = Before.Graph.Nodes'Last);
      pragma Assert (for all I in S.Graph.Nodes'Range =>
        S.Graph.Nodes (I) = Before.Graph.Nodes (I));
      pragma Assert (S.Graph.Nodes = Before.Graph.Nodes);
      pragma Assert (Valid (S) and then Can_Edit (S));
      pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
      if not Success then
         pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
         return;
      end if;
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      if Target_Doc /= Null_Node then
         pragma Assert
           (S.Graph.Owners (Positive (Target_B)).State = Live);
      end if;
      for I in 0 .. S.Graph.Node_Used loop
         pragma Loop_Variant (Increases => I);
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
            return;
         end if;
      end loop;
      if Target_Doc /= Null_Node
        and then S.Graph.Owners (Positive (Target_B)).References >
          Natural'Last - S.Graph.Node_Used
      then
         Success := False;
         pragma Assert (Snapshot_Nodes (S) = Original_Nodes);
         return;
      end if;
      if Target_Doc /= Null_Node then
         Original_Target_References := S.Graph.Owners (Positive (Target_B)).References;
         pragma Assert
           (S.Graph.Owners (Positive (Target_B)).References <=
              Natural'Last - S.Graph.Node_Used);
      end if;
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then
             S.Graph.Nodes (I).Document = Null_Node
               or else S.Graph.Nodes (I).Document = Target_Doc));
      if not Already_Attached then
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then
             S.Graph.Nodes (I).Document = Null_Node
               or else S.Graph.Nodes (I).Document = Target_Doc));
      Same_Ancestor
        (Snapshot_Nodes (Before), Snapshot_Nodes (S), Node_Count (S), Child, Parent);
      pragma Assert (not Ancestor_In_Nodes
        (Snapshot_Nodes (S), Node_Count (S), Child, Parent));
      pragma Assert (not Ancestor (S, Child, Parent));
      pragma Assert (not S.Marks (Positive (Parent)));
      pragma Assert (S.Marks (Positive (Child)));
      pragma Assert (Node (S, Parent).Tree_Rank = Parent_Item.Tree_Rank);
      pragma Assert (Node (S, Child).Tree_Rank = Child_Item.Tree_Rank);
      S.Effects.Dirty := True;
      Unlink (S, Child);
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert
        (if Target_Doc /= Null_Node then
           Owner (S, Target_B).References = Original_Target_References);
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then
             S.Graph.Nodes (I).Document = Null_Node
               or else S.Graph.Nodes (I).Document = Target_Doc));
      if Target_Doc /= Null_Node then
         pragma Assert
           (S.Graph.Owners (Positive (Target_B)).State = Live);
      end if;
      pragma Assert (not S.Marks (Positive (Parent)));
      pragma Assert (S.Marks (Positive (Child)));
      pragma Assert (Node (S, Parent).Tree_Rank = Parent_Item.Tree_Rank);
      pragma Assert (Node (S, Child).Tree_Rank = Child_Item.Tree_Rank);
      Lift_Marked (S, Rank_Lift);
      pragma Assert (Node_Count (S) = Node_Count (Before));
      pragma Assert
        (if Target_Doc /= Null_Node then
           Owner (S, Target_B).References = Original_Target_References);
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then
             S.Graph.Nodes (I).Document = Null_Node
               or else S.Graph.Nodes (I).Document = Target_Doc));
      if Target_Doc /= Null_Node then
         pragma Assert
           (S.Graph.Owners (Positive (Target_B)).State = Live);
      end if;
      pragma Assert (Node (S, Parent).Tree_Rank = Parent_Item.Tree_Rank);
      pragma Assert
        (Node (S, Child).Tree_Rank = Child_Item.Tree_Rank + Rank_Lift);
      Detached := S;
      pragma Assert
        (S.Capacity = Detached.Capacity
         and then (for all I in 1 .. S.Capacity =>
           S.Marks (I) = Detached.Marks (I)));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
          (if S.Marks (I) then S.Graph.Nodes (I).State = Live));
      if Target_Doc /= Null_Node then
         pragma Assert
           (Detached.Graph.Owners (Positive (Target_B)).State = Live);
      end if;
      pragma Assert (Node (S, Parent).Tree_Rank < Node (S, Child).Tree_Rank);
      pragma Assert
        ((if Property then Node (S, Parent).Last_Prop
          else Node (S, Parent).Last_Child) =
         (if Property then Unlinked_View (Before, Child, Parent).Last_Prop
          else Unlinked_View (Before, Child, Parent).Last_Child));
      Parent_Item := S.Graph.Nodes (Positive (Parent));
      Child_Item := S.Graph.Nodes (Positive (Child));
      Last := (if Property then Parent_Item.Last_Prop else Parent_Item.Last_Child);
      if Replaced = Null_Node then
         pragma Assert (Property = (Child_Item.Kind = Attribute_Node));
         pragma Assert (Last /= Parent and then Last /= Child);
         Child_Item.Parent := Parent;
         Child_Item.Previous := Last;
         Child_Item.Next := Null_Node;
         Child_Item.Sibling_Order := Append_Order;
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
           S.Graph.Namespaces (I) = Detached.Graph.Namespaces (I));
         pragma Assert (for all I in 1 .. S.Graph.Owner_Used =>
           S.Graph.Owners (I) = Detached.Graph.Owners (I));
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
             Same_Pins (Node (S, I), Node (Detached, I)));
         pragma Assert (Pins_In_Range (S));
         Append_Lemma (Detached, S, Parent, Child, Append_Order);
         Preserve_Pin_Equation (Detached, S);
         Preserve_Namespace_Links (Detached.Graph, S.Graph);
      else
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
         Preserve_Pin_Equation (Detached, S);
         Preserve_Namespace_Links (Detached.Graph, S.Graph);
      end if;
      else
         Detached := S;
      end if;
      pragma Assert (Node (S, Child).Parent = Parent);
      pragma Assert (Valid (S) and then Can_Edit (S));
      pragma Assert
        (S.Capacity = Detached.Capacity
         and then (for all I in 1 .. S.Capacity =>
           S.Marks (I) = Detached.Marks (I)));
      if Target_Doc /= Null_Node then
         pragma Assert (Target_Doc <= Node_Ref (Node_Count (S)));
         pragma Assert (Node (S, Target_Doc).Kind = Document_Node);
         pragma Assert (Node (S, Target_Doc).State in Live | Tombstone);
         pragma Assert (Node (S, Target_Doc).Owner = Target_B);
         pragma Assert (Target_B <= Owner_Ref (Owner_Count (S)));
         pragma Assert
           (S.Graph.Owners (Positive (Target_B)) =
              Detached.Graph.Owners (Positive (Target_B)));
         pragma Assert
           (Detached.Graph.Owners (Positive (Target_B)).References <=
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
      pragma Assert (Node (S, Child).Parent = Parent);
      Success := True;
      pragma Assert (Valid (S));
   end Attach;

   procedure Attach_Child
     (S : in out State; Parent, Child : Node_Ref; Success : out Boolean)
   is
   begin
      Attach (S, Parent, Child, False, Success);
   end Attach_Child;

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

   function Retired_View (Item : Node_View) return Node_View is
     ((Item with delta State => Tombstone,
       Parent => 0, First_Child => 0, Last_Child => 0,
       Previous => 0, Next => 0, First_Prop => 0, Last_Prop => 0,
       Document => 0, Namespace => 0, Ns_Pin => 0, Doc_Pin => 0,
       Content_Pin => 0, Content => System.Null_Address, Content_Length => 0));

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
       and then (for all I in 1 .. S.Graph.Node_Used => Node_Pins_Valid (S.Graph, I));

   procedure Retire_Node (S : in out State; N : Node_Ref) is
      Before : constant State := S with Ghost;
      Item : constant Node_View := S.Graph.Nodes (Positive (N));
   begin
      pragma Assert (Node_Pins_Valid (Before.Graph, Positive (N)));
      S.Graph.Nodes (Positive (N)) := Retired_View (Item);
      for B in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) loop
         Changed_Holder_Count
           (Snapshot_Nodes (Before), Snapshot_Nodes (S), B,
            S.Graph.Node_Used, Positive (N));
         if Holds (Item, B) then
            pragma Assert (Live_Owner (Before.Graph, B));
            pragma Assert (Positive_Holder_Count_Witness
              (Snapshot_Nodes (Before), B, S.Graph.Node_Used, Positive (N)));
            pragma Assert (S.Graph.Owners (Positive (B)).References >
              S.Graph.Owners (Positive (B)).Reservations);
            Release_Pin (S.Graph.Owners (Positive (B)));
         end if;
         pragma Loop_Invariant (Effects_Valid (S));
         pragma Loop_Invariant
           (for all J in 1 .. S.Capacity =>
             S.Graph.Nodes (J) =
               (if J = Positive (N) then Retired_View (Item)
                else Before.Graph.Nodes (J)));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) =>
             (if K > B then S.Graph.Owners (Positive (K)) = Before.Graph.Owners (Positive (K))));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             (if not Holds (Item, K) then
                S.Graph.Owners (Positive (K)) = Before.Graph.Owners (Positive (K))
              else S.Graph.Owners (Positive (K)).Reservations =
                Before.Graph.Owners (Positive (K)).Reservations
                and then S.Graph.Owners (Positive (K)).Address =
                  Before.Graph.Owners (Positive (K)).Address
                and then S.Graph.Owners (Positive (K)).References =
                  Before.Graph.Owners (Positive (K)).References - 1
                and then S.Graph.Owners (Positive (K)).State =
                  (if S.Graph.Owners (Positive (K)).References > 0
                   then Live else Releasing)));
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             ((Before.Graph.Owners (Positive (K)).State /= Live
               and then S.Graph.Owners (Positive (K)).State /= Live) or else
               (S.Graph.Owners (Positive (K)).Reservations <=
                  S.Graph.Owners (Positive (K)).References
                and then S.Graph.Owners (Positive (K)).References -
                  S.Graph.Owners (Positive (K)).Reservations =
                  Holder_Count (Snapshot_Nodes (S), K, S.Graph.Node_Used))));
      end loop;
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Pins_Valid (Before.Graph, I));
         for K in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) loop
            if Holds (S.Graph.Nodes (I), K) then
               pragma Assert (Before.Graph.Owners (Positive (K)).State = Live);
               pragma Assert (Positive_Holder_Count_Witness
                 (Snapshot_Nodes (S), K, S.Graph.Node_Used, I));
               pragma Assert (S.Graph.Owners (Positive (K)).References > 0);
               pragma Assert (S.Graph.Owners (Positive (K)).State = Live);
            end if;
            pragma Loop_Invariant
              (for all B in Owner_Ref range 1 .. K =>
                (if Holds (S.Graph.Nodes (I), B) then Live_Owner (S.Graph, B)));
         end loop;
         pragma Assert (Node_Pins_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Pins_Valid (S.Graph, J));
      end loop;
   end Retire_Node;

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

   procedure Retired_Links_Lemma
     (Before, After : Graph_State; Marks : Mark_Array)
   is
   begin
      for I in 1 .. Before.Node_Used loop
         pragma Assert (Node_Links_Valid (Before, I));
         if After.Nodes (I).State = Live then
            pragma Assert (not Marks (I));
            if Before.Nodes (I).First_Child /= 0 then
               pragma Assert
                 (not Marks (Positive (Before.Nodes (I).First_Child)));
            end if;
            if Before.Nodes (I).Last_Child /= 0 then
               pragma Assert
                 (not Marks (Positive (Before.Nodes (I).Last_Child)));
            end if;
            if Before.Nodes (I).First_Prop /= 0 then
               pragma Assert
                 (not Marks (Positive (Before.Nodes (I).First_Prop)));
            end if;
            if Before.Nodes (I).Last_Prop /= 0 then
               pragma Assert
                 (not Marks (Positive (Before.Nodes (I).Last_Prop)));
            end if;
         end if;
         pragma Assert (Node_Siblings_Valid (After, I));
         pragma Assert (Node_Children_Valid (After, I));
         pragma Assert (Node_Namespaces_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (After, J));
      end loop;
   end Retired_Links_Lemma;

   procedure Free_Marked_Subtree (S : in out State; Root : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live
       and then S.Marks (Positive (Root))
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
       and then Same_Marks (S, S'Old)
       and then Node (S, Root).State = Tombstone
       and then Projection_Required (S)
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (if not S.Marks (Positive (I)) then
           Node (S, I) = Unlinked_View (S'Old, Root, I)))
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

   procedure Free_Marked_Subtree (S : in out State; Root : Node_Ref) is
      Initial : constant State := S with Ghost;
   begin
      Unlink (S, Root);
      S.Effects.Dirty := True;
      declare
         Before : constant State := S with Ghost;
      begin
         pragma Assert
           (if Facades_Present (Initial) then Facades_Present (S));
         for I in 1 .. S.Graph.Node_Used loop
            if S.Marks (I) then
               Retire_Node (S, Node_Ref (I));
            end if;
            pragma Loop_Invariant (Well_Sized (S) and then Pins_In_Range (S));
            pragma Loop_Invariant (Pin_Equation (S));
            pragma Loop_Invariant (Effects_Valid (S));
            pragma Loop_Invariant (S.Effects = Before.Effects);
            pragma Loop_Invariant
              (if Facades_Present (Before) then Facades_Present (S));
            pragma Loop_Invariant
              (for all J in 1 .. S.Graph.Owner_Used =>
                Owner (S, Owner_Ref (J)).Reservations =
                  Owner (Before, Owner_Ref (J)).Reservations
                and then (if Owner (Before, Owner_Ref (J)).State = Live
                  and then Owner (Before, Owner_Ref (J)).Reservations > 0 then
                  Owner (S, Owner_Ref (J)).State = Live));
            pragma Loop_Invariant
              (for all J in 1 .. S.Graph.Owner_Used =>
                (if Before.Graph.Owners (J).State in Live | Releasing then
                  S.Graph.Owners (J).State in Live | Releasing));
            pragma Loop_Invariant (S.Graph.Node_Used = Before.Graph.Node_Used);
            pragma Loop_Invariant (S.Graph.Ns_Used = Before.Graph.Ns_Used);
            pragma Loop_Invariant (S.Graph.Owner_Used = Before.Graph.Owner_Used);
            pragma Loop_Invariant
              (for all J in 1 .. S.Capacity =>
                S.Graph.Namespaces (J) = Before.Graph.Namespaces (J));
            pragma Loop_Invariant
              (for all J in 1 .. S.Capacity => S.Marks (J) = Before.Marks (J));
            pragma Loop_Invariant
              (for all J in 1 .. S.Graph.Node_Used => Node_Pins_Valid (S.Graph, J));
            pragma Loop_Invariant
              (for all J in 1 .. S.Graph.Node_Used =>
                S.Graph.Nodes (J) =
                  (if J <= I and then S.Marks (J)
                   then Retired_View (Before.Graph.Nodes (J))
                   else Before.Graph.Nodes (J)));
         end loop;
         Retired_Links_Lemma (Before.Graph, S.Graph, Before.Marks);
         Preserve_Namespace_Links (Before.Graph, S.Graph);
         pragma Assert (Facades_Preserved (Before, S));
      end;
   end Free_Marked_Subtree;

   procedure Free_Subtree (S : in out State; Root : Node_Ref) is
      Prepared : Boolean;
      Before : constant State := S with Ghost;
   begin
      Prepare_Subtree (S, Root, 0, Prepared);
      pragma Assert (Prepared);
      pragma Assert (Same_Used_Entries (Before, S));
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
      Free_Marked_Subtree (S, Root);
      pragma Assert (Facades_Preserved (Before, S));
   end Free_Subtree;

   procedure Merge_Text
     (S : in out State; Target, Source : Node_Ref;
      Content : System.Address; Length : Natural; Content_Owner : Owner_Ref;
      Success : out Boolean)
   is
      T : constant Node_View := Node (S, Target);
      C : constant Node_View := Node (S, Source);
      Proposed : constant Node_View := Projected_View
        (T, T.Name, T.Name_Length, Content, Length, T.Document, T.Namespace,
         T.Ns_Pin, T.Doc_Pin, Content_Owner);
      Prepared : Boolean;
   begin
      Success := False;
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
      if S.Marks (Positive (Target)) then
         return;
      end if;

      Set_Node_Projection_Internal
        (S, Target, T.Name, T.Name_Length, Content, Length,
         T.Document, T.Namespace, T.Ns_Pin, T.Doc_Pin, Content_Owner, Success);
      pragma Assert (Success);
      Free_Marked_Subtree (S, Source);
   end Merge_Text;

end XML3_DOM;
