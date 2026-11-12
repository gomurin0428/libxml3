with System;
with XML3_Native_Memory;

--  The xmlBuffer operations of libxml2 2.15.4 in its only remaining
--  allocation scheme (XML_BUFFER_ALLOC_IO).  A buffer is the allocation
--  Base (contentIO) and the content Offset bytes into it; Size counts the
--  bytes available from the content, Used the bytes in use.  A non-empty
--  allocation keeps a NUL after the used bytes.  The adapter reads and
--  writes the public struct; the sizes and every allocation, copy and
--  release are decided here.
package XML3_Byte_Buffers with SPARK_Mode is
   use type System.Address;

   --  C int limit used by the libxml2 size checks.
   Max_Size : constant := Integer'Last;

   type Buffer is record
      Base : System.Address := System.Null_Address;
      Offset : Natural := 0;
      Used : Natural := 0;
      Size : Natural := 0;
   end record;

   function Well_Formed (B : Buffer) return Boolean is
     (if B.Base = System.Null_Address
      then B.Offset = 0 and then B.Used = 0 and then B.Size = 0
      else B.Used < B.Size and then B.Offset <= Max_Size - B.Size)
   with Global => null;

   function Content (B : Buffer) return System.Address
   with Global => null,
     Pre => Well_Formed (B);

   --  xmlBufferCreate (Default) and xmlBufferCreateSize: 256 bytes, or
   --  Requested + 1 bytes, or none for 0.  Ok is False when the request is
   --  too large or the allocation fails.
   procedure Create
     (Default : Boolean; Requested : Natural; B : out Buffer;
      Ok : out Boolean)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Post => Well_Formed (B);

   --  xmlBufferGrow: -1 on failure, otherwise the result libxml2 returns
   --  (0 when there was already room).
   procedure Grow (B : in out Buffer; Length : Natural; Result : out Integer)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B),
     Post => Well_Formed (B) and then Result >= -1;

   type Add_Status is (Added, No_Memory);

   --  xmlBufferAdd of Length bytes at Source, which may lie in the buffer
   --  itself as in libxml2 (the bytes are moved, not copied).
   procedure Add
     (B : in out Buffer; Source : System.Address; Length : Natural;
      Status : out Add_Status)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B) and then Source /= System.Null_Address,
     Post => Well_Formed (B)
       and then (if Status = Added then B.Used = B'Old.Used + Length
                 else B.Used = B'Old.Used);

   --  xmlBufferAddHead.
   procedure Add_Head
     (B : in out Buffer; Source : System.Address; Length : Natural;
      Status : out Add_Status)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B) and then Source /= System.Null_Address,
     Post => Well_Formed (B);

   --  xmlBufferShrink: -1 when Length exceeds the used bytes.
   procedure Shrink (B : in out Buffer; Length : Natural; Result : out Integer)
   with Global => null,
     Pre => Well_Formed (B),
     Post => Well_Formed (B);

   --  xmlBufferEmpty.
   procedure Empty (B : in out Buffer)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B),
     Post => Well_Formed (B) and then B.Used = 0;

   --  xmlBufferDetach: the content becomes the caller's; a shrunk buffer
   --  returns a copy (NULL when it cannot be made) and frees its block.
   procedure Detach (B : in out Buffer; Result : out System.Address)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B),
     Post => B = (others => <>);

   --  xmlBufferWriteQuotedString: the text in double quotes, in single
   --  quotes when it contains a double quote, or in double quotes with
   --  each double quote written as &quot; when it contains both.  Failed
   --  additions are ignored, as in libxml2.
   procedure Add_Quoted
     (B : in out Buffer; Source : System.Address; Length : Natural)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B)
       and then (Length = 0 or else Source /= System.Null_Address),
     Post => Well_Formed (B);

   --  xmlAttrSerializeTxtContent for a document without an encoding: the
   --  text escaped as an attribute value, with every non-ASCII character
   --  (U+FFFD for malformed UTF-8 and for U+FFFE / U+FFFF) and every
   --  control character other than TAB, LF and CR written as a
   --  hexadecimal character reference.  Ok is False when an addition
   --  failed.
   procedure Add_Attribute_Text
     (B : in out Buffer; Source : System.Address; Length : Natural;
      Ok : out Boolean)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B)
       and then (Length = 0 or else Source /= System.Null_Address),
     Post => Well_Formed (B);

   --  The int results of xmlBufferAdd and xmlBufferAddHead: libxml2
   --  answers XML_ERR_OK, XML_ERR_ARGUMENT for a missing buffer or string
   --  and XML_ERR_NO_MEMORY, except that xmlBufferAddHead answers -1 when
   --  it cannot grow.
   OK_Code : constant := 0;
   Argument_Code : constant := 115;
   No_Memory_Code : constant := 2;

   function Add_Code (Status : Add_Status) return Integer is
     (if Status = Added then OK_Code else No_Memory_Code)
   with Global => null;

   function Add_Head_Code (Status : Add_Status) return Integer is
     (if Status = Added then OK_Code else -1)
   with Global => null;

   --  The block of xmlBufferFree.
   procedure Release (B : in out Buffer)
   with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
     Pre => Well_Formed (B),
     Post => B = (others => <>);

end XML3_Byte_Buffers;
