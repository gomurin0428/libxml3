#ifdef XML3_REFERENCE_VERSION
#include <libxml/parser.h>
#include <libxml/tree.h>
#else
#include <libxml3.h>
#endif

#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    NAME_LIMIT = 50000,
    VALUE_LIMIT = 10000000,
    HUGE_NAME = 50001,
    HUGE_VALUE = 10000001
};

static int quiet_options(void) {
    return XML_PARSE_NOERROR | XML_PARSE_NOWARNING | XML_PARSE_NONET;
}

static xmlDocPtr parse(const char *input, size_t length, int options) {
    assert(length <= (size_t)INT_MAX);
    return xmlReadMemory(input, (int)length, NULL, NULL, options);
}

static void test_name_limits(void) {
    const size_t local_length = NAME_LIMIT;
    char *xml = (char *)malloc(local_length + 16);
    assert(xml);
    memcpy(xml, "<r><", 4);
    memset(xml + 4, 'n', local_length);
    memcpy(xml + 4 + local_length, "/></r>", 7);
    xmlDocPtr doc = parse(xml, local_length + 10, quiet_options());
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && root->children);
    assert(strlen((const char *)root->children->name) == local_length);
    xmlFreeDoc(doc);
    free(xml);

    xml = (char *)malloc(local_length + 64);
    assert(xml);
    const char *normal_prefix = "<r xmlns:p='urn:p'><p:";
    size_t normal_prefix_length = strlen(normal_prefix);
    memcpy(xml, normal_prefix, normal_prefix_length);
    memset(xml + normal_prefix_length, 'n', local_length);
    const char *normal_suffix = "/></r>";
    size_t normal_suffix_length = strlen(normal_suffix);
    memcpy(xml + normal_prefix_length + local_length, normal_suffix,
           normal_suffix_length);
    doc = parse(xml, normal_prefix_length + local_length + normal_suffix_length,
                quiet_options());
    assert(doc);
    root = xmlDocGetRootElement(doc);
    assert(root && root->children && root->children->ns);
    assert(strlen((const char *)root->children->name) == local_length);
    xmlFreeDoc(doc);
    free(xml);

    xml = (char *)malloc(local_length + 17);
    assert(xml);
    memcpy(xml, "<r><", 4);
    memset(xml + 4, 'n', local_length + 1);
    memcpy(xml + 5 + local_length, "/></r>", 6);
    assert(!parse(xml, local_length + 11, quiet_options()));
    free(xml);

    xml = (char *)malloc(HUGE_NAME + 32);
    assert(xml);
    const char *prefix = "<r xmlns:p='urn:p'><p:";
    size_t prefix_length = strlen(prefix);
    memcpy(xml, prefix, prefix_length);
    memset(xml + prefix_length, 'n', HUGE_NAME);
    const char *suffix = "/></r>";
    size_t suffix_length = strlen(suffix);
    memcpy(xml + prefix_length + HUGE_NAME, suffix, suffix_length);
    size_t length = prefix_length + HUGE_NAME + suffix_length;
    doc = parse(xml, length, quiet_options() | XML_PARSE_HUGE);
    assert(doc);
    root = xmlDocGetRootElement(doc);
    assert(root && root->children && root->children->ns);
    assert(strlen((const char *)root->children->name) == HUGE_NAME);
    assert(xmlStrEqual(root->children->ns->prefix, BAD_CAST "p"));
    xmlFreeDoc(doc);
    free(xml);

    xml = (char *)malloc((size_t)NAME_LIMIT + 32);
    assert(xml);
    memcpy(xml, "<r><?", 5);
    memset(xml + 5, 'p', NAME_LIMIT);
    memcpy(xml + 5 + NAME_LIMIT, "?></r>", 6);
    length = 5 + NAME_LIMIT + 6;
    doc = parse(xml, length, quiet_options());
    assert(doc);
    root = xmlDocGetRootElement(doc);
    assert(root && root->children);
    assert(root->children->type == XML_PI_NODE);
    assert(strlen((const char *)root->children->name) == NAME_LIMIT);
    xmlFreeDoc(doc);
    free(xml);
}

static char *make_text_doc(size_t value_length, size_t *length) {
    char *xml = (char *)malloc(value_length + 8);
    assert(xml);
    memcpy(xml, "<r>", 3);
    memset(xml + 3, 'v', value_length);
    memcpy(xml + 3 + value_length, "</r>", 5);
    *length = value_length + 7;
    return xml;
}

static void check_text_length(size_t value_length, int options) {
    size_t length;
    char *xml = make_text_doc(value_length, &length);
    xmlDocPtr doc = parse(xml, length, options);
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && root->children && root->children->type == XML_TEXT_NODE);
    xmlChar *content = xmlNodeGetContent(root);
    assert(content);
    assert(strlen((const char *)content) == value_length);
    assert(content[0] == 'v' && content[value_length - 1] == 'v');
    xmlFree(content);
    xmlFreeDoc(doc);
    free(xml);
}

