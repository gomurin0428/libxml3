#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(XML3_DEVELOPMENT_TEST) && !defined(XML3_NO_OOM_TEST)
extern void xml3_oom_enable(long index);
extern void xml3_oom_disable(void);
extern int xml3_oom_was_injected(void);
#endif

static void expect_exact_output(const char *input, const char *expected) {
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size == (int)strlen(expected));
    assert(memcmp(memory, expected, (size_t)size) == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void test_shared_lexical_cases(void) {
    static const char simple_input[] = "<r a='&amp;'>x</r>";
    static const char simple_expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<r a=\"&amp;\">x</r>\n";
    static const char representative_input[] =
        "<名 xmlns='urn:default' xmlns:p='urn:p' "
        "p:属性='a&amp;&quot;&#9;&#10;'>é&amp;&lt;"
        "<![CDATA[c]]><!--inside--><?pi data?></名>";
    static const char representative_expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<名 xmlns=\"urn:default\" xmlns:p=\"urn:p\" "
        "p:属性=\"a&amp;&quot;&#9;&#10;\">é&amp;&lt;"
        "<![CDATA[c]]><!--inside--><?pi data?></名>\n";

    expect_exact_output(simple_input, simple_expected);
    expect_exact_output(representative_input, representative_expected);
}

static void test_constructed_comments_and_pi(void) {
    static const char expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<!--before-->\n"
        "<r><!--note--><?work 値?><!----><?empty ?><?bare?>"
        "<?xml-stylesheet type='x'?></r>\n<?after?>\n";
    char comment_content[] = "note";
    char target[] = "work";
    char pi_content[] = "値";
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr comment = xmlNewComment(BAD_CAST comment_content);
    xmlNodePtr pi = xmlNewPI(BAD_CAST target, BAD_CAST pi_content);
    xmlNodePtr null_comment = xmlNewComment(NULL);
    xmlNodePtr empty_comment = xmlNewComment(BAD_CAST "");
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc && root && comment && pi && null_comment && empty_comment);
    assert(comment->type == XML_COMMENT_NODE && pi->type == XML_PI_NODE);
    assert(comment->parent == NULL && comment->doc == NULL);
    assert(pi->parent == NULL && pi->doc == NULL && pi->ns == NULL);
    assert(strcmp((const char *)comment->name, "comment") == 0);
    assert(null_comment->content == NULL);
    assert(empty_comment->content && empty_comment->content[0] == 0);
    assert(xmlNewPI(NULL, BAD_CAST "data") == NULL);
    comment_content[0] = 'X';
    target[0] = 'X';
    pi_content[0] = 'X';
    assert(xmlAddChild((xmlNodePtr)doc, xmlNewComment(BAD_CAST "before")));
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, comment) == comment);
    assert(xmlAddChild(root, pi) == pi);
    assert(xmlAddChild(root, null_comment) == null_comment);
    assert(xmlAddChild(root, empty_comment) == empty_comment);
    assert(xmlAddChild(root, xmlNewPI(BAD_CAST "empty", BAD_CAST "")));
    assert(xmlAddChild(root, xmlNewPI(BAD_CAST "bare", NULL)));
    assert(xmlAddChild(root, xmlNewPI(BAD_CAST "xml-stylesheet", BAD_CAST "type='x'")));
    assert(xmlAddChild((xmlNodePtr)doc, xmlNewPI(BAD_CAST "after", NULL)));
    assert(comment->doc == doc && pi->doc == doc);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size == (int)sizeof(expected) - 1);
    assert(memcmp(memory, expected, sizeof(expected)) == 0);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc);
    root = xmlDocGetRootElement(doc);
    comment = root->children;
    pi = comment->next;
    assert(comment->type == XML_COMMENT_NODE);
    assert(strcmp((const char *)comment->content, "note") == 0);
    assert(pi->type == XML_PI_NODE && strcmp((const char *)pi->name, "work") == 0);
    assert(strcmp((const char *)pi->content, "値") == 0);
    xmlUnlinkNode(pi);
    assert(pi->parent == NULL && pi->next == NULL && pi->prev == NULL);
    xmlFreeNode(pi);
    xmlFreeDoc(doc);
    xmlFree(memory);
}

