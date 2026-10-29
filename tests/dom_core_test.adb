with Ada.Assertions;
with Ada.Text_IO;
with System;
with System.Storage_Elements;
with XML3_DOM; use XML3_DOM;
with XML3_DOM_Allocation;

procedure DOM_Core_Test is
   use type System.Address;
   S : State_Access;
   OK : Boolean;
   Arena, Foreign, Reused, Released : Owner_Ref;
   Doc, Root, Child, Fresh : Node_Ref;
   Ns, Foreign_Ns : Namespace_Ref;
   Address : System.Address;

   function Token (I : Positive) return System.Address is
     (System.Storage_Elements.To_Address (System.Storage_Elements.Integer_Address (I)));

   procedure Bind (N : Node_Ref; Declaration : Namespace_Ref := Null_Namespace) is
   begin
      Set_Node_Projection
        (S.all, N, System.Null_Address, 0, System.Null_Address, 0,
         Doc, Declaration, (if Declaration = 0 then 0 else Arena),
         (if N = Doc then 0 else Arena), 0, 0, OK);
      pragma Assert (OK);
   end Bind;

   procedure Expect_Release_Blocked is
      Blocked : Boolean := False;
   begin
      begin
         Take_Release (S.all, Released, Address);
      exception
         when Ada.Assertions.Assertion_Error => Blocked := True;
      end;
      pragma Assert (Blocked);
   end Expect_Release_Blocked;

   procedure Project is
      N : Node_Ref;
      Declaration : Namespace_Ref;
   begin
      Begin_Projection (S.all);
      while Phase (S.all) = Projecting_Nodes loop
         Next_Node_Projection (S.all, N);
         if N /= Null_Node then
            Expect_Release_Blocked;
            Acknowledge_Projection (S.all);
         end if;
      end loop;
      while Phase (S.all) = Projecting_Namespaces loop
         Next_Namespace_Projection (S.all, Declaration);
         if Declaration /= Null_Namespace then
            Expect_Release_Blocked;
            Acknowledge_Projection (S.all);
         end if;
      end loop;
      pragma Assert (Can_Edit (S.all) and then not Projection_Required (S.all));
   end Project;

   procedure Attribute_Children is
      T : State_Access;
      Own : Owner_Ref;
      Parent, Attr, First, Last, Kept : Node_Ref;
      Local_OK : Boolean;
   begin
      Initialize (T, 8, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (500), Own, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (501), Own, 0, Parent, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Attribute_Node, Token (502), Own, 0, Attr, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Text_Node, Token (503), Own, 0, First, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Text_Node, Token (504), Own, 0, Last, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Text_Node, Token (505), Own, 0, Kept, Local_OK);
      pragma Assert (Local_OK);
      Release_Reservation (T.all, Own);
      Attach_Property (T.all, Parent, Attr, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Attr, First, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Attr, Kept, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Attr, Last, Local_OK);
      pragma Assert (Local_OK);
      Retire_Attribute_Children (T.all, Attr, Kept);
      pragma Assert
        (Node (T.all, First).State = Tombstone
         and then Node (T.all, Last).State = Tombstone
         and then Node (T.all, Attr).First_Child = Kept
         and then Node (T.all, Attr).Last_Child = Kept
         and then Node (T.all, Kept).Next = Null_Node
         and then Node (T.all, Kept).Previous = Null_Node
         and then Node (T.all, Parent).First_Prop = Attr
         and then Node (T.all, Attr).Parent = Parent
         and then Owner (T.all, Own).References = 3);
      Retire_Attribute_Children (T.all, Attr, Null_Node);
      pragma Assert
        (Node (T.all, Kept).State = Tombstone
         and then Node (T.all, Attr).First_Child = Null_Node
         and then Node (T.all, Attr).Last_Child = Null_Node
         and then Owner (T.all, Own).References = 2);
      Free_Subtree (T.all, Parent);
      pragma Assert (Owner (T.all, Own).References = 0);
      XML3_DOM_Allocation.Free_State (T);
   end Attribute_Children;

   procedure Text_Attribute_Retirement is
      T : State_Access;
      Attribute_Owner, Text_Owner, Element_Owner, Namespace_Owner : Owner_Ref;
      Attribute, Text, Element, Rejected_Attribute, Non_Text : Node_Ref;
      Declaration : Namespace_Ref;
      Local_OK : Boolean;
   begin
      Initialize (T, 8, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (520), Attribute_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (521), Text_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (522), Element_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (523), Namespace_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Attribute_Node, Token (524), Attribute_Owner, 0,
         Attribute, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Text_Node, Token (525), Text_Owner, 0, Text, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (526), Element_Owner, 0,
         Element, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Attribute_Node, Token (527), Attribute_Owner, 0,
         Rejected_Attribute, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (528), Element_Owner, 0,
         Non_Text, Local_OK);
      pragma Assert (Local_OK);
      Register_Namespace
        (T.all, Token (529), Token (530), 1, Token (531), 1,
         Namespace_Owner, Declaration, Local_OK, Owns_Reservation => True);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Attribute, Text, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Rejected_Attribute, Non_Text, Local_OK);
      pragma Assert (not Local_OK);
      Attach_Namespace (T.all, Element, Declaration, Local_OK);
      pragma Assert (Local_OK);
      Release_Reservation (T.all, Attribute_Owner);
      Release_Reservation (T.all, Text_Owner);
      Release_Reservation (T.all, Element_Owner);
      pragma Assert (Text_Attribute_Content (T.all, Attribute));
      pragma Assert (Text_Attribute_Content (T.all, Rejected_Attribute));
      declare
         Namespaces_Before : constant Namespace_View_Array :=
           Snapshot_Namespaces (T.all) with Ghost;
         Reservations_Before : constant Natural :=
           Owner (T.all, Namespace_Owner).Reservations with Ghost;
         Element_Before : constant Node_View :=
           Node (T.all, Element) with Ghost;
      begin
         Retire_Attribute_Children (T.all, Attribute, Null_Node);
         pragma Assert
           (Node (T.all, Text).State = Tombstone
            and then Snapshot_Namespaces (T.all) = Namespaces_Before
            and then Owner (T.all, Namespace_Owner).Reservations =
              Reservations_Before
            and then Node (T.all, Element) = Element_Before);
      end;
      XML3_DOM_Allocation.Free_State (T);
   end Text_Attribute_Retirement;

   procedure Namespace_Reservation is
      T : State_Access;
      Root_Owner, Borrower_Owner, Ns_Owner : Owner_Ref;
      Root, Borrower : Node_Ref;
      Declaration : Namespace_Ref;
      Local_OK : Boolean;
      Released_Owner : Owner_Ref;
      Released_Address : System.Address;
      procedure Project_Local is
         Projected_Node : Node_Ref;
         Projected_Namespace : Namespace_Ref;
      begin
         Begin_Projection (T.all);
         while Phase (T.all) = Projecting_Nodes loop
            Next_Node_Projection (T.all, Projected_Node);
            if Projected_Node /= Null_Node then
               Acknowledge_Projection (T.all);
            end if;
         end loop;
         while Phase (T.all) = Projecting_Namespaces loop
            Next_Namespace_Projection (T.all, Projected_Namespace);
            if Projected_Namespace /= Null_Namespace then
               Acknowledge_Projection (T.all);
            end if;
         end loop;
      end Project_Local;
   begin
      Initialize (T, 8, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (510), Root_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (511), Borrower_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (512), Ns_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (513), Root_Owner, 0, Root, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (514), Borrower_Owner, 0, Borrower,
         Local_OK);
      pragma Assert (Local_OK);
      Register_Namespace
        (T.all, Token (515), Token (516), 1, Token (517), 1, Ns_Owner,
         Declaration, Local_OK, Owns_Reservation => True);
      pragma Assert
        (Local_OK and then Namespace_Reservation_Held (T.all, Ns_Owner));
      Attach_Namespace (T.all, Root, Declaration, Local_OK);
      pragma Assert (Local_OK);
      Set_Node_Projection
         (T.all, Borrower, System.Null_Address, 0, System.Null_Address, 0,
         Null_Node, Declaration, Ns_Owner, 0, 0, 0, Local_OK);
      pragma Assert (Local_OK and then Namespace (T.all, Declaration).State = Live);

      pragma Assert (not Retained_Declarations_Clear (T.all, Root));
      Free_Subtree_With_Namespaces (T.all, Root);
      pragma Assert
        (Namespace (T.all, Declaration).State = Live
         and then Namespace (T.all, Declaration).Parent = Null_Node
         and then Namespace (T.all, Declaration).Next = Null_Namespace
         and then Namespace (T.all, Declaration).Previous = Null_Namespace
         and then not Namespace (T.all, Declaration).Attached
         and then not Namespace (T.all, Declaration).Owns_Reservation
         and then Owner (T.all, Ns_Owner).Reservations = 0
         and then Owner (T.all, Ns_Owner).References = 1
         and then Node (T.all, Borrower).Namespace = Declaration);

      Set_Node_Projection
         (T.all, Borrower, System.Null_Address, 0, System.Null_Address, 0,
         Null_Node, Null_Namespace, 0, 0, 0, 0, Local_OK);
      pragma Assert
        (Local_OK and then Owner (T.all, Ns_Owner).State = Releasing
         and then Namespace_Release_Required (T.all, Declaration));
      Free_Subtree (T.all, Borrower);
      Release_Reservation (T.all, Root_Owner);
      Release_Reservation (T.all, Borrower_Owner);
      Project_Local;
      loop
         Take_Release (T.all, Released_Owner, Released_Address);
         exit when Released_Owner = 0;
         Acknowledge_Release (T.all, Released_Owner);
      end loop;
      pragma Assert
        (Owner (T.all, Ns_Owner).State = Unused
         and then Owner (T.all, Root_Owner).State = Unused
         and then Owner (T.all, Borrower_Owner).State = Unused
         and then Valid (T.all));
      XML3_DOM_Allocation.Free_State (T);
   end Namespace_Reservation;

   procedure Text_Merging is
      T : State_Access;
      A, B, Old_Content, New_Content, F : Owner_Ref;
      Parent, Target, Source, Foreign_Doc : Node_Ref;
      Local_OK : Boolean;

      procedure Set_Content
        (N : Node_Ref; Length : Natural; Pin : Owner_Ref := 0;
         Document : Node_Ref := 0; Doc_Pin : Owner_Ref := 0) is
      begin
         Set_Node_Projection
           (T.all, N, System.Null_Address, 0, Token (80), Length,
            Document, 0, 0, Doc_Pin, Pin, 0, Local_OK);
         pragma Assert (Local_OK);
      end Set_Content;
   begin
      Initialize (T, 16, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (71), A, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (72), B, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (73), Old_Content, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (74), New_Content, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (75), F, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (76), A, 0, Parent, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Text_Node, Token (77), A, 0, Target, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Text_Node, Token (78), B, 0, Source, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Document_Node, Token (79), F, 0, Foreign_Doc, Local_OK);
      pragma Assert (Local_OK);
      Set_Content (Foreign_Doc, 0, Document => Foreign_Doc);
      Set_Content (Target, 2, Old_Content);
      Set_Content (Source, 3, Document => Foreign_Doc, Doc_Pin => F);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Merge_Text (T.all, Target, Source, Token (81), 5, New_Content, Local_OK);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      Set_Content (Source, 3);
      Attach_Child (T.all, Parent, Source, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Parent, Target, Local_OK);
      pragma Assert (Local_OK);
      Release_Reservation (T.all, A);
      Release_Reservation (T.all, B);
      Release_Reservation (T.all, Old_Content);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Merge_Text (T.all, Target, Source, Token (81), 4, New_Content, Local_OK);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
         Merge_Text
           (T.all, Target, Source, System.Null_Address, 5, New_Content, Local_OK);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
         Merge_Text (T.all, Target, Target, Token (81), 4, New_Content, Local_OK);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      Merge_Text (T.all, Target, Source, Token (81), 5, New_Content, Local_OK);
      pragma Assert (Local_OK and then Valid (T.all));
      pragma Assert
        (Node (T.all, Target).Content = Token (81)
         and then Node (T.all, Target).Content_Length = 5
         and then Node (T.all, Target).Content_Pin = New_Content
         and then Node (T.all, Target).Parent = Parent
         and then Node (T.all, Target).Previous = 0
         and then Node (T.all, Target).Next = 0
         and then Node (T.all, Parent).First_Child = Target
         and then Node (T.all, Parent).Last_Child = Target
         and then Node (T.all, Source).State = Tombstone);
      pragma Assert
        (Owner (T.all, Old_Content).State = Releasing
         and then Owner (T.all, B).State = Releasing
         and then Owner (T.all, New_Content).References = 2
         and then Projection_Required (T.all));
      Release_Reservation (T.all, New_Content);
      pragma Assert (Owner (T.all, New_Content).References = 1);
      XML3_DOM_Allocation.Free_State (T);
   end Text_Merging;

   procedure Document_Propagation is
      T : State_Access;
      A, B, F : Owner_Ref;
      D, R, C, Foreign_D, FR, FC, Detached_R, Detached_C : Node_Ref;
      Before_References : Natural;
      Local_OK : Boolean;

      procedure Project_Node
        (N, Document : Node_Ref; Doc_Pin : Owner_Ref := 0) is
      begin
         Set_Node_Projection
           (T.all, N, System.Null_Address, 0, System.Null_Address, 0,
            Document, 0, 0, Doc_Pin, 0, 0, Local_OK);
         pragma Assert (Local_OK);
      end Project_Node;

      procedure Try_Project_Node
        (N, Document : Node_Ref; Doc_Pin : Owner_Ref := 0) is
      begin
         Set_Node_Projection
           (T.all, N, System.Null_Address, 0, System.Null_Address, 0,
            Document, 0, 0, Doc_Pin, 0, 0, Local_OK);
      end Try_Project_Node;
   begin
      Initialize (T, 32, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (20), A, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (21), B, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (22), F, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Document_Node, Token (23), A, 0, D, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (24), B, 0, R, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (25), B, 0, C, Local_OK);
      pragma Assert (Local_OK);
      Project_Node (D, D);
      Project_Node (R, 0);
      Project_Node (C, 0, F);
      pragma Assert (Owner (T.all, F).References = 2);
      Attach_Child (T.all, R, C, Local_OK);
      pragma Assert (Local_OK);
      Before_References := Owner (T.all, A).References;
      Attach_Child (T.all, D, R, Local_OK);
      pragma Assert (Local_OK);
      pragma Assert
        (Node (T.all, R).Document = D
         and then Node (T.all, C).Document = D
         and then Node (T.all, R).Doc_Pin = A
         and then Node (T.all, C).Doc_Pin = A
         and then Owner (T.all, A).References = Before_References + 2);
      pragma Assert (Owner (T.all, F).References = 1);

      Register_Node
        (T.all, Document_Node, Token (26), F, 0, Foreign_D, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (27), B, 0, FR, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (28), B, 0, FC, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (29), B, 0, Detached_R, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (30), B, 0, Detached_C, Local_OK);
      pragma Assert (Local_OK);
      Project_Node (Foreign_D, Foreign_D);
      Project_Node (FR, 0);
      Project_Node (FC, 0);
      Project_Node (Detached_R, 0);
      Project_Node (Detached_C, 0);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Try_Project_Node (C, Foreign_D, F);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      Attach_Child (T.all, FR, FC, Local_OK);
      pragma Assert (Local_OK);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Try_Project_Node (FC, Foreign_D, F);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      Attach_Child (T.all, Foreign_D, FR, Local_OK);
      pragma Assert (Local_OK);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Attach_Child (T.all, R, FR, Local_OK);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      Attach_Child (T.all, Detached_R, Detached_C, Local_OK);
      pragma Assert (Local_OK);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Try_Project_Node (Detached_R, Foreign_D, F);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      XML3_DOM_Allocation.Free_State (T);
      pragma Assert (T = null);
   end Document_Propagation;

   procedure Root_Replacement is
      T : State_Access;
      A, B : Owner_Ref;
      D, Comment_N, PI, Old_Root, Old_Child : Node_Ref;
      New_Root, New_Child : Node_Ref;
      Foreign_Doc, Foreign_Root : Node_Ref;
      Empty_Doc, Empty_Root : Node_Ref;
      Previous : Node_Ref;
      Before : State (32) with Ghost;
      Local_OK : Boolean;

      procedure Project_Node
        (N, Document : Node_Ref; Doc_Pin : Owner_Ref := Null_Owner) is
      begin
         Set_Node_Projection
           (T.all, N, System.Null_Address, 0, System.Null_Address, 0,
            Document, 0, 0, Doc_Pin, 0, 0, Local_OK);
         pragma Assert (Local_OK);
      end Project_Node;
   begin
      Initialize (T, 32, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (30), A, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (31), B, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Document_Node, Token (32), A, 0, D, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Comment_Node, Token (33), A, 0, Comment_N, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Processing_Instruction_Node, Token (34), A, 0, PI, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (35), A, 0, Old_Root, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (36), A, 0, Old_Child, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (37), A, 0, New_Root, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (38), A, 0, New_Child, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Document_Node, Token (39), B, 0, Foreign_Doc, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (40), B, 0, Foreign_Root, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Document_Node, Token (41), A, 0, Empty_Doc, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (42), A, 0, Empty_Root, Local_OK);
      pragma Assert (Local_OK);

      Project_Node (D, D);
      Project_Node (Comment_N, 0);
      Project_Node (PI, 0);
      Project_Node (Old_Root, 0);
      Project_Node (Old_Child, 0);
      Project_Node (New_Root, 0);
      Project_Node (New_Child, 0);
      Project_Node (Foreign_Doc, Foreign_Doc);
      Project_Node (Foreign_Root, 0);
      Project_Node (Empty_Doc, Empty_Doc);
      Project_Node (Empty_Root, 0);

      Attach_Child (T.all, Old_Root, Old_Child, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, New_Root, New_Child, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, D, Comment_N, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, D, Old_Root, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, D, PI, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Foreign_Doc, Foreign_Root, Local_OK);
      pragma Assert (Local_OK);

      Replace_Root (T.all, D, New_Root, Previous, Local_OK);
      pragma Assert (Local_OK and then Previous = Old_Root);
      pragma Assert
        (Node (T.all, New_Root).Parent = D
         and then Node (T.all, New_Root).Previous = Comment_N
         and then Node (T.all, New_Root).Next = PI
         and then Node (T.all, New_Root).Sibling_Order =
           Node (T.all, Old_Root).Sibling_Order);
      pragma Assert
        (Node (T.all, D).First_Child = Comment_N
         and then Node (T.all, D).Last_Child = PI
         and then Node (T.all, Comment_N).Next = New_Root
         and then Node (T.all, PI).Previous = New_Root
         and then Node (T.all, Comment_N).Sibling_Order <
           Node (T.all, New_Root).Sibling_Order
         and then Node (T.all, New_Root).Sibling_Order <
           Node (T.all, PI).Sibling_Order);
      pragma Assert
        (Node (T.all, Old_Root).State = Live
         and then Node (T.all, Old_Root).Parent = Null_Node
         and then Node (T.all, Old_Root).Previous = Null_Node
         and then Node (T.all, Old_Root).Next = Null_Node
         and then Node (T.all, Old_Child).Parent = Old_Root
         and then Node (T.all, New_Child).Document = D
         and then Node (T.all, New_Child).Doc_Pin = A);

      Before := T.all;
      Replace_Root (T.all, D, Foreign_Root, Previous, Local_OK);
      pragma Assert (not Local_OK and then Previous = Null_Node);
      pragma Assert (Same_Graph (T.all, Before));

      Replace_Root (T.all, D, New_Child, Previous, Local_OK);
      pragma Assert (Local_OK and then Previous = New_Root);
      pragma Assert
         (Node (T.all, New_Child).Parent = D
         and then Node (T.all, New_Root).Parent = Null_Node
         and then Node (T.all, New_Child).Previous = Comment_N
         and then Node (T.all, New_Child).Next = PI
         and then Node (T.all, New_Root).First_Child = Null_Node);
      Before := T.all;
      Replace_Root (T.all, D, New_Child, Previous, Local_OK);
      pragma Assert
        (Local_OK and then Previous = New_Child
         and then Same_Graph (T.all, Before));

      Replace_Root (T.all, Empty_Doc, Empty_Root, Previous, Local_OK);
      pragma Assert
        (Local_OK and then Previous = Null_Node
         and then Node (T.all, Empty_Root).Parent = Empty_Doc);
      XML3_DOM_Allocation.Free_State (T);
      pragma Assert (T = null);
   end Root_Replacement;

   procedure Adjacent_Sibling_Insertion is
      T : State_Access;
      Own : Owner_Ref;
      Owner_References : Natural;
      Right_Ns_Pin, Right_Doc_Pin, Right_Content_Pin : Owner_Ref;
      Doc, Root, Left, Middle, Right, Other, Moved : Node_Ref;
      Local_OK : Boolean;
   begin
      Initialize (T, 12, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (900), Own, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Document_Node, Token (901), Own, 0, Doc, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (902), Own, 0, Root, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (903), Own, 0, Left, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (904), Own, 0, Middle, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (905), Own, 0, Right, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (906), Own, 0, Other, Local_OK);
      pragma Assert (Local_OK);
      Register_Node (T.all, Element_Node, Token (907), Own, 0, Moved, Local_OK);
      pragma Assert (Local_OK);
      Release_Reservation (T.all, Own);
      Attach_Child (T.all, Doc, Root, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Root, Left, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Root, Middle, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Root, Right, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Root, Other, Local_OK);
      pragma Assert (Local_OK);
      Attach_Child (T.all, Other, Moved, Local_OK);
      pragma Assert (Local_OK);
      Owner_References := Owner (T.all, Own).References;
      Right_Ns_Pin := Node (T.all, Right).Ns_Pin;
      Right_Doc_Pin := Node (T.all, Right).Doc_Pin;
      Right_Content_Pin := Node (T.all, Right).Content_Pin;
      Insert_Sibling (T.all, Left, Right, True, Local_OK);
      pragma Assert
        (Local_OK and then Node (T.all, Right).Next = Left
         and then Node (T.all, Root).First_Child = Right);
      Insert_Sibling (T.all, Moved, Right, True, Local_OK);
      pragma Assert
        (Local_OK and then Node (T.all, Right).Parent = Other
         and then Node (T.all, Right).Document = Doc
         and then Node (T.all, Other).First_Child = Right
         and then Node (T.all, Right).Next = Moved);
      Insert_Sibling (T.all, Moved, Right, False, Local_OK);
      pragma Assert
        (Local_OK and then Node (T.all, Other).First_Child = Moved
         and then Node (T.all, Moved).Next = Right
         and then Node (T.all, Right).Previous = Moved);
      pragma Assert
        (Owner (T.all, Own).References = Owner_References
         and then Node (T.all, Right).Ns_Pin = Right_Ns_Pin
         and then Node (T.all, Right).Doc_Pin = Right_Doc_Pin
         and then Node (T.all, Right).Content_Pin = Right_Content_Pin);
      Free_Subtree (T.all, Doc);
      XML3_DOM_Allocation.Free_State (T);
   end Adjacent_Sibling_Insertion;

   procedure Name_Owner_Lifetime is
      T : State_Access;
      Arena, Name_Owner, Content_Owner, Shared_Owner : Owner_Ref;
      Node_With_Name, Node_With_Shared_Owner : Node_Ref;
      Local_OK : Boolean;

      procedure Finish_Projection is
         Projected_Node : Node_Ref;
         Declaration : Namespace_Ref;
      begin
         Begin_Projection (T.all);
         while Phase (T.all) = Projecting_Nodes loop
            Next_Node_Projection (T.all, Projected_Node);
            if Projected_Node /= Null_Node then
               Acknowledge_Projection (T.all);
            end if;
         end loop;
         while Phase (T.all) = Projecting_Namespaces loop
            Next_Namespace_Projection (T.all, Declaration);
            if Declaration /= Null_Namespace then
               Acknowledge_Projection (T.all);
            end if;
         end loop;
         pragma Assert
           (Can_Edit (T.all) and then not Projection_Required (T.all));
      end Finish_Projection;
   begin
      Initialize (T, 8, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (920), Arena, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (921), Name_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (922), Content_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Owner (T.all, Token (923), Shared_Owner, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (924), Arena, 0,
         Node_With_Name, Local_OK);
      pragma Assert (Local_OK);
      Register_Node
        (T.all, Element_Node, Token (925), Arena, 0,
         Node_With_Shared_Owner, Local_OK);
      pragma Assert (Local_OK);

      Set_Node_Projection
        (T.all, Node_With_Name, Token (926), 4,
         System.Null_Address, 0, Null_Node, Null_Namespace,
         Null_Owner, Null_Owner, Null_Owner, Name_Owner, Local_OK);
      pragma Assert (Local_OK);
      Finish_Projection;
      Set_Node_Projection
        (T.all, Node_With_Name, Token (926), 4, Token (927), 3,
         Null_Node, Null_Namespace, Null_Owner, Null_Owner,
         Content_Owner, Name_Owner, Local_OK);
      pragma Assert
        (Local_OK and then Owner (T.all, Name_Owner).References = 2
         and then Node (T.all, Node_With_Name).Name_Pin = Name_Owner);
      Finish_Projection;

      Set_Node_Projection
        (T.all, Node_With_Shared_Owner, Token (928), 6, Token (929), 5,
         Null_Node, Null_Namespace, Null_Owner, Null_Owner,
         Shared_Owner, Shared_Owner, Local_OK);
      pragma Assert
        (Local_OK and then Owner (T.all, Shared_Owner).References = 2);
      Finish_Projection;
      Release_Reservation (T.all, Arena);
      Release_Reservation (T.all, Name_Owner);
      Release_Reservation (T.all, Content_Owner);
      Release_Reservation (T.all, Shared_Owner);
      Free_Subtree (T.all, Node_With_Name);
      Free_Subtree (T.all, Node_With_Shared_Owner);
      pragma Assert
        (Node (T.all, Node_With_Name).Name_Pin = Null_Owner
         and then Node (T.all, Node_With_Name).Content_Pin = Null_Owner
         and then Owner (T.all, Name_Owner).References = 0
         and then Owner (T.all, Name_Owner).State = Releasing
         and then Owner (T.all, Content_Owner).References = 0
         and then Owner (T.all, Content_Owner).State = Releasing
         and then Owner (T.all, Shared_Owner).References = 0
         and then Owner (T.all, Shared_Owner).State = Releasing);
      XML3_DOM_Allocation.Free_State (T);
   end Name_Owner_Lifetime;

begin
   Attribute_Children;
   Text_Attribute_Retirement;
   Namespace_Reservation;
   Text_Merging;
   Document_Propagation;
   Root_Replacement;
   Adjacent_Sibling_Insertion;
   Name_Owner_Lifetime;
   Initialize (S, 16, OK);
   pragma Assert (OK and then S /= null);
   Register_Owner (S.all, Token (1), Arena, OK);
   pragma Assert (OK);
   Register_Node (S.all, Document_Node, Token (2), Arena, 0, Doc, OK);
   pragma Assert (OK);
   Register_Node (S.all, Element_Node, Token (3), Arena, 0, Root, OK);
   pragma Assert (OK);
   Register_Node (S.all, Element_Node, Token (4), Arena, 0, Child, OK);
   pragma Assert (OK);
   Register_Namespace
     (S.all, Token (5), System.Null_Address, 0,
      System.Null_Address, 0, Arena, Ns, OK);
   pragma Assert (OK);
   Attach_Namespace (S.all, Root, Ns, OK);
   pragma Assert (OK);
   Bind (Doc);
   Bind (Root, Ns);
   Bind (Child, Ns);
   pragma Assert (Owner (S.all, Arena).References = 4);
   Release_Reservation (S.all, Arena);
   pragma Assert (Owner (S.all, Arena).References = 3);
   Attach_Child (S.all, Doc, Root, OK);
   pragma Assert (OK);
   Attach_Child (S.all, Root, Child, OK);
   pragma Assert (OK);
   declare
      Before : constant State := S.all with Ghost;
   begin
      Attach_Child (S.all, Child, Root, OK);
      pragma Assert (not OK and then Same_Graph (S.all, Before));
   end;
   Unlink (S.all, Child);
   pragma Assert (Node (S.all, Child).Parent = 0);
   pragma Assert (Owner (S.all, Arena).References = 3);
   Free_Subtree (S.all, Doc);
   pragma Assert (Node (S.all, Doc).State = Tombstone);
   pragma Assert (Node (S.all, Root).State = Tombstone);
   pragma Assert (Node (S.all, Child).State = Live);
   pragma Assert (Node (S.all, Child).Document = Doc);
   pragma Assert (Node (S.all, Child).Namespace = Ns);
   pragma Assert (Owner (S.all, Arena).References = 1);
   Expect_Release_Blocked;
   Project;
   Take_Release (S.all, Released, Address);
   pragma Assert (Released = 0 and then Address = System.Null_Address);
   Free_Subtree (S.all, Child);
   pragma Assert (Owner (S.all, Arena).State = Releasing);
   pragma Assert (not Owner (S.all, Arena).Release_Emitted);
   pragma Assert (Namespace (S.all, Ns).State = Live);
   Expect_Release_Blocked;
   Project;
   Take_Release (S.all, Released, Address);
   pragma Assert (Released = Arena and then Address = Token (1));
   pragma Assert (Owner (S.all, Arena).Release_Emitted);
   Expect_Release_Blocked;
   Acknowledge_Release (S.all, Released);
   pragma Assert (Owner (S.all, Arena).State = Unused);
   pragma Assert (Node (S.all, Doc).State = Unused);
   pragma Assert (Node (S.all, Root).State = Unused);
   pragma Assert (Node (S.all, Child).State = Unused);
   pragma Assert (Namespace (S.all, Ns).State = Unused);
   Take_Release (S.all, Released, Address);
   pragma Assert (Released = 0);

   Register_Owner (S.all, Token (6), Reused, OK);
   pragma Assert (OK and then Reused = Arena);
   Register_Node (S.all, Element_Node, Token (7), Reused, 0, Fresh, OK);
   pragma Assert (OK);
   pragma Assert (Namespace (S.all, Ns).State = Unused);
   Register_Owner (S.all, Token (8), Foreign, OK);
   pragma Assert (OK);
   Register_Namespace
     (S.all, Token (9), System.Null_Address, 0,
      System.Null_Address, 0, Foreign, Foreign_Ns, OK);
   pragma Assert (OK);
   declare
      Before : constant State := S.all with Ghost;
   begin
      Attach_Namespace (S.all, Fresh, Foreign_Ns, OK);
      pragma Assert (not OK and then Same_Graph (S.all, Before));
   end;
   Release_Reservation (S.all, Reused);
   Release_Reservation (S.all, Foreign);
   Free_Subtree (S.all, Fresh);
   Project;
   Take_Release (S.all, Released, Address);
   pragma Assert (Released = Reused and then Address = Token (6));
   Acknowledge_Release (S.all, Released);
   Take_Release (S.all, Released, Address);
   pragma Assert (Released = Foreign and then Address = Token (8));
   Acknowledge_Release (S.all, Released);
   Take_Release (S.all, Released, Address);
   pragma Assert (Released = 0 and then Valid (S.all));
   XML3_DOM_Allocation.Free_State (S);
   pragma Assert (S = null);
   Ada.Text_IO.Put_Line ("DOM core lifecycle and effect protocol tests passed");
end DOM_Core_Test;
