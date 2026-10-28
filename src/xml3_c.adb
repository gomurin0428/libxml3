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

package body XML3_C is
   use type System.Address;
   use type Interfaces.Unsigned_32;
   use type XML3_Encoding.Encoding_Kind;
   use type XML3_Encoding.Conversion_Status;
   use type XML3_DOM_Constructors.Construction_Status;
   use type XML3_DOM_Store.Documents.Read_Status;

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

   function C_Strcmp
     (Left, Right : System.Address) return int
     with Import, Convention => C, External_Name => "strcmp";

   function C_Strlen (Item : System.Address) return size_t
     with Import, Convention => C, External_Name => "strlen";

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

   procedure Doc_Dump_Memory_Enc
     (Document, Memory, Size, Encoding : System.Address)
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
         or else Encoding = System.Null_Address
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
           (Document, Encoding_Text, Result, Length, Status);
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
   end Doc_Dump_Memory_Enc;

   function New_Node
      (Ns, Name : System.Address) return System.Address
   is
   begin
      return New_Doc_Node
        (System.Null_Address, Ns, Name, System.Null_Address);
   end New_Node;

   function New_Element_Node
     (Context, Ns, Name, Content : System.Address;
      Raw_Content, As_Child : Boolean)
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
               Content /= System.Null_Address, Result, Status);
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
   end New_Element_Node;

   function New_Doc_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      if Name = System.Null_Address then
         return System.Null_Address;
      end if;
      return New_Element_Node
        (Doc, Ns, Name, Content, Raw_Content => False, As_Child => False);
   end New_Doc_Node;

   function New_Doc_Raw_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      if Name = System.Null_Address then
         return System.Null_Address;
      end if;
      return New_Element_Node
        (Doc, Ns, Name, Content, Raw_Content => True, As_Child => False);
   end New_Doc_Raw_Node;

   function New_Child
     (Parent, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      return New_Element_Node
        (Parent, Ns, Name, Content, Raw_Content => False, As_Child => True);
   end New_Child;

   function New_Text_Child
     (Parent, Ns, Name, Content : System.Address) return System.Address
   is
   begin
      return New_Element_Node
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

   function Add_Child
     (Parent, Child : System.Address) return System.Address
   is
      Result : System.Address := System.Null_Address;
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Parent = System.Null_Address or else Child = System.Null_Address then
         return System.Null_Address;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Add_Child (Parent, Child, Result, Status);
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
   end Add_Child;

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
      Bounded : Boolean) return Interfaces.C.int
   is
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      declare
         Suffix : constant String :=
           (if Bounded then C_String_Prefix (Content, int'Max (Length, 0))
            else C_String_Value (Content));
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Add_Content
           (Node, Suffix, Status,
            Has_Input => Bounded and then Length > 0
              and then Content /= System.Null_Address);
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
   end Node_Append_Content;

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

   procedure Free_Node (Node : System.Address) is
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
         XML3_DOM_Runtime.Release
           (Node, XML3_DOM_Store.Content_Node, False, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Report_Dom_Error (1);
   end Free_Node;

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

   function Node_Get_Content (Node : System.Address) return System.Address is
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
         XML3_DOM_Runtime.Get_Content (Node, Result, Status);
      end;
      Report_Operation_Status (Status, Validation_Error => False);
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
   end Node_Get_Content;

   function Get_Prop
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
            XML3_DOM_Runtime.Get_Property
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
      Status : XML3_DOM_Store.Operation_Status :=
        XML3_DOM_Constructors.Internal_Error;
   begin
      if Attribute = System.Null_Address then
         return;
      end if;
      declare
         Guard : XML3_DOM_Lock.Guard;
      begin
         XML3_DOM_Lock.Acquire (Guard);
         XML3_DOM_Runtime.Release
           (Attribute, XML3_DOM_Store.Namespaced_Attribute, False, Status);
      end;
      Report_Operation_Status (Status);
   exception
      when XML3_DOM_Lock.Lock_Error =>
         Report_Dom_Error (1);
      when Storage_Error =>
         XML3_Errors.Report_Simple (6, 2, 3, System.Null_Address);
      when others =>
         Report_Dom_Error (1);
   end Free_Prop;

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
            XML3_DOM_Runtime.Get_Property
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
   end Get_Ns_Prop;

   function Get_No_Ns_Prop
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
            XML3_DOM_Runtime.Get_Property
              (Node, Name_Text, XML3_DOM_Store.Queries.No_Namespace, "",
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
   end Get_No_Ns_Prop;

   function First_Element_Child (Parent : System.Address) return System.Address
   is
   begin
      return Select_Element_Node
        (Parent, XML3_DOM_Store.Queries.First_Element);
   end First_Element_Child;

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

   function Str_Compare
     (Left, Right : System.Address) return Interfaces.C.int
   is
   begin
      if Left = Right then
         return 0;
      elsif Left = System.Null_Address then
         return -1;
      elsif Right = System.Null_Address then
         return 1;
      end if;
      return C_Strcmp (Left, Right);
   exception
      when others =>
         return 0;
   end Str_Compare;

   function Str_Equal
     (Left, Right : System.Address) return Interfaces.C.int
   is
   begin
      if Left = Right then
         return 1;
      elsif Left = System.Null_Address or else Right = System.Null_Address then
         return 0;
      elsif C_Strcmp (Left, Right) = 0 then
         return 1;
      else
         return 0;
      end if;
   exception
      when others =>
         return 0;
   end Str_Equal;

   function Str_Length (Item : System.Address) return Interfaces.C.int is
      Length : size_t;
   begin
      if Item = System.Null_Address then
         return 0;
      end if;
      Length := C_Strlen (Item);
      if Length > size_t (int'Last) then
         return -1;
      end if;
      return int (Length);
   exception
      when others =>
         return 0;
   end Str_Length;

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
