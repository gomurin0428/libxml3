with Ada.Unchecked_Conversion;
with Interfaces.C; use Interfaces.C;
with Interfaces;
with System.Storage_Elements; use System.Storage_Elements;
with XML3_Namespaces;
with XML3_Parser;
with XML3_Text;
with XML3_Errors;

package body XML3_C is

   use type System.Address;
   use type Interfaces.Unsigned_32;
   use type XML3_Parser.Node_Kind;
   use type XML3_Parser.Parse_Status;

   Element_Type  : constant int := 1;
   Attr_Type     : constant int := 2;
   Text_Type     : constant int := 3;
   CData_Type    : constant int := 4;
   PI_Type       : constant int := 7;
   Comment_Type  : constant int := 8;
   Document_Type : constant int := 9;
   Namespace_Decl_Type : constant int := 18;

   Max_Input : constant := XML3_Text.Max_Bytes;
   Step_Limit : constant := Integer'Last - 1;
   String_Limit : constant := Integer'Last;
   Initial_Arena : constant := 2_048;
   Allowed_Options : constant Interfaces.Unsigned_32 := 16#0008_0860#;
   Arena_Status : constant int := -1;

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

   type Xml_Ns is record
      Next         : System.Address := System.Null_Address;
      Ns_Type      : int := 0;
      Href         : System.Address := System.Null_Address;
      Prefix       : System.Address := System.Null_Address;
      Private_Data : System.Address := System.Null_Address;
      Context      : System.Address := System.Null_Address;
   end record with Convention => C;

   type Ns_Access is access all Xml_Ns;

   function To_Ns is
     new Ada.Unchecked_Conversion (System.Address, Ns_Access);

   --  Every document is a single heap block laid out as
   --  [Block_Header][document node][node array][namespace array][string bytes].
   --  Freeing a document never follows pointer fields exposed to C.
   type Block_Header is record
      Magic       : unsigned_long := 0;
      Size        : size_t := 0;
      Implicit_Ns : System.Address := System.Null_Address;
   end record with Convention => C;

   type Header_Access is access all Block_Header;

   function To_Header is
     new Ada.Unchecked_Conversion (System.Address, Header_Access);

   Block_Magic : constant unsigned_long := 16#584D_4C33_444F_4331#;

   Header_Bytes : constant Storage_Offset :=
     Block_Header'Max_Size_In_Storage_Elements;
   Node_Bytes : constant Storage_Offset :=
     Xml_Node'Max_Size_In_Storage_Elements;
   Parser_Node_Bytes : constant Storage_Offset :=
     XML3_Parser.Node'Max_Size_In_Storage_Elements;
   Ns_Bytes : constant Storage_Offset :=
     Xml_Ns'Max_Size_In_Storage_Elements;
   Name_Bytes : constant Storage_Offset :=
     XML3_Namespaces.Name_Info'Max_Size_In_Storage_Elements;
   Natural_Bytes : constant Storage_Offset :=
     Natural'Max_Size_In_Storage_Elements;

   function Add_Size (Left, Right : size_t) return size_t;
   function Multiply_Size (Left, Right : size_t) return size_t;
   function To_Storage_Offset_Checked (Value : size_t) return Storage_Offset;

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
   function Copy_C_String
     (Item : System.Address; Length : Natural) return System.Address;
   function Equal_Names (Left, Right : System.Address) return Boolean;
   function Same_Text (Item : System.Address; Value : String) return Boolean;
   function Node_At (Base : System.Address; Index : Natural) return Node_Access;
   function Namespace_At (Base : System.Address; Index : Natural) return Ns_Access;
   procedure Append_Child (Parent, Child : System.Address);
   procedure Append_Property (Element, Attribute : System.Address);
   procedure Append_Ns_Def (Element, Namespace : System.Address);
   function Implicit_Ns_For_Node (Node : System.Address) return System.Address;
   function Search_Ns_Internal
     (Node, Prefix : System.Address) return System.Address;
   function Search_Ns_By_Href_Internal
     (Node, Href : System.Address) return System.Address;
   function Content_Length (Start : System.Address) return Natural;
   procedure Content_Copy (Start, Target : System.Address);
   procedure Build
     (Input  : String;
      Huge   : Boolean;
      Result : out System.Address;
      Status : out int;
      Diagnostic : out XML3_Parser.Diagnostic_Info);
   procedure Set_Status (Target : System.Address; Value : int);
   function Parse_Buffer
     (Buffer   : System.Address;
      Size     : Interfaces.C.int;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int;
      Status   : out int) return System.Address;

   function Byte_At (Base : System.Address; Offset : Natural) return Character
   is
      Item : Character
        with Import,
          Address => Base
            + To_Storage_Offset_Checked (size_t (Offset));
   begin
      return Item;
   end Byte_At;

   function Add_Size (Left, Right : size_t) return size_t is
   begin
      if Left > size_t'Last - Right then
         raise Storage_Error;
      end if;
      return Left + Right;
   end Add_Size;

   function Multiply_Size (Left, Right : size_t) return size_t is
   begin
      if Right /= 0 and then Left > size_t'Last / Right then
         raise Storage_Error;
      end if;
      return Left * Right;
   end Multiply_Size;

   function To_Storage_Offset_Checked (Value : size_t) return Storage_Offset is
   begin
      if Value > size_t (Storage_Offset'Last) then
         raise Storage_Error;
      end if;
      return Storage_Offset (Value);
   end To_Storage_Offset_Checked;

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
      Result : constant System.Address :=
        C_Malloc (Add_Size (size_t (Value'Length), 1));
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

   function Copy_C_String
     (Item : System.Address; Length : Natural) return System.Address
   is
      Result : System.Address := System.Null_Address;
   begin
      if Item = System.Null_Address or else Length = Natural'Last then
         return System.Null_Address;
      end if;
      Result := C_Malloc (Add_Size (size_t (Length), 1));
      if Result = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Source : String (1 .. Length)
           with Import, Address => Item;
         Target : String (1 .. Length + 1)
           with Import, Address => Result;
      begin
         Target (1 .. Length) := Source;
         Target (Length + 1) := Character'Val (0);
      end;
      return Result;
   exception
      when others =>
         if Result /= System.Null_Address then
            C_Free (Result);
         end if;
         return System.Null_Address;
   end Copy_C_String;

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
         if Offset = String_Limit then
            return False;
         end if;
         Offset := Offset + 1;
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
      return To_Node
        (Base + To_Storage_Offset_Checked
           (Multiply_Size (size_t (Index), size_t (Node_Bytes))));
   end Node_At;

   function Namespace_At
     (Base : System.Address; Index : Natural) return Ns_Access
   is
   begin
      return To_Ns
        (Base + To_Storage_Offset_Checked
           (Multiply_Size (size_t (Index), size_t (Ns_Bytes))));
   end Namespace_At;

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

   procedure Append_Ns_Def (Element, Namespace : System.Address) is
      Owner : constant Node_Access := To_Node (Element);
      Item  : constant Ns_Access := To_Ns (Namespace);
      Scan  : System.Address := Owner.Ns_Def;
   begin
      if Scan = System.Null_Address then
         Owner.Ns_Def := Namespace;
         return;
      end if;
      while To_Ns (Scan).Next /= System.Null_Address loop
         Scan := To_Ns (Scan).Next;
      end loop;
      To_Ns (Scan).Next := Namespace;
      Item.Next := System.Null_Address;
   end Append_Ns_Def;

   function Implicit_Ns_For_Node
     (Node : System.Address) return System.Address
   is
      Block : System.Address;
   begin
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Doc : constant System.Address := To_Node (Node).Doc;
      begin
         if Doc = System.Null_Address then
            return System.Null_Address;
         end if;
         Block := Doc - Header_Bytes;
         if To_Header (Block).Magic /= Block_Magic then
            return System.Null_Address;
         end if;
         return To_Header (Block).Implicit_Ns;
      end;
   exception
      when others =>
         return System.Null_Address;
   end Implicit_Ns_For_Node;

   function Search_Ns_Internal
     (Node, Prefix : System.Address) return System.Address
   is
      Current : System.Address := Node;
      Steps : Natural := 0;
      Ns_Steps : Natural := 0;
   begin
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      if Same_Text (Prefix, "xml") then
         return Implicit_Ns_For_Node (Node);
      end if;
      if To_Node (Current).Node_Type = Attr_Type then
         Current := To_Node (Current).Parent;
      end if;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         declare
            Item : constant Node_Access := To_Node (Current);
            Ns_Current : System.Address;
         begin
            if Item.Node_Type = Element_Type then
               Ns_Current := Item.Ns_Def;
               while Ns_Current /= System.Null_Address loop
                  Ns_Steps := Ns_Steps + 1;
                  exit when Ns_Steps > Step_Limit;
                  if Equal_Names (To_Ns (Ns_Current).Prefix, Prefix) then
                     return Ns_Current;
                  end if;
                  Ns_Current := To_Ns (Ns_Current).Next;
               end loop;
            end if;
            Current := Item.Parent;
         end;
      end loop;
      return System.Null_Address;
   end Search_Ns_Internal;

   function Search_Ns_By_Href_Internal
     (Node, Href : System.Address) return System.Address
   is
      Current : System.Address := Node;
      Steps : Natural := 0;
      Ns_Steps : Natural := 0;
      Attribute_Input : Boolean;
   begin
      if Node = System.Null_Address or else Href = System.Null_Address then
         return System.Null_Address;
      end if;
      if Same_Text (Href, XML3_Namespaces.XML_URI) then
         return Implicit_Ns_For_Node (Node);
      end if;
      Attribute_Input := To_Node (Node).Node_Type = Attr_Type;
      if Attribute_Input then
         Current := To_Node (Current).Parent;
      end if;
      while Current /= System.Null_Address loop
         Steps := Steps + 1;
         exit when Steps > Step_Limit;
         declare
            Item : constant Node_Access := To_Node (Current);
            Ns_Current : System.Address;
         begin
            if Item.Node_Type = Element_Type then
               Ns_Current := Item.Ns_Def;
               while Ns_Current /= System.Null_Address loop
                  Ns_Steps := Ns_Steps + 1;
                  exit when Ns_Steps > Step_Limit;
                  if (not Attribute_Input
                      or else To_Ns (Ns_Current).Prefix /= System.Null_Address)
                    and then Equal_Names (To_Ns (Ns_Current).Href, Href)
                    and then Search_Ns_Internal
                      (Node, To_Ns (Ns_Current).Prefix) = Ns_Current
                  then
                     return Ns_Current;
                  end if;
                  Ns_Current := To_Ns (Ns_Current).Next;
               end loop;
            end if;
            Current := Item.Parent;
         end;
      end loop;
      return System.Null_Address;
   end Search_Ns_By_Href_Internal;

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
                  if Piece > Integer'Last - Total then
                     return Integer'Last;
                  end if;
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
                  if Piece > Integer'Last - Integer (Cursor) then
                     exit;
                  end if;
                  declare
                     Chunk : String (1 .. Piece)
                       with Import, Address => Item.Content;
                     Slot : String (1 .. Piece)
                       with Import,
                            Address => Target
                              + To_Storage_Offset_Checked (size_t (Cursor));
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
           with Import,
             Address => Target + To_Storage_Offset_Checked (size_t (Cursor));
      begin
         Terminator := Character'Val (0);
      end;
   end Content_Copy;

   procedure Build_Arena
     (Input           : String;
      Huge            : Boolean;
      Capacity        : Positive;
      Nodes_Buffer    : System.Address;
      Names_Buffer    : System.Address;
      Index_Buffer    : System.Address;
      Scratch_A_Buffer : System.Address;
      Scratch_B_Buffer : System.Address;
      Result          : out System.Address;
      Status          : out int;
      Diagnostic      : out XML3_Parser.Diagnostic_Info)
   is
      Nodes : XML3_Parser.Node_Array (1 .. Capacity)
        with Import, Address => Nodes_Buffer;
      Names : XML3_Namespaces.Name_Array (1 .. Capacity)
        with Import, Address => Names_Buffer;
      Scratch_A : String (1 .. Input'Length)
        with Import, Address => Scratch_A_Buffer;
      Scratch_B : String (1 .. Input'Length)
        with Import, Address => Scratch_B_Buffer;
      Count : XML3_Parser.Node_Id;
      Root : XML3_Parser.Node_Id;
      Parse_Status : XML3_Parser.Parse_Status;
      Parse_Diagnostic : XML3_Parser.Diagnostic_Info;
      Namespace_Diagnostic : XML3_Parser.Diagnostic_Info;
      Attribute_Values : Natural := 0;
      Namespace_Total : Natural := 1;
      Node_Total : Natural;
      String_Bytes : size_t;
      Block_Size : size_t;
      Block : System.Address := System.Null_Address;
      Nodes_Base : System.Address;
      Namespaces_Base : System.Address;
      Cursor : System.Address;
      Cursor_Limit : System.Address;
      Next_Index : Natural := 1;
      Next_Namespace : Natural := 1;
      Dom_Index : array (1 .. Capacity) of Natural
        with Import, Address => Index_Buffer;
      Value_Index : array (1 .. Capacity) of Natural
        with Import,
          Address => Index_Buffer
            + To_Storage_Offset_Checked
              (Multiply_Size (size_t (Capacity), size_t (Natural_Bytes)));
      Namespace_Index : array (1 .. Capacity) of Natural
        with Import,
          Address => Index_Buffer
            + To_Storage_Offset_Checked
              (Multiply_Size
                 (Multiply_Size
                    (size_t (Capacity), size_t (Natural_Bytes)), 2));

      procedure Put (Value : String; Target : out System.Address);
      procedure Put_Decoded
        (First, Last : Natural;
         Attribute, References : Boolean;
         Target : out System.Address);

      procedure Put (Value : String; Target : out System.Address) is
         Bytes : constant Storage_Offset :=
           To_Storage_Offset_Checked
             (Add_Size (size_t (Value'Length), 1));
      begin
         if Cursor > Cursor_Limit
           or else Bytes > Cursor_Limit - Cursor
         then
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
         Cursor := Cursor + Bytes;
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
         XML3_Text.Decode
           (Input (First .. Last), Attribute, References,
            Scratch_A (1 .. Last - First + 1), Length, Valid);
         if not Valid then
            raise Program_Error;
         end if;
         Put (Scratch_A (1 .. Length), Target);
      end Put_Decoded;
   begin
      Result := System.Null_Address;
      pragma Unreferenced (Root);
      XML3_Parser.Parse
        (Input, Scratch_A, Nodes, Count, Root, Parse_Status, Huge,
         Parse_Diagnostic);
      Diagnostic := Parse_Diagnostic;
      if Parse_Status = XML3_Parser.Arena_Exhausted then
         Status := Arena_Status;
         return;
      end if;
      if Parse_Status = XML3_Parser.Success then
         XML3_Namespaces.Resolve
           (Input, Nodes, Count, Names, Scratch_A, Scratch_B, Parse_Status,
            Namespace_Diagnostic);
         Diagnostic := Namespace_Diagnostic;
      end if;
      case Parse_Status is
         when XML3_Parser.Success => Status := Status_OK;
         when XML3_Parser.Malformed => Status := Status_Malformed;
         when XML3_Parser.Unsupported => Status := Status_Unsupported;
         when XML3_Parser.Limit_Exceeded => Status := Status_Limit_Exceeded;
         when XML3_Parser.Arena_Exhausted => Status := Arena_Status;
      end case;
      if Status /= Status_OK then
         return;
      end if;

      for K in 1 .. Count loop
         if Nodes (K).Kind = XML3_Parser.Attribute_Node
           and then not Names (K).Declaration
         then
            Attribute_Values := Attribute_Values + 1;
         end if;
         if Names (K).Declaration
           and then Names (K).Binding /= XML3_Namespaces.Implicit_XML
         then
            Namespace_Total := Namespace_Total + 1;
         end if;
      end loop;
      if Natural (Count) > Natural'Last - Attribute_Values - 1 then
         raise Storage_Error;
      end if;
      Node_Total := 1 + Natural (Count) + Attribute_Values;
      String_Bytes := Add_Size
        (Add_Size
           (Multiply_Size (size_t (Input'Length), 2),
            Multiply_Size (size_t (Natural (Count)) + 2, 16)),
         64);
      Block_Size := Add_Size
        (Add_Size
           (Add_Size (size_t (Header_Bytes),
              Multiply_Size (size_t (Node_Bytes), size_t (Node_Total))),
            Multiply_Size (size_t (Ns_Bytes), size_t (Namespace_Total))),
         String_Bytes);
      if Block_Size > size_t (Storage_Offset'Last) then
         raise Storage_Error;
      end if;

      Block := C_Malloc (Block_Size);
      if Block = System.Null_Address then
         Status := Status_No_Memory;
         return;
      end if;

      Nodes_Base := Block + Header_Bytes;
      Namespaces_Base :=
        Nodes_Base + To_Storage_Offset_Checked
          (Multiply_Size (size_t (Node_Total), size_t (Node_Bytes)));
      Cursor :=
        Namespaces_Base + To_Storage_Offset_Checked
          (Multiply_Size (size_t (Namespace_Total), size_t (Ns_Bytes)));
      Cursor_Limit := Cursor + To_Storage_Offset_Checked (String_Bytes);
      for Index in 0 .. Node_Total - 1 loop
         Node_At (Nodes_Base, Index).all := (others => <>);
      end loop;
      for Index in 0 .. Namespace_Total - 1 loop
         Namespace_At (Namespaces_Base, Index).all := (others => <>);
      end loop;
      To_Header (Block).all :=
        (Magic => Block_Magic,
         Size => Block_Size,
         Implicit_Ns => Namespace_At (Namespaces_Base, 0).all'Address);

      declare
         Document : constant Node_Access := Node_At (Nodes_Base, 0);
         Implicit : constant Ns_Access := Namespace_At (Namespaces_Base, 0);
      begin
         Document.Node_Type := Document_Type;
         Document.Doc := Nodes_Base;
         Implicit.Ns_Type := Namespace_Decl_Type;
         Put (XML3_Namespaces.XML_URI, Implicit.Href);
         Put ("xml", Implicit.Prefix);
      end;

      for K in 1 .. Count loop
         Dom_Index (K) := Next_Index;
         Next_Index := Next_Index + 1;
         if Nodes (K).Kind = XML3_Parser.Attribute_Node
           and then not Names (K).Declaration
         then
            Value_Index (K) := Next_Index;
            Next_Index := Next_Index + 1;
         end if;
         if Names (K).Declaration
           and then Names (K).Binding /= XML3_Namespaces.Implicit_XML
         then
            Namespace_Index (K) := Next_Namespace;
            Next_Namespace := Next_Namespace + 1;
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
                  Put (Input (Names (K).Local_First .. Source.Name_Last),
                       Item.Name);
               when XML3_Parser.Attribute_Node =>
                  if not Names (K).Declaration then
                     Item.Node_Type := Attr_Type;
                     Put
                       (Input (Names (K).Local_First .. Source.Name_Last),
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
                        Value.Parent :=
                          Node_At (Nodes_Base, Dom_Index (K)).all'Address;
                        Item.Children :=
                          Node_At (Nodes_Base, Value_Index (K)).all'Address;
                        Item.Last := Item.Children;
                     end;
                  end if;
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
              Node_At (Nodes_Base, Dom_Index (K)).all'Address;
            Owner : constant System.Address :=
              (if Nodes (K).Parent = 0 then Nodes_Base
               else Node_At
                 (Nodes_Base, Dom_Index (Nodes (K).Parent)).all'Address);
         begin
            if Nodes (K).Kind = XML3_Parser.Attribute_Node then
               if not Names (K).Declaration then
                  Append_Property (Owner, Child);
               end if;
            else
               Append_Child (Owner, Child);
            end if;
         end;
      end loop;

      for K in 1 .. Count loop
         if Names (K).Declaration
           and then Names (K).Binding /= XML3_Namespaces.Implicit_XML
         then
            declare
               Source : constant XML3_Parser.Node := Nodes (K);
               Namespace : constant Ns_Access :=
                 Namespace_At (Namespaces_Base, Namespace_Index (K));
               Owner : constant System.Address :=
                 Node_At (Nodes_Base, Dom_Index (Source.Parent)).all'Address;
            begin
               Namespace.Ns_Type := Namespace_Decl_Type;
               if Names (K).Prefix_Last >= Source.Name_First then
                  Put
                    (Input (Names (K).Local_First .. Source.Name_Last),
                     Namespace.Prefix);
               end if;
               Put_Decoded
                 (Source.Value_First, Source.Value_Last,
                  True, True, Namespace.Href);
               Append_Ns_Def (Owner, Namespace.all'Address);
            end;
         end if;
      end loop;

      for K in 1 .. Count loop
         if Nodes (K).Kind = XML3_Parser.Element_Node
           or else (Nodes (K).Kind = XML3_Parser.Attribute_Node
                    and then not Names (K).Declaration)
         then
            declare
               Binding : constant XML3_Namespaces.Binding_Id :=
                 Names (K).Binding;
               Item : constant Node_Access :=
                 Node_At (Nodes_Base, Dom_Index (K));
            begin
               if Binding = XML3_Namespaces.Implicit_XML then
                  Item.Ns := To_Header (Block).Implicit_Ns;
               elsif Binding /= 0 then
                  Item.Ns :=
                    Namespace_At
                      (Namespaces_Base, Namespace_Index (Binding)).all'Address;
               end if;
            end;
         end if;
      end loop;

      Result := Nodes_Base;
   exception
      when Storage_Error =>
         if Block /= System.Null_Address then
            C_Free (Block);
         end if;
         Result := System.Null_Address;
         Status := Status_No_Memory;
      when others =>
         if Block /= System.Null_Address then
            C_Free (Block);
         end if;
         Result := System.Null_Address;
         Status := Status_Internal_Error;
   end Build_Arena;

   procedure Build
     (Input  : String;
      Huge   : Boolean;
      Result : out System.Address;
      Status : out int;
      Diagnostic : out XML3_Parser.Diagnostic_Info)
   is
      Capacity : Natural := Natural'Max
        (1, Natural'Min (Initial_Arena, Input'Length));
      Nodes_Buffer : System.Address := System.Null_Address;
      Names_Buffer : System.Address := System.Null_Address;
      Index_Buffer : System.Address := System.Null_Address;
      Scratch_A_Buffer : System.Address := System.Null_Address;
      Scratch_B_Buffer : System.Address := System.Null_Address;

      procedure Free_Workspaces is
      begin
         if Nodes_Buffer /= System.Null_Address then
            C_Free (Nodes_Buffer);
            Nodes_Buffer := System.Null_Address;
         end if;
         if Names_Buffer /= System.Null_Address then
            C_Free (Names_Buffer);
            Names_Buffer := System.Null_Address;
         end if;
         if Index_Buffer /= System.Null_Address then
            C_Free (Index_Buffer);
            Index_Buffer := System.Null_Address;
         end if;
         if Scratch_A_Buffer /= System.Null_Address then
            C_Free (Scratch_A_Buffer);
            Scratch_A_Buffer := System.Null_Address;
         end if;
         if Scratch_B_Buffer /= System.Null_Address then
            C_Free (Scratch_B_Buffer);
            Scratch_B_Buffer := System.Null_Address;
         end if;
      end Free_Workspaces;
   begin
      Result := System.Null_Address;
      Diagnostic :=
        (Domain => 1, Code => 0, Level => 0, Byte_Position => 1,
         Int1 => 0, Int2 => 0);
      loop
         Nodes_Buffer := C_Malloc
           (Multiply_Size (size_t (Capacity), size_t (Parser_Node_Bytes)));
         Names_Buffer := C_Malloc
           (Multiply_Size (size_t (Capacity), size_t (Name_Bytes)));
         Index_Buffer := C_Malloc
           (Multiply_Size
              (Multiply_Size (size_t (Capacity), size_t (Natural_Bytes)), 3));
         Scratch_A_Buffer := C_Malloc (size_t (Natural'Max (1, Input'Length)));
         Scratch_B_Buffer := C_Malloc (size_t (Natural'Max (1, Input'Length)));
         if Nodes_Buffer = System.Null_Address
           or else Names_Buffer = System.Null_Address
           or else Index_Buffer = System.Null_Address
           or else Scratch_A_Buffer = System.Null_Address
           or else Scratch_B_Buffer = System.Null_Address
         then
            Free_Workspaces;
            Status := Status_No_Memory;
            return;
         end if;
         Build_Arena
           (Input, Huge, Positive (Capacity), Nodes_Buffer, Names_Buffer,
            Index_Buffer, Scratch_A_Buffer, Scratch_B_Buffer, Result, Status,
            Diagnostic);
         Free_Workspaces;
         exit when Status /= Arena_Status;
         if Capacity = XML3_Parser.Max_Nodes then
            Status := Status_Limit_Exceeded;
            return;
         elsif Capacity > XML3_Parser.Max_Nodes / 2 then
            Capacity := XML3_Parser.Max_Nodes;
         else
            Capacity := Capacity * 2;
         end if;
      end loop;
   exception
      when Storage_Error =>
         Free_Workspaces;
         Result := System.Null_Address;
         Status := Status_No_Memory;
      when others =>
         Free_Workspaces;
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
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int;
      Status   : out int) return System.Address
   is
      Result : System.Address;
      Huge : Boolean;
      Diagnostic : XML3_Parser.Diagnostic_Info;
   begin
      if Buffer = System.Null_Address
        or else Size < 0
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
         XML3_Errors.Report_Simple (1, 32, 3, URL);
         if XML3_Errors.Last_Error_Is_OOM then
            Status := Status_No_Memory;
         end if;
         return System.Null_Address;
      end if;
      if Options < 0 then
         Status := Status_Unsupported;
         XML3_Errors.Report_Simple (1, 115, 3, URL);
         if XML3_Errors.Last_Error_Is_OOM then
            Status := Status_No_Memory;
         end if;
         return System.Null_Address;
      end if;
      declare
         Bits : constant Interfaces.Unsigned_32 :=
           Interfaces.Unsigned_32 (Options);
      begin
         if (Bits and not Allowed_Options) /= 0 then
            Status := Status_Unsupported;
            XML3_Errors.Report_Simple (1, 115, 3, URL);
            if XML3_Errors.Last_Error_Is_OOM then
               Status := Status_No_Memory;
            end if;
            return System.Null_Address;
         end if;
         Huge := (Bits and 16#0008_0000#) /= 0;
      end;
      declare
         Source : String (1 .. Natural (Size)) with Import, Address => Buffer;
      begin
         Build (Source, Huge, Result, Status, Diagnostic);
         if Status = Status_No_Memory then
            XML3_Errors.Report_Simple (6, 2, 3, URL);
         elsif Status = Status_Internal_Error then
            XML3_Errors.Report_Simple (1, 1, 3, URL);
         elsif Status = Status_Unsupported and then Diagnostic.Code = 0 then
            XML3_Errors.Report_Simple (1, 115, 3, URL);
         elsif Status /= Status_OK and then Status /= Arena_Status then
            if Diagnostic.Code = 0 then
               XML3_Errors.Report_Simple (1, 1, 3, URL);
            else
               XML3_Errors.Report
                 (Diagnostic.Domain, Diagnostic.Code, Diagnostic.Level,
                  Diagnostic.Byte_Position, Diagnostic.Int1, Source, URL);
            end if;
         end if;
         if Status /= Status_OK and then XML3_Errors.Last_Error_Is_OOM then
            Status := Status_No_Memory;
         end if;
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
        (Buffer, Size, System.Null_Address, System.Null_Address, 0, Code);
      Set_Status (Status, Code);
      return Result;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         Set_Status (Status, Status_No_Memory);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, System.Null_Address);
         Set_Status
           (Status,
            (if XML3_Errors.Last_Error_Is_OOM
             then Status_No_Memory else Status_Internal_Error));
         return System.Null_Address;
   end Read_Memory_Status;

   function Read_Memory
     (Buffer   : System.Address;
      Size     : Interfaces.C.int;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int) return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      return Parse_Buffer (Buffer, Size, URL, Encoding, Options, Code);
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, URL);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, URL);
         return System.Null_Address;
   end Read_Memory;

   function Parse_Memory
     (Buffer : System.Address;
      Size   : Interfaces.C.int) return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      return Parse_Buffer
        (Buffer, Size, System.Null_Address, System.Null_Address, 0, Code);
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, System.Null_Address);
         return System.Null_Address;
   end Parse_Memory;

   function Read_Doc
     (Cur      : System.Address;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int) return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      if Cur = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Length : constant size_t := C_Strlen (Cur);
      begin
         if Length > size_t (Max_Input)
           or else Length > size_t (int'Last)
         then
            return System.Null_Address;
         end if;
         return Parse_Buffer
           (Cur, int (Length), URL, Encoding, Options, Code);
      end;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, URL);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, URL);
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
               Owned_Result := C_Malloc (Add_Size (size_t (Length), 1));
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
               return Copy_C_String (Value, Natural (Length));
            end;
         else
            declare
               Length : constant Integer :=
                 Scan_Length (Item.Content, String_Limit);
            begin
               if Length < 0 then
                  return System.Null_Address;
               end if;
               return Copy_C_String (Item.Content, Natural (Length));
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

   function Search_Ns
     (Doc, Node, Prefix : System.Address) return System.Address
   is
      pragma Unreferenced (Doc);
   begin
      return Search_Ns_Internal (Node, Prefix);
   exception
      when others =>
         return System.Null_Address;
   end Search_Ns;

   function Search_Ns_By_Href
     (Doc, Node, Href : System.Address) return System.Address
   is
      pragma Unreferenced (Doc);
   begin
      return Search_Ns_By_Href_Internal (Node, Href);
   exception
      when others =>
         return System.Null_Address;
   end Search_Ns_By_Href;

   function Has_Ns_Prop
     (Node, Name, Href : System.Address) return System.Address
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
         declare
            Attribute : constant Node_Access := To_Node (Current);
         begin
            if Equal_Names (Attribute.Name, Name) then
               if Href = System.Null_Address then
                  if Attribute.Ns = System.Null_Address then
                     return Current;
                  end if;
               elsif Attribute.Ns /= System.Null_Address
                 and then Equal_Names (To_Ns (Attribute.Ns).Href, Href)
               then
                  return Current;
               end if;
            end if;
            Current := Attribute.Next;
         end;
      end loop;
      return System.Null_Address;
   exception
      when others =>
         return System.Null_Address;
   end Has_Ns_Prop;

   function Get_Ns_Prop
     (Node, Name, Href : System.Address) return System.Address
   is
      Attribute : constant System.Address := Has_Ns_Prop (Node, Name, Href);
   begin
      if Attribute = System.Null_Address then
         return System.Null_Address;
      end if;
      return Node_Get_Content (Attribute);
   exception
      when others =>
         return System.Null_Address;
   end Get_Ns_Prop;

   function Get_No_Ns_Prop
     (Node, Name : System.Address) return System.Address
   is
   begin
      return Get_Ns_Prop (Node, Name, System.Null_Address);
   exception
      when others =>
         return System.Null_Address;
   end Get_No_Ns_Prop;

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
