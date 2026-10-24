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
         (if N = Doc then 0 else Arena), 0, OK);
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

   procedure Document_Propagation is
      T : State_Access;
      A, B, F : Owner_Ref;
      D, R, C, Foreign_D, FR, FC : Node_Ref;
      Before_References : Natural;
      Local_OK : Boolean;

      procedure Project_Node
        (N, Document : Node_Ref; Doc_Pin : Owner_Ref := 0) is
      begin
         Set_Node_Projection
           (T.all, N, System.Null_Address, 0, System.Null_Address, 0,
            Document, 0, 0, Doc_Pin, 0, Local_OK);
         pragma Assert (Local_OK);
      end Project_Node;
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
      Project_Node (Foreign_D, Foreign_D);
      Project_Node (FR, 0);
      Project_Node (FC, 0);
      Attach_Child (T.all, FR, FC, Local_OK);
      pragma Assert (Local_OK);
      Project_Node (FC, Foreign_D, F);
      declare
         Before : constant State := T.all with Ghost;
      begin
         Attach_Child (T.all, R, FR, Local_OK);
         pragma Assert (not Local_OK and then Same_Graph (T.all, Before));
      end;
      XML3_DOM_Allocation.Free_State (T);
      pragma Assert (T = null);
   end Document_Propagation;
begin
   Document_Propagation;
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
