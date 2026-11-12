with Ada.Unchecked_Deallocation;
with System.Address_To_Access_Conversions;
with XML3_Diagnostic_Messages;
with XML3_Error_Records;
with XML3_Text;

package body XML3_Errors is

   subtype Error_Record is XML3_Error_Records.Error_Record;

   use type Interfaces.C.int;
   use type System.Address;

   XML3_OOM : constant Interfaces.C.int :=
     XML3_Error_Records.Out_Of_Memory_Code;

   function TLS_Get return System.Address
     with Import, Convention => C, External_Name => "xml3ErrorsTLSGet";

   function TLS_Set (State : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3ErrorsTLSSet";

   function Emergency_TLS_Address return System.Address
     with Import, Convention => C,
       External_Name => "xml3ErrorsEmergencyRecord";

   subtype Error_State is XML3_Error_Records.Error_Slot;

   package Conversion is new System.Address_To_Access_Conversions
     (Error_State);
   subtype Error_State_Access is Conversion.Object_Pointer;
   use type Error_State_Access;
   package Error_Conversion is new System.Address_To_Access_Conversions
     (Error_Record);
   subtype Error_Access is Error_Conversion.Object_Pointer;
   use type Error_Access;

   procedure Free_State is new Ada.Unchecked_Deallocation
     (Error_State, Error_State_Access);

   Emergency_Message : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("out of memory" & ASCII.LF);
   Emergency_Active : Boolean := False
     with Thread_Local_Storage;

   Marks : XML3_Error_Records.Error_Mark := (0, 0, 0, 0)
     with Thread_Local_Storage;

   --  Records that an error of Level and Code is being published.
   procedure Note (Level, Code : Interfaces.C.int) is
   begin
      Marks := XML3_Error_Records.Advanced (Marks, Level, Code);
   end Note;

   procedure Current_Mark
     (Serial, Fatal_Serial, Error_Serial : out Interfaces.Unsigned_64;
      Error_Code : out Interfaces.C.int) is
   begin
      Serial := Marks.Serial;
      Fatal_Serial := Marks.Fatal_Serial;
      Error_Serial := Marks.Error_Serial;
      Error_Code := Marks.Error_Code;
   end Current_Mark;

   Message_Empty : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Document is empty" & ASCII.LF);
   Message_Start : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Start tag expected, '<' not found" & ASCII.LF);
   Message_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Name required" & ASCII.LF);
   Message_Tag : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Tag name mismatch" & ASCII.LF);
   Message_Comment : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Comment not finished" & ASCII.LF);
   Message_CData : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("CData not finished" & ASCII.LF);
   Message_PI : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("PI not finished" & ASCII.LF);
   Message_UTF8 : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid character encoding" & ASCII.LF);
   Message_Namespace : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Namespace error" & ASCII.LF);
   Message_No_Memory : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Memory allocation failed" & ASCII.LF);
   Message_Internal : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Internal parser error" & ASCII.LF);
   Message_Unsupported : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Unsupported parser option or feature" & ASCII.LF);
   Message_Extra_Content : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Extra content at the end of the document" & ASCII.LF);
   Message_Invalid_Character : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid XML character" & ASCII.LF);
   Message_Character_Reference : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid character reference" & ASCII.LF);
   Message_Entity_Semicolon : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Entity reference is missing a semicolon" & ASCII.LF);
   Message_Entity : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Entity reference is not declared" & ASCII.LF);
   Message_External_Entity : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("External entities are unsupported" & ASCII.LF);
   Message_Encoding : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Unsupported document encoding" & ASCII.LF);
   Message_Encoding_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid encoding name" & ASCII.LF);
   Message_Encoding_Mismatch : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Document encoding does not match its declaration" & ASCII.LF);
   Message_Attribute_Value : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid attribute value" & ASCII.LF);
   Message_Attribute_Unclosed : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Attribute value is not closed" & ASCII.LF);
   Message_Attribute_Required : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Attribute name or value required" & ASCII.LF);
   Message_Start_Tag : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Start tag is not finished" & ASCII.LF);
   Message_End_Tag : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Tag is not finished" & ASCII.LF);
   Message_Reserved_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("The XML processing-instruction target is reserved" & ASCII.LF);
   Message_Name_Length : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("XML name is too long" & ASCII.LF);
   Message_Resource : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Resource limit exceeded" & ASCII.LF);
   Message_Standalone : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid standalone declaration value" & ASCII.LF);
   Message_XML_Declaration : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("XML declaration is not finished" & ASCII.LF);
   Message_Comment_Hyphen : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Invalid hyphen sequence in comment" & ASCII.LF);
   Message_Quote : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Less-than sign is not allowed in an attribute value" & ASCII.LF);
   Message_CData_Position : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("CDATA terminator is misplaced" & ASCII.LF);
   Message_Equal : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Equals sign required" & ASCII.LF);
   Message_Duplicate_Attribute : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("Attribute is already specified" & ASCII.LF);
   Message_Generic : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C ("XML parsing error" & ASCII.LF);

   use all type XML3_Diagnostic_Messages.Message_Kind;

   Message_Addresses : constant array (XML3_Diagnostic_Messages.Message_Kind)
     of System.Address :=
     (Empty => Message_Empty'Address,
      Start => Message_Start'Address,
      Name => Message_Name'Address,
      Tag => Message_Tag'Address,
      Comment => Message_Comment'Address,
      CData => Message_CData'Address,
      PI => Message_PI'Address,
      UTF8 => Message_UTF8'Address,
      Namespace => Message_Namespace'Address,
      No_Memory => Message_No_Memory'Address,
      Internal => Message_Internal'Address,
      Unsupported => Message_Unsupported'Address,
      Extra_Content => Message_Extra_Content'Address,
      Invalid_Character => Message_Invalid_Character'Address,
      Character_Reference => Message_Character_Reference'Address,
      Entity_Semicolon => Message_Entity_Semicolon'Address,
      Entity => Message_Entity'Address,
      External_Entity => Message_External_Entity'Address,
      Encoding => Message_Encoding'Address,
      Encoding_Name => Message_Encoding_Name'Address,
      Encoding_Mismatch => Message_Encoding_Mismatch'Address,
      Attribute_Value => Message_Attribute_Value'Address,
      Attribute_Unclosed => Message_Attribute_Unclosed'Address,
      Attribute_Required => Message_Attribute_Required'Address,
      Start_Tag => Message_Start_Tag'Address,
      End_Tag => Message_End_Tag'Address,
      Reserved_Name => Message_Reserved_Name'Address,
      Name_Length => Message_Name_Length'Address,
      Resource => Message_Resource'Address,
      Standalone => Message_Standalone'Address,
      XML_Declaration => Message_XML_Declaration'Address,
      Comment_Hyphen => Message_Comment_Hyphen'Address,
      Quote => Message_Quote'Address,
      CData_Position => Message_CData_Position'Address,
      Equal => Message_Equal'Address,
      Duplicate_Attribute => Message_Duplicate_Attribute'Address,
      Generic_Error => Message_Generic'Address);

   function State_At
     (Address : System.Address) return Error_State_Access
   is
   begin
      if Address = System.Null_Address then
         return null;
      end if;
      return Conversion.To_Pointer (Address);
   end State_At;

   function Emergency_Error return Error_Access is
   begin
      return Error_Conversion.To_Pointer (Emergency_TLS_Address);
   end Emergency_Error;

   function Current_State
     (Create : Boolean) return Error_State_Access
   is
      Address : constant System.Address := TLS_Get;
      State   : Error_State_Access := State_At (Address);
   begin
      if State /= null or else not Create then
         return State;
      end if;
      State := new Error_State;
      if TLS_Set (State.all'Address) /= 0 then
         Free_State (State);
         return null;
      end if;
      return State;
   exception
      when Storage_Error =>
         return null;
   end Current_State;

   function Internal_State
     (Error : System.Address) return Error_State_Access
   is
      State : constant Error_State_Access := Current_State (False);
   begin
      if State /= null and then Error = State.Error'Address then
         return State;
      end if;
      return null;
   end Internal_State;

   procedure Clear_Record (Item : in out Error_Record)
     renames XML3_Error_Records.Release;

   procedure Set_OOM is
      State : constant Error_State_Access := Current_State (False);
   begin
      Note (XML3_Error_Records.Fatal_Level, XML3_OOM);
      if State /= null then
         XML3_Error_Records.Install_Out_Of_Memory
           (State.all, Emergency_Message'Address);
      else
         XML3_Error_Records.Fill_Out_Of_Memory
           (Emergency_Error.all, Emergency_Message'Address);
         Emergency_Active := True;
      end if;
   exception
      when others =>
         XML3_Error_Records.Fill_Out_Of_Memory
           (Emergency_Error.all, Emergency_Message'Address);
         Emergency_Active := True;
   end Set_OOM;

   procedure Set_Error
     (Domain  : Interfaces.C.int;
      Code    : Interfaces.C.int;
      Level   : Interfaces.C.int;
      Line    : Interfaces.C.int;
      Int1    : Interfaces.C.int;
      Int2    : Interfaces.C.int;
      Message : System.Address;
      File    : System.Address;
      Str1    : System.Address;
      Str2    : System.Address;
      Str3    : System.Address)
   is
      State : constant Error_State_Access := Current_State (True);
      Replacement : Error_Record := (others => <>);
      Success : Boolean;
   begin
      Note (Level, Code);
      XML3_Error_Records.Clone
        ((Domain => Domain, Code => Code, Level => Level, Line => Line,
          Int1 => Int1, Int2 => Int2, Message => Message, File => File,
          Str1 => Str1, Str2 => Str2, Str3 => Str3, others => <>),
         Replacement, Success);
      if not Success then
         Set_OOM;
         return;
      end if;
      if State = null then
         Clear_Record (Replacement);
         Set_OOM;
         return;
      end if;
      XML3_Error_Records.Install (State.all, Replacement);
      Emergency_Active := False;
   exception
      when others =>
         Clear_Record (Replacement);
         Set_OOM;
   end Set_Error;

   procedure Report
     (Domain        : Natural;
      Code          : Natural;
      Level         : Natural;
      Byte_Position : Natural;
      Int1          : Integer;
      Input         : String;
      File          : System.Address)
   is
      Location : constant XML3_Text.Text_Location :=
        XML3_Text.Location_At (Input, Byte_Position);
      Message : constant System.Address :=
        Message_Addresses
          (XML3_Diagnostic_Messages.Kind_For
             (Interfaces.C.int (Code), Interfaces.C.int (Domain),
              Has_Input => Input'Length /= 0));
   begin
      Set_Error
        (Interfaces.C.int (Domain),
         Interfaces.C.int (Code),
         Interfaces.C.int (Level),
         Interfaces.C.int (Location.Line), Interfaces.C.int (Int1),
         Interfaces.C.int (Location.Column),
         Message, File,
         System.Null_Address, System.Null_Address, System.Null_Address);
   exception
      when others =>
         Set_OOM;
   end Report;

   procedure Report_Simple
     (Domain : Interfaces.C.int;
      Code   : Interfaces.C.int;
      Level  : Interfaces.C.int;
      File   : System.Address)
   is
   begin
      Set_Error
        (Domain, Code, Level, 0, 0, 0,
         Message_Addresses (XML3_Diagnostic_Messages.Kind_For (Code, Domain)),
         File,
         System.Null_Address, System.Null_Address, System.Null_Address);
   exception
      when others =>
         Set_OOM;
   end Report_Simple;

   function Last_Error_Is_OOM return Boolean is
      State : constant Error_State_Access := Current_State (False);
   begin
      if State /= null then
         return State.Error.Code = XML3_OOM;
      elsif Emergency_Active then
         return Emergency_Error.Code = XML3_OOM;
      end if;
      return False;
   exception
      when others =>
         return False;
   end Last_Error_Is_OOM;

   function Get_Last_Error return System.Address is
      State : constant Error_State_Access := Current_State (False);
   begin
      case XML3_Error_Records.Select_Last_Error
             (Has_Slot => State /= null,
              Code => (if State /= null then State.Error.Code else 0),
              Emergency_Active => Emergency_Active)
      is
         when XML3_Error_Records.Slot_Record =>
            return State.Error'Address;
         when XML3_Error_Records.Emergency_Record =>
            return Emergency_TLS_Address;
         when XML3_Error_Records.No_Error =>
            return System.Null_Address;
      end case;
   exception
      when others =>
         return System.Null_Address;
   end Get_Last_Error;

   procedure Reset_Last_Error is
      State : constant Error_State_Access := Current_State (False);
   begin
      if State /= null then
         XML3_Error_Records.Clear_Slot (State.all);
      end if;
      Emergency_Error.all := (others => <>);
      Emergency_Active := False;
   exception
      when others =>
         null;
   end Reset_Last_Error;

   procedure Reset_Error (Error : System.Address) is
      State : constant Error_State_Access := Internal_State (Error);
   begin
      if Error = System.Null_Address then
         return;
      elsif State /= null then
         XML3_Error_Records.Clear_Slot (State.all);
      elsif Error = Emergency_TLS_Address then
         Emergency_Error.all := (others => <>);
         Emergency_Active := False;
      else
         Clear_Record (Error_Conversion.To_Pointer (Error).all);
      end if;
   exception
      when others =>
         null;
   end Reset_Error;

   function Copy_Error
     (From : System.Address;
      To   : System.Address) return Interfaces.C.int
   is
      Source : Error_Record;
      Copy   : Error_Record := (others => <>);
      Success : Boolean;
   begin
      case XML3_Error_Records.Decide_Copy
             (From_Null => From = System.Null_Address,
              To_Null => To = System.Null_Address,
              Same => From = To,
              To_Emergency =>
                From /= System.Null_Address
                  and then To /= System.Null_Address
                  and then From /= To
                  and then To = Emergency_TLS_Address)
      is
         when XML3_Error_Records.Reject =>
            return -1;
         when XML3_Error_Records.Already_Copied =>
            return 0;
         when XML3_Error_Records.Clone_Source =>
            null;
      end case;
      Source := Error_Conversion.To_Pointer (From).all;
      XML3_Error_Records.Clone (Source, Copy, Success);
      if not Success then
         Set_OOM;
         return -1;
      end if;
      Reset_Error (To);
      Error_Conversion.To_Pointer (To).all := Copy;
      return 0;
   exception
      when others =>
         Clear_Record (Copy);
         Set_OOM;
         return -1;
   end Copy_Error;

   procedure Destroy_State (State : System.Address) is
      Value : Error_State_Access := State_At (State);
   begin
      if Value = null then
         return;
      end if;
      XML3_Error_Records.Clear_Slot (Value.all);
      Free_State (Value);
   exception
      when others =>
         null;
   end Destroy_State;

end XML3_Errors;
