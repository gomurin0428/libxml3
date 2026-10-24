with XML3_DOM;
with XML3_DOM_Bridge;
with XML3_Native_Memory;
with System;

package XML3_DOM_Constructors with SPARK_Mode is
   use XML3_DOM;
   use type System.Address;

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
       and then XML3_DOM.Facades_Present (Current.all),
     Post =>
       (declare
          Old_Nodes : constant Node_View_Array := Snapshot_Nodes (Current.all)'Old;
          Old_Node_Count : constant Natural := Node_Count (Current.all)'Old;
          Old_Namespace_Count : constant Natural :=
            Namespace_Count (Current.all)'Old;
          Old_Owner_Count : constant Natural := Owner_Count (Current.all)'Old;
        begin
          Current /= null
            and then Valid (Current.all) and then Can_Edit (Current.all)
            and then not Projection_Required (Current.all)
            and then XML3_DOM.Facades_Present (Current.all)
            and then Node_Count (Current.all) >= Old_Node_Count
            and then Namespace_Count (Current.all) >= Old_Namespace_Count
            and then Owner_Count (Current.all) >= Old_Owner_Count
            and then (for all I in Node_Ref range 1 .. Node_Ref (Old_Node_Count) =>
              (if Old_Nodes (Positive (I)).State = Live then
                 Node (Current.all, I) = Old_Nodes (Positive (I))))
            and then (if Status = Created then
              N in 1 .. Node_Ref (Node_Count (Current.all))
              and then Node (Current.all, N).State = Live
              and then Node (Current.all, N).Kind = Kind
              and then Node (Current.all, N).Facade /= System.Null_Address
              and then Node (Current.all, N).Parent = Null_Node
              and then Node (Current.all, N).First_Child = Null_Node
              and then Node (Current.all, N).First_Prop = Null_Node
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
end XML3_DOM_Constructors;
