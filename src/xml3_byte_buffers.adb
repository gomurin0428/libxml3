package body XML3_Byte_Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

   Default_Size : constant := 256;

   function Content (B : Buffer) return System.Address is
     (if B.Base = System.Null_Address then System.Null_Address
      else Native.Offset (B.Base, Native.Byte_Count (B.Offset)));

   --  memmove of Count bytes from From + From_Index to To + To_Index.  The
   --  native offsets of non-null bases are never null; the check only
   --  states it.
   procedure Move_Bytes
     (From : System.Address; From_Index : Natural;
      To : System.Address; To_Index : Natural; Count : Natural)
   with Global => (In_Out => Native.Foreign_Memory),
     Pre => From /= System.Null_Address and then To /= System.Null_Address
   is
      Source : constant System.Address :=
        Native.Offset (From, Native.Byte_Count (From_Index));
      Target : constant System.Address :=
        Native.Offset (To, Native.Byte_Count (To_Index));
   begin
      if Count > 0
        and then Source /= System.Null_Address
        and then Target /= System.Null_Address
      then
         Native.Copy_Bytes (Source, Target, Count);
      end if;
   end Move_Bytes;

   --  The size xmlBufferGrow chooses for room after Length more bytes.
   function Grown_Size (B : Buffer; Length : Natural) return Positive is
     (if B.Size > Length then
        (if B.Size <= Max_Size / 2 then 2 * B.Size else Max_Size)
      elsif B.Used + Length + 1 <= Max_Size - 100
      then B.Used + Length + 1 + 100
      else B.Used + Length + 1)
   with Global => null,
     Pre => Well_Formed (B) and then Length < Max_Size - B.Used,
     Post => Grown_Size'Result > B.Used + Length;

   --  Moves the content into a new block of New_Size bytes, keeping the
   --  NUL after the used bytes; Moved is False when the allocation fails,
   --  leaving B unchanged.
   procedure Move_To_New_Block
     (B : in out Buffer; New_Size : Positive; Moved : out Boolean)
   with Global => (In_Out => Native.Foreign_Memory),
     Pre => Well_Formed (B) and then New_Size > B.Used,
     Post => Well_Formed (B)
       and then B.Used = B'Old.Used
       and then (if Moved then B.Size = New_Size and then B.Offset = 0
                 else B = B'Old)
   is
      New_Base : System.Address;
   begin
      Native.Allocate (Native.Byte_Count (New_Size), New_Base);
      if New_Base = System.Null_Address then
         Moved := False;
         return;
      end if;
      if B.Base /= System.Null_Address then
         Move_Bytes (B.Base, B.Offset, New_Base, 0, B.Used);
         Native.Free (B.Base);
      end if;
      Native.Write_Byte (New_Base, B.Used, Character'Val (0));
      B := (Base => New_Base, Offset => 0, Used => B.Used, Size => New_Size);
      Moved := True;
   end Move_To_New_Block;

   procedure Create
     (Default : Boolean; Requested : Natural; B : out Buffer;
      Ok : out Boolean)
   is
      Size : Natural;
      Base : System.Address;
   begin
      B := (others => <>);
      Ok := False;
      if Default then
         Size := Default_Size;
      elsif Requested >= Max_Size then
         return;
      elsif Requested = 0 then
         Ok := True;
         return;
      else
         Size := Requested + 1;
      end if;
      Native.Allocate (Native.Byte_Count (Size), Base);
      if Base = System.Null_Address then
         return;
      end if;
      Native.Write_Byte (Base, 0, Character'Val (0));
      B := (Base => Base, Offset => 0, Used => 0, Size => Size);
      Ok := True;
   end Create;

   procedure Grow (B : in out Buffer; Length : Natural; Result : out Integer)
   is
      Moved : Boolean;
   begin
      if Length < B.Size - B.Used then
         Result := 0;
         return;
      elsif Length >= Max_Size - B.Used then
         Result := -1;
         return;
      end if;
      Move_To_New_Block (B, Grown_Size (B, Length), Moved);
      Result := (if Moved then B.Size - B.Used - 1 else -1);
   end Grow;

   procedure Add
     (B : in out Buffer; Source : System.Address; Length : Natural;
      Status : out Add_Status)
   is
      New_Base : System.Address;
      New_Size : Positive;
   begin
      Status := Added;
      if Length = 0 then
         return;
      elsif Length < B.Size - B.Used then
         Move_Bytes (Source, 0, B.Base, B.Offset + B.Used, Length);
         B.Used := B.Used + Length;
         Native.Write_Byte (B.Base, B.Offset + B.Used, Character'Val (0));
         return;
      elsif Length >= Max_Size - B.Used then
         Status := No_Memory;
         return;
      end if;
      --  Grows as xmlBufferGrow does, but reads Source before releasing
      --  the old block, so that bytes taken from the buffer itself stay
      --  valid.
      New_Size := Grown_Size (B, Length);
      Native.Allocate (Native.Byte_Count (New_Size), New_Base);
      if New_Base = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      if B.Base /= System.Null_Address then
         Move_Bytes (B.Base, B.Offset, New_Base, 0, B.Used);
      end if;
      Move_Bytes (Source, 0, New_Base, B.Used, Length);
      if B.Base /= System.Null_Address then
         Native.Free (B.Base);
      end if;
      Native.Write_Byte (New_Base, B.Used + Length, Character'Val (0));
      B := (Base => New_Base, Offset => 0, Used => B.Used + Length,
            Size => New_Size);
   end Add;

   procedure Add_Head
     (B : in out Buffer; Source : System.Address; Length : Natural;
      Status : out Add_Status)
   is
      Start : constant Natural := B.Offset;
      Result : Integer;
   begin
      Status := Added;
      if Length = 0 then
         return;
      elsif B.Base /= System.Null_Address and then Length <= Start then
         --  Room left by an earlier shrink.
         B.Offset := B.Offset - Length;
         Move_Bytes (Source, 0, B.Base, B.Offset, Length);
         B.Used := B.Used + Length;
         B.Size := B.Size + Length;
         return;
      elsif B.Base /= System.Null_Address
        and then Length < B.Size - B.Used + Start
      then
         --  Move the content to the start of the block.
         Move_Bytes (B.Base, B.Offset, B.Base, Length, B.Used + 1);
         Move_Bytes (Source, 0, B.Base, 0, Length);
         B.Offset := 0;
         B.Used := B.Used + Length;
         B.Size := B.Size + Start;
         return;
      end if;
      Grow (B, Length, Result);
      if Result < 0
        or else B.Base = System.Null_Address
        or else Length >= B.Size - B.Used
      then
         Status := No_Memory;
         return;
      end if;
      Move_Bytes (B.Base, B.Offset, B.Base, B.Offset + Length, B.Used + 1);
      Move_Bytes (Source, 0, B.Base, B.Offset, Length);
      B.Used := B.Used + Length;
   end Add_Head;

   procedure Shrink (B : in out Buffer; Length : Natural; Result : out Integer)
   is
   begin
      if Length = 0 then
         Result := 0;
      elsif Length > B.Used then
         Result := -1;
      else
         B.Used := B.Used - Length;
         B.Offset := B.Offset + Length;
         B.Size := B.Size - Length;
         Result := Length;
      end if;
   end Shrink;

   procedure Empty (B : in out Buffer) is
   begin
      if B.Base = System.Null_Address then
         return;
      end if;
      B.Used := 0;
      B.Size := B.Size + B.Offset;
      B.Offset := 0;
      Native.Write_Byte (B.Base, 0, Character'Val (0));
   end Empty;

   procedure Detach (B : in out Buffer; Result : out System.Address) is
   begin
      Result := Content (B);
      if B.Base /= System.Null_Address and then B.Offset /= 0 then
         Native.Allocate (Native.Byte_Count (B.Used) + 1, Result);
         if Result /= System.Null_Address then
            Move_Bytes (B.Base, B.Offset, Result, 0, B.Used);
            Native.Write_Byte (Result, B.Used, Character'Val (0));
         end if;
         Native.Free (B.Base);
      end if;
      B := (others => <>);
   end Detach;

   procedure Add_Quoted
     (B : in out Buffer; Source : System.Address; Length : Natural)
   is
      Double_Quote : constant Character := '"';
      Single_Quote : constant Character := Character'Val (39);
      Has_Double, Has_Single : Boolean := False;
      Item : Character;
      Base : Natural := 0;
      Ignored : Add_Status;

      procedure Add_Text (Target : in out Buffer; Text : String)
      with Global => (In_Out => Native.Foreign_Memory),
        Pre => Well_Formed (Target),
        Post => Well_Formed (Target)
      is
         Copy : constant String (1 .. Text'Length) := Text;
         Room : System.Address;
         Status : Add_Status;
      begin
         if Copy'Length = 0 then
            return;
         end if;
         --  Through a native copy, since Add reads native bytes.
         Native.Allocate (Native.Byte_Count (Copy'Length), Room);
         if Room = System.Null_Address then
            return;
         end if;
         Native.Write_String (Room, 0, Copy);
         Add (Target, Room, Copy'Length, Status);
         Native.Free (Room);
      end Add_Text;

      --  Source (From .. Upto - 1).
      procedure Add_Segment
        (Target : in out Buffer; Text : System.Address; From, Upto : Natural)
      with Global => (In_Out => Native.Foreign_Memory),
        Pre => Well_Formed (Target) and then Text /= System.Null_Address,
        Post => Well_Formed (Target)
      is
         Segment : constant System.Address :=
           Native.Offset (Text, Native.Byte_Count (From));
         Status : Add_Status;
      begin
         if Upto > From and then Segment /= System.Null_Address then
            Add (Target, Segment, Upto - From, Status);
         end if;
      end Add_Segment;
   begin
      if Length > 0 then
         for Index in 0 .. Length - 1 loop
            Item := Native.Byte_At (Source, Index);
            Has_Double := Has_Double or else Item = Double_Quote;
            Has_Single := Has_Single or else Item = Single_Quote;
         end loop;
      end if;
      if Has_Double and then Has_Single then
         Add_Text (B, (1 => Double_Quote));
         for Index in 0 .. Length - 1 loop
            if Native.Byte_At (Source, Index) = Double_Quote then
               Add_Segment (B, Source, Base, Index);
               Add_Text (B, "&quot;");
               Base := Index + 1;
            end if;
            pragma Loop_Invariant (Well_Formed (B));
            pragma Loop_Invariant (Base <= Index + 1);
         end loop;
         Add_Segment (B, Source, Base, Length);
         Add_Text (B, (1 => Double_Quote));
      else
         Add_Text (B, (1 => (if Has_Double then Single_Quote else Double_Quote)));
         if Length > 0 then
            Add (B, Source, Length, Ignored);
         end if;
         Add_Text (B, (1 => (if Has_Double then Single_Quote else Double_Quote)));
      end if;
   end Add_Quoted;

   procedure Release (B : in out Buffer) is
   begin
      if B.Base /= System.Null_Address then
         Native.Free (B.Base);
      end if;
      B := (others => <>);
   end Release;

end XML3_Byte_Buffers;
