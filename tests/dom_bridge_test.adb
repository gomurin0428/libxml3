with Ada.Text_IO;
with Interfaces.C;
with System;
with XML3_DOM; use XML3_DOM;
with XML3_DOM.Import;
with XML3_DOM_Allocation;
with XML3_DOM_Bridge;
with XML3_DOM_Constructors;
with XML3_DOM_Store;
with XML3_Native_Memory;

procedure DOM_Bridge_Test is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   use type System.Address;
   use type Interfaces.C.unsigned;

   procedure Store_Merge_Track (Root, Target, Source : System.Address)
     with Import, Convention => C, External_Name => "bridge_store_merge_track";
   procedure Store_Merge_Check (Merged : Interfaces.C.int)
     with Import, Convention => C, External_Name => "bridge_store_merge_check";
   procedure Store_Merge_Reset
     with Import, Convention => C, External_Name => "bridge_store_merge_reset";

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
      Doc, 0, 0, 0, 0, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Doc_Owner);

   Register_Owner (S.all, Root_Block, Root_Owner, OK);
   pragma Assert (OK);
   Register_Node (S.all, Element_Node, Root_Facade, Root_Owner, 0, Root, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Root, Root_Name'Address, Root_Name'Length - 1,
      System.Null_Address, 0, 0, Ns, Doc_Owner, 0, 0, OK);
   pragma Assert (OK);
   Release_Reservation (S.all, Root_Owner);

   Register_Owner (S.all, Child_Block, Child_Owner, OK);
   pragma Assert (OK);
   Register_Node (S.all, Text_Node, Child_Facade, Child_Owner, 0, Child, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Child, Text_Name'Address, Text_Name'Length - 1,
      Content'Address, Content'Length - 1, 0, 0, 0, 0, 0, OK);
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
      Merge_Old_Content_Owner, OK);
   pragma Assert (OK);
   Set_Node_Projection
     (S.all, Merge_Source, Merge_Source_Name'Address,
      Merge_Source_Name'Length - 1, Merge_Source_Content_Block,
      Merge_Source_Content'Length - 1, 0, 0, 0, 0,
      Merge_Source_Content_Owner, OK);
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
         Version_At, Version'Length - 1, Source_Doc, 0, 0, 0, 0, OK);
      pragma Assert (OK);
      Set_Node_Projection
        (Source.all, Source_Root, Name_At, Root_Name'Length - 1,
         System.Null_Address, 0, 0, Source_Ns, Arena_Owner, 0, 0, OK);
      pragma Assert (OK);
      Set_Node_Projection
        (Source.all, Source_Text, Text_Name_At, Text_Name'Length - 1,
         Content_At, Content'Length - 1, 0, 0, 0, 0, 0, OK);
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
         Version'Address, Version'Length - 1, Original, 0, 0, 0, 0, OK);
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
   Ada.Text_IO.Put_Line ("DOM arena adoption, rollback, and release tests passed");
end DOM_Bridge_Test;
