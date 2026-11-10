with Interfaces.C;
with XML3_Diagnostic_Codes;
with XML3_Text.Buffers;
with XML3_Text.QNames;

package XML3_Text_Results with SPARK_Mode is
   use type Interfaces.C.int;
   use type XML3_Text.Buffers.UTF8_Status;
   use type XML3_Text.Buffers.Search_Status;
   use type XML3_Text.Buffers.Path_Status;
   use type XML3_Text.Buffers.Escape_Status;
   use type XML3_Text.QNames.Comparison_Status;

   package Codes renames XML3_Diagnostic_Codes;
   package Buffers renames XML3_Text.Buffers;
   package QNames renames XML3_Text.QNames;

   --  Diagnostics of the string entry points.  A string that is merely
   --  invalid or absent is an ordinary answer and publishes nothing; only a
   --  string beyond the supported length and a failed allocation are
   --  reported.

   function Unsupported return Codes.Diagnostic_Code is
     (Codes.For_Failure (Codes.Unsupported_Text))
   with Global => null;

   function No_Memory return Codes.Diagnostic_Code is
     (Codes.For_Failure (Codes.Allocation_Failure))
   with Global => null;

   --  A scan that stopped at the length limit (xmlStrcmp, xmlStrlen).
   function For_Limit (Exceeded : Boolean) return Codes.Diagnostic_Code is
     (if Exceeded then Unsupported else Codes.None)
   with Global => null,
     Post => For_Limit'Result.Present = Exceeded;

   --  xmlUTF8Charcmp with a malformed character.
   function For_Malformed (Malformed : Boolean) return Codes.Diagnostic_Code
   is
     (if Malformed then Codes.For_Failure (Codes.Invalid_Character)
      else Codes.None)
   with Global => null,
     Post => For_Malformed'Result.Present = Malformed;

   function For_UTF8 (Status : Buffers.UTF8_Status) return Codes.Diagnostic_Code
   is (For_Limit (Status = Buffers.UTF8_Limit_Exceeded))
   with Global => null;

   function For_Search
     (Status : Buffers.Search_Status) return Codes.Diagnostic_Code
   is (For_Limit (Status = Buffers.Search_Limit_Exceeded))
   with Global => null;

   function For_Path (Status : Buffers.Path_Status) return Codes.Diagnostic_Code
   is (For_Limit (Status = Buffers.Path_Limit_Exceeded))
   with Global => null;

   --  xmlURIEscapeStr and xmlURIUnescapeString: invalid input answers NULL
   --  silently.
   function For_URI_Escape
     (Status : Buffers.Escape_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when Buffers.Escaped | Buffers.Invalid_Text => Codes.None,
        when Buffers.Escape_No_Memory => No_Memory,
        when Buffers.Escape_Limit_Exceeded => Unsupported)
   with Global => null;

   --  xmlEncodeSpecialChars: text that cannot be encoded is reported.
   function For_Special_Escape
     (Status : Buffers.Escape_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when Buffers.Escaped => Codes.None,
        when Buffers.Escape_No_Memory => No_Memory,
        when Buffers.Invalid_Text | Buffers.Escape_Limit_Exceeded =>
          Unsupported)
   with Global => null,
     Post => For_Special_Escape'Result.Present = (Status /= Buffers.Escaped);

   function For_Append
     (Status : Buffers.Append_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when Buffers.Unchanged | Buffers.Appended | Buffers.Invalid_Length =>
          Codes.None,
        when Buffers.Append_No_Memory => No_Memory,
        when Buffers.Append_Limit_Exceeded => Unsupported)
   with Global => null;

   function For_Concatenate
     (Status : Buffers.Concatenate_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when Buffers.Copied | Buffers.No_Input => Codes.None,
        when Buffers.No_Memory => No_Memory,
        when Buffers.Limit_Exceeded => Unsupported)
   with Global => null;

   function For_Slice
     (Status : Buffers.Slice_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when Buffers.Sliced | Buffers.No_Slice => Codes.None,
        when Buffers.No_Memory => No_Memory,
        when Buffers.Slice_Limit_Exceeded => Unsupported)
   with Global => null;

   function For_Comparison
     (Status : QNames.Comparison_Status) return Codes.Diagnostic_Code
   is (For_Limit (Status = QNames.Comparison_Limit_Exceeded))
   with Global => null;

   function For_Build
     (Status : QNames.Build_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when QNames.Built | QNames.Invalid_Argument => Codes.None,
        when QNames.No_Memory => No_Memory,
        when QNames.Limit_Exceeded => Unsupported)
   with Global => null;

   function For_Split
     (Status : QNames.Split_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when QNames.No_Prefix | QNames.Split_Done => Codes.None,
        when QNames.No_Memory => No_Memory,
        when QNames.Split_Limit_Exceeded => Unsupported)
   with Global => null;

   function For_Prefix
     (Status : QNames.Prefix_Status) return Codes.Diagnostic_Code
   is
     (case Status is
        when QNames.Prefix_Absent | QNames.Prefix_Found => Codes.None,
        when QNames.Prefix_Limit_Exceeded => Unsupported)
   with Global => null;

   --  Results.  An entry point whose scan fails answers as it does for an
   --  invalid or absent string.

   --  xmlCheckUTF8: 1 for valid UTF-8, 0 otherwise.
   function Validity (Status : Buffers.UTF8_Status) return Interfaces.C.int is
     (if Status = Buffers.UTF8_Valid then 1 else 0)
   with Global => null;

   --  xmlUTF8Strlen and xmlUTF8Strsize: the measure, or -1.
   function Measure
     (Length : XML3_Text.Byte_Count; Status : Buffers.UTF8_Status)
      return Interfaces.C.int
   is (if Status = Buffers.UTF8_Valid then Interfaces.C.int (Length) else -1)
   with Global => null,
     Post => Measure'Result >= -1
       and then (Measure'Result = -1) = (Status /= Buffers.UTF8_Valid);

   --  xmlStrlen: the length, or -1 beyond the supported length.
   function Measure
     (Length : XML3_Text.Byte_Count; Measured : Boolean)
      return Interfaces.C.int
   is (if Measured then Interfaces.C.int (Length) else -1)
   with Global => null,
     Post => Measure'Result >= -1
       and then (Measure'Result = -1) = not Measured;

   --  xmlUTF8Strloc: the character index of the match, or -1.
   function Location
     (Index : XML3_Text.Byte_Count; Status : Buffers.Search_Status)
      return Interfaces.C.int
   is (if Status = Buffers.Matched then Interfaces.C.int (Index) else -1)
   with Global => null,
     Post => Location'Result >= -1
       and then (Location'Result = -1) = (Status /= Buffers.Matched);

   --  xmlNormalizeURIPath: 0 when normalized, -1 otherwise.
   function Path_Code (Status : Buffers.Path_Status) return Interfaces.C.int is
     (if Status = Buffers.Normalized then 0 else -1)
   with Global => null;

   --  xmlStrQEqual: 1 when equal, 0 otherwise.
   function Equality
     (Status : QNames.Comparison_Status) return Interfaces.C.int
   is (if Status = QNames.Same then 1 else 0)
   with Global => null;

   --  xmlStrEqual from a three-way comparison.
   function Equality (Comparison : Interfaces.C.int) return Interfaces.C.int is
     (if Comparison = 0 then 1 else 0)
   with Global => null;

end XML3_Text_Results;
