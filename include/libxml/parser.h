#ifndef LIBXML3_PARSER_H
#define LIBXML3_PARSER_H

#include <libxml/tree.h>
#include <libxml/xmlIO.h>
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

/* The bits of xmlCtxtGetStatus. */
typedef enum {
    XML_STATUS_NOT_WELL_FORMED = (1 << 0),
    XML_STATUS_NOT_NS_WELL_FORMED = (1 << 1),
    XML_STATUS_DTD_VALIDATION_FAILED = (1 << 2),
    XML_STATUS_CATASTROPHIC_ERROR = (1 << 3)
} xmlParserStatus;

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
xmlDocPtr xmlReadFd(int fd, const char *URL, const char *encoding,
                    int options);
xmlDocPtr xmlReadIO(xmlInputReadCallback ioread,
                    xmlInputCloseCallback ioclose, void *ioctx,
                    const char *URL, const char *encoding, int options);

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
xmlDocPtr xmlCtxtReadFd(xmlParserCtxtPtr ctxt, int fd, const char *URL,
                        const char *encoding, int options);
xmlDocPtr xmlCtxtReadIO(xmlParserCtxtPtr ctxt, xmlInputReadCallback ioread,
                        xmlInputCloseCallback ioclose, void *ioctx,
                        const char *URL, const char *encoding, int options);
void *xmlCtxtGetPrivate(xmlParserCtxtPtr ctxt);
void xmlCtxtSetPrivate(xmlParserCtxtPtr ctxt, void *priv);
void *xmlCtxtGetUserData(xmlParserCtxtPtr ctxt);
xmlDocPtr xmlCtxtGetDocument(xmlParserCtxtPtr ctxt);
xmlNodePtr xmlCtxtGetNode(xmlParserCtxtPtr ctxt);
int xmlCtxtIsHtml(xmlParserCtxtPtr ctxt);
int xmlCtxtIsStopped(xmlParserCtxtPtr ctxt);
int xmlCtxtIsInSubset(xmlParserCtxtPtr ctxt);
int xmlCtxtGetStatus(xmlParserCtxtPtr ctxt);
void xmlStopParser(xmlParserCtxtPtr ctxt);

#ifdef __cplusplus
}
#endif

#endif
