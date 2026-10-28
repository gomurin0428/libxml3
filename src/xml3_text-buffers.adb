package body XML3_Text.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

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
