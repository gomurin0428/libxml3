#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void assert_content(xmlNodePtr node, const char *expected) {
    xmlChar *content = xmlNodeGetContent(node);
    assert(content != NULL);
    assert(strcmp((const char *)content, expected) == 0);
    xmlFree(content);
}

static void test_element_and_attribute_append(void) {
    static const char input[] = "<root a='v'>left</root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr trailing;
    xmlAttrPtr attr;
    xmlNodePtr attr_text;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    trailing = root->children;
    attr = root->properties;
    attr_text = attr->children;
    assert(xmlNodeAddContent(root, BAD_CAST "é<&") == 0);
    assert(root->children == trailing && root->last == trailing);
    assert_content(root, "lefté<&");
    assert(xmlNodeAddContent((xmlNodePtr)attr, BAD_CAST "x<&") == 0);
    assert(root->properties == attr);
    assert(attr->children == attr_text && attr->last == attr_text);
    assert(strcmp((const char *)attr->children->content, "vx<&") == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "lefté&lt;&amp;") != NULL);
    assert(strstr((const char *)memory, "a=\"vx&lt;&amp;\"") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed), "lefté<&");
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void test_new_child_after_non_text(void) {
    xmlDocPtr doc = xmlReadMemory("<r><!--c--></r>", 15, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr comment;
    xmlNodePtr text;
    xmlAttrPtr attr;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    comment = root->children;
    assert(comment != NULL && comment->type == XML_COMMENT_NODE);
    assert(xmlNodeAddContent(root, BAD_CAST "tail") == 0);
    text = root->last;
    assert(text != comment && text->type == XML_TEXT_NODE);
    assert(root->children == comment && comment->next == text);
    assert_content(text, "tail");
    attr = xmlNewProp(root, BAD_CAST "empty", NULL);
    assert(attr != NULL && attr->children == NULL);
    assert(xmlNodeAddContent((xmlNodePtr)attr, BAD_CAST "value") == 0);
    assert(attr->children != NULL && attr->children == attr->last);
    assert(attr->children->type == XML_TEXT_NODE);
    assert(strcmp((const char *)attr->children->content, "value") == 0);
    xmlFreeDoc(doc);
}

static void test_scalar_nodes_and_aliasing(void) {
    xmlNodePtr text = xmlNewText(BAD_CAST "ab");
    static const char input[] = "<r><![CDATA[c]]></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr cdata;
    xmlNodePtr comment = xmlNewComment(BAD_CAST "note");
    xmlNodePtr pi = xmlNewPI(BAD_CAST "target", BAD_CAST "data");
    xmlNodePtr empty_text = xmlNewText(NULL);

    assert(text != NULL && doc != NULL && comment != NULL && pi != NULL &&
           empty_text != NULL);
    assert(xmlNodeAddContent(text, text->content) == 0);
    assert(strcmp((const char *)text->content, "abab") == 0);
    assert(xmlNodeAddContent(empty_text, BAD_CAST "filled") == 0);
    assert(strcmp((const char *)empty_text->content, "filled") == 0);
    cdata = xmlDocGetRootElement(doc)->children;
    assert(cdata != NULL && cdata->type == XML_CDATA_SECTION_NODE);
    assert(xmlNodeAddContent(cdata, BAD_CAST "d") == 0);
    assert(strcmp((const char *)cdata->content, "cd") == 0);
    assert(xmlNodeAddContent(comment, BAD_CAST " &") == 0);
    assert(strcmp((const char *)comment->content, "note &") == 0);
    assert(xmlNodeAddContent(pi, BAD_CAST " more") == 0);
    assert(strcmp((const char *)pi->content, "data more") == 0);
    assert(xmlNodeAddContent(text, NULL) == 0);
    assert(xmlNodeAddContent(text, BAD_CAST "") == 0);
    assert(strcmp((const char *)text->content, "abab") == 0);
    assert(xmlNodeAddContent(NULL, BAD_CAST "x") == 1);

    xmlFreeNode(text);
    xmlFreeNode(empty_text);
    xmlFreeNode(comment);
    xmlFreeNode(pi);
    xmlFreeDoc(doc);
}

static void test_detached_lifetime(void) {
    xmlDocPtr doc = xmlReadMemory("<r>old</r>", 10, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr text;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    text = root->children;
    xmlUnlinkNode(text);
    xmlFreeDoc(doc);
    assert(xmlNodeAddContent(text, BAD_CAST "-new") == 0);
    assert(strcmp((const char *)text->content, "old-new") == 0);
    xmlFreeNode(text);
}

static void test_set_content(void) {
    static const char input[] =
        "<root xmlns='urn:root' xmlns:p='urn:attribute' p:a='v'>"
        "<x>old</x><!--c--></root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlAttrPtr attr;
    xmlNsPtr root_ns;
    xmlNsPtr attr_ns;
    xmlNodePtr text, cdata, reparsed_root;
    xmlDocPtr reparsed;
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    attr = root->properties;
    root_ns = root->ns;
    attr_ns = attr->ns;
    assert(root_ns != NULL && attr_ns != NULL);
    assert(xmlNodeSetContent(root, BAD_CAST "<&amp; &#x1f600;\r\n\t") == 0);
    assert(root->properties == attr);
    assert(root->ns == root_ns && attr->ns == attr_ns);
    assert(root->children != NULL && root->children->next == NULL);
    assert_content(root, "<& 😀\r\n\t");
    assert(root->children->type == XML_TEXT_NODE);
    assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "a&lt;&#65;") == 0);
    assert(root->properties == attr);
    assert(attr->ns == attr_ns);
    assert_content((xmlNodePtr)attr, "a<A");

    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "&lt;&amp; 😀") != NULL);
    assert(strstr((const char *)memory, "p:a=\"a&lt;A\"") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    reparsed_root = xmlDocGetRootElement(reparsed);
    assert_content(reparsed_root, "<& 😀\r\n\t");
    assert(reparsed_root->ns != NULL &&
           strcmp((const char *)reparsed_root->ns->href, "urn:root") == 0);
    assert(reparsed_root->properties != NULL &&
           reparsed_root->properties->ns != NULL);
    assert_content((xmlNodePtr)reparsed_root->properties, "a<A");
    xmlFreeDoc(reparsed);
    xmlFree(memory);

    assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "") == 0);
    assert(attr->children == NULL);
    assert(xmlNodeSetContent((xmlNodePtr)attr, NULL) == 0);
    assert(attr->children == NULL);

    text = xmlNewText(BAD_CAST "old");
    assert(text != NULL);
    assert(xmlNodeSetContent(text, NULL) == 0 && text->content == NULL);
    assert(xmlNodeSetContent(text, BAD_CAST "") == 0 &&
           text->content != NULL && strcmp((const char *)text->content, "") == 0);
    assert(xmlNodeSetContent(text, BAD_CAST "alias") == 0);
    assert(xmlNodeSetContent(text, text->content) == 0);
    assert(strcmp((const char *)text->content, "alias") == 0);
    xmlFreeNode(text);

    assert(xmlNodeSetContent(root, BAD_CAST "") == 0 && root->children == NULL);
    assert(xmlNodeSetContent(root, NULL) == 0 && root->children == NULL);
    xmlFreeDoc(doc);

    {
        static const char cdata_input[] = "<r><![CDATA[old]]></r>";
        doc = xmlReadMemory(cdata_input, (int)sizeof(cdata_input) - 1,
                            NULL, NULL, 0);
    }
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    cdata = root->children;
    assert(cdata != NULL && cdata->type == XML_CDATA_SECTION_NODE);
    assert(xmlNodeSetContent(cdata, BAD_CAST "raw<&") == 0);
    assert(cdata->type == XML_CDATA_SECTION_NODE);
    assert(strcmp((const char *)cdata->content, "raw<&") == 0);
    xmlFreeDoc(doc);

    text = xmlNewComment(BAD_CAST "old");
    assert(text != NULL);
    assert(xmlNodeSetContent(text, BAD_CAST "raw<&") == 0);
    assert(strcmp((const char *)text->content, "raw<&") == 0);
    xmlFreeNode(text);
    text = xmlNewPI(BAD_CAST "target", BAD_CAST "old");
    assert(text != NULL);
    assert(xmlNodeSetContent(text, BAD_CAST "raw<&") == 0);
    assert(strcmp((const char *)text->content, "raw<&") == 0);
    xmlFreeNode(text);

    doc = xmlNewDoc(NULL);
    assert(doc != NULL);
    assert(xmlNodeSetContent((xmlNodePtr)doc, BAD_CAST "ignored") == 0);
    assert(xmlDocGetRootElement(doc) == NULL);
    xmlFreeDoc(doc);
}

