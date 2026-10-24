package XML3_DOM.Import with SPARK_Mode is
   use type State_Access;
   pragma Unevaluated_Use_Of_Old (Allow);

   type Import_Status is (Imported, No_Memory, Limit_Exceeded);

   function Is_Arena (S : State) return Boolean is
     (Node_Count (S) > 0 and then Owner_Count (S) = 1
      and then Facades_Present (S)
      and then Node (S, 1).Kind = Document_Node
      and then Node (S, 1).Parent = Null_Node
      and then Owner (S, 1).State = Live
      and then Owner (S, 1).Address /= System.Null_Address
      and then Owner (S, 1).Reservations = 0
      and then Owner (S, 1).References = Node_Count (S)
      and then (for all N in Node_Ref range 1 .. Node_Ref (Node_Count (S)) =>
        Node (S, N).State = Live and then Node (S, N).Owner = 1
        and then Node (S, N).Document = 1
        and then (if N /= 1 then Node (S, N).Kind /= Document_Node
          and then Node (S, N).Parent /= Null_Node))
      and then (for all N in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (S)) =>
          Namespace (S, N).State = Live and then Namespace (S, N).Owner = 1))
     with Ghost, Global => null, Pre => Valid (S);

   procedure Adopt
     (Destination : in out State; Source : in out State_Access;
      Root : out Node_Ref; Status : out Import_Status)
     with Global => null,
       Pre => Valid (Destination) and then Can_Edit (Destination)
         and then Facades_Present (Destination)
         and then Source /= null
         and then Valid (Source.all) and then Can_Edit (Source.all)
         and then Is_Arena (Source.all),
       Post => Valid (Destination) and then Can_Edit (Destination)
         and then Facades_Present (Destination)
         and then Capacity_Of (Destination) = Capacity_Of (Destination)'Old
         and then Node_Count (Destination) >= Node_Count (Destination)'Old
         and then Namespace_Count (Destination) >= Namespace_Count (Destination)'Old
         and then Owner_Count (Destination) >= Owner_Count (Destination)'Old
         and then (for all N in Node_Ref range
           1 .. Node_Ref (Node_Count (Destination)'Old) =>
             (if Node (Destination'Old, N).State in Live | Tombstone then
               Node (Destination, N) = Node (Destination'Old, N)))
         and then (for all N in Namespace_Ref range
           1 .. Namespace_Ref (Namespace_Count (Destination)'Old) =>
             (if Namespace (Destination'Old, N).State = Live then
               Namespace (Destination, N) = Namespace (Destination'Old, N)))
         and then (for all B in Owner_Ref range
           1 .. Owner_Ref (Owner_Count (Destination)'Old) =>
             (if Owner (Destination'Old, B).State in Live | Releasing then
               Owner (Destination, B) = Owner (Destination'Old, B)))
         and then (if Status = Imported then
           Source = null
           and then Root in 1 .. Node_Ref (Node_Count (Destination))
           and then Node (Destination, Root).State = Live
           and then Node (Destination, Root).Kind = Document_Node
           and then Node (Destination, Root).Document = Root
           and then Node (Destination, Root).Facade = Node (Source.all'Old, 1).Facade
           and then Projection_Required (Destination)
         else Root = Null_Node and then Source /= null
           and then Same_Graph (Destination, Destination'Old)
           and then Same_Graph (Source.all, Source.all'Old));
end XML3_DOM.Import;
