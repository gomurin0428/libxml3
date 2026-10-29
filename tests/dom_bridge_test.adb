with Ada.Text_IO;
with Interfaces.C;
with System;
with System.Storage_Elements;
with XML3_DOM; use XML3_DOM;
with XML3_DOM.Import;
with XML3_DOM_Allocation;
with XML3_DOM_Bridge;
with XML3_DOM_Constructors;
with XML3_DOM_Store;
with XML3_DOM_Store.Documents;
with XML3_DOM_Store.Queries;
with XML3_DOM_Store.Properties;
with XML3_DOM.Materialize;
with XML3_Native_Memory;
with XML3_Namespaces;
with XML3_Parser;
with XML3_Encoding;

procedure DOM_Bridge_Test is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   use type System.Address;
   use type Interfaces.C.unsigned;
   use type System.Storage_Elements.Integer_Address;

   procedure Store_Merge_Track (Root, Target, Source : System.Address)
     with Import, Convention => C, External_Name => "bridge_store_merge_track";
   procedure Store_Merge_Check (Merged : Interfaces.C.int)
     with Import, Convention => C, External_Name => "bridge_store_merge_check";
   procedure Store_Merge_Reset
     with Import, Convention => C, External_Name => "bridge_store_merge_reset";
   procedure Store_Property_Check
     (Doc, Root, First, First_Value, First_Content,
      Second, Second_Value, Second_Content : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_store_property_check";
   function Store_Property_Child (Attribute : System.Address)
      return System.Address
     with Import, Convention => C,
       External_Name => "bridge_store_property_child";
   procedure Store_Standalone_Property_Check
     (Attribute, Value, Content : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_store_standalone_property_check";
   procedure Store_Property_Track_Retired
     (Attribute, Value : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_store_property_track_retired";
   procedure Store_Property_Check_Retired
     with Import, Convention => C,
       External_Name => "bridge_store_property_check_retired";
   procedure Store_No_Namespace_Check
     (Root, Namespaced, Lang, Added : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_store_no_namespace_check";
   procedure Namespace_Track (Block, Facade : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_namespace_track";
   function Namespace_Free_Count return Interfaces.C.unsigned
     with Import, Convention => C,
       External_Name => "bridge_namespace_free_count";
   procedure Namespace_Reset
     with Import, Convention => C,
       External_Name => "bridge_namespace_reset";

   procedure Track
     (Doc_Block, Root_Block, Child_Block, Doc, Root, Child : System.Address)
     with Import, Convention => C, External_Name => "bridge_track";
   procedure Reset_Tracking
   with Import, Convention => C, External_Name => "bridge_reset_tracking";
   procedure Merge_Reset_Tracking
     with Import, Convention => C,
       External_Name => "bridge_merge_reset_tracking";
   procedure Fail_Next_Malloc
     with Import, Convention => C, External_Name => "bridge_fail_next_malloc";
   procedure Constructor_Track
     (Doc_Block, Root_Block, Text_Block, Doc, Root, Text, Ns : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_constructor_track";
   procedure Constructor_Check_Live
     (Doc, Root, Text, Ns : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_constructor_check_live";
   function Constructor_Free_Count (Index : Interfaces.C.unsigned)
      return Interfaces.C.unsigned
     with Import, Convention => C,
       External_Name => "bridge_constructor_free_count";
   procedure Constructor_Reset_Tracking
     with Import, Convention => C,
       External_Name => "bridge_constructor_reset_tracking";
   procedure Merge_Track
     (Target_Block, Source_Content, Source_Block, Old_Content, New_Content,
      Target, Source : System.Address)
     with Import, Convention => C, External_Name => "bridge_merge_track";
   procedure Merge_Check_Initial
     with Import, Convention => C, External_Name => "bridge_merge_check_initial";
   procedure Merge_Check_Pending
     with Import, Convention => C, External_Name => "bridge_merge_check_pending";
   procedure Merge_Check_Target
     with Import, Convention => C, External_Name => "bridge_merge_check_target";
   procedure Check_Live (Doc, Root, Child, Ns : System.Address)
     with Import, Convention => C, External_Name => "bridge_check_live";
   procedure Check_Detached (Doc, Root, Child, Ns : System.Address)
     with Import, Convention => C, External_Name => "bridge_check_detached";
   function Free_Count (Index : Interfaces.C.unsigned) return Interfaces.C.unsigned
     with Import, Convention => C, External_Name => "bridge_free_count";
   function Merge_Free_Count (Index : Interfaces.C.unsigned)
      return Interfaces.C.unsigned
     with Import, Convention => C, External_Name => "bridge_merge_free_count";
   procedure Materialize_Check
     (Doc, Before, Root, Attr, Attr_Value, Lang, Lang_Value,
      Text, CData, Comment, PI, Child,
      Implicit, Default_Ns, Prefix_Ns, Empty_Ns : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_materialize_check";
   procedure Materialize_Track
     (Arena, Doc, Before, Root, Attr, Attr_Value, Lang, Lang_Value,
      Text, CData, Comment, PI, Child,
      Implicit, Default_Ns, Prefix_Ns, Empty_Ns : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_materialize_track";
   procedure Materialize_Check_Retained
     (Root, Attr, Attr_Value, Lang, Lang_Value, Text, CData,
      Comment, PI, Child, Implicit, Default_Ns,
      Prefix_Ns, Empty_Ns : System.Address)
     with Import, Convention => C,
       External_Name => "bridge_materialize_check_retained";
   function Materialize_Free_Count return Interfaces.C.unsigned
     with Import, Convention => C,
       External_Name => "bridge_materialize_free_count";
   procedure Materialize_Reset
     with Import, Convention => C,
       External_Name => "bridge_materialize_reset";

   Version : aliased constant String := "1.0" & Character'Val (0);
   Root_Name : aliased constant String := "r" & Character'Val (0);
   Text_Name : aliased constant String := "text" & Character'Val (0);
   Content : aliased constant String := "x" & Character'Val (0);
   Prefix : aliased constant String := "xml" & Character'Val (0);
   Href : aliased constant String :=
     "http://www.w3.org/XML/1998/namespace" & Character'Val (0);
   Merge_Target_Name : aliased constant String :=
     "target" & Character'Val (0);
   Merge_Source_Name : aliased constant String :=
     "source" & Character'Val (0);
   Merge_Target_Content : aliased constant String :=
     "ab" & Character'Val (0);
   Merge_Source_Content : aliased constant String :=
     "cd" & Character'Val (0);
   Merge_New_Content : aliased constant String :=
     "abcd" & Character'Val (0);
   S : State_Access;
   OK : Boolean;
   Doc_Block, Root_Block, Child_Block : System.Address;
   Doc_Facade, Root_Facade, Child_Facade, Ns_Facade : System.Address;
   Doc, Root, Child : Node_Ref;
   Ns : Namespace_Ref;
   Doc_Owner, Root_Owner, Child_Owner : Owner_Ref;
   Merge_Target_Block, Merge_Source_Block : System.Address;
   Merge_Source_Content_Block, Merge_Old_Content_Block,
     Merge_New_Content_Block : System.Address;
   Merge_Target_Facade, Merge_Source_Facade : System.Address;
   Merge_Target, Merge_Source : Node_Ref;
   Merge_Target_Owner, Merge_Source_Owner, Merge_Source_Content_Owner,
     Merge_Old_Content_Owner, Merge_New_Content_Owner : Owner_Ref;
begin
   Initialize (S, 16, OK);
   pragma Assert (OK);
   Native.Allocate (Native.Node_Stride + Native.Namespace_Stride, Doc_Block);
   Native.Allocate (Native.Node_Stride, Root_Block);
   Native.Allocate (Native.Node_Stride, Child_Block);
   pragma Assert
     (Doc_Block /= System.Null_Address and then Root_Block /= System.Null_Address
      and then Child_Block /= System.Null_Address);
   Doc_Facade := Native.Offset (Doc_Block, Native.Metadata_Bytes);
   Root_Facade := Native.Offset (Root_Block, Native.Metadata_Bytes);
   Child_Facade := Native.Offset (Child_Block, Native.Metadata_Bytes);
   Ns_Facade := Native.Offset (Doc_Block, Native.Node_Stride + Native.Metadata_Bytes);
   Native.Initialize_Node (Doc_Facade);
   Native.Initialize_Node (Root_Facade);
   Native.Initialize_Node (Child_Facade);
   Native.Initialize_Namespace (Ns_Facade);
   Track (Doc_Block, Root_Block, Child_Block, Doc_Facade, Root_Facade, Child_Facade);

   Register_Owner (S.all, Doc_Block, Doc_Owner, OK);
   pragma Assert (OK);
   Register_Node (S.all, Document_Node, Doc_Facade, Doc_Owner, 0, Doc, OK);
   pragma Assert (OK);
   Register_Namespace
     (S.all, Ns_Facade, Href'Address, Href'Length - 1,
      Prefix'Address, Prefix'Length - 1, Doc_Owner, Ns, OK);
   pragma Assert (OK);
   Set_Node_Projection
      (S.all, Doc, System.Null_Address, 0, Version'Address, Version'Length - 1,
      Doc, 0, 0, 0, 0, 0, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Doc_Owner);

   Register_Owner (S.all, Root_Block, Root_Owner, OK);
   pragma Assert (OK);
   Register_Node (S.all, Element_Node, Root_Facade, Root_Owner, 0, Root, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Root, Root_Name'Address, Root_Name'Length - 1,
      System.Null_Address, 0, 0, Ns, Doc_Owner, 0, 0, 0, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Root_Owner);

   Register_Owner (S.all, Child_Block, Child_Owner, OK);
   pragma Assert (OK);
   Register_Node (S.all, Text_Node, Child_Facade, Child_Owner, 0, Child, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Child, Text_Name'Address, Text_Name'Length - 1,
      Content'Address, Content'Length - 1, 0, 0, 0, 0, 0, 0, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Child_Owner);
   Attach_Child (S.all, Root, Child, OK);
   pragma Assert (OK);
   Attach_Child (S.all, Doc, Root, OK);
   pragma Assert (OK);
   pragma Assert (Owner (S.all, Doc_Owner).References = 3);
   XML3_DOM_Bridge.Synchronize (S.all);
   pragma Assert
     (Native.Node_Id (Doc_Facade) = Natural (Doc)
      and then Native.Node_Id (Root_Facade) = Natural (Root)
      and then Native.Node_Id (Child_Facade) = Natural (Child)
      and then Native.Namespace_Id (Ns_Facade) = Natural (Ns));
   Check_Live (Doc_Facade, Root_Facade, Child_Facade, Ns_Facade);

   Unlink (S.all, Root);
   Free_Subtree (S.all, Doc);
   XML3_DOM_Bridge.Synchronize (S.all);
   pragma Assert (Free_Count (0) = 0 and then Free_Count (1) = 0 and then Free_Count (2) = 0);
   pragma Assert (Owner (S.all, Doc_Owner).References = 2);
   Check_Detached (Doc_Facade, Root_Facade, Child_Facade, Ns_Facade);

   Free_Subtree (S.all, Root);
   pragma Assert (Free_Count (0) = 0 and then Free_Count (1) = 0 and then Free_Count (2) = 0);
   XML3_DOM_Bridge.Synchronize (S.all);
   pragma Assert (Free_Count (0) = 1 and then Free_Count (1) = 1 and then Free_Count (2) = 1);
   XML3_DOM_Bridge.Synchronize (S.all);
   pragma Assert (Free_Count (0) = 1 and then Free_Count (1) = 1 and then Free_Count (2) = 1);
   XML3_DOM_Allocation.Free_State (S);
   Reset_Tracking;

   Initialize (S, 16, OK);
   pragma Assert (OK);
   Native.Allocate (Native.Node_Stride, Merge_Target_Block);
   Native.Allocate (Native.Node_Stride, Merge_Source_Block);
   Native.Allocate
     (Native.Byte_Count (Merge_Target_Content'Length), Merge_Old_Content_Block);
   Native.Allocate
     (Native.Byte_Count (Merge_Source_Content'Length),
      Merge_Source_Content_Block);
   Native.Allocate
     (Native.Byte_Count (Merge_New_Content'Length), Merge_New_Content_Block);
   pragma Assert
     (Merge_Target_Block /= System.Null_Address
      and then Merge_Source_Block /= System.Null_Address
      and then Merge_Old_Content_Block /= System.Null_Address
      and then Merge_Source_Content_Block /= System.Null_Address
      and then Merge_New_Content_Block /= System.Null_Address);
   Merge_Target_Facade :=
     Native.Offset (Merge_Target_Block, Native.Metadata_Bytes);
   Merge_Source_Facade :=
     Native.Offset (Merge_Source_Block, Native.Metadata_Bytes);
   Native.Initialize_Node (Merge_Target_Facade);
   Native.Initialize_Node (Merge_Source_Facade);
   Native.Write_String (Merge_Old_Content_Block, 0, Merge_Target_Content);
   Native.Write_String
     (Merge_Source_Content_Block, 0, Merge_Source_Content);
   Native.Write_String (Merge_New_Content_Block, 0, Merge_New_Content);
   Merge_Track
     (Merge_Target_Block, Merge_Source_Content_Block, Merge_Source_Block,
      Merge_Old_Content_Block, Merge_New_Content_Block,
      Merge_Target_Facade, Merge_Source_Facade);

   Register_Owner (S.all, Merge_Target_Block, Merge_Target_Owner, OK);
   pragma Assert (OK);
   Register_Owner
     (S.all, Merge_Source_Content_Block, Merge_Source_Content_Owner, OK);
   pragma Assert (OK);
   Register_Owner (S.all, Merge_Source_Block, Merge_Source_Owner, OK);
   pragma Assert (OK);
   Register_Owner
     (S.all, Merge_Old_Content_Block, Merge_Old_Content_Owner, OK);
   pragma Assert (OK);
   Register_Owner
     (S.all, Merge_New_Content_Block, Merge_New_Content_Owner, OK);
   pragma Assert (OK);
   Register_Node
     (S.all, Text_Node, Merge_Target_Facade, Merge_Target_Owner, 0,
      Merge_Target, OK);
   pragma Assert (OK);
   Register_Node
     (S.all, Text_Node, Merge_Source_Facade, Merge_Source_Owner, 0,
      Merge_Source, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Merge_Target, Merge_Target_Name'Address,
      Merge_Target_Name'Length - 1, Merge_Old_Content_Block,
      Merge_Target_Content'Length - 1, 0, 0, 0, 0,
      Merge_Old_Content_Owner, 0, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Merge_Source, Merge_Source_Name'Address,
      Merge_Source_Name'Length - 1, Merge_Source_Content_Block,
      Merge_Source_Content'Length - 1, 0, 0, 0, 0,
      Merge_Source_Content_Owner, 0, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Merge_Target_Owner);
   Release_Reservation (S.all, Merge_Source_Owner);
   Release_Reservation (S.all, Merge_Source_Content_Owner);
   Release_Reservation (S.all, Merge_Old_Content_Owner);
   XML3_DOM_Bridge.Synchronize (S.all);
   Merge_Check_Initial;
   Merge_Text
     (S.all, Merge_Target, Merge_Source, Merge_New_Content_Block,
      Merge_New_Content'Length - 1, Merge_New_Content_Owner, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Merge_New_Content_Owner);
   pragma Assert
     (Merge_Free_Count (0) = 0
      and then Merge_Free_Count (1) = 0
      and then Merge_Free_Count (2) = 0
      and then Merge_Free_Count (3) = 0
      and then Merge_Free_Count (4) = 0);
   Merge_Check_Pending;
   XML3_DOM_Bridge.Synchronize (S.all);
   Merge_Check_Target;
   pragma Assert
     (Merge_Free_Count (0) = 0
      and then Merge_Free_Count (1) = 1
      and then Merge_Free_Count (2) = 1
      and then Merge_Free_Count (3) = 1
      and then Merge_Free_Count (4) = 0);
   Free_Subtree (S.all, Merge_Target);
   XML3_DOM_Bridge.Synchronize (S.all);
   pragma Assert
     (Merge_Free_Count (0) = 1
      and then Merge_Free_Count (1) = 1
      and then Merge_Free_Count (2) = 1
      and then Merge_Free_Count (3) = 1
      and then Merge_Free_Count (4) = 1);
   XML3_DOM_Bridge.Synchronize (S.all);
   pragma Assert
     (Merge_Free_Count (0) = 1
      and then Merge_Free_Count (1) = 1
      and then Merge_Free_Count (2) = 1
      and then Merge_Free_Count (3) = 1
      and then Merge_Free_Count (4) = 1);
   XML3_DOM_Allocation.Free_State (S);
   Merge_Reset_Tracking;

   Initialize (S, 1, OK);
   pragma Assert (OK);
   declare
      use XML3_DOM_Constructors;
      Doc_N, Root_N, Text_N : Node_Ref;
      Bad_N : Node_Ref;
      Previous : Node_Ref;
      Xml_Ns, Ignored_Ns, Bad_Ns : Namespace_Ref;
      Build_Status : Construction_Status;
      Attach_OK : Boolean;
      Before_Nodes : constant Natural := Node_Count (S.all);
      Before_Doc, Before_Root, Before_Text : Node_View;
   begin
      Create_Node
        (S, Document_Node, "ignored", "1.0", True, Null_Namespace,
         Doc_N, Xml_Ns, Build_Status);
      pragma Assert (Build_Status = Created);
      Create_Node
        (S, Element_Node, "r", "", False, Xml_Ns,
         Root_N, Ignored_Ns, Build_Status);
      pragma Assert (Build_Status = Created);
      Create_Node
        (S, Text_Node, "text", "x", True, Null_Namespace,
         Text_N, Ignored_Ns, Build_Status);
      pragma Assert (Build_Status = Created);
      pragma Assert (Node_Count (S.all) = Before_Nodes + 3);
      pragma Assert
        (Node (S.all, Doc_N).Document = Doc_N
         and then Node (S.all, Doc_N).Namespace = Null_Namespace
         and then Namespace (S.all, Xml_Ns).Owner = Node (S.all, Doc_N).Owner
         and then Node (S.all, Root_N).Namespace = Xml_Ns
         and then Node (S.all, Root_N).Ns_Pin = Node (S.all, Doc_N).Owner);
      Attach_Child (S.all, Root_N, Text_N, Attach_OK);
      pragma Assert (Attach_OK);
      Replace_Root (S.all, Doc_N, Root_N, Previous, Attach_OK);
      pragma Assert (Attach_OK);
      XML3_DOM_Bridge.Synchronize (S.all);
      Constructor_Track
        (Owner (S.all, Node (S.all, Doc_N).Owner).Address,
         Owner (S.all, Node (S.all, Root_N).Owner).Address,
         Owner (S.all, Node (S.all, Text_N).Owner).Address,
         Node (S.all, Doc_N).Facade,
         Node (S.all, Root_N).Facade,
         Node (S.all, Text_N).Facade,
         Namespace (S.all, Xml_Ns).Facade);
      pragma Assert (Capacity_Of (S.all) = 4);
      Constructor_Check_Live
        (Node (S.all, Doc_N).Facade, Node (S.all, Root_N).Facade,
         Node (S.all, Text_N).Facade, Namespace (S.all, Xml_Ns).Facade);
      Before_Doc := Node (S.all, Doc_N);
      Before_Root := Node (S.all, Root_N);
      Before_Text := Node (S.all, Text_N);
      Create_Node
        (S, Text_Node, "bad", "y", True, Xml_Ns,
         Bad_N, Bad_Ns, Build_Status);
      pragma Assert
        (Build_Status = Invalid_Argument
         and then Bad_N = Null_Node
         and then Bad_Ns = Null_Namespace
        and then Node (S.all, Doc_N) = Before_Doc
        and then Node (S.all, Root_N) = Before_Root
        and then Node (S.all, Text_N) = Before_Text
        and then Constructor_Free_Count (0) = 0
        and then Constructor_Free_Count (1) = 0
        and then Constructor_Free_Count (2) = 0);
      Fail_Next_Malloc;
      Create_Node
        (S, Text_Node, "bad", "y", True, Null_Namespace,
         Bad_N, Bad_Ns, Build_Status);
      pragma Assert
        (Build_Status = No_Memory
         and then Bad_N = Null_Node
         and then Bad_Ns = Null_Namespace
         and then Node (S.all, Doc_N) = Before_Doc
         and then Node (S.all, Root_N) = Before_Root
         and then Node (S.all, Text_N) = Before_Text
         and then Constructor_Free_Count (0) = 0
         and then Constructor_Free_Count (1) = 0
         and then Constructor_Free_Count (2) = 0);
      Unlink (S.all, Root_N);
      Free_Subtree (S.all, Doc_N);
      XML3_DOM_Bridge.Synchronize (S.all);
      pragma Assert
        (Constructor_Free_Count (0) = 0
         and then Constructor_Free_Count (1) = 0
         and then Constructor_Free_Count (2) = 0);
      Check_Detached
        (Node (S.all, Doc_N).Facade, Node (S.all, Root_N).Facade,
         Node (S.all, Text_N).Facade, Namespace (S.all, Xml_Ns).Facade);
      Free_Subtree (S.all, Root_N);
      XML3_DOM_Bridge.Synchronize (S.all);
      pragma Assert
        (Constructor_Free_Count (0) = 1
         and then Constructor_Free_Count (1) = 1
         and then Constructor_Free_Count (2) = 1);
      Constructor_Reset_Tracking;
   end;
   XML3_DOM_Allocation.Free_State (S);
   Ada.Text_IO.Put_Line ("Native DOM projection, pin lifetime, and release ordering tests passed");

   declare
      package Stores renames XML3_DOM_Store;
      use XML3_DOM_Constructors;
      Managed : Stores.Store;
      Doc, Root, Text, Xml_Ns, Ignored, Previous, Rejected : System.Address;
      Status : Stores.Operation_Status;
      Item, Before_Root : Node_View;
      Found : Boolean;
   begin
      pragma Assert (Stores.Is_Empty (Managed));
      Stores.Construct
        (Managed, Document_Node, "", "1.0", True, System.Null_Address,
         Doc, Xml_Ns, Status);
      pragma Assert (Status = Created);
      Stores.Construct
        (Managed, Element_Node, "r", "", False, Xml_Ns,
         Root, Ignored, Status);
      pragma Assert (Status = Created);
      Stores.Construct
        (Managed, Text_Node, "text", "x", True, System.Null_Address,
         Text, Ignored, Status);
      pragma Assert (Status = Created);
      Stores.Attach (Managed, Root, Text, False, Status);
      pragma Assert (Status = Created);
      Stores.Set_Root (Managed, Doc, Root, Previous, Status);
      pragma Assert (Status = Created and then Previous = System.Null_Address);
      Constructor_Check_Live (Doc, Root, Text, Xml_Ns);
      Stores.Inspect (Managed, Root, Before_Root, Found);
      pragma Assert (Found);

      Stores.Construct
        (Managed, Element_Node, "bad", "", False, Doc,
         Rejected, Ignored, Status);
      pragma Assert (Status = Invalid_Argument and then Rejected = System.Null_Address);
      Fail_Next_Malloc;
      Stores.Construct
        (Managed, Text_Node, "text", "y", True, System.Null_Address,
         Rejected, Ignored, Status);
      pragma Assert (Status = No_Memory and then Rejected = System.Null_Address);
      Stores.Inspect (Managed, Root, Item, Found);
      pragma Assert (Found and then Item = Before_Root);

      Stores.Unlink (Managed, Root, Status);
      pragma Assert (Status = Created);
      Stores.Release (Managed, Doc, Stores.Document_Only, False, Status);
      pragma Assert (Status = Created and then not Stores.Is_Empty (Managed));
      Check_Detached (Doc, Root, Text, Xml_Ns);
      Stores.Inspect (Managed, Doc, Item, Found);
      pragma Assert (not Found);
      Stores.Inspect (Managed, Root, Item, Found);
      pragma Assert (Found);
      Stores.Release (Managed, Root, Stores.Content_Node, False, Status);
      pragma Assert (Status = Created and then Stores.Is_Empty (Managed));
      Stores.Inspect (Managed, System.Null_Address, Item, Found);
      pragma Assert (not Found);
   end;
   Ada.Text_IO.Put_Line ("Opaque DOM store lifecycle tests passed");

   declare
      package Stores renames XML3_DOM_Store;
      use XML3_DOM_Constructors;
      Managed : Stores.Store;
      Root, Target, Source, Ignored, Result : System.Address;
      Status : Stores.Operation_Status;
      Before_Root, Before_Target, Before_Source, Item : Node_View;
      Found : Boolean;
   begin
      Stores.Construct
        (Managed, Element_Node, "r", "", False, System.Null_Address,
         Root, Ignored, Status);
      pragma Assert (Status = Created);
      Stores.Construct
        (Managed, Text_Node, "text", "ab", True, System.Null_Address,
         Target, Ignored, Status);
      pragma Assert (Status = Created);
      Stores.Construct
        (Managed, Text_Node, "text", "cd", True, System.Null_Address,
         Source, Ignored, Status);
      pragma Assert (Status = Created);
      Stores.Add_Child (Managed, Root, Target, Result, Status);
      pragma Assert (Status = Created and then Result = Target);
      Store_Merge_Track (Root, Target, Source);
      Store_Merge_Check (0);
      Stores.Inspect (Managed, Root, Before_Root, Found);
      pragma Assert (Found);
      Stores.Inspect (Managed, Target, Before_Target, Found);
      pragma Assert (Found);
      Stores.Inspect (Managed, Source, Before_Source, Found);
      pragma Assert (Found);

      Fail_Next_Malloc;
      Stores.Add_Child (Managed, Root, Source, Result, Status);
      pragma Assert (Status = No_Memory and then Result = System.Null_Address);
      Stores.Inspect (Managed, Root, Item, Found);
      pragma Assert (Found and then Item = Before_Root);
      Stores.Inspect (Managed, Target, Item, Found);
      pragma Assert (Found and then Item = Before_Target);
      Stores.Inspect (Managed, Source, Item, Found);
      pragma Assert (Found and then Item = Before_Source);
      Store_Merge_Check (0);

      Stores.Add_Child (Managed, Root, Source, Result, Status);
      pragma Assert (Status = Created and then Result = Target);
      Store_Merge_Check (1);
      Stores.Add_Child (Managed, Root, Target, Result, Status);
      pragma Assert (Status = Created and then Result = Target);
      Store_Merge_Check (1);
      Store_Merge_Reset;
      Stores.Release (Managed, Root, Stores.Content_Node, False, Status);
      pragma Assert (Status = Created and then Stores.Is_Empty (Managed));
   end;
   Ada.Text_IO.Put_Line ("Opaque DOM store text merge and rollback tests passed");
   declare
      package Stores renames XML3_DOM_Store;
      package Properties renames XML3_DOM_Store.Properties;
      use type XML3_DOM_Constructors.Construction_Status;
      Managed : Stores.Store;
      Doc, Root, Ignored, First, Duplicate, Returned, Standalone :
        System.Address := System.Null_Address;
      First_Value, Duplicate_Value, New_Value, Empty_Value :
        System.Address := System.Null_Address;
      Status : Stores.Operation_Status;
      First_View, First_Value_View, Duplicate_View, Duplicate_Value_View,
        Item : Node_View;
      Found : Boolean;
      Original_Content : aliased constant String :=
        "original&amp;<" & Character'Val (0);
      Duplicate_Content : aliased constant String :=
        "duplicate" & Character'Val (0);
      Updated_Content : aliased constant String :=
        "updated" & Character'Val (0);
      Empty_Content : aliased constant String := Character'Val (0) & "";
      Standalone_Content : aliased constant String :=
        "standalone" & Character'Val (0);
      procedure Fail_Malloc_Nth (Nth : Interfaces.C.unsigned)
        with Import, Convention => C,
          External_Name => "bridge_fail_malloc_nth";
      procedure Check_Malloc_Failure
        with Import, Convention => C,
          External_Name => "bridge_check_malloc_failure";
   begin
      Stores.Construct
        (Managed, Document_Node, "", "1.0", True, System.Null_Address,
         Doc, Ignored, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);
      Stores.Construct
        (Managed, Element_Node, "r", "", False, System.Null_Address,
         Root, Ignored, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);
      Stores.Attach (Managed, Doc, Root, False, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);

      Properties.Create_Property
        (Managed, Root, "item", "original&amp;<", True, First, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then First /= System.Null_Address);
      Properties.Create_Property
        (Managed, Root, "item", "duplicate", True, Duplicate, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Duplicate /= System.Null_Address
         and then Duplicate /= First);
      First_Value := Store_Property_Child (First);
      Duplicate_Value := Store_Property_Child (Duplicate);
      pragma Assert
        (First_Value /= System.Null_Address
         and then Duplicate_Value /= System.Null_Address);
      Store_Property_Check
        (Doc, Root, First, First_Value, Original_Content'Address,
         Duplicate, Duplicate_Value, Duplicate_Content'Address);

      Fail_Malloc_Nth (Interfaces.C.unsigned'(2));
      Properties.Create_Property
        (Managed, Root, "unpublished", "failure", True, Returned, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.No_Memory
         and then Returned = System.Null_Address);
      Check_Malloc_Failure;
      Store_Property_Check
        (Doc, Root, First, First_Value, Original_Content'Address,
         Duplicate, Duplicate_Value, Duplicate_Content'Address);

      Stores.Inspect (Managed, First, First_View, Found);
      pragma Assert (Found);
      Stores.Inspect (Managed, First_Value, First_Value_View, Found);
      pragma Assert (Found);
      Stores.Inspect (Managed, Duplicate, Duplicate_View, Found);
      pragma Assert (Found);
      Stores.Inspect (Managed, Duplicate_Value, Duplicate_Value_View, Found);
      pragma Assert (Found);

      Fail_Next_Malloc;
      Properties.Set_Property
        (Managed, Root, "item", "blocked", True, Returned, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.No_Memory
         and then Returned = System.Null_Address);
      Stores.Inspect (Managed, First, Item, Found);
      pragma Assert (Found and then Item = First_View);
      Stores.Inspect (Managed, First_Value, Item, Found);
      pragma Assert (Found and then Item = First_Value_View);
      Stores.Inspect (Managed, Duplicate, Item, Found);
      pragma Assert (Found and then Item = Duplicate_View);
      Stores.Inspect (Managed, Duplicate_Value, Item, Found);
      pragma Assert (Found and then Item = Duplicate_Value_View);
      Store_Property_Check
        (Doc, Root, First, First_Value, Original_Content'Address,
         Duplicate, Duplicate_Value, Duplicate_Content'Address);

      Store_Property_Track_Retired (First, First_Value);
      Properties.Set_Property
        (Managed, Root, "item", "updated", True, Returned, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created and then Returned = First);
      Store_Property_Check_Retired;
      New_Value := Store_Property_Child (First);
      pragma Assert
        (New_Value /= System.Null_Address and then New_Value /= First_Value);
      Stores.Inspect (Managed, First, Item, Found);
      pragma Assert
        (Found and then Item.Facade = First_View.Facade
         and then Item.Parent = First_View.Parent
         and then Item.Previous = First_View.Previous
         and then Item.Next = First_View.Next);
      Stores.Inspect (Managed, New_Value, Item, Found);
      pragma Assert
        (Found and then Item.Kind = Text_Node and then Item.Content_Length = 7);
      Stores.Inspect (Managed, Duplicate, Item, Found);
      pragma Assert (Found and then Item = Duplicate_View);
      Stores.Inspect (Managed, Duplicate_Value, Item, Found);
      pragma Assert (Found and then Item = Duplicate_Value_View);
      Store_Property_Check
        (Doc, Root, First, New_Value, Updated_Content'Address,
         Duplicate, Duplicate_Value, Duplicate_Content'Address);

      Properties.Set_Property
        (Managed, Root, "item", "", False, Returned, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created and then Returned = First);
      Store_Property_Check
        (Doc, Root, First, System.Null_Address, System.Null_Address,
         Duplicate, Duplicate_Value, Duplicate_Content'Address);

      Properties.Set_Property
        (Managed, Root, "item", "", True, Returned, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created and then Returned = First);
      Empty_Value := Store_Property_Child (First);
      pragma Assert (Empty_Value /= System.Null_Address);
      Stores.Inspect (Managed, Empty_Value, Item, Found);
      pragma Assert
        (Found and then Item.Kind = Text_Node
         and then Item.Content_Length = 0
         and then Item.Content /= System.Null_Address);
      Store_Property_Check
        (Doc, Root, First, Empty_Value, Empty_Content'Address,
         Duplicate, Duplicate_Value, Duplicate_Content'Address);

      Stores.Release
        (Managed, First, Stores.Plain_Attribute, True, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);
      Store_Property_Check
        (Doc, Root, Duplicate, Duplicate_Value, Duplicate_Content'Address,
         System.Null_Address, System.Null_Address, System.Null_Address);
      Stores.Release
        (Managed, Duplicate, Stores.Plain_Attribute, True, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);
      Store_Property_Check
        (Doc, Root, System.Null_Address, System.Null_Address,
         System.Null_Address, System.Null_Address, System.Null_Address,
         System.Null_Address);

      Properties.Create_Property
        (Managed, System.Null_Address, "standalone", "standalone", True,
         Standalone, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Standalone /= System.Null_Address);
      New_Value := Store_Property_Child (Standalone);
      pragma Assert (New_Value /= System.Null_Address);
      Store_Standalone_Property_Check
        (Standalone, New_Value, Standalone_Content'Address);
      Stores.Release
        (Managed, Standalone, Stores.Plain_Attribute, False, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);
      Stores.Release
        (Managed, Doc, Stores.Document_Only, False, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Stores.Is_Empty (Managed));
   end;
   Ada.Text_IO.Put_Line ("Store property creation, replacement, and rollback tests passed");
   declare
      package Importer renames XML3_DOM.Import;
      use type Importer.Import_Status;
      Source, Destination, Tiny : State_Access;
      Arena, Original_Block, Spare_Block : System.Address;
      Arena_Doc, Arena_Root, Arena_Text, Arena_Ns, Original_Facade,
        Spare_Facade, Spare_Ns_Facade : System.Address;
      Version_At, Name_At, Text_Name_At, Content_At, Prefix_At, Href_At : System.Address;
      Arena_Owner, Original_Owner, Spare_Owner : Owner_Ref;
      Source_Doc, Source_Root, Source_Text, Original, Spare, Imported_Doc : Node_Ref;
      Source_Ns, Spare_Ns : Namespace_Ref;
      Status : Importer.Import_Status;
      Payload : constant Native.Byte_Count := 3 * Native.Node_Stride + Native.Namespace_Stride;
      Strings : constant String := Version & Root_Name & Text_Name & Content & Prefix & Href;
      subtype Map_Block is XML3_DOM_Allocation.Import_Maps (3);

      procedure Import_Track
        (Arena, Doc, Root, Text, Ns, Original : System.Address)
        with Import, Convention => C, External_Name => "bridge_import_track";
      procedure Import_Check_Live
        with Import, Convention => C, External_Name => "bridge_import_check_live";
      procedure Import_Check_Retained
        with Import, Convention => C, External_Name => "bridge_import_check_retained";
      procedure Import_Reset
        with Import, Convention => C, External_Name => "bridge_import_reset";
      function Import_Free_Count return Interfaces.C.unsigned
        with Import, Convention => C, External_Name => "bridge_import_free_count";
      procedure Import_Fail_Allocation (Size : Interfaces.C.size_t)
        with Import, Convention => C, External_Name => "bridge_import_fail_allocation";
      procedure Import_Check_Allocation_Failure
        with Import, Convention => C, External_Name => "bridge_import_check_allocation_failure";
   begin
      Initialize (Source, 4, OK);
      pragma Assert (OK);
      Initialize (Destination, 8, OK);
      pragma Assert (OK);
      Initialize (Tiny, 2, OK);
      pragma Assert (OK);
      Native.Allocate (Payload + Native.Byte_Count (Strings'Length), Arena);
      Native.Allocate (Native.Node_Stride, Original_Block);
      Native.Allocate (Native.Node_Stride + Native.Namespace_Stride, Spare_Block);
      pragma Assert (Arena /= System.Null_Address and then Original_Block /= System.Null_Address
                     and then Spare_Block /= System.Null_Address);
      Arena_Doc := Native.Offset (Arena, Native.Metadata_Bytes);
      Arena_Root := Native.Offset (Arena, Native.Node_Stride + Native.Metadata_Bytes);
      Arena_Text := Native.Offset (Arena, 2 * Native.Node_Stride + Native.Metadata_Bytes);
      Arena_Ns := Native.Offset (Arena, 3 * Native.Node_Stride + Native.Metadata_Bytes);
      Original_Facade := Native.Offset (Original_Block, Native.Metadata_Bytes);
      Spare_Facade := Native.Offset (Spare_Block, Native.Metadata_Bytes);
      Spare_Ns_Facade := Native.Offset (Spare_Block, Native.Node_Stride + Native.Metadata_Bytes);
      Native.Initialize_Node (Arena_Doc);
      Native.Initialize_Node (Arena_Root);
      Native.Initialize_Node (Arena_Text);
      Native.Initialize_Namespace (Arena_Ns);
      Native.Initialize_Node (Original_Facade);
      Native.Initialize_Node (Spare_Facade);
      Native.Initialize_Namespace (Spare_Ns_Facade);
      Version_At := Native.Offset (Arena, Payload);
      Native.Write_String (Version_At, 0, Strings);
      Name_At := Native.Offset (Version_At, Version'Length);
      Text_Name_At := Native.Offset (Name_At, Root_Name'Length);
      Content_At := Native.Offset (Text_Name_At, Text_Name'Length);
      Prefix_At := Native.Offset (Content_At, Content'Length);
      Href_At := Native.Offset (Prefix_At, Prefix'Length);

      Register_Owner (Source.all, Arena, Arena_Owner, OK);
      pragma Assert (OK and then Arena_Owner = 1);
      Register_Node (Source.all, Document_Node, Arena_Doc, Arena_Owner, 0, Source_Doc, OK);
      pragma Assert (OK and then Source_Doc = 1);
      Register_Node (Source.all, Element_Node, Arena_Root, Arena_Owner, 0, Source_Root, OK);
      pragma Assert (OK and then Source_Root = 2);
      Register_Node (Source.all, Text_Node, Arena_Text, Arena_Owner, 0, Source_Text, OK);
      pragma Assert (OK and then Source_Text = 3);
      Register_Namespace
        (Source.all, Arena_Ns, Href_At, Href'Length - 1,
         Prefix_At, Prefix'Length - 1, Arena_Owner, Source_Ns, OK);
      pragma Assert (OK and then Source_Ns = 1);
      Set_Node_Projection
        (Source.all, Source_Doc, System.Null_Address, 0,
         Version_At, Version'Length - 1, Source_Doc, 0, 0, 0, 0, 0, OK);
      pragma Assert (OK);
      Set_Node_Projection
        (Source.all, Source_Root, Name_At, Root_Name'Length - 1,
         System.Null_Address, 0, 0, Source_Ns, Arena_Owner, 0, 0, 0, OK);
      pragma Assert (OK);
      Set_Node_Projection
        (Source.all, Source_Text, Text_Name_At, Text_Name'Length - 1,
         Content_At, Content'Length - 1, 0, 0, 0, 0, 0, 0, OK);
      pragma Assert (OK);
      Attach_Child (Source.all, Source_Root, Source_Text, OK);
      pragma Assert (OK);
      Attach_Child (Source.all, Source_Doc, Source_Root, OK);
      pragma Assert (OK);
      Release_Reservation (Source.all, Arena_Owner);
      XML3_DOM_Bridge.Synchronize (Source.all);
      pragma Assert (Importer.Is_Arena (Source.all));

      Register_Owner (Destination.all, Original_Block, Original_Owner, OK);
      pragma Assert (OK);
      Register_Node
        (Destination.all, Document_Node, Original_Facade, Original_Owner, 0, Original, OK);
      pragma Assert (OK and then Original = 1);
      Set_Node_Projection
        (Destination.all, Original, System.Null_Address, 0,
         Version'Address, Version'Length - 1, Original, 0, 0, 0, 0, 0, OK);
      pragma Assert (OK);
      Release_Reservation (Destination.all, Original_Owner);
      Register_Owner (Destination.all, Spare_Block, Spare_Owner, OK);
      pragma Assert (OK and then Spare_Owner = 2);
      Register_Node
        (Destination.all, Element_Node, Spare_Facade, Spare_Owner, 0, Spare, OK);
      pragma Assert (OK and then Spare = 2);
      Register_Namespace
        (Destination.all, Spare_Ns_Facade, Href'Address, Href'Length - 1,
         Prefix'Address, Prefix'Length - 1, Spare_Owner, Spare_Ns, OK);
      pragma Assert (OK and then Spare_Ns = 1);
      Release_Reservation (Destination.all, Spare_Owner);
      Free_Subtree (Destination.all, Spare);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      pragma Assert (Node (Destination.all, Spare).State = Unused
                     and then Owner (Destination.all, Spare_Owner).State = Unused
                     and then Namespace (Destination.all, Spare_Ns).State = Unused);
      Import_Track (Arena, Arena_Doc, Arena_Root, Arena_Text, Arena_Ns, Original_Facade);

      declare
         Original_Source : constant State_Access := Source;
         Before_Source : constant State := Source.all;
         Before_Tiny : constant State := Tiny.all;
         Before_Destination : constant State := Destination.all;
      begin
         Importer.Adopt (Tiny.all, Source, Imported_Doc, Status);
         pragma Assert (Status = Importer.Limit_Exceeded and then Imported_Doc = 0);
         pragma Assert (Source = Original_Source and then Same_Graph (Source.all, Before_Source));
         pragma Assert (Same_Graph (Tiny.all, Before_Tiny) and then Import_Free_Count = 0);
         Import_Fail_Allocation (Interfaces.C.size_t (Map_Block'Size / System.Storage_Unit));
         Importer.Adopt (Destination.all, Source, Imported_Doc, Status);
         Import_Check_Allocation_Failure;
         pragma Assert (Status = Importer.No_Memory and then Imported_Doc = 0);
         pragma Assert (Source = Original_Source and then Same_Graph (Source.all, Before_Source));
         pragma Assert (Same_Graph (Destination.all, Before_Destination)
                        and then Import_Free_Count = 0);
         Importer.Adopt (Destination.all, Source, Imported_Doc, Status);
         pragma Assert (Status = Importer.Imported and then Source = null and then Imported_Doc = 2);
         pragma Assert (Node (Destination.all, Original) = Node (Before_Destination, Original));
      end;
      pragma Assert (Import_Free_Count = 0);
      pragma Assert (Node (Destination.all, 2).Owner = Spare_Owner
                     and then Node (Destination.all, 3).Facade = Arena_Root
                     and then Node (Destination.all, 4).Facade = Arena_Text
                     and then Namespace (Destination.all, Spare_Ns).Facade = Arena_Ns);
      pragma Assert (Native.Node_Id (Arena_Doc) = 1);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      Import_Check_Live;
      Unlink (Destination.all, 3);
      Free_Subtree (Destination.all, Imported_Doc);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      Import_Check_Retained;
      pragma Assert (Import_Free_Count = 0);
      Free_Subtree (Destination.all, 3);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      pragma Assert (Import_Free_Count = 1);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      pragma Assert (Import_Free_Count = 1);
      Import_Reset;
      Free_Subtree (Destination.all, Original);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      XML3_DOM_Allocation.Free_State (Destination);
      XML3_DOM_Allocation.Free_State (Tiny);
   end;
   declare
      use type XML3_Parser.Parse_Status;
      use type XML3_DOM_Constructors.Construction_Status;
      use type XML3_DOM.Import.Import_Status;
      Input : constant String :=
        "<?before x?><r xmlns=""urn:d"" xmlns:p=""urn:p"" p:a=""A&amp;B"" xml:lang=""ja"">one<![CDATA[two]]><!--c--><?pi x?><p:c xmlns=""""/></r>";
      Scratch, Scratch_B : String (1 .. Input'Length) := (others => ' ');
      Parsed_Nodes : XML3_Parser.Node_Array (1 .. 64);
      Parsed_Names : XML3_Namespaces.Name_Array (1 .. 64);
      Count, Parser_Root : XML3_Parser.Node_Id;
      Parse_Status, Resolve_Status : XML3_Parser.Parse_Status;
      Parse_Diag, Resolve_Diag : XML3_Parser.Diagnostic_Info;
      Source, Destination : State_Access := null;
      Build_Status : XML3_DOM_Constructors.Construction_Status;
      Import_Status : XML3_DOM.Import.Import_Status;
      Destination_Doc, Imported_Doc, Imported_Root : Node_Ref;
      Destination_Ns : Namespace_Ref;
      Destination_Doc_Before : Node_View;
      N1, N2, N3, N4, N5, N6, N7, N8, N9, N10, N11, N12 : Node_Ref;
      procedure Fail_Malloc_Nth (Nth : Interfaces.C.unsigned)
        with Import, Convention => C,
          External_Name => "bridge_fail_malloc_nth";
      procedure Check_Malloc_Failure
        with Import, Convention => C,
          External_Name => "bridge_check_malloc_failure";
      procedure Begin_Malloc_Tracking
        with Import, Convention => C,
          External_Name => "bridge_begin_malloc_tracking";
      procedure End_Malloc_Tracking
        with Import, Convention => C,
          External_Name => "bridge_end_malloc_tracking";
   begin
      XML3_Parser.Parse
        (Input, Scratch, Parsed_Nodes, Count, Parser_Root, Parse_Status,
         False, Parse_Diag);
      pragma Assert (Parse_Status = XML3_Parser.Success);
      XML3_Namespaces.Resolve
        (Input, Parsed_Nodes, Count, Parsed_Names, Scratch, Scratch_B,
         Resolve_Status, Resolve_Diag);
      pragma Assert (Resolve_Status = XML3_Parser.Success);
      Initialize (Destination, 32, OK);
      pragma Assert (OK);
      XML3_DOM_Constructors.Create_Node
        (Destination, Document_Node, "", "", False, 0, Destination_Doc,
         Destination_Ns, Build_Status);
      pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
      Destination_Doc_Before := Node (Destination.all, Destination_Doc);
      declare
         Before_Destination : constant State := Destination.all;
      begin
         for Nth in 1 .. 3 loop
            Fail_Malloc_Nth (Interfaces.C.unsigned (Nth));
            XML3_DOM.Materialize.Build
              (Input, Parsed_Nodes, Count, Parsed_Names, Scratch, Source,
               Build_Status);
            Check_Malloc_Failure;
            pragma Assert
              (Build_Status = XML3_DOM_Constructors.No_Memory
               and then Source = null
               and then Same_Graph (Destination.all, Before_Destination));
         end loop;
         declare
         Valid_Binding : constant XML3_Namespaces.Binding_Id :=
              Parsed_Names (5).Binding;
         begin
            Parsed_Names (5).Binding := 1;
            Begin_Malloc_Tracking;
            XML3_DOM.Materialize.Build
              (Input, Parsed_Nodes, Count, Parsed_Names, Scratch, Source,
               Build_Status);
            End_Malloc_Tracking;
            pragma Assert
              (Build_Status = XML3_DOM_Constructors.Internal_Error
               and then Source = null
               and then Same_Graph (Destination.all, Before_Destination));
            Parsed_Names (5).Binding := Valid_Binding;
         end;
      end;
      XML3_DOM.Materialize.Build
        (Input, Parsed_Nodes, Count, Parsed_Names, Scratch, Source,
         Build_Status);
      pragma Assert
        (Build_Status = XML3_DOM_Constructors.Created
         and then Source /= null
         and then Node_Count (Source.all) = 12
         and then Namespace_Count (Source.all) = 4);
      XML3_DOM.Import.Adopt
        (Destination.all, Source, Imported_Doc, Import_Status);
      pragma Assert
        (Import_Status = XML3_DOM.Import.Imported and then Source = null);
      Imported_Root :=
        Node (Destination.all,
              Node (Destination.all, Imported_Doc).First_Child).Next;
      XML3_DOM_Bridge.Synchronize (Destination.all);
      N1 := 2; N2 := 3; N3 := 4; N4 := 5; N5 := 6; N6 := 7;
      N7 := 8; N8 := 9; N9 := 10; N10 := 11; N11 := 12; N12 := 13;
      Materialize_Check
        (Node (Destination.all, N1).Facade,
         Node (Destination.all, N2).Facade,
         Node (Destination.all, N3).Facade,
         Node (Destination.all, N4).Facade,
         Node (Destination.all, N5).Facade,
         Node (Destination.all, N6).Facade,
         Node (Destination.all, N7).Facade,
         Node (Destination.all, N8).Facade,
         Node (Destination.all, N9).Facade,
         Node (Destination.all, N10).Facade,
         Node (Destination.all, N11).Facade,
         Node (Destination.all, N12).Facade,
         Namespace (Destination.all, 2).Facade,
         Namespace (Destination.all, 3).Facade,
         Namespace (Destination.all, 4).Facade,
         Namespace (Destination.all, 5).Facade);
      pragma Assert (Imported_Root = N3);
      Materialize_Track
        (Owner (Destination.all, Node (Destination.all, N1).Owner).Address,
         Node (Destination.all, N1).Facade,
         Node (Destination.all, N2).Facade,
         Node (Destination.all, N3).Facade,
         Node (Destination.all, N4).Facade,
         Node (Destination.all, N5).Facade,
         Node (Destination.all, N6).Facade,
         Node (Destination.all, N7).Facade,
         Node (Destination.all, N8).Facade,
         Node (Destination.all, N9).Facade,
         Node (Destination.all, N10).Facade,
         Node (Destination.all, N11).Facade,
         Node (Destination.all, N12).Facade,
         Namespace (Destination.all, 2).Facade,
         Namespace (Destination.all, 3).Facade,
         Namespace (Destination.all, 4).Facade,
         Namespace (Destination.all, 5).Facade);
      for I in 1 .. 12 loop
         pragma Assert
           (Native.Node_Id (Node (Destination.all, Node_Ref (I + 1)).Facade)
            = I + 1);
      end loop;
      for I in 1 .. 4 loop
         pragma Assert
           (Native.Namespace_Id
              (Namespace (Destination.all, Namespace_Ref (I + 1)).Facade)
            = I + 1);
      end loop;
      pragma Assert
        (Node (Destination.all, Destination_Doc) = Destination_Doc_Before);
      Unlink (Destination.all, Imported_Root);
      Free_Subtree (Destination.all, Imported_Doc);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      Materialize_Check_Retained
        (Node (Destination.all, Imported_Root).Facade,
         Node (Destination.all, N4).Facade,
         Node (Destination.all, N5).Facade,
         Node (Destination.all, N6).Facade,
         Node (Destination.all, N7).Facade,
         Node (Destination.all, N8).Facade,
         Node (Destination.all, N9).Facade,
         Node (Destination.all, N10).Facade,
         Node (Destination.all, N11).Facade,
         Node (Destination.all, N12).Facade,
         Namespace (Destination.all, 2).Facade,
         Namespace (Destination.all, 3).Facade,
         Namespace (Destination.all, 4).Facade,
         Namespace (Destination.all, 5).Facade);
      Free_Subtree (Destination.all, Imported_Root);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      pragma Assert
        (Materialize_Free_Count = 1
         and then Node (Destination.all, Destination_Doc) =
                    Destination_Doc_Before);
      Free_Subtree (Destination.all, Destination_Doc);
      XML3_DOM_Bridge.Synchronize (Destination.all);
      pragma Assert (Materialize_Free_Count = 1);
      Materialize_Reset;
      XML3_DOM_Allocation.Free_State (Destination);
      declare
         Managed : XML3_DOM_Store.Store;
         Existing, Existing_Ns, Imported, Second, Root_Facade : System.Address;
         Source_Doc, Source_Before, Source_Root, Source_Attr,
           Source_Attr_Value, Source_Lang, Source_Lang_Value,
           Source_Text, Source_CData, Source_Comment, Source_PI,
           Source_Child : System.Address;
         Source_Implicit, Source_Default, Source_Prefix,
           Source_Empty : System.Address;
         Query_Result : System.Address;
         Query_Count : Natural;
         Query_Status : XML3_DOM_Constructors.Construction_Status;
         Existing_View, Found_View : Node_View;
         Found : Boolean;
         procedure Check_Content
           (Base : System.Address; Expected : String)
         is
         begin
            pragma Assert (Base /= System.Null_Address);
            if Expected'Length > 0 then
               for I in 0 .. Expected'Length - 1 loop
                  pragma Assert
                    (Native.Byte_At (Base, I)
                     = Expected (Expected'First + I));
               end loop;
            end if;
            pragma Assert
              (Native.Byte_At (Base, Expected'Length) = Character'Val (0));
            Native.Free (Base);
         end Check_Content;
         procedure Store_Arena_Check (Doc : System.Address)
           with Import, Convention => C,
             External_Name => "bridge_store_arena_check";
      begin
         XML3_DOM.Materialize.Build
           (Input, Parsed_Nodes, Count, Parsed_Names, Scratch, Source,
            Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         pragma Assert
           (Source /= null
            and then Node_Count (Source.all) = 12
            and then Namespace_Count (Source.all) = 4);
         Source_Doc := Node (Source.all, 1).Facade;
         Source_Before := Node (Source.all, 2).Facade;
         Source_Root := Node (Source.all, 3).Facade;
         Source_Attr := Node (Source.all, 4).Facade;
         Source_Attr_Value := Node (Source.all, 5).Facade;
         Source_Lang := Node (Source.all, 6).Facade;
         Source_Lang_Value := Node (Source.all, 7).Facade;
         Source_Text := Node (Source.all, 8).Facade;
         Source_CData := Node (Source.all, 9).Facade;
         Source_Comment := Node (Source.all, 10).Facade;
         Source_PI := Node (Source.all, 11).Facade;
         Source_Child := Node (Source.all, 12).Facade;
         Source_Implicit := Namespace (Source.all, 1).Facade;
         Source_Default := Namespace (Source.all, 2).Facade;
         Source_Prefix := Namespace (Source.all, 3).Facade;
         Source_Empty := Namespace (Source.all, 4).Facade;
         pragma Assert
           (Source_Before /= System.Null_Address
            and then Source_Attr_Value /= System.Null_Address
            and then Source_Lang_Value /= System.Null_Address
            and then Source_Empty /= System.Null_Address);
         declare
            Before_Source : constant State := Source.all;
         begin
            Fail_Next_Malloc;
            XML3_DOM_Store.Adopt_Arena (Managed, Source, Imported, Build_Status);
            pragma Assert
              (Build_Status = XML3_DOM_Constructors.No_Memory
               and then Imported = System.Null_Address and then Source /= null
               and then Source.all = Before_Source
               and then XML3_DOM_Store.Is_Empty (Managed));
            XML3_DOM_Store.Construct
              (Managed, Document_Node, "", "", False, System.Null_Address,
               Existing, Existing_Ns, Build_Status);
            pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
            XML3_DOM_Store.Inspect (Managed, Existing, Existing_View, Found);
            pragma Assert (Found);
            Fail_Next_Malloc;
            XML3_DOM_Store.Adopt_Arena (Managed, Source, Imported, Build_Status);
            pragma Assert
              (Build_Status = XML3_DOM_Constructors.No_Memory
               and then Imported = System.Null_Address and then Source /= null
               and then Source.all = Before_Source);
            XML3_DOM_Store.Inspect (Managed, Existing, Found_View, Found);
            pragma Assert (Found and then Found_View = Existing_View);
         end;
         Root_Facade := Node (Source.all, 3).Facade;
         XML3_DOM_Store.Adopt_Arena (Managed, Source, Imported, Build_Status);
         pragma Assert
           (Build_Status = XML3_DOM_Constructors.Created and then Source = null);
         Store_Arena_Check (Imported);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, Source_Doc,
            XML3_DOM_Store.Queries.Document_Root,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Root and then Query_Count = 0);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, Source_Doc,
            XML3_DOM_Store.Queries.First_Element,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Root and then Query_Count = 0);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, Source_Before,
            XML3_DOM_Store.Queries.Next_Element,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Root and then Query_Count = 0);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Next_Element,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address
            and then Query_Count = 0);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.First_Element,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Child and then Query_Count = 0);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, Source_Doc,
            XML3_DOM_Store.Queries.Element_Count,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address
            and then Query_Count = 1);
         XML3_DOM_Store.Queries.Select_Element
           (Managed, System.Null_Address,
            XML3_DOM_Store.Queries.First_Element,
            Query_Result, Query_Count, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Invalid_Argument
            and then Query_Result = System.Null_Address
            and then Query_Count = 0);
         XML3_DOM_Store.Queries.Find_Property
           (Managed, Source_Root, "a",
            XML3_DOM_Store.Queries.Any_Namespace, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Attr);
         XML3_DOM_Store.Queries.Find_Property
           (Managed, Source_Root, "a",
            XML3_DOM_Store.Queries.No_Namespace, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Find_Property
           (Managed, Source_Root, "a",
            XML3_DOM_Store.Queries.Exact_Namespace, "urn:p",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Attr);
         XML3_DOM_Store.Queries.Find_Property
           (Managed, Source_Root, "lang",
            XML3_DOM_Store.Queries.Exact_Namespace,
            XML3_Namespaces.XML_URI, Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Lang);
         XML3_DOM_Store.Queries.Find_Property
           (Managed, System.Null_Address, "a",
            XML3_DOM_Store.Queries.Any_Namespace, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Invalid_Argument
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Prefix_Search, True, "p",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Prefix);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Prefix_Search, False, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Default);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Child,
            XML3_DOM_Store.Queries.Prefix_Search, False, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Empty);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Prefix_Search, True, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Prefix_Search, True, "xml",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Implicit);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Href_Search, True, "urn:p",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Prefix);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Child,
            XML3_DOM_Store.Queries.Href_Search, True, "urn:d",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Child,
            XML3_DOM_Store.Queries.Href_Search, True, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Empty);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Lang,
            XML3_DOM_Store.Queries.Href_Search, True, "urn:d",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Href_Search, False, "",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Root, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "onetwo");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Doc, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "onetwo");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Attr, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "A&B");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Attr_Value, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "A&B");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Lang, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "ja");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Lang_Value, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "ja");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, System.Null_Address, Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Invalid_Argument
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Text, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "one");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_CData, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "two");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Comment, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "c");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_PI, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "x");
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Child, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "");
         Fail_Next_Malloc;
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Root, Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.No_Memory
            and then Query_Result = System.Null_Address);
         Store_Arena_Check (Imported);
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Root, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "onetwo");
         XML3_DOM_Store.Inspect (Managed, Root_Facade, Found_View, Found);
         pragma Assert (Found and then Found_View.Kind = Element_Node);
         XML3_DOM.Materialize.Build
           (Input, Parsed_Nodes, Count, Parsed_Names, Scratch, Source,
            Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         declare
            Before_Source : constant State := Source.all;
         begin
            Fail_Next_Malloc;
            XML3_DOM_Store.Adopt_Arena (Managed, Source, Second, Build_Status);
            pragma Assert
              (Build_Status = XML3_DOM_Constructors.No_Memory
               and then Source /= null and then Source.all = Before_Source);
            Store_Arena_Check (Imported);
         end;
         XML3_DOM_Store.Adopt_Arena (Managed, Source, Second, Build_Status);
         pragma Assert
           (Build_Status = XML3_DOM_Constructors.Created and then Source = null);
         Store_Arena_Check (Imported);
         Store_Arena_Check (Second);
         XML3_DOM_Store.Properties.Set_Property
           (Managed, Source_Root, "a", "plain", True,
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result /= System.Null_Address
            and then Query_Result /= Source_Attr);
         Store_No_Namespace_Check
           (Source_Root, Source_Attr, Source_Lang, Query_Result);
         XML3_DOM_Store.Unlink (Managed, Source_Attr, Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Attr_Value,
            XML3_DOM_Store.Queries.Prefix_Search, True, "p",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = System.Null_Address);
         XML3_DOM_Store.Attach
           (Managed, Source_Root, Source_Attr, True, Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         XML3_DOM_Store.Add_Child
           (Managed, Source_Root, Source_Text, Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Text);
         XML3_DOM_Store.Queries.Get_Content
           (Managed, Source_Root, Query_Result, Query_Status);
         pragma Assert (Query_Status = XML3_DOM_Constructors.Created);
         Check_Content (Query_Result, "twoone");
         XML3_DOM_Store.Inspect (Managed, Existing, Found_View, Found);
         pragma Assert (Found and then Found_View = Existing_View);
         XML3_DOM_Store.Unlink (Managed, Root_Facade, Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         XML3_DOM_Store.Release
           (Managed, Imported, XML3_DOM_Store.Document_Only, False, Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         XML3_DOM_Store.Queries.Search_Namespace
           (Managed, Source_Root,
            XML3_DOM_Store.Queries.Prefix_Search, True, "xml",
            Query_Result, Query_Status);
         pragma Assert
           (Query_Status = XML3_DOM_Constructors.Created
            and then Query_Result = Source_Implicit);
         XML3_DOM_Store.Inspect (Managed, Root_Facade, Found_View, Found);
         pragma Assert (Found and then Found_View.Parent = Null_Node);
         XML3_DOM_Store.Release
           (Managed, Root_Facade, XML3_DOM_Store.Content_Node, False, Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         XML3_DOM_Store.Release
           (Managed, Second, XML3_DOM_Store.Document_Only, False, Build_Status);
         pragma Assert (Build_Status = XML3_DOM_Constructors.Created);
         XML3_DOM_Store.Release
           (Managed, Existing, XML3_DOM_Store.Document_Only, False, Build_Status);
         pragma Assert
           (Build_Status = XML3_DOM_Constructors.Created
            and then XML3_DOM_Store.Is_Empty (Managed));
      end;
   end;
   Ada.Text_IO.Put_Line ("DOM arena adoption, rollback, and release tests passed");

   declare
      package Documents renames XML3_DOM_Store.Documents;
      use type Documents.Read_Status;
      use type XML3_DOM_Constructors.Construction_Status;
      Input : constant String := "<r><x/></r>";
      Nodes : XML3_Parser.Node_Array (1 .. 16);
      Names : XML3_Namespaces.Name_Array (1 .. 16);
      Scratch_A, Scratch_B : String (Input'Range);
      Managed : XML3_DOM_Store.Store;
      Doc : System.Address;
      Read_Status : Documents.Read_Status;
      Release_Status : XML3_DOM_Store.Operation_Status;
      Diagnostic : XML3_Parser.Diagnostic_Info;
      procedure Fail_Malloc_Nth (Nth : Interfaces.C.unsigned)
        with Import, Convention => C,
          External_Name => "bridge_fail_malloc_nth";
      procedure Check_Malloc_Failure
        with Import, Convention => C,
          External_Name => "bridge_check_malloc_failure";
   begin
      --  Materialization allocates three blocks; fail the Store allocation.
      Fail_Malloc_Nth (4);
      Documents.Read
        (Managed, Input, False, XML3_Encoding.Encoding_Info'(others => <>),
         Nodes, Names, Scratch_A, Scratch_B, Doc, Read_Status, Diagnostic);
      Check_Malloc_Failure;
      pragma Assert
        (Read_Status = Documents.No_Memory
         and then Doc = System.Null_Address
         and then XML3_DOM_Store.Is_Empty (Managed));
      Documents.Read
        (Managed, Input, False, XML3_Encoding.Encoding_Info'(others => <>),
         Nodes, Names, Scratch_A, Scratch_B, Doc, Read_Status, Diagnostic);
      pragma Assert (Read_Status = Documents.Parsed);
      XML3_DOM_Store.Release
        (Managed, Doc, XML3_DOM_Store.Document_Only, False, Release_Status);
      pragma Assert
        (Release_Status = XML3_DOM_Constructors.Created
         and then XML3_DOM_Store.Is_Empty (Managed));
   end;
   Ada.Text_IO.Put_Line ("Unpublished document rollback and Store reuse passed");

   declare
      use type XML3_DOM_Constructors.Construction_Status;
      Managed : XML3_DOM_Store.Store;
      Root, Borrower, Ns, Implicit_Ns : System.Address;
      Status : XML3_DOM_Store.Operation_Status;
      Block : System.Address;
   begin
      XML3_DOM_Store.Construct
        (Managed, Element_Node, "root", "", False, System.Null_Address,
         Root, Implicit_Ns, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Root /= System.Null_Address);
      XML3_DOM_Store.Construct
        (Managed, Element_Node, "borrower", "", False, System.Null_Address,
         Borrower, Implicit_Ns, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Borrower /= System.Null_Address);
      XML3_DOM_Store.Create_Namespace
        (Managed, Root, "urn:retained", "p", True, True, Ns, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Ns /= System.Null_Address);
      Block := System.Storage_Elements.To_Address
        (System.Storage_Elements.To_Integer (Ns)
         - System.Storage_Elements.Integer_Address (Native.Metadata_Bytes));
      Namespace_Track (Block, Ns);
      XML3_DOM_Store.Free_Namespace (Managed, Ns, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Invalid_Argument);
      XML3_DOM_Store.Set_Namespace (Managed, Borrower, Ns, Status);
      pragma Assert (Status = XML3_DOM_Constructors.Created);
      XML3_DOM_Store.Release
        (Managed, Root, XML3_DOM_Store.Content_Node, False, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Namespace_Free_Count = 0);
      XML3_DOM_Store.Free_Namespace (Managed, Ns, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Invalid_Argument
         and then Namespace_Free_Count = 0);
      XML3_DOM_Store.Release
        (Managed, Borrower, XML3_DOM_Store.Content_Node, False, Status);
      pragma Assert
        (Status = XML3_DOM_Constructors.Created
         and then Namespace_Free_Count = 1
         and then XML3_DOM_Store.Is_Empty (Managed));
      Namespace_Reset;
   end;
   Ada.Text_IO.Put_Line
     ("Constructed namespace retention and exactly-once release passed");
end DOM_Bridge_Test;
