#include <libxml/parser.h>
#include <libxml/tree.h>
#ifdef XML3_REFERENCE_TEST
#include <libxml/xmlversion.h>
#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void value_is(xmlNodePtr node, const char *expected) {
    xmlChar *value = xmlNodeGetContent(node);
    assert(value != NULL && strcmp((const char *)value, expected) == 0);
    xmlFree(value);
}

static void test_namespace_and_attribute_flow(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr child = xmlNewNode(NULL, BAD_CAST "child");
    xmlNsPtr def, p, q, other, shadow;
    xmlAttrPtr plain, first, second, duplicate;
    char href[] = "urn:one";
    char prefix[] = "p";
    assert(doc != NULL && root != NULL && child != NULL);
    def = xmlNewNs(root, BAD_CAST "urn:default", NULL);
    p = xmlNewNs(root, BAD_CAST href, BAD_CAST prefix);
    q = xmlNewNs(root, BAD_CAST "urn:one", BAD_CAST "q");
    other = xmlNewNs(root, BAD_CAST "urn:two", BAD_CAST "other");
    assert(def != NULL && p != NULL && q != NULL && other != NULL);
    href[0] = 'X';
    prefix[0] = 'X';
    assert(strcmp((const char *)p->href, "urn:one") == 0);
    assert(strcmp((const char *)p->prefix, "p") == 0);
    assert(root->ns == NULL && root->nsDef == def);
    assert(def->next == p && p->next == q && q->next == other);
    assert(other->next == NULL);
    assert(xmlNewNs(root, BAD_CAST "urn:collision", BAD_CAST "p") == NULL);
    assert(xmlNewNs(root, BAD_CAST "urn:collision", NULL) == NULL);
    assert(other->next == NULL);
    xmlResetLastError();
    xmlSetNs(root, def);
    assert(root->ns == def);
    assert(xmlAddChild(root, child) == child);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    xmlSetNs(child, p);
    assert(child->ns == p);
    assert(xmlSearchNs(doc, child, BAD_CAST "p") == p);
    assert(xmlSearchNs(doc, child, NULL) == def);

    plain = xmlNewProp(child, BAD_CAST "a", BAD_CAST "plain");
    first = xmlNewNsProp(child, p, BAD_CAST "a", BAD_CAST "one");
    second = xmlSetNsProp(child, other, BAD_CAST "a", BAD_CAST "two");
    assert(plain != NULL && first != NULL && second != NULL);
    assert(child->properties == plain && plain->next == first);
    assert(first->next == second && second->prev == first);
    assert(first->doc == doc && first->children->doc == doc);
    first->_private = &href;
    assert(xmlSetNsProp(child, q, BAD_CAST "a", BAD_CAST "&amp; &#65;") == first);
    assert(first->ns == q && first->_private == &href);
    value_is((xmlNodePtr)first, "&amp; &#65;");
    value_is((xmlNodePtr)plain, "plain");
    value_is((xmlNodePtr)second, "two");
    assert(xmlSetProp(child, BAD_CAST "p:a", BAD_CAST "qualified") == first);
    assert(first->ns == p);
    value_is((xmlNodePtr)first, "qualified");
    assert(xmlSetNsProp(child, q, BAD_CAST "a", NULL) == first);
    assert(first->ns == q && first->children == NULL && first->last == NULL);
    assert(xmlSetNsProp(child, p, BAD_CAST "a", BAD_CAST "") == first);
    assert(first->children != NULL);
    value_is((xmlNodePtr)first, "");
    duplicate = xmlNewNsProp(child, p, BAD_CAST "a", BAD_CAST "duplicate");
    assert(duplicate != NULL && duplicate != first && second->next == duplicate);
    assert(xmlUnsetNsProp(child, q, BAD_CAST "a") == 0);
    assert(plain->next == second && second->prev == plain);
    assert(xmlHasNsProp(child, BAD_CAST "a", BAD_CAST "urn:one") == duplicate);
    assert(xmlRemoveProp(duplicate) == 0 && second->next == NULL);
    assert(xmlUnsetNsProp(child, p, BAD_CAST "a") == -1);
    assert(xmlUnsetNsProp(child, NULL, BAD_CAST "a") == 0);
    assert(child->properties == second && second->prev == NULL);
    assert(xmlRemoveProp(second) == 0 && child->properties == NULL);

    shadow = xmlNewNs(child, BAD_CAST "urn:shadow", BAD_CAST "p");
    assert(shadow != NULL && xmlSearchNs(doc, child, BAD_CAST "p") == shadow);
    first = xmlSetProp(child, BAD_CAST "p:a", BAD_CAST "shadow");
    assert(first != NULL && first->ns == shadow);
    assert(xmlHasNsProp(child, BAD_CAST "a", BAD_CAST "urn:one") == NULL);
    xmlSetNs(child, NULL);
    assert(child->ns == NULL);
    xmlSetNs((xmlNodePtr)first, other);
    assert(first->ns == other);
    assert(xmlUnsetNsProp(child, other, BAD_CAST "a") == 0);
    assert(xmlSetProp(child, BAD_CAST "xml:lang", BAD_CAST "ja") != NULL);
    assert(xmlHasNsProp(child, BAD_CAST "lang",
                       BAD_CAST "http://www.w3.org/XML/1998/namespace") != NULL);
    xmlFreeDoc(doc);
}

