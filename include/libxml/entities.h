#ifndef LIBXML3_ENTITIES_H
#define LIBXML3_ENTITIES_H

#include <libxml/tree.h>

#ifdef __cplusplus
extern "C" {
#endif

xmlChar *xmlEncodeSpecialChars(const xmlDoc *doc, const xmlChar *input);
xmlChar *xmlEncodeEntitiesReentrant(xmlDoc *doc, const xmlChar *input);

#ifdef __cplusplus
}
#endif

#endif
