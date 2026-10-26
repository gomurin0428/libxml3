with Interfaces.C;
with XML3_DOM_Lock;

procedure DOM_Lock_Test is
   use type Interfaces.C.int;

   procedure Reset
     with Import, Convention => C, External_Name => "dom_lock_test_reset";
   procedure Fail_Next_Lock
     with Import, Convention => C,
       External_Name => "dom_lock_test_fail_next_lock";
   procedure Fail_Next_Unlock
     with Import, Convention => C,
       External_Name => "dom_lock_test_fail_next_unlock";
   function Lock_Count return Interfaces.C.int
     with Import, Convention => C, External_Name => "dom_lock_test_lock_count";
   function Unlock_Count return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "dom_lock_test_unlock_count";

   Raised : Boolean;
begin
   Reset;
   declare
      Guard : XML3_DOM_Lock.Guard;
   begin
      XML3_DOM_Lock.Acquire (Guard);
   end;
   pragma Assert (Lock_Count = 1 and Unlock_Count = 1);

   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         raise Program_Error;
      end;
   exception
      when Program_Error =>
         null;
   end;
   pragma Assert (Lock_Count = 2 and Unlock_Count = 2);

   Fail_Next_Lock;
   Raised := False;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
      end;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Raised := True;
   end;
   pragma Assert (Raised and Lock_Count = 3 and Unlock_Count = 2);

   Fail_Next_Unlock;
   Raised := False;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
      end;
   exception
      when others =>
         Raised := True;
   end;
   pragma Assert (Raised and Lock_Count = 4 and Unlock_Count = 3);

   declare
      Guard : XML3_DOM_Lock.Guard;
   begin
      XML3_DOM_Lock.Acquire (Guard);
   end;
   pragma Assert (Lock_Count = 5 and Unlock_Count = 4);
end DOM_Lock_Test;