#ifndef XML3_REFERENCE_TEST
static unsigned int rejected_case;

static void expect_rejected(xmlDocPtr doc, const char *encoding) {
    xmlChar *memory = (xmlChar *)1;
    int size = 77;

    xmlResetLastError();
    xmlDocDumpMemoryEnc(doc, &memory, &size, encoding);
    if (memory != NULL || size != 0) {
        fprintf(stderr, "rejection case %u (encoding %s): size %d, output %s\n",
                rejected_case, encoding != NULL ? encoding : "(null)", size,
                memory != NULL ? (const char *)memory : "(null)");
    }
    rejected_case++;
    assert(memory == NULL && size == 0);
    assert(xmlGetLastError() != NULL);
}

static void test_round_trip(void) {
    static const char input[] =
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<?before data?><!--top-->"
        "<名 xmlns='urn:default' xmlns:q='urn:q' "
        "q:属性='a&amp;&quot;&#9;&#10;' plain='v' empty=''>"
        "A&amp;&lt;&gt;&#13;<![CDATA[x]]]]><![CDATA[>y]]><!--inside-->"
        "<?inside value?>"
        "</名><!--after-->";
    static const char expected_text_before[] = "A&<>\rx]]>y";
    static const char expected_text[] = "A&<>\rx]]>y追加&<>\r";
    static const char expected_attribute[] = "a&\"\t\n";
    static const char expected_edited_attribute[] = "x&\"y\t\n";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
    xmlNodePtr root;
    xmlChar *attribute;
    xmlChar *content;
    xmlChar *edited_attribute;
    xmlNsPtr q_namespace;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root != NULL);
    attribute = xmlGetNsProp(root, BAD_CAST "属性", BAD_CAST "urn:q");
    content = xmlNodeGetContent(root);
    assert(attribute != NULL && strcmp((const char *)attribute,
                                       expected_attribute) == 0);
    assert(content != NULL &&
           strcmp((const char *)content, expected_text_before) == 0);
    xmlFree(attribute);
    xmlFree(content);
    q_namespace = xmlSearchNs(doc, root, BAD_CAST "q");
    assert(q_namespace != NULL);
    assert(xmlSetNsProp(root, q_namespace, BAD_CAST "追記",
                        BAD_CAST "x&\"y\t\n") != NULL);
    assert(xmlAddChild(root, xmlNewText(BAD_CAST "追加&<>\r")) != NULL);

    xmlDocDumpMemoryEnc(doc, &memory, &size, "uTf-8");
    assert(memory != NULL && size > 0 && memory[size] == 0);
    assert(strstr((const char *)memory, "encoding=\"uTf-8\"") != NULL);
    assert(strstr((const char *)memory, "<名") != NULL);
    assert(strstr((const char *)memory, "&quot;&#9;&#10;") != NULL);
    assert(strstr((const char *)memory, "]]]]><![CDATA[>") != NULL);
    xmlFreeDoc(doc);

    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    root = xmlDocGetRootElement(reparsed);
    attribute = xmlGetNsProp(root, BAD_CAST "属性", BAD_CAST "urn:q");
    edited_attribute = xmlGetNsProp(root, BAD_CAST "追記", BAD_CAST "urn:q");
    {
        xmlChar *empty = xmlGetProp(root, BAD_CAST "empty");
        assert(empty != NULL && strcmp((const char *)empty, "") == 0);
        xmlFree(empty);
    }
    content = xmlNodeGetContent(root);
    assert(attribute != NULL && strcmp((const char *)attribute,
                                       expected_attribute) == 0);
    assert(edited_attribute != NULL &&
           strcmp((const char *)edited_attribute,
                  expected_edited_attribute) == 0);
    assert(content != NULL && strcmp((const char *)content, expected_text) == 0);
    xmlFree(attribute);
    xmlFree(edited_attribute);
    xmlFree(content);
    xmlFreeDoc(reparsed);
    assert(strstr((const char *)memory, "<名") != NULL);
    xmlFree(memory);
}

