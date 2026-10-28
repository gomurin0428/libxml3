#define _GNU_SOURCE
#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>
#if defined(__unix__)
#include <sys/mman.h>
#include <unistd.h>
#endif

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

static void test_document_text(void) {
    static const xmlChar raw[] = {'<', 'B', 'X'};
    const int null_lengths[] = {-1, 0, 3};
    xmlDocPtr doc = xmlNewDoc(NULL), reparsed;
    xmlNodePtr text, bounded, orphan, root;
    xmlChar *memory = NULL;
    int size = 0;
    size_t i;
    assert(doc != NULL);
    text = xmlNewDocText(NULL, BAD_CAST "standalone");
    assert(text != NULL && text->doc == NULL);
    assert_content(text, "standalone");
    xmlFreeNode(text);
    bounded = xmlNewDocTextLen(NULL, raw, 2);
    assert(bounded != NULL && bounded->doc == NULL);
    assert_content(bounded, "<B");
    xmlFreeNode(bounded);
    for (i = 0; i < sizeof(null_lengths) / sizeof(null_lengths[0]); ++i) {
        text = xmlNewDocTextLen(doc, NULL, null_lengths[i]);
        assert(text != NULL && text->content == NULL && text->doc == doc);
        assert(text->parent == NULL && doc->children == NULL);
        xmlFreeNode(text);
    }
    assert(xmlNewDocTextLen(doc, raw, -1) == NULL);
    text = xmlNewDocText(doc, BAD_CAST "A&");
    bounded = xmlNewDocTextLen(doc, raw, 2);
    orphan = xmlNewDocText(doc, BAD_CAST "orphan");
    assert(text != NULL && bounded != NULL && orphan != NULL);
    assert(text->doc == doc && bounded->doc == doc && orphan->doc == doc);
    assert(text->parent == NULL && text->next == NULL && text->prev == NULL);
    assert(doc->children == NULL && doc->last == NULL);
    root = xmlNewNode(NULL, BAD_CAST "root");
    assert(root != NULL && xmlDocSetRootElement(doc, root) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlNewDocText((xmlDocPtr)root, BAD_CAST "bad") == NULL);
    assert(xmlNewDocTextLen((xmlDocPtr)root, NULL, 0) == NULL);
#endif
    assert(xmlAddChild(root, text) == text);
    assert(xmlAddChild(root, bounded) == text);
    assert(root->children == text && root->last == text);
    assert_content(root, "A&<B");
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed), "A&<B");
    xmlFree(memory);
    xmlFreeDoc(reparsed);
#ifndef XML3_REFERENCE_TEST
    xmlUnlinkNode(text);
    xmlFreeDoc(doc);
    assert(text->doc == doc && orphan->doc == doc);
    assert(xmlNodeAddContent(text, BAD_CAST "!") == 0);
    assert_content(text, "A&<B!");
    assert(xmlNodeSetContent(orphan, BAD_CAST "repaired") == 0);
    xmlFreeNode(text);
    assert_content(orphan, "repaired");
    xmlFreeNode(orphan);
#else
    xmlFreeNode(orphan);
    xmlFreeDoc(doc);
#endif
}

static void test_new_text_len(void) {
    static const xmlChar raw[] = {'A', '&', '<', 'X'};
    static const xmlChar terminated[] = {'z', 0, 'x'};
    const int null_lengths[] = {-1, 0, 3};
    xmlNodePtr text, root;
    xmlDocPtr doc, reparsed;
    xmlChar *memory = NULL;
    int size = 0;
    size_t i;
    for (i = 0; i < sizeof(null_lengths) / sizeof(null_lengths[0]); ++i) {
        text = xmlNewTextLen(NULL, null_lengths[i]);
        assert(text != NULL && text->content == NULL);
        assert(text->type == XML_TEXT_NODE && text->doc == NULL);
        xmlFreeNode(text);
    }
    assert(xmlNewTextLen(raw, -1) == NULL);
    text = xmlNewTextLen(raw, 0);
    assert(text != NULL && text->content != NULL && text->content[0] == 0);
    xmlFreeNode(text);
    text = xmlNewTextLen(terminated, 3);
    assert(text != NULL);
    assert_content(text, "z");
    assert(xmlNodeAddContentLen(text, raw, 3) == 0);
    assert_content(text, "zA&<");
    xmlFreeNode(text);
    text = xmlNewTextLen(raw, 3);
    assert(text != NULL && text->parent == NULL && text->doc == NULL);
    assert_content(text, "A&<");
    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "root");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, text) == text);
    assert(text->doc == doc && text->parent == root);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "A&amp;&lt;") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed), "A&<");
    xmlFree(memory);
    xmlFreeDoc(reparsed);
#ifndef XML3_REFERENCE_TEST
    xmlUnlinkNode(text);
    xmlFreeDoc(doc);
    assert(xmlNodeAddContentLen(text, BAD_CAST "!ignored", 1) == 0);
    assert_content(text, "A&<!");
    xmlFreeNode(text);
#else
    xmlFreeDoc(doc);
#endif
}

static void test_add_content_len(void) {
    static const xmlChar raw[] = {'A', '&', 'a', 'm', 'p', ';', 'B', 'X'};
    static const xmlChar empty[] = {0, 'x'};
    static const xmlChar terminated[] = {'z', 0, 'x'};
    static const xmlChar utf8[] = {0xc3, 0xa9};
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr text = xmlNewText(NULL);
    xmlNodePtr child;
    xmlAttrPtr attr;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;
    assert(doc != NULL && root != NULL && text != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    attr = xmlNewProp(root, BAD_CAST "a", NULL);
    assert(attr != NULL);
    assert(xmlNodeAddContentLen(root, raw, 0) == 0 && root->children == NULL);
    assert(xmlNodeAddContentLen(root, raw, -7) == 0 && root->children == NULL);
    assert(xmlNodeAddContentLen(root, NULL, 7) == 0 && root->children == NULL);
    assert(xmlNodeAddContentLen(root, empty, 1) == 0);
    child = root->children;
    assert(child != NULL && child == root->last && child->type == XML_TEXT_NODE);
    assert(child->content != NULL && child->content[0] == 0);
    assert(xmlNodeAddContentLen((xmlNodePtr)attr, empty, 1) == 0);
    assert(attr->children != NULL && attr->children->content != NULL);
    assert(attr->children->content[0] == 0);
    assert(xmlNodeAddContentLen(text, empty, 1) == 0);
    assert(text->content != NULL && text->content[0] == 0);
    assert(xmlNodeAddContentLen(root, raw, 7) == 0);
    assert(root->children == child && root->last == child);
    assert_content(root, "A&amp;B");
    assert(xmlNodeAddContentLen((xmlNodePtr)attr, raw, 7) == 0);
    assert_content((xmlNodePtr)attr, "A&amp;B");
    assert(xmlNodeAddContentLen(text, raw, 7) == 0);
    assert(xmlNodeAddContentLen(text, text->content + 1, 5) == 0);
    assert_content(text, "A&amp;B&amp;");
    assert(xmlNodeAddContentLen(text, terminated, 3) == 0);
    assert_content(text, "A&amp;B&amp;z");
    assert(xmlNodeAddContentLen(root, utf8, 1) == 0);
#ifndef XML3_REFERENCE_TEST
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory == NULL && size == 0);
#endif
    assert(xmlNodeAddContentLen(root, utf8 + 1, 1) == 0);
    assert_content(root, "A&amp;Bé");
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "A&amp;amp;B") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed), "A&amp;Bé");
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    assert(xmlNodeAddContentLen(NULL, raw, 3) == 1);
    xmlFreeNode(text);
    xmlFreeDoc(doc);
}

