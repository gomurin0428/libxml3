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

   type C_Entity is record
      Private_Data : System.Address := System.Null_Address;
      Node_Type : int := 17;
      Name : System.Address := System.Null_Address;
      Children, Last, Parent, Next, Previous, Document : System.Address :=
        System.Null_Address;
      Original, Content : System.Address := System.Null_Address;
      Length : int := 1;
      Entity_Type : int := 6;
      External_ID, System_ID, Next_Entity, URI : System.Address :=
        System.Null_Address;
      Owner, Flags : int := 0;
      Expanded_Size : unsigned_long := 0;
   end record with Convention => C;

   Entity_Lt_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C (XML3_Text.Entity_Name (XML3_Text.Entity_Lt));
   Entity_Gt_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C (XML3_Text.Entity_Name (XML3_Text.Entity_Gt));
   Entity_Amp_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C (XML3_Text.Entity_Name (XML3_Text.Entity_Amp));
   Entity_Apos_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C (XML3_Text.Entity_Name (XML3_Text.Entity_Apos));
   Entity_Quot_Name : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C (XML3_Text.Entity_Name (XML3_Text.Entity_Quot));

   Entity_Lt_Value : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C
       (String'(1 => XML3_Text.Entity_Value (XML3_Text.Entity_Lt)));
   Entity_Gt_Value : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C
       (String'(1 => XML3_Text.Entity_Value (XML3_Text.Entity_Gt)));
   Entity_Amp_Value : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C
       (String'(1 => XML3_Text.Entity_Value (XML3_Text.Entity_Amp)));
   Entity_Apos_Value : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C
       (String'(1 => XML3_Text.Entity_Value (XML3_Text.Entity_Apos)));
   Entity_Quot_Value : aliased constant Interfaces.C.char_array :=
     Interfaces.C.To_C
       (String'(1 => XML3_Text.Entity_Value (XML3_Text.Entity_Quot)));

   function Name_Address
     (Kind : XML3_Text.Predefined_Entity_Kind) return System.Address is
     (case Kind is
         when XML3_Text.Entity_Lt => Entity_Lt_Name'Address,
         when XML3_Text.Entity_Gt => Entity_Gt_Name'Address,
         when XML3_Text.Entity_Amp => Entity_Amp_Name'Address,
         when XML3_Text.Entity_Apos => Entity_Apos_Name'Address,
         when XML3_Text.Entity_Quot => Entity_Quot_Name'Address);

   function Value_Address
     (Kind : XML3_Text.Predefined_Entity_Kind) return System.Address is
     (case Kind is
         when XML3_Text.Entity_Lt => Entity_Lt_Value'Address,
         when XML3_Text.Entity_Gt => Entity_Gt_Value'Address,
         when XML3_Text.Entity_Amp => Entity_Amp_Value'Address,
         when XML3_Text.Entity_Apos => Entity_Apos_Value'Address,
         when XML3_Text.Entity_Quot => Entity_Quot_Value'Address);

   function Make_Entity
     (Kind : XML3_Text.Predefined_Entity_Kind) return C_Entity is
     (Private_Data => System.Null_Address,
      Node_Type => 17,
      Name => Name_Address (Kind),
      Children => System.Null_Address,
      Last => System.Null_Address,
      Parent => System.Null_Address,
      Next => System.Null_Address,
      Previous => System.Null_Address,
      Document => System.Null_Address,
      Original => Value_Address (Kind),
      Content => Value_Address (Kind),
      Length => 1,
      Entity_Type => 6,
      External_ID => System.Null_Address,
      System_ID => System.Null_Address,
      Next_Entity => System.Null_Address,
      URI => System.Null_Address,
      Owner => 0,
      Flags => 0,
      Expanded_Size => 0);

   type Entity_Array is
     array (XML3_Text.Predefined_Entity_Kind) of aliased C_Entity;

   Predefined_Entities : constant Entity_Array :=
     (XML3_Text.Entity_Lt => Make_Entity (XML3_Text.Entity_Lt),
      XML3_Text.Entity_Gt => Make_Entity (XML3_Text.Entity_Gt),
      XML3_Text.Entity_Amp => Make_Entity (XML3_Text.Entity_Amp),
      XML3_Text.Entity_Apos => Make_Entity (XML3_Text.Entity_Apos),
      XML3_Text.Entity_Quot => Make_Entity (XML3_Text.Entity_Quot));

   function Predefined_Entity
     (Kind : XML3_Text.Predefined_Entity_Kind) return System.Address is
     (Predefined_Entities (Kind)'Address);

   function C_Malloc (Bytes : size_t) return System.Address
     with Import, Convention => C, External_Name => "malloc";
   procedure C_Free (Base : System.Address)
     with Import, Convention => C, External_Name => "free";
   function C_Memmove (Target, Source : System.Address; Count : size_t) return System.Address
     with Import, Convention => C, External_Name => "memmove";
   function C_Memcmp (Left, Right : System.Address; Count : size_t) return int
     with Import, Convention => C, External_Name => "memcmp";

   procedure Read_Character_Range_Group
     (Base : System.Address; Value : out Character_Range_Group)
   is
      Item : constant Character_Range_Group with Import, Address => Base;
   begin
      Value := Item;
   end Read_Character_Range_Group;

   procedure Read_Character_Range
     (Base : System.Address; Index : Natural; Short_Range : Boolean;
      Low, High : out Interfaces.C.unsigned)
   is
   begin
      if Short_Range then
         declare
            Item : constant C_Short_Range with Import,
              Address => Offset (Base, Byte_Count (Index) * Short_Range_Bytes);
         begin
            Low := unsigned (Item.Low);
            High := unsigned (Item.High);
         end;
      else
         declare
            Item : constant C_Long_Range with Import,
              Address => Offset (Base, Byte_Count (Index) * Long_Range_Bytes);
         begin
            Low := Item.Low;
            High := Item.High;
         end;
      end if;
   end Read_Character_Range;

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

   function Address_Value (Base : System.Address) return Integer_Address is
     (To_Integer (Base));

   procedure Write_Address
     (Base : System.Address; Index : Natural; Value : System.Address)
   is
      Slot : System.Address with Import,
        Address => Offset (Base, Byte_Count (Index) * Address_Bytes);
   begin
      Slot := Value;
   end Write_Address;

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
      Id : constant Metadata_Access :=
        To_Metadata (Facade - Storage_Offset (Metadata_Bytes));
   begin
      if Id.Id = size_t (Value.Id)
        and then Item.Node_Type = Value.Node_Type
        and then Item.Name = Value.Name
        and then Item.Children = Value.Children
        and then Item.Last = Value.Last
        and then Item.Parent = Value.Parent
        and then Item.Next = Value.Next
        and then Item.Previous = Value.Previous
        and then Item.Document = Value.Document
      then
         if Value.Is_Document then
            if To_Document (Facade).Version = Value.Content then
               return;
            end if;
         elsif Item.Namespace = Value.Namespace
           and then Item.Content = Value.Content
           and then Item.Properties = Value.Properties
           and then Item.Namespace_Definitions = Value.Namespace_Definitions
         then
            return;
         end if;
      end if;

      Id.Id := size_t (Value.Id);
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
      Id : constant Metadata_Access :=
        To_Metadata (Facade - Storage_Offset (Metadata_Bytes));
   begin
      if Id.Id = size_t (Value.Id)
        and then Item.Node_Type = 18
        and then Item.Next = Value.Next
        and then Item.Href = Value.Href
        and then Item.Prefix = Value.Prefix
        and then Item.Context = System.Null_Address
      then
         return;
      end if;

      Id.Id := size_t (Value.Id);
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