static void test_misc_rejections_and_lifetime(void) {
    static const struct { const char *target; const char *content; } cases[] = {
        {NULL, "bad--comment"}, {NULL, "trailing-"},
        {NULL, "\001"}, {NULL, "\xc3"},
        {"xml", ""}, {"xmL", ""}, {"xMl", ""}, {"xML", ""},
        {"Xml", ""}, {"XmL", ""}, {"XMl", ""}, {"XML", ""},
        {"", ""}, {"bad name", ""}, {"ok", "?>"}, {"ok", "\001"}
    };
    size_t i;
    for (i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        xmlNodePtr node = cases[i].target
            ? xmlNewPI(BAD_CAST cases[i].target, BAD_CAST cases[i].content)
            : xmlNewComment(BAD_CAST cases[i].content);
        xmlChar *memory = NULL;
        int size = 0;
        assert(doc && root && node);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, node) == node);
        expect_rejected(doc, "UTF-8");
        assert(root->children == node && node->parent == root);
        xmlUnlinkNode(node);
        xmlFreeNode(node);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory && strstr((const char *)memory, "<r/>"));
        xmlFree(memory);
        xmlFreeDoc(doc);
    }
    {
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        xmlNodePtr comment = xmlNewComment(BAD_CAST "retained comment");
        xmlNodePtr pi = xmlNewPI(BAD_CAST "retained", BAD_CAST "PI data");
        xmlChar *content;
        assert(doc && root && comment && pi);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, comment) == comment);
        assert(xmlAddChild(root, pi) == pi);
        xmlUnlinkNode(comment);
        xmlUnlinkNode(pi);
        xmlFreeDoc(doc);
        content = xmlNodeGetContent(comment);
        assert(content && strcmp((const char *)content, "retained comment") == 0);
        xmlFree(content);
        content = xmlNodeGetContent(pi);
        assert(content && strcmp((const char *)content, "PI data") == 0);
        xmlFree(content);
        assert(strcmp((const char *)pi->name, "retained") == 0);
        xmlFreeNode(comment);
        xmlFreeNode(pi);
    }
}

static void test_pointer_contracts(void) {
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
    xmlChar *memory = NULL;
    int size = 1;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, NULL, &size, "UTF-8");
    assert(size == 0);
    xmlDocDumpMemoryEnc(doc, &memory, NULL, "UTF-8");
    assert(memory != NULL);
    xmlFree(memory);
    memory = (xmlChar *)1;
    size = 99;
    xmlDocDumpMemoryEnc(NULL, &memory, &size, "UTF-8");
    assert(memory == NULL && size == 0);
    expect_rejected(doc, NULL);
    expect_rejected(doc, "");
    expect_rejected(doc, "UTF-16");
    xmlFreeDoc(doc);
}

static void test_namespace_shadowing(void) {
    static const char input[] =
        "<r xmlns:p='urn:outer'><p:a><p:b xmlns:p='urn:inner' p:id='1'/>"
        "</p:a></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
    xmlChar *memory = NULL;
    xmlChar *value;
    int size = 0;
    xmlNodePtr inner;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory,
                                    "<p:b xmlns:p=\"urn:inner\" p:id=\"1\"/>"));
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc != NULL);
    inner = xmlDocGetRootElement(doc)->children->children;
    assert(inner != NULL && inner->type == XML_ELEMENT_NODE);
    value = xmlGetNsProp(inner,
                         BAD_CAST "id", BAD_CAST "urn:inner");
    assert(value != NULL && strcmp((const char *)value, "1") == 0);
    xmlFree(value);
    xmlFreeDoc(doc);
    xmlFree(memory);
}