static void test_set_content_len(void) {
    static const xmlChar reference[] = {'A', '&', 'a', 'm', 'p', ';', 'B', 'X'};
    static const xmlChar terminated[] = {'a', 0, 'z'};
    static const xmlChar raw[] = {'a', 'b', 'c', 'X'};
    xmlNodePtr element = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr text = xmlNewText(BAD_CAST "old");
    xmlAttrPtr attr;
    assert(element != NULL && text != NULL);
    attr = xmlNewProp(element, BAD_CAST "a", BAD_CAST "old");
    assert(attr != NULL);
    assert(xmlNodeSetContentLen(element, reference, 7) == 0);
    assert_content(element, "A&B");
    assert(xmlNodeSetContentLen((xmlNodePtr)attr, reference, 7) == 0);
    assert_content((xmlNodePtr)attr, "A&B");
    assert(xmlNodeSetContentLen(text, raw, 3) == 0);
    assert_content(text, "abc");
    assert(xmlNodeSetContentLen(text, text->content + 1, 2) == 0);
    assert_content(text, "bc");
    assert(xmlNodeSetContentLen(text, terminated, 3) == 0);
    assert_content(text, "a");
    assert(xmlNodeAddContent(text, BAD_CAST "&") == 0);
    assert_content(text, "a&");
    assert(xmlNodeSetContentLen(element, terminated, 3) == 0);
    assert_content(element, "a");
    assert(xmlNodeSetContentLen(text, raw, 0) == 0);
    assert(text->content != NULL && text->content[0] == 0);
    assert(xmlNodeSetContentLen(element, raw, 0) == 0);
#ifdef XML3_REFERENCE_TEST
    assert(element->children != NULL);
    assert(element->children->type == XML_TEXT_NODE);
    assert(element->children->content != NULL &&
           element->children->content[0] == 0);
#else
    assert(element->children == NULL);
#endif
    assert(xmlNodeSetContentLen(text, BAD_CAST "negative", -7) == 0);
    assert_content(text, "negative");
    assert(xmlNodeSetContentLen(element, BAD_CAST "&amp;", -1) == 0);
    assert_content(element, "&");
    assert(xmlNodeSetContentLen(text, NULL, 20) == 0);
    assert(text->content == NULL);
    assert(xmlNodeSetContentLen(element, NULL, 20) == 0);
    assert(element->children == NULL);
    assert(xmlNodeSetContentLen(NULL, raw, 3) == 1);
    xmlFreeNode(text);
    xmlFreeNode(element);
}

#if defined(__unix__)
static void test_bounded_content_guard_page(void) {
    long page_size = sysconf(_SC_PAGESIZE);
    unsigned char *mapping;
    xmlChar *buffer;
    xmlNodePtr text = xmlNewText(NULL);
    xmlNodePtr element = xmlNewNode(NULL, BAD_CAST "root");
    assert(page_size >= 8 && text != NULL && element != NULL);
    mapping = mmap(NULL, (size_t)page_size * 2, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page_size, (size_t)page_size, PROT_NONE) == 0);
    buffer = mapping + page_size - 7;
    memcpy(buffer, "A&amp;B", 7);
    {
        xmlNodePtr bounded = xmlNewTextLen(buffer, 7);
        assert(bounded != NULL);
        assert_content(bounded, "A&amp;B");
        xmlFreeNode(bounded);
        bounded = xmlNewTextLen(mapping + page_size, 0);
        assert(bounded != NULL && bounded->content != NULL);
        assert(bounded->content[0] == 0);
        xmlFreeNode(bounded);
        assert(xmlNewTextLen(mapping + page_size, -1) == NULL);
        {
            xmlDocPtr doc = xmlNewDoc(NULL);
            assert(doc != NULL);
            bounded = xmlNewDocTextLen(doc, buffer, 7);
            assert(bounded != NULL && bounded->doc == doc);
            assert_content(bounded, "A&amp;B");
            xmlFreeNode(bounded);
            bounded = xmlNewDocTextLen(doc, mapping + page_size, 0);
            assert(bounded != NULL && bounded->doc == doc);
            assert(bounded->content != NULL && bounded->content[0] == 0);
            xmlFreeNode(bounded);
            assert(xmlNewDocTextLen(doc, mapping + page_size, -1) == NULL);
            bounded = xmlNewCDataBlock(doc, buffer, 7);
            assert(bounded && bounded->name == NULL && bounded->doc == doc);
            assert_content(bounded, "A&amp;B");
            xmlFreeNode(bounded);
            bounded = xmlNewCDataBlock(doc, mapping + page_size, 0);
            assert(bounded && bounded->content && bounded->content[0] == 0);
            xmlFreeNode(bounded);
            assert(xmlNewCDataBlock(doc, mapping + page_size, -1) == NULL);
            assert(doc->children == NULL);
            xmlFreeDoc(doc);
        }
    }
    assert(xmlNodeSetContentLen(element, buffer, 7) == 0);
    assert_content(element, "A&B");
    assert(xmlNodeSetContentLen(text, buffer, 7) == 0);
    assert_content(text, "A&amp;B");
    assert(xmlNodeAddContentLen(element, buffer, 7) == 0);
    assert_content(element, "A&BA&amp;B");
    assert(xmlNodeAddContentLen(text, buffer, 7) == 0);
    assert_content(text, "A&amp;BA&amp;B");
    assert(xmlNodeAddContentLen(element, mapping + page_size, 0) == 0);
    assert(xmlNodeAddContentLen(element, mapping + page_size, -7) == 0);
    assert_content(element, "A&BA&amp;B");
    assert(xmlNodeAddContentLen(text, mapping + page_size, 0) == 0);
    assert(xmlNodeAddContentLen(text, mapping + page_size, -7) == 0);
    assert_content(text, "A&amp;BA&amp;B");
