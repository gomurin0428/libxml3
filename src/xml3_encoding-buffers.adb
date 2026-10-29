package body XML3_Encoding.Buffers with SPARK_Mode is
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
