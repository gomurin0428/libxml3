with XML3_DOM_Constructors;
with XML3_DOM_Store.Content;
with XML3_DOM_Store.Copies;
with XML3_DOM_Store.Properties;
with XML3_DOM_Store.Serialization;

package body XML3_DOM_Runtime
  with SPARK_Mode, Refined_State => (Managed => Current)
is
   use type XML3_DOM.Node_Kind;
   use type XML3_DOM_Store.Operation_Status;
   use type System.Address;

      procedure Read
        (Input : String; Huge : Boolean;
         Encoding : XML3_Encoding.Encoding_Info;
         Nodes : out XML3_Parser.Node_Array;
         Names : out XML3_Namespaces.Name_Array;
         Scratch_A, Scratch_B : in out String;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Documents.Read_Status;
         Diagnostic : out XML3_Parser.Diagnostic_Info)
      is
      begin
         XML3_DOM_Store.Documents.Read
           (Current, Input, Huge, Encoding, Nodes, Names, Scratch_A, Scratch_B,
            Result, Status, Diagnostic);
      end Read;

      procedure Construct
        (Kind : XML3_DOM.Node_Kind; Name, Content : String;
         Has_Content : Boolean; Ns : System.Address;
         Result, Implicit_Ns : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Construct
           (Current, Kind, Name, Content, Has_Content, Ns, Result, Implicit_Ns,
            Status);
      end Construct;

      procedure New_Document
        (Version : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.New_Document (Current, Version, Result, Status);
      end New_Document;

      procedure Create_Namespace
        (Element, Href, Prefix : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Create_Namespace
           (Current, Element, Href, Prefix, Result, Status);
      end Create_Namespace;

      procedure Copy_Namespace
        (Source : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Copy_Namespace (Current, Source, Result, Status);
      end Copy_Namespace;

      procedure Set_Namespace
        (Node, Ns : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Set_Namespace (Current, Node, Ns, Status);
      end Set_Namespace;

      procedure Free_Namespace
        (Ns : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Free_Namespace (Current, Ns, Status);
      end Free_Namespace;

      procedure Add_Child
        (Parent, Child : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Add_Child (Current, Parent, Child, Result, Status);
      end Add_Child;

      procedure Add_Sibling
        (Sibling, Child : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Add_Sibling (Current, Sibling, Child, Result, Status);
      end Add_Sibling;

      procedure Insert_Sibling
        (Sibling, Child : System.Address; Before : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Insert_Sibling
           (Current, Sibling, Child, Before, Result, Status);
      end Insert_Sibling;

      procedure Replace_Node
        (Old, Cur : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Replace_Node (Current, Old, Cur, Result, Status);
      end Replace_Node;

      procedure Copy_Node
        (Source, Doc : System.Address; Extended : Integer;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Copies.Copy_Node
           (Current, Source, Doc, XML3_DOM_Store.Copies.Mode_For (Extended),
            Result, Status);
      end Copy_Node;

      procedure Copy_Property
        (Target, Source : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Copies.Copy_Property
           (Current, Target, Source, Result, Status);
      end Copy_Property;

      procedure Copy_Document
        (Source : System.Address; Recursive : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Copies.Copy_Document
           (Current, Source, Recursive, Result, Status);
      end Copy_Document;

      procedure Merge_Text
        (First, Second : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Merge_Text (Current, First, Second, Result, Status);
      end Merge_Text;

      procedure New_Child
        (Parent, Ns, Name, Content : System.Address;
         Raw_Content : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Content.New_Child
           (Current, Parent, Ns, Name, Content, Raw_Content,
            Result, Status);
      end New_Child;

      procedure New_Doc_Node
        (Doc, Ns, Name, Content : System.Address;
         Raw_Content : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status;
         Attribute_Mode : Boolean := False)
      is
      begin
         XML3_DOM_Store.Content.New_Doc_Node
           (Current, Doc, Ns, Name, Content, Raw_Content,
            Result, Status, Attribute_Mode);
      end New_Doc_Node;

      procedure Add_Content
        (Facade, Suffix : System.Address; Length : Integer; Bounded : Boolean;
         Status : out XML3_DOM_Store.Operation_Status;
         Text_Only : Boolean := False)
      is
      begin
         XML3_DOM_Store.Content.Append
           (Current, Facade, Suffix, Length, Bounded, Status, Text_Only);
      end Add_Content;

      procedure Set_Name
        (Facade, Name : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Content.Set_Name (Current, Facade, Name, Status);
      end Set_Name;

      procedure Set_Content
        (Facade, Content : System.Address; Length : Integer;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Content.Set
           (Current, Facade, Content, Length, Status);
      end Set_Content;

      procedure New_Doc_Content
        (Doc : System.Address; Kind : XML3_DOM.Node_Kind;
         Name : String; Content : System.Address; Length : Integer;
         Terminated : Boolean;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status;
         Name_Source : System.Address := System.Null_Address)
      is
      begin
         XML3_DOM_Store.Content.New_Doc_Content_Bytes
           (Current, Doc, Kind, Name, Content, Length, Terminated, Result, Status,
            Name_Source);
      end New_Doc_Content;

      procedure Parse_Content_List
        (Doc, Content : System.Address; Length : Integer;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Content.Parse_Content_List
           (Current, Doc, Content, Length, Result, Status);
      end Parse_Content_List;

      procedure Set_Root
        (Doc, Root : System.Address; Previous : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Set_Root (Current, Doc, Root, Previous, Status);
      end Set_Root;

      procedure Unlink_Content
        (Facade : System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Unlink (Current, Facade, Status);
      end Unlink_Content;

      procedure Release
        (Facade : System.Address; Kind : XML3_DOM_Store.Release_Kind;
         Require_Parent : Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Release (Current, Facade, Kind, Require_Parent, Status);
      end Release;

      procedure Release_List
        (Facade : System.Address; Kind : XML3_DOM_Store.Release_Kind;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Release_List (Current, Facade, Kind, Status);
      end Release_List;

      procedure Create_Property
        (Element, Name, Value : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Create_Property
           (Current, Element, Name, Value, Result, Status);
      end Create_Property;

      procedure Set_Property
        (Element : System.Address; Name, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Set_Property
           (Current, Element, Name, Value, Has_Value, Result, Status);
      end Set_Property;

      procedure Create_Namespace_Property
        (Element, Ns, Name, Value : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Edit_Namespace_Property
           (Current, Element, Ns, Name, Value, False, Result, Status);
      end Create_Namespace_Property;

      procedure Set_Namespace_Property
        (Element, Ns, Name, Value : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Edit_Namespace_Property
           (Current, Element, Ns, Name, Value, True, Result, Status);
      end Set_Namespace_Property;

      procedure Unset_Namespace_Property
        (Element, Ns, Name : System.Address; Removed : out Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Unset_Property
           (Current, Element, Ns, Name, True, Removed, Status);
      end Unset_Namespace_Property;

      procedure Set_Qualified_Property
        (Element, QName, Value : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Set_Qualified_Property
           (Current, Element, QName, Value, Result, Status);
      end Set_Qualified_Property;

      procedure Unset_Property
        (Element, Name : System.Address;
         Removed : out Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Unset_Property
           (Current, Element, System.Null_Address, Name, False, Removed, Status);
      end Unset_Property;

      procedure Find_Property
        (Element, Name : System.Address;
         Filter : XML3_DOM_Store.Queries.Property_Filter;
         Href : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Find_Property
           (Current, Element, Name, Filter, Href, Result, Status);
      end Find_Property;

      procedure Get_Property
        (Element, Name : System.Address;
         Filter : XML3_DOM_Store.Queries.Property_Filter;
         Href : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
         Property : System.Address;
      begin
         XML3_DOM_Store.Queries.Find_Property
           (Current, Element, Name, Filter, Href, Property, Status);
         if Status /= XML3_DOM_Constructors.Created
           or else Property = System.Null_Address
         then
            Result := System.Null_Address;
            return;
         end if;
         XML3_DOM_Store.Queries.Get_Content (Current, Property, Result, Status);
      end Get_Property;

      procedure Get_Inherited_XML_Property
        (Facade : System.Address; Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
         Result : out System.Address;
         Space : out XML3_DOM_Store.Queries.Space_Policy;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Get_Inherited_XML_Property
           (Current, Facade, Mode, Result, Space, Status);
      end Get_Inherited_XML_Property;

      procedure Set_XML_Property
        (Element : System.Address; Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
         Value : System.Address; Space_Value : Integer;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Set_XML_Property
           (Current, Element, Mode, Value, Space_Value, Status);
      end Set_XML_Property;

      procedure Test_Node
        (Facade : System.Address; Mode : XML3_DOM_Store.Queries.Node_Test_Kind;
         Result : out Boolean; Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Test_Node (Current, Facade, Mode, Result, Status);
      end Test_Node;

      procedure Select_Element
        (Facade : System.Address;
         Mode : XML3_DOM_Store.Queries.Element_Query_Kind;
         Result : out System.Address; Count : out Natural;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Select_Element
           (Current, Facade, Mode, Result, Count, Status);
      end Select_Element;

      procedure Get_Namespace_List
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Get_Namespace_List
           (Current, Facade, Result, Status);
      end Get_Namespace_List;

      procedure Search_Namespace
        (Facade : System.Address;
         Mode : XML3_DOM_Store.Queries.Namespace_Query_Kind;
         Value : System.Address;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Lookup_Namespace
           (Current, Facade, Mode, Value, Result, Status);
      end Search_Namespace;

      procedure Get_Content
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Get_Content (Current, Facade, Result, Status);
      end Get_Content;

      procedure Get_List_Content
        (Facade : System.Address; Escape : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status;
         Doc : System.Address := System.Null_Address;
         Default_Entities : Boolean := False)
      is
      begin
         XML3_DOM_Store.Queries.Get_List_Content
           (Current, Facade, Escape, Result, Status, Doc, Default_Entities);
      end Get_List_Content;

      procedure Get_Document_Entity
        (Document, Name : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Get_Document_Entity
           (Current, Document, Name, Result, Status);
      end Get_Document_Entity;

      procedure Encode_Entities
        (Document, Input : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Encode_Entities
           (Current, Document, Input, Result, Status);
      end Encode_Entities;

      procedure Get_Path
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Get_Path (Current, Facade, Result, Status);
      end Get_Path;

      procedure Get_Line_Number
        (Facade : System.Address; Result : out Integer)
      is
      begin
         XML3_DOM_Store.Queries.Get_Line_Number (Current, Facade, Result);
      end Get_Line_Number;

      procedure Dump_Node
        (Node : System.Address; Level : Integer; Formatted : Boolean;
         Result : out System.Address; Length : out Natural;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Serialization.Dump_Node
           (Current, Node, Level, Formatted, Result, Length, Status);
      end Dump_Node;

      procedure Dump_Memory_Encoding
        (Document, Encoding : System.Address;
         Result : out System.Address; Length : out Natural;
         Status : out XML3_DOM_Store.Operation_Status;
         Formatted : Boolean := False)
      is
      begin
         XML3_DOM_Store.Serialization.Dump
           (Current, Document, Encoding, Result, Length, Status,
            Formatted);
      end Dump_Memory_Encoding;

      procedure Save
        (Node, Encoding : System.Address;
         Document_Only, Formatted : Boolean;
         Style : XML3_Serialization.Output_Style;
         Result : out System.Address; Length : out Natural;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Serialization.Save
           (Current, Node, Encoding, Document_Only, Formatted, Style,
            Result, Length, Status);
      end Save;
end XML3_DOM_Runtime;
