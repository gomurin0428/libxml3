#include <libxml/chvalid.h>
#include <libxml3.h>

static_assert(XML_PARSE_HUGE == (1 << 19));
static_assert(XML_ERR_INT_SUBSET_NOT_FINISHED == 118);
static_assert(XML_NS_ERR_COLON == 205);
static_assert(XML_ENTITY_DECL == 17);
static_assert(XML_INTERNAL_PREDEFINED_ENTITY == 6);

int main() {
    int (*name_values[])(const xmlChar *) = {
        xmlValidateNameValue, xmlValidateNamesValue,
        xmlValidateNmtokenValue, xmlValidateNmtokensValue
    };
    (void)name_values;
    xmlEntityPtr (*get_predefined_entity)(const xmlChar *) =
        xmlGetPredefinedEntity;
    (void)get_predefined_entity;
    xmlEntityPtr (*get_doc_entity)(const xmlDoc *, const xmlChar *) = xmlGetDocEntity;
    (void)get_doc_entity;
    xmlChar *(*uri_escape)(const xmlChar *, const xmlChar *) = xmlURIEscapeStr;
    (void)uri_escape;
    char *(*uri_unescape)(const char *, int, char *) = xmlURIUnescapeString;
    (void)uri_unescape;
    int (*uri_path)(char *) = xmlNormalizeURIPath;
    (void)uri_path;
    int (*character_classes[])(unsigned int) = {
        xmlIsChar, xmlIsBlank, xmlIsDigit, xmlIsExtender, xmlIsIdeographic, xmlIsPubidChar,
        xmlIsBaseChar, xmlIsCombining
    };
    (void)character_classes;
    int (*range_check)(unsigned int, const xmlChRangeGroup *) = xmlCharInRange;
    (void)range_check;
    int (*copy_char)(int, xmlChar *, int) = xmlCopyChar;
    int (*copy_multibyte)(xmlChar *, int) = xmlCopyCharMultiByte;
    (void)copy_char;
    (void)copy_multibyte;
    void (*dump_format)(xmlDocPtr, xmlChar **, int *, int) = xmlDocDumpFormatMemory;
    void (*dump_format_enc)(xmlDocPtr, xmlChar **, int *, const char *, int) =
        xmlDocDumpFormatMemoryEnc;
    (void)dump_format;
    (void)dump_format_enc;
    void (*dump_memory)(xmlDocPtr, xmlChar **, int *) = xmlDocDumpMemory;
    (void)dump_memory;
    int (*is_xhtml)(const xmlChar *, const xmlChar *) = xmlIsXHTML;
    (void)is_xhtml;
    xmlChar *(*encode_special)(const xmlDoc *, const xmlChar *) = xmlEncodeSpecialChars;
    (void)encode_special;
    xmlChar *(*encode_entities)(xmlDoc *, const xmlChar *) = xmlEncodeEntitiesReentrant;
    (void)encode_entities;
    xmlChar *(*get_node_path)(const xmlNode *) = xmlGetNodePath;
    (void)get_node_path;
    long (*get_line_no)(const xmlNode *) = xmlGetLineNo;
    (void)get_line_no;
    void (*set_node_name)(xmlNode *, const xmlChar *) = xmlNodeSetName;
    (void)set_node_name;
    xmlNodePtr (*string_list)(const xmlDoc *, const xmlChar *) = xmlStringGetNodeList;
    xmlNodePtr (*string_len_list)(const xmlDoc *, const xmlChar *, int) =
        xmlStringLenGetNodeList;
    (void)string_list;
    (void)string_len_list;
    xmlChar *(*raw_list)(const xmlDoc *, const xmlNode *, int) =
        xmlNodeListGetRawString;
    (void)raw_list;
    xmlChar *(*node_list)(xmlDoc *, const xmlNode *, int) = xmlNodeListGetString;
    (void)node_list;
    int (*check_utf8)(const unsigned char *) = xmlCheckUTF8;
    int (*utf8_length)(const xmlChar *) = xmlUTF8Strlen;
    int (*utf8_size)(const xmlChar *, int) = xmlUTF8Strsize;
    int (*utf8_lead_size)(const xmlChar *) = xmlUTF8Size;
    int (*utf8_compare)(const xmlChar *, const xmlChar *) = xmlUTF8Charcmp;
    (void)utf8_compare;
    int (*utf8_location)(const xmlChar *, const xmlChar *) = xmlUTF8Strloc;
    (void)utf8_location;
    (void)utf8_lead_size;
    xmlChar *(*utf8_copy)(const xmlChar *, int) = xmlUTF8Strndup;
    xmlChar *(*utf8_slice)(const xmlChar *, int, int) = xmlUTF8Strsub;
    (void)utf8_slice;
    (void)utf8_copy;
    (void)utf8_size;
    const xmlChar *(*utf8_position)(const xmlChar *, int) = xmlUTF8Strpos;
    (void)utf8_position;
    (void)utf8_length;
    int (*get_utf8_char)(const unsigned char *, int *) = xmlGetUTF8Char;
    (void)get_utf8_char;
    (void)check_utf8;
    xmlChar *(*str_append)(xmlChar *, const xmlChar *) = xmlStrcat;
    xmlChar *(*str_n_append)(xmlChar *, const xmlChar *, int) = xmlStrncat;
    (void)str_append;
    (void)str_n_append;
    xmlNodePtr (*add_prev_sibling)(xmlNodePtr, xmlNodePtr) = xmlAddPrevSibling;
    xmlNodePtr (*add_next_sibling)(xmlNodePtr, xmlNodePtr) = xmlAddNextSibling;
    xmlNodePtr (*replace_node)(xmlNodePtr, xmlNodePtr) = xmlReplaceNode;
    (void)add_prev_sibling;
    (void)add_next_sibling;
    (void)replace_node;
    int (*str_case_compare)(const xmlChar *, const xmlChar *) = xmlStrcasecmp;
    (void)str_case_compare;
    xmlChar *(*str_sub_copy)(const xmlChar *, int, int) = xmlStrsub;
    (void)str_sub_copy;
    const xmlChar *(*str_substring)(const xmlChar *, const xmlChar *) = xmlStrstr;
    const xmlChar *(*str_case_substring)(const xmlChar *, const xmlChar *) = xmlStrcasestr;
    (void)str_substring;
    (void)str_case_substring;
    int (*str_q_equal)(const xmlChar *, const xmlChar *, const xmlChar *) = xmlStrQEqual;
    (void)str_q_equal;
    const xmlChar *(*str_character)(const xmlChar *, xmlChar) = xmlStrchr;
    (void)str_character;
    xmlChar *(*char_duplicate)(const char *) = xmlCharStrdup;
    xmlChar *(*char_n_duplicate)(const char *, int) = xmlCharStrndup;
    (void)char_duplicate;
    (void)char_n_duplicate;
    int (*str_n_compare)(const xmlChar *, const xmlChar *, int) = xmlStrncmp;
    int (*str_n_case_compare)(const xmlChar *, const xmlChar *, int) = xmlStrncasecmp;
    (void)str_n_compare;
    (void)str_n_case_compare;
    xmlChar *(*str_concat_new)(const xmlChar *, const xmlChar *, int) = xmlStrncatNew;
    (void)str_concat_new;
    xmlChar *(*str_duplicate)(const xmlChar *) = xmlStrdup;
    xmlChar *(*str_n_duplicate)(const xmlChar *, int) = xmlStrndup;
    (void)str_duplicate;
    (void)str_n_duplicate;
    xmlNs *(*copy_namespace)(xmlNs *) = xmlCopyNamespace;
    (void)copy_namespace;
    xmlNode *(*copy_node)(xmlNode *, int) = xmlCopyNode;
    xmlNode *(*doc_copy_node)(xmlNode *, xmlDoc *, int) = xmlDocCopyNode;
    xmlAttr *(*copy_prop)(xmlNode *, xmlAttr *) = xmlCopyProp;
    xmlDoc *(*copy_doc)(xmlDoc *, int) = xmlCopyDoc;
    (void)copy_node;
    (void)doc_copy_node;
    (void)copy_prop;
    (void)copy_doc;
    xmlBuffer *(*buffer_create)(void) = xmlBufferCreate;
    int (*buffer_add)(xmlBuffer *, const xmlChar *, int) = xmlBufferAdd;
    const xmlChar *(*buffer_content)(const xmlBuffer *) = xmlBufferContent;
    int (*node_dump)(xmlBuffer *, xmlDoc *, xmlNode *, int, int) = xmlNodeDump;
    int (*doc_format_dump)(FILE *, xmlDoc *, int) = xmlDocFormatDump;
    void (*elem_dump)(FILE *, xmlDoc *, xmlNode *) = xmlElemDump;
    int (*save_format_file_enc)(const char *, xmlDoc *, const char *, int) =
        xmlSaveFormatFileEnc;
    (void)buffer_create;
    (void)buffer_add;
    (void)buffer_content;
    (void)node_dump;
    (void)doc_format_dump;
    (void)elem_dump;
    (void)save_format_file_enc;
    xmlDoc *(*read_file)(const char *, const char *, int) = xmlReadFile;
    xmlDoc *(*parse_file)(const char *) = xmlParseFile;
    (void)read_file;
    (void)parse_file;
    xmlDoc *(*read_fd)(int, const char *, const char *, int) = xmlReadFd;
    xmlDoc *(*read_io)(xmlInputReadCallback, xmlInputCloseCallback, void *,
                       const char *, const char *, int) = xmlReadIO;
    xmlDoc *(*ctxt_read_fd)(xmlParserCtxt *, int, const char *, const char *,
                            int) = xmlCtxtReadFd;
    xmlDoc *(*ctxt_read_io)(xmlParserCtxt *, xmlInputReadCallback,
                            xmlInputCloseCallback, void *, const char *,
                            const char *, int) = xmlCtxtReadIO;
    (void)read_fd;
    (void)read_io;
    (void)ctxt_read_fd;
    (void)ctxt_read_io;
    xmlParserCtxtPtr (*new_parser_ctxt)() = xmlNewParserCtxt;
    void (*free_parser_ctxt)(xmlParserCtxt *) = xmlFreeParserCtxt;
    void (*ctxt_reset)(xmlParserCtxtPtr) = xmlCtxtReset;
    int (*ctxt_use_options)(xmlParserCtxt *, int) = xmlCtxtUseOptions;
    int (*ctxt_set_options)(xmlParserCtxt *, int) = xmlCtxtSetOptions;
    int (*ctxt_get_options)(xmlParserCtxt *) = xmlCtxtGetOptions;
    xmlDoc *(*ctxt_read_memory)(xmlParserCtxt *, const char *, int,
                                const char *, const char *, int) =
        xmlCtxtReadMemory;
    xmlDoc *(*ctxt_read_doc)(xmlParserCtxt *, const xmlChar *, const char *,
                             const char *, int) = xmlCtxtReadDoc;
    xmlDoc *(*ctxt_read_file)(xmlParserCtxt *, const char *, const char *,
                              int) = xmlCtxtReadFile;
    const xmlError *(*ctxt_get_last_error)(void *) = xmlCtxtGetLastError;
    void (*ctxt_reset_last_error)(void *) = xmlCtxtResetLastError;
    (void)new_parser_ctxt;
    (void)free_parser_ctxt;
    (void)ctxt_reset;
    (void)ctxt_use_options;
    (void)ctxt_set_options;
    (void)ctxt_get_options;
    (void)ctxt_read_memory;
    (void)ctxt_read_doc;
    (void)ctxt_read_file;
    (void)ctxt_get_last_error;
    (void)ctxt_reset_last_error;
    xmlSaveCtxtPtr (*save_to_fd)(int, const char *, int) = xmlSaveToFd;
    xmlSaveCtxt *(*save_to_filename)(const char *, const char *, int) =
        xmlSaveToFilename;
    xmlSaveCtxt *(*save_to_buffer)(xmlBuffer *, const char *, int) =
        xmlSaveToBuffer;
    xmlSaveCtxt *(*save_to_io)(xmlOutputWriteCallback, xmlOutputCloseCallback,
                               void *, const char *, int) = xmlSaveToIO;
    long (*save_doc)(xmlSaveCtxt *, xmlDoc *) = xmlSaveDoc;
    long (*save_tree)(xmlSaveCtxt *, xmlNode *) = xmlSaveTree;
    int (*save_flush)(xmlSaveCtxt *) = xmlSaveFlush;
    int (*save_close)(xmlSaveCtxt *) = xmlSaveClose;
    xmlParserErrors (*save_finish)(xmlSaveCtxt *) = xmlSaveFinish;
    int (*save_set_indent)(xmlSaveCtxt *, const char *) =
        xmlSaveSetIndentString;
    xmlSaveOption save_options[] = {
        XML_SAVE_FORMAT, XML_SAVE_NO_DECL, XML_SAVE_NO_EMPTY,
        XML_SAVE_NO_XHTML, XML_SAVE_XHTML, XML_SAVE_AS_XML,
        XML_SAVE_AS_HTML, XML_SAVE_WSNONSIG, XML_SAVE_EMPTY,
        XML_SAVE_NO_INDENT, XML_SAVE_INDENT};
    (void)save_to_fd;
    (void)save_to_filename;
    (void)save_to_buffer;
    (void)save_to_io;
    (void)save_doc;
    (void)save_tree;
    (void)save_flush;
    (void)save_close;
    (void)save_finish;
    (void)save_set_indent;
    (void)save_options;
    void (*set_structured)(void *, xmlStructuredErrorFunc) =
        xmlSetStructuredErrorFunc;
    void (*ctxt_set_handler)(xmlParserCtxt *, xmlStructuredErrorFunc, void *) =
        xmlCtxtSetErrorHandler;
    (void)set_structured;
    (void)ctxt_set_handler;
    xmlURI *(*create_uri)() = xmlCreateURI;
    int (*parse_uri_safe)(const char *, xmlURI **) = xmlParseURISafe;
    xmlURIPtr (*parse_uri)(const char *) = xmlParseURI;
    xmlURIPtr (*parse_uri_raw)(const char *, int) = xmlParseURIRaw;
    int (*parse_uri_reference)(xmlURI *, const char *) = xmlParseURIReference;
    xmlChar *(*save_uri)(xmlURI *) = xmlSaveUri;
    void (*print_uri)(FILE *, xmlURI *) = xmlPrintURI;
    void (*free_uri)(xmlURI *) = xmlFreeURI;
    (void)create_uri;
    (void)parse_uri_safe;
    (void)parse_uri;
    (void)parse_uri_raw;
    (void)parse_uri_reference;
    (void)save_uri;
    (void)print_uri;
    (void)free_uri;
    xmlChar *(*build_uri)(const xmlChar *, const xmlChar *) = xmlBuildURI;
    int (*build_uri_safe)(const xmlChar *, const xmlChar *, xmlChar **) =
        xmlBuildURISafe;
    xmlChar *(*build_relative)(const xmlChar *, const xmlChar *) =
        xmlBuildRelativeURI;
    int (*build_relative_safe)(const xmlChar *, const xmlChar *, xmlChar **) =
        xmlBuildRelativeURISafe;
    xmlChar *(*canonic_path)(const xmlChar *) = xmlCanonicPath;
    xmlChar *(*path_to_uri)(const xmlChar *) = xmlPathToURI;
    xmlChar *(*uri_escape_full)(const xmlChar *) = xmlURIEscape;
    (void)build_uri;
    (void)build_uri_safe;
    (void)build_relative;
    (void)build_relative_safe;
    (void)canonic_path;
    (void)path_to_uri;
    (void)uri_escape_full;
    int (*str_printf)(xmlChar *, int, const char *, ...) = xmlStrPrintf;
    int (*str_vprintf)(xmlChar *, int, const char *, va_list) = xmlStrVPrintf;
    (void)str_printf;
    (void)str_vprintf;
    int (*mem_setup)(xmlFreeFunc, xmlMallocFunc, xmlReallocFunc,
                     xmlStrdupFunc) = xmlMemSetup;
    int (*mem_get)(xmlFreeFunc *, xmlMallocFunc *, xmlReallocFunc *,
                   xmlStrdupFunc *) = xmlMemGet;
    void *(*mem_malloc)(size_t) = xmlMalloc;
    void *(*mem_realloc)(void *, size_t) = xmlRealloc;
    char *(*mem_strdup)(const char *) = xmlMemStrdup;
    int (*mem_used)() = xmlMemUsed;
    (void)mem_setup;
    (void)mem_get;
    (void)mem_malloc;
    (void)mem_realloc;
    (void)mem_strdup;
    (void)mem_used;
    {
        xmlURI uri = {};
        uri.port = 0;
        uri.cleanup = 0;
        uri.query_raw = nullptr;
        (void)uri;
    }
    {
        xmlParserCtxt context;
        context._private = nullptr;
        context.myDoc = nullptr;
        context.wellFormed = 1;
        context.errNo = 0;
        context.options = 0;
        context.lastError.code = 0;
        (void)context;
    }
    xmlNode *(*new_node_eat_name)(xmlNs *, xmlChar *) = xmlNewNodeEatName;
    int (*node_buf_get_content)(xmlBuffer *, const xmlNode *) =
        xmlNodeBufGetContent;
    void (*attr_serialize)(xmlBuffer *, xmlDoc *, xmlAttr *, const xmlChar *) =
        xmlAttrSerializeTxtContent;
    void (*free_ns_list)(xmlNs *) = xmlFreeNsList;
    (void)new_node_eat_name;
    (void)node_buf_get_content;
    (void)attr_serialize;
    (void)free_ns_list;
    xmlChar *(*build_qname)(const xmlChar *, const xmlChar *, xmlChar *, int) = xmlBuildQName;
    (void)build_qname;
    xmlChar *(*split_copy)(const xmlChar *, xmlChar **) = xmlSplitQName2;
    const xmlChar *(*split_view)(const xmlChar *, int *) = xmlSplitQName3;
    (void)split_copy;
    (void)split_view;
    int (*ns_list_safe)(const xmlDoc *, const xmlNode *, xmlNs ***) = xmlGetNsListSafe;
    xmlNs **(*ns_list)(const xmlDoc *, const xmlNode *) = xmlGetNsList;
    (void)ns_list_safe;
    (void)ns_list;
    using ValidateNameFunction = int (*)(const xmlChar *, int);
    const ValidateNameFunction validators[] = {
        xmlValidateName, xmlValidateNCName, xmlValidateQName, xmlValidateNMToken};
    (void)validators;
    int (*get_attr_value)(const xmlNode *, const xmlChar *, const xmlChar *,
                          xmlChar **) = xmlNodeGetAttrValue;
    (void)get_attr_value;
    const int equal = xmlStrEqual(BAD_CAST "r", BAD_CAST "r");
    const xmlError *(*last_error)(void) = xmlGetLastError;
    using SearchNsFunction =
        xmlNsPtr (*)(xmlDocPtr, xmlNodePtr, const xmlChar *);
    const SearchNsFunction search_ns = xmlSearchNs;
    const SearchNsFunction search_ns_by_href = xmlSearchNsByHref;
    xmlAttrPtr (*new_prop)(xmlNodePtr, const xmlChar *, const xmlChar *) =
        xmlNewProp;
    xmlAttrPtr (*new_doc_prop)(xmlDocPtr, const xmlChar *, const xmlChar *) =
        xmlNewDocProp;
    xmlAttrPtr (*set_prop)(xmlNodePtr, const xmlChar *, const xmlChar *) =
        xmlSetProp;
    int (*unset_prop)(xmlNodePtr, const xmlChar *) = xmlUnsetProp;
    int (*remove_prop)(xmlAttrPtr) = xmlRemoveProp;
    void (*free_prop)(xmlAttrPtr) = xmlFreeProp;
    void (*free_node_list)(xmlNodePtr) = xmlFreeNodeList;
    void (*free_prop_list)(xmlAttrPtr) = xmlFreePropList;
    (void)free_node_list;
    (void)free_prop_list;
    xmlNsPtr (*new_ns)(xmlNodePtr, const xmlChar *, const xmlChar *) =
        xmlNewNs;
    void (*set_ns)(xmlNodePtr, xmlNsPtr) = xmlSetNs;
    void (*free_ns)(xmlNsPtr) = xmlFreeNs;
    xmlAttrPtr (*new_ns_prop)(xmlNodePtr, xmlNsPtr, const xmlChar *,
                              const xmlChar *) = xmlNewNsProp;
    xmlAttrPtr (*set_ns_prop)(xmlNodePtr, xmlNsPtr, const xmlChar *,
                              const xmlChar *) = xmlSetNsProp;
    int (*unset_ns_prop)(xmlNodePtr, xmlNsPtr, const xmlChar *) =
        xmlUnsetNsProp;
    void (*dump_memory_enc)(xmlDocPtr, xmlChar **, int *, const char *) =
        xmlDocDumpMemoryEnc;
    xmlNodePtr (*new_comment)(const xmlChar *) = xmlNewComment;
    xmlNodePtr (*new_doc_comment)(xmlDocPtr, const xmlChar *) = xmlNewDocComment;
    xmlNodePtr (*new_cdata)(xmlDocPtr, const xmlChar *, int) = xmlNewCDataBlock;
    xmlNodePtr (*new_doc_pi)(xmlDocPtr, const xmlChar *, const xmlChar *) = xmlNewDocPI;
    xmlNodePtr (*new_text_len)(const xmlChar *, int) = xmlNewTextLen;
    xmlNodePtr (*new_doc_text)(const xmlDoc *, const xmlChar *) = xmlNewDocText;
    xmlNodePtr (*new_doc_text_len)(xmlDocPtr, const xmlChar *, int) = xmlNewDocTextLen;
    xmlNodePtr (*new_pi)(const xmlChar *, const xmlChar *) = xmlNewPI;
    int (*node_add_content)(xmlNodePtr, const xmlChar *) = xmlNodeAddContent;
    int (*node_set_content)(xmlNodePtr, const xmlChar *) = xmlNodeSetContent;
    int (*node_set_content_len)(xmlNodePtr, const xmlChar *, int) = xmlNodeSetContentLen;
    int (*node_add_content_len)(xmlNodePtr, const xmlChar *, int) = xmlNodeAddContentLen;
    xmlNodePtr (*new_child)(xmlNodePtr, xmlNsPtr, const xmlChar *,
                           const xmlChar *) = xmlNewChild;
    xmlNodePtr (*new_doc_node)(xmlDocPtr, xmlNsPtr, const xmlChar *,
                              const xmlChar *) = xmlNewDocNode;
    xmlNodePtr (*new_doc_raw_node)(xmlDocPtr, xmlNsPtr, const xmlChar *,
                                  const xmlChar *) = xmlNewDocRawNode;
    xmlNodePtr (*last_element_child)(xmlNodePtr) = xmlLastElementChild;
    xmlNodePtr (*get_last_child)(const xmlNode *) = xmlGetLastChild;
    (void)get_last_child;
    xmlNodePtr (*text_merge)(xmlNodePtr, xmlNodePtr) = xmlTextMerge;
    int (*text_concat)(xmlNodePtr, const xmlChar *, int) = xmlTextConcat;
    int (*node_is_text)(const xmlNode *) = xmlNodeIsText;
    int (*is_blank_node)(const xmlNode *) = xmlIsBlankNode;
    xmlChar *(*node_get_lang)(const xmlNode *) = xmlNodeGetLang;
    int (*node_get_space_preserve)(const xmlNode *) = xmlNodeGetSpacePreserve;
    int (*node_set_lang)(xmlNode *, const xmlChar *) = xmlNodeSetLang;
    int (*node_set_space_preserve)(xmlNode *, int) = xmlNodeSetSpacePreserve;
    xmlNodePtr (*previous_element_sibling)(xmlNodePtr) = xmlPreviousElementSibling;
    xmlNodePtr (*new_text_child)(xmlNodePtr, xmlNsPtr, const xmlChar *,
                                const xmlChar *) = xmlNewTextChild;
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, nullptr, nullptr, XML_PARSE_NONET);
    if (!doc) return 1;
    xmlNodePtr root = xmlDocGetRootElement(doc);
    const unsigned long count = xmlChildElementCount(root);
    (void)count;
    (void)equal;
    (void)search_ns;
    (void)search_ns_by_href;
    (void)new_prop;
    (void)new_doc_prop;
    (void)set_prop;
    (void)unset_prop;
    (void)remove_prop;
    (void)free_prop;
    (void)new_ns;
    (void)set_ns;
    (void)free_ns;
    (void)new_ns_prop;
    (void)set_ns_prop;
    (void)unset_ns_prop;
    (void)dump_memory_enc;
    (void)new_comment;
    (void)new_doc_comment;
    (void)new_cdata;
    (void)new_doc_pi;
    (void)new_text_len;
    (void)new_doc_text;
    (void)new_doc_text_len;
    (void)new_pi;
    (void)node_add_content;
    (void)node_set_content;
    (void)node_set_content_len;
    (void)node_add_content_len;
    (void)new_child;
    (void)new_doc_node;
    (void)new_doc_raw_node;
    (void)last_element_child;
    (void)text_merge;
    (void)text_concat;
    (void)node_is_text;
    (void)is_blank_node;
    (void)node_get_lang;
    (void)node_get_space_preserve;
    (void)node_set_lang;
    (void)node_set_space_preserve;
    (void)previous_element_sibling;
    (void)new_text_child;
    (void)last_error;
    xmlFreeDoc(doc);
    return 0;
}
