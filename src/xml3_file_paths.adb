package body XML3_File_Paths with SPARK_Mode is
   package Native renames XML3_Native_Memory;

   function Lower (Item : Character) return Character is
     (if Item in 'A' .. 'Z'
      then Character'Val (Character'Pos (Item) + 32) else Item)
   with Global => null;

   --  Whether the name starts with Prefix, ignoring ASCII case.
   function Starts_With
     (Name : System.Address; Length : Natural; Prefix : String)
      return Boolean
   with Global => (Input => Native.Foreign_Memory),
     Pre => Name /= System.Null_Address and then Prefix'First = 1,
     Post => (if Starts_With'Result then Prefix'Length <= Length)
   is
   begin
      if Prefix'Length > Length then
         return False;
      end if;
      for Index in Prefix'Range loop
         if Lower (Native.Byte_At (Name, Index - 1)) /= Prefix (Index) then
            return False;
         end if;
      end loop;
      return True;
   end Starts_With;

   --  RFC 3986 scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ":".
   function Has_Scheme (Name : System.Address; Length : Natural)
     return Boolean
   with Global => (Input => Native.Foreign_Memory),
     Pre => Name /= System.Null_Address
   is
      Item : Character;
   begin
      if Length = 0
        or else Lower (Native.Byte_At (Name, 0)) not in 'a' .. 'z'
      then
         return False;
      end if;
      for Index in 1 .. Length - 1 loop
         Item := Lower (Native.Byte_At (Name, Index));
         if Item = ':' then
            return True;
         elsif Item not in 'a' .. 'z' | '0' .. '9' | '+' | '-' | '.' then
            return False;
         end if;
      end loop;
      return False;
   end Has_Scheme;

   procedure Plan
     (Name : System.Address; Length : Natural; Result : out Path_Plan)
   is
   begin
      if not Has_Scheme (Name, Length) then
         Result := (Unescape => True, Skip => 0, May_Be_Standard => True);
      elsif Starts_With (Name, Length, "file://localhost/") then
         Result := (Unescape => True, Skip => 16, May_Be_Standard => False);
      elsif Starts_With (Name, Length, "file:///") then
         Result := (Unescape => True, Skip => 7, May_Be_Standard => False);
      elsif Starts_With (Name, Length, "file:/") then
         Result := (Unescape => True, Skip => 5, May_Be_Standard => False);
      else
         Result := (Unescape => False, Skip => 0, May_Be_Standard => False);
      end if;
   end Plan;

   function Is_Standard (Path : System.Address; Length : Natural)
     return Boolean
   is (Length = 1 and then Native.Byte_At (Path, 0) = '-');

end XML3_File_Paths;
