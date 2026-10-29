with Interfaces.C;
with System;
with System.Storage_Elements;
with XML3_Text;

package XML3_Native_Memory
  with SPARK_Mode,
    Abstract_State => (Foreign_Memory with External => Async_Readers)
is
   use type System.Address;
   use type Interfaces.C.ptrdiff_t;
   subtype Byte_Count is Interfaces.C.ptrdiff_t range 0 .. Interfaces.C.ptrdiff_t'Last;
   subtype Positive_Byte_Count is Byte_Count range 1 .. Byte_Count'Last;
   Address_Bytes : constant Positive_Byte_Count;

   function Predefined_Entity (Kind : XML3_Text.Predefined_Entity_Kind)
      return System.Address
     with Global => null, Post => Predefined_Entity'Result /= System.Null_Address;

   type Character_Range_Group is record
      Short_Count, Long_Count : Interfaces.C.int;
      Short_Ranges, Long_Ranges : System.Address;
   end record with Convention => C;

   Short_Range_Bytes : constant Positive_Byte_Count;
   Long_Range_Bytes : constant Positive_Byte_Count;

   procedure Read_Character_Range_Group
     (Base : System.Address; Value : out Character_Range_Group)
     with Global => (Input => Foreign_Memory), Pre => Base /= System.Null_Address;

   procedure Read_Character_Range
     (Base : System.Address; Index : Natural; Short_Range : Boolean;
      Low, High : out Interfaces.C.unsigned)
     with Global => (Input => Foreign_Memory),
       Pre => Base /= System.Null_Address
         and then Byte_Count (Index) <= Byte_Count'Last /
           (if Short_Range then Short_Range_Bytes else Long_Range_Bytes);

   type Node_Projection is record
      Id : Natural := 0;
      Is_Document : Boolean := False;
      Node_Type : Interfaces.C.int := 0;
      Name, Children, Last, Parent, Next, Previous, Document,
        Namespace, Content, Properties, Namespace_Definitions : System.Address :=
          System.Null_Address;
   end record;

   type Namespace_Projection is record
      Id : Natural := 0;
      Next, Href, Prefix : System.Address := System.Null_Address;
   end record;

   Node_Bytes : constant Byte_Count;
   Node_Stride : constant Byte_Count;
   Namespace_Stride : constant Byte_Count;
   Metadata_Bytes : constant Byte_Count;

   procedure Allocate (Bytes : Byte_Count; Base : out System.Address)
     with Global => (In_Out => Foreign_Memory), Pre => Bytes > 0;
   procedure Free (Base : System.Address)
     with Global => (In_Out => Foreign_Memory);

   function Offset (Base : System.Address; Bytes : Byte_Count) return System.Address
     with Global => null;
   function Address_Value (Base : System.Address)
     return System.Storage_Elements.Integer_Address with Global => null;
   function Node_Id (Facade : System.Address) return Natural
     with Global => (Input => Foreign_Memory), Pre => Facade /= System.Null_Address;
   function Namespace_Id (Facade : System.Address) return Natural
     with Global => (Input => Foreign_Memory), Pre => Facade /= System.Null_Address;

   procedure Initialize_Node (Facade : System.Address)
     with Global => (In_Out => Foreign_Memory), Pre => Facade /= System.Null_Address;
   procedure Initialize_Namespace (Facade : System.Address)
     with Global => (In_Out => Foreign_Memory), Pre => Facade /= System.Null_Address;
   procedure Write_Node (Facade : System.Address; Value : Node_Projection)
     with Global => (In_Out => Foreign_Memory), Pre => Facade /= System.Null_Address;
   procedure Write_Namespace (Facade : System.Address; Value : Namespace_Projection)
     with Global => (In_Out => Foreign_Memory), Pre => Facade /= System.Null_Address;

   function Byte_At (Base : System.Address; Index : Natural) return Character
     with Global => (Input => Foreign_Memory), Pre => Base /= System.Null_Address;
   procedure Write_Byte (Base : System.Address; Index : Natural; Value : Character)
     with Global => (In_Out => Foreign_Memory), Pre => Base /= System.Null_Address;
   procedure Write_Address
     (Base : System.Address; Index : Natural; Value : System.Address)
     with Global => (In_Out => Foreign_Memory),
       Pre => Base /= System.Null_Address
         and then Byte_Count (Index) <= Byte_Count'Last / Address_Bytes;
   procedure Read_String (Base : System.Address; Value : out String)
     with Global => (Input => Foreign_Memory), Pre => Base /= System.Null_Address;
   procedure Write_String (Base : System.Address; Index : Natural; Value : String)
     with Global => (In_Out => Foreign_Memory), Pre => Base /= System.Null_Address;
   procedure Copy_Bytes
     (Source, Target : System.Address; Count : Natural)
     with Global => (In_Out => Foreign_Memory),
       Pre => Count = 0 or else
         (Source /= System.Null_Address and then Target /= System.Null_Address);
   function Equal_Bytes (Left, Right : System.Address; Count : Natural) return Boolean
     with Global => (Input => Foreign_Memory),
       Pre => Count = 0 or else
         (Left /= System.Null_Address and then Right /= System.Null_Address);

private
   pragma SPARK_Mode (Off);

   Address_Bytes : constant Positive_Byte_Count :=
     System.Address'Max_Size_In_Storage_Elements;

   type C_Short_Range is record
      Low, High : Interfaces.C.unsigned_short;
   end record with Convention => C;

   type C_Long_Range is record
      Low, High : Interfaces.C.unsigned;
   end record with Convention => C;

   Short_Range_Bytes : constant Positive_Byte_Count :=
     C_Short_Range'Max_Size_In_Storage_Elements;
   Long_Range_Bytes : constant Positive_Byte_Count :=
     C_Long_Range'Max_Size_In_Storage_Elements;

   type C_Node is record
      Private_Data : System.Address := System.Null_Address;
      Node_Type : Interfaces.C.int := 0;
      Name, Children, Last, Parent, Next, Previous, Document,
        Namespace, Content, Properties, Namespace_Definitions : System.Address :=
          System.Null_Address;
   end record with Convention => C, Volatile;

   type C_Document is record
      Private_Data : System.Address := System.Null_Address;
      Node_Type : Interfaces.C.int := 0;
      Name, Children, Last, Parent, Next, Previous, Document, Version : System.Address :=
        System.Null_Address;
   end record with Convention => C, Volatile;

   type C_Namespace is record
      Next : System.Address := System.Null_Address;
      Node_Type : Interfaces.C.int := 0;
      Href, Prefix, Private_Data, Context : System.Address := System.Null_Address;
   end record with Convention => C, Volatile;

   type Metadata is record
      Id : Interfaces.C.size_t := 0;
   end record with Convention => C, Volatile;

   Node_Bytes : constant Byte_Count := C_Node'Max_Size_In_Storage_Elements;
   Metadata_Bytes : constant Byte_Count := Metadata'Max_Size_In_Storage_Elements;
   Node_Stride : constant Byte_Count := Metadata_Bytes + Node_Bytes;
   Namespace_Stride : constant Byte_Count :=
     Metadata_Bytes + C_Namespace'Max_Size_In_Storage_Elements;
end XML3_Native_Memory;
