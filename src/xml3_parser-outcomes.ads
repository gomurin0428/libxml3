with XML3_DOM_Store.Documents;
with XML3_Parser.Workspaces;

package XML3_Parser.Outcomes with SPARK_Mode is
   use type XML3_DOM_Store.Documents.Read_Status;

   --  Decides whether a parse attempt is finished, needs a larger node
   --  arena, or has reached the node limit.
   type Attempt_Step is (Finished, Grow, Limit_Reached);

   function After_Attempt
     (Status : XML3_DOM_Store.Documents.Read_Status;
      Capacity : XML3_Parser.Workspaces.Capacity) return Attempt_Step
   is
     (if Status /= XML3_DOM_Store.Documents.Arena_Exhausted then Finished
      elsif Capacity < XML3_Parser.Workspaces.Capacity'Last then Grow
      else Limit_Reached)
   with Global => null,
     Post =>
       (if After_Attempt'Result = Grow
        then Capacity < XML3_Parser.Workspaces.Capacity'Last)
       and then (if After_Attempt'Result /= Finished
                 then Status = XML3_DOM_Store.Documents.Arena_Exhausted);

   --  Selects which diagnostic the adapter publishes for a finished parse.
   type Report_Kind is
     (No_Report, Report_Diagnostic, Report_No_Memory, Report_Internal,
      Report_Unsupported_Feature, Report_Limit_Exceeded);

   function Report_For
     (Status : XML3_DOM_Store.Documents.Read_Status;
      Diagnostic_Code : Natural) return Report_Kind
   is
     (case Status is
        when XML3_DOM_Store.Documents.No_Memory => Report_No_Memory,
        when XML3_DOM_Store.Documents.Internal_Error => Report_Internal,
        when XML3_DOM_Store.Documents.Unsupported =>
          (if Diagnostic_Code = 0 then Report_Unsupported_Feature
           else Report_Diagnostic),
        when XML3_DOM_Store.Documents.Parsed =>
          (if Diagnostic_Code = 0 then No_Report else Report_Diagnostic),
        when XML3_DOM_Store.Documents.Limit_Exceeded =>
          (if Diagnostic_Code = 0 then Report_Limit_Exceeded
           else Report_Diagnostic),
        when XML3_DOM_Store.Documents.Malformed =>
          (if Diagnostic_Code = 0 then Report_Internal
           else Report_Diagnostic),
        when XML3_DOM_Store.Documents.Arena_Exhausted => No_Report)
   with Global => null,
     Post =>
       (if Status = XML3_DOM_Store.Documents.Parsed and then Diagnostic_Code = 0
        then Report_For'Result = No_Report);
end XML3_Parser.Outcomes;
