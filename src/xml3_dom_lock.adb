with Interfaces.C;

package body XML3_DOM_Lock is
   use type Interfaces.C.int;

   function Lock return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3_dom_mutex_lock";
   function Unlock return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3_dom_mutex_unlock";

   Held_Here : Boolean := False
     with Thread_Local_Storage;

   After_Release : Release_Hook := null;

   procedure Set_Release_Hook (Hook : Release_Hook) is
   begin
      After_Release := Hook;
   end Set_Release_Hook;

   procedure Acquire (Item : in out Guard) is
   begin
      if Item.Held then
         raise Lock_Error;
      end if;
      if Lock /= 0 then
         raise Lock_Error;
      end if;
      Item.Held := True;
      Held_Here := True;
   end Acquire;

   overriding procedure Finalize (Item : in out Guard) is
   begin
      if Item.Held then
         Item.Held := False;
         Held_Here := False;
         if Unlock /= 0 then
            raise Lock_Error;
         end if;
         if After_Release /= null then
            After_Release.all;
         end if;
      end if;
   end Finalize;

   function Held_By_Caller return Boolean is (Held_Here);
end XML3_DOM_Lock;
