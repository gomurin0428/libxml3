#ifndef LIBXML3_XMLSTRING_H
#define LIBXML3_XMLSTRING_H

#include <stddef.h>
#include <libxml/xmlversion.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char xmlChar;
typedef xmlChar *xmlCharPtr;

#define BAD_CAST (xmlChar *)

int xmlStrcmp(const xmlChar *str1, const xmlChar *str2);
int xmlStrEqual(const xmlChar *str1, const xmlChar *str2);
int xmlStrlen(const xmlChar *str);
xmlChar *xmlStrdup(const xmlChar *cur);
xmlChar *xmlStrndup(const xmlChar *cur, int len);
xmlChar *xmlStrncatNew(const xmlChar *str1, const xmlChar *str2, int len);

#ifdef __cplusplus
}
#endif

#endif
