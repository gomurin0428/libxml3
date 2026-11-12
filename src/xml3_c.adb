with GNAT.Threads;
pragma Unreferenced (GNAT.Threads);
with Interfaces.C; use Interfaces.C;
with System.Storage_Elements; use System.Storage_Elements;
with XML3_DOM;
with XML3_DOM_Constructors;
with XML3_DOM_Lock;
with XML3_DOM_Results;
with XML3_DOM_Runtime;
with XML3_DOM_Store;
with XML3_DOM_Store.Documents;
with XML3_DOM_Store.Queries;
with XML3_Diagnostic_Codes;
with XML3_Encoding;
with XML3_Encoding.Buffers;
with XML3_Byte_Buffers;
with XML3_Entry_Guards;
with XML3_File_Paths;
with XML3_IO_Errors;
with XML3_Native_Memory;
with XML3_Error_Records;
with XML3_Errors;
with XML3_Namespaces;
with XML3_Parser;
with XML3_Parser.Attempts;
with XML3_Parser.Contexts;
with XML3_Parser.Options;
with XML3_Parser.Outcomes;
with XML3_Parser.Requests;
with XML3_Parser.Statuses;
with XML3_Parser.Workspaces;
with XML3_Save_Contexts;
with XML3_Serialization;
with XML3_Text;
with XML3_Text.Buffers;
with XML3_Text.QNames;
with XML3_Text_Results;
with XML3_URIs;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body XML3_C is
   use type System.Address;
   use type XML3_Parser.Options.Profile;
   use type XML3_Encoding.Encoding_Kind;
   use type XML3_DOM_Constructors.Construction_Status;
   use type XML3_DOM_Store.Documents.Read_Status;
   use type XML3_DOM_Store.Queries.XML_Property_Kind;
   use type XML3_DOM_Store.Queries.Space_Policy;
   use all type XML3_Diagnostic_Codes.Adapter_Failure;

   package Results renames XML3_DOM_Results;
   package Text_Results renames XML3_Text_Results;
   package Guards renames XML3_Entry_Guards;

   --  xmlFree releases with the allocator set by xmlMemSetup.
   procedure C_Free (Item : System.Address)
     with Import, Convention => C, External_Name => "xml3MemRelease";

   procedure Set_Status (Target : System.Address; Value : int);
   procedure Set_Address
     (Target : System.Address; Value : System.Address);
   procedure Report_Failure
     (Failure : XML3_Diagnostic_Codes.Adapter_Failure;
      File : System.Address := System.Null_Address);
   procedure Report_Code
     (Item : XML3_Diagnostic_Codes.Diagnostic_Code;
      File : System.Address := System.Null_Address);
   procedure Report_Operation_Status
     (Status : XML3_DOM_Store.Operation_Status;
      Class : Results.Operation_Class := Results.Edit);
   procedure Build
     (Input : String; Huge : Boolean; Encoding : XML3_Encoding.Encoding_Info;
      Result : out System.Address;
      Status : out XML3_DOM_Store.Documents.Read_Status;
      Diagnostic : out XML3_Parser.Diagnostic_Info);
   function Status_Code
     (Status : XML3_Parser.Statuses.Public_Status) return int;
   function Refused
     (Group : Guards.Entry_Group; First_Present : Boolean;
      Second_Present : Boolean := True; Distinct : Boolean := True)
      return Boolean;
   function Parse_Buffer
     (Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int;
      Status : out XML3_Parser.Statuses.Public_Status) return System.Address;

   procedure Set_Status (Target : System.Address; Value : int) is
   begin
      if Target = System.Null_Address then
         return;
      end if;
      declare
         Slot : int with Import, Address => Target;
      begin
         Slot := Value;
      end;
   end Set_Status;

   procedure Set_Address
     (Target : System.Address; Value : System.Address)
   is
   begin
      if Target = System.Null_Address then
         return;
      end if;
      declare
         Slot : System.Address with Import, Address => Target;
      begin
         Slot := Value;
      end;
   end Set_Address;

   procedure Report_Failure
     (Failure : XML3_Diagnostic_Codes.Adapter_Failure;
      File : System.Address := System.Null_Address)
   is
   begin
      Report_Code (XML3_Diagnostic_Codes.For_Failure (Failure), File);
   end Report_Failure;

   procedure Report_Code
     (Item : XML3_Diagnostic_Codes.Diagnostic_Code;
      File : System.Address := System.Null_Address)
   is
   begin
      if Item.Present then
         XML3_Errors.Report_Simple (Item.Domain, Item.Code, 3, File);
      end if;
   end Report_Code;

   procedure Report_Operation_Status
     (Status : XML3_DOM_Store.Operation_Status;
      Class : Results.Operation_Class := Results.Edit)
   is
   begin
      Report_Code (Results.Diagnostic_For (Class, Status));
   end Report_Operation_Status;

   --  Applies the argument check SPARK selected for an entry point group:
   --  publishes the diagnostic of a reported refusal and answers whether
   --  the call must return its refusal value at once.
   function Refused
     (Group : Guards.Entry_Group; First_Present : Boolean;
      Second_Present : Boolean := True; Distinct : Boolean := True)
      return Boolean
   is
      use type Guards.Admission;
      Decision : constant Guards.Admission :=
        Guards.Admit (Group, First_Present, Second_Present, Distinct);
   begin
      Report_Code (Guards.Diagnostic_For (Decision));
      return Decision /= Guards.Admitted;
   end Refused;

   --  C ABI encoding of the status SPARK selected; no decision is made here.
   function Status_Code
     (Status : XML3_Parser.Statuses.Public_Status) return int
   is
     (case Status is
        when XML3_Parser.Statuses.OK => Status_OK,
        when XML3_Parser.Statuses.Malformed => Status_Malformed,
        when XML3_Parser.Statuses.Unsupported => Status_Unsupported,
        when XML3_Parser.Statuses.Limit_Exceeded => Status_Limit_Exceeded,
        when XML3_Parser.Statuses.Invalid_Argument =>
          Status_Invalid_Argument,
        when XML3_Parser.Statuses.No_Memory => Status_No_Memory,
        when XML3_Parser.Statuses.Internal_Error => Status_Internal_Error);

   procedure Build_Arena
     (Input : String; Huge : Boolean; Encoding : XML3_Encoding.Encoding_Info;
      Capacity : Positive; Nodes_Buffer, Names_Buffer,
      Scratch_A_Buffer, Scratch_B_Buffer : System.Address;
      Result : out System.Address;
      Status : out XML3_DOM_Store.Documents.Read_Status;
      Diagnostic : out XML3_Parser.Diagnostic_Info)
   is
      Nodes : XML3_Parser.Node_Array (1 .. Capacity)
        with Import, Address => Nodes_Buffer;
      Names : XML3_Namespaces.Name_Array (1 .. Capacity)
        with Import, Address => Names_Buffer;
      Scratch_A : String (1 .. Input'Length)
        with Import, Address => Scratch_A_Buffer;
      Scratch_B : String (1 .. Input'Length)
        with Import, Address => Scratch_B_Buffer;
   begin
      Result := System.Null_Address;
      Status := XML3_DOM_Store.Documents.Internal_Error;
      Diagnostic :=
        (Domain => 1, Code => 0, Level => 0, Byte_Position => 1,
         Int1 => 0, Int2 => 0);
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Read
           (Input, Huge, Encoding, Nodes, Names, Scratch_A, Scratch_B,
            Result, Status, Diagnostic);
      end;
   exception
      when Storage_Error =>
         Result := System.Null_Address;
         Status := XML3_DOM_Store.Documents.No_Memory;
      when XML3_DOM_Lock.Lock_Error =>
         Result := System.Null_Address;
         Status := XML3_DOM_Store.Documents.Internal_Error;
      when others =>
         Result := System.Null_Address;
         Status := XML3_DOM_Store.Documents.Internal_Error;
   end Build_Arena;

   procedure Build
     (Input : String; Huge : Boolean; Encoding : XML3_Encoding.Encoding_Info;
      Result : out System.Address;
      Status : out XML3_DOM_Store.Documents.Read_Status;
      Diagnostic : out XML3_Parser.Diagnostic_Info)
   is
      package Workspaces renames XML3_Parser.Workspaces;

      --  Downward closure over this call's input; the attempt itself keeps
      --  the address overlays, the DOM lock and the exception mapping.
      procedure Attempt
        (Capacity : Workspaces.Capacity; Workspace : Workspaces.Buffers;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Documents.Read_Status;
         Diagnostic : out XML3_Parser.Diagnostic_Info)
      is
      begin
         Build_Arena
           (Input, Huge, Encoding, Capacity, Workspace.Nodes, Workspace.Names,
            Workspace.Scratch_A, Workspace.Scratch_B, Result, Status,
            Diagnostic);
      end Attempt;
    begin
      XML3_Parser.Attempts.Run
        (Attempt'Unrestricted_Access, Input'Length, Result, Status,
         Diagnostic);
    exception
      when Storage_Error =>
         Result := System.Null_Address;
         Status := XML3_DOM_Store.Documents.No_Memory;
      when others =>
         Result := System.Null_Address;
         Status := XML3_DOM_Store.Documents.Internal_Error;
   end Build;

   function Parse_Buffer
     (Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int;
      Status : out XML3_Parser.Statuses.Public_Status) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Huge : Boolean := False;
      Diagnostic : XML3_Parser.Diagnostic_Info;
      Prepared : XML3_Encoding.Buffers.Input_View;
      package Requests renames XML3_Parser.Requests;
      package Statuses renames XML3_Parser.Statuses;
      use type XML3_Parser.Requests.Admission_Kind;

      procedure Parse_And_Report
        (Input : String; Encoding_Info : XML3_Encoding.Encoding_Info)
      is
         package Outcomes renames XML3_Parser.Outcomes;
         use type XML3_Parser.Outcomes.Report_Kind;
         Outcome : XML3_DOM_Store.Documents.Read_Status;
         Report : XML3_Parser.Outcomes.Report_Kind;
         Settlement : Statuses.Parse_Settlement;
      begin
         Build (Input, Huge, Encoding_Info, Result, Outcome, Diagnostic);
         Report := Outcomes.Report_For (Outcome, Diagnostic.Code);
         if Report = Outcomes.Report_Diagnostic then
            XML3_Errors.Report
              (Diagnostic.Domain, Diagnostic.Code, Diagnostic.Level,
               Diagnostic.Byte_Position, Diagnostic.Int1, Input, URL);
         else
            Report_Code (XML3_Diagnostic_Codes.For_Report (Report), URL);
         end if;
         Settlement :=
           Statuses.Settle_Parse
             (Statuses.For_Read (Outcome), Report,
              XML3_Errors.Last_Error_Is_OOM);
         if Settlement.Discard_Document
           and then Result /= System.Null_Address
         then
            Free_Doc (Result);
            Result := System.Null_Address;
         end if;
         Status := Settlement.Status;
      end Parse_And_Report;

      --  Publishes a failed preparation in the shape SPARK selected, then
      --  applies the out-of-memory fixup.
      procedure Report_Preparation_Failure
        (Prepare_Status : XML3_Encoding.Buffers.Conversion_Result;
         Shape : Statuses.Preparation_Report)
      is
         Item : constant XML3_Diagnostic_Codes.Diagnostic_Code :=
           XML3_Diagnostic_Codes.For_Preparation (Prepare_Status);
      begin
         case Shape is
            when Statuses.At_Input_Start =>
               XML3_Errors.Report
                 (Natural (Item.Domain), Natural (Item.Code), 3, 1, 0, "",
                  URL);
            when Statuses.Without_Position =>
               Report_Code (Item, URL);
            when Statuses.No_Report =>
               null;
         end case;
         Status :=
           Statuses.After_Report
             (Statuses.For_Preparation (Prepare_Status),
              XML3_Errors.Last_Error_Is_OOM);
      end Report_Preparation_Failure;

      procedure Reject (Kind : Requests.Admission_Kind) is
      begin
         Report_Code (XML3_Diagnostic_Codes.For_Admission (Kind), URL);
         Status :=
           Statuses.After_Report
             (Statuses.For_Admission (Kind), XML3_Errors.Last_Error_Is_OOM);
      end Reject;
   begin
      Status := Statuses.Internal_Error;
      declare
         Arguments : constant Requests.Admission_Kind :=
           Requests.Check_Arguments (Buffer /= System.Null_Address, Size);
      begin
         if Arguments /= Requests.Admitted then
            Status := Statuses.For_Admission (Arguments);
            return System.Null_Address;
         end if;
      end;
      declare
         Requested : constant XML3_Encoding.Encoding_Kind :=
           XML3_Encoding.Buffers.Classify_Bytes (Encoding);
         Encoding_Admission : constant Requests.Admission_Kind :=
           Requests.After_Encoding (Requested);
      begin
         if Encoding_Admission /= Requests.Admitted then
            Reject (Encoding_Admission);
            return System.Null_Address;
         end if;
         declare
            Selected : constant XML3_Parser.Options.Profile :=
              XML3_Parser.Options.Classify (Options);
            Option_Admission : constant Requests.Admission_Kind :=
              Requests.After_Options (Selected);
         begin
            if Option_Admission /= Requests.Admitted then
               Reject (Option_Admission);
               return System.Null_Address;
            end if;
            Huge := Requests.Huge_Requested (Selected);
         end;
         declare
            Prepare_Status : XML3_Encoding.Buffers.Conversion_Result;
         begin
            XML3_Encoding.Buffers.Prepare_Input
              (Buffer, Natural (Size), Requested, Prepared, Prepare_Status);
            declare
               Shape : constant Statuses.Preparation_Report :=
                 Statuses.Report_For_Preparation (Prepare_Status);
               use type Statuses.Preparation_Report;
            begin
               if Shape = Statuses.No_Report then
                  declare
                     Input : String (1 .. Prepared.Length)
                       with Import, Address => Prepared.Data;
                  begin
                     Parse_And_Report (Input, Prepared.Info);
                  end;
               else
                  Report_Preparation_Failure (Prepare_Status, Shape);
               end if;
            end;
         end;
      end;
      XML3_Encoding.Buffers.Release_Input (Prepared);
      return Result;
   exception
      when Storage_Error =>
         if Result /= System.Null_Address then
            Free_Doc (Result);
         end if;
         XML3_Encoding.Buffers.Release_Input (Prepared);
         Status := Statuses.No_Memory;
         Report_Failure (Allocation_Failure, URL);
         return System.Null_Address;
      when others =>
         if Result /= System.Null_Address then
            Free_Doc (Result);
         end if;
         XML3_Encoding.Buffers.Release_Input (Prepared);
         Report_Failure (Parser_Exception, URL);
         Status :=
           XML3_Parser.Statuses.After_Exception
             (XML3_Errors.Last_Error_Is_OOM);
         return System.Null_Address;
   end Parse_Buffer;

   procedure Init_Parser is
   begin
      null;
   end Init_Parser;

   procedure Cleanup_Parser is
   begin
      null;
   end Cleanup_Parser;

   function Read_Memory_Status
     (Buffer : System.Address; Size : Interfaces.C.int;
      Status : System.Address) return System.Address
   is
      Code : XML3_Parser.Statuses.Public_Status :=
        XML3_Parser.Statuses.Internal_Error;
      Result : System.Address;
   begin
      Result := Parse_Buffer
        (Buffer, Size, System.Null_Address, System.Null_Address, 0, Code);
      Set_Status (Status, Status_Code (Code));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         Set_Status (Status, Status_Code (XML3_Parser.Statuses.No_Memory));
         return System.Null_Address;
      when others =>
         Report_Failure (Parser_Exception);
         Set_Status
           (Status,
            Status_Code
              (XML3_Parser.Statuses.After_Exception
                 (XML3_Errors.Last_Error_Is_OOM)));
         return System.Null_Address;
   end Read_Memory_Status;

   function Read_Memory
     (Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
   is
      Code : XML3_Parser.Statuses.Public_Status :=
        XML3_Parser.Statuses.Internal_Error;
   begin
      return Parse_Buffer (Buffer, Size, URL, Encoding, Options, Code);
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure, URL);
         return System.Null_Address;
      when others =>
         Report_Failure (Parser_Exception, URL);
         return System.Null_Address;
   end Read_Memory;

   function Parse_Memory
     (Buffer : System.Address; Size : Interfaces.C.int) return System.Address
   is
      Code : XML3_Parser.Statuses.Public_Status :=
        XML3_Parser.Statuses.Internal_Error;
   begin
      return Parse_Buffer
        (Buffer, Size, System.Null_Address, System.Null_Address, 0, Code);
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Parser_Exception);
         return System.Null_Address;
   end Parse_Memory;

   function Read_Doc
     (Cur : System.Address; URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
   is
      Code : XML3_Parser.Statuses.Public_Status :=
        XML3_Parser.Statuses.Internal_Error;
      Length : XML3_Text.Byte_Count;
      Found : Boolean;
   begin
      if Refused (Guards.Document_Read, Cur /= System.Null_Address) then
         return System.Null_Address;
      end if;
      XML3_Text.Buffers.Measure (Cur, Length, Found);
      if not Found then
         return System.Null_Address;
      end if;
      return Parse_Buffer
        (Cur, int (Length), URL, Encoding, Options, Code);
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure, URL);
         return System.Null_Address;
      when others =>
         Report_Failure (Parser_Exception, URL);
         return System.Null_Address;
   end Read_Doc;

   ------------------------------------------------------------------
   --  File input.  The path and the diagnostics are decided in SPARK
   --  (XML3_File_Paths, XML3_IO_Errors); the system calls are in the C
   --  helper, the parse is the memory parse with the file name as URL.
   ------------------------------------------------------------------

   function File_Read_Path
     (Path : System.Address; Standard_Input : Interfaces.C.int;
      Limit : Interfaces.C.size_t;
      Data : access System.Address; Length : access Interfaces.C.size_t;
      Read_Stage : access Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3FileReadPath";

   --  Publishes the I/O failure of an input, as xmlCtxtErrIO does: a
   --  failure to open names the file in the message and in str1; a
   --  failure to read is reported at line 1, column 1 of the file.
   procedure Report_Input_Failure
     (Name : String; Name_Address : System.Address;
      Code : Interfaces.C.int; While_Reading : Boolean)
   is
      Text : constant String :=
        (if While_Reading then XML3_IO_Errors.Text (Code)
         else XML3_IO_Errors.Open_Message (Name, Code))
        & Character'Val (10);
      Message : System.Address;
   begin
      --  The record copies the message; this NUL-terminated buffer is
      --  released afterwards.
      XML3_Native_Memory.Allocate (Text'Length + 1, Message);
      if Message = System.Null_Address then
         Report_Failure (Allocation_Failure);
         return;
      end if;
      XML3_Native_Memory.Write_String (Message, 0, Text);
      XML3_Native_Memory.Write_Byte (Message, Text'Length, Character'Val (0));
      if While_Reading then
         XML3_Errors.Set_Error
           (XML3_IO_Errors.IO_Domain, Code, XML3_IO_Errors.Level_For (Code),
            1, 0, 1, Message, Name_Address,
            System.Null_Address, System.Null_Address, System.Null_Address);
      else
         XML3_Errors.Set_Error
           (XML3_IO_Errors.IO_Domain, Code, XML3_IO_Errors.Level_For (Code),
            0, 0, 0, Message, System.Null_Address,
            Name_Address, System.Null_Address, System.Null_Address);
      end if;
      XML3_Native_Memory.Free (Message);
   end Report_Input_Failure;

   function Read_File_Input
     (Name, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
   is
      Name_Length, Path_Length : XML3_Text.Byte_Count;
      Found : Boolean;
      Plan : XML3_File_Paths.Path_Plan;
      Path : System.Address := System.Null_Address;
      Unescape_Status : XML3_Text.Buffers.Escape_Status;
      Data : aliased System.Address := System.Null_Address;
      Length : aliased Interfaces.C.size_t := 0;
      Stage : aliased Interfaces.C.int := 0;
      Code : Interfaces.C.int;
      Standard_Input : Boolean;
      Status : XML3_Parser.Statuses.Public_Status;
      Result : System.Address;
      use type XML3_Text.Buffers.Escape_Status;
   begin
      if Refused (Guards.File_Read, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      XML3_Text.Buffers.Measure (Name, Name_Length, Found);
      if not Found then
         Report_Failure (Unsupported_Text);
         return System.Null_Address;
      end if;
      --  xmlReadFile keeps "-" for standard input.
      Standard_Input :=
        XML3_File_Paths.Is_Standard (Name, Natural (Name_Length));
      if not Standard_Input then
         XML3_File_Paths.Plan_Input (Name, Natural (Name_Length), Plan);
         if Plan.Unescape then
            XML3_Text.Buffers.Unescape_URI
              (XML3_Native_Memory.Offset
                 (Name, XML3_Native_Memory.Byte_Count (Plan.Skip)),
               Integer (Name_Length) - Plan.Skip, System.Null_Address,
               Path, Unescape_Status);
            if Unescape_Status /= XML3_Text.Buffers.Escaped then
               Report_Failure (Allocation_Failure);
               return System.Null_Address;
            end if;
            XML3_Text.Buffers.Measure (Path, Path_Length, Found);
         end if;
      end if;
      Code := File_Read_Path
        ((if Path /= System.Null_Address then Path else Name),
         (if Standard_Input then 1 else 0),
         Interfaces.C.size_t (XML3_Text.Max_Bytes),
         Data'Access, Length'Access, Stage'Access);
      if Path /= System.Null_Address then
         XML3_Native_Memory.Free (Path);
      end if;
      if Code = -1 then
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      elsif Code = -2 then
         --  Larger than the parser accepts: stopped before reading on.
         Report_Code (XML3_Diagnostic_Codes.Resource_Limit, Name);
         return System.Null_Address;
      elsif Code /= 0 then
         declare
            Text : String (1 .. Natural (Name_Length))
              with Import, Address => Name;
         begin
            Report_Input_Failure (Text, Name, Code, Stage /= 0);
         end;
         return System.Null_Address;
      end if;
      if Length > Interfaces.C.size_t (Interfaces.C.int'Last) then
         XML3_Native_Memory.Free (Data);
         Report_Code (XML3_Diagnostic_Codes.Resource_Limit, Name);
         return System.Null_Address;
      end if;
      Result := Parse_Buffer
        (Data, Interfaces.C.int (Length), Name, Encoding, Options, Status);
      XML3_Native_Memory.Free (Data);
      return Result;
   exception
      when Storage_Error =>
         if Data /= System.Null_Address then
            XML3_Native_Memory.Free (Data);
         end if;
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         if Data /= System.Null_Address then
            XML3_Native_Memory.Free (Data);
         end if;
         Report_Failure (Parser_Exception);
         return System.Null_Address;
   end Read_File_Input;

   function Read_File
     (Name, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address is
     (Read_File_Input (Name, Encoding, Options));

   function Parse_File (Name : System.Address) return System.Address is
     (Read_File_Input (Name, System.Null_Address, 0));

   ------------------------------------------------------------------
   --  Input from a file descriptor or from the caller's callbacks
   --  (xmlReadFd, xmlReadIO and their context forms).  The C helper reads
   --  the whole input as libxml2 requests it, then it is parsed as memory
   --  with the URL.  A read failure is reported before the parse, at
   --  line 1, as xmlCtxtErrIO does when the parser cannot grow its input;
   --  after a warning (XML_IO_UNKNOWN, XML_IO_ENOENT) the bytes read are
   --  parsed, any other failure stops the read without a document.
   ------------------------------------------------------------------

   function Fd_Read_All
     (Fd : Interfaces.C.int; Limit : Interfaces.C.size_t;
      Data : access System.Address; Length : access Interfaces.C.size_t;
      Failure : access Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3FdReadAll";

   function IO_Read_All
     (Read, IO_Context : System.Address; Limit : Interfaces.C.size_t;
      Data : access System.Address; Length : access Interfaces.C.size_t;
      Failure : access Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3IOReadAll";

   procedure IO_Close (Close, IO_Context : System.Address)
     with Import, Convention => C, External_Name => "xml3IOClose";

   --  Code, Data, Length and Failure are what the C helper answered.
   function Parse_Read_Input
     (Code : Interfaces.C.int; Data : System.Address;
      Length : Interfaces.C.size_t; Failure : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
   is
      Status : XML3_Parser.Statuses.Public_Status;
      Result : System.Address;
   begin
      if Code = -1 then
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      elsif Code = -2 then
         Report_Code (XML3_Diagnostic_Codes.Resource_Limit, URL);
         return System.Null_Address;
      end if;
      if Failure /= 0 then
         Report_Input_Failure ("", URL, Failure, While_Reading => True);
         if XML3_IO_Errors.Level_For (Failure) /= XML3_IO_Errors.Warning_Level
         then
            XML3_Native_Memory.Free (Data);
            return System.Null_Address;
         end if;
      end if;
      if Length > Interfaces.C.size_t (Interfaces.C.int'Last) then
         XML3_Native_Memory.Free (Data);
         Report_Code (XML3_Diagnostic_Codes.Resource_Limit, URL);
         return System.Null_Address;
      end if;
      Result := Parse_Buffer
        (Data, Interfaces.C.int (Length), URL, Encoding, Options, Status);
      XML3_Native_Memory.Free (Data);
      return Result;
   exception
      when Storage_Error =>
         XML3_Native_Memory.Free (Data);
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         XML3_Native_Memory.Free (Data);
         Report_Failure (Parser_Exception);
         return System.Null_Address;
   end Parse_Read_Input;

   function Read_Fd_Input
     (Fd : Interfaces.C.int; URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
   is
      Data : aliased System.Address := System.Null_Address;
      Length : aliased Interfaces.C.size_t := 0;
      Failure : aliased Interfaces.C.int := 0;
      Code : Interfaces.C.int;
   begin
      --  libxml2 makes no input for a negative descriptor, silently.
      if Fd < 0 then
         return System.Null_Address;
      end if;
      Code := Fd_Read_All
        (Fd, Interfaces.C.size_t (XML3_Text.Max_Bytes), Data'Access,
         Length'Access, Failure'Access);
      return Parse_Read_Input
        (Code, Data, Length, Failure, URL, Encoding, Options);
   end Read_Fd_Input;

   function Read_IO_Input
     (Read, Close, IO_Context, URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
   is
      Data : aliased System.Address := System.Null_Address;
      Length : aliased Interfaces.C.size_t := 0;
      Failure : aliased Interfaces.C.int := 0;
      Code : Interfaces.C.int;
      Result : System.Address;
   begin
      --  Without a read callback there is no input, and the close
      --  callback is not called.
      if Read = System.Null_Address then
         return System.Null_Address;
      end if;
      Code := IO_Read_All
        (Read, IO_Context, Interfaces.C.size_t (XML3_Text.Max_Bytes),
         Data'Access, Length'Access, Failure'Access);
      Result := Parse_Read_Input
        (Code, Data, Length, Failure, URL, Encoding, Options);
      --  The input is freed, and closed, when the parse has finished.
      IO_Close (Close, IO_Context);
      return Result;
   end Read_IO_Input;

   function Read_Fd
     (Fd : Interfaces.C.int; URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address is
     (Read_Fd_Input (Fd, URL, Encoding, Options));

   function Read_IO
     (Read, Close, IO_Context, URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address is
     (Read_IO_Input (Read, Close, IO_Context, URL, Encoding, Options));

   ------------------------------------------------------------------
   --  Parser contexts: the reduced xmlParserCtxt of parser.h.  What a
   --  context stores is decided in SPARK (XML3_Parser.Contexts); a read
   --  is the corresponding plain read with the context's options, and the
   --  context takes over what the thread's error marks say it raised.
   ------------------------------------------------------------------

   package Contexts renames XML3_Parser.Contexts;


   type Parser_Context is record
      Private_Data : System.Address;
      My_Doc : System.Address;
      Well_Formed : int;
      Err_No : int;
      Options : int;
      Last_Error : aliased XML3_Error_Records.Error_Record;
      --  Not in the public struct: the context's error handler, and its
      --  nsWellFormed and disableSAX.
      Handler : XML3_Errors.Structured_Handler;
      Handler_Data : System.Address;
      Flags : aliased Contexts.Parse_Flags;
   end record with Convention => C;

   function New_Parser_Ctxt return System.Address is
      Result : System.Address;
   begin
      XML3_Native_Memory.Allocate
        (XML3_Native_Memory.Byte_Count
           (Parser_Context'Max_Size_In_Storage_Elements),
         Result);
      if Result = System.Null_Address then
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      end if;
      declare
         Context : Parser_Context with Import, Address => Result;
      begin
         Context :=
           (Private_Data => System.Null_Address,
            My_Doc => System.Null_Address,
            Well_Formed => Contexts.Clean.Well_Formed,
            Err_No => Contexts.Clean.Err_No,
            Options => Contexts.Initial_Options,
            Last_Error => XML3_Error_Records.Empty_Record,
            Handler => null,
            Handler_Data => System.Null_Address,
            Flags => Contexts.Running);
      end;
      return Result;
   end New_Parser_Ctxt;

   procedure Free_Parser_Ctxt (Ctxt : System.Address) is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         --  As in libxml2, a document left in myDoc is not released.
         XML3_Errors.Reset_Error (Context.Last_Error'Address);
      end;
      XML3_Native_Memory.Free (Ctxt);
   end Free_Parser_Ctxt;

   procedure Ctxt_Reset (Ctxt : System.Address) is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         if Context.My_Doc /= System.Null_Address then
            Free_Doc (Context.My_Doc);
            Context.My_Doc := System.Null_Address;
         end if;
         Context.Well_Formed := Contexts.Clean.Well_Formed;
         Context.Err_No := Contexts.Clean.Err_No;
         Context.Flags := Contexts.Running;
         XML3_Errors.Reset_Error (Context.Last_Error'Address);
      end;
   end Ctxt_Reset;

   function Store_Options
     (Ctxt : System.Address; Options : int; Keep : Boolean) return int is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return Contexts.Missing_Context;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         Context.Options := Contexts.Stored (Context.Options, Options, Keep);
      end;
      return Contexts.Unknown (Options);
   end Store_Options;

   function Ctxt_Use_Options (Ctxt : System.Address; Options : int)
     return int is (Store_Options (Ctxt, Options, Keep => True));

   function Ctxt_Set_Options (Ctxt : System.Address; Options : int)
     return int is (Store_Options (Ctxt, Options, Keep => False));

   function Ctxt_Get_Options (Ctxt : System.Address) return int is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return Contexts.Missing_Context;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         return Context.Options;
      end;
   end Ctxt_Get_Options;

   --  xmlCtxtReset and xmlCtxtUseOptions, which every read starts with;
   --  answers the options the read uses.
   function Prepare_Read (Ctxt : System.Address; Options : int) return int
   is
      Unknown : int;
   begin
      Ctxt_Reset (Ctxt);
      Unknown := Ctxt_Use_Options (Ctxt, Options);
      pragma Unreferenced (Unknown);
      return Ctxt_Get_Options (Ctxt);
   end Prepare_Read;

   --  Starts a read through Ctxt: xmlCtxtReset and xmlCtxtUseOptions, then
   --  the errors published until Finish_Read are recorded for the context
   --  and go to its handler.  Effective is the options the read uses.
   procedure Start_Read
     (Ctxt : System.Address; Options : int; Effective : out int;
      Previous : out XML3_Errors.Saved_Read)
   is
   begin
      Effective := Prepare_Read (Ctxt, Options);
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         XML3_Errors.Begin_Context_Read
           ((Context => Ctxt, Handler => Context.Handler,
             Data => Context.Handler_Data, Options => Effective,
             Target => Context.Last_Error'Address,
             Well_Formed => Context.Well_Formed'Address,
             Err_No => Context.Err_No'Address,
             Flags => Context.Flags'Address),
            Previous);
      end;
   end Start_Read;

   --  Ends the read: the context's wellFormed, errNo and lastError were
   --  updated as each error was published (XML3_Errors.Note_Context).
   --  The document is kept only when the context is still well-formed, as
   --  xmlCtxtParseDocument decides: xmlStopParser, called by a handler
   --  during the read, can clear wellFormed after the parser built it.
   procedure Finish_Read
     (Ctxt : System.Address; Previous : XML3_Errors.Saved_Read;
      Result : in out System.Address)
   is
      Outcome : XML3_Errors.Read_Outcome;
      Context : Parser_Context with Import, Address => Ctxt;
   begin
      XML3_Errors.End_Context_Read (Previous, Outcome);
      if Result /= System.Null_Address and then Context.Well_Formed = 0 then
         Free_Doc (Result);
         Result := System.Null_Address;
      end if;
   end Finish_Read;

   function Ctxt_Read_Memory
     (Ctxt, Buffer : System.Address; Size : int;
      URL, Encoding : System.Address; Options : int) return System.Address
   is
      Code : XML3_Parser.Statuses.Public_Status;
      Result : System.Address;
      Effective : int;
      Previous : XML3_Errors.Saved_Read;
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address)
        or else Size < 0
      then
         return System.Null_Address;
      end if;
      Start_Read (Ctxt, Options, Effective, Previous);
      begin
         Result := Parse_Buffer (Buffer, Size, URL, Encoding, Effective, Code);
      exception
         when Storage_Error =>
            Report_Failure (Allocation_Failure, URL);
            Result := System.Null_Address;
         when others =>
            Report_Failure (Parser_Exception, URL);
            Result := System.Null_Address;
      end;
      Finish_Read (Ctxt, Previous, Result);
      return Result;
   end Ctxt_Read_Memory;

   function Ctxt_Read_Doc
     (Ctxt, Cur, URL, Encoding : System.Address; Options : int)
      return System.Address
   is
      Result : System.Address;
      Effective : int;
      Previous : XML3_Errors.Saved_Read;
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Start_Read (Ctxt, Options, Effective, Previous);
      Result := Read_Doc (Cur, URL, Encoding, Effective);
      Finish_Read (Ctxt, Previous, Result);
      return Result;
   end Ctxt_Read_Doc;

   function Ctxt_Read_File
     (Ctxt, Name, Encoding : System.Address; Options : int)
      return System.Address
   is
      Result : System.Address;
      Effective : int;
      Previous : XML3_Errors.Saved_Read;
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Start_Read (Ctxt, Options, Effective, Previous);
      Result := Read_File_Input (Name, Encoding, Effective);
      Finish_Read (Ctxt, Previous, Result);
      return Result;
   end Ctxt_Read_File;

   function Ctxt_Read_Fd
     (Ctxt : System.Address; Fd : int; URL, Encoding : System.Address;
      Options : int) return System.Address
   is
      Result : System.Address;
      Effective : int;
      Previous : XML3_Errors.Saved_Read;
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Start_Read (Ctxt, Options, Effective, Previous);
      Result := Read_Fd_Input (Fd, URL, Encoding, Effective);
      Finish_Read (Ctxt, Previous, Result);
      return Result;
   end Ctxt_Read_Fd;

   function Ctxt_Read_IO
     (Ctxt, Read, Close, IO_Context, URL, Encoding : System.Address;
      Options : int) return System.Address
   is
      Result : System.Address;
      Effective : int;
      Previous : XML3_Errors.Saved_Read;
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Start_Read (Ctxt, Options, Effective, Previous);
      Result := Read_IO_Input
        (Read, Close, IO_Context, URL, Encoding, Effective);
      Finish_Read (Ctxt, Previous, Result);
      return Result;
   end Ctxt_Read_IO;

   procedure Ctxt_Set_Error_Handler
     (Ctxt : System.Address; Handler : XML3_Errors.Structured_Handler;
      Data : System.Address)
   is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         Context.Handler := Handler;
         Context.Handler_Data := Data;
      end;
   end Ctxt_Set_Error_Handler;

   function Ctxt_Get_Last_Error (Ctxt : System.Address) return System.Address
   is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         if Context.Last_Error.Code = 0 then
            return System.Null_Address;
         end if;
         return Context.Last_Error'Address;
      end;
   end Ctxt_Get_Last_Error;

   --  The accessors of libxml2 2.15.4 over the reduced context.  A NULL
   --  context answers NULL or 0, and xmlCtxtGetStatus answers what a
   --  catastrophic error gives, as libxml2 does.

   function Ctxt_Get_Private (Ctxt : System.Address) return System.Address
   is
   begin
      if Ctxt = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         return Context.Private_Data;
      end;
   end Ctxt_Get_Private;

   procedure Ctxt_Set_Private (Ctxt, Data : System.Address) is
   begin
      if Ctxt = System.Null_Address then
         return;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         Context.Private_Data := Data;
      end;
   end Ctxt_Set_Private;

   --  The SAX user data, which is the context itself: the context has no
   --  SAX handler to pass other data to.
   function Ctxt_Get_User_Data (Ctxt : System.Address) return System.Address
   is (Ctxt);

   --  myDoc when the context is well-formed, otherwise NULL after freeing
   --  it; myDoc is cleared either way.
   function Ctxt_Get_Document (Ctxt : System.Address) return System.Address
   is
      Doc : System.Address;
   begin
      if Ctxt = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         Doc := Context.My_Doc;
         Context.My_Doc := System.Null_Address;
         if Context.Well_Formed = 0 and then Doc /= System.Null_Address then
            Free_Doc (Doc);
            Doc := System.Null_Address;
         end if;
         return Doc;
      end;
   end Ctxt_Get_Document;

   --  The node being parsed, which outside a read is none: myDoc.
   function Ctxt_Get_Node (Ctxt : System.Address) return System.Address is
   begin
      if Ctxt = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         return Context.My_Doc;
      end;
   end Ctxt_Get_Node;

   function Ctxt_Is_Html (Ctxt : System.Address) return int is
     (0);

   function Ctxt_Is_In_Subset (Ctxt : System.Address) return int is
     (0);

   function Ctxt_Is_Stopped (Ctxt : System.Address) return int is
   begin
      if Ctxt = System.Null_Address then
         return 0;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         return (if Context.Flags.Disable_SAX /= 0 then 1 else 0);
      end;
   end Ctxt_Is_Stopped;

   function Ctxt_Get_Status (Ctxt : System.Address) return int is
   begin
      if Ctxt = System.Null_Address then
         return Contexts.Status
           (Contexts.Clean.Well_Formed, Contexts.Running,
            XML3_Error_Records.Fatal_Level,
            XML3_Error_Records.Out_Of_Memory_Code, False);
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         return Contexts.Status
           (Context.Well_Formed, Context.Flags, Context.Last_Error.Level,
            Context.Last_Error.Code, Contexts.Validates (Context.Options));
      end;
   end Ctxt_Get_Status;

   procedure Stop_Parser (Ctxt : System.Address) is
   begin
      if Ctxt = System.Null_Address then
         return;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
         State : constant Contexts.Context_State :=
           Contexts.After_Stop
             ((Well_Formed => Context.Well_Formed,
               Err_No => Context.Err_No));
      begin
         Context.Flags.Disable_SAX := 2;
         if Context.Err_No = 0 then
            --  libxml2 sets only the code of lastError.
            Context.Last_Error.Code := State.Err_No;
         end if;
         Context.Well_Formed := State.Well_Formed;
         Context.Err_No := State.Err_No;
      end;
   end Stop_Parser;

   procedure Ctxt_Reset_Last_Error (Ctxt : System.Address) is
   begin
      if Refused (Guards.Context_Use, Ctxt /= System.Null_Address) then
         return;
      end if;
      declare
         Context : Parser_Context with Import, Address => Ctxt;
      begin
         Context.Err_No := Contexts.Clean.Err_No;
         XML3_Errors.Reset_Error (Context.Last_Error'Address);
      end;
   end Ctxt_Reset_Last_Error;

   function Parse_Doc (Cur : System.Address) return System.Address is
   begin
      return Read_Doc (Cur, System.Null_Address, System.Null_Address, 0);
   end Parse_Doc;

   function Test_Node
     (Node : System.Address; Mode : XML3_DOM_Store.Queries.Node_Test_Kind)
     return Interfaces.C.int
   is
      Result : Boolean := False;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Test_Node (Node, Mode, Result, Status);
      end;
      Report_Operation_Status (Status, Results.Node_Test);
      return Results.Truth (Result);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Truth (False);
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Truth (False);
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Truth (False);
   end Test_Node;

   function Node_Is_Text (Node : System.Address) return Interfaces.C.int is
   begin
      return Test_Node (Node, XML3_DOM_Store.Queries.Text_Test);
   end Node_Is_Text;

   function Is_Blank_Node (Node : System.Address) return Interfaces.C.int is
   begin
      return Test_Node (Node, XML3_DOM_Store.Queries.Blank_Test);
   end Is_Blank_Node;

   function Select_Element_Node
     (Facade : System.Address; Mode : XML3_DOM_Store.Queries.Element_Query_Kind;
      Class : Results.Operation_Class := Results.Element_Navigation)
      return System.Address
   is
      Result : System.Address := System.Null_Address;
      Count : Natural := 0;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Element_Query, Facade /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Select_Element
           (Facade, Mode, Result, Count, Status);
      end;
      Report_Operation_Status (Status, Class);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Select_Element_Node;

   function Doc_Get_Root_Element (Doc : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Doc, XML3_DOM_Store.Queries.Document_Root, Results.Document_Root);
   end Doc_Get_Root_Element;

   function New_Doc (Version : System.Address) return System.Address is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.New_Document (Version, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end New_Doc;

   procedure Doc_Dump_Memory
     (Document, Memory, Size : System.Address)
   is
   begin
      Doc_Dump_Memory_Enc (Document, Memory, Size, System.Null_Address);
   end Doc_Dump_Memory;

   procedure Doc_Dump_Memory_Enc
     (Document, Memory, Size, Encoding : System.Address)
   is
   begin
      Doc_Dump_Format_Memory_Enc (Document, Memory, Size, Encoding, 0);
   end Doc_Dump_Memory_Enc;

   procedure Doc_Dump_Format_Memory
     (Document, Memory, Size : System.Address; Format : int)
   is
   begin
      Doc_Dump_Format_Memory_Enc
        (Document, Memory, Size, System.Null_Address, Format);
   end Doc_Dump_Format_Memory;

   procedure Doc_Dump_Format_Memory_Enc
     (Document, Memory, Size, Encoding : System.Address; Format : int)
   is
      Result : System.Address := System.Null_Address;
      Length : Natural := 0;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      Set_Address (Memory, System.Null_Address);
      Set_Status (Size, 0);
      if Refused
           (Guards.Document_Dump, Document /= System.Null_Address,
            Memory /= System.Null_Address)
      then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Dump_Memory_Encoding
           (Document, Encoding, Result, Length, Status,
            Formatted => Format /= 0);
      end;
      if Status = XML3_DOM_Constructors.Created then
         Set_Address (Memory, Result);
         Set_Status (Size, int (Length));
         return;
      end if;
      Report_Operation_Status (Status);
      return;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return;
      when others =>
         Report_Failure (Unexpected_Exception);
         return;
   end Doc_Dump_Format_Memory_Enc;

   ------------------------------------------------------------------
   --  xmlBuffer.  The adapter only maps the public struct onto the SPARK
   --  XML3_Byte_Buffers view and back; the sizes, allocations and copies
   --  are decided there.
   ------------------------------------------------------------------

   package Buffers renames XML3_Byte_Buffers;

   type C_Buffer is record
      Content : System.Address;
      Used : Interfaces.C.unsigned;
      Size : Interfaces.C.unsigned;
      Alloc : Interfaces.C.int;
      Content_IO : System.Address;
   end record with Convention => C;

   --  XML_BUFFER_ALLOC_IO, the only scheme of libxml2 2.15.
   Alloc_IO : constant Interfaces.C.int := 3;

   function File_Write_Path
     (Path : System.Address; Standard_Output : Interfaces.C.int;
      Data : System.Address; Length : Interfaces.C.size_t)
      return Interfaces.C.long
     with Import, Convention => C, External_Name => "xml3FileWritePath";
   function File_Write_Stream
     (Stream, Data : System.Address; Length : Interfaces.C.size_t)
      return Interfaces.C.long
     with Import, Convention => C, External_Name => "xml3FileWriteStream";
   function File_Standard_Output return System.Address
     with Import, Convention => C, External_Name => "xml3FileStandardOutput";

   --  The view of a buffer struct; Ok is False for a struct that is not
   --  in the shape this library creates.
   procedure Read_Buffer
     (Address : System.Address; View : out Buffers.Buffer; Ok : out Boolean)
   is
      Item : C_Buffer with Import, Address => Address;
      Offset : Storage_Offset;
   begin
      View := (others => <>);
      Ok := False;
      if Item.Used > Interfaces.C.unsigned (Integer'Last)
        or else Item.Size > Interfaces.C.unsigned (Integer'Last)
      then
         return;
      end if;
      if Item.Content_IO = System.Null_Address then
         if Item.Content /= System.Null_Address then
            return;
         end if;
      else
         if Item.Content = System.Null_Address
           or else Item.Content < Item.Content_IO
         then
            return;
         end if;
         Offset := Item.Content - Item.Content_IO;
         if Offset > Storage_Offset (Integer'Last) then
            return;
         end if;
         View.Base := Item.Content_IO;
         View.Offset := Natural (Offset);
      end if;
      View.Used := Natural (Item.Used);
      View.Size := Natural (Item.Size);
      Ok := Buffers.Well_Formed (View);
   end Read_Buffer;

   procedure Write_Buffer
     (Address : System.Address; View : Buffers.Buffer)
   is
      Item : C_Buffer with Import, Address => Address;
   begin
      Item :=
        (Content => Buffers.Content (View),
         Used => Interfaces.C.unsigned (View.Used),
         Size => Interfaces.C.unsigned (View.Size),
         Alloc => Alloc_IO,
         Content_IO => View.Base);
   end Write_Buffer;

   function New_Buffer (Default : Boolean; Requested : Natural)
      return System.Address
   is
      Base : System.Address;
      View : Buffers.Buffer;
      Ok : Boolean;
   begin
      XML3_Native_Memory.Allocate (C_Buffer'Size / 8, Base);
      if Base = System.Null_Address then
         return System.Null_Address;
      end if;
      Buffers.Create (Default, Requested, View, Ok);
      if not Ok then
         XML3_Native_Memory.Free (Base);
         return System.Null_Address;
      end if;
      Write_Buffer (Base, View);
      return Base;
   end New_Buffer;

   function Buffer_Create return System.Address is
   begin
      return New_Buffer (True, 0);
   exception
      when others =>
         return System.Null_Address;
   end Buffer_Create;

   function Buffer_Create_Size (Size : Interfaces.C.size_t)
      return System.Address
   is
   begin
      return New_Buffer
        (False,
         (if Size >= Interfaces.C.size_t (Integer'Last) then Integer'Last
          else Natural (Size)));
   exception
      when others =>
         return System.Null_Address;
   end Buffer_Create_Size;

   function Buffer_Create_Static
     (Memory : System.Address; Size : Interfaces.C.size_t)
      return System.Address
   is
      Result : constant System.Address := Buffer_Create_Size (Size);
   begin
      if Result /= System.Null_Address
        and then Buffer_Add
          (Result, Memory,
           (if Size > Interfaces.C.size_t (Interfaces.C.int'Last)
            then Interfaces.C.int'Last else Interfaces.C.int (Size)))
          /= Buffers.OK_Code
      then
         Buffer_Free (Result);
         return System.Null_Address;
      end if;
      return Result;
   exception
      when others =>
         return System.Null_Address;
   end Buffer_Create_Static;

   procedure Buffer_Free (Buffer : System.Address) is
      View : Buffers.Buffer;
      Ok : Boolean;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if Ok then
         Buffers.Release (View);
      end if;
      XML3_Native_Memory.Free (Buffer);
   exception
      when others =>
         null;
   end Buffer_Free;

   procedure Buffer_Empty (Buffer : System.Address) is
      View : Buffers.Buffer;
      Ok : Boolean;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if Ok then
         Buffers.Empty (View);
         Write_Buffer (Buffer, View);
      end if;
   exception
      when others =>
         null;
   end Buffer_Empty;

   function Buffer_Shrink
     (Buffer : System.Address; Length : Interfaces.C.unsigned)
      return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok : Boolean;
      Result : Integer;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return -1;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return -1;
      end if;
      Buffers.Shrink
        (View,
         (if Length > Interfaces.C.unsigned (Integer'Last) then Integer'Last
          else Natural (Length)),
         Result);
      Write_Buffer (Buffer, View);
      return Interfaces.C.int (Result);
   exception
      when others =>
         return -1;
   end Buffer_Shrink;

   function Buffer_Grow
     (Buffer : System.Address; Length : Interfaces.C.unsigned)
      return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok : Boolean;
      Result : Integer;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return -1;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return -1;
      end if;
      Buffers.Grow
        (View,
         (if Length > Interfaces.C.unsigned (Integer'Last) then Integer'Last
          else Natural (Length)),
         Result);
      Write_Buffer (Buffer, View);
      return Interfaces.C.int (Result);
   exception
      when others =>
         return -1;
   end Buffer_Grow;

   function Buffer_Resize
     (Buffer : System.Address; Size : Interfaces.C.unsigned)
      return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok : Boolean;
      Result : Integer;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return 0;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return 0;
      elsif Size < Interfaces.C.unsigned (View.Size) then
         return 1;
      end if;
      Buffers.Grow
        (View,
         (if Size > Interfaces.C.unsigned (Integer'Last) then Integer'Last
          else Natural (Size) - View.Used),
         Result);
      Write_Buffer (Buffer, View);
      return (if Result < 0 then 0 else 1);
   exception
      when others =>
         return 0;
   end Buffer_Resize;

   --  xmlBufferAdd and xmlBufferAddHead; a negative Length measures the
   --  NUL-terminated text.
   function Buffer_Insert
     (Buffer, Text : System.Address; Length : Interfaces.C.int;
      Head : Boolean) return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok, Found : Boolean;
      Count : XML3_Text.Byte_Count;
      Status : Buffers.Add_Status;
   begin
      if Refused
           (Guards.Buffer_Append, Buffer /= System.Null_Address,
            Text /= System.Null_Address)
      then
         return Buffers.Argument_Code;
      end if;
      if Length < 0 then
         XML3_Text.Buffers.Measure (Text, Count, Found);
         if not Found then
            return Buffers.No_Memory_Code;
         end if;
      else
         Count := XML3_Text.Byte_Count (Length);
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return Buffers.Argument_Code;
      end if;
      if Head then
         Buffers.Add_Head (View, Text, Natural (Count), Status);
      else
         Buffers.Add (View, Text, Natural (Count), Status);
      end if;
      Write_Buffer (Buffer, View);
      return Interfaces.C.int
        (if Head then Buffers.Add_Head_Code (Status)
         else Buffers.Add_Code (Status));
   exception
      when others =>
         return Buffers.No_Memory_Code;
   end Buffer_Insert;

   function Buffer_Add
     (Buffer, Text : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int is
     (Buffer_Insert (Buffer, Text, Length, False));

   function Buffer_Add_Head
     (Buffer, Text : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int is
     (Buffer_Insert (Buffer, Text, Length, True));

   function Buffer_Cat (Buffer, Text : System.Address)
      return Interfaces.C.int is
     (Buffer_Insert (Buffer, Text, -1, False));

   function Buffer_C_Cat (Buffer, Text : System.Address)
      return Interfaces.C.int is
     (Buffer_Insert (Buffer, Text, -1, False));

   procedure Buffer_Write_Xml_Chars (Buffer, Text : System.Address) is
      Ignored : Interfaces.C.int;
   begin
      Ignored := Buffer_Insert (Buffer, Text, -1, False);
   end Buffer_Write_Xml_Chars;

   procedure Buffer_Write_C_Chars (Buffer, Text : System.Address) is
      Ignored : Interfaces.C.int;
   begin
      Ignored := Buffer_Insert (Buffer, Text, -1, False);
   end Buffer_Write_C_Chars;

   procedure Buffer_Write_Quoted_String (Buffer, Text : System.Address) is
      View : Buffers.Buffer;
      Ok, Found : Boolean;
      Count : XML3_Text.Byte_Count := 0;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return;
      end if;
      if Text /= System.Null_Address then
         XML3_Text.Buffers.Measure (Text, Count, Found);
         if not Found then
            return;
         end if;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if Ok then
         Buffers.Add_Quoted (View, Text, Natural (Count));
         Write_Buffer (Buffer, View);
      end if;
   exception
      when others =>
         null;
   end Buffer_Write_Quoted_String;

   function Buffer_Content (Buffer : System.Address) return System.Address
   is
      View : Buffers.Buffer;
      Ok : Boolean;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Read_Buffer (Buffer, View, Ok);
      return (if Ok then Buffers.Content (View) else System.Null_Address);
   exception
      when others =>
         return System.Null_Address;
   end Buffer_Content;

   function Buffer_Length (Buffer : System.Address) return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok : Boolean;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return 0;
      end if;
      Read_Buffer (Buffer, View, Ok);
      return (if Ok then Interfaces.C.int (View.Used) else 0);
   exception
      when others =>
         return 0;
   end Buffer_Length;

   function Buffer_Detach (Buffer : System.Address) return System.Address is
      View : Buffers.Buffer;
      Ok : Boolean;
      Result : System.Address;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return System.Null_Address;
      end if;
      Buffers.Detach (View, Result);
      Write_Buffer (Buffer, View);
      return Result;
   exception
      when others =>
         return System.Null_Address;
   end Buffer_Detach;

   procedure Buffer_Set_Allocation_Scheme
     (Buffer : System.Address; Scheme : Interfaces.C.int)
   is
      pragma Unreferenced (Buffer, Scheme);
   begin
      null;
   end Buffer_Set_Allocation_Scheme;

   function Buffer_Dump (Stream, Buffer : System.Address)
      return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok : Boolean;
      Written : Interfaces.C.long;
   begin
      if Refused (Guards.Buffer_Use, Buffer /= System.Null_Address) then
         return 0;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok or else View.Base = System.Null_Address then
         return 0;
      end if;
      Written := File_Write_Stream
        ((if Stream = System.Null_Address then File_Standard_Output
          else Stream),
         Buffers.Content (View), Interfaces.C.size_t (View.Used));
      return (if Written < 0 then 0 else Interfaces.C.int (Written));
   exception
      when others =>
         return 0;
   end Buffer_Dump;

   ------------------------------------------------------------------
   --  Serialization to a buffer, a stream or a file.
   ------------------------------------------------------------------

   --  Serializes Node (as xmlNodeDump) or Doc (as xmlDocDumpFormatMemoryEnc
   --  with Encoding) under the DOM lock; Result is a caller-owned
   --  allocation of Length bytes, or null after the failure was reported.
   procedure Serialize
     (Node, Doc, Encoding : System.Address; Level : Integer;
      Formatted : Boolean; Result : out System.Address;
      Length : out Natural)
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      Result := System.Null_Address;
      Length := 0;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         if Node /= System.Null_Address then
            XML3_DOM_Runtime.Dump_Node
              (Node, Level, Formatted, Result, Length, Status);
         else
            XML3_DOM_Runtime.Dump_Memory_Encoding
              (Doc, Encoding, Result, Length, Status, Formatted);
         end if;
      end;
      if Status /= XML3_DOM_Constructors.Created then
         Report_Operation_Status (Status);
         Result := System.Null_Address;
         Length := 0;
      end if;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         Result := System.Null_Address;
         Length := 0;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         Result := System.Null_Address;
         Length := 0;
   end Serialize;

   function Node_Dump
     (Buffer, Doc, Node : System.Address;
      Level, Format : Interfaces.C.int) return Interfaces.C.int
   is
      pragma Unreferenced (Doc);
      Bytes : System.Address;
      Length : Natural;
      View : Buffers.Buffer;
      Ok : Boolean;
      Status : Buffers.Add_Status;
   begin
      if Refused
           (Guards.Node_Dump, Buffer /= System.Null_Address,
            Node /= System.Null_Address)
      then
         return -1;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return -1;
      end if;
      Serialize
        (Node, System.Null_Address, System.Null_Address, Integer (Level),
         Format /= 0, Bytes, Length);
      if Bytes = System.Null_Address then
         return -1;
      end if;
      Buffers.Add (View, Bytes, Length, Status);
      XML3_Native_Memory.Free (Bytes);
      Write_Buffer (Buffer, View);
      return (if Buffers.Add_Code (Status) = Buffers.OK_Code
              then Interfaces.C.int (Length) else -1);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Node_Dump;

   --  The path a file output opens, as libxml2's default output callback
   --  resolves it (XML3_File_Paths): Name itself or an unescaped copy that
   --  the caller releases (Owned), and whether it means standard output.
   --  Ok is False when the name cannot be resolved.
   procedure Resolve_Output
     (Name : System.Address; Path : out System.Address;
      Owned, Standard, Ok : out Boolean)
   is
      Name_Length : XML3_Text.Byte_Count;
      Found : Boolean;
      Plan : XML3_File_Paths.Path_Plan;
      Status : XML3_Text.Buffers.Escape_Status;
      Path_Length : XML3_Text.Byte_Count;
      use type XML3_Text.Buffers.Escape_Status;
   begin
      Path := Name;
      Owned := False;
      Standard := False;
      Ok := False;
      XML3_Text.Buffers.Measure (Name, Name_Length, Found);
      if not Found then
         return;
      end if;
      XML3_File_Paths.Plan (Name, Natural (Name_Length), Plan);
      if Plan.Unescape then
         XML3_Text.Buffers.Unescape_URI
           (XML3_Native_Memory.Offset
              (Name, XML3_Native_Memory.Byte_Count (Plan.Skip)),
            Integer (Name_Length) - Plan.Skip,
            System.Null_Address, Path, Status);
         if Status /= XML3_Text.Buffers.Escaped
           or else Path = System.Null_Address
         then
            Path := Name;
            return;
         end if;
         Owned := True;
         if Plan.May_Be_Standard then
            XML3_Text.Buffers.Measure (Path, Path_Length, Found);
            Standard := Found
              and then XML3_File_Paths.Is_Standard
                (Path, Natural (Path_Length));
         end if;
      end if;
      Ok := True;
   end Resolve_Output;

   --  Writes the serialization to a stream (Name null) or the file Name.
   function Write_Serialization
     (Stream, Name, Node, Doc, Encoding : System.Address; Level : Integer;
      Formatted : Boolean) return Interfaces.C.int
   is
      Bytes, Path : System.Address := System.Null_Address;
      Length : Natural;
      Written : Interfaces.C.long := -1;
      Owned, Standard, Ok : Boolean;
   begin
      Serialize (Node, Doc, Encoding, Level, Formatted, Bytes, Length);
      if Bytes = System.Null_Address then
         return -1;
      end if;
      if Name = System.Null_Address then
         Written := File_Write_Stream
           (Stream, Bytes, Interfaces.C.size_t (Length));
      else
         Resolve_Output (Name, Path, Owned, Standard, Ok);
         if Ok then
            Written := File_Write_Path
              (Path, (if Standard then 1 else 0),
               Bytes, Interfaces.C.size_t (Length));
         end if;
         if Owned then
            XML3_Native_Memory.Free (Path);
         end if;
      end if;
      XML3_Native_Memory.Free (Bytes);
      --  An open failure is -1, a write failure the negated XML_IO_* code,
      --  as libxml2 returns them; neither publishes a diagnostic.
      return Interfaces.C.int (Written);
   exception
      when others =>
         if Bytes /= System.Null_Address then
            XML3_Native_Memory.Free (Bytes);
         end if;
         Report_Failure (Unexpected_Exception);
         return -1;
   end Write_Serialization;

   procedure Elem_Dump (Stream, Doc, Node : System.Address) is
      pragma Unreferenced (Doc);
      Ignored : Interfaces.C.int;
   begin
      if Refused
           (Guards.Stream_Dump, Stream /= System.Null_Address,
            Node /= System.Null_Address)
      then
         return;
      end if;
      --  xmlElemDump formats from level 0.
      Ignored := Write_Serialization
        (Stream, System.Null_Address, Node, System.Null_Address,
         System.Null_Address, 0, True);
   end Elem_Dump;

   function Doc_Format_Dump
     (Stream, Doc : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int
   is
   begin
      if Refused
           (Guards.Stream_Dump, Stream /= System.Null_Address,
            Doc /= System.Null_Address)
      then
         return -1;
      end if;
      return Write_Serialization
        (Stream, System.Null_Address, System.Null_Address, Doc,
         System.Null_Address, 0, Format /= 0);
   end Doc_Format_Dump;

   function Doc_Dump (Stream, Doc : System.Address) return Interfaces.C.int
   is (Doc_Format_Dump (Stream, Doc, 0));

   function Save_Format_File_Enc
     (Name, Doc, Encoding : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int
   is
   begin
      if Refused
           (Guards.File_Save, Name /= System.Null_Address,
            Doc /= System.Null_Address)
      then
         return -1;
      end if;
      return Write_Serialization
        (System.Null_Address, Name, System.Null_Address, Doc, Encoding, 0,
         Format /= 0);
   end Save_Format_File_Enc;

   function Save_File (Name, Doc : System.Address) return Interfaces.C.int is
     (Save_Format_File_Enc (Name, Doc, System.Null_Address, 0));

   function Save_Format_File
     (Name, Doc : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int is
     (Save_Format_File_Enc (Name, Doc, System.Null_Address, Format));

   function Save_File_Enc
     (Name, Doc, Encoding : System.Address) return Interfaces.C.int is
     (Save_Format_File_Enc (Name, Doc, Encoding, 0));

   ------------------------------------------------------------------
   --  Creation that takes ownership of the name: the node gets its own
   --  copy, and the caller's name is released whether or not the node
   --  could be made, as libxml2 releases it on failure (it keeps the
   --  caller's pointer on success).
   ------------------------------------------------------------------

   function New_Node_Eat_Name (Ns, Name : System.Address)
      return System.Address is
     (New_Doc_Node_Eat_Name
        (System.Null_Address, Ns, Name, System.Null_Address));

   function New_Doc_Node_Eat_Name
     (Doc, Ns, Name, Content : System.Address) return System.Address
   is
      Result : System.Address;
   begin
      if Refused (Guards.Node_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Result := New_Doc_Node (Doc, Ns, Name, Content);
      XML3_Native_Memory.Free (Name);
      return Result;
   end New_Doc_Node_Eat_Name;

   function New_Ns_Prop_Eat_Name
     (Node, Ns, Name, Value : System.Address) return System.Address
   is
      Result : System.Address;
   begin
      if Refused (Guards.Node_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      Result := New_Ns_Prop (Node, Ns, Name, Value);
      XML3_Native_Memory.Free (Name);
      return Result;
   end New_Ns_Prop_Eat_Name;

   --  Allocation schemes were removed in libxml2 2.15: the getter answers
   --  XML_BUFFER_ALLOC_EXACT and the setter has no effect.
   function Get_Buffer_Allocation_Scheme return Interfaces.C.int is (1);

   procedure Set_Buffer_Allocation_Scheme (Scheme : Interfaces.C.int) is
      pragma Unreferenced (Scheme);
   begin
      null;
   end Set_Buffer_Allocation_Scheme;

   function Node_Buf_Get_Content (Buffer, Node : System.Address)
      return Interfaces.C.int
   is
      View : Buffers.Buffer;
      Ok, Found : Boolean;
      Text : System.Address;
      Count : XML3_Text.Byte_Count := 0;
      Status : Buffers.Add_Status := Buffers.Added;
   begin
      if Refused
           (Guards.Node_Dump, Buffer /= System.Null_Address,
            Node /= System.Null_Address)
      then
         return -1;
      end if;
      Read_Buffer (Buffer, View, Ok);
      if not Ok then
         return -1;
      end if;
      Text := Node_Get_Content (Node);
      if Text = System.Null_Address then
         return -1;
      end if;
      XML3_Text.Buffers.Measure (Text, Count, Found);
      if Found and then Count > 0 then
         Buffers.Add (View, Text, Natural (Count), Status);
         Write_Buffer (Buffer, View);
      end if;
      XML3_Native_Memory.Free (Text);
      return (if Found and then Buffers.Add_Code (Status) = Buffers.OK_Code
              then 0 else -1);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Node_Buf_Get_Content;

   procedure Attr_Serialize_Txt_Content
     (Buffer, Doc, Attribute, Text : System.Address)
   is
      pragma Unreferenced (Doc, Attribute);
      View : Buffers.Buffer;
      Ok, Found : Boolean;
      Count : XML3_Text.Byte_Count;
      Ignored : System.Address;
   begin
      if Refused
           (Guards.Buffer_Append, Buffer /= System.Null_Address,
            Text /= System.Null_Address)
      then
         return;
      end if;
      Read_Buffer (Buffer, View, Ok);
      XML3_Text.Buffers.Measure (Text, Count, Found);
      if not Ok or else not Found then
         return;
      end if;
      Buffers.Add_Attribute_Text (View, Text, Natural (Count), Ok);
      if not Ok then
         --  libxml2 drops the whole content when an addition fails.
         Buffers.Detach (View, Ignored);
         if Ignored /= System.Null_Address then
            XML3_Native_Memory.Free (Ignored);
         end if;
      end if;
      Write_Buffer (Buffer, View);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
   end Attr_Serialize_Txt_Content;

   --  xmlFreeNsList: each declaration of the chain, as xmlFreeNs releases
   --  it; the next link is read before the release.
   procedure Free_Ns_List (Ns : System.Address) is
      type C_Ns is record
         Next : System.Address;
      end record with Convention => C;
      Current : System.Address := Ns;
      Next : System.Address;
   begin
      for Step in 1 .. Natural'Last loop
         exit when Current = System.Null_Address;
         declare
            Item : C_Ns with Import, Address => Current;
         begin
            Next := Item.Next;
         end;
         Free_Ns (Current);
         Current := Next;
      end loop;
   end Free_Ns_List;

   function New_Node
      (Ns, Name : System.Address) return System.Address
   is
   begin
      return New_Doc_Node
        (System.Null_Address, Ns, Name, System.Null_Address);
   end New_Node;

   function New_Container_Node
     (Context, Ns, Name, Content : System.Address;
      Raw_Content, As_Child : Boolean; Attribute_Mode : Boolean := False)
     return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Child_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         if As_Child then
            XML3_DOM_Runtime.New_Child
              (Context, Ns, Name, Content, Raw_Content, Result, Status);
         else
            XML3_DOM_Runtime.New_Doc_Node
              (Context, Ns, Name, Content, Raw_Content,
               Result, Status, Attribute_Mode);
         end if;
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end New_Container_Node;

   function New_Doc_Prop
     (Doc, Name, Value : System.Address) return System.Address
   is
   begin
      if Refused (Guards.Node_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return New_Container_Node
        (Doc, System.Null_Address, Name, Value, Raw_Content => False,
         As_Child => False, Attribute_Mode => True);
   end New_Doc_Prop;

   function New_Doc_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      if Refused (Guards.Node_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return New_Container_Node
        (Doc, Ns, Name, Content, Raw_Content => False, As_Child => False);
   end New_Doc_Node;

   function New_Doc_Raw_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      if Refused (Guards.Node_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return New_Container_Node
        (Doc, Ns, Name, Content, Raw_Content => True, As_Child => False);
   end New_Doc_Raw_Node;

   function New_Child
     (Parent, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      return New_Container_Node
        (Parent, Ns, Name, Content, Raw_Content => False, As_Child => True);
   end New_Child;

   function New_Text_Child
     (Parent, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      return New_Container_Node
        (Parent, Ns, Name, Content, Raw_Content => True, As_Child => True);
   end New_Text_Child;

   function New_Content_Node
     (Kind : XML3_DOM.Node_Kind; Name : String; Content : System.Address;
      Length : Interfaces.C.int := -1; Doc : System.Address := System.Null_Address;
      Terminated : Boolean := True;
      Name_Source : System.Address := System.Null_Address)
     return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.New_Doc_Content
           (Doc, Kind, Name, Content, Integer (Length), Terminated, Result, Status,
            Name_Source);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end New_Content_Node;

   function New_Text (Content : System.Address) return System.Address is
   begin
      return New_Content_Node (XML3_DOM.Text_Node, "text", Content);
   end New_Text;

   function String_Len_Get_Node_List
     (Doc, Value : System.Address; Length : Interfaces.C.int)
     return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Node_List_Parse, Value /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Parse_Content_List
           (Doc, Value, Integer (Length), Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end String_Len_Get_Node_List;

   function String_Get_Node_List
     (Doc, Value : System.Address) return System.Address
   is
   begin
      return String_Len_Get_Node_List (Doc, Value, -1);
   end String_Get_Node_List;

   function New_Text_Len
     (Content : System.Address; Length : Interfaces.C.int)
     return System.Address
   is
   begin
      return New_Content_Node
        (XML3_DOM.Text_Node, "text", Content, Length, Terminated => False);
   end New_Text_Len;

   function New_Doc_Text
     (Doc, Content : System.Address) return System.Address
   is
   begin
      return New_Content_Node (XML3_DOM.Text_Node, "text", Content, Doc => Doc);
   end New_Doc_Text;

   function New_Doc_Text_Len
     (Doc, Content : System.Address; Length : Interfaces.C.int)
     return System.Address
   is
   begin
      return New_Content_Node
        (XML3_DOM.Text_Node, "text", Content, Length, Doc, Terminated => False);
   end New_Doc_Text_Len;

   function New_Comment (Content : System.Address) return System.Address is
   begin
      return New_Content_Node (XML3_DOM.Comment_Node, "comment", Content);
   end New_Comment;

   function New_Doc_Comment
     (Doc, Content : System.Address) return System.Address
   is
   begin
      return New_Content_Node
        (XML3_DOM.Comment_Node, "comment", Content, Doc => Doc);
   end New_Doc_Comment;

   function New_CData_Block
     (Doc, Content : System.Address; Length : Interfaces.C.int)
      return System.Address
   is
   begin
      return New_Content_Node
        (XML3_DOM.CData_Node, "", Content, Length, Doc, Terminated => False);
   end New_CData_Block;

   function New_PI
     (Name, Content : System.Address) return System.Address
   is
   begin
      return New_Doc_PI (System.Null_Address, Name, Content);
   end New_PI;

   function New_Doc_PI
     (Doc, Name, Content : System.Address) return System.Address
   is
   begin
      if Refused (Guards.PI_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return New_Content_Node
        (XML3_DOM.Processing_Instruction_Node, "", Content,
         Doc => Doc, Name_Source => Name);
   end New_Doc_PI;

   function Doc_Set_Root_Element
     (Doc, Root : System.Address) return System.Address
   is
      Previous : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Root_Replacement, Doc /= System.Null_Address,
            Root /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Root (Doc, Root, Previous, Status);
      end;
      Report_Operation_Status (Status);
      return Previous;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Doc_Set_Root_Element;

   type Node_Operation is
     (Append_Child, Append_Sibling, Previous_Sibling, Next_Sibling);

   function Add_Node
     (Target, Child : System.Address; Operation : Node_Operation)
      return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Node_Insertion, Target /= System.Null_Address,
            Child /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         case Operation is
            when Append_Child =>
               XML3_DOM_Runtime.Add_Child (Target, Child, Result, Status);
            when Append_Sibling =>
               XML3_DOM_Runtime.Add_Sibling (Target, Child, Result, Status);
            when Previous_Sibling =>
               XML3_DOM_Runtime.Insert_Sibling
                 (Target, Child, True, Result, Status);
            when Next_Sibling =>
               XML3_DOM_Runtime.Insert_Sibling
                 (Target, Child, False, Result, Status);
         end case;
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Add_Node;

   function Add_Child
     (Parent, Child : System.Address) return System.Address is
     (Add_Node (Parent, Child, Append_Child));

   function Add_Sibling
     (Sibling, Child : System.Address) return System.Address is
     (Add_Node (Sibling, Child, Append_Sibling));

   function Add_Previous_Sibling
     (Sibling, Child : System.Address) return System.Address is
     (Add_Node (Sibling, Child, Previous_Sibling));

   function Add_Next_Sibling
     (Sibling, Child : System.Address) return System.Address is
     (Add_Node (Sibling, Child, Next_Sibling));

   function Replace_Node
     (Old, Cur : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Node_Replacement, Old /= System.Null_Address,
            Distinct => Old /= Cur)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Replace_Node (Old, Cur, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Replace_Node;

   function Text_Merge
     (First, Second : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Merge_Text (First, Second, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Text_Merge;

   function Node_Append_Content
     (Node, Content : System.Address; Length : Interfaces.C.int;
      Bounded : Boolean; Text_Only : Boolean := False;
      Group : Guards.Entry_Group := Guards.Content_Addition)
      return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Group, Node /= System.Null_Address) then
         return Results.Update
           (Results.Status_Of (Invalid_Argument), Text_Only);
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Add_Content
           (Node, Content, Integer (Length), Bounded, Status, Text_Only);
      end;
      if Status /= XML3_DOM_Constructors.Created then
         Report_Operation_Status (Status);
      end if;
      return Results.Update (Status, Text_Only);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Update
           (Results.Status_Of (Lock_Failure), Text_Only);
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Update
           (Results.Status_Of (Allocation_Failure), Text_Only);
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Update
           (Results.Status_Of (Unexpected_Exception), Text_Only);
   end Node_Append_Content;

   function Text_Concat
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
   is
   begin
      return Node_Append_Content
        (Node, Content, Length, Length >= 0, True, Guards.Text_Concatenation);
   end Text_Concat;

   function Node_Add_Content
     (Node, Content : System.Address) return Interfaces.C.int
   is
   begin
      return Node_Append_Content (Node, Content, 0, False);
   end Node_Add_Content;

   function Node_Add_Content_Len
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
   is
   begin
      return Node_Append_Content (Node, Content, Length, True);
   end Node_Add_Content_Len;

   procedure Node_Set_Name (Node, Name : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Node_Renaming, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Name (Node, Name, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
      when others =>
         Report_Failure (Unexpected_Exception);
   end Node_Set_Name;

   function Node_Set_Content_Len
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Content
           (Node, Content, Integer (Length), Status);
      end;
      if Status /= XML3_DOM_Constructors.Created then
         Report_Operation_Status (Status);
      end if;
      return Results.Update (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Update (Results.Status_Of (Lock_Failure));
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Update (Results.Status_Of (Allocation_Failure));
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Update
           (Results.Status_Of (Unexpected_Exception));
   end Node_Set_Content_Len;

   function Node_Set_Content
     (Node, Content : System.Address) return Interfaces.C.int
   is
   begin
      return Node_Set_Content_Len (Node, Content, -1);
   end Node_Set_Content;

   procedure Unlink_Node (Node : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Node_Unlinking, Node /= System.Null_Address) then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Unlink_Content (Node, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
      when others =>
         Report_Failure (Unexpected_Exception);
   end Unlink_Node;

   procedure Free_Managed_Node
     (Node : System.Address; Kind : XML3_DOM_Store.Release_Kind;
      As_List : Boolean)
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Node_Release, Node /= System.Null_Address) then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         if As_List then
            XML3_DOM_Runtime.Release_List (Node, Kind, Status);
         else
            XML3_DOM_Runtime.Release (Node, Kind, False, Status);
         end if;
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
      when others =>
         Report_Failure (Unexpected_Exception);
   end Free_Managed_Node;

   procedure Free_Node (Node : System.Address) is
   begin
      Free_Managed_Node (Node, XML3_DOM_Store.Content_Node, False);
   end Free_Node;

   procedure Free_Node_List (Node : System.Address) is
   begin
      Free_Managed_Node (Node, XML3_DOM_Store.Content_Node, True);
   end Free_Node_List;

   procedure Free_Doc (Doc : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Document_Release, Doc /= System.Null_Address) then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Release
           (Doc, XML3_DOM_Store.Document_Only, False, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
      when others =>
         Report_Failure (Unexpected_Exception);
   end Free_Doc;

   function Get_Node_String
     (Node : System.Address; Path : Boolean) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Node_Text, Node /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         if Path then
            XML3_DOM_Runtime.Get_Path (Node, Result, Status);
         else
            XML3_DOM_Runtime.Get_Content (Node, Result, Status);
         end if;
      end;
      Report_Operation_Status
        (Status, (if Path then Results.Node_Path else Results.Node_Content));
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Get_Node_String;

   function Node_Get_Content (Node : System.Address) return System.Address is
   begin
      return Get_Node_String (Node, False);
   end Node_Get_Content;

   function Get_List_String
     (Doc, List : System.Address; Inline_Value : Interfaces.C.int; Raw : Boolean)
     return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Node_List_Text, List /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_List_Content
           (List, Inline_Value = 0, Result, Status,
            Doc => Doc, Default_Entities => not Raw);
      end;
      Report_Operation_Status (Status, Results.Node_List_Text);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Get_List_String;

   function Node_List_Get_Raw_String
     (Doc, List : System.Address; Inline_Value : Interfaces.C.int)
     return System.Address
   is
   begin
      return Get_List_String (Doc, List, Inline_Value, True);
   end Node_List_Get_Raw_String;

   function Node_List_Get_String
     (Doc, List : System.Address; Inline_Value : Interfaces.C.int)
     return System.Address
   is
   begin
      return Get_List_String (Doc, List, Inline_Value, False);
   end Node_List_Get_String;

   function Node_Get_Path (Node : System.Address) return System.Address is
   begin
      return Get_Node_String (Node, True);
   end Node_Get_Path;

   function Node_Get_Line_No (Node : System.Address) return Interfaces.C.long is
      Result : Integer := -1;
   begin
      if Refused (Guards.Line_Number, Node /= System.Null_Address) then
         return -1;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Line_Number (Node, Result);
      end;
      return Interfaces.C.long (Result);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return -1;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return -1;
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Node_Get_Line_No;

   procedure Get_Inherited_XML_Property
     (Node : System.Address;
      Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
      Result : out System.Address;
      Space : out XML3_DOM_Store.Queries.Space_Policy)
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      Result := System.Null_Address;
      Space := XML3_DOM_Store.Queries.Unspecified;
      if Refused (Guards.Inherited_Property, Node /= System.Null_Address) then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Inherited_XML_Property
           (Node, Mode, Result, Space, Status);
      end;
      Report_Operation_Status (Status, Results.Inherited_Property);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when Storage_Error =>
         Result := System.Null_Address;
         Space := XML3_DOM_Store.Queries.Unspecified;
         Report_Failure (Allocation_Failure);
      when others =>
         Result := System.Null_Address;
         Space := XML3_DOM_Store.Queries.Unspecified;
         Report_Failure (Unexpected_Exception);
   end Get_Inherited_XML_Property;

   function Node_Get_Lang (Node : System.Address) return System.Address is
      Result : System.Address := System.Null_Address;
      Space : XML3_DOM_Store.Queries.Space_Policy :=
        XML3_DOM_Store.Queries.Unspecified;
   begin
      Get_Inherited_XML_Property
        (Node, XML3_DOM_Store.Queries.Language_Property, Result, Space);
      return Result;
   end Node_Get_Lang;

   function Node_Get_Space_Preserve
     (Node : System.Address) return Interfaces.C.int
   is
      Result : System.Address := System.Null_Address;
      Space : XML3_DOM_Store.Queries.Space_Policy :=
        XML3_DOM_Store.Queries.Unspecified;
   begin
      Get_Inherited_XML_Property
        (Node, XML3_DOM_Store.Queries.Space_Property, Result, Space);
      return Results.Space_Code (Space);
   end Node_Get_Space_Preserve;

   function Set_XML_Property
     (Element, Value : System.Address;
      Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
      Space_Value : Interfaces.C.int) return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Property_Update, Element /= System.Null_Address) then
         return Results.Update
           (Results.Status_Of (Invalid_Argument));
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_XML_Property
           (Element, Mode, Value, Integer (Space_Value), Status);
      end;
      Report_Operation_Status (Status);
      return Results.Update (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Update (Results.Status_Of (Lock_Failure));
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Update (Results.Status_Of (Allocation_Failure));
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Update
           (Results.Status_Of (Unexpected_Exception));
   end Set_XML_Property;

   function Node_Set_Lang
     (Node, Language : System.Address) return Interfaces.C.int
   is
   begin
      return Set_XML_Property
        (Node, Language, XML3_DOM_Store.Queries.Language_Property, 0);
   end Node_Set_Lang;

   function Node_Set_Space_Preserve
     (Node : System.Address; Value : Interfaces.C.int)
      return Interfaces.C.int
   is
   begin
      return Set_XML_Property
        (Node, System.Null_Address,
         XML3_DOM_Store.Queries.Space_Property, Value);
   end Node_Set_Space_Preserve;

   function Get_Property_Value
     (Node, Name, Href : System.Address;
      Filter : XML3_DOM_Store.Queries.Property_Filter;
      Code : out Interfaces.C.int) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      Code :=
        Results.Lookup (Results.Status_Of (Invalid_Argument), Found => False);
      if Refused
           (Guards.Property_Lookup, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Property
           (Node, Name, Filter, Href, Result, Status);
      end;
      Report_Operation_Status (Status, Results.Property_Lookup);
      Code :=
        Results.Lookup (Status, Found => Result /= System.Null_Address);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Code :=
           Results.Lookup (Results.Status_Of (Lock_Failure), Found => False);
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Code :=
           Results.Lookup
             (Results.Status_Of (Allocation_Failure), Found => False);
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Code :=
           Results.Lookup
             (Results.Status_Of (Unexpected_Exception), Found => False);
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Get_Property_Value;

   function Get_Prop
     (Node, Name : System.Address) return System.Address
   is
      Code : Interfaces.C.int;
   begin
      return Get_Property_Value
        (Node, Name, System.Null_Address,
         XML3_DOM_Store.Queries.Any_Namespace, Code);
   end Get_Prop;

   function New_Ns
     (Node, Href, Prefix : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Create_Namespace
           (Node, Href, Prefix, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end New_Ns;

   function Copy_Ns (Source : System.Address) return System.Address is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Namespace_Copy, Source /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Copy_Namespace (Source, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Copy_Ns;

   --  The four copy entry points share the lock, the status report and
   --  the exception mapping; Operation selects the Runtime call.
   type Copy_Operation is (Node_Copy, Property_Copy, Document_Copy);

   function Copy_Any
     (Operation : Copy_Operation; Node, Other : System.Address;
      Value : Interfaces.C.int) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         case Operation is
            when Node_Copy =>
               XML3_DOM_Runtime.Copy_Node
                 (Node, Other, Integer (Value), Result, Status);
            when Property_Copy =>
               XML3_DOM_Runtime.Copy_Property (Other, Node, Result, Status);
            when Document_Copy =>
               XML3_DOM_Runtime.Copy_Document
                 (Node, Value /= 0, Result, Status);
         end case;
      end;
      Report_Operation_Status (Status, Results.Node_Copy);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Copy_Any;

   function Copy_Node
     (Node : System.Address; Extended : Interfaces.C.int)
      return System.Address
   is
   begin
      if Refused (Guards.Node_Copy, Node /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return Copy_Any (Node_Copy, Node, System.Null_Address, Extended);
   end Copy_Node;

   function Doc_Copy_Node
     (Node, Doc : System.Address; Extended : Interfaces.C.int)
      return System.Address
   is
   begin
      if Refused (Guards.Node_Copy, Node /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return Copy_Any (Node_Copy, Node, Doc, Extended);
   end Doc_Copy_Node;

   function Copy_Prop (Target, Cur : System.Address) return System.Address is
   begin
      if Refused
           (Guards.Property_Copy, Target /= System.Null_Address,
            Cur /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      return Copy_Any (Property_Copy, Cur, Target, 0);
   end Copy_Prop;

   function Copy_Doc
     (Doc : System.Address; Recursive : Interfaces.C.int)
      return System.Address
   is
   begin
      if Refused (Guards.Node_Copy, Doc /= System.Null_Address) then
         return System.Null_Address;
      end if;
      return Copy_Any (Document_Copy, Doc, System.Null_Address, Recursive);
   end Copy_Doc;

   procedure Set_Ns (Node, Ns : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Namespace_Assignment, Node /= System.Null_Address)
      then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Namespace (Node, Ns, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when others =>
         Report_Failure (Unexpected_Namespace_Exception);
   end Set_Ns;

   procedure Free_Ns (Ns : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Namespace_Release, Ns /= System.Null_Address) then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Free_Namespace (Ns, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
      when others =>
         Report_Failure (Unexpected_Namespace_Exception);
   end Free_Ns;

   function New_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Attribute_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Create_Namespace_Property
           (Node, Ns, Name, Value, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end New_Ns_Prop;

   function Set_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Attribute_Update, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Namespace_Property
           (Node, Ns, Name, Value, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Set_Ns_Prop;

   function Unset_Ns_Prop
     (Node, Ns, Name : System.Address) return Interfaces.C.int
   is
      Removed : Boolean := False;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Attribute_Update, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return Results.Removal
           (Results.Status_Of (Invalid_Argument));
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Unset_Namespace_Property
           (Node, Ns, Name, Removed, Status);
      end;
      Report_Operation_Status (Status);
      return Results.Removal (Status, Removed);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Removal (Results.Status_Of (Lock_Failure));
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Removal (Results.Status_Of (Allocation_Failure));
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Removal
           (Results.Status_Of (Unexpected_Exception));
   end Unset_Ns_Prop;

   function New_Prop
     (Node, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Attribute_Creation, Name /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Create_Property (Node, Name, Value, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end New_Prop;

   function Set_Prop
     (Node, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Attribute_Update, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Qualified_Property (Node, Name, Value, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Set_Prop;

   function Unset_Prop
     (Node, Name : System.Address) return Interfaces.C.int
   is
      Removed : Boolean := False;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Attribute_Update, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return Results.Removal
           (Results.Status_Of (Invalid_Argument));
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Unset_Property (Node, Name, Removed, Status);
      end;
      Report_Operation_Status (Status);
      return Results.Removal (Status, Removed);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Removal (Results.Status_Of (Lock_Failure));
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Removal (Results.Status_Of (Allocation_Failure));
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Removal
           (Results.Status_Of (Unexpected_Exception));
   end Unset_Prop;

   function Remove_Prop (Attribute : System.Address) return Interfaces.C.int is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Attribute_Removal, Attribute /= System.Null_Address)
      then
         return Results.Removal
           (Results.Status_Of (Invalid_Argument));
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Release
           (Attribute, XML3_DOM_Store.Namespaced_Attribute, True, Status);
      end;
      Report_Operation_Status (Status);
      return Results.Removal (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return Results.Removal (Results.Status_Of (Lock_Failure));
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return Results.Removal (Results.Status_Of (Allocation_Failure));
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Removal
           (Results.Status_Of (Unexpected_Exception));
   end Remove_Prop;

   procedure Free_Prop (Attribute : System.Address) is
   begin
      Free_Managed_Node (Attribute, XML3_DOM_Store.Namespaced_Attribute, False);
   end Free_Prop;

   procedure Free_Prop_List (Attribute : System.Address) is
   begin
      Free_Managed_Node (Attribute, XML3_DOM_Store.Namespaced_Attribute, True);
   end Free_Prop_List;

   function Has_Prop
     (Node, Name : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Property_Lookup, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Find_Property
           (Node, Name, XML3_DOM_Store.Queries.Any_Namespace, System.Null_Address,
            Result, Status);
      end;
      Report_Operation_Status (Status, Results.Property_Lookup);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Has_Prop;

   function Namespace_List_Value
     (Node : System.Address; Code : out int) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status;
   begin
      Code :=
        Results.Lookup (Results.Status_Of (Invalid_Argument), Found => False);
      if Refused (Guards.Namespace_Query, Node /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Namespace_List (Node, Result, Status);
      end;
      Report_Operation_Status (Status, Results.Namespace_List);
      Code :=
        Results.Lookup (Status, Found => Result /= System.Null_Address);
      return Result;
   exception
      when Storage_Error =>
         Code :=
           Results.Lookup
             (Results.Status_Of (Allocation_Failure), Found => False);
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Code :=
           Results.Lookup
             (Results.Status_Of (Unexpected_Exception), Found => False);
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Namespace_List_Value;

   function Get_Ns_List (Doc, Node : System.Address) return System.Address is
      pragma Unreferenced (Doc);
      Code : int;
   begin
      return Namespace_List_Value (Node, Code);
   end Get_Ns_List;

   function Get_Ns_List_Safe (Doc, Node, Output : System.Address) return int is
      pragma Unreferenced (Doc);
      Result : System.Address;
      Code : int;
   begin
      Set_Address (Output, System.Null_Address);
      if Refused (Guards.Lookup_Output, Output /= System.Null_Address) then
         return Results.Lookup
           (Results.Status_Of (Invalid_Argument), Found => False);
      end if;
      Result := Namespace_List_Value (Node, Code);
      Set_Address (Output, Result);
      return Code;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Lookup
           (Results.Status_Of (Unexpected_Exception), Found => False);
   end Get_Ns_List_Safe;

   function Search_Ns
     (Doc, Node, Prefix : System.Address) return System.Address
   is
      pragma Unreferenced (Doc);
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Namespace_Query, Node /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Search_Namespace
           (Node, XML3_DOM_Store.Queries.Prefix_Search, Prefix, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Search_Ns;

   function Search_Ns_By_Href
     (Doc, Node, Href : System.Address) return System.Address
   is
      pragma Unreferenced (Doc);
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Namespace_Query, Node /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Search_Namespace
           (Node, XML3_DOM_Store.Queries.Href_Search, Href, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Search_Ns_By_Href;

   function Has_Ns_Prop
     (Node, Name, Href : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Filter : constant XML3_DOM_Store.Queries.Property_Filter :=
        (if Href = System.Null_Address
         then XML3_DOM_Store.Queries.No_Namespace
         else XML3_DOM_Store.Queries.Exact_Namespace);
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Property_Lookup, Node /= System.Null_Address,
            Name /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Find_Property
           (Node, Name, Filter, Href, Result, Status);
      end;
      Report_Operation_Status (Status, Results.Property_Lookup);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return System.Null_Address;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Has_Ns_Prop;

   function Get_Ns_Prop
     (Node, Name, Href : System.Address) return System.Address
   is
      Filter : constant XML3_DOM_Store.Queries.Property_Filter :=
        (if Href = System.Null_Address
         then XML3_DOM_Store.Queries.No_Namespace
         else XML3_DOM_Store.Queries.Exact_Namespace);
      Code : Interfaces.C.int;
   begin
      return Get_Property_Value (Node, Name, Href, Filter, Code);
   end Get_Ns_Prop;

   function Get_No_Ns_Prop
     (Node, Name : System.Address) return System.Address
   is
   begin
      return Get_Ns_Prop (Node, Name, System.Null_Address);
   end Get_No_Ns_Prop;

   function Node_Get_Attr_Value
     (Node, Name, Href, Output : System.Address) return Interfaces.C.int
   is
      Result : System.Address;
      Code : Interfaces.C.int;
      Filter : constant XML3_DOM_Store.Queries.Property_Filter :=
        (if Href = System.Null_Address
         then XML3_DOM_Store.Queries.No_Namespace
         else XML3_DOM_Store.Queries.Exact_Namespace);
   begin
      Set_Address (Output, System.Null_Address);
      if Refused (Guards.Lookup_Output, Output /= System.Null_Address) then
         return Results.Lookup
           (Results.Status_Of (Invalid_Argument), Found => False);
      end if;
      Result := Get_Property_Value (Node, Name, Href, Filter, Code);
      Set_Address (Output, Result);
      return Code;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Results.Lookup
           (Results.Status_Of (Unexpected_Exception), Found => False);
   end Node_Get_Attr_Value;

   function First_Element_Child (Parent : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Parent, XML3_DOM_Store.Queries.First_Element);
   end First_Element_Child;

   function Get_Last_Child (Parent : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Parent, XML3_DOM_Store.Queries.Last_Child_Node);
   end Get_Last_Child;

   function Last_Element_Child (Parent : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Parent, XML3_DOM_Store.Queries.Last_Element);
   end Last_Element_Child;

   function Next_Element_Sibling (Node : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Node, XML3_DOM_Store.Queries.Next_Element);
   end Next_Element_Sibling;

   function Previous_Element_Sibling (Node : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Node, XML3_DOM_Store.Queries.Previous_Element);
   end Previous_Element_Sibling;

   function Child_Element_Count
     (Parent : System.Address) return Interfaces.C.unsigned_long
   is
      Result : System.Address := System.Null_Address;
      Count : Natural := 0;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Element_Query, Parent /= System.Null_Address) then
         return 0;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Select_Element
           (Parent, XML3_DOM_Store.Queries.Element_Count,
            Result, Count, Status);
      end;
      Report_Operation_Status (Status, Results.Child_Count);
      return unsigned_long (Count);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return 0;
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return 0;
      when others =>
         Report_Failure (Unexpected_Exception);
         return 0;
   end Child_Element_Count;

   function Check_UTF8 (Item : System.Address) return Interfaces.C.int is
      Status : XML3_Text.Buffers.UTF8_Status;
   begin
      XML3_Text.Buffers.Check_UTF8 (Item, Status);
      Report_Code (Text_Results.For_UTF8 (Status));
      return Text_Results.Validity (Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Validity (XML3_Text.Buffers.UTF8_Invalid);
   end Check_UTF8;

   function UTF8_Length_Result
     (Length : XML3_Text.Byte_Count; Status : XML3_Text.Buffers.UTF8_Status)
      return Interfaces.C.int
   is
   begin
      Report_Code (Text_Results.For_UTF8 (Status));
      return Text_Results.Measure (Length, Status);
   end UTF8_Length_Result;

   function UTF8_Str_Length (Item : System.Address) return Interfaces.C.int is
      Length : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.UTF8_Status;
   begin
      XML3_Text.Buffers.Count_UTF8 (Item, Length, Status);
      return UTF8_Length_Result (Length, Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Measure (0, XML3_Text.Buffers.UTF8_Invalid);
   end UTF8_Str_Length;

   function UTF8_Str_Size
     (Item : System.Address; Characters : Interfaces.C.int) return Interfaces.C.int
   is
      Size : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.UTF8_Status;
   begin
      XML3_Text.Buffers.Measure_UTF8_Prefix (Item, Integer (Characters), Size, Status);
      return UTF8_Length_Result (Size, Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Measure (0, XML3_Text.Buffers.UTF8_Invalid);
   end UTF8_Str_Size;

   function UTF8_Size (Item : System.Address) return Interfaces.C.int is
   begin
      return int (XML3_Text.Buffers.UTF8_Lead_Size (Item));
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end UTF8_Size;

   function Normalize_URI_Path (Path : System.Address) return Interfaces.C.int is
      Status : XML3_Text.Buffers.Path_Status;
   begin
      XML3_Text.Buffers.Normalize_URI_Path (Path, Status);
      Report_Code (Text_Results.For_Path (Status));
      return Text_Results.Path_Code (Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Path_Code (XML3_Text.Buffers.Invalid_Path);
   end Normalize_URI_Path;

   function URI_Unescape_String
     (Input : System.Address; Length : Interfaces.C.int; Target : System.Address)
      return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;
   begin
      XML3_Text.Buffers.Unescape_URI (Input, Integer (Length), Target, Result, Status);
      Report_Code (Text_Results.For_URI_Escape (Status));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end URI_Unescape_String;

   function URI_Escape_Str (Input, Exceptions : System.Address) return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;
   begin
      XML3_Text.Buffers.Escape_URI (Input, Exceptions, Result, Status);
      Report_Code (Text_Results.For_URI_Escape (Status));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end URI_Escape_Str;

   function Copy_Char_Multi_Byte
     (Output : System.Address; Code : Interfaces.C.int) return Interfaces.C.int
   is
      Written : Natural;
   begin
      XML3_Text.Buffers.Write_UTF8_Char (Output, Integer (Code), Written);
      return int (Written);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return 0;
   end Copy_Char_Multi_Byte;

   function Copy_Char
     (Length : Interfaces.C.int; Output : System.Address; Code : Interfaces.C.int)
      return Interfaces.C.int
   is
      pragma Unreferenced (Length);
   begin
      return Copy_Char_Multi_Byte (Output, Code);
   end Copy_Char;

   function Char_In_Range
     (Code : Interfaces.C.unsigned; Group : System.Address) return Interfaces.C.int is
     (Boolean'Pos (XML3_Text.Buffers.Character_In_Range (Code, Group)));

   function Is_XML_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Char (Natural (Code))));

   function Validate_Name_Value (Value : System.Address) return Interfaces.C.int is
     (int (Boolean'Pos (XML3_Text.Buffers.Valid_Name_Value
        (Value, XML3_Text.Buffers.Single_Name))));

   function Validate_Names_Value (Value : System.Address) return Interfaces.C.int is
     (int (Boolean'Pos (XML3_Text.Buffers.Valid_Name_Value
        (Value, XML3_Text.Buffers.Name_List))));

   function Validate_NMToken_Value (Value : System.Address) return Interfaces.C.int is
     (int (Boolean'Pos (XML3_Text.Buffers.Valid_Name_Value
        (Value, XML3_Text.Buffers.Single_NMToken))));

   function Validate_NMTokens_Value (Value : System.Address) return Interfaces.C.int is
     (int (Boolean'Pos (XML3_Text.Buffers.Valid_Name_Value
        (Value, XML3_Text.Buffers.NMToken_List))));

   function Get_Predefined_Entity (Name : System.Address) return System.Address is
     (XML3_Text.Buffers.Get_Predefined_Entity (Name));

   function Get_Document_Entity (Document, Name : System.Address) return System.Address is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status := XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Document_Entity (Document, Name, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Get_Document_Entity;

   function Is_XHTML (System_ID, Public_ID : System.Address) return Interfaces.C.int is
     (int (XML3_Text.Buffers.Is_XHTML (System_ID, Public_ID)));

   function Is_XML_Blank (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Blank (Natural (Code))));

   function Is_XML_Base_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Base_Char (Natural (Code))));

   function Is_XML_Combining (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Combining (Natural (Code))));

   function Is_XML_Digit (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Digit (Natural (Code))));

   function Is_XML_Extender (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Extender (Natural (Code))));

   function Is_XML_Ideographic (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Ideographic (Natural (Code))));

   function Is_XML_Pubid_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Pubid_Char (Natural (Code))));

   function UTF8_Char_Compare (Left, Right : System.Address) return Interfaces.C.int is
      Result : Integer;
      Invalid : Boolean;
   begin
      XML3_Text.Buffers.Compare_UTF8_Character (Left, Right, Result, Invalid);
      Report_Code (Text_Results.For_Malformed (Invalid));
      return int (Result);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end UTF8_Char_Compare;

   function UTF8_Str_Location (Item, Pattern : System.Address) return Interfaces.C.int is
      Index : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status;
   begin
      XML3_Text.Buffers.Find_UTF8_Character (Item, Pattern, Index, Status);
      Report_Code (Text_Results.For_Search (Status));
      return Text_Results.Location (Index, Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Location (0, XML3_Text.Buffers.No_Match);
   end UTF8_Str_Location;

   function Get_UTF8_Char
     (Item : System.Address; Length : System.Address) return Interfaces.C.int
   is
      Code : Integer;
      Width : Natural;
   begin
      if Refused
           (Guards.Character_Decoding, Item /= System.Null_Address,
            Length /= System.Null_Address)
      then
         --  Set_Status writes nothing when the length slot is missing.
         Set_Status (Length, 0);
         return -1;
      end if;
      declare
         Slot : int with Import, Address => Length;
      begin
         XML3_Text.Buffers.Get_UTF8_Char (Item, Integer (Slot), Code, Width);
         Slot := int (Width);
         return int (Code);
      end;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         Set_Status (Length, 0);
         return -1;
   end Get_UTF8_Char;

   function Append_String
     (Item, Addition : System.Address; Length : Interfaces.C.int;
      Terminated : Boolean) return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Append_Status;
   begin
      XML3_Text.Buffers.Append
        (Item, Addition, Integer (Length), Terminated, Result, Status);
      Report_Code (Text_Results.For_Append (Status));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Append_String;

   function Str_Append (Item, Addition : System.Address) return System.Address is
     (Append_String (Item, Addition, 0, True));

   function Str_N_Append
     (Item, Addition : System.Address; Length : Interfaces.C.int) return System.Address is
     (Append_String (Item, Addition, Length, False));

   function Compare_Strings
     (Left, Right : System.Address; Ignore_Case : Boolean) return Interfaces.C.int
   is
      Result : Integer;
      Limit_Exceeded : Boolean;
   begin
      XML3_Text.Buffers.Compare_Terminated
        (Left, Right, Ignore_Case, Result, Limit_Exceeded);
      Report_Code (Text_Results.For_Limit (Limit_Exceeded));
      return Interfaces.C.int (Result);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Compare_Strings;

   function Str_Compare
     (Left, Right : System.Address) return Interfaces.C.int is
     (Compare_Strings (Left, Right, False));

   function Str_Case_Compare
     (Left, Right : System.Address) return Interfaces.C.int is
     (Compare_Strings (Left, Right, True));

   function Str_Equal
     (Left, Right : System.Address) return Interfaces.C.int
   is (Text_Results.Equality (Compare_Strings (Left, Right, False)));

   function Str_Q_Equal
     (Prefix, Name, Value : System.Address) return Interfaces.C.int
   is
      Status : XML3_Text.QNames.Comparison_Status;
   begin
      XML3_Text.QNames.Compare (Prefix, Name, Value, Status);
      Report_Code (Text_Results.For_Comparison (Status));
      return Text_Results.Equality (Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Equality (XML3_Text.QNames.Different);
   end Str_Q_Equal;

   function Search_Result
     (Item : System.Address; Position : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status)
      return System.Address
   is
   begin
      Report_Code (Text_Results.For_Search (Status));
      case Status is
         when XML3_Text.Buffers.Matched =>
            return Item + Storage_Offset (Position);
         when XML3_Text.Buffers.No_Match
            | XML3_Text.Buffers.Search_Limit_Exceeded =>
            return System.Null_Address;
      end case;
   end Search_Result;

   function UTF8_Str_Position
     (Item : System.Address; Index : Interfaces.C.int) return System.Address
   is
      Position : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status;
   begin
      XML3_Text.Buffers.Find_UTF8_Position (Item, Integer (Index), Position, Status);
      return Search_Result (Item, Position, Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end UTF8_Str_Position;

   function Str_Character
     (Item : System.Address; Value : Interfaces.C.unsigned_char)
      return System.Address
   is
      Position : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status;
   begin
      XML3_Text.Buffers.Find_Byte
        (Item, Character'Val (Value), Position, Status);
      return Search_Result (Item, Position, Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Str_Character;

   function Find_Substring
     (Item, Pattern : System.Address; Ignore_Case : Boolean)
      return System.Address
   is
      Position : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status;
   begin
      XML3_Text.Buffers.Find_Substring
        (Item, Pattern, Ignore_Case, Position, Status);
      return Search_Result (Item, Position, Status);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Find_Substring;

   function Str_Substring (Item, Pattern : System.Address) return System.Address is
   begin
      return Find_Substring (Item, Pattern, False);
   end Str_Substring;

   function Str_Case_Substring
     (Item, Pattern : System.Address) return System.Address is
   begin
      return Find_Substring (Item, Pattern, True);
   end Str_Case_Substring;

   function Compare_Bounded_Strings
     (Left, Right : System.Address; Length : Interfaces.C.int;
      Ignore_Case : Boolean) return Interfaces.C.int
   is
   begin
      return Interfaces.C.int
        (XML3_Text.Buffers.Compare_Bounded
           (Left, Right, Integer (Length), Ignore_Case));
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return 0;
   end Compare_Bounded_Strings;

   function Str_N_Compare
     (Left, Right : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int is
   begin
      return Compare_Bounded_Strings (Left, Right, Length, False);
   end Str_N_Compare;

   function Str_N_Case_Compare
     (Left, Right : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int is
   begin
      return Compare_Bounded_Strings (Left, Right, Length, True);
   end Str_N_Case_Compare;

   function Str_N_Concat_New
     (Left, Right : System.Address; Length : Interfaces.C.int)
      return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Concatenate_Status;
   begin
      XML3_Text.Buffers.Concatenate_Bytes
        (Left, Right, Integer (Length), Result, Status);
      Report_Code (Text_Results.For_Concatenate (Status));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Str_N_Concat_New;

   function Encode_Special_Chars
     (Document, Input : System.Address) return System.Address
   is
      pragma Unreferenced (Document);
      Result : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;
   begin
      if Refused (Guards.Entity_Encoding, Input /= System.Null_Address) then
         return System.Null_Address;
      end if;
      XML3_Text.Buffers.Escape_Special_Bytes (Input, Result, Status);
      Report_Code (Text_Results.For_Special_Escape (Status));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Encode_Special_Chars;

   function Encode_Entities_Reentrant
     (Document, Input : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused (Guards.Entity_Encoding, Input /= System.Null_Address) then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Encode_Entities
           (Document, Input, Result, Status);
      end;
      Report_Operation_Status (Status, Results.Entity_Encoding);
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Encode_Entities_Reentrant;

   function Slice_Result
     (Result : System.Address; Status : XML3_Text.Buffers.Slice_Status)
      return System.Address
   is
   begin
      Report_Code (Text_Results.For_Slice (Status));
      return Result;
   end Slice_Result;

   function Str_Duplicate (Item : System.Address) return System.Address is
   begin
      return Str_N_Concat_New (System.Null_Address, Item, -1);
   end Str_Duplicate;

   function Char_Str_Duplicate (Item : System.Address) return System.Address is
   begin
      return Str_Duplicate (Item);
   end Char_Str_Duplicate;

   function Char_Str_N_Duplicate
     (Item : System.Address; Length : Interfaces.C.int) return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Slice_Status;
   begin
      XML3_Text.Buffers.Copy_Byte_Prefix
        (Item, Integer (Length), Result, Status);
      return Slice_Result (Result, Status);
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Char_Str_N_Duplicate;

   function Str_N_Duplicate
     (Item : System.Address; Length : Interfaces.C.int) return System.Address is
   begin
      if Length < 0 then
         return System.Null_Address;
      end if;
      return Str_N_Concat_New (System.Null_Address, Item, Length);
   end Str_N_Duplicate;

   function Str_Sub_Copy
     (Item : System.Address; Start, Length : Interfaces.C.int)
      return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Slice_Status;
   begin
      XML3_Text.Buffers.Slice
        (Item, Integer (Start), Integer (Length), Result, Status);
      return Slice_Result (Result, Status);
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Str_Sub_Copy;

   function UTF8_Str_N_Duplicate
     (Item : System.Address; Characters : Interfaces.C.int) return System.Address
   is
   begin
      return UTF8_Str_Sub_Copy (Item, 0, Characters);
   end UTF8_Str_N_Duplicate;

   function UTF8_Str_Sub_Copy
     (Item : System.Address; Start, Characters : Interfaces.C.int) return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.Buffers.Slice_Status;
   begin
      XML3_Text.Buffers.Copy_UTF8_Slice
        (Item, Integer (Start), Integer (Characters), Result, Status);
      return Slice_Result (Result, Status);
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end UTF8_Str_Sub_Copy;

   function Str_Length (Item : System.Address) return Interfaces.C.int is
      Length : XML3_Text.Byte_Count;
      Success : Boolean;
   begin
      XML3_Text.Buffers.Measure (Item, Length, Success);
      Report_Code (Text_Results.For_Limit (not Success));
      return Text_Results.Measure (Length, Measured => Success);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Text_Results.Measure (0, Measured => False);
   end Str_Length;

   function Build_QName
     (Name, Prefix, Memory : System.Address; Length : Interfaces.C.int)
      return System.Address
   is
      Result : System.Address;
      Status : XML3_Text.QNames.Build_Status;
   begin
      XML3_Text.QNames.Build
        (Name, Prefix, Memory, Integer (Length), Result, Status);
      Report_Code (Text_Results.For_Build (Status));
      return Result;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Build_QName;

   function Split_QName2 (Name, Prefix : System.Address) return System.Address is
      Prefix_Value, Local : System.Address;
      Status : XML3_Text.QNames.Split_Status;
   begin
      Set_Address (Prefix, System.Null_Address);
      if Refused
           (Guards.QName_Split, Name /= System.Null_Address,
            Prefix /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      XML3_Text.QNames.Split (Name, Prefix_Value, Local, Status);
      Report_Code (Text_Results.For_Split (Status));
      Set_Address (Prefix, Prefix_Value);
      return Local;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Split_QName2;

   function Split_QName3 (Name, Length : System.Address) return System.Address is
      Count : XML3_Text.Byte_Count;
      Local : System.Address;
      Status : XML3_Text.QNames.Prefix_Status;
      use type XML3_Text.QNames.Prefix_Status;
   begin
      if Refused
           (Guards.QName_Split, Name /= System.Null_Address,
            Length /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      XML3_Text.QNames.Locate_Prefix (Name, Count, Local, Status);
      Report_Code (Text_Results.For_Prefix (Status));
      if Status /= XML3_Text.QNames.Prefix_Found then
         return System.Null_Address;
      end if;
      Set_Status (Length, int (Count));
      return Local;
   exception
      when Storage_Error =>
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Split_QName3;

   function Validate_Name_Value
     (Value : System.Address; Space : int; Kind : XML3_Text.Name_Kind)
      return int
   is
   begin
      return int (XML3_Text.Buffers.Validate_Name (Value, Kind, Space /= 0));
   exception
      when others =>
         return -1;
   end Validate_Name_Value;

   function Validate_Name (Value : System.Address; Space : int) return int is
   begin
      return Validate_Name_Value (Value, Space, XML3_Text.XML_Name);
   end Validate_Name;

   function Validate_NCName (Value : System.Address; Space : int) return int is
   begin
      return Validate_Name_Value (Value, Space, XML3_Text.NCName);
   end Validate_NCName;

   function Validate_QName (Value : System.Address; Space : int) return int is
   begin
      return Validate_Name_Value (Value, Space, XML3_Text.QName);
   end Validate_QName;

   function Validate_NMToken (Value : System.Address; Space : int) return int is
   begin
      return Validate_Name_Value (Value, Space, XML3_Text.NMToken);
   end Validate_NMToken;

   procedure Free (Item : System.Address) is
   begin
      if Item /= System.Null_Address then
         C_Free (Item);
      end if;
   exception
      when others =>
         null;
   end Free;

   ------------------------------------------------------------------
   --  Save contexts (xmlsave.h).  The options, the indent string and the
   --  output buffer's state are decided in SPARK (XML3_Save_Contexts);
   --  the pending bytes are an XML3_Byte_Buffers buffer.  This part keeps
   --  the context and calls the target.
   ------------------------------------------------------------------

   package Save renames XML3_Save_Contexts;

   function Fd_Write
     (Fd : int; Data : System.Address; Length : int) return int
     with Import, Convention => C, External_Name => "xml3FdWrite";
   function Fd_Close (Fd : int) return int
     with Import, Convention => C, External_Name => "xml3FdClose";
   function File_Open_Write (Path : System.Address; Standard : int)
      return int
     with Import, Convention => C, External_Name => "xml3FileOpenWrite";

   type Target_Kind is (Buffer_Target, Fd_Target, File_Target, IO_Target);

   type Save_Context is record
      Kind : Target_Kind;
      Target : System.Address;
      Fd : int;
      Write : Output_Write_Callback;
      Close : Output_Close_Callback;
      Has_Encoding : Boolean;
      Encoding : String (1 .. 6);
      Formatted : Boolean;
      Style : XML3_Serialization.Output_Style;
      Pending : Buffers.Buffer;
      Output : Save.Output_State;
   end record;

   --  The bytes handed to a target for an empty write.
   Empty_Bytes : aliased constant char_array (0 .. 0) := (0 => nul);

   --  Checks the encoding and the options of a new context.  Ok is False
   --  after the refusal was reported.
   procedure Check_Save_Request
     (Encoding : System.Address; Options : int;
      Name : out XML3_Serialization.UTF8_Name; Ok : out Boolean)
   is
      Valid : Boolean;
   begin
      Name := "UTF-8";
      Ok := False;
      if Encoding /= System.Null_Address then
         XML3_Serialization.Read_UTF8_Name (Encoding, Name, Valid);
         if not Valid then
            XML3_Errors.Report_Simple
              (Save.Output_Domain, Save.Unsupported_Encoding_Code,
               Save.Unsupported_Encoding_Level, System.Null_Address);
            return;
         end if;
      end if;
      if not Save.Supported (Options) then
         XML3_Errors.Report_Simple
           (Save.Output_Domain, Save.Unsupported_Option_Code,
            Save.Unsupported_Option_Level, System.Null_Address);
         return;
      end if;
      Ok := True;
   end Check_Save_Request;

   function New_Save_Context
     (Kind : Target_Kind; Target : System.Address; Fd : int;
      Write : Output_Write_Callback; Close : Output_Close_Callback;
      Has_Encoding : Boolean; Name : XML3_Serialization.UTF8_Name;
      Options : int) return System.Address
   is
      Result : System.Address;
   begin
      XML3_Native_Memory.Allocate
        (XML3_Native_Memory.Byte_Count
           (Save_Context'Max_Size_In_Storage_Elements),
         Result);
      if Result = System.Null_Address then
         Report_Failure (Allocation_Failure);
         return System.Null_Address;
      end if;
      declare
         Context : Save_Context with Import, Address => Result;
      begin
         Context :=
           (Kind => Kind, Target => Target, Fd => Fd, Write => Write,
            Close => Close, Has_Encoding => Has_Encoding,
            Encoding => Name & Character'Val (0),
            Formatted => Save.Formatted (Options),
            Style => Save.Style_For (Options),
            Pending => (others => <>),
            Output => (Written => 0, Error => 0));
      end;
      return Result;
   end New_Save_Context;

   function Save_To_Buffer
     (Buffer, Encoding : System.Address; Options : int) return System.Address
   is
      Name : XML3_Serialization.UTF8_Name;
      Ok : Boolean;
   begin
      Check_Save_Request (Encoding, Options, Name, Ok);
      if not Ok
        or else Refused (Guards.Save_Creation, Buffer /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      return New_Save_Context
        (Buffer_Target, Buffer, -1, null, null,
         Encoding /= System.Null_Address, Name, Options);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Save_To_Buffer;

   function Save_To_Fd
     (Fd : int; Encoding : System.Address; Options : int) return System.Address
   is
      Name : XML3_Serialization.UTF8_Name;
      Ok : Boolean;
   begin
      Check_Save_Request (Encoding, Options, Name, Ok);
      if not Ok or else Fd < 0 then
         return System.Null_Address;
      end if;
      return New_Save_Context
        (Fd_Target, System.Null_Address, Fd, null, null,
         Encoding /= System.Null_Address, Name, Options);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Save_To_Fd;

   function Save_To_Filename
     (Name, Encoding : System.Address; Options : int) return System.Address
   is
      Encoding_Name : XML3_Serialization.UTF8_Name;
      Ok : Boolean;
      Path : System.Address;
      Owned, Standard : Boolean;
      Fd : int := -1;
      Result : System.Address;
   begin
      Check_Save_Request (Encoding, Options, Encoding_Name, Ok);
      if not Ok
        or else Refused (Guards.Save_Creation, Name /= System.Null_Address)
      then
         return System.Null_Address;
      end if;
      --  The file is created or truncated now; a name that cannot be
      --  opened gives no context and no diagnostic, as in libxml2.
      Resolve_Output (Name, Path, Owned, Standard, Ok);
      if Ok then
         Fd := File_Open_Write (Path, (if Standard then 1 else 0));
      end if;
      if Owned then
         XML3_Native_Memory.Free (Path);
      end if;
      if Fd < 0 then
         return System.Null_Address;
      end if;
      Result := New_Save_Context
        (File_Target, System.Null_Address, Fd, null, null,
         Encoding /= System.Null_Address, Encoding_Name, Options);
      if Result = System.Null_Address then
         Ok := Fd_Close (Fd) = 0;
      end if;
      return Result;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Save_To_Filename;

   function Save_To_IO
     (Write : Output_Write_Callback; Close : Output_Close_Callback;
      Context, Encoding : System.Address; Options : int)
      return System.Address
   is
      Name : XML3_Serialization.UTF8_Name;
      Ok : Boolean;
   begin
      Check_Save_Request (Encoding, Options, Name, Ok);
      if not Ok or else Refused (Guards.Save_Creation, Write /= null) then
         return System.Null_Address;
      end if;
      return New_Save_Context
        (IO_Target, Context, -1, Write, Close,
         Encoding /= System.Null_Address, Name, Options);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Save_To_IO;

   --  The target's write callback for Length bytes at Data.
   function Call_Write
     (Context : Save_Context; Data : System.Address; Length : Natural)
      return int
   is
      Bytes : constant System.Address :=
        (if Data = System.Null_Address then Empty_Bytes'Address else Data);
   begin
      case Context.Kind is
         when Buffer_Target =>
            --  xmlBufferWrite: the length, or -XML_ERR_NO_MEMORY.
            declare
               View : Buffers.Buffer;
               Ok : Boolean;
               Status : Buffers.Add_Status;
               use type Buffers.Add_Status;
            begin
               Read_Buffer (Context.Target, View, Ok);
               if not Ok then
                  return -int (Save.No_Memory_Code);
               end if;
               Buffers.Add (View, Bytes, Length, Status);
               Write_Buffer (Context.Target, View);
               return (if Status = Buffers.Added then int (Length)
                       else -int (Save.No_Memory_Code));
            end;
         when Fd_Target | File_Target =>
            return Fd_Write (Context.Fd, Bytes, int (Length));
         when IO_Target =>
            return Context.Write (Context.Target, Bytes, int (Length));
      end case;
   end Call_Write;

   --  xmlOutputBufferFlush: hands every pending byte to the target once.
   function Flush_Output (Ctxt : System.Address) return int is
      Context : Save_Context with Import, Address => Ctxt;
      Count : constant Natural := Context.Pending.Used;
      Result : int;
      Ignored : Integer;
   begin
      if Context.Output.Error /= 0 then
         return -1;
      end if;
      Result := Call_Write (Context, Buffers.Content (Context.Pending), Count);
      Buffers.Shrink (Context.Pending, Save.Taken (Result, Count), Ignored);
      Context.Output :=
        Save.After_Write (Context.Output, Result, Count, Strict => False);
      return Result;
   end Flush_Output;

   --  xmlOutputBufferWrite of a serialization: the bytes are kept, and
   --  reach the target once MINLEN of them are pending.
   procedure Add_Output
     (Ctxt, Bytes : System.Address; Length : Natural)
   is
      Context : Save_Context with Import, Address => Ctxt;
      Status : Buffers.Add_Status;
      Count : Natural;
      Result : int;
      Ignored : Integer;
      use type Buffers.Add_Status;
   begin
      if Context.Output.Error /= 0 then
         return;
      end if;
      Buffers.Add (Context.Pending, Bytes, Length, Status);
      if Status /= Buffers.Added then
         Context.Output.Error := Save.No_Memory_Code;
         return;
      end if;
      while Save.Must_Write (Context.Pending.Used) loop
         Count := Context.Pending.Used;
         Result := Call_Write
           (Context, Buffers.Content (Context.Pending), Count);
         Context.Output :=
           Save.After_Write (Context.Output, Result, Count, Strict => True);
         exit when Context.Output.Error /= 0;
         Buffers.Shrink (Context.Pending, Save.Taken (Result, Count), Ignored);
      end loop;
   end Add_Output;

   --  xmlOutputBufferClose and the release of the context: a last flush,
   --  the close callback, and the result of the output.
   function Close_Output (Ctxt : System.Address) return Save.Output_State is
      Ignored : int;
      State : Save.Output_State;
   begin
      Ignored := Flush_Output (Ctxt);
      declare
         Context : Save_Context with Import, Address => Ctxt;
      begin
         case Context.Kind is
            when File_Target =>
               Context.Output :=
                 Save.After_Close (Context.Output, Fd_Close (Context.Fd));
            when IO_Target =>
               if Context.Close /= null then
                  Context.Output :=
                    Save.After_Close
                      (Context.Output, Context.Close (Context.Target));
               end if;
            when Buffer_Target | Fd_Target =>
               null;
         end case;
         State := Context.Output;
         Buffers.Release (Context.Pending);
      end;
      XML3_Native_Memory.Free (Ctxt);
      return State;
   end Close_Output;

   function Save_Node
     (Ctxt, Node : System.Address; Document_Only : Boolean)
      return Interfaces.C.long
   is
      Bytes : System.Address := System.Null_Address;
      Length : Natural := 0;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Refused
           (Guards.Save_Output, Ctxt /= System.Null_Address,
            Node /= System.Null_Address)
      then
         return -1;
      end if;
      declare
         Context : Save_Context with Import, Address => Ctxt;
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Save
              (Node,
               (if Context.Has_Encoding then Context.Encoding'Address
                else System.Null_Address),
               Document_Only, Context.Formatted, Context.Style,
               Bytes, Length, Status);
         end;
      end;
      if Status /= XML3_DOM_Constructors.Created then
         Report_Operation_Status (Status, Results.Node_Save);
         return -1;
      end if;
      Add_Output (Ctxt, Bytes, Length);
      XML3_Native_Memory.Free (Bytes);
      return 0;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Failure (Lock_Failure);
         return -1;
      when Storage_Error =>
         if Bytes /= System.Null_Address then
            XML3_Native_Memory.Free (Bytes);
         end if;
         Report_Failure (Allocation_Failure);
         return -1;
      when others =>
         if Bytes /= System.Null_Address then
            XML3_Native_Memory.Free (Bytes);
         end if;
         Report_Failure (Unexpected_Exception);
         return -1;
   end Save_Node;

   function Save_Doc (Ctxt, Doc : System.Address) return Interfaces.C.long is
     (Save_Node (Ctxt, Doc, Document_Only => True));

   function Save_Tree (Ctxt, Node : System.Address) return Interfaces.C.long
   is (Save_Node (Ctxt, Node, Document_Only => False));

   function Save_Flush (Ctxt : System.Address) return int is
   begin
      if Refused (Guards.Save_Use, Ctxt /= System.Null_Address) then
         return -1;
      end if;
      return Flush_Output (Ctxt);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Save_Flush;

   function Save_Close (Ctxt : System.Address) return int is
      Result : int;
      Ignored : Save.Output_State;
   begin
      if Refused (Guards.Save_Use, Ctxt /= System.Null_Address) then
         return -1;
      end if;
      Result := Flush_Output (Ctxt);
      Ignored := Close_Output (Ctxt);
      return Result;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Save_Close;

   function Save_Finish (Ctxt : System.Address) return int is
   begin
      if Refused (Guards.Save_Use, Ctxt /= System.Null_Address) then
         return Save.Missing_Context_Finish;
      end if;
      return Save.Finish_Code (Close_Output (Ctxt));
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return Save.Internal_Error_Code;
   end Save_Finish;

   function Save_Set_Indent_String (Ctxt, Indent : System.Address)
      return int
   is
      Length : XML3_Text.Byte_Count;
      Found : Boolean;
   begin
      if Refused (Guards.Save_Use, Ctxt /= System.Null_Address)
        or else Indent = System.Null_Address
      then
         return -1;
      end if;
      XML3_Text.Buffers.Measure (Indent, Length, Found);
      if not Found or else not Save.Indent_Accepted (Natural (Length)) then
         return -1;
      end if;
      declare
         Context : Save_Context with Import, Address => Ctxt;
         Text : String (1 .. Natural (Length)) with Import, Address => Indent;
      begin
         Context.Style.Indent_Unit (Text'Range) := Text;
         Context.Style.Unit_Size := Text'Length;
      end;
      return 0;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Save_Set_Indent_String;


   ------------------------------------------------------------------
   --  URI references (uri.h).  The components are found by the SPARK
   --  XML3_URIs.Parse; this part copies or unescapes them into the
   --  public struct and serializes it with XML3_URIs.Kept.
   ------------------------------------------------------------------

   type C_URI is record
      Scheme, Opaque, Authority, Server, User : System.Address;
      Port : int;
      Path, Query, Fragment : System.Address;
      Cleanup : int;
      Query_Raw : System.Address;
   end record with Convention => C;

   Empty_URI : constant C_URI :=
     (Scheme | Opaque | Authority | Server | User | Path | Query
        | Fragment | Query_Raw => System.Null_Address,
      Port => XML3_URIs.Port_Empty, Cleanup => 0);

   function Create_URI return System.Address is
      Result : System.Address;
   begin
      XML3_Native_Memory.Allocate
        (XML3_Native_Memory.Byte_Count (C_URI'Max_Size_In_Storage_Elements),
         Result);
      if Result /= System.Null_Address then
         declare
            Item : C_URI with Import, Address => Result;
         begin
            Item := Empty_URI;
         end;
      end if;
      return Result;
   end Create_URI;

   procedure Free_If_Set (Item : in out System.Address) is
   begin
      if Item /= System.Null_Address then
         XML3_Native_Memory.Free (Item);
         Item := System.Null_Address;
      end if;
   end Free_If_Set;

   --  xmlCleanURI: every string released, the port and flags kept.
   procedure Clean_URI (Item : in out C_URI) is
   begin
      Free_If_Set (Item.Scheme);
      Free_If_Set (Item.Server);
      Free_If_Set (Item.User);
      Free_If_Set (Item.Path);
      Free_If_Set (Item.Fragment);
      Free_If_Set (Item.Opaque);
      Free_If_Set (Item.Authority);
      Free_If_Set (Item.Query);
      Free_If_Set (Item.Query_Raw);
   end Clean_URI;

   procedure Free_URI (URI : System.Address) is
   begin
      if URI = System.Null_Address then
         return;
      end if;
      declare
         Item : C_URI with Import, Address => URI;
      begin
         Clean_URI (Item);
      end;
      XML3_Native_Memory.Free (URI);
   end Free_URI;

   --  xmlParse3986URIReference into Item: 0, 1 when the text is not a URI
   --  reference, -1 for a missing text or a failed allocation.
   function Parse_Into
     (Item : in out C_URI; Text : System.Address; Detached : Boolean := False)
      return int
   is
      Length : XML3_Text.Byte_Count;
      Found : Boolean;
      Parts : XML3_URIs.Parts;
      Ok : Boolean;
      Failed : Boolean := False;
      Raw : constant Boolean := (Item.Cleanup / 2) mod 2 = 1;

      --  The component of Span: a copy, or an unescaped copy unless the
      --  struct keeps components escaped (Keep_Escaped) or the flags do.
      function Component
        (S : XML3_URIs.Span; Keep_Escaped : Boolean := False)
         return System.Address
      is
         Start : System.Address;
         Count : Natural;
         Result : System.Address;
      begin
         if not S.Present then
            return System.Null_Address;
         end if;
         Start := XML3_Native_Memory.Offset
           (Text, XML3_Native_Memory.Byte_Count (S.First - 1));
         Count := S.Last - S.First + 1;
         if Raw or else Keep_Escaped then
            Result := Str_N_Duplicate (Start, int (Count));
         else
            --  As libxml2, an empty component is unescaped from its start
            --  to the end of the text (xmlURIUnescapeString with length 0).
            Result := URI_Unescape_String
              (Start, int (Count), System.Null_Address);
         end if;
         if Result = System.Null_Address then
            Failed := True;
         end if;
         return Result;
      end Component;
   begin
      if Text = System.Null_Address then
         return -1;
      end if;
      Clean_URI (Item);
      XML3_Text.Buffers.Measure (Text, Length, Found);
      if not Found or else Natural (Length) >= Natural'Last - 4 then
         return -1;
      end if;
      declare
         Input : String (1 .. Natural (Length)) with Import, Address => Text;
      begin
         XML3_URIs.Parse
           (Input, Item.Cleanup, Item.Port, Parts, Ok, Detached);
      end;
      Item.Port := Parts.Port;
      if not Ok then
         return 1;
      end if;
      Item.Scheme := Component (Parts.Scheme, Keep_Escaped => True);
      Item.Server := Component (Parts.Server);
      Item.User := Component (Parts.User);
      Item.Path := Component (Parts.Path);
      Item.Query := Component (Parts.Query);
      Item.Query_Raw := Component (Parts.Query, Keep_Escaped => True);
      Item.Fragment := Component (Parts.Fragment);
      if Failed then
         Clean_URI (Item);
         return -1;
      end if;
      return 0;
   end Parse_Into;

   function Parse_URI_Reference (URI, Text : System.Address) return int is
   begin
      if Text = System.Null_Address then
         return -1;
      end if;
      if URI = System.Null_Address then
         --  Only whether the text is a URI reference.
         declare
            Scratch : C_URI := Empty_URI;
            Result : constant int :=
              Parse_Into (Scratch, Text, Detached => True);
         begin
            Clean_URI (Scratch);
            return Result;
         end;
      end if;
      declare
         Item : C_URI with Import, Address => URI;
      begin
         return Parse_Into (Item, Text);
      end;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Parse_URI_Reference;

   function Parse_New_URI (Text : System.Address; Cleanup : int;
                           Code : out int) return System.Address
   is
      Result : System.Address;
   begin
      Result := Create_URI;
      if Result = System.Null_Address then
         Code := -1;
         return System.Null_Address;
      end if;
      declare
         Item : C_URI with Import, Address => Result;
      begin
         Item.Cleanup := Cleanup;
         Code := Parse_Into (Item, Text);
      end;
      if Code /= 0 then
         Free_URI (Result);
         return System.Null_Address;
      end if;
      return Result;
   end Parse_New_URI;

   function Parse_URI_Safe (Text, Output : System.Address) return int is
      Code : int;
      Result : System.Address;
   begin
      if Output = System.Null_Address then
         return 1;
      end if;
      Set_Address (Output, System.Null_Address);
      if Text = System.Null_Address then
         return 1;
      end if;
      Result := Parse_New_URI (Text, 0, Code);
      Set_Address (Output, Result);
      return Code;
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return -1;
   end Parse_URI_Safe;

   function Parse_URI (Text : System.Address) return System.Address is
      Code : int;
   begin
      if Text = System.Null_Address then
         return System.Null_Address;
      end if;
      return Parse_New_URI (Text, 0, Code);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Parse_URI;

   function Parse_URI_Raw (Text : System.Address; Raw : int)
      return System.Address
   is
      Code : int;
   begin
      if Text = System.Null_Address then
         return System.Null_Address;
      end if;
      return Parse_New_URI
        (Text, (if Raw /= 0 then XML3_URIs.No_Unescape else 0), Code);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Parse_URI_Raw;

   function Save_URI (URI : System.Address) return System.Address is
      use Ada.Strings.Unbounded;
      Output : Unbounded_String;
      Hex : constant String := "0123456789ABCDEF";

      function Text_Of (Item : System.Address) return String is
         Length : XML3_Text.Byte_Count;
         Found : Boolean;
      begin
         XML3_Text.Buffers.Measure (Item, Length, Found);
         if not Found then
            raise Constraint_Error;
         end if;
         declare
            Value : String (1 .. Natural (Length))
              with Import, Address => Item;
         begin
            return Value;
         end;
      end Text_Of;

      procedure Put_Escaped
        (Component : XML3_URIs.Save_Component; Value : String) is
      begin
         for C of Value loop
            if XML3_URIs.Kept (Component, C) then
               Append (Output, C);
            else
               Append (Output, '%');
               Append (Output, Hex (Character'Pos (C) / 16 + 1));
               Append (Output, Hex (Character'Pos (C) mod 16 + 1));
            end if;
         end loop;
      end Put_Escaped;

      Result : System.Address;
   begin
      if URI = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Item : C_URI with Import, Address => URI;
         Null_Address : constant System.Address := System.Null_Address;
      begin
         if Item.Scheme /= Null_Address then
            Append (Output, Text_Of (Item.Scheme));
            Append (Output, ':');
         end if;
         if Item.Opaque /= Null_Address then
            Put_Escaped (XML3_URIs.Opaque_Part, Text_Of (Item.Opaque));
         else
            if Item.Server /= Null_Address
              or else Item.Port /= XML3_URIs.Port_Empty
            then
               Append (Output, "//");
               if Item.User /= Null_Address then
                  Put_Escaped (XML3_URIs.User_Part, Text_Of (Item.User));
                  Append (Output, '@');
               end if;
               if Item.Server /= Null_Address then
                  Append (Output, Text_Of (Item.Server));
               end if;
               if Item.Port > 0 then
                  declare
                     Image : constant String := int'Image (Item.Port);
                  begin
                     Append (Output, ':');
                     Append (Output, Image (Image'First + 1 .. Image'Last));
                  end;
               end if;
            elsif Item.Authority /= Null_Address then
               Append (Output, "//");
               Put_Escaped
                 (XML3_URIs.Authority_Part, Text_Of (Item.Authority));
            end if;
            if Item.Path /= Null_Address then
               declare
                  Path : constant String := Text_Of (Item.Path);
                  From : Positive := 1;
               begin
                  --  file:///d: keeps the drive colon.
                  if Item.Scheme /= Null_Address
                    and then Path'Length >= 3
                    and then Path (1) = '/'
                    and then Path (2) in 'a' .. 'z' | 'A' .. 'Z'
                    and then Path (3) = ':'
                    and then Text_Of (Item.Scheme) = "file"
                  then
                     Append (Output, Path (1 .. 3));
                     From := 4;
                  end if;
                  Put_Escaped (XML3_URIs.Path_Part, Path (From .. Path'Last));
               end;
            end if;
            if Item.Query_Raw /= Null_Address then
               Append (Output, '?');
               Append (Output, Text_Of (Item.Query_Raw));
            elsif Item.Query /= Null_Address then
               Append (Output, '?');
               Put_Escaped (XML3_URIs.Query_Part, Text_Of (Item.Query));
            end if;
         end if;
         if Item.Fragment /= Null_Address then
            Append (Output, '#');
            Put_Escaped (XML3_URIs.Fragment_Part, Text_Of (Item.Fragment));
         end if;
      end;
      declare
         Value : constant String := To_String (Output);
      begin
         XML3_Native_Memory.Allocate
           (XML3_Native_Memory.Byte_Count (Value'Length + 1), Result);
         if Result = System.Null_Address then
            return System.Null_Address;
         end if;
         XML3_Native_Memory.Write_String (Result, 0, Value);
         XML3_Native_Memory.Write_Byte (Result, Value'Length, Character'Val (0));
      end;
      return Result;
   exception
      when others =>
         return System.Null_Address;
   end Save_URI;

   function C_Fputs (Text, Stream : System.Address) return int
     with Import, Convention => C, External_Name => "fputs";

   procedure Print_URI (Stream, URI : System.Address) is
      Text : System.Address := Save_URI (URI);
      Ignored : int;
   begin
      if Text /= System.Null_Address then
         Ignored := C_Fputs (Text, Stream);
         XML3_Native_Memory.Free (Text);
      end if;
   end Print_URI;


   ------------------------------------------------------------------
   --  URI resolution and conversion, following libxml2's uri.c on the
   --  parsed structs; paths are normalized by the SPARK
   --  XML3_URIs.Normalize_Path.
   ------------------------------------------------------------------

   --  A C string's bytes; Constraint_Error for one too long to measure.
   function C_Text (Item : System.Address) return String is
      Length : XML3_Text.Byte_Count;
      Found : Boolean;
   begin
      XML3_Text.Buffers.Measure (Item, Length, Found);
      if not Found then
         raise Constraint_Error;
      end if;
      declare
         Value : String (1 .. Natural (Length)) with Import, Address => Item;
      begin
         return Value;
      end;
   end C_Text;

   --  A new NUL-terminated copy of Value, or null when it cannot be made.
   function New_C_String (Value : String) return System.Address is
      Result : System.Address;
   begin
      XML3_Native_Memory.Allocate
        (XML3_Native_Memory.Byte_Count (Value'Length + 1), Result);
      if Result /= System.Null_Address then
         XML3_Native_Memory.Write_String (Result, 0, Value);
         XML3_Native_Memory.Write_Byte
           (Result, Value'Length, Character'Val (0));
      end if;
      return Result;
   end New_C_String;

   function Has_Scheme_Separator (Value : String) return Boolean is
     (Ada.Strings.Fixed.Index (Value, "://") /= 0);

   function Normalized (Value : String; Is_File : Boolean) return String is
      Buffer : String (1 .. Natural'Max (Value'Length, 1)) :=
        (others => ' ');
      Last : Natural;
   begin
      Buffer (1 .. Value'Length) := Value;
      XML3_URIs.Normalize_Path (Buffer, Value'Length, Is_File, Last);
      return Buffer (1 .. Last);
   end Normalized;

   --  A copy of a C string field (null stays null); Failed records a
   --  copy that could not be made.
   function Copy_Field
     (Item : System.Address; Failed : in out Boolean) return System.Address
   is
      Result : System.Address;
   begin
      if Item = System.Null_Address then
         return System.Null_Address;
      end if;
      Result := Str_Duplicate (Item);
      if Result = System.Null_Address then
         Failed := True;
      end if;
      return Result;
   end Copy_Field;

   function Set_Field
     (Value : String; Failed : in out Boolean) return System.Address
   is
      Result : constant System.Address := New_C_String (Value);
   begin
      if Result = System.Null_Address then
         Failed := True;
      end if;
      return Result;
   end Set_Field;

   --  xmlResolvePath: a reference against a base that is a file path.
   function Resolve_Path (Escaped, Base, Output : System.Address) return int
   is
      Ref, Result : Ada.Strings.Unbounded.Unbounded_String;
      Fragment_At : Natural;
      use Ada.Strings.Unbounded;
   begin
      if Escaped = System.Null_Address or else C_Text (Escaped) = "" then
         if Base = System.Null_Address or else C_Text (Base) = "" then
            return 1;
         end if;
         declare
            Copy : constant System.Address := Str_Duplicate (Base);
         begin
            Set_Address (Output, Copy);
            return (if Copy = System.Null_Address then -1 else 0);
         end;
      end if;
      declare
         Text : constant String := C_Text (Escaped);
         Before : System.Address;
         Unescaped : System.Address;
      begin
         --  The part before the fragment is unescaped.
         Fragment_At := Ada.Strings.Fixed.Index (Text, "#");
         Before := New_C_String
           (if Fragment_At = 0 then Text
            else Text (Text'First .. Fragment_At - 1));
         if Before = System.Null_Address then
            return -1;
         end if;
         Unescaped := URI_Unescape_String (Before, -1, System.Null_Address);
         XML3_Native_Memory.Free (Before);
         if Unescaped = System.Null_Address then
            return -1;
         end if;
         Ref := To_Unbounded_String (C_Text (Unescaped));
         XML3_Native_Memory.Free (Unescaped);
         Result := Ref;
         if Base /= System.Null_Address and then C_Text (Base) /= ""
           and then not (Length (Ref) > 0 and then Element (Ref, 1) = '/')
         then
            declare
               Base_Text : constant String := C_Text (Base);
               I : Natural := Base_Text'Length;
            begin
               --  Remove the last segment of the base.
               while I > 0 and then Base_Text (I) /= '/' loop
                  I := I - 1;
               end loop;
               if I > 0 then
                  Result := To_Unbounded_String
                    (Normalized (Base_Text (1 .. I) & To_String (Ref),
                                 Is_File => True));
               end if;
            end;
         end if;
         if Fragment_At /= 0 then
            Append (Result, Text (Fragment_At .. Text'Last));
         end if;
      end;
      declare
         Copy : constant System.Address := New_C_String (To_String (Result));
      begin
         Set_Address (Output, Copy);
         return (if Copy = System.Null_Address then -1 else 0);
      end;
   end Resolve_Path;

   function Build_URI_Safe (URI, Base, Output : System.Address) return int
   is
      Ref, Bas, Res : C_URI := Empty_URI;
      Has_Ref : Boolean := False;
      Value : System.Address := System.Null_Address;
      Ret : int;
      Failed : Boolean := False;
      Null_Address : constant System.Address := System.Null_Address;

      function Save (Item : in out C_URI) return System.Address is
         Item_Address : constant System.Address := Item'Address;
      begin
         return Save_URI (Item_Address);
      end Save;

      procedure Finish is
      begin
         Clean_URI (Ref);
         Clean_URI (Bas);
         Clean_URI (Res);
      end Finish;
   begin
      if Output = Null_Address then
         return 1;
      end if;
      Set_Address (Output, Null_Address);
      if URI = Null_Address then
         return 1;
      end if;
      if Base = Null_Address then
         Value := Str_Duplicate (URI);
         Set_Address (Output, Value);
         return (if Value = Null_Address then -1 else 0);
      end if;
      if C_Text (URI) /= "" then
         Ret := Parse_Into (Ref, URI);
         if Ret /= 0 then
            Finish;
            return Ret;
         end if;
         Has_Ref := True;
      end if;
      if Has_Ref and then Ref.Scheme /= Null_Address then
         --  An absolute URI is returned as it is.
         Finish;
         Value := Str_Duplicate (URI);
         Set_Address (Output, Value);
         return (if Value = Null_Address then -1 else 0);
      end if;
      if not Has_Scheme_Separator (C_Text (Base)) then
         --  A base without a scheme and authority is a file path.
         Finish;
         return Resolve_Path (URI, Base, Output);
      end if;
      Ret := Parse_Into (Bas, Base);
      if Ret < 0 then
         Finish;
         return Ret;
      elsif Ret /= 0 then
         if Has_Ref then
            Value := Save (Ref);
            Ret := (if Value = Null_Address then -1 else 0);
         end if;
         Finish;
         Set_Address (Output, Value);
         return Ret;
      end if;
      if not Has_Ref then
         --  The base without its fragment.
         Free_If_Set (Bas.Fragment);
         Value := Save (Bas);
         Finish;
         Set_Address (Output, Value);
         return (if Value = Null_Address then -1 else 0);
      end if;

      if Ref.Scheme = Null_Address and then Ref.Path = Null_Address
        and then Ref.Authority = Null_Address
        and then Ref.Server = Null_Address
        and then Ref.Port = XML3_URIs.Port_Empty
      then
         --  2) A reference to the current document.
         Res.Scheme := Copy_Field (Bas.Scheme, Failed);
         if Bas.Authority /= Null_Address then
            Res.Authority := Copy_Field (Bas.Authority, Failed);
         else
            Res.Server := Copy_Field (Bas.Server, Failed);
            Res.User := Copy_Field (Bas.User, Failed);
            Res.Port := Bas.Port;
         end if;
         Res.Path := Copy_Field (Bas.Path, Failed);
         if Ref.Query_Raw /= Null_Address then
            Res.Query_Raw := Copy_Field (Ref.Query_Raw, Failed);
         elsif Ref.Query /= Null_Address then
            Res.Query := Copy_Field (Ref.Query, Failed);
         elsif Bas.Query_Raw /= Null_Address then
            Res.Query_Raw := Copy_Field (Bas.Query_Raw, Failed);
         elsif Bas.Query /= Null_Address then
            Res.Query := Copy_Field (Bas.Query, Failed);
         end if;
         Res.Fragment := Copy_Field (Ref.Fragment, Failed);
      else
         --  3) The scheme of the base.
         Res.Scheme := Copy_Field (Bas.Scheme, Failed);
         if Ref.Query_Raw /= Null_Address then
            Res.Query_Raw := Copy_Field (Ref.Query_Raw, Failed);
         elsif Ref.Query /= Null_Address then
            Res.Query := Copy_Field (Ref.Query, Failed);
         end if;
         Res.Fragment := Copy_Field (Ref.Fragment, Failed);
         if Ref.Authority /= Null_Address or else Ref.Server /= Null_Address
           or else Ref.Port /= XML3_URIs.Port_Empty
         then
            --  4) A network-path reference.
            if Ref.Authority /= Null_Address then
               Res.Authority := Copy_Field (Ref.Authority, Failed);
            else
               Res.Server := Copy_Field (Ref.Server, Failed);
               Res.User := Copy_Field (Ref.User, Failed);
               Res.Port := Ref.Port;
            end if;
            Res.Path := Copy_Field (Ref.Path, Failed);
         else
            if Bas.Authority /= Null_Address then
               Res.Authority := Copy_Field (Bas.Authority, Failed);
            elsif Bas.Server /= Null_Address
              or else Bas.Port /= XML3_URIs.Port_Empty
            then
               Res.Server := Copy_Field (Bas.Server, Failed);
               Res.User := Copy_Field (Bas.User, Failed);
               Res.Port := Bas.Port;
            end if;
            if Ref.Path /= Null_Address and then C_Text (Ref.Path) /= ""
              and then C_Text (Ref.Path) (1) = '/'
            then
               --  5) An absolute-path reference.
               Res.Path := Copy_Field (Ref.Path, Failed);
            else
               --  6) Merge with the base path and normalize.
               declare
                  use Ada.Strings.Unbounded;
                  Merged : Unbounded_String;
                  Base_Path : constant String :=
                    (if Bas.Path = Null_Address then "" else C_Text (Bas.Path));
                  Last_Slash : Natural := 0;
               begin
                  for I in Base_Path'Range loop
                     if Base_Path (I) = '/' then
                        Last_Slash := I;
                     end if;
                  end loop;
                  Merged := To_Unbounded_String (Base_Path (1 .. Last_Slash));
                  if Ref.Path /= Null_Address and then C_Text (Ref.Path) /= ""
                  then
                     if Last_Slash = 0
                       and then (Bas.Server /= Null_Address
                                 or else Bas.Port /= XML3_URIs.Port_Empty)
                     then
                        Append (Merged, '/');
                     end if;
                     Append (Merged, C_Text (Ref.Path));
                  end if;
                  Res.Path := Set_Field
                    (Normalized (To_String (Merged), Is_File => False),
                     Failed);
               end;
            end if;
         end if;
      end if;
      --  7) Recombine.
      if not Failed then
         Value := Save (Res);
      end if;
      Finish;
      Set_Address (Output, Value);
      return (if Value = Null_Address then -1 else 0);
   exception
      when others =>
         Finish;
         Report_Failure (Unexpected_Exception);
         return -1;
   end Build_URI_Safe;

   function Build_URI (URI, Base : System.Address) return System.Address is
      Result : aliased System.Address := System.Null_Address;
      Ignored : int;
   begin
      Ignored := Build_URI_Safe (URI, Base, Result'Address);
      return Result;
   end Build_URI;

   --  xmlParseUriOrPath: a file path (no "://") normalized as a path,
   --  otherwise a URI reference with its path normalized.
   function Parse_URI_Or_Path (Text : System.Address; Item : in out C_URI)
      return int
   is
      Value : constant String := C_Text (Text);
      Failed : Boolean := False;
      Ret : int;
   begin
      if not Has_Scheme_Separator (Value) then
         Item.Path := Set_Field (Normalized (Value, Is_File => True), Failed);
         return (if Failed then -1 else 0);
      end if;
      Ret := Parse_Into (Item, Text);
      if Ret /= 0 then
         return Ret;
      end if;
      if Item.Path /= System.Null_Address then
         declare
            Path : constant String :=
              Normalized (C_Text (Item.Path), Is_File => False);
         begin
            Free_If_Set (Item.Path);
            Item.Path := Set_Field (Path, Failed);
         end;
      end if;
      return (if Failed then -1 else 0);
   end Parse_URI_Or_Path;

   function Build_Relative_URI_Safe (URI, Base, Output : System.Address)
      return int
   is
      Ref, Bas : C_URI := Empty_URI;
      Value : System.Address := System.Null_Address;
      Ret : int := 0;
      Null_Address : constant System.Address := System.Null_Address;
      --  The relative form, before the escaping of xmlSaveUri's
      --  exceptions; Pending when it is still to be computed.
      Relative : Ada.Strings.Unbounded.Unbounded_String;
      Have_Relative, Escape_Relative : Boolean := False;
      Exceptions : aliased constant char_array := To_C ("/;&=+$,");
      use Ada.Strings.Unbounded;

      function Equal_Fields (Left, Right : System.Address) return Boolean is
        (if Left = Null_Address or else Right = Null_Address
         then Left = Right
         else C_Text (Left) = C_Text (Right));
   begin
      if Output = Null_Address then
         return 1;
      end if;
      Set_Address (Output, Null_Address);
      if URI = Null_Address or else C_Text (URI) = "" then
         return 1;
      end if;
      Ret := Parse_URI_Or_Path (URI, Ref);
      if Ret < 0 then
         Clean_URI (Ref);
         return Ret;
      elsif Ret /= 0 then
         --  An invalid URI is returned as it is.
         Clean_URI (Ref);
         Value := Str_Duplicate (URI);
         Set_Address (Output, Value);
         return (if Value = Null_Address then -1 else 0);
      end if;
      if Base /= Null_Address and then C_Text (Base) /= "" then
         Ret := Parse_URI_Or_Path (Base, Bas);
         if Ret < 0 then
            Clean_URI (Ref);
            Clean_URI (Bas);
            return Ret;
         end if;
         if Ret = 0
           and then Equal_Fields (Bas.Scheme, Ref.Scheme)
           and then Equal_Fields (Bas.Server, Ref.Server)
           and then Bas.Port = Ref.Port
         then
            if Equal_Fields (Bas.Path, Ref.Path) then
               Relative := Null_Unbounded_String;
               Have_Relative := True;
            elsif Bas.Path = Null_Address then
               Relative := To_Unbounded_String (C_Text (Ref.Path));
               Have_Relative := True;
               Escape_Relative := True;
            else
               declare
                  B : constant String := C_Text (Bas.Path);
                  R : constant String :=
                    (if Ref.Path = Null_Address then "/"
                     else C_Text (Ref.Path));
                  Pos : Natural := 0;
                  Ix : Natural;
                  Slashes : Natural := 0;
                  function B_At (I : Natural) return Character is
                    (if I < B'Length then B (I + 1) else Character'Val (0));
                  function R_At (I : Natural) return Character is
                    (if I < R'Length then R (I + 1) else Character'Val (0));
               begin
                  if (B_At (0) = '/') = (R_At (0) = '/') then
                     while B_At (Pos) = R_At (Pos)
                       and then B_At (Pos) /= Character'Val (0)
                     loop
                        Pos := Pos + 1;
                     end loop;
                     if B_At (Pos) = R_At (Pos) then
                        Relative := Null_Unbounded_String;
                        Have_Relative := True;
                     else
                        Ix := Pos;
                        while Ix > 0 and then R_At (Ix - 1) /= '/' loop
                           Ix := Ix - 1;
                        end loop;
                        declare
                           Unique : constant String := R (Ix + 1 .. R'Last);
                        begin
                           for I in Ix .. B'Length - 1 loop
                              if B_At (I) = '/' then
                                 Slashes := Slashes + 1;
                              end if;
                           end loop;
                           if Slashes = 0 and then Unique = "" then
                              Relative := To_Unbounded_String ("./");
                              Have_Relative := True;
                           elsif Slashes = 0 then
                              Relative := To_Unbounded_String (Unique);
                              Have_Relative := True;
                              Escape_Relative := True;
                           else
                              for I in 1 .. Slashes loop
                                 Append (Relative, "../");
                              end loop;
                              if Unique'Length > 0
                                and then Unique (Unique'First) = '/'
                              then
                                 Append
                                   (Relative,
                                    Unique (Unique'First + 1 .. Unique'Last));
                              else
                                 Append (Relative, Unique);
                              end if;
                              Have_Relative := True;
                              Escape_Relative := True;
                           end if;
                        end;
                     end if;
                  end if;
               end;
            end if;
         end if;
      end if;
      if Have_Relative and then Escape_Relative then
         declare
            Plain : constant System.Address :=
              New_C_String (To_String (Relative));
         begin
            if Plain /= Null_Address then
               Value := URI_Escape_Str (Plain, Exceptions'Address);
               XML3_Native_Memory.Free (Plain);
            end if;
            Ret := (if Value = Null_Address then -1 else 0);
         end;
      elsif Have_Relative then
         Value := New_C_String (To_String (Relative));
         Ret := (if Value = Null_Address then -1 else 0);
      else
         --  The reference itself.
         declare
            Item : C_URI := Ref;
         begin
            Value := Save_URI (Item'Address);
            Ret := (if Value = Null_Address then -1 else 0);
         end;
      end if;
      Clean_URI (Ref);
      Clean_URI (Bas);
      Set_Address (Output, Value);
      return Ret;
   exception
      when others =>
         Clean_URI (Ref);
         Clean_URI (Bas);
         Report_Failure (Unexpected_Exception);
         return -1;
   end Build_Relative_URI_Safe;

   function Build_Relative_URI (URI, Base : System.Address)
      return System.Address
   is
      Result : aliased System.Address := System.Null_Address;
      Ignored : int;
   begin
      Ignored := Build_Relative_URI_Safe (URI, Base, Result'Address);
      return Result;
   end Build_Relative_URI;

   function Canonic_Path (Path : System.Address) return System.Address is
      Kept : aliased constant char_array := To_C (":/?#[]@!$&()*+,;='%");
   begin
      if Path = System.Null_Address then
         return System.Null_Address;
      end if;
      if Has_Scheme_Separator (C_Text (Path)) then
         return URI_Escape_Str (Path, Kept'Address);
      end if;
      return Str_Duplicate (Path);
   exception
      when others =>
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end Canonic_Path;

   function Path_To_URI (Path : System.Address) return System.Address is
     (Canonic_Path (Path));

   function URI_Escape (Text : System.Address) return System.Address is
      Item : C_URI := Empty_URI;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Any : Boolean := False;
      Failed : Boolean := False;
      use Ada.Strings.Unbounded;

      procedure Put_Escaped (Field : System.Address; Kept : String) is
         List : aliased constant char_array := To_C (Kept);
         Escaped : System.Address;
      begin
         Escaped := URI_Escape_Str (Field, List'Address);
         if Escaped = System.Null_Address then
            Failed := True;
            return;
         end if;
         Append (Result, C_Text (Escaped));
         XML3_Native_Memory.Free (Escaped);
      end Put_Escaped;

      procedure Put (Value : String) is
      begin
         Append (Result, Value);
         Any := True;
      end Put;
   begin
      if Text = System.Null_Address then
         return System.Null_Address;
      end if;
      --  Unwise characters are allowed in the unescaped form.
      Item.Cleanup := XML3_URIs.Allow_Unwise;
      if Parse_Into (Item, Text) /= 0 then
         Clean_URI (Item);
         return System.Null_Address;
      end if;
      if Item.Scheme /= System.Null_Address then
         Put_Escaped (Item.Scheme, "+-.");
         Put (":");
      end if;
      if Item.Authority /= System.Null_Address then
         Put ("//");
         Put_Escaped (Item.Authority, "/?;:@");
      end if;
      if Item.User /= System.Null_Address then
         Put ("//");
         Put_Escaped (Item.User, ";:&=+$,");
         Put ("@");
      end if;
      if Item.Server /= System.Null_Address then
         if Item.User = System.Null_Address then
            Put ("//");
         end if;
         Put_Escaped (Item.Server, "/?;:@");
         Any := True;
      end if;
      if Item.Port > 0 then
         declare
            Image : constant String := int'Image (Item.Port);
         begin
            Put (":" & Image (Image'First + 1 .. Image'Last));
         end;
      end if;
      if Item.Path /= System.Null_Address then
         Put_Escaped (Item.Path, ":@&=+$,/?;");
         Any := True;
      end if;
      if Item.Query_Raw /= System.Null_Address then
         Put ("?" & C_Text (Item.Query_Raw));
      elsif Item.Query /= System.Null_Address then
         Put ("?");
         Put_Escaped (Item.Query, ";/?:@&=+,$");
      end if;
      if Item.Opaque /= System.Null_Address then
         Put_Escaped (Item.Opaque, "");
         Any := True;
      end if;
      if Item.Fragment /= System.Null_Address then
         Put ("#");
         Put_Escaped (Item.Fragment, "#");
      end if;
      Clean_URI (Item);
      if Failed or else not Any then
         return System.Null_Address;
      end if;
      return New_C_String (To_String (Result));
   exception
      when others =>
         Clean_URI (Item);
         Report_Failure (Unexpected_Exception);
         return System.Null_Address;
   end URI_Escape;

end XML3_C;
