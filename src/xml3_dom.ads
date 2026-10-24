with System;

package XML3_DOM with SPARK_Mode is
   use type System.Address;
   pragma Unevaluated_Use_Of_Old (Allow);

   type Node_Ref is new Natural;
   type Namespace_Ref is new Natural;
   type Owner_Ref is new Natural;

   Null_Node      : constant Node_Ref := 0;
   Null_Namespace : constant Namespace_Ref := 0;
   Null_Owner     : constant Owner_Ref := 0;

   type Slot_State is (Unused, Live, Tombstone, Releasing);
   type Node_Kind is
     (Document_Node, Element_Node, Attribute_Node, Text_Node,
      CData_Node, Comment_Node, Processing_Instruction_Node);

   type Node_View is record
      State       : Slot_State := Unused;
      Kind        : Node_Kind := Element_Node;
      Facade      : System.Address := System.Null_Address;
      Name        : System.Address := System.Null_Address;
      Name_Length : Natural := 0;
      Content     : System.Address := System.Null_Address;
      Content_Length : Natural := 0;
      Parent      : Node_Ref := Null_Node;
      First_Child : Node_Ref := Null_Node;
      Last_Child  : Node_Ref := Null_Node;
      Previous    : Node_Ref := Null_Node;
      Next        : Node_Ref := Null_Node;
      Sibling_Order : Natural := 0;
      First_Prop  : Node_Ref := Null_Node;
      Last_Prop   : Node_Ref := Null_Node;
      First_Namespace : Namespace_Ref := Null_Namespace;
      Last_Namespace  : Namespace_Ref := Null_Namespace;
      Document    : Node_Ref := Null_Node;
      Namespace   : Namespace_Ref := Null_Namespace;
      Owner       : Owner_Ref := Null_Owner;
      Ns_Pin      : Owner_Ref := Null_Owner;
      Doc_Pin     : Owner_Ref := Null_Owner;
      Content_Pin : Owner_Ref := Null_Owner;
      Tree_Rank   : Natural := 0;
   end record;

   type Namespace_View is record
      State        : Slot_State := Unused;
      Facade       : System.Address := System.Null_Address;
      Href         : System.Address := System.Null_Address;
      Href_Length  : Natural := 0;
      Prefix       : System.Address := System.Null_Address;
      Prefix_Length : Natural := 0;
      Owner        : Owner_Ref := Null_Owner;
      Parent       : Node_Ref := Null_Node;
      Next         : Namespace_Ref := Null_Namespace;
      Previous     : Namespace_Ref := Null_Namespace;
      Sibling_Order : Natural := 0;
      Attached : Boolean := False;
   end record;

   type Owner_View is record
      State            : Slot_State := Unused;
      Address          : System.Address := System.Null_Address;
      References       : Natural := 0;
      Reservations     : Natural := 0;
      Release_Emitted  : Boolean := False;
   end record;

   type State (Capacity : Positive) is private;
   type State_Access is access all State;
   type Node_View_Array is array (Positive range <>) of Node_View;
   type Namespace_View_Array is array (Positive range <>) of Namespace_View;
   type Owner_View_Array is array (Positive range <>) of Owner_View;
   type Mark_Array is array (Positive range <>) of Boolean;

   function Snapshot_Marks (S : State) return Mark_Array
     with Ghost, Global => null,
       Annotate => (GNATprove, Inline_For_Proof);

   function Same_Marks (Left, Right : State) return Boolean is
     (Left.Capacity = Right.Capacity
      and then (for all I in 1 .. Left.Capacity =>
        Snapshot_Marks (Left) (I) = Snapshot_Marks (Right) (I)))
     with Ghost, Global => null;

   type Effect_Phase is
     (Editing, Projecting_Nodes, Node_Projection_Pending,
      Projecting_Namespaces, Namespace_Projection_Pending, Release_Pending);

   function Phase (S : State) return Effect_Phase with Global => null;
   function Projection_Required (S : State) return Boolean with Global => null;
   function Active_Release (S : State) return Owner_Ref with Global => null;
   function Projection_Cursor (S : State) return Natural with Global => null;
   function Release_Cursor (S : State) return Natural with Global => null;
   function Can_Edit (S : State) return Boolean is (Phase (S) = Editing)
     with Global => null;
   function Effects_Valid (S : State) return Boolean
     with Ghost, Global => null;
   function Same_Graph (Left, Right : State) return Boolean
     with Ghost, Global => null;

   function Node_Count (S : State) return Natural
     with Global => null;
   function Namespace_Count (S : State) return Natural
     with Global => null;
   function Owner_Count (S : State) return Natural
     with Global => null;
   function Capacity_Of (S : State) return Positive
     with Global => null;

   function Node (S : State; N : Node_Ref) return Node_View
     with Global => null, Pre => N in 1 .. Node_Ref (S.Capacity);
   function Namespace (S : State; N : Namespace_Ref) return Namespace_View
     with Global => null,
       Pre => N in 1 .. Namespace_Ref (S.Capacity);
   function Owner (S : State; B : Owner_Ref) return Owner_View
     with Global => null, Pre => B in 1 .. Owner_Ref (S.Capacity);

   function Holds (N : Node_View; B : Owner_Ref) return Boolean
     is (N.State = Live and then B /= Null_Owner
         and then (N.Owner = B or else N.Ns_Pin = B
                   or else N.Doc_Pin = B or else N.Content_Pin = B))
     with Global => null;

   function Same_Pins (Left, Right : Node_View) return Boolean is
     (Left.State = Right.State and then Left.Owner = Right.Owner
      and then Left.Ns_Pin = Right.Ns_Pin
      and then Left.Doc_Pin = Right.Doc_Pin
      and then Left.Content_Pin = Right.Content_Pin)
     with Ghost, Global => null;

   function Snapshot_Nodes (S : State) return Node_View_Array
     with Ghost, Global => null;

   function Holder_Count
     (Nodes : Node_View_Array; B : Owner_Ref; N : Natural) return Natural
   is (if N = 0 then 0
       else (if Holds (Nodes (N), B) then 1 else 0)
         + Holder_Count (Nodes, B, N - 1))
     with Ghost, Global => null,
       Pre => Nodes'First = 1 and then N <= Nodes'Last,
       Post => Holder_Count'Result <= N
         and then Holder_Count'Result =
           (if N = 0 then 0
            else (if Holds (Nodes (N), B) then 1 else 0)
              + Holder_Count (Nodes, B, N - 1)),
       Subprogram_Variant => (Decreases => N);
   function Well_Sized (S : State) return Boolean
     with Ghost, Global => null;

   function Projection_Links_In_Range (S : State) return Boolean is
     ((for all N in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
        (declare
           Item : constant Node_View := Node (S, N);
         begin
           Item.State /= Live or else
             (Item.First_Child <= Node_Ref (Node_Count (S))
              and then Item.Last_Child <= Node_Ref (Node_Count (S))
              and then Item.Parent <= Node_Ref (Node_Count (S))
              and then Item.Next <= Node_Ref (Node_Count (S))
              and then Item.Previous <= Node_Ref (Node_Count (S))
              and then Item.Document <= Node_Ref (Node_Count (S))
              and then Item.First_Prop <= Node_Ref (Node_Count (S))
              and then Item.Namespace <= Namespace_Ref (Namespace_Count (S))
              and then Item.First_Namespace <= Namespace_Ref (Namespace_Count (S)))))
      and then (for all N in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (S)) =>
          (if Namespace (S, N).State = Live then
             Namespace (S, N).Next <= Namespace_Ref (Namespace_Count (S)))))
     with Ghost, Global => null, Pre => Well_Sized (S);

   function Links_Valid (S : State) return Boolean
     with Ghost, Global => null, Pre => Well_Sized (S),
       Post => (if Links_Valid'Result then Projection_Links_In_Range (S));
   function Pins_In_Range (S : State) return Boolean is
     (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
       (Node (S, N).State /= Live or else
         (Node (S, N).Owner <= Owner_Ref (Owner_Count (S))
          and then Node (S, N).Ns_Pin <= Owner_Ref (Owner_Count (S))
          and then Node (S, N).Doc_Pin <= Owner_Ref (Owner_Count (S))
          and then Node (S, N).Content_Pin <= Owner_Ref (Owner_Count (S)))))
     with Ghost, Global => null, Pre => Well_Sized (S);
   function Pin_Equation (S : State) return Boolean
   is
     (for all B in Owner_Ref range
        1 .. Owner_Ref (Owner_Count (S)) =>
          (Owner (S, B).State /= Live
           or else
             (Owner (S, B).Reservations <= Owner (S, B).References
              and then Owner (S, B).References
                - Owner (S, B).Reservations =
                  Holder_Count
                    (Snapshot_Nodes (S), B, Node_Count (S)))))
     with Ghost, Global => null,
       Pre => Well_Sized (S)
         and then Node_Count (S) <= Natural (S.Capacity)
         and then Owner_Count (S) <= Natural (S.Capacity),
       Annotate => (GNATprove, Inline_For_Proof);
   function Valid (S : State) return Boolean
     is (Well_Sized (S) and then Effects_Valid (S) and then Pins_In_Range (S)
         and then Pin_Equation (S)
         and then Links_Valid (S))
     with Ghost, Global => null;
   function Snapshot_Namespaces (S : State) return Namespace_View_Array
     with Ghost, Global => null,
       Annotate => (GNATprove, Inline_For_Proof);
   function Snapshot_Owners (S : State) return Owner_View_Array
     with Ghost, Global => null,
       Annotate => (GNATprove, Inline_For_Proof);

   function Ancestor_In_Nodes
     (Nodes : Node_View_Array; Used : Natural; Candidate, N : Node_Ref)
      return Boolean
   is
     (Nodes (Positive (N)).State = Live and then
       (Candidate = N or else
         (Nodes (Positive (N)).Parent in 1 .. Node_Ref (Used) and then
          Nodes (Positive (Nodes (Positive (N)).Parent)).State = Live and then
          Nodes (Positive (Nodes (Positive (N)).Parent)).Tree_Rank
            < Nodes (Positive (N)).Tree_Rank and then
          Ancestor_In_Nodes (Nodes, Used, Candidate, Nodes (Positive (N)).Parent))))
   with Ghost, Global => null,
     Pre => Nodes'First = 1 and then Used <= Nodes'Last
       and then Candidate in 1 .. Node_Ref (Used)
       and then N in 1 .. Node_Ref (Used),
     Post => Ancestor_In_Nodes'Result =
       (Nodes (Positive (N)).State = Live and then
         (Candidate = N or else
           (Nodes (Positive (N)).Parent in 1 .. Node_Ref (Used) and then
            Nodes (Positive (Nodes (Positive (N)).Parent)).State = Live and then
            Nodes (Positive (Nodes (Positive (N)).Parent)).Tree_Rank
              < Nodes (Positive (N)).Tree_Rank and then
            Ancestor_In_Nodes
              (Nodes, Used, Candidate, Nodes (Positive (N)).Parent))))
       and then (if Ancestor_In_Nodes'Result then
       Nodes (Positive (Candidate)).State = Live and then
       Nodes (Positive (Candidate)).Tree_Rank <= Nodes (Positive (N)).Tree_Rank),
     Subprogram_Variant => (Decreases => Nodes (Positive (N)).Tree_Rank);

   function Ancestor (S : State; Candidate, N : Node_Ref) return Boolean
     with Ghost, Global => null,
       Pre => Valid (S)
         and then Candidate in 1 .. Node_Ref (Node_Count (S))
         and then N in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, N).State = Live,
       Post => Ancestor'Result = Ancestor_In_Nodes
         (Snapshot_Nodes (S), Node_Count (S), Candidate, N)
         and then Ancestor'Result =
         (Candidate = N or else
           (Node (S, N).Parent /= Null_Node and then
             Ancestor (S, Candidate, Node (S, N).Parent)))
         and then (if Ancestor'Result then
           Node (S, Candidate).State = Live and then
           Node (S, Candidate).Tree_Rank <= Node (S, N).Tree_Rank),
       Subprogram_Variant => (Decreases => Node (S, N).Tree_Rank);

   function Is_Ancestor (S : State; Candidate, N : Node_Ref) return Boolean
     with Global => null,
       Pre => Valid (S)
         and then Candidate in 1 .. Node_Ref (Node_Count (S))
         and then N in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, N).State = Live,
       Post => Is_Ancestor'Result = Ancestor (S, Candidate, N);

   procedure Initialize
     (Current : out State_Access;
      Capacity : Positive;
      Success : out Boolean)
   with Global => null,
     Post => (if Success then Current /= null
              and then Current.Capacity = Capacity
              and then Valid (Current.all) and then Can_Edit (Current.all)
              else Current = null);

   procedure Ensure_Capacity
     (Current : in out State_Access;
      Nodes_Needed : Natural;
      Namespaces_Needed : Natural;
      Owners_Needed : Natural;
      Success : out Boolean)
   with Global => null,
     Pre => Current /= null and then Valid (Current.all) and then Can_Edit (Current.all),
     Post => Current /= null
       and then Valid (Current.all) and then Can_Edit (Current.all)
       and then (if Success then
         Natural (Current.Capacity) >= Nodes_Needed
         and then Natural (Current.Capacity) >= Namespaces_Needed
         and then Natural (Current.Capacity) >= Owners_Needed
         else Snapshot_Nodes (Current.all) = Snapshot_Nodes (Current.all)'Old
           and then Snapshot_Namespaces (Current.all) =
             Snapshot_Namespaces (Current.all)'Old
           and then Snapshot_Owners (Current.all) =
             Snapshot_Owners (Current.all)'Old);

   --  Allocate a larger backing state before changing the current one.
   --  The allocator's null/success/capacity guarantee is trusted at the
   --  XML3_DOM_Allocation boundary; all copying and sizing remain in SPARK.
   procedure Reserve
     (Current : in out State_Access;
      Needed  : Positive;
      Success : out Boolean)
   with Global => null,
     Pre => Current /= null and then Valid (Current.all) and then Can_Edit (Current.all),
     Post => Current /= null and then Valid (Current.all) and then Can_Edit (Current.all) and then
       (if not Success then
          Current.Capacity = Current.Capacity'Old
            and then Current.all = Current.all'Old
            and then Snapshot_Nodes (Current.all) =
              Snapshot_Nodes (Current.all)'Old
            and then Snapshot_Namespaces (Current.all) =
              Snapshot_Namespaces (Current.all)'Old
            and then Snapshot_Owners (Current.all) =
              Snapshot_Owners (Current.all)'Old
        else
          Current.Capacity >= Needed);

   procedure Register_Owner
     (S : in out State;
      Address : System.Address;
      B : out Owner_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S),
     Post => Valid (S) and then Can_Edit (S)
       and then (if Success then B in 1 .. Owner_Ref (Owner_Count (S))
                 and then Owner (S, B).State = Live
                 and then Owner (S, B).References = 1
                 and then Owner (S, B).Reservations = 1
                 else B = Null_Owner);

   procedure Release_Reservation
     (S : in out State; B : Owner_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S) and then B in 1 .. Owner_Ref (Owner_Count (S))
       and then Owner (S, B).State = Live
       and then Owner (S, B).Reservations > 0,
     Post => Valid (S) and then Can_Edit (S)
       and then Projection_Required (S)
       and then Owner (S, B).References = Owner (S, B).References'Old - 1
       and then Owner (S, B).Reservations = Owner (S, B).Reservations'Old - 1
       and then Owner (S, B).Address = Owner (S, B).Address'Old
       and then not Owner (S, B).Release_Emitted
       and then Owner (S, B).State =
         (if Owner (S, B).References = 0 then Releasing else Live);

   procedure Register_Node
     (S : in out State;
      Kind : Node_Kind;
      Facade : System.Address;
      Own : Owner_Ref;
      Doc_Pin : Owner_Ref;
      N : out Node_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Own in 1 .. Owner_Ref (S.Capacity)
       and then Own <= Owner_Ref (Owner_Count (S))
       and then Owner (S, Own).State = Live
       and then Owner (S, Own).Reservations > 0
       and then (Doc_Pin = Null_Owner
                 or else (Doc_Pin in 1 .. Owner_Ref (S.Capacity)
                   and then Doc_Pin <= Owner_Ref (Owner_Count (S))
                   and then Owner (S, Doc_Pin).State = Live)),
     Post => Valid (S) and then Can_Edit (S)
       and then (if not Success then N = Null_Node
                 else N in 1 .. Node_Ref (S.Capacity)
                   and then N <= Node_Ref (Node_Count (S))
                   and then Node (S, N).State = Live
                   and then Node (S, N).Kind = Kind
                   and then Node (S, N).Facade = Facade
                   and then Node (S, N).Owner = Own);

   function Projected_View
     (Item : Node_View;
      Name : System.Address; Name_Length : Natural;
      Content : System.Address; Content_Length : Natural;
      Document : Node_Ref; Namespace : Namespace_Ref;
      Namespace_Pin, Doc_Pin, Content_Pin : Owner_Ref) return Node_View
   is ((Item with delta Name => Name, Name_Length => Name_Length,
       Content => Content, Content_Length => Content_Length,
       Document => Document, Namespace => Namespace,
       Ns_Pin => Namespace_Pin, Doc_Pin => Doc_Pin, Content_Pin => Content_Pin))
   with Global => null;

   function Projection_Allowed
     (S : State; N : Node_Ref; Proposed : Node_View) return Boolean
   is
     (Proposed = Projected_View
        (Node (S, N), Proposed.Name, Proposed.Name_Length,
         Proposed.Content, Proposed.Content_Length,
         Proposed.Document, Proposed.Namespace,
         Proposed.Ns_Pin, Proposed.Doc_Pin, Proposed.Content_Pin)
      and then (Proposed.Ns_Pin = 0 or else
        (Proposed.Ns_Pin <= Owner_Ref (Owner_Count (S))
         and then Owner (S, Proposed.Ns_Pin).State = Live))
      and then (Proposed.Doc_Pin = 0 or else
        (Proposed.Doc_Pin <= Owner_Ref (Owner_Count (S))
         and then Owner (S, Proposed.Doc_Pin).State = Live))
      and then (Proposed.Content_Pin = 0 or else
        (Proposed.Content_Pin <= Owner_Ref (Owner_Count (S))
         and then Owner (S, Proposed.Content_Pin).State = Live))
      and then (Proposed.Document = 0 or else
        (Proposed.Document <= Node_Ref (Node_Count (S))
         and then Node (S, Proposed.Document).Kind = Document_Node
         and then Node (S, Proposed.Document).State in Live | Tombstone
         and then (N = Proposed.Document or else
           Proposed.Doc_Pin = Node (S, Proposed.Document).Owner)))
      and then (Proposed.Namespace = 0 or else
        (Proposed.Namespace <= Namespace_Ref (Namespace_Count (S))
         and then Namespace (S, Proposed.Namespace).State = Live
         and then Proposed.Ns_Pin = Namespace (S, Proposed.Namespace).Owner))
      and then (for all B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S)) =>
        (Holds (Node (S, N), B) or else not Holds (Proposed, B)
         or else Owner (S, B).References < Natural'Last)))
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then N in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, N).State = Live;

   procedure Set_Node_Projection
     (S : in out State;
      N : Node_Ref;
      Name : System.Address;
      Name_Length : Natural;
      Content : System.Address;
      Content_Length : Natural;
      Document : Node_Ref;
      Namespace : Namespace_Ref;
      Namespace_Pin : Owner_Ref;
      Doc_Pin : Owner_Ref;
      Content_Pin : Owner_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then N in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, N).State = Live,
     Post => (declare
       Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S)'Old;
       Original_Ns : constant Namespace_View_Array := Snapshot_Namespaces (S)'Old;
       Original_Owners : constant Owner_View_Array := Snapshot_Owners (S)'Old;
       Allowed : constant Boolean := Projection_Allowed
         (S, N, Projected_View
           (Node (S, N), Name, Name_Length, Content, Content_Length,
            Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin))'Old;
     begin
       Valid (S) and then Can_Edit (S)
       and then Capacity_Of (S) = Capacity_Of (S)'Old
       and then Node_Count (S) = Node_Count (S)'Old
       and then Namespace_Count (S) = Namespace_Count (S)'Old
       and then Owner_Count (S) = Owner_Count (S)'Old
       and then Snapshot_Marks (S) = Snapshot_Marks (S)'Old
       and then Same_Marks (S, S'Old)
       and then Release_Cursor (S) = Release_Cursor (S)'Old
       and then Success = Allowed
       and then (if Success then Projection_Required (S)
         and then Node (S, N) = Projected_View
           (Original_Nodes (Positive (N)),
            Name, Name_Length, Content, Content_Length,
            Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin)
         else Projection_Required (S) = Projection_Required (S)'Old)
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (if not Success or else I /= N then
           Node (S, I) = Original_Nodes (Positive (I))))
       and then (for all I in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) =>
         XML3_DOM.Namespace (S, I) = Original_Ns (Positive (I)))
       and then (for all B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S)) =>
         (if Holds (Original_Nodes (Positive (N)), B) = Holds (Node (S, N), B) then
           Owner (S, B) = Original_Owners (Positive (B))
          else Owner (S, B).Address = Original_Owners (Positive (B)).Address
            and then Owner (S, B).Reservations =
              Original_Owners (Positive (B)).Reservations
            and then not Owner (S, B).Release_Emitted
            and then Owner (S, B).State =
              (if Owner (S, B).References = 0 then Releasing else Live)
            and then Long_Long_Integer (Owner (S, B).References)
              + Boolean'Pos (Holds (Original_Nodes (Positive (N)), B)) =
                Long_Long_Integer (Original_Owners (Positive (B)).References)
                  + Boolean'Pos (Holds (Node (S, N), B)))));

   procedure Register_Namespace
     (S : in out State;
      Facade : System.Address;
      Href : System.Address;
      Href_Length : Natural;
      Prefix : System.Address;
      Prefix_Length : Natural;
      Own : Owner_Ref;
      Ns : out Namespace_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S) and then Own in 1 .. Owner_Ref (Owner_Count (S))
       and then Owner (S, Own).State = Live
       and then Owner (S, Own).Reservations > 0,
     Post => Valid (S) and then Can_Edit (S)
       and then (if Success then Ns in 1 .. Namespace_Ref (Namespace_Count (S))
         and then Namespace (S, Ns).State = Live
         and then Namespace (S, Ns).Facade = Facade
         and then Namespace (S, Ns).Owner = Own
         else Ns = Null_Namespace);

   procedure Attach_Namespace
     (S : in out State; Element : Node_Ref; Ns : Namespace_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Element in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Element).State = Live
       and then Ns in 1 .. Namespace_Ref (Namespace_Count (S))
       and then Namespace (S, Ns).State = Live,
     Post => Valid (S) and then Can_Edit (S)
       and then (if Success then Namespace (S, Ns).Attached
                 else Snapshot_Nodes (S) = Snapshot_Nodes (S)'Old
                   and then Snapshot_Namespaces (S) =
                     Snapshot_Namespaces (S)'Old);

   function Unlinked_View (S : State; N, I : Node_Ref) return Node_View
     with Ghost, Global => null,
       Pre => Well_Sized (S) and then N in 1 .. Node_Ref (Node_Count (S))
         and then I in 1 .. Node_Ref (Node_Count (S));

   procedure Unlink (S : in out State; N : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then N in 1 .. Node_Ref (S.Capacity)
       and then N <= Node_Ref (Node_Count (S))
       and then Node (S, N).State = Live,
     Post => Valid (S) and then Can_Edit (S)
       and then Node (S, N).Parent = Null_Node
       and then Node (S, N).Previous = Null_Node
       and then Node (S, N).Next = Null_Node
       and then Node (S, N).Facade = Node (S, N)'Old.Facade
       and then Node (S, N).Owner = Node (S, N)'Old.Owner
       and then Node (S, N).Ns_Pin = Node (S, N)'Old.Ns_Pin
       and then Node (S, N).Doc_Pin = Node (S, N)'Old.Doc_Pin
       and then Node (S, N).Content_Pin = Node (S, N)'Old.Content_Pin
       and then Node_Count (S) = Node_Count (S)'Old
       and then Namespace_Count (S) = Namespace_Count (S)'Old
       and then Owner_Count (S) = Owner_Count (S)'Old
       and then S.Capacity = S.Capacity'Old
       and then Snapshot_Namespaces (S)'First =
         Snapshot_Namespaces (S)'Old'First
       and then Snapshot_Namespaces (S)'Last =
         Snapshot_Namespaces (S)'Old'Last
       and then (for all I in Snapshot_Namespaces (S)'Range =>
         Snapshot_Namespaces (S) (I) = Snapshot_Namespaces (S)'Old (I))
       and then Snapshot_Owners (S) = Snapshot_Owners (S)'Old
       and then Snapshot_Marks (S) = Snapshot_Marks (S)'Old
       and then (if Projection_Required (S'Old) or else Node (S'Old, N).Parent /= 0
                 then Projection_Required (S))
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         Same_Pins (Node (S, I), Node (S'Old, I))
         and then Node (S, I) = Unlinked_View (S'Old, N, I));

   procedure Attach_Child
     (S : in out State; Parent, Child : Node_Ref; Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Parent in 1 .. Node_Ref (S.Capacity)
       and then Parent <= Node_Ref (Node_Count (S))
       and then Child in 1 .. Node_Ref (S.Capacity)
       and then Child <= Node_Ref (Node_Count (S))
       and then Node (S, Parent).State = Live
     and then Node (S, Child).State = Live,
     Post => (declare
       Target_Doc : constant Node_Ref :=
         (if Node (S'Old, Parent).Kind = Document_Node
          then Parent else Node (S'Old, Parent).Document);
     begin Valid (S) and then Can_Edit (S)
       and then (if Success then Node (S, Child).Parent = Parent)
       and then (if not Success then Snapshot_Nodes (S) = Snapshot_Nodes (S)'Old)
       and then (if Success then
         (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           (if Snapshot_Marks (S) (Positive (I)) then
              Node (S, I).Document = Target_Doc
              and then (Target_Doc = Null_Node
                or else Node (S, I).Doc_Pin =
                  Node (S'Old,
                    (if Node (S'Old, Parent).Kind = Document_Node
                     then Parent else Node (S'Old, Parent).Document)).Owner))))
       );

   procedure Attach_Property
     (S : in out State; Element, Attribute : Node_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then Element in 1 .. Node_Ref (Node_Count (S))
       and then Attribute in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Element).State = Live
       and then Node (S, Attribute).State = Live
       and then Node (S, Attribute).Kind = Attribute_Node,
     Post => (declare
       Target_Doc : constant Node_Ref :=
         (if Node (S'Old, Element).Kind = Document_Node
          then Element else Node (S'Old, Element).Document);
     begin Valid (S) and then Can_Edit (S)
       and then (if Success then Node (S, Attribute).Parent = Element)
       and then (if not Success then Snapshot_Nodes (S) = Snapshot_Nodes (S)'Old)
       and then (if Success then
         (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
           (if Snapshot_Marks (S) (Positive (I)) then
              Node (S, I).Document = Target_Doc
              and then (Target_Doc = Null_Node
                or else Node (S, I).Doc_Pin =
                  Node (S'Old,
                    (if Node (S'Old, Element).Kind = Document_Node
                     then Element else Node (S'Old, Element).Document)).Owner))))
       );

   procedure Free_Subtree
     (S : in out State; Root : Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S) and then Root in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, Root).State = Live,
     Post => Valid (S) and then Can_Edit (S)
       and then Node (S, Root).State = Tombstone;

   procedure Begin_Projection (S : in out State)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S),
     Post => Valid (S) and then Phase (S) = Projecting_Nodes
       and then Projection_Cursor (S) = 0
       and then Projection_Required (S) and then Same_Graph (S, S'Old);

   procedure Next_Node_Projection (S : in out State; N : out Node_Ref)
   with Global => null,
     Pre => Valid (S) and then Phase (S) = Projecting_Nodes,
     Post => Valid (S) and then Same_Graph (S, S'Old)
       and then (if N = Null_Node then Phase (S) = Projecting_Namespaces
         else Phase (S) = Node_Projection_Pending
           and then Projection_Cursor (S) > Projection_Cursor (S'Old)
           and then N in 1 .. Node_Ref (Node_Count (S))
           and then Node (S, N).State in Live | Tombstone);

   procedure Next_Namespace_Projection (S : in out State; N : out Namespace_Ref)
   with Global => null,
     Pre => Valid (S) and then Phase (S) = Projecting_Namespaces,
     Post => Valid (S) and then Same_Graph (S, S'Old)
       and then (if N = Null_Namespace then Can_Edit (S)
           and then not Projection_Required (S)
         else Phase (S) = Namespace_Projection_Pending
           and then Projection_Cursor (S) > Projection_Cursor (S'Old)
           and then N in 1 .. Namespace_Ref (Namespace_Count (S))
           and then Namespace (S, N).State = Live);

   procedure Acknowledge_Projection (S : in out State)
   with Global => null,
     Pre => Valid (S) and then Phase (S) in
       Node_Projection_Pending | Namespace_Projection_Pending,
     Post => Valid (S) and then Same_Graph (S, S'Old)
       and then Projection_Required (S)
       and then Projection_Cursor (S) = Projection_Cursor (S'Old)
       and then Phase (S) =
         (if Phase (S'Old) = Node_Projection_Pending then Projecting_Nodes
          else Projecting_Namespaces);

   procedure Take_Release
     (S : in out State; B : out Owner_Ref; Address : out System.Address)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S) and then not Projection_Required (S),
     Post => Valid (S) and then not Projection_Required (S)
       and then (if B = Null_Owner then Can_Edit (S)
           and then Address = System.Null_Address and then Same_Graph (S, S'Old)
         else Phase (S) = Release_Pending
           and then B = Active_Release (S)
           and then Release_Cursor (S) = Natural (B)
           and then Release_Cursor (S) > Release_Cursor (S'Old)
           and then B in 1 .. Owner_Ref (Owner_Count (S))
           and then Owner (S, B).State = Releasing
           and then Owner (S, B).References = 0
           and then Owner (S, B).Reservations = 0
           and then Owner (S, B).Release_Emitted
           and then not Owner (S'Old, B).Release_Emitted
           and then Address = Owner (S, B).Address);

   procedure Acknowledge_Release (S : in out State; B : Owner_Ref)
   with Global => null,
     Pre => Valid (S) and then Phase (S) = Release_Pending
       and then B = Active_Release (S)
       and then B in 1 .. Owner_Ref (Owner_Count (S))
       and then Owner (S, B).State = Releasing
       and then Owner (S, B).References = 0
       and then Owner (S, B).Reservations = 0
       and then Owner (S, B).Release_Emitted,
     Post => Valid (S) and then Can_Edit (S)
       and then not Projection_Required (S)
       and then Release_Cursor (S) = Release_Cursor (S)'Old
       and then Owner (S, B).State = Unused
       and then (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (Node (S, N).State = Unused or else Node (S, N).Owner /= B))
       and then (for all N in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) =>
         (Namespace (S, N).State = Unused or else Namespace (S, N).Owner /= B));

private
   subtype Node_Slot_Array is Node_View_Array;
   subtype Namespace_Slot_Array is Namespace_View_Array;
   subtype Owner_Slot_Array is Owner_View_Array;

   type Graph_State (Capacity : Positive) is record
      Nodes      : Node_Slot_Array (1 .. Capacity) := (others => <>);
      Namespaces : Namespace_Slot_Array (1 .. Capacity) := (others => <>);
      Owners     : Owner_Slot_Array (1 .. Capacity) := (others => <>);
      Node_Used  : Natural := 0;
      Ns_Used    : Natural := 0;
      Owner_Used : Natural := 0;
   end record;

   type Effect_State is record
      Phase : Effect_Phase := Editing;
      Dirty : Boolean := False;
      Cursor : Natural := 0;
      Released_Through : Natural := 0;
      Active_Release : Owner_Ref := Null_Owner;
   end record;

   type State (Capacity : Positive) is record
      Graph : Graph_State (Capacity);
      Effects : Effect_State;
      Marks : Mark_Array (1 .. Capacity) := (others => False);
   end record;

   function Phase (S : State) return Effect_Phase is (S.Effects.Phase);
   function Projection_Required (S : State) return Boolean is (S.Effects.Dirty);
   function Active_Release (S : State) return Owner_Ref is
     (S.Effects.Active_Release);
   function Projection_Cursor (S : State) return Natural is (S.Effects.Cursor);
   function Release_Cursor (S : State) return Natural is
     (S.Effects.Released_Through);
   function Same_Graph (Left, Right : State) return Boolean is
     (Left.Capacity = Right.Capacity
      and then Left.Graph.Node_Used = Right.Graph.Node_Used
      and then Left.Graph.Ns_Used = Right.Graph.Ns_Used
      and then Left.Graph.Owner_Used = Right.Graph.Owner_Used
      and then (for all I in 1 .. Left.Capacity =>
        Left.Graph.Nodes (I) = Right.Graph.Nodes (I)
        and then Left.Graph.Namespaces (I) = Right.Graph.Namespaces (I)
        and then Left.Graph.Owners (I) = Right.Graph.Owners (I)));

   function Effects_Valid (S : State) return Boolean is
     (S.Graph.Owner_Used <= S.Capacity
       and then S.Effects.Released_Through <= S.Graph.Owner_Used and then
       (case S.Effects.Phase is
         when Editing =>
           S.Effects.Cursor = 0 and then S.Effects.Active_Release = 0,
         when Projecting_Nodes | Node_Projection_Pending =>
           S.Effects.Dirty and then S.Effects.Active_Release = 0
           and then S.Effects.Cursor <= S.Graph.Node_Used
           and then (if S.Effects.Phase = Node_Projection_Pending then
             S.Effects.Cursor > 0),
         when Projecting_Namespaces | Namespace_Projection_Pending =>
           S.Effects.Dirty and then S.Effects.Active_Release = 0
           and then S.Effects.Cursor <= S.Graph.Ns_Used
           and then (if S.Effects.Phase = Namespace_Projection_Pending then
             S.Effects.Cursor > 0),
         when Release_Pending =>
           not S.Effects.Dirty and then S.Effects.Cursor = 0
           and then S.Effects.Active_Release in 1 .. Owner_Ref (S.Graph.Owner_Used)
           and then S.Graph.Owners (Positive (S.Effects.Active_Release)).State = Releasing)
       and then (for all I in 1 .. S.Graph.Owner_Used =>
         (S.Graph.Owners (I).Release_Emitted =
           (S.Effects.Phase = Release_Pending and then
            Owner_Ref (I) = S.Effects.Active_Release))
         and then (if not S.Effects.Dirty
           and then I <= S.Effects.Released_Through
           and then Owner_Ref (I) /= S.Effects.Active_Release
           then S.Graph.Owners (I).State /= Releasing)
         and then (if S.Graph.Owners (I).State = Releasing then
           S.Graph.Owners (I).References = 0 and then
           S.Graph.Owners (I).Reservations = 0)));

   function Node_Count (S : State) return Natural is (S.Graph.Node_Used);
   function Namespace_Count (S : State) return Natural is (S.Graph.Ns_Used);
   function Owner_Count (S : State) return Natural is (S.Graph.Owner_Used);
   function Capacity_Of (S : State) return Positive is (S.Capacity);

   function Node (S : State; N : Node_Ref) return Node_View is
     (S.Graph.Nodes (Positive (N)));
   function Namespace (S : State; N : Namespace_Ref) return Namespace_View is
     (S.Graph.Namespaces (Positive (N)));
   function Owner (S : State; B : Owner_Ref) return Owner_View is
     (S.Graph.Owners (Positive (B)));

   function Well_Sized (S : Graph_State) return Boolean is
     (S.Node_Used <= S.Capacity
      and then S.Ns_Used <= S.Capacity
      and then S.Owner_Used <= S.Capacity)
     with Ghost;

   function Well_Sized (S : State) return Boolean is
     (S.Graph.Capacity = S.Capacity and then Well_Sized (S.Graph));

   function Live_Node (S : Graph_State; N : Node_Ref) return Boolean is
     (N in 1 .. Node_Ref (S.Node_Used)
      and then S.Nodes (Positive (N)).State = Live)
     with Ghost, Pre => Well_Sized (S);

   function Live_Owner (S : Graph_State; B : Owner_Ref) return Boolean is
     (B in 1 .. Owner_Ref (S.Owner_Used)
      and then S.Owners (Positive (B)).State = Live)
     with Ghost, Pre => Well_Sized (S);

   function Node_Pins_Valid (S : Graph_State; I : Positive) return Boolean is
     (declare
        N : constant Node_View := S.Nodes (I);
      begin
        N.State /= Live or else
          (Live_Owner (S, N.Owner)
           and then (N.Ns_Pin = 0 or else Live_Owner (S, N.Ns_Pin))
           and then (N.Doc_Pin = 0 or else Live_Owner (S, N.Doc_Pin))
           and then (N.Content_Pin = 0 or else Live_Owner (S, N.Content_Pin))
           and then (if N.Document /= 0 then
             N.Document <= Node_Ref (S.Node_Used)
             and then S.Nodes (Positive (N.Document)).Kind = Document_Node
             and then S.Nodes (Positive (N.Document)).State in Live | Tombstone
             and then
               ((N.Kind = Document_Node
                 and then N.Document = Node_Ref (I))
                or else N.Doc_Pin =
                  S.Nodes (Positive (N.Document)).Owner))
           and then (if N.Namespace /= 0 then
             N.Namespace <= Namespace_Ref (S.Ns_Used)
             and then S.Namespaces (Positive (N.Namespace)).State = Live
             and then N.Ns_Pin =
               S.Namespaces (Positive (N.Namespace)).Owner)))
     with Ghost, Pre => Well_Sized (S) and then I <= S.Node_Used;

   function Node_Siblings_Valid (S : Graph_State; I : Positive) return Boolean is
     (declare
        N : constant Node_View := S.Nodes (I);
      begin
        N.State /= Live or else
          ((if N.Parent = 0 then N.Previous = 0 and N.Next = 0
                     else Live_Node (S, N.Parent)
                       and then S.Nodes (Positive (N.Parent)).Tree_Rank
                         < N.Tree_Rank
                       and then N.Parent /= Node_Ref (I))
           and then (if N.Previous /= 0 then
             Live_Node (S, N.Previous) and then N.Previous /= Node_Ref (I)
             and then S.Nodes (Positive (N.Previous)).Next = Node_Ref (I)
             and then S.Nodes (Positive (N.Previous)).Parent = N.Parent
             and then S.Nodes (Positive (N.Previous)).Sibling_Order < N.Sibling_Order
             and then (S.Nodes (Positive (N.Previous)).Kind = Attribute_Node) =
               (N.Kind = Attribute_Node))
           and then (if N.Next /= 0 then
             Live_Node (S, N.Next) and then N.Next /= Node_Ref (I)
             and then S.Nodes (Positive (N.Next)).Previous = Node_Ref (I)
             and then S.Nodes (Positive (N.Next)).Parent = N.Parent
             and then S.Nodes (Positive (N.Next)).Sibling_Order > N.Sibling_Order
             and then (S.Nodes (Positive (N.Next)).Kind = Attribute_Node) =
               (N.Kind = Attribute_Node))
           and then (if N.Parent /= 0 and then N.Previous = 0 then
             (if N.Kind = Attribute_Node then
                S.Nodes (Positive (N.Parent)).First_Prop = Node_Ref (I)
              else S.Nodes (Positive (N.Parent)).First_Child = Node_Ref (I)))
           and then (if N.Parent /= 0 and then N.Next = 0 then
             (if N.Kind = Attribute_Node then
                S.Nodes (Positive (N.Parent)).Last_Prop = Node_Ref (I)
              else S.Nodes (Positive (N.Parent)).Last_Child = Node_Ref (I)))))
     with Ghost, Pre => Well_Sized (S) and then I <= S.Node_Used;

   function Node_Children_Valid (S : Graph_State; I : Positive) return Boolean is
     (declare
        N : constant Node_View := S.Nodes (I);
      begin
        N.State /= Live or else
          (((N.First_Child = 0) = (N.Last_Child = 0))
           and then (if N.First_Child /= 0 then
             Live_Node (S, N.First_Child)
             and then S.Nodes (Positive (N.First_Child)).Previous = 0
             and then S.Nodes (Positive (N.First_Child)).Parent = Node_Ref (I)
             and then S.Nodes (Positive (N.First_Child)).Kind /= Attribute_Node)
           and then (if N.Last_Child /= 0 then
             Live_Node (S, N.Last_Child)
             and then S.Nodes (Positive (N.Last_Child)).Next = 0
             and then S.Nodes (Positive (N.Last_Child)).Parent = Node_Ref (I)
             and then S.Nodes (Positive (N.Last_Child)).Kind /= Attribute_Node)
           and then ((N.First_Prop = 0) = (N.Last_Prop = 0))
           and then (if N.First_Prop /= 0 then
             Live_Node (S, N.First_Prop)
             and then S.Nodes (Positive (N.First_Prop)).Previous = 0
             and then S.Nodes (Positive (N.First_Prop)).Parent = Node_Ref (I)
             and then S.Nodes (Positive (N.First_Prop)).Kind = Attribute_Node)
           and then (if N.Last_Prop /= 0 then
             Live_Node (S, N.Last_Prop)
             and then S.Nodes (Positive (N.Last_Prop)).Next = 0
             and then S.Nodes (Positive (N.Last_Prop)).Parent = Node_Ref (I)
             and then S.Nodes (Positive (N.Last_Prop)).Kind = Attribute_Node)))
     with Ghost, Pre => Well_Sized (S) and then I <= S.Node_Used;

   function Allocated_Namespace
     (S : Graph_State; N : Namespace_Ref) return Boolean is
     (N in 1 .. Namespace_Ref (S.Ns_Used)
      and then S.Namespaces (Positive (N)).State = Live)
     with Ghost, Pre => Well_Sized (S);

   function Node_Namespaces_Valid (S : Graph_State; I : Positive) return Boolean is
     (declare
        N : constant Node_View := S.Nodes (I);
      begin
        N.State not in Live | Tombstone or else
          (((N.First_Namespace = 0) = (N.Last_Namespace = 0))
           and then (if N.First_Namespace /= 0 then
             Allocated_Namespace (S, N.First_Namespace)
             and then S.Namespaces (Positive (N.First_Namespace)).Attached
             and then S.Namespaces (Positive (N.First_Namespace)).Parent = Node_Ref (I)
             and then S.Namespaces (Positive (N.First_Namespace)).Owner = N.Owner
             and then S.Namespaces (Positive (N.First_Namespace)).Previous = 0)
           and then (if N.Last_Namespace /= 0 then
             Allocated_Namespace (S, N.Last_Namespace)
             and then S.Namespaces (Positive (N.Last_Namespace)).Attached
             and then S.Namespaces (Positive (N.Last_Namespace)).Parent = Node_Ref (I)
             and then S.Namespaces (Positive (N.Last_Namespace)).Owner = N.Owner
             and then S.Namespaces (Positive (N.Last_Namespace)).Next = 0)))
     with Ghost, Pre => Well_Sized (S) and then I <= S.Node_Used;

   function Namespace_Links_Valid (S : Graph_State; I : Positive) return Boolean is
     (declare
        N : constant Namespace_View := S.Namespaces (I);
      begin
        N.State /= Live or else
          (N.Owner in 1 .. Owner_Ref (S.Owner_Used)
           and then S.Owners (Positive (N.Owner)).State in Live | Releasing
           and then N.Attached = (N.Parent /= 0)
           and then (if N.Parent = 0 then N.Next = 0 and then N.Previous = 0
             else N.Parent in 1 .. Node_Ref (S.Node_Used)
               and then S.Nodes (Positive (N.Parent)).State in Live | Tombstone
               and then S.Nodes (Positive (N.Parent)).Kind = Element_Node
               and then S.Nodes (Positive (N.Parent)).Owner = N.Owner)
           and then (if N.Previous /= 0 then
             Allocated_Namespace (S, N.Previous)
             and then S.Namespaces (Positive (N.Previous)).Next = Namespace_Ref (I)
             and then S.Namespaces (Positive (N.Previous)).Parent = N.Parent
             and then S.Namespaces (Positive (N.Previous)).Owner = N.Owner
             and then S.Namespaces (Positive (N.Previous)).Sibling_Order < N.Sibling_Order)
           and then (if N.Next /= 0 then
             Allocated_Namespace (S, N.Next)
             and then S.Namespaces (Positive (N.Next)).Previous = Namespace_Ref (I)
             and then S.Namespaces (Positive (N.Next)).Parent = N.Parent
             and then S.Namespaces (Positive (N.Next)).Owner = N.Owner
             and then S.Namespaces (Positive (N.Next)).Sibling_Order > N.Sibling_Order)
           and then (if N.Parent /= 0 and then N.Previous = 0 then
             S.Nodes (Positive (N.Parent)).First_Namespace = Namespace_Ref (I))
           and then (if N.Parent /= 0 and then N.Next = 0 then
             S.Nodes (Positive (N.Parent)).Last_Namespace = Namespace_Ref (I))))
     with Ghost, Pre => Well_Sized (S) and then I <= S.Ns_Used;

   function Node_Links_Valid (S : Graph_State; I : Positive) return Boolean is
     (Node_Pins_Valid (S, I) and then Node_Siblings_Valid (S, I)
      and then Node_Children_Valid (S, I) and then Node_Namespaces_Valid (S, I))
     with Ghost, Pre => Well_Sized (S) and then I <= S.Node_Used,
       Annotate => (GNATprove, Inline_For_Proof);

   function Links_Valid (S : State) return Boolean is
     ((for all I in 1 .. S.Graph.Node_Used => Node_Links_Valid (S.Graph, I))
      and then (for all I in 1 .. S.Graph.Ns_Used => Namespace_Links_Valid (S.Graph, I)));

   function Snapshot_Nodes (S : State) return Node_View_Array is
     (S.Graph.Nodes);
   function Snapshot_Marks (S : State) return Mark_Array is (S.Marks);
   function Snapshot_Namespaces (S : State) return Namespace_View_Array is
     (S.Graph.Namespaces);
   function Snapshot_Owners (S : State) return Owner_View_Array is
     (S.Graph.Owners);
end XML3_DOM;
