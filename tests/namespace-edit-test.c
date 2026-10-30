#define _GNU_SOURCE
#include <libxml/parser.h>
#include <libxml/tree.h>
#ifdef XML3_REFERENCE_TEST
#include <libxml/xmlversion.h>
#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static void namespace_field_is(const xmlChar *value, const char *expected) {
    assert((value == NULL) == (expected == NULL));
    if (expected) assert(strcmp((const char *)value, expected) == 0);
}

static void test_namespace_input(void) {
    static const char *hrefs[] = {"urn:guard", "", NULL};
    static const char *prefixes[] = {"p\xc3\xa9", "", NULL};
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 4, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    assert(mprotect(mapping + page * 3, (size_t)page, PROT_NONE) == 0);
    for (size_t i = 0; i < sizeof(hrefs) / sizeof(hrefs[0]); ++i) {
        for (size_t j = 0; j < sizeof(prefixes) / sizeof(prefixes[0]); ++j) {
            char *href = NULL, *prefix = NULL;
            if (hrefs[i]) {
                size_t bytes = strlen(hrefs[i]) + 1;
                href = mapping + page - bytes;
                memcpy(href, hrefs[i], bytes);
            }
            if (prefixes[j]) {
                size_t bytes = strlen(prefixes[j]) + 1;
                prefix = mapping + page * 3 - bytes;
                memcpy(prefix, prefixes[j], bytes);
            }
            xmlNsPtr source = xmlNewNs(NULL, BAD_CAST href, BAD_CAST prefix);
            assert(source);
            assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
            assert(mprotect(mapping + page * 2, (size_t)page, PROT_NONE) == 0);
            namespace_field_is(source->href, hrefs[i]);
            namespace_field_is(source->prefix, prefixes[j]);
            xmlDocPtr doc = xmlNewDoc(NULL);
            xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
            assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
            xmlNsPtr ns = xmlNewNs(root, source->href, source->prefix);
            assert(ns && root->nsDef == ns && ns->next == NULL);
            xmlFreeNs(source);
            namespace_field_is(ns->href, hrefs[i]);
            namespace_field_is(ns->prefix, prefixes[j]);
            if (hrefs[i]) {
                assert(xmlNewNs(root, ns->href, ns->prefix) == NULL);
                assert(root->nsDef == ns && ns->next == NULL);
            }
            if (i == 0 && j != 1) {
                xmlSetNs(root, ns);
                assert(xmlNewTextChild(root, ns, BAD_CAST "c", BAD_CAST "kept"));
                xmlChar *output = NULL;
                int length = 0;
                xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
                assert(output && length > 0);
                xmlFreeDoc(doc);
                doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
                assert(doc);
                root = xmlDocGetRootElement(doc);
                assert(root->ns && root->children && root->children->ns);
                namespace_field_is(root->ns->href, hrefs[i]);
                namespace_field_is(root->ns->prefix, prefixes[j]);
                assert(xmlNodeSetContent(root->children, BAD_CAST "edited") == 0);
                xmlChar *value = xmlNodeGetContent(root->children);
                assert(value && strcmp((const char *)value, "edited") == 0);
                xmlFree(value);
                xmlFree(output);
            }
            xmlFreeDoc(doc);
            assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
            assert(mprotect(mapping + page * 2, (size_t)page,
                            PROT_READ | PROT_WRITE) == 0);
        }
    }
#ifndef XML3_REFERENCE_TEST
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr text = xmlNewText(BAD_CAST "kept");
    assert(doc && text);
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    xmlNodePtr invalid[] = {(xmlNodePtr)protected, (xmlNodePtr)doc, text};
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        xmlResetLastError();
        assert(xmlNewNs(invalid[i], protected, protected) == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    }
    assert(doc->children == NULL && strcmp((const char *)text->content, "kept") == 0);
    xmlFreeNode(text);
    xmlFreeDoc(doc);
#endif
    xmlResetLastError();
    assert(munmap(mapping, (size_t)page * 4) == 0);
}

