with Interfaces.C;

package body XML3_DOM_Lock is
   use type Interfaces.C.int;

   function Lock return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3_dom_mutex_lock";
   function Unlock return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3_dom_mutex_unlock";

   procedure Acquire (Item : in out Guard) is
   begin
      if Item.Held then
         raise Lock_Error;
      end if;
      if Lock /= 0 then
         raise Lock_Error;
      end if;
      Item.Held := True;
   end Acquire;

   overriding procedure Finalize (Item : in out Guard) is
   begin
      if Item.Held then
         Item.Held := False;
         if Unlock /= 0 then
            raise Lock_Error;
         end if;
      end if;
   end Finalize;
end XML3_DOM_Lock;
