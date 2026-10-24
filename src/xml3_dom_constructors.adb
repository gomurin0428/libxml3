with System;
with XML3_DOM_Bridge;
with XML3_Namespaces;

package body XML3_DOM_Constructors with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   use type System.Address;

   procedure Add_Bytes
     (Left, Right : Native.Byte_Count;
      Result : out Native.Byte_Count;
      Success : out Boolean)
   is
   begin
      if Left > Native.Byte_Count'Last - Right then
         Result := 0;
         Success := False;
         return;
      end if;
      Result := Left + Right;
      Success := True;
   end Add_Bytes;

   procedure Add_Natural
     (Left : Native.Byte_Count;
      Right : Natural;
      Result : out Native.Byte_Count;
      Success : out Boolean)
   is
   begin
      Add_Bytes (Left, Native.Byte_Count (Right), Result, Success);
   end Add_Natural;

   procedure Retire_Registered
     (Current : in out State_Access;
      Own : Owner_Ref;
      New_Node : Node_Ref)
   with Pre => Current /= null
     and then Valid (Current.all) and then Can_Edit (Current.all)
     and then XML3_DOM_Bridge.Facades_Present (Current.all)
     and then New_Node in 1 .. Node_Ref (Node_Count (Current.all))
     and then Node (Current.all, New_Node).State = Live
     and then Node (Current.all, New_Node).Owner = Own
     and then Node (Current.all, New_Node).Parent = Null_Node
     and then Node (Current.all, New_Node).First_Child = Null_Node
     and then Node (Current.all, New_Node).First_Prop = Null_Node
     and then Own in 1 .. Owner_Ref (Owner_Count (Current.all))
     and then Owner (Current.all, Own).State = Live
     and then Owner (Current.all, Own).Reservations > 0,
     Post => (declare
       Old_Nodes : constant Node_View_Array :=
         Snapshot_Nodes (Current.all)'Old;
       Old_Node_Count : constant Natural := Node_Count (Current.all)'Old;
       Old_Namespace_Count : constant Natural :=
         Namespace_Count (Current.all)'Old;
       Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
       Old_Capacity : constant Positive := Capacity_Of (Current.all)'Old;
     begin
       Current /= null
         and then Valid (Current.all) and then Can_Edit (Current.all)
         and then not Projection_Required (Current.all)
         and then XML3_DOM_Bridge.Facades_Present (Current.all)
         and then Node_Count (Current.all) = Old_Node_Count
         and then Namespace_Count (Current.all) = Old_Namespace_Count
         and then Owner_Count (Current.all) = Old_Owner_Count
         and then Capacity_Of (Current.all) = Old_Capacity
         and then (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
           (if I /= New_Node and then Old_Nodes (Positive (I)).State = Live
            then Node (Current.all, I) = Old_Nodes (Positive (I)))))
   is
   begin
      Free_Subtree (Current.all, New_Node);
      Release_Reservation (Current.all, Own);
      XML3_DOM_Bridge.Synchronize (Current.all);
   end Retire_Registered;

   procedure Create_Node
     (Current : in out State_Access;
      Kind : Node_Kind;
      Name, Content : String;
      Has_Content : Boolean;
      Ns : Namespace_Ref;
      N : out Node_Ref;
      Implicit_Ns : out Namespace_Ref;
      Status : out Construction_Status)
   is
      Need_Nodes, Need_Namespaces, Need_Owners : Natural;
      Bytes, Cursor, Next : Native.Byte_Count;
      Node_Facade_Offset, Namespace_Facade_Offset : Native.Byte_Count;
      Name_Offset, Content_Offset, Href_Offset, Prefix_Offset :
        Native.Byte_Count := 0;
      Block : System.Address := System.Null_Address;
      Node_Facade, Namespace_Facade : System.Address := System.Null_Address;
      Name_Address, Content_Address : System.Address := System.Null_Address;
      Href_Address, Prefix_Address : System.Address := System.Null_Address;
      Own : Owner_Ref := Null_Owner;
      Local_N : Node_Ref := Null_Node;
      Local_Ns : Namespace_Ref := Null_Namespace;
      Local_Ok : Boolean;
      Capacity_Ok : Boolean;
      Size_Ok : Boolean;
      Is_Doc : constant Boolean := Kind = Document_Node;
   begin
      N := Null_Node;
      Implicit_Ns := Null_Namespace;
      Status := Invalid_Argument;

      if Ns /= Null_Namespace then
         if Kind not in Element_Node | Attribute_Node
           or else Ns > Namespace_Ref (Namespace_Count (Current.all))
           or else Namespace (Current.all, Ns).State /= Live
           or else Namespace (Current.all, Ns).Owner = Null_Owner
           or else Namespace (Current.all, Ns).Owner >
             Owner_Ref (Owner_Count (Current.all))
           or else Owner
             (Current.all, Namespace (Current.all, Ns).Owner).State /= Live
         then
            return;
         end if;
         if Owner
           (Current.all, Namespace (Current.all, Ns).Owner).References =
             Natural'Last
         then
            Status := Limit_Exceeded;
            return;
         end if;
      end if;

      if Node_Count (Current.all) = Natural'Last
        or else Owner_Count (Current.all) = Natural'Last
        or else (Is_Doc and then Namespace_Count (Current.all) = Natural'Last)
        or else (Name'Length = Natural'Last and then not Is_Doc)
        or else (Has_Content and then Content'Length = Natural'Last)
      then
         Status := Limit_Exceeded;
         return;
      end if;

      Need_Nodes := Node_Count (Current.all) + 1;
      Need_Owners := Owner_Count (Current.all) + 1;
      Need_Namespaces := Namespace_Count (Current.all) +
        (if Is_Doc then 1 else 0);
      Ensure_Capacity
        (Current, Need_Nodes, Need_Namespaces, Need_Owners, Capacity_Ok);
      if not Capacity_Ok then
         Status := No_Memory;
         return;
      end if;

      Add_Bytes
        (Native.Node_Stride,
         (if Is_Doc then Native.Namespace_Stride else 0), Cursor, Size_Ok);
      if not Size_Ok then
         Status := Limit_Exceeded;
         return;
      end if;
      Node_Facade_Offset := Native.Metadata_Bytes;
      if Is_Doc then
         Add_Bytes
           (Native.Node_Stride, Native.Metadata_Bytes,
            Namespace_Facade_Offset, Size_Ok);
         if not Size_Ok then
            Status := Limit_Exceeded;
            return;
         end if;
      else
         Namespace_Facade_Offset := 0;
      end if;
      if not Is_Doc then
         Name_Offset := Cursor;
         Add_Natural (Cursor, Name'Length + 1, Next, Size_Ok);
         if not Size_Ok then
            Status := Limit_Exceeded;
            return;
         end if;
         Cursor := Next;
      end if;
      if Has_Content then
         Content_Offset := Cursor;
         Add_Natural (Cursor, Content'Length + 1, Next, Size_Ok);
         if not Size_Ok then
            Status := Limit_Exceeded;
            return;
         end if;
         Cursor := Next;
      end if;
      if Is_Doc then
         Href_Offset := Cursor;
         Add_Natural
           (Cursor, XML3_Namespaces.XML_URI'Length + 1, Next, Size_Ok);
         if not Size_Ok then
            Status := Limit_Exceeded;
            return;
         end if;
         Cursor := Next;
         Prefix_Offset := Cursor;
         Add_Natural (Cursor, 4, Next, Size_Ok);
         if not Size_Ok then
            Status := Limit_Exceeded;
            return;
         end if;
         Cursor := Next;
      end if;
      Bytes := Cursor;
      if Bytes = 0 then
         Status := Internal_Error;
         return;
      end if;

      Native.Allocate (Bytes, Block);
      if Block = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      Node_Facade := Native.Offset (Block, Node_Facade_Offset);
      if Is_Doc then
         Namespace_Facade := Native.Offset (Block, Namespace_Facade_Offset);
      end if;
      if not Is_Doc then
         Name_Address := Native.Offset (Block, Name_Offset);
      end if;
      if Has_Content then
         Content_Address := Native.Offset (Block, Content_Offset);
      end if;
      if Is_Doc then
         Href_Address := Native.Offset (Block, Href_Offset);
         Prefix_Address := Native.Offset (Block, Prefix_Offset);
      end if;
      if Node_Facade = System.Null_Address
        or else (Is_Doc and then Namespace_Facade = System.Null_Address)
        or else ((not Is_Doc) and then Name_Address = System.Null_Address)
        or else (Has_Content and then Content_Address = System.Null_Address)
        or else (Is_Doc and then
          (Href_Address = System.Null_Address
           or else Prefix_Address = System.Null_Address))
      then
         Native.Free (Block);
         Status := Internal_Error;
         return;
      end if;
      pragma Assert (Node_Facade /= System.Null_Address);
      if Is_Doc then
         pragma Assert (Namespace_Facade /= System.Null_Address);
      end if;

      Native.Initialize_Node (Node_Facade);
      if Is_Doc then
         Native.Initialize_Namespace (Namespace_Facade);
         Native.Write_String
           (Href_Address, 0, XML3_Namespaces.XML_URI);
         Native.Write_Byte
           (Href_Address, XML3_Namespaces.XML_URI'Length, Character'Val (0));
         Native.Write_String (Prefix_Address, 0, "xml");
         Native.Write_Byte (Prefix_Address, 3, Character'Val (0));
      else
         if Name'Length > 0 then
            Native.Write_String (Name_Address, 0, Name);
         end if;
         Native.Write_Byte (Name_Address, Name'Length, Character'Val (0));
      end if;
      if Has_Content then
         if Content'Length > 0 then
            Native.Write_String (Content_Address, 0, Content);
         end if;
         Native.Write_Byte
           (Content_Address, Content'Length, Character'Val (0));
      end if;

      Register_Owner (Current.all, Block, Own, Local_Ok);
      if not Local_Ok then
         Native.Free (Block);
         Status := Internal_Error;
         return;
      end if;
      Register_Node
        (Current.all, Kind, Node_Facade, Own, Null_Owner, Local_N, Local_Ok);
      if not Local_Ok then
         Release_Reservation (Current.all, Own);
         XML3_DOM_Bridge.Synchronize (Current.all);
         Status := Internal_Error;
         return;
      end if;
      Set_Node_Projection
        (Current.all, Local_N,
         (if Is_Doc then System.Null_Address else Name_Address),
         (if Is_Doc then 0 else Name'Length),
         Content_Address, (if Has_Content then Content'Length else 0),
         (if Is_Doc then Local_N else Null_Node), Ns,
         (if Ns = Null_Namespace then Null_Owner
          else Namespace (Current.all, Ns).Owner),
         Null_Owner, Null_Owner, Local_Ok);
      if not Local_Ok then
         Retire_Registered (Current, Own, Local_N);
         Status := Internal_Error;
         return;
      end if;

      if Is_Doc then
         Register_Namespace
           (Current.all, Namespace_Facade, Href_Address,
            XML3_Namespaces.XML_URI'Length, Prefix_Address, 3,
            Own, Local_Ns, Local_Ok);
         if not Local_Ok then
            Retire_Registered (Current, Own, Local_N);
            Status := Internal_Error;
            return;
         end if;
      end if;

      Release_Reservation (Current.all, Own);
      XML3_DOM_Bridge.Synchronize (Current.all);
      N := Local_N;
      Implicit_Ns := Local_Ns;
      Status := Created;
   end Create_Node;
end XML3_DOM_Constructors;