static void test_standalone_and_parsed(void) {
    static const char input[] = "<r xmlns:p='urn:one' p:a='old'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNsPtr alias, empty, null_href;
    xmlAttrPtr attr;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    alias = xmlNewNs(root, BAD_CAST "urn:one", BAD_CAST "alias");
    assert(alias != NULL && root->nsDef->next == alias);
    attr = root->properties;
    assert(xmlSetNsProp(root, alias, BAD_CAST "a", BAD_CAST "new") == attr);
    assert(attr->ns == alias);
    value_is((xmlNodePtr)attr, "new");
    xmlSetNs((xmlNodePtr)attr, root->nsDef);
    assert(attr->ns == root->nsDef);
    assert(xmlUnsetNsProp(root, alias, BAD_CAST "a") == 0);
    xmlFreeDoc(doc);

    alias = xmlNewNs(NULL, BAD_CAST "urn:standalone", BAD_CAST "p");
    attr = xmlNewNsProp(NULL, alias, BAD_CAST "a", BAD_CAST "standalone");
    assert(alias != NULL && attr != NULL && attr->ns == alias);
    assert(attr->parent == NULL && attr->doc == NULL);
    value_is((xmlNodePtr)attr, "standalone");
    xmlFreeProp(attr);
    xmlFreeNs(alias);
    xmlFreeNs(NULL);
    empty = xmlNewNs(NULL, BAD_CAST "", NULL);
    null_href = xmlNewNs(NULL, NULL, BAD_CAST "p");
    assert(empty != NULL && empty->href != NULL && empty->href[0] == 0);
    assert(null_href != NULL && null_href->href == NULL);
    xmlFreeNs(empty);
    xmlFreeNs(null_href);
}

#ifndef XML3_REFERENCE_TEST
static void assert_tree_error(void) {
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    xmlResetLastError();
}

