#ifndef LIBXML3_URI_H
#define LIBXML3_URI_H

#include <libxml/xmlstring.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

typedef struct _xmlURI xmlURI;
typedef xmlURI *xmlURIPtr;

/* A parsed URI reference.  The strings are allocated with xmlMalloc and
 * released by xmlFreeURI.  cleanup holds the parse flags (1 allows the
 * unwise characters {}|\^[]`, 2 keeps the components escaped, 4 allows
 * other characters outside URIs); port is 0 when absent and -1 for an
 * authority without a server. */
struct _xmlURI {
    char *scheme;
    char *opaque;
    char *authority;
    char *server;
    char *user;
    int port;
    char *path;
    char *query;
    char *fragment;
    int cleanup;
    char *query_raw;
};

xmlURIPtr xmlCreateURI(void);
int xmlParseURISafe(const char *str, xmlURIPtr *uri);
xmlURIPtr xmlParseURI(const char *str);
xmlURIPtr xmlParseURIRaw(const char *str, int raw);
int xmlParseURIReference(xmlURIPtr uri, const char *str);
xmlChar *xmlSaveUri(xmlURIPtr uri);
void xmlPrintURI(FILE *stream, xmlURIPtr uri);
void xmlFreeURI(xmlURIPtr uri);
xmlChar *xmlURIEscapeStr(const xmlChar *str, const xmlChar *list);
char *xmlURIUnescapeString(const char *str, int len, char *target);
int xmlNormalizeURIPath(char *path);

#ifdef __cplusplus
}
#endif

#endif
