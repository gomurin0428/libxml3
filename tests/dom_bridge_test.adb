with Ada.Text_IO;
with Interfaces.C;
with System;
with XML3_DOM; use XML3_DOM;
with XML3_DOM_Allocation;
with XML3_DOM_Bridge;
with XML3_Native_Memory;

procedure DOM_Bridge_Test is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   use type System.Address;
   use type Interfaces.C.unsigned;

   procedure Track
     (Doc_Block, Root_Block, Child_Block, Doc, Root, Child : System.Address)
     with Import, Convention => C, External_Name => "bridge_track";
   procedure Reset_Tracking
     with Import, Convention => C, External_Name => "bridge_reset_tracking";
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
   Ada.Text_IO.Put_Line ("Native DOM projection, pin lifetime, and release ordering tests passed");
end DOM_Bridge_Test;
