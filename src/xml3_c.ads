--  C binding layer. This unit is deliberately outside SPARK: it performs
--  foreign pointer conversion and heap allocation. See docs/assurance.md.

with Interfaces.C;
with System;

package XML3_C is

   Status_OK               : constant Interfaces.C.int := 0;
   Status_Malformed        : constant Interfaces.C.int := 1;
   Status_Unsupported      : constant Interfaces.C.int := 2;
   Status_Limit_Exceeded   : constant Interfaces.C.int := 3;
   Status_Invalid_Argument : constant Interfaces.C.int := 4;
   Status_No_Memory        : constant Interfaces.C.int := 5;
   Status_Internal_Error   : constant Interfaces.C.int := 6;

   procedure Init_Parser
     with Export, Convention => C, External_Name => "xmlInitParser";

   procedure Cleanup_Parser
     with Export, Convention => C, External_Name => "xmlCleanupParser";

   function Read_Memory_Status
     (Buffer : System.Address;
      Size   : Interfaces.C.int;
      Status : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xml3ReadMemory";

   function Read_Memory
     (Buffer   : System.Address;
      Size     : Interfaces.C.int;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlReadMemory";

   function Parse_Memory
     (Buffer : System.Address;
      Size   : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlParseMemory";

   function Read_Doc
     (Cur      : System.Address;
      URL      : System.Address;
      Encoding : System.Address;
      Options  : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlReadDoc";

   function Parse_Doc (Cur : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlParseDoc";

   function Doc_Get_Root_Element (Doc : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlDocGetRootElement";

   function New_Doc (Version : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDoc";

   function New_Node
     (Ns, Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNode";

   function New_Text (Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewText";

   function Doc_Set_Root_Element
     (Doc, Root : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlDocSetRootElement";

   function Add_Child
     (Parent, Child : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlAddChild";

   procedure Unlink_Node (Node : System.Address)
     with Export, Convention => C, External_Name => "xmlUnlinkNode";

   procedure Free_Node (Node : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNode";

   procedure Free_Doc (Doc : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeDoc";

   function Node_Get_Content (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNodeGetContent";

   function Get_Prop
     (Node : System.Address;
      Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetProp";

   function New_Ns (Node, Href, Prefix : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNs";

   procedure Set_Ns (Node, Ns : System.Address)
     with Export, Convention => C, External_Name => "xmlSetNs";

   procedure Free_Ns (Ns : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNs";

   function New_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNsProp";

   function Set_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSetNsProp";

   function Unset_Ns_Prop (Node, Ns, Name : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUnsetNsProp";

   function New_Prop
     (Node, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewProp";

   function Set_Prop
     (Node, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSetProp";

   function Unset_Prop
     (Node, Name : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUnsetProp";

   function Remove_Prop (Attribute : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlRemoveProp";

   procedure Free_Prop (Attribute : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeProp";

   function Has_Prop
     (Node : System.Address;
      Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlHasProp";

   function Search_Ns
     (Doc, Node, Prefix : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSearchNs";

   function Search_Ns_By_Href
     (Doc, Node, Href : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSearchNsByHref";

   function Has_Ns_Prop
     (Node, Name, Href : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlHasNsProp";

   function Get_Ns_Prop
     (Node, Name, Href : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetNsProp";

   function Get_No_Ns_Prop
     (Node, Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetNoNsProp";

   function First_Element_Child (Parent : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlFirstElementChild";

   function Next_Element_Sibling (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNextElementSibling";

   function Child_Element_Count
     (Parent : System.Address) return Interfaces.C.unsigned_long
     with Export, Convention => C, External_Name => "xmlChildElementCount";

   function Str_Compare
     (Left  : System.Address;
      Right : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrcmp";

   function Str_Equal
     (Left  : System.Address;
      Right : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrEqual";

   function Str_Length (Item : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrlen";

   procedure Free (Item : System.Address)
     with Export, Convention => C, External_Name => "xmlFree";

end XML3_C;
