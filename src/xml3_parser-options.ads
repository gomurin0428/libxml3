with Interfaces.C;

package XML3_Parser.Options with SPARK_Mode is
   use type Interfaces.C.int;
   use type Interfaces.Unsigned_32;

   type Profile is (Unsupported, Normal, Huge);
   Allowed_Bits : constant Interfaces.Unsigned_32 := 16#0008_0860#;
   Huge_Bit : constant Interfaces.Unsigned_32 := 16#0008_0000#;

   function Classify (Value : Interfaces.C.int) return Profile
     with Global => null,
       Post => (Classify'Result /= Unsupported) =
         (Value >= 0 and then
          (Interfaces.Unsigned_32 (Value) and not Allowed_Bits) = 0)
         and then (Classify'Result = Huge) =
           (Classify'Result /= Unsupported and then
            (Interfaces.Unsigned_32 (Value) and Huge_Bit) /= 0);
end XML3_Parser.Options;
