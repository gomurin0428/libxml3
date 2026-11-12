with XML3_Diagnostic_Codes;

package XML3_Entry_Guards with SPARK_Mode is
   use type XML3_Diagnostic_Codes.Diagnostic_Code;

   --  The argument checks C entry points make before they take the DOM lock
   --  or call into the core.  Entry points are grouped by the check they
   --  share.  First and Second name the pointer arguments a group checks,
   --  in the order of the C signature; a group that checks one argument
   --  only ignores Second.
   type Entry_Group is
     (Document_Read,
      --  xmlReadDoc, xmlParseDoc: cur
      Element_Query,
      --  xmlDocGetRootElement, xmlFirstElementChild, xmlLastElementChild,
      --  xmlNextElementSibling, xmlPreviousElementSibling,
      --  xmlChildElementCount: the node
      Document_Dump,
      --  xmlDocDumpMemory and its Enc/Format variants: doc, mem
      Child_Creation,
      --  xmlNewChild, xmlNewTextChild: name
      Node_Creation,
      --  xmlNewNode, xmlNewDocNode, xmlNewDocRawNode, xmlNewDocProp: name
      PI_Creation,
      --  xmlNewPI, xmlNewDocPI: name
      Node_List_Parse,
      --  xmlStringGetNodeList, xmlStringLenGetNodeList: value
      Root_Replacement,
      --  xmlDocSetRootElement: doc, root
      Node_Insertion,
      --  xmlAddChild, xmlAddSibling, xmlAddPrevSibling, xmlAddNextSibling:
      --  the target, the new node
      Node_Replacement,
      --  xmlReplaceNode: old; old and cur must also differ
      Text_Concatenation,
      --  xmlTextConcat: node
      Content_Addition,
      --  xmlNodeAddContent, xmlNodeAddContentLen: nothing (the core
      --  answers for a missing node)
      Node_Renaming,
      --  xmlNodeSetName: node, name
      Node_Unlinking,
      --  xmlUnlinkNode: node
      Node_Release,
      --  xmlFreeNode, xmlFreeNodeList, xmlFreeProp, xmlFreePropList: node
      Document_Release,
      --  xmlFreeDoc: doc
      Node_Text,
      --  xmlNodeGetContent, xmlGetNodePath: node
      Node_List_Text,
      --  xmlNodeListGetString, xmlNodeListGetRawString: list
      Line_Number,
      --  xmlGetLineNo: node
      Inherited_Property,
      --  xmlNodeGetLang, xmlNodeGetSpacePreserve: node
      Property_Update,
      --  xmlNodeSetLang, xmlNodeSetSpacePreserve: node
      Property_Lookup,
      --  xmlGetProp, xmlGetNsProp, xmlGetNoNsProp, xmlNodeGetAttrValue,
      --  xmlHasProp, xmlHasNsProp: node, name
      Lookup_Output,
      --  xmlNodeGetAttrValue, xmlGetNsListSafe: the output slot
      Namespace_Copy,
      --  xmlCopyNamespace: the namespace
      Node_Copy,
      --  xmlCopyNode, xmlDocCopyNode, xmlCopyDoc: the node or document
      Property_Copy,
      --  xmlCopyProp: the attribute (its second argument); the target is
      --  optional
      Buffer_Use,
      --  xmlBufferFree, xmlBufferEmpty, xmlBufferShrink, xmlBufferGrow,
      --  xmlBufferResize, xmlBufferContent, xmlBufferLength,
      --  xmlBufferDetach, xmlBufferWriteQuotedString: the buffer
      Buffer_Append,
      --  xmlBufferAdd, xmlBufferAddHead, xmlBufferCat, xmlBufferCCat,
      --  xmlBufferWriteCHAR, xmlBufferWriteChar: the buffer, the text
      Node_Dump,
      --  xmlNodeDump: the buffer, the node
      Stream_Dump,
      --  xmlDocDump, xmlDocFormatDump, xmlElemDump: the stream, the
      --  document or node
      File_Save,
      --  xmlSaveFile and its variants: the filename, the document
      File_Read,
      --  xmlReadFile, xmlParseFile: the filename
      Namespace_Assignment,
      --  xmlSetNs: node
      Namespace_Release,
      --  xmlFreeNs: the namespace
      Namespace_Query,
      --  xmlGetNsList, xmlGetNsListSafe, xmlSearchNs, xmlSearchNsByHref:
      --  node
      Attribute_Creation,
      --  xmlNewProp, xmlNewNsProp: name
      Attribute_Update,
      --  xmlSetProp, xmlSetNsProp, xmlUnsetProp, xmlUnsetNsProp: node, name
      Attribute_Removal,
      --  xmlRemoveProp: the attribute
      Character_Decoding,
      --  xmlGetUTF8Char: the input, the length slot
      Entity_Encoding,
      --  xmlEncodeSpecialChars, xmlEncodeEntitiesReentrant: the input
      QName_Split);
      --  xmlSplitQName2: name, prefix slot; xmlSplitQName3: name, length
      --  slot

   type Guard_Rule is record
      First_Required : Boolean;
      Second_Required : Boolean;
      --  The two arguments must not be the same object.
      Distinct_Required : Boolean;
      --  A refused call publishes the invalid-argument diagnostic; other
      --  groups refuse silently, as libxml2 does for these entry points.
      Reported : Boolean;
   end record;

   type Rule_Table is array (Entry_Group) of Guard_Rule;

   Silent_One : constant Guard_Rule :=
     (First_Required => True, Second_Required => False,
      Distinct_Required => False, Reported => False);
   Silent_Two : constant Guard_Rule :=
     (First_Required => True, Second_Required => True,
      Distinct_Required => False, Reported => False);
   Reported_One : constant Guard_Rule :=
     (First_Required => True, Second_Required => False,
      Distinct_Required => False, Reported => True);
   Reported_Two : constant Guard_Rule :=
     (First_Required => True, Second_Required => True,
      Distinct_Required => False, Reported => True);

   Rules : constant Rule_Table :=
     (Document_Read => Silent_One,
      Element_Query => Silent_One,
      Document_Dump => Reported_Two,
      Child_Creation => Reported_One,
      Node_Creation => Silent_One,
      PI_Creation => Silent_One,
      Node_List_Parse => Silent_One,
      Root_Replacement => Silent_Two,
      Node_Insertion => Silent_Two,
      Node_Replacement =>
        (First_Required => True, Second_Required => False,
         Distinct_Required => True, Reported => False),
      Text_Concatenation => Silent_One,
      Content_Addition =>
        (First_Required => False, Second_Required => False,
         Distinct_Required => False, Reported => False),
      Node_Renaming => Silent_Two,
      Node_Unlinking => Silent_One,
      Node_Release => Silent_One,
      Document_Release => Silent_One,
      Node_Text => Silent_One,
      Node_List_Text => Silent_One,
      Line_Number => Silent_One,
      Inherited_Property => Silent_One,
      Property_Update => Reported_One,
      Property_Lookup => Silent_Two,
      Lookup_Output => Silent_One,
      Namespace_Copy => Silent_One,
      Node_Copy => Silent_One,
      Property_Copy =>
        (First_Required => False, Second_Required => True,
         Distinct_Required => False, Reported => False),
      Buffer_Use => Silent_One,
      Buffer_Append => Silent_Two,
      Node_Dump => Silent_Two,
      Stream_Dump => Silent_Two,
      File_Save => Silent_Two,
      File_Read => Silent_One,
      Namespace_Assignment => Silent_One,
      Namespace_Release => Silent_One,
      Namespace_Query => Silent_One,
      Attribute_Creation => Reported_One,
      Attribute_Update => Reported_Two,
      Attribute_Removal => Reported_One,
      Character_Decoding => Silent_Two,
      Entity_Encoding => Silent_One,
      QName_Split => Silent_Two);

   type Admission is (Admitted, Refused, Refused_And_Reported);

   --  Whether a call with these arguments goes ahead.  A refused call
   --  returns the refusal value of its entry point at once.
   function Admit
     (Group : Entry_Group;
      First_Present : Boolean;
      Second_Present : Boolean := True;
      Distinct : Boolean := True) return Admission
   is
     (if (Rules (Group).First_Required and then not First_Present)
        or else (Rules (Group).Second_Required and then not Second_Present)
        or else (Rules (Group).Distinct_Required and then not Distinct)
      then (if Rules (Group).Reported then Refused_And_Reported else Refused)
      else Admitted)
   with Global => null,
     Post =>
       --  Every argument a group requires is present in an admitted call.
       (if Admit'Result = Admitted
        then (First_Present or else not Rules (Group).First_Required)
             and then (Second_Present
                       or else not Rules (Group).Second_Required)
             and then (Distinct or else not Rules (Group).Distinct_Required))
       --  A call whose arguments are all present and distinct goes ahead.
       and then (if First_Present and then Second_Present and then Distinct
                 then Admit'Result = Admitted)
       --  Only the groups marked Reported publish a refusal.
       and then (if Admit'Result = Refused_And_Reported
                 then Rules (Group).Reported)
       and then (if Admit'Result = Refused
                 then not Rules (Group).Reported);

   --  The diagnostic a decision publishes: the one an operation reports
   --  for an unusable argument, and only for a reported refusal.
   function Diagnostic_For
     (Decision : Admission) return XML3_Diagnostic_Codes.Diagnostic_Code
   is
     (if Decision = Refused_And_Reported
      then XML3_Diagnostic_Codes.For_Failure
             (XML3_Diagnostic_Codes.Invalid_Argument)
      else XML3_Diagnostic_Codes.None)
   with Global => null,
     Post =>
       Diagnostic_For'Result.Present = (Decision = Refused_And_Reported)
       and then (if Decision = Refused_And_Reported
                 then Diagnostic_For'Result =
                        XML3_Diagnostic_Codes.DOM_Invalid_Argument);

end XML3_Entry_Guards;
