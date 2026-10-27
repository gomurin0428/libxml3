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
typedef struct _xmlNs xmlNs;
typedef struct _xmlNs *xmlNsPtr;

typedef enum {
    XML_ELEMENT_NODE = 1,
    XML_ATTRIBUTE_NODE = 2,
    XML_TEXT_NODE = 3,
    XML_CDATA_SECTION_NODE = 4,
    XML_PI_NODE = 7,
    XML_COMMENT_NODE = 8,
    XML_DOCUMENT_NODE = 9,
    XML_NAMESPACE_DECL = 18
} xmlElementType;

typedef xmlElementType xmlNsType;

#define XML_XML_NAMESPACE ((const xmlChar *)"http://www.w3.org/XML/1998/namespace")

struct _xmlNs {
    xmlNsPtr next;
    xmlNsType type;
    const xmlChar *href;
    const xmlChar *prefix;
    void *_private;
    xmlDocPtr context;
};

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
    xmlNsPtr ns;
    xmlChar *content;
    xmlAttrPtr properties;
    xmlNsPtr nsDef;
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
    xmlNsPtr ns;
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
    const xmlChar *version;
};

xmlNodePtr xmlDocGetRootElement(const xmlDoc *doc);
xmlDocPtr xmlNewDoc(const xmlChar *version);
void xmlDocDumpMemoryEnc(xmlDocPtr cur, xmlChar **mem, int *size,
                         const char *encoding);
xmlNodePtr xmlNewNode(xmlNsPtr ns, const xmlChar *name);
xmlNodePtr xmlNewText(const xmlChar *content);
xmlNodePtr xmlDocSetRootElement(xmlDocPtr doc, xmlNodePtr root);
xmlNodePtr xmlAddChild(xmlNodePtr parent, xmlNodePtr cur);
void xmlUnlinkNode(xmlNodePtr cur);
void xmlFreeNode(xmlNodePtr cur);
void xmlFreeDoc(xmlDocPtr cur);
xmlNsPtr xmlNewNs(xmlNodePtr node, const xmlChar *href, const xmlChar *prefix);
void xmlSetNs(xmlNodePtr node, xmlNsPtr ns);
void xmlFreeNs(xmlNsPtr cur);
xmlAttrPtr xmlNewProp(xmlNodePtr node, const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlNewNsProp(xmlNodePtr node, xmlNsPtr ns,
                        const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlSetNsProp(xmlNodePtr node, xmlNsPtr ns,
                        const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlSetProp(xmlNodePtr node, const xmlChar *name, const xmlChar *value);
int xmlUnsetNsProp(xmlNodePtr node, xmlNsPtr ns, const xmlChar *name);
int xmlUnsetProp(xmlNodePtr node, const xmlChar *name);
int xmlRemoveProp(xmlAttrPtr cur);
void xmlFreeProp(xmlAttrPtr cur);
xmlChar *xmlNodeGetContent(const xmlNode *cur);
xmlChar *xmlGetProp(const xmlNode *node, const xmlChar *name);
xmlAttrPtr xmlHasProp(const xmlNode *node, const xmlChar *name);
xmlNsPtr xmlSearchNs(xmlDocPtr doc, xmlNodePtr node,
                     const xmlChar *nameSpace);
xmlNsPtr xmlSearchNsByHref(xmlDocPtr doc, xmlNodePtr node,
                           const xmlChar *href);
xmlAttrPtr xmlHasNsProp(const xmlNode *node, const xmlChar *name,
                        const xmlChar *href);
xmlChar *xmlGetNsProp(const xmlNode *node, const xmlChar *name,
                      const xmlChar *href);
xmlChar *xmlGetNoNsProp(const xmlNode *node, const xmlChar *name);
xmlNodePtr xmlFirstElementChild(const xmlNode *parent);
xmlNodePtr xmlNextElementSibling(const xmlNode *node);
unsigned long xmlChildElementCount(const xmlNode *parent);

#ifdef __cplusplus
}
#endif

#endif
