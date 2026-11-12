with Interfaces.C;
with XML3_Errors;

package body XML3_DOM_Lock is
   use type Interfaces.C.int;

   function Lock return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3_dom_mutex_lock";
   function Unlock return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3_dom_mutex_unlock";

   Held_Here : Boolean := False
     with Thread_Local_Storage;

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
         XML3_Errors.Dispatch_Deferred;
      end if;
   end Finalize;

   function Held_By_Caller return Boolean is (Held_Here);
end XML3_DOM_Lock;
