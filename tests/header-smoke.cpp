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
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, nullptr, nullptr, XML_PARSE_NONET);
    if (!doc) return 1;
    xmlNodePtr root = xmlDocGetRootElement(doc);
    const unsigned long count = xmlChildElementCount(root);
    (void)count;
    (void)equal;
    (void)search_ns;
    (void)search_ns_by_href;
    (void)last_error;
    xmlFreeDoc(doc);
    return 0;
}
