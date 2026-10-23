#include <libxml/parser.h>
#include <libxml/tree.h>
#ifdef XML3_REFERENCE_TEST
#include <libxml/xmlversion.h>
#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>

#ifdef XML3_REFERENCE_TEST
static void check_reference_version(void) {
    assert(LIBXML_VERSION == 21504);
    assert(xmlParserVersion != NULL);
    assert(strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) == 0);
}
#else
static void check_reference_version(void) {}
#endif

static void assert_value(xmlAttrPtr attr, const char *value) {
    xmlChar *content;
    assert(attr != NULL && attr->type == XML_ATTRIBUTE_NODE);
    content = xmlNodeGetContent((xmlNodePtr)attr);
    assert(content != NULL && strcmp((const char *)content, value) == 0);
    xmlFree(content);
    if (attr->children != NULL) {
        assert(attr->children == attr->last);
        assert(attr->children->type == XML_TEXT_NODE);
        assert(attr->children->parent == (xmlNodePtr)attr);
        assert(attr->children->doc == attr->doc);
        assert(attr->children->next == NULL && attr->children->prev == NULL);
    }
}

static void test_edit_flow(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlAttrPtr first, duplicate, last, created;
    char name[] = "mode";
    char value[] = "raw &amp; &#65; &missing; < > \" '\t\n";
    assert(doc != NULL && root != NULL);
    first = xmlNewProp(root, BAD_CAST name, BAD_CAST value);
    assert(first != NULL && first->doc == NULL && first->parent == root);
    name[0] = 'X';
    value[0] = 'X';
    assert(strcmp((const char *)first->name, "mode") == 0);
    assert_value(first, "raw &amp; &#65; &missing; < > \" '\t\n");
    duplicate = xmlNewProp(root, BAD_CAST "mode", BAD_CAST "duplicate");
    last = xmlNewProp(root, BAD_CAST "last", NULL);
    assert(duplicate != NULL && last != NULL);
    assert(root->properties == first && first->prev == NULL);
    assert(first->next == duplicate && duplicate->prev == first);
    assert(duplicate->next == last && last->prev == duplicate);
    assert(last->next == NULL && last->children == NULL && last->last == NULL);
    assert_value(last, "");

    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(first->doc == doc && duplicate->doc == doc && last->doc == doc);
    assert_value(first, "raw &amp; &#65; &missing; < > \" '\t\n");
    first->_private = &name;
    assert(xmlSetProp(root, BAD_CAST "mode", BAD_CAST "updated") == first);
    assert(first->_private == &name && first->next == duplicate);
    assert_value(first, "updated");
    assert_value(duplicate, "duplicate");
    assert(xmlSetProp(root, BAD_CAST "mode", first->children->content + 2) == first);
    assert_value(first, "dated");
    assert(xmlSetProp(root, BAD_CAST "mode", NULL) == first);
    assert(first->children == NULL && first->last == NULL);
    assert_value(first, "");
    assert(xmlSetProp(root, BAD_CAST "mode", BAD_CAST "") == first);
    assert(first->children != NULL);
    assert_value(first, "");
    created = xmlSetProp(root, BAD_CAST "added", BAD_CAST "値 &amp;");
    assert(created != NULL && last->next == created && created->prev == last);
    assert_value(created, "値 &amp;");

    assert(xmlRemoveProp(duplicate) == 0);
    assert(first->next == last && last->prev == first);
    assert(xmlUnsetProp(root, BAD_CAST "mode") == 0);
    assert(root->properties == last && last->prev == NULL);
    assert(xmlUnsetProp(root, BAD_CAST "absent") == -1);
    assert(xmlRemoveProp(created) == 0 && last->next == NULL);
    assert(xmlRemoveProp(last) == 0 && root->properties == NULL);
    xmlFreeDoc(doc);
}

