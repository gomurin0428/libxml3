#include <libxml3.h>
#include <assert.h>
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static void expect_null(const char *buffer, int size, int options) {
    assert(xmlReadMemory(buffer, size, NULL, NULL, options) == NULL);
}

static void expect_status(const char *buffer, int size, int expected) {
    int status = -1;
    xmlDocPtr doc = xml3ReadMemory(buffer, size, &status);
    assert((doc != NULL) == (expected == XML3_STATUS_OK));
    assert(status == expected);
    if (doc) xmlFreeDoc(doc);
}

static void test_dom_and_ownership(void) {
    const char input[] =
        "<?xml version=\"1.0\"?><r a=\"A&amp;B\"><x>one&amp;two</x>"
        "<![CDATA[raw]]><!--note--><?pi data?></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, "UTF-8",
                                  XML_PARSE_NONET | XML_PARSE_NOERROR |
                                      XML_PARSE_NOWARNING);
    assert(doc != NULL);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root != NULL && root->type == XML_ELEMENT_NODE);
    assert(root->parent == (xmlNodePtr)doc);
    assert(root->content == NULL);
    assert(xmlChildElementCount(root) == 1);
    assert(xmlFirstElementChild(root) != NULL);
    assert(xmlNextElementSibling(xmlFirstElementChild(root)) == NULL);
    assert(xmlStrEqual(root->name, (const xmlChar *)"r"));
    assert(xmlStrcmp(root->name, (const xmlChar *)"r") == 0);
    assert(xmlStrlen(root->name) == 1);

    xmlAttrPtr attr = xmlHasProp(root, (const xmlChar *)"a");
    assert(attr != NULL && attr->type == XML_ATTRIBUTE_NODE);
    assert(attr->children != NULL && attr->children->type == XML_TEXT_NODE);
    xmlChar *prop = xmlGetProp(root, (const xmlChar *)"a");
    assert(prop != NULL && strcmp((const char *)prop, "A&B") == 0);
    xmlFree(prop);

    xmlChar *content = xmlNodeGetContent(root);
    assert(content != NULL && strcmp((const char *)content, "one&tworaw") == 0);
    xmlFree(content);

    xmlNodePtr child = root->children;
    assert(child != NULL && child->type == XML_ELEMENT_NODE);
    xmlChar *child_content = xmlNodeGetContent(child);
    assert(child_content != NULL);
    xmlFree(child_content);
    assert(child->next != NULL && child->next->type == XML_CDATA_SECTION_NODE);
    assert(child->next->name == NULL);
    assert(child->next->next != NULL &&
           child->next->next->type == XML_COMMENT_NODE);
    assert(strcmp((const char *)child->next->next->name, "comment") == 0);
    assert(child->next->next->next != NULL &&
           child->next->next->next->type == XML_PI_NODE);
    assert(strcmp((const char *)child->next->next->next->name, "pi") == 0);
    xmlFreeDoc(doc);

    char mutable_input[] = "<copy>owned</copy>";
    doc = xmlReadMemory(mutable_input, (int)strlen(mutable_input), NULL, NULL, 0);
    assert(doc != NULL);
    memset(mutable_input, 'z', strlen(mutable_input));
    root = xmlDocGetRootElement(doc);
    assert(strcmp((const char *)root->name, "copy") == 0);
    content = xmlNodeGetContent(root);
    assert(content != NULL && strcmp((const char *)content, "owned") == 0);
    xmlFree(content);
    xmlFreeDoc(doc);
}

