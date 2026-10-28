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
#if defined(__unix__)
    test_bounded_content_guard_page();
#endif
    test_construct_child();
    test_construct_text_child();
#ifndef XML3_REFERENCE_TEST
    test_set_content_len_rejection();
    test_construct_text_child_serialization_validation();
    test_construct_child_failure_and_lifetime();
    test_set_rejection_is_transactional();
    test_set_namespace_borrower_lifetime();
    test_invalid_facade_and_document_noop();
    test_invalid_comment_serialization();
#endif
    puts("content edit tests passed");
    return 0;
}
