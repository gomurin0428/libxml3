with Ada.Unchecked_Deallocation;
with System.Address_To_Access_Conversions;

package body XML3_Errors is

   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type System.Address;

   XML3_OOM : constant Interfaces.C.int := 2;
   XML3_MEMORY : constant Interfaces.C.int := 6;
   XML3_FATAL : constant Interfaces.C.int := 3;

   function TLS_Get return System.Address
     with Import, Convention => C, External_Name => "xml3ErrorsTLSGet";

   function TLS_Set (State : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "xml3ErrorsTLSSet";

   function Emergency_TLS_Address return System.Address
     with Import, Convention => C,
       External_Name => "xml3ErrorsEmergencyRecord";

   function C_Malloc (Size : Interfaces.C.size_t) return System.Address
     with Import, Convention => C, External_Name => "malloc";

   procedure C_Free (Item : System.Address)
     with Import, Convention => C, External_Name => "free";

   function C_Strlen (Item : System.Address) return Interfaces.C.size_t
     with Import, Convention => C, External_Name => "strlen";

   function C_Memcpy
     (Destination : System.Address;
      Source      : System.Address;
      Size        : Interfaces.C.size_t) return System.Address
     with Import, Convention => C, External_Name => "memcpy";

   type Error_State;

   type Error_State is record
      Error     : aliased Error_Record := (others => <>);
      Emergency : Boolean := False;
   end record;

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
     Interfaces.C.To_C ("Invalid UTF-8" & ASCII.LF);
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

   function Message_For (Code : Natural; Domain : Natural) return System.Address is
   begin
      if Code = 2 then
         return Message_No_Memory'Address;
      elsif Code = 1 then
         return Message_Internal'Address;
      elsif Code = 4 then
         return Message_Empty'Address;
      elsif Code = 5 then
         return Message_Extra_Content'Address;
      elsif Code = 9 then
         return Message_Invalid_Character'Address;
      elsif Code = 6 or else Code = 7 or else Code = 8 then
         return Message_Character_Reference'Address;
      elsif Code = 23 then
         return Message_Entity_Semicolon'Address;
      elsif Code = 26 or else Code = 27 then
         return Message_Entity'Address;
      elsif Code = 29 then
         return Message_External_Entity'Address;
      elsif Code = 32 then
         return Message_Encoding'Address;
      elsif Code = 34 or else Code = 40 then
         return Message_Attribute_Unclosed'Address;
      elsif Code = 38 then
         return Message_Quote'Address;
      elsif Code = 39 then
         return Message_Attribute_Required'Address;
      elsif Code = 41 then
         return Message_Attribute_Value'Address;
      elsif Code = 68 then
         return Message_Name'Address;
      elsif Code = 75 then
         return Message_Equal'Address;
      elsif Code = 42 then
         return Message_Duplicate_Attribute'Address;
      elsif Code = 73 then
         return Message_Start_Tag'Address;
      elsif Code = 77 then
         return Message_End_Tag'Address;
      elsif Code = 78 then
         return Message_Standalone'Address;
      elsif Code = 57 then
         return Message_XML_Declaration'Address;
      elsif Code = 80 then
         return Message_Comment_Hyphen'Address;
      elsif Code = 110 then
         return Message_Name_Length'Address;
      elsif Code = 114 then
         return Message_Resource'Address;
      elsif Code = 115 then
         return Message_Unsupported'Address;
      elsif Code = 76 then
         return Message_Tag'Address;
      elsif Code = 62 then
         return Message_CData_Position'Address;
      elsif Code = 45 then
         return Message_Comment'Address;
      elsif Code = 63 then
         return Message_CData'Address;
      elsif Code = 47 then
         return Message_PI'Address;
      elsif Code = 64 then
         return Message_Reserved_Name'Address;
      elsif Domain = 8 or else Code = 81 then
         return Message_UTF8'Address;
      elsif Domain = 3 then
         return Message_Namespace'Address;
      else
         return Message_Generic'Address;
      end if;
   end Message_For;

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

   procedure Free_Pointer (Item : in out System.Address) is
   begin
      if Item /= System.Null_Address then
         C_Free (Item);
         Item := System.Null_Address;
      end if;
   end Free_Pointer;

   procedure Clear_Record (Item : in out Error_Record) is
   begin
      Free_Pointer (Item.Message);
      Free_Pointer (Item.File);
      Free_Pointer (Item.Str1);
      Free_Pointer (Item.Str2);
      Free_Pointer (Item.Str3);
      Item := (others => <>);
   end Clear_Record;

   function Duplicate (Item : System.Address) return System.Address is
      Length : Interfaces.C.size_t;
      Copy   : System.Address;
   begin
      if Item = System.Null_Address then
         return System.Null_Address;
      end if;
      Length := C_Strlen (Item);
      if Length = Interfaces.C.size_t'Last then
         return System.Null_Address;
      end if;
      Copy := C_Malloc (Length + 1);
      if Copy = System.Null_Address then
         return System.Null_Address;
      end if;
      Copy := C_Memcpy (Copy, Item, Length + 1);
      return Copy;
   exception
      when others =>
         return System.Null_Address;
   end Duplicate;

   procedure Set_OOM is
      State : constant Error_State_Access := Current_State (False);
      Item  : Error_Access;
   begin
      if State /= null then
         if not State.Emergency then
            Clear_Record (State.Error);
         else
            State.Error := (others => <>);
         end if;
         State.Emergency := True;
         Item := State.Error'Access;
      else
         Emergency_Error.all := (others => <>);
         Item := Emergency_Error;
         Emergency_Active := True;
      end if;
      Item.all.Domain := XML3_MEMORY;
      Item.all.Code := XML3_OOM;
      Item.all.Level := XML3_FATAL;
      Item.all.Message := Emergency_Message'Address;
   exception
      when others =>
         Emergency_Error.all := (others => <>);
         Emergency_Error.Domain := XML3_MEMORY;
         Emergency_Error.Code := XML3_OOM;
         Emergency_Error.Level := XML3_FATAL;
         Emergency_Error.Message := Emergency_Message'Address;
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
   begin
      Replacement.Domain := Domain;
      Replacement.Code := Code;
      Replacement.Level := Level;
      Replacement.Line := Line;
      Replacement.Int1 := Int1;
      Replacement.Int2 := Int2;
      Replacement.Message := Duplicate (Message);
      if Message /= System.Null_Address
        and then Replacement.Message = System.Null_Address
      then
         Set_OOM;
         return;
      end if;
      Replacement.File := Duplicate (File);
      if File /= System.Null_Address and then Replacement.File = System.Null_Address then
         Clear_Record (Replacement);
         Set_OOM;
         return;
      end if;
      Replacement.Str1 := Duplicate (Str1);
      if Str1 /= System.Null_Address and then Replacement.Str1 = System.Null_Address then
         Clear_Record (Replacement);
         Set_OOM;
         return;
      end if;
      Replacement.Str2 := Duplicate (Str2);
      if Str2 /= System.Null_Address and then Replacement.Str2 = System.Null_Address then
         Clear_Record (Replacement);
         Set_OOM;
         return;
      end if;
      Replacement.Str3 := Duplicate (Str3);
      if Str3 /= System.Null_Address and then Replacement.Str3 = System.Null_Address then
         Clear_Record (Replacement);
         Set_OOM;
         return;
      end if;
      if State = null then
         Clear_Record (Replacement);
         Set_OOM;
         return;
      end if;
      if not State.Emergency then
         Clear_Record (State.Error);
      else
         State.Error := (others => <>);
      end if;
      State.Emergency := False;
      State.Error := Replacement;
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
      Limit : constant Natural :=
        Natural'Min (Input'Length + 1, Byte_Position);
      Line : Interfaces.C.int := 1;
      Column : Interfaces.C.int := 1;
      Byte : Character;
      Message : System.Address;
   begin
      if Limit > 1 then
         for I in Input'First .. Limit - 1 loop
            Byte := Input (I);
            if Byte = Character'Val (10) then
               Line := Line + 1;
               Column := 1;
            elsif Character'Pos (Byte) < 128
              or else Character'Pos (Byte) not in 16#80# .. 16#BF#
            then
               Column := Column + 1;
            end if;
         end loop;
      end if;
      if Code = 4 and then Input'Length /= 0 then
         Message := Message_Start'Address;
      else
         Message := Message_For (Code, Domain);
      end if;
      Set_Error
        (Interfaces.C.int (Domain),
         Interfaces.C.int (Code),
         Interfaces.C.int (Level),
         Line, Interfaces.C.int (Int1), Column,
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
         Message_For (Natural (Code), Natural (Domain)), File,
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
      if State /= null and then State.Error.Code /= 0 then
         return State.Error'Address;
      elsif Emergency_Active then
         return Emergency_TLS_Address;
      end if;
      return System.Null_Address;
   exception
      when others =>
         return System.Null_Address;
   end Get_Last_Error;

   procedure Reset_Last_Error is
      State : constant Error_State_Access := Current_State (False);
   begin
      if State /= null then
         if not State.Emergency then
            Clear_Record (State.Error);
         else
            State.Error := (others => <>);
         end if;
         State.Emergency := False;
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
         if not State.Emergency then
            Clear_Record (State.Error);
         else
            State.Error := (others => <>);
         end if;
         State.Emergency := False;
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
   begin
      if From = System.Null_Address or else To = System.Null_Address then
         return -1;
      elsif From = To then
         return 0;
      elsif To = Emergency_TLS_Address then
         return -1;
      end if;
      Source := Error_Conversion.To_Pointer (From).all;
      Copy.Domain := Source.Domain;
      Copy.Code := Source.Code;
      Copy.Level := Source.Level;
      Copy.Line := Source.Line;
      Copy.Int1 := Source.Int1;
      Copy.Int2 := Source.Int2;
      Copy.Ctxt := Source.Ctxt;
      Copy.Node := Source.Node;
      Copy.Message := Duplicate (Source.Message);
      if Source.Message /= System.Null_Address
        and then Copy.Message = System.Null_Address
      then
         Set_OOM;
         return -1;
      end if;
      Copy.File := Duplicate (Source.File);
      Copy.Str1 := Duplicate (Source.Str1);
      Copy.Str2 := Duplicate (Source.Str2);
      Copy.Str3 := Duplicate (Source.Str3);
      if (Source.File /= System.Null_Address and then Copy.File = System.Null_Address)
        or else (Source.Str1 /= System.Null_Address and then Copy.Str1 = System.Null_Address)
        or else (Source.Str2 /= System.Null_Address and then Copy.Str2 = System.Null_Address)
        or else (Source.Str3 /= System.Null_Address and then Copy.Str3 = System.Null_Address)
      then
         Clear_Record (Copy);
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
      if not Value.Emergency then
         Clear_Record (Value.Error);
      end if;
      Free_State (Value);
   exception
      when others =>
         null;
   end Destroy_State;

end XML3_Errors;
