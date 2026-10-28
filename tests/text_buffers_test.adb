with Ada.Text_IO;
with System;
with XML3_Native_Memory;
with XML3_Text;
with XML3_Text.Buffers;

procedure Text_Buffers_Test is
   use type System.Address;
   use type XML3_Text.Buffers.Append_Status;
   use type XML3_Text.Buffers.UTF8_Status;
   use type XML3_Text.Text_Error_Kind;
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

   procedure Check_Append is
      Input, Output : System.Address;
      Status : XML3_Text.Buffers.Append_Status;
      Addition : aliased String := "b" & Character'Val (0);
   begin
      XML3_Text.Buffers.Duplicate ("a", Input);
      pragma Assert (Input /= System.Null_Address);
      XML3_Text.Buffers.Append (Input, Addition'Address, 1, False, Output, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.Append_Limit_Exceeded
                     and Output = System.Null_Address);
      XML3_Text.Buffers.Duplicate ("a", Input);
      pragma Assert (Input /= System.Null_Address);
      XML3_Text.Buffers.Append (Input, Addition'Address, 0, True, Output, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Append_Limit_Exceeded
                     and Output = System.Null_Address);
      XML3_Text.Buffers.Duplicate ("a", Input);
      pragma Assert (Input /= System.Null_Address);
      XML3_Text.Buffers.Append (Input, Addition'Address, 1, False, Output, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.Appended
                     and Output /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Byte_At (Output, 0) = 'a'
                     and XML3_Native_Memory.Byte_At (Output, 1) = 'b'
                     and XML3_Native_Memory.Byte_At (Output, 2) = Character'Val (0));
      XML3_Native_Memory.Free (Output);
   end Check_Append;

   procedure Check_Measure is
      Text : aliased String := "ab" & Character'Val (0);
      Length : XML3_Text.Byte_Count;
      Success : Boolean;
   begin
      XML3_Text.Buffers.Measure (System.Null_Address, Length, Success, 0);
      pragma Assert (Success and Length = 0);
      XML3_Text.Buffers.Measure (Text'Address, Length, Success, 0);
      pragma Assert (not Success and Length = 0);
      XML3_Text.Buffers.Measure (Text'Address, Length, Success, 1);
      pragma Assert (not Success and Length = 0);
      XML3_Text.Buffers.Measure (Text'Address, Length, Success, 2);
      pragma Assert (Success and Length = 2);
      Text (1) := Character'Val (0);
      XML3_Text.Buffers.Measure (Text'Address, Length, Success, 0);
      pragma Assert (Success and Length = 0);
   end Check_Measure;

   procedure Check_UTF8 is
      Text : aliased String := Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Status : XML3_Text.Buffers.UTF8_Status;
      Kind : XML3_Text.Text_Error_Kind;
      Error_Position : Natural;
   begin
      XML3_Text.Buffers.Check_UTF8 (System.Null_Address, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Invalid);
      for Last in 0 .. 2 loop
         XML3_Text.Buffers.Check_UTF8 (Text'Address, Status, Last);
         pragma Assert (Status = XML3_Text.Buffers.UTF8_Limit_Exceeded);
      end loop;
      XML3_Text.Buffers.Check_UTF8 (Text'Address, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid);
      Text (2) := Character'Val (0);
      XML3_Text.Buffers.Check_UTF8 (Text'Address, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Invalid);
      Text (1) := Character'Val (0);
      XML3_Text.Buffers.Check_UTF8 (Text'Address, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid);
      Text (1) := 'a';
      XML3_Text.Buffers.Check_UTF8 (Text'Address, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Limit_Exceeded);
      Text (1) := Character'Val (1);
      XML3_Text.Validate_UTF8 (Text (1 .. 1), Kind, Error_Position);
      pragma Assert (Kind = XML3_Text.Invalid_XML_Character and Error_Position = 1);
      XML3_Text.Validate_UTF8 (Text (1 .. 1), Kind, Error_Position, XML_Only => False);
      pragma Assert (Kind = XML3_Text.No_Text_Error and Error_Position = 0);
   end Check_UTF8;

   procedure Check_UTF8_Count is
      Text : aliased String := "a" & Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Status : XML3_Text.Buffers.UTF8_Status;
      Length : XML3_Text.Byte_Count;
   begin
      XML3_Text.Buffers.Count_UTF8 (System.Null_Address, Length, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Invalid and Length = 0);
      for Last in 0 .. 3 loop
         XML3_Text.Buffers.Count_UTF8 (Text'Address, Length, Status, Last);
         pragma Assert (Status = XML3_Text.Buffers.UTF8_Limit_Exceeded and Length = 0);
      end loop;
      XML3_Text.Buffers.Count_UTF8 (Text'Address, Length, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Length = 2);
      Text (3) := Character'Val (0);
      XML3_Text.Buffers.Count_UTF8 (Text'Address, Length, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Invalid and Length = 0);
      Text (2) := Character'Val (0);
      XML3_Text.Buffers.Count_UTF8 (Text'Address, Length, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Length = 1);
      Text (1) := Character'Val (0);
      XML3_Text.Buffers.Count_UTF8 (Text'Address, Length, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Length = 0);
   end Check_UTF8_Count;
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
   Check_Append;
   Check_Measure;
   Check_UTF8;
   Check_UTF8_Count;
   Ada.Text_IO.Put_Line ("text buffer boundary checks passed");
end Text_Buffers_Test;
