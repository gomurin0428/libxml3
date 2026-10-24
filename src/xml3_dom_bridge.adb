with Interfaces.C;

package body XML3_DOM_Bridge with SPARK_Mode is
   package Native renames XML3_Native_Memory;

   function Node_Address (S : State; N : Node_Ref) return System.Address is
     (if N = Null_Node then System.Null_Address else Node (S, N).Facade)
     with Global => null, Pre => N <= Node_Ref (Capacity_Of (S));

   function Namespace_Address (S : State; N : Namespace_Ref) return System.Address is
     (if N = Null_Namespace then System.Null_Address else Namespace (S, N).Facade)
     with Global => null, Pre => N <= Namespace_Ref (Capacity_Of (S));

   function Type_Number (Kind : Node_Kind) return Interfaces.C.int is
     (case Kind is
        when Element_Node => 1,
        when Attribute_Node => 2,
        when Text_Node => 3,
        when CData_Node => 4,
        when Processing_Instruction_Node => 7,
        when Comment_Node => 8,
        when Document_Node => 9);

   function Node_Command (S : State; N : Node_Ref) return Native.Node_Projection
     with Global => null,
       Pre => Valid (S) and then N in 1 .. Node_Ref (Node_Count (S))
         and then Node (S, N).State in Live | Tombstone;

   function Node_Command (S : State; N : Node_Ref) return Native.Node_Projection is
      Item : constant Node_View := Node (S, N);
   begin
      if Item.State = Tombstone then
         return (Id => Natural (N), Is_Document => Item.Kind = Document_Node,
                 Node_Type => Type_Number (Item.Kind), others => <>);
      end if;
      return
        (Id => Natural (N), Is_Document => Item.Kind = Document_Node,
         Node_Type => Type_Number (Item.Kind), Name => Item.Name,
         Children => Node_Address (S, Item.First_Child),
         Last => Node_Address (S, Item.Last_Child),
         Parent => Node_Address (S, Item.Parent),
         Next => Node_Address (S, Item.Next),
         Previous => Node_Address (S, Item.Previous),
         Document => Node_Address (S, Item.Document),
         Namespace => Namespace_Address (S, Item.Namespace),
         Content => Item.Content,
         Properties => Node_Address (S, Item.First_Prop),
         Namespace_Definitions => Namespace_Address (S, Item.First_Namespace));
   end Node_Command;

   function Namespace_Command (S : State; N : Namespace_Ref) return Native.Namespace_Projection
     with Global => null,
       Pre => Valid (S) and then N in 1 .. Namespace_Ref (Namespace_Count (S))
         and then Namespace (S, N).State = Live;

   function Namespace_Command (S : State; N : Namespace_Ref) return Native.Namespace_Projection is
      Item : constant Namespace_View := Namespace (S, N);
   begin
      return (Id => Natural (N), Next => Namespace_Address (S, Item.Next),
              Href => Item.Href, Prefix => Item.Prefix);
   end Namespace_Command;

   procedure Preserve_Facades (Before, After : State)
     with Ghost, Global => null,
       Pre => Well_Sized (Before) and then Well_Sized (After)
         and then Same_Graph (Before, After) and then Facades_Present (Before),
       Post => Facades_Present (After);

   procedure Preserve_Facades (Before, After : State) is
   begin
      for N in Node_Ref range 1 .. Node_Ref (Node_Count (After)) loop
         pragma Assert (Node (Before, N) = Node (After, N));
         pragma Assert
           (if Node (After, N).State in Live | Tombstone then
              Node (After, N).Facade /= System.Null_Address);
         pragma Loop_Invariant
           (for all I in Node_Ref range 1 .. N =>
              (if Node (After, I).State in Live | Tombstone then
                 Node (After, I).Facade /= System.Null_Address));
      end loop;
      for N in Namespace_Ref range 1 .. Namespace_Ref (Namespace_Count (After)) loop
         pragma Assert (Namespace (Before, N) = Namespace (After, N));
         pragma Assert
           (if Namespace (After, N).State = Live then
              Namespace (After, N).Facade /= System.Null_Address);
         pragma Loop_Invariant
           (for all I in Namespace_Ref range 1 .. N =>
              (if Namespace (After, I).State = Live then
                 Namespace (After, I).Facade /= System.Null_Address));
      end loop;
   end Preserve_Facades;

   procedure Synchronize (S : in out State) is
      Initial : constant State := S with Ghost;
      N : Node_Ref;
      Ns : Namespace_Ref;
      B : Owner_Ref;
      Address : System.Address;
   begin
      if Projection_Required (S) then
         declare
            Before : constant State := S with Ghost;
         begin
            Begin_Projection (S);
            Preserve_Facades (Before, S);
         end;
         loop
            pragma Loop_Invariant
              (Valid (S) and then Phase (S) = Projecting_Nodes
               and then Facades_Present (S));
            pragma Loop_Invariant (Live_Entries_Preserved (Initial, S));
            pragma Loop_Variant (Increases => Projection_Cursor (S));
            declare
               Before : constant State := S with Ghost;
            begin
               Next_Node_Projection (S, N);
               Preserve_Facades (Before, S);
            end;
            exit when N = Null_Node;
            Native.Write_Node (Node (S, N).Facade, Node_Command (S, N));
            declare
               Before : constant State := S with Ghost;
            begin
               Acknowledge_Projection (S);
               Preserve_Facades (Before, S);
            end;
         end loop;
         loop
            pragma Loop_Invariant
              (Valid (S) and then Phase (S) = Projecting_Namespaces
               and then Facades_Present (S));
            pragma Loop_Invariant (Live_Entries_Preserved (Initial, S));
            pragma Loop_Variant (Increases => Projection_Cursor (S));
            declare
               Before : constant State := S with Ghost;
            begin
               Next_Namespace_Projection (S, Ns);
               Preserve_Facades (Before, S);
            end;
            exit when Ns = Null_Namespace;
            Native.Write_Namespace
              (Namespace (S, Ns).Facade, Namespace_Command (S, Ns));
            declare
               Before : constant State := S with Ghost;
            begin
               Acknowledge_Projection (S);
               Preserve_Facades (Before, S);
            end;
         end loop;
      end if;
      loop
         pragma Loop_Invariant
           (Valid (S) and then Can_Edit (S) and then not Projection_Required (S));
         pragma Loop_Invariant (Live_Entries_Preserved (Initial, S));
         pragma Loop_Variant (Increases => Release_Cursor (S));
         Take_Release (S, B, Address);
         exit when B = Null_Owner;
         Native.Free (Address);
         Acknowledge_Release (S, B);
      end loop;
   end Synchronize;
end XML3_DOM_Bridge;
