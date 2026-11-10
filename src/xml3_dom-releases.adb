with XML3_DOM.Graph_Lemmas; use XML3_DOM.Graph_Lemmas;
package body XML3_DOM.Releases with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Take_Release
     (S : in out State; B : out Owner_Ref; Address : out System.Address)
   is
      Before : constant State := S with Ghost;
   begin
      while S.Effects.Released_Through < S.Graph.Owner_Used loop
         pragma Loop_Variant (Increases => S.Effects.Released_Through);
         pragma Loop_Invariant (Valid (S) and then Can_Edit (S));
         pragma Loop_Invariant (not S.Effects.Dirty);
         pragma Loop_Invariant (S.Effects.Phase = Editing);
         pragma Loop_Invariant (S.Effects.Cursor = 0);
         pragma Loop_Invariant (S.Effects.Active_Release = Null_Owner);
         pragma Loop_Invariant
           (S.Effects.Released_Through <= S.Graph.Owner_Used);
         pragma Loop_Invariant (Same_Graph (S, Before));
         pragma Loop_Invariant
           (S.Effects.Released_Through >= Before.Effects.Released_Through);
         pragma Loop_Invariant
           (for all I in 1 .. S.Effects.Released_Through =>
              S.Graph.Owners (I).State /= Releasing);
         pragma Loop_Invariant
           (for all I in 1 .. S.Effects.Released_Through =>
              not S.Graph.Owners (I).Release_Emitted);
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
            for I in 1 .. S.Graph.Owner_Used loop
               pragma Assert
                 (S.Graph.Owners (I).Release_Emitted =
                    (S.Effects.Phase = Release_Pending
                     and then Owner_Ref (I) = S.Effects.Active_Release));
               pragma Loop_Invariant
                 (for all J in 1 .. I =>
                    S.Graph.Owners (J).Release_Emitted =
                      (S.Effects.Phase = Release_Pending
                       and then Owner_Ref (J) = S.Effects.Active_Release));
            end loop;
            Preserve_Namespace_Links (Before.Graph, S.Graph);
            pragma Assert
              (for all I in 1 .. S.Graph.Node_Used =>
                 Node_Links_Valid (S.Graph, I));
            pragma Assert
              (for all I in 1 .. S.Graph.Ns_Used =>
                 Namespace_Links_Valid (S.Graph, I));
            pragma Assert (Links_Valid (S));
            pragma Assert (S.Graph.Owner_Used <= S.Capacity);
            pragma Assert (S.Effects.Released_Through <= S.Graph.Owner_Used);
            pragma Assert (S.Effects.Phase = Release_Pending);
            pragma Assert (not S.Effects.Dirty and then S.Effects.Cursor = 0);
            pragma Assert
              (S.Effects.Active_Release in
                 1 .. Owner_Ref (S.Graph.Owner_Used));
            pragma Assert
              (S.Graph.Owners (Positive (S.Effects.Active_Release)).State =
                 Releasing);
            pragma Assert
              (for all I in 1 .. S.Graph.Owner_Used =>
                 S.Graph.Owners (I).Release_Emitted =
                   (S.Effects.Phase = Release_Pending
                    and then Owner_Ref (I) = S.Effects.Active_Release));
            pragma Assert
              (for all I in 1 .. S.Graph.Owner_Used =>
                 (if not S.Effects.Dirty
                   and then I <= S.Effects.Released_Through
                   and then Owner_Ref (I) /= S.Effects.Active_Release
                  then S.Graph.Owners (I).State /= Releasing));
            pragma Assert
              (for all I in 1 .. S.Graph.Owner_Used =>
                 (if S.Graph.Owners (I).State = Releasing then
                    S.Graph.Owners (I).References = 0
                    and then S.Graph.Owners (I).Reservations = 0));
            pragma Assert (Effects_Valid (S));
            pragma Assert (Valid (S));
            --  Only owner B and the effect state changed.
            Facades_Frame (Before, S);
            return;
         end if;
      end loop;
      B := Null_Owner;
      Address := System.Null_Address;
      pragma Assert (Effects_Valid (S));
      pragma Assert (Valid (S));
      Facades_Same_Graph (Before, S);
   end Take_Release;

   procedure Namespace_Release_Lemma
     (Before, After : Graph_State; B : Owner_Ref; I : Positive)
   with Ghost, Global => null,
     Pre => Well_Sized (Before) and then Well_Sized (After)
       and then Before.Node_Used = After.Node_Used
       and then Before.Ns_Used = After.Ns_Used
       and then Before.Owner_Used = After.Owner_Used
       and then B in 1 .. Owner_Ref (Before.Owner_Used)
       and then Before.Owners (Positive (B)).State = Releasing
       and then I <= Before.Ns_Used
       and then (for all J in 1 .. Before.Node_Used =>
         Node_Pins_Valid (Before, J)
         and then After.Nodes (J) =
           (if Before.Nodes (J).Owner = B then (others => <>)
            else Before.Nodes (J)))
       and then (for all J in 1 .. Before.Ns_Used =>
         Namespace_Links_Valid (Before, J)
         and then After.Namespaces (J) =
           (if Before.Namespaces (J).Owner = B then (others => <>)
            else Before.Namespaces (J)))
       and then (for all K in 1 .. Before.Owner_Used =>
         After.Owners (K) =
           (if Owner_Ref (K) = B then (others => <>) else Before.Owners (K))),
     Post => Namespace_Links_Valid (After, I);

   procedure Namespace_Release_Lemma
     (Before, After : Graph_State; B : Owner_Ref; I : Positive)
   is
      N : constant Namespace_View := Before.Namespaces (I);
   begin
      pragma Assert (Namespace_Links_Valid (Before, I));
      if N.State /= Live or else N.Owner = B then
         return;
      end if;
      pragma Assert (After.Namespaces (I) = N);
      pragma Assert (After.Owners (Positive (N.Owner)) =
                       Before.Owners (Positive (N.Owner)));
      if N.Parent /= Null_Node then
         pragma Assert (Node_Pins_Valid (Before, Positive (N.Parent)));
         pragma Assert (Before.Nodes (Positive (N.Parent)).Owner /= B);
         pragma Assert (After.Nodes (Positive (N.Parent)) =
                          Before.Nodes (Positive (N.Parent)));
      end if;
      if N.Previous /= Null_Namespace then
         pragma Assert (Namespace_Links_Valid (Before, Positive (N.Previous)));
         pragma Assert (Before.Namespaces (Positive (N.Previous)).Owner /= B);
         pragma Assert (After.Namespaces (Positive (N.Previous)) =
                          Before.Namespaces (Positive (N.Previous)));
      end if;
      if N.Next /= Null_Namespace then
         pragma Assert (Namespace_Links_Valid (Before, Positive (N.Next)));
         pragma Assert (Before.Namespaces (Positive (N.Next)).Owner /= B);
         pragma Assert (After.Namespaces (Positive (N.Next)) =
                          Before.Namespaces (Positive (N.Next)));
      end if;
      for J in 1 .. Before.Ns_Used loop
         pragma Assert
           (if After.Namespaces (J).State = Live then
             After.Namespaces (J) = Before.Namespaces (J));
         pragma Loop_Invariant
           (for all K in 1 .. J =>
             (if K /= I and then After.Namespaces (K).State = Live
               and then After.Namespaces (K).Owns_Reservation
               and then N.Owns_Reservation
              then After.Namespaces (K).Owner /= N.Owner));
      end loop;
   end Namespace_Release_Lemma;

   procedure Acknowledge_Release (S : in out State; B : Owner_Ref) is
      Before : constant State := S with Ghost;
   begin
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Pins_Valid (Before.Graph, I));
         pragma Assert (Node_Namespaces_Valid (Before.Graph, I));
         pragma Assert (if S.Graph.Nodes (I).State = Live then
           not Holds (S.Graph.Nodes (I), B));
         if S.Graph.Nodes (I).Owner = B then
            pragma Assert (S.Graph.Nodes (I).State /= Live);
            pragma Assert (Before.Graph.Nodes (I).State /= Live);
            if S.Graph.Nodes (I).State = Tombstone
              and then S.Graph.Nodes (I).First_Namespace /= Null_Namespace
            then
               pragma Assert
                 (Before.Graph.Nodes (I).First_Namespace <=
                    Namespace_Ref (Before.Graph.Ns_Used));
               pragma Assert (Namespace_Links_Valid
                 (Before.Graph,
                  Positive (Before.Graph.Nodes (I).First_Namespace)));
               pragma Assert (not Before.Graph.Namespaces
                 (Positive (Before.Graph.Nodes (I).First_Namespace)).
                   Owns_Reservation);
               pragma Assert (Before.Graph.Namespaces
                 (Positive (Before.Graph.Nodes (I).First_Namespace)).Owner = B);
            end if;
            if S.Graph.Nodes (I).State = Tombstone
              and then S.Graph.Nodes (I).Last_Namespace /= Null_Namespace
            then
               pragma Assert
                 (Before.Graph.Nodes (I).Last_Namespace <=
                    Namespace_Ref (Before.Graph.Ns_Used));
               pragma Assert (Namespace_Links_Valid
                 (Before.Graph,
                  Positive (Before.Graph.Nodes (I).Last_Namespace)));
               pragma Assert (not Before.Graph.Namespaces
                 (Positive (Before.Graph.Nodes (I).Last_Namespace)).
                   Owns_Reservation);
               pragma Assert (Before.Graph.Namespaces
                 (Positive (Before.Graph.Nodes (I).Last_Namespace)).Owner = B);
            end if;
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
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         pragma Assert (Namespace_Links_Valid (Before.Graph, I));
         pragma Assert
           (if Before.Graph.Namespaces (I).State = Live
              and then Before.Graph.Namespaces (I).Parent /= Null_Node
            then
              Before.Graph.Namespaces (I).Parent <=
                Node_Ref (Before.Graph.Node_Used));
         pragma Assert
           (if Before.Graph.Namespaces (I).State = Live
              and then Before.Graph.Namespaces (I).Parent /= Null_Node
              and then Before.Graph.Namespaces (I).Owner /= B
            then Before.Graph.Nodes
              (Positive (Before.Graph.Namespaces (I).Parent)).Owner /= B);
         if S.Graph.Namespaces (I).State = Live
           and then S.Graph.Namespaces (I).Owner /= B
         then
            if S.Graph.Namespaces (I).Previous /= Null_Namespace then
               pragma Assert
                 (Before.Graph.Namespaces (I).Previous <=
                    Namespace_Ref (Before.Graph.Ns_Used));
               pragma Assert (Namespace_Links_Valid
                 (Before.Graph,
                  Positive (Before.Graph.Namespaces (I).Previous)));
               pragma Assert (Before.Graph.Namespaces
                 (Positive (Before.Graph.Namespaces (I).Previous)).Owner /= B);
            end if;
            if S.Graph.Namespaces (I).Next /= Null_Namespace then
               pragma Assert
                 (Before.Graph.Namespaces (I).Next <=
                    Namespace_Ref (Before.Graph.Ns_Used));
               pragma Assert (Namespace_Links_Valid
                 (Before.Graph,
                  Positive (Before.Graph.Namespaces (I).Next)));
               pragma Assert (Before.Graph.Namespaces
                 (Positive (Before.Graph.Namespaces (I).Next)).Owner /= B);
            end if;
         end if;
         if S.Graph.Namespaces (I).Owner = B then
            S.Graph.Namespaces (I) := (others => <>);
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. S.Graph.Ns_Used =>
             S.Graph.Namespaces (J) =
               (if J <= I and then Before.Graph.Namespaces (J).Owner = B
                then (others => <>) else Before.Graph.Namespaces (J)));
      end loop;
      --  Every node and namespace is either unchanged or reset to Unused.
      Facades_Frame (Before, S);
      pragma Assert (if Facades_Present (Before) then Facades_Present (S));
      S.Graph.Owners (Positive (B)) := (others => <>);
      pragma Assert
        (for all K in Owner_Ref range 1 .. Owner_Ref (S.Graph.Owner_Used) =>
           S.Graph.Owners (Positive (K)) =
             (if K = B then (others => <>) else
                Before.Graph.Owners (Positive (K))));
      S.Effects.Active_Release := Null_Owner;
      S.Effects.Phase := Editing;
      Preserve_Pin_Equation (Before, S);
      for I in 1 .. S.Graph.Node_Used loop
         pragma Assert (Node_Links_Valid (Before.Graph, I));
         --  A surviving node keeps its namespaces: they belong to its own
         --  owner, which is not B, or hold a reservation, which B (being
         --  released) cannot.
         if S.Graph.Nodes (I).State in Live | Tombstone then
            pragma Assert (S.Graph.Nodes (I) = Before.Graph.Nodes (I));
            pragma Assert (Before.Graph.Nodes (I).Owner /= B);
            if S.Graph.Nodes (I).First_Namespace /= Null_Namespace then
               pragma Assert (Namespace_Links_Valid
                 (Before.Graph,
                  Positive (Before.Graph.Nodes (I).First_Namespace)));
               pragma Assert (Before.Graph.Namespaces
                 (Positive (Before.Graph.Nodes (I).First_Namespace)).Owner /= B);
               pragma Assert
                 (S.Graph.Namespaces
                    (Positive (Before.Graph.Nodes (I).First_Namespace)) =
                  Before.Graph.Namespaces
                    (Positive (Before.Graph.Nodes (I).First_Namespace)));
            end if;
            if S.Graph.Nodes (I).Last_Namespace /= Null_Namespace then
               pragma Assert (Namespace_Links_Valid
                 (Before.Graph,
                  Positive (Before.Graph.Nodes (I).Last_Namespace)));
               pragma Assert (Before.Graph.Namespaces
                 (Positive (Before.Graph.Nodes (I).Last_Namespace)).Owner /= B);
               pragma Assert
                 (S.Graph.Namespaces
                    (Positive (Before.Graph.Nodes (I).Last_Namespace)) =
                  Before.Graph.Namespaces
                    (Positive (Before.Graph.Nodes (I).Last_Namespace)));
            end if;
         end if;
         pragma Assert (Node_Pins_Valid (S.Graph, I));
         pragma Assert (Node_Siblings_Valid (S.Graph, I));
         pragma Assert (Node_Children_Valid (S.Graph, I));
         pragma Assert (Node_Namespaces_Valid (S.Graph, I));
         pragma Loop_Invariant
           (for all J in 1 .. I => Node_Links_Valid (S.Graph, J));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         Namespace_Release_Lemma (Before.Graph, S.Graph, B, I);
         pragma Loop_Invariant
           (for all J in 1 .. I => Namespace_Links_Valid (S.Graph, J));
      end loop;
      Ranges_From_Links (S);
      pragma Assert (Projection_Links_In_Range (S));
      pragma Assert (Pins_In_Range (S));
      Facades_Frame (Before, S);
      pragma Assert (if Facades_Present (Before) then Facades_Present (S));
   end Acknowledge_Release;

end XML3_DOM.Releases;
