#include <libxml3.h>

static_assert(XML_PARSE_HUGE == (1 << 19));
static_assert(XML_ERR_INT_SUBSET_NOT_FINISHED == 118);
static_assert(XML_NS_ERR_COLON == 205);

int main() {
    xmlChar *(*str_append)(xmlChar *, const xmlChar *) = xmlStrcat;
    xmlChar *(*str_n_append)(xmlChar *, const xmlChar *, int) = xmlStrncat;
    (void)str_append;
    (void)str_n_append;
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
