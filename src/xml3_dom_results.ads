with Interfaces.C;
with XML3_DOM_Constructors;
with XML3_DOM_Store.Queries;
with XML3_Diagnostic_Codes;

package XML3_DOM_Results with SPARK_Mode is
   use type Interfaces.C.int;
   use type XML3_DOM_Constructors.Construction_Status;
   use type XML3_DOM_Store.Queries.Space_Policy;
   use type XML3_Diagnostic_Codes.Adapter_Failure;
   use type XML3_Diagnostic_Codes.Diagnostic_Code;

   subtype Status is XML3_DOM_Constructors.Construction_Status;
   subtype Failure is XML3_Diagnostic_Codes.Adapter_Failure;

   --  The operation status an adapter failure stands for.  Entry points
   --  return the same value for a failure they detect themselves (a guard
   --  or an exception handler) as for the equivalent status reported by the
   --  operation, so each convention below is a function of the status only.
   --  For the DOM causes the diagnostic published for the cause is also the
   --  one the equivalent status publishes.
   function Status_Of (Cause : Failure) return Status is
     (case Cause is
        when XML3_Diagnostic_Codes.Allocation_Failure =>
          XML3_DOM_Constructors.No_Memory,
        when XML3_Diagnostic_Codes.Lock_Failure
           | XML3_Diagnostic_Codes.Unexpected_Exception
           | XML3_Diagnostic_Codes.Parser_Exception =>
          XML3_DOM_Constructors.Internal_Error,
        when XML3_Diagnostic_Codes.Unexpected_Namespace_Exception
           | XML3_Diagnostic_Codes.Invalid_Argument
           | XML3_Diagnostic_Codes.Unsupported_Text
           | XML3_Diagnostic_Codes.Invalid_Character =>
          XML3_DOM_Constructors.Invalid_Argument)
   with Global => null,
     Post => Status_Of'Result /= XML3_DOM_Constructors.Created
       and then (Status_Of'Result = XML3_DOM_Constructors.No_Memory) =
                  (Cause = XML3_Diagnostic_Codes.Allocation_Failure)
       and then (if Cause not in XML3_Diagnostic_Codes.Invalid_Character
                               | XML3_Diagnostic_Codes.Parser_Exception
                 then XML3_Diagnostic_Codes.For_Operation
                        (Status_Of'Result, Validation_Error => True) =
                      XML3_Diagnostic_Codes.For_Failure (Cause));

   --  xmlUnsetProp, xmlUnsetNsProp and xmlRemoveProp: 0 when the attribute
   --  was removed, -1 otherwise.  An operation that succeeds without
   --  removing anything (no such attribute) is a failure for the caller.
   function Removal
     (Outcome : Status; Removed : Boolean := True) return Interfaces.C.int
   is
     (if Outcome = XML3_DOM_Constructors.Created and then Removed then 0
      else -1)
   with Global => null,
     Post => Removal'Result in -1 | 0
       and then (Removal'Result = 0) =
                  (Outcome = XML3_DOM_Constructors.Created and then Removed);

   --  xmlNodeSetContent(Len), xmlNodeAddContent(Len), xmlNodeSetLang and
   --  xmlNodeSetSpacePreserve: 0 on success, -1 when out of memory and 1
   --  for any other failure.  xmlTextConcat (Text_Only) reports every
   --  failure as -1.
   function Update
     (Outcome : Status; Text_Only : Boolean := False) return Interfaces.C.int
   is
     (if Outcome = XML3_DOM_Constructors.Created then 0
      elsif Text_Only or else Outcome = XML3_DOM_Constructors.No_Memory
      then -1
      else 1)
   with Global => null,
     Post => Update'Result in -1 .. 1
       and then (Update'Result = 0) =
                  (Outcome = XML3_DOM_Constructors.Created)
       and then (if Outcome = XML3_DOM_Constructors.No_Memory
                 then Update'Result = -1)
       and then (if Text_Only then Update'Result /= 1);

   --  xmlNodeGetAttrValue and xmlGetNsListSafe: 0 when a value is returned,
   --  1 when there is none or the arguments do not name one, and -1 for
   --  every other failure.
   function Lookup
     (Outcome : Status; Found : Boolean) return Interfaces.C.int
   is
     (case Outcome is
        when XML3_DOM_Constructors.Created => (if Found then 0 else 1),
        when XML3_DOM_Constructors.Invalid_Argument => 1,
        when XML3_DOM_Constructors.No_Memory
           | XML3_DOM_Constructors.Limit_Exceeded
           | XML3_DOM_Constructors.Internal_Error => -1)
   with Global => null,
     Post => Lookup'Result in -1 .. 1
       and then (Lookup'Result = 0) =
                  (Outcome = XML3_DOM_Constructors.Created and then Found)
       and then (if Outcome = XML3_DOM_Constructors.No_Memory
                 then Lookup'Result = -1);

   --  xmlNodeGetSpacePreserve: -1 when no xml:space value is inherited.
   function Space_Code
     (Space : XML3_DOM_Store.Queries.Space_Policy) return Interfaces.C.int
   is
     (case Space is
        when XML3_DOM_Store.Queries.Unspecified => -1,
        when XML3_DOM_Store.Queries.Default_Space => 0,
        when XML3_DOM_Store.Queries.Preserve_Space => 1)
   with Global => null;

   --  xmlNodeIsText and xmlIsBlankNode: a failed test answers false.
   function Truth (Value : Boolean) return Interfaces.C.int is
     (if Value then 1 else 0)
   with Global => null;

end XML3_DOM_Results;
