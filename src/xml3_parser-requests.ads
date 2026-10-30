with Interfaces.C;
with XML3_Encoding;
with XML3_Parser.Options;
with XML3_Text;

package XML3_Parser.Requests with SPARK_Mode is
   use type Interfaces.C.int;

   --  Admission of a parse request.  The decision is staged because the
   --  adapter must not read the caller's encoding name before the buffer
   --  arguments are accepted, and must not classify the options before the
   --  encoding is accepted.  Each stage only sees the inputs that are legal
   --  to read at that point.
   type Admission_Kind is
     (Admitted, Invalid_Argument, Unsupported_Encoding, Unsupported_Options);

   --  First stage: decided from the buffer pointer and size alone.
   function Check_Arguments
     (Has_Buffer : Boolean; Size : Interfaces.C.int) return Admission_Kind
   is
     (if Has_Buffer and then Size >= 0
        and then Size <= Interfaces.C.int (XML3_Text.Max_Bytes)
      then Admitted
      else Invalid_Argument)
   with Global => null;

   --  Second stage: only reached once the arguments are admitted.
   function After_Encoding
     (Requested : XML3_Encoding.Encoding_Kind) return Admission_Kind
   is
     (case Requested is
        when XML3_Encoding.Unsupported => Unsupported_Encoding,
        when others => Admitted)
   with Global => null;

   --  Third stage: only reached once the encoding is admitted.
   function After_Options (Selected : Options.Profile) return Admission_Kind
   is
     (case Selected is
        when Options.Unsupported => Unsupported_Options,
        when others => Admitted)
   with Global => null;

   function Huge_Requested (Selected : Options.Profile) return Boolean
   is
     (case Selected is
        when Options.Huge => True,
        when others => False)
   with Global => null;

   type Admission is record
      Kind : Admission_Kind;
      Requested : XML3_Encoding.Encoding_Kind;
      Huge : Boolean;
   end record;

   --  Composition of the stages, specifying the order in which a request is
   --  rejected.  The adapter evaluates the stages one at a time instead, so
   --  that a rejected argument check cannot read the encoding name; the
   --  encoding reported here is Unspecified in that case.
   function Admit
     (Has_Buffer : Boolean; Size : Interfaces.C.int;
      Requested : XML3_Encoding.Encoding_Kind;
      Selected : Options.Profile) return Admission
   is
     (if Check_Arguments (Has_Buffer, Size) /= Admitted
      then (Kind => Invalid_Argument,
            Requested => XML3_Encoding.Unspecified, Huge => False)
      elsif After_Encoding (Requested) /= Admitted
      then (Kind => Unsupported_Encoding, Requested => Requested,
            Huge => False)
      elsif After_Options (Selected) /= Admitted
      then (Kind => Unsupported_Options, Requested => Requested,
            Huge => False)
      else (Kind => Admitted, Requested => Requested,
            Huge => Huge_Requested (Selected)))
   with Global => null;

end XML3_Parser.Requests;
