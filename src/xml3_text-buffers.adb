package body XML3_Text.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

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

   function Compare_Bounded
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean)
      return Integer
   is
      L, R : Character;
   begin
      if Length <= 0 or else Left = Right then
         return 0;
      elsif Left = System.Null_Address then
         return -1;
      elsif Right = System.Null_Address then
         return 1;
      end if;
      for Index in 0 .. Length - 1 loop
         L := Native.Byte_At (Left, Index);
         R := Native.Byte_At (Right, Index);
         if Ignore_Case then
            L := Case_Map (L);
            R := Case_Map (R);
         end if;
         if L /= R then
            return Character'Pos (L) - Character'Pos (R);
         elsif L = Character'Val (0) then
            return 0;
         end if;
      end loop;
      return 0;
   end Compare_Bounded;

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
