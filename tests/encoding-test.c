#ifdef XML3_REFERENCE_TEST
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#include <libxml/xmlversion.h>
#else
#include <libxml3.h>
#endif

#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
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

static int quiet_options(void) {
    return XML_PARSE_NOERROR | XML_PARSE_NOWARNING;
}

static xmlDocPtr parse_bytes(const unsigned char *input, size_t length,
                             const char *encoding, int options) {
    assert(length <= INT_MAX);
    return xmlReadMemory((const char *)input, (int)length, NULL, encoding,
                         quiet_options() | options);
}

static xmlDocPtr parse_reset(const unsigned char *input, size_t length,
                             const char *encoding, int options) {
    xmlResetLastError();
    return parse_bytes(input, length, encoding, options);
}

static void append_unit(unsigned char *output, size_t *position,
                        uint16_t value, int big_endian) {
    if (big_endian) {
        output[(*position)++] = (unsigned char)(value >> 8);
        output[(*position)++] = (unsigned char)value;
    } else {
        output[(*position)++] = (unsigned char)value;
        output[(*position)++] = (unsigned char)(value >> 8);
    }
}

static uint32_t next_utf8(const unsigned char **cursor) {
    uint32_t first = *(*cursor)++;
    if (first < 0x80)
        return first;
    if (first < 0xe0) {
        uint32_t value = (first & 0x1f) << 6;
        value |= *(*cursor)++ & 0x3f;
        return value;
    }
    if (first < 0xf0) {
        uint32_t value = (first & 0x0f) << 12;
        value |= (*(*cursor)++ & 0x3f) << 6;
        value |= *(*cursor)++ & 0x3f;
        return value;
    }
    uint32_t value = (first & 0x07) << 18;
    value |= (*(*cursor)++ & 0x3f) << 12;
    value |= (*(*cursor)++ & 0x3f) << 6;
    value |= *(*cursor)++ & 0x3f;
    return value;
}

static unsigned char *utf16_from_utf8(const char *input, int big_endian,
                                      int bom, size_t *output_length) {
    size_t input_length = strlen(input);
    unsigned char *output = malloc(input_length * 2 + 4);
    size_t position = 0;
    const unsigned char *cursor = (const unsigned char *)input;

    assert(output != NULL);
    if (bom) {
        output[position++] = big_endian ? 0xfe : 0xff;
        output[position++] = big_endian ? 0xff : 0xfe;
    }
    while (*cursor != 0) {
        uint32_t scalar = next_utf8(&cursor);
        if (scalar < 0x10000) {
            append_unit(output, &position, (uint16_t)scalar, big_endian);
        } else {
            scalar -= 0x10000;
            append_unit(output, &position,
                        (uint16_t)(0xd800 + (scalar >> 10)), big_endian);
            append_unit(output, &position,
                        (uint16_t)(0xdc00 + (scalar & 0x3ff)), big_endian);
        }
    }
    *output_length = position;
    return output;
}

static void assert_utf16_tree(int big_endian, int bom, const char *encoding) {
    const char *xml =
        "<\xf0\x90\x80\x80 xmlns:p='urn:one' "
        "p:\xf0\x90\x80\x80='\xe5\x80\xa4'>"
        "A\xc3\xa9\xe2\x82\xac\xf0\x9f\x98\x80"
        "</\xf0\x90\x80\x80>";
    const char *name = "\xf0\x90\x80\x80";
    const char *text = "A\xc3\xa9\xe2\x82\xac\xf0\x9f\x98\x80";
    size_t length;
    unsigned char *input = utf16_from_utf8(xml, big_endian, bom, &length);
    xmlDocPtr doc = parse_reset(input, length, encoding, 0);
    assert(doc != NULL);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root != NULL && strcmp((const char *)root->name, name) == 0);
    assert(xmlSearchNs(doc, root, BAD_CAST "p") != NULL);
    xmlChar *attribute =
        xmlGetNsProp(root, BAD_CAST name, BAD_CAST "urn:one");
    assert(attribute != NULL && strcmp((const char *)attribute, "\xe5\x80\xa4") == 0);
    xmlChar *content = xmlNodeGetContent(root);
    assert(content != NULL && strcmp((const char *)content, text) == 0);
    xmlFree(attribute);
    xmlFree(content);
    xmlFreeDoc(doc);
    free(input);
}

static void test_bomless_declarations(void) {
    const char *xml =
        "<?xml version='1.0' encoding='UTF-16'?>"
        "<r attr='value'>\xe6\x97\xa5</r>";
    for (int big_endian = 0; big_endian < 2; ++big_endian) {
        size_t length;
        unsigned char *input =
            utf16_from_utf8(xml, big_endian, 0, &length);
        xmlDocPtr doc = parse_reset(input, length, NULL, 0);
        assert(doc != NULL);
        xmlNodePtr root = xmlDocGetRootElement(doc);
        xmlChar *content = xmlNodeGetContent(root);
        assert(content != NULL && strcmp((const char *)content, "\xe6\x97\xa5") == 0);
        xmlFree(content);
        xmlFreeDoc(doc);
        free(input);
    }
}

