with Ada.Text_IO;
with XML3_Text;
with XML3_Text.Buffers;

procedure Text_Buffers_Test is
   Left : aliased String := "aa" & Character'Val (0);
   Right : aliased String := "aa" & Character'Val (0);
   Result : Integer;
   Limit_Flag : Boolean;

   procedure Check
     (Last : XML3_Text.Byte_Count; Ignore_Case : Boolean;
      Expected : Integer; Exceeded : Boolean)
   is
   begin
      XML3_Text.Buffers.Compare_Terminated
        (Left'Address, Right'Address, Ignore_Case, Result, Limit_Flag, Last);
      pragma Assert (Result = Expected and Limit_Flag = Exceeded);
   end Check;
begin
   Check (0, False, -1, True);
   Check (1, False, -1, True);
   Check (2, False, 0, False);
   Right (2) := 'b';
   Check (1, False, -1, False);
   Right (1 .. 2) := "AA";
   Check (0, False, 32, False);
   Check (1, True, -1, True);
   Check (2, True, 0, False);
   XML3_Text.Buffers.Compare_Terminated
     (Left'Address, Left'Address, False, Result, Limit_Flag, 0);
   pragma Assert (Result = 0 and not Limit_Flag);
   Ada.Text_IO.Put_Line ("text buffer boundary checks passed");
end Text_Buffers_Test;
