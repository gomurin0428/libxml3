with XML3_DOM;
with XML3_DOM_Bridge;
with XML3_Native_Memory;
with System;

package XML3_DOM_Constructors with SPARK_Mode is
   use XML3_DOM;
   use type System.Address;
   pragma Unevaluated_Use_Of_Old (Allow);

   type Construction_Status is
     (Created, Invalid_Argument, No_Memory, Limit_Exceeded, Internal_Error);

   procedure Create_Node
     (Current : in out State_Access;
      Kind : Node_Kind;
      Name, Content : String;
      Has_Content : Boolean;
      Ns : Namespace_Ref;
      N : out Node_Ref;
      Implicit_Ns : out Namespace_Ref;
      Status : out Construction_Status)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Current /= null
       and then Valid (Current.all) and then Can_Edit (Current.all)
       and then not Projection_Required (Current.all)
       and then XML3_DOM.Facades_Present (Current.all);
   pragma Postcondition (Current /= null);
   pragma Postcondition (Valid (Current.all));
   pragma Postcondition (Can_Edit (Current.all));
   pragma Postcondition (not Projection_Required (Current.all));
   pragma Postcondition (XML3_DOM.Facades_Present (Current.all));
   pragma Postcondition (Node_Count (Current.all) >= Node_Count (Current.all)'Old);
   pragma Postcondition (Namespace_Count (Current.all) >= Namespace_Count (Current.all)'Old);
   pragma Postcondition (Owner_Count (Current.all) >= Owner_Count (Current.all)'Old);
   pragma Postcondition
     ((declare
          Old_Owners : constant Owner_View_Array :=
            Snapshot_Owners (Current.all)'Old;
          Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
        begin
          (for all B in Owner_Ref range 1 .. Owner_Ref (Old_Owner_Count) =>
             (if Old_Owners (Positive (B)).State = Live then
                Owner (Current.all, B).State = Live))));
   pragma Postcondition
     ((declare
          Old_Owners : constant Owner_View_Array :=
            Snapshot_Owners (Current.all)'Old;
          Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
        begin
          (for all B in Owner_Ref range
              1 .. Owner_Ref (Old_Owner_Count) =>
                (if Old_Owners (Positive (B)).State = Releasing then
                  Owner (Current.all, B).State /= Live))));
   pragma Postcondition
     ((declare
          Old_Namespaces : constant Namespace_View_Array :=
            Snapshot_Namespaces (Current.all)'Old;
          Old_Namespace_Count : constant Natural :=
            Namespace_Count (Current.all)'Old;
        begin
          (if Kind /= Document_Node then
              Namespace_Count (Current.all) = Old_Namespace_Count
              and then (for all I in Namespace_Ref range
                1 .. Namespace_Ref (Old_Namespace_Count) =>
                  (if Namespace (Current.all, I).State = Live then
                    Namespace (Current.all, I) = Old_Namespaces (Positive (I)))))));
   pragma Postcondition
     ((declare
          Old_Nodes : constant Node_View_Array := Snapshot_Nodes (Current.all)'Old;
          Old_Node_Count : constant Natural := Node_Count (Current.all)'Old;
        begin
          (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
              (if Old_Nodes (Positive (I)).State = Live then
                 Node (Current.all, I) = Old_Nodes (Positive (I))))));
   pragma Postcondition
     ((declare
          Old_Nodes : constant Node_View_Array := Snapshot_Nodes (Current.all)'Old;
          Old_Node_Count : constant Natural := Node_Count (Current.all)'Old;
        begin
          (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (Current.all)) =>
             (if Node (Current.all, I).State = Live and then I /= N then
                I <= Node_Ref (Old_Node_Count)
                and then Node (Current.all, I) = Old_Nodes (Positive (I))))));
   pragma Postcondition
     ((declare
          Old_Namespaces : constant Namespace_View_Array :=
            Snapshot_Namespaces (Current.all)'Old;
          Old_Owners : constant Owner_View_Array :=
            Snapshot_Owners (Current.all)'Old;
          Old_Namespace_Count : constant Natural :=
            Namespace_Count (Current.all)'Old;
          Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
        begin
          (for all I in Namespace_Ref range
              1 .. Namespace_Ref (Old_Namespace_Count) =>
                (if Old_Namespaces (Positive (I)).State = Live
                  and then Old_Namespaces (Positive (I)).Owner in
                    1 .. Owner_Ref (Old_Owner_Count)
                  and then Old_Owners
                    (Positive (Old_Namespaces (Positive (I)).Owner)).State = Live
                 then
                   Namespace (Current.all, I) =
                     Old_Namespaces (Positive (I))))));
   pragma Postcondition
     ((if Status = Created then
              N in 1 .. Node_Ref (Node_Count (Current.all))
              and then Node (Current.all, N).State = Live
              and then Node (Current.all, N).Kind = Kind
              and then Node (Current.all, N).Facade /= System.Null_Address
              and then Node (Current.all, N).Parent = Null_Node
              and then Node (Current.all, N).First_Child = Null_Node
              and then Node (Current.all, N).First_Prop = Null_Node
              and then Node (Current.all, N).First_Namespace = Null_Namespace
              and then Node (Current.all, N).Last_Namespace = Null_Namespace
              and then (if Kind = Attribute_Node then
                Text_Attribute_Content (Current.all, N))
              and then Node (Current.all, N).Namespace = Ns
              and then Node (Current.all, N).Name_Length =
                (if Kind = Document_Node then 0 else Name'Length)
              and then Node (Current.all, N).Content_Length =
                (if Has_Content then Content'Length else 0)
              and then Node (Current.all, N).Document =
                (if Kind = Document_Node then N else Null_Node)
              and then (if Kind = Document_Node then
                Implicit_Ns in 1 .. Namespace_Ref (Namespace_Count (Current.all))
                and then Namespace (Current.all, Implicit_Ns).State = Live
                and then Namespace (Current.all, Implicit_Ns).Owner =
                  Node (Current.all, N).Owner
                else Implicit_Ns = Null_Namespace)
            else N = Null_Node and then Implicit_Ns = Null_Namespace));

   procedure Create_Namespace
     (Current : in out State_Access;
      Href, Prefix : String;
      Has_Href, Has_Prefix : Boolean;
      Ns : out Namespace_Ref;
      Status : out Construction_Status)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Current /= null
       and then Valid (Current.all) and then Can_Edit (Current.all)
       and then not Projection_Required (Current.all)
       and then XML3_DOM.Facades_Present (Current.all),
     Post =>
       (declare
          Old_Nodes : constant Node_View_Array := Snapshot_Nodes (Current.all)'Old;
          Old_Namespaces : constant Namespace_View_Array :=
            Snapshot_Namespaces (Current.all)'Old;
          Old_Owners : constant Owner_View_Array := Snapshot_Owners (Current.all)'Old;
          Old_Node_Count : constant Natural := Node_Count (Current.all)'Old;
          Old_Namespace_Count : constant Natural := Namespace_Count (Current.all)'Old;
          Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
        begin
          Current /= null
          and then Valid (Current.all) and then Can_Edit (Current.all)
          and then XML3_DOM.Facades_Present (Current.all)
          and then Node_Count (Current.all) = Old_Node_Count
          and then Namespace_Count (Current.all) >= Old_Namespace_Count
          and then Owner_Count (Current.all) >= Old_Owner_Count
          and then (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
            (if Old_Nodes (Positive (I)).State = Live then
               Node (Current.all, I) = Old_Nodes (Positive (I))))
          and then (for all I in Namespace_Ref range
            1 .. Namespace_Ref (Old_Namespace_Count) =>
              (if Old_Namespaces (Positive (I)).State = Live
                and then Old_Namespaces (Positive (I)).Owner in
                  1 .. Owner_Ref (Old_Owner_Count)
                and then Old_Owners
                  (Positive (Old_Namespaces (Positive (I)).Owner)).State = Live
               then
                 Namespace (Current.all, I) = Old_Namespaces (Positive (I))))
          and then (for all I in Owner_Ref range 1 .. Owner_Ref (Old_Owner_Count) =>
            (if Old_Owners (Positive (I)).State = Live then
               Owner (Current.all, I) = Old_Owners (Positive (I))))
          and then (if Status = Created then
            Ns in 1 .. Namespace_Ref (Namespace_Count (Current.all))
            and then Namespace (Current.all, Ns).State = Live
            and then Namespace (Current.all, Ns).Owns_Reservation
            and then Namespace (Current.all, Ns).Parent = Null_Node
            and then Namespace (Current.all, Ns).Facade /= System.Null_Address
            and then Projection_Required (Current.all)
          else Ns = Null_Namespace
            and then not Projection_Required (Current.all)));
end XML3_DOM_Constructors;
