with System;
with XML3_DOM;
with XML3_DOM_Constructors;
with XML3_Native_Memory;

package XML3_DOM_Store with SPARK_Mode is
   use type System.Address;
   use type XML3_DOM.Slot_State;
   use type XML3_DOM_Constructors.Construction_Status;

   type Store is limited private
     with Default_Initial_Condition => Ready (Store);
   function Ready (S : Store) return Boolean with Ghost, Global => null;
   function Is_Empty (S : Store) return Boolean with Global => null;

   subtype Operation_Status is XML3_DOM_Constructors.Construction_Status;
   type Release_Kind is (Document_Only, Content_Node, Plain_Attribute);

   procedure Construct
     (S : in out Store; Kind : XML3_DOM.Node_Kind;
      Name, Content : String; Has_Content : Boolean;
      Ns : System.Address; Result, Implicit_Ns : out System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = XML3_DOM_Constructors.Created then
                  Result /= System.Null_Address
                else Result = System.Null_Address
                  and then Implicit_Ns = System.Null_Address);

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

private
   use type XML3_DOM.State_Access;

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
end XML3_DOM_Store;
