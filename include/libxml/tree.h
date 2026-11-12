#ifndef LIBXML3_TREE_H
#define LIBXML3_TREE_H

#include <stdio.h>
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
typedef struct _xmlEntity xmlEntity;
typedef struct _xmlEntity *xmlEntityPtr;

typedef enum {
    XML_ELEMENT_NODE = 1,
    XML_ATTRIBUTE_NODE = 2,
    XML_TEXT_NODE = 3,
    XML_CDATA_SECTION_NODE = 4,
    XML_PI_NODE = 7,
    XML_COMMENT_NODE = 8,
    XML_DOCUMENT_NODE = 9,
    XML_ENTITY_DECL = 17,
    XML_NAMESPACE_DECL = 18
} xmlElementType;

typedef xmlElementType xmlNsType;

/* libxml2 2.15 only uses XML_BUFFER_ALLOC_IO; the other values remain for
 * source compatibility. */
typedef enum {
    XML_BUFFER_ALLOC_DOUBLEIT,
    XML_BUFFER_ALLOC_EXACT,
    XML_BUFFER_ALLOC_IMMUTABLE,
    XML_BUFFER_ALLOC_IO,
    XML_BUFFER_ALLOC_HYBRID,
    XML_BUFFER_ALLOC_BOUNDED
} xmlBufferAllocationScheme;

typedef struct _xmlBuffer xmlBuffer;
typedef struct _xmlBuffer *xmlBufferPtr;

/* The fields are deprecated in libxml2; use xmlBufferContent and
 * xmlBufferLength. */
struct _xmlBuffer {
    xmlChar *content;
    unsigned int use;
    unsigned int size;
    xmlBufferAllocationScheme alloc;
    xmlChar *contentIO;
};

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
int xmlIsXHTML(const xmlChar *systemID, const xmlChar *publicID);
xmlDocPtr xmlNewDoc(const xmlChar *version);
void xmlDocDumpMemory(xmlDocPtr cur, xmlChar **mem, int *size);
void xmlDocDumpMemoryEnc(xmlDocPtr cur, xmlChar **mem, int *size,
                         const char *encoding);
void xmlDocDumpFormatMemory(xmlDocPtr cur, xmlChar **mem, int *size,
                            int format);
void xmlDocDumpFormatMemoryEnc(xmlDocPtr cur, xmlChar **mem, int *size,
                               const char *encoding, int format);
xmlNodePtr xmlNewNode(xmlNsPtr ns, const xmlChar *name);
xmlNodePtr xmlNewDocNode(xmlDocPtr doc, xmlNsPtr ns,
                         const xmlChar *name, const xmlChar *content);
xmlNodePtr xmlNewDocRawNode(xmlDocPtr doc, xmlNsPtr ns,
                            const xmlChar *name, const xmlChar *content);
xmlNodePtr xmlNewChild(xmlNodePtr parent, xmlNsPtr ns,
                       const xmlChar *name, const xmlChar *content);
xmlNodePtr xmlNewTextChild(xmlNodePtr parent, xmlNsPtr ns,
                           const xmlChar *name, const xmlChar *content);
xmlNodePtr xmlNewText(const xmlChar *content);
xmlNodePtr xmlNewTextLen(const xmlChar *content, int len);
xmlNodePtr xmlNewDocText(const xmlDoc *doc, const xmlChar *content);
xmlNodePtr xmlNewDocTextLen(xmlDocPtr doc, const xmlChar *content, int len);
xmlNodePtr xmlStringGetNodeList(const xmlDoc *doc, const xmlChar *value);
xmlNodePtr xmlStringLenGetNodeList(const xmlDoc *doc, const xmlChar *value,
                                 int len);
