with XML3_DOM_Allocation;
with XML3_DOM_Bridge;
with XML3_DOM_Store.Properties;
with XML3_Text.Buffers;

package body XML3_DOM_Store with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

   function Find_Registered_Node
     (S : Store; Facade : System.Address) return Node_Ref
   is
      Item : Node_View;
   begin
      if S.Current = null or else Facade = System.Null_Address then
         return Null_Node;
      end if;
      for Index in 1 .. Node_Count (S.Current.all) loop
         Item := Node (S.Current.all, Node_Ref (Index));
         if Item.State = Live and then Item.Facade = Facade then
            return Node_Ref (Index);
         end if;
      end loop;
      return Null_Node;
   end Find_Registered_Node;

   function Find_Node (S : Store; Facade : System.Address) return Node_Ref
   is
      Id : Natural;
   begin
      if S.Current = null or else Facade = System.Null_Address then
         return Null_Node;
      end if;
      Id := Native.Node_Id (Facade);
      if Id in 1 .. Node_Count (S.Current.all)
        and then Node (S.Current.all, Node_Ref (Id)).State = Live
        and then Node (S.Current.all, Node_Ref (Id)).Facade = Facade
      then
         return Node_Ref (Id);
      end if;
      return Null_Node;
   end Find_Node;

   function Find_Namespace
     (S : Store; Facade : System.Address) return Namespace_Ref
   is
      Id : Natural;
   begin
      if S.Current = null or else Facade = System.Null_Address then
         return Null_Namespace;
      end if;
      Id := Native.Namespace_Id (Facade);
      if Id in 1 .. Namespace_Count (S.Current.all)
        and then Namespace (S.Current.all, Namespace_Ref (Id)).State = Live
        and then Namespace (S.Current.all, Namespace_Ref (Id)).Facade = Facade
      then
         return Namespace_Ref (Id);
      end if;
      return Null_Namespace;
   end Find_Namespace;

   procedure Reclaim_Empty (S : in out Store)
   is
   begin
      if Reclaimable (S) and then S.Current /= null then
         XML3_DOM_Allocation.Free_State (S.Current);
      end if;
   end Reclaim_Empty;

   procedure Adopt_Arena
     (S : in out Store; Source : in out State_Access;
      Result : out System.Address; Status : out Operation_Status)
   is
      use type XML3_DOM.Import.Import_Status;
      Source_Nodes : constant Natural := Node_Count (Source.all);
      Source_Namespaces : constant Natural := Namespace_Count (Source.all);
      Root : Node_Ref;
      Imported : XML3_DOM.Import.Import_Status;
      Allocated : Boolean;
   begin
      Result := System.Null_Address;
      Status := No_Memory;
      if S.Current = null then
         Initialize
           (S.Current, Positive (Natural'Max
              (16, Natural'Max (Source_Nodes, Source_Namespaces))), Allocated);
         if not Allocated then
            return;
         end if;
      end if;
      if Source_Nodes > Natural'Last - Node_Count (S.Current.all)
        or else Source_Namespaces >
          Natural'Last - Namespace_Count (S.Current.all)
        or else Owner_Count (S.Current.all) = Natural'Last
      then
         Status := Limit_Exceeded;
         Reclaim_Empty (S);
         return;
      end if;
      Ensure_Capacity
        (S.Current, Node_Count (S.Current.all) + Source_Nodes,
         Namespace_Count (S.Current.all) + Source_Namespaces,
         Owner_Count (S.Current.all) + 1, Allocated);
      if not Allocated then
         Reclaim_Empty (S);
         return;
      end if;
      XML3_DOM.Import.Adopt (S.Current.all, Source, Root, Imported);
      if Imported = XML3_DOM.Import.Imported then
         Result := Node (S.Current.all, Root).Facade;
         XML3_DOM_Bridge.Synchronize (S.Current.all);
         Status := Created;
      else
         Status := (if Imported = XML3_DOM.Import.No_Memory
                    then No_Memory else Limit_Exceeded);
         Reclaim_Empty (S);
      end if;
   end Adopt_Arena;

   procedure Create_Namespace
     (S : in out Store; Element : System.Address;
      Href, Prefix : String; Has_Href, Has_Prefix : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : Node_Ref := Null_Node;
      N : Namespace_Ref := Null_Namespace;
      Attached, Ok : Boolean;
      Current : Namespace_Ref;
      Existing : Namespace_View;
      Existing_Prefix : String (1 .. Prefix'Length);
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Element /= System.Null_Address then
         E := Find_Node (S, Element);
         if E = Null_Node or else Node (S.Current.all, E).Kind /= Element_Node then
            return;
         end if;
         Current := Node (S.Current.all, E).First_Namespace;
         for Step in 1 .. Namespace_Count (S.Current.all) loop
            exit when Current = Null_Namespace;
            if Current > Namespace_Ref (Namespace_Count (S.Current.all))
              or else Namespace (S.Current.all, Current).State /= Live
            then
               Status := Internal_Error;
               return;
            end if;
            Existing := Namespace (S.Current.all, Current);
            if Existing.Prefix_Length = Prefix'Length then
               if Has_Prefix then
                  if Existing.Prefix /= System.Null_Address then
                     Native.Read_String (Existing.Prefix, Existing_Prefix);
                     if Existing_Prefix = Prefix then
                        return;
                     end if;
                  end if;
               elsif Existing.Prefix = System.Null_Address then
                  return;
               end if;
            end if;
            Current := Existing.Next;
         end loop;
      end if;
      if S.Current = null then
         Initialize (S.Current, 16, Ok);
         if not Ok then
            Status := No_Memory;
            return;
         end if;
      end if;
      XML3_DOM_Constructors.Create_Namespace
        (S.Current, Href, Prefix, Has_Href, Has_Prefix, N, Status);
      if Status /= Created then
         Reclaim_Empty (S);
         return;
      end if;
      if E /= Null_Node then
         Attach_Namespace (S.Current.all, E, N, Attached);
         if not Attached then
            Release_Namespace_Reservation (S.Current.all, N);
            XML3_DOM_Bridge.Synchronize (S.Current.all);
            Reclaim_Empty (S);
            Status := Invalid_Argument;
            return;
         end if;
      end if;
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Result := Namespace (S.Current.all, N).Facade;
      Status := Created;
   end Create_Namespace;

   procedure Copy_Namespace
     (S : in out Store; Source : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : constant Namespace_Ref := Find_Namespace (S, Source);
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if N = Null_Namespace then
         return;
      end if;
      declare
         Item : constant Namespace_View := Namespace (S.Current.all, N);
         Href : String (1 .. Item.Href_Length) := (others => Character'Val (0));
         Prefix : String (1 .. Item.Prefix_Length) := (others => Character'Val (0));
      begin
         if Item.Href /= System.Null_Address then
            Native.Read_String (Item.Href, Href);
         end if;
         if Item.Prefix /= System.Null_Address then
            Native.Read_String (Item.Prefix, Prefix);
         end if;
         Create_Namespace
           (S, System.Null_Address, Href, Prefix,
            Item.Href /= System.Null_Address, Item.Prefix /= System.Null_Address,
            Result, Status);
      end;
   end Copy_Namespace;

   procedure Set_Namespace
     (S : in out Store; Node_Facade, Ns : System.Address;
      Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Node_Facade);
      Q : constant Namespace_Ref := Find_Namespace (S, Ns);
      Item : Node_View;
      Changed : Boolean;
   begin
      Status := Invalid_Argument;
      if N = Null_Node or else
        Node (S.Current.all, N).Kind not in Element_Node | Attribute_Node
        or else (Ns /= System.Null_Address and then Q = Null_Namespace)
      then
         return;
      end if;
      Item := Node (S.Current.all, N);
      Set_Node_Projection
        (S.Current.all, N, Item.Name, Item.Name_Length, Item.Content,
         Item.Content_Length, Item.Document, Q,
         (if Q = Null_Namespace then Null_Owner
          else Namespace (S.Current.all, Q).Owner),
         Item.Doc_Pin, Item.Content_Pin, Item.Name_Pin, Changed);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      if Changed then
         Status := Created;
      end if;
   end Set_Namespace;

   procedure Free_Namespace
     (S : in out Store; Ns : System.Address;
      Status : out Operation_Status)
   is
      N : constant Namespace_Ref := Find_Namespace (S, Ns);
   begin
      Status := Invalid_Argument;
      if N = Null_Namespace
        or else not Namespace (S.Current.all, N).Owns_Reservation
        or else Namespace (S.Current.all, N).Attached
      then
         return;
      end if;
      Release_Namespace_Reservation (S.Current.all, N);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Reclaim_Empty (S);
      Status := Created;
   end Free_Namespace;

   procedure Construct
     (S : in out Store; Kind : Node_Kind;
      Name, Content : String; Has_Content : Boolean;
      Ns : System.Address; Result, Implicit_Ns : out System.Address;
      Status : out Operation_Status;
      Content_Source : System.Address := System.Null_Address;
      Source_Length : Natural := 0;
      Name_Source : System.Address := System.Null_Address;
      Source_Name_Length : Natural := 0)
   is
      N : Node_Ref;
      Xml_Ns : Namespace_Ref;
      Selected_Ns : constant Namespace_Ref := Find_Namespace (S, Ns);
      Initialized : Boolean;
   begin
      Result := System.Null_Address;
      Implicit_Ns := System.Null_Address;
      if Ns /= System.Null_Address and then Selected_Ns = Null_Namespace then
         Status := Invalid_Argument;
         return;
      end if;
      if S.Current = null then
         Initialize (S.Current, 16, Initialized);
         if not Initialized then
            Status := No_Memory;
            return;
         end if;
      end if;
      Create_Node
        (S.Current, Kind, Name, Content, Has_Content, Selected_Ns,
         N, Xml_Ns, Status, Content_Source, Source_Length,
         Name_Source, Source_Name_Length);
      if Status = Created then
         Result := Node (S.Current.all, N).Facade;
         if Xml_Ns /= Null_Namespace then
            Implicit_Ns := Namespace (S.Current.all, Xml_Ns).Facade;
         end if;
      else
         Reclaim_Empty (S);
      end if;
   end Construct;

   procedure New_Document
     (S : in out Store; Version : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      Length : XML3_Text.Byte_Count;
      Found : Boolean;
      Implicit_Ns : System.Address;
   begin
      Result := System.Null_Address;
      if Version = System.Null_Address then
         Construct
           (S, Document_Node, "", "1.0", True, System.Null_Address,
            Result, Implicit_Ns, Status);
         return;
      end if;
      XML3_Text.Buffers.Measure (Version, Length, Found);
      if not Found then
         Status := Invalid_Argument;
         return;
      end if;
      Construct
        (S, Document_Node, "", "", True, System.Null_Address,
         Result, Implicit_Ns, Status, Version, Length);
   end New_Document;

   procedure Inspect
     (S : Store; Facade : System.Address;
      Item : out Node_View; Found : out Boolean)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
   begin
      Found := N /= Null_Node;
      Item := (others => <>);
      if Found then
         Item := Node (S.Current.all, N);
      end if;
   end Inspect;

   procedure Attach
     (S : in out Store; Parent, Child : System.Address;
      Property : Boolean; Status : out Operation_Status)
   is
      P : constant Node_Ref := Find_Node (S, Parent);
      C : constant Node_Ref := Find_Node (S, Child);
      Attached : Boolean;
   begin
      Status := Invalid_Argument;
      if P = Null_Node or else C = Null_Node then
         return;
      end if;
      if Property then
         if Node (S.Current.all, C).Kind /= Attribute_Node then
            return;
         end if;
         Attach_Property (S.Current.all, P, C, Attached);
      else
         Attach_Child (S.Current.all, P, C, Attached);
      end if;
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      if Attached then
         Status := Created;
      end if;
   end Attach;

   procedure Merge_Text
     (S : in out Store; First, Second : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      T, C : Node_Ref;
      Changed : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if First = System.Null_Address or else Second = System.Null_Address then
         Result := (if First = System.Null_Address then Second else First);
         Status := Created;
         return;
      end if;
      T := Find_Node (S, First);
      C := Find_Node (S, Second);
      if T = Null_Node or else C = Null_Node or else T = C then
         return;
      end if;
      declare
         Target : constant Node_View := Node (S.Current.all, T);
         Source : constant Node_View := Node (S.Current.all, C);
         Length : Natural;
         Buffer, Suffix : System.Address;
         Own : Owner_Ref;
         Allocated : Boolean;
      begin
         if Target.Kind /= Text_Node or else Source.Kind /= Text_Node
           or else (Source.Document /= Null_Node
             and then Source.Document /= Target.Document)
         then
            return;
         end if;
         if (Target.Content_Length > 0
               and then Target.Content = System.Null_Address)
           or else (Source.Content_Length > 0
             and then Source.Content = System.Null_Address)
         then
            Status := Internal_Error;
            return;
         end if;
         if Source.Content = System.Null_Address then
            Release (S, Second, Content_Node, False, Status);
            if Status = Created then
               Result := First;
            end if;
            return;
         end if;
         if Source.Content_Length >= Natural'Last - Target.Content_Length
           or else Owner_Count (S.Current.all) = Natural'Last
         then
            Status := Limit_Exceeded;
            return;
         end if;
         Length := Target.Content_Length + Source.Content_Length;
         Ensure_Capacity
           (S.Current, Node_Count (S.Current.all),
            Namespace_Count (S.Current.all), Owner_Count (S.Current.all) + 1,
            Allocated);
         if not Allocated then
            Status := No_Memory;
            return;
         end if;
         Native.Allocate (Native.Byte_Count (Length) + 1, Buffer);
         if Buffer = System.Null_Address then
            Status := No_Memory;
            return;
         end if;
         Suffix := Native.Offset
           (Buffer, Native.Byte_Count (Target.Content_Length));
         if Suffix = System.Null_Address then
            Native.Free (Buffer);
            Status := No_Memory;
            return;
         end if;
         Native.Copy_Bytes (Target.Content, Buffer, Target.Content_Length);
         Native.Copy_Bytes (Source.Content, Suffix, Source.Content_Length);
         Native.Write_Byte (Buffer, Length, Character'Val (0));
         Register_Owner (S.Current.all, Buffer, Own, Allocated);
         if not Allocated then
            Native.Free (Buffer);
            Status := Internal_Error;
            return;
         end if;
         XML3_DOM.Merge_Text (S.Current.all, T, C, Buffer, Length, Own, Changed);
         Release_Reservation (S.Current.all, Own);
         XML3_DOM_Bridge.Synchronize (S.Current.all);
         if Changed then
            Result := First;
            Status := Created;
         end if;
      end;
   end Merge_Text;

   procedure Add_Child
     (S : in out Store; Parent, Child : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      P : constant Node_Ref := Find_Node (S, Parent);
      C : constant Node_Ref := Find_Node (S, Child);
      Tail : Node_Ref;
      Changed : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if P = Null_Node or else C = Null_Node then
         return;
      end if;
      if Node (S.Current.all, C).Kind = Attribute_Node then
         XML3_DOM_Store.Properties.Add_Property
           (S, Parent, Child, Result, Status);
         return;
      end if;
      if Node (S.Current.all, P).Kind not in Element_Node | Document_Node
        or else Node (S.Current.all, C).Kind not in
          Element_Node | Text_Node | CData_Node | Comment_Node
          | Processing_Instruction_Node
        or else (Node (S.Current.all, P).Kind = Document_Node
          and then Node (S.Current.all, C).Kind in Text_Node | CData_Node)
      then
         return;
      end if;
      Tail := Node (S.Current.all, P).Last_Child;
      if Node (S.Current.all, C).Parent = P and then Tail = C then
         Result := Child;
         Status := Created;
         return;
      end if;
      if Node (S.Current.all, C).Kind = Text_Node
        and then Tail in 1 .. Node_Ref (Node_Count (S.Current.all))
        and then Node (S.Current.all, Tail).State = Live
        and then Node (S.Current.all, Tail).Kind = Text_Node
      then
         Merge_Text
           (S, Node (S.Current.all, Tail).Facade, Child, Result, Status);
      else
         Attach_Child (S.Current.all, P, C, Changed);
         XML3_DOM_Bridge.Synchronize (S.Current.all);
         if Changed then
            Result := Child;
            Status := Created;
         end if;
      end if;
   end Add_Child;

   procedure Add_Sibling
     (S : in out Store; Sibling, Child : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Sibling);
      C : constant Node_Ref := Find_Node (S, Child);
      P : Node_Ref;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if N = Null_Node or else C = Null_Node or else N = C then
         return;
      end if;
      if (Node (S.Current.all, N).Kind = Attribute_Node) /=
        (Node (S.Current.all, C).Kind = Attribute_Node)
      then
         return;
      end if;
      P := Node (S.Current.all, N).Parent;
      if P not in 1 .. Node_Ref (Node_Count (S.Current.all))
        or else Node (S.Current.all, P).State /= Live
      then
         return;
      end if;
      Add_Child (S, Node (S.Current.all, P).Facade, Child, Result, Status);
   end Add_Sibling;

   procedure Insert_Sibling
     (S : in out Store; Sibling, Child : System.Address; Before : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Sibling);
      C : constant Node_Ref := Find_Node (S, Child);
      Changed : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if N = Null_Node or else C = Null_Node or else N = C then
         return;
      end if;
      XML3_DOM.Insert_Sibling (S.Current.all, N, C, Before, Changed);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      if Changed then
         Result := Child;
         Status := Created;
      end if;
   end Insert_Sibling;

   procedure Replace_Node
     (S : in out Store; Old, Cur : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      O : constant Node_Ref := Find_Node (S, Old);
      C : Node_Ref;
      Parent : Node_Ref;
      Changed : Boolean;
      Previous : Node_Ref;
      Replaced : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Old = Cur or else O = Null_Node
        or else O > Node_Ref (Node_Count (S.Current.all))
      then
         return;
      end if;
      Parent := Node (S.Current.all, O).Parent;
      if Parent = Null_Node
        or else Parent > Node_Ref (Node_Count (S.Current.all))
      then
         return;
      end if;
      if Node (S.Current.all, Parent).State /= Live then
         return;
      end if;
      if Cur = System.Null_Address then
         XML3_DOM.Unlink (S.Current.all, O);
         XML3_DOM_Bridge.Synchronize (S.Current.all);
         Result := Old;
         Status := Created;
         return;
      end if;
      C := Find_Node (S, Cur);
      if C = Null_Node then
         return;
      end if;
      if (Node (S.Current.all, O).Kind = Attribute_Node) /=
        (Node (S.Current.all, C).Kind = Attribute_Node)
      then
         Result := Old;
         Status := Created;
         return;
      end if;
      if Node (S.Current.all, O).Kind = Attribute_Node then
         return;
      end if;
      if Node (S.Current.all, Parent).Kind = Document_Node
        and then Node (S.Current.all, O).Kind = Element_Node
        and then Node (S.Current.all, C).Kind = Element_Node
      then
         XML3_DOM.Replace_Root
           (S.Current.all, Parent, C, Previous, Replaced);
         XML3_DOM_Bridge.Synchronize (S.Current.all);
         if Replaced and then Previous = O then
            Result := Old;
            Status := Created;
         end if;
         return;
      end if;
      XML3_DOM.Insert_Sibling
        (S.Current.all, O, C, True, Changed);
      if Changed then
         if O /= Null_Node
           and then O <= Node_Ref (Node_Count (S.Current.all))
           and then Node (S.Current.all, O).State = Live
         then
            XML3_DOM.Unlink (S.Current.all, O);
            Result := Old;
            Status := Created;
         else
            Status := Internal_Error;
         end if;
      end if;
      XML3_DOM_Bridge.Synchronize (S.Current.all);
   end Replace_Node;

   procedure Set_Root
     (S : in out Store; Doc, Root : System.Address;
      Previous : out System.Address; Status : out Operation_Status)
   is
      D : constant Node_Ref := Find_Node (S, Doc);
      R : constant Node_Ref := Find_Node (S, Root);
      Old_Root : Node_Ref;
      Replaced : Boolean;
   begin
      Previous := System.Null_Address;
      Status := Invalid_Argument;
      if D = Null_Node or else R = Null_Node then
         return;
      end if;
      Replace_Root (S.Current.all, D, R, Old_Root, Replaced);
      if Replaced then
         Status := Created;
         if Old_Root /= Null_Node then
            Previous := Node (S.Current.all, Old_Root).Facade;
         end if;
      end if;
      XML3_DOM_Bridge.Synchronize (S.Current.all);
   end Set_Root;

   procedure Unlink
     (S : in out Store; Facade : System.Address;
      Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
   begin
      Status := Invalid_Argument;
      if Facade = System.Null_Address then
         Status := Created;
         return;
      elsif N = Null_Node then
         return;
      end if;
      if Node (S.Current.all, N).Kind = Document_Node then
         return;
      end if;
      XML3_DOM.Unlink (S.Current.all, N);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Status := Created;
   end Unlink;

   procedure Release
     (S : in out Store; Facade : System.Address; Kind : Release_Kind;
      Require_Parent : Boolean; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
      Item : Node_View;
   begin
      Status := Invalid_Argument;
      if Facade = System.Null_Address and then not Require_Parent then
         Status := Created;
         return;
      elsif N = Null_Node then
         return;
      end if;
      Item := Node (S.Current.all, N);
      if (Require_Parent and then Item.Parent = Null_Node)
        or else (case Kind is
          when Document_Only => Item.Kind /= Document_Node,
          when Content_Node => Item.Kind in Document_Node | Attribute_Node,
          when Plain_Attribute | Namespaced_Attribute =>
            Item.Kind /= Attribute_Node)
      then
         return;
      end if;
      Free_Subtree_With_Namespaces (S.Current.all, N);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Reclaim_Empty (S);
      Status := Created;
   end Release;

   procedure Release_List
     (S : in out Store; Facade : System.Address; Kind : Release_Kind;
      Status : out Operation_Status)
   is
      N : Node_Ref := Find_Node (S, Facade);
      Following : Node_Ref;
      Item : Node_View;
   begin
      Status := Invalid_Argument;
      if Facade = System.Null_Address then
         Status := Created;
         return;
      elsif N = Null_Node or else Kind = Document_Only then
         return;
      end if;
      Status := Internal_Error;
      for Step in 1 .. Node_Count (S.Current.all) loop
         pragma Loop_Invariant (S.Current /= null);
         pragma Loop_Invariant
           (Valid (S.Current.all) and then Can_Edit (S.Current.all)
            and then Facades_Present (S.Current.all));
         if N not in 1 .. Node_Ref (Node_Count (S.Current.all))
           or else Node (S.Current.all, N).State /= Live
         then
            exit;
         end if;
         Item := Node (S.Current.all, N);
         if (Kind = Content_Node
             and then Item.Kind in Document_Node | Attribute_Node)
           or else (Kind in Plain_Attribute | Namespaced_Attribute
                    and then Item.Kind /= Attribute_Node)
         then
            Status := Invalid_Argument;
            exit;
         end if;
         Following := Item.Next;
         Free_Subtree_With_Namespaces (S.Current.all, N);
         N := Following;
         if N = Null_Node then
            Status := Created;
            exit;
         end if;
      end loop;
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Reclaim_Empty (S);
   end Release_List;
end XML3_DOM_Store;
