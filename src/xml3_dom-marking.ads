private package XML3_DOM.Marking with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Compose_Namespace_Snapshots
     (Left, Middle, Right : Namespace_View_Array)
     with Ghost, Global => null,
       Pre => Left'First = 1 and then Middle'First = 1
         and then Right'First = 1
         and then Left'Last = Middle'Last and then Middle'Last = Right'Last
         and then Left = Middle and then Middle = Right,
       Post => Left = Right;

   procedure Namespace_Array_Equality
     (Left, Right : Namespace_View_Array)
     with Ghost, Global => null,
       Pre => Left'First = 1 and then Right'First = 1
         and then Left'Last = Right'Last
         and then (for all I in Left'Range => Left (I) = Right (I)),
       Post => Left = Right;

   procedure Namespace_Frame
     (S : State; Original : Namespace_View_Array)
     with Ghost, Global => null,
       Pre => Original'First = 1 and then Original'Last = S.Capacity
         and then (for all I in 1 .. S.Capacity =>
           S.Graph.Namespaces (I) = Original (I)),
       Post => S.Graph.Namespaces = Original
         and then Snapshot_Namespaces (S) = Original;

   procedure Unchanged_Graph_Namespaces (Before, After : State)
     with Ghost, Global => null,
       Pre => Before.Capacity = After.Capacity
         and then (for all I in 1 .. Before.Capacity =>
           Before.Graph.Namespaces (I) = After.Graph.Namespaces (I)),
       Post => After.Graph.Namespaces = Before.Graph.Namespaces;

   procedure Compose_Mark_Snapshots (Left, Middle, Right : Mark_Array)
     with Ghost, Global => null,
       Pre => Left'First = 1 and then Middle'First = 1
         and then Right'First = 1
         and then Left'Last = Middle'Last and then Middle'Last = Right'Last
         and then Left = Middle and then Middle = Right,
       Post => Left = Right;

   procedure Mark_Frame (S : State; Original : Mark_Array)
     with Ghost, Global => null,
       Pre => Original'First = 1 and then Original'Last = S.Capacity
         and then (for all I in 1 .. S.Capacity =>
           S.Marks (I) = Original (I)),
       Post => S.Marks = Original;

   procedure Preserve_Marked_State
     (Before, After : Node_View_Array;
      Before_Marks, After_Marks : Mark_Array; Used : Natural;
      Target_Doc : Node_Ref)
     with Ghost, Global => null,
       Pre => Before'First = 1 and then After'First = 1
         and then Before_Marks'First = 1 and then After_Marks'First = 1
         and then Used <= Before'Last and then Used <= After'Last
         and then Used <= Before_Marks'Last and then Used <= After_Marks'Last
         and then Before_Marks = After_Marks
         and then (for all I in 1 .. Used =>
           Before (I).State = After (I).State
           and then Before (I).Document = After (I).Document)
         and then (for all I in 1 .. Used =>
           (if Before_Marks (I) then Before (I).State = Live
             and then (Before (I).Document = Null_Node
               or else Before (I).Document = Target_Doc))),
       Post => (for all I in 1 .. Used =>
         (if After_Marks (I) then After (I).State = Live
           and then (After (I).Document = Null_Node
             or else After (I).Document = Target_Doc)));

   procedure Same_Graph_Snapshots (Left, Right : State)
     with Ghost, Global => null,
       Pre => Well_Sized (Left) and then Well_Sized (Right)
         and then Same_Graph (Left, Right),
       Post => Snapshot_Nodes (Left) = Snapshot_Nodes (Right)
         and then Snapshot_Namespaces (Left) = Snapshot_Namespaces (Right)
         and then Facades_Present (Left) = Facades_Present (Right)
         and then Left.Graph.Capacity = Right.Graph.Capacity
         and then Left.Graph.Nodes = Right.Graph.Nodes
         and then Left.Graph.Namespaces = Right.Graph.Namespaces
         and then Left.Graph.Owners = Right.Graph.Owners
         and then Left.Graph.Node_Used = Right.Graph.Node_Used
         and then Left.Graph.Ns_Used = Right.Graph.Ns_Used
         and then Left.Graph.Owner_Used = Right.Graph.Owner_Used;

   procedure Prepare_Subtree
     (S : in out State; Root : Node_Ref; Lift : Natural;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live,
     Post => (declare
       Original_Namespaces : constant Namespace_View_Array :=
         S.Graph.Namespaces'Old;
     begin S.Effects = S.Effects'Old and then Valid (S)
       and then S.Graph = S.Graph'Old
       and then S.Graph.Nodes = S.Graph.Nodes'Old
       and then (if Lift = 0 then Success)
       and then (for all I in 1 .. S.Capacity =>
         S.Graph.Namespaces (I) = Original_Namespaces (I))
       and then S.Graph.Namespaces = Original_Namespaces
       and then S.Graph.Owners = S.Graph.Owners'Old
       and then S.Graph.Node_Used = S.Graph.Node_Used'Old
       and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
       and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
       and then (if Success
         and then S.Graph.Nodes (Positive (Root)).First_Child = Null_Node
         and then S.Graph.Nodes (Positive (Root)).First_Prop = Null_Node then
           (for all I in 1 .. S.Graph.Node_Used =>
             S.Marks (I) = (Node_Ref (I) = Root)))
       and then (if Success then S.Marks (Positive (Root))
         and then (for all I in 1 .. S.Graph.Node_Used =>
           S.Marks (I) = (S.Graph.Nodes (I).State = Live and then
             Ancestor (S, Root, Node_Ref (I)))
           and then (if S.Marks (I) then
             S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Lift)
           and then (if S.Graph.Nodes (I).State = Live
             and then S.Graph.Nodes (I).Parent /= 0 and then Node_Ref (I) /= Root
             then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
                and then S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent))))));

   procedure Lift_Marked (S : in out State; Lift : Natural)
   with Global => null,
     Pre => Valid (S)
       and then (for all I in 1 .. S.Graph.Node_Used =>
         (if S.Marks (I) then S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Lift)
         and then (if S.Graph.Nodes (I).State = Live and then S.Graph.Nodes (I).Parent /= 0
           then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
             and then S.Marks (I) = S.Marks (Positive (S.Graph.Nodes (I).Parent)))),
     Post => S.Effects = S.Effects'Old and then Valid (S) and then S.Marks = S.Marks'Old
       and then S.Graph.Node_Used = S.Graph.Node_Used'Old
       and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
       and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
       and then S.Graph.Owners = S.Graph.Owners'Old
       and then S.Graph.Namespaces = S.Graph.Namespaces'Old
       and then (for all I in 1 .. S.Graph.Node_Used =>
         S.Graph.Nodes (I) = (S.Graph.Nodes'Old (I) with delta Tree_Rank =>
           S.Graph.Nodes'Old (I).Tree_Rank + (if S.Marks (I) then Lift else 0)));

   procedure Set_Marked_Document
     (S : in out State; Target_Doc : Node_Ref; Target_B : Owner_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Target_Doc in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Target_Doc).Kind = Document_Node
       and then Node (S, Target_Doc).State in Live | Tombstone
       and then Target_B in 1 .. Owner_Ref (Owner_Count (S))
       and then Node (S, Target_Doc).Owner = Target_B
       and then Owner (S, Target_B).State = Live
       and then Owner (S, Target_B).References <=
         Natural'Last - Node_Count (S)
       and then (for all I in 1 .. Node_Count (S) =>
         (if S.Marks (I) then
            Node (S, Node_Ref (I)).State = Live
              and then (Node (S, Node_Ref (I)).Document = Null_Node
                or else Node (S, Node_Ref (I)).Document = Target_Doc))),
     Post => (declare
       Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S)'Old;
       Original_Marks : constant Mark_Array := Snapshot_Marks (S)'Old;
     begin Valid (S) and then Can_Edit (S)
       and then S.Capacity = S.Capacity'Old
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then S.Marks = S.Marks'Old
       and then (for all I in Namespace_Ref range
         1 .. Namespace_Ref (Namespace_Count (S)) =>
           Namespace (S, I) = Namespace (S'Old, I))
       and then (for all I in 1 .. Node_Count (S) =>
         (if S.Marks (I) then
            S.Graph.Nodes (I).Document = Target_Doc
              and then S.Graph.Nodes (I).Doc_Pin = Target_B))
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           S.Graph.Nodes (Positive (I)) =
             (if Original_Marks (Positive (I)) then
                (Original_Nodes (Positive (I)) with delta
                   Document => Target_Doc, Doc_Pin => Target_B)
              else Original_Nodes (Positive (I)))));

   procedure Relink_Marked_Subtree
     (S : in out State; Parent, Child : Node_Ref; Property : Boolean;
      Append_Order, Rank_Lift : Natural; Replaced : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Parent /= Child
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live
       and then Property = (Node (S, Child).Kind = Attribute_Node)
       and then not S.Marks (Positive (Parent))
       and then S.Marks (Positive (Child))
       and then Rank_Lift <= Natural'Last - Node (S, Child).Tree_Rank
       and then Node (S, Parent).Tree_Rank <
         Node (S, Child).Tree_Rank + Rank_Lift
       and then (for all I in 1 .. S.Graph.Node_Used =>
         (if S.Marks (I) then
            S.Graph.Nodes (I).State = Live
              and then S.Graph.Nodes (I).Tree_Rank <=
                Natural'Last - Rank_Lift))
       and then (for all I in 1 .. S.Graph.Node_Used =>
         (if S.Graph.Nodes (I).State = Live
           and then S.Graph.Nodes (I).Parent /= Null_Node
           and then Node_Ref (I) /= Child
          then S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
            and then S.Marks (I) =
              S.Marks (Positive (S.Graph.Nodes (I).Parent))))
       and then (if Replaced = Null_Node then
         (declare
            Last : constant Node_Ref :=
              (if Property then Node (S, Parent).Last_Prop
               else Node (S, Parent).Last_Child);
          begin Last = Null_Node or else
            (Last in 1 .. Node_Ref (Node_Count (S))
             and then Last /= Child
             and then Node (S, Last).Sibling_Order < Append_Order)))
       and then (if Replaced /= Null_Node then
         Node (S, Parent).Kind = Document_Node
           and then Node (S, Child).Kind = Element_Node
           and then Replaced in 1 .. Node_Ref (Node_Count (S))
           and then Replaced /= Parent and then Replaced /= Child
           and then Node (S, Replaced).State = Live
           and then Node (S, Replaced).Kind = Element_Node
           and then Node (S, Replaced).Parent = Parent),
     Post => Valid (S) and then Can_Edit (S)
       and then S.Capacity = S.Capacity'Old
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then Node_Count (S) = Node_Count (S'Old)
       and then Namespace_Count (S) = Namespace_Count (S'Old)
       and then Owner_Count (S) = Owner_Count (S'Old)
       and then S.Marks = S.Marks'Old
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S)) =>
           Same_Pins (Node (S, I), Node (S'Old, I))
             and then Node (S, I).Kind = Node (S'Old, I).Kind
             and then Node (S, I).Facade = Node (S'Old, I).Facade
             and then (if I /= Child and then I /= Replaced then
               Node (S, I).Parent = Node (S'Old, I).Parent)
             and then Node (S, I).Document = Node (S'Old, I).Document)
       and then (for all I in Namespace_Ref range
         1 .. Namespace_Ref (Namespace_Count (S)) =>
           Namespace (S, I) = Namespace (S'Old, I))
       and then (for all I in Owner_Ref range
         1 .. Owner_Ref (Owner_Count (S)) =>
           Owner (S, I) = Owner (S'Old, I))
       and then (if not Property and then Replaced = Null_Node
         and then Node (S'Old, Child).Parent = Null_Node then
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
             Node (S, I).First_Prop = Node (S'Old, I).First_Prop
             and then Node (S, I).First_Namespace =
               Node (S'Old, I).First_Namespace
             and then (if I /= Parent then
               Node (S, I).First_Child = Node (S'Old, I).First_Child)))
       and then Node (S, Child).Parent = Parent
       and then (if Replaced = Null_Node then
         (if Property then
            Node (S, Parent).Last_Prop = Child
              and then Node (S, Child).Next = Null_Node
          else
            Node (S, Parent).Last_Child = Child
              and then Node (S, Child).Next = Null_Node))
       and then (if Replaced /= Null_Node then
         Replaced in 1 .. Node_Ref (Node_Count (S))
           and then Node (S, Replaced).State = Live
           and then Node (S, Replaced).Parent = Null_Node
           and then Node (S, Replaced).Previous = Null_Node
           and then Node (S, Replaced).Next = Null_Node
           and then Node (S, Child).Previous =
             Unlinked_View (S'Old, Child, Replaced).Previous
           and then Node (S, Child).Next =
             Unlinked_View (S'Old, Child, Replaced).Next
           and then Node (S, Child).Sibling_Order =
             Unlinked_View (S'Old, Child, Replaced).Sibling_Order);

   procedure Check_Attachment
     (S : State; Parent, Child : Node_Ref; Property : Boolean;
      Replaced : Node_Ref; Already_Attached : out Boolean;
      Append_Order, Rank_Lift : out Natural;
      Target_Doc : out Node_Ref; Target_B : out Owner_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live,
     Post => (if Success then
       Target_Doc = (if Node (S, Parent).Kind = Document_Node
         then Parent else Node (S, Parent).Document)
       and then (if Target_Doc /= Null_Node then
         Target_Doc in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, Target_Doc).Kind = Document_Node
         and then Node (S, Target_Doc).State in Live | Tombstone
         and then Target_B = Node (S, Target_Doc).Owner
         and then Target_B in 1 .. Owner_Ref (Owner_Count (S))
         and then Owner (S, Target_B).State = Live)
       and then Parent /= Child
       and then not Ancestor (S, Child, Parent)
       and then Property = (Node (S, Child).Kind = Attribute_Node)
       and then Node (S, Child).Kind /= Document_Node
       and then (if Property then Node (S, Parent).Kind = Element_Node
         else Node (S, Parent).Kind in
           Document_Node | Element_Node | Attribute_Node)
       and then (if Node (S, Parent).Kind = Attribute_Node then
         Node (S, Child).Kind = Text_Node)
       and then (if Node (S, Parent).Kind = Document_Node then
         Node (S, Child).Kind in
           Element_Node | Comment_Node | Processing_Instruction_Node)
       and then (if Replaced /= Null_Node then
         Node (S, Parent).Kind = Document_Node
         and then Node (S, Child).Kind = Element_Node
         and then Replaced in 1 .. Node_Ref (Node_Count (S))
         and then Replaced /= Parent and then Replaced /= Child
         and then Node (S, Replaced).State = Live
         and then Node (S, Replaced).Kind = Element_Node
         and then Node (S, Replaced).Parent = Parent)
       and then Already_Attached =
         (Replaced = Null_Node and then Node (S, Child).Parent = Parent
          and then (if Property then Node (S, Parent).Last_Prop
                    else Node (S, Parent).Last_Child) = Child)
       and then (if not Already_Attached then
         Rank_Lift <= Natural'Last - Node (S, Child).Tree_Rank
         and then Node (S, Parent).Tree_Rank <
           Node (S, Child).Tree_Rank + Rank_Lift
         and then (if Replaced = Null_Node then
           (declare
              Last : constant Node_Ref :=
                (if Property then Node (S, Parent).Last_Prop
                 else Node (S, Parent).Last_Child);
            begin Last = Null_Node or else
              (Last in 1 .. Node_Ref (Node_Count (S))
               and then Last /= Child
               and then Node (S, Last).Sibling_Order < Append_Order)))));

   procedure Prepare_Attachment
     (S : in out State; Parent, Child : Node_Ref; Property : Boolean;
      Replaced : Node_Ref; Already_Attached : out Boolean;
      Append_Order, Rank_Lift : out Natural;
      Target_Doc : out Node_Ref; Target_B : out Owner_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live,
     Post => Valid (S) and then Can_Edit (S)
       and then S.Graph.Capacity = S.Graph.Capacity'Old
       and then S.Graph.Nodes = S.Graph.Nodes'Old
       and then S.Graph.Namespaces = S.Graph.Namespaces'Old
       and then S.Graph.Owners = S.Graph.Owners'Old
       and then S.Graph.Node_Used = S.Graph.Node_Used'Old
       and then S.Graph.Ns_Used = S.Graph.Ns_Used'Old
       and then S.Graph.Owner_Used = S.Graph.Owner_Used'Old
       and then S.Effects = S.Effects'Old
       and then Same_Graph (S, S'Old)
       and then Snapshot_Nodes (S) = Snapshot_Nodes (S)'Old
       and then Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old
       and then (if Success then
       Target_Doc = (if Node (S, Parent).Kind = Document_Node
         then Parent else Node (S, Parent).Document)
       and then (if Target_Doc /= Null_Node then
         Target_Doc in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, Target_Doc).Kind = Document_Node
         and then Node (S, Target_Doc).State in Live | Tombstone
         and then Target_B = Node (S, Target_Doc).Owner
         and then Target_B in 1 .. Owner_Ref (Owner_Count (S))
         and then Owner (S, Target_B).State = Live)
       and then Parent /= Child
       and then not Ancestor (S, Child, Parent)
       and then Property = (Node (S, Child).Kind = Attribute_Node)
       and then Node (S, Child).Kind /= Document_Node
       and then (if Property then Node (S, Parent).Kind = Element_Node
         else Node (S, Parent).Kind in
           Document_Node | Element_Node | Attribute_Node)
       and then (if Node (S, Parent).Kind = Attribute_Node then
         Node (S, Child).Kind = Text_Node)
       and then (if Node (S, Parent).Kind = Document_Node then
         Node (S, Child).Kind in
           Element_Node | Comment_Node | Processing_Instruction_Node)
       and then (if Replaced /= Null_Node then
         Node (S, Parent).Kind = Document_Node
         and then Node (S, Child).Kind = Element_Node
         and then Replaced in 1 .. Node_Ref (Node_Count (S))
         and then Replaced /= Parent and then Replaced /= Child
         and then Node (S, Replaced).State = Live
         and then Node (S, Replaced).Kind = Element_Node
         and then Node (S, Replaced).Parent = Parent)
       and then Already_Attached =
         (Replaced = Null_Node and then Node (S, Child).Parent = Parent
          and then (if Property then Node (S, Parent).Last_Prop
                    else Node (S, Parent).Last_Child) = Child)
       and then (if not Already_Attached then
         Rank_Lift <= Natural'Last - Node (S, Child).Tree_Rank
         and then Node (S, Parent).Tree_Rank <
           Node (S, Child).Tree_Rank + Rank_Lift
         and then (if Replaced = Null_Node then
           (declare
              Last : constant Node_Ref :=
                (if Property then Node (S, Parent).Last_Prop
                 else Node (S, Parent).Last_Child);
            begin Last = Null_Node or else
              (Last in 1 .. Node_Ref (Node_Count (S))
               and then Last /= Child
               and then Node (S, Last).Sibling_Order < Append_Order)))))
       and then (if Success then S.Marks (Positive (Child))
         and then (for all I in 1 .. S.Graph.Node_Used =>
           S.Marks (I) = (S.Graph.Nodes (I).State = Live and then
             Ancestor (S, Child, Node_Ref (I)))
           and then (if S.Marks (I) then
             S.Graph.Nodes (I).Tree_Rank <= Natural'Last - Rank_Lift
             and then (S.Graph.Nodes (I).Document = Null_Node
               or else S.Graph.Nodes (I).Document = Target_Doc))
           and then (if S.Graph.Nodes (I).State = Live
             and then S.Graph.Nodes (I).Parent /= Null_Node
             and then Node_Ref (I) /= Child then
               S.Graph.Nodes (I).Parent <= Node_Ref (S.Graph.Node_Used)
               and then S.Marks (I) =
                 S.Marks (Positive (S.Graph.Nodes (I).Parent))))
         and then (if Target_Doc /= Null_Node then
           Target_B in 1 .. Owner_Ref (Owner_Count (S))
           and then S.Graph.Owners (Positive (Target_B)).References <=
             Natural'Last - S.Graph.Node_Used));

   procedure Attach
     (S : in out State; Parent, Child : Node_Ref;
      Property : Boolean; Success : out Boolean;
      Replaced : Node_Ref := Null_Node)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (S.Graph.Node_Used)
       and then Child in 1 .. Node_Ref (S.Graph.Node_Used)
       and then Node (S, Parent).State = Live
       and then Node (S, Child).State = Live;
   pragma Postcondition
     ((if not Success then Same_Graph (S, S'Old)));
   pragma Postcondition
     (Valid (S));
   pragma Postcondition
     (Can_Edit (S));
   pragma Postcondition
     ((if Facades_Present (S'Old) then Facades_Present (S)));
   pragma Postcondition
     (Snapshot_Namespaces (S) = Snapshot_Namespaces (S)'Old);
   pragma Postcondition
     (S.Capacity = S'Old.Capacity);
   pragma Postcondition
     (Node_Count (S) = Node_Count (S'Old));
   pragma Postcondition
     (Namespace_Count (S) = Namespace_Count (S'Old));
   pragma Postcondition
     (Owner_Count (S) = Owner_Count (S'Old));
   pragma Postcondition
     ((for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           Node (S, I).State = Node (S'Old, I).State
             and then Node (S, I).Kind =
               Snapshot_Nodes (S)'Old (Positive (I)).Kind
             and then (if I /= Child and then I /= Replaced then
               Node (S, I).Parent = Node (S'Old, I).Parent)
             and then Node (S, I).Facade = Node (S'Old, I).Facade));
   pragma Postcondition
     ((for all I in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (S)) =>
             Namespace (S, I) = Namespace (S'Old, I)));
   pragma Postcondition
     ((if not Property and then Replaced = Null_Node
         and then Node (S'Old, Child).Parent = Null_Node then
           (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
             Node (S, I).First_Prop = Node (S'Old, I).First_Prop
             and then Node (S, I).First_Namespace =
               Node (S'Old, I).First_Namespace
             and then (if I /= Parent then
               Node (S, I).First_Child = Node (S'Old, I).First_Child))));
   pragma Postcondition
     ((if not Property and then Node (S'Old, Parent).Kind = Attribute_Node
         and then Text_Attribute_Content (S'Old, Parent)
         and then Node (S'Old, Child).Kind = Text_Node
         and then Node (S'Old, Child).Parent = Null_Node
         and then Node (S'Old, Child).First_Child = Null_Node
         and then Node (S'Old, Child).First_Prop = Null_Node
         and then Node (S'Old, Child).First_Namespace = Null_Namespace then
           Text_Attribute_Content (S, Parent)
           and then Node (S, Parent).First_Prop = Node (S'Old, Parent).First_Prop
           and then Node (S, Parent).First_Namespace =
             Node (S'Old, Parent).First_Namespace
           and then Node (S, Child).First_Child = Null_Node
           and then Node (S, Child).First_Prop = Null_Node
           and then Node (S, Child).First_Namespace = Null_Namespace));
   pragma Postcondition
     ((if Success then Node (S, Child).Parent = Parent
       and then (if Replaced = Null_Node then
         (if Property then
            Node (S, Parent).Last_Prop = Child
              and then Node (S, Child).Next = Null_Node
          else
            Node (S, Parent).Last_Child = Child
              and then Node (S, Child).Next = Null_Node)
       else True)
           and then (if Replaced /= Null_Node then
             Replaced in 1 .. Node_Ref (Node_Count (S))
             and then Node (S, Replaced).State = Live
             and then Node (S, Replaced).Parent = Null_Node
             and then Node (S, Replaced).Previous = Null_Node
             and then Node (S, Replaced).Next = Null_Node
             and then Node (S, Child).Previous =
               Unlinked_View (S'Old, Child, Replaced).Previous
             and then Node (S, Child).Next =
               Unlinked_View (S'Old, Child, Replaced).Next
             and then Node (S, Child).Sibling_Order =
               Unlinked_View (S'Old, Child, Replaced).Sibling_Order)
         and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           (if Snapshot_Marks (S) (Positive (I)) then
              Node (S, I).Document =
                (if Node (S'Old, Parent).Kind = Document_Node
                 then Parent else Node (S'Old, Parent).Document)
             and then ((if Node (S'Old, Parent).Kind = Document_Node
                         then Parent else Node (S'Old, Parent).Document) = Null_Node
                or else Node (S, I).Doc_Pin =
                  Node (S'Old,
                    (if Node (S'Old, Parent).Kind = Document_Node
                     then Parent else Node (S'Old, Parent).Document)).Owner)))
       ));

end XML3_DOM.Marking;
