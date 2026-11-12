/* Node, property and document copies.  The output of this program is
 * compared between libxml3 and the pinned reference libxml2 (make
 * test-copy), so every line must describe behavior both share. */
#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void put_string(const xmlChar *value) {
    if (value == NULL) {
        fputs("null", stdout);
        return;
    }
    putchar('"');
    for (; *value; ++value) {
        if (*value < 0x20 || *value >= 0x7f || *value == '"' || *value == '\\')
            printf("\\x%02x", (unsigned)*value);
        else
            putchar(*value);
    }
    putchar('"');
}

/* Whether ns is one of the declarations on node or its ancestors. */
static int declared_above(const xmlNode *node, const xmlNs *ns) {
    for (; node != NULL; node = node->parent) {
        if (node->type != XML_ELEMENT_NODE)
            continue;
        for (const xmlNs *def = node->nsDef; def != NULL; def = def->next)
            if (def == ns)
                return 1;
    }
    return 0;
}

static void put_ns(const xmlNode *holder, const xmlNs *ns) {
    if (ns == NULL) {
        fputs("none", stdout);
        return;
    }
    put_string(ns->prefix);
    putchar('=');
    put_string(ns->href);
    fputs(declared_above(holder, ns) ? "@scope" : "@outside", stdout);
}

static const char *doc_relation(const xmlNode *node, const xmlDoc *doc) {
    if (node->doc == NULL)
        return "nodoc";
    return node->doc == doc ? "doc" : "otherdoc";
}

static void dump(const xmlNode *node, const xmlDoc *doc, int depth);

static void dump_attr(const xmlAttr *attr, const xmlDoc *doc, int depth) {
    printf("%*s@", depth * 2, "");
    put_string(attr->name);
    printf(" %s ns:", doc_relation((const xmlNode *)attr, doc));
    put_ns(attr->parent != NULL ? attr->parent : (const xmlNode *)attr,
           attr->ns);
    putchar('\n');
    for (const xmlNode *child = attr->children; child; child = child->next) {
        assert(child->parent == (const xmlNode *)attr);
        dump(child, doc, depth + 1);
    }
}

static void dump(const xmlNode *node, const xmlDoc *doc, int depth) {
    printf("%*s%d ", depth * 2, "", (int)node->type);
    put_string(node->name);
    printf(" %s", doc_relation(node, doc));
    if (node->type == XML_ELEMENT_NODE) {
        fputs(" ns:", stdout);
        put_ns(node, node->ns);
        for (const xmlNs *def = node->nsDef; def != NULL; def = def->next) {
            fputs(" def:", stdout);
            put_string(def->prefix);
            putchar('=');
            put_string(def->href);
        }
    } else {
        fputs(" content:", stdout);
        put_string(node->content);
    }
    putchar('\n');
    if (node->type == XML_ELEMENT_NODE)
        for (const xmlAttr *attr = node->properties; attr; attr = attr->next) {
            assert(attr->parent == node);
            dump_attr(attr, doc, depth + 1);
        }
    for (const xmlNode *child = node->children; child; child = child->next) {
        assert(child->parent == node);
        dump(child, doc, depth + 1);
    }
}

static void dump_document(const char *label, xmlDocPtr doc) {
    xmlChar *memory = NULL;
    int size = 0;

    printf("== %s version:", label);
    put_string(doc->version);
    putchar('\n');
    for (const xmlNode *child = doc->children; child; child = child->next) {
        assert(child->parent == (const xmlNode *)doc);
        dump(child, doc, 1);
    }
    xmlDocDumpMemory(doc, &memory, &size);
    assert(memory != NULL);
    fputs((const char *)memory, stdout);
    xmlFree(memory);
}

static xmlDocPtr parse(const char *text) {
    xmlDocPtr doc = xmlReadMemory(text, (int)strlen(text), NULL, NULL, 0);
    assert(doc != NULL);
    return doc;
}

static xmlNodePtr child_element(xmlNodePtr parent, const char *name) {
    for (xmlNodePtr child = parent->children; child; child = child->next)
        if (child->type == XML_ELEMENT_NODE &&
            strcmp((const char *)child->name, name) == 0)
            return child;
    assert(0);
    return NULL;
}

static const char sample[] =
    "<r xmlns:a='urn:a' xmlns='urn:d'>"
    "<a:x a:at='one' b='two&amp;'><y>t<!--c--><?pi data?><![CDATA[<cd>]]></y>"
    "<e xml:lang='en'/></a:x>"
    "<z xmlns:a='urn:other'/></r>";

static void test_node_copies(void) {
    xmlDocPtr doc = parse(sample);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlNodePtr x = child_element(root, "x");
    xmlNodePtr y = child_element(x, "y");

    for (int extended = 0; extended <= 3; ++extended) {
        xmlNodePtr copy = xmlCopyNode(x, extended);
        assert(copy != NULL && copy != x);
        assert(copy->parent == NULL && copy->next == NULL && copy->prev == NULL);
        printf("== xmlCopyNode(x, %d)\n", extended);
        dump(copy, doc, 0);
        xmlFreeNode(copy);
    }
    {
        xmlNodePtr copy = xmlCopyNode(y, 1);
        printf("== xmlCopyNode(y, 1) default namespace\n");
        dump(copy, doc, 0);
        xmlFreeNode(copy);
    }
    for (xmlNodePtr child = y->children; child; child = child->next) {
        xmlNodePtr copy = xmlCopyNode(child, 1);
        assert(copy != NULL && copy->type == child->type);
        printf("== xmlCopyNode(child of y, 1)\n");
        dump(copy, doc, 0);
        xmlFreeNode(copy);
    }
    {
        xmlNodePtr copy = xmlDocCopyNode(x, doc, 1);
        printf("== xmlDocCopyNode(x, same doc, 1)\n");
        dump(copy, doc, 0);
        assert(xmlAddChild(root, copy) == copy);
        dump_document("same doc after xmlAddChild", doc);
    }
    {
        xmlDocPtr target = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr copy = xmlDocCopyNode(x, target, 1);
        printf("== xmlDocCopyNode(x, other doc, 1)\n");
        dump(copy, target, 0);
        assert(xmlDocSetRootElement(target, copy) == NULL);
        dump_document("other doc", target);
        xmlFreeDoc(target);
    }
    xmlFreeDoc(doc);
}

