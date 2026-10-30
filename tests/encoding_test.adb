with Ada.Assertions; use Ada.Assertions;
with Ada.Text_IO;
with XML3_Encoding;
with XML3_Encoding.Buffers;
with XML3_Native_Memory;
with System;
with XML3_Text;

procedure Encoding_Test is
   use type XML3_Encoding.Encoding_Kind;
   use type XML3_Encoding.Conversion_Status;
   use type XML3_Encoding.Buffers.Conversion_Result;
   use type System.Address;

   function B (Value : Natural) return Character is
     (Character'Val (Value));

   Full_Input : constant String :=
     B (16#41#) & B (16#00#)
     & B (16#E9#) & B (16#00#)
     & B (16#AC#) & B (16#20#)
     & B (16#3D#) & B (16#D8#)
     & B (16#00#) & B (16#DE#);
   Expected : constant String :=
     "A" & B (16#C3#) & B (16#A9#)
     & B (16#E2#) & B (16#82#) & B (16#AC#)
     & B (16#F0#) & B (16#9F#) & B (16#98#) & B (16#80#);
   Empty_Input : constant String (1 .. 0) := "";
   Empty_Output : String (1 .. 0) := "";
   Measured : XML3_Text.Byte_Count;
   Filled : XML3_Text.Byte_Count;
   Status : XML3_Encoding.Conversion_Status;
   Error_Position : Natural;
begin
   Assert (XML3_Encoding.Classify ("utf-8") = XML3_Encoding.UTF8);
   Assert (XML3_Encoding.Classify ("UTF8") = XML3_Encoding.UTF8);
   Assert (XML3_Encoding.Classify ("uTf-16") = XML3_Encoding.UTF16);
   Assert (XML3_Encoding.Classify ("utf16") = XML3_Encoding.UTF16);
   Assert (XML3_Encoding.Classify ("UTF-16LE") = XML3_Encoding.UTF16LE);
   Assert (XML3_Encoding.Classify ("utf-16be") = XML3_Encoding.UTF16BE);
   Assert (XML3_Encoding.Valid_Name ("utf-16le"));
   Assert (not XML3_Encoding.Valid_Name ("8UTF"));
   Assert (not XML3_Encoding.Valid_Name ("UTF 8"));

   declare
      LE_BOM : constant String := B (16#FF#) & B (16#FE#);
      BE_BOM : constant String := B (16#FE#) & B (16#FF#);
      LE_Declaration : constant String :=
        B (16#3C#) & B (0) & B (16#3F#) & B (0);
      BE_Declaration : constant String :=
        B (0) & B (16#3C#) & B (0) & B (16#3F#);
      UTF8_BOM : constant String :=
        B (16#EF#) & B (16#BB#) & B (16#BF#);
      Info : XML3_Encoding.Encoding_Info;
   begin
      Info := XML3_Encoding.Detect (LE_BOM, XML3_Encoding.Unspecified);
      Assert (Info.Kind = XML3_Encoding.UTF16LE and Info.Skip = 2
              and Info.Auto_Detected);
      Info := XML3_Encoding.Detect (BE_BOM, XML3_Encoding.Unspecified);
      Assert (Info.Kind = XML3_Encoding.UTF16BE and Info.Skip = 2
              and Info.Auto_Detected);
      Info := XML3_Encoding.Detect
        (LE_Declaration, XML3_Encoding.Unspecified);
      Assert (Info.Kind = XML3_Encoding.UTF16LE and Info.Skip = 0);
      Info := XML3_Encoding.Detect
        (BE_Declaration, XML3_Encoding.Unspecified);
      Assert (Info.Kind = XML3_Encoding.UTF16BE and Info.Skip = 0);
      Info := XML3_Encoding.Detect (UTF8_BOM, XML3_Encoding.Unspecified);
      Assert (Info.Kind = XML3_Encoding.UTF8 and Info.Skip = 3);
      Info := XML3_Encoding.Detect (BE_BOM, XML3_Encoding.UTF16);
      Assert (Info.Kind = XML3_Encoding.UTF16LE
              and Info.Skip = 0 and Info.Explicit);
   end;

   XML3_Encoding.Decode_UTF16
     (Full_Input, True, Empty_Output, Measured, Status, Error_Position,
      Measure_Only => True);
   Assert (Status = XML3_Encoding.Success);
   Assert (Measured = Expected'Length);
   Assert (Error_Position = 0);
   declare
      Output : String (1 .. Expected'Length);
   begin
      XML3_Encoding.Decode_UTF16
        (Full_Input, True, Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Success);
      Assert (Filled = Measured);
      Assert (Output = Expected);
   end;

   declare
      Small_Output : String (1 .. Expected'Length - 1);
   begin
      XML3_Encoding.Decode_UTF16
        (Full_Input, True, Small_Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Output_Too_Small);
      Assert (Filled = 6);
      Assert (Error_Position = 7);
   end;

   XML3_Encoding.Decode_UTF16
     (Empty_Input, True, Empty_Output, Filled, Status, Error_Position);
   Assert (Status = XML3_Encoding.Success and Filled = 0
           and Error_Position = 0);

   declare
      Boundaries : constant String :=
        B (0) & B (16#D8#) & B (0) & B (16#DC#)
        & B (16#FF#) & B (16#DB#) & B (16#FF#) & B (16#DF#);
      Boundary_Output : String (1 .. 8);
      Boundary_Expected : constant String :=
        B (16#F0#) & B (16#90#) & B (16#80#) & B (16#80#)
        & B (16#F4#) & B (16#8F#) & B (16#BF#) & B (16#BF#);
   begin
      XML3_Encoding.Decode_UTF16
        (Boundaries, True, Boundary_Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Success and Filled = 8);
      Assert (Boundary_Output = Boundary_Expected);
   end;

   declare
      Odd : constant String := B (16#41#) & B (0) & B (16#42#);
      Lone_High : constant String := B (0) & B (16#D8#);
      Lone_Low : constant String := B (0) & B (16#DC#);
      Bad_Pair : constant String :=
        B (0) & B (16#D8#) & B (16#41#) & B (0);
      Truncated_Pair : constant String :=
        B (0) & B (16#D8#) & B (0);
      Output : String (1 .. 8);
   begin
      XML3_Encoding.Decode_UTF16
        (Odd, True, Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Invalid_Encoding
              and Error_Position = 3 and Filled = 1);
      XML3_Encoding.Decode_UTF16
        (Lone_High, True, Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Invalid_Encoding
              and Error_Position = 1);
      XML3_Encoding.Decode_UTF16
        (Lone_Low, True, Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Invalid_Encoding
              and Error_Position = 1);
      XML3_Encoding.Decode_UTF16
        (Bad_Pair, True, Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Invalid_Encoding
              and Error_Position = 1);
      XML3_Encoding.Decode_UTF16
        (Truncated_Pair, True, Output, Filled, Status, Error_Position);
      Assert (Status = XML3_Encoding.Invalid_Encoding
              and Error_Position = 1);
   end;

   declare
      Source : aliased String := Full_Input;
      Result : System.Address;
      Length : XML3_Text.Byte_Count;
      Converted : XML3_Encoding.Buffers.Conversion_Result;
      Output : String (1 .. Expected'Length);
   begin
      for Little in Boolean loop
         if not Little then
            for I in 0 .. Source'Length / 2 - 1 loop
               Source (I * 2 + 1) := Full_Input (I * 2 + 2);
               Source (I * 2 + 2) := Full_Input (I * 2 + 1);
            end loop;
         else
            Source := Full_Input;
         end if;
         XML3_Encoding.Buffers.Convert_UTF16
           (Source'Address, Source'Length, Little, Result, Length, Converted,
            Limit => Expected'Length);
         Assert (Converted = XML3_Encoding.Buffers.Converted
                 and Result /= System.Null_Address and Length = Expected'Length);
         Source := (others => B (0));
         XML3_Native_Memory.Read_String (Result, Output);
         Assert (Output = Expected);
         XML3_Native_Memory.Free (Result);
      end loop;
      Source := Full_Input;
      XML3_Encoding.Buffers.Convert_UTF16
        (Source'Address, Source'Length, True, Result, Length, Converted,
         Limit => Expected'Length - 1);
      Assert (Converted = XML3_Encoding.Buffers.Conversion_Limit_Exceeded
              and Result = System.Null_Address and Length = 0);
      XML3_Encoding.Buffers.Convert_UTF16
        (Source'Address, 0, True, Result, Length, Converted, Limit => 0);
      Assert (Converted = XML3_Encoding.Buffers.Converted
              and Result /= System.Null_Address and Length = 0);
      XML3_Native_Memory.Free (Result);
      declare
         Invalid : aliased constant String := B (0) & B (16#D8#) & B (16#41#) & B (0);
      begin
         XML3_Encoding.Buffers.Convert_UTF16
           (Invalid'Address, Invalid'Length, True, Result, Length, Converted);
         Assert (Converted = XML3_Encoding.Buffers.Invalid_UTF16
                 and Result = System.Null_Address and Length = 0);
      end;
   end;
   Ada.Text_IO.Put_Line ("UTF-16 decoder tests passed");
end Encoding_Test;
