#ifndef LIBXML3_XMLIO_H
#define LIBXML3_XMLIO_H

#include <stddef.h>
#include <stdio.h>

#include <libxml/tree.h>
#include <libxml/xmlversion.h>

#ifdef __cplusplus
extern "C" {
#endif

/* The input callbacks of xmlReadIO and xmlCtxtReadIO: read answers the
 * number of bytes stored (at most len), 0 at the end of the input, or a
 * negative XML_IO_* code (-1 for XML_IO_UNKNOWN) on failure. */
typedef int (*xmlInputReadCallback)(void *context, char *buffer, int len);
typedef int (*xmlInputCloseCallback)(void *context);

/* The output callbacks of xmlSaveToIO and xmlOutputBufferCreateIO. */
typedef int (*xmlOutputWriteCallback)(void *context, const char *buffer,
                                      int len);
typedef int (*xmlOutputCloseCallback)(void *context);

/* Encoding handlers are not provided: the output buffer functions accept
 * only a NULL encoder. */
typedef struct _xmlCharEncodingHandler xmlCharEncodingHandler;
typedef xmlCharEncodingHandler *xmlCharEncodingHandlerPtr;

/* An output buffer.  The fields keep their libxml2 meaning: the bytes not
 * yet written stay in buffer (xmlOutputBufferGetContent), written counts
 * the bytes the target took and error holds the first failure.  encoder
 * and conv are always NULL; writecallback and closecallback are the
 * caller's for xmlOutputBufferCreateIO and NULL otherwise. */
struct _xmlOutputBuffer {
    void *context;
    xmlOutputWriteCallback writecallback;
    xmlOutputCloseCallback closecallback;
    xmlCharEncodingHandler *encoder;
    xmlBuf *buffer;
    xmlBuf *conv;
    int written;
    int error;
};

xmlOutputBufferPtr xmlAllocOutputBuffer(xmlCharEncodingHandlerPtr encoder);
xmlOutputBufferPtr xmlOutputBufferCreateIO(xmlOutputWriteCallback iowrite,
                                           xmlOutputCloseCallback ioclose,
                                           void *ioctx,
                                           xmlCharEncodingHandlerPtr encoder);
xmlOutputBufferPtr xmlOutputBufferCreateBuffer(
    xmlBufferPtr buffer, xmlCharEncodingHandlerPtr encoder);
xmlOutputBufferPtr xmlOutputBufferCreateFd(int fd,
                                           xmlCharEncodingHandlerPtr encoder);
xmlOutputBufferPtr xmlOutputBufferCreateFile(FILE *file,
                                             xmlCharEncodingHandlerPtr encoder);
xmlOutputBufferPtr xmlOutputBufferCreateFilename(
    const char *URI, xmlCharEncodingHandlerPtr encoder, int compression);
int xmlOutputBufferWrite(xmlOutputBufferPtr out, int len, const char *buf);
int xmlOutputBufferWriteString(xmlOutputBufferPtr out, const char *str);
int xmlOutputBufferFlush(xmlOutputBufferPtr out);
int xmlOutputBufferClose(xmlOutputBufferPtr out);
const xmlChar *xmlOutputBufferGetContent(xmlOutputBufferPtr out);
size_t xmlOutputBufferGetSize(xmlOutputBufferPtr out);

#ifdef __cplusplus
}
#endif

#endif
