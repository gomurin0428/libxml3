package body XML3_Encoding.Buffers with SPARK_Mode is
   package Native renames XML3_Native_Memory;

   function Detect_Bytes
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Requested : Encoding_Kind) return Encoding_Info
     with Global => (Input => Native.Foreign_Memory),
       Pre => Input /= System.Null_Address and then Requested /= Unsupported,
       Post => Detect_Bytes'Result.Skip <= Input_Length
         and then Detect_Bytes'Result.Kind /= UTF16
   is
      Probe_Length : constant Natural :=
        (if Input_Length < 2 then 0 else Natural'Min
           (Input_Length, (case Requested is
              when UTF16 | UTF16LE | UTF16BE => 2,
              when UTF8 => 3, when others => 4)));
      Header : String (1 .. Probe_Length) := (others => Character'Val (0));
   begin
      if Probe_Length > 0 then
         Native.Read_String (Input, Header);
      end if;
      return Detect (Header, Requested);
   end Detect_Bytes;

   procedure Prepare_Input
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Requested : Encoding_Kind; Result : out Input_View;
      Status : out Conversion_Result)
   is
      Normalized : System.Address;
   begin
      Result := (others => <>);
      Result.Info := Detect_Bytes (Input, Input_Length, Requested);
      Normalized := (if Result.Info.Skip = 0 then Input else
        Native.Offset (Input, Native.Byte_Count (Result.Info.Skip)));
      if Normalized = System.Null_Address then
         Status := Conversion_Limit_Exceeded;
         return;
      end if;
      if Result.Info.Kind = UTF8 then
         Result.Data := Normalized;
         Result.Length := Input_Length - Result.Info.Skip;
         Status := Converted;
      else
         Convert_UTF16
           (Normalized, Input_Length - Result.Info.Skip,
            Result.Info.Kind = UTF16LE, Result.Data, Result.Length, Status);
         Result.Owns_Data := Status = Converted;
      end if;
   end Prepare_Input;

   procedure Release_Input (Item : in out Input_View) is
   begin
      if Item.Owns_Data then
         Native.Free (Item.Data);
      end if;
      Item := (others => <>);
   end Release_Input;

   procedure Convert_UTF16_Pass
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Little_Endian : Boolean; Target : System.Address;
      Capacity : XML3_Text.Byte_Count; Written : out XML3_Text.Byte_Count;
      Status : out Conversion_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Input /= System.Null_Address,
       Post => Written <= Capacity,
       Always_Terminates
   is
      Position : XML3_Text.Byte_Count := 0;
      High, Low : UTF16_Unit;
      Have_Low : Boolean;
      Code, Consumed : Natural;
      Width : Positive range 1 .. 4;
   begin
      Written := 0;
      Status := Invalid_Encoding;
      while Position < Input_Length loop
         pragma Loop_Invariant (Position <= Input_Length);
         pragma Loop_Invariant (Written <= Capacity);
         pragma Loop_Variant (Increases => Position);
         if Input_Length - Position < 2 then
            return;
         end if;
         High := Read_UTF16_Unit
           (Native.Byte_At (Input, Position),
            Native.Byte_At (Input, Position + 1), Little_Endian);
         Have_Low := High in 16#D800# .. 16#DBFF#
           and then Input_Length - Position >= 4;
         Low := 0;
         if Have_Low then
            Low := Read_UTF16_Unit
              (Native.Byte_At (Input, Position + 2),
               Native.Byte_At (Input, Position + 3), Little_Endian);
         end if;
         Decode_UTF16_Pair (High, Low, Have_Low, Code, Consumed);
         if Consumed = 0 then
            return;
         end if;
         Width := XML3_Text.UTF8_Width (Code);
         if Width > Capacity - Written then
            Status := Output_Too_Small;
            return;
         end if;
         if Target /= System.Null_Address then
            Native.Write_String (Target, Written, XML3_Text.UTF8_Image (Code));
         end if;
         Written := Written + Width;
         Position := Position + Consumed;
      end loop;
      Status := Success;
   end Convert_UTF16_Pass;

   procedure Convert_UTF16
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Little_Endian : Boolean; Result : out System.Address;
      Length : out XML3_Text.Byte_Count; Status : out Conversion_Result;
      Limit : XML3_Text.Byte_Count := XML3_Text.Max_Bytes)
   is
      Measured, Filled : XML3_Text.Byte_Count;
      Pass_Status : Conversion_Status;
   begin
      Result := System.Null_Address;
      Length := 0;
      Status := Invalid_UTF16;
      Convert_UTF16_Pass
        (Input, Input_Length, Little_Endian, System.Null_Address,
         Limit, Measured, Pass_Status);
      if Pass_Status = Invalid_Encoding then
         return;
      elsif Pass_Status = Output_Too_Small then
         Status := Conversion_Limit_Exceeded;
         return;
      end if;
      Native.Allocate (Native.Byte_Count (Natural'Max (1, Measured)), Result);
      if Result = System.Null_Address then
         Status := Conversion_No_Memory;
         return;
      end if;
      Convert_UTF16_Pass
        (Input, Input_Length, Little_Endian, Result, Measured, Filled, Pass_Status);
      if Pass_Status = Success and then Filled = Measured then
         Length := Filled;
         Status := Converted;
      else
         Native.Free (Result);
         Result := System.Null_Address;
         Status := (if Pass_Status = Invalid_Encoding then Invalid_UTF16
                    else Conversion_Limit_Exceeded);
      end if;
   end Convert_UTF16;

   function Classify_Bytes (Name : System.Address) return Encoding_Kind is
      Matches : array (Known_Names'Range) of Boolean := (others => True);
   begin
      if Name = System.Null_Address then
         return Unspecified;
      end if;
      for Offset in 0 .. Name_Length'Last loop
         declare
            Value : constant Character :=
              XML3_Native_Memory.Byte_At (Name, Offset);
            Any_Match : Boolean := False;
         begin
            if Value = Character'Val (0) then
               for I in Known_Names'Range loop
                  if Matches (I) and then Known_Names (I).Length = Offset then
                     return Known_Names (I).Kind;
                  end if;
               end loop;
               return Unsupported;
            end if;
            for I in Known_Names'Range loop
               Matches (I) := Matches (I)
                 and then Offset < Known_Names (I).Length
                 and then Upper (Value) = Known_Names (I).Value (Offset + 1);
               Any_Match := Any_Match or Matches (I);
            end loop;
            if not Any_Match then
               return Unsupported;
            end if;
         end;
      end loop;
      return Unsupported;
   end Classify_Bytes;
end XML3_Encoding.Buffers;
