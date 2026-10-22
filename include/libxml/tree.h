#ifndef LIBXML3_TREE_H
#define LIBXML3_TREE_H

#include <libxml/xmlstring.h>
#include <libxml/xmlmemory.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _xmlNode xmlNode;
typedef struct _xmlNode *xmlNodePtr;
typedef struct _xmlAttr xmlAttr;
typedef struct _xmlAttr *xmlAttrPtr;
typedef struct _xmlDoc xmlDoc;
typedef struct _xmlDoc *xmlDocPtr;

typedef enum {
    XML_ELEMENT_NODE = 1,
    XML_ATTRIBUTE_NODE = 2,
    XML_TEXT_NODE = 3,
    XML_CDATA_SECTION_NODE = 4,
    XML_PI_NODE = 7,
    XML_COMMENT_NODE = 8,
    XML_DOCUMENT_NODE = 9
} xmlElementType;

struct _xmlNode {
    void *_private;
    xmlElementType type;
    const xmlChar *name;
    xmlNodePtr children;
    xmlNodePtr last;
    xmlNodePtr parent;
    xmlNodePtr next;
    xmlNodePtr prev;
    xmlDocPtr doc;
    void *ns;
    xmlChar *content;
    xmlAttrPtr properties;
    void *nsDef;
};

struct _xmlAttr {
    void *_private;
    xmlElementType type;
    const xmlChar *name;
    xmlNodePtr children;
    xmlNodePtr last;
    xmlNodePtr parent;
    xmlAttrPtr next;
    xmlAttrPtr prev;
    xmlDocPtr doc;
    void *ns;
};

struct _xmlDoc {
    void *_private;
    xmlElementType type;
    const xmlChar *name;
    xmlNodePtr children;
    xmlNodePtr last;
    xmlNodePtr parent;
    xmlNodePtr next;
    xmlNodePtr prev;
    xmlDocPtr doc;
};

xmlNodePtr xmlDocGetRootElement(const xmlDoc *doc);
void xmlFreeDoc(xmlDocPtr cur);
xmlChar *xmlNodeGetContent(const xmlNode *cur);
xmlChar *xmlGetProp(const xmlNode *node, const xmlChar *name);
xmlAttrPtr xmlHasProp(const xmlNode *node, const xmlChar *name);
xmlNodePtr xmlFirstElementChild(const xmlNode *parent);
xmlNodePtr xmlNextElementSibling(const xmlNode *node);
unsigned long xmlChildElementCount(const xmlNode *parent);

#ifdef __cplusplus
}
#endif

#endif
