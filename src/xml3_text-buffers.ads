with System;
with Interfaces.C;
with XML3_Native_Memory;

package XML3_Text.Buffers with SPARK_Mode is
   use type System.Address;

   type Concatenate_Status is (Copied, No_Input, No_Memory, Limit_Exceeded);

   type Name_Value_Kind is (Single_Name, Name_List, Single_NMToken, NMToken_List);

   function Valid_Name_Value
     (Source : System.Address; Kind : Name_Value_Kind;
      Last : Byte_Count := Max_Bytes) return Boolean
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Source = System.Null_Address then not Valid_Name_Value'Result);

   function Validate_Name
     (Source : System.Address; Kind : Name_Kind; Allow_Space : Boolean;
      Last : Byte_Count := Max_Bytes) return Integer
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Validate_Name'Result in -1 .. 1
         and then (if Source = System.Null_Address then Validate_Name'Result = -1);

   function Get_Predefined_Entity (Name : System.Address) return System.Address
     with Global => (Input => XML3_Native_Memory.Foreign_Memory);

   type Search_Status is (No_Match, Matched, Search_Limit_Exceeded);

   type Slice_Status is (Sliced, No_Slice, No_Memory, Slice_Limit_Exceeded);

   type Append_Status is
     (Unchanged, Appended, Invalid_Length, Append_No_Memory, Append_Limit_Exceeded);

   type UTF8_Status is (UTF8_Valid, UTF8_Invalid, UTF8_Limit_Exceeded);

   type Escape_Status is
     (Escaped, Invalid_Text, Escape_No_Memory, Escape_Limit_Exceeded);

   type Path_Status is (Normalized, Invalid_Path, Path_Limit_Exceeded);
   procedure Normalize_URI_Path
     (Item : System.Address; Status : out Path_Status;
      Limit : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Normalized then Item /= System.Null_Address);

   procedure Unescape_URI
     (Input : System.Address; Length : Integer; Target : System.Address;
      Result : out System.Address; Status : out Escape_Status;
      Limit : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Escaped then Result /= System.Null_Address
                  and then (if Target /= System.Null_Address then Result = Target)
                else Result = System.Null_Address);

   procedure Escape_URI
     (Input, Exceptions : System.Address;
      Result : out System.Address; Status : out Escape_Status;
      Limit : Byte_Count := Max_Bytes; List_Limit : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Escaped then Result /= System.Null_Address
                else Result = System.Null_Address);

   function Character_In_Range
     (Code : Interfaces.C.unsigned; Group : System.Address) return Boolean
     with Global => (Input => XML3_Native_Memory.Foreign_Memory);

   procedure Write_UTF8_Char
     (Target : System.Address; Code : Integer; Written : out Natural)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Written in 0 .. 4
         and then (if Target = System.Null_Address
                     or else Code not in 0 .. 16#10FFFF#
                     or else Code in 16#D800# .. 16#DFFF#
                   then Written = 0 else Written = UTF8_Width (Code));

   function Valid_Name
     (Source : System.Address; Source_Length : Natural;
      Allow_Colon : Boolean) return Boolean
     with Global => (Input => XML3_Native_Memory.Foreign_Memory);

   function Is_XHTML (System_ID, Public_ID : System.Address) return Integer
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Is_XHTML'Result in -1 .. 1
         and then (if System_ID = System.Null_Address
                     and then Public_ID = System.Null_Address
                   then Is_XHTML'Result = -1 else Is_XHTML'Result in 0 .. 1);

   procedure Escape_Special
     (Input : String; Result : out System.Address; Status : out Escape_Status;
      Limit : Byte_Count := Max_Bytes;
      Non_ASCII, Attribute : Boolean := False; Quotes : Boolean := True)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input'First = 1 and then Input'Last in 0 .. Max_Bytes,
       Post => (if Status = Escaped then Result /= System.Null_Address
                else Result = System.Null_Address);

   function Character_Reference (Code : Natural) return String
     with Global => null, Pre => Code <= 16#10FFFF#,
       Post => Character_Reference'Result'Length in 4 .. 10;

   function UTF8_Lead_Size (Item : System.Address) return Integer
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => UTF8_Lead_Size'Result in -1 | 1 .. 4
         and then (if Item = System.Null_Address then UTF8_Lead_Size'Result = -1);

   procedure Compare_UTF8_Character
     (Left, Right : System.Address; Result : out Integer; Invalid : out Boolean)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Result in -255 .. 255 and then (if Invalid then Result = -1);

   procedure Copy_UTF8_Slice
     (Item : System.Address; Start, Characters : Integer;
      Result : out System.Address; Status : out Slice_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Sliced then Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Copy_UTF8_Prefix
     (Item : System.Address; Characters : Integer;
      Result : out System.Address; Status : out Slice_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Sliced then Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Measure_UTF8_Prefix
     (Item : System.Address; Characters : Integer;
      Size : out Byte_Count; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Size <= Last
         and then (if Status /= UTF8_Valid then Size = 0)
         and then (if Item = System.Null_Address or Characters <= 0
                   then Size = 0 and Status = UTF8_Valid);

   procedure Find_UTF8_Position
     (Item : System.Address; Index : Integer;
      Position : out Byte_Count; Status : out Search_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Position <= Last
         and then (if Status = Matched then Item /= System.Null_Address
                   else Position = 0);

   procedure Find_UTF8_Character
     (Item, Pattern : System.Address;
      Index : out Byte_Count; Status : out Search_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Index <= Last
         and then (if Status = Matched then
                      Item /= System.Null_Address and Pattern /= System.Null_Address
                   else Index = 0);

   procedure Count_UTF8
     (Item : System.Address; Length : out Byte_Count; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Length <= Last
         and then (if Status /= UTF8_Valid then Length = 0)
         and then (if Item = System.Null_Address then Status = UTF8_Invalid);

   procedure Check_UTF8
     (Item : System.Address; Status : out UTF8_Status;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Item = System.Null_Address then Status = UTF8_Invalid);

   procedure Get_UTF8_Char
     (Item : System.Address; Available : Integer;
      Code : out Integer; Width : out Natural)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (Width = 0 and then Code = -1)
         or else (Width in 1 .. 4 and then Width <= Available
                  and then Code in 0 .. 16#10FFFF#);

   procedure Measure
     (Item : System.Address; Length : out Byte_Count; Success : out Boolean;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Length <= Last and then (if not Success then Length = 0);

   procedure Append
     (Item, Addition : System.Address; Length : Integer; Terminated : Boolean;
      Result : out System.Address; Status : out Append_Status;
      Limit : Byte_Count := Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Unchanged then Result = Item
                elsif Status = Appended then Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Compare_Terminated
     (Left, Right : System.Address; Ignore_Case : Boolean;
      Result : out Integer; Limit_Exceeded : out Boolean;
      Last : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Result in -255 .. 255
         and then (if Limit_Exceeded then Result = -1);

   procedure Slice
     (Item : System.Address; Start, Length : Integer;
      Result : out System.Address; Status : out Slice_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Sliced then Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Find_Substring
     (Item, Pattern : System.Address; Ignore_Case : Boolean;
      Position : out Byte_Count; Status : out Search_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Matched then
         Item /= System.Null_Address and then Pattern /= System.Null_Address
           and then Position < Max_Bytes
         else Position = 0);

   procedure Find_Byte
     (Item : System.Address; Value : Character;
      Position : out Byte_Count; Status : out Search_Status;
      Limit : Byte_Count := Max_Bytes)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Status = Matched then
         Item /= System.Null_Address and then Value /= Character'Val (0)
           and then Position < Limit
         else Position = 0);

   function Compare_Bounded
     (Left, Right : System.Address; Length : Integer; Ignore_Case : Boolean)
      return Integer
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => Compare_Bounded'Result in -255 .. 255;

   function Fits (Left_Length, Right_Length : Natural) return Boolean is
     (Left_Length <= Max_Bytes
      and then Right_Length <= Max_Bytes - Left_Length)
     with Global => null;

   procedure Concatenate
     (Left, Right : String; Has_Left, Has_Right : Boolean;
      Result : out System.Address; Status : out Concatenate_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => (Has_Left or else Left'Length = 0)
         and then (Has_Right or else Right'Length = 0),
       Post => (if Status = Copied then Result /= System.Null_Address
                else Result = System.Null_Address);

   procedure Duplicate (Input : String; Result : out System.Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input'Length <= Max_Bytes;
end XML3_Text.Buffers;
