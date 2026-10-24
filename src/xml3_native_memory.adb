with Ada.Unchecked_Conversion;
with System.Storage_Elements;

package body XML3_Native_Memory with SPARK_Mode => Off is
   use Interfaces.C;
   use System.Storage_Elements;

   type Node_Access is access all C_Node;
   type Document_Access is access all C_Document;
   type Namespace_Access is access all C_Namespace;
   type Metadata_Access is access all Metadata;
   function To_Node is new Ada.Unchecked_Conversion (System.Address, Node_Access);
   function To_Document is new Ada.Unchecked_Conversion (System.Address, Document_Access);
   function To_Namespace is new Ada.Unchecked_Conversion (System.Address, Namespace_Access);
   function To_Metadata is new Ada.Unchecked_Conversion (System.Address, Metadata_Access);

   function C_Malloc (Bytes : size_t) return System.Address
     with Import, Convention => C, External_Name => "malloc";
   procedure C_Free (Base : System.Address)
     with Import, Convention => C, External_Name => "free";
   function C_Memmove (Target, Source : System.Address; Count : size_t) return System.Address
     with Import, Convention => C, External_Name => "memmove";
   function C_Memcmp (Left, Right : System.Address; Count : size_t) return int
     with Import, Convention => C, External_Name => "memcmp";

   procedure Allocate (Bytes : Byte_Count; Base : out System.Address) is
   begin
      Base := C_Malloc (size_t (Bytes));
   end Allocate;

   procedure Free (Base : System.Address) is
   begin
      C_Free (Base);
   end Free;

   function Offset (Base : System.Address; Bytes : Byte_Count) return System.Address is
     (Base + Storage_Offset (Bytes));

   function Read_Id (Facade : System.Address) return Natural is
      Value : constant size_t :=
        To_Metadata (Facade - Storage_Offset (Metadata_Bytes)).Id;
   begin
      return (if Value <= size_t (Natural'Last) then Natural (Value) else 0);
   end Read_Id;

   function Node_Id (Facade : System.Address) return Natural is (Read_Id (Facade));
   function Namespace_Id (Facade : System.Address) return Natural is (Read_Id (Facade));

   procedure Initialize_Node (Facade : System.Address) is
   begin
      To_Metadata (Facade - Storage_Offset (Metadata_Bytes)).all := (Id => 0);
      To_Node (Facade).all := (others => <>);
   end Initialize_Node;

   procedure Initialize_Namespace (Facade : System.Address) is
   begin
      To_Metadata (Facade - Storage_Offset (Metadata_Bytes)).all := (Id => 0);
      To_Namespace (Facade).all := (others => <>);
   end Initialize_Namespace;

   procedure Write_Node (Facade : System.Address; Value : Node_Projection) is
      Item : constant Node_Access := To_Node (Facade);
   begin
      To_Metadata (Facade - Storage_Offset (Metadata_Bytes)).Id := size_t (Value.Id);
      Item.Node_Type := Value.Node_Type;
      Item.Name := Value.Name;
      Item.Children := Value.Children;
      Item.Last := Value.Last;
      Item.Parent := Value.Parent;
      Item.Next := Value.Next;
      Item.Previous := Value.Previous;
      Item.Document := Value.Document;
      if Value.Is_Document then
         To_Document (Facade).Version := Value.Content;
      else
         Item.Namespace := Value.Namespace;
         Item.Content := Value.Content;
         Item.Properties := Value.Properties;
         Item.Namespace_Definitions := Value.Namespace_Definitions;
      end if;
   end Write_Node;

   procedure Write_Namespace (Facade : System.Address; Value : Namespace_Projection) is
      Item : constant Namespace_Access := To_Namespace (Facade);
   begin
      To_Metadata (Facade - Storage_Offset (Metadata_Bytes)).Id := size_t (Value.Id);
      Item.Node_Type := 18;
      Item.Next := Value.Next;
      Item.Href := Value.Href;
      Item.Prefix := Value.Prefix;
      Item.Context := System.Null_Address;
   end Write_Namespace;

   function Byte_At (Base : System.Address; Index : Natural) return Character is
      Value : Character with Import, Address => Base + Storage_Offset (Index);
   begin
      return Value;
   end Byte_At;

   procedure Write_Byte (Base : System.Address; Index : Natural; Value : Character) is
      Target : Character with Import, Address => Base + Storage_Offset (Index);
   begin
      Target := Value;
   end Write_Byte;

   procedure Read_String (Base : System.Address; Value : out String) is
      Source : String (Value'Range) with Import, Address => Base;
   begin
      Value := Source;
   end Read_String;

   procedure Write_String (Base : System.Address; Index : Natural; Value : String) is
      Target : String (Value'Range) with Import, Address => Base + Storage_Offset (Index);
   begin
      Target := Value;
   end Write_String;

   procedure Copy_Bytes (Source, Target : System.Address; Count : Natural) is
      Unused : System.Address;
   begin
      if Count > 0 then
         Unused := C_Memmove (Target, Source, size_t (Count));
      end if;
   end Copy_Bytes;

   function Equal_Bytes (Left, Right : System.Address; Count : Natural) return Boolean is
     (Count = 0 or else C_Memcmp (Left, Right, size_t (Count)) = 0);
end XML3_Native_Memory;
