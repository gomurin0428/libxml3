#ifndef LIBXML3_XMLIO_H
#define LIBXML3_XMLIO_H

#include <libxml/xmlversion.h>

#ifdef __cplusplus
extern "C" {
#endif

/* The input callbacks of xmlReadIO and xmlCtxtReadIO: read answers the
 * number of bytes stored (at most len), 0 at the end of the input, or a
 * negative XML_IO_* code (-1 for XML_IO_UNKNOWN) on failure. */
typedef int (*xmlInputReadCallback)(void *context, char *buffer, int len);
typedef int (*xmlInputCloseCallback)(void *context);

/* The output callbacks of xmlSaveToIO.  The input and output buffer
 * structures and the other I/O functions of libxml2 are not provided. */
typedef int (*xmlOutputWriteCallback)(void *context, const char *buffer,
                                      int len);
typedef int (*xmlOutputCloseCallback)(void *context);

#ifdef __cplusplus
}
#endif

#endif