static void test_namespace_escaping(void) {
    static const char uri[] = "urn:a&\"b\tc\nd";
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr ns;
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    ns = xmlNewNs(root, BAD_CAST uri, BAD_CAST "p");
    assert(ns != NULL);
    xmlSetNs(root, ns);
    assert(xmlNewProp(root, BAD_CAST "nil", NULL) != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory,
        "xmlns:p=\"urn:a&amp;&quot;b&#9;c&#10;d\"") != NULL);
    assert(strstr((const char *)memory, "nil=\"\"") != NULL);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root->ns != NULL && strcmp((const char *)root->ns->href, uri) == 0);
    xmlFreeDoc(doc);
    xmlFree(memory);
}

static void test_empty_document(void) {
    static const char expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size == (int)sizeof(expected) - 1);
    assert(memcmp(memory, expected, (size_t)size) == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void expect_invalid_namespace_binding(const char *href,
                                             const char *prefix) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNewNs(root, BAD_CAST href, BAD_CAST prefix) != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);
}

static void test_empty_namespace_attribute_rejection(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr empty;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    empty = xmlNewNs(root, BAD_CAST "", NULL);
    assert(empty != NULL);
    assert(xmlNewNsProp(root, empty, BAD_CAST "a", BAD_CAST "1") != NULL);
    assert(xmlNewProp(root, BAD_CAST "a", BAD_CAST "2") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    empty = xmlNewNs(root, BAD_CAST "", NULL);
    assert(empty != NULL);
    assert(xmlNewNsProp(root, empty, BAD_CAST "xmlns", BAD_CAST "value") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);
}

static void test_safer_rejections(void) {
    xmlDocPtr doc;
    xmlNodePtr root;
    xmlNodePtr child;
    xmlNsPtr first;
    xmlNsPtr second;

    doc = xmlNewDoc(BAD_CAST "1.1");
    assert(doc != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNewProp(root, BAD_CAST "xmlns", BAD_CAST "urn:invalid") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    expect_invalid_namespace_binding("urn:invalid", "xmlns");
    expect_invalid_namespace_binding("http://www.w3.org/2000/xmlns/", "p");
    expect_invalid_namespace_binding("http://www.w3.org/XML/1998/namespace",
                                     "p");
    expect_invalid_namespace_binding("", "p");
    expect_invalid_namespace_binding("urn:invalid", "");
    expect_invalid_namespace_binding("urn:invalid", "bad prefix");

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNewNs(root, BAD_CAST "urn:invalid",
                    BAD_CAST "xml") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "bad name");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    {
        static const char control[] = {1, 0};
        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "r");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, xmlNewText(BAD_CAST control)) != NULL);
        expect_rejected(doc, "UTF-8");
        xmlFreeDoc(doc);
    }

    {
        static const char malformed[] = {(char)0xc3, 0};
        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "r");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, xmlNewText(BAD_CAST malformed)) != NULL);
        expect_rejected(doc, "UTF-8");
        xmlFreeDoc(doc);
    }

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    first = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "p");
    second = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "q");
    assert(first != NULL && second != NULL);
    assert(xmlNewNsProp(root, first, BAD_CAST "a", BAD_CAST "1") != NULL);
    assert(xmlNewNsProp(root, second, BAD_CAST "a", BAD_CAST "2") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    {
        static const char source[] = "<r xmlns='urn:default'><child/></r>";
        doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    }
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    child = root->children;
    assert(child != NULL && child->type == XML_ELEMENT_NODE);
    xmlSetNs(child, NULL);
    expect_rejected(doc, "UTF-8");
    assert(xmlNewNs(child, BAD_CAST "", NULL) != NULL);
    {
        xmlChar *memory = NULL;
        int size = 0;
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory != NULL && strstr((const char *)memory,
                                        "xmlns=\"\"") != NULL);
        xmlFree(memory);
    }
    xmlFreeDoc(doc);
}

static void test_borrowed_namespace_scope(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr borrowed;
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    borrowed = xmlNewNs(NULL, BAD_CAST "urn:borrowed", BAD_CAST "p");
    assert(borrowed != NULL);
    xmlSetNs(root, borrowed);
    expect_rejected(doc, "UTF-8");
    assert(root->ns == borrowed && root->nsDef == NULL);
    assert(xmlNewNs(root, BAD_CAST "urn:borrowed", BAD_CAST "p") != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory,
                                    "xmlns:p=\"urn:borrowed\"") != NULL);
    assert(root->ns == borrowed);
    xmlFree(memory);
    xmlFreeDoc(doc);
    xmlFreeNs(borrowed);
}

