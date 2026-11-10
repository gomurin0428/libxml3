with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
package body XML3_DOM.Projection with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

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
      Name_Pin : Owner_Ref;
      Success : out Boolean)
   is
      Before : constant State := S with Ghost;
      Step_Owners : Owner_View_Array (1 .. Before.Capacity) with Ghost;
      Old_Item : constant Node_View := S.Graph.Nodes (Positive (N));
      New_Item : constant Node_View := Projected_View
        (Old_Item, Name, Name_Length, Content, Content_Length,
         Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin, Name_Pin);
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
         --  Owners at the start of this step: only owner B changes in it,
         --  and never its Release_Emitted flag.
         Step_Owners := S.Graph.Owners;
         begin
            pragma Assert
              (if Before.Graph.Owners (Positive (B)).State /= Live then
                 not Holds (Old_Item, B) and then not Holds (New_Item, B));
            Changed_Holder_Count
              (Snapshot_Nodes (Before), Snapshot_Nodes (S), B,
               S.Graph.Node_Used, Positive (N));
            if not Holds (Old_Item, B) and then Holds (New_Item, B) then
               S.Graph.Owners (Positive (B)).References :=
                 S.Graph.Owners (Positive (B)).References + 1;
            elsif Holds (Old_Item, B) and then not Holds (New_Item, B) then
               pragma Assert (Positive_Holder_Count_Witness
                 (Snapshot_Nodes (Before), B, S.Graph.Node_Used,
                  Positive (N)));
               pragma Assert (S.Graph.Owners (Positive (B)).References >
                 S.Graph.Owners (Positive (B)).Reservations);
               Release_Pin (S.Graph.Owners (Positive (B)));
            end if;
            pragma Assert
              (for all K in 1 .. S.Graph.Owner_Used =>
                 (if K /= Positive (B) then
                    S.Graph.Owners (K) = Step_Owners (K)));
            pragma Assert
              (S.Graph.Owners (Positive (B)).Release_Emitted =
                 Step_Owners (Positive (B)).Release_Emitted);
            pragma Assert
              (for all K in 1 .. S.Graph.Owner_Used =>
                 S.Graph.Owners (K).Release_Emitted =
                   Before.Graph.Owners (K).Release_Emitted);
         end;
         pragma Assert (not S.Graph.Owners (Positive (B)).Release_Emitted);
         pragma Loop_Invariant (S.Graph.Node_Used = Before.Graph.Node_Used);
         pragma Loop_Invariant (S.Graph.Owner_Used = Before.Graph.Owner_Used);
         pragma Loop_Invariant (S.Graph.Ns_Used = Before.Graph.Ns_Used);
         pragma Loop_Invariant
           (S.Effects = (Before.Effects with delta Dirty => True));
         pragma Loop_Invariant
           (for all K in 1 .. S.Graph.Owner_Used =>
             S.Graph.Owners (K).Release_Emitted =
               Before.Graph.Owners (K).Release_Emitted);
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
             (if Before.Graph.Owners (Positive (K)).State /= Live then
                S.Graph.Owners (Positive (K)) =
                  Before.Graph.Owners (Positive (K))));
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
      --  The projection changes payload and pin fields of node N only;
      --  every other node and all link fields are unchanged.
      pragma Assert
        (for all J in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (J).State = Before.Graph.Nodes (J).State
           and then S.Graph.Nodes (J).Kind = Before.Graph.Nodes (J).Kind);
      pragma Assert
        (for all J in 1 .. S.Graph.Node_Used =>
           Same_Tree_Links (Before.Graph.Nodes (J), S.Graph.Nodes (J)));
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         pragma Assert
           (if I = Positive (N) then S.Graph.Nodes (I) = New_Item
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
         if S.Graph.Nodes (I).State = Live then
            Held_Pins_Live (S.Graph, I);
         end if;
         pragma Assert (Node_Pins_Valid (S.Graph, I));
         Tree_Links_Frame (Before.Graph, S.Graph, I);
         pragma Assert (Node_Siblings_Valid (S.Graph, I));
         pragma Assert (Node_Children_Valid (S.Graph, I));
         pragma Assert (Node_Namespaces_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      Success := True;
      pragma Assert
        (for all J in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (J).Facade = Before.Graph.Nodes (J).Facade);
      Facades_Frame (Before, S);
      pragma Assert (if Facades_Present (Before) then Facades_Present (S));
      pragma Assert (S.Graph.Namespaces = Before.Graph.Namespaces);
      pragma Assert (Snapshot_Namespaces (S) = Snapshot_Namespaces (Before));
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

end XML3_DOM.Projection;
