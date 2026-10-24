with System;
with XML3_DOM_Allocation;

package body XML3_DOM.Materialize with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   package Allocation renames XML3_DOM_Allocation;
   package Constructors renames XML3_DOM_Constructors;
   use type Native.Byte_Count;
   use type XML3_Parser.Node_Kind;
   use type Allocation.Import_Maps_Access;

   procedure Count_Arena_Holders (Nodes : Node_View_Array; Count : Natural)
     with Ghost, Global => null,
       Pre => Nodes'First = 1 and then Count <= Nodes'Last
         and then (for all I in 1 .. Count =>
           Nodes (I).State = Live and then Nodes (I).Owner = 1),
       Post => Holder_Count (Nodes, 1, Count) = Count;

   procedure Count_Arena_Holders (Nodes : Node_View_Array; Count : Natural) is
   begin
      for I in 1 .. Count loop
         pragma Assert (Holds (Nodes (I), 1));
         pragma Loop_Invariant (Holder_Count (Nodes, 1, I) = I);
      end loop;
   end Count_Arena_Holders;

   function Arena_Node (S : State; I : Positive) return Boolean is
     (S.Graph.Nodes (I).State = Live
      and then S.Graph.Nodes (I).Owner = 1
      and then S.Graph.Nodes (I).Document = 1
      and then S.Graph.Nodes (I).Facade /= System.Null_Address
      and then (if I = 1 then
        S.Graph.Nodes (I).Kind = Document_Node
        and then S.Graph.Nodes (I).Parent = Null_Node
      else S.Graph.Nodes (I).Kind /= Document_Node
        and then S.Graph.Nodes (I).Parent /= Null_Node)
      and then Node_Links_Valid (S.Graph, I)
     )
     with Global => null,
       Pre => Well_Sized (S) and then I <= S.Graph.Node_Used,
       Annotate => (GNATprove, Inline_For_Proof);

   function Arena_Namespace (S : State; I : Positive) return Boolean is
     (S.Graph.Namespaces (I).State = Live
      and then S.Graph.Namespaces (I).Owner = 1
      and then S.Graph.Namespaces (I).Facade /= System.Null_Address
     and then Namespace_Links_Valid (S.Graph, I))
     with Global => null,
       Pre => Well_Sized (S) and then I <= S.Graph.Ns_Used,
       Annotate => (GNATprove, Inline_For_Proof);

   function Check_Arena (S : State) return Boolean
     with Global => null, Pre => Well_Sized (S),
       Post => (if Check_Arena'Result then
         Valid (S) and then Can_Edit (S) and then Facades_Present (S)
         and then XML3_DOM.Import.Is_Arena (S)
         and then Projection_Required (S));

   function Check_Arena (S : State) return Boolean is
   begin
      if S.Graph.Node_Used = 0 or else S.Graph.Owner_Used /= 1
        or else S.Effects /=
          (Phase => Editing, Dirty => True, Cursor => 0,
           Released_Through => 0, Active_Release => Null_Owner)
        or else S.Graph.Owners (1).State /= Live
        or else S.Graph.Owners (1).Address = System.Null_Address
        or else S.Graph.Owners (1).Reservations /= 0
        or else S.Graph.Owners (1).References /= S.Graph.Node_Used
        or else S.Graph.Owners (1).Release_Emitted
      then
         return False;
      end if;

      for I in 1 .. S.Graph.Node_Used loop
         if not Arena_Node (S, I) then
            return False;
         end if;
         pragma Loop_Invariant
           (for all J in 1 .. I => Arena_Node (S, J));
      end loop;
      for I in 1 .. S.Graph.Ns_Used loop
         if not Arena_Namespace (S, I) then
            return False;
         end if;
        pragma Loop_Invariant
          (for all J in 1 .. I => Arena_Namespace (S, J));
        pragma Loop_Invariant
          (for all J in 1 .. S.Graph.Node_Used => Arena_Node (S, J));
      end loop;

      pragma Assert (Facades_Present (S));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (I).State = Live
             and then S.Graph.Nodes (I).Owner = 1
             and then S.Graph.Nodes (I).Document = 1
             and then Node_Links_Valid (S.Graph, I));
      pragma Assert
        (for all I in 1 .. S.Graph.Node_Used =>
           S.Graph.Nodes (I).Facade /= System.Null_Address);
      pragma Assert
        (for all I in 1 .. S.Graph.Ns_Used =>
           S.Graph.Namespaces (I).State = Live
             and then S.Graph.Namespaces (I).Owner = 1
             and then S.Graph.Namespaces (I).Facade /= System.Null_Address
             and then Namespace_Links_Valid (S.Graph, I));
      Count_Arena_Holders (S.Graph.Nodes, S.Graph.Node_Used);
      pragma Assert (Effects_Valid (S));
      pragma Assert (Pins_In_Range (S));
      pragma Assert (Pin_Equation (S));
      pragma Assert (Links_Valid (S));
      return True;
   end Check_Arena;

   function Span_Length (First : Positive; Last : Natural) return Natural is
     (if First <= Last then Last - First + 1 else 0);

   procedure Add_Bytes
     (Left, Right : Native.Byte_Count;
      Result : out Native.Byte_Count; Success : in out Boolean)
   with Post =>
     (if not Success'Old then
        not Success and then Result = 0
      elsif Left <= Native.Byte_Count'Last - Right then
        Success and then Result = Left + Right
      else
        not Success and then Result = 0)
   is
   begin
      if not Success then
         Result := 0;
      elsif Left > Native.Byte_Count'Last - Right then
         Result := 0;
         Success := False;
      else
         Result := Left + Right;
      end if;
   end Add_Bytes;

   procedure Add_Natural
     (Left : Native.Byte_Count; Right : Natural;
      Result : out Native.Byte_Count; Success : in out Boolean)
   is
   begin
      Add_Bytes (Left, Native.Byte_Count (Right), Result, Success);
   end Add_Natural;

   procedure Mul_Bytes
     (Left : Native.Byte_Count; Right : Natural;
      Result : out Native.Byte_Count; Success : in out Boolean)
   with Post =>
     (if not Success'Old then
        not Success and then Result = 0
      elsif Right = 0 then
        Success and then Result = 0
      elsif Left <= Native.Byte_Count'Last / Native.Byte_Count (Right) then
        Success and then Result = Left * Native.Byte_Count (Right)
      else
        not Success and then Result = 0)
   is
   begin
      if not Success then
         Result := 0;
      elsif Right = 0 then
         Result := 0;
      elsif Left > Native.Byte_Count'Last / Native.Byte_Count (Right) then
         Result := 0;
         Success := False;
      else
         Result := Left * Native.Byte_Count (Right);
      end if;
   end Mul_Bytes;

   procedure Add_Span
     (Total : in out Native.Byte_Count; First : Positive; Last : Natural;
      Success : in out Boolean)
     with Global => null,
       Post => Total >= Total'Old
         and then (if not Success'Old then not Success)
   is
      Next : Native.Byte_Count;
   begin
      if Success then
         if Span_Length (First, Last) = Natural'Last then
            Success := False;
         else
            Add_Natural (Total, Span_Length (First, Last) + 1, Next, Success);
            if Success then
               Total := Next;
            end if;
         end if;
      end if;
   end Add_Span;

   procedure Add_Constant
     (Total : in out Native.Byte_Count; Value : String;
      Success : in out Boolean)
     with Global => null, Pre => Value'Length <= XML3_Text.Max_Bytes,
       Post => Total >= Total'Old
         and then (if not Success'Old then not Success)
   is
      Next : Native.Byte_Count;
   begin
      if Success then
         Add_Natural (Total, Value'Length + 1, Next, Success);
         if Success then
            Total := Next;
         end if;
      end if;
   end Add_Constant;

   procedure Put_Span
     (Base : System.Address; Capacity : Native.Byte_Count;
      Cursor : in out Native.Byte_Count; Input : String;
      First : Positive; Last : Natural; Address : out System.Address;
      Success : in out Boolean)
   with Global => (In_Out => Native.Foreign_Memory),
     Pre => Input'First = 1
     and then Input'Length <= XML3_Text.Max_Bytes
     and then First <= Input'Length + 1
     and then Last <= Input'Length,
     Post => Cursor >= Cursor'Old
       and then (if not Success'Old then not Success)
       and then (if Success then
         Address /= System.Null_Address and then Cursor <= Capacity
       else Cursor = Cursor'Old and then Address = System.Null_Address)
   is
      Length : constant Natural := Span_Length (First, Last);
      Need : Native.Byte_Count := 0;
      Target_Address : System.Address;
   begin
      Address := System.Null_Address;
      if not Success then
         return;
      end if;
      if Length = Natural'Last then
         Success := False;
         return;
      end if;
      Need := Native.Byte_Count (Length + 1);
      if Cursor > Capacity or else Need > Capacity - Cursor then
         Success := False;
         return;
      end if;
      Target_Address := Native.Offset (Base, Cursor);
      if Target_Address = System.Null_Address then
         Success := False;
         return;
      end if;
      if Length > 0 then
         Native.Write_String (Target_Address, 0, Input (First .. Last));
      end if;
      Native.Write_Byte (Target_Address, Length, Character'Val (0));
      Address := Target_Address;
      Cursor := Cursor + Need;
   end Put_Span;

   procedure Put_Constant
     (Base : System.Address; Capacity : Native.Byte_Count;
      Cursor : in out Native.Byte_Count; Value : String;
      Address : out System.Address; Success : in out Boolean)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Value'First = 1 and then Value'Length <= XML3_Text.Max_Bytes,
       Post => Cursor >= Cursor'Old
         and then (if not Success'Old then not Success)
         and then (if Success then
           Address /= System.Null_Address and then Cursor <= Capacity
         else Cursor = Cursor'Old and then Address = System.Null_Address)
   is
   begin
      Put_Span (Base, Capacity, Cursor, Value, 1,
                Value'Length, Address, Success);
   end Put_Constant;

   procedure Put_Decoded
     (Base : System.Address; Capacity : Native.Byte_Count;
      Cursor : in out Native.Byte_Count; Input : String;
      First : Positive; Last : Natural; Attribute, References : Boolean;
      Scratch : in out String; Address : out System.Address;
      Length : out Natural; Success : in out Boolean)
   with Global => (In_Out => Native.Foreign_Memory),
     Pre => Input'First = 1
     and then Input'Length <= XML3_Text.Max_Bytes
     and then First <= Input'Length + 1
     and then Last <= Input'Length
     and then Scratch'First = 1 and then Scratch'Length = Input'Length,
     Post => Cursor >= Cursor'Old
       and then Length <= Span_Length (First, Last)
       and then (if not Success'Old then not Success)
       and then (if Success then
         Address /= System.Null_Address and then Cursor <= Capacity
       else Cursor = Cursor'Old and then Address = System.Null_Address)
   is
      Raw_Length : constant Natural := Span_Length (First, Last);
      Decoded : XML3_Text.Byte_Count;
      Good : Boolean;
      Target_Address : System.Address;
   begin
      Address := System.Null_Address;
      Length := 0;
      if not Success then
         return;
      end if;
      if Raw_Length = 0 then
         Put_Span (Base, Capacity, Cursor, Scratch, 1, 0,
                   Target_Address, Success);
         Address := Target_Address;
         return;
      end if;
      if Raw_Length > Scratch'Length then
         Success := False;
         return;
      end if;
      XML3_Text.Decode
        (Input (First .. Last), Attribute, References,
         Scratch (1 .. Raw_Length), Decoded, Good);
      if not Good or else Decoded > Raw_Length then
         Success := False;
         return;
      end if;
      Length := Natural (Decoded);
      Put_Span (Base, Capacity, Cursor, Scratch, 1, Length,
                Target_Address, Success);
      Address := Target_Address;
   end Put_Decoded;

   procedure Add_Node_Budget
     (Nodes : XML3_Parser.Node_Array;
      Names : XML3_Namespaces.Name_Array; Count : XML3_Parser.Node_Id;
      Total : in out Native.Byte_Count; Success : in out Boolean)
     with Global => null,
       Pre => Nodes'First = 1 and then Names'First = 1
         and then Count <= Nodes'Last and then Count <= Names'Last,
       Post => Total >= Total'Old
         and then (if not Success'Old then not Success)
   is
      Item : XML3_Parser.Node;
   begin
      Add_Constant (Total, "1.0", Success);
      Add_Constant (Total, XML3_Namespaces.XML_URI, Success);
      Add_Constant (Total, "xml", Success);
      for K in 1 .. Count loop
         pragma Loop_Invariant (Total >= Total'Loop_Entry);
         pragma Loop_Invariant
           (if not Success'Loop_Entry then not Success);
         Item := Nodes (K);
         if not Names (K).Declaration then
            case Item.Kind is
               when XML3_Parser.Element_Node | XML3_Parser.Attribute_Node =>
                  Add_Span (Total, Item.Name_First,
                            Nodes (K).Name_Last, Success);
               when XML3_Parser.Text_Node =>
                  Add_Constant (Total, "text", Success);
               when XML3_Parser.CData_Node =>
                  null;
               when XML3_Parser.Comment_Node =>
                  Add_Constant (Total, "comment", Success);
               when XML3_Parser.PI_Node =>
                  Add_Span (Total, Item.Name_First, Item.Name_Last, Success);
            end case;
            if Item.Kind = XML3_Parser.Attribute_Node then
               Add_Constant (Total, "text", Success);
               Add_Span (Total, Item.Value_First, Item.Value_Last, Success);
            elsif Item.Kind in XML3_Parser.Text_Node | XML3_Parser.CData_Node |
              XML3_Parser.Comment_Node | XML3_Parser.PI_Node
            then
               Add_Span (Total, Item.Value_First, Item.Value_Last, Success);
            end if;
         elsif Names (K).Binding /= XML3_Namespaces.Implicit_XML then
            Add_Span (Total, Item.Value_First, Item.Value_Last, Success);
            if Names (K).Prefix_Last >= Item.Name_First then
               Add_Span (Total, Names (K).Local_First, Item.Name_Last, Success);
            end if;
         end if;
      end loop;
   end Add_Node_Budget;

   procedure Initialize_Candidate
     (S : in out State; Capacity : Positive)
   with Global => null, Pre => S.Capacity = Capacity
     and then S.Graph.Capacity = Capacity,
     Post => Well_Sized (S) and then Can_Edit (S)
       and then Projection_Required (S)
       and then S.Graph.Node_Used = 0 and then S.Graph.Ns_Used = 0
       and then S.Graph.Owner_Used = 0
       and then S.Effects =
         (Phase => Editing, Dirty => True, Cursor => 0,
          Released_Through => 0, Active_Release => Null_Owner)
       and then (for all I in 1 .. Capacity =>
         S.Graph.Nodes (I) = Node_View'(others => <>)
         and then S.Graph.Namespaces (I) = Namespace_View'(others => <>)
         and then S.Graph.Owners (I) = Owner_View'(others => <>)
         and then not S.Marks (I))
   is
   begin
      for I in S.Graph.Nodes'Range loop
         S.Graph.Nodes (I) := (others => <>);
         S.Graph.Namespaces (I) := (others => <>);
         S.Graph.Owners (I) := (others => <>);
         S.Marks (I) := False;
         pragma Loop_Invariant
           (for all J in 1 .. I =>
             S.Graph.Nodes (J) = Node_View'(others => <>)
             and then S.Graph.Namespaces (J) = Namespace_View'(others => <>)
             and then S.Graph.Owners (J) = Owner_View'(others => <>)
             and then not S.Marks (J));
      end loop;
      S.Graph.Node_Used := 0;
      S.Graph.Ns_Used := 0;
      S.Graph.Owner_Used := 0;
      S.Effects := (Phase => Editing, Dirty => True, Cursor => 0,
                    Released_Through => 0, Active_Release => Null_Owner);
   end Initialize_Candidate;

   procedure Fill_Node
     (S : in out State; Maps : Allocation.Import_Maps;
      Input : String; P : XML3_Parser.Node; Info : XML3_Namespaces.Name_Info;
      Current : Node_Ref; Base : System.Address;
      Node_Bytes, Node_Facade_Bytes, Arena_Bytes : Native.Byte_Count;
      Cursor : in out Native.Byte_Count; Scratch : in out String;
      Ok : in out Boolean)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Well_Sized (S)
         and then Input'First = 1
         and then Input'Length <= XML3_Text.Max_Bytes
         and then Scratch'First = 1 and then Scratch'Length = Input'Length
         and then P.Name_Last <= Input'Length
         and then P.Value_Last <= Input'Length
         and then P.Name_First <= P.Name_Last + 1
         and then P.Value_First <= P.Value_Last + 1
         and then Info.Local_First <= P.Name_Last + 1,
       Post => Well_Sized (S)
         and then S.Graph.Node_Used = S.Graph.Node_Used'Old
         and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
         and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
         and then S.Graph.Owners = S.Graph.Owners'Old
         and then S.Effects = S.Effects'Old
         and then S.Marks = S.Marks'Old
         and then Cursor >= Cursor'Old
         and then (if not Ok'Old then not Ok)
         and then S.Graph.Namespaces = S.Graph.Namespaces'Old
   is
      Node_Count_New : constant Natural := S.Graph.Node_Used;
      Ns_Count_New : constant Natural := S.Graph.Ns_Used;
      Count : constant Positive := Maps.Capacity;
      Node_Offset, Facade_Offset : Native.Byte_Count;
      Target_Address : System.Address := System.Null_Address;
   begin
      if not Ok then
         return;
      end if;
   declare
      Parent_Parser : constant XML3_Parser.Node_Id := P.Parent;
      Parent_Node : Node_Ref;
      Kind : Node_Kind;
      Name_Address, Content_Address : System.Address;
      Name_Length, Content_Length : Natural := 0;
      Node_Value : Node_View;
      Tail : Node_Ref := 0;
      Ns_Value : Namespace_Ref := 0;
   begin
      if Parent_Parser = 0 then
         Parent_Node := 1;
      elsif Parent_Parser > Count
        or else Maps.Nodes (Parent_Parser) = Null_Node
      then
         Ok := False;
         return;
      else
         Parent_Node := Maps.Nodes (Parent_Parser);
      end if;
     if Parent_Node = 0
       or else Natural (Parent_Node) > Node_Count_New
       or else S.Graph.Nodes
         (Positive (Parent_Node)).State /= Live
     then
         Ok := False;
         return;
      end if;
     if Current < 2 or else Natural (Current) > Node_Count_New then
        Ok := False;
        return;
     end if;
     Mul_Bytes (Native.Node_Stride, Natural (Current) - 1,
                 Node_Offset, Ok);
     if Ok then
         Add_Bytes (Node_Offset, Native.Metadata_Bytes,
                    Facade_Offset, Ok);
         if Ok and then
           (Facade_Offset < Native.Metadata_Bytes
            or else Facade_Offset > Node_Bytes
            or else Node_Facade_Bytes > Node_Bytes - Facade_Offset)
         then
            Ok := False;
         end if;
         if Ok then
            Target_Address := Native.Offset (Base, Facade_Offset);
            Ok := Target_Address /= System.Null_Address;
         end if;
      end if;
      if not Ok then
         return;
      end if;
      if P.Kind = XML3_Parser.Attribute_Node then
         if S.Graph.Nodes (Positive (Parent_Node)).Kind /=
           Element_Node
         then
            Ok := False;
            return;
         end if;
         Kind := Attribute_Node;
      else
         Kind := (case P.Kind is
           when XML3_Parser.Element_Node => Element_Node,
           when XML3_Parser.Text_Node => Text_Node,
           when XML3_Parser.CData_Node => CData_Node,
           when XML3_Parser.Comment_Node => Comment_Node,
           when XML3_Parser.PI_Node => Processing_Instruction_Node,
           when XML3_Parser.Attribute_Node => Attribute_Node);
         if S.Graph.Nodes (Positive (Parent_Node)).Kind not in
           Document_Node | Element_Node
         then
            Ok := False;
            return;
         end if;
      end if;
      if Info.Binding = XML3_Namespaces.Implicit_XML then
         Ns_Value := 1;
      elsif Info.Binding /= 0 then
         if Info.Binding > Count
           or else Maps.Namespaces (Info.Binding) = 0
           or else Natural
             (Maps.Namespaces (Info.Binding)) > Ns_Count_New
         then
            Ok := False;
            return;
         end if;
         Ns_Value := Maps.Namespaces (Info.Binding);
      end if;
      Name_Address := System.Null_Address;
      Content_Address := System.Null_Address;
      if P.Kind in XML3_Parser.Element_Node |
        XML3_Parser.Attribute_Node
      then
         Put_Span (Base, Arena_Bytes, Cursor, Input, Info.Local_First,
                   P.Name_Last, Name_Address, Ok);
         Name_Length := Span_Length
           (Info.Local_First, P.Name_Last);
      elsif P.Kind = XML3_Parser.PI_Node then
         Put_Span (Base, Arena_Bytes, Cursor, Input, P.Name_First,
                   P.Name_Last, Name_Address, Ok);
         Name_Length := Span_Length (P.Name_First, P.Name_Last);
      elsif P.Kind = XML3_Parser.Text_Node then
         Put_Constant (Base, Arena_Bytes, Cursor, "text",
                       Name_Address, Ok);
         Name_Length := 4;
      elsif P.Kind = XML3_Parser.Comment_Node then
         Put_Constant (Base, Arena_Bytes, Cursor, "comment",
                       Name_Address, Ok);
         Name_Length := 7;
      end if;
      if P.Kind = XML3_Parser.Text_Node then
         Put_Decoded (Base, Arena_Bytes, Cursor, Input, P.Value_First,
           P.Value_Last, False, True, Scratch, Content_Address,
           Content_Length, Ok);
      elsif P.Kind = XML3_Parser.CData_Node then
         Put_Decoded (Base, Arena_Bytes, Cursor, Input, P.Value_First,
           P.Value_Last, False, False, Scratch, Content_Address,
           Content_Length, Ok);
      elsif P.Kind in XML3_Parser.Comment_Node |
        XML3_Parser.PI_Node
      then
         Put_Decoded (Base, Arena_Bytes, Cursor, Input, P.Value_First,
           P.Value_Last, False, False, Scratch, Content_Address,
           Content_Length, Ok);
      end if;
      Node_Value :=
        (State => Live, Kind => Kind, Facade => Target_Address,
         Name => Name_Address, Name_Length => Name_Length,
         Content => Content_Address, Content_Length => Content_Length,
         Parent => Parent_Node, First_Child => 0, Last_Child => 0,
         Previous => 0, Next => 0,
         Sibling_Order => Natural (Current),
         First_Prop => 0, Last_Prop => 0, First_Namespace => 0,
         Last_Namespace => 0, Document => 1, Namespace => Ns_Value,
         Owner => 1, Ns_Pin => (if Ns_Value = 0 then 0 else 1),
         Doc_Pin => 1, Content_Pin => 0,
         Tree_Rank => Natural (Current));
      if P.Kind = XML3_Parser.Attribute_Node then
         Node_Value.Content := System.Null_Address;
         Node_Value.Content_Length := 0;
      end if;
      if P.Kind = XML3_Parser.Attribute_Node then
         Tail := S.Graph.Nodes (Positive (Parent_Node)).Last_Prop;
      else
         Tail := S.Graph.Nodes (Positive (Parent_Node)).Last_Child;
      end if;
      if Tail /= 0 then
         if Tail < 2 or else Natural (Tail) > Node_Count_New
           or else Tail >= Current
           or else S.Graph.Nodes (Positive (Tail)).State /= Live
           or else S.Graph.Nodes (Positive (Tail)).Parent /=
             Parent_Node
         then
            Ok := False;
            return;
         end if;
         S.Graph.Nodes (Positive (Tail)).Next := Current;
         Node_Value.Previous := Tail;
      end if;
      if P.Kind = XML3_Parser.Attribute_Node then
         S.Graph.Nodes (Positive (Parent_Node)).Last_Prop := Current;
         if Tail = 0 then
            S.Graph.Nodes (Positive (Parent_Node)).First_Prop := Current;
         end if;
      else
         S.Graph.Nodes (Positive (Parent_Node)).Last_Child := Current;
         if Tail = 0 then
            S.Graph.Nodes (Positive (Parent_Node)).First_Child := Current;
         end if;
      end if;
      S.Graph.Nodes (Positive (Current)) := Node_Value;
      if P.Kind = XML3_Parser.Attribute_Node then
         declare
            Value_Id : Node_Ref := 0;
            Value_Name, Value_Content : System.Address;
            Value_Facade : System.Address := System.Null_Address;
            Value_Offset : Native.Byte_Count;
            Value_Length : Natural;
            Value_Node : Node_View;
         begin
           if Natural (Current) >= Node_Count_New then
               Ok := False;
               return;
            end if;
            Value_Id := Current + 1;
            if Value_Id < 2
              or else Natural (Value_Id) > Node_Count_New
            then
               Ok := False;
               return;
            end if;
            Mul_Bytes (Native.Node_Stride,
              Natural (Value_Id) - 1, Value_Offset, Ok);
            Add_Bytes (Value_Offset, Native.Metadata_Bytes,
              Facade_Offset, Ok);
           if Facade_Offset < Native.Metadata_Bytes
             or else Facade_Offset > Node_Bytes
             or else Node_Facade_Bytes >
               Node_Bytes - Facade_Offset
            then
               Ok := False;
            elsif Ok then
               Value_Facade := Native.Offset (Base, Facade_Offset);
               if Value_Facade = System.Null_Address then
                  Ok := False;
               end if;
            end if;
            if not Ok then
               return;
            end if;
            Put_Constant (Base, Arena_Bytes, Cursor, "text",
                          Value_Name, Ok);
            Put_Decoded (Base, Arena_Bytes, Cursor, Input, P.Value_First,
              P.Value_Last, True, True, Scratch, Value_Content,
              Value_Length, Ok);
            Value_Node :=
               (State => Live, Kind => Text_Node,
               Facade => Value_Facade,
               Name => Value_Name, Name_Length => 4,
               Content => Value_Content, Content_Length => Value_Length,
               Parent => Current, First_Child => 0, Last_Child => 0,
               Previous => 0, Next => 0,
               Sibling_Order => Natural (Value_Id),
               First_Prop => 0, Last_Prop => 0, First_Namespace => 0,
               Last_Namespace => 0, Document => 1, Namespace => 0,
               Owner => 1, Ns_Pin => 0, Doc_Pin => 1,
               Content_Pin => 0, Tree_Rank => Natural (Value_Id));
            S.Graph.Nodes (Positive (Current)).First_Child :=
              Value_Id;
            S.Graph.Nodes (Positive (Current)).Last_Child :=
              Value_Id;
            S.Graph.Nodes (Positive (Current)).Next := 0;
            S.Graph.Nodes (Positive (Value_Id)) := Value_Node;
         end;
      end if;
   end;
   end Fill_Node;

   procedure Fill_Namespace
     (S : in out State; Maps : Allocation.Import_Maps;
      Input : String; P : XML3_Parser.Node; Info : XML3_Namespaces.Name_Info;
      N : Namespace_Ref; Base : System.Address;
      Node_Bytes, Bytes, Ns_Facade_Bytes, Arena_Bytes : Native.Byte_Count;
      Cursor : in out Native.Byte_Count; Scratch : in out String;
      Ok : in out Boolean)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Well_Sized (S)
         and then Input'First = 1
         and then Input'Length <= XML3_Text.Max_Bytes
         and then Scratch'First = 1 and then Scratch'Length = Input'Length
         and then P.Name_Last <= Input'Length
         and then P.Value_Last <= Input'Length
         and then P.Name_First <= P.Name_Last + 1
         and then P.Value_First <= P.Value_Last + 1
         and then Info.Local_First <= P.Name_Last + 1,
       Post => Well_Sized (S)
         and then S.Graph.Node_Used = S.Graph.Node_Used'Old
         and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
         and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
         and then S.Graph.Owners = S.Graph.Owners'Old
         and then S.Effects = S.Effects'Old
         and then S.Marks = S.Marks'Old
         and then Cursor >= Cursor'Old
         and then (if not Ok'Old then not Ok)
   is
      Node_Count_New : constant Natural := S.Graph.Node_Used;
      Ns_Count_New : constant Natural := S.Graph.Ns_Used;
      Count : constant Positive := Maps.Capacity;
      Ns_Offset, Facade_Offset : Native.Byte_Count;
      Target_Address : System.Address := System.Null_Address;
      Ns_Previous : Namespace_Ref;
   begin
      if not Ok then
         return;
      end if;
   declare
      Parent : Node_Ref;
      Href : System.Address;
      Prefix : System.Address;
      Href_Length : Natural;
      Prefix_Length : Natural := 0;
      Ns_Value : Namespace_View;
      Facade_Byte_Offset : Native.Byte_Count;
   begin
      if N < 2 or else Natural (N) > Ns_Count_New then
         Ok := False;
         return;
      end if;
      if P.Parent = 0 or else P.Parent > Count
        or else Maps.Nodes (P.Parent) = 0
        or else Natural (Maps.Nodes (P.Parent)) >
          Node_Count_New
        or else S.Graph.Nodes
          (Positive (Maps.Nodes (P.Parent))).State /= Live
        or else S.Graph.Nodes
          (Positive (Maps.Nodes (P.Parent))).Kind /=
            Element_Node
      then
         Ok := False;
         return;
      end if;
      Parent := Maps.Nodes (P.Parent);
      Put_Decoded (Base, Arena_Bytes, Cursor, Input, P.Value_First,
        P.Value_Last, True, True, Scratch, Href, Href_Length, Ok);
      if not Ok then
         return;
      end if;
      Prefix := System.Null_Address;
      if Info.Prefix_Last >= P.Name_First then
         Put_Span (Base, Arena_Bytes, Cursor, Input, Info.Local_First,
           P.Name_Last, Prefix, Ok);
         if not Ok then
            return;
         end if;
         Prefix_Length := Span_Length
           (Info.Local_First, P.Name_Last);
      end if;
      Mul_Bytes
        (Native.Namespace_Stride, Natural (N) - 1,
         Ns_Offset, Ok);
      Add_Bytes (Node_Bytes, Ns_Offset,
                 Facade_Byte_Offset, Ok);
      Add_Bytes (Facade_Byte_Offset, Native.Metadata_Bytes,
                 Facade_Offset, Ok);
      if Facade_Byte_Offset < Node_Bytes
        or else Facade_Offset - Node_Bytes <
          Native.Metadata_Bytes
        or else Facade_Offset < Facade_Byte_Offset
        or else Facade_Offset > Bytes
        or else Ns_Facade_Bytes > Bytes - Facade_Offset
      then
         Ok := False;
      elsif Ok then
         Target_Address := Native.Offset (Base, Facade_Offset);
         if Target_Address = System.Null_Address then
            Ok := False;
         end if;
      end if;
      if not Ok then
         return;
      end if;
      Ns_Value :=
        (State => Live, Facade => Target_Address,
         Href => Href, Href_Length => Href_Length,
         Prefix => Prefix, Prefix_Length => Prefix_Length,
         Owner => 1, Parent => Parent, Next => 0, Previous => 0,
         Sibling_Order => Natural (N), Attached => True);
      Ns_Previous := S.Graph.Nodes
        (Positive (Parent)).Last_Namespace;
      if Ns_Previous /= 0 then
        if Ns_Previous < 2
          or else Natural (Ns_Previous) > Ns_Count_New
          or else Ns_Previous >= N
          or else S.Graph.Namespaces
            (Positive (Ns_Previous)).State /= Live
          or else not S.Graph.Namespaces
            (Positive (Ns_Previous)).Attached
          or else S.Graph.Namespaces
            (Positive (Ns_Previous)).Parent /= Parent
        then
            Ok := False;
            return;
         end if;
         S.Graph.Namespaces
           (Positive (Ns_Previous)).Next := N;
         Ns_Value.Previous := Ns_Previous;
      end if;
      S.Graph.Namespaces (Positive (N)) := Ns_Value;
      S.Graph.Nodes (Positive (Parent)).Last_Namespace := N;
      if Ns_Previous = 0 then
         S.Graph.Nodes (Positive (Parent)).First_Namespace := N;
      end if;
   end;
   end Fill_Namespace;

   procedure Build
     (Input : String;
      Nodes : XML3_Parser.Node_Array;
      Count : XML3_Parser.Node_Id;
      Names : XML3_Namespaces.Name_Array;
      Scratch : in out String;
      Source : out State_Access;
      Status : out XML3_DOM_Constructors.Construction_Status)
   is
      Candidate : State_Access := null;
      Maps : Allocation.Import_Maps_Access := null;
      Base : System.Address := System.Null_Address;
      Node_Count_New : Natural := 0;
      Ns_Count_New : Natural := 0;
      Next_Node : Natural := 1;
      Next_Ns : Natural := 1;
      Capacity : Positive;
      Bytes, Arena_Bytes, Node_Bytes, Ns_Bytes, String_Bytes :
        Native.Byte_Count := 0;
      Cursor : Native.Byte_Count := 0;
      Ok : Boolean := True;
      Node_Offset, Ns_Offset, Facade_Offset, Next_Offset :
        Native.Byte_Count;
      Node_Facade_Bytes, Ns_Facade_Bytes : Native.Byte_Count;
      Target_Address, Version_Address, Implicit_Href,
        Implicit_Prefix, Implicit_Facade : System.Address :=
          System.Null_Address;
   begin
      Source := null;
      Status := Constructors.Internal_Error;
      if Count = 0 or else Input'Length = 0 then
         return;
      end if;

      for I in 1 .. Count loop
         if Names (I).Declaration
           and then Nodes (I).Kind /= XML3_Parser.Attribute_Node
         then
            return;
         end if;
         if Names (I).Declaration then
            if Names (I).Binding = XML3_Namespaces.Implicit_XML then
               null;
            elsif Ns_Count_New = Natural'Last then
               Status := Constructors.Limit_Exceeded;
               return;
            else
               Ns_Count_New := Ns_Count_New + 1;
            end if;
         else
            if Node_Count_New = Natural'Last then
               Status := Constructors.Limit_Exceeded;
               return;
            end if;
            Node_Count_New := Node_Count_New + 1;
            if Nodes (I).Kind = XML3_Parser.Attribute_Node then
               if Node_Count_New = Natural'Last then
                  Status := Constructors.Limit_Exceeded;
                  return;
               end if;
               Node_Count_New := Node_Count_New + 1;
            end if;
         end if;
      end loop;
      if Node_Count_New >= Natural'Last - 1
        or else Ns_Count_New >= Natural'Last - 1
      then
         Status := Constructors.Limit_Exceeded;
         return;
      end if;
      Node_Count_New := Node_Count_New + 1;
      Ns_Count_New := Ns_Count_New + 1;
      if Node_Count_New = 0 or else Ns_Count_New = 0 then
         Status := Constructors.Limit_Exceeded;
         return;
      end if;
      Capacity := Positive (Natural'Max (Node_Count_New, Ns_Count_New));

      Add_Node_Budget
        (Nodes, Names, Count, String_Bytes, Ok);
      if Native.Node_Stride <= Native.Metadata_Bytes
        or else Native.Namespace_Stride <= Native.Metadata_Bytes
      then
         Status := Constructors.Internal_Error;
         return;
      end if;
      Node_Facade_Bytes := Native.Node_Stride - Native.Metadata_Bytes;
      Ns_Facade_Bytes := Native.Namespace_Stride - Native.Metadata_Bytes;
      Mul_Bytes (Native.Node_Stride, Node_Count_New, Node_Bytes, Ok);
      if Ok then
         Mul_Bytes (Native.Namespace_Stride, Ns_Count_New, Ns_Bytes, Ok);
      end if;
      if Ok then
         Add_Bytes (Node_Bytes, Ns_Bytes, Bytes, Ok);
      end if;
      if Ok then
         Add_Bytes (Bytes, String_Bytes, Arena_Bytes, Ok);
      end if;
      if not Ok or else Arena_Bytes = 0 then
         Status := Constructors.Limit_Exceeded;
         return;
      end if;

      Candidate := Allocation.Allocate_State (Capacity);
      if Candidate = null then
         Status := Constructors.No_Memory;
         return;
      end if;
      Initialize_Candidate (Candidate.all, Capacity);
      Maps := Allocation.Allocate_Maps (Positive (Count));
      if Maps = null then
         Allocation.Free_State (Candidate);
         Status := Constructors.No_Memory;
         return;
      end if;
      for I in Maps.all.Nodes'Range loop
         Maps.all.Nodes (I) := Null_Node;
         Maps.all.Namespaces (I) := Null_Namespace;
      end loop;

      Native.Allocate (Arena_Bytes, Base);
      if Base = System.Null_Address then
         Allocation.Free_Maps (Maps);
         Allocation.Free_State (Candidate);
         Status := Constructors.No_Memory;
         return;
      end if;
      Candidate.Graph.Node_Used := Node_Count_New;
      Candidate.Graph.Ns_Used := Ns_Count_New;
      Candidate.Graph.Owner_Used := 1;
      Candidate.Graph.Owners (1) :=
        (State => Live, Address => Base, References => Node_Count_New,
         Reservations => 0, Release_Emitted => False);

      Node_Offset := Native.Metadata_Bytes;
      for I in 1 .. Node_Count_New loop
         if not Ok then
            exit;
         end if;
         if Node_Offset < Native.Metadata_Bytes
           or else Node_Offset - Native.Metadata_Bytes > Node_Bytes
           or else Native.Node_Stride >
             Node_Bytes - (Node_Offset - Native.Metadata_Bytes)
         then
            Ok := False;
            exit;
         end if;
         Target_Address := Native.Offset (Base, Node_Offset);
         if Target_Address = System.Null_Address then
            Ok := False;
            exit;
         else
            Native.Initialize_Node (Target_Address);
         end if;
         if I < Node_Count_New then
            Add_Bytes (Node_Offset, Native.Node_Stride,
                       Next_Offset, Ok);
            if Ok then
               Node_Offset := Next_Offset;
            end if;
         end if;
         pragma Loop_Invariant
           (not Ok or else
              (Node_Offset =
                Native.Metadata_Bytes
                + Native.Node_Stride
                  * Native.Byte_Count
                    (if I < Node_Count_New then I else I - 1)
               and then
                Node_Offset <= Node_Bytes));
      end loop;
      Add_Bytes (Node_Bytes, Native.Metadata_Bytes, Ns_Offset, Ok);
      for I in 1 .. Ns_Count_New loop
         if not Ok then
            exit;
         end if;
         if Ns_Offset < Node_Bytes
           or else Ns_Offset - Node_Bytes < Native.Metadata_Bytes
           or else Ns_Offset > Bytes
           or else Native.Namespace_Stride >
             Bytes - (Ns_Offset - Native.Metadata_Bytes)
         then
            Ok := False;
            exit;
         end if;
         Target_Address := Native.Offset (Base, Ns_Offset);
         if Target_Address = System.Null_Address then
            Ok := False;
            exit;
         else
            Native.Initialize_Namespace (Target_Address);
         end if;
         if I < Ns_Count_New then
            Add_Bytes (Ns_Offset, Native.Namespace_Stride,
                       Next_Offset, Ok);
            if Ok then
               Ns_Offset := Next_Offset;
            end if;
         end if;
         pragma Loop_Invariant
           (not Ok or else
              (Ns_Offset =
                Node_Bytes + Native.Metadata_Bytes
                + Native.Namespace_Stride
                  * Native.Byte_Count
                    (if I < Ns_Count_New then I else I - 1)
               and then Ns_Offset >= Node_Bytes
               and then Ns_Offset <= Bytes));
      end loop;
      if not Ok then
         Native.Free (Base);
         Allocation.Free_Maps (Maps);
         Allocation.Free_State (Candidate);
         Status := Constructors.Internal_Error;
         return;
      end if;

      Next_Node := 2;
      Next_Ns := 2;
      for I in 1 .. Count loop
         if Names (I).Declaration then
            Maps.all.Nodes (I) := Null_Node;
            if Names (I).Binding /= XML3_Namespaces.Implicit_XML then
               if Next_Ns > Ns_Count_New or else Next_Ns = Natural'Last then
                  Status := Constructors.Limit_Exceeded;
                  Ok := False;
                  exit;
               end if;
               Maps.all.Namespaces (I) := Namespace_Ref (Next_Ns);
               Next_Ns := Next_Ns + 1;
            end if;
         else
            if Next_Node > Node_Count_New or else Next_Node = Natural'Last then
               Status := Constructors.Limit_Exceeded;
               Ok := False;
               exit;
            end if;
            Maps.all.Nodes (I) := Node_Ref (Next_Node);
            Next_Node := Next_Node + 1;
            if Nodes (I).Kind = XML3_Parser.Attribute_Node then
               if Next_Node > Node_Count_New
                 or else Next_Node = Natural'Last
               then
                  Status := Constructors.Limit_Exceeded;
                  Ok := False;
                  exit;
               end if;
               Next_Node := Next_Node + 1;
            end if;
         end if;
      end loop;
      if not Ok or else Next_Node /= Node_Count_New + 1
        or else Next_Ns /= Ns_Count_New + 1
      then
         Native.Free (Base);
         Allocation.Free_Maps (Maps);
         Allocation.Free_State (Candidate);
         if Status /= Constructors.Limit_Exceeded then
            Status := Constructors.Internal_Error;
         end if;
         return;
      end if;

      Facade_Offset := Native.Metadata_Bytes;
      if Facade_Offset > Node_Bytes
        or else Node_Facade_Bytes > Node_Bytes - Facade_Offset
      then
         Ok := False;
      elsif Ok then
         Target_Address := Native.Offset (Base, Facade_Offset);
         if Target_Address = System.Null_Address then
            Ok := False;
         end if;
      end if;
      Cursor := Bytes;
      pragma Assert (Cursor >= Bytes);
      Put_Constant (Base, Arena_Bytes, Cursor, "1.0", Version_Address, Ok);
      Put_Constant (Base, Arena_Bytes, Cursor, XML3_Namespaces.XML_URI,
                    Implicit_Href, Ok);
      Put_Constant (Base, Arena_Bytes, Cursor, "xml", Implicit_Prefix, Ok);
      Candidate.Graph.Nodes (1) :=
        (State => Live, Kind => Document_Node, Facade => Target_Address,
         Name => System.Null_Address, Name_Length => 0,
         Content => Version_Address, Content_Length => 3, Parent => 0,
         First_Child => 0, Last_Child => 0, Previous => 0, Next => 0,
         Sibling_Order => 0, First_Prop => 0, Last_Prop => 0,
         First_Namespace => 0, Last_Namespace => 0, Document => 1,
         Namespace => 0, Owner => 1, Ns_Pin => 0, Doc_Pin => 0,
         Content_Pin => 0, Tree_Rank => 0);
      Add_Bytes (Node_Bytes, Native.Metadata_Bytes, Facade_Offset, Ok);
      if Facade_Offset < Node_Bytes or else Facade_Offset > Bytes
        or else Ns_Facade_Bytes > Bytes - Facade_Offset
      then
         Ok := False;
      elsif Ok then
         Implicit_Facade := Native.Offset (Base, Facade_Offset);
         if Implicit_Facade = System.Null_Address then
            Ok := False;
         end if;
      end if;
      Candidate.Graph.Namespaces (1) :=
        (State => Live, Facade => Implicit_Facade,
         Href => Implicit_Href, Href_Length => XML3_Namespaces.XML_URI'Length,
         Prefix => Implicit_Prefix, Prefix_Length => 3, Owner => 1,
         Parent => 0, Next => 0, Previous => 0, Sibling_Order => 1,
         Attached => False);

      for I in 1 .. Count loop
         if not Ok then
            exit;
         end if;
         pragma Loop_Invariant (Well_Sized (Candidate.all));
         if not Names (I).Declaration then
            Fill_Node
              (Candidate.all, Maps.all, Input, Nodes (I), Names (I),
               Maps.Nodes (I), Base, Node_Bytes, Node_Facade_Bytes,
               Arena_Bytes, Cursor, Scratch, Ok);
         end if;
      end loop;

      if Ok then
         for I in 1 .. Count loop
            if Names (I).Declaration then
               declare
                  P : constant XML3_Parser.Node := Nodes (I);
                  Parent : Node_Ref;
               begin
                  if P.Parent = 0 or else P.Parent > Count
                    or else Maps.all.Nodes (P.Parent) = Null_Node
                  then
                     Ok := False;
                     exit;
                  end if;
                  Parent := Maps.all.Nodes (P.Parent);
                  if Parent = 0 or else Natural (Parent) > Node_Count_New
                    or else Candidate.Graph.Nodes (Positive (Parent)).State /=
                      Live
                    or else Candidate.Graph.Nodes (Positive (Parent)).Kind /=
                      Element_Node
                  then
                     Ok := False;
                     exit;
                  end if;
               end;
            end if;
         end loop;
      end if;

      if Ok then
         for I in 1 .. Count loop
            if not Ok then
               exit;
            end if;
            pragma Loop_Invariant (Well_Sized (Candidate.all));
            if Names (I).Declaration
              and then Names (I).Binding /= XML3_Namespaces.Implicit_XML
            then
               Fill_Namespace
                 (Candidate.all, Maps.all, Input, Nodes (I), Names (I),
                  Maps.Namespaces (I), Base, Node_Bytes, Bytes,
                  Ns_Facade_Bytes, Arena_Bytes, Cursor, Scratch, Ok);
            end if;
         end loop;
      end if;

      if not Ok or else Cursor < Bytes or else Cursor > Arena_Bytes
        or else not Check_Arena (Candidate.all)
      then
         Native.Free (Base);
         Allocation.Free_Maps (Maps);
         Allocation.Free_State (Candidate);
         Status := Constructors.Internal_Error;
         return;
      end if;
      Allocation.Free_Maps (Maps);
      Source := Candidate;
      Status := Constructors.Created;
   end Build;
end XML3_DOM.Materialize;
