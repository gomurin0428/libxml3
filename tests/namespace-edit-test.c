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

#ifndef XML3_REFERENCE_TEST
static void expect_tree_error(void) {
    const xmlError *error = xmlGetLastError();
    assert(error != NULL);
    assert(error->domain == XML_FROM_TREE);
    assert(error->code == 115);
    xmlResetLastError();
}
#endif

static void test_namespace_property_flow(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr child = xmlNewNode(NULL, BAD_CAST "child");
    xmlNsPtr def, p, q, other;
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
    {
        xmlNodePtr prefix_root = xmlNewNode(NULL, BAD_CAST "prefixes");
        xmlNsPtr no_prefix, empty_prefix;
        assert(prefix_root != NULL);
        no_prefix = xmlNewNs(prefix_root, BAD_CAST "urn:null-prefix", NULL);
        empty_prefix = xmlNewNs(prefix_root, BAD_CAST "urn:empty-prefix",
                                BAD_CAST "");
        assert(no_prefix != NULL && empty_prefix != NULL);
        assert(xmlNewNs(prefix_root, BAD_CAST "urn:duplicate-null", NULL)
               == NULL);
        assert(xmlNewNs(prefix_root, BAD_CAST "urn:duplicate-empty",
                        BAD_CAST "") == NULL);
        xmlFreeNode(prefix_root);
    }

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
    {
        xmlAttrPtr updated = xmlSetProp(child, BAD_CAST "p:a",
                                        BAD_CAST "qualified");
        assert(updated == first);
    }
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

    {
        xmlNsPtr shadow = xmlNewNs(child, BAD_CAST "urn:shadow", BAD_CAST "p");
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
    }
    xmlFreeDoc(doc);
}

static void test_docless_xml_namespace(void) {
    static const xmlChar *xml_href =
        BAD_CAST "http://www.w3.org/XML/1998/namespace";
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlAttrPtr lang, space;
    xmlNsPtr ns;

    assert(root != NULL && root->doc == NULL);
    lang = xmlSetProp(root, BAD_CAST "xml:lang", BAD_CAST "ja");
    assert(lang != NULL && lang->parent == root);
    ns = lang->ns;
    assert(ns != NULL && root->nsDef == ns && ns->next == NULL);
    assert(strcmp((const char *)ns->prefix, "xml") == 0);
    assert(strcmp((const char *)ns->href, (const char *)xml_href) == 0);
    assert(xmlSearchNs(NULL, root, BAD_CAST "xml") == ns);
    assert(xmlSearchNsByHref(NULL, root, xml_href) == ns);
    assert(xmlSearchNs(NULL, (xmlNodePtr)lang, BAD_CAST "xml") == ns);
    assert(xmlSearchNsByHref(NULL, (xmlNodePtr)lang, xml_href) == ns);
    space = xmlSetProp(root, BAD_CAST "xml:space", BAD_CAST "preserve");
    assert(space != NULL && space->ns == ns);
    assert(root->nsDef == ns && ns->next == NULL);
    xmlFreeNode(root);
}