xmlNodePtr xmlNewComment(const xmlChar *content);
xmlNodePtr xmlNewPI(const xmlChar *name, const xmlChar *content);
xmlNodePtr xmlNewDocComment(xmlDocPtr doc, const xmlChar *content);
xmlNodePtr xmlNewCDataBlock(xmlDocPtr doc, const xmlChar *content, int len);
xmlNodePtr xmlNewDocPI(xmlDocPtr doc, const xmlChar *name, const xmlChar *content);
xmlNodePtr xmlDocSetRootElement(xmlDocPtr doc, xmlNodePtr root);
xmlNodePtr xmlAddChild(xmlNodePtr parent, xmlNodePtr cur);
xmlNodePtr xmlAddSibling(xmlNodePtr node, xmlNodePtr cur);
xmlNodePtr xmlAddPrevSibling(xmlNodePtr node, xmlNodePtr cur);
xmlNodePtr xmlAddNextSibling(xmlNodePtr node, xmlNodePtr cur);
xmlNodePtr xmlReplaceNode(xmlNodePtr old, xmlNodePtr cur);
xmlNodePtr xmlTextMerge(xmlNodePtr first, xmlNodePtr second);
int xmlTextConcat(xmlNodePtr node, const xmlChar *content, int len);
int xmlNodeIsText(const xmlNode *node);
int xmlIsBlankNode(const xmlNode *node);
xmlChar *xmlNodeGetLang(const xmlNode *node);
int xmlNodeGetSpacePreserve(const xmlNode *node);
int xmlNodeSetLang(xmlNodePtr node, const xmlChar *lang);
int xmlNodeSetSpacePreserve(xmlNodePtr node, int value);
int xmlNodeAddContent(xmlNodePtr cur, const xmlChar *content);
int xmlNodeAddContentLen(xmlNodePtr cur, const xmlChar *content, int len);
int xmlNodeSetContent(xmlNodePtr cur, const xmlChar *content);
int xmlNodeSetContentLen(xmlNodePtr cur, const xmlChar *content, int len);
void xmlNodeSetName(xmlNode *cur, const xmlChar *name);
void xmlUnlinkNode(xmlNodePtr cur);
void xmlFreeNode(xmlNodePtr cur);
void xmlFreeNodeList(xmlNodePtr cur);
void xmlFreeDoc(xmlDocPtr cur);
xmlNsPtr xmlNewNs(xmlNodePtr node, const xmlChar *href, const xmlChar *prefix);
void xmlSetNs(xmlNodePtr node, xmlNsPtr ns);
void xmlFreeNs(xmlNsPtr cur);
xmlNsPtr xmlCopyNamespace(xmlNsPtr cur);
xmlNodePtr xmlCopyNode(xmlNodePtr node, int extended);
xmlNodePtr xmlDocCopyNode(xmlNodePtr node, xmlDocPtr doc, int extended);
xmlAttrPtr xmlCopyProp(xmlNodePtr target, xmlAttrPtr cur);
xmlDocPtr xmlCopyDoc(xmlDocPtr doc, int recursive);
xmlBufferPtr xmlBufferCreate(void);
xmlBufferPtr xmlBufferCreateSize(size_t size);
xmlBufferPtr xmlBufferCreateStatic(void *mem, size_t size);
void xmlBufferFree(xmlBufferPtr buf);
void xmlBufferEmpty(xmlBufferPtr buf);
int xmlBufferShrink(xmlBufferPtr buf, unsigned int len);
int xmlBufferGrow(xmlBufferPtr buf, unsigned int len);
int xmlBufferResize(xmlBufferPtr buf, unsigned int size);
int xmlBufferAdd(xmlBufferPtr buf, const xmlChar *str, int len);
int xmlBufferAddHead(xmlBufferPtr buf, const xmlChar *str, int len);
int xmlBufferCat(xmlBufferPtr buf, const xmlChar *str);
int xmlBufferCCat(xmlBufferPtr buf, const char *str);
void xmlBufferWriteCHAR(xmlBufferPtr buf, const xmlChar *string);
void xmlBufferWriteChar(xmlBufferPtr buf, const char *string);
void xmlBufferWriteQuotedString(xmlBufferPtr buf, const xmlChar *string);
const xmlChar *xmlBufferContent(const xmlBuffer *buf);
int xmlBufferLength(const xmlBuffer *buf);
xmlChar *xmlBufferDetach(xmlBufferPtr buf);
void xmlBufferSetAllocationScheme(xmlBufferPtr buf,
                                  xmlBufferAllocationScheme scheme);
int xmlBufferDump(FILE *file, xmlBufferPtr buf);
int xmlNodeDump(xmlBufferPtr buf, xmlDocPtr doc, xmlNodePtr cur, int level,
                int format);
void xmlElemDump(FILE *f, xmlDocPtr doc, xmlNodePtr cur);
int xmlDocDump(FILE *f, xmlDocPtr cur);
int xmlDocFormatDump(FILE *f, xmlDocPtr cur, int format);
int xmlSaveFile(const char *filename, xmlDocPtr cur);
int xmlSaveFormatFile(const char *filename, xmlDocPtr cur, int format);
int xmlSaveFileEnc(const char *filename, xmlDocPtr cur, const char *encoding);
int xmlSaveFormatFileEnc(const char *filename, xmlDocPtr cur,
                         const char *encoding, int format);
