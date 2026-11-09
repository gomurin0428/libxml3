with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
package body XML3_DOM.Freeing with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Retire_Node (S : in out State; N : Node_Ref) is
      Before : constant State := S with Ghost;
      Item : constant Node_View := S.Graph.Nodes (Positive (N));
      Step : State (Before.Capacity) with Ghost;
   begin
      pragma Assert (Node_Pins_Valid (Before.Graph, Positive (N)));
      S.Graph.Nodes (Positive (N)) := Retired_View (Item);
      for B in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) loop
         Step := S;
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
         Owner_Step_Effects (Step, S, Positive (B));
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
      --  Only node N changes (to its retired view, which keeps Kind and
      --  Facade); namespaces are untouched.
      pragma Assert (S.Graph.Namespaces = Before.Graph.Namespaces);
      pragma Assert
        (for all J in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (J).Kind = Before.Graph.Nodes (J).Kind
           and then S.Graph.Nodes (J).Facade = Before.Graph.Nodes (J).Facade
           and then (if Before.Graph.Nodes (J).State in Live | Tombstone
                     then S.Graph.Nodes (J).State in Live | Tombstone));
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Pins_Valid (Before.Graph, I));
         pragma Assert
           (if I = Positive (N) then S.Graph.Nodes (I) = Retired_View (Item)
            else S.Graph.Nodes (I) = Before.Graph.Nodes (I));
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
      Facades_Frame (Before, S);
      pragma Assert (if Facades_Present (Before) then Facades_Present (S));
   end Retire_Node;

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

   procedure Marked_Text_Declarations_Clear (S : State; Root : Node_Ref) is
   begin
      for I in 1 .. S.Graph.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (S.Graph, I));
         if S.Graph.Namespaces (I).State = Live
           and then S.Graph.Namespaces (I).Owns_Reservation
           and then S.Graph.Namespaces (I).Parent /= Null_Node
         then
            pragma Assert
              (Node (S, S.Graph.Namespaces (I).Parent).Kind = Element_Node);
            pragma Assert (S.Graph.Namespaces (I).Parent /= Root);
            pragma Assert
              (not S.Marks (Positive (S.Graph.Namespaces (I).Parent)));
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             (if S.Graph.Namespaces (J).State = Live
               and then S.Graph.Namespaces (J).Owns_Reservation
               and then S.Graph.Namespaces (J).Parent /= Null_Node then
                 not S.Marks (Positive (S.Graph.Namespaces (J).Parent))));
      end loop;
   end Marked_Text_Declarations_Clear;

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
              (if (for all J in 1 .. Before.Graph.Node_Used =>
                Before.Marks (J) = (Node_Ref (J) = Root)) then
                  (for all B in Owner_Ref range
                    1 .. Owner_Ref (Owner_Count (Before)) =>
                      (if not Holds (Node (Before, Root), B) then
                        Owner (S, B) = Owner (Before, B))));
            pragma Loop_Invariant
              (for all B in Owner_Ref range
                1 .. Owner_Ref (Owner_Count (Before)) =>
                  (if Owner (Before, B).State /= Live then
                    Owner (S, B) = Owner (Before, B)));
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
            pragma Loop_Invariant
              (for all J in 1 .. S.Graph.Owner_Used =>
                S.Graph.Owners (J).Reservations =
                  Before.Graph.Owners (J).Reservations
                and then (if Before.Graph.Owners (J).State = Live
                  and then Before.Graph.Owners (J).Reservations > 0
                  then S.Graph.Owners (J).State = Live));
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

end XML3_DOM.Freeing;
