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
end XML3_DOM_Allocation;
