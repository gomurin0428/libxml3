#include <libxml3.h>

static_assert(XML_PARSE_HUGE == (1 << 19));
static_assert(XML_ERR_INT_SUBSET_NOT_FINISHED == 118);
static_assert(XML_NS_ERR_COLON == 205);

int main() {
    const int equal = xmlStrEqual(BAD_CAST "r", BAD_CAST "r");
    const xmlError *(*last_error)(void) = xmlGetLastError;
    using SearchNsFunction =
        xmlNsPtr (*)(xmlDocPtr, xmlNodePtr, const xmlChar *);
    const SearchNsFunction search_ns = xmlSearchNs;
    const SearchNsFunction search_ns_by_href = xmlSearchNsByHref;
    xmlAttrPtr (*new_prop)(xmlNodePtr, const xmlChar *, const xmlChar *) =
        xmlNewProp;
    xmlAttrPtr (*set_prop)(xmlNodePtr, const xmlChar *, const xmlChar *) =
        xmlSetProp;
    int (*unset_prop)(xmlNodePtr, const xmlChar *) = xmlUnsetProp;
    int (*remove_prop)(xmlAttrPtr) = xmlRemoveProp;
    void (*free_prop)(xmlAttrPtr) = xmlFreeProp;
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
    xmlNodePtr (*text_merge)(xmlNodePtr, xmlNodePtr) = xmlTextMerge;
    int (*text_concat)(xmlNodePtr, const xmlChar *, int) = xmlTextConcat;
    int (*node_is_text)(const xmlNode *) = xmlNodeIsText;
    int (*is_blank_node)(const xmlNode *) = xmlIsBlankNode;
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
    (void)previous_element_sibling;
    (void)new_text_child;
    (void)last_error;
    xmlFreeDoc(doc);
    return 0;
}