static void test_rejection_and_boundaries(void) {
    const char good[] = "<r/>";
    expect_status(good, (int)strlen(good), XML3_STATUS_OK);
    expect_status("<r>", 3, XML3_STATUS_MALFORMED);
    expect_status("<r/><s/>", 8, XML3_STATUS_MALFORMED);
    expect_status("<r a='1' a='2'/>", 16, XML3_STATUS_MALFORMED);
    expect_status("<r xmlns:x='u'/>", 16, XML3_STATUS_UNSUPPORTED);
    expect_status("<r>&bogus;</r>", 14, XML3_STATUS_MALFORMED);
    expect_status("<r>&#x110000;</r>", 17, XML3_STATUS_MALFORMED);
    expect_status("<r>&#0;</r>", (int)strlen("<r>&#0;</r>"),
                  XML3_STATUS_MALFORMED);
    expect_status("<r>&#xD800;</r>", (int)strlen("<r>&#xD800;</r>"),
                  XML3_STATUS_MALFORMED);
    expect_status("<r>&", (int)strlen("<r>&"), XML3_STATUS_MALFORMED);
    expect_status("<r>&amp", (int)strlen("<r>&amp"), XML3_STATUS_MALFORMED);
    expect_status("<!DOCTYPE r [<!ENTITY x 'x'>]><r>&x;</r>",
                  (int)strlen("<!DOCTYPE r [<!ENTITY x 'x'>]><r>&x;</r>"),
                  XML3_STATUS_UNSUPPORTED);
    expect_status("<!DOCTYPE r SYSTEM 'file:///etc/passwd'><r/>",
                  (int)strlen("<!DOCTYPE r SYSTEM 'file:///etc/passwd'><r/>"),
                  XML3_STATUS_UNSUPPORTED);
    expect_status("<!DOCTYPE r [<!ENTITY a '1234567890'>"
                  "<!ENTITY b '&a;&a;&a;&a;&a;&a;&a;&a;'>]><r>&b;</r>",
                  (int)strlen("<!DOCTYPE r [<!ENTITY a '1234567890'>"
                  "<!ENTITY b '&a;&a;&a;&a;&a;&a;&a;&a;'>]><r>&b;</r>"),
                  XML3_STATUS_UNSUPPORTED);

    expect_null(NULL, 0, 0);
    expect_null(NULL, -1, 0);
    expect_null(NULL, 1, 0);
    expect_null(good, 0, 0);
    expect_null(good, -1, 0);
    expect_null(good, 65537, 0);
    expect_null(good, 4, 1);
    expect_null(good, 4, 128);
    expect_null(good, 4, 4096);
    expect_null(good, 4, 2048 | 128);
    assert(xmlReadMemory(good, 4, NULL, "UTF-16", 0) == NULL);
    xmlDocPtr doc = xmlReadMemory(good, 4, NULL, "utf-8", 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    doc = xmlReadMemory(good, 4, NULL, "UTF-8", 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    doc = xmlReadDoc((const xmlChar *)good, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    doc = xmlParseMemory(good, 4);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    doc = xmlParseDoc((const xmlChar *)good);
    assert(doc != NULL);
    xmlFreeDoc(doc);

    {
        char *oversize = (char *)malloc(65537);
        assert(oversize != NULL);
        memset(oversize, 'x', 65537);
        expect_status(oversize, 65536, XML3_STATUS_MALFORMED);
        int status = -1;
        assert(xml3ReadMemory(oversize, 65537, &status) == NULL);
        assert(status == XML3_STATUS_INVALID_ARGUMENT);
        free(oversize);
    }
}

static char *make_nested(unsigned depth, size_t *length) {
    const size_t width = 7;
    char *xml = (char *)malloc((size_t)depth * width + 1);
    assert(xml != NULL);
    size_t cursor = 0;
    for (unsigned i = 0; i < depth; ++i) {
        memcpy(xml + cursor, "<x>", 3);
        cursor += 3;
    }
    for (unsigned i = 0; i < depth; ++i) {
        memcpy(xml + cursor, "</x>", 4);
        cursor += 4;
    }
    xml[cursor] = '\0';
    *length = cursor;
    return xml;
}

static void test_exact_resource_limits(void) {
    const size_t max_bytes = 65536;
    char *large = (char *)malloc(max_bytes + 1);
    assert(large != NULL);
    memcpy(large, "<r>", 3);
    memset(large + 3, 'a', max_bytes - 7);
    memcpy(large + max_bytes - 4, "</r>", 4);
    int status = -1;
    xmlDocPtr doc = xml3ReadMemory(large, (int)max_bytes, &status);
    assert(doc != NULL);
    assert(status == XML3_STATUS_OK);
    xmlFreeDoc(doc);
    free(large);

    size_t length = 0;
    char *xml = make_nested(64, &length);
    expect_status(xml, (int)length, XML3_STATUS_OK);
    free(xml);
    xml = make_nested(65, &length);
    expect_status(xml, (int)length, XML3_STATUS_LIMIT_EXCEEDED);
    free(xml);

    const char *fragment = "<x a='v'/>";
    const char *ending = "</r>";
    const size_t child_bytes = strlen(fragment);
    const size_t exact_length = 3 + 1023 * child_bytes + strlen("<t/>") +
                                strlen(ending);
    xml = (char *)malloc(exact_length + child_bytes + 1);
    assert(xml != NULL);
    size_t cursor = 0;
    memcpy(xml + cursor, "<r>", 3);
    cursor += 3;
    for (size_t i = 0; i < 1023; ++i) {
        memcpy(xml + cursor, fragment, child_bytes);
        cursor += child_bytes;
    }
    memcpy(xml + cursor, "<t/>", 4);
    cursor += 4;
    memcpy(xml + cursor, ending, strlen(ending));
    cursor += strlen(ending);
    assert(cursor == exact_length);
    expect_status(xml, (int)cursor, XML3_STATUS_OK);

    cursor = 3;
    for (size_t i = 0; i < 1023; ++i) {
        memcpy(xml + cursor, fragment, child_bytes);
        cursor += child_bytes;
    }
    memcpy(xml + cursor, "<t/><u/>", 8);
    cursor += 8;
    memcpy(xml + cursor, ending, strlen(ending));
    cursor += strlen(ending);
    expect_status(xml, (int)cursor, XML3_STATUS_LIMIT_EXCEEDED);
    free(xml);
}

static void test_invalid_utf8(void) {
    const char invalid[] = {'<', 'r', '>', (char)0xc0, (char)0x80,
                            '<', '/', 'r', '>'};
    expect_status(invalid, (int)sizeof(invalid), XML3_STATUS_MALFORMED);
}

static void test_input_validation(void) {
    int status = -1;
    assert(xml3ReadMemory(NULL, 0, &status) == NULL);
    assert(status == XML3_STATUS_INVALID_ARGUMENT);
    assert(xml3ReadMemory(NULL, -1, &status) == NULL);
    assert(status == XML3_STATUS_INVALID_ARGUMENT);
    assert(xml3ReadMemory(NULL, 65537, &status) == NULL);
    assert(status == XML3_STATUS_INVALID_ARGUMENT);
    xmlDocPtr doc = xml3ReadMemory("<r/>", 4, &status);
    assert(doc != NULL);
    assert(status == XML3_STATUS_OK);
    xmlFreeDoc(doc);
    doc = xmlParseDoc((const xmlChar *)"<r/>");
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlParseDoc(NULL) == NULL);

    char *bounded = (char *)malloc(65536);
    assert(bounded != NULL);
    memcpy(bounded, "<r/>", 4);
    memset(bounded + 4, ' ', 65531);
    bounded[65535] = '\0';
    doc = xmlReadDoc((const xmlChar *)bounded, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    memset(bounded, 'x', 65536);
    assert(xmlReadDoc((const xmlChar *)bounded, NULL, NULL, 0) == NULL);
    free(bounded);
}

static void test_strings_and_cycles(void) {
    const xmlChar *a = (const xmlChar *)"abc";
    const xmlChar *b = (const xmlChar *)"abd";
    assert(xmlStrEqual(a, a) == 1);
    assert(xmlStrEqual(a, b) == 0);
    assert(xmlStrEqual(NULL, NULL) == 1);
    assert(xmlStrEqual(NULL, a) == 0);
    assert(xmlStrcmp(a, b) < 0);
    assert(xmlStrcmp(NULL, a) < 0);
    assert(xmlStrcmp(a, NULL) > 0);
    assert(xmlStrlen(a) == 3);
    assert(xmlStrlen(NULL) == 0);
    for (int i = 0; i < 1000; ++i) {
        const char input[] = "<r a='v'><x/></r>";
        xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        xmlFreeDoc(doc);
    }
}

static void test_long_c_strings(void) {
    const size_t former_limit = 4u * 65536u + 16u;
    const size_t length = former_limit + 8u;
    char *left = (char *)malloc(length + 1);
    char *right = (char *)malloc(length + 1);
    assert(left != NULL && right != NULL);
    memset(left, 'm', length);
    left[length] = '\0';
    memcpy(right, left, length + 1);

    assert(xmlStrEqual((const xmlChar *)left, (const xmlChar *)right) == 1);
    assert(xmlStrcmp((const xmlChar *)left, (const xmlChar *)right) == 0);
    assert(xmlStrlen((const xmlChar *)left) == (int)length);

    right[former_limit + 1] = 'n';
    assert(xmlStrEqual((const xmlChar *)left, (const xmlChar *)right) == 0);
    assert(xmlStrcmp((const xmlChar *)left, (const xmlChar *)right) < 0);
    assert(xmlStrlen((const xmlChar *)right) == (int)length);

    free(left);
    free(right);
}

int main(void) {
    xmlInitParser();
    test_dom_and_ownership();
    test_rejection_and_boundaries();
    test_exact_resource_limits();
    test_invalid_utf8();
    test_input_validation();
    test_strings_and_cycles();
    test_long_c_strings();
    xmlCleanupParser();
    puts("api tests passed");
    return 0;
}
