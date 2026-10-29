#ifndef LIBXML3_ENTITIES_H
#define LIBXML3_ENTITIES_H

#include <libxml/tree.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    XML_INTERNAL_GENERAL_ENTITY = 1,
    XML_EXTERNAL_GENERAL_PARSED_ENTITY = 2,
    XML_EXTERNAL_GENERAL_UNPARSED_ENTITY = 3,
    XML_INTERNAL_PARAMETER_ENTITY = 4,
    XML_EXTERNAL_PARAMETER_ENTITY = 5,
    XML_INTERNAL_PREDEFINED_ENTITY = 6
} xmlEntityType;

struct _xmlEntity {
    void *_private;
    xmlElementType type;
    const xmlChar *name;
    struct _xmlNode *children;
    struct _xmlNode *last;
    struct _xmlDtd *parent;
    struct _xmlNode *next;
    struct _xmlNode *prev;
    struct _xmlDoc *doc;
    xmlChar *orig;
    xmlChar *content;
    int length;
    xmlEntityType etype;
    const xmlChar *ExternalID;
    const xmlChar *SystemID;
    struct _xmlEntity *nexte;
    const xmlChar *URI;
    int owner;
    int flags;
    unsigned long expandedSize;
};

xmlEntity *xmlGetPredefinedEntity(const xmlChar *name);
xmlChar *xmlEncodeSpecialChars(const xmlDoc *doc, const xmlChar *input);
xmlChar *xmlEncodeEntitiesReentrant(xmlDoc *doc, const xmlChar *input);

#ifdef __cplusplus
}
#endif

#endif
