private package XML3_DOM.Projection with SPARK_Mode is
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Set_Node_Projection_Internal
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
      Name_Pin : Owner_Ref;
      Success : out Boolean)
   with Global => null,
     Pre => Valid (S) and then Can_Edit (S)
       and then N in 1 .. Node_Ref (Node_Count (S))
       and then Node (S, N).State = Live,
     Post => (declare
       Original_Nodes : constant Node_View_Array := Snapshot_Nodes (S)'Old;
       Original_Ns : constant Namespace_View_Array := Snapshot_Namespaces (S)'Old;
       Original_Owners : constant Owner_View_Array := Snapshot_Owners (S)'Old;
       Allowed : constant Boolean := Projection_Pins_Allowed
         (S, N, Projected_View
           (Node (S, N), Name, Name_Length, Content, Content_Length,
            Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin,
            Name_Pin))'Old;
     begin
       Valid (S) and then Can_Edit (S)
       and then (if Facades_Present (S'Old) then Facades_Present (S))
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
            Document, Namespace, Namespace_Pin, Doc_Pin, Content_Pin,
            Name_Pin)
         else Projection_Required (S) = Projection_Required (S)'Old)
       and then (for all I in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
         (if not Success or else I /= N then
           Node (S, I) = Original_Nodes (Positive (I))))
       and then (for all I in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (S)) =>
         XML3_DOM.Namespace (S, I) = Original_Ns (Positive (I)))
       and then Snapshot_Namespaces (S) = Original_Ns
       and then (for all B in Owner_Ref range 1 .. Owner_Ref (Owner_Count (S)) =>
         (if Original_Owners (Positive (B)).State /= Live then
            Owner (S, B) = Original_Owners (Positive (B))))
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

end XML3_DOM.Projection;