static void test_namespace_search_input(void) {
    static const char document[] =
        "<r xmlns='urn:d' xmlns:p='urn:p'><c xmlns:p='urn:q' a='v'>kept</c></r>";
    static const char xml_uri[] = "http://www.w3.org/XML/1998/namespace";
    static const struct { int by_href; const char *query, *expected; } cases[] = {
        {0, "p", "urn:q"}, {0, NULL, "urn:d"}, {0, "", NULL},
        {0, "missing", NULL}, {0, "xml", xml_uri},
        {1, "urn:q", "urn:q"}, {1, "urn:p", NULL}, {1, "urn:d", "urn:d"},
        {1, NULL, NULL}, {1, "", NULL}, {1, xml_uri, xml_uri}
    };
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 64);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    xmlDocPtr ignored_doc = (xmlDocPtr)(mapping + page);
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        xmlNsPtr (*lookup)(xmlDocPtr, xmlNodePtr, const xmlChar *) =
            cases[i].by_href ? xmlSearchNsByHref : xmlSearchNs;
        char *input = NULL;
        if (cases[i].query) {
            size_t bytes = strlen(cases[i].query) + 1;
            input = mapping + page - bytes;
            memcpy(input, cases[i].query, bytes);
        }
        xmlDocPtr doc = xmlReadMemory(document, (int)strlen(document), NULL, NULL, 0);
        assert(doc);
        xmlNodePtr child = xmlDocGetRootElement(doc)->children;
        assert(child && child->children);
        xmlResetLastError();
        xmlNsPtr found = lookup(ignored_doc, child->children, BAD_CAST input);
        assert(xmlGetLastError() == NULL);
        assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
        assert((found != NULL) == (cases[i].expected != NULL));
        if (found) {
            namespace_field_is(found->href, cases[i].expected);
            assert(lookup(ignored_doc, child->children,
                          cases[i].by_href ? found->href : found->prefix) == found);
            if (strcmp(cases[i].expected, xml_uri) != 0) xmlSetNs(child, found);
        }
        xmlChar *output = NULL;
        int length = 0;
        xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
        assert(output && length > 0);
        xmlFreeDoc(doc);
        doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
        assert(doc);
        child = xmlDocGetRootElement(doc)->children;
        if (cases[i].expected && strcmp(cases[i].expected, xml_uri) != 0) {
            assert(child->ns);
            namespace_field_is(child->ns->href, cases[i].expected);
        }
        assert(xmlNodeSetContent(child, BAD_CAST "edited") == 0);
        xmlChar *value = xmlNodeGetContent(child);
        assert(value && strcmp((const char *)value, "edited") == 0);
        xmlFree(value);
        xmlFree(output);
        xmlFreeDoc(doc);
        assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
    }
    for (int by_href = 0; by_href < 2; ++by_href) {
        xmlNsPtr (*lookup)(xmlDocPtr, xmlNodePtr, const xmlChar *) =
            by_href ? xmlSearchNsByHref : xmlSearchNs;
        const char *query = by_href ? xml_uri : "xml";
        size_t bytes = strlen(query) + 1;
        char *input = mapping + page - bytes;
        memcpy(input, query, bytes);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        assert(root);
        xmlNodePtr child = xmlNewTextChild(root, NULL, BAD_CAST "c", BAD_CAST "kept");
        assert(child);
        xmlNsPtr found = lookup(ignored_doc, child->children, BAD_CAST input);
        assert(found);
        assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
        namespace_field_is(found->href, xml_uri);
        namespace_field_is(found->prefix, "xml");
        assert(lookup(ignored_doc, child->children, BAD_CAST query) == found);
        xmlFreeNode(root);
#ifndef XML3_REFERENCE_TEST
        const xmlChar *protected = (const xmlChar *)(mapping + page);
        xmlResetLastError();
        assert(lookup(ignored_doc, NULL, protected) == NULL);
        assert(xmlGetLastError() == NULL);
        assert(lookup(ignored_doc, (xmlNodePtr)protected, protected) == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        xmlResetLastError();
#endif
        assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
    }
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

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

static void test_namespace_copies(void) {
    static const struct { const char *href, *prefix; } cases[] = {
        {"urn:p", "p"}, {"urn:default", NULL}, {"", "p"},
        {NULL, "p"}, {NULL, NULL}, {"", ""}, {"urn:名", "名"}
    };
    int marker = 42;
    assert(!xmlCopyNamespace(NULL));
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        xmlNsPtr source = xmlNewNs(NULL, BAD_CAST cases[i].href, BAD_CAST cases[i].prefix);
        assert(source);
        source->_private = &marker;
        xmlNsPtr copy = xmlCopyNamespace(source);
        assert(copy && copy != source && !copy->next && !copy->_private);
#ifndef XML3_REFERENCE_TEST
        assert(!copy->context);
#endif
        assert(copy->type == XML_NAMESPACE_DECL && source->_private == &marker);
        if (cases[i].href) assert(copy->href && copy->href != source->href);
        else assert(!copy->href);
        if (cases[i].prefix) assert(copy->prefix && copy->prefix != source->prefix);
        else assert(!copy->prefix);
        xmlFreeNs(source);
        if (cases[i].href) assert(xmlStrEqual(copy->href, BAD_CAST cases[i].href));
        if (cases[i].prefix) assert(xmlStrEqual(copy->prefix, BAD_CAST cases[i].prefix));
        xmlFreeNs(copy);
    }
    {
        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc && root);
        xmlDocSetRootElement(doc, root);
        xmlNsPtr source = xmlNewNs(root, BAD_CAST "urn:p", BAD_CAST "p");
        xmlNsPtr next = xmlNewNs(root, BAD_CAST "urn:q", BAD_CAST "q");
        xmlNsPtr copy = xmlCopyNamespace(source);
        assert(source && next && copy && !copy->next);
#ifndef XML3_REFERENCE_TEST
        assert(!copy->context);
#endif
        assert(root->nsDef == source && source->next == next && !next->next);
        xmlNodePtr child = xmlNewNode(copy, BAD_CAST "child");
        assert(child && xmlAddChild(root, child) == child && child->ns == copy);
        xmlNodeSetContent(child, BAD_CAST "value");
        xmlChar *bytes = NULL;
        int size = -1;
        xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
        assert(bytes && size > 0);
        xmlDocPtr parsed = xmlReadMemory((const char *)bytes, size, NULL, NULL, 0);
        assert(parsed);
        xmlNodePtr parsed_child = xmlFirstElementChild(xmlDocGetRootElement(parsed));
        assert(parsed_child && parsed_child->ns && xmlStrEqual(parsed_child->ns->href, BAD_CAST "urn:p"));
        value_is(parsed_child, "value");
        xmlFreeDoc(parsed);
        xmlFree(bytes);
#ifndef XML3_REFERENCE_TEST
        xmlUnlinkNode(child);
        xmlFreeDoc(doc);
        xmlFreeNs(copy);
        value_is(child, "value");
        assert(xmlStrEqual(child->ns->href, BAD_CAST "urn:p"));
        xmlNsPtr second_copy = xmlCopyNamespace(child->ns);
        assert(second_copy && second_copy != child->ns);
        xmlFreeNode(child);
        assert(xmlStrEqual(second_copy->href, BAD_CAST "urn:p"));
        xmlFreeNs(second_copy);
#else
        xmlFreeDoc(doc);
        assert(xmlStrEqual(copy->href, BAD_CAST "urn:p"));
        xmlFreeNs(copy);
#endif
    }
}

