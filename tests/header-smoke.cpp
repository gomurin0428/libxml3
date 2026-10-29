#include <libxml/chvalid.h>
#include <libxml3.h>

static_assert(XML_PARSE_HUGE == (1 << 19));
static_assert(XML_ERR_INT_SUBSET_NOT_FINISHED == 118);
static_assert(XML_NS_ERR_COLON == 205);

int main() {
    int (*character_classes[])(unsigned int) = {
        xmlIsChar, xmlIsBlank, xmlIsDigit, xmlIsExtender, xmlIsIdeographic, xmlIsPubidChar,
        xmlIsBaseChar, xmlIsCombining
    };
    (void)character_classes;
    int (*range_check)(unsigned int, const xmlChRangeGroup *) = xmlCharInRange;
    (void)range_check;
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
