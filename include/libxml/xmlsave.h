#ifndef LIBXML3_XMLSAVE_H
#define LIBXML3_XMLSAVE_H

#include <libxml/xmlversion.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#include <libxml/xmlIO.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    XML_SAVE_FORMAT = 1 << 0,
    XML_SAVE_NO_DECL = 1 << 1,
    XML_SAVE_NO_EMPTY = 1 << 2,
    XML_SAVE_NO_XHTML = 1 << 3,
    XML_SAVE_XHTML = 1 << 4,
    XML_SAVE_AS_XML = 1 << 5,
    XML_SAVE_AS_HTML = 1 << 6,
    XML_SAVE_WSNONSIG = 1 << 7,
    XML_SAVE_EMPTY = 1 << 8,
    XML_SAVE_NO_INDENT = 1 << 9,
    XML_SAVE_INDENT = 1 << 10
} xmlSaveOption;

/* An opaque save context: made by the xmlSaveTo* functions, released by
 * xmlSaveClose or xmlSaveFinish.  Only UTF-8 output (or none, which
 * writes non-ASCII characters as character references) is supported, and
 * XML_SAVE_XHTML, XML_SAVE_AS_HTML and XML_SAVE_WSNONSIG without
 * XML_SAVE_FORMAT are refused. */
typedef struct _xmlSaveCtxt xmlSaveCtxt;
typedef xmlSaveCtxt *xmlSaveCtxtPtr;

xmlSaveCtxtPtr xmlSaveToFd(int fd, const char *encoding, int options);
xmlSaveCtxtPtr xmlSaveToFilename(const char *filename, const char *encoding,
                                 int options);
xmlSaveCtxtPtr xmlSaveToBuffer(xmlBufferPtr buffer, const char *encoding,
                               int options);
xmlSaveCtxtPtr xmlSaveToIO(xmlOutputWriteCallback iowrite,
                           xmlOutputCloseCallback ioclose, void *ioctx,
                           const char *encoding, int options);
long xmlSaveDoc(xmlSaveCtxtPtr ctxt, xmlDocPtr doc);
long xmlSaveTree(xmlSaveCtxtPtr ctxt, xmlNodePtr node);
int xmlSaveFlush(xmlSaveCtxtPtr ctxt);
int xmlSaveClose(xmlSaveCtxtPtr ctxt);
xmlParserErrors xmlSaveFinish(xmlSaveCtxtPtr ctxt);
int xmlSaveSetIndentString(xmlSaveCtxtPtr ctxt, const char *indent);

#ifdef __cplusplus
}
#endif

#endif
