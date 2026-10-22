with Ada.Unchecked_Conversion;
with Interfaces.C; use Interfaces.C;
with System.Storage_Elements; use System.Storage_Elements;
with XML3_Parser;
with XML3_Text;

package body XML3_C is

   use type System.Address;
   use type XML3_Parser.Node_Kind;

   Element_Type  : constant int := 1;
   Attr_Type     : constant int := 2;
   Text_Type     : constant int := 3;
   CData_Type    : constant int := 4;
   PI_Type       : constant int := 7;
   Comment_Type  : constant int := 8;
   Document_Type : constant int := 9;

   Max_Input : constant := XML3_Text.Max_Bytes;
   Step_Limit : constant := 4 * XML3_Parser.Max_Nodes + 16;
   String_Limit : constant := 4 * Max_Input + 16;

   type Xml_Node is record
      Private_Data : System.Address := System.Null_Address;
      Node_Type    : int := 0;
      Name         : System.Address := System.Null_Address;
      Children     : System.Address := System.Null_Address;
      Last         : System.Address := System.Null_Address;
      Parent       : System.Address := System.Null_Address;
      Next         : System.Address := System.Null_Address;
      Prev         : System.Address := System.Null_Address;
      Doc          : System.Address := System.Null_Address;
      Ns           : System.Address := System.Null_Address;
      Content      : System.Address := System.Null_Address;
      Properties   : System.Address := System.Null_Address;
      Ns_Def       : System.Address := System.Null_Address;
   end record with Convention => C;

   type Node_Access is access all Xml_Node;

   function To_Node is
     new Ada.Unchecked_Conversion (System.Address, Node_Access);

   --  Every document is a single heap block laid out as
   --  [Block_Header][document node][node array][string bytes]. Freeing a
   --  document therefore never follows the pointer fields exposed to C.
   type Block_Header is record
      Magic : unsigned_long := 0;
      Size  : size_t := 0;
   end record with Convention => C;

   type Header_Access is access all Block_Header;

   function To_Header is
     new Ada.Unchecked_Conversion (System.Address, Header_Access);

   Block_Magic : constant unsigned_long := 16#584D_4C33_444F_4331#;

   Header_Bytes : constant Storage_Offset :=
     Block_Header'Max_Size_In_Storage_Elements;
   Node_Bytes : constant Storage_Offset :=
     Xml_Node'Max_Size_In_Storage_Elements;

   function C_Malloc (Size : size_t) return System.Address
     with Import, Convention => C, External_Name => "malloc";

   procedure C_Free (Item : System.Address)
     with Import, Convention => C, External_Name => "free";

   function C_Strcmp
     (Left, Right : System.Address) return int
     with Import, Convention => C, External_Name => "strcmp";

   function C_Strlen (Item : System.Address) return size_t
     with Import, Convention => C, External_Name => "strlen";

   function Byte_At (Base : System.Address; Offset : Natural) return Character;
   function Scan_Length (Item : System.Address; Limit : Natural) return Integer;
   function To_String (Item : System.Address; Length : Natural) return String;
   function Alloc_String (Value : String) return System.Address;
   function Equal_Names (Left, Right : System.Address) return Boolean;
   function Same_Text (Item : System.Address; Value : String) return Boolean;
   function Node_At (Base : System.Address; Index : Natural) return Node_Access;
   procedure Append_Child (Parent, Child : System.Address);
   procedure Append_Property (Element, Attribute : System.Address);
   function Content_Length (Start : System.Address) return Natural;
   procedure Content_Copy (Start, Target : System.Address);
   procedure Build
     (Input  : String;
      Result : out System.Address;
      Status : out int);
   procedure Set_Status (Target : System.Address; Value : int);
   function Parse_Buffer
     (Buffer   : System.Address;
      Size     : Interfaces.C.int;
      Encoding : System.Address;
      Options  : Interfaces.C.int;
      Status   : out int) return System.Address;

   function Byte_At (Base : System.Address; Offset : Natural) return Character
   is
      Item : Character
        with Import, Address => Base + Storage_Offset (Offset);
   begin
      return Item;
   end Byte_At;

   function Scan_Length (Item : System.Address; Limit : Natural) return Integer
   is
   begin
      if Item = System.Null_Address then
         return -1;
      end if;
      if Limit = 0 then
         return -1;
      end if;
      for Offset in 0 .. Limit - 1 loop
         if Byte_At (Item, Offset) = Character'Val (0) then
            return Offset;
         end if;
      end loop;
      return -1;
   end Scan_Length;

   function To_String (Item : System.Address; Length : Natural) return String is
      Source : String (1 .. Length) with Import, Address => Item;
   begin
      return Source;
   end To_String;

   function Alloc_String (Value : String) return System.Address is
      Result : constant System.Address := C_Malloc (Value'Length + 1);
   begin
      if Result = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Target : String (1 .. Value'Length + 1)
           with Import, Address => Result;
      begin
         Target (1 .. Value'Length) := Value;
         Target (Value'Length + 1) := Character'Val (0);
      end;
      return Result;
   end Alloc_String;

   function Equal_Names (Left, Right : System.Address) return Boolean is
      Offset : Natural := 0;
      L, R : Character;
   begin
      if Left = System.Null_Address or else Right = System.Null_Address then
         return Left = Right;
      end if;
      loop
         L := Byte_At (Left, Offset);
         R := Byte_At (Right, Offset);
         if L /= R then
            return False;
         end if;
         exit when L = Character'Val (0);
         Offset := Offset + 1;
         if Offset > String_Limit then
            return False;
         end if;
      end loop;
      return True;
   end Equal_Names;

   function Same_Text (Item : System.Address; Value : String) return Boolean is
      Length : constant Integer := Scan_Length (Item, Value'Length + 1);
   begin
      return Length = Value'Length
        and then To_String (Item, Value'Length) = Value;
   end Same_Text;

   function Node_At (Base : System.Address; Index : Natural) return Node_Access
   is
   begin
      return To_Node (Base + Storage_Offset (Index) * Node_Bytes);
   end Node_At;

   procedure Append_Child (Parent, Child : System.Address) is
      Owner : constant Node_Access := To_Node (Parent);
      Item  : constant Node_Access := To_Node (Child);
   begin
      Item.Parent := Parent;
      Item.Prev := Owner.Last;
      if Owner.Last = System.Null_Address then
         Owner.Children := Child;
      else
         To_Node (Owner.Last).Next := Child;
      end if;
      Owner.Last := Child;
   end Append_Child;

   procedure Append_Property (Element, Attribute : System.Address) is
      Owner : constant Node_Access := To_Node (Element);
      Item  : constant Node_Access := To_Node (Attribute);
      Scan  : System.Address := Owner.Properties;
   begin
      Item.Parent := Element;
      if Scan = System.Null_Address then
         Owner.Properties := Attribute;
         return;
      end if;
      while To_Node (Scan).Next /= System.Null_Address loop
         Scan := To_Node (Scan).Next;
      end loop;
      To_Node (Scan).Next := Attribute;
      Item.Prev := Scan;
   end Append_Property;

   function Content_Length (Start : System.Address) return Natural is
      Current : System.Address := To_Node (Start).Children;
      Steps : Natural := 0;
      Total : Natural := 0;
      Piece : Integer;
   begin
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         declare
            Item : constant Node_Access := To_Node (Current);
         begin
            if Item.Node_Type = Text_Type or else Item.Node_Type = CData_Type
            then
               Piece := Scan_Length (Item.Content, String_Limit);
               if Piece > 0 then
                  Total := Total + Piece;
               end if;
            end if;
            if Item.Children /= System.Null_Address then
               Current := Item.Children;
            else
               Climb : loop
                  declare
                     Up : constant Node_Access := To_Node (Current);
                  begin
                     if Up.Next /= System.Null_Address then
                        Current := Up.Next;
                        exit Climb;
                     end if;
                     Current := Up.Parent;
                     if Current = System.Null_Address
                       or else Current = Start
                     then
                        Current := System.Null_Address;
                        exit Climb;
                     end if;
                  end;
               end loop Climb;
            end if;
         end;
      end loop;
      return Total;
   end Content_Length;

   procedure Content_Copy (Start, Target : System.Address) is
      Current : System.Address := To_Node (Start).Children;
      Steps : Natural := 0;
      Cursor : Natural := 0;
      Piece : Integer;
   begin
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         declare
            Item : constant Node_Access := To_Node (Current);
         begin
            if Item.Node_Type = Text_Type or else Item.Node_Type = CData_Type
            then
               Piece := Scan_Length (Item.Content, String_Limit);
               if Piece > 0 then
                  declare
                     Chunk : String (1 .. Piece)
                       with Import, Address => Item.Content;
                     Slot : String (1 .. Piece)
                       with Import,
                            Address => Target + Storage_Offset (Cursor);
                  begin
                     Slot := Chunk;
                  end;
                  Cursor := Cursor + Piece;
               end if;
            end if;
            if Item.Children /= System.Null_Address then
               Current := Item.Children;
            else
               Climb : loop
                  declare
                     Up : constant Node_Access := To_Node (Current);
                  begin
                     if Up.Next /= System.Null_Address then
                        Current := Up.Next;
                        exit Climb;
                     end if;
                     Current := Up.Parent;
                     if Current = System.Null_Address
                       or else Current = Start
                     then
                        Current := System.Null_Address;
                        exit Climb;
                     end if;
                  end;
               end loop Climb;
            end if;
         end;
      end loop;
      declare
         Terminator : Character
           with Import, Address => Target + Storage_Offset (Cursor);
      begin
         Terminator := Character'Val (0);
      end;
   end Content_Copy;

   procedure Build
     (Input  : String;
      Result : out System.Address;
      Status : out int)
   is
      Nodes : XML3_Parser.Node_Array;
      Count : XML3_Parser.Node_Id;
      Root : XML3_Parser.Node_Id;
      Parse_Status : XML3_Parser.Parse_Status;
      Attributes : Natural := 0;
      Node_Total : Natural;
      String_Bytes : Natural;
      Block : System.Address := System.Null_Address;
      Nodes_Base : System.Address;
      Cursor : System.Address;
      Cursor_Limit : System.Address;
      Next_Index : Natural := 1;
      Dom_Index : array (1 .. XML3_Parser.Max_Nodes) of Natural :=
        [others => 0];
      Value_Index : array (1 .. XML3_Parser.Max_Nodes) of Natural :=
        [others => 0];

      procedure Put (Value : String; Target : out System.Address);
      procedure Put_Decoded
        (First, Last : Natural;
         Attribute, References : Boolean;
         Target : out System.Address);

      procedure Put (Value : String; Target : out System.Address) is
      begin
         if Cursor + Storage_Offset (Value'Length + 1) > Cursor_Limit then
            raise Program_Error;
         end if;
         declare
            Slot : String (1 .. Value'Length + 1)
              with Import, Address => Cursor;
         begin
            Slot (1 .. Value'Length) := Value;
            Slot (Value'Length + 1) := Character'Val (0);
         end;
         Target := Cursor;
         Cursor := Cursor + Storage_Offset (Value'Length + 1);
      end Put;

      procedure Put_Decoded
        (First, Last : Natural;
         Attribute, References : Boolean;
         Target : out System.Address)
      is
         Length : XML3_Text.Byte_Count;
         Valid : Boolean;
      begin
         if First > Last then
            Put ("", Target);
            return;
         end if;
         declare
            Raw : constant String (1 .. Last - First + 1) :=
              Input (First .. Last);
            Decoded : String (1 .. Raw'Length);
         begin
         XML3_Text.Decode
           (Raw, Attribute, References, Decoded, Length, Valid);
         if not Valid then
            raise Program_Error;
         end if;
         Put (Decoded (1 .. Length), Target);
         end;
      end Put_Decoded;
   begin
      Result := System.Null_Address;
      XML3_Parser.Parse (Input, Nodes, Count, Root, Parse_Status);
      case Parse_Status is
         when XML3_Parser.Success => Status := Status_OK;
         when XML3_Parser.Malformed => Status := Status_Malformed;
         when XML3_Parser.Unsupported => Status := Status_Unsupported;
         when XML3_Parser.Limit_Exceeded => Status := Status_Limit_Exceeded;
      end case;
      if Status /= Status_OK then
         return;
      end if;

      for K in 1 .. Count loop
         if Nodes (K).Kind = XML3_Parser.Attribute_Node then
            Attributes := Attributes + 1;
         end if;
      end loop;
      Node_Total := 1 + Natural (Count) + Attributes;
      String_Bytes := 2 * Input'Length + 16 * (Natural (Count) + 2) + 64;

      Block := C_Malloc
        (size_t (Header_Bytes)
         + size_t (Node_Bytes) * size_t (Node_Total)
         + size_t (String_Bytes));
      if Block = System.Null_Address then
         Status := Status_No_Memory;
         return;
      end if;

      Nodes_Base := Block + Header_Bytes;
      Cursor := Nodes_Base + Storage_Offset (Node_Total) * Node_Bytes;
      Cursor_Limit := Cursor + Storage_Offset (String_Bytes);
      for Index in 0 .. Node_Total - 1 loop
         Node_At (Nodes_Base, Index).all := (others => <>);
      end loop;
      To_Header (Block).all :=
        (Magic => Block_Magic,
         Size  => size_t (Header_Bytes)
                  + size_t (Node_Bytes) * size_t (Node_Total)
                  + size_t (String_Bytes));

      declare
         Document : constant Node_Access := Node_At (Nodes_Base, 0);
      begin
         Document.Node_Type := Document_Type;
         Document.Doc := Nodes_Base;
      end;

      for K in 1 .. Count loop
         Dom_Index (K) := Next_Index;
         Next_Index := Next_Index + 1;
         if Nodes (K).Kind = XML3_Parser.Attribute_Node then
            Value_Index (K) := Next_Index;
            Next_Index := Next_Index + 1;
         end if;
      end loop;

      for K in 1 .. Count loop
         declare
            Source : constant XML3_Parser.Node := Nodes (K);
            Item : constant Node_Access := Node_At (Nodes_Base, Dom_Index (K));
         begin
            Item.Doc := Nodes_Base;
            case Source.Kind is
               when XML3_Parser.Element_Node =>
                  Item.Node_Type := Element_Type;
                  Put (Input (Source.Name_First .. Source.Name_Last),
                       Item.Name);
               when XML3_Parser.Attribute_Node =>
                  Item.Node_Type := Attr_Type;
                  Put (Input (Source.Name_First .. Source.Name_Last),
                       Item.Name);
                  declare
                     Value : constant Node_Access :=
                       Node_At (Nodes_Base, Value_Index (K));
                  begin
                     Value.Node_Type := Text_Type;
                     Value.Doc := Nodes_Base;
                     Put ("text", Value.Name);
                     Put_Decoded
                       (Source.Value_First, Source.Value_Last,
                        True, True, Value.Content);
                     Value.Parent := Nodes_Base
                       + Storage_Offset (Dom_Index (K)) * Node_Bytes;
                     Item.Children := Nodes_Base
                       + Storage_Offset (Value_Index (K)) * Node_Bytes;
                     Item.Last := Item.Children;
                  end;
               when XML3_Parser.Text_Node =>
                  Item.Node_Type := Text_Type;
                  Put ("text", Item.Name);
                  Put_Decoded
                    (Source.Value_First, Source.Value_Last,
                     False, True, Item.Content);
               when XML3_Parser.CData_Node =>
                  Item.Node_Type := CData_Type;
                  Put_Decoded
                    (Source.Value_First, Source.Value_Last,
                     False, False, Item.Content);
               when XML3_Parser.Comment_Node =>
                  Item.Node_Type := Comment_Type;
                  Put ("comment", Item.Name);
                  Put_Decoded
                    (Source.Value_First, Source.Value_Last,
                     False, False, Item.Content);
               when XML3_Parser.PI_Node =>
                  Item.Node_Type := PI_Type;
                  Put (Input (Source.Name_First .. Source.Name_Last),
                       Item.Name);
                  Put_Decoded
                    (Source.Value_First, Source.Value_Last,
                     False, False, Item.Content);
            end case;
         end;
      end loop;

      for K in 1 .. Count loop
         declare
            Child : constant System.Address :=
              Nodes_Base + Storage_Offset (Dom_Index (K)) * Node_Bytes;
            Owner : constant System.Address :=
              (if Nodes (K).Parent = 0 then Nodes_Base
               else Nodes_Base
                    + Storage_Offset (Dom_Index (Nodes (K).Parent))
                      * Node_Bytes);
         begin
            if Nodes (K).Kind = XML3_Parser.Attribute_Node then
               Append_Property (Owner, Child);
            else
               Append_Child (Owner, Child);
            end if;
         end;
      end loop;

      Result := Nodes_Base;
   exception
      when others =>
         if Block /= System.Null_Address then
            C_Free (Block);
         end if;
         Result := System.Null_Address;
         Status := Status_Internal_Error;
   end Build;

   procedure Set_Status (Target : System.Address; Value : int) is
   begin
      if Target = System.Null_Address then
         return;
      end if;
      declare
         Slot : int with Import, Address => Target;
      begin
         Slot := Value;
      end;
   end Set_Status;

   function Parse_Buffer
     (Buffer   : System.Address;
      Size     : Interfaces.C.int;
      Encoding : System.Address;
      Options  : Interfaces.C.int;
      Status   : out int) return System.Address
   is
      Result : System.Address;
   begin
      if Buffer = System.Null_Address
        or else Size <= 0
        or else Size > int (Max_Input)
      then
         Status := Status_Invalid_Argument;
         return System.Null_Address;
      end if;
      if Encoding /= System.Null_Address
        and then not Same_Text (Encoding, "UTF-8")
        and then not Same_Text (Encoding, "utf-8")
      then
         Status := Status_Unsupported;
         return System.Null_Address;
      end if;
      if Options < 0
        or else Options mod 32 /= 0
        or else Options mod 2048 >= 128
        or else Options / 2048 > 1
      then
         Status := Status_Unsupported;
         return System.Null_Address;
      end if;
      declare
         Source : String (1 .. Natural (Size)) with Import, Address => Buffer;
      begin
         Build (Source, Result, Status);
      end;
      return Result;
   end Parse_Buffer;

   procedure Init_Parser is
   begin
      null;
   end Init_Parser;

   procedure Cleanup_Parser is
   begin
      null;
   end Cleanup_Parser;

   function Read_Memory_Status
     (Buffer : System.Address;
      Size   : Interfaces.C.int;
      Status : System.Address) return System.Address
   is
      Code : int := Status_Internal_Error;
      Result : System.Address;
   begin
      Result := Parse_Buffer
        (Buffer, Size, System.Null_Address, 0, Code);
      Set_Status (Status, Code);
      return Result;
   exception
      when others =>
         Set_Status (Status, Status_Internal_Error);
         return System.Null_Address;
   end Read_Memory_Status;

   function Read_Memory
     (Buffer   : System.Address;
      Size     : Interfaces.C.int;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int) return System.Address
   is
      pragma Unreferenced (URL);
      Code : int := Status_Internal_Error;
   begin
      return Parse_Buffer (Buffer, Size, Encoding, Options, Code);
   exception
      when others =>
         return System.Null_Address;
   end Read_Memory;

   function Parse_Memory
     (Buffer : System.Address;
      Size   : Interfaces.C.int) return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      return Parse_Buffer (Buffer, Size, System.Null_Address, 0, Code);
   exception
      when others =>
         return System.Null_Address;
   end Parse_Memory;

   function Read_Doc
     (Cur      : System.Address;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int) return System.Address
   is
      pragma Unreferenced (URL);
      Length : constant Integer := Scan_Length (Cur, Max_Input);
      Code : int := Status_Internal_Error;
   begin
      if Length <= 0 then
         return System.Null_Address;
      end if;
      return Parse_Buffer (Cur, int (Length), Encoding, Options, Code);
   exception
      when others =>
         return System.Null_Address;
   end Read_Doc;

   function Parse_Doc (Cur : System.Address) return System.Address is
   begin
      return Read_Doc (Cur, System.Null_Address, System.Null_Address, 0);
   end Parse_Doc;

   function Doc_Get_Root_Element (Doc : System.Address) return System.Address
   is
      Current : System.Address;
      Steps : Natural := 0;
   begin
      if Doc = System.Null_Address
        or else To_Node (Doc).Node_Type /= Document_Type
      then
         return System.Null_Address;
      end if;
      Current := To_Node (Doc).Children;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         if To_Node (Current).Node_Type = Element_Type then
            return Current;
         end if;
         Current := To_Node (Current).Next;
      end loop;
      return System.Null_Address;
   exception
      when others =>
         return System.Null_Address;
   end Doc_Get_Root_Element;

   procedure Free_Doc (Doc : System.Address) is
   begin
      if Doc = System.Null_Address then
         return;
      end if;
      declare
         Block : constant System.Address := Doc - Header_Bytes;
      begin
         if To_Header (Block).Magic /= Block_Magic then
            return;
         end if;
         To_Header (Block).Magic := 0;
         C_Free (Block);
      end;
   exception
      when others =>
         null;
   end Free_Doc;

   function Node_Get_Content (Node : System.Address) return System.Address is
      Owned_Result : System.Address := System.Null_Address;
   begin
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Item : constant Node_Access := To_Node (Node);
      begin
         if Item.Node_Type = Element_Type
           or else Item.Node_Type = Document_Type
         then
            declare
               Length : constant Natural := Content_Length (Node);
            begin
               Owned_Result := C_Malloc (size_t (Length) + 1);
               if Owned_Result = System.Null_Address then
                  return System.Null_Address;
               end if;
               Content_Copy (Node, Owned_Result);
               declare
                  Result : constant System.Address := Owned_Result;
               begin
                  Owned_Result := System.Null_Address;
                  return Result;
               end;
            end;
         elsif Item.Node_Type = Attr_Type then
            if Item.Children = System.Null_Address then
               return Alloc_String ("");
            end if;
            declare
               Value : constant System.Address :=
                 To_Node (Item.Children).Content;
               Length : constant Integer := Scan_Length (Value, String_Limit);
            begin
               if Length < 0 then
                  return System.Null_Address;
               end if;
               return Alloc_String (To_String (Value, Length));
            end;
         else
            declare
               Length : constant Integer :=
                 Scan_Length (Item.Content, String_Limit);
            begin
               if Length < 0 then
                  return System.Null_Address;
               end if;
               return Alloc_String (To_String (Item.Content, Length));
            end;
         end if;
      end;
   exception
      when others =>
         if Owned_Result /= System.Null_Address then
            C_Free (Owned_Result);
         end if;
         return System.Null_Address;
   end Node_Get_Content;

   function Has_Prop
     (Node : System.Address;
      Name : System.Address) return System.Address
   is
      Current : System.Address;
      Steps : Natural := 0;
   begin
      if Node = System.Null_Address
        or else Name = System.Null_Address
        or else To_Node (Node).Node_Type /= Element_Type
      then
         return System.Null_Address;
      end if;
      Current := To_Node (Node).Properties;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         if Equal_Names (To_Node (Current).Name, Name) then
            return Current;
         end if;
         Current := To_Node (Current).Next;
      end loop;
      return System.Null_Address;
   exception
      when others =>
         return System.Null_Address;
   end Has_Prop;

   function Get_Prop
     (Node : System.Address;
      Name : System.Address) return System.Address
   is
      Attribute : constant System.Address := Has_Prop (Node, Name);
   begin
      if Attribute = System.Null_Address then
         return System.Null_Address;
      end if;
      return Node_Get_Content (Attribute);
   exception
      when others =>
         return System.Null_Address;
   end Get_Prop;

   function First_Element_Child (Parent : System.Address) return System.Address
   is
      Current : System.Address;
      Steps : Natural := 0;
   begin
      if Parent = System.Null_Address then
         return System.Null_Address;
      end if;
      Current := To_Node (Parent).Children;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         if To_Node (Current).Node_Type = Element_Type then
            return Current;
         end if;
         Current := To_Node (Current).Next;
      end loop;
      return System.Null_Address;
   exception
      when others =>
         return System.Null_Address;
   end First_Element_Child;

   function Next_Element_Sibling (Node : System.Address) return System.Address
   is
      Current : System.Address;
      Steps : Natural := 0;
   begin
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      Current := To_Node (Node).Next;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         if To_Node (Current).Node_Type = Element_Type then
            return Current;
         end if;
         Current := To_Node (Current).Next;
      end loop;
      return System.Null_Address;
   exception
      when others =>
         return System.Null_Address;
   end Next_Element_Sibling;

   function Child_Element_Count
     (Parent : System.Address) return Interfaces.C.unsigned_long
   is
      Current : System.Address;
      Steps : Natural := 0;
      Total : unsigned_long := 0;
   begin
      if Parent = System.Null_Address then
         return 0;
      end if;
      Current := To_Node (Parent).Children;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         if To_Node (Current).Node_Type = Element_Type then
            Total := Total + 1;
         end if;
         Current := To_Node (Current).Next;
      end loop;
      return Total;
   exception
      when others =>
         return 0;
   end Child_Element_Count;

   function Str_Compare
     (Left  : System.Address;
      Right : System.Address) return Interfaces.C.int
   is
   begin
      if Left = Right then
         return 0;
      elsif Left = System.Null_Address then
         return -1;
      elsif Right = System.Null_Address then
         return 1;
      end if;
      return C_Strcmp (Left, Right);
   exception
      when others =>
         return 0;
   end Str_Compare;

   function Str_Equal
     (Left  : System.Address;
      Right : System.Address) return Interfaces.C.int
   is
   begin
      if Left = Right then
         return 1;
      elsif Left = System.Null_Address or else Right = System.Null_Address then
         return 0;
      elsif C_Strcmp (Left, Right) = 0 then
         return 1;
      else
         return 0;
      end if;
   exception
      when others =>
         return 0;
   end Str_Equal;

   function Str_Length (Item : System.Address) return Interfaces.C.int is
      Length : size_t;
   begin
      if Item = System.Null_Address then
         return 0;
      end if;
      Length := C_Strlen (Item);
      if Length > size_t (int'Last) then
         return -1;
      end if;
      return int (Length);
   exception
      when others =>
         return 0;
   end Str_Length;

   procedure Free (Item : System.Address) is
   begin
      if Item /= System.Null_Address then
         C_Free (Item);
      end if;
   exception
      when others =>
         null;
   end Free;

end XML3_C;
