#include <libxml3.h>

int main() {
    const int equal = xmlStrEqual(BAD_CAST "r", BAD_CAST "r");
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, nullptr, nullptr, XML_PARSE_NONET);
    if (!doc) return 1;
    xmlNodePtr root = xmlDocGetRootElement(doc);
    const unsigned long count = xmlChildElementCount(root);
    (void)count;
    (void)equal;
    xmlFreeDoc(doc);
    return 0;
}
