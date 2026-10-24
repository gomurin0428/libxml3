with System;
with XML3_DOM;
with XML3_DOM_Bridge;
with XML3_DOM_Constructors;
with XML3_DOM_Store.Queries;
with XML3_Native_Memory;

package body XML3_DOM_Store.Properties with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   pragma Unevaluated_Use_Of_Old (Allow);
   package Native renames XML3_Native_Memory;
   use type Node_Ref;
   use type State_Access;
   use type System.Address;
   use type Construction_Status;

   function Has_Colon (Name : String) return Boolean is
   begin
      for I in Name'Range loop
         if Name (I) = ':' then
            return True;
         end if;
      end loop;
      return False;
   end Has_Colon;

   procedure Discard_Unpublished (S : in out Store; N : Node_Ref)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => S.Current /= null
         and then Valid (S.Current.all)
         and then Can_Edit (S.Current.all)
         and then Facades_Present (S.Current.all)
         and then N in 1 .. Node_Ref (Node_Count (S.Current.all))
         and then Node (S.Current.all, N).State = Live
         and then Node (S.Current.all, N).Parent = Null_Node,
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
               and then not Ancestor (S.Current.all'Old, N, I)
              then Node (S.Current.all, I) =
                Node (S.Current.all'Old, I)));

   procedure Discard_Unpublished (S : in out Store; N : Node_Ref) is
      Before : constant State := S.Current.all with Ghost;
   begin
      Free_Subtree (S.Current.all, N);
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
end XML3_DOM_Store.Properties;