static void test_property_copies(void) {
    xmlDocPtr doc = parse(sample);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlNodePtr x = child_element(root, "x");
    xmlNodePtr z = child_element(root, "z");
    xmlAttrPtr prefixed = x->properties;
    xmlAttrPtr plain = prefixed->next;
    xmlDocPtr other = parse("<o/>");
    xmlNodePtr o = xmlDocGetRootElement(other);
    xmlAttrPtr copy;

    printf("== xmlCopyNode(attribute, 1)\n");
    copy = (xmlAttrPtr)xmlCopyNode((xmlNodePtr)prefixed, 1);
    assert(copy != NULL && copy->parent == NULL);
    dump_attr(copy, doc, 0);
    xmlFreeProp(copy);

    printf("== xmlCopyProp(NULL, prefixed)\n");
    copy = xmlCopyProp(NULL, prefixed);
    dump_attr(copy, doc, 0);
    xmlFreeProp(copy);

    /* The target redeclares the prefix for another name: reconciled. */
    printf("== xmlCopyProp(z, prefixed)\n");
    copy = xmlCopyProp(z, prefixed);
    copy->parent = NULL;
    dump_attr(copy, doc, 0);
    printf("   target ");
    dump(z, doc, 0);
    xmlFreeProp(copy);

    /* The target has no declaration: declared again on its root. */
    printf("== xmlCopyProp(other root, prefixed)\n");
    copy = xmlCopyProp(o, prefixed);
    copy->parent = NULL;
    dump_attr(copy, other, 0);
    printf("   target ");
    dump(o, other, 0);
    xmlFreeProp(copy);

    printf("== xmlCopyProp(other root, plain)\n");
    copy = xmlCopyProp(o, plain);
    copy->parent = NULL;
    dump_attr(copy, other, 0);
    xmlFreeProp(copy);

    xmlFreeDoc(other);
    xmlFreeDoc(doc);
}

static void test_reconciled_element(void) {
    xmlDocPtr doc = parse("<r xmlns:q='urn:taken'><c/></r>");
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlNodePtr c = root->children;
    xmlNsPtr loose = xmlNewNs(NULL, BAD_CAST "urn:loose", BAD_CAST "q");
    xmlNodePtr copy;

    assert(loose != NULL);
    xmlSetNs(c, loose);
    /* q is bound to another name on the copy's new parent: q1. */
    copy = xmlCopyNode(c, 1);
    printf("== reconciled, detached\n");
    dump(copy, doc, 0);
    assert(xmlAddChild(root, copy) == copy);
    copy = xmlDocCopyNode(c, doc, 1);
    xmlFreeNode(copy);
    xmlSetNs(c, NULL);
    xmlFreeNs(loose);
    dump_document("reconciled", doc);
    xmlFreeDoc(doc);
}

static void test_document_copies(void) {
    static const char text[] =
        "<?xml version='1.0'?><!--before--><r xmlns:a='urn:a'><a:c a:k='v'>"
        "text</a:c></r><?after x?>";
    xmlDocPtr doc = parse(text);
    xmlDocPtr shallow = xmlCopyDoc(doc, 0);
    xmlDocPtr deep = xmlCopyDoc(doc, 1);
    xmlDocPtr through_node = (xmlDocPtr)xmlCopyNode((xmlNodePtr)doc, 2);
    xmlDocPtr versionless = xmlNewDoc(NULL);
    xmlDocPtr versionless_copy = xmlCopyDoc(versionless, 1);

    assert(shallow != NULL && shallow->children == NULL);
    dump_document("xmlCopyDoc(doc, 0)", shallow);
    dump_document("xmlCopyDoc(doc, 1)", deep);
    dump_document("xmlCopyNode(doc, 2)", through_node);
    dump_document("xmlCopyDoc(versionless, 1)", versionless_copy);
    xmlFreeDoc(versionless_copy);
    xmlFreeDoc(versionless);
    xmlFreeDoc(through_node);
    xmlFreeDoc(deep);
    xmlFreeDoc(shallow);
    xmlFreeDoc(doc);
}

static void test_arguments(void) {
    xmlDocPtr doc = parse("<r a='1'/>");
    xmlNodePtr root = xmlDocGetRootElement(doc);

    xmlResetLastError();
    assert(xmlCopyNode(NULL, 1) == NULL);
    assert(xmlDocCopyNode(NULL, doc, 1) == NULL);
    assert(xmlCopyProp(root, NULL) == NULL);
    assert(xmlCopyProp(NULL, NULL) == NULL);
    assert(xmlCopyDoc(NULL, 1) == NULL);
    /* A target that is not an element. */
    assert(xmlCopyProp((xmlNodePtr)root->properties, root->properties) == NULL);
    assert(xmlGetLastError() == NULL);
    printf("== argument checks\n");
    xmlFreeDoc(doc);
}

int main(void) {
    test_node_copies();
    test_property_copies();
    test_reconciled_element();
    test_document_copies();
    test_arguments();
    puts("copy tests passed");
    return 0;
}
