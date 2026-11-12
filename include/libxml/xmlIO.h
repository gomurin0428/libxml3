#ifndef LIBXML3_XMLIO_H
#define LIBXML3_XMLIO_H

#include <libxml/xmlversion.h>

#ifdef __cplusplus
extern "C" {
#endif

/* The output callbacks of xmlSaveToIO.  The input and output buffer
 * structures and the other I/O functions of libxml2 are not provided. */
typedef int (*xmlOutputWriteCallback)(void *context, const char *buffer,
                                      int len);
typedef int (*xmlOutputCloseCallback)(void *context);

#ifdef __cplusplus
}
#endif

#endif
