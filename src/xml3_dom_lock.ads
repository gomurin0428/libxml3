with Ada.Finalization;

package XML3_DOM_Lock is
   Lock_Error : exception;
   type Guard is new Ada.Finalization.Limited_Controlled with private;
   procedure Acquire (Item : in out Guard);
   overriding procedure Finalize (Item : in out Guard);

   --  Whether the calling thread holds the DOM lock.  Error handlers are
   --  not called while it does (they may call back into the library), and
   --  the errors published meanwhile reach them when the lock is released.
   function Held_By_Caller return Boolean;
private
   type Guard is new Ada.Finalization.Limited_Controlled with record
      Held : Boolean := False;
   end record;
end XML3_DOM_Lock;