static void test_set_detached_lifetime(void) {
    xmlDocPtr doc = xmlReadMemory("<r>old</r>", 10, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr text;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    text = root->children;
    xmlUnlinkNode(text);
    xmlFreeDoc(doc);
    assert(xmlNodeSetContent(text, BAD_CAST "detached") == 0);
    assert(strcmp((const char *)text->content, "detached") == 0);
    xmlFreeNode(text);
}

#ifndef XML3_REFERENCE_TEST
static void test_set_rejection_is_transactional(void) {
    static const char input[] = "<r><x>old</x><y/></r>";
    static const char *const invalid[] = {
        "&unknown;", "&amp", "&#xZZ;", "&#0;"
    };
    static const char invalid_utf8[] = { (char)0xc0, (char)0xaf, '\0' };
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr first;
    xmlNodePtr last;
    xmlChar *first_content;
    size_t i;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    last = root->last;
    first_content = first->children->content;
    for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        assert(xmlNodeSetContent(root, BAD_CAST invalid[i]) == 1);
        assert(root->children == first && root->last == last);
        assert(first->children->content == first_content);
        assert(strcmp((const char *)first_content, "old") == 0);
    }
    assert(xmlNodeSetContent(root, (const xmlChar *)invalid_utf8) == 1);
    assert(root->children == first && root->last == last);
    assert(first->children->content == first_content);
    xmlFreeDoc(doc);
}