static void test_rejected_operations(void) {
    static const char input[] = "<r xmlns:p='urn:one' p:a='old'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNsPtr ns, missing_href;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    ns = xmlNewNs(root, BAD_CAST "urn:two", BAD_CAST "q");
    assert(ns != NULL);
    xmlFreeNs(ns);
    assert_tree_error();
    xmlFreeNs(root->nsDef);
    assert_tree_error();
    assert(root->nsDef->next == ns && ns->next == NULL);
    assert(xmlNewNs((xmlNodePtr)doc, BAD_CAST "urn:bad", NULL) == NULL);
    assert_tree_error();
    assert(xmlSetProp(root, BAD_CAST "missing:a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlSetProp(root, BAD_CAST "p:a:b", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlSetProp(root, BAD_CAST ":a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlSetProp(root, BAD_CAST "p:", BAD_CAST "bad") == NULL);
    assert_tree_error();
    xmlSetNs(root, (xmlNsPtr)root);
    assert_tree_error();
    assert(root->ns == NULL);
    missing_href = xmlNewNs(NULL, NULL, BAD_CAST "p");
    assert(missing_href != NULL);
    assert(xmlSetNsProp(root, missing_href, BAD_CAST "a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    xmlFreeNs(missing_href);
    value_is((xmlNodePtr)root->properties, "old");
    xmlFreeDoc(doc);
}

static void test_retained_namespace_lifetimes(void) {
    static const char input[] = "<source xmlns:p='urn:parsed'/>";
    xmlDocPtr source = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr target = xmlNewDoc(NULL);
    xmlNodePtr source_root, root, borrower;
    xmlNsPtr parsed, created, standalone;
    xmlAttrPtr attr;
    assert(source != NULL && target != NULL);
    source_root = xmlDocGetRootElement(source);
    parsed = source_root->nsDef;
    created = xmlNewNs(source_root, BAD_CAST "urn:created", BAD_CAST "c");
    root = xmlNewNode(NULL, BAD_CAST "target");
    borrower = xmlNewNode(parsed, BAD_CAST "borrower");
    assert(created != NULL && root != NULL && borrower != NULL);
    assert(xmlDocSetRootElement(target, root) == NULL);
    assert(xmlAddChild(root, borrower) == borrower);
    attr = xmlNewNsProp(root, created, BAD_CAST "a", BAD_CAST "value");
    assert(attr != NULL);
    xmlFreeDoc(source);
    assert(strcmp((const char *)borrower->ns->href, "urn:parsed") == 0);
    assert(strcmp((const char *)attr->ns->href, "urn:created") == 0);
    assert(attr->ns->next == NULL);
    standalone = xmlNewNs(NULL, BAD_CAST "urn:standalone", BAD_CAST "s");
    assert(standalone != NULL);
    xmlSetNs(borrower, standalone);
    assert(borrower->ns == standalone);
    xmlSetNs((xmlNodePtr)attr, standalone);
    assert(attr->ns == standalone);
    xmlFreeNs(standalone);
    assert(strcmp((const char *)borrower->ns->href, "urn:standalone") == 0);
    assert(xmlRemoveProp(attr) == 0);
    xmlUnlinkNode(borrower);
    xmlFreeDoc(target);
    assert(strcmp((const char *)borrower->ns->prefix, "s") == 0);
    xmlFreeNode(borrower);

    source = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    assert(source != NULL);
    source_root = xmlDocGetRootElement(source);
    borrower = xmlNewNode(source_root->nsDef, BAD_CAST "shared-pin");
    assert(borrower != NULL && xmlAddChild(source_root, borrower) == borrower);
    standalone = xmlNewNs(NULL, BAD_CAST "urn:replacement", BAD_CAST "s");
    assert(standalone != NULL);
    xmlSetNs(borrower, standalone);
    xmlFreeNs(standalone);
    xmlUnlinkNode(borrower);
    xmlFreeDoc(source);
    assert(borrower->doc->type == XML_DOCUMENT_NODE);
    xmlSetNs(borrower, NULL);
    assert(borrower->ns == NULL && borrower->doc->type == XML_DOCUMENT_NODE);
    xmlFreeNode(borrower);
}
#endif

int main(void) {
#ifdef XML3_REFERENCE_TEST
    assert(LIBXML_VERSION == 21504);
    assert(strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) == 0);
#endif
    test_namespace_and_attribute_flow();
    test_standalone_and_parsed();
#ifndef XML3_REFERENCE_TEST
    test_rejected_operations();
    test_retained_namespace_lifetimes();
#endif
    puts("Namespace editing tests passed");
    return 0;
}
