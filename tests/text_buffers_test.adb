with Ada.Text_IO;
with System;
with XML3_Native_Memory;
with XML3_Text;
with XML3_Text.Buffers;

procedure Text_Buffers_Test is
   use type System.Address;
   use type XML3_Text.Buffers.Append_Status;
   use type XML3_Text.Buffers.UTF8_Status;
   use type XML3_Text.Buffers.Search_Status;
   use type XML3_Text.Buffers.Slice_Status;
   use type XML3_Text.Buffers.Escape_Status;
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

   procedure Check_Escape is
      Output : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;
   begin
      XML3_Text.Buffers.Escape_Special ("", Output, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Escaped
                     and Output /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Byte_At (Output, 0) = Character'Val (0));
      XML3_Native_Memory.Free (Output);
      XML3_Text.Buffers.Escape_Special ("a", Output, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Escape_Limit_Exceeded
                     and Output = System.Null_Address);
      XML3_Text.Buffers.Escape_Special ("a&", Output, Status, 5);
      pragma Assert (Status = XML3_Text.Buffers.Escape_Limit_Exceeded
                     and Output = System.Null_Address);
      XML3_Text.Buffers.Escape_Special ("a&", Output, Status, 6);
      pragma Assert (Status = XML3_Text.Buffers.Escaped
                     and Output /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Byte_At (Output, 0) = 'a'
                     and XML3_Native_Memory.Byte_At (Output, 1) = '&'
                     and XML3_Native_Memory.Byte_At (Output, 5) = ';'
                     and XML3_Native_Memory.Byte_At (Output, 6) = Character'Val (0));
      XML3_Native_Memory.Free (Output);
      XML3_Text.Buffers.Escape_Special
        ((1 => Character'Val (1)), Output, Status);
      pragma Assert (Status = XML3_Text.Buffers.Invalid_Text
                     and Output = System.Null_Address);
   end Check_Escape;

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

   procedure Check_UTF8_Position is
      Text : aliased String := "a" & Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Status : XML3_Text.Buffers.Search_Status;
      Position : XML3_Text.Byte_Count;
   begin
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 0, Position, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Matched and Position = 0);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 1, Position, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Search_Limit_Exceeded and Position = 0);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 1, Position, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.Matched and Position = 1);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 2, Position, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.Search_Limit_Exceeded and Position = 0);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 2, Position, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.Matched and Position = 4);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 3, Position, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Position = 0);
      Text (3) := Character'Val (0);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, 2, Position, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Position = 0);
      XML3_Text.Buffers.Find_UTF8_Position (System.Null_Address, 0, Position, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Position = 0);
      XML3_Text.Buffers.Find_UTF8_Position (Text'Address, -1, Position, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Position = 0);
   end Check_UTF8_Position;

   procedure Check_UTF8_Prefix_Size is
      Text : aliased String := "a" & Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Status : XML3_Text.Buffers.UTF8_Status;
      Size : XML3_Text.Byte_Count;
   begin
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, 0, Size, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Size = 0);
      XML3_Text.Buffers.Measure_UTF8_Prefix (System.Null_Address, 1, Size, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Size = 0);
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, -1, Size, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Size = 0);
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, 1, Size, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Limit_Exceeded and Size = 0);
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, 1, Size, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Size = 1);
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, 2, Size, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Limit_Exceeded and Size = 0);
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, 3, Size, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Valid and Size = 4);
      Text (3) := Character'Val (0);
      XML3_Text.Buffers.Measure_UTF8_Prefix (Text'Address, 2, Size, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.UTF8_Invalid and Size = 0);
   end Check_UTF8_Prefix_Size;

   procedure Check_UTF8_Prefix_Copy is
      Text : aliased String := "a" & Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Status : XML3_Text.Buffers.Slice_Status;
      Copy : System.Address;
   begin
      XML3_Text.Buffers.Copy_UTF8_Prefix (System.Null_Address, 0, Copy, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice and Copy = System.Null_Address);
      XML3_Text.Buffers.Copy_UTF8_Prefix (Text'Address, -1, Copy, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice and Copy = System.Null_Address);
      XML3_Text.Buffers.Copy_UTF8_Prefix (Text'Address, 0, Copy, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Sliced and Copy /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Byte_At (Copy, 0) = Character'Val (0));
      XML3_Native_Memory.Free (Copy);
      XML3_Text.Buffers.Copy_UTF8_Prefix (Text'Address, 2, Copy, Status, 3);
      pragma Assert
        (Status = XML3_Text.Buffers.Slice_Limit_Exceeded and Copy = System.Null_Address);
      XML3_Text.Buffers.Copy_UTF8_Prefix (Text'Address, 3, Copy, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.Sliced and Copy /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Equal_Bytes (Copy, Text'Address, 5));
      XML3_Native_Memory.Free (Copy);
      Text (3) := Character'Val (0);
      XML3_Text.Buffers.Copy_UTF8_Prefix (Text'Address, 2, Copy, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice and Copy = System.Null_Address);
   end Check_UTF8_Prefix_Copy;

   procedure Check_UTF8_Slice is
      Text : aliased String := "a" & Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Status : XML3_Text.Buffers.Slice_Status;
      Copy : System.Address;
   begin
      XML3_Text.Buffers.Copy_UTF8_Slice (Text'Address, 1, 1, Copy, Status, 3);
      pragma Assert
        (Status = XML3_Text.Buffers.Slice_Limit_Exceeded and Copy = System.Null_Address);
      XML3_Text.Buffers.Copy_UTF8_Slice (Text'Address, 1, 1, Copy, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.Sliced and Copy /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Byte_At (Copy, 0) = Character'Val (16#E2#));
      pragma Assert (XML3_Native_Memory.Byte_At (Copy, 3) = Character'Val (0));
      XML3_Native_Memory.Free (Copy);
      XML3_Text.Buffers.Copy_UTF8_Slice (Text'Address, 2, 0, Copy, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.Sliced and Copy /= System.Null_Address);
      pragma Assert (XML3_Native_Memory.Byte_At (Copy, 0) = Character'Val (0));
      XML3_Native_Memory.Free (Copy);
      XML3_Text.Buffers.Copy_UTF8_Slice (Text'Address, 3, 0, Copy, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice and Copy = System.Null_Address);
      Text (3) := Character'Val (0);
      XML3_Text.Buffers.Copy_UTF8_Slice (Text'Address, 2, 0, Copy, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice and Copy = System.Null_Address);
      XML3_Text.Buffers.Copy_UTF8_Slice (Text'Address, 1, 1, Copy, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice and Copy = System.Null_Address);
   end Check_UTF8_Slice;

   procedure Check_UTF8_Lead_Size is
      Byte : aliased Character := Character'Val (0);
   begin
      pragma Assert (XML3_Text.Buffers.UTF8_Lead_Size (System.Null_Address) = -1);
      pragma Assert (XML3_Text.Buffers.UTF8_Lead_Size (Byte'Address) = 1);
      Byte := Character'Val (16#C2#);
      pragma Assert (XML3_Text.Buffers.UTF8_Lead_Size (Byte'Address) = 2);
      Byte := Character'Val (16#E0#);
      pragma Assert (XML3_Text.Buffers.UTF8_Lead_Size (Byte'Address) = 3);
      Byte := Character'Val (16#F4#);
      pragma Assert (XML3_Text.Buffers.UTF8_Lead_Size (Byte'Address) = 4);
      Byte := Character'Val (16#F5#);
      pragma Assert (XML3_Text.Buffers.UTF8_Lead_Size (Byte'Address) = -1);
   end Check_UTF8_Lead_Size;

   procedure Check_UTF8_Character is
      Text : aliased String := "a" & Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#) & Character'Val (0);
      Euro : aliased String := Text (2 .. 4);
      A : aliased String := "a";
      Empty : aliased Character := Character'Val (0);
      Index : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status;
   begin
      XML3_Text.Buffers.Find_UTF8_Character (Text'Address, A'Address, Index, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Matched and Index = 0);
      XML3_Text.Buffers.Find_UTF8_Character (Text'Address, Euro'Address, Index, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.Search_Limit_Exceeded and Index = 0);
      XML3_Text.Buffers.Find_UTF8_Character (Text'Address, Euro'Address, Index, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.Matched and Index = 1);
      XML3_Text.Buffers.Find_UTF8_Character (Text'Address, Empty'Address, Index, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Matched and Index = 0);
      XML3_Text.Buffers.Find_UTF8_Character (Empty'Address, A'Address, Index, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Index = 0);
      XML3_Text.Buffers.Find_UTF8_Character
        (System.Null_Address, A'Address, Index, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Index = 0);
      Text (3) := Character'Val (0);
      XML3_Text.Buffers.Find_UTF8_Character (Text'Address, Euro'Address, Index, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.No_Match and Index = 0);
   end Check_UTF8_Character;

   procedure Check_UTF8_Comparison is
      Text : aliased String := Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#);
      Other : aliased String := Text;
      A : aliased Character := 'a';
      Empty : aliased Character := Character'Val (0);
      Result : Integer;
      Invalid : Boolean;
   begin
      XML3_Text.Buffers.Compare_UTF8_Character
        (Text'Address, Other'Address, Result, Invalid);
      pragma Assert (Result = 0 and not Invalid);
      XML3_Text.Buffers.Compare_UTF8_Character
        (System.Null_Address, A'Address, Result, Invalid);
      pragma Assert (Result = -1 and not Invalid);
      XML3_Text.Buffers.Compare_UTF8_Character
        (Empty'Address, Empty'Address, Result, Invalid);
      pragma Assert (Result = 0 and not Invalid);
      Text (2) := Character'Val (0);
      XML3_Text.Buffers.Compare_UTF8_Character
        (Text'Address, Text'Address, Result, Invalid);
      pragma Assert (Result = -1 and Invalid);
      XML3_Text.Buffers.Compare_UTF8_Character
        (Text'Address, A'Address, Result, Invalid);
      pragma Assert (Result = 16#E2# - Character'Pos ('a') and not Invalid);
      Text (1) := Character'Val (16#80#);
      XML3_Text.Buffers.Compare_UTF8_Character
        (Text'Address, A'Address, Result, Invalid);
      pragma Assert (Result = -1 and Invalid);
   end Check_UTF8_Comparison;

   procedure Check_Name_Validation is
      QName : aliased String := "a:b";
      Unicode_Name : aliased String :=
        Character'Val (16#E5#) & Character'Val (16#90#)
          & Character'Val (16#8D#);
      Truncated : aliased String :=
        String'(1 => Character'Val (16#E2#));
      Injection : aliased String := "a'b]";
   begin
      pragma Assert
        (not XML3_Text.Buffers.Valid_Name
           (QName'Address, QName'Length, False));
      pragma Assert
        (XML3_Text.Buffers.Valid_Name
           (QName'Address, QName'Length, True));
      pragma Assert
        (XML3_Text.Buffers.Valid_Name
           (Unicode_Name'Address, Unicode_Name'Length, False));
      pragma Assert
        (not XML3_Text.Buffers.Valid_Name
           (Truncated'Address, Truncated'Length, False));
      pragma Assert
        (not XML3_Text.Buffers.Valid_Name
           (Injection'Address, Injection'Length, True));
      pragma Assert
        (not XML3_Text.Buffers.Valid_Name
           (System.Null_Address, 0, False));
      pragma Assert
        (not XML3_Text.Buffers.Valid_Name
           (QName'Address, 0, False));
   end Check_Name_Validation;
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
   Check_Escape;
   Check_Append;
   Check_Measure;
   Check_UTF8;
   Check_UTF8_Count;
   Check_UTF8_Position;
   Check_UTF8_Prefix_Size;
   Check_UTF8_Prefix_Copy;
   Check_UTF8_Slice;
   Check_UTF8_Lead_Size;
   Check_UTF8_Character;
   Check_UTF8_Comparison;
   Check_Name_Validation;
   Ada.Text_IO.Put_Line ("text buffer boundary checks passed");
end Text_Buffers_Test;
