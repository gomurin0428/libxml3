with GNAT.Threads;
pragma Unreferenced (GNAT.Threads);
with Interfaces.C; use Interfaces.C;
with Interfaces;
with System.Storage_Elements; use System.Storage_Elements;
with XML3_DOM;
with XML3_DOM_Constructors;
with XML3_DOM_Lock;
with XML3_DOM_Runtime;
with XML3_DOM_Store;
with XML3_DOM_Store.Documents;
with XML3_DOM_Store.Queries;
with XML3_Encoding;
with XML3_Errors;
with XML3_Namespaces;
with XML3_Parser;
with XML3_Text;
with XML3_Text.Buffers;
with XML3_Text.QNames;

package body XML3_C is
   use type System.Address;
   use type Interfaces.Unsigned_32;
   use type XML3_Encoding.Encoding_Kind;
   use type XML3_Encoding.Conversion_Status;
   use type XML3_DOM_Constructors.Construction_Status;
   use type XML3_DOM_Store.Documents.Read_Status;
   use type XML3_DOM_Store.Queries.XML_Property_Kind;
   use type XML3_DOM_Store.Queries.Space_Policy;

   Max_Input : constant := XML3_Text.Max_Bytes;
   Initial_Arena : constant := 2_048;
   Allowed_Options : constant Interfaces.Unsigned_32 := 16#0008_0860#;
   Arena_Status : constant int := -1;

   Parser_Node_Bytes : constant Storage_Offset :=
     XML3_Parser.Node'Max_Size_In_Storage_Elements;
   Name_Bytes : constant Storage_Offset :=
     XML3_Namespaces.Name_Info'Max_Size_In_Storage_Elements;

   Invalid_C_String : exception;

   function Multiply_Size (Left, Right : size_t) return size_t;
   function To_Storage_Offset_Checked (Value : size_t) return Storage_Offset;

   function C_Malloc (Size : size_t) return System.Address
     with Import, Convention => C, External_Name => "malloc";

   procedure C_Free (Item : System.Address)
     with Import, Convention => C, External_Name => "free";

   function Byte_At (Base : System.Address; Offset : Natural) return Character;
   function Scan_Length (Item : System.Address; Limit : Natural) return Integer;
   function To_String (Item : System.Address; Length : Natural) return String;
   function C_String_Value
     (Item : System.Address; Default : String := "") return String;
   procedure Set_Status (Target : System.Address; Value : int);
   procedure Set_Address
     (Target : System.Address; Value : System.Address);
   procedure Report_Dom_Error (Code : int);
   procedure Report_Operation_Status
     (Status : XML3_DOM_Store.Operation_Status;
      Validation_Error : Boolean := True);
   procedure Build
     (Input : String; Huge : Boolean; Encoding : XML3_Encoding.Encoding_Info;
      Result : out System.Address; Status : out int;
      Diagnostic : out XML3_Parser.Diagnostic_Info);
   function Parse_Buffer
     (Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int;
      Status : out int) return System.Address;

   function Byte_At (Base : System.Address; Offset : Natural) return Character
   is
      Item : Character
        with Import,
          Address => Base + To_Storage_Offset_Checked (size_t (Offset));
   begin
      return Item;
   end Byte_At;

   function Multiply_Size (Left, Right : size_t) return size_t is
   begin
      if Right /= 0 and then Left > size_t'Last / Right then
         raise Storage_Error;
      end if;
      return Left * Right;
   end Multiply_Size;

   function To_Storage_Offset_Checked (Value : size_t) return Storage_Offset is
   begin
      if Value > size_t (Storage_Offset'Last) then
         raise Storage_Error;
      end if;
      return Storage_Offset (Value);
   end To_Storage_Offset_Checked;

   function Scan_Length (Item : System.Address; Limit : Natural) return Integer
   is
   begin
      if Item = System.Null_Address or else Limit = 0 then
         return -1;
      end if;
      for Offset in 0 .. Limit - 1 loop
         if Byte_At (Item, Offset) = Character'Val (0) then
            return Offset;
         end if;
      end loop;
      return -1;
   end Scan_Length;

   function To_String (Item : System.Address; Length : Natural) return String is
      Source : String (1 .. Length) with Import, Address => Item;
   begin
      return Source;
   end To_String;

   function C_String_Value
     (Item : System.Address; Default : String := "") return String
   is
      Length : Integer;
   begin
      if Item = System.Null_Address then
         return Default;
      end if;
      Length := Scan_Length (Item, Max_Input + 1);
      if Length < 0 then
         raise Invalid_C_String;
      end if;
      return To_String (Item, Natural (Length));
   end C_String_Value;

   function C_String_Prefix
     (Item : System.Address; Limit : Interfaces.C.int) return String
   is
      Length : Integer;
   begin
      if Item = System.Null_Address or else Limit = 0 then
         return "";
      elsif Limit < 0 then
         return C_String_Value (Item);
      elsif Limit > Max_Input then
         raise Invalid_C_String;
      end if;
      Length := Scan_Length (Item, Natural (Limit));
      return To_String
        (Item, (if Length < 0 then Natural (Limit) else Natural (Length)));
   end C_String_Prefix;

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

   procedure Report_Dom_Error (Code : int) is
   begin
      XML3_Errors.Report_Simple (2, Code, 3, System.Null_Address);
   end Report_Dom_Error;

   procedure Report_Operation_Status
     (Status : XML3_DOM_Store.Operation_Status;
      Validation_Error : Boolean := True)
   is
   begin
      case Status is
         when XML3_DOM_Constructors.Created =>
            null;
         when XML3_DOM_Constructors.Invalid_Argument =>
            if Validation_Error then
               Report_Dom_Error (115);
            end if;
         when XML3_DOM_Constructors.No_Memory =>
            XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         when XML3_DOM_Constructors.Limit_Exceeded =>
            XML3_Errors.Report_Simple (1, 114, 3, System.Null_Address);
         when XML3_DOM_Constructors.Internal_Error =>
            Report_Dom_Error (1);
      end case;
   end Report_Operation_Status;

   procedure Build_Arena
     (Input : String; Huge : Boolean; Encoding : XML3_Encoding.Encoding_Info;
      Capacity : Positive; Nodes_Buffer, Names_Buffer,
      Scratch_A_Buffer, Scratch_B_Buffer : System.Address;
      Result : out System.Address; Status : out int;
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
      Read_Status : XML3_DOM_Store.Documents.Read_Status;
   begin
      Result := System.Null_Address;
      Status := Status_Internal_Error;
      Diagnostic :=
        (Domain => 1, Code => 0, Level => 0, Byte_Position => 1,
         Int1 => 0, Int2 => 0);
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Read
           (Input, Huge, Encoding, Nodes, Names, Scratch_A, Scratch_B,
            Result, Read_Status, Diagnostic);
      end;
      case Read_Status is
         when XML3_DOM_Store.Documents.Parsed =>
            Status := Status_OK;
         when XML3_DOM_Store.Documents.Malformed =>
            Status := Status_Malformed;
         when XML3_DOM_Store.Documents.Unsupported =>
            Status := Status_Unsupported;
         when XML3_DOM_Store.Documents.Limit_Exceeded =>
            Status := Status_Limit_Exceeded;
         when XML3_DOM_Store.Documents.Arena_Exhausted =>
            Status := Arena_Status;
         when XML3_DOM_Store.Documents.No_Memory =>
            Status := Status_No_Memory;
         when XML3_DOM_Store.Documents.Internal_Error =>
            Status := Status_Internal_Error;
      end case;
   exception
      when Storage_Error =>
         Result := System.Null_Address;
         Status := Status_No_Memory;
      when XML3_DOM_Lock.Lock_Error =>
         Result := System.Null_Address;
         Status := Status_Internal_Error;
      when others =>
         Result := System.Null_Address;
         Status := Status_Internal_Error;
   end Build_Arena;

   procedure Build
     (Input : String; Huge : Boolean; Encoding : XML3_Encoding.Encoding_Info;
      Result : out System.Address; Status : out int;
      Diagnostic : out XML3_Parser.Diagnostic_Info)
   is
      Capacity : Natural := Natural'Max
        (1, Natural'Min (Initial_Arena, Input'Length));
      Nodes_Buffer : System.Address := System.Null_Address;
      Names_Buffer : System.Address := System.Null_Address;
      Scratch_A_Buffer : System.Address := System.Null_Address;
      Scratch_B_Buffer : System.Address := System.Null_Address;

      procedure Free_Workspaces is
      begin
         if Nodes_Buffer /= System.Null_Address then
            C_Free (Nodes_Buffer);
            Nodes_Buffer := System.Null_Address;
         end if;
         if Names_Buffer /= System.Null_Address then
            C_Free (Names_Buffer);
            Names_Buffer := System.Null_Address;
         end if;
         if Scratch_A_Buffer /= System.Null_Address then
            C_Free (Scratch_A_Buffer);
            Scratch_A_Buffer := System.Null_Address;
         end if;
         if Scratch_B_Buffer /= System.Null_Address then
            C_Free (Scratch_B_Buffer);
            Scratch_B_Buffer := System.Null_Address;
         end if;
      end Free_Workspaces;
   begin
      Result := System.Null_Address;
      Status := Status_Internal_Error;
      Diagnostic :=
        (Domain => 1, Code => 0, Level => 0, Byte_Position => 1,
         Int1 => 0, Int2 => 0);
      loop
         Nodes_Buffer := C_Malloc
           (Multiply_Size (size_t (Capacity), size_t (Parser_Node_Bytes)));
         Names_Buffer := C_Malloc
           (Multiply_Size (size_t (Capacity), size_t (Name_Bytes)));
         Scratch_A_Buffer := C_Malloc
           (size_t (Natural'Max (1, Input'Length)));
         Scratch_B_Buffer := C_Malloc
           (size_t (Natural'Max (1, Input'Length)));
         if Nodes_Buffer = System.Null_Address
           or else Names_Buffer = System.Null_Address
           or else Scratch_A_Buffer = System.Null_Address
           or else Scratch_B_Buffer = System.Null_Address
         then
            Free_Workspaces;
            Status := Status_No_Memory;
            return;
         end if;
         Build_Arena
           (Input, Huge, Encoding, Positive (Capacity), Nodes_Buffer,
            Names_Buffer, Scratch_A_Buffer, Scratch_B_Buffer, Result, Status,
            Diagnostic);
         Free_Workspaces;
         exit when Status /= Arena_Status;
         if Capacity = XML3_Parser.Max_Nodes then
            Status := Status_Limit_Exceeded;
            return;
         elsif Capacity > XML3_Parser.Max_Nodes / 2 then
            Capacity := XML3_Parser.Max_Nodes;
         else
            Capacity := Capacity * 2;
         end if;
      end loop;
   exception
      when Storage_Error =>
         Free_Workspaces;
         Result := System.Null_Address;
         Status := Status_No_Memory;
      when others =>
         Free_Workspaces;
         Result := System.Null_Address;
         Status := Status_Internal_Error;
   end Build;

   function Parse_Buffer
     (Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int;
      Status : out int) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Huge : Boolean := False;
      Diagnostic : XML3_Parser.Diagnostic_Info;
      Converted_Buffer : System.Address := System.Null_Address;

      procedure Free_Converted is
      begin
         if Converted_Buffer /= System.Null_Address then
            C_Free (Converted_Buffer);
            Converted_Buffer := System.Null_Address;
         end if;
      end Free_Converted;

      procedure Parse_And_Report
        (Input : String; Encoding_Info : XML3_Encoding.Encoding_Info)
      is
      begin
         Build (Input, Huge, Encoding_Info, Result, Status, Diagnostic);
         if Status = Status_No_Memory then
            XML3_Errors.Report_Simple (6, 2, 3, URL);
         elsif Status = Status_Internal_Error then
            XML3_Errors.Report_Simple (1, 1, 3, URL);
         elsif Status = Status_Unsupported and then Diagnostic.Code = 0 then
            XML3_Errors.Report_Simple (1, 115, 3, URL);
         elsif Status = Status_OK then
            if Diagnostic.Code /= 0 then
               XML3_Errors.Report
                 (Diagnostic.Domain, Diagnostic.Code, Diagnostic.Level,
                  Diagnostic.Byte_Position, Diagnostic.Int1, Input, URL);
               if XML3_Errors.Last_Error_Is_OOM then
                  if Result /= System.Null_Address then
                     Free_Doc (Result);
                     Result := System.Null_Address;
                  end if;
                  Status := Status_No_Memory;
               end if;
            end if;
         elsif Status /= Arena_Status then
            if Diagnostic.Code = 0 then
               XML3_Errors.Report_Simple (1, 1, 3, URL);
            else
               XML3_Errors.Report
                 (Diagnostic.Domain, Diagnostic.Code, Diagnostic.Level,
                  Diagnostic.Byte_Position, Diagnostic.Int1, Input, URL);
            end if;
         end if;
         if Status /= Status_OK and then XML3_Errors.Last_Error_Is_OOM then
            Status := Status_No_Memory;
         end if;
      end Parse_And_Report;

      procedure Report_Conversion_Error
        (Code : Natural; Domain : Natural; Error_Status : int)
      is
      begin
         Status := Error_Status;
         XML3_Errors.Report (Domain, Code, 3, 1, 0, "", URL);
         if XML3_Errors.Last_Error_Is_OOM then
            Status := Status_No_Memory;
         end if;
      end Report_Conversion_Error;
   begin
      Status := Status_Internal_Error;
      if Buffer = System.Null_Address
        or else Size < 0
        or else Size > int (Max_Input)
      then
         Status := Status_Invalid_Argument;
         return System.Null_Address;
      end if;
      declare
         Requested : XML3_Encoding.Encoding_Kind :=
           XML3_Encoding.Unspecified;
      begin
         if Encoding /= System.Null_Address then
            declare
               Encoding_Length : constant Integer := Scan_Length (Encoding, 9);
            begin
               if Encoding_Length < 0 then
                  Status := Status_Unsupported;
                  XML3_Errors.Report_Simple (1, 32, 3, URL);
                  if XML3_Errors.Last_Error_Is_OOM then
                     Status := Status_No_Memory;
                  end if;
                  return System.Null_Address;
               end if;
               Requested := XML3_Encoding.Classify
                 (To_String (Encoding, Natural (Encoding_Length)));
            end;
            if Requested = XML3_Encoding.Unsupported then
               Status := Status_Unsupported;
               XML3_Errors.Report_Simple (1, 32, 3, URL);
               if XML3_Errors.Last_Error_Is_OOM then
                  Status := Status_No_Memory;
               end if;
               return System.Null_Address;
            end if;
         end if;
         if Options < 0 then
            Status := Status_Unsupported;
            XML3_Errors.Report_Simple (1, 115, 3, URL);
            if XML3_Errors.Last_Error_Is_OOM then
               Status := Status_No_Memory;
            end if;
            return System.Null_Address;
         end if;
         declare
            Bits : constant Interfaces.Unsigned_32 :=
              Interfaces.Unsigned_32 (Options);
         begin
            if (Bits and not Allowed_Options) /= 0 then
               Status := Status_Unsupported;
               XML3_Errors.Report_Simple (1, 115, 3, URL);
               if XML3_Errors.Last_Error_Is_OOM then
                  Status := Status_No_Memory;
               end if;
               return System.Null_Address;
            end if;
            Huge := (Bits and 16#0008_0000#) /= 0;
         end;
         declare
            Source : String (1 .. Natural (Size))
              with Import, Address => Buffer;
         begin
            declare
               Info : constant XML3_Encoding.Encoding_Info :=
                 XML3_Encoding.Detect (Source, Requested);
               Normalized_Length : constant Natural :=
                 Source'Length - Info.Skip;
               Normalized_Address : constant System.Address :=
                 Buffer + To_Storage_Offset_Checked (size_t (Info.Skip));
               Normalized : String (1 .. Normalized_Length)
                 with Import, Address => Normalized_Address;
            begin
               if Info.Kind = XML3_Encoding.UTF8 then
                  Parse_And_Report (Normalized, Info);
               else
                  declare
                     Empty_Output : String (1 .. 0) := "";
                     Decoded_Length : XML3_Text.Byte_Count;
                     Decode_Status : XML3_Encoding.Conversion_Status;
                     Error_Position : Natural;
                  begin
                     XML3_Encoding.Decode_UTF16
                       (Normalized, Info.Kind = XML3_Encoding.UTF16LE,
                        Empty_Output, Decoded_Length, Decode_Status,
                        Error_Position, Measure_Only => True);
                     if Decode_Status = XML3_Encoding.Invalid_Encoding then
                        Report_Conversion_Error (81, 8, Status_Malformed);
                     elsif Decode_Status =
                       XML3_Encoding.Output_Too_Small
                     then
                        Report_Conversion_Error
                          (114, 1, Status_Limit_Exceeded);
                     else
                        Converted_Buffer := C_Malloc
                          (size_t (Natural'Max
                             (1, Natural (Decoded_Length))));
                        if Converted_Buffer = System.Null_Address then
                           Status := Status_No_Memory;
                           XML3_Errors.Report_Simple (6, 2, 3, URL);
                        else
                           declare
                              Converted : String
                                (1 .. Natural (Decoded_Length))
                                  with Import, Address => Converted_Buffer;
                              Filled_Length : XML3_Text.Byte_Count;
                              Fill_Status : XML3_Encoding.Conversion_Status;
                              Fill_Error_Position : Natural;
                           begin
                              XML3_Encoding.Decode_UTF16
                                (Normalized,
                                 Info.Kind = XML3_Encoding.UTF16LE,
                                 Converted, Filled_Length, Fill_Status,
                                 Fill_Error_Position);
                              if Fill_Status = XML3_Encoding.Success
                                and then Filled_Length = Decoded_Length
                              then
                                 Parse_And_Report (Converted, Info);
                              elsif Fill_Status =
                                XML3_Encoding.Invalid_Encoding
                              then
                                 Report_Conversion_Error
                                   (81, 8, Status_Malformed);
                              else
                                 Report_Conversion_Error
                                   (114, 1, Status_Limit_Exceeded);
                              end if;
                           end;
                        end if;
                     end if;
                  end;
                  Free_Converted;
               end if;
            end;
         end;
      end;
      Free_Converted;
      return Result;
   exception
      when Storage_Error =>
         if Result /= System.Null_Address then
            Free_Doc (Result);
         end if;
         Free_Converted;
         Status := Status_No_Memory;
         XML3_Errors.Report_Simple (6, 2, 3, URL);
         return System.Null_Address;
      when others =>
         if Result /= System.Null_Address then
            Free_Doc (Result);
         end if;
         Free_Converted;
         XML3_Errors.Report_Simple (1, 1, 3, URL);
         Status :=
           (if XML3_Errors.Last_Error_Is_OOM
            then Status_No_Memory else Status_Internal_Error);
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
      Code : int := Status_Internal_Error;
      Result : System.Address;
   begin
      Result := Parse_Buffer
        (Buffer, Size, System.Null_Address, System.Null_Address, 0, Code);
      Set_Status (Status, Code);
      return Result;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         Set_Status (Status, Status_No_Memory);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, System.Null_Address);
         Set_Status
           (Status,
            (if XML3_Errors.Last_Error_Is_OOM
             then Status_No_Memory else Status_Internal_Error));
         return System.Null_Address;
   end Read_Memory_Status;

   function Read_Memory
     (Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      return Parse_Buffer (Buffer, Size, URL, Encoding, Options, Code);
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, URL);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, URL);
         return System.Null_Address;
   end Read_Memory;

   function Parse_Memory
     (Buffer : System.Address; Size : Interfaces.C.int) return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      return Parse_Buffer
        (Buffer, Size, System.Null_Address, System.Null_Address, 0, Code);
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, System.Null_Address);
         return System.Null_Address;
   end Parse_Memory;

   function Read_Doc
     (Cur : System.Address; URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
   is
      Code : int := Status_Internal_Error;
   begin
      if Cur = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Length : constant Integer := Scan_Length (Cur, Max_Input + 1);
      begin
         if Length < 0 then
            return System.Null_Address;
         end if;
         return Parse_Buffer
           (Cur, int (Length), URL, Encoding, Options, Code);
      end;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, URL);
         return System.Null_Address;
      when others =>
         XML3_Errors.Report_Simple (1, 1, 3, URL);
         return System.Null_Address;
   end Read_Doc;

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
      Report_Operation_Status (Status, Validation_Error => False);
      return (if Result then 1 else 0);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return 0;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return 0;
      when others =>
         Report_Dom_Error (1);
         return 0;
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
      Validation_Error : Boolean := False) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Count : Natural := 0;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Facade = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Select_Element
           (Facade, Mode, Result, Count, Status);
      end;
      Report_Operation_Status (Status, Validation_Error => Validation_Error);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Select_Element_Node;

   function Doc_Get_Root_Element (Doc : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Doc, XML3_DOM_Store.Queries.Document_Root, Validation_Error => True);
   end Doc_Get_Root_Element;

   function New_Doc (Version : System.Address) return System.Address is
      Result, Implicit_Ns : System.Address := System.Null_Address;
      Name : constant String := "";
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Version_Text : constant String := C_String_Value (Version, "1.0");
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Construct
              (XML3_DOM.Document_Node, Name, Version_Text, True,
               System.Null_Address, Result, Implicit_Ns, Status);
         end;
         Report_Operation_Status (Status);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Document = System.Null_Address
        or else Memory = System.Null_Address
      then
         Report_Dom_Error (115);
         return;
      end if;
      declare
         Encoding_Text : constant String := C_String_Value (Encoding);
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Dump_Memory_Encoding
           (Document, Encoding_Text, Result, Length, Status,
            Default_Encoding => Encoding = System.Null_Address,
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
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return;
      when others =>
         Report_Dom_Error (1);
         return;
   end Doc_Dump_Format_Memory_Enc;

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
      if Name = System.Null_Address then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Content_Text : constant String := C_String_Value (Content);
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         if As_Child then
            XML3_DOM_Runtime.New_Child
              (Context, Ns, Name_Text, Content_Text, Raw_Content,
               Content /= System.Null_Address, Result, Status);
         else
            XML3_DOM_Runtime.New_Doc_Node
              (Context, Ns, Name_Text, Content_Text, Raw_Content,
               Content /= System.Null_Address, Result, Status, Attribute_Mode);
         end if;
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end New_Container_Node;

   function New_Doc_Prop
     (Doc, Name, Value : System.Address) return System.Address
   is
   begin
      if Name = System.Null_Address then
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
      if Name = System.Null_Address then
         return System.Null_Address;
      end if;
      return New_Container_Node
        (Doc, Ns, Name, Content, Raw_Content => False, As_Child => False);
   end New_Doc_Node;

   function New_Doc_Raw_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      if Name = System.Null_Address then
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
      Length : Interfaces.C.int := -1; Doc : System.Address := System.Null_Address)
     return System.Address
   is
      Result : System.Address := System.Null_Address;
      Has_Content : constant Boolean := Content /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Content_Text : constant String :=
           C_String_Prefix (Content, Length);
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.New_Doc_Content
              (Doc, Kind, Name, Content_Text, Has_Content, Result, Status);
         end;
         Report_Operation_Status (Status);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Value = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Content : constant String := C_String_Prefix (Value, Length);
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Parse_Content_List (Doc, Content, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Content /= System.Null_Address and then Length < 0 then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      return New_Content_Node (XML3_DOM.Text_Node, "text", Content, Length);
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
      if Content /= System.Null_Address and then Length < 0 then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      return New_Content_Node (XML3_DOM.Text_Node, "text", Content, Length, Doc);
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
      if Content /= System.Null_Address and then Length < 0 then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      return New_Content_Node
        (XML3_DOM.CData_Node, "", Content, Length, Doc);
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
      if Name = System.Null_Address then
         return System.Null_Address;
      end if;
      return New_Content_Node
        (XML3_DOM.Processing_Instruction_Node, C_String_Value (Name), Content,
         Doc => Doc);
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end New_Doc_PI;

   function Doc_Set_Root_Element
     (Doc, Root : System.Address) return System.Address
   is
      Previous : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Doc = System.Null_Address or else Root = System.Null_Address then
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
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Target = System.Null_Address or else Child = System.Null_Address then
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
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Text_Merge;

   function Node_Append_Content
     (Node, Content : System.Address; Length : Interfaces.C.int;
      Bounded : Boolean; Text_Only : Boolean := False) return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Text_Only and then Node = System.Null_Address then
         return -1;
      end if;
      declare
         Suffix : constant String :=
           (if Bounded then C_String_Prefix (Content, int'Max (Length, 0))
            else C_String_Value (Content));
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Add_Content
           (Node, Suffix, Status,
            Has_Input => Content /= System.Null_Address
              and then (Text_Only or else (Bounded and then Length > 0)),
            Text_Only => Text_Only);
      end;
      if Status /= XML3_DOM_Constructors.Created then
         Report_Operation_Status (Status);
      end if;
      return (if Status = XML3_DOM_Constructors.Created then 0
              elsif Text_Only or else Status = XML3_DOM_Constructors.No_Memory
                then -1
              else 1);
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return (if Text_Only then -1 else 1);
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return (if Text_Only then -1 else 1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return -1;
      when others =>
         Report_Dom_Error (1);
         return (if Text_Only then -1 else 1);
   end Node_Append_Content;

   function Text_Concat
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
   is
   begin
      return Node_Append_Content (Node, Content, Length, Length >= 0, True);
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
      if Node = System.Null_Address or else Name = System.Null_Address then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Name (Node, Name, Status);
      end;
      Report_Operation_Status (Status, Validation_Error => True);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Report_Dom_Error (1);
   end Node_Set_Name;

   function Node_Set_Content_Len
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Value : constant String := C_String_Prefix (Content, Length);
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Content
           (Node, Value, Content /= System.Null_Address, Status);
      end;
      if Status /= XML3_DOM_Constructors.Created then
         Report_Operation_Status (Status);
      end if;
      return (if Status = XML3_DOM_Constructors.Created then 0
              elsif Status = XML3_DOM_Constructors.No_Memory then -1
              else 1);
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return 1;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return 1;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return -1;
      when others =>
         Report_Dom_Error (1);
         return 1;
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
      if Node = System.Null_Address then
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
         Report_Dom_Error (1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Report_Dom_Error (1);
   end Unlink_Node;

   procedure Free_Managed_Node
     (Node : System.Address; Kind : XML3_DOM_Store.Release_Kind;
      As_List : Boolean)
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address then
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
         Report_Dom_Error (1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Report_Dom_Error (1);
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
      if Doc = System.Null_Address then
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
         Report_Dom_Error (1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Report_Dom_Error (1);
   end Free_Doc;

   function Get_Node_String
     (Node : System.Address; Path : Boolean) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address then
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
      Report_Operation_Status (Status, Validation_Error => Path);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if List = System.Null_Address then
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
      Report_Operation_Status (Status, Validation_Error => True);
      return Result;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Node = System.Null_Address then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Inherited_XML_Property
           (Node, Mode, Result, Space, Status);
      end;
      Report_Operation_Status (Status, Validation_Error => False);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
      when Storage_Error =>
         Result := System.Null_Address;
         Space := XML3_DOM_Store.Queries.Unspecified;
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Result := System.Null_Address;
         Space := XML3_DOM_Store.Queries.Unspecified;
         Report_Dom_Error (1);
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
      case Space is
         when XML3_DOM_Store.Queries.Unspecified =>
            return -1;
         when XML3_DOM_Store.Queries.Default_Space =>
            return 0;
         when XML3_DOM_Store.Queries.Preserve_Space =>
            return 1;
      end case;
   end Node_Get_Space_Preserve;

   function Set_XML_Property
     (Element, Value : System.Address;
      Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
      Space_Value : Interfaces.C.int) return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Element = System.Null_Address then
         Report_Dom_Error (115);
         return 1;
      end if;
      declare
         Has_Value : constant Boolean :=
           Mode = XML3_DOM_Store.Queries.Language_Property
           and then Value /= System.Null_Address;
         Value_Text : constant String :=
           (if Has_Value then C_String_Value (Value) else "");
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_XML_Property
           (Element, Mode, Value_Text, Has_Value, Integer (Space_Value), Status);
      end;
      Report_Operation_Status (Status);
      if Status = XML3_DOM_Constructors.Created then
         return 0;
      elsif Status = XML3_DOM_Constructors.No_Memory then
         return -1;
      else
         return 1;
      end if;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return 1;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return 1;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return -1;
      when others =>
         Report_Dom_Error (1);
         return 1;
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
      Code := 1;
      if Node = System.Null_Address or else Name = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Href_Text : constant String := C_String_Value (Href);
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Get_Property
              (Node, Name_Text, Filter, Href_Text, Result, Status);
         end;
         Report_Operation_Status (Status, Validation_Error => False);
         Code := (case Status is
                    when XML3_DOM_Constructors.Created =>
                      (if Result = System.Null_Address then 1 else 0),
                    when XML3_DOM_Constructors.Invalid_Argument => 1,
                    when others => -1);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Code := -1;
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Code := -1;
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         Code := -1;
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Code := -1;
         Report_Dom_Error (1);
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
         Href_Text : constant String :=
           (if Href = System.Null_Address then "" else C_String_Value (Href));
         Prefix_Text : constant String :=
           (if Prefix = System.Null_Address then ""
            else C_String_Value (Prefix));
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Create_Namespace
           (Node, Href_Text, Prefix_Text, Href /= System.Null_Address,
            Prefix /= System.Null_Address, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end New_Ns;

   function Copy_Ns (Source : System.Address) return System.Address is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Source = System.Null_Address then
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
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Copy_Ns;

   procedure Set_Ns (Node, Ns : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address then
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
         Report_Dom_Error (1);
      when others =>
         Report_Dom_Error (115);
   end Set_Ns;

   procedure Free_Ns (Ns : System.Address) is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Ns = System.Null_Address then
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
         Report_Dom_Error (1);
      when others =>
         Report_Dom_Error (115);
   end Free_Ns;

   function New_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Has_Value : constant Boolean := Value /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Name = System.Null_Address then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Value_Text : constant String :=
           (if Has_Value then C_String_Value (Value) else "");
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Create_Namespace_Property
           (Node, Ns, Name_Text, Value_Text, Has_Value, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end New_Ns_Prop;

   function Set_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Has_Value : constant Boolean := Value /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address or else Name = System.Null_Address then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Value_Text : constant String :=
           (if Has_Value then C_String_Value (Value) else "");
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Set_Namespace_Property
           (Node, Ns, Name_Text, Value_Text, Has_Value, Result, Status);
      end;
      Report_Operation_Status (Status);
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Set_Ns_Prop;

   function Unset_Ns_Prop
     (Node, Ns, Name : System.Address) return Interfaces.C.int
   is
      Removed : Boolean := False;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address or else Name = System.Null_Address then
         Report_Dom_Error (115);
         return -1;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Unset_Namespace_Property
           (Node, Ns, Name_Text, Removed, Status);
      end;
      if Status = XML3_DOM_Constructors.Created and then Removed then
         return 0;
      end if;
      Report_Operation_Status (Status);
      return -1;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return -1;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return -1;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return -1;
      when others =>
         Report_Dom_Error (1);
         return -1;
   end Unset_Ns_Prop;

   function New_Prop
     (Node, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Has_Value : constant Boolean := Value /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Name = System.Null_Address then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Value_Text : constant String :=
           (if Value = System.Null_Address then "" else C_String_Value (Value));
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Create_Property
              (Node, Name_Text, Value_Text, Has_Value, Result, Status);
         end;
         Report_Operation_Status (Status);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end New_Prop;

   function Set_Prop
     (Node, Name, Value : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Has_Value : constant Boolean := Value /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address or else Name = System.Null_Address then
         Report_Dom_Error (115);
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Value_Text : constant String :=
           (if Value = System.Null_Address then "" else C_String_Value (Value));
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Set_Qualified_Property
              (Node, Name_Text, Value_Text, Has_Value, Result, Status);
         end;
         Report_Operation_Status (Status);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Set_Prop;

   function Unset_Prop
     (Node, Name : System.Address) return Interfaces.C.int
   is
      Removed : Boolean := False;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address or else Name = System.Null_Address then
         Report_Dom_Error (115);
         return -1;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Unset_Property (Node, Name_Text, Removed, Status);
         end;
         if Status /= XML3_DOM_Constructors.Created then
            Report_Operation_Status (Status);
            return -1;
         end if;
         if Removed then
            return 0;
         end if;
         return -1;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return -1;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return -1;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return -1;
      when others =>
         Report_Dom_Error (1);
         return -1;
   end Unset_Prop;

   function Remove_Prop (Attribute : System.Address) return Interfaces.C.int is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Attribute = System.Null_Address then
         Report_Dom_Error (115);
         return -1;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Release
           (Attribute, XML3_DOM_Store.Namespaced_Attribute, True, Status);
      end;
      if Status = XML3_DOM_Constructors.Created then
         return 0;
      end if;
      Report_Operation_Status (Status);
      return -1;
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return -1;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return -1;
      when others =>
         Report_Dom_Error (1);
         return -1;
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
      if Node = System.Null_Address or else Name = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Find_Property
              (Node, Name_Text, XML3_DOM_Store.Queries.Any_Namespace, "",
               Result, Status);
         end;
         Report_Operation_Status (Status, Validation_Error => False);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Has_Prop;

   function Namespace_List_Value
     (Node : System.Address; Code : out int) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status;
   begin
      Code := 1;
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Get_Namespace_List (Node, Result, Status);
      end;
      Report_Operation_Status (Status, Validation_Error => False);
      Code := (case Status is
                 when XML3_DOM_Constructors.Created =>
                   (if Result = System.Null_Address then 1 else 0),
                 when XML3_DOM_Constructors.Invalid_Argument => 1,
                 when others => -1);
      return Result;
   exception
      when Storage_Error =>
         Code := -1;
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Code := -1;
         Report_Dom_Error (1);
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
      if Output = System.Null_Address then
         return 1;
      end if;
      Result := Namespace_List_Value (Node, Code);
      Set_Address (Output, Result);
      return Code;
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
   end Get_Ns_List_Safe;

   function Search_Ns
     (Doc, Node, Prefix : System.Address) return System.Address
   is
      pragma Unreferenced (Doc);
      Result : System.Address := System.Null_Address;
      Has_Value : constant Boolean := Prefix /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Value : constant String :=
           (if Prefix = System.Null_Address then "" else C_String_Value (Prefix));
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Search_Namespace
              (Node, XML3_DOM_Store.Queries.Prefix_Search,
               Has_Value, Value, Result, Status);
         end;
         Report_Operation_Status (Status, Validation_Error => False);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Search_Ns;

   function Search_Ns_By_Href
     (Doc, Node, Href : System.Address) return System.Address
   is
      pragma Unreferenced (Doc);
      Result : System.Address := System.Null_Address;
      Has_Value : constant Boolean := Href /= System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Node = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Value : constant String :=
           (if Href = System.Null_Address then "" else C_String_Value (Href));
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Search_Namespace
              (Node, XML3_DOM_Store.Queries.Href_Search,
               Has_Value, Value, Result, Status);
         end;
         Report_Operation_Status (Status, Validation_Error => False);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Node = System.Null_Address or else Name = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Name_Text : constant String := C_String_Value (Name);
         Href_Text : constant String :=
           (if Href = System.Null_Address then "" else C_String_Value (Href));
      begin
         declare
            Guard : XML3_DOM_Lock.Guard;
         begin
            XML3_DOM_Lock.Acquire (Guard);
            XML3_DOM_Runtime.Find_Property
              (Node, Name_Text, Filter, Href_Text, Result, Status);
         end;
         Report_Operation_Status (Status, Validation_Error => False);
         return Result;
      end;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Output = System.Null_Address then
         return 1;
      end if;
      Result := Get_Property_Value (Node, Name, Href, Filter, Code);
      Set_Address (Output, Result);
      return Code;
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
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
      if Parent = System.Null_Address then
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
      Report_Operation_Status (Status, Validation_Error => False);
      return unsigned_long (Count);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
         return 0;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return 0;
      when others =>
         Report_Dom_Error (1);
         return 0;
   end Child_Element_Count;

   function Check_UTF8 (Item : System.Address) return Interfaces.C.int is
      Status : XML3_Text.Buffers.UTF8_Status;
      use type XML3_Text.Buffers.UTF8_Status;
   begin
      XML3_Text.Buffers.Check_UTF8 (Item, Status);
      if Status = XML3_Text.Buffers.UTF8_Limit_Exceeded then
         Report_Dom_Error (115);
      end if;
      return (if Status = XML3_Text.Buffers.UTF8_Valid then 1 else 0);
   exception
      when others =>
         Report_Dom_Error (1);
         return 0;
   end Check_UTF8;

   function UTF8_Length_Result
     (Length : XML3_Text.Byte_Count; Status : XML3_Text.Buffers.UTF8_Status)
      return Interfaces.C.int
   is
      use type XML3_Text.Buffers.UTF8_Status;
   begin
      if Status = XML3_Text.Buffers.UTF8_Limit_Exceeded then
         Report_Dom_Error (115);
      end if;
      return (if Status = XML3_Text.Buffers.UTF8_Valid then int (Length) else -1);
   end UTF8_Length_Result;

   function UTF8_Str_Length (Item : System.Address) return Interfaces.C.int is
      Length : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.UTF8_Status;
   begin
      XML3_Text.Buffers.Count_UTF8 (Item, Length, Status);
      return UTF8_Length_Result (Length, Status);
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
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
         Report_Dom_Error (1);
         return -1;
   end UTF8_Str_Size;

   function UTF8_Size (Item : System.Address) return Interfaces.C.int is
   begin
      return int (XML3_Text.Buffers.UTF8_Lead_Size (Item));
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
   end UTF8_Size;

   function Is_XML_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Char (Natural (Code))));

   function Is_XML_Blank (Code : Interfaces.C.unsigned) return Interfaces.C.int is
     (if Code > Interfaces.C.unsigned (Natural'Last) then 0
      else Boolean'Pos (XML3_Text.XML_Blank (Natural (Code))));

   function UTF8_Char_Compare (Left, Right : System.Address) return Interfaces.C.int is
      Result : Integer;
      Invalid : Boolean;
   begin
      XML3_Text.Buffers.Compare_UTF8_Character (Left, Right, Result, Invalid);
      if Invalid then
         Report_Dom_Error (9);
      end if;
      return int (Result);
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
   end UTF8_Char_Compare;

   function UTF8_Str_Location (Item, Pattern : System.Address) return Interfaces.C.int is
      use type XML3_Text.Buffers.Search_Status;
      Index : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status;
   begin
      XML3_Text.Buffers.Find_UTF8_Character (Item, Pattern, Index, Status);
      if Status = XML3_Text.Buffers.Search_Limit_Exceeded then
         Report_Dom_Error (115);
      end if;
      return (if Status = XML3_Text.Buffers.Matched then int (Index) else -1);
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
   end UTF8_Str_Location;

   function Get_UTF8_Char
     (Item : System.Address; Length : System.Address) return Interfaces.C.int
   is
      Code : Integer;
      Width : Natural;
   begin
      if Length = System.Null_Address then
         return -1;
      end if;
      if Item = System.Null_Address then
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
         Report_Dom_Error (1);
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
      case Status is
         when XML3_Text.Buffers.Append_No_Memory =>
            XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         when XML3_Text.Buffers.Append_Limit_Exceeded =>
            Report_Dom_Error (115);
         when others => null;
      end case;
      return Result;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
      if Limit_Exceeded then
         Report_Dom_Error (115);
      end if;
      return Interfaces.C.int (Result);
   exception
      when others =>
         Report_Dom_Error (1);
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
   is (if Compare_Strings (Left, Right, False) = 0 then 1 else 0);

   function Str_Q_Equal
     (Prefix, Name, Value : System.Address) return Interfaces.C.int
   is
      Status : XML3_Text.QNames.Comparison_Status;
   begin
      XML3_Text.QNames.Compare (Prefix, Name, Value, Status);
      case Status is
         when XML3_Text.QNames.Same =>
            return 1;
         when XML3_Text.QNames.Different =>
            return 0;
         when XML3_Text.QNames.Comparison_Limit_Exceeded =>
            Report_Dom_Error (115);
            return 0;
      end case;
   exception
      when others =>
         Report_Dom_Error (1);
         return 0;
   end Str_Q_Equal;

   function Search_Result
     (Item : System.Address; Position : XML3_Text.Byte_Count;
      Status : XML3_Text.Buffers.Search_Status)
      return System.Address
   is
   begin
      case Status is
         when XML3_Text.Buffers.Matched =>
            return Item + Storage_Offset (Position);
         when XML3_Text.Buffers.No_Match =>
            return System.Null_Address;
         when XML3_Text.Buffers.Search_Limit_Exceeded =>
            Report_Dom_Error (115);
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
         Report_Dom_Error (1);
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
         Report_Dom_Error (1);
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
         Report_Dom_Error (1);
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
         Report_Dom_Error (1);
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
      declare
         Head : constant String := C_String_Value (Left);
      begin
         if Right /= System.Null_Address and then Length > 0
           and then not XML3_Text.Buffers.Fits (Head'Length, Natural (Length))
         then
            raise Invalid_C_String;
         end if;
         declare
            Tail : constant String :=
              (if Right = System.Null_Address or else Length = 0 then ""
               elsif Length < 0 then C_String_Value (Right)
               else To_String (Right, Natural (Length)));
         begin
            XML3_Text.Buffers.Concatenate
              (Head, Tail, Left /= System.Null_Address,
               Right /= System.Null_Address, Result, Status);
         end;
      end;
      case Status is
         when XML3_Text.Buffers.Copied | XML3_Text.Buffers.No_Input => null;
         when XML3_Text.Buffers.No_Memory =>
            XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         when XML3_Text.Buffers.Limit_Exceeded => Report_Dom_Error (115);
      end case;
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Str_N_Concat_New;

   function Encode_Special_Chars
     (Document, Input : System.Address) return System.Address
   is
      pragma Unreferenced (Document);
      Result : System.Address;
      Status : XML3_Text.Buffers.Escape_Status;
   begin
      if Input = System.Null_Address then
         return System.Null_Address;
      end if;
      XML3_Text.Buffers.Escape_Special (C_String_Value (Input), Result, Status);
      case Status is
         when XML3_Text.Buffers.Escaped => null;
         when XML3_Text.Buffers.Escape_No_Memory =>
            XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         when XML3_Text.Buffers.Invalid_Text |
              XML3_Text.Buffers.Escape_Limit_Exceeded => Report_Dom_Error (115);
      end case;
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Encode_Special_Chars;

   function Encode_Entities_Reentrant
     (Document, Input : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Input = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Encode_Entities
           (Document, C_String_Value (Input), Result, Status);
      end;
      Report_Operation_Status (Status, Validation_Error => True);
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Encode_Entities_Reentrant;

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
   begin
      if Item = System.Null_Address or else Length < 0 then
         return System.Null_Address;
      end if;
      XML3_Text.Buffers.Duplicate (C_String_Prefix (Item, Length), Result);
      if Result = System.Null_Address then
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      end if;
      return Result;
   exception
      when Invalid_C_String =>
         Report_Dom_Error (115);
         return System.Null_Address;
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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

   function Slice_Result
     (Result : System.Address; Status : XML3_Text.Buffers.Slice_Status)
      return System.Address
   is
   begin
      case Status is
         when XML3_Text.Buffers.No_Memory =>
            XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         when XML3_Text.Buffers.Slice_Limit_Exceeded =>
            Report_Dom_Error (115);
         when others => null;
      end case;
      return Result;
   end Slice_Result;

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
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
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
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end UTF8_Str_Sub_Copy;

   function Str_Length (Item : System.Address) return Interfaces.C.int is
      Length : XML3_Text.Byte_Count;
      Success : Boolean;
   begin
      XML3_Text.Buffers.Measure (Item, Length, Success);
      if not Success then
         Report_Dom_Error (115);
         return -1;
      end if;
      return int (Length);
   exception
      when others =>
         Report_Dom_Error (1);
         return -1;
   end Str_Length;

   function Build_QName
     (Name, Prefix, Memory : System.Address; Length : Interfaces.C.int)
      return System.Address
   is
      Read_Inputs : constant Boolean := Name /= System.Null_Address
        and then Prefix /= System.Null_Address and then Length >= 0;
      Result : System.Address;
      Status : XML3_Text.QNames.Build_Status;
   begin
      declare
         Name_Text : constant String :=
           (if Read_Inputs then C_String_Value (Name) else "");
         Prefix_Text : constant String :=
           (if Read_Inputs then C_String_Value (Prefix) else "");
      begin
         XML3_Text.QNames.Build
           (Name_Text, Prefix_Text, Name, Memory, Prefix /= System.Null_Address,
            Integer (Length), Result, Status);
         case Status is
            when XML3_Text.QNames.No_Memory =>
               XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
            when XML3_Text.QNames.Limit_Exceeded =>
               Report_Dom_Error (115);
            when others => null;
         end case;
         return Result;
      end;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Build_QName;

   function Split_QName2 (Name, Prefix : System.Address) return System.Address is
      Prefix_Value, Local : System.Address;
      Status : XML3_Text.QNames.Split_Status;
      use type XML3_Text.QNames.Split_Status;
   begin
      Set_Address (Prefix, System.Null_Address);
      if Name = System.Null_Address or else Prefix = System.Null_Address then
         return System.Null_Address;
      end if;
      XML3_Text.QNames.Split (C_String_Value (Name), Prefix_Value, Local, Status);
      if Status = XML3_Text.QNames.No_Memory then
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      end if;
      Set_Address (Prefix, Prefix_Value);
      return Local;
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Split_QName2;

   function Split_QName3 (Name, Length : System.Address) return System.Address is
      Count : XML3_Text.Byte_Count;
   begin
      if Name = System.Null_Address or else Length = System.Null_Address then
         return System.Null_Address;
      end if;
      Count := XML3_Text.QNames.Prefix_Length (C_String_Value (Name));
      if Count = 0 then
         return System.Null_Address;
      end if;
      Set_Status (Length, int (Count));
      return Name + Storage_Offset (Count + 1);
   exception
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
         return System.Null_Address;
      when others =>
         Report_Dom_Error (1);
         return System.Null_Address;
   end Split_QName3;

   function Validate_Name_Value
     (Value : System.Address; Space : int; Kind : XML3_Text.Name_Kind)
      return int
   is
   begin
      if Value = System.Null_Address then
         return -1;
      end if;
      return (if XML3_Text.Valid_Name
        (C_String_Value (Value), Kind, Space /= 0) then 0 else 1);
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
end XML3_C;
