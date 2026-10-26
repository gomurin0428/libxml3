with XML3_DOM;

package XML3_DOM_Allocation with SPARK_Mode is
   use type XML3_DOM.State_Access;

   function Allocate_State
     (Capacity : Positive) return XML3_DOM.State_Access
   with Global => null,
     Post => Allocate_State'Result = null
       or else Allocate_State'Result.Capacity = Capacity;

   procedure Free_State (Item : in out XML3_DOM.State_Access)
   with Global => null,
        Post => Item = null;

   type Node_Map_Array is array (Positive range <>) of XML3_DOM.Node_Ref;
   type Namespace_Map_Array is array (Positive range <>) of XML3_DOM.Namespace_Ref;
   type Import_Maps (Capacity : Positive) is record
      Nodes : Node_Map_Array (1 .. Capacity) := (others => XML3_DOM.Null_Node);
      Namespaces : Namespace_Map_Array (1 .. Capacity) :=
        (others => XML3_DOM.Null_Namespace);
   end record;
   type Import_Maps_Access is access all Import_Maps;

   function Allocate_Maps (Capacity : Positive) return Import_Maps_Access
     with Global => null,
       Post => Allocate_Maps'Result = null
         or else Allocate_Maps'Result.Capacity = Capacity;

   procedure Free_Maps (Item : in out Import_Maps_Access)
     with Global => null, Post => Item = null;
end XML3_DOM_Allocation;