#ifndef XML3_REFERENCE_TEST
    assert(xmlNodeSetContentLen(element, mapping + page_size, 0) == 0);
    assert(element->children == NULL);
    assert(xmlNodeSetContentLen(text, mapping + page_size, 0) == 0);
    assert(text->content != NULL && text->content[0] == 0);
#endif
    {
        xmlNodePtr concat = xmlNewText(NULL);
        assert(concat);
        assert(xmlTextConcat(NULL, mapping + page_size, -1) == -1);
        assert(xmlTextConcat(concat, mapping + page_size, 0) == 0);
        assert(concat->content && concat->content[0] == 0);
        assert(xmlTextConcat(concat, buffer, 7) == 0);
        assert_content(concat, "A&amp;B");
#ifndef XML3_REFERENCE_TEST
        buffer[6] = 0;
        assert(xmlTextConcat(concat, buffer + 6, 7) == 0);
        assert_content(concat, "A&amp;B");
#endif
        xmlFreeNode(concat);
    }
    assert(munmap(mapping, (size_t)page_size * 2) == 0);
    xmlFreeNode(text);
    xmlFreeNode(element);
}
#endif

#ifndef XML3_REFERENCE_TEST
static void test_set_content_len_rejection(void) {
    static const xmlChar reference[] = {'&', 'a', 'm', 'p', ';'};
    static const xmlChar utf8[] = {0xc3, 0xa9};
    xmlNodePtr element = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr old;
    assert(element != NULL);
    old = xmlNewTextChild(element, NULL, BAD_CAST "old", BAD_CAST "kept");
    assert(old != NULL);
    assert(xmlNodeSetContentLen(element, reference, 4) == 1);
    assert(element->children == old && old->parent == element);
    assert(xmlNodeSetContentLen(element, utf8, 1) == 1);
    assert(element->children == old && old->parent == element);
    assert_content(element, "kept");
    assert(xmlNodeSetContentLen(element, utf8, 2) == 0);
    assert_content(element, "é");
    xmlFreeNode(element);
}
#endif

static void test_construct_doc_node(int raw) {
    static const char input[] = "<p:root xmlns:p='urn:p'><p:old/></p:root>";
    char name[] = "child";
    char value[] = "A&amp;&#x1F642;\r\n\t";
    const char *expected = raw ? "A&amp;&#x1F642;\r\n\t" : "A&🙂\r\n\t";
    xmlNodePtr (*create)(xmlDocPtr, xmlNsPtr, const xmlChar *, const xmlChar *) =
        raw ? xmlNewDocRawNode : xmlNewDocNode;
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr reparsed;
    xmlNodePtr root, old, child, plain, empty, detached, survivor;
    xmlNsPtr ns;
    xmlChar *memory = NULL;
    int size = 0;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    old = root->children;
    ns = root->ns;
    child = create(doc, ns, BAD_CAST name, BAD_CAST value);
    plain = create(doc, NULL, BAD_CAST "plain", NULL);
    empty = create(doc, NULL, BAD_CAST "empty", BAD_CAST "");
    detached = create(NULL, NULL, BAD_CAST "free", BAD_CAST "&amp;");
    survivor = create(doc, ns, BAD_CAST "survivor", BAD_CAST "A&amp;");
    assert(child && plain && empty && detached && survivor);
    assert(child->doc == doc && child->parent == NULL);
    assert(child->next == NULL && child->prev == NULL && child->ns == ns);
    assert(child->content == NULL && child->children == child->last);
    assert(child->children->doc == doc && child->children->parent == child);
    assert(child->children->type == XML_TEXT_NODE && child->children->ns == NULL);
    assert(plain->ns == NULL && plain->children == NULL && plain->doc == doc);
    assert((empty->children != NULL) == raw);
    if (raw) {
        assert(empty->children->doc == doc && empty->children->content);
        assert(empty->children->content[0] == 0);
    }
    assert(detached->doc == NULL && detached->children->doc == NULL);
    assert_content(detached, raw ? "&amp;" : "&");
    xmlFreeNode(detached);
    assert(create(doc, ns, NULL, BAD_CAST "x") == NULL);
    assert(doc->children == root && root->children == old && root->last == old);
    assert(old->next == NULL && old->parent == root);
    name[0] = 'Z';
    value[0] = 'Z';
    assert(strcmp((const char *)child->name, "child") == 0);
    assert_content(child, expected);
    assert(xmlAddChild(root, child) == child);
    assert(xmlAddChild(root, plain) == plain);
    assert(xmlAddChild(root, empty) == empty);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size > 0);
    assert(strstr((const char *)memory, "<p:child>") != NULL);
    assert(strstr((const char *)memory, "<plain/>") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed);
    assert_content(xmlDocGetRootElement(reparsed)->children->next, expected);
    xmlFreeDoc(reparsed);
    xmlFree(memory);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
    assert(survivor->doc == doc && survivor->children->doc == doc);
    assert(strcmp((const char *)ns->href, "urn:p") == 0);
    assert(xmlNodeSetContent(survivor, BAD_CAST "fixed&amp;") == 0);
    assert(xmlNodeAddContent(survivor, BAD_CAST "!") == 0);
    assert_content(survivor, "fixed&!");
    assert(survivor->ns == ns && survivor->children->doc == doc);
    xmlFreeNode(survivor);
#else
    xmlFreeNode(survivor);
    xmlFreeDoc(doc);
#endif
}

