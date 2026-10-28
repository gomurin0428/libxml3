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

   procedure Doc_Dump_Memory_Enc
     (Document, Memory, Size, Encoding : System.Address)
     with Export, Convention => C, External_Name => "xmlDocDumpMemoryEnc";

   function New_Node
     (Ns, Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNode";

   function New_Doc_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocNode";

   function New_Doc_Prop
     (Doc, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocProp";

   function New_Doc_Raw_Node
     (Doc, Ns, Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocRawNode";

   function New_Child
     (Parent, Ns, Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewChild";

   function New_Text_Child
     (Parent, Ns, Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewTextChild";

   function New_Text (Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewText";

   function New_Text_Len
     (Content : System.Address; Length : Interfaces.C.int)
     return System.Address
     with Export, Convention => C, External_Name => "xmlNewTextLen";

   function New_Doc_Text
     (Doc, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocText";

   function New_Doc_Text_Len
     (Doc, Content : System.Address; Length : Interfaces.C.int)
     return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocTextLen";

   function New_Comment (Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewComment";

   function New_PI (Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewPI";

   function New_Doc_Comment
     (Doc, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocComment";

   function New_CData_Block
     (Doc, Content : System.Address; Length : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlNewCDataBlock";

   function New_Doc_PI
     (Doc, Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocPI";

   function Doc_Set_Root_Element
     (Doc, Root : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlDocSetRootElement";

   function Add_Child
     (Parent, Child : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlAddChild";

   function Add_Sibling
     (Sibling, Child : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlAddSibling";

   function Text_Merge
     (First, Second : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlTextMerge";

   function Node_Add_Content
     (Node, Content : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeAddContent";

   function Node_Is_Text (Node : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeIsText";

   function Is_Blank_Node (Node : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsBlankNode";

   function Text_Concat
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlTextConcat";

   function Node_Add_Content_Len
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeAddContentLen";

   function Node_Set_Content
     (Node, Content : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeSetContent";

   function Node_Set_Content_Len
     (Node, Content : System.Address; Length : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeSetContentLen";

   procedure Unlink_Node (Node : System.Address)
     with Export, Convention => C, External_Name => "xmlUnlinkNode";

   procedure Free_Node (Node : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNode";

   procedure Free_Node_List (Node : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNodeList";

   procedure Free_Doc (Doc : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeDoc";

   function New_Ns
     (Node, Href, Prefix : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNs";

   procedure Set_Ns (Node, Ns : System.Address)
     with Export, Convention => C, External_Name => "xmlSetNs";

   function Copy_Ns (Source : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCopyNamespace";

   procedure Free_Ns (Ns : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNs";

   function Node_Get_Content (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNodeGetContent";

   function Node_Get_Lang (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNodeGetLang";

   function Node_Get_Space_Preserve
     (Node : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeGetSpacePreserve";

   function Node_Set_Lang
     (Node, Language : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeSetLang";

   function Node_Set_Space_Preserve
     (Node : System.Address; Value : Interfaces.C.int) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeSetSpacePreserve";

   function Get_Prop
     (Node : System.Address;
      Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetProp";

   function New_Prop
     (Node, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewProp";

   function New_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNsProp";

   function Set_Ns_Prop
     (Node, Ns, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSetNsProp";

   function Unset_Ns_Prop
     (Node, Ns, Name : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUnsetNsProp";

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

   procedure Free_Prop_List (Attribute : System.Address)
     with Export, Convention => C, External_Name => "xmlFreePropList";

   function Has_Prop
     (Node : System.Address;
      Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlHasProp";

   function Get_Ns_List (Doc, Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetNsList";

   function Get_Ns_List_Safe (Doc, Node, Output : System.Address)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlGetNsListSafe";

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

   function Node_Get_Attr_Value
     (Node, Name, Href, Output : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeGetAttrValue";

   function Get_No_Ns_Prop
     (Node, Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetNoNsProp";

   function First_Element_Child (Parent : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlFirstElementChild";

   function Get_Last_Child (Parent : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetLastChild";

   function Last_Element_Child (Parent : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlLastElementChild";

   function Next_Element_Sibling (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNextElementSibling";

   function Previous_Element_Sibling (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlPreviousElementSibling";

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

   function Str_Case_Compare
     (Left, Right : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrcasecmp";

   function Str_Duplicate (Item : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlStrdup";

   function Str_Character
     (Item : System.Address; Value : Interfaces.C.unsigned_char)
      return System.Address
     with Export, Convention => C, External_Name => "xmlStrchr";

   function Str_Q_Equal
     (Prefix, Name, Value : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrQEqual";

   function Str_Substring (Item, Pattern : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlStrstr";

   function Str_Sub_Copy
     (Item : System.Address; Start, Length : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlStrsub";

   function Str_Case_Substring
     (Item, Pattern : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlStrcasestr";

   function Char_Str_Duplicate (Item : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCharStrdup";

   function Char_Str_N_Duplicate
     (Item : System.Address; Length : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlCharStrndup";

   function Str_N_Compare
     (Left, Right : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrncmp";

   function Str_N_Case_Compare
     (Left, Right : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlStrncasecmp";

   function Str_N_Concat_New
     (Left, Right : System.Address; Length : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlStrncatNew";

   function Str_N_Duplicate
     (Item : System.Address; Length : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlStrndup";

   function Build_QName
     (Name, Prefix, Memory : System.Address; Length : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlBuildQName";

   function Split_QName2 (Name, Prefix : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSplitQName2";

   function Split_QName3 (Name, Length : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSplitQName3";

   function Validate_Name (Value : System.Address; Space : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateName";

   function Validate_NCName (Value : System.Address; Space : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateNCName";

   function Validate_QName (Value : System.Address; Space : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateQName";

   function Validate_NMToken (Value : System.Address; Space : Interfaces.C.int)
     return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateNMToken";

   procedure Free (Item : System.Address)
     with Export, Convention => C, External_Name => "xmlFree";

end XML3_C;