static void test_large_text_and_depth(void) {
#ifdef XML3_DEVELOPMENT_TEST
    size_t length = 256;
    const size_t depth = 32;
#else
    size_t length = 70 * 1024;
    const size_t depth = 12000;
#endif
    char *large = malloc(length + 1);
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr cursor;
    xmlChar *memory = NULL;
    int size = 0;
    size_t i;

    assert(large != NULL && doc != NULL && root != NULL);
    memset(large, '&', length);
    large[length] = 0;
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, xmlNewText(BAD_CAST large)) != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    {
        static const char prefix[] =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<r>";
        static const char suffix[] = "</r>\n";
        size_t expected_size = strlen(prefix) + length * 5 + strlen(suffix);
        assert(size == (int)expected_size && memory[size] == 0);
        assert(strstr((const char *)memory, "&amp;&amp;&amp;") != NULL);
        {
            xmlDocPtr reparsed = xmlReadMemory((const char *)memory, size,
                                                NULL, NULL, 0);
            xmlChar *content;
            assert(reparsed != NULL);
            content = xmlNodeGetContent(xmlDocGetRootElement(reparsed));
            assert(content != NULL);
            {
                size_t content_length;
                for (content_length = 0;
                     content_length <= length && content[content_length] != 0;
                     ++content_length)
                {
                }
                assert(content_length == length);
            }
            assert(memcmp(content, large, length) == 0);
            xmlFree(content);
            xmlFreeDoc(reparsed);
        }
    }
    xmlFree(memory);
    xmlFreeDoc(doc);
    free(large);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "n");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    cursor = root;
    for (i = 1; i < depth; ++i) {
        xmlNodePtr next = xmlNewNode(NULL, BAD_CAST "n");
        assert(next != NULL && xmlAddChild(cursor, next) == next);
        cursor = next;
    }
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(size > (int)(depth * 7) && memory[size] == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

#if !defined(XML3_DEVELOPMENT_TEST) && !defined(XML3_NO_OOM_TEST)
static void test_serialization_oom(void) {
    static const char input[] = "<r a='v'>text</r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1,
                                  NULL, NULL, 0);
    xmlNodePtr root;
    xmlChar *memory = NULL;
    int size = 19;
    int injected;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root != NULL && root->properties != NULL);
    xml3_oom_enable(0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    injected = xml3_oom_was_injected();
    xml3_oom_disable();
    assert(injected && memory == NULL && size == 0);
    assert(strcmp((const char *)root->properties->children->content, "v") == 0);
    assert(strcmp((const char *)root->children->content, "text") == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory, "<r a=\"v\">text</r>"));
    xmlFree(memory);
    xmlFreeDoc(doc);
}
#endif

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--misc") == 0) {
        test_constructed_comments_and_pi();
        test_misc_rejections_and_lifetime();
        puts("comment and PI construction tests passed");
        return 0;
    }
    test_shared_lexical_cases();
    test_round_trip();
    test_constructed_comments_and_pi();
    test_misc_rejections_and_lifetime();
    test_pointer_contracts();
    test_namespace_shadowing();
    test_namespace_escaping();
    test_empty_document();
    test_safer_rejections();
    test_empty_namespace_attribute_rejection();
    test_borrowed_namespace_scope();
    test_large_text_and_depth();
#if !defined(XML3_DEVELOPMENT_TEST) && !defined(XML3_NO_OOM_TEST)
    test_serialization_oom();
#endif
    puts("UTF-8 memory serialization tests passed");
    return 0;
}

#else
int main(void) {
    test_shared_lexical_cases();
    test_constructed_comments_and_pi();
    puts("reference UTF-8 serializer lexical case passed");
    return 0;
}
#endif