static void test_standalone_and_parsed_namespaces(void) {
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
    assert(alias != NULL);
    attr = xmlNewNsProp(NULL, alias, BAD_CAST "a", BAD_CAST "standalone");
    assert(attr != NULL && attr->ns == alias);
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
static void test_rejections(void) {
    static const char input[] = "<r xmlns:p='urn:one' p:a='old'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNsPtr ns, missing_href;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    ns = xmlNewNs(root, BAD_CAST "urn:two", BAD_CAST "q");
    assert(ns != NULL);
    xmlFreeNs(ns);
    expect_tree_error();
    xmlFreeNs(root->nsDef);
    expect_tree_error();
    assert(root->nsDef->next == ns && ns->next == NULL);
    assert(xmlNewNs((xmlNodePtr)doc, BAD_CAST "urn:bad", NULL) == NULL);
    expect_tree_error();
    assert(xmlSetProp(root, BAD_CAST "missing:a", BAD_CAST "bad") == NULL);
    expect_tree_error();
    assert(xmlSetProp(root, BAD_CAST "p:a:b", BAD_CAST "bad") == NULL);
    expect_tree_error();
    assert(xmlSetProp(root, BAD_CAST ":a", BAD_CAST "bad") == NULL);
    expect_tree_error();
    assert(xmlSetProp(root, BAD_CAST "p:", BAD_CAST "bad") == NULL);
    expect_tree_error();
    xmlSetNs(root, (xmlNsPtr)root);
    expect_tree_error();
    assert(root->ns == NULL);
    missing_href = xmlNewNs(NULL, NULL, BAD_CAST "p");
    assert(missing_href != NULL);
    assert(xmlSetNsProp(root, missing_href, BAD_CAST "a", BAD_CAST "bad") == NULL);
    expect_tree_error();
    xmlFreeNs(missing_href);
    value_is((xmlNodePtr)root->properties, "old");
    xmlFreeDoc(doc);
}
#endif

#ifndef XML3_REFERENCE_TEST
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
    assert(borrower->ns->next == NULL && attr->ns->next == NULL);
    standalone = xmlNewNs(NULL, BAD_CAST "urn:standalone", BAD_CAST "s");
    assert(standalone != NULL);
    xmlSetNs(borrower, standalone);
    xmlSetNs((xmlNodePtr)attr, standalone);
    xmlFreeNs(standalone);
    assert(strcmp((const char *)borrower->ns->href, "urn:standalone") == 0);
    assert(xmlRemoveProp(attr) == 0);
    xmlUnlinkNode(borrower);
    xmlFreeDoc(target);
    assert(strcmp((const char *)borrower->ns->prefix, "s") == 0);
    xmlFreeNode(borrower);
}

static void test_docless_xml_namespace_lifetime(void) {
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlAttrPtr lang, detached;
    xmlNsPtr ns;
    assert(root != NULL);
    lang = xmlSetProp(root, BAD_CAST "xml:lang", BAD_CAST "ja");
    assert(lang != NULL && lang->ns != NULL);
    ns = lang->ns;
    detached = xmlNewNsProp(NULL, ns, BAD_CAST "detached", BAD_CAST "value");
    assert(detached != NULL && detached->parent == NULL && detached->ns == ns);
    xmlFreeNode(root);
    assert(detached->ns == ns);
    assert(strcmp((const char *)ns->prefix, "xml") == 0);
    assert(strcmp((const char *)ns->href,
                  "http://www.w3.org/XML/1998/namespace") == 0);
    xmlFreeProp(detached);
}

static void test_replace_last_namespace_borrower(void) {
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr original = xmlNewNs(NULL, BAD_CAST "urn:shared", BAD_CAST "old");
    xmlNsPtr replacement = xmlNewNs(NULL, BAD_CAST "urn:shared", BAD_CAST "new");
    xmlAttrPtr attr;
    int marker = 0;
    assert(root != NULL && original != NULL && replacement != NULL);
    attr = xmlNewNsProp(root, original, BAD_CAST "a", BAD_CAST "old");
    assert(attr != NULL);
    attr->_private = &marker;
    xmlFreeNs(original);
    assert(attr->ns == original);
    assert(xmlSetNsProp(root, replacement, BAD_CAST "a", BAD_CAST "new") == attr);
    assert(attr->ns == replacement && attr->_private == &marker);
    assert(root->properties == attr && attr->next == NULL && attr->prev == NULL);
    value_is((xmlNodePtr)attr, "new");
    xmlFreeNs(replacement);
    xmlFreeNode(root);
}
#endif

