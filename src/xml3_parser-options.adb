package body XML3_Parser.Options with SPARK_Mode is
   function Classify (Value : Interfaces.C.int) return Profile is
   begin
      if Value < 0 then
         return Unsupported;
      end if;
      declare
         Bits : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Value);
      begin
         if (Bits and not Allowed_Bits) /= 0 then
            return Unsupported;
         elsif (Bits and Huge_Bit) /= 0 then
            return Huge;
         else
            return Normal;
         end if;
      end;
   end Classify;
end XML3_Parser.Options;
