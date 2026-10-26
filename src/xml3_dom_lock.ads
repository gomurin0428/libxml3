with Ada.Finalization;

package XML3_DOM_Lock is
   Lock_Error : exception;
   type Guard is new Ada.Finalization.Limited_Controlled with private;
   procedure Acquire (Item : in out Guard);
   overriding procedure Finalize (Item : in out Guard);
private
   type Guard is new Ada.Finalization.Limited_Controlled with record
      Held : Boolean := False;
   end record;
end XML3_DOM_Lock;