static void test_docless_namespace_lookup(void) {
    const xmlChar *xml_uri = BAD_CAST "http://www.w3.org/XML/1998/namespace";
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr child = xmlNewChild(root, NULL, BAD_CAST "child", BAD_CAST "text");
    xmlNsPtr ns, by_uri;
    xmlAttrPtr attr;
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlChar *dump = NULL;
    int size = 0;
    assert(root && child && doc && !child->nsDef);
    ns = xmlSearchNs(NULL, child->children, BAD_CAST "xml");
    assert(ns && child->nsDef == ns && !root->nsDef);
    assert(xmlStrEqual(ns->prefix, BAD_CAST "xml") && xmlStrEqual(ns->href, xml_uri));
    assert(xmlSearchNsByHref(NULL, child, xml_uri) == ns);
    assert(xmlSearchNs(NULL, child, BAD_CAST "xml") == ns && !ns->next);
    attr = xmlNewNsProp(child, ns, BAD_CAST "lang", BAD_CAST "ja");
    assert(attr && xmlSearchNs(NULL, (xmlNodePtr)attr, BAD_CAST "xml") == ns);
    by_uri = xmlSearchNsByHref(NULL, root, xml_uri);
    assert(by_uri && root->nsDef == by_uri && by_uri != ns);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    xmlDocDumpMemoryEnc(doc, &dump, &size, "UTF-8");
    assert(dump && size > 0);
    {
        xmlDocPtr parsed = xmlReadMemory((const char *)dump, size, NULL, NULL, 0);
        xmlChar *lang;
        assert(parsed);
        lang = xmlNodeGetLang(xmlDocGetRootElement(parsed)->children);
        assert(lang && xmlStrEqual(lang, BAD_CAST "ja"));
        xmlFree(lang);
        xmlFreeDoc(parsed);
    }
    xmlFree(dump);
    xmlFreeDoc(doc);
    root = xmlNewText(BAD_CAST "standalone");
    attr = xmlNewDocProp(NULL, BAD_CAST "standalone", NULL);
    assert(root && attr);
    assert(!xmlSearchNs(NULL, root, BAD_CAST "xml"));
    assert(!xmlSearchNsByHref(NULL, (xmlNodePtr)attr, xml_uri));
    xmlFreeNode(root);
    xmlFreeProp(attr);
#ifndef XML3_REFERENCE_TEST
    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "retained");
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    ns = xmlSearchNs(NULL, root, BAD_CAST "xml");
    assert(ns);
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    assert(xmlSearchNsByHref(NULL, root, xml_uri) == ns);
    assert(xmlNewNsProp(root, ns, BAD_CAST "lang", BAD_CAST "en"));
    xmlFreeNode(root);
#endif
}

static void test_null_namespace_uri_lookup(void) {
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr child = xmlNewChild(root, NULL, BAD_CAST "child", NULL);
    xmlNsPtr parent, null_uri, empty_uri;
    xmlAttrPtr attr;
    assert(root && child);
    parent = xmlNewNs(root, BAD_CAST "urn:parent", BAD_CAST "p");
    null_uri = xmlNewNs(child, NULL, BAD_CAST "p");
    empty_uri = xmlNewNs(child, BAD_CAST "", BAD_CAST "empty");
    assert(parent && null_uri && empty_uri);
    assert(xmlSearchNs(NULL, child, BAD_CAST "p") == parent);
    assert(xmlSearchNsByHref(NULL, child, NULL) == null_uri);
    assert(xmlSearchNsByHref(NULL, child, BAD_CAST "") == empty_uri);
    assert(!xmlSearchNsByHref(NULL, child, BAD_CAST "urn:parent"));
    attr = xmlNewProp(child, BAD_CAST "a", BAD_CAST "v");
    assert(attr && xmlSearchNsByHref(NULL, (xmlNodePtr)attr, NULL) == null_uri);
    assert(xmlSearchNs(NULL, child, BAD_CAST "empty") == empty_uri);
    assert(!xmlSearchNsByHref(NULL, root, NULL));
    xmlFreeNode(root);
}

int main(void) {
#ifdef XML3_REFERENCE_TEST
    assert(LIBXML_VERSION == 21504);
    assert(strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) == 0);
#endif
    test_namespace_property_flow();
    test_docless_namespace_lookup();
    test_null_namespace_uri_lookup();
    test_docless_xml_namespace();
    test_standalone_and_parsed_namespaces();
#ifndef XML3_REFERENCE_TEST
    test_rejections();
    test_retained_namespace_lifetimes();
    test_docless_xml_namespace_lifetime();
    test_replace_last_namespace_borrower();
#endif
    puts("Namespace editing tests passed");
    return 0;
}
