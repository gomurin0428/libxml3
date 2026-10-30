with Ada.Text_IO;
with System;
with XML3_Native_Memory;
with XML3_Text;
with XML3_Text.Buffers;
with XML3_Text.QNames;

procedure Text_Buffers_Test is
   use type System.Address;
   use type XML3_Text.QNames.Prefix_Status;
   use type XML3_Text.QNames.Split_Status;
   use type XML3_Text.QNames.Build_Status;
   use type XML3_Text.Buffers.Concatenate_Status;
   use type XML3_Text.Buffers.Append_Status;
   use type XML3_Text.Buffers.UTF8_Status;
   use type XML3_Text.Buffers.Search_Status;
   use type XML3_Text.Buffers.Slice_Status;
   use type XML3_Text.Buffers.Escape_Status;
   use type XML3_Text.Buffers.Path_Status;
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

   procedure Check_Byte_Prefix is
      Input : aliased String := "ab";
      Early_NUL : aliased String := "a" & Character'Val (0) & "x";
      Result : System.Address;
      Status : XML3_Text.Buffers.Slice_Status;
   begin
      XML3_Text.Buffers.Copy_Byte_Prefix
        (System.Null_Address, Integer'Last, Result, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice
        and then Result = System.Null_Address);
      XML3_Text.Buffers.Copy_Byte_Prefix (Input'Address, -1, Result, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Slice
        and then Result = System.Null_Address);
      XML3_Text.Buffers.Copy_Byte_Prefix (Input'Address, 2, Result, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.Slice_Limit_Exceeded
        and then Result = System.Null_Address);
      XML3_Text.Buffers.Copy_Byte_Prefix (Early_NUL'Address, 3, Result, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.Slice_Limit_Exceeded
        and then Result = System.Null_Address);
      XML3_Text.Buffers.Copy_Byte_Prefix (Input'Address, 2, Result, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.Sliced
        and then XML3_Native_Memory.Byte_At (Result, 0) = 'a'
        and then XML3_Native_Memory.Byte_At (Result, 1) = 'b'
        and then XML3_Native_Memory.Byte_At (Result, 2) = Character'Val (0));
      XML3_Native_Memory.Free (Result);
      XML3_Text.Buffers.Copy_Byte_Prefix (Early_NUL'Address, 3, Result, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.Sliced
        and then XML3_Native_Memory.Byte_At (Result, 0) = 'a'
        and then XML3_Native_Memory.Byte_At (Result, 1) = Character'Val (0));
      XML3_Native_Memory.Free (Result);
      XML3_Text.Buffers.Copy_Byte_Prefix (Input'Address, 0, Result, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Sliced
        and then XML3_Native_Memory.Byte_At (Result, 0) = Character'Val (0));
      XML3_Native_Memory.Free (Result);
   end Check_Byte_Prefix;

   procedure Check_Concatenate is
      Left : aliased String := "ab" & Character'Val (0);
      Right : aliased String := "c" & Character'Val (0);
      Empty : aliased String := "" & Character'Val (0);
      Result : System.Address;
      Status : XML3_Text.Buffers.Concatenate_Status;
   begin
      XML3_Text.Buffers.Concatenate_Bytes
        (System.Null_Address, System.Null_Address, Integer'Last, Result, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.No_Input
        and then Result = System.Null_Address);
      for Length in -1 .. 1 loop
         if Length /= 0 then
            XML3_Text.Buffers.Concatenate_Bytes
              (Left'Address, Right'Address, Length, Result, Status, 2);
            pragma Assert (Status = XML3_Text.Buffers.Limit_Exceeded
              and then Result = System.Null_Address);
            XML3_Text.Buffers.Concatenate_Bytes
              (Left'Address, Right'Address, Length, Result, Status, 3);
            pragma Assert (Status = XML3_Text.Buffers.Copied);
            pragma Assert (XML3_Native_Memory.Byte_At (Result, 0) = 'a'
              and then XML3_Native_Memory.Byte_At (Result, 1) = 'b'
              and then XML3_Native_Memory.Byte_At (Result, 2) = 'c'
              and then XML3_Native_Memory.Byte_At (Result, 3) = Character'Val (0));
            XML3_Native_Memory.Free (Result);
         end if;
      end loop;
      XML3_Text.Buffers.Concatenate_Bytes
        (System.Null_Address, Right'Address, 2, Result, Status, 1);
      pragma Assert (Status = XML3_Text.Buffers.Limit_Exceeded
        and then Result = System.Null_Address);
      XML3_Text.Buffers.Concatenate_Bytes
        (System.Null_Address, Right'Address, 0, Result, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Copied
        and then XML3_Native_Memory.Byte_At (Result, 0) = Character'Val (0));
      XML3_Native_Memory.Free (Result);
      XML3_Text.Buffers.Concatenate_Bytes
        (Empty'Address, System.Null_Address, 0, Result, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Copied
        and then XML3_Native_Memory.Byte_At (Result, 0) = Character'Val (0));
      XML3_Native_Memory.Free (Result);
      for Limit in 0 .. 1 loop
         XML3_Text.Buffers.Concatenate_Bytes
           (Left'Address, System.Null_Address, 0, Result, Status, Limit);
         pragma Assert (Status = XML3_Text.Buffers.Limit_Exceeded
           and then Result = System.Null_Address);
      end loop;
      XML3_Text.Buffers.Concatenate_Bytes
        (Left'Address, System.Null_Address, 0, Result, Status, 2);
      pragma Assert (Status = XML3_Text.Buffers.Copied
        and then XML3_Native_Memory.Byte_At (Result, 0) = 'a'
        and then XML3_Native_Memory.Byte_At (Result, 1) = 'b'
        and then XML3_Native_Memory.Byte_At (Result, 2) = Character'Val (0));
      XML3_Native_Memory.Free (Result);
   end Check_Concatenate;

   procedure Check_QName_Build is
      Name : aliased String := "x" & Character'Val (0);
      Prefix : aliased String := "p" & Character'Val (0);
      Buffer : aliased String := "!!!!";
      Built : System.Address;
      Status : XML3_Text.QNames.Build_Status;
   begin
      XML3_Text.QNames.Build
        (Name'Address, System.Null_Address, Buffer'Address, 4, Built, Status, 0);
      pragma Assert (Status = XML3_Text.QNames.Built and then Built = Name'Address
        and then Buffer = "!!!!");
      for Limit in 0 .. 3 loop
         XML3_Text.QNames.Build
           (Name'Address, Prefix'Address, Buffer'Address, 4, Built, Status, Limit);
         pragma Assert (Status = XML3_Text.QNames.Limit_Exceeded
           and then Built = System.Null_Address and then Buffer = "!!!!");
      end loop;
      XML3_Text.QNames.Build
        (Name'Address, Prefix'Address, Buffer'Address, 4, Built, Status, 4);
      pragma Assert (Status = XML3_Text.QNames.Built and then Built = Buffer'Address
        and then Buffer = "p:x" & Character'Val (0));
   end Check_QName_Build;

   procedure Check_QName_Copy is
      Input : aliased String := "p:x" & Character'Val (0);
      Empty_Prefix : aliased String := ":";
      Prefix, Local : System.Address;
      Status : XML3_Text.QNames.Split_Status;
   begin
      XML3_Text.QNames.Split (System.Null_Address, Prefix, Local, Status, 0);
      pragma Assert (Status = XML3_Text.QNames.No_Prefix and then
        Prefix = System.Null_Address and then Local = System.Null_Address);
      for Last in 0 .. 2 loop
         XML3_Text.QNames.Split (Input'Address, Prefix, Local, Status, Last);
         pragma Assert (Status = XML3_Text.QNames.Split_Limit_Exceeded and then
           Prefix = System.Null_Address and then Local = System.Null_Address);
      end loop;
      XML3_Text.QNames.Split (Input'Address, Prefix, Local, Status, 3);
      pragma Assert (Status = XML3_Text.QNames.Split_Done);
      pragma Assert (XML3_Native_Memory.Byte_At (Prefix, 0) = 'p'
        and then XML3_Native_Memory.Byte_At (Prefix, 1) = Character'Val (0)
        and then XML3_Native_Memory.Byte_At (Local, 0) = 'x'
        and then XML3_Native_Memory.Byte_At (Local, 1) = Character'Val (0));
      XML3_Native_Memory.Free (Prefix);
      XML3_Native_Memory.Free (Local);
      XML3_Text.QNames.Split (Empty_Prefix'Address, Prefix, Local, Status, 0);
      pragma Assert (Status = XML3_Text.QNames.No_Prefix and then
        Prefix = System.Null_Address and then Local = System.Null_Address);
   end Check_QName_Copy;

   procedure Check_QName_Prefix is
      Input : aliased String := "p:x";
      Empty_Local : aliased String := "p:" & Character'Val (0);
      Empty_Prefix : aliased String := ":";
      Count : XML3_Text.Byte_Count;
      Local : System.Address;
      Status : XML3_Text.QNames.Prefix_Status;
   begin
      XML3_Text.QNames.Locate_Prefix (System.Null_Address, Count, Local, Status, 0);
      pragma Assert (Status = XML3_Text.QNames.Prefix_Absent and then Count = 0
        and then Local = System.Null_Address);
      for Last in 0 .. 1 loop
         XML3_Text.QNames.Locate_Prefix (Input'Address, Count, Local, Status, Last);
         pragma Assert (Status = XML3_Text.QNames.Prefix_Limit_Exceeded and then Count = 0
           and then Local = System.Null_Address);
      end loop;
      XML3_Text.QNames.Locate_Prefix (Input'Address, Count, Local, Status, 2);
      pragma Assert (Status = XML3_Text.QNames.Prefix_Found and then Count = 1
        and then Local = Input (3)'Address);
      XML3_Text.QNames.Locate_Prefix (Empty_Local'Address, Count, Local, Status, 2);
      pragma Assert (Status = XML3_Text.QNames.Prefix_Absent and then Count = 0
        and then Local = System.Null_Address);
      XML3_Text.QNames.Locate_Prefix (Empty_Prefix'Address, Count, Local, Status, 0);
      pragma Assert (Status = XML3_Text.QNames.Prefix_Absent and then Count = 0
        and then Local = System.Null_Address);
   end Check_QName_Prefix;

   procedure Check_Name_Values is
      Input : aliased String := "ab" & Character'Val (0);
      UTF8 : aliased String := Character'Val (16#C3#) & Character'Val (16#A9#)
        & Character'Val (0);
      Names : aliased String := "a b" & Character'Val (0);
      Tokens : aliased String := " a " & Character'Val (0);
   begin
      for Kind in XML3_Text.Buffers.Name_Value_Kind loop
         pragma Assert (not XML3_Text.Buffers.Valid_Name_Value
           (System.Null_Address, Kind, 0));
         pragma Assert (not XML3_Text.Buffers.Valid_Name_Value (Input'Address, Kind, 1));
         pragma Assert (XML3_Text.Buffers.Valid_Name_Value (Input'Address, Kind, 2));
         pragma Assert (not XML3_Text.Buffers.Valid_Name_Value (UTF8'Address, Kind, 0));
         pragma Assert (not XML3_Text.Buffers.Valid_Name_Value (UTF8'Address, Kind, 1));
         pragma Assert (XML3_Text.Buffers.Valid_Name_Value (UTF8'Address, Kind, 2));
      end loop;
      pragma Assert (not XML3_Text.Buffers.Valid_Name_Value
        (Names'Address, XML3_Text.Buffers.Name_List, 2));
      pragma Assert (XML3_Text.Buffers.Valid_Name_Value
        (Names'Address, XML3_Text.Buffers.Name_List, 3));
      pragma Assert (not XML3_Text.Buffers.Valid_Name_Value
        (Tokens'Address, XML3_Text.Buffers.Name_List, 3));
      pragma Assert (XML3_Text.Buffers.Valid_Name_Value
        (Tokens'Address, XML3_Text.Buffers.NMToken_List, 3));
   end Check_Name_Values;

   procedure Check_Streaming_Name_Validation is
      Input : aliased String := "ab" & Character'Val (0);
      QName : aliased String := "a:b" & Character'Val (0);
      UTF8 : aliased String := Character'Val (16#C3#) & Character'Val (16#A9#)
        & Character'Val (0);
      Truncated : aliased String := Character'Val (16#F0#) & Character'Val (0);
      Rejected : aliased String := "!";
   begin
      for Kind in XML3_Text.Name_Kind loop
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (System.Null_Address, Kind, False, 0) = -1);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (Input'Address, Kind, False, 1) = -1);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (Input'Address, Kind, False, 2) = 0);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (UTF8'Address, Kind, False, 0) = -1);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (UTF8'Address, Kind, False, 1) = -1);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (UTF8'Address, Kind, False, 2) = 0);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (Truncated'Address, Kind, False, 0) = -1);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (Truncated'Address, Kind, False, 1) = 1);
         pragma Assert (XML3_Text.Buffers.Validate_Name
           (Rejected'Address, Kind, False, 0) = 1);
      end loop;
      pragma Assert (XML3_Text.Buffers.Validate_Name
        (QName'Address, XML3_Text.QName, False, 2) = -1);
      pragma Assert (XML3_Text.Buffers.Validate_Name
        (QName'Address, XML3_Text.QName, False, 3) = 0);
   end Check_Streaming_Name_Validation;

   procedure Check_URI_Path is
      Input : aliased String := "a/.." & Character'Val (0);
      Empty : aliased String := (1 => Character'Val (0));
      Status : XML3_Text.Buffers.Path_Status;
   begin
      XML3_Text.Buffers.Normalize_URI_Path (System.Null_Address, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Invalid_Path);
      XML3_Text.Buffers.Normalize_URI_Path (Empty'Address, Status, 0);
      pragma Assert (Status = XML3_Text.Buffers.Normalized);
      XML3_Text.Buffers.Normalize_URI_Path (Input'Address, Status, 3);
      pragma Assert (Status = XML3_Text.Buffers.Path_Limit_Exceeded
                     and Input = "a/.." & Character'Val (0));
      XML3_Text.Buffers.Normalize_URI_Path (Input'Address, Status, 4);
      pragma Assert (Status = XML3_Text.Buffers.Normalized
                     and Input (1) = Character'Val (0));
   end Check_URI_Path;

   procedure Check_URI_Unescape is
      Empty : aliased String := (1 => Character'Val (0));
      Input : aliased String := "%41" & Character'Val (0);
      Target : aliased String := "keep";
      procedure Run
        (Source : System.Address; Length : Integer; Limit : XML3_Text.Byte_Count;
         Expected : XML3_Text.Buffers.Escape_Status; Text : String := "";
         Destination : System.Address := System.Null_Address)
      is
         Output : System.Address;
         Status : XML3_Text.Buffers.Escape_Status;
         Value : String (1 .. Text'Length);
      begin
         XML3_Text.Buffers.Unescape_URI
           (Source, Length, Destination, Output, Status, Limit);
         pragma Assert (Status = Expected);
         if Status = XML3_Text.Buffers.Escaped then
            pragma Assert (Output /= System.Null_Address);
            XML3_Native_Memory.Read_String (Output, Value);
            pragma Assert (Value = Text and then
              XML3_Native_Memory.Byte_At (Output, Text'Length) = Character'Val (0));
            if Destination = System.Null_Address then
               XML3_Native_Memory.Free (Output);
            else
               pragma Assert (Output = Destination);
            end if;
         else
            pragma Assert (Output = System.Null_Address);
         end if;
      end Run;
   begin
      Run (System.Null_Address, 3, 0, XML3_Text.Buffers.Invalid_Text,
           Destination => Target'Address);
      Run (Input'Address, 3, 2, XML3_Text.Buffers.Escape_Limit_Exceeded,
           Destination => Target'Address);
      pragma Assert (Target = "keep" and Input = "%41" & Character'Val (0));
      Run (Input'Address, 0, 2, XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Empty'Address, 0, 0, XML3_Text.Buffers.Escaped);
      Run (Input'Address, 2, 2, XML3_Text.Buffers.Escaped, "%4");
      Run (Input'Address, 3, 3, XML3_Text.Buffers.Escaped, "A");
      Run (Input'Address, Integer'First, 3, XML3_Text.Buffers.Escaped, "A",
           Target'Address);
      Run (Input'Address, 0, 3, XML3_Text.Buffers.Escaped, "A", Input'Address);
   end Check_URI_Unescape;

   procedure Check_URI is
      Empty : aliased String := (1 => Character'Val (0));
      Escaped : aliased String := "#" & Character'Val (0);
      Mixed : aliased String := "a/" & Character'Val (0);
      List : aliased String := "?/" & Character'Val (0);
      procedure Run
        (Input, Exceptions : System.Address; Limit, List_Limit : XML3_Text.Byte_Count;
         Expected : XML3_Text.Buffers.Escape_Status; Text : String := "")
      is
         Output : System.Address;
         Status : XML3_Text.Buffers.Escape_Status;
         Value : String (1 .. Text'Length);
      begin
         XML3_Text.Buffers.Escape_URI
           (Input, Exceptions, Output, Status, Limit, List_Limit);
         pragma Assert (Status = Expected);
         if Status = XML3_Text.Buffers.Escaped then
            pragma Assert (Output /= System.Null_Address);
            XML3_Native_Memory.Read_String (Output, Value);
            pragma Assert (Value = Text and then
              XML3_Native_Memory.Byte_At (Output, Text'Length) = Character'Val (0));
            XML3_Native_Memory.Free (Output);
         else
            pragma Assert (Output = System.Null_Address);
         end if;
      end Run;
   begin
      Run (System.Null_Address, List'Address, 0, 0, XML3_Text.Buffers.Invalid_Text);
      Run (Empty'Address, List'Address, 0, 0, XML3_Text.Buffers.Escaped);
      Run (Escaped'Address, System.Null_Address, 0, 0,
           XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Escaped'Address, System.Null_Address, 2, 0,
           XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Escaped'Address, System.Null_Address, 3, 0,
           XML3_Text.Buffers.Escaped, "%23");
      Run (Escaped'Address, List'Address, 3, 1,
           XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Escaped'Address, List'Address, 3, 2, XML3_Text.Buffers.Escaped, "%23");
      Run (Mixed'Address, System.Null_Address, 3, 0,
           XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Mixed'Address, System.Null_Address, 4, 0,
           XML3_Text.Buffers.Escaped, "a%2F");
      Run (Mixed'Address, List'Address, 2, 1,
           XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Mixed'Address, List'Address, 2, 2, XML3_Text.Buffers.Escaped, "a/");
   end Check_URI;

   procedure Check_Escape is
      Output : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;
      Unicode : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
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
      XML3_Text.Buffers.Escape_Special
        (Unicode, Output, Status, 5, Non_ASCII => True);
      pragma Assert (Status = XML3_Text.Buffers.Escape_Limit_Exceeded
                     and Output = System.Null_Address);
      XML3_Text.Buffers.Escape_Special
        (Unicode, Output, Status, 6, Non_ASCII => True);
      pragma Assert (Status = XML3_Text.Buffers.Escaped
                     and Output /= System.Null_Address);
      declare
         Value : String (1 .. 6);
      begin
         XML3_Native_Memory.Read_String (Output, Value);
         pragma Assert (Value = "&#xE9;"
                        and XML3_Native_Memory.Byte_At (Output, 6) = Character'Val (0));
      end;
      XML3_Native_Memory.Free (Output);
   end Check_Escape;

   procedure Check_Escape_Bytes is
      Unicode : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      Output : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;

      procedure Run
        (Value : String; Limit : XML3_Text.Byte_Count;
         Wanted : XML3_Text.Buffers.Escape_Status; Expected : String := "";
         Non_ASCII, Attribute : Boolean := False; Quotes : Boolean := True)
      is
         Source : aliased String := Value & Character'Val (0);
      begin
         XML3_Text.Buffers.Escape_Special_Bytes
           (Source'Address, Output, Status, Limit, Non_ASCII, Attribute, Quotes);
         pragma Assert (Status = Wanted);
         if Status = XML3_Text.Buffers.Escaped then
            pragma Assert (Output /= System.Null_Address);
            for I in Expected'Range loop
               pragma Assert (XML3_Native_Memory.Byte_At
                 (Output, I - Expected'First) = Expected (I));
            end loop;
            pragma Assert (XML3_Native_Memory.Byte_At
              (Output, Expected'Length) = Character'Val (0));
            XML3_Native_Memory.Free (Output);
         else
            pragma Assert (Output = System.Null_Address);
         end if;
      end Run;
   begin
      XML3_Text.Buffers.Escape_Special_Bytes
        (System.Null_Address, Output, Status);
      pragma Assert (Status = XML3_Text.Buffers.Invalid_Text
        and then Output = System.Null_Address);
      Run ("", 0, XML3_Text.Buffers.Escaped);
      Run ("a", 0, XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run ("a&", 5, XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run ("a&", 6, XML3_Text.Buffers.Escaped, "a&amp;");
      Run (Unicode, 0, XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Unicode, 1, XML3_Text.Buffers.Escape_Limit_Exceeded);
      Run (Unicode, 2, XML3_Text.Buffers.Escaped, Unicode);
      Run (Unicode, 5, XML3_Text.Buffers.Escape_Limit_Exceeded, Non_ASCII => True);
      Run (Unicode, 6, XML3_Text.Buffers.Escaped, "&#xE9;", Non_ASCII => True);
      Run ("""", 1, XML3_Text.Buffers.Escaped, """", Quotes => False);
      Run (Character'Val (9) & Character'Val (10) & '"', 15,
           XML3_Text.Buffers.Escaped, "&#9;&#10;&quot;", Attribute => True, Quotes => False);
      Run ((1 => Character'Val (1)), 1, XML3_Text.Buffers.Invalid_Text);
      Run ((1 => Character'Val (16#FF#)), 1, XML3_Text.Buffers.Invalid_Text);
      Run ("a" & Character'Val (0) & Character'Val (16#FF#), 3,
           XML3_Text.Buffers.Escaped, "a");
   end Check_Escape_Bytes;

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

   procedure Check_Measure_Byte_Prefix is
      Text : aliased String := "ab" & Character'Val (0);
      Length : XML3_Text.Byte_Count;
   begin
      XML3_Text.Buffers.Measure_Byte_Prefix
        (System.Null_Address, XML3_Text.Max_Bytes, Length);
      pragma Assert (Length = 0);
      for Limit in 0 .. 3 loop
         XML3_Text.Buffers.Measure_Byte_Prefix (Text'Address, Limit, Length);
         pragma Assert (Length = Natural'Min (Limit, 2));
      end loop;
      Text (1) := Character'Val (0);
      XML3_Text.Buffers.Measure_Byte_Prefix (Text'Address, 3, Length);
      pragma Assert (Length = 0);
   end Check_Measure_Byte_Prefix;

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

   procedure Check_Predefined_Entity is
      Amp : aliased String := "amp" & Character'Val (0);
      Missing : aliased String := "missing" & Character'Val (0);
   begin
      pragma Assert
        (XML3_Text.Buffers.Get_Predefined_Entity
           (Amp'Address) /= System.Null_Address);
      pragma Assert
        (XML3_Text.Buffers.Get_Predefined_Entity
           (Missing'Address) = System.Null_Address);
      pragma Assert
        (XML3_Text.Buffers.Get_Predefined_Entity
           (System.Null_Address) = System.Null_Address);
   end Check_Predefined_Entity;
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
   Check_Escape_Bytes;
   Check_URI;
   Check_URI_Unescape;
   Check_URI_Path;
   Check_Name_Values;
   Check_QName_Prefix;
   Check_QName_Copy;
   Check_QName_Build;
   Check_Concatenate;
   Check_Byte_Prefix;
   Check_Streaming_Name_Validation;
   Check_Append;
   Check_Measure;
   Check_Measure_Byte_Prefix;
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
   Check_Predefined_Entity;
   Ada.Text_IO.Put_Line ("text buffer boundary checks passed");
end Text_Buffers_Test;
