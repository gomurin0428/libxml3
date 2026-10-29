with System;
with XML3_DOM;
with XML3_DOM_Store;
with XML3_DOM_Store.Documents;
with XML3_DOM_Store.Queries;
with XML3_DOM_Store.Serialization;
with XML3_Encoding;
with XML3_Namespaces;
with XML3_Native_Memory;
with XML3_Parser;
with XML3_Text;

package XML3_DOM_Runtime
  with SPARK_Mode, Abstract_State => Managed
is
      procedure Read
        (Input : String; Huge : Boolean;
         Encoding : XML3_Encoding.Encoding_Info;
         Nodes : out XML3_Parser.Node_Array;
         Names : out XML3_Namespaces.Name_Array;
         Scratch_A, Scratch_B : in out String;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Documents.Read_Status;
         Diagnostic : out XML3_Parser.Diagnostic_Info)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory)),
          Pre => Input'First = 1
            and then Input'Length <= XML3_Text.Max_Bytes
            and then Input'Last in 0 .. XML3_Text.Max_Bytes
            and then Nodes'First = 1
            and then Nodes'Last in 1 .. XML3_Parser.Max_Nodes
            and then Names'First = 1 and then Names'Last = Nodes'Last
            and then Scratch_A'First = 1
            and then Scratch_A'Length = Input'Length
            and then Scratch_B'First = 1
            and then Scratch_B'Length = Input'Length;

      procedure Construct
        (Kind : XML3_DOM.Node_Kind; Name, Content : String;
         Has_Content : Boolean; Ns : System.Address;
         Result, Implicit_Ns : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Create_Namespace
        (Element : System.Address; Href, Prefix : String;
         Has_Href, Has_Prefix : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Copy_Namespace
        (Source : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Set_Namespace
        (Node, Ns : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Free_Namespace
        (Ns : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Add_Child
        (Parent, Child : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Add_Sibling
        (Sibling, Child : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Insert_Sibling
        (Sibling, Child : System.Address; Before : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure New_Child
        (Parent, Ns : System.Address; Name, Content : String;
         Raw_Content, Has_Content : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Merge_Text
        (First, Second : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Add_Content
        (Facade : System.Address; Suffix : String;
         Status : out XML3_DOM_Store.Operation_Status;
         Has_Input : Boolean := False; Text_Only : Boolean := False)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure New_Doc_Content
        (Doc : System.Address; Kind : XML3_DOM.Node_Kind;
         Name, Content : String; Has_Content : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure New_Doc_Node
        (Doc, Ns : System.Address; Name, Content : String;
         Raw_Content, Has_Content : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status;
         Attribute_Mode : Boolean := False)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Set_Content
        (Facade : System.Address; Content : String; Has_Content : Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Set_Root
        (Doc, Root : System.Address; Previous : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Unlink_Content
        (Facade : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Release
        (Facade : System.Address; Kind : XML3_DOM_Store.Release_Kind;
         Require_Parent : Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Release_List
        (Facade : System.Address; Kind : XML3_DOM_Store.Release_Kind;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Create_Property
        (Element : System.Address; Name, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Set_Property
        (Element : System.Address; Name, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Create_Namespace_Property
        (Element, Ns : System.Address; Name, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Set_Namespace_Property
        (Element, Ns : System.Address; Name, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Unset_Namespace_Property
        (Element, Ns : System.Address; Name : String; Removed : out Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Set_Qualified_Property
        (Element : System.Address; QName, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Unset_Property
        (Element : System.Address; Name : String;
         Removed : out Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Find_Property
        (Element : System.Address; Name : String;
         Filter : XML3_DOM_Store.Queries.Property_Filter;
         Href : String; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Get_Property
        (Element : System.Address; Name : String;
         Filter : XML3_DOM_Store.Queries.Property_Filter;
         Href : String; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Get_Inherited_XML_Property
        (Facade : System.Address; Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
         Result : out System.Address;
         Space : out XML3_DOM_Store.Queries.Space_Policy;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global =>
          (Input => Managed, In_Out => XML3_Native_Memory.Foreign_Memory);

      procedure Set_XML_Property
        (Element : System.Address; Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
         Value : String; Has_Value : Boolean; Space_Value : Integer;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Test_Node
        (Facade : System.Address; Mode : XML3_DOM_Store.Queries.Node_Test_Kind;
         Result : out Boolean; Status : out XML3_DOM_Store.Operation_Status)
        with Global => (Input => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Select_Element
        (Facade : System.Address; Mode : XML3_DOM_Store.Queries.Element_Query_Kind;
         Result : out System.Address; Count : out Natural;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Get_Namespace_List
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Search_Namespace
        (Facade : System.Address;
         Mode : XML3_DOM_Store.Queries.Namespace_Query_Kind;
         Has_Value : Boolean; Value : String;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Get_Content
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Get_Path
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
        with Global => (In_Out => (Managed, XML3_Native_Memory.Foreign_Memory));

      procedure Dump_Memory_Encoding
        (Document : System.Address; Encoding : String;
         Result : out System.Address; Length : out Natural;
         Status : out XML3_DOM_Store.Operation_Status;
         Default_Encoding, Formatted : Boolean := False)
        with Global =>
          (Input => Managed, In_Out => XML3_Native_Memory.Foreign_Memory);

private
   Current : XML3_DOM_Store.Store with Part_Of => Managed;
end XML3_DOM_Runtime;
