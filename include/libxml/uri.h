#ifndef LIBXML3_URI_H
#define LIBXML3_URI_H

#include <libxml/xmlstring.h>

#ifdef __cplusplus
extern "C" {
#endif

xmlChar *xmlURIEscapeStr(const xmlChar *str, const xmlChar *list);
char *xmlURIUnescapeString(const char *str, int len, char *target);

#ifdef __cplusplus
}
#endif

#endif
