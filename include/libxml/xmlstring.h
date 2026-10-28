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
const xmlChar *xmlStrchr(const xmlChar *str, xmlChar val);
int xmlStrncmp(const xmlChar *str1, const xmlChar *str2, int len);
int xmlStrncasecmp(const xmlChar *str1, const xmlChar *str2, int len);
int xmlStrEqual(const xmlChar *str1, const xmlChar *str2);
int xmlStrQEqual(const xmlChar *pref, const xmlChar *name, const xmlChar *str);
int xmlStrlen(const xmlChar *str);
xmlChar *xmlStrdup(const xmlChar *cur);
xmlChar *xmlCharStrdup(const char *cur);
xmlChar *xmlCharStrndup(const char *cur, int len);
xmlChar *xmlStrndup(const xmlChar *cur, int len);
xmlChar *xmlStrncatNew(const xmlChar *str1, const xmlChar *str2, int len);

#ifdef __cplusplus
}
#endif

#endif