static char *make_nested(unsigned depth, int self_closing, size_t *length) {
    size_t opens = self_closing ? depth - 1 : depth;
    size_t closes = self_closing ? depth - 1 : depth;
    size_t size = opens * 3 + (self_closing ? 4 : 0) + closes * 4;
    char *xml = (char *)malloc(size + 1);
    assert(xml);
    size_t cursor = 0;
    for (size_t i = 0; i < opens; ++i) {
        memcpy(xml + cursor, "<x>", 3);
        cursor += 3;
    }
    if (self_closing) {
        memcpy(xml + cursor, "<x/>", 4);
        cursor += 4;
    }
    for (size_t i = 0; i < closes; ++i) {
        memcpy(xml + cursor, "</x>", 4);
        cursor += 4;
    }
    xml[cursor] = '\0';
    *length = cursor;
    return xml;
}

static void check_depth(unsigned depth, int self_closing, int options,
                        int expected) {
    size_t length;
    char *xml = make_nested(depth, self_closing, &length);
    xmlDocPtr doc = parse(xml, length, options);
    assert((doc != NULL) == expected);
    if (doc) {
        xmlNodePtr node = xmlDocGetRootElement(doc);
        unsigned found = 0;
        while (node) {
            ++found;
            node = xmlFirstElementChild(node);
        }
        assert(found == depth);
        xmlFreeDoc(doc);
    }
    free(xml);
}

static void test_large_document_and_arena(void) {
    const size_t siblings = 4096;
    size_t length = 3 + siblings * 4 + 4;
    char *xml = (char *)malloc(length);
    assert(xml);
    size_t cursor = 0;
    memcpy(xml + cursor, "<r>", 3);
    cursor += 3;
    for (size_t i = 0; i < siblings; ++i) {
        memcpy(xml + cursor, "<x/>", 4);
        cursor += 4;
    }
    memcpy(xml + cursor, "</r>", 4);
    cursor += 4;
    assert(cursor == length);
    xmlDocPtr doc = parse(xml, length, quiet_options());
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && xmlChildElementCount(root) == siblings);
    xmlFreeDoc(doc);
    free(xml);

    const size_t part = 6000000;
    length = 3 + 3 + part + 4 + 3 + part + 4 + 4;
    xml = (char *)malloc(length);
    assert(xml);
    cursor = 0;
    memcpy(xml + cursor, "<r><a>", 6);
    cursor += 6;
    memset(xml + cursor, 'a', part);
    cursor += part;
    memcpy(xml + cursor, "</a><b>", 7);
    cursor += 7;
    memset(xml + cursor, 'b', part);
    cursor += part;
    memcpy(xml + cursor, "</b></r>", 8);
    cursor += 8;
    assert(cursor == length);
    doc = parse(xml, length, quiet_options());
    assert(doc);
    root = xmlDocGetRootElement(doc);
    assert(root && xmlChildElementCount(root) == 2);
    xmlChar *content = xmlNodeGetContent(root);
    assert(content && strlen((const char *)content) == part * 2);
    assert(content[0] == 'a' && content[part - 1] == 'a');
    assert(content[part] == 'b' && content[part * 2 - 1] == 'b');
    xmlFree(content);
    xmlFreeDoc(doc);
    free(xml);
}

static void test_huge_does_not_enable_features(void) {
    const char *malformed = "<r>";
    assert(!parse(malformed, strlen(malformed),
                  quiet_options() | XML_PARSE_HUGE));
#ifdef XML3_REFERENCE_VERSION
    const char *dtd = "<!DOCTYPE r [<!ENTITY x 'v'>]><r/>";
    xmlDocPtr doc = parse(dtd, strlen(dtd),
                          quiet_options() | XML_PARSE_HUGE);
    assert(doc);
    xmlFreeDoc(doc);
#else
    const char *dtd = "<!DOCTYPE r [<!ENTITY x 'v'>]><r/>";
    assert(!parse(dtd, strlen(dtd), quiet_options() | XML_PARSE_HUGE));
    assert(!parse("<r/>", 4, quiet_options() | XML_PARSE_HUGE | (1 << 4)));
#endif
}

int main(void) {
#ifdef XML3_REFERENCE_VERSION
    if (strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) != 0) {
        fprintf(stderr, "wrong reference runtime: %s\n", xmlParserVersion);
        return 1;
    }
#endif
    test_name_limits();
    check_text_length(VALUE_LIMIT, quiet_options());
    {
        size_t length;
        char *xml = make_text_doc(HUGE_VALUE, &length);
        assert(!parse(xml, length, quiet_options()));
        free(xml);
    }
    check_text_length(HUGE_VALUE, quiet_options() | XML_PARSE_HUGE);
    check_depth(256, 1, quiet_options(), 1);
    check_depth(256, 0, quiet_options(), 1);
    check_depth(257, 1, quiet_options(), 0);
    check_depth(257, 0, quiet_options(), 0);
    check_depth(2048, 1, quiet_options() | XML_PARSE_HUGE, 1);
    check_depth(2048, 0, quiet_options() | XML_PARSE_HUGE, 1);
    check_depth(2049, 1, quiet_options() | XML_PARSE_HUGE, 0);
    check_depth(2049, 0, quiet_options() | XML_PARSE_HUGE, 0);
    test_large_document_and_arena();
    test_huge_does_not_enable_features();
    puts("resource tests passed");
    return 0;
}
