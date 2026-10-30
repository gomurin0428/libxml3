with Interfaces.C;
with XML3_DOM_Constructors;
with XML3_Encoding.Buffers;
with XML3_Parser.Outcomes;
with XML3_Parser.Requests;

package XML3_Diagnostic_Codes with SPARK_Mode is

   --  Selects the (domain, code) pair the adapter publishes for an
   --  operation outcome.  Present is False when no diagnostic is reported
   --  or when the reported diagnostic comes from the parser itself.
   type Diagnostic_Code is record
      Present : Boolean;
      Domain : Interfaces.C.int;
      Code : Interfaces.C.int;
   end record;

   None : constant Diagnostic_Code :=
     (Present => False, Domain => 0, Code => 0);

   Out_Of_Memory : constant Diagnostic_Code :=
     (Present => True, Domain => 6, Code => 2);
   Resource_Limit : constant Diagnostic_Code :=
     (Present => True, Domain => 1, Code => 114);
   Parser_Internal_Error : constant Diagnostic_Code :=
     (Present => True, Domain => 1, Code => 1);
   Unsupported_Feature : constant Diagnostic_Code :=
     (Present => True, Domain => 1, Code => 115);
   Unsupported_Encoding : constant Diagnostic_Code :=
     (Present => True, Domain => 1, Code => 32);
   Invalid_UTF16_Input : constant Diagnostic_Code :=
     (Present => True, Domain => 8, Code => 81);
   DOM_Invalid_Argument : constant Diagnostic_Code :=
     (Present => True, Domain => 2, Code => 115);
   DOM_Internal_Error : constant Diagnostic_Code :=
     (Present => True, Domain => 2, Code => 1);

   function For_Operation
     (Status : XML3_DOM_Constructors.Construction_Status;
      Validation_Error : Boolean) return Diagnostic_Code
   is
     (case Status is
        when XML3_DOM_Constructors.Created => None,
        when XML3_DOM_Constructors.Invalid_Argument =>
          (if Validation_Error then DOM_Invalid_Argument else None),
        when XML3_DOM_Constructors.No_Memory => Out_Of_Memory,
        when XML3_DOM_Constructors.Limit_Exceeded => Resource_Limit,
        when XML3_DOM_Constructors.Internal_Error => DOM_Internal_Error)
   with Global => null;

   function For_Preparation
     (Status : XML3_Encoding.Buffers.Conversion_Result)
      return Diagnostic_Code
   is
     (case Status is
        when XML3_Encoding.Buffers.Converted => None,
        when XML3_Encoding.Buffers.Invalid_UTF16 => Invalid_UTF16_Input,
        when XML3_Encoding.Buffers.Conversion_Limit_Exceeded =>
          Resource_Limit,
        when XML3_Encoding.Buffers.Conversion_No_Memory => Out_Of_Memory)
   with Global => null;

   --  Report_Diagnostic republishes the parser diagnostic, so no fixed
   --  pair applies to it.
   function For_Report
     (Kind : XML3_Parser.Outcomes.Report_Kind) return Diagnostic_Code
   is
     (case Kind is
        when XML3_Parser.Outcomes.No_Report
           | XML3_Parser.Outcomes.Report_Diagnostic => None,
        when XML3_Parser.Outcomes.Report_No_Memory => Out_Of_Memory,
        when XML3_Parser.Outcomes.Report_Internal => Parser_Internal_Error,
        when XML3_Parser.Outcomes.Report_Unsupported_Feature =>
          Unsupported_Feature,
        when XML3_Parser.Outcomes.Report_Limit_Exceeded => Resource_Limit)
   with Global => null;

   --  Admitted and rejected arguments publish no diagnostic; the argument
   --  rejection only sets the C status.
   function For_Admission
     (Kind : XML3_Parser.Requests.Admission_Kind) return Diagnostic_Code
   is
     (case Kind is
        when XML3_Parser.Requests.Admitted
           | XML3_Parser.Requests.Invalid_Argument => None,
        when XML3_Parser.Requests.Unsupported_Encoding =>
          Unsupported_Encoding,
        when XML3_Parser.Requests.Unsupported_Options =>
          Unsupported_Feature)
   with Global => null;

end XML3_Diagnostic_Codes;