static void test_node_predicates(void) {
    static const char *values[] = {NULL, "", " \t\r\n", " \tx", "\v", "\f",
                                   "\xc2\xa0", "\xe3\x80\x80"};
    static const char input[] = "<r a=' '>\t<a/> \n<![CDATA[\t]]><!-- --><?p   ?></r>";
    xmlDocPtr doc;
    xmlNodePtr root, text, node;
    size_t i;
    assert(xmlNodeIsText(NULL) == 0 && xmlIsBlankNode(NULL) == 0);
    for (i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
        xmlNodePtr cdata;
        xmlChar *before;
        int expected = i < 3;
        text = xmlNewText(BAD_CAST values[i]);
        cdata = xmlNewCDataBlock(NULL, BAD_CAST values[i],
                                values[i] ? (int)strlen(values[i]) : 0);
        assert(text && cdata);
        before = text->content;
        assert(xmlNodeIsText(text) == 1 && xmlNodeIsText(cdata) == 0);
        assert(xmlIsBlankNode(text) == expected && xmlIsBlankNode(cdata) == expected);
        assert(text->content == before && text->parent == NULL);
        xmlFreeNode(text);
        xmlFreeNode(cdata);
    }
    doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    assert(doc);
    root = xmlDocGetRootElement(doc);
    text = root->children;
    assert(xmlNodeIsText((xmlNodePtr)doc) == 0 && xmlIsBlankNode((xmlNodePtr)doc) == 0);
    assert(xmlNodeIsText(root) == 0 && xmlIsBlankNode(root) == 0);
    assert(xmlNodeIsText((xmlNodePtr)root->properties) == 0);
    assert(xmlIsBlankNode((xmlNodePtr)root->properties) == 0);
    for (node = root->children; node; node = node->next) {
        assert(xmlNodeIsText(node) == (node->type == XML_TEXT_NODE));
        assert(xmlIsBlankNode(node) == (node->type == XML_TEXT_NODE ||
                                        node->type == XML_CDATA_SECTION_NODE));
        assert(node->parent == root && node->doc == doc);
    }
    assert(xmlIsBlankNode(text) == 1);
    assert(xmlTextConcat(text, BAD_CAST "x", 1) == 0);
    assert(xmlIsBlankNode(text) == 0 && xmlNodeIsText(text) == 1);
    assert(xmlNodeSetContent(text, BAD_CAST " \r\n") == 0);
    assert(xmlIsBlankNode(text) == 1 && root->children == text);
    xmlUnlinkNode(root);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    assert(xmlNodeIsText(text) == 1 && xmlIsBlankNode(text) == 1);
    node = xmlNewText(BAD_CAST "q");
    assert(node && xmlTextMerge(text, node) == text);
    assert(xmlIsBlankNode(text) == 0 && xmlNodeIsText(text) == 1);
    xmlFreeNode(root);
#ifdef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#else
    {
        xmlNode invalid = {0};
        invalid.type = XML_TEXT_NODE;
        invalid.content = BAD_CAST " ";
        xmlResetLastError();
        assert(xmlNodeIsText(&invalid) == 0 && xmlIsBlankNode(&invalid) == 0);
        assert(xmlGetLastError() == NULL);
    }
#endif
}

static void test_inherited_xml_properties(void) {
    static const char input[] =
        "<root><child a='value'>text<!--note--></child><other/></root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, child, other, text, comment, node, reparsed_child;
    xmlAttrPtr attr;
    xmlNsPtr xml_ns, wrong_ns;
    xmlChar *value, *memory = NULL;
    xmlDocPtr reparsed;
    int size = 0;

    assert(doc);
    root = xmlDocGetRootElement(doc);
    child = root->children;
    other = child->next;
    text = child->children;
    comment = text->next;
    attr = child->properties;
    assert(other && text && comment && attr);
    assert(xmlNodeSetLang(root, BAD_CAST "en") == 0);
    assert(xmlNodeSetSpacePreserve(root, 1) == 0);
    xml_ns = xmlSearchNsByHref(doc, root, XML_XML_NAMESPACE);
    assert(xml_ns);
    wrong_ns = xmlNewNs(root, BAD_CAST "urn:wrong", BAD_CAST "w");
    assert(wrong_ns);
    assert(xmlSetProp(root, BAD_CAST "lang", BAD_CAST "unqualified"));
    assert(xmlSetProp(root, BAD_CAST "space", BAD_CAST "default"));
    assert(xmlSetNsProp(root, wrong_ns, BAD_CAST "lang", BAD_CAST "wrong"));
    assert(xmlSetNsProp(root, wrong_ns, BAD_CAST "space", BAD_CAST "default"));
    assert(xmlSetProp(child, BAD_CAST "lang", BAD_CAST "unqualified"));
    assert(xmlSetNsProp(child, wrong_ns, BAD_CAST "lang", BAD_CAST "wrong"));
    assert(xmlSetProp(child, BAD_CAST "space", BAD_CAST "default"));
    assert(xmlSetNsProp(child, wrong_ns, BAD_CAST "space", BAD_CAST "default"));

    value = xmlNodeGetLang(root);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);
    value = xmlNodeGetLang(child);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);
    value = xmlNodeGetLang(text);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);
    value = xmlNodeGetLang((xmlNodePtr)attr);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);
    value = xmlNodeGetLang(comment);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);
    assert(xmlNodeGetLang((xmlNodePtr)doc) == NULL);
    assert(xmlNodeGetSpacePreserve(root) == 1);
    assert(xmlNodeGetSpacePreserve(child) == 1);
    assert(xmlNodeGetSpacePreserve(text) == -1);
    assert(xmlNodeGetSpacePreserve((xmlNodePtr)attr) == -1);
    assert(xmlNodeGetSpacePreserve(comment) == -1);
    assert(xmlNodeGetSpacePreserve((xmlNodePtr)doc) == -1);

    assert(xmlNodeSetLang(child, BAD_CAST "fr") == 0);
    value = xmlNodeGetLang(child);
    assert(value && strcmp((const char *)value, "fr") == 0);
    xmlFree(value);
    assert(xmlNodeSetLang(child, BAD_CAST "") == 0);
    value = xmlNodeGetLang(child);
    assert(value && value[0] == 0);
    xmlFree(value);
    value = xmlNodeGetLang(text);
    assert(value && value[0] == 0);
    xmlFree(value);
    assert(xmlUnsetNsProp(child, xml_ns, BAD_CAST "lang") == 0);
    value = xmlNodeGetLang(child);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);
    assert(xmlNodeSetLang(child, NULL) == 0);
    value = xmlNodeGetLang(child);
    assert(value && value[0] == 0);
    xmlFree(value);
    value = xmlNodeGetLang(text);
    assert(value && value[0] == 0);
    xmlFree(value);
    assert(xmlUnsetNsProp(child, xml_ns, BAD_CAST "lang") == 0);
    value = xmlNodeGetLang(child);
    assert(value && strcmp((const char *)value, "en") == 0);
    xmlFree(value);

    assert(xmlSetNsProp(child, xml_ns, BAD_CAST "space", BAD_CAST "unknown"));
    assert(xmlNodeGetSpacePreserve(child) == 1);
    assert(xmlSetNsProp(child, xml_ns, BAD_CAST "space", BAD_CAST ""));
    assert(xmlNodeGetSpacePreserve(child) == 1);
    assert(xmlNodeSetSpacePreserve(child, 0) == 0);
    assert(xmlNodeGetSpacePreserve(child) == 0);
    assert(xmlNodeSetSpacePreserve(child, -7) == 0);
    assert(xmlNodeGetSpacePreserve(child) == 1);

    xmlUnlinkNode(child);
    assert(child->doc == doc);
    assert(xmlNodeGetLang(child) == NULL);
    assert(xmlNodeSetSpacePreserve(child, 0) == 0);
    assert(xmlNodeGetSpacePreserve(child) == 0);
    assert(xmlNodeSetLang(other, BAD_CAST "branch") == 0);
    assert(xmlAddChild(other, child) == child);
    value = xmlNodeGetLang(child);
    assert(value && strcmp((const char *)value, "branch") == 0);
    xmlFree(value);
    assert(xmlNodeSetSpacePreserve(child, 0) == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size > 0);
    assert(strstr((const char *)memory, "xml:lang=\"branch\"") != NULL);
    assert(strstr((const char *)memory, "xml:space=\"default\"") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed);
    node = xmlDocGetRootElement(reparsed)->children;
    reparsed_child = node->children;
    value = xmlNodeGetLang(reparsed_child);
    assert(value && strcmp((const char *)value, "branch") == 0);
    xmlFree(value);
    assert(xmlNodeGetSpacePreserve(reparsed_child) == 0);
    xmlFreeDoc(reparsed);
    xmlFree(memory);

    value = xmlNodeGetLang(child);
    assert(value && strcmp((const char *)value, "branch") == 0);
    xmlFreeDoc(doc);
    assert(strcmp((const char *)value, "branch") == 0);
    xmlFree(value);

    node = xmlNewNode(NULL, BAD_CAST "standalone");
    assert(node);
    assert(xmlNodeSetLang(node, BAD_CAST "local") == 0);
    assert(xmlSearchNsByHref(NULL, node, XML_XML_NAMESPACE) != NULL);
    value = xmlNodeGetLang(node);
    assert(value && strcmp((const char *)value, "local") == 0);
    xmlFree(value);
    assert(xmlNodeSetSpacePreserve(node, -3) == 0);
    assert(xmlNodeGetSpacePreserve(node) == 1);
    assert(xmlNodeSetLang(NULL, BAD_CAST "invalid") == 1);
    assert(xmlNodeSetSpacePreserve(NULL, 0) == 1);
    text = xmlNewText(BAD_CAST "text");
    assert(text);
    assert(xmlNodeSetLang(text, BAD_CAST "invalid") == 1);
    assert(xmlNodeSetSpacePreserve(text, 1) == 1);
    xmlFreeNode(text);
    xmlFreeNode(node);

