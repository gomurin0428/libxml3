with XML3_DOM_Store.Documents;
with XML3_Encoding.Buffers;
with XML3_Parser.Outcomes;
with XML3_Parser.Requests;

package XML3_Parser.Statuses with SPARK_Mode is
   use type XML3_DOM_Store.Documents.Read_Status;
   use type XML3_Encoding.Buffers.Conversion_Result;
   use type XML3_Parser.Outcomes.Report_Kind;
   use type XML3_Parser.Requests.Admission_Kind;

   --  The status a parse entry point publishes through its C status slot.
   --  The literals are declared in the order of the C ABI values 0 .. 6;
   --  the adapter keeps the conversion to those values.
   type Public_Status is
     (OK, Malformed, Unsupported, Limit_Exceeded, Invalid_Argument,
      No_Memory, Internal_Error);

   --  Status of a finished parse, before the diagnostic is published.
   --  An exhausted arena only reaches this point when the node limit stops
   --  the retry loop, which the adapter has always reported as internal.
   function For_Read
     (Status : XML3_DOM_Store.Documents.Read_Status) return Public_Status
   is
     (case Status is
        when XML3_DOM_Store.Documents.Parsed => OK,
        when XML3_DOM_Store.Documents.Malformed => Malformed,
        when XML3_DOM_Store.Documents.Unsupported => Unsupported,
        when XML3_DOM_Store.Documents.Limit_Exceeded => Limit_Exceeded,
        when XML3_DOM_Store.Documents.Arena_Exhausted => Internal_Error,
        when XML3_DOM_Store.Documents.No_Memory => No_Memory,
        when XML3_DOM_Store.Documents.Internal_Error => Internal_Error)
   with Global => null,
     Post =>
       (For_Read'Result = OK) = (Status = XML3_DOM_Store.Documents.Parsed);

   --  Status of a request admission stage.
   function For_Admission
     (Kind : XML3_Parser.Requests.Admission_Kind) return Public_Status
   is
     (case Kind is
        when XML3_Parser.Requests.Admitted => OK,
        when XML3_Parser.Requests.Invalid_Argument => Invalid_Argument,
        when XML3_Parser.Requests.Unsupported_Encoding
           | XML3_Parser.Requests.Unsupported_Options => Unsupported)
   with Global => null,
     Post =>
       (For_Admission'Result = OK) =
         (Kind = XML3_Parser.Requests.Admitted);

   --  Status of the native input preparation.
   function For_Preparation
     (Status : XML3_Encoding.Buffers.Conversion_Result) return Public_Status
   is
     (case Status is
        when XML3_Encoding.Buffers.Converted => OK,
        when XML3_Encoding.Buffers.Invalid_UTF16 => Malformed,
        when XML3_Encoding.Buffers.Conversion_Limit_Exceeded =>
          Limit_Exceeded,
        when XML3_Encoding.Buffers.Conversion_No_Memory => No_Memory)
   with Global => null,
     Post =>
       (For_Preparation'Result = OK) =
         (Status = XML3_Encoding.Buffers.Converted);

   --  Applied once a failure has been published.  When publishing the
   --  diagnostic itself ran out of memory, the thread-local error records
   --  an out-of-memory error instead, and the caller must see No_Memory.
   --  A successful status is never changed here.
   function After_Report
     (Status : Public_Status; OOM_Recorded : Boolean) return Public_Status
   is
     (if Status /= OK and then OOM_Recorded then No_Memory else Status)
   with Global => null,
     Post =>
       (if Status = OK then After_Report'Result = OK)
       and then (if After_Report'Result /= Status
                 then After_Report'Result = No_Memory);

   --  Final decision for a finished parse.  A successful parse that
   --  published a warning diagnostic and found out-of-memory recorded must
   --  not hand out its document: the document is discarded and the caller
   --  sees No_Memory.  Every other outcome keeps the document (there is
   --  none on failure) and applies After_Report.
   type Parse_Settlement is record
      Status : Public_Status;
      Discard_Document : Boolean;
   end record;

   function Settle_Parse
     (Status : Public_Status;
      Report : XML3_Parser.Outcomes.Report_Kind;
      OOM_Recorded : Boolean) return Parse_Settlement
   is
     (if Status = OK
        and then Report = XML3_Parser.Outcomes.Report_Diagnostic
        and then OOM_Recorded
      then (Status => No_Memory, Discard_Document => True)
      else (Status => After_Report (Status, OOM_Recorded),
            Discard_Document => False))
   with Global => null,
     Post =>
       (if Settle_Parse'Result.Discard_Document
        then Status = OK and then Settle_Parse'Result.Status = No_Memory)
       and then (Settle_Parse'Result.Status = OK) =
                  (Status = OK and then not Settle_Parse'Result.Discard_Document)
       and then (if not OOM_Recorded
                 then Settle_Parse'Result = (Status, False));

   --  Status published by an exception handler of a parse entry point.
   function After_Exception (OOM_Recorded : Boolean) return Public_Status
   is
     (if OOM_Recorded then No_Memory else Internal_Error)
   with Global => null,
     Post => After_Exception'Result /= OK;

end XML3_Parser.Statuses;