static void test_set_namespace_borrower_lifetime(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr child = xmlNewNode(NULL, BAD_CAST "child");
    xmlNodePtr borrower = xmlNewNode(NULL, BAD_CAST "borrower");
    xmlNsPtr ns;

    assert(doc != NULL && root != NULL && child != NULL && borrower != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, child) == child);
    ns = xmlNewNs(child, BAD_CAST "urn:borrowed", BAD_CAST "p");
    assert(ns != NULL);
    xmlSetNs(borrower, ns);
    assert(borrower->ns == ns);
    assert(xmlNodeSetContent(root, BAD_CAST "replacement") == 0);
    assert(root->children != NULL && root->children == root->last);
    assert(root->children->type == XML_TEXT_NODE);
    assert(borrower->ns == ns);
    assert(strcmp((const char *)ns->href, "urn:borrowed") == 0);
    xmlFreeDoc(doc);
    assert(borrower->ns == ns);
    assert(strcmp((const char *)ns->href, "urn:borrowed") == 0);
    xmlFreeNode(borrower);
}

static void test_invalid_facade_and_document_noop(void) {
    xmlNode invalid = {0};
    xmlDocPtr doc = xmlNewDoc(NULL);

    assert(doc != NULL);
    invalid.type = XML_TEXT_NODE;
    assert(xmlNodeAddContent(&invalid, NULL) == 1);
    assert(xmlNodeAddContent(&invalid, BAD_CAST "x") == 1);
    assert(xmlNodeAddContent((xmlNodePtr)doc, BAD_CAST "ignored") == 0);
    assert(xmlNodeSetContent(&invalid, BAD_CAST "x") == 1);
    assert(xmlNodeSetContent(NULL, BAD_CAST "x") == 1);
    assert(xmlNodeSetContent((xmlNodePtr)doc, BAD_CAST "ignored") == 0);
    assert(xmlDocGetRootElement(doc) == NULL);
    xmlFreeDoc(doc);
}

static void test_invalid_comment_serialization(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr comment = xmlNewComment(BAD_CAST "bad");
    xmlChar *memory = (xmlChar *)1;
    int size = 77;

    assert(doc != NULL && root != NULL && comment != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, comment) == comment);
    assert(xmlNodeAddContent(comment, BAD_CAST "--") == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory == NULL && size == 0);
    xmlFreeDoc(doc);
}
#endif

