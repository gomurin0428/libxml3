#include <libxml3.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

static void value_is(xmlChar *value, const char *expected) {
    assert(value && strcmp((const char *)value, expected) == 0);
    xmlFree(value);
}

static void test_scopes_and_attributes(void) {
    char input[] = "<p:r id='plain' p:id='one' q:id='two' xmlns='urn:default' "
        "xmlns:p='urn:one' xmlns:q='urn:two'><p:c xmlns:p='urn:two'>"
        "<d xmlns=''/></p:c><p:after/></p:r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    assert(doc);
    memset(input, 'x', strlen(input));
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(xmlStrEqual(root->name, BAD_CAST "r"));
    assert(root->ns && xmlStrEqual(root->ns->prefix, BAD_CAST "p"));
    assert(xmlStrEqual(root->ns->href, BAD_CAST "urn:one"));
    assert(root->nsDef && !root->nsDef->prefix);
    assert(root->nsDef->type == XML_NAMESPACE_DECL);
    assert(root->nsDef->next == root->ns);
    assert(xmlHasProp(root, BAD_CAST "xmlns") == NULL);
    assert(xmlHasProp(root, BAD_CAST "xmlns:p") == NULL);
    value_is(xmlGetProp(root, BAD_CAST "id"), "plain");
    value_is(xmlGetNoNsProp(root, BAD_CAST "id"), "plain");
    value_is(xmlGetNsProp(root, BAD_CAST "id", NULL), "plain");
    value_is(xmlGetNsProp(root, BAD_CAST "id", BAD_CAST "urn:one"), "one");
    value_is(xmlGetNsProp(root, BAD_CAST "id", BAD_CAST "urn:two"), "two");
    assert(!xmlGetNsProp(root, BAD_CAST "id", BAD_CAST ""));
    assert(!xmlHasNsProp(root, BAD_CAST "id", BAD_CAST "urn:missing"));
    xmlAttrPtr attr = xmlHasNsProp(root, BAD_CAST "id", BAD_CAST "urn:one");
    assert(attr && attr->ns == root->ns);
    assert(xmlSearchNs(doc, (xmlNodePtr)attr, BAD_CAST "p") == root->ns);
    assert(!xmlSearchNsByHref(doc, (xmlNodePtr)attr, BAD_CAST "urn:default"));

    xmlNodePtr child = xmlFirstElementChild(root);
    xmlNodePtr after = xmlNextElementSibling(child);
    assert(child->ns == child->nsDef && child->ns != root->ns);
    assert(xmlStrEqual(child->ns->href, BAD_CAST "urn:two"));
    assert(after->ns == root->ns);
    assert(xmlSearchNs(doc, child, BAD_CAST "p") == child->ns);
    assert(!xmlSearchNsByHref(doc, child, BAD_CAST "urn:one"));
    assert(xmlSearchNsByHref(doc, child, BAD_CAST "urn:two") == child->ns);
    xmlNodePtr reset = xmlFirstElementChild(child);
    assert(!reset->ns && reset->nsDef && reset->nsDef->href[0] == 0);
    assert(xmlSearchNs(doc, reset, NULL) == reset->nsDef);
    assert(!xmlSearchNsByHref(doc, reset, BAD_CAST "urn:default"));

    /* Freeing the document must not follow caller-editable namespace links. */
    root->nsDef->next = root->nsDef;
    root->nsDef = NULL;
    xmlFreeDoc(doc);
}

static void test_reserved_and_normalized_bindings(void) {
    const char input[] = "<r xmlns:xml='http://www.w3.org/XML/1998/namespace' "
        "xmlns:p='urn:a&amp;b' xml:lang='en' p:id='yes'><xml:c/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root->nsDef && xmlStrEqual(root->nsDef->prefix, BAD_CAST "p"));
    assert(!root->nsDef->next);
    xmlNsPtr ns = xmlSearchNs(doc, root, BAD_CAST "xml");
    assert(ns && ns->type == XML_NAMESPACE_DECL);
    assert(xmlStrEqual(ns->href, XML_XML_NAMESPACE));
    assert(xmlFirstElementChild(root)->ns == ns);
    assert(xmlSearchNsByHref(doc, root, XML_XML_NAMESPACE) == ns);
    value_is(xmlGetNsProp(root, BAD_CAST "lang", XML_XML_NAMESPACE), "en");
    value_is(xmlGetNsProp(root, BAD_CAST "id", BAD_CAST "urn:a&b"), "yes");
    xmlFreeDoc(doc);
}

static void test_rejection(void) {
    const char *const invalid[] = {
        "<p:r/>", "<r p:x='a'/>", "<a:b:c/>", "<a:/>", "<:a/>",
        "<r xmlns:p=''/>", "<r xmlns:xml='urn:wrong'/>",
        "<r xmlns:xmlns='urn:wrong'/>",
        "<r xmlns='http://www.w3.org/XML/1998/namespace'/>",
        "<r xmlns:p='http://www.w3.org/XML/1998/namespace'/>",
        "<r xmlns:p='http://www.w3.org/2000/xmlns/'/>",
        "<r xmlns:p='urn:x' xmlns:q='urn:&#120;' p:a='1' q:a='2'/>",
        "<r><x xmlns:p='urn:x'/><p:y/></r>"
    };
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        int status = -1;
        xmlDocPtr doc = xml3ReadMemory(invalid[i], (int)strlen(invalid[i]), &status);
        assert(!doc && status == XML3_STATUS_MALFORMED);
    }
    assert(!xmlSearchNs(NULL, NULL, NULL));
    assert(!xmlSearchNsByHref(NULL, NULL, NULL));
    assert(!xmlHasNsProp(NULL, BAD_CAST "x", NULL));
    assert(!xmlGetNsProp(NULL, BAD_CAST "x", NULL));
    assert(!xmlGetNoNsProp(NULL, BAD_CAST "x"));
}

int main(void) {
    test_scopes_and_attributes();
    test_reserved_and_normalized_bindings();
    test_rejection();
    puts("namespace API tests passed");
}
