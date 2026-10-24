with XML3_DOM_Allocation;
with XML3_DOM_Bridge;

package body XML3_DOM_Store with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;

   function Find_Node (S : Store; Facade : System.Address) return Node_Ref
     with Global => (Input => Native.Foreign_Memory),
       Pre => S.Current = null
         or else
           (Valid (S.Current.all)
            and then Can_Edit (S.Current.all)
            and then not Projection_Required (S.Current.all)
            and then Facades_Present (S.Current.all)),
       Post => (if Find_Node'Result /= Null_Node then
         S.Current /= null
         and then Find_Node'Result in 1 .. Node_Ref (Node_Count (S.Current.all))
         and then Node (S.Current.all, Find_Node'Result).State = Live
         and then Node (S.Current.all, Find_Node'Result).Facade = Facade)
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
     with Global => (Input => Native.Foreign_Memory),
       Pre => S.Current = null
         or else
           (Valid (S.Current.all)
            and then Can_Edit (S.Current.all)
            and then not Projection_Required (S.Current.all)
            and then Facades_Present (S.Current.all)),
       Post => (if Find_Namespace'Result /= Null_Namespace then
         S.Current /= null
         and then Find_Namespace'Result in
           1 .. Namespace_Ref (Namespace_Count (S.Current.all))
         and then Namespace (S.Current.all, Find_Namespace'Result).State = Live
         and then Namespace (S.Current.all, Find_Namespace'Result).Facade = Facade)
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
     with Global => null,
       Pre => S.Current = null
         or else
           (Valid (S.Current.all)
            and then Can_Edit (S.Current.all)
            and then not Projection_Required (S.Current.all)
            and then Facades_Present (S.Current.all)),
       Post => Ready (S)
   is
   begin
      if S.Current = null then
         return;
      end if;
      for B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S.Current.all)) loop
         if Owner (S.Current.all, B).State /= Unused then
            return;
         end if;
      end loop;
      XML3_DOM_Allocation.Free_State (S.Current);
   end Reclaim_Empty;

   procedure Construct
     (S : in out Store; Kind : Node_Kind;
      Name, Content : String; Has_Content : Boolean;
      Ns : System.Address; Result, Implicit_Ns : out System.Address;
      Status : out Operation_Status)
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
         N, Xml_Ns, Status);
      if Status = Created then
         Result := Node (S.Current.all, N).Facade;
         if Xml_Ns /= Null_Namespace then
            Implicit_Ns := Namespace (S.Current.all, Xml_Ns).Facade;
         end if;
      else
         Reclaim_Empty (S);
      end if;
   end Construct;

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
      if Node (S.Current.all, N).Kind in Document_Node | Attribute_Node then
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
          when Plain_Attribute => Item.Kind /= Attribute_Node
            or else Item.Namespace /= Null_Namespace)
      then
         return;
      end if;
      Free_Subtree (S.Current.all, N);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Reclaim_Empty (S);
      Status := Created;
   end Release;
end XML3_DOM_Store;
