#ifndef LIBXML3_H
#define LIBXML3_H

/* libxml3 is a separately named experimental source/API subset. It is not
 * ABI-compatible with libxml2 and must not be used as libxml2.so.2. */
#include <libxml/xmlversion.h>
#include <libxml/xmlstring.h>
#include <libxml/xmlmemory.h>
#include <libxml/tree.h>
#include <libxml/entities.h>
#include <libxml/parser.h>
#include <libxml/xmlerror.h>

#ifdef __cplusplus
extern "C" {
#endif

#define XML3_STATUS_OK 0
#define XML3_STATUS_MALFORMED 1
#define XML3_STATUS_UNSUPPORTED 2
#define XML3_STATUS_LIMIT_EXCEEDED 3
#define XML3_STATUS_INVALID_ARGUMENT 4
#define XML3_STATUS_NO_MEMORY 5
#define XML3_STATUS_INTERNAL_ERROR 6

xmlDocPtr xml3ReadMemory(const char *buffer, int size, int *status);

#ifdef __cplusplus
}
#endif

#endif
