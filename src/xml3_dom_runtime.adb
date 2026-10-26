with XML3_DOM_Constructors;
with XML3_DOM_Store.Properties;

package body XML3_DOM_Runtime
  with SPARK_Mode, Refined_State => (Managed => Current)
is
   use type XML3_DOM.Node_Kind;
   use type XML3_DOM_Store.Operation_Status;
   use type System.Address;

   function Has_Colon (Name : String) return Boolean is
   begin
      for I in Name'Range loop
         if Name (I) = ':' then
            return True;
         end if;
      end loop;
      return False;
   end Has_Colon;

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

      procedure Add_Child
        (Parent, Child : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Add_Child (Current, Parent, Child, Result, Status);
      end Add_Child;

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
         Item : XML3_DOM.Node_View;
         Found : Boolean;
      begin
         XML3_DOM_Store.Inspect (Current, Facade, Item, Found);
         if not Found
           or else Item.Kind = XML3_DOM.Document_Node
           or else Item.Kind = XML3_DOM.Attribute_Node
         then
            Status := XML3_DOM_Constructors.Invalid_Argument;
            return;
         end if;
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

      procedure Create_Property
        (Element : System.Address; Name, Value : String;
         Has_Value : Boolean; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Properties.Create_Property
           (Current, Element, Name, Value, Has_Value, Result, Status);
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

      procedure Unset_Property
        (Element : System.Address; Name : String;
         Removed : out Boolean;
         Status : out XML3_DOM_Store.Operation_Status)
      is
         Property : System.Address;
      begin
         Removed := False;
         if Has_Colon (Name) then
            Status := XML3_DOM_Constructors.Invalid_Argument;
            return;
         end if;
         XML3_DOM_Store.Queries.Find_Property
           (Current, Element, Name, XML3_DOM_Store.Queries.No_Namespace, "",
            Property, Status);
         if Status /= XML3_DOM_Constructors.Created
           or else Property = System.Null_Address
         then
            return;
         end if;
         XML3_DOM_Store.Release
           (Current, Property, XML3_DOM_Store.Plain_Attribute, True, Status);
         Removed := Status = XML3_DOM_Constructors.Created;
      end Unset_Property;

      procedure Find_Property
        (Element : System.Address; Name : String;
         Filter : XML3_DOM_Store.Queries.Property_Filter;
         Href : String; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Find_Property
           (Current, Element, Name, Filter, Href, Result, Status);
      end Find_Property;

      procedure Get_Property
        (Element : System.Address; Name : String;
         Filter : XML3_DOM_Store.Queries.Property_Filter;
         Href : String; Result : out System.Address;
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

      procedure Search_Namespace
        (Facade : System.Address;
         Mode : XML3_DOM_Store.Queries.Namespace_Query_Kind;
         Has_Value : Boolean; Value : String;
         Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Search_Namespace
           (Current, Facade, Mode, Has_Value, Value, Result, Status);
      end Search_Namespace;

      procedure Get_Content
        (Facade : System.Address; Result : out System.Address;
         Status : out XML3_DOM_Store.Operation_Status)
      is
      begin
         XML3_DOM_Store.Queries.Get_Content (Current, Facade, Result, Status);
      end Get_Content;
end XML3_DOM_Runtime;
