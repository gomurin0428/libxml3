#ifndef LIBXML3_PARSER_INTERNALS_H
#define LIBXML3_PARSER_INTERNALS_H

#include <libxml/xmlstring.h>

#ifdef __cplusplus
extern "C" {
#endif

int xmlCopyCharMultiByte(xmlChar *out, int val);
int xmlCopyChar(int len, xmlChar *out, int val);

#ifdef __cplusplus
}
#endif

#endif
