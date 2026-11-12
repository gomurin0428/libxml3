--  C binding layer. This unit is deliberately outside SPARK: it performs
--  foreign pointer conversion and heap allocation. See docs/assurance.md.

with Interfaces.C;
with System;
with XML3_Errors;

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

   function Read_File
     (Name, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlReadFile";

   function Parse_File (Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlParseFile";

   function Read_Fd
     (Fd : Interfaces.C.int; URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlReadFd";

   function Read_IO
     (Read, Close, IO_Context, URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlReadIO";

   function New_Parser_Ctxt return System.Address
     with Export, Convention => C, External_Name => "xmlNewParserCtxt";

   procedure Free_Parser_Ctxt (Ctxt : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeParserCtxt";

   procedure Ctxt_Reset (Ctxt : System.Address)
     with Export, Convention => C, External_Name => "xmlCtxtReset";

   function Ctxt_Use_Options
     (Ctxt : System.Address; Options : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtUseOptions";

   function Ctxt_Set_Options
     (Ctxt : System.Address; Options : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtSetOptions";

   function Ctxt_Get_Options (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtGetOptions";

   function Ctxt_Read_Memory
     (Ctxt, Buffer : System.Address; Size : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtReadMemory";

   function Ctxt_Read_Doc
     (Ctxt, Cur, URL, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtReadDoc";

   function Ctxt_Read_File
     (Ctxt, Name, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtReadFile";

   function Ctxt_Read_Fd
     (Ctxt : System.Address; Fd : Interfaces.C.int;
      URL, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtReadFd";

   function Ctxt_Read_IO
     (Ctxt, Read, Close, IO_Context, URL, Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtReadIO";

   --  The output callbacks of xmlSaveToIO and xmlOutputBufferCreateIO.
   type Output_Write_Callback is access function
     (Context, Data : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int
     with Convention => C;
   type Output_Close_Callback is access function
     (Context : System.Address) return Interfaces.C.int
     with Convention => C;

   function Alloc_Output_Buffer (Encoder : System.Address)
      return System.Address
     with Export, Convention => C, External_Name => "xmlAllocOutputBuffer";

   function Output_Buffer_Create_IO
     (Write : Output_Write_Callback; Close : Output_Close_Callback;
      Context, Encoder : System.Address) return System.Address
     with Export, Convention => C,
       External_Name => "xmlOutputBufferCreateIO";

   function Output_Buffer_Create_Buffer
     (Buffer, Encoder : System.Address) return System.Address
     with Export, Convention => C,
       External_Name => "xmlOutputBufferCreateBuffer";

   function Output_Buffer_Create_Fd
     (Fd : Interfaces.C.int; Encoder : System.Address) return System.Address
     with Export, Convention => C,
       External_Name => "xmlOutputBufferCreateFd";

   function Output_Buffer_Create_File
     (Stream, Encoder : System.Address) return System.Address
     with Export, Convention => C,
       External_Name => "xmlOutputBufferCreateFile";

   function Output_Buffer_Create_Filename
     (URI, Encoder : System.Address; Compression : Interfaces.C.int)
      return System.Address
     with Export, Convention => C,
       External_Name => "xmlOutputBufferCreateFilename";

   function Output_Buffer_Write
     (Output : System.Address; Length : Interfaces.C.int;
      Data : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlOutputBufferWrite";

   function Output_Buffer_Write_String
     (Output, Text : System.Address) return Interfaces.C.int
     with Export, Convention => C,
       External_Name => "xmlOutputBufferWriteString";

   function Output_Buffer_Flush (Output : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlOutputBufferFlush";

   function Output_Buffer_Close (Output : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlOutputBufferClose";

   function Output_Buffer_Get_Content (Output : System.Address)
      return System.Address
     with Export, Convention => C,
       External_Name => "xmlOutputBufferGetContent";

   function Output_Buffer_Get_Size (Output : System.Address)
      return Interfaces.C.size_t
     with Export, Convention => C,
       External_Name => "xmlOutputBufferGetSize";

   procedure Node_Dump_Output
     (Output, Doc, Node : System.Address; Level, Format : Interfaces.C.int;
      Encoding : System.Address)
     with Export, Convention => C, External_Name => "xmlNodeDumpOutput";

   function Save_File_To (Output, Doc, Encoding : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFileTo";

   function Save_Format_File_To
     (Output, Doc, Encoding : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFormatFileTo";

   function Ctxt_Get_Private (Ctxt : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtGetPrivate";

   procedure Ctxt_Set_Private (Ctxt, Data : System.Address)
     with Export, Convention => C, External_Name => "xmlCtxtSetPrivate";

   function Ctxt_Get_User_Data (Ctxt : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtGetUserData";

   function Ctxt_Get_Document (Ctxt : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtGetDocument";

   function Ctxt_Get_Node (Ctxt : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtGetNode";

   function Ctxt_Is_Html (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtIsHtml";

   function Ctxt_Is_In_Subset (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtIsInSubset";

   function Ctxt_Is_Stopped (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtIsStopped";

   function Ctxt_Get_Status (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCtxtGetStatus";

   procedure Stop_Parser (Ctxt : System.Address)
     with Export, Convention => C, External_Name => "xmlStopParser";

   procedure Ctxt_Set_Error_Handler
     (Ctxt : System.Address; Handler : XML3_Errors.Structured_Handler;
      Data : System.Address)
     with Export, Convention => C, External_Name => "xmlCtxtSetErrorHandler";

   function Ctxt_Get_Last_Error (Ctxt : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCtxtGetLastError";

   procedure Ctxt_Reset_Last_Error (Ctxt : System.Address)
     with Export, Convention => C, External_Name => "xmlCtxtResetLastError";

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

   procedure Doc_Dump_Memory
     (Document, Memory, Size : System.Address)
     with Export, Convention => C, External_Name => "xmlDocDumpMemory";

   procedure Doc_Dump_Memory_Enc
     (Document, Memory, Size, Encoding : System.Address)
     with Export, Convention => C, External_Name => "xmlDocDumpMemoryEnc";

   procedure Doc_Dump_Format_Memory
     (Document, Memory, Size : System.Address; Format : Interfaces.C.int)
     with Export, Convention => C, External_Name => "xmlDocDumpFormatMemory";

   procedure Doc_Dump_Format_Memory_Enc
     (Document, Memory, Size, Encoding : System.Address;
      Format : Interfaces.C.int)
     with Export, Convention => C, External_Name => "xmlDocDumpFormatMemoryEnc";

   --  xmlBuffer and the serialization entry points that write to a
   --  buffer, a stream or a file.
   function Buffer_Create return System.Address
     with Export, Convention => C, External_Name => "xmlBufferCreate";
   function Buffer_Create_Size (Size : Interfaces.C.size_t)
      return System.Address
     with Export, Convention => C, External_Name => "xmlBufferCreateSize";
   function Buffer_Create_Static
     (Memory : System.Address; Size : Interfaces.C.size_t)
      return System.Address
     with Export, Convention => C, External_Name => "xmlBufferCreateStatic";
   procedure Buffer_Free (Buffer : System.Address)
     with Export, Convention => C, External_Name => "xmlBufferFree";
   procedure Buffer_Empty (Buffer : System.Address)
     with Export, Convention => C, External_Name => "xmlBufferEmpty";
   function Buffer_Shrink
     (Buffer : System.Address; Length : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferShrink";
   function Buffer_Grow
     (Buffer : System.Address; Length : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferGrow";
   function Buffer_Resize
     (Buffer : System.Address; Size : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferResize";
   function Buffer_Add
     (Buffer, Text : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferAdd";
   function Buffer_Add_Head
     (Buffer, Text : System.Address; Length : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferAddHead";
   function Buffer_Cat (Buffer, Text : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferCat";
   function Buffer_C_Cat (Buffer, Text : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferCCat";
   procedure Buffer_Write_Xml_Chars (Buffer, Text : System.Address)
     with Export, Convention => C, External_Name => "xmlBufferWriteCHAR";
   procedure Buffer_Write_C_Chars (Buffer, Text : System.Address)
     with Export, Convention => C, External_Name => "xmlBufferWriteChar";
   procedure Buffer_Write_Quoted_String (Buffer, Text : System.Address)
     with Export, Convention => C,
       External_Name => "xmlBufferWriteQuotedString";
   function Buffer_Content (Buffer : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlBufferContent";
   function Buffer_Length (Buffer : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferLength";
   function Buffer_Detach (Buffer : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlBufferDetach";
   procedure Buffer_Set_Allocation_Scheme
     (Buffer : System.Address; Scheme : Interfaces.C.int)
     with Export, Convention => C,
       External_Name => "xmlBufferSetAllocationScheme";
   function Buffer_Dump (Stream, Buffer : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBufferDump";

   function Node_Dump
     (Buffer, Doc, Node : System.Address;
      Level, Format : Interfaces.C.int) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeDump";
   procedure Elem_Dump (Stream, Doc, Node : System.Address)
     with Export, Convention => C, External_Name => "xmlElemDump";
   function Doc_Dump (Stream, Doc : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlDocDump";
   function Doc_Format_Dump
     (Stream, Doc : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlDocFormatDump";
   function Save_File (Name, Doc : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFile";
   function Save_Format_File
     (Name, Doc : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFormatFile";
   function Save_File_Enc
     (Name, Doc, Encoding : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFileEnc";
   function Save_Format_File_Enc
     (Name, Doc, Encoding : System.Address; Format : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFormatFileEnc";

   --  Creation that takes ownership of the name, buffer helpers and the
   --  namespace list release.
   function New_Node_Eat_Name (Ns, Name : System.Address)
      return System.Address
     with Export, Convention => C, External_Name => "xmlNewNodeEatName";
   function New_Doc_Node_Eat_Name
     (Doc, Ns, Name, Content : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewDocNodeEatName";
   function New_Ns_Prop_Eat_Name
     (Node, Ns, Name, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNewNsPropEatName";
   function Get_Buffer_Allocation_Scheme return Interfaces.C.int
     with Export, Convention => C,
       External_Name => "xmlGetBufferAllocationScheme";
   procedure Set_Buffer_Allocation_Scheme (Scheme : Interfaces.C.int)
     with Export, Convention => C,
       External_Name => "xmlSetBufferAllocationScheme";
   function Node_Buf_Get_Content (Buffer, Node : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNodeBufGetContent";
   procedure Attr_Serialize_Txt_Content
     (Buffer, Doc, Attribute, Text : System.Address)
     with Export, Convention => C,
       External_Name => "xmlAttrSerializeTxtContent";
   procedure Free_Ns_List (Ns : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNsList";

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

   function String_Get_Node_List
     (Doc, Value : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlStringGetNodeList";

   function Node_List_Get_Raw_String
     (Doc, List : System.Address; Inline_Value : Interfaces.C.int)
     return System.Address
     with Export, Convention => C, External_Name => "xmlNodeListGetRawString";

   function Node_List_Get_String
     (Doc, List : System.Address; Inline_Value : Interfaces.C.int)
     return System.Address
     with Export, Convention => C, External_Name => "xmlNodeListGetString";

   function String_Len_Get_Node_List
     (Doc, Value : System.Address; Length : Interfaces.C.int)
     return System.Address
     with Export, Convention => C, External_Name => "xmlStringLenGetNodeList";

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

   function Add_Previous_Sibling
     (Sibling, Child : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlAddPrevSibling";

   function Add_Next_Sibling
     (Sibling, Child : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlAddNextSibling";

   function Replace_Node
     (Old, Cur : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlReplaceNode";

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

   procedure Node_Set_Name (Node, Name : System.Address)
     with Export, Convention => C, External_Name => "xmlNodeSetName";

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

   function Copy_Node
     (Node : System.Address; Extended : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlCopyNode";

   function Doc_Copy_Node
     (Node, Doc : System.Address; Extended : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlDocCopyNode";

   function Copy_Prop (Target, Cur : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCopyProp";

   function Copy_Doc
     (Doc : System.Address; Recursive : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlCopyDoc";

   procedure Free_Ns (Ns : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeNs";

   function Node_Get_Content (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlNodeGetContent";

   function Node_Get_Path (Node : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetNodePath";

   function Node_Get_Line_No (Node : System.Address) return Interfaces.C.long
     with Export, Convention => C, External_Name => "xmlGetLineNo";

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

   function Check_UTF8 (Item : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCheckUTF8";

   function URI_Escape_Str (Input, Exceptions : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlURIEscapeStr";

   function Normalize_URI_Path (Path : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlNormalizeURIPath";

   function URI_Unescape_String
     (Input : System.Address; Length : Interfaces.C.int; Target : System.Address)
      return System.Address
     with Export, Convention => C, External_Name => "xmlURIUnescapeString";

   function Copy_Char_Multi_Byte
     (Output : System.Address; Code : Interfaces.C.int) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCopyCharMultiByte";

   function Copy_Char
     (Length : Interfaces.C.int; Output : System.Address; Code : Interfaces.C.int)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCopyChar";

   function Char_In_Range
     (Code : Interfaces.C.unsigned; Group : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlCharInRange";

   function Is_XML_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsChar";

   function Validate_Name_Value (Value : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateNameValue";

   function Validate_Names_Value (Value : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateNamesValue";

   function Validate_NMToken_Value (Value : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateNmtokenValue";

   function Validate_NMTokens_Value (Value : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlValidateNmtokensValue";

   function Get_Predefined_Entity (Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetPredefinedEntity";

   function Get_Document_Entity (Document, Name : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlGetDocEntity";

   function Is_XHTML (System_ID, Public_ID : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsXHTML";

   function Is_XML_Blank (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsBlank";

   function Is_XML_Base_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsBaseChar";

   function Is_XML_Combining (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsCombining";

   function Is_XML_Digit (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsDigit";

   function Is_XML_Extender (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsExtender";

   function Is_XML_Ideographic (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsIdeographic";

   function Is_XML_Pubid_Char (Code : Interfaces.C.unsigned) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlIsPubidChar";

   function UTF8_Str_Length (Item : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUTF8Strlen";

   function UTF8_Str_Size
     (Item : System.Address; Characters : Interfaces.C.int) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUTF8Strsize";

   function UTF8_Size (Item : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUTF8Size";

   function UTF8_Char_Compare (Left, Right : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUTF8Charcmp";

   function UTF8_Str_Location (Item, Pattern : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlUTF8Strloc";

   function UTF8_Str_N_Duplicate
     (Item : System.Address; Characters : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlUTF8Strndup";

   function UTF8_Str_Sub_Copy
     (Item : System.Address; Start, Characters : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlUTF8Strsub";

   function UTF8_Str_Position
     (Item : System.Address; Index : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlUTF8Strpos";

   function Get_UTF8_Char
     (Item : System.Address; Length : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlGetUTF8Char";

   function Str_Append (Item, Addition : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlStrcat";

   function Str_N_Append
     (Item, Addition : System.Address; Length : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlStrncat";

   function Encode_Special_Chars
     (Document, Input : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlEncodeSpecialChars";

   function Encode_Entities_Reentrant
     (Document, Input : System.Address) return System.Address
     with Export, Convention => C,
          External_Name => "xmlEncodeEntitiesReentrant";

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

   function Create_URI return System.Address
     with Export, Convention => C, External_Name => "xmlCreateURI";

   procedure Free_URI (URI : System.Address)
     with Export, Convention => C, External_Name => "xmlFreeURI";

   function Parse_URI_Safe (Text, Output : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlParseURISafe";

   function Parse_URI (Text : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlParseURI";

   function Parse_URI_Raw (Text : System.Address; Raw : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlParseURIRaw";

   function Parse_URI_Reference (URI, Text : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlParseURIReference";

   function Save_URI (URI : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlSaveUri";

   procedure Print_URI (Stream, URI : System.Address)
     with Export, Convention => C, External_Name => "xmlPrintURI";

   function Build_URI_Safe (URI, Base, Output : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlBuildURISafe";

   function Build_URI (URI, Base : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlBuildURI";

   function Build_Relative_URI_Safe (URI, Base, Output : System.Address)
      return Interfaces.C.int
     with Export, Convention => C,
       External_Name => "xmlBuildRelativeURISafe";

   function Build_Relative_URI (URI, Base : System.Address)
      return System.Address
     with Export, Convention => C, External_Name => "xmlBuildRelativeURI";

   function Canonic_Path (Path : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlCanonicPath";

   function Path_To_URI (Path : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlPathToURI";

   function URI_Escape (Text : System.Address) return System.Address
     with Export, Convention => C, External_Name => "xmlURIEscape";

   function Save_To_Buffer
     (Buffer, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlSaveToBuffer";

   function Save_To_Fd
     (Fd : Interfaces.C.int; Encoding : System.Address;
      Options : Interfaces.C.int) return System.Address
     with Export, Convention => C, External_Name => "xmlSaveToFd";

   function Save_To_Filename
     (Name, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlSaveToFilename";

   function Save_To_IO
     (Write : Output_Write_Callback; Close : Output_Close_Callback;
      Context, Encoding : System.Address; Options : Interfaces.C.int)
      return System.Address
     with Export, Convention => C, External_Name => "xmlSaveToIO";

   function Save_Doc (Ctxt, Doc : System.Address) return Interfaces.C.long
     with Export, Convention => C, External_Name => "xmlSaveDoc";

   function Save_Tree (Ctxt, Node : System.Address) return Interfaces.C.long
     with Export, Convention => C, External_Name => "xmlSaveTree";

   function Save_Flush (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFlush";

   function Save_Close (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveClose";

   function Save_Finish (Ctxt : System.Address) return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveFinish";

   function Save_Set_Indent_String (Ctxt, Indent : System.Address)
      return Interfaces.C.int
     with Export, Convention => C, External_Name => "xmlSaveSetIndentString";

end XML3_C;