static void test_parsed_attributes(void) {
    static const char input[] =
        "<root xmlns:p='urn:attrs' p:a='namespaced' a='old &amp; value' b='b'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlAttrPtr namespaced, plain;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    namespaced = root->properties;
    plain = namespaced->next;
    assert(namespaced->ns != NULL && plain->ns == NULL);
    assert_value(plain, "old & value");
    assert(xmlSetProp(root, BAD_CAST "a", BAD_CAST "&amp; &#65;") == plain);
    assert_value(plain, "&amp; &#65;");
    assert_value(namespaced, "namespaced");
    assert(xmlUnsetProp(root, BAD_CAST "a") == 0);
    assert(root->properties == namespaced && namespaced->next->prev == namespaced);
    assert(xmlUnsetProp(root, BAD_CAST "a") == -1);
    plain = xmlSetProp(root, BAD_CAST "a", BAD_CAST "new");
    assert(plain != NULL && plain->ns == NULL && plain->doc == doc);
    assert_value(namespaced, "namespaced");
    xmlFreeDoc(doc);
}

static void test_standalone_attributes(void) {
    xmlAttrPtr attr = xmlNewProp(NULL, BAD_CAST "standalone", BAD_CAST "value");
    assert(attr != NULL && attr->parent == NULL && attr->doc == NULL);
    assert_value(attr, "value");
    assert(xmlRemoveProp(attr) == -1);
    assert_value(attr, "value");
    xmlFreeProp(attr);
    xmlFreeProp(NULL);
    xmlResetLastError();
}

#ifndef XML3_REFERENCE_TEST
static void assert_tree_error(void) {
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    xmlResetLastError();
}

static void test_rejections_and_safe_free(void) {
    static const char input[] = "<r xmlns:p='urn:attrs' p:a='keep' a='remove'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlAttrPtr namespaced, plain;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    namespaced = root->properties;
    plain = namespaced->next;
    assert(xmlSetProp(root, BAD_CAST "missing:a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlNewProp(root, BAD_CAST "p:b", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlUnsetProp(root, BAD_CAST "p:a") == -1);
    assert_tree_error();
    assert(xmlNewProp(root, NULL, BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlSetProp(NULL, BAD_CAST "a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlNewProp((xmlNodePtr)doc, BAD_CAST "a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlNewProp((xmlNodePtr)root->nsDef, BAD_CAST "a", NULL) == NULL);
    assert_tree_error();
    xmlFreeProp((xmlAttrPtr)root->nsDef);
    assert_tree_error();
    xmlFreeProp((xmlAttrPtr)root);
    assert_tree_error();
    assert(root->properties == namespaced && namespaced->next == plain);
    assert_value(namespaced, "keep");
    assert_value(plain, "remove");
    xmlFreeProp(plain);
    assert(namespaced->next == NULL && root->properties == namespaced);
    xmlFreeDoc(doc);
}

static void test_detached_lifetime_and_errors(void) {
    static const char input[] = "<r><item a='old'/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr item, text;
    xmlAttrPtr attr;
    int code;
    assert(doc != NULL);
    item = xmlDocGetRootElement(doc)->children;
    xmlUnlinkNode(item);
    xmlFreeDoc(doc);
    attr = item->properties;
    assert(xmlSetProp(item, BAD_CAST "a", BAD_CAST "survives") == attr);
    text = attr->children;
    xmlUnlinkNode(text);
    assert(xmlRemoveProp(attr) == 0 && item->properties == NULL);
    xmlFreeNode(item);
    assert(strcmp((const char *)text->content, "survives") == 0);
    xmlFreeNode(text);

    assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
    code = xmlGetLastError()->code;
    item = xmlNewNode(NULL, BAD_CAST "item");
    assert(item != NULL);
    attr = xmlNewProp(item, BAD_CAST "a", BAD_CAST "v");
    assert(attr != NULL && xmlGetLastError()->code == code);
    assert(xmlSetProp(item, BAD_CAST "a", BAD_CAST "w") == attr);
    assert(xmlGetLastError()->code == code);
    assert(xmlUnsetProp(item, BAD_CAST "absent") == -1);
    assert(xmlGetLastError()->code == code);
    assert(xmlRemoveProp(attr) == 0 && xmlGetLastError()->code == code);
    xmlFreeNode(item);
    xmlResetLastError();
}
#endif

int main(void) {
    check_reference_version();
    test_edit_flow();
    test_parsed_attributes();
    test_standalone_attributes();
#ifndef XML3_REFERENCE_TEST
    test_rejections_and_safe_free();
    test_detached_lifetime_and_errors();
#endif
    puts("Attribute editing tests passed");
    return 0;
}
