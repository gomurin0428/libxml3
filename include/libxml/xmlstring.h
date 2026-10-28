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
int xmlStrcasecmp(const xmlChar *str1, const xmlChar *str2);
const xmlChar *xmlStrchr(const xmlChar *str, xmlChar val);
const xmlChar *xmlStrstr(const xmlChar *str, const xmlChar *val);
const xmlChar *xmlStrcasestr(const xmlChar *str, const xmlChar *val);
xmlChar *xmlStrsub(const xmlChar *str, int start, int len);
int xmlStrncmp(const xmlChar *str1, const xmlChar *str2, int len);
int xmlStrncasecmp(const xmlChar *str1, const xmlChar *str2, int len);
int xmlStrEqual(const xmlChar *str1, const xmlChar *str2);
int xmlStrQEqual(const xmlChar *pref, const xmlChar *name, const xmlChar *str);
int xmlStrlen(const xmlChar *str);
int xmlCheckUTF8(const unsigned char *utf);
int xmlUTF8Strlen(const xmlChar *utf);
int xmlUTF8Strsize(const xmlChar *utf, int len);
int xmlUTF8Size(const xmlChar *utf);
xmlChar *xmlUTF8Strndup(const xmlChar *utf, int len);
xmlChar *xmlUTF8Strsub(const xmlChar *utf, int start, int len);
const xmlChar *xmlUTF8Strpos(const xmlChar *utf, int pos);
int xmlGetUTF8Char(const unsigned char *utf, int *len);
xmlChar *xmlStrdup(const xmlChar *cur);
xmlChar *xmlCharStrdup(const char *cur);
xmlChar *xmlCharStrndup(const char *cur, int len);
xmlChar *xmlStrndup(const xmlChar *cur, int len);
xmlChar *xmlStrncatNew(const xmlChar *str1, const xmlChar *str2, int len);
xmlChar *xmlStrcat(xmlChar *cur, const xmlChar *add);
xmlChar *xmlStrncat(xmlChar *cur, const xmlChar *add, int len);

#ifdef __cplusplus
}
#endif

#endif
