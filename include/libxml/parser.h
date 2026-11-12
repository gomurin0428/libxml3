#ifndef LIBXML3_PARSER_H
#define LIBXML3_PARSER_H

#include <libxml/tree.h>
#include <libxml/xmlerror.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    XML_PARSE_NOERROR = 1 << 5,
    XML_PARSE_NOWARNING = 1 << 6,
    XML_PARSE_NONET = 1 << 11,
    XML_PARSE_HUGE = 1 << 19
} xmlParserOption;

/* A reduced parser context: the fields below keep their libxml2 meaning,
 * the other fields of libxml2's struct are not provided.  Contexts are
 * made by xmlNewParserCtxt and released by xmlFreeParserCtxt. */
struct _xmlParserCtxt {
    void *_private;
    xmlDocPtr myDoc;
    int wellFormed;
    int errNo;
    int options;
    xmlError lastError;
};

void xmlInitParser(void);
void xmlCleanupParser(void);
xmlDocPtr xmlReadMemory(const char *buffer, int size, const char *URL,
                        const char *encoding, int options);
xmlDocPtr xmlParseMemory(const char *buffer, int size);
xmlDocPtr xmlReadDoc(const xmlChar *cur, const char *URL,
                     const char *encoding, int options);
xmlDocPtr xmlParseDoc(const xmlChar *cur);
xmlDocPtr xmlReadFile(const char *filename, const char *encoding, int options);
xmlDocPtr xmlParseFile(const char *filename);

xmlParserCtxtPtr xmlNewParserCtxt(void);
void xmlCtxtSetErrorHandler(xmlParserCtxtPtr ctxt,
                            xmlStructuredErrorFunc handler, void *data);
void xmlFreeParserCtxt(xmlParserCtxtPtr ctxt);
void xmlCtxtReset(xmlParserCtxtPtr ctxt);
int xmlCtxtUseOptions(xmlParserCtxtPtr ctxt, int options);
int xmlCtxtSetOptions(xmlParserCtxtPtr ctxt, int options);
int xmlCtxtGetOptions(xmlParserCtxtPtr ctxt);
xmlDocPtr xmlCtxtReadMemory(xmlParserCtxtPtr ctxt, const char *buffer,
                            int size, const char *URL, const char *encoding,
                            int options);
xmlDocPtr xmlCtxtReadDoc(xmlParserCtxtPtr ctxt, const xmlChar *cur,
                         const char *URL, const char *encoding, int options);
xmlDocPtr xmlCtxtReadFile(xmlParserCtxtPtr ctxt, const char *filename,
                          const char *encoding, int options);

#ifdef __cplusplus
}
#endif

#endif
