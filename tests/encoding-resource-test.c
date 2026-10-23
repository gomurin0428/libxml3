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

static void put_le(unsigned char *buffer, size_t *position, uint16_t unit) {
    buffer[(*position)++] = (unsigned char)unit;
    buffer[(*position)++] = (unsigned char)(unit >> 8);
}

static unsigned char *make_text(size_t count, size_t *length) {
    static const char prefix[] = "<r>";
    static const char suffix[] = "</r>";
    size_t capacity = 2 + (sizeof(prefix) - 1 + count +
                           sizeof(suffix) - 1) * 2;
    unsigned char *buffer = malloc(capacity);
    size_t position = 0;
    assert(buffer != NULL);
    buffer[position++] = 0xff;
    buffer[position++] = 0xfe;
    for (size_t i = 0; i < sizeof(prefix) - 1; ++i)
        put_le(buffer, &position, (unsigned char)prefix[i]);
    for (size_t i = 0; i < count; ++i)
        put_le(buffer, &position, 0x0800);
    for (size_t i = 0; i < sizeof(suffix) - 1; ++i)
        put_le(buffer, &position, (unsigned char)suffix[i]);
    *length = position;
    assert(position <= capacity && position <= INT_MAX);
    return buffer;
}

static unsigned char *make_long_name(size_t count, size_t *length) {
    size_t capacity = 2 + (1 + count + 2) * 2;
    unsigned char *buffer = malloc(capacity);
    size_t position = 0;
    assert(buffer != NULL);
    buffer[position++] = 0xff;
    buffer[position++] = 0xfe;
    put_le(buffer, &position, '<');
    for (size_t i = 0; i < count; ++i)
        put_le(buffer, &position, 0x0800);
    put_le(buffer, &position, '/');
    put_le(buffer, &position, '>');
    *length = position;
    assert(position <= capacity && position <= INT_MAX);
    return buffer;
}

static xmlDocPtr parse(const unsigned char *input, size_t length, int options) {
    xmlResetLastError();
    return xmlReadMemory((const char *)input, (int)length, NULL, NULL,
                         XML_PARSE_NOERROR | XML_PARSE_NOWARNING | options);
}

static void check_text_value(size_t count, int options, int accepted) {
    size_t length;
    unsigned char *input = make_text(count, &length);
    xmlDocPtr doc = parse(input, length, options);
    if (accepted) {
        assert(doc != NULL);
        xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
        assert(content != NULL);
        assert(xmlStrlen(content) == (int)(count * 3));
        xmlFree(content);
        xmlFreeDoc(doc);
    } else {
        const xmlError *error = xmlGetLastError();
        assert(doc == NULL);
        assert(error != NULL);
        assert(error->code == 114);
    }
    free(input);
}

static void check_name_limit(size_t count, int options, int accepted) {
    size_t length;
    unsigned char *input = make_long_name(count, &length);
    xmlDocPtr doc = parse(input, length, options);
    if (accepted) {
        assert(doc != NULL);
        xmlFreeDoc(doc);
    } else {
        const xmlError *error = xmlGetLastError();
        assert(doc == NULL);
        assert(error != NULL);
#ifndef XML3_REFERENCE_TEST
        assert(error->code == 110);
#endif
    }
    free(input);
}

int main(void) {
    const size_t below_10m_characters = 3333333;
    const size_t above_10m_characters = 3333334;
    const size_t above_50k_name_characters = 16667;

    check_reference_version();
    check_text_value(below_10m_characters, 0, 1);
    check_text_value(above_10m_characters, 0, 0);
    check_text_value(above_10m_characters, XML_PARSE_HUGE, 1);
    check_name_limit(above_50k_name_characters, 0, 0);
    check_name_limit(above_50k_name_characters, XML_PARSE_HUGE, 1);
    puts("UTF-16 expanded resource limits passed");
    return 0;
}
