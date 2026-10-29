with System;
with XML3_DOM;
with XML3_DOM_Bridge;
with XML3_DOM_Constructors;
with XML3_DOM_Store.Queries;
with XML3_Namespaces;
with XML3_Native_Memory;
with XML3_Text;

package body XML3_DOM_Store.Properties with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   use XML3_DOM_Store.Queries;
   pragma Unevaluated_Use_Of_Old (Allow);
   package Native renames XML3_Native_Memory;
   use type Node_Ref;
   use type State_Access;
   use type System.Address;
   use type Construction_Status;

   procedure Add_Property
     (S : in out Store; Element, Attribute : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : constant Node_Ref := Find_Node (S, Element);
      A : constant Node_Ref := Find_Node (S, Attribute);
      Existing : System.Address := System.Null_Address;
      Old : Node_Ref;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if E = Null_Node or else A = Null_Node
        or else Node (S.Current.all, E).Kind /= Element_Node
        or else Node (S.Current.all, A).Kind /= Attribute_Node
      then
         return;
      end if;
      if Node (S.Current.all, A).Parent = E
        and then Node (S.Current.all, E).Last_Prop = A
      then
         Result := Attribute;
         Status := Created;
         return;
      end if;
      Find_Matching_Property (S, Element, Attribute, Existing, Status);
      if Status /= Created then
         return;
      end if;
      if Existing /= System.Null_Address and then Existing /= Attribute then
         Old := Find_Node (S, Existing);
         if Old = Null_Node
           or else Node (S.Current.all, Old).Kind /= Attribute_Node
           or else Node (S.Current.all, Old).Parent /= E
         then
            Status := Internal_Error;
            return;
         end if;
      end if;
      Attach (S, Element, Attribute, True, Status);
      if Status /= Created then
         return;
      end if;
      if Existing /= System.Null_Address and then Existing /= Attribute then
         Release (S, Existing, Plain_Attribute, False, Status);
         if Status /= Created then
            return;
         end if;
      end if;
      Result := Attribute;
   end Add_Property;

   function Attached_Entry
     (Current : State; Ns : System.Address; I : Namespace_Ref) return Boolean is
     (Ns /= System.Null_Address
      and then Namespace (Current, I).State = Live
      and then Namespace (Current, I).Facade = Ns
      and then Namespace (Current, I).Attached
      and then Namespace (Current, I).Owner in
        1 .. Owner_Ref (Owner_Count (Current))
      and then Owner (Current, Namespace (Current, I).Owner).State = Live)
     with Ghost, Global => null,
       Pre => Well_Sized (Current)
         and then I in 1 .. Namespace_Ref (Namespace_Count (Current)),
       Annotate => (GNATprove, Inline_For_Proof);

   function Attachment_In_State
     (Current : State; Ns : System.Address) return Boolean is
     (Ns /= System.Null_Address
      and then (for some I in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (Current)) =>
          Attached_Entry (Current, Ns, I)))
     with Ghost, Global => null, Pre => Well_Sized (Current),
       Annotate => (GNATprove, Inline_For_Proof);

   procedure Preserve_Attachment
     (Before, After : State; Ns : System.Address)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then Namespace_Retention_Valid (Before)
         and then Namespace_Count (Before) = Namespace_Count (After)
         and then Owner_Count (Before) <= Owner_Count (After)
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             (if Attached_Entry (After, Ns, I) then
               Namespace (After, I) = Namespace (Before, I)))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             (if Ns /= System.Null_Address
               and then Namespace (Before, I).State = Live
               and then Namespace (Before, I).Facade = Ns
               and then Namespace (Before, I).Attached
              then Owner (Before, Namespace (Before, I).Owner).State = Live
                or else Owner (After, Namespace (Before, I).Owner).State /= Live))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             (if Attached_Entry (Before, Ns, I) then
               Namespace (After, I) = Namespace (Before, I)
               and then Owner (After, Namespace (Before, I).Owner).State = Live)),
       Post => Attachment_In_State (Before, Ns) =
         Attachment_In_State (After, Ns);

   procedure Preserve_Attachment
     (Before, After : State; Ns : System.Address)
   is
   begin
      for I in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (Before))
      loop
         if Attached_Entry (After, Ns, I) then
            pragma Assert (Namespace (Before, I) = Namespace (After, I));
            pragma Assert
              (Owner (Before, Namespace (Before, I).Owner).State in
                 Live | Releasing);
            pragma Assert (Attached_Entry (Before, Ns, I));
         end if;
         pragma Assert
           (Attached_Entry (Before, Ns, I) = Attached_Entry (After, Ns, I));
         pragma Loop_Invariant
           (for all J in Namespace_Ref range 1 .. I =>
             Attached_Entry (Before, Ns, J) = Attached_Entry (After, Ns, J));
      end loop;
   end Preserve_Attachment;

   procedure Reclaim_Empty_Preserving_Attachment
     (S : in out Store; Ns : System.Address)
     with Global => null,
       Pre => S.Current = null or else
         (Valid (S.Current.all) and then Can_Edit (S.Current.all)
          and then not Projection_Required (S.Current.all)
          and then Facades_Present (S.Current.all)),
       Post => Ready (S)
         and then Namespace_Attached (S, Ns) = Namespace_Attached (S, Ns)'Old;

   procedure Reclaim_Empty_Preserving_Attachment
     (S : in out Store; Ns : System.Address)
   is
      Was_Attached : constant Boolean := Namespace_Attached (S, Ns) with Ghost;
   begin
      if S.Current /= null then
         declare
            Before : constant State := S.Current.all with Ghost;
         begin
            Reclaim_Empty (S);
            if S.Current /= null then
               Preserve_Attachment (Before, S.Current.all, Ns);
            else
               pragma Assert (not Attachment_In_State (Before, Ns));
            end if;
         end;
      else
         Reclaim_Empty (S);
      end if;
      pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
   end Reclaim_Empty_Preserving_Attachment;

   function Namespace_Declaration_Safe
     (S : State; Facade : System.Address)
      return Boolean
   with Global => null,
     Pre => Valid (S),
     Post => Namespace_Declaration_Safe'Result =
       (for all I in Namespace_Ref range
         1 .. Namespace_Ref (Namespace_Count (S)) =>
           (if Namespace (S, I).State = Live
             and then Namespace (S, I).Facade = Facade
             and then Namespace (S, I).Attached
            then Namespace (S, I).Parent in 1 .. Node_Ref (Node_Count (S))
              and then Node (S, Namespace (S, I).Parent).State = Live));

   function Namespace_Declaration_Safe
     (S : State; Facade : System.Address)
      return Boolean
   is
      Item : Namespace_View;
   begin
      for I in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) loop
         Item := Namespace (S, I);
         if Item.State = Live and then Item.Facade = Facade
           and then Item.Attached
         then
            if Item.Parent not in 1 .. Node_Ref (Node_Count (S))
              or else Node (S, Item.Parent).State /= Live
            then
               return False;
            end if;
         end if;
         pragma Loop_Invariant
           (for all J in Namespace_Ref range 1 .. I =>
             (if Namespace (S, J).State = Live
               and then Namespace (S, J).Facade = Facade
               and then Namespace (S, J).Attached
              then Namespace (S, J).Parent in 1 .. Node_Ref (Node_Count (S))
                and then Node (S, Namespace (S, J).Parent).State = Live));
      end loop;
      return True;
   end Namespace_Declaration_Safe;

   procedure Preserve_Safe_Attachment
     (Before, After : State; Ns : System.Address)
     with Ghost, Global => null,
       Pre => Valid (Before) and then Valid (After)
         and then Namespace_Declaration_Safe (Before, Ns)
         and then Namespace_Count (Before) = Namespace_Count (After)
         and then Node_Count (Before) <= Node_Count (After)
         and then Owner_Count (Before) <= Owner_Count (After)
         and then (for all N in Node_Ref range
           1 .. Node_Ref (Node_Count (Before)) =>
             (if Node (Before, N).State = Live
               and then Node (Before, N).Kind = Element_Node then
                 Node (After, N).State = Live))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             (if Namespace (After, I).State = Live then
               Namespace (After, I) = Namespace (Before, I))
             and then (if Namespace (Before, I).State = Live
               and then Namespace (Before, I).Facade = Ns
               and then Namespace (Before, I).Attached then
                 Namespace (After, I) = Namespace (Before, I))),
       Post => Namespace_Declaration_Safe (After, Ns)
         and then Attachment_In_State (Before, Ns) =
           Attachment_In_State (After, Ns);

   procedure Preserve_Safe_Attachment
     (Before, After : State; Ns : System.Address)
   is
   begin
      for I in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (Before))
      loop
         if Namespace (After, I).State = Live
           and then Namespace (After, I).Facade = Ns
           and then Namespace (After, I).Attached
         then
            pragma Assert (Namespace (After, I) = Namespace (Before, I));
            pragma Assert
              (Node (Before, Namespace (Before, I).Parent).State = Live);
            pragma Assert
              (Node (Before, Namespace (Before, I).Parent).Kind = Element_Node);
            pragma Assert
              (Node (After, Namespace (After, I).Parent).State = Live);
         end if;
         pragma Loop_Invariant
           (for all J in Namespace_Ref range 1 .. I =>
             (if Namespace (After, J).State = Live
               and then Namespace (After, J).Facade = Ns
               and then Namespace (After, J).Attached then
                 Namespace (After, J).Parent in
                   1 .. Node_Ref (Node_Count (After))
                 and then Node (After, Namespace (After, J).Parent).State = Live));
      end loop;
      pragma Assert (Namespace_Declaration_Safe (After, Ns));
      Preserve_Attachment (Before, After, Ns);
   end Preserve_Safe_Attachment;

   function Has_Colon (Name : String) return Boolean is
   begin
      for I in Name'Range loop
         if Name (I) = ':' then
            return True;
         end if;
      end loop;
      return False;
   end Has_Colon;

   function Valid_NCName (Name : String) return Boolean is
   begin
      if Name'Length = 0 or else Name'Length > XML3_Text.Max_Bytes then
         return False;
      end if;
      declare
         Normalized : String (1 .. Name'Length);
         Position : Positive := 1;
         Width : Natural;
      begin
         Normalized := Name;
         while Position <= Normalized'Last loop
            Width := XML3_Text.Name_Width
              (Normalized, Position, Position = Normalized'First);
            if Width = 0 then
               return False;
            end if;
            Position := Position + Width;
            pragma Loop_Variant (Increases => Position);
         end loop;
         return True;
      end;
   end Valid_NCName;

   procedure Discard_Unpublished (S : in out Store; N : Node_Ref)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => S.Current /= null
         and then Valid (S.Current.all)
         and then Can_Edit (S.Current.all)
         and then Facades_Present (S.Current.all)
         and then N in 1 .. Node_Ref (Node_Count (S.Current.all))
         and then Node (S.Current.all, N).State = Live
         and then Node (S.Current.all, N).Parent = Null_Node
         and then Node (S.Current.all, N).Kind in Attribute_Node | Text_Node
         and then Node (S.Current.all, N).First_Prop = Null_Node
         and then Node (S.Current.all, N).First_Namespace = Null_Namespace
         and then (if Node (S.Current.all, N).Kind = Attribute_Node then
           Text_Attribute_Content (S.Current.all, N)
           else Node (S.Current.all, N).First_Child = Null_Node),
       Post => S.Current /= null
         and then Valid (S.Current.all)
         and then Can_Edit (S.Current.all)
         and then not Projection_Required (S.Current.all)
         and then Facades_Present (S.Current.all)
         and then Node_Count (S.Current.all) =
           Node_Count (S.Current.all'Old)
         and then Namespace_Count (S.Current.all) =
           Namespace_Count (S.Current.all'Old)
         and then Owner_Count (S.Current.all) =
           Owner_Count (S.Current.all'Old)
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S.Current.all'Old)) =>
             (if Node (S.Current.all'Old, I).State = Live
               and then Node (S.Current.all'Old, I).Kind = Element_Node
              then Node (S.Current.all, I) = Node (S.Current.all'Old, I)))
         and then (if Node (S.Current.all'Old, N).First_Child = Null_Node then
           (for all I in Node_Ref range
             1 .. Node_Ref (Node_Count (S.Current.all'Old)) =>
               (if I /= N and then Node (S.Current.all'Old, I).State = Live then
                 Node (S.Current.all, I) = Node (S.Current.all'Old, I))))
         and then (for all B in Owner_Ref range
           1 .. Owner_Ref (Owner_Count (S.Current.all'Old)) =>
             (if Owner (S.Current.all'Old, B).State = Releasing then
               Owner (S.Current.all, B).State /= Live))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S.Current.all'Old)) =>
             (if Namespace (S.Current.all, I).State = Live then
               Namespace (S.Current.all, I) = Namespace (S.Current.all'Old, I)))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S.Current.all'Old)) =>
             (if Namespace (S.Current.all'Old, I).State = Live
               and then Namespace (S.Current.all'Old, I).Parent in
                 1 .. Node_Ref (Node_Count (S.Current.all'Old))
               and then Node
                 (S.Current.all'Old, Namespace (S.Current.all'Old, I).Parent).State = Live
              then Namespace (S.Current.all, I) = Namespace (S.Current.all'Old, I)))
         and then (for all I in Node_Ref range
           1 .. Node_Ref (Node_Count (S.Current.all'Old)) =>
             (if Node (S.Current.all'Old, I).State = Live
               and then not Ancestor (S.Current.all'Old, N, I)
              then Node (S.Current.all, I) =
                Node (S.Current.all'Old, I)));

   procedure Discard_Unpublished (S : in out Store; N : Node_Ref) is
      Before : constant State := S.Current.all with Ghost;
   begin
      if Node (S.Current.all, N).Kind = Attribute_Node
        and then Node (S.Current.all, N).First_Child /= Null_Node
      then
         Retire_Attribute_Children (S.Current.all, N, Null_Node);
      end if;
      pragma Assert
        (Snapshot_Namespaces (S.Current.all) = Snapshot_Namespaces (Before));
      Leaf_Retained_Declarations_Lemma (S.Current.all, N);
      Free_Subtree (S.Current.all, N);
      pragma Assert
        (Snapshot_Namespaces (S.Current.all) = Snapshot_Namespaces (Before));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (Before)) =>
           (if Node (Before, I).State = Live
             and then Node (Before, I).Kind = Element_Node then
               Node (S.Current.all, I) = Node (Before, I)));
      pragma Assert (Namespace_Retention_Valid (S.Current.all));
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             (if Namespace (Before, I).State = Live
               and then Namespace (Before, I).Parent in
                 1 .. Node_Ref (Node_Count (Before))
               and then Node (Before, Namespace (Before, I).Parent).State = Live
              then Owner (S.Current.all, Namespace (Before, I).Owner).State =
                Live));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (Before)) =>
           (if Node (Before, I).State = Live
             and then not Ancestor (Before, N, I)
            then Node (S.Current.all, I) = Node (Before, I)));
      XML3_DOM_Bridge.Synchronize (S.Current.all);
   end Discard_Unpublished;

   procedure Create_Property
     (S : in out Store; Element : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : Node_Ref := Null_Node;
      Attribute : Node_Ref := Null_Node;
      Text : Node_Ref := Null_Node;
      Ignored_Namespace : Namespace_Ref;
      Initialized : Boolean;
      Attached : Boolean;
      Failure : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Has_Colon (Name) then
         return;
      end if;
      if Element /= System.Null_Address then
         E := Find_Node (S, Element);
         if E = Null_Node
           or else Node (S.Current.all, E).Kind /= Element_Node
         then
            return;
         end if;
      end if;
      if S.Current = null then
         Initialize (S.Current, 16, Initialized);
         if not Initialized then
            Status := No_Memory;
            return;
         end if;
      end if;

      Create_Node
        (S.Current, Attribute_Node, Name, "", False, Null_Namespace,
         Attribute, Ignored_Namespace, Status);
      if Status /= Created then
         Failure := Status;
         Reclaim_Empty (S);
         Status := Failure;
         return;
      end if;

      if Has_Value then
         Create_Node
           (S.Current, Text_Node, "text", Value, True, Null_Namespace,
            Text, Ignored_Namespace, Status);
         Empty_Attribute_Content_Lemma (S.Current.all, Attribute);
         if Status /= Created then
            Failure := Status;
            Discard_Unpublished (S, Attribute);
            Reclaim_Empty (S);
            Status := Failure;
            return;
         end if;
         Attach_Child (S.Current.all, Attribute, Text, Attached);
         if not Attached then
            Failure := Internal_Error;
            Discard_Unpublished (S, Text);
            Empty_Attribute_Content_Lemma (S.Current.all, Attribute);
            Discard_Unpublished (S, Attribute);
            Reclaim_Empty (S);
            Status := Failure;
            return;
         end if;
      end if;

      if E /= Null_Node then
         Attach_Property (S.Current.all, E, Attribute, Attached);
         if not Attached then
            Failure := Internal_Error;
            Discard_Unpublished (S, Attribute);
            Reclaim_Empty (S);
            Status := Failure;
            return;
         end if;
      end if;

      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Result := Node (S.Current.all, Attribute).Facade;
      Status := Created;
   end Create_Property;

   procedure Set_Property
     (S : in out Store; Element : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : constant Node_Ref := Find_Node (S, Element);
      Existing : System.Address;
      Attribute : Node_Ref;
      Replacement : Node_Ref := Null_Node;
      Ignored_Namespace : Namespace_Ref;
      Attached : Boolean;
      Find_Status : Operation_Status;
      Failure : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Has_Colon (Name)
        or else Element = System.Null_Address
        or else E = Null_Node
        or else Node (S.Current.all, E).Kind /= Element_Node
      then
         return;
      end if;

      XML3_DOM_Store.Queries.Find_Property
        (S, Element, Name, XML3_DOM_Store.Queries.No_Namespace, "",
         Existing, Find_Status);
      if Find_Status /= Created then
         Status := Find_Status;
         return;
      elsif Existing = System.Null_Address then
         Create_Property (S, Element, Name, Value, Has_Value, Result, Status);
         return;
      end if;

      Attribute := Find_Node (S, Existing);
      if Attribute = Null_Node
        or else Node (S.Current.all, Attribute).Kind /= Attribute_Node
      then
         Status := Internal_Error;
         return;
      end if;

      if Has_Value then
         Create_Node
           (S.Current, Text_Node, "text", Value, True, Null_Namespace,
            Replacement, Ignored_Namespace, Status);
         if Status /= Created then
            return;
         end if;
         Attach_Child (S.Current.all, Attribute, Replacement, Attached);
         if not Attached then
            Failure := Internal_Error;
            Discard_Unpublished (S, Replacement);
            Reclaim_Empty (S);
            Status := Failure;
            return;
         end if;
      end if;

      Retire_Attribute_Children
        (S.Current.all, Attribute,
         (if Has_Value then Replacement else Null_Node));
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Result := Existing;
      Status := Created;
   end Set_Property;

   procedure Create_Namespace_Property
     (S : in out Store; Element, Ns : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : constant Node_Ref := Find_Node (S, Element);
      Q : constant Namespace_Ref := Find_Namespace (S, Ns);
      Attribute, Text : Node_Ref := Null_Node;
      Ignored_Namespace : Namespace_Ref;
      Attached : Boolean;
      Failure : Operation_Status;
      Initialized : Boolean;
      Was_Attached : constant Boolean := Namespace_Attached (S, Ns)
        with Ghost;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if (Element /= System.Null_Address
          and then (E = Null_Node
            or else Node (S.Current.all, E).Kind /= Element_Node))
        or else (Ns /= System.Null_Address
          and then (Q = Null_Namespace
            or else Namespace (S.Current.all, Q).Href =
              System.Null_Address))
        or else Has_Colon (Name)
      then
         return;
      end if;
      if S.Current /= null
        and then not Namespace_Declaration_Safe (S.Current.all, Ns)
      then
         return;
      end if;
      if S.Current = null then
         Initialize (S.Current, 16, Initialized);
         if not Initialized then
            Status := No_Memory;
            return;
         end if;
      end if;
      declare
         Before : constant State := S.Current.all with Ghost;
      begin
         pragma Assert (Attachment_In_State (Before, Ns) = Was_Attached);
         pragma Assert (Namespace_Declaration_Safe (S.Current.all, Ns));
         declare
            Checkpoint : constant State := S.Current.all with Ghost;
         begin
            pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
            Create_Node
              (S.Current, Attribute_Node, Name, "", False, Q,
               Attribute, Ignored_Namespace, Status);
            Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
            pragma Assert
              (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         end;
         pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
         if Status /= Created then
            Failure := Status;
            Reclaim_Empty_Preserving_Attachment (S, Ns);
            Status := Failure;
            return;
         end if;
         if Has_Value then
            declare
               Checkpoint : constant State := S.Current.all with Ghost;
            begin
               pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
               Create_Node
                 (S.Current, Text_Node, "text", Value, True, Null_Namespace,
                  Text, Ignored_Namespace, Status);
               Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
               pragma Assert
                 (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
            end;
            Empty_Attribute_Content_Lemma (S.Current.all, Attribute);
            if Status /= Created then
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Discard_Unpublished (S, Attribute);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
               Reclaim_Empty_Preserving_Attachment (S, Ns);
               return;
            end if;
            declare
               Checkpoint : constant State := S.Current.all with Ghost;
            begin
               pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
               Attach_Child (S.Current.all, Attribute, Text, Attached);
               Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
               pragma Assert
                 (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
            end;
            if not Attached then
               Failure := Internal_Error;
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Discard_Unpublished (S, Text);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               Empty_Attribute_Content_Lemma (S.Current.all, Attribute);
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Discard_Unpublished (S, Attribute);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
               Reclaim_Empty_Preserving_Attachment (S, Ns);
               Status := Failure;
               return;
            end if;
         end if;
         pragma Assert
           (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         if E /= Null_Node then
            declare
               Checkpoint : constant State := S.Current.all with Ghost;
            begin
               pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
               Attach_Property (S.Current.all, E, Attribute, Attached);
               pragma Assert
                 (for all I in Namespace_Ref range
                    1 .. Namespace_Ref (Namespace_Count (Checkpoint)) =>
                      Namespace (S.Current.all, I) = Namespace (Checkpoint, I));
               Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
               pragma Assert
                 (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
            end;
            if not Attached then
               Failure := Internal_Error;
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Discard_Unpublished (S, Attribute);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
               Reclaim_Empty_Preserving_Attachment (S, Ns);
               Status := Failure;
               return;
            end if;
         end if;
         pragma Assert
           (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         declare
            Checkpoint : constant State := S.Current.all with Ghost;
         begin
            pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
            XML3_DOM_Bridge.Synchronize (S.Current.all);
            Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
            pragma Assert
              (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         end;
         Result := Node (S.Current.all, Attribute).Facade;
         Status := Created;
         pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
      end;
   end Create_Namespace_Property;

   procedure Retire_Text_Attribute_Children
     (Current : in out State; Attribute, Keep : Node_Ref; Ns : System.Address)
     with Global => null,
       Pre => Valid (Current) and then Can_Edit (Current)
         and then Namespace_Declaration_Safe (Current, Ns)
         and then Attribute in 1 .. Node_Ref (Node_Count (Current))
         and then Node (Current, Attribute).State = Live
         and then Node (Current, Attribute).Kind = Attribute_Node
         and then Text_Attribute_Content (Current, Attribute)
         and then (Keep = Null_Node or else
           (Keep in 1 .. Node_Ref (Node_Count (Current))
            and then Node (Current, Keep).State = Live
            and then Node (Current, Keep).Kind /= Attribute_Node
            and then Node (Current, Keep).Parent = Attribute));
   pragma Postcondition
     (Valid (Current) and then Can_Edit (Current)
      and then Facades_Preserved (Current'Old, Current)
      and then (if Facades_Present (Current'Old) then Facades_Present (Current)));
   pragma Postcondition
     (Node_Count (Current) = Node_Count (Current)'Old
      and then Namespace_Count (Current) = Namespace_Count (Current)'Old
      and then Owner_Count (Current) = Owner_Count (Current)'Old);
   pragma Postcondition
     (Snapshot_Namespaces (Current) = Snapshot_Namespaces (Current)'Old);
   pragma Postcondition
     (for all I in Namespace_Ref range
       1 .. Namespace_Ref (Namespace_Count (Current)) =>
         Namespace (Current, I) = Namespace (Current'Old, I));
   pragma Postcondition
     (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (Current)'Old) =>
       (if Node (Current'Old, I).State = Live
         and then Node (Current'Old, I).Kind = Element_Node then
           Node (Current, I) = Node (Current'Old, I)));
   pragma Postcondition (Namespace_Declaration_Safe (Current, Ns));
   pragma Postcondition
     (Attachment_In_State (Current, Ns) = Attachment_In_State (Current, Ns)'Old);

   procedure Retire_Text_Attribute_Children
     (Current : in out State; Attribute, Keep : Node_Ref; Ns : System.Address)
   is
      Checkpoint : constant State := Current with Ghost;
      Was_Attached : constant Boolean := Attachment_In_State (Current, Ns)
        with Ghost;
   begin
      pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
      pragma Assert (Text_Attribute_Content (Checkpoint, Attribute));
      pragma Assert (Text_Attribute_Content (Current, Attribute));
      pragma Assert
        (Snapshot_Namespaces (Current) = Snapshot_Namespaces (Checkpoint));
      Retire_Attribute_Children (Current, Attribute, Keep);
      pragma Assert
        (Snapshot_Namespaces (Current) = Snapshot_Namespaces (Checkpoint));
      Preserve_Safe_Attachment (Checkpoint, Current, Ns);
      pragma Assert (Attachment_In_State (Current, Ns) = Was_Attached);
   end Retire_Text_Attribute_Children;

   procedure Set_Namespace_Property
     (S : in out Store; Element, Ns : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : constant Node_Ref := Find_Node (S, Element);
      Q : constant Namespace_Ref := Find_Namespace (S, Ns);
      Existing : System.Address := System.Null_Address;
      Attribute, Replacement : Node_Ref := Null_Node;
      Old_Item : Node_View;
      Ignored_Namespace : Namespace_Ref;
      Href_Length : constant Natural :=
        (if Q = Null_Namespace then 1
         else Namespace (S.Current.all, Q).Href_Length);
      Href_Value : String (1 .. Href_Length) := (others => ' ');
      Find_Status : Operation_Status;
      Attached : Boolean;
      Changed : Boolean;
      Was_Attached : constant Boolean := Namespace_Attached (S, Ns)
        with Ghost;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if E = Null_Node or else Node (S.Current.all, E).Kind /= Element_Node
        or else (Ns /= System.Null_Address
          and then (Q = Null_Namespace
            or else Namespace (S.Current.all, Q).Href =
              System.Null_Address))
        or else Has_Colon (Name)
      then
         return;
      end if;
      if Q /= Null_Namespace then
         if Href_Value'Length > 0 then
            Native.Read_String (Namespace (S.Current.all, Q).Href, Href_Value);
         end if;
      end if;
      XML3_DOM_Store.Queries.Find_Property
        (S, Element, Name,
         (if Q = Null_Namespace then No_Namespace else Exact_Namespace),
         (if Q = Null_Namespace then "" else Href_Value),
         Existing, Find_Status);
      if Find_Status /= Created then
         Status := Find_Status;
         return;
      elsif Existing = System.Null_Address then
         Create_Namespace_Property
           (S, Element, Ns, Name, Value, Has_Value, Result, Status);
         return;
      end if;
      Attribute := Find_Node (S, Existing);
      if Attribute = Null_Node
        or else Node (S.Current.all, Attribute).Kind /= Attribute_Node
      then
         Status := Internal_Error;
         return;
      end if;
      if not Namespace_Declaration_Safe (S.Current.all, Ns)
        or else not Text_Attribute_Content (S.Current.all, Attribute)
      then
         Status := Invalid_Argument;
         return;
      end if;
      declare
         Before : constant State := S.Current.all with Ghost;
      begin
         pragma Assert (Attachment_In_State (Before, Ns) = Was_Attached);
         pragma Assert (Namespace_Declaration_Safe (S.Current.all, Ns));
         Old_Item := Node (S.Current.all, Attribute);
         if Has_Value then
            declare
               Checkpoint : constant State := S.Current.all with Ghost;
            begin
               pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
               Create_Node
                 (S.Current, Text_Node, "text", Value, True, Null_Namespace,
                  Replacement, Ignored_Namespace, Status);
               Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
               pragma Assert
                 (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
            end;
            pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
            if Status /= Created then
               return;
            end if;
         end if;
         if Replacement /= Null_Node then
            declare
               Checkpoint : constant State := S.Current.all with Ghost;
            begin
               pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
               Attach_Child (S.Current.all, Attribute, Replacement, Attached);
               pragma Assert
                 (for all I in Namespace_Ref range
                    1 .. Namespace_Ref (Namespace_Count (Checkpoint)) =>
                      Namespace (S.Current.all, I) = Namespace (Checkpoint, I));
               Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
               pragma Assert
                 (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
            end;
            if not Attached then
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Discard_Unpublished (S, Replacement);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
               Reclaim_Empty_Preserving_Attachment (S, Ns);
               Status := Internal_Error;
               return;
            end if;
         end if;
         Old_Item := Node (S.Current.all, Attribute);
         declare
            Checkpoint : constant State := S.Current.all with Ghost;
         begin
            pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
            Set_Node_Projection
              (S.Current.all, Attribute, Old_Item.Name, Old_Item.Name_Length,
               Old_Item.Content, Old_Item.Content_Length, Old_Item.Document, Q,
               (if Q = Null_Namespace then Null_Owner
                else Namespace (S.Current.all, Q).Owner),
               Old_Item.Doc_Pin, Old_Item.Content_Pin, Old_Item.Name_Pin,
               Changed);
            Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
            pragma Assert
              (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         end;
         pragma Assert
           (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         if not Changed then
            if Replacement /= Null_Node then
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Unlink (S.Current.all, Replacement);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               declare
                  Checkpoint : constant State := S.Current.all with Ghost;
               begin
                  pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
                  Discard_Unpublished (S, Replacement);
                  Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
                  pragma Assert
                    (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
               end;
               pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
               Reclaim_Empty_Preserving_Attachment (S, Ns);
            end if;
            Status := Limit_Exceeded;
            return;
         end if;
         declare
            Checkpoint : constant State := S.Current.all with Ghost;
         begin
            pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
            Retire_Text_Attribute_Children
              (S.Current.all, Attribute,
               (if Has_Value then Replacement else Null_Node), Ns);
            pragma Assert
              (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         end;
         declare
            Checkpoint : constant State := S.Current.all with Ghost;
         begin
            pragma Assert (Attachment_In_State (Checkpoint, Ns) = Was_Attached);
            XML3_DOM_Bridge.Synchronize (S.Current.all);
            Preserve_Safe_Attachment (Checkpoint, S.Current.all, Ns);
            pragma Assert
              (Attachment_In_State (S.Current.all, Ns) = Was_Attached);
         end;
         Result := Existing;
         Status := Created;
         pragma Assert (Namespace_Attached (S, Ns) = Was_Attached);
      end;
   end Set_Namespace_Property;

   procedure Unset_Namespace_Property
     (S : in out Store; Element, Ns : System.Address; Name : String;
      Removed : out Boolean; Status : out Operation_Status)
   is
      E : constant Node_Ref := Find_Node (S, Element);
      Q : constant Namespace_Ref := Find_Namespace (S, Ns);
      Href_Length : constant Natural :=
        (if Q = Null_Namespace then 1
         else Namespace (S.Current.all, Q).Href_Length);
      Href_Value : String (1 .. Href_Length) := (others => ' ');
      Attribute : System.Address := System.Null_Address;
   begin
      Removed := False;
      Status := Invalid_Argument;
      if E = Null_Node or else Node (S.Current.all, E).Kind /= Element_Node
        or else (Ns /= System.Null_Address
          and then (Q = Null_Namespace
            or else Namespace (S.Current.all, Q).Href =
              System.Null_Address))
      then
         return;
      end if;
      if Q /= Null_Namespace and then Href_Value'Length > 0 then
         Native.Read_String (Namespace (S.Current.all, Q).Href, Href_Value);
      end if;
      XML3_DOM_Store.Queries.Find_Property
        (S, Element, Name,
         (if Q = Null_Namespace then No_Namespace else Exact_Namespace),
         (if Q = Null_Namespace then "" else Href_Value),
         Attribute, Status);
      if Status /= Created or else Attribute = System.Null_Address then
         return;
      end if;
      XML3_DOM_Store.Release
        (S, Attribute, Namespaced_Attribute, True, Status);
      Removed := Status = Created;
   end Unset_Namespace_Property;

   procedure Set_Qualified_Property
     (S : in out Store; Element : System.Address;
      QName, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      Separator : Natural := 0;
      Namespace_Facade : System.Address := System.Null_Address;
      E : Node_Ref;
      Q : Namespace_Ref;
      Created_Implicit : Boolean := False;
      Failure : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      for I in QName'Range loop
         pragma Loop_Invariant
           (Separator = 0 or else Separator in QName'Range);
         if QName (I) = ':' then
            if Separator /= 0 then
               return;
            end if;
            Separator := I;
         end if;
      end loop;
      if Separator = 0 then
         Set_Property (S, Element, QName, Value, Has_Value, Result, Status);
         return;
      end if;
      if Separator = QName'First or else Separator = QName'Last then
         return;
      end if;
      declare
         Prefix : constant String := QName (QName'First .. Separator - 1);
         Local : constant String := QName (Separator + 1 .. QName'Last);
         Local_Name : String (1 .. Local'Length);
      begin
         if not Valid_NCName (Prefix) or else not Valid_NCName (Local) then
            return;
         end if;
         Local_Name := Local;
         Search_Namespace
           (S, Element, Prefix_Search, True, Prefix, Namespace_Facade, Status);
         if Status /= Created then
            return;
         elsif Namespace_Facade = System.Null_Address then
            E := Find_Node (S, Element);
            if Prefix /= "xml" or else E = Null_Node
              or else Node (S.Current.all, E).Document /= Null_Node
            then
               Status := Invalid_Argument;
               return;
            end if;
            Create_Namespace
              (S, Element, XML3_Namespaces.XML_URI, "xml", True, True,
               Namespace_Facade, Status);
            if Status /= Created then
               return;
            end if;
            Created_Implicit := True;
         end if;
         Set_Namespace_Property
           (S, Element, Namespace_Facade, Local_Name,
            Value, Has_Value, Result, Status);
         if Created_Implicit
           and then (Status /= Created or else Result = System.Null_Address)
         then
            Failure := Status;
            Q := Find_Namespace (S, Namespace_Facade);
            if Q /= Null_Namespace
              and then Namespace (S.Current.all, Q).Attached
            then
               Detach_Namespace_Declaration (S.Current.all, Q);
               if Namespace (S.Current.all, Q).Owns_Reservation then
                  pragma Assert
                    (Q in 1 .. Namespace_Ref
                      (Namespace_Count (S.Current.all)));
                  Release_Namespace_Reservation (S.Current.all, Q);
               end if;
               XML3_DOM_Bridge.Synchronize (S.Current.all);
               Reclaim_Empty (S);
            end if;
            Result := System.Null_Address;
            Status := Failure;
         end if;
      end;
   end Set_Qualified_Property;
end XML3_DOM_Store.Properties;