static void test_construct_child(void) {
    static const char input[] =
        "<p:root xmlns:p='urn:parent' xmlns:q='urn:other'><!--before--></p:root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, first, child, other, empty;
    xmlNsPtr alternate;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    alternate = xmlSearchNs(doc, root, BAD_CAST "q");
    assert(root->ns != NULL && alternate != NULL);
    child = xmlNewChild(root, NULL, BAD_CAST "child",
                        BAD_CAST "<&amp;&#x1F642;\r\n\t");
    assert(child != NULL && child->parent == root && child->doc == doc);
    assert(child->ns == root->ns && child->children->ns == NULL);
    assert(root->children == first && first->next == child);
    assert(child->prev == first && root->last == child && child->next == NULL);
    assert(child->children->parent == child && child->children->doc == doc);
    assert_content(child, "<&🙂\r\n\t");
    other = xmlNewChild(root, alternate, child->name, BAD_CAST "other");
    assert(other != NULL && other->ns == alternate);
    assert(strcmp((const char *)other->name, "child") == 0);
    assert(child->next == other && other->prev == child && root->last == other);
    empty = xmlNewChild(child, NULL, BAD_CAST "empty", NULL);
    assert(empty != NULL && empty->ns == child->ns && empty->children == NULL);
    empty = xmlNewChild(child, NULL, BAD_CAST "empty", BAD_CAST "");
    assert(empty != NULL && empty->children == NULL && child->last == empty);
    assert(xmlNewChild(first, NULL, BAD_CAST "invalid", NULL) == NULL);
    assert(xmlNewChild(root, NULL, NULL, NULL) == NULL);
    assert(xmlNewChild(NULL, NULL, BAD_CAST "invalid", NULL) == NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "<p:child>") != NULL);
    assert(strstr((const char *)memory, "<q:child>other</q:child>") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed)->children->next,
                   "<&🙂\r\n\t");
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    assert(doc != NULL);
    child = xmlNewChild((xmlNodePtr)doc, NULL, BAD_CAST "root", BAD_CAST "text");
    assert(child != NULL && child == xmlDocGetRootElement(doc));
    assert(child->parent == (xmlNodePtr)doc && child->doc == doc);
    assert(child->children->doc == doc);
    xmlFreeDoc(doc);
}

#ifndef XML3_REFERENCE_TEST
static void test_construct_child_failure_and_lifetime(void) {
    static const char input[] = "<p:root xmlns:p='urn:parent'><p:old/></p:root>";
    static const char *const invalid[] = {"&unknown;", "&#0;", "bad &", "\xc3"};
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, old, child;
    xmlNode invalid_node = {0};
    xmlNs invalid_ns = {0};
    xmlNsPtr ns;
    size_t i;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    old = root->children;
    ns = root->ns;
    for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
        assert(xmlNewChild(root, NULL, BAD_CAST "bad", BAD_CAST invalid[i]) == NULL);
        assert(root->children == old && root->last == old && root->ns == ns);
        assert(old->parent == root && old->next == NULL && old->prev == NULL);
    }
    assert(xmlNewChild(&invalid_node, NULL, BAD_CAST "bad", NULL) == NULL);
    assert(xmlNewChild(root, &invalid_ns, BAD_CAST "bad", NULL) == NULL);
    assert(root->children == old && root->last == old);
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    child = xmlNewChild(root, NULL, BAD_CAST "after-release", BAD_CAST "new&amp;text");
    assert(child != NULL && child->parent == root && child->ns == ns);
    assert_content(child, "new&text");
    assert(strcmp((const char *)ns->href, "urn:parent") == 0);
    xmlFreeNode(root);
}
#endif

int main(void) {
    assert(xmlNodeAddContent(NULL, NULL) == 1);
    assert(xmlNodeSetContent(NULL, NULL) == 1);
    test_element_and_attribute_append();
    test_new_child_after_non_text();
    test_scalar_nodes_and_aliasing();
    test_detached_lifetime();
    test_set_content();
    test_set_detached_lifetime();
    test_construct_child();
#ifndef XML3_REFERENCE_TEST
    test_construct_child_failure_and_lifetime();
    test_set_rejection_is_transactional();
    test_set_namespace_borrower_lifetime();
    test_invalid_facade_and_document_noop();
    test_invalid_comment_serialization();
#endif
    puts("content edit tests passed");
    return 0;
}