#ifndef XML3_REFERENCE_TEST
    {
        xmlDocPtr held_doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr held = xmlNewDocNode(held_doc, NULL, BAD_CAST "held", NULL);
        xmlNode unregistered = {0};
        assert(held_doc && held && held->parent == NULL);
        xmlFreeDoc(held_doc);
        assert(xmlNodeGetLang(held) == NULL);
        assert(xmlNodeSetLang(held, BAD_CAST "after-free") == 0);
        value = xmlNodeGetLang(held);
        assert(value && strcmp((const char *)value, "after-free") == 0);
        xmlFree(value);
        assert(xmlNodeSetSpacePreserve(held, 1) == 0);
        assert(xmlNodeGetSpacePreserve(held) == 1);
        xmlFreeNode(held);

        unregistered.type = XML_ELEMENT_NODE;
        unregistered.parent = &unregistered;
        xmlResetLastError();
        assert(xmlNodeGetLang(&unregistered) == NULL);
        assert(xmlNodeGetSpacePreserve(&unregistered) == -1);
        assert(xmlGetLastError() == NULL);
    }
#endif
}

static void test_text_concat(void) {
    static const char input[] = "<r a='old'>t<![CDATA[c]]><!--n--><?p v?></r>";
    static const xmlChar suffix[] = {'<', '&'};
    static const xmlChar embedded[] = {'x', 0, 'y'};
    static const char *expected[] = {"t<&", "c<&", "n<&", "v<&"};
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, nodes[4], text;
    xmlChar *memory = NULL;
    xmlDocPtr reparsed;
    int size = 0;
    size_t i;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    nodes[0] = root->children;
    for (i = 1; i < 4; i++) nodes[i] = nodes[i - 1]->next;
    assert(xmlTextConcat(NULL, NULL, 0) == -1);
    assert(xmlTextConcat(root, NULL, 0) == -1);
    assert(xmlTextConcat(root, suffix, 2) == -1);
    assert(xmlTextConcat((xmlNodePtr)root->properties, suffix, 2) == -1);
    assert(xmlTextConcat((xmlNodePtr)doc, NULL, -1) == -1);
    assert_content((xmlNodePtr)root->properties, "old");
    for (i = 0; i < 4; i++) {
        xmlChar *before = nodes[i]->content;
        assert(xmlTextConcat(nodes[i], NULL, -1) == 0);
        assert(nodes[i]->content == before);
        assert(xmlTextConcat(nodes[i], suffix, 2) == 0);
        assert_content(nodes[i], expected[i]);
        assert(nodes[i]->parent == root && nodes[i]->doc == doc);
        assert(nodes[i]->prev == (i ? nodes[i - 1] : NULL));
        assert(nodes[i]->next == (i < 3 ? nodes[i + 1] : NULL));
    }
    assert(root->children == nodes[0] && root->last == nodes[3]);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size > 0);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed);
    assert_content(xmlDocGetRootElement(reparsed), "t<&c<&");
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    xmlUnlinkNode(root);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    assert(xmlTextConcat(nodes[0], BAD_CAST "!", -1) == 0);
    assert_content(root, "t<&!c<&");
    xmlFreeNode(root);
#ifdef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    text = xmlNewText(NULL);
    assert(text && xmlTextConcat(text, NULL, 100) == 0 && text->content == NULL);
    assert(xmlTextConcat(text, BAD_CAST "ignored", 0) == 0);
    assert(text->content && text->content[0] == 0);
    assert(xmlTextConcat(text, BAD_CAST "abX", 2) == 0);
    assert(xmlTextConcat(text, text->content, 2) == 0);
    assert_content(text, "abab");
    assert(xmlTextConcat(text, BAD_CAST "!", -1) == 0);
    assert(xmlTextConcat(text, BAD_CAST "?", -2) == 0);
    assert(xmlTextConcat(text, embedded, 3) == 0);
    assert_content(text, "abab!?x");
    assert(xmlTextConcat(text, BAD_CAST "s", 1) == 0);
    assert_content(text, "abab!?xs");
#ifndef XML3_REFERENCE_TEST
    {
        xmlNode invalid = {0};
        assert(xmlTextConcat(&invalid, suffix, 2) == -1);
    }
#endif
    xmlFreeNode(text);
    xmlResetLastError();
}

