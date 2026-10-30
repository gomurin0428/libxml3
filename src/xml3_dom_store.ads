with System;
with XML3_DOM;
with XML3_DOM.Import;
with XML3_DOM_Constructors;
with XML3_Native_Memory;

package XML3_DOM_Store with SPARK_Mode is
   use type System.Address;
   use type XML3_DOM.Slot_State;
   use type XML3_DOM_Constructors.Construction_Status;
   use type XML3_DOM.State_Access;
   use type XML3_DOM.State;
   use type XML3_DOM.Namespace_Ref;
   use type XML3_DOM.Namespace_View_Array;
   use type XML3_DOM.Owner_View_Array;
   pragma Unevaluated_Use_Of_Old (Allow);

   type Store is limited private
     with Default_Initial_Condition => Ready (Store);
   function Ready (S : Store) return Boolean with Ghost, Global => null;
   function Is_Empty (S : Store) return Boolean with Global => null;

   subtype Operation_Status is XML3_DOM_Constructors.Construction_Status;
   type Release_Kind is
     (Document_Only, Content_Node, Plain_Attribute, Namespaced_Attribute);

   procedure Create_Namespace
     (S : in out Store; Element : System.Address;
      Href, Prefix : String; Has_Href, Has_Prefix : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Copy_Namespace
     (S : in out Store; Source : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Set_Namespace
     (S : in out Store; Node_Facade, Ns : System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

   procedure Free_Namespace
     (S : in out Store; Ns : System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

   procedure Adopt_Arena
     (S : in out Store; Source : in out XML3_DOM.State_Access;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Source /= null
         and then XML3_DOM.Valid (Source.all)
         and then XML3_DOM.Can_Edit (Source.all)
         and then XML3_DOM.Import.Is_Arena (Source.all),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Source = null and then Result /= System.Null_Address
       else Result = System.Null_Address and then Source /= null
         and then XML3_DOM.Valid (Source.all)
         and then XML3_DOM.Can_Edit (Source.all)
         and then XML3_DOM.Import.Is_Arena (Source.all)
         and then Source.all = Source.all'Old);

   procedure Construct
     (S : in out Store; Kind : XML3_DOM.Node_Kind;
      Name, Content : String; Has_Content : Boolean;
      Ns : System.Address; Result, Implicit_Ns : out System.Address;
      Status : out Operation_Status;
      Content_Source : System.Address := System.Null_Address;
      Source_Length : Natural := 0;
      Name_Source : System.Address := System.Null_Address;
      Source_Name_Length : Natural := 0)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => (if Content_Source = System.Null_Address then Source_Length = 0
         else Has_Content and then Content'Length = 0)
         and then (if Name_Source = System.Null_Address then Source_Name_Length = 0
           else Name'Length = 0),
       Post => (if Status = XML3_DOM_Constructors.Created then
                  Result /= System.Null_Address
                else Result = System.Null_Address
                  and then Implicit_Ns = System.Null_Address);

   procedure New_Document
     (S : in out Store; Version : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Inspect
     (S : Store; Facade : System.Address;
      Item : out XML3_DOM.Node_View; Found : out Boolean)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Found then Item.State = XML3_DOM.Live
                  and then Item.Facade = Facade);

   --  Parser/attribute assembly: this primitive does not coalesce text.
   procedure Attach
     (S : in out Store; Parent, Child : System.Address;
      Property : Boolean; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

   procedure Add_Child
     (S : in out Store; Parent, Child : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = XML3_DOM_Constructors.Created then
                  Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Add_Sibling
     (S : in out Store; Sibling, Child : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = XML3_DOM_Constructors.Created then
                Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Insert_Sibling
     (S : in out Store; Sibling, Child : System.Address; Before : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S) and then
         (if Status = XML3_DOM_Constructors.Created then
                  Result /= System.Null_Address
               else Result = System.Null_Address);

   procedure Replace_Node
     (S : in out Store; Old, Cur : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S) and then
         (if Status = XML3_DOM_Constructors.Created
          then Result = Old
          else Result = System.Null_Address);

   procedure Merge_Text
     (S : in out Store; First, Second : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S) and then
         (if Status = XML3_DOM_Constructors.Created then
         Result = (if First = System.Null_Address then Second else First)
         else Result = System.Null_Address);

   procedure Set_Root
     (S : in out Store; Doc, Root : System.Address;
      Previous : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status /= XML3_DOM_Constructors.Created then
                  Previous = System.Null_Address);

   procedure Unlink
     (S : in out Store; Facade : System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

   procedure Release
     (S : in out Store; Facade : System.Address; Kind : Release_Kind;
      Require_Parent : Boolean; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

   procedure Release_List
     (S : in out Store; Facade : System.Address; Kind : Release_Kind;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

private
   type Store is limited record
      Current : XML3_DOM.State_Access := null;
   end record with Type_Invariant =>
     Store.Current = null
       or else
         (XML3_DOM.Valid (Store.Current.all)
          and then XML3_DOM.Can_Edit (Store.Current.all)
          and then not XML3_DOM.Projection_Required (Store.Current.all)
          and then XML3_DOM.Facades_Present (Store.Current.all));

   function Ready (S : Store) return Boolean is
     (S.Current = null or else
        (XML3_DOM.Valid (S.Current.all)
         and then XML3_DOM.Can_Edit (S.Current.all)
         and then not XML3_DOM.Projection_Required (S.Current.all)
         and then XML3_DOM.Facades_Present (S.Current.all)));

   function Is_Empty (S : Store) return Boolean is (S.Current = null);

   use type XML3_DOM.Node_Ref;
   function Reclaimable (S : Store) return Boolean is
     (S.Current = null or else
        (for all B in XML3_DOM.Owner_Ref range
           1 .. XML3_DOM.Owner_Ref (XML3_DOM.Owner_Count (S.Current.all)) =>
             XML3_DOM.Owner (S.Current.all, B).State = XML3_DOM.Unused))
     with Global => null,
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all));

   procedure Reclaim_Empty (S : in out Store)
     with Global => null,
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all)),
       Post =>
         (declare
            Old_Owner_Count : constant Natural :=
              Natural'(if S.Current = null then 0
                       else XML3_DOM.Owner_Count (S.Current.all))'Old;
            Old_Namespace_Count : constant Natural :=
              Natural'(if S.Current = null then 0
                       else XML3_DOM.Namespace_Count (S.Current.all))'Old;
            Old_Owners : constant XML3_DOM.Owner_View_Array :=
              XML3_DOM.Owner_View_Array'
                (if S.Current = null then
                   XML3_DOM.Owner_View_Array'(1 .. 0 => (others => <>))
                 else XML3_DOM.Snapshot_Owners (S.Current.all))'Old;
            Old_Namespaces : constant XML3_DOM.Namespace_View_Array :=
              XML3_DOM.Namespace_View_Array'
                (if S.Current = null then
                   XML3_DOM.Namespace_View_Array'(1 .. 0 => (others => <>))
                 else XML3_DOM.Snapshot_Namespaces (S.Current.all))'Old;
          begin
            Ready (S)
            and then (if Reclaimable (S)'Old then S.Current = null
            else S.Current /= null
              and then XML3_DOM.Owner_Count (S.Current.all) = Old_Owner_Count
              and then XML3_DOM.Namespace_Count (S.Current.all) =
                Old_Namespace_Count
              and then XML3_DOM.Snapshot_Owners (S.Current.all) = Old_Owners
              and then XML3_DOM.Snapshot_Namespaces (S.Current.all) =
                Old_Namespaces));

   function Find_Registered_Node
     (S : Store; Facade : System.Address) return XML3_DOM.Node_Ref
     with Global => null,
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all)),
       Post => (if Find_Registered_Node'Result /= XML3_DOM.Null_Node then
         S.Current /= null
         and then Find_Registered_Node'Result in
           1 .. XML3_DOM.Node_Ref (XML3_DOM.Node_Count (S.Current.all))
         and then XML3_DOM.Node
           (S.Current.all, Find_Registered_Node'Result).State = XML3_DOM.Live
         and then XML3_DOM.Node
           (S.Current.all, Find_Registered_Node'Result).Facade = Facade);

   function Find_Node
     (S : Store; Facade : System.Address) return XML3_DOM.Node_Ref
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all)),
       Post => (if Find_Node'Result /= XML3_DOM.Null_Node then
         S.Current /= null
         and then Find_Node'Result in
           1 .. XML3_DOM.Node_Ref (XML3_DOM.Node_Count (S.Current.all))
         and then XML3_DOM.Node (S.Current.all, Find_Node'Result).State =
           XML3_DOM.Live
         and then XML3_DOM.Node (S.Current.all, Find_Node'Result).Facade =
           Facade);

   function Find_Registered_Namespace
     (S : Store; Facade : System.Address) return XML3_DOM.Namespace_Ref
     with Global => null,
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all)),
       Post => (if Find_Registered_Namespace'Result /= XML3_DOM.Null_Namespace then
         S.Current /= null
         and then Find_Registered_Namespace'Result in
           1 .. XML3_DOM.Namespace_Ref
             (XML3_DOM.Namespace_Count (S.Current.all))
         and then XML3_DOM.Namespace
           (S.Current.all, Find_Registered_Namespace'Result).State = XML3_DOM.Live
         and then XML3_DOM.Namespace
           (S.Current.all, Find_Registered_Namespace'Result).Facade = Facade);

   function Find_Namespace
     (S : Store; Facade : System.Address) return XML3_DOM.Namespace_Ref
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all)),
       Post => (if Find_Namespace'Result /= XML3_DOM.Null_Namespace then
         S.Current /= null
         and then Find_Namespace'Result in
           1 .. XML3_DOM.Namespace_Ref
             (XML3_DOM.Namespace_Count (S.Current.all))
         and then XML3_DOM.Namespace
           (S.Current.all, Find_Namespace'Result).State = XML3_DOM.Live
         and then XML3_DOM.Namespace
           (S.Current.all, Find_Namespace'Result).Facade = Facade);

end XML3_DOM_Store;
