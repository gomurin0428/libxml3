package body XML3_DOM.Graph_Lemmas with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Release_Pin (Item : in out Owner_View) is
   begin
      Item.References := Item.References - 1;
      if Item.References = 0 then
         Item.State := Releasing;
      end if;
   end Release_Pin;

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

   procedure Retained_Ancestor
     (Original, Remaining : Node_View_Array; Used : Natural;
      Candidate, N : Node_Ref)
   is
      P : constant Node_Ref := Remaining (Positive (N)).Parent;
   begin
      if Remaining (Positive (N)).State = Live and then Candidate /= N
        and then P in 1 .. Node_Ref (Used)
        and then Remaining (Positive (P)).State = Live
        and then Remaining (Positive (P)).Tree_Rank <
          Remaining (Positive (N)).Tree_Rank
      then
         Retained_Ancestor (Original, Remaining, Used, Candidate, P);
      end if;
   end Retained_Ancestor;

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
   is
   begin
      if I = N then
         return True;
      end if;
      return Positive_Holder_Count_Witness (Nodes, B, N - 1, I);
   end Positive_Holder_Count_Witness;

   procedure Zero_Holder_Count
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural)
   is
   begin
      if N > 0 then
         Zero_Holder_Count (Nodes, B, N - 1);
      end if;
   end Zero_Holder_Count;

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

   procedure Copied_Links_Lemma (Before, After : Graph_State) is
   begin
      for I in 1 .. Before.Node_Used loop
         pragma Assert (Node_Links_Valid (Before, I));
         pragma Assert (Node_Links_Valid (After, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (After, J));
      end loop;
   end Copied_Links_Lemma;

   procedure Owner_Step_Effects (Before, After : State; B : Positive) is
   begin
      pragma Assert
        (for all K in 1 .. After.Graph.Owner_Used =>
           not After.Graph.Owners (K).Release_Emitted);
   end Owner_Step_Effects;

   procedure Facades_Frame (Before, After : State) is
   begin
      --  Restate the raw-array precondition in the accessor form that
      --  Facades_Present is written in.
      pragma Assert
        (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (After)) =>
           (if Node (After, N).State in Live | Tombstone then
              Node (Before, N).State in Live | Tombstone
              and then Node (After, N).Facade = Node (Before, N).Facade));
      pragma Assert
        (for all N in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (After)) =>
             (if Namespace (After, N).State = Live then
                Namespace (Before, N).State = Live
                and then Namespace (After, N).Facade =
                  Namespace (Before, N).Facade));
   end Facades_Frame;

   procedure Tree_Links_Frame (Before, After : Graph_State; I : Positive)
   is null;

   procedure Namespace_Owners_Live (S : Graph_State) is
   begin
      for I in 1 .. S.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (S, I));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              (if S.Namespaces (J).State = Live
                 and then S.Namespaces (J).Owns_Reservation
               then S.Owners (Positive (S.Namespaces (J).Owner)).State = Live
                 and then S.Owners
                   (Positive (S.Namespaces (J).Owner)).Reservations > 0
                 and then (if S.Namespaces (J).Parent /= Null_Node then
                   S.Nodes (Positive (S.Namespaces (J).Parent)).State =
                     Live)));
      end loop;
   end Namespace_Owners_Live;

   procedure Unlinked_Fields (Before, After : State; N : Node_Ref) is
   begin
      for I in 1 .. After.Graph.Node_Used loop
         pragma Assert
           (Node (After, Node_Ref (I)) = Unlinked_View (Before, N, Node_Ref (I)));
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              After.Graph.Nodes (J).State = Before.Graph.Nodes (J).State
              and then After.Graph.Nodes (J).Tree_Rank =
                Before.Graph.Nodes (J).Tree_Rank
              and then After.Graph.Nodes (J).Parent =
                (if J = Positive (N) then Null_Node
                 else Before.Graph.Nodes (J).Parent));
      end loop;
   end Unlinked_Fields;

   procedure Held_Pins_Live (S : Graph_State; I : Positive) is
   begin
      pragma Assert (Holds (S.Nodes (I), S.Nodes (I).Owner));
      pragma Assert
        (if S.Nodes (I).Ns_Pin /= 0 then Holds (S.Nodes (I), S.Nodes (I).Ns_Pin));
      pragma Assert
        (if S.Nodes (I).Doc_Pin /= 0 then
           Holds (S.Nodes (I), S.Nodes (I).Doc_Pin));
      pragma Assert
        (if S.Nodes (I).Content_Pin /= 0 then
           Holds (S.Nodes (I), S.Nodes (I).Content_Pin));
      pragma Assert
        (if S.Nodes (I).Name_Pin /= 0 then
           Holds (S.Nodes (I), S.Nodes (I).Name_Pin));
   end Held_Pins_Live;

   procedure Facades_Same_Graph (Before, After : State) is
   begin
      pragma Assert
        (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (After)) =>
           Node (After, N) = Node (Before, N));
      pragma Assert
        (for all N in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (After)) =>
             Namespace (After, N) = Namespace (Before, N));
   end Facades_Same_Graph;

   procedure Node_Links_Of (S : State; I : Positive) is
   begin
      pragma Assert (Links_Valid (S));
      pragma Assert (Node_Links_Valid (S.Graph, I));
   end Node_Links_Of;

   procedure Namespace_Links_Frame (Before, After : Graph_State) is
   begin
      Namespace_Owners_Live (Before);
      for I in 1 .. Before.Ns_Used loop
         if Before.Namespaces (I).State = Live
           and then Before.Namespaces (I).Owns_Reservation
         then
            pragma Assert
              (Before.Owners (Positive (Before.Namespaces (I).Owner)).State
                 = Live);
            pragma Assert
              (After.Owners (Positive (Before.Namespaces (I).Owner)).State
                 = Live);
            if Before.Namespaces (I).Parent /= Null_Node then
               pragma Assert
                 (Before.Nodes (Positive (Before.Namespaces (I).Parent)).State
                    = Live);
               pragma Assert
                 (After.Nodes (Positive (Before.Namespaces (I).Parent)).State
                    = Live);
            end if;
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              (if Before.Namespaces (J).State = Live
                 and then Before.Namespaces (J).Owns_Reservation
               then After.Owners
                   (Positive (Before.Namespaces (J).Owner)).State = Live
                 and then After.Owners
                   (Positive (Before.Namespaces (J).Owner)).Reservations > 0
                 and then (if Before.Namespaces (J).Parent /= Null_Node then
                   After.Nodes
                     (Positive (Before.Namespaces (J).Parent)).State = Live)));
      end loop;
      Preserve_Namespace_Links (Before, After);
   end Namespace_Links_Frame;

   procedure Ranges_From_Links (S : State) is
   begin
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. Node_Ref (I) =>
              (Node (S, J).State /= Live or else
                 (Node (S, J).Owner <= Owner_Ref (Owner_Count (S))
                  and then Node (S, J).Ns_Pin <= Owner_Ref (Owner_Count (S))
                  and then Node (S, J).Doc_Pin <= Owner_Ref (Owner_Count (S))
                  and then Node (S, J).Content_Pin <=
                    Owner_Ref (Owner_Count (S))
                  and then Node (S, J).Name_Pin <=
                    Owner_Ref (Owner_Count (S))
                  and then Node (S, J).First_Child <= Node_Ref (Node_Count (S))
                  and then Node (S, J).Last_Child <= Node_Ref (Node_Count (S))
                  and then Node (S, J).Parent <= Node_Ref (Node_Count (S))
                  and then Node (S, J).Next <= Node_Ref (Node_Count (S))
                  and then Node (S, J).Previous <= Node_Ref (Node_Count (S))
                  and then Node (S, J).Document <= Node_Ref (Node_Count (S))
                  and then Node (S, J).First_Prop <= Node_Ref (Node_Count (S))
                  and then Node (S, J).Namespace <=
                    Namespace_Ref (Namespace_Count (S))
                  and then Node (S, J).First_Namespace <=
                    Namespace_Ref (Namespace_Count (S)))));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in Namespace_Ref range 1 .. Namespace_Ref (I) =>
              (if Namespace (S, J).State = Live then
                 Namespace (S, J).Next <= Namespace_Ref (Namespace_Count (S))
                 and then Namespace (S, J).Previous <=
                   Namespace_Ref (Namespace_Count (S))
                 and then Namespace (S, J).Parent <=
                   Node_Ref (Node_Count (S))));
      end loop;
   end Ranges_From_Links;

   procedure Unlink_Fields_Raw (Before, After : State; N : Node_Ref) is
   begin
      for I in 1 .. After.Graph.Node_Used loop
         pragma Assert
           (Node (After, Node_Ref (I)).State = Node (Before, Node_Ref (I)).State);
         pragma Loop_Invariant
           (for all J in 1 .. I =>
              After.Graph.Nodes (J).State = Before.Graph.Nodes (J).State
              and then After.Graph.Nodes (J).Tree_Rank =
                Before.Graph.Nodes (J).Tree_Rank
              and then After.Graph.Nodes (J).Parent =
                (if J = Positive (N) then Null_Node
                 else Before.Graph.Nodes (J).Parent));
      end loop;
   end Unlink_Fields_Raw;

end XML3_DOM.Graph_Lemmas;
