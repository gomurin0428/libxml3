package body XML3_Text.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

   procedure Scan_UTF8
     (Item : System.Address; Stop_After : Integer;
      Length, Offset : out Byte_Count; Status : out UTF8_Status; Last : Byte_Count)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Length <= Offset and then Offset <= Last
         and then (if Status /= UTF8_Valid then Length = 0 and Offset = 0)
         and then (if Item = System.Null_Address then Status = UTF8_Invalid);

   procedure Check_UTF8
     (Item : System.Address; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Length : Byte_Count;
      pragma Unreferenced (Length);
   begin
      Count_UTF8 (Item, Length, Status, Last);
   end Check_UTF8;

   procedure Count_UTF8
     (Item : System.Address; Length : out Byte_Count; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Offset : Byte_Count;
      pragma Unreferenced (Offset);
   begin
      Scan_UTF8 (Item, -1, Length, Offset, Status, Last);
   end Count_UTF8;

   procedure Measure_UTF8_Prefix
     (Item : System.Address; Characters : Integer;
      Size : out Byte_Count; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Length : Byte_Count;
      pragma Unreferenced (Length);
   begin
      Size := 0;
      Status := UTF8_Valid;
      if Item = System.Null_Address or else Characters <= 0 then
         return;
      end if;
      Scan_UTF8 (Item, Characters, Length, Size, Status, Last);
   end Measure_UTF8_Prefix;

   procedure Find_UTF8_Position
     (Item : System.Address; Index : Integer;
      Position : out Byte_Count; Status : out Search_Status;
      Last : Byte_Count := Max_Bytes)
   is
      Length, Offset : Byte_Count;
      Result : UTF8_Status;
   begin
      Position := 0;
      Status := No_Match;
      if Index < 0 then
         return;
      end if;
      Scan_UTF8 (Item, Index, Length, Offset, Result, Last);
      if Result = UTF8_Valid and then Length = Index then
         Position := Offset;
         Status := Matched;
      elsif Result = UTF8_Limit_Exceeded then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_UTF8_Position;

   procedure Scan_UTF8
     (Item : System.Address; Stop_After : Integer;
      Length, Offset : out Byte_Count; Status : out UTF8_Status; Last : Byte_Count)
   is
      Position : Natural := 0;
      Count : Natural := 0;
      Bytes : String (1 .. 4) := (others => Character'Val (0));
      B : Natural;
      Width : Positive range 1 .. 4;
      Kind : Text_Error_Kind;
      Error_Position : Natural;
   begin
      Length := 0;
      Offset := 0;
      Status := UTF8_Invalid;
      if Item = System.Null_Address then
         return;
      end if;
      while Position <= Last loop
         pragma Loop_Invariant (Position <= Last + 4);
         pragma Loop_Invariant (Count <= Position);
         pragma Loop_Variant (Increases => Position);
         if Count = Stop_After then
            Length := Count;
            Offset := Position;
            Status := UTF8_Valid;
            return;
         end if;
         Bytes (1) := Native.Byte_At (Item, Position);
         B := Character'Pos (Bytes (1));
         if B = 0 then
            Length := Count;
            Offset := Position;
            Status := UTF8_Valid;
            return;
         elsif B < 128 then
            Width := 1;
         elsif B in 16#C2# .. 16#DF# then
            Width := 2;
         elsif B in 16#E0# .. 16#EF# then
            Width := 3;
         elsif B in 16#F0# .. 16#F4# then
            Width := 4;
         else
            return;
         end if;
         for Continuation in 1 .. Width - 1 loop
            if Continuation > Last - Position then
               Status := UTF8_Limit_Exceeded;
               return;
            end if;
            pragma Assert (Position + Continuation <= Last);
            Bytes (Continuation + 1) := Native.Byte_At (Item, Position + Continuation);
            if Character'Pos (Bytes (Continuation + 1)) not in 16#80# .. 16#BF# then
               return;
            end if;
         end loop;
         if Width > 1 then
            Validate_UTF8 (Bytes (1 .. Width), Kind, Error_Position, XML_Only => False);
            if Kind /= No_Text_Error then
               return;
            end if;
         end if;
         Position := Position + Width;
         Count := Count + 1;
      end loop;
      Status := UTF8_Limit_Exceeded;
   end Scan_UTF8;

   procedure Get_UTF8_Char
     (Item : System.Address; Available : Integer;
      Code : out Integer; Width : out Natural)
   is
      B : Natural;
      C : Natural;
      Minimum : Natural;
      Needed : Positive range 2 .. 4;
   begin
      Code := -1;
      Width := 0;
      if Item = System.Null_Address or else Available < 1 then
         return;
      end if;
      B := Character'Pos (Native.Byte_At (Item, 0));
      if B < 128 then
         Code := B;
         Width := 1;
         return;
      elsif B in 16#C2# .. 16#DF# then
         Needed := 2;
         C := B - 16#C0#;
         Minimum := 16#80#;
      elsif B in 16#E0# .. 16#EF# then
         Needed := 3;
         C := B - 16#E0#;
         Minimum := 16#800#;
      elsif B in 16#F0# .. 16#F4# then
         Needed := 4;
         C := B - 16#F0#;
         Minimum := 16#10000#;
      else
         return;
      end if;
      if Available < Needed then
         return;
      end if;
      for J in 1 .. Needed - 1 loop
         pragma Loop_Invariant (C <= 16#10FFFF#);
         B := Character'Pos (Native.Byte_At (Item, J));
         if B not in 16#80# .. 16#BF#
           or else C > (16#10FFFF# - (B - 16#80#)) / 64
         then
            return;
         end if;
         C := C * 64 + B - 16#80#;
      end loop;
      if C < Minimum or else C in 16#D800# .. 16#DFFF# then
         return;
      end if;
      Code := C;
      Width := Needed;
   end Get_UTF8_Char;

   procedure Read_Length
     (Item : System.Address; Last : Byte_Count;
      Length : out Byte_Count; Found : out Boolean)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Item /= System.Null_Address,
       Post => Length <= Last and then (if not Found then Length = 0)
   is
   begin
      Length := 0;
      Found := False;
      for Index in 0 .. Last loop
         if Native.Byte_At (Item, Index) = Character'Val (0) then
            Length := Index;
            Found := True;
            return;
         end if;
      end loop;
   end Read_Length;

   procedure Measure
     (Item : System.Address; Length : out Byte_Count; Success : out Boolean;
      Last : Byte_Count := Max_Bytes)
   is
   begin
      if Item = System.Null_Address then
         Length := 0;
         Success := True;
      else
         Read_Length (Item, Last, Length, Success);
      end if;
   end Measure;

   procedure Build_Append
     (Item, Addition : System.Address; Length : Integer; Terminated : Boolean;
      Result : out System.Address; Status : out Append_Status; Limit : Byte_Count)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Unchanged then Result = Item
                elsif Status = Appended then Result /= System.Null_Address
                else Result = System.Null_Address)
   is
      Prefix_Length : Byte_Count := 0;
      Added_Length : Byte_Count;
      Found : Boolean;
      Current : Character;
   begin
      Result := System.Null_Address;
      Status := Unchanged;
      if Addition = System.Null_Address or else (not Terminated and then Length = 0) then
         Result := Item;
         return;
      elsif not Terminated and then Length < 0 then
         Status := Invalid_Length;
         return;
      end if;
      Status := Append_Limit_Exceeded;
      if Terminated then
         Read_Length (Addition, Limit, Added_Length, Found);
         if not Found then
            return;
         end if;
      elsif Length > Limit then
         return;
      else
         Added_Length := Length;
      end if;
      if Added_Length = 0 and then Item /= System.Null_Address then
         Result := Item;
         Status := Unchanged;
         return;
      end if;
      if Item /= System.Null_Address then
         Read_Length (Item, Limit - Added_Length, Prefix_Length, Found);
         if not Found then
            return;
         end if;
      end if;
      Status := Append_No_Memory;
      Native.Allocate (Native.Byte_Count (Prefix_Length + Added_Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      if Item /= System.Null_Address then
         for Index in 0 .. Prefix_Length - 1 loop
            Current := Native.Byte_At (Item, Index);
            Native.Write_Byte (Result, Index, Current);
         end loop;
      end if;
      for Index in 0 .. Added_Length - 1 loop
         Current := Native.Byte_At (Addition, Index);
         Native.Write_Byte (Result, Prefix_Length + Index, Current);
      end loop;
      Native.Write_Byte (Result, Prefix_Length + Added_Length, Character'Val (0));
      Status := Appended;
   end Build_Append;

   procedure Append
     (Item, Addition : System.Address; Length : Integer; Terminated : Boolean;
      Result : out System.Address; Status : out Append_Status;
      Limit : Byte_Count := Max_Bytes)
   is
   begin
      Build_Append (Item, Addition, Length, Terminated, Result, Status, Limit);
      if Status /= Unchanged and then Item /= System.Null_Address then
         Native.Free (Item);
      end if;
   end Append;

   procedure Slice
     (Item : System.Address; Start, Length : Integer;
      Result : out System.Address; Status : out Slice_Status)
   is
      Current : Character;
   begin
      Result := System.Null_Address;
      Status := No_Slice;
      if Item = System.Null_Address or else Start < 0 or else Length < 0 then
         return;
      elsif Start >= Max_Bytes or else Length > Max_Bytes - Start then
         Status := Slice_Limit_Exceeded;
         return;
      end if;
      for Index in 0 .. Start loop
         if Native.Byte_At (Item, Index) = Character'Val (0) then
            return;
         end if;
      end loop;
      Status := No_Memory;
      Native.Allocate (Native.Byte_Count (Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      for Index in 0 .. Length - 1 loop
         Current := Native.Byte_At (Item, Start + Index);
         Native.Write_Byte (Result, Index, Current);
      end loop;
      Native.Write_Byte (Result, Length, Character'Val (0));
      Status := Sliced;
   end Slice;

   procedure Find_Byte
     (Item : System.Address; Value : Character;
      Position : out Byte_Count; Status : out Search_Status)
   is
      Current : Character;
   begin
      Position := 0;
      Status := No_Match;
      if Item = System.Null_Address or else Value = Character'Val (0) then
         return;
      end if;
      for Index in 0 .. Max_Bytes - 1 loop
         Current := Native.Byte_At (Item, Index);
         if Current = Character'Val (0) then
            return;
         elsif Current = Value then
            Position := Index;
            Status := Matched;
            return;
         end if;
      end loop;
      if Native.Byte_At (Item, Max_Bytes) /= Character'Val (0) then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_Byte;

   --  The pinned reference also maps '[' to '{'.
   function Case_Map (Item : Character) return Character is
     (if Item in 'A' .. 'Z' or else Item = '['
      then Character'Val (Character'Pos (Item) + 32) else Item);

   procedure Find_Substring
     (Item, Pattern : System.Address; Ignore_Case : Boolean;
      Position : out Byte_Count; Status : out Search_Status)
   is
      First, Current, Expected : Character;
   begin
      Position := 0;
      Status := No_Match;
      if Item = System.Null_Address or else Pattern = System.Null_Address then
         return;
      end if;
      First := Native.Byte_At (Pattern, 0);
      if First = Character'Val (0) then
         Status := Matched;
         return;
      elsif Ignore_Case then
         First := Case_Map (First);
      end if;
      for Start in 0 .. Max_Bytes - 1 loop
         Current := Native.Byte_At (Item, Start);
         if Current = Character'Val (0) then
            return;
         elsif Ignore_Case then
            Current := Case_Map (Current);
         end if;
         if Current = First then
            for Index in 1 .. Max_Bytes - Start loop
               Expected := Native.Byte_At (Pattern, Index);
               if Expected = Character'Val (0) then
                  Position := Start;
                  Status := Matched;
                  return;
               end if;
               Current := Native.Byte_At (Item, Start + Index);
               if Current = Character'Val (0) then
                  return;
               elsif Start + Index = Max_Bytes then
                  Status := Search_Limit_Exceeded;
                  return;
               end if;
               if Ignore_Case then
                  Current := Case_Map (Current);
                  Expected := Case_Map (Expected);
               end if;
               exit when Current /= Expected;
            end loop;
         end if;
      end loop;
      if Native.Byte_At (Item, Max_Bytes) /= Character'Val (0) then
         Status := Search_Limit_Exceeded;
      end if;
   end Find_Substring;

   procedure Compare_Scan
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean;
      Result : out Integer; Complete : out Boolean)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Result in -255 .. 255
   is
      L, R : Character;
   begin
      Result := 0;
      Complete := True;
      if Length <= 0 or else Left = Right then
         return;
      elsif Left = System.Null_Address then
         Result := -1;
         return;
      elsif Right = System.Null_Address then
         Result := 1;
         return;
      end if;
      for Index in 0 .. Length - 1 loop
         L := Native.Byte_At (Left, Index);
         R := Native.Byte_At (Right, Index);
         if Ignore_Case then
            L := Case_Map (L);
            R := Case_Map (R);
         end if;
         if L /= R then
            Result := Character'Pos (L) - Character'Pos (R);
            return;
         elsif L = Character'Val (0) then
            return;
         end if;
      end loop;
      Complete := False;
   end Compare_Scan;

   function Compare_Bounded
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean)
      return Integer
   is
      Result : Integer;
      Complete : Boolean;
   begin
      Compare_Scan (Left, Right, Length, Ignore_Case, Result, Complete);
      if Complete then
         return Result;
      else
         return 0;
      end if;
   end Compare_Bounded;

   procedure Compare_Terminated
     (Left, Right : System.Address; Ignore_Case : Boolean;
      Result : out Integer; Limit_Exceeded : out Boolean;
      Last : Byte_Count := Max_Bytes)
   is
      Complete : Boolean;
   begin
      Compare_Scan (Left, Right, Last + 1, Ignore_Case, Result, Complete);
      Limit_Exceeded := not Complete;
      if Limit_Exceeded then
         Result := -1;
      end if;
   end Compare_Terminated;

   procedure Concatenate
     (Left, Right : String; Has_Left, Has_Right : Boolean;
      Result : out System.Address; Status : out Concatenate_Status)
   is
      Length : Byte_Count;
   begin
      Result := System.Null_Address;
      Status := No_Input;
      if not Has_Left and then not Has_Right then
         return;
      end if;
      Status := Limit_Exceeded;
      if not Fits (Left'Length, Right'Length) then
         return;
      end if;
      Length := Left'Length + Right'Length;
      Status := No_Memory;
      Native.Allocate (Native.Byte_Count (Length) + 1, Result);
      if Result = System.Null_Address then
         return;
      end if;
      Native.Write_String (Result, 0, Left);
      Native.Write_String (Result, Left'Length, Right);
      Native.Write_Byte (Result, Length, Character'Val (0));
      Status := Copied;
   end Concatenate;

   procedure Duplicate (Input : String; Result : out System.Address) is
      Status : Concatenate_Status;
   begin
      Concatenate (Input, "", True, False, Result, Status);
      if Status /= Copied then
         Result := System.Null_Address;
      end if;
   end Duplicate;
end XML3_Text.Buffers;