static void check_ns_list(xmlNodePtr node, xmlNsPtr *expected, size_t count) {
    xmlNsPtr *list = (xmlNsPtr *)1;
    assert(xmlGetNsListSafe(NULL, node, &list) == (count ? 0 : 1));
    if (count) {
        assert(list);
        for (size_t i = 0; i < count; ++i) assert(list[i] == expected[i]);
        assert(list[count] == NULL);
    } else {
        assert(list == NULL);
    }
    xmlFree(list);
    list = xmlGetNsList(NULL, node);
    if (count) {
        assert(list);
        for (size_t i = 0; i < count; ++i) assert(list[i] == expected[i]);
        assert(list[count] == NULL);
    } else {
        assert(list == NULL);
    }
    xmlFree(list);
}

static void test_namespace_lists(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    assert(doc && root);
    xmlDocSetRootElement(doc, root);
    xmlNsPtr p = xmlNewNs(root, BAD_CAST "urn:parent", BAD_CAST "p");
    xmlNsPtr d = xmlNewNs(root, BAD_CAST "urn:default", NULL);
    xmlNsPtr q = xmlNewNs(root, BAD_CAST "urn:q", BAD_CAST "q");
    xmlNodePtr child = xmlNewChild(root, NULL, BAD_CAST "child", NULL);
    assert(p && d && q && child);
    xmlNsPtr shadow = xmlNewNs(child, BAD_CAST "urn:child", BAD_CAST "p");
    xmlNsPtr empty = xmlNewNs(child, BAD_CAST "", NULL);
    xmlNsPtr null_href = xmlNewNs(child, NULL, BAD_CAST "n");
    assert(shadow && empty && null_href);
    xmlNsPtr expected[] = {shadow, empty, null_href, q};
    check_ns_list(child, expected, 4);
    xmlNodePtr text = xmlNewText(BAD_CAST "value");
    assert(text && xmlAddChild(child, text));
    xmlAttrPtr attr = xmlNewProp(child, BAD_CAST "id", BAD_CAST "1");
    assert(attr);
    check_ns_list(text, expected, 4);
    check_ns_list((xmlNodePtr)attr, expected, 4);
    assert(child->nsDef == shadow && shadow->next == empty);
    check_ns_list(NULL, NULL, 0);
    check_ns_list((xmlNodePtr)doc, NULL, 0);
    assert(xmlGetNsListSafe(doc, child, NULL) == 1);
    xmlNodePtr standalone = xmlNewNode(q, BAD_CAST "standalone");
    assert(standalone);
    check_ns_list(standalone, NULL, 0);
    xmlFreeNode(standalone);
    xmlUnlinkNode(child);
    check_ns_list(child, expected, 3);
    assert(xmlAddChild(root, child) == child);
    check_ns_list(child, expected, 4);
    xmlUnlinkNode(child);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
    check_ns_list(child, expected, 3);
    xmlFreeNode(child);
#else
    xmlFreeNode(child);
    xmlFreeDoc(doc);
#endif
}

int main(void) {
    test_namespace_search_input();
    test_namespace_input();
    test_namespace_copies();
    test_namespace_lists();
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