static void test_text_merge(void) {
    static const char input[] =
        "<r a='A' b='B'>left<!--gap-->right<x/>tail</r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, first, second, gap, x, tail, extra;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    gap = first->next;
    second = gap->next;
    x = second->next;
    tail = root->last;
    assert(xmlTextMerge(NULL, NULL) == NULL);
    assert(xmlTextMerge(NULL, root) == root && xmlTextMerge(root, NULL) == root);
    assert(xmlTextMerge(first, first) == NULL);
    assert(xmlTextMerge(root, first) == NULL);
    extra = xmlNewCDataBlock(NULL, BAD_CAST "raw", 3);
    assert(extra && xmlTextMerge(first, extra) == NULL);
    assert_content(first, "left");
    assert_content(extra, "raw");
    xmlFreeNode(extra);
    assert(xmlTextMerge(first, second) == first);
    assert(root->children == first && first->parent == root);
    assert(first->next == gap && gap->prev == first);
    assert(gap->next == x && x->prev == gap && root->last == tail);
    assert_content(first, "leftright");
    extra = xmlNewText(BAD_CAST "&raw");
    assert(extra && xmlTextMerge(first, extra) == first);
    assert_content(first, "leftright&raw");
    assert(xmlTextMerge(root->properties->children,
                        root->properties->next->children) ==
           root->properties->children);
    assert_content((xmlNodePtr)root->properties, "AB");
    assert(root->properties->next->children == NULL);
    assert(root->properties->next->last == NULL);
    assert(xmlTextMerge(tail, first) == tail);
    assert(root->children == gap && gap->prev == NULL);
    assert(root->last == tail && tail->prev == x && x->next == tail);
    assert_content(root, "tailleftright&raw");
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size > 0);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed);
    assert_content(xmlDocGetRootElement(reparsed), "tailleftright&raw");
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    xmlUnlinkNode(root);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    extra = xmlNewText(BAD_CAST "!");
    assert(extra && xmlTextMerge(tail, extra) == tail);
    assert_content(tail, "tailleftright&raw!");
    assert(xmlNodeSetContent(tail, BAD_CAST "repaired") == 0);
    assert_content(root, "repaired");
    xmlFreeNode(root);
#ifdef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    first = xmlNewText(NULL);
    second = xmlNewText(NULL);
    assert(first && second && xmlTextMerge(first, second) == first);
    assert(first->content == NULL);
    second = xmlNewText(BAD_CAST "");
    assert(second && xmlTextMerge(first, second) == first);
    assert(first->content && first->content[0] == 0);
    second = xmlNewText(NULL);
    memory = first->content;
    assert(second && xmlTextMerge(first, second) == first);
    assert(first->content == memory);
    xmlFreeNode(first);
    root = xmlNewNode(NULL, BAD_CAST "r");
    first = xmlNewText(NULL);
    second = xmlNewText(NULL);
    assert(root && first && second);
    assert(xmlAddChild(root, first) == first);
    assert(xmlAddChild(root, second) == first);
    assert(first->content == NULL && root->last == first);
    xmlFreeNode(root);
#ifndef XML3_REFERENCE_TEST
    {
        xmlDocPtr other = xmlNewDoc(NULL);
        xmlNode invalid = {0};
        doc = xmlNewDoc(NULL);
        first = xmlNewDocText(doc, BAD_CAST "left");
        second = xmlNewDocText(other, BAD_CAST "right");
        assert(doc && other && first && second);
        assert(xmlTextMerge(first, second) == NULL);
        assert(first->doc == doc && second->doc == other);
        assert_content(first, "left");
        assert_content(second, "right");
        assert(xmlTextMerge(first, &invalid) == NULL);
        assert(xmlTextMerge(&invalid, second) == NULL);
        xmlFreeNode(first);
        xmlFreeNode(second);
        xmlFreeDoc(doc);
        xmlFreeDoc(other);
    }
#endif
    xmlResetLastError();
}

static void test_last_child(void) {
    static const char input[] =
        "<r xmlns:p='urn:tail' p:a='value'><one/>tail<!--last--></r><!--after-->";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr empty = xmlNewDoc(NULL);
    xmlNodePtr root, tail, value;
    xmlAttrPtr attr;
    assert(doc && empty);
    assert(xmlGetLastChild(NULL) == NULL);
    assert(xmlGetLastChild((const xmlNode *)empty) == NULL);
    xmlFreeDoc(empty);
    root = xmlDocGetRootElement(doc);
    attr = root->properties;
    tail = xmlGetLastChild(root);
    assert(tail && tail->type == XML_COMMENT_NODE && tail == root->last);
    assert(xmlLastElementChild(root) == root->children);
    assert(xmlGetLastChild(root->children) == NULL);
    assert(xmlGetLastChild(tail) == NULL);
    assert(xmlGetLastChild((const xmlNode *)doc) == doc->last);
    assert(doc->last->type == XML_COMMENT_NODE);
    assert(xmlGetLastChild((const xmlNode *)root->nsDef) == NULL);
    assert(xmlGetLastChild((const xmlNode *)attr) == attr->last);
    assert_content(xmlGetLastChild((const xmlNode *)attr), "value");
    xmlUnlinkNode(tail);
    assert(xmlGetLastChild(root) == root->last && root->last->type == XML_TEXT_NODE);
    assert_content(xmlGetLastChild(root), "tail");
    assert(xmlAddSibling(root->children, tail) == tail);
    assert(xmlGetLastChild(root) == tail);
    tail = xmlNewCDataBlock(doc, BAD_CAST "cdata", 5);
    assert(tail && xmlAddSibling(root->children, tail) == tail);
    assert(xmlGetLastChild(root) == tail && xmlGetLastChild(tail) == NULL);
    tail = xmlNewPI(BAD_CAST "target", BAD_CAST "data");
    assert(tail && xmlAddSibling(root->children, tail) == tail);
    assert(xmlGetLastChild(root) == tail && xmlGetLastChild(tail) == NULL);
    assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "changed") == 0);
    value = xmlGetLastChild((const xmlNode *)attr);
    assert(value == attr->children && value == attr->last);
    assert_content(value, "changed");
    xmlUnlinkNode(value);
    assert(xmlGetLastChild((const xmlNode *)attr) == NULL);
    xmlFreeNode(value);
    assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "restored") == 0);
    assert(xmlNodeSetContent(root, BAD_CAST "new&amp;content") == 0);
    assert(xmlGetLastChild(root) == root->children);
    assert_content(xmlGetLastChild(root), "new&content");
    xmlUnlinkNode(root);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    assert(xmlGetLastChild(root) == root->last);
    assert_content(xmlGetLastChild(root), "new&content");
    assert_content(xmlGetLastChild((const xmlNode *)attr), "restored");
    xmlFreeNode(root);
#ifdef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#else
    {
        xmlNode unmanaged = {0};
        unmanaged.type = XML_ELEMENT_NODE;
        unmanaged.last = &unmanaged;
        xmlResetLastError();
        assert(xmlGetLastChild(&unmanaged) == NULL);
        assert(xmlGetLastError() == NULL);
    }