static void test_empty_and_bom_only(void) {
    static const unsigned char empty[] = {0};
    static const unsigned char le_bom[] = {0xff, 0xfe};
    static const unsigned char be_bom[] = {0xfe, 0xff};
    assert(parse_reset(empty, 0, NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(parse_reset(le_bom, sizeof(le_bom), NULL, 0) == NULL);
    assert(parse_reset(be_bom, sizeof(be_bom), NULL, 0) == NULL);
}

static void check_double_bom(const unsigned char *single_bom,
                             size_t single_bom_length,
                             const unsigned char *double_bom,
                             size_t double_bom_length,
                             const char *encoding) {
    for (int explicit_encoding = 0; explicit_encoding < 2;
         ++explicit_encoding) {
        const char *requested = explicit_encoding ? encoding : NULL;
        xmlDocPtr doc = parse_reset(single_bom, single_bom_length,
                                    requested, 0);
        assert(doc != NULL);
        xmlFreeDoc(doc);

        doc = parse_reset(double_bom, double_bom_length, requested, 0);
        assert(doc == NULL);
        assert(xmlGetLastError() != NULL);
    }
}

static void test_double_bom(void) {
    static const unsigned char utf8_single[] =
        {0xef, 0xbb, 0xbf, '<', 'r', '/', '>'};
    static const unsigned char utf8_double[] =
        {0xef, 0xbb, 0xbf, 0xef, 0xbb, 0xbf, '<', 'r', '/', '>'};
    static const unsigned char utf16le_single[] =
        {0xff, 0xfe, 0x3c, 0x00, 0x72, 0x00, 0x2f, 0x00, 0x3e, 0x00};
    static const unsigned char utf16le_double[] =
        {0xff, 0xfe, 0xff, 0xfe, 0x3c, 0x00, 0x72, 0x00, 0x2f, 0x00,
         0x3e, 0x00};
    static const unsigned char utf16be_single[] =
        {0xfe, 0xff, 0x00, 0x3c, 0x00, 0x72, 0x00, 0x2f, 0x00, 0x3e};
    static const unsigned char utf16be_double[] =
        {0xfe, 0xff, 0xfe, 0xff, 0x00, 0x3c, 0x00, 0x72, 0x00, 0x2f,
         0x00, 0x3e};

    check_double_bom(utf8_single, sizeof(utf8_single), utf8_double,
                     sizeof(utf8_double), "UTF-8");
    check_double_bom(utf16le_single, sizeof(utf16le_single), utf16le_double,
                     sizeof(utf16le_double), "UTF-16LE");
    check_double_bom(utf16be_single, sizeof(utf16be_single), utf16be_double,
                     sizeof(utf16be_double), "UTF-16BE");
}

static void test_malformed_utf16(void) {
    static const char valid[] = "<r/>";
    size_t base_length;
    unsigned char *base = utf16_from_utf8(valid, 0, 1, &base_length);
    unsigned char *odd = malloc(base_length + 1);
    unsigned char *lone_high = malloc(base_length + 2);
    unsigned char *lone_low = malloc(base_length + 2);
    unsigned char *bad_pair = malloc(base_length + 4);
    assert(odd != NULL && lone_high != NULL && lone_low != NULL && bad_pair != NULL);

    memcpy(odd, base, base_length);
    odd[base_length] = 'x';
    assert(parse_reset(odd, base_length + 1, NULL, 0) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_IO);
    assert(xmlGetLastError()->code == 81);
    assert(xmlGetLastError()->line == 1 && xmlGetLastError()->int2 == 1);
#endif

    memcpy(lone_high, base, base_length);
    lone_high[base_length] = 0x00;
    lone_high[base_length + 1] = 0xd8;
    assert(parse_reset(lone_high, base_length + 2, NULL, 0) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->domain == XML_FROM_IO);
    assert(xmlGetLastError()->code == 81);
#endif

    memcpy(lone_low, base, base_length);
    lone_low[base_length] = 0x00;
    lone_low[base_length + 1] = 0xdc;
    assert(parse_reset(lone_low, base_length + 2, NULL, 0) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->domain == XML_FROM_IO);
    assert(xmlGetLastError()->code == 81);
#endif

    memcpy(bad_pair, base, base_length);
    bad_pair[base_length] = 0x00;
    bad_pair[base_length + 1] = 0xd8;
    bad_pair[base_length + 2] = 0x41;
    bad_pair[base_length + 3] = 0x00;
    assert(parse_reset(bad_pair, base_length + 4, NULL, 0) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->domain == XML_FROM_IO);
    assert(xmlGetLastError()->code == 81);
#endif

    free(bad_pair);
    free(lone_low);
    free(lone_high);
    free(odd);
    free(base);
}

static void test_declaration_precedence_and_endian_conflict(void) {
    const char *declares_utf16 =
        "<?xml version='1.0' encoding='UTF-16'?><r/>";
    size_t length;
    unsigned char *utf8 = (unsigned char *)declares_utf16;
    xmlDocPtr doc = parse_reset(utf8, strlen(declares_utf16), "UTF-8", 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);

    const char *bad_name =
        "<?xml version='1.0' encoding='8UTF'?><r/>";
    doc = parse_reset((const unsigned char *)bad_name, strlen(bad_name),
                      "UTF-8", 0);
    assert(doc == NULL);
    assert(xmlGetLastError() != NULL);
#ifdef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->code == 57);
#else
    assert(xmlGetLastError()->code == 79);
#endif

    doc = parse_reset((const unsigned char *)declares_utf16,
                      strlen(declares_utf16), NULL, 0);
    assert(doc == NULL);
    assert(xmlGetLastError() != NULL);
#ifdef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->code == 57);
#else
    assert(xmlGetLastError()->code == 81);
#endif

    static const unsigned char unknown_input[] = "<r/>";
    doc = parse_reset(unknown_input, sizeof(unknown_input) - 1, "UTF-32", 0);
#ifdef XML3_REFERENCE_TEST
    assert(doc == NULL);
#else
    assert(doc == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == 32);
    assert(xmlGetLastError()->line == 0 && xmlGetLastError()->int2 == 0);
#endif

    const char *be_xml = "<r/>";
    unsigned char *be = utf16_from_utf8(be_xml, 1, 1, &length);
    doc = parse_reset(be, length, "UTF-16", 0);
    assert(doc == NULL);
    assert(xmlGetLastError() != NULL);
    free(be);
}

static void test_warning_lifecycle(void) {
    static const unsigned char warning_input[] =
        {0xef, 0xbb, 0xbf, '<', '?', 'x', 'm', 'l', ' ',
         'v', 'e', 'r', 's', 'i', 'o', 'n', '=', '\'', '1', '.', '0',
         '\'', ' ', 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g', '=', '\'',
         'U', 'T', 'F', '-', '1', '6', '\'', '?', '>', '<', 'r', '/', '>'};
    xmlDocPtr doc = parse_reset(warning_input, sizeof(warning_input), NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == 113);
    assert(xmlGetLastError()->level == XML_ERR_WARNING);
#endif

    doc = parse_bytes((const unsigned char *)"<r/>", 4, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlGetLastError() != NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->code == 113);
#endif

    xmlResetLastError();
    assert(xmlGetLastError() == NULL);
    doc = parse_reset(warning_input, sizeof(warning_input), NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    doc = parse_bytes((const unsigned char *)"<r></s>", 7, NULL, 0);
    assert(doc == NULL);
    assert(xmlGetLastError() != NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError()->code == XML_ERR_TAG_NAME_MISMATCH);
#endif
}

static void test_source_ownership(void) {
    size_t length;
    unsigned char *input =
        utf16_from_utf8("<r attr='kept'>owned</r>", 0, 1, &length);
    unsigned char *original = malloc(length);
    assert(original != NULL);
    memcpy(original, input, length);
    xmlDocPtr doc = parse_reset(input, length, NULL, 0);
    assert(doc != NULL);
    assert(memcmp(input, original, length) == 0);
    memset(input, 0, length);
    free(input);
    free(original);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlChar *attribute = xmlGetProp(root, BAD_CAST "attr");
    xmlChar *content = xmlNodeGetContent(root);
    assert(attribute != NULL && strcmp((const char *)attribute, "kept") == 0);
    assert(content != NULL && strcmp((const char *)content, "owned") == 0);
    xmlFree(attribute);
    xmlFree(content);
    xmlFreeDoc(doc);
}

int main(void) {
    check_reference_version();
    assert_utf16_tree(0, 1, NULL);
    assert_utf16_tree(1, 1, NULL);
    assert_utf16_tree(0, 0, "uTf-16lE");
    assert_utf16_tree(1, 0, "UTF-16BE");
    test_bomless_declarations();
    test_empty_and_bom_only();
    test_double_bom();
    test_malformed_utf16();
    test_declaration_precedence_and_endian_conflict();
    test_warning_lifecycle();
    test_source_ownership();
    puts("UTF-16 integration tests passed");
    return 0;
}