xmlNodePtr xmlNewNodeEatName(xmlNsPtr ns, xmlChar *name);
xmlNodePtr xmlNewDocNodeEatName(xmlDocPtr doc, xmlNsPtr ns, xmlChar *name,
                                const xmlChar *content);
xmlAttrPtr xmlNewNsPropEatName(xmlNodePtr node, xmlNsPtr ns, xmlChar *name,
                               const xmlChar *value);
xmlBufferAllocationScheme xmlGetBufferAllocationScheme(void);
void xmlSetBufferAllocationScheme(xmlBufferAllocationScheme scheme);
int xmlNodeBufGetContent(xmlBufferPtr buffer, const xmlNode *cur);
void xmlAttrSerializeTxtContent(xmlBufferPtr buf, xmlDocPtr doc,
                                xmlAttrPtr attr, const xmlChar *string);
void xmlFreeNsList(xmlNsPtr cur);
xmlAttrPtr xmlNewProp(xmlNodePtr node, const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlNewDocProp(xmlDocPtr doc, const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlNewNsProp(xmlNodePtr node, xmlNsPtr ns,
                        const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlSetNsProp(xmlNodePtr node, xmlNsPtr ns,
                        const xmlChar *name, const xmlChar *value);
xmlAttrPtr xmlSetProp(xmlNodePtr node, const xmlChar *name, const xmlChar *value);
int xmlUnsetNsProp(xmlNodePtr node, xmlNsPtr ns, const xmlChar *name);
int xmlUnsetProp(xmlNodePtr node, const xmlChar *name);
int xmlRemoveProp(xmlAttrPtr cur);
void xmlFreeProp(xmlAttrPtr cur);
void xmlFreePropList(xmlAttrPtr cur);
int xmlValidateName(const xmlChar *value, int space);
int xmlValidateNCName(const xmlChar *value, int space);
int xmlValidateQName(const xmlChar *value, int space);
int xmlValidateNMToken(const xmlChar *value, int space);
xmlChar *xmlSplitQName2(const xmlChar *name, xmlChar **prefix);
xmlChar *xmlBuildQName(const xmlChar *ncname, const xmlChar *prefix,
                       xmlChar *memory, int len);
const xmlChar *xmlSplitQName3(const xmlChar *name, int *len);
xmlChar *xmlNodeGetContent(const xmlNode *cur);
xmlChar *xmlNodeListGetRawString(const xmlDoc *doc, const xmlNode *list,
                                int inLine);
xmlChar *xmlNodeListGetString(xmlDoc *doc, const xmlNode *list, int inLine);
xmlChar *xmlGetNodePath(const xmlNode *node);
long xmlGetLineNo(const xmlNode *node);
xmlChar *xmlGetProp(const xmlNode *node, const xmlChar *name);
xmlAttrPtr xmlHasProp(const xmlNode *node, const xmlChar *name);
xmlNsPtr xmlSearchNs(xmlDocPtr doc, xmlNodePtr node,
                     const xmlChar *nameSpace);
int xmlGetNsListSafe(const xmlDoc *doc, const xmlNode *node, xmlNs ***out);
xmlNs **xmlGetNsList(const xmlDoc *doc, const xmlNode *node);
xmlNsPtr xmlSearchNsByHref(xmlDocPtr doc, xmlNodePtr node,
                           const xmlChar *href);
xmlAttrPtr xmlHasNsProp(const xmlNode *node, const xmlChar *name,
                        const xmlChar *href);
xmlChar *xmlGetNsProp(const xmlNode *node, const xmlChar *name,
                      const xmlChar *href);
xmlChar *xmlGetNoNsProp(const xmlNode *node, const xmlChar *name);
int xmlNodeGetAttrValue(const xmlNode *node, const xmlChar *name,
                        const xmlChar *nsUri, xmlChar **out);
xmlNodePtr xmlFirstElementChild(const xmlNode *parent);
xmlNodePtr xmlLastElementChild(xmlNode *parent);
xmlNodePtr xmlGetLastChild(const xmlNode *parent);
xmlNodePtr xmlNextElementSibling(const xmlNode *node);
xmlNodePtr xmlPreviousElementSibling(xmlNode *node);
unsigned long xmlChildElementCount(const xmlNode *parent);

#ifdef __cplusplus
}
#endif

#endif