#endif
}

static void test_reverse_element_navigation(void) {
    static const char input[] =
        "<!--before--><r a='v'>start<a/>mid<!--gap--><b/><?pi x?>"
        "<![CDATA[tail]]>end</r><!--after-->";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, a, b, c;
    xmlDocPtr empty = xmlNewDoc(NULL);
    assert(doc && empty);
    assert(xmlLastElementChild(NULL) == NULL);
    assert(xmlPreviousElementSibling(NULL) == NULL);
    assert(xmlLastElementChild((xmlNodePtr)empty) == NULL);
    xmlFreeDoc(empty);
    root = xmlDocGetRootElement(doc);
    a = xmlFirstElementChild(root);
    b = xmlNextElementSibling(a);
    assert(a && b && strcmp((const char *)a->name, "a") == 0);
    assert(strcmp((const char *)b->name, "b") == 0);
    assert(xmlLastElementChild(root) == b && xmlChildElementCount(root) == 2);
    assert(xmlPreviousElementSibling(root->last) == b);
    assert(xmlPreviousElementSibling(b) == a);
    assert(xmlPreviousElementSibling(a) == NULL);
    assert(xmlLastElementChild(a) == NULL);
    assert(xmlLastElementChild(root->last) == NULL);
    assert(xmlLastElementChild((xmlNodePtr)doc) == root);
    assert(xmlPreviousElementSibling(doc->last) == root);
    assert(xmlPreviousElementSibling((xmlNodePtr)doc) == NULL);
    assert(xmlLastElementChild((xmlNodePtr)root->properties) == NULL);
    assert(xmlPreviousElementSibling((xmlNodePtr)root->properties) == NULL);
    xmlUnlinkNode(b);
    assert(xmlLastElementChild(root) == a);
    assert(xmlPreviousElementSibling(b) == NULL);
    c = xmlNewDocRawNode(doc, NULL, BAD_CAST "c", BAD_CAST "");
    assert(c && xmlAddChild(root, c) == c);
    assert(xmlLastElementChild(root) == c && xmlPreviousElementSibling(c) == a);
    assert(xmlLastElementChild(c) == NULL);
    assert(xmlAddChild(root, b) == b);
    assert(xmlLastElementChild(root) == b && xmlPreviousElementSibling(b) == c);
    assert(xmlNextElementSibling(c) == b && xmlChildElementCount(root) == 3);
    xmlUnlinkNode(a);
    xmlFreeNode(a);
    assert(xmlPreviousElementSibling(c) == NULL);
    xmlUnlinkNode(root);
    assert(xmlLastElementChild((xmlNodePtr)doc) == NULL);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#endif
    assert(xmlLastElementChild(root) == b && xmlPreviousElementSibling(b) == c);
    xmlUnlinkNode(b);
    xmlFreeNode(b);
    assert(xmlLastElementChild(root) == c);
    xmlUnlinkNode(c);
    xmlFreeNode(c);
    assert(xmlLastElementChild(root) == NULL && xmlChildElementCount(root) == 0);
    assert_content(root, "startmidtailend");
    xmlFreeNode(root);
#ifdef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
#else
    {
        xmlNode unregistered = {0};
        unregistered.type = XML_ELEMENT_NODE;
        unregistered.last = &unregistered;
        unregistered.prev = &unregistered;
        xmlResetLastError();
        assert(xmlLastElementChild(&unregistered) == NULL);
        assert(xmlPreviousElementSibling(&unregistered) == NULL);
        assert(xmlGetLastError() == NULL);
    }
#endif
}

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

static void test_construct_text_child(void) {
    static const char input[] = "<p:root xmlns:p='urn:parent' xmlns:q='urn:other'/>";
    static const char value[] = "<&amp;&#65;&unknown;é\r\n\t";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, child, empty, absent, other;
    xmlNsPtr alternate;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    alternate = xmlSearchNs(doc, root, BAD_CAST "q");
    assert(alternate != NULL);
    child = xmlNewTextChild(root, NULL, BAD_CAST "literal", BAD_CAST value);
    assert(child != NULL && child->parent == root && child->doc == doc);
    assert(child->ns == root->ns && child->children->ns == NULL);
    assert(child->children->parent == child && child->children->doc == doc);
    assert_content(child, value);
    empty = xmlNewTextChild(root, NULL, BAD_CAST "empty", BAD_CAST "");
    assert(empty != NULL && empty->children != NULL);
    assert(empty->children == empty->last && empty->children->type == XML_TEXT_NODE);
    assert(empty->children->content != NULL && empty->children->content[0] == 0);
    absent = xmlNewTextChild(root, NULL, BAD_CAST "absent", NULL);
    assert(absent != NULL && absent->children == NULL && absent->last == NULL);
    other = xmlNewTextChild(root, alternate, child->name, BAD_CAST "other");
    assert(other != NULL && other->ns == alternate);
    assert(root->children == child && child->next == empty && empty->prev == child);
    assert(empty->next == absent && absent->next == other && root->last == other);
    assert(xmlNewTextChild(child->children, NULL, BAD_CAST "bad", NULL) == NULL);
    assert(xmlNewTextChild(root, NULL, NULL, NULL) == NULL);
    assert(xmlNewTextChild(NULL, NULL, BAD_CAST "bad", NULL) == NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "&lt;&amp;amp;&amp;#65;&amp;unknown;") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed)->children, value);
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    assert(doc != NULL);
    child = xmlNewTextChild((xmlNodePtr)doc, NULL, BAD_CAST "root", BAD_CAST "&amp;");
    assert(child != NULL && child == xmlDocGetRootElement(doc));
    assert(child->parent == (xmlNodePtr)doc && child->doc == doc);
    assert_content(child, "&amp;");
    xmlFreeDoc(doc);
}

#ifndef XML3_REFERENCE_TEST
static void test_construct_text_child_serialization_validation(void) {
    static const char *const invalid[] = {"\x01", "\xc3"};
    size_t i;
    for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr child;
        xmlChar *memory = NULL;
        int size = 0;
        assert(doc != NULL);
        child = xmlNewTextChild((xmlNodePtr)doc, NULL, BAD_CAST "root", BAD_CAST invalid[i]);
        assert(child != NULL);
        assert_content(child, invalid[i]);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory == NULL && size == 0);
        assert(xmlNodeSetContent(child->children, BAD_CAST "recovered & text") == 0);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory != NULL && size > 0);
        assert(strstr((const char *)memory, "recovered &amp; text") != NULL);
        xmlFree(memory);
        xmlFreeDoc(doc);
    }
}

