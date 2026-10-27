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
     and then Node (Current.all, New_Node).First_Namespace = Null_Namespace
     and then Node (Current.all, New_Node).Last_Namespace = Null_Namespace
     and then Node (Current.all, New_Node).Ns_Pin = Null_Owner
     and then Node (Current.all, New_Node).Doc_Pin = Null_Owner
     and then Node (Current.all, New_Node).Content_Pin = Null_Owner
     and then Own in 1 .. Owner_Ref (Owner_Count (Current.all))
     and then (for all I in Namespace_Ref range
       1 .. Namespace_Ref (Namespace_Count (Current.all)) =>
         (if Namespace (Current.all, I).State = Live then
           Namespace (Current.all, I).Owner /= Own))
     and then Owner (Current.all, Own).State = Live
     and then Owner (Current.all, Own).Reservations > 0,
     Post => (declare
       Old_Nodes : constant Node_View_Array :=
         Snapshot_Nodes (Current.all)'Old;
       Old_Namespaces : constant Namespace_View_Array :=
         Snapshot_Namespaces (Current.all)'Old;
       Old_Owners : constant Owner_View_Array :=
         Snapshot_Owners (Current.all)'Old;
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
         and then (for all B in Owner_Ref range
           1 .. Owner_Ref (Old_Owner_Count) =>
             (if Old_Owners (Positive (B)).State /= Live then
               Owner (Current.all, B).State /= Live))
         and then (for all B in Owner_Ref range
           1 .. Owner_Ref (Old_Owner_Count) =>
             (if Old_Owners (Positive (B)).State = Live and then B /= Own
              then Owner (Current.all, B) = Old_Owners (Positive (B))))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Old_Namespace_Count) =>
             (if Namespace (Current.all, I).State = Live then
               Namespace (Current.all, I) = Old_Namespaces (Positive (I))))
         and then (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Old_Namespace_Count) =>
             (if Old_Namespaces (Positive (I)).State = Live
               and then Old_Namespaces (Positive (I)).Owner in
                 1 .. Owner_Ref (Old_Owner_Count)
               and then Old_Owners
                 (Positive (Old_Namespaces (Positive (I)).Owner)).State =
                   Live
              then Namespace (Current.all, I) =
                Old_Namespaces (Positive (I))))
         and then (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
           (if Node (Current.all, I).State = Live then
              I /= New_Node and then Node (Current.all, I) = Old_Nodes (Positive (I))))
         and then (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
           (if I /= New_Node and then Old_Nodes (Positive (I)).State = Live
            then Node (Current.all, I) = Old_Nodes (Positive (I)))))
   is
      Before : constant State := Current.all with Ghost;
   begin
      Leaf_Retained_Declarations_Lemma (Current.all, New_Node);
      Free_Subtree (Current.all, New_Node);
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             Namespace (Current.all, I) = Namespace (Before, I));
      Release_Reservation (Current.all, Own);
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Before)) =>
             Namespace (Current.all, I) = Namespace (Before, I));
      declare
         Sync_Before : constant State := Current.all with Ghost;
      begin
         XML3_DOM_Bridge.Synchronize (Current.all);
         pragma Assert (Live_Entries_Preserved (Sync_Before, Current.all));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Namespace_Count (Before)) =>
                (if Namespace (Current.all, I).State = Live then
                   Namespace (Current.all, I) =
                     Namespace (Before, I)));
      end;
   end Retire_Registered;

   procedure Allocate_Node_Buffer
     (Is_Doc : Boolean;
      Name, Content : String;
      Has_Content : Boolean;
      Block, Node_Facade, Namespace_Facade, Name_Address, Content_Address,
        Href_Address, Prefix_Address : out System.Address;
      Status : out Construction_Status)
   with Global => (In_Out => Native.Foreign_Memory),
     Pre => (Is_Doc or else Name'Length < Natural'Last)
       and then (not Has_Content or else Content'Length < Natural'Last),
     Post =>
       (if Status = Created then
          Block /= System.Null_Address
          and then Node_Facade /= System.Null_Address
          and then (if Is_Doc then
            Namespace_Facade /= System.Null_Address
            and then Href_Address /= System.Null_Address
            and then Prefix_Address /= System.Null_Address)
          and then (if not Is_Doc then
            Name_Address /= System.Null_Address)
          and then (if Has_Content then
            Content_Address /= System.Null_Address)
        else Block = System.Null_Address)
   is
      Bytes, Cursor, Next : Native.Byte_Count;
      Node_Facade_Offset, Namespace_Facade_Offset : Native.Byte_Count;
      Name_Offset, Content_Offset, Href_Offset, Prefix_Offset :
        Native.Byte_Count := 0;
      Size_Ok : Boolean;
   begin
      Block := System.Null_Address;
      Node_Facade := System.Null_Address;
      Namespace_Facade := System.Null_Address;
      Name_Address := System.Null_Address;
      Content_Address := System.Null_Address;
      Href_Address := System.Null_Address;
      Prefix_Address := System.Null_Address;
      Status := Internal_Error;

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
         Block := System.Null_Address;
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
      Status := Created;
   end Allocate_Node_Buffer;

   procedure Prepare_Node_Capacity
     (Current : in out State_Access;
      Kind : Node_Kind;
      Name_Length, Content_Length : Natural;
      Has_Content : Boolean;
      Ns : Namespace_Ref;
      Status : out Construction_Status)
   with Global => null,
     Pre => Current /= null
       and then Valid (Current.all) and then Can_Edit (Current.all)
       and then not Projection_Required (Current.all)
       and then Facades_Present (Current.all),
     Post => (declare
       Old_Nodes : constant Node_View_Array :=
         Snapshot_Nodes (Current.all)'Old;
       Old_Namespaces : constant Namespace_View_Array :=
         Snapshot_Namespaces (Current.all)'Old;
       Old_Owners : constant Owner_View_Array :=
         Snapshot_Owners (Current.all)'Old;
       Old_Node_Count : constant Natural := Node_Count (Current.all)'Old;
       Old_Namespace_Count : constant Natural :=
         Namespace_Count (Current.all)'Old;
       Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
       Old_Capacity : constant Positive := Capacity_Of (Current.all)'Old;
     begin
       Current /= null
       and then Valid (Current.all) and then Can_Edit (Current.all)
       and then not Projection_Required (Current.all)
       and then Facades_Present (Current.all)
       and then Capacity_Of (Current.all) >= Old_Capacity
       and then Node_Count (Current.all) = Old_Node_Count
       and then Namespace_Count (Current.all) = Old_Namespace_Count
       and then Owner_Count (Current.all) = Old_Owner_Count
       and then (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
         Node (Current.all, I) = Old_Nodes (Positive (I)))
       and then (for all I in Namespace_Ref range
         1 .. Namespace_Ref (Old_Namespace_Count) =>
           Namespace (Current.all, I) = Old_Namespaces (Positive (I)))
       and then (for all B in Owner_Ref range 1 .. Owner_Ref (Old_Owner_Count) =>
         Owner (Current.all, B) = Old_Owners (Positive (B)))
       and then (if Status = Created then
         Node_Count (Current.all) < Capacity_Of (Current.all)
         and then Owner_Count (Current.all) < Capacity_Of (Current.all)
         and then (if Kind = Document_Node then
           Namespace_Count (Current.all) < Capacity_Of (Current.all))
         and then (Kind = Document_Node or else Name_Length < Natural'Last)
         and then (not Has_Content or else Content_Length < Natural'Last)
         and then (if Ns /= Null_Namespace then
           Kind in Element_Node | Attribute_Node
           and then Ns in 1 .. Namespace_Ref (Namespace_Count (Current.all))
           and then Namespace (Current.all, Ns).State = Live
           and then Namespace (Current.all, Ns).Owner in
             1 .. Owner_Ref (Owner_Count (Current.all))
           and then Owner
             (Current.all, Namespace (Current.all, Ns).Owner).State = Live
           and then Owner
             (Current.all, Namespace (Current.all, Ns).Owner).References <
               Natural'Last)));

   procedure Prepare_Node_Capacity
     (Current : in out State_Access;
      Kind : Node_Kind;
      Name_Length, Content_Length : Natural;
      Has_Content : Boolean;
      Ns : Namespace_Ref;
      Status : out Construction_Status)
   is
      Need_Nodes, Need_Namespaces, Need_Owners : Natural;
      Capacity_Ok : Boolean;
      Is_Doc : constant Boolean := Kind = Document_Node;
   begin
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
        or else (Name_Length = Natural'Last and then not Is_Doc)
        or else (Has_Content and then Content_Length = Natural'Last)
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
      Status := (if Capacity_Ok then Created else No_Memory);
   end Prepare_Node_Capacity;

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
      Block : System.Address := System.Null_Address;
      Node_Facade, Namespace_Facade : System.Address := System.Null_Address;
      Name_Address, Content_Address : System.Address := System.Null_Address;
      Href_Address, Prefix_Address : System.Address := System.Null_Address;
      Own : Owner_Ref := Null_Owner;
      Local_N : Node_Ref := Null_Node;
      Local_Ns : Namespace_Ref := Null_Namespace;
      Local_Ok : Boolean;
      Is_Doc : constant Boolean := Kind = Document_Node;
      Entry_Node_Count : constant Natural := Node_Count (Current.all)
        with Ghost;
      Entry_Namespace_Count : constant Natural :=
        Namespace_Count (Current.all) with Ghost;
      Entry_Owner_Count : constant Natural := Owner_Count (Current.all)
        with Ghost;
      Entry_Nodes : constant Node_View_Array :=
        Snapshot_Nodes (Current.all) with Ghost;
      Entry_Namespaces : constant Namespace_View_Array :=
        Snapshot_Namespaces (Current.all) with Ghost;
      Entry_Owners : constant Owner_View_Array :=
        Snapshot_Owners (Current.all) with Ghost;
   begin
      N := Null_Node;
      Implicit_Ns := Null_Namespace;
      Prepare_Node_Capacity
        (Current, Kind, Name'Length, Content'Length, Has_Content, Ns, Status);
      if Status /= Created then
         return;
      end if;

      Allocate_Node_Buffer
        (Is_Doc, Name, Content, Has_Content,
         Block, Node_Facade, Namespace_Facade, Name_Address, Content_Address,
         Href_Address, Prefix_Address, Status);
      if Status /= Created then
         return;
      end if;

      Register_Owner (Current.all, Block, Own, Local_Ok);
      if not Local_Ok then
         Native.Free (Block);
         Status := Internal_Error;
         return;
      end if;
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Current.all)) =>
             (if Namespace (Current.all, I).State = Live then
                Namespace (Current.all, I).Owner /= Own));
      Register_Node
        (Current.all, Kind, Node_Facade, Own, Null_Owner, Local_N, Local_Ok);
      if not Local_Ok then
         Release_Reservation (Current.all, Own);
         XML3_DOM_Bridge.Synchronize (Current.all);
         pragma Assert
           (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
              (if Entry_Owners (Positive (B)).State = Live then
                 Owner (Current.all, B).State = Live));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Entry_Namespace_Count) =>
                (if Entry_Namespaces (Positive (I)).State = Live
                  and then Entry_Namespaces (Positive (I)).Owner in
                    1 .. Owner_Ref (Entry_Owner_Count)
                  and then Entry_Owners
                    (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                      Live
                 then Namespace (Current.all, I) =
                   Entry_Namespaces (Positive (I))));
         Status := Internal_Error;
         return;
      end if;
      for I in Node_Ref range 1 .. Node_Ref (Node_Count (Current.all)) loop
         pragma Assert
           (if I <= Node_Ref (Entry_Node_Count)
             and then Entry_Nodes (Positive (I)).State = Live then
              I /= Local_N
              and then Node (Current.all, I) = Entry_Nodes (Positive (I)));
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. I =>
             (if J <= Node_Ref (Entry_Node_Count)
               and then Entry_Nodes (Positive (J)).State = Live then
                J /= Local_N
                and then Node (Current.all, J) = Entry_Nodes (Positive (J))));
      end loop;
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Current.all)) =>
             (if Namespace (Current.all, I).State = Live then
                Namespace (Current.all, I).Owner /= Own));
      declare
         Projection_Namespace_Count : constant Natural :=
           Namespace_Count (Current.all) with Ghost;
         Before_Projection : constant State := Current.all with Ghost;
      begin
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Projection_Namespace_Count) =>
                (if Namespace (Before_Projection, I).State = Live then
                   Namespace (Before_Projection, I).Owner /= Own));
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
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Projection_Namespace_Count) =>
                   Namespace (Current.all, I) =
                     Namespace (Before_Projection, I));
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Entry_Namespace_Count) =>
                   Namespace (Current.all, I) =
                     Entry_Namespaces (Positive (I)));
            pragma Assert
              (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
                 (if Entry_Owners (Positive (B)).State = Live then
                    Owner (Current.all, B).State = Live));
            Retire_Registered (Current, Own, Local_N);
            pragma Assert
              (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
                 (if Entry_Owners (Positive (B)).State = Live then
                    Owner (Current.all, B).State = Live));
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Entry_Namespace_Count) =>
                   (if Entry_Namespaces (Positive (I)).State = Live
                     and then Entry_Namespaces (Positive (I)).Owner in
                       1 .. Owner_Ref (Entry_Owner_Count)
                     and then Entry_Owners
                       (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                         Live
                    then Namespace (Current.all, I) =
                      Entry_Namespaces (Positive (I))));
            Status := Internal_Error;
            return;
         end if;
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Projection_Namespace_Count) =>
                Namespace (Current.all, I) =
                  Namespace (Before_Projection, I));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Projection_Namespace_Count) =>
                (if Namespace (Current.all, I).State = Live then
                   Namespace (Current.all, I).Owner /= Own));
      end;

      if Is_Doc then
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Namespace_Count (Current.all)) =>
                (if Namespace (Current.all, I).State = Live then
                   Namespace (Current.all, I).Owner /= Own));
         Register_Namespace
           (Current.all, Namespace_Facade, Href_Address,
            XML3_Namespaces.XML_URI'Length, Prefix_Address, 3,
            Own, Local_Ns, Local_Ok);
         if not Local_Ok then
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Namespace_Count (Current.all)) =>
                   (if Namespace (Current.all, I).State = Live then
                      Namespace (Current.all, I).Owner /= Own));
            Retire_Registered (Current, Own, Local_N);
            pragma Assert
              (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
                 (if Entry_Owners (Positive (B)).State = Live then
                    Owner (Current.all, B).State = Live));
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Entry_Namespace_Count) =>
                   (if Entry_Namespaces (Positive (I)).State = Live
                     and then Entry_Namespaces (Positive (I)).Owner in
                       1 .. Owner_Ref (Entry_Owner_Count)
                     and then Entry_Owners
                       (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                         Live
                    then Namespace (Current.all, I) =
                      Entry_Namespaces (Positive (I))));
            Status := Internal_Error;
            return;
         end if;
      end if;

      pragma Assert (not Namespace_Reservation_Held (Current.all, Own));
      Release_Reservation (Current.all, Own);
      for B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (Current.all)) loop
         pragma Assert
           (if B <= Owner_Ref (Entry_Owner_Count)
             and then Entry_Owners (Positive (B)).State in Live | Releasing
            then B /= Own and then Owner (Current.all, B).State =
              Entry_Owners (Positive (B)).State);
         pragma Loop_Invariant
           (for all K in Owner_Ref range 1 .. B =>
             (if K <= Owner_Ref (Entry_Owner_Count)
               and then Entry_Owners (Positive (K)).State in Live | Releasing
              then K /= Own and then Owner (Current.all, K).State =
                Entry_Owners (Positive (K)).State));
      end loop;
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Entry_Node_Count) =>
           (if Entry_Nodes (Positive (I)).State = Live then
              Node (Current.all, I) = Entry_Nodes (Positive (I))));
      pragma Assert
        (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
           (if Entry_Owners (Positive (B)).State = Releasing then
              Owner (Current.all, B).State /= Live));
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Entry_Namespace_Count) =>
             (if Entry_Namespaces (Positive (I)).State = Live
               and then Entry_Namespaces (Positive (I)).Owner in
                 1 .. Owner_Ref (Entry_Owner_Count)
               and then Entry_Owners
                 (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                   Live
              then Namespace (Current.all, I) =
                Entry_Namespaces (Positive (I))));
      declare
         Sync_Before : constant State := Current.all with Ghost;
      begin
         if not Is_Doc then
            pragma Assert
              (Namespace_Count (Current.all) = Entry_Namespace_Count);
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Entry_Namespace_Count) =>
                   Namespace (Current.all, I) =
                     Entry_Namespaces (Positive (I)));
         end if;
         XML3_DOM_Bridge.Synchronize (Current.all);
         pragma Assert
           (Live_Entries_Preserved (Sync_Before, Current.all));
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Entry_Node_Count) =>
              (if Entry_Nodes (Positive (I)).State = Live then
                 Node (Sync_Before, I) = Entry_Nodes (Positive (I))));
         pragma Assert
           (for all I in Node_Ref range 1 .. Node_Ref (Entry_Node_Count) =>
              (if Entry_Nodes (Positive (I)).State = Live then
                 Node (Current.all, I) = Node (Sync_Before, I)));
         pragma Assert
           (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
              (if Entry_Owners (Positive (B)).State = Releasing then
                 Owner (Sync_Before, B).State /= Live));
         pragma Assert
           (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
              (if Entry_Owners (Positive (B)).State = Releasing then
                 Owner (Current.all, B).State /= Live));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Entry_Namespace_Count) =>
                (if Entry_Namespaces (Positive (I)).State = Live
                  and then Entry_Namespaces (Positive (I)).Owner in
                    1 .. Owner_Ref (Entry_Owner_Count)
                  and then Entry_Owners
                    (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                      Live
                 then Namespace (Sync_Before, I) =
                   Entry_Namespaces (Positive (I))));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Entry_Namespace_Count) =>
                (if Entry_Namespaces (Positive (I)).State = Live
                  and then Entry_Namespaces (Positive (I)).Owner in
                    1 .. Owner_Ref (Entry_Owner_Count)
                  and then Entry_Owners
                    (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                      Live
                 then Namespace (Current.all, I) =
                   Namespace (Sync_Before, I)));
         pragma Assert
           (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Entry_Namespace_Count) =>
                (if Entry_Namespaces (Positive (I)).State = Live
                  and then Entry_Namespaces (Positive (I)).Owner in
                    1 .. Owner_Ref (Entry_Owner_Count)
                  and then Entry_Owners
                    (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                      Live
                 then Namespace (Current.all, I) =
                   Entry_Namespaces (Positive (I))));
         if not Is_Doc then
            pragma Assert
              (Namespace_Count (Current.all) = Entry_Namespace_Count);
            pragma Assert
              (for all I in Namespace_Ref range
                 1 .. Namespace_Ref (Entry_Namespace_Count) =>
                   (if Namespace (Current.all, I).State = Live then
                      Namespace (Current.all, I) =
                        Entry_Namespaces (Positive (I))));
         end if;
      end;
      pragma Assert (Current /= null);
      pragma Assert (Valid (Current.all));
      pragma Assert (Can_Edit (Current.all));
      pragma Assert (not Projection_Required (Current.all));
      pragma Assert (XML3_DOM.Facades_Present (Current.all));
      pragma Assert (Node_Count (Current.all) >= Entry_Node_Count);
      pragma Assert (Namespace_Count (Current.all) >= Entry_Namespace_Count);
      pragma Assert (Owner_Count (Current.all) >= Entry_Owner_Count);
      pragma Assert
        (for all B in Owner_Ref range 1 .. Owner_Ref (Entry_Owner_Count) =>
           (if Entry_Owners (Positive (B)).State = Live then
              Owner (Current.all, B).State = Live));
      pragma Assert
        (for all I in Node_Ref range 1 .. Node_Ref (Entry_Node_Count) =>
           (if Entry_Nodes (Positive (I)).State = Live then
              Node (Current.all, I) = Entry_Nodes (Positive (I))));
      pragma Assert
        (for all I in Namespace_Ref range
           1 .. Namespace_Ref (Entry_Namespace_Count) =>
             (if Entry_Namespaces (Positive (I)).State = Live
               and then Entry_Namespaces (Positive (I)).Owner in
                 1 .. Owner_Ref (Entry_Owner_Count)
               and then Entry_Owners
                 (Positive (Entry_Namespaces (Positive (I)).Owner)).State =
                   Live
              then Namespace (Current.all, I) =
                Entry_Namespaces (Positive (I))));
      pragma Assert
        (Local_N in 1 .. Node_Ref (Node_Count (Current.all))
         and then Node (Current.all, Local_N).State = Live
         and then Node (Current.all, Local_N).Kind = Kind
         and then Node (Current.all, Local_N).Facade /= System.Null_Address
         and then Node (Current.all, Local_N).Parent = Null_Node
         and then Node (Current.all, Local_N).First_Child = Null_Node
         and then Node (Current.all, Local_N).First_Prop = Null_Node
         and then Node (Current.all, Local_N).First_Namespace = Null_Namespace
         and then Node (Current.all, Local_N).Last_Namespace = Null_Namespace
         and then Node (Current.all, Local_N).Namespace = Ns
         and then Node (Current.all, Local_N).Name_Length =
           (if Kind = Document_Node then 0 else Name'Length)
         and then Node (Current.all, Local_N).Content_Length =
           (if Has_Content then Content'Length else 0)
         and then Node (Current.all, Local_N).Document =
           (if Kind = Document_Node then Local_N else Null_Node)
         and then (if Kind = Document_Node then
           Local_Ns in 1 .. Namespace_Ref (Namespace_Count (Current.all))
           and then Namespace (Current.all, Local_Ns).State = Live
           and then Namespace (Current.all, Local_Ns).Owner =
             Node (Current.all, Local_N).Owner
          else Local_Ns = Null_Namespace));
      N := Local_N;
      Implicit_Ns := Local_Ns;
      Status := Created;
      if Kind = Attribute_Node then
         Empty_Attribute_Content_Lemma (Current.all, N);
      end if;
      pragma Assert (N = Local_N);
      pragma Assert (Implicit_Ns = Local_Ns);
      pragma Assert (Status = Created);
   end Create_Node;

   procedure Create_Namespace
     (Current : in out State_Access;
      Href, Prefix : String;
      Has_Href, Has_Prefix : Boolean;
      Ns : out Namespace_Ref;
      Status : out Construction_Status)
   is
      Capacity_Ok, Size_Ok, Local_Ok : Boolean;
      Bytes, Cursor, Facade_Offset : Native.Byte_Count;
      Href_Address, Prefix_Address : System.Address :=
        System.Null_Address;
      Block, Facade : System.Address := System.Null_Address;
      Own : Owner_Ref := Null_Owner;
      Local : Namespace_Ref := Null_Namespace;
   begin
      Ns := Null_Namespace;
      Status := Invalid_Argument;
      if (not Has_Href and then Href'Length /= 0)
        or else (not Has_Prefix and then Prefix'Length /= 0)
        or else (Has_Href and then Href'Length = Natural'Last)
        or else (Has_Prefix and then Prefix'Length = Natural'Last)
        or else Namespace_Count (Current.all) = Natural'Last
        or else Owner_Count (Current.all) = Natural'Last
      then
         Status := Limit_Exceeded;
         return;
      end if;
      Ensure_Capacity
        (Current, Node_Count (Current.all),
         Namespace_Count (Current.all) + 1,
         Owner_Count (Current.all) + 1, Capacity_Ok);
      if not Capacity_Ok then
         Status := No_Memory;
         return;
      end if;
      Add_Bytes (Native.Namespace_Stride, 0, Cursor, Size_Ok);
      if Has_Href then
         Add_Natural (Cursor, Href'Length + 1, Cursor, Size_Ok);
      end if;
      if Size_Ok and then Has_Prefix then
         Add_Natural (Cursor, Prefix'Length + 1, Cursor, Size_Ok);
      end if;
      Bytes := Cursor;
      if not Size_Ok or else Bytes = 0 then
         Status := Limit_Exceeded;
         return;
      end if;
      Facade_Offset := Native.Metadata_Bytes;
      Native.Allocate (Bytes, Block);
      if Block = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      Facade := Native.Offset (Block, Facade_Offset);
      if Facade = System.Null_Address then
         Native.Free (Block);
         Status := Internal_Error;
         return;
      end if;
      Native.Initialize_Namespace (Facade);
      Cursor := Native.Namespace_Stride;
      if Has_Href then
         Href_Address := Native.Offset (Block, Cursor);
         if Href_Address = System.Null_Address then
            Native.Free (Block);
            Status := Internal_Error;
            return;
         end if;
         Native.Write_String (Href_Address, 0, Href);
         Native.Write_Byte (Href_Address, Href'Length, Character'Val (0));
         Add_Natural (Cursor, Href'Length + 1, Cursor, Size_Ok);
      end if;
      if Size_Ok and then Has_Prefix then
         Prefix_Address := Native.Offset (Block, Cursor);
         if Prefix_Address = System.Null_Address then
            Native.Free (Block);
            Status := Internal_Error;
            return;
         end if;
         Native.Write_String (Prefix_Address, 0, Prefix);
         Native.Write_Byte (Prefix_Address, Prefix'Length, Character'Val (0));
      end if;
      if not Size_Ok then
         Native.Free (Block);
         Status := Limit_Exceeded;
         return;
      end if;
      Register_Owner (Current.all, Block, Own, Local_Ok);
      if not Local_Ok then
         Native.Free (Block);
         Status := Internal_Error;
         return;
      end if;
      Register_Namespace
        (Current.all, Facade, Href_Address,
         (if Has_Href then Href'Length else 0),
         Prefix_Address, (if Has_Prefix then Prefix'Length else 0),
         Own, Local, Local_Ok, True);
      if not Local_Ok then
         Release_Reservation (Current.all, Own);
         XML3_DOM_Bridge.Synchronize (Current.all);
         Status := Internal_Error;
         return;
      end if;
      Ns := Local;
      Status := Created;
   end Create_Namespace;
end XML3_DOM_Constructors;
