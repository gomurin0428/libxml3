with Ada.Unchecked_Deallocation;

package body XML3_DOM_Allocation with SPARK_Mode => Off is
   procedure Free is new Ada.Unchecked_Deallocation
     (XML3_DOM.State, XML3_DOM.State_Access);

   function Allocate_State
     (Capacity : Positive) return XML3_DOM.State_Access
   is
   begin
      return new XML3_DOM.State (Capacity);
   exception
      when Storage_Error =>
         return null;
   end Allocate_State;

   procedure Free_State (Item : in out XML3_DOM.State_Access) is
   begin
      if Item /= null then
         Free (Item);
      end if;
   end Free_State;
end XML3_DOM_Allocation;
