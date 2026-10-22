#ifndef LIBXML3_PARSER_H
#define LIBXML3_PARSER_H

#include <libxml/tree.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    XML_PARSE_NOERROR = 1 << 5,
    XML_PARSE_NOWARNING = 1 << 6,
    XML_PARSE_NONET = 1 << 11,
    XML_PARSE_HUGE = 1 << 19
} xmlParserOption;

void xmlInitParser(void);
void xmlCleanupParser(void);
xmlDocPtr xmlReadMemory(const char *buffer, int size, const char *URL,
                        const char *encoding, int options);
xmlDocPtr xmlParseMemory(const char *buffer, int size);
xmlDocPtr xmlReadDoc(const xmlChar *cur, const char *URL,
                     const char *encoding, int options);
xmlDocPtr xmlParseDoc(const xmlChar *cur);

#ifdef __cplusplus
}
#endif

#endif