static void test_construct_doc_node_rejections(void) {
    static const char input[] = "<p:root xmlns:p='urn:p'><p:old/></p:root>";
    static const char *const invalid[] = {"&unknown;", "&#0;", "bad &", "\xc3"};
    static const char *const raw_invalid[] = {"\xc3", "\1"};
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, old;
    xmlDoc unregistered = {0};
    xmlNs invalid_ns = {0};
    size_t i;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    old = root->children;
    for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        assert(xmlNewDocNode(doc, root->ns, BAD_CAST "bad", BAD_CAST invalid[i]) == NULL);
        assert(root->children == old && root->last == old && old->next == NULL);
    }
    assert(xmlNewDocNode(&unregistered, NULL, BAD_CAST "bad", NULL) == NULL);
    assert(xmlNewDocRawNode((xmlDocPtr)root, NULL, BAD_CAST "bad", NULL) == NULL);
    assert(xmlNewDocNode(doc, &invalid_ns, BAD_CAST "bad", NULL) == NULL);
    assert(xmlNewDocRawNode(doc, &invalid_ns, BAD_CAST "bad", NULL) == NULL);
    for (i = 0; i < sizeof(raw_invalid) / sizeof(raw_invalid[0]); ++i) {
        xmlNodePtr node = xmlNewDocRawNode(doc, root->ns, BAD_CAST "bad",
                                         BAD_CAST raw_invalid[i]);
        xmlChar *memory = NULL;
        int size = 0;
        assert(node && xmlAddChild(root, node) == node);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory == NULL && size == 0);
        assert(xmlNodeSetContent(node->children, BAD_CAST "repaired & text") == 0);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory && strstr((const char *)memory, "repaired &amp; text"));
        xmlFree(memory);
        xmlUnlinkNode(node);
        xmlFreeNode(node);
        assert(root->children == old && root->last == old && old->next == NULL);
    }
    xmlFreeDoc(doc);
}

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
    assert(xmlNewTextChild(&invalid_node, NULL, BAD_CAST "bad", NULL) == NULL);
    assert(xmlNewTextChild(root, &invalid_ns, BAD_CAST "bad", NULL) == NULL);
    assert(root->children == old && root->last == old);
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    child = xmlNewChild(root, NULL, BAD_CAST "after-release", BAD_CAST "new&amp;text");
    assert(child != NULL && child->parent == root && child->ns == ns);
    assert_content(child, "new&text");
    child = xmlNewTextChild(root, NULL, BAD_CAST "literal", BAD_CAST "new&amp;text");
    assert(child != NULL && child->parent == root && child->ns == ns);
    assert_content(child, "new&amp;text");
    assert(strcmp((const char *)ns->href, "urn:parent") == 0);
    xmlFreeNode(root);
}
#endif

static void test_document_property(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlAttrPtr attr;
    const char *values[] = {NULL, "", "a&amp;b&#x1F642;\t\r\n", "literal<text"};
    const char *expected[] = {"", "", "a&b\xF0\x9F\x99\x82\t\r\n", "literal<text"};
    assert(doc && root);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    for (unsigned i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
        attr = xmlNewDocProp(doc, BAD_CAST "a", BAD_CAST values[i]);
        assert(attr && attr->type == XML_ATTRIBUTE_NODE && attr->doc == doc);
        assert(attr->parent == NULL && attr->prev == NULL && attr->next == NULL);
        assert(attr->ns == NULL && root->properties == NULL);
        assert_content((xmlNodePtr)attr, expected[i]);
        if (i < 2) {
            assert(attr->children == NULL && attr->last == NULL);
        } else {
            assert(attr->children && attr->children == attr->last);
            assert(attr->children->doc == doc && attr->children->parent == (xmlNodePtr)attr);
        }
        assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "edited&amp;value") == 0);
        assert_content((xmlNodePtr)attr, "edited&value");
        xmlFreeProp(attr);
    }
    assert(xmlNewDocProp(doc, NULL, BAD_CAST "x") == NULL);
    attr = xmlNewDocProp(NULL, BAD_CAST "standalone", BAD_CAST "&#65;");
    assert(attr && attr->doc == NULL);
    assert_content((xmlNodePtr)attr, "A");
    xmlFreeProp(attr);
#ifndef XML3_REFERENCE_TEST
    {
        xmlNode unmanaged = {0};
        const char *invalid[] = {"&missing;", "&#0;", "&#x110000;", "&amp"};
        for (unsigned i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
            assert(xmlNewDocProp(doc, BAD_CAST "a", BAD_CAST invalid[i]) == NULL);
            assert(xmlDocGetRootElement(doc) == root && root->properties == NULL);
        }
        assert(xmlNewDocProp(doc, BAD_CAST "p:a", BAD_CAST "v") == NULL);
        assert(xmlNewDocProp((xmlDocPtr)root, BAD_CAST "a", BAD_CAST "v") == NULL);
        assert(xmlNewDocProp((xmlDocPtr)&unmanaged, BAD_CAST "a", BAD_CAST "v") == NULL);
    }
    attr = xmlNewDocProp(doc, BAD_CAST "held", BAD_CAST "before");
    assert(attr);
    xmlFreeDoc(doc);
    assert(attr->doc == doc && attr->children->doc == doc);
    assert_content((xmlNodePtr)attr, "before");
    assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "after&amp;free") == 0);
    assert_content((xmlNodePtr)attr, "after&free");
    xmlFreeProp(attr);
#else
    xmlFreeDoc(doc);
#endif
}

int main(void) {
    assert(xmlNodeAddContent(NULL, NULL) == 1);
    assert(xmlNodeSetContent(NULL, NULL) == 1);
    test_element_and_attribute_append();
    test_new_child_after_non_text();
    test_scalar_nodes_and_aliasing();
    test_detached_lifetime();
    test_set_content();
    test_set_detached_lifetime();
    test_set_content_len();
    test_add_content_len();
    test_new_text_len();
    test_document_text();
    test_document_property();
#if defined(__unix__)
    test_bounded_content_guard_page();
#endif
    test_construct_child();
    test_construct_doc_node(0);
    test_construct_doc_node(1);
    test_reverse_element_navigation();
    test_last_child();
    test_text_merge();
    test_text_concat();
    test_node_predicates();
    test_inherited_xml_properties();
    test_construct_text_child();
#ifndef XML3_REFERENCE_TEST
    test_set_content_len_rejection();
    test_construct_text_child_serialization_validation();
    test_construct_child_failure_and_lifetime();
    test_construct_doc_node_rejections();
    test_set_rejection_is_transactional();
    test_set_namespace_borrower_lifetime();
    test_invalid_facade_and_document_noop();
    test_invalid_comment_serialization();
#endif
    puts("content edit tests passed");
    return 0;
}
