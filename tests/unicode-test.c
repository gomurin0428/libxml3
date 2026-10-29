#define _GNU_SOURCE
#ifdef XML3_REFERENCE_VERSION
#include <libxml/parser.h>
#include <libxml/tree.h>
#else
#include <libxml3.h>
#endif
#include <libxml/entities.h>
#include <libxml/chvalid.h>
#include <libxml/parserInternals.h>
#include <libxml/uri.h>
#include <libxml/valid.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#if defined(__unix__)
#include <sys/mman.h>
#include <unistd.h>
#endif

typedef int (*bounded_compare_fn)(const xmlChar *, const xmlChar *, int);
static void check_uri_path(const char *input, const char *expected) {
    char buffer[128];
    size_t length = strlen(input);
    assert(length + 3 <= sizeof(buffer));
    memset(buffer, '~', sizeof(buffer));
    memcpy(buffer + 1, input, length + 1);
    assert(xmlNormalizeURIPath(buffer + 1) == 0);
    assert(strcmp(buffer + 1, expected) == 0);
    assert(buffer[0] == '~' && buffer[length + 2] == '~');
    assert(xmlNormalizeURIPath(buffer + 1) == 0);
    assert(strcmp(buffer + 1, expected) == 0);
}

static void test_uri_paths(void) {
    static const struct { const char *input, *expected, *reference; } cases[] = {
        {"", "", NULL}, {".", "", NULL}, {"..", "..", NULL},
        {"./", "", NULL}, {"../", "../", NULL}, {"/", "/", NULL},
        {"//", "/", NULL}, {"///a//b///", "/a/b/", NULL},
        {"a/.", "a/", NULL}, {"a/..", "", NULL}, {"a/b/..", "a/", NULL},
        {"a/../", "", NULL}, {"a/b/../../c", "c", NULL},
        {"a/../../b", "../b", NULL}, {"../a/../b", "../b", NULL},
        {"..//../a", "../../a", "../a"}, {"/../a", "/a", "/../a"},
        {"/a/../../b", "/b", "/../b"}, {"//../a", "/a", NULL},
        {"./a/./b/../c/", "a/c/", NULL}, {"a/.../b", "a/.../b", NULL},
        {"a/%2e%2e/b", "a/%2e%2e/b", NULL}, {"a\\..\\b", "a\\..\\b", NULL},
        {"a?x/../b", "b", NULL}, {"%2f/../b", "b", NULL},
        {"/a//./../b/.", "/b/", NULL}, {"../../a/../b", "../../b", NULL},
        {"..//..", "../..", "../"}, {"/..", "/", "/.."},
        {"a//.", "a/", NULL}, {"a//..", "", NULL},
        {"\xe9\xa1\x94/../ok", "ok", NULL}
    };
    assert(xmlNormalizeURIPath(NULL) == -1);
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        const char *expected = cases[i].expected;
#ifdef XML3_REFERENCE_VERSION
        if (cases[i].reference) expected = cases[i].reference;
#endif
        check_uri_path(cases[i].input, expected);
    }
    for (unsigned value = 1; value <= 255; ++value) {
        char input[] = {(char)value, 0};
        check_uri_path(input, value == '.' ? "" : input);
    }
    char *path = xmlURIUnescapeString("dir/./%E9%A1%94/../leaf", 0, NULL);
    assert(path && xmlNormalizeURIPath(path) == 0);
    xmlChar *escaped = xmlURIEscapeStr(BAD_CAST path, BAD_CAST "/");
    xmlFree(path);
    assert(escaped && strcmp((const char *)escaped, "dir/leaf") == 0);
    path = xmlURIUnescapeString((const char *)escaped, 0, NULL);
    xmlFree(escaped);
    assert(path && strcmp(path, "dir/leaf") == 0);
    xmlFree(path);
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky);
    int code = sticky->code;
    check_uri_path("a/../b", "b");
    assert(xmlNormalizeURIPath(NULL) == -1);
    assert(xmlGetLastError() == sticky && sticky->code == code);
    xmlResetLastError();
#if defined(__unix__)
    long page_size = sysconf(_SC_PAGESIZE);
    assert(page_size > 0);
    size_t page = (size_t)page_size;
    char *mapping = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    char *guard = mapping + page;
    assert(mprotect(guard, page, PROT_NONE) == 0);
    guard[-1] = 0;
    assert(mprotect(mapping, page, PROT_READ) == 0);
    assert(xmlNormalizeURIPath(guard - 1) == 0);
    assert(mprotect(mapping, page, PROT_READ | PROT_WRITE) == 0);
    const char *inputs[] = {".", "..", "a/..", "a/.", "//", "./\xff"};
    const char *outputs[] = {"", "..", "", "a/", "/", "\xff"};
    for (size_t i = 0; i < sizeof(inputs) / sizeof(inputs[0]); ++i) {
        size_t length = strlen(inputs[i]);
        char *input = guard - length - 1;
        memcpy(input, inputs[i], length + 1);
        assert(xmlNormalizeURIPath(input) == 0);
        assert(strcmp(input, outputs[i]) == 0);
    }
    assert(munmap(mapping, page * 2) == 0);
#endif
}

static void check_uri_unescape(const char *input, int length,
                               const char *expected, size_t size) {
    char *result = xmlURIUnescapeString(input, length, NULL);
    assert(result && result != input);
    assert(memcmp(result, expected, size) == 0 && result[size] == 0);
    xmlFree(result);
    char target[128], inplace[128];
    size_t span = length > 0 ? (size_t)length : strlen(input);
    assert(size + 3 <= sizeof(target) && span + 2 <= sizeof(inplace));
    memset(target, '~', sizeof(target));
    result = xmlURIUnescapeString(input, length, target + 1);
    assert(result == target + 1);
    assert(memcmp(result, expected, size) == 0 && result[size] == 0);
    assert(target[0] == '~' && target[size + 2] == '~');
    memset(inplace, '~', sizeof(inplace));
    memcpy(inplace, input, span);
    inplace[span] = 0;
    result = xmlURIUnescapeString(inplace, length, inplace);
    assert(result == inplace);
    assert(memcmp(result, expected, size) == 0 && result[size] == 0);
    assert(inplace[span + 1] == '~');
}

static void test_uri_unescaping(void) {
    assert(!xmlURIUnescapeString(NULL, INT_MAX, NULL));
    check_uri_unescape("", 0, "", 0);
    check_uri_unescape("a%20b+%2f%aF", -1, "a b+/\xaf", 6);
    check_uri_unescape("%", 0, "%", 1);
    check_uri_unescape("%A", 0, "%A", 2);
    check_uri_unescape("%G1%1G%%41", 0, "%G1%1G%A", 8);
    check_uri_unescape("%41ignored", 3, "A", 1);
    check_uri_unescape("%41", 1, "%", 1);
    check_uri_unescape("%41", 2, "%4", 2);
    check_uri_unescape("%00tail", 0, "\0tail", 5);
    const char binary[] = {'a', 0, '%', '4', '2', 'c'};
    check_uri_unescape(binary, sizeof(binary), "a\0Bc", 4);
    check_uri_unescape(binary, INT_MIN, "a", 1);
    const char *hex[] = {"0123456789ABCDEF", "0123456789abcdef"};
    for (unsigned value = 0; value <= 255; ++value) {
        for (unsigned casing = 0; casing < 2; ++casing) {
            char input[] = {'%', hex[casing][value >> 4], hex[casing][value & 15], 0};
            char expected[] = {(char)value};
            check_uri_unescape(input, 3, expected, 1);
        }
    }
    xmlChar raw[256];
    for (unsigned i = 0; i < 255; ++i) raw[i] = (xmlChar)(i + 1);
    raw[255] = 0;
    xmlChar *encoded = xmlURIEscapeStr(raw, NULL);
    assert(encoded);
    char *decoded = xmlURIUnescapeString((const char *)encoded, 0, NULL);
    xmlFree(encoded);
    assert(decoded && memcmp(decoded, raw, sizeof(raw)) == 0);
    xmlFree(decoded);
    char overlap[32] = "xa%42c";
    assert(xmlURIUnescapeString(overlap + 1, 0, overlap) == overlap);
    assert(strcmp(overlap, "aBc") == 0);
#ifndef XML3_REFERENCE_VERSION
    strcpy(overlap, "a%42c");
    assert(xmlURIUnescapeString(overlap, 0, overlap + 1) == overlap + 1);
    assert(strcmp(overlap + 1, "aBc") == 0);
#endif
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky);
    int error_code = sticky->code;
    check_uri_unescape("a%20b", 0, "a b", 3);
    assert(!xmlURIUnescapeString(NULL, 0, overlap));
    assert(xmlGetLastError() == sticky && sticky->code == error_code);
    xmlResetLastError();
#if defined(__unix__)
    long page_size = sysconf(_SC_PAGESIZE);
    assert(page_size > 0);
    size_t page = (size_t)page_size;
    char *mapping = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    char *guard = mapping + page;
    assert(mprotect(guard, page, PROT_NONE) == 0);
    assert(!xmlURIUnescapeString(NULL, 0, guard));
    guard[-1] = 0;
    check_uri_unescape(guard - 1, 0, "", 0);
    memcpy(guard - 3, "%41", 3);
    check_uri_unescape(guard - 3, 3, "A", 1);
    assert(xmlURIUnescapeString(guard - 3, 3, guard - 2) == guard - 2);
    assert(guard[-2] == 'A' && guard[-1] == 0);
    guard[-1] = '%';
    check_uri_unescape(guard - 1, 1, "%", 1);
    memcpy(guard - 2, "%4", 2);
    check_uri_unescape(guard - 2, 2, "%4", 2);
#ifndef XML3_REFERENCE_VERSION
    assert(!xmlURIUnescapeString(guard, INT_MAX, guard));
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
#endif
    assert(munmap(mapping, page * 2) == 0);
#endif
}

static void check_uri_escape(const xmlChar *input, const xmlChar *exceptions,
                             const xmlChar *expected) {
    xmlChar *escaped = xmlURIEscapeStr(input, exceptions);
    assert(escaped && escaped != input && escaped != exceptions);
    assert(strcmp((const char *)escaped, (const char *)expected) == 0);
    xmlFree(escaped);
}

static void test_uri_escaping(void) {
    assert(!xmlURIEscapeStr(NULL, BAD_CAST "/"));
    check_uri_escape(BAD_CAST "", NULL, BAD_CAST "");
    check_uri_escape(BAD_CAST "a b/%20?x=1&y=2", NULL,
                     BAD_CAST "a%20b%2F%2520%3Fx%3D1%26y%3D2");
    check_uri_escape(BAD_CAST "a b/%20?x=1&y=2", BAD_CAST "/?=&%",
                     BAD_CAST "a%20b/%20?x=1&y=2");
    check_uri_escape(BAD_CAST "\xe9\xa1\x94/\xf0\x9f\x99\x82", NULL,
                     BAD_CAST "%E9%A1%94%2F%F0%9F%99%82");
    const char *hex = "0123456789ABCDEF";
    for (unsigned value = 1; value <= 255; ++value) {
        xmlChar input[2] = {(xmlChar)value, 0};
        xmlChar escaped[4] = {'%', (xmlChar)hex[value >> 4],
                              (xmlChar)hex[value & 15], 0};
        int safe = (value >= 'a' && value <= 'z') ||
                   (value >= 'A' && value <= 'Z') ||
                   (value >= '0' && value <= '9') ||
                   strchr("-._~!*'()@", (int)value) != NULL;
        check_uri_escape(input, NULL, safe ? input : escaped);
        check_uri_escape(input, input, input);
        check_uri_escape(input, BAD_CAST "", safe ? input : escaped);
    }
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky);
    int error_code = sticky->code;
    check_uri_escape(BAD_CAST "a b", NULL, BAD_CAST "a%20b");
    assert(!xmlURIEscapeStr(NULL, NULL));
    assert(xmlGetLastError() == sticky && sticky->code == error_code);
    xmlResetLastError();
#if defined(__unix__)
    long page_size = sysconf(_SC_PAGESIZE);
    assert(page_size > 0);
    size_t page = (size_t)page_size;
    xmlChar *mapping = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    xmlChar *guard = mapping + page;
    assert(mprotect(guard, page, PROT_NONE) == 0);
    guard[-1] = 0;
    check_uri_escape(guard - 1, guard, BAD_CAST "");
    guard[-2] = 'a';
    check_uri_escape(guard - 2, guard, BAD_CAST "a");
    assert(!xmlURIEscapeStr(NULL, guard));
    guard[-2] = '/';
    check_uri_escape(guard - 2, NULL, BAD_CAST "%2F");
    check_uri_escape(BAD_CAST "/?", guard - 2, BAD_CAST "/%3F");
    guard[-1] = '/';
    check_uri_escape(BAD_CAST "/", guard - 1, BAD_CAST "/");
    assert(munmap(mapping, page * 2) == 0);
#endif
    xmlChar *input = xmlStrdup(BAD_CAST "dir/\xe9\xa1\x94 a?x=1&y=2");
    xmlChar *exceptions = xmlStrdup(BAD_CAST "/?=&");
    assert(input && exceptions);
    xmlChar *escaped = xmlURIEscapeStr(input, exceptions);
    assert(escaped);
    xmlFree(input);
    xmlFree(exceptions);
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
    assert(doc && xmlSetProp(xmlDocGetRootElement(doc), BAD_CAST "href", escaped));
    xmlFree(escaped);
    xmlChar *serialized = NULL;
    int size = 0;
    xmlDocDumpMemory(doc, &serialized, &size);
    assert(serialized && size > 0);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)serialized, size, NULL, NULL, 0);
    xmlFree(serialized);
    assert(doc);
    xmlChar *value = xmlGetProp(xmlDocGetRootElement(doc), BAD_CAST "href");
    xmlFreeDoc(doc);
    assert(value && strcmp((const char *)value, "dir/%E9%A1%94%20a?x=1&y=2") == 0);
    char *decoded = xmlURIUnescapeString((const char *)value, 0, NULL);
    xmlFree(value);
    assert(decoded && strcmp(decoded, "dir/\xe9\xa1\x94 a?x=1&y=2") == 0);
    xmlFree(decoded);
}

static const bounded_compare_fn bounded_comparisons[] = {xmlStrncmp, xmlStrncasecmp};
typedef const xmlChar *(*substring_fn)(const xmlChar *, const xmlChar *);
static const substring_fn substring_searches[] = {xmlStrstr, xmlStrcasestr};

typedef int (*character_class_fn)(unsigned int);
#ifdef XML3_REFERENCE_VERSION
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
static const character_class_fn character_classes[] = {
    xmlIsChar, xmlIsBlank, xmlIsDigit, xmlIsExtender, xmlIsIdeographic, xmlIsPubidChar,
    xmlIsBaseChar, xmlIsCombining
};
#ifdef XML3_REFERENCE_VERSION
#pragma GCC diagnostic pop
#endif

static int expected_in_character_ranges(unsigned int code,
        const unsigned int ranges[][2], size_t count) {
    if (count == 0 || code > ranges[count - 1][1])
        return 0;
    for (size_t i = 0; i < count; ++i) {
        if (code < ranges[i][0])
            return 0;
        if (code <= ranges[i][1])
            return 1;
    }
    return 0;
}

#ifdef XML3_REFERENCE_VERSION
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
static int copy_char_compat(xmlChar *out, int code) {
    return xmlCopyChar(-1, out, code);
}

typedef int (*utf8_writer_fn)(xmlChar *, int);
static const utf8_writer_fn utf8_writers[] = {xmlCopyCharMultiByte, copy_char_compat};

static void test_utf8_writing(void) {
    for (size_t writer = 0; writer < 2; ++writer) {
        for (int code = 0; code <= 0x10ffff; ++code) {
            xmlChar bytes[6];
            memset(bytes, 0xa5, sizeof(bytes));
            if (code >= 0xd800 && code <= 0xdfff) {
#ifndef XML3_REFERENCE_VERSION
                assert(utf8_writers[writer](bytes + 1, code) == 0);
                for (size_t i = 0; i < sizeof(bytes); ++i)
                    assert(bytes[i] == 0xa5);
#endif
                continue;
            }
            int expected = code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
            int count = utf8_writers[writer](bytes + 1, code);
            assert(count == expected);
            assert(bytes[0] == 0xa5);
            for (size_t i = (size_t)count + 1; i < sizeof(bytes); ++i)
                assert(bytes[i] == 0xa5);
            int available = count;
            assert(xmlGetUTF8Char(bytes + 1, &available) == code);
            assert(available == count);
        }
        const int invalid[] = {INT_MIN, -1, 0x110000, INT_MAX};
        for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
            xmlChar bytes[4] = {0xa5, 0xa5, 0xa5, 0xa5};
            assert(utf8_writers[writer](bytes, invalid[i]) == 0);
            for (size_t j = 0; j < sizeof(bytes); ++j)
                assert(bytes[j] == 0xa5);
        }
        assert(utf8_writers[writer](NULL, 0x1f642) == 0);
#if defined(__unix__)
        long page_size = sysconf(_SC_PAGESIZE);
        assert(page_size > 0);
        size_t page = (size_t)page_size;
        xmlChar *mapping = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
                               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        assert(mapping != MAP_FAILED);
        xmlChar *guard = mapping + page;
        assert(mprotect(guard, page, PROT_NONE) == 0);
        const int edges[] = {0, 0x7f, 0x80, 0x7ff, 0x800, 0xd7ff,
                             0xe000, 0xffff, 0x10000, 0x10ffff};
        for (size_t i = 0; i < sizeof(edges) / sizeof(edges[0]); ++i) {
            int code = edges[i];
            int width = code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
            guard[-width - 1] = 0xa5;
            assert(utf8_writers[writer](guard - width, code) == width);
            assert(guard[-width - 1] == 0xa5);
        }
        for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i)
            assert(utf8_writers[writer](guard, invalid[i]) == 0);
#ifndef XML3_REFERENCE_VERSION
        assert(utf8_writers[writer](guard, 0xd800) == 0);
        assert(utf8_writers[writer](guard, 0xdfff) == 0);
#endif
        assert(munmap(mapping, page * 2) == 0);
#endif
        xmlChar source[64] = "<r>";
        int length = 3;
        const int content[] = {0x03a9, 0x9854, 0x1f642};
        for (size_t i = 0; i < sizeof(content) / sizeof(content[0]); ++i) {
            int written = utf8_writers[writer](source + length, content[i]);
            assert(written > 0);
            length += written;
        }
        memcpy(source + length, "</r>", 5);
        xmlDocPtr doc = xmlReadMemory((const char *)source, length + 4, NULL, NULL, 0);
        assert(doc);
        xmlChar *value = xmlNodeGetContent(xmlDocGetRootElement(doc));
        assert(value);
        xmlFreeDoc(doc);
        memset(source, 0, sizeof(source));
        assert(strcmp((const char *)value, "\xce\xa9\xe9\xa1\x94\xf0\x9f\x99\x82") == 0);
        assert(xmlUTF8Strlen(value) == 3);
        xmlFree(value);
    }
    const int ignored_lengths[] = {INT_MIN, -1, 0, 1, 4, INT_MAX};
    for (size_t i = 0; i < sizeof(ignored_lengths) / sizeof(ignored_lengths[0]); ++i) {
        xmlChar bytes[5] = {0xa5, 0xa5, 0xa5, 0xa5, 0xa5};
        assert(xmlCopyChar(ignored_lengths[i], bytes, 0x1f642) == 4);
        assert(memcmp(bytes, "\xf0\x9f\x99\x82", 4) == 0);
        assert(bytes[4] == 0xa5);
    }
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky);
    for (size_t writer = 0; writer < 2; ++writer) {
        xmlChar bytes[4];
        assert(utf8_writers[writer](bytes, 'x') == 1);
        assert(utf8_writers[writer](bytes, -1) == 0);
        assert(utf8_writers[writer](NULL, 'x') == 0);
        assert(xmlGetLastError() == sticky);
    }
    xmlResetLastError();
}
#ifdef XML3_REFERENCE_VERSION
#pragma GCC diagnostic pop
#endif

static void test_character_range_groups(void) {
    static const xmlChSRange short_ranges[] = {
        {0, 0}, {9, 13}, {65, 90}, {0xd800, 0xdfff}, {0xffff, 0xffff}
    };
    static const xmlChLRange long_ranges[] = {
        {0x10000, 0x10000}, {0x10fffe, 0x110001},
        {0x80000000u, 0x80000004u}, {UINT_MAX, UINT_MAX}
    };
    xmlChRangeGroup group = {5, 4, short_ranges, long_ranges};
    for (unsigned int code = 0; code <= 0x110002; ++code) {
        int expected = 0;
        if (code < 0x10000) {
            for (size_t i = 0; i < 5; ++i)
                if (code >= short_ranges[i].low && code <= short_ranges[i].high)
                    expected = 1;
        } else {
            for (size_t i = 0; i < 4; ++i)
                if (code >= long_ranges[i].low && code <= long_ranges[i].high)
                    expected = 1;
        }
        assert(xmlCharInRange(code, &group) == expected);
    }
    assert(xmlCharInRange(0x7fffffffu, &group) == 0);
    assert(xmlCharInRange(0x80000000u, &group) == 1);
    assert(xmlCharInRange(0x80000002u, &group) == 1);
    assert(xmlCharInRange(0x80000005u, &group) == 0);
    assert(xmlCharInRange(UINT_MAX - 1, &group) == 0);
    assert(xmlCharInRange(UINT_MAX, &group) == 1);
    assert(xmlCharInRange(65, NULL) == 0);
    group.nbShortRange = group.nbLongRange = 0;
    group.shortRange = NULL;
    group.longRange = NULL;
    assert(xmlCharInRange(65, &group) == 0);
    assert(xmlCharInRange(0x10000, &group) == 0);
#ifndef XML3_REFERENCE_VERSION
    group.nbShortRange = group.nbLongRange = INT_MIN;
    assert(xmlCharInRange(65, &group) == 0);
    assert(xmlCharInRange(0x10000, &group) == 0);
    group.nbShortRange = group.nbLongRange = 1;
    assert(xmlCharInRange(65, &group) == 0);
    assert(xmlCharInRange(0x10000, &group) == 0);
#endif
#if defined(__unix__)
    {
        long page_size = sysconf(_SC_PAGESIZE);
        assert(page_size > 0);
        size_t page = (size_t)page_size;
        unsigned char *mapping = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
                                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        assert(mapping != MAP_FAILED);
        unsigned char *guard = mapping + page;
        assert(mprotect(guard, page, PROT_NONE) == 0);
        xmlChSRange *short_edge = (xmlChSRange *)(guard - sizeof(xmlChSRange));
        *short_edge = (xmlChSRange){65, 90};
        group = (xmlChRangeGroup){1, INT_MAX, short_edge, (const xmlChLRange *)guard};
        assert(xmlCharInRange(65, &group) == 1);
        assert(xmlCharInRange(91, &group) == 0);
        xmlChLRange *long_edge = (xmlChLRange *)(guard - sizeof(xmlChLRange));
        *long_edge = (xmlChLRange){0x10000, UINT_MAX};
        group = (xmlChRangeGroup){INT_MAX, 1, (const xmlChSRange *)guard, long_edge};
        assert(xmlCharInRange(0x10000, &group) == 1);
        assert(xmlCharInRange(UINT_MAX, &group) == 1);
        group = (xmlChRangeGroup){0, 0, (const xmlChSRange *)guard,
                                 (const xmlChLRange *)guard};
        assert(xmlCharInRange(65, &group) == 0);
        assert(xmlCharInRange(0x10000, &group) == 0);
        assert(munmap(mapping, page * 2) == 0);
    }
#endif
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky != NULL);
    group = (xmlChRangeGroup){5, 4, short_ranges, long_ranges};
    assert(xmlCharInRange(65, &group) == 1);
    assert(xmlCharInRange(64, &group) == 0);
    assert(xmlCharInRange(65, NULL) == 0);
    assert(xmlGetLastError() == sticky);
    xmlResetLastError();
}

static void test_character_classes(void) {
    static const unsigned int base_ranges[][2] = {
        {0x41, 0x5a}, {0x61, 0x7a}, {0xc0, 0xd6}, {0xd8, 0xf6},
        {0xf8, 0xff}, {0x100, 0x131}, {0x134, 0x13e}, {0x141, 0x148},
        {0x14a, 0x17e}, {0x180, 0x1c3}, {0x1cd, 0x1f0}, {0x1f4, 0x1f5},
        {0x1fa, 0x217}, {0x250, 0x2a8}, {0x2bb, 0x2c1}, {0x386, 0x386},
        {0x388, 0x38a}, {0x38c, 0x38c}, {0x38e, 0x3a1}, {0x3a3, 0x3ce},
        {0x3d0, 0x3d6}, {0x3da, 0x3da}, {0x3dc, 0x3dc}, {0x3de, 0x3de},
        {0x3e0, 0x3e0}, {0x3e2, 0x3f3}, {0x401, 0x40c}, {0x40e, 0x44f},
        {0x451, 0x45c}, {0x45e, 0x481}, {0x490, 0x4c4}, {0x4c7, 0x4c8},
        {0x4cb, 0x4cc}, {0x4d0, 0x4eb}, {0x4ee, 0x4f5}, {0x4f8, 0x4f9},
        {0x531, 0x556}, {0x559, 0x559}, {0x561, 0x586}, {0x5d0, 0x5ea},
        {0x5f0, 0x5f2}, {0x621, 0x63a}, {0x641, 0x64a}, {0x671, 0x6b7},
        {0x6ba, 0x6be}, {0x6c0, 0x6ce}, {0x6d0, 0x6d3}, {0x6d5, 0x6d5},
        {0x6e5, 0x6e6}, {0x905, 0x939}, {0x93d, 0x93d}, {0x958, 0x961},
        {0x985, 0x98c}, {0x98f, 0x990}, {0x993, 0x9a8}, {0x9aa, 0x9b0},
        {0x9b2, 0x9b2}, {0x9b6, 0x9b9}, {0x9dc, 0x9dd}, {0x9df, 0x9e1},
        {0x9f0, 0x9f1}, {0xa05, 0xa0a}, {0xa0f, 0xa10}, {0xa13, 0xa28},
        {0xa2a, 0xa30}, {0xa32, 0xa33}, {0xa35, 0xa36}, {0xa38, 0xa39},
        {0xa59, 0xa5c}, {0xa5e, 0xa5e}, {0xa72, 0xa74}, {0xa85, 0xa8b},
        {0xa8d, 0xa8d}, {0xa8f, 0xa91}, {0xa93, 0xaa8}, {0xaaa, 0xab0},
        {0xab2, 0xab3}, {0xab5, 0xab9}, {0xabd, 0xabd}, {0xae0, 0xae0},
        {0xb05, 0xb0c}, {0xb0f, 0xb10}, {0xb13, 0xb28}, {0xb2a, 0xb30},
        {0xb32, 0xb33}, {0xb36, 0xb39}, {0xb3d, 0xb3d}, {0xb5c, 0xb5d},
        {0xb5f, 0xb61}, {0xb85, 0xb8a}, {0xb8e, 0xb90}, {0xb92, 0xb95},
        {0xb99, 0xb9a}, {0xb9c, 0xb9c}, {0xb9e, 0xb9f}, {0xba3, 0xba4},
        {0xba8, 0xbaa}, {0xbae, 0xbb5}, {0xbb7, 0xbb9}, {0xc05, 0xc0c},
        {0xc0e, 0xc10}, {0xc12, 0xc28}, {0xc2a, 0xc33}, {0xc35, 0xc39},
        {0xc60, 0xc61}, {0xc85, 0xc8c}, {0xc8e, 0xc90}, {0xc92, 0xca8},
        {0xcaa, 0xcb3}, {0xcb5, 0xcb9}, {0xcde, 0xcde}, {0xce0, 0xce1},
        {0xd05, 0xd0c}, {0xd0e, 0xd10}, {0xd12, 0xd28}, {0xd2a, 0xd39},
        {0xd60, 0xd61}, {0xe01, 0xe2e}, {0xe30, 0xe30}, {0xe32, 0xe33},
        {0xe40, 0xe45}, {0xe81, 0xe82}, {0xe84, 0xe84}, {0xe87, 0xe88},
        {0xe8a, 0xe8a}, {0xe8d, 0xe8d}, {0xe94, 0xe97}, {0xe99, 0xe9f},
        {0xea1, 0xea3}, {0xea5, 0xea5}, {0xea7, 0xea7}, {0xeaa, 0xeab},
        {0xead, 0xeae}, {0xeb0, 0xeb0}, {0xeb2, 0xeb3}, {0xebd, 0xebd},
        {0xec0, 0xec4}, {0xf40, 0xf47}, {0xf49, 0xf69}, {0x10a0, 0x10c5},
        {0x10d0, 0x10f6}, {0x1100, 0x1100}, {0x1102, 0x1103}, {0x1105, 0x1107},
        {0x1109, 0x1109}, {0x110b, 0x110c}, {0x110e, 0x1112}, {0x113c, 0x113c},
        {0x113e, 0x113e}, {0x1140, 0x1140}, {0x114c, 0x114c}, {0x114e, 0x114e},
        {0x1150, 0x1150}, {0x1154, 0x1155}, {0x1159, 0x1159}, {0x115f, 0x1161},
        {0x1163, 0x1163}, {0x1165, 0x1165}, {0x1167, 0x1167}, {0x1169, 0x1169},
        {0x116d, 0x116e}, {0x1172, 0x1173}, {0x1175, 0x1175}, {0x119e, 0x119e},
        {0x11a8, 0x11a8}, {0x11ab, 0x11ab}, {0x11ae, 0x11af}, {0x11b7, 0x11b8},
        {0x11ba, 0x11ba}, {0x11bc, 0x11c2}, {0x11eb, 0x11eb}, {0x11f0, 0x11f0},
        {0x11f9, 0x11f9}, {0x1e00, 0x1e9b}, {0x1ea0, 0x1ef9}, {0x1f00, 0x1f15},
        {0x1f18, 0x1f1d}, {0x1f20, 0x1f45}, {0x1f48, 0x1f4d}, {0x1f50, 0x1f57},
        {0x1f59, 0x1f59}, {0x1f5b, 0x1f5b}, {0x1f5d, 0x1f5d}, {0x1f5f, 0x1f7d},
        {0x1f80, 0x1fb4}, {0x1fb6, 0x1fbc}, {0x1fbe, 0x1fbe}, {0x1fc2, 0x1fc4},
        {0x1fc6, 0x1fcc}, {0x1fd0, 0x1fd3}, {0x1fd6, 0x1fdb}, {0x1fe0, 0x1fec},
        {0x1ff2, 0x1ff4}, {0x1ff6, 0x1ffc}, {0x2126, 0x2126}, {0x212a, 0x212b},
        {0x212e, 0x212e}, {0x2180, 0x2182}, {0x3041, 0x3094}, {0x30a1, 0x30fa},
        {0x3105, 0x312c}, {0xac00, 0xd7a3}
    };
    static const unsigned int combining_ranges[][2] = {
        {0x300, 0x345}, {0x360, 0x361}, {0x483, 0x486}, {0x591, 0x5a1},
        {0x5a3, 0x5b9}, {0x5bb, 0x5bd}, {0x5bf, 0x5bf}, {0x5c1, 0x5c2},
        {0x5c4, 0x5c4}, {0x64b, 0x652}, {0x670, 0x670}, {0x6d6, 0x6dc},
        {0x6dd, 0x6df}, {0x6e0, 0x6e4}, {0x6e7, 0x6e8}, {0x6ea, 0x6ed},
        {0x901, 0x903}, {0x93c, 0x93c}, {0x93e, 0x94c}, {0x94d, 0x94d},
        {0x951, 0x954}, {0x962, 0x963}, {0x981, 0x983}, {0x9bc, 0x9bc},
        {0x9be, 0x9be}, {0x9bf, 0x9bf}, {0x9c0, 0x9c4}, {0x9c7, 0x9c8},
        {0x9cb, 0x9cd}, {0x9d7, 0x9d7}, {0x9e2, 0x9e3}, {0xa02, 0xa02},
        {0xa3c, 0xa3c}, {0xa3e, 0xa3e}, {0xa3f, 0xa3f}, {0xa40, 0xa42},
        {0xa47, 0xa48}, {0xa4b, 0xa4d}, {0xa70, 0xa71}, {0xa81, 0xa83},
        {0xabc, 0xabc}, {0xabe, 0xac5}, {0xac7, 0xac9}, {0xacb, 0xacd},
        {0xb01, 0xb03}, {0xb3c, 0xb3c}, {0xb3e, 0xb43}, {0xb47, 0xb48},
        {0xb4b, 0xb4d}, {0xb56, 0xb57}, {0xb82, 0xb83}, {0xbbe, 0xbc2},
        {0xbc6, 0xbc8}, {0xbca, 0xbcd}, {0xbd7, 0xbd7}, {0xc01, 0xc03},
        {0xc3e, 0xc44}, {0xc46, 0xc48}, {0xc4a, 0xc4d}, {0xc55, 0xc56},
        {0xc82, 0xc83}, {0xcbe, 0xcc4}, {0xcc6, 0xcc8}, {0xcca, 0xccd},
        {0xcd5, 0xcd6}, {0xd02, 0xd03}, {0xd3e, 0xd43}, {0xd46, 0xd48},
        {0xd4a, 0xd4d}, {0xd57, 0xd57}, {0xe31, 0xe31}, {0xe34, 0xe3a},
        {0xe47, 0xe4e}, {0xeb1, 0xeb1}, {0xeb4, 0xeb9}, {0xebb, 0xebc},
        {0xec8, 0xecd}, {0xf18, 0xf19}, {0xf35, 0xf35}, {0xf37, 0xf37},
        {0xf39, 0xf39}, {0xf3e, 0xf3e}, {0xf3f, 0xf3f}, {0xf71, 0xf84},
        {0xf86, 0xf8b}, {0xf90, 0xf95}, {0xf97, 0xf97}, {0xf99, 0xfad},
        {0xfb1, 0xfb7}, {0xfb9, 0xfb9}, {0x20d0, 0x20dc}, {0x20e1, 0x20e1},
        {0x302a, 0x302f}, {0x3099, 0x3099}, {0x309a, 0x309a}
    };
    static const unsigned int digit_ranges[][2] = {
        {0x30, 0x39}, {0x660, 0x669}, {0x6f0, 0x6f9}, {0x966, 0x96f},
        {0x9e6, 0x9ef}, {0xa66, 0xa6f}, {0xae6, 0xaef}, {0xb66, 0xb6f},
        {0xbe7, 0xbef}, {0xc66, 0xc6f}, {0xce6, 0xcef}, {0xd66, 0xd6f},
        {0xe50, 0xe59}, {0xed0, 0xed9}, {0xf20, 0xf29}
    };
    static const unsigned int extender_ranges[][2] = {
        {0xb7, 0xb7}, {0x2d0, 0x2d1}, {0x387, 0x387}, {0x640, 0x640},
        {0xe46, 0xe46}, {0xec6, 0xec6}, {0x3005, 0x3005}, {0x3031, 0x3035},
        {0x309d, 0x309e}, {0x30fc, 0x30fe}
    };
    static const char pubid_chars[] =
        "\n\r abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        "-'()+,./:=?;!*#@$_%";
    xmlResetLastError();
    for (unsigned int code = 0; code <= 0x110000; ++code) {
        int blank = code == 9 || code == 10 || code == 13 || code == 32;
        int valid = code == 9 || code == 10 || code == 13 ||
            (code >= 0x20 && code <= 0xd7ff) ||
            (code >= 0xe000 && code <= 0xfffd) ||
            (code >= 0x10000 && code <= 0x10ffff);
        assert(character_classes[0](code) == valid);
        assert(character_classes[1](code) == blank);
        int digit = 0, extender = 0;
        for (size_t i = 0; i < sizeof(digit_ranges) / sizeof(*digit_ranges); ++i)
            digit |= code >= digit_ranges[i][0] && code <= digit_ranges[i][1];
        for (size_t i = 0; i < sizeof(extender_ranges) / sizeof(*extender_ranges); ++i)
            extender |= code >= extender_ranges[i][0] && code <= extender_ranges[i][1];
        int ideographic = code == 0x3007 || (code >= 0x3021 && code <= 0x3029) ||
            (code >= 0x4e00 && code <= 0x9fa5);
        int pubid = code != 0 && code < 128 && strchr(pubid_chars, (int)code) != NULL;
        assert(character_classes[2](code) == digit);
        assert(character_classes[3](code) == extender);
        assert(character_classes[4](code) == ideographic);
        assert(character_classes[5](code) == pubid);
        assert(character_classes[6](code) == expected_in_character_ranges(
            code, base_ranges, sizeof(base_ranges) / sizeof(*base_ranges)));
        assert(character_classes[7](code) == expected_in_character_ranges(
            code, combining_ranges, sizeof(combining_ranges) / sizeof(*combining_ranges)));
    }
    const unsigned int high[] = {0x1fffffu, UINT_MAX / 2, UINT_MAX / 2 + 1u, UINT_MAX};
    for (size_t i = 0; i < sizeof(high) / sizeof(*high); ++i) {
        for (size_t j = 0; j < sizeof(character_classes) / sizeof(*character_classes); ++j)
            assert(character_classes[j](high[i]) == 0);
    }
    assert(xmlValidateNCName(BAD_CAST "\xe0\xaf\xa6", 0) == 0);
    assert(xmlValidateNCName(BAD_CAST "\xe9\xbe\xa6", 0) == 0);
    assert(xmlValidateNCName(BAD_CAST "\xcd\xbf", 0) == 0);
    assert(xmlValidateNCName(BAD_CAST "a\xcd\x86", 0) == 0);
    assert(xmlGetLastError() == NULL);
}

static xmlChar *encode_chars(xmlDocPtr doc, const xmlChar *input, int entities) {
    return entities ? xmlEncodeEntitiesReentrant(doc, input)
                    : xmlEncodeSpecialChars(doc, input);
}

static void test_escaping(int entities) {
    static const char input[] = "<&>\"'\r\n\t名😀&amp;";
    const char *expected = entities
        ? "&lt;&amp;&gt;\"'&#13;\n\t&#x540D;&#x1F600;&amp;amp;"
        : "&lt;&amp;&gt;&quot;'&#13;\n\t名😀&amp;amp;";
    xmlResetLastError();
    assert(encode_chars(NULL, NULL, entities) == NULL);
    assert(xmlGetLastError() == NULL);
    xmlChar *escaped = encode_chars(NULL, BAD_CAST "", entities);
    assert(escaped && escaped[0] == 0);
    xmlFree(escaped);
    xmlDoc unused = {0};
    xmlDocPtr context = entities ? xmlNewDoc(NULL) : &unused;
    assert(context);
    escaped = encode_chars(context, BAD_CAST "", entities);
    assert(escaped && escaped[0] == 0);
    xmlFree(escaped);
    for (int byte = 1; byte < 128; ++byte) {
        if (byte < 32 && byte != '\r' && byte != '\n' && byte != '\t')
            continue;
        xmlChar one[] = {(xmlChar)byte, 0};
        const char *replacement = byte == '<' ? "&lt;" : byte == '>' ? "&gt;"
            : byte == '&' ? "&amp;" : byte == '"' && !entities ? "&quot;"
            : byte == '\r' ? "&#13;" : (const char *)one;
        escaped = encode_chars(NULL, one, entities);
        assert(escaped && strcmp((const char *)escaped, replacement) == 0);
        xmlFree(escaped);
    }
    xmlChar *source = xmlStrdup(BAD_CAST input);
    assert(source);
    escaped = encode_chars(context, source, entities);
    assert(escaped && escaped != source);
    assert(strcmp((const char *)escaped, expected) == 0);
    assert(strcmp((const char *)source, input) == 0);
    if (entities) xmlFreeDoc(context);
    xmlFree(source);
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNodeSetContent(root, escaped) == 0);
    xmlFree(escaped);
    xmlChar *output = NULL;
    int size = 0;
    xmlDocDumpMemoryEnc(doc, &output, &size, "UTF-8");
    assert(output && size > 0);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)output, size, NULL, NULL, 0);
    assert(doc);
    xmlFree(output);
    xmlChar *value = xmlNodeGetContent(xmlDocGetRootElement(doc));
    assert(value && strcmp((const char *)value, input) == 0);
    xmlFree(value);
    xmlFreeDoc(doc);

#ifndef XML3_REFERENCE_VERSION
    const char *invalid[] = {"\1", "\xc3", "\xc0\xaf", "\xed\xa0\x80",
                             "\xef\xbf\xbe", "\xf4\x90\x80\x80"};
    for (size_t i = 0; i < sizeof(invalid) / sizeof(*invalid); ++i) {
        xmlResetLastError();
        assert(encode_chars(NULL, BAD_CAST invalid[i], entities) == NULL);
        assert(xmlGetLastError() != NULL);
    }
    xmlResetLastError();
    if (entities) {
        assert(xmlEncodeEntitiesReentrant((xmlDocPtr)1, NULL) == NULL);
        assert(xmlGetLastError() == NULL);
        assert(xmlEncodeEntitiesReentrant((xmlDocPtr)1, BAD_CAST "") == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        root = xmlNewNode(NULL, BAD_CAST "r");
        assert(root);
        assert(xmlEncodeEntitiesReentrant((xmlDocPtr)root, BAD_CAST "x") == NULL);
        xmlFreeNode(root);
        escaped = xmlEncodeEntitiesReentrant(NULL, BAD_CAST "ok");
        assert(escaped && strcmp((const char *)escaped, "ok") == 0);
        xmlFree(escaped);
        xmlResetLastError();
    }
#endif
    if (entities) {
        const char *encoded = "<?xml version='1.0' encoding='UTF-8'?><r/>";
        doc = xmlReadMemory(encoded, (int)strlen(encoded), NULL, NULL, 0);
        assert(doc);
        escaped = xmlEncodeEntitiesReentrant(doc, BAD_CAST "名");
        assert(escaped);
#ifdef XML3_REFERENCE_VERSION
        assert(strcmp((const char *)escaped, "名") == 0);
#else
        assert(strcmp((const char *)escaped, "&#x540D;") == 0);
#endif
        xmlFreeDoc(doc);
        xmlFree(escaped);
    }
#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    mapping[page - 2] = '&';
    mapping[page - 1] = 0;
    escaped = encode_chars(NULL, BAD_CAST (mapping + page - 2), entities);
    assert(escaped && strcmp((const char *)escaped, "&amp;") == 0);
    xmlFree(escaped);
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif
}

static void test_string_slice(void) {
    xmlResetLastError();
    assert(!xmlStrsub(NULL, 0, 0));
    assert(!xmlGetLastError());
    assert(!xmlStrsub(NULL, -1, -1));
    assert(!xmlGetLastError());
    assert(!xmlStrsub(BAD_CAST "abc", -1, 1));
    assert(!xmlGetLastError());
    assert(!xmlStrsub(BAD_CAST "abc", 0, -1));
    assert(!xmlGetLastError());
    assert(!xmlStrsub(BAD_CAST "", 0, 0));
    assert(!xmlGetLastError());
    assert(!xmlStrsub(BAD_CAST "abc", 3, 0));
    assert(!xmlGetLastError());
    assert(!xmlStrsub(BAD_CAST "abc", 4, 1));
    assert(!xmlGetLastError());
    const xmlChar bytes[] = {'x', 'a', 0, 'b', 0xff, 0};
    xmlChar *copy = xmlStrsub(bytes, 1, 4);
    assert(copy && copy != bytes + 1 && !memcmp(copy, bytes + 1, 4) && copy[4] == 0);
    xmlFree(copy);
    assert(!xmlStrsub(bytes, 3, 1));
    copy = xmlStrsub(BAD_CAST "abc", 2, 0);
    assert(copy && copy[0] == 0);
    xmlFree(copy);
    copy = xmlStrsub(BAD_CAST "abc", 1, 2);
    assert(copy && xmlStrEqual(copy, BAD_CAST "bc"));
    xmlFree(copy);
    const xmlChar utf8[] = "名";
    copy = xmlStrsub(utf8, 1, 1);
    assert(copy && copy[0] == 0x90 && copy[1] == 0);
    xmlFree(copy);
    xmlChar *source = xmlCharStrdup("prefix:<r>名</r>");
    assert(source);
    const xmlChar *xml = xmlStrstr(source, BAD_CAST "<r>");
    assert(xml);
    copy = xmlStrsub(source, (int)(xml - source), xmlStrlen(xml));
    assert(copy);
    xmlFree(source);
    xmlDocPtr doc = xmlReadMemory((const char *)copy, xmlStrlen(copy), NULL, NULL, 0);
    xmlFree(copy);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    assert(content && xmlStrEqual(content, BAD_CAST "名"));
    xmlFree(content);
    xmlFreeDoc(doc);
}

static void test_qname_equality(void) {
    static const struct { const char *prefix, *name, *value; int equal; } cases[] = {
        {NULL, NULL, NULL, 1}, {NULL, NULL, "", 0}, {NULL, "", NULL, 0},
        {NULL, "", "", 1}, {NULL, "n", "n", 1}, {NULL, "n", "p:n", 0},
        {"p", NULL, "p:n", 0}, {"p", "n", NULL, 0}, {"p", NULL, NULL, 0},
        {"p", "n", "p:n", 1}, {"p", "n", "q:n", 0}, {"p", "n", "p:x", 0},
        {"p", "n", "p:nx", 0}, {"p", "n", "p:", 0}, {"p", "n", "p", 0},
        {"pq", "n", "p:n", 0}, {"p", "n", "pq:n", 0},
        {"p", "", "p:", 1}, {"", "n", ":n", 0}, {"", "", ":", 0},
        {"p:q", "n", "p:q:n", 1}, {"p", "n:x", "p:n:x", 1},
        {"P", "n", "p:n", 0}, {"p", "名", "p:名", 1},
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i)
        assert(xmlStrQEqual(BAD_CAST cases[i].prefix, BAD_CAST cases[i].name,
                            BAD_CAST cases[i].value) == cases[i].equal);
    xmlChar left[] = "name", right[] = "name";
    assert(xmlStrQEqual(NULL, left, right) == 1);
    right[3] = 'x';
    assert(xmlStrQEqual(NULL, left, right) == 0);
    xmlChar alias[] = "p:name";
    assert(xmlStrQEqual(BAD_CAST "p", alias + 2, alias) == 1);
    for (unsigned byte = 1; byte < 256; ++byte) {
        xmlChar prefix[] = {(xmlChar)byte, 0}, name[] = {(xmlChar)byte, 0};
        xmlChar value[] = {(xmlChar)byte, ':', (xmlChar)byte, 0};
        assert(xmlStrQEqual(prefix, name, value) == 1);
        value[2] ^= 1;
        assert(xmlStrQEqual(prefix, name, value) == 0);
    }
#ifndef XML3_REFERENCE_VERSION
    const xmlChar tail[] = {0, ':', 'n', 0};
    assert(xmlStrQEqual(BAD_CAST "", BAD_CAST "n", tail) == 0);
#endif
    const char *xml = "<p:名 xmlns:p=\"urn:test\"/>";
    xmlDocPtr doc = xmlReadMemory(xml, (int)strlen(xml), NULL, NULL, 0);
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && root->ns);
    assert(xmlStrQEqual(root->ns->prefix, root->name, BAD_CAST "p:名") == 1);
    xmlFreeDoc(doc);
}

static void test_byte_search(void) {
    xmlChar bytes[256];
    for (unsigned value = 1; value < 256; ++value)
        bytes[value - 1] = (xmlChar)value;
    bytes[255] = 0;
    for (unsigned value = 0; value < 256; ++value) {
        assert(!xmlStrchr(NULL, (xmlChar)value));
        assert(xmlStrchr(bytes, (xmlChar)value) == (value ? bytes + value - 1 : NULL));
    }
    xmlChar text[] = {'x', 'y', 'x', 0, 'z'};
    assert(xmlStrchr(text, 'x') == text);
    assert(xmlStrchr(text, 'y') == text + 1);
    assert(!xmlStrchr(text, 'z') && !xmlStrchr(text, 0));
    assert(!xmlStrchr(BAD_CAST "", 'x'));
    const xmlChar *borrowed = xmlStrchr(text, 'y');
    text[1] = 'q';
    assert(*borrowed == 'q');
    const xmlChar utf8[] = "名";
    assert(xmlStrchr(utf8, 0x90) == utf8 + 1);

    xmlChar *source = xmlCharStrdup("<r>名</r>");
    assert(source);
    const xmlChar *start = xmlStrchr(source, '>');
    assert(start);
    ++start;
    const xmlChar *end = xmlStrchr(start, '<');
    assert(end);
    xmlChar *copy = xmlStrndup(start, (int)(end - start));
    assert(copy);
    xmlFree(source);
    assert(xmlStrEqual(copy, BAD_CAST "名"));
    xmlFree(copy);
}

static void test_char_string_duplicates(void) {
    char source[] = {'a', (char)0xff, 0, 'z'};
    const xmlChar expected[] = {'a', 0xff, 0};
    assert(!xmlCharStrdup(NULL));
    assert(!xmlCharStrndup(NULL, 0) && !xmlCharStrndup(NULL, INT_MAX));
    assert(!xmlCharStrndup(source, -1) && !xmlCharStrndup(source, INT_MIN));
    xmlChar *copy = xmlCharStrdup(source);
    assert(copy && copy != (xmlChar *)source && memcmp(copy, expected, sizeof(expected)) == 0);
    source[0] = 'b';
    assert(copy[0] == 'a');
    source[0] = 'a';
    xmlFree(copy);
    for (int length = 0; length <= (int)sizeof(source); ++length) {
        size_t copied = length < 2 ? (size_t)length : 2;
        copy = xmlCharStrndup(source, length);
        assert(copy && copy != (xmlChar *)source);
        assert(memcmp(copy, expected, copied) == 0 && copy[copied] == 0);
        xmlFree(copy);
    }
    copy = xmlCharStrdup("");
    assert(copy && copy[0] == 0);
    xmlFree(copy);
    copy = xmlCharStrndup("", 7);
    assert(copy && copy[0] == 0);
    xmlFree(copy);
    copy = xmlCharStrdup("<r>名</r>");
    assert(copy);
    xmlDocPtr doc = xmlReadMemory((const char *)copy, xmlStrlen(copy), NULL, NULL, 0);
    xmlFree(copy);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    assert(content && strcmp((const char *)content, "名") == 0);
    xmlFree(content);
    xmlFreeDoc(doc);
}

static unsigned reference_case_map(unsigned value) {
    return (value >= 'A' && value <= 'Z') || value == '[' ? value + 32 : value;
}

static void test_substring_search(void) {
    static const struct { const char *text, *pattern; int position[2]; } cases[] = {
        {NULL, NULL, {-1, -1}}, {NULL, "x", {-1, -1}}, {"x", NULL, {-1, -1}},
        {"", "", {0, 0}}, {"", "x", {-1, -1}}, {"abc", "", {0, 0}},
        {"abc", "abc", {0, 0}}, {"abc", "bc", {1, 1}}, {"abc", "c", {2, 2}},
        {"ababa", "aba", {0, 0}}, {"aaab", "aab", {1, 1}},
        {"abc", "abcd", {-1, -1}}, {"abcd", "bd", {-1, -1}},
        {"xAbCabc", "abc", {4, 1}}, {"x[YZ", "{yz", {-1, 1}},
        {"A", "a", {-1, 0}}, {"x名y", "名", {1, 1}},
        {"x\0ab", "ab", {-1, -1}}, {"abcd", "bc\0z", {1, 1}},
    };
    for (size_t f = 0; f < sizeof(substring_searches) / sizeof(*substring_searches); ++f) {
        substring_fn search = substring_searches[f];
        for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
            const xmlChar *text = BAD_CAST cases[i].text;
            int position = cases[i].position[f];
            assert(search(text, BAD_CAST cases[i].pattern) ==
                   (position < 0 ? NULL : text + position));
        }
        xmlChar alias[] = "aaaab";
        assert(search(alias, alias + 2) == alias + 2);
        assert(search(alias, alias) == alias);
        xmlChar mutable[] = "left right";
        const xmlChar *borrowed = search(mutable, BAD_CAST "right");
        assert(borrowed == mutable + 5);
        mutable[5] = 'R';
        assert(*borrowed == 'R');
        const xmlChar utf8[] = "名";
        const xmlChar partial[] = {0x90, 0};
        assert(search(utf8, partial) == utf8 + 1);
    }
    for (unsigned a = 1; a < 256; ++a) {
        for (unsigned b = 1; b < 256; ++b) {
            xmlChar text[] = {(xmlChar)a, 0}, pattern[] = {(xmlChar)b, 0};
            assert(xmlStrstr(text, pattern) == (a == b ? text : NULL));
            assert(xmlStrcasestr(text, pattern) ==
                   (reference_case_map(a) == reference_case_map(b) ? text : NULL));
        }
    }
    xmlChar *source = xmlCharStrdup("<r>Sample</r>");
    assert(source);
    const xmlChar *start = xmlStrcasestr(source, BAD_CAST "sample");
    assert(start);
    const xmlChar *end = xmlStrstr(start, BAD_CAST "</r>");
    assert(end);
    xmlChar *copy = xmlStrndup(start, (int)(end - start));
    assert(copy);
    xmlFree(source);
    assert(xmlStrEqual(copy, BAD_CAST "Sample"));
    xmlFree(copy);
}

static void test_utf8_check(void) {
    xmlResetLastError();
    assert(xmlCheckUTF8(NULL) == 0);
    for (unsigned b = 0; b < 256; ++b) {
        const unsigned char text[] = {(unsigned char)b, 0};
        assert(xmlCheckUTF8(text) == (b < 128));
    }
    const char *valid[] = {
        "", "ASCII", "名é", "a\0\xff", "\x01", "\x7f", "\xc2\x80", "\xdf\xbf",
        "\xe0\xa0\x80", "\xed\x9f\xbf", "\xee\x80\x80", "\xef\xbf\xbe", "\xef\xbf\xbf",
        "\xf0\x90\x80\x80", "\xf4\x8f\xbf\xbf"
    };
    for (size_t i = 0; i < sizeof(valid) / sizeof(valid[0]); ++i)
        assert(xmlCheckUTF8((const unsigned char *)valid[i]) == 1);
    const char *invalid[] = {
        "\xc2", "\xe2\x82", "\xf0\x90\x80", "\xc2x", "\xe2\x28\xa1",
        "\xf0\x90x\x80", "\x80", "\xf8\x88\x80\x80\x80", "\xfe", "\xff"
    };
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i)
        assert(xmlCheckUTF8((const unsigned char *)invalid[i]) == 0);
    const char *noncanonical[] = {
        "\xc0\x80", "\xc1\xbf", "\xe0\x80\x80", "\xf0\x80\x80\x80",
        "\xed\xa0\x80", "\xed\xbf\xbf", "\xf4\x90\x80\x80", "\xf5\x80\x80\x80"
    };
#ifdef XML3_REFERENCE_VERSION
    const int permissive = 1;
#else
    const int permissive = 0;
#endif
    for (size_t i = 0; i < sizeof(noncanonical) / sizeof(noncanonical[0]); ++i)
        assert(xmlCheckUTF8((const unsigned char *)noncanonical[i]) == permissive);
    assert(!xmlGetLastError());
    const char source[] = "<r>名é</r>";
    assert(xmlCheckUTF8((const unsigned char *)source));
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content && xmlCheckUTF8(content));
    xmlFree(content);
}

static int utf8_char(const char *bytes, int available, int *width) {
    *width = available;
    return xmlGetUTF8Char((const unsigned char *)bytes, width);
}

static void test_utf8_char(void) {
    int len;
    assert(xmlGetUTF8Char(NULL, &len) == -1 && len == 0);
    assert(xmlGetUTF8Char(BAD_CAST "a", NULL) == -1);
    xmlResetLastError();
    for (unsigned b = 0; b < 128; ++b) {
        const unsigned char text[] = {(unsigned char)b, 0xff};
        len = 2;
        assert(xmlGetUTF8Char(text, &len) == (int)b && len == 1);
    }
    static const struct { const char *bytes; int available; int code; int width; } cases[] = {
        {"\0", 1, 0, 1}, {"A\xff", 1, 'A', 1}, {"\xc2\x80", 2, 0x80, 2},
        {"\xdf\xbf", 2, 0x7ff, 2}, {"\xc3\xa9x", 3, 0xe9, 2},
        {"\xe0\xa0\x80", 3, 0x800, 3}, {"\xe5\x90\x8d", 3, 0x540d, 3},
        {"\xed\x9f\xbf", 3, 0xd7ff, 3}, {"\xee\x80\x80", 3, 0xe000, 3},
        {"\xef\xbf\xbf", 3, 0xffff, 3}, {"\xf0\x90\x80\x80", 4, 0x10000, 4},
        {"\xf4\x8f\xbf\xbf", 4, 0x10ffff, 4}, {"\xf0\x9f\x98\x80\x80", 5, 0x1f600, 4},
        {"\x01", 1, 1, 1}, {"\xef\xbf\xbe", 3, 0xfffe, 3},
        {"\xc2\x80", 1, -1, 0}, {"\xe0\xa0\x80", 2, -1, 0},
        {"\xf0\x90\x80\x80", 3, -1, 0}, {"A", 0, -1, 0}, {"A", -1, -1, 0},
        {"\x80\x80", 2, -1, 0}, {"\xc2x", 2, -1, 0}, {"\xe2\x28\xa1", 3, -1, 0},
        {"\xe2\x82x", 3, -1, 0}, {"\xf0\x90\x80x", 4, -1, 0}, {"\xc0\x80", 2, -1, 0},
        {"\xc1\xbf", 2, -1, 0}, {"\xe0\x80\x80", 3, -1, 0}, {"\xf0\x80\x80\x80", 4, -1, 0},
        {"\xed\xa0\x80", 3, -1, 0}, {"\xed\xbf\xbf", 3, -1, 0},
        {"\xf4\x90\x80\x80", 4, -1, 0}, {"\xf5\x80\x80\x80", 4, -1, 0},
        {"\xf8\x88\x80\x80", 4, -1, 0}, {"\xff\x80\x80\x80", 4, -1, 0}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        int width;
        assert(utf8_char(cases[i].bytes, cases[i].available, &width) == cases[i].code);
        assert(width == cases[i].width);
    }
    static const char *permissive[] = {"\xf8\x90\x80\x80", "\xfc\x80\x80\x80"};
#ifdef XML3_REFERENCE_VERSION
    static const int permissive_expected[] = {0x10000, 0x100000};
#endif
    for (size_t i = 0; i < sizeof(permissive) / sizeof(permissive[0]); ++i) {
        int width;
        int code = utf8_char(permissive[i], 4, &width);
#ifdef XML3_REFERENCE_VERSION
        assert(code == permissive_expected[i] && width == 4);
#else
        assert(code == -1 && width == 0);
#endif
    }
    assert(!xmlGetLastError());
    const char source[] = "<r>A名\xf0\x9f\x98\x80</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content);
    static const int expected[] = {'A', 0x540d, 0x1f600};
    const xmlChar *cursor = content;
    int remaining = xmlStrlen(content);
    for (size_t i = 0; i < 3; ++i) {
        len = remaining;
        assert(xmlGetUTF8Char(cursor, &len) == expected[i]);
        cursor += len;
        remaining -= len;
    }
    assert(remaining == 0 && *cursor == 0);
    xmlFree(content);
}

static void test_utf8_length(void) {
    xmlResetLastError();
    assert(xmlUTF8Strlen(NULL) == -1);
    static const struct { const char *text; int length; } cases[] = {
        {"", 0}, {"abc", 3}, {"名é", 2}, {"A名\xf0\x9f\x98\x80", 3},
        {"e\xcc\x81", 2}, {"a\0\xff", 1}, {"\x01\xef\xbf\xbe", 2},
        {"\xc2\x80\xdf\xbf\xe0\xa0\x80\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf", 6},
        {"\xf0\x90\x80\x80\xf4\x8f\xbf\xbf", 2},
        {"\x80", -1}, {"\xc2", -1}, {"x\xe2\x82", -1}, {"ab\xf0\x90\x80", -1},
        {"\xc2x", -1}, {"\xe2\x28\xa1", -1}, {"\xf0\x90x\x80", -1},
        {"\xf8\x88\x80\x80\x80", -1}, {"\xff", -1}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
        assert(xmlUTF8Strlen((const xmlChar *)cases[i].text) == cases[i].length);
    static const char *permissive[] = {
        "\xc0\x80", "\xe0\x80\x80", "\xf0\x80\x80\x80",
        "\xed\xa0\x80", "\xf4\x90\x80\x80", "\xf5\x80\x80\x80", "\x80\x80"
    };
#ifdef XML3_REFERENCE_VERSION
    const int expected = 1;
#else
    const int expected = -1;
#endif
    for (size_t i = 0; i < sizeof(permissive) / sizeof(permissive[0]); ++i)
        assert(xmlUTF8Strlen((const xmlChar *)permissive[i]) == expected);
    assert(!xmlGetLastError());
    const char source[] = "<r>A名\xf0\x9f\x98\x80</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content && xmlStrlen(content) == 8 && xmlUTF8Strlen(content) == 3);
    xmlFree(content);
}

static void test_utf8_position(void) {
    xmlResetLastError();
    const xmlChar text[] = "A名\xf0\x9f\x98\x80Z";
    const int offsets[] = {0, 1, 4, 8, 9};
    for (int i = 0; i < 5; ++i)
        assert(xmlUTF8Strpos(text, i) == text + offsets[i]);
    assert(!xmlUTF8Strpos(text, 5) && !xmlUTF8Strpos(text, INT_MAX));
    assert(!xmlUTF8Strpos(text, -1) && !xmlUTF8Strpos(NULL, 0));
    const xmlChar empty[] = "";
    assert(xmlUTF8Strpos(empty, 0) == empty && !xmlUTF8Strpos(empty, 1));
    const xmlChar combining[] = "e\xcc\x81x";
    assert(xmlUTF8Strpos(combining, 1) == combining + 1);
    assert(xmlUTF8Strpos(combining, 2) == combining + 3);
    const xmlChar invalid_tail[] = "A\xff";
    assert(xmlUTF8Strpos(invalid_tail, 1) == invalid_tail + 1);
    assert(!xmlUTF8Strpos(invalid_tail, 2));
    const xmlChar nonxml[] = "\x01\xef\xbf\xbe";
    assert(xmlUTF8Strpos(nonxml, 2) == nonxml + 4);
    const xmlChar truncated[] = "a\xe2\x82";
    assert(!xmlUTF8Strpos(truncated, 2));
    const xmlChar premature_nul[] = "a\0\xff";
    assert(xmlUTF8Strpos(premature_nul, 1) == premature_nul + 1);
    assert(!xmlUTF8Strpos(premature_nul, 2));
    static const char *permissive[] = {
        "\xc0\x80", "\xe0\x80\x80", "\xed\xa0\x80",
        "\xf4\x90\x80\x80", "\xf8\x88\x80\x80\x80"
    };
    for (size_t i = 0; i < sizeof(permissive) / sizeof(permissive[0]); ++i) {
        const xmlChar *input = (const xmlChar *)permissive[i];
        assert(xmlUTF8Strpos(input, 0) == input);
#ifdef XML3_REFERENCE_VERSION
        assert(xmlUTF8Strpos(input, 1) == input + strlen(permissive[i]));
#else
        assert(!xmlUTF8Strpos(input, 1));
#endif
    }
    assert(!xmlGetLastError());
    const char source[] = "<r>A名\xf0\x9f\x98\x80Z</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content);
    const xmlChar *start = xmlUTF8Strpos(content, 1);
    const xmlChar *end = xmlUTF8Strpos(content, 3);
    assert(start && end);
    xmlChar *copy = xmlStrndup(start, (int)(end - start));
    assert(copy);
    xmlFree(content);
    assert(xmlStrEqual(copy, BAD_CAST "名\xf0\x9f\x98\x80"));
    xmlFree(copy);
}

static void test_utf8_prefix_size(void) {
    xmlResetLastError();
    const xmlChar text[] = "A名\xf0\x9f\x98\x80Z";
    const int expected[] = {0, 1, 4, 8, 9, 9};
    for (int i = 0; i < 6; ++i)
        assert(xmlUTF8Strsize(text, i) == expected[i]);
    assert(xmlUTF8Strsize(text, INT_MAX) == 9);
    assert(xmlUTF8Strsize(text, INT_MIN) == 0);
    assert(xmlUTF8Strsize(NULL, INT_MAX) == 0);
    assert(xmlUTF8Strsize(BAD_CAST "", 4) == 0);
    assert(xmlUTF8Strsize(BAD_CAST "e\xcc\x81x", 2) == 3);
    assert(xmlUTF8Strsize(BAD_CAST "\x01\xef\xbf\xbe", 2) == 4);
    assert(xmlUTF8Strsize(BAD_CAST "a\0\xff", 2) == 1);
    assert(xmlUTF8Strsize(BAD_CAST "a\xff", 1) == 1);
    static const char *malformed[] = {
        "\x80", "\xc2x", "\xe2\x82", "\xf0\x90\x80",
        "\xc0\x80", "\xe0\x80\x80", "\xed\xa0\x80",
        "\xf4\x90\x80\x80", "\xf8\x88\x80\x80\x80"
    };
    for (size_t i = 0; i < sizeof(malformed) / sizeof(malformed[0]); ++i) {
#ifdef XML3_REFERENCE_VERSION
        const int bytes = (int)strlen(malformed[i]);
#else
        const int bytes = -1;
#endif
        assert(xmlUTF8Strsize((const xmlChar *)malformed[i], 1) == bytes);
    }
#ifdef XML3_REFERENCE_VERSION
    assert(xmlUTF8Strsize(BAD_CAST "a\xe2\x82", 2) == 3);
#else
    assert(xmlUTF8Strsize(BAD_CAST "a\xe2\x82", 2) == -1);
#endif
    assert(!xmlGetLastError());
    const char source[] = "<r>A名\xf0\x9f\x98\x80</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content);
    int bytes = xmlUTF8Strsize(content, 2);
    assert(bytes == 4);
    xmlChar *copy = xmlStrndup(content, bytes);
    assert(copy);
    xmlFree(content);
    assert(xmlStrEqual(copy, BAD_CAST "A名"));
    xmlFree(copy);
}

static void test_utf8_prefix_copy(void) {
    xmlResetLastError();
    const xmlChar text[] = "A名\xf0\x9f\x98\x80Z";
    const int sizes[] = {0, 1, 4, 8, 9, 9};
    for (int count = 0; count < 6; ++count) {
        xmlChar *copy = xmlUTF8Strndup(text, count);
        assert(copy && copy != text);
        assert(!memcmp(copy, text, (size_t)sizes[count]) && copy[sizes[count]] == 0);
        xmlFree(copy);
    }
    assert(!xmlUTF8Strndup(NULL, 0) && !xmlUTF8Strndup(NULL, INT_MAX));
    assert(!xmlUTF8Strndup(text, INT_MIN));
    static const struct { const char *source; int count; const char *expected; } cases[] = {
        {"", INT_MAX, ""}, {"e\xcc\x81x", 2, "e\xcc\x81"},
        {"\x01\xef\xbf\xbe", INT_MAX, "\x01\xef\xbf\xbe"},
        {"a\0\xff", INT_MAX, "a"}, {"a\xff", 1, "a"}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        xmlChar *copy = xmlUTF8Strndup((const xmlChar *)cases[i].source, cases[i].count);
        assert(copy && xmlStrEqual(copy, (const xmlChar *)cases[i].expected));
        xmlFree(copy);
    }
    static const char *malformed[] = {
        "\x80", "\xc2x", "\xe2\x82", "\xc0\x80", "a\xed\xa0\x80",
        "\xf4\x90\x80\x80", "\xf8\x88\x80\x80\x80"
    };
    for (size_t i = 0; i < sizeof(malformed) / sizeof(malformed[0]); ++i) {
        xmlChar *copy = xmlUTF8Strndup((const xmlChar *)malformed[i], 2);
#ifdef XML3_REFERENCE_VERSION
        assert(copy && !strcmp((const char *)copy, malformed[i]));
#else
        assert(!copy);
#endif
        xmlFree(copy);
    }
    assert(!xmlGetLastError());
    const char source[] = "<r>名\xf0\x9f\x98\x80tail</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content);
    xmlChar *copy = xmlUTF8Strndup(content, 2);
    assert(copy && copy != content);
    xmlFree(content);
    xmlNodePtr node = xmlNewNode(NULL, BAD_CAST "r");
    assert(node && xmlNewTextChild(node, NULL, BAD_CAST "value", copy));
    xmlFree(copy);
    xmlChar *value = xmlNodeGetContent(node);
    xmlFreeNode(node);
    assert(value && xmlStrEqual(value, BAD_CAST "名\xf0\x9f\x98\x80"));
    xmlFree(value);
}

static void test_utf8_slice(void) {
    xmlResetLastError();
    const xmlChar text[] = "A名\xf0\x9f\x98\x80Z";
    const int offsets[] = {0, 1, 4, 8, 9};
    for (int start = 0; start <= 4; ++start) {
        for (int count = 0; count <= 5; ++count) {
            int end = start + count < 4 ? start + count : 4;
            size_t bytes = (size_t)(offsets[end] - offsets[start]);
            xmlChar *copy = xmlUTF8Strsub(text, start, count);
            assert(copy && copy != text + offsets[start]);
            assert(!memcmp(copy, text + offsets[start], bytes) && copy[bytes] == 0);
            xmlFree(copy);
        }
    }
    assert(!xmlUTF8Strsub(NULL, 0, 0));
    assert(!xmlUTF8Strsub(text, -1, 1) && !xmlUTF8Strsub(text, 0, -1));
    assert(!xmlUTF8Strsub(text, 5, 0) && !xmlUTF8Strsub(text, INT_MAX, 0));
    assert(!xmlUTF8Strsub(BAD_CAST "\xe2\x82", 1, 0));
    static const struct {
        const char *source; int start, count; const char *expected;
    } cases[] = {
        {"", 0, INT_MAX, ""}, {"a\0\xff", 1, INT_MAX, ""},
        {"a\xff", 1, 0, ""}, {"a名\xff", 1, 1, "名"},
        {"e\xcc\x81x", 1, 1, "\xcc\x81"},
        {"a\x01\xef\xbf\xbe", 1, INT_MAX, "\x01\xef\xbf\xbe"}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        xmlChar *copy = xmlUTF8Strsub((const xmlChar *)cases[i].source,
                                     cases[i].start, cases[i].count);
        assert(copy && xmlStrEqual(copy, (const xmlChar *)cases[i].expected));
        xmlFree(copy);
    }
    static const char *malformed_prefix[] = {
        "\x80x", "\xc2xx", "\xc0\x80x", "\xed\xa0\x80x",
        "\xf4\x90\x80\x80x", "\xf8\x88\x80\x80\x80x"
    };
    for (size_t i = 0; i < sizeof(malformed_prefix) / sizeof(malformed_prefix[0]); ++i) {
        xmlChar *copy = xmlUTF8Strsub((const xmlChar *)malformed_prefix[i], 1, 1);
#ifdef XML3_REFERENCE_VERSION
        assert(copy && xmlStrEqual(copy, BAD_CAST "x"));
#else
        assert(!copy);
#endif
        xmlFree(copy);
    }
    xmlChar *copy = xmlUTF8Strsub(BAD_CAST "a\xe2\x82", 1, 1);
#ifdef XML3_REFERENCE_VERSION
    assert(copy && !strcmp((const char *)copy, "\xe2\x82"));
#else
    assert(!copy);
#endif
    xmlFree(copy);
    assert(!xmlGetLastError());
    const char source[] = "<r>head名\xf0\x9f\x98\x80tail</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content);
    copy = xmlUTF8Strsub(content, 4, 2);
    assert(copy);
    xmlFree(content);
    xmlNodePtr node = xmlNewText(copy);
    xmlFree(copy);
    assert(node);
    xmlChar *value = xmlNodeGetContent(node);
    xmlFreeNode(node);
    assert(value && xmlStrEqual(value, BAD_CAST "名\xf0\x9f\x98\x80"));
    xmlFree(value);
}

static void test_utf8_character_compare(void) {
    static const struct { const char *text; int width; } chars[] = {
        {"", 1}, {"\x01", 1}, {"a", 1}, {"z", 1}, {"\x7f", 1},
        {"\xc2\x80", 2}, {"\xdf\xbf", 2}, {"\xe0\xa0\x80", 3},
        {"\xed\x9f\xbf", 3}, {"\xee\x80\x80", 3}, {"\xef\xbf\xbe", 3},
        {"\xf0\x90\x80\x80", 4}, {"\xf4\x8f\xbf\xbf", 4}
    };
    xmlResetLastError();
    assert(xmlUTF8Charcmp(NULL, NULL) == 0);
    assert(xmlUTF8Charcmp(NULL, BAD_CAST "") == -1);
    assert(xmlUTF8Charcmp(BAD_CAST "", NULL) == 1);
    for (size_t i = 0; i < sizeof(chars) / sizeof(chars[0]); ++i) {
        for (size_t j = 0; j < sizeof(chars) / sizeof(chars[0]); ++j) {
            const xmlChar *left = (const xmlChar *)chars[i].text;
            const xmlChar *right = (const xmlChar *)chars[j].text;
            int expected = 0;
            for (int k = 0; k < chars[i].width; ++k) {
                expected = left[k] - right[k];
                if (expected || !left[k]) break;
            }
            assert(xmlUTF8Charcmp(left, right) == expected);
        }
    }
    assert(xmlUTF8Charcmp(BAD_CAST "名\xff", BAD_CAST "名suffix") == 0);
    assert(xmlUTF8Charcmp(BAD_CAST "e\xcc\x81", BAD_CAST "ex") == 0);
    assert(xmlUTF8Charcmp(BAD_CAST "é", BAD_CAST "e\xcc\x81") > 0);
    assert(xmlUTF8Charcmp(BAD_CAST "\xe2x", BAD_CAST "\xe3y") == -1);
    assert(xmlUTF8Charcmp(BAD_CAST "a", BAD_CAST "\xff") == 'a' - 255);
    assert(!xmlGetLastError());
    static const char *invalid[] = {
        "\x80", "\xc0\x80", "\xe0\x80\x80", "\xed\xa0\x80",
        "\xf4\x90\x80\x80", "\xf8\x88\x80\x80\x80", "\xff",
        "\xc2", "\xe2\x82", "\xe2x"
    };
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        xmlChar copy[8];
        strcpy((char *)copy, invalid[i]);
        for (int alias = 0; alias < 2; ++alias) {
            xmlResetLastError();
            const xmlChar *left = (const xmlChar *)invalid[i];
            int result = xmlUTF8Charcmp(left, alias ? left : copy);
#ifdef XML3_REFERENCE_VERSION
            assert(result == 0 && !xmlGetLastError());
#else
            assert(result == -1);
            const xmlError *error = xmlGetLastError();
            assert(error && error->domain == XML_FROM_TREE && error->code == XML_ERR_INVALID_CHAR);
#endif
        }
        assert(!strcmp((char *)copy, invalid[i]));
    }
    xmlResetLastError();
}

static void test_utf8_location(void) {
    xmlResetLastError();
    assert(xmlUTF8Strloc(NULL, BAD_CAST "a") == -1);
    assert(xmlUTF8Strloc(BAD_CAST "a", NULL) == -1);
    static const struct { const char *text, *pattern; int index; } cases[] = {
        {"A名\xf0\x9f\x98\x80Z名", "名suffix", 1},
        {"A名\xf0\x9f\x98\x80Z名", "\xf0\x9f\x98\x80", 2},
        {"abab", "ba", 1}, {"abc", "z", -1},
        {"", "", -1}, {"abc", "", 0}, {"\xff", "", 0},
        {"名\xff", "名\xff", 0}, {"e\xcc\x81x", "\xcc\x81", 1},
        {"é", "e\xcc\x81", -1}, {"A\x01\xef\xbf\xbe", "\xef\xbf\xbe", 2},
        {"\xe2\x82", "x", -1}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
        assert(xmlUTF8Strloc((const xmlChar *)cases[i].text,
                            (const xmlChar *)cases[i].pattern) == cases[i].index);
    static const char *invalid[] = {
        "\xc0\x80", "\xe0\x80\x80", "\xed\xa0\x80",
        "\xf4\x90\x80\x80", "\xf8\x88\x80\x80\x80"
    };
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        xmlChar text[12];
        size_t bytes = strlen(invalid[i]);
        memcpy(text, invalid[i], bytes);
        memcpy(text + bytes, "z", 2);
        int after = xmlUTF8Strloc(text, BAD_CAST "z");
        int same = xmlUTF8Strloc((const xmlChar *)invalid[i], (const xmlChar *)invalid[i]);
#ifdef XML3_REFERENCE_VERSION
        assert(after == 1 && same == 0);
#else
        assert(after == -1 && same == -1);
#endif
    }
    assert(!xmlGetLastError());
    const char source[] = "<r>A名\xf0\x9f\x98\x80Z名</r>";
    xmlDocPtr doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    xmlFreeDoc(doc);
    assert(content);
    int index = xmlUTF8Strloc(content, BAD_CAST "\xf0\x9f\x98\x80tail");
    assert(index == 2);
    xmlChar *copy = xmlUTF8Strsub(content, index, 1);
    xmlFree(content);
    assert(copy);
    xmlNodePtr node = xmlNewText(copy);
    xmlFree(copy);
    assert(node);
    xmlChar *value = xmlNodeGetContent(node);
    xmlFreeNode(node);
    assert(value && xmlStrEqual(value, BAD_CAST "\xf0\x9f\x98\x80"));
    xmlFree(value);
}

static int expected_utf8_lead_size(int byte) {
    if (byte < 0x80) return 1;
    if (byte >= 0xc2 && byte <= 0xdf) return 2;
    if (byte >= 0xe0 && byte <= 0xef) return 3;
    if (byte >= 0xf0 && byte <= 0xf4) return 4;
#ifdef XML3_REFERENCE_VERSION
    if (byte == 0xc0 || byte == 0xc1) return 2;
    if (byte >= 0xf5 && byte <= 0xf7) return 4;
    if (byte >= 0xf8 && byte <= 0xfb) return 5;
    if (byte >= 0xfc && byte <= 0xfd) return 6;
    if (byte == 0xfe) return 7;
#endif
    return -1;
}

static void test_utf8_lead_size(void) {
    xmlResetLastError();
    assert(xmlUTF8Size(NULL) == -1);
    for (int byte = 0; byte < 256; ++byte) {
        xmlChar value = (xmlChar)byte;
        assert(xmlUTF8Size(&value) == expected_utf8_lead_size(byte));
        assert(value == (xmlChar)byte);
    }
    assert(xmlUTF8Size(BAD_CAST "\xe2x") == 3);
    assert(xmlUTF8Size(BAD_CAST "\xed\xa0\x80") == 3);
#ifndef XML3_REFERENCE_VERSION
    assert(!xmlCheckUTF8(BAD_CAST "\xe2x"));
    assert(!xmlCheckUTF8(BAD_CAST "\xed\xa0\x80"));
#endif
    assert(!xmlGetLastError());
}

static void test_string_length(void) {
    assert(xmlStrlen(NULL) == 0 && xmlStrlen(BAD_CAST "") == 0);
    assert(xmlStrlen(BAD_CAST "abc") == 3);
    assert(xmlStrlen(BAD_CAST "名é") == 5);
    assert(xmlStrlen(BAD_CAST "a\0tail") == 1);
    const xmlChar raw[] = {0xff, 0xc0, 0x80, 0};
    assert(xmlStrlen(raw) == 3);
    xmlDocPtr doc = xmlReadMemory("<Root>名</Root>", 16, NULL, NULL, 0);
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && xmlStrlen(root->name) == 4);
    xmlChar *content = xmlNodeGetContent(root);
    xmlFreeDoc(doc);
    assert(content && xmlStrlen(content) == 3);
    xmlFree(content);
}

static void test_string_append(void) {
    assert(!xmlStrcat(NULL, NULL));
    assert(!xmlStrncat(NULL, NULL, -1));
    assert(!xmlStrncat(NULL, BAD_CAST "x", 0));
    xmlChar *cur = xmlStrcat(NULL, BAD_CAST "");
    assert(cur && cur[0] == 0);
    xmlFree(cur);
    cur = xmlStrdup(BAD_CAST "head");
    assert(cur);
    assert(xmlStrcat(cur, NULL) == cur && xmlStrcat(cur, BAD_CAST "") == cur);
    assert(xmlStrncat(cur, BAD_CAST "ignored", 0) == cur);
    assert(xmlStrncat(cur, NULL, -1) == cur);
    cur = xmlStrcat(cur, BAD_CAST ":");
    assert(cur && xmlStrEqual(cur, BAD_CAST "head:"));
    const xmlChar raw[] = {'a', 0, 'b', 0xff};
    cur = xmlStrncat(cur, raw, 4);
    assert(cur && !memcmp(cur, "head:", 5) && !memcmp(cur + 5, raw, 4) && cur[9] == 0);
    xmlFree(cur);
    cur = xmlStrncat(NULL, raw, 4);
    assert(cur && !memcmp(cur, raw, 4) && cur[4] == 0);
    xmlFree(cur);
    cur = xmlStrdup(BAD_CAST "consumed");
    assert(cur);
    cur = xmlStrncat(cur, BAD_CAST "x", -1);
    assert(!cur);
    cur = xmlStrdup(BAD_CAST "<r>");
    assert(cur);
    cur = xmlStrcat(cur, BAD_CAST "名");
    assert(cur);
    cur = xmlStrncat(cur, BAD_CAST "</r>ignored", 4);
    assert(cur);
    xmlDocPtr doc = xmlReadMemory((const char *)cur, xmlStrlen(cur), NULL, NULL, 0);
    xmlFree(cur);
    assert(doc);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    assert(content && xmlStrEqual(content, BAD_CAST "名"));
    xmlFree(content);
    xmlFreeDoc(doc);
#ifndef XML3_REFERENCE_VERSION
    cur = xmlStrdup(BAD_CAST "ab");
    assert(cur);
    cur = xmlStrcat(cur, cur);
    assert(cur && xmlStrEqual(cur, BAD_CAST "abab"));
    cur = xmlStrncat(cur, cur + 1, 3);
    assert(cur && xmlStrEqual(cur, BAD_CAST "ababbab"));
    xmlFree(cur);
    cur = xmlStrndup(raw, 4);
    assert(cur);
    cur = xmlStrncat(cur, cur + 2, 2);
    assert(cur && !memcmp(cur, "ab\xff", 3) && cur[3] == 0);
    xmlFree(cur);
#endif
}

static void test_full_string_comparisons(void) {
    assert(xmlStrcmp(NULL, NULL) == 0 && xmlStrcasecmp(NULL, NULL) == 0);
    assert(xmlStrEqual(NULL, NULL) == 1);
    assert(xmlStrcmp(NULL, BAD_CAST "") == -1 && xmlStrcmp(BAD_CAST "", NULL) == 1);
    assert(xmlStrcasecmp(NULL, BAD_CAST "") == -1 && xmlStrcasecmp(BAD_CAST "", NULL) == 1);
    assert(!xmlStrEqual(NULL, BAD_CAST "") && !xmlStrEqual(BAD_CAST "", NULL));
    for (unsigned left = 0; left < 256; ++left) {
        for (unsigned right = 0; right < 256; ++right) {
            xmlChar a[] = {(xmlChar)left, 0}, b[] = {(xmlChar)right, 0};
            assert(xmlStrcmp(a, b) == (int)left - (int)right);
            assert(xmlStrcasecmp(a, b) ==
                   (int)reference_case_map(left) - (int)reference_case_map(right));
            assert(xmlStrEqual(a, b) == (left == right));
        }
    }
    assert(xmlStrcasecmp(BAD_CAST "AbC", BAD_CAST "aBc") == 0);
    assert(xmlStrcasecmp(BAD_CAST "[name]", BAD_CAST "{NAME]") == 0);
    assert(xmlStrcasecmp(BAD_CAST "名a", BAD_CAST "名B") == -1);
    assert(xmlStrcasecmp(BAD_CAST "É", BAD_CAST "é") != 0);
    assert(xmlStrcasecmp(BAD_CAST "abc", BAD_CAST "abcd") == -'d');
    assert(xmlStrcmp(BAD_CAST "a\0x", BAD_CAST "a\0y") == 0);
    assert(xmlStrcasecmp(BAD_CAST "a\0x", BAD_CAST "A\0y") == 0);
    xmlDocPtr doc = xmlReadMemory("<Root>MiXeD</Root>", 18, NULL, NULL, 0);
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && xmlStrcasecmp(root->name, BAD_CAST "root") == 0);
    assert(!xmlStrEqual(root->name, BAD_CAST "root"));
    xmlChar *text = xmlNodeGetContent(root);
    xmlFreeDoc(doc);
    assert(text && xmlStrcasecmp(text, BAD_CAST "mixed") == 0);
    xmlFree(text);
}

static void test_bounded_string_comparisons(void) {
    for (unsigned left = 0; left < 256; ++left) {
        for (unsigned right = 0; right < 256; ++right) {
            xmlChar a[] = {(xmlChar)left}, b[] = {(xmlChar)right};
            assert(xmlStrncmp(a, b, 1) == (int)left - (int)right);
            assert(xmlStrncasecmp(a, b, 1) ==
                   (int)reference_case_map(left) - (int)reference_case_map(right));
        }
    }
    for (size_t i = 0; i < sizeof(bounded_comparisons) / sizeof(*bounded_comparisons); ++i) {
        bounded_compare_fn compare = bounded_comparisons[i];
        xmlChar a[] = {'a', 0, 'x'}, b[] = {'a', 0, 'y'};
        xmlChar raw_a[] = {'a', 'b', 'c'}, raw_b[] = {'a', 'b', 'c'};
        assert(compare(NULL, NULL, INT_MAX) == 0);
        assert(compare(NULL, raw_a, 1) == -1 && compare(raw_a, NULL, 1) == 1);
        assert(compare(NULL, raw_a, 0) == 0 && compare(raw_a, NULL, INT_MIN) == 0);
        assert(compare(raw_a, raw_a, INT_MAX) == 0);
        assert(compare(raw_a, raw_b, 3) == 0);
        assert(compare(a, b, INT_MAX) == 0);
        assert(compare(BAD_CAST "abcdef", BAD_CAST "abcXYZ", 3) == 0);
        assert(compare(BAD_CAST "名a", BAD_CAST "名b", 4) == -1);
        assert(compare(BAD_CAST "\xc3\x84", BAD_CAST "\xc3\xa4", 2) == -32);
    }
    assert(xmlStrncmp(BAD_CAST "AbC", BAD_CAST "aBc", 3) == -32);
    assert(xmlStrncasecmp(BAD_CAST "AbC", BAD_CAST "aBc", 3) == 0);
    assert(xmlStrncasecmp(BAD_CAST "[", BAD_CAST "{", 1) == 0);
    assert(xmlStrncmp(BAD_CAST "abcdef", BAD_CAST "abcXYZ", 4) == 12);
    assert(xmlStrncasecmp(BAD_CAST "abcdef", BAD_CAST "abcXYZ", 4) == -20);
}

static void test_string_concatenation(void) {
    static const struct {
        const char *left, *right;
        int length;
        const char *expected;
        size_t size;
    } cases[] = {
        {NULL, NULL, -1, NULL, 0},
        {NULL, NULL, INT_MAX, NULL, 0},
        {NULL, "", 0, "", 0},
        {"", NULL, INT_MAX, "", 0},
        {"L", NULL, -1, "L", 1},
        {"L", NULL, INT_MAX, "L", 1},
        {NULL, "abc", -3, "abc", 3},
        {NULL, "abc", 2, "ab", 2},
        {"L", "abc", 0, "L", 1},
        {"L", "abc", 2, "Lab", 3},
        {"L", "a\0b\xff", 4, "La\0b\xff", 5},
        {"L", "a\0b\xff", -1, "La", 2},
        {"\xff", "\xc0", -1, "\xff\xc0", 2},
        {"\xe5\x90", "\x8d", 1, "名", 3},
        {"日", "本", -1, "日本", 6}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        const xmlChar *left = BAD_CAST cases[i].left, *right = BAD_CAST cases[i].right;
        xmlChar *copy = xmlStrncatNew(left, right, cases[i].length);
        if (!cases[i].expected) {
            assert(!copy);
        } else {
            assert(copy && copy != left && copy != right);
            assert(memcmp(copy, cases[i].expected, cases[i].size) == 0);
            assert(copy[cases[i].size] == 0);
        }
        xmlFree(copy);
    }
    {
        xmlChar source[] = "abc";
        xmlChar *copy = xmlStrncatNew(source, source + 1, 2);
        assert(copy && strcmp((const char *)copy, "abcbc") == 0);
        assert(strcmp((const char *)source, "abc") == 0);
        source[0] = 'x';
        copy[1] = 'y';
        assert(copy[0] == 'a' && source[1] == 'b');
        xmlFree(copy);
    }
    {
        xmlChar *head = xmlStrdup(BAD_CAST "<r>名");
        xmlChar *tail = xmlStrdup(BAD_CAST "</r>");
        assert(head && tail);
        xmlChar *copy = xmlStrncatNew(head, tail, -1);
        assert(copy);
        xmlFree(head);
        xmlFree(tail);
        xmlDocPtr doc = xmlReadMemory((const char *)copy, xmlStrlen(copy), NULL, NULL, 0);
        xmlFree(copy);
        assert(doc);
        xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
        assert(content && strcmp((const char *)content, "名") == 0);
        xmlFree(content);
        xmlFreeDoc(doc);
    }
}

static void test_string_duplicates(void) {
    static const char *cases[] = {"", "abc", "名", "\xff\xc0", "p:a:b"};
    assert(!xmlStrdup(NULL));
    assert(!xmlStrndup(NULL, 0) && !xmlStrndup(NULL, 3));
    assert(!xmlStrndup(BAD_CAST "abc", -1));
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        const xmlChar *source = BAD_CAST cases[i];
        size_t size = strlen(cases[i]);
        xmlChar *copy = xmlStrdup(source);
        assert(copy && copy != source && memcmp(copy, source, size + 1) == 0);
        xmlFree(copy);
        for (size_t len = 0; len <= size; ++len) {
            copy = xmlStrndup(source, (int)len);
            assert(copy && copy != source && copy[len] == 0);
            assert(memcmp(copy, source, len) == 0);
            xmlFree(copy);
        }
    }
    {
        xmlChar source[] = {'a', 0, 'b', 0xff};
        xmlChar *copy = xmlStrndup(source, sizeof(source));
        assert(copy && copy != source && memcmp(copy, source, sizeof(source)) == 0);
        assert(copy[sizeof(source)] == 0);
        source[0] = 'x';
        assert(copy[0] == 'a');
        xmlFree(copy);
        copy = xmlStrdup(source);
        assert(copy && copy[0] == 'x' && copy[1] == 0);
        copy[0] = 'y';
        assert(source[0] == 'x');
        xmlFree(copy);
    }
#if defined(__unix__)
    {
        long page_size = sysconf(_SC_PAGESIZE);
        assert(page_size > 3);
        xmlChar *mapping = mmap(NULL, (size_t)page_size * 2, PROT_READ | PROT_WRITE,
                               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        assert(mapping != MAP_FAILED);
        xmlChar *unreadable = mapping + page_size;
        assert(mprotect(unreadable, (size_t)page_size, PROT_NONE) == 0);
        assert(xmlUTF8Strloc(NULL, unreadable) == -1);
        assert(xmlUTF8Charcmp(NULL, unreadable) == -1);
#ifndef XML3_REFERENCE_VERSION
        assert(xmlUTF8Charcmp(unreadable, NULL) == 1);
#endif
        assert(xmlUTF8Strloc(unreadable, NULL) == -1);
        for (int byte = 0; byte < 256; ++byte) {
            unreadable[-1] = (xmlChar)byte;
            assert(xmlUTF8Size(unreadable - 1) == expected_utf8_lead_size(byte));
        }
        xmlChar *source = unreadable - 3;
        memcpy(source, "abc", 3);
        xmlChar *copy = xmlStrndup(source, 3);
        assert(copy && memcmp(copy, "abc\0", 4) == 0);
        xmlFree(copy);
        copy = xmlStrncatNew(BAD_CAST "L", source, 3);
        assert(copy && memcmp(copy, "Labc\0", 5) == 0);
        xmlFree(copy);
        copy = xmlStrncatNew(BAD_CAST "L", unreadable, 0);
        assert(copy && copy[0] == 'L' && copy[1] == 0);
        xmlFree(copy);
        copy = xmlStrncatNew(NULL, unreadable, 0);
        assert(copy && copy[0] == 0);
        xmlFree(copy);
        assert(!xmlStrncatNew(BAD_CAST "01234567890123456789012345678901", unreadable,
                             INT_MAX - 16));
        xmlResetLastError();
        copy = xmlStrndup(unreadable, 0);
        assert(copy && copy[0] == 0);
        xmlFree(copy);
        assert(!xmlStrndup(unreadable, -1));
        source[2] = 0;
        copy = xmlStrncatNew(BAD_CAST "L", source, -1);
        assert(copy && strcmp((const char *)copy, "Lab") == 0);
        xmlFree(copy);
        copy = xmlStrdup(source);
        assert(copy && strcmp((const char *)copy, "ab") == 0);
        xmlFree(copy);
#ifndef XML3_REFERENCE_VERSION
        assert(!xmlStrndup(unreadable, INT_MAX));
        xmlResetLastError();
#endif
        copy = xmlCharStrdup((const char *)source);
        assert(copy && strcmp((const char *)copy, "ab") == 0);
        xmlFree(copy);
        copy = xmlCharStrndup((const char *)source, 100);
        assert(copy && strcmp((const char *)copy, "ab") == 0);
        xmlFree(copy);
        copy = xmlCharStrndup((const char *)unreadable, 0);
        assert(copy && copy[0] == 0);
        xmlFree(copy);
        assert(!xmlCharStrndup((const char *)unreadable, INT_MIN));
#ifndef XML3_REFERENCE_VERSION
        assert(!xmlCharStrndup((const char *)unreadable, INT_MAX));
        xmlResetLastError();
#endif
        source[2] = 0xff;
        copy = xmlCharStrndup((const char *)source, 3);
        assert(copy && memcmp(copy, source, 3) == 0 && copy[3] == 0);
        xmlFree(copy);
        for (size_t i = 0; i < sizeof(bounded_comparisons) / sizeof(*bounded_comparisons); ++i) {
            bounded_compare_fn compare = bounded_comparisons[i];
            assert(compare(unreadable, unreadable, INT_MAX) == 0);
            assert(compare(unreadable, source, 0) == 0);
            assert(compare(source, unreadable, INT_MIN) == 0);
            assert(compare(NULL, unreadable, INT_MAX) == -1);
            assert(compare(unreadable, NULL, INT_MAX) == 1);
            source[2] = 'a';
            assert(compare(source + 2, BAD_CAST "a", 1) == 0);
            assert(compare(source + 2, BAD_CAST "b", INT_MAX) == -1);
            assert(compare(BAD_CAST "b", source + 2, INT_MAX) == 1);
            source[2] = 0;
            assert(compare(source + 2, BAD_CAST "", INT_MAX) == 0);
        }
        source[2] = 0;
        assert(!xmlStrchr(source + 2, 'x'));
        assert(!xmlStrchr(source + 2, 0));
        source[2] = 0xff;
        assert(xmlStrchr(source + 2, 0xff) == source + 2);
        source[2] = 'x';
        assert(xmlStrQEqual(BAD_CAST "p", source + 2, BAD_CAST "p:y") == 0);
        assert(xmlStrQEqual(source + 2, BAD_CAST "n", BAD_CAST "y:n") == 0);
        assert(xmlStrQEqual(NULL, unreadable, unreadable) == 1);
        assert(xmlStrQEqual(unreadable, NULL, unreadable) == 0);
        assert(xmlStrQEqual(unreadable, unreadable, NULL) == 0);
        source[0] = 'p'; source[1] = ':'; source[2] = 0;
        assert(xmlStrQEqual(BAD_CAST "p", BAD_CAST "", source) == 1);
        assert(xmlStrQEqual(NULL, source + 2, BAD_CAST "") == 1);
#ifndef XML3_REFERENCE_VERSION
        assert(xmlStrQEqual(source + 2, BAD_CAST "", source + 2) == 0);
#endif
        for (size_t i = 0; i < sizeof(substring_searches) / sizeof(*substring_searches); ++i) {
            substring_fn search = substring_searches[i];
            assert(search(NULL, unreadable) == NULL);
            assert(search(unreadable, NULL) == NULL);
            assert(search(unreadable, BAD_CAST "") == unreadable);
            source[0] = 'a'; source[1] = 'b'; source[2] = 0;
            assert(search(source, BAD_CAST "ab") == source);
            assert(search(source, BAD_CAST "abcd") == NULL);
            assert(search(source + 2, BAD_CAST "x") == NULL);
            source[1] = 'x';
            const xmlChar text[] = "ax";
            assert(search(text, source + 1) == text + 1);
            source[2] = 'x';
            assert(search(source + 2, BAD_CAST "x") == source + 2);
        }
        assert(!xmlStrsub(unreadable, -1, 0));
        assert(!xmlStrsub(unreadable, 0, -1));
#ifndef XML3_REFERENCE_VERSION
        assert(!xmlStrsub(unreadable, INT_MAX, 0));
        assert(xmlGetLastError());
        xmlResetLastError();
        assert(!xmlStrsub(unreadable, 0, INT_MAX));
        assert(xmlGetLastError());
        xmlResetLastError();
        assert(!xmlStrsub(unreadable, 1, INT_MAX - 16));
        assert(xmlGetLastError());
        xmlResetLastError();
#endif
        source[0] = 'a'; source[1] = 'b'; source[2] = 'c';
        copy = xmlStrsub(source, 1, 2);
        assert(copy && !memcmp(copy, "bc", 3));
        xmlFree(copy);
        copy = xmlStrsub(source + 2, 0, 0);
        assert(copy && copy[0] == 0);
        xmlFree(copy);
        source[2] = 0;
        assert(!xmlStrsub(source, 3, 1));
        source[2] = 'A';
        assert(xmlStrcmp(unreadable, unreadable) == 0);
        assert(xmlStrcasecmp(unreadable, unreadable) == 0);
        assert(xmlStrEqual(unreadable, unreadable) == 1);
        assert(xmlStrcasecmp(NULL, unreadable) == -1);
        assert(xmlStrcasecmp(unreadable, NULL) == 1);
        assert(xmlStrcmp(source + 2, BAD_CAST "B") == -1);
        assert(xmlStrcasecmp(source + 2, BAD_CAST "b") == -1);
        assert(!xmlStrEqual(source + 2, BAD_CAST "B"));
        assert(xmlStrncasecmp(source + 2, BAD_CAST "a", 1) == 0);
        assert(xmlStrncasecmp(source + 2, BAD_CAST "B", INT_MAX) == -1);
        source[1] = 'A'; source[2] = 0;
        assert(xmlStrcasecmp(source + 1, BAD_CAST "a") == 0);
        assert(xmlStrcmp(source + 1, BAD_CAST "A") == 0);
        assert(xmlStrEqual(source + 1, BAD_CAST "A") == 1);
        assert(xmlStrlen(source + 1) == 1 && xmlStrlen(source + 2) == 0);
        assert(xmlStrcat((xmlChar *)unreadable, NULL) == unreadable);
        assert(xmlStrcat((xmlChar *)unreadable, BAD_CAST "") == unreadable);
        assert(xmlStrncat((xmlChar *)unreadable, unreadable, 0) == unreadable);
        assert(xmlStrncat((xmlChar *)unreadable, NULL, -1) == unreadable);
        xmlChar *appended = xmlStrcat(NULL, source + 1);
        assert(appended && xmlStrEqual(appended, BAD_CAST "A"));
        xmlFree(appended);
        source[2] = 'x';
        appended = xmlStrdup(BAD_CAST "p");
        assert(appended);
        appended = xmlStrncat(appended, source + 2, 1);
        assert(appended && xmlStrEqual(appended, BAD_CAST "px"));
        xmlFree(appended);
#ifndef XML3_REFERENCE_VERSION
        xmlResetLastError();
        appended = xmlStrdup(BAD_CAST "consumed");
        assert(appended);
        appended = xmlStrncat(appended, unreadable, INT_MAX);
        assert(!appended && xmlGetLastError() && xmlGetLastError()->code == XML_ERR_ARGUMENT);
        xmlResetLastError();
#endif
        const xmlChar complete[] = {0xf4, 0x8f, 0xbf, 0xbf, 0};
        xmlChar *terminated = mapping + page_size - sizeof(complete);
        memcpy(terminated, complete, sizeof(complete));
        assert(xmlCheckUTF8(terminated) == 1);
        assert(xmlUTF8Strlen(terminated) == 1);
        xmlChar *utf = mapping + page_size - 4;
        memcpy(utf, complete, 4);
        source[0] = 0xe2;
        source[1] = 0x82;
        source[2] = 0;
        assert(xmlCheckUTF8(source) == 0);
        assert(xmlUTF8Strlen(source) == -1);
        source[1] = 0xe2;
        assert(xmlCheckUTF8(source + 1) == 0);
        assert(xmlCheckUTF8(source + 2) == 1);
        assert(xmlUTF8Strlen(source + 2) == 0);
        source[2] = 0xff;
        assert(xmlCheckUTF8(source + 2) == 0);
#ifndef XML3_REFERENCE_VERSION
        source[2] = 0xc0;
        assert(xmlCheckUTF8(source + 2) == 0);
#endif
        memcpy(utf, complete, 4);
        int len = 4;
        assert(xmlGetUTF8Char(utf, &len) == 0x10ffff && len == 4);
        source[2] = 0xe2;
        len = 1;
        assert(xmlGetUTF8Char(source + 2, &len) == -1 && len == 0);
        source[2] = 'z';
        len = 1;
        assert(xmlGetUTF8Char(source + 2, &len) == 'z' && len == 1);
#ifndef XML3_REFERENCE_VERSION
        len = 0;
        assert(xmlGetUTF8Char(unreadable, &len) == -1 && len == 0);
#endif
        assert(xmlUTF8Strpos(unreadable, 0) == unreadable);
        assert(xmlUTF8Strsize(unreadable, 0) == 0);
        assert(xmlUTF8Strsize(unreadable, -1) == 0);
        xmlChar *prefix_copy = xmlUTF8Strndup(unreadable, 0);
        assert(prefix_copy && prefix_copy[0] == 0);
        xmlFree(prefix_copy);
        assert(!xmlUTF8Strndup(unreadable, -1));
        assert(!xmlUTF8Strsub(unreadable, -1, 0));
        assert(!xmlUTF8Strsub(unreadable, 1, -1));
        prefix_copy = xmlUTF8Strsub(unreadable, 0, 0);
        assert(prefix_copy && prefix_copy[0] == 0);
        xmlFree(prefix_copy);
        assert(!xmlUTF8Strpos(unreadable, -1));
        source[2] = 'a';
        assert(xmlUTF8Strpos(source + 2, 1) == unreadable);
        assert(xmlUTF8Strloc(source + 2, source + 2) == 0);
        assert(xmlUTF8Charcmp(source + 2, source + 2) == 0);
        source[2] = 0xc2;
        assert(xmlUTF8Charcmp(source + 2, BAD_CAST "\xc3") == -1);
        source[2] = 'a';
        assert(xmlUTF8Strsize(source + 2, 1) == 1);
        prefix_copy = xmlUTF8Strndup(source + 2, 1);
        assert(prefix_copy && prefix_copy[0] == 'a' && prefix_copy[1] == 0);
        xmlFree(prefix_copy);
        prefix_copy = xmlUTF8Strsub(source + 2, 1, 0);
        assert(prefix_copy && prefix_copy[0] == 0);
        xmlFree(prefix_copy);
        source[1] = 0xc2;
        source[2] = 0;
        assert(xmlUTF8Strloc(source + 1, BAD_CAST "a") == -1);
#ifndef XML3_REFERENCE_VERSION
        assert(xmlUTF8Charcmp(source + 1, source + 1) == -1);
        assert(xmlGetLastError() && xmlGetLastError()->code == XML_ERR_INVALID_CHAR);
        xmlResetLastError();
#endif
#ifndef XML3_REFERENCE_VERSION
        assert(xmlUTF8Strloc(unreadable, source + 1) == -1);
#endif
        assert(!xmlUTF8Strpos(source + 1, 1));
        memcpy(utf, complete, 4);
        assert(xmlUTF8Strpos(utf, 1) == unreadable);
        assert(xmlUTF8Strsize(utf, 1) == 4);
        prefix_copy = xmlUTF8Strndup(utf, 1);
        assert(prefix_copy && !memcmp(prefix_copy, complete, 4) && prefix_copy[4] == 0);
        xmlFree(prefix_copy);
        utf[-1] = 'a';
        assert(xmlUTF8Strloc(utf - 1, utf) == 1);
        assert(xmlUTF8Strloc(utf, complete) == 0);
        assert(xmlUTF8Charcmp(utf, complete) == 0);
        assert(xmlUTF8Charcmp(utf, utf) == 0);
        prefix_copy = xmlUTF8Strsub(utf - 1, 1, 1);
        assert(prefix_copy && !memcmp(prefix_copy, complete, 4) && prefix_copy[4] == 0);
        xmlFree(prefix_copy);
        assert(munmap(mapping, (size_t)page_size * 2) == 0);
    }
#endif
}

typedef int (*validate_name_fn)(const xmlChar *, int);
static const validate_name_fn validators[] = {
    xmlValidateName, xmlValidateNCName, xmlValidateQName, xmlValidateNMToken
};

static void test_validation(void) {
    static const struct { const char *value; unsigned valid; } cases[] = {
        {"a", 15}, {"_x-1.z", 15}, {"名", 15}, {"e\xcc\x81", 15},
        {"p:名", 13}, {":a", 9}, {"a:", 9}, {":", 9}, {"a:b:c", 9},
        {"a:1", 9}, {"1a", 8}, {"-", 8}, {".", 8}, {"\xcc\x81", 8},
        {"", 0}, {"a b", 0}, {"a\tb", 0}, {"a/b", 0}, {"a&b", 0},
        {"\xc0\xaf", 0}, {"\xe3\x81", 0}, {"\x80", 0},
        {"\xf4\x90\x80\x80", 0}, {"a\xe2\x28\xa1", 0},
        {"\xc2\xa0", 0}, {"\v", 0}, {"\f", 0}
    };
    static const int space_flags[] = {0, 1, -1, INT_MIN};
    char padded[128];
    for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f) {
        assert(validators[f](NULL, 0) == -1);
        assert(validators[f](NULL, 1) == -1);
        for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
            int expected = (cases[i].valid & (1u << f)) ? 0 : 1;
            for (size_t s = 0; s < sizeof(space_flags) / sizeof(*space_flags); ++s) {
                int space = space_flags[s];
                assert(validators[f](BAD_CAST cases[i].value, space) == expected);
                snprintf(padded, sizeof(padded), " \t\r\n%s\n\r\t ", cases[i].value);
                assert(validators[f](BAD_CAST padded, space) == (space ? expected : 1));
            }
        }
        assert(validators[f](BAD_CAST "a\0:ignored", 0) == 0);
        assert(validators[f](BAD_CAST " \t\r\n", 1) == 1);
    }
#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        snprintf(padded, sizeof(padded), " \t\r\n%s\n\r\t ", cases[i].value);
        size_t size = strlen(padded) + 1;
        char *value = mapping + page - size;
        memcpy(value, padded, size);
        for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f)
            for (size_t s = 0; s < sizeof(space_flags) / sizeof(*space_flags); ++s) {
                int expected = space_flags[s] && (cases[i].valid & (1u << f)) ? 0 : 1;
                assert(validators[f](BAD_CAST value, space_flags[s]) == expected);
            }
    }
    mapping[page - 1] = '!';
    for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f)
        for (size_t s = 0; s < sizeof(space_flags) / sizeof(*space_flags); ++s)
            assert(validators[f](BAD_CAST (mapping + page - 1), space_flags[s]) == 1);
    memcpy(mapping + page - 3, "a \xf0", 3);
    for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f)
        assert(validators[f](BAD_CAST (mapping + page - 3), 1) == 1);
    mapping[page - 1] = ':';
    assert(xmlValidateNCName(BAD_CAST (mapping + page - 1), 0) == 1);
    assert(xmlValidateQName(BAD_CAST (mapping + page - 1), 0) == 1);
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif
    {
        size_t length = 262168;
        char *name = malloc(length + 1);
        assert(name);
        memset(name, 'a', length);
        name[length] = 0;
        for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f)
            assert(validators[f](BAD_CAST name, 0) == 0);
        name[length - 1] = '/';
        for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f)
            assert(validators[f](BAD_CAST name, 0) == 1);
        free(name);
    }
    static const char document[] = "<p:root xmlns:p='urn:n'><child/></p:root>";
    xmlDocPtr doc = xmlReadMemory(document, (int)(sizeof(document) - 1), NULL, NULL, 0);
    assert(doc != NULL);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && root->ns && root->ns->prefix);
    assert(xmlValidateNCName(root->name, 0) == 0);
    xmlChar *qualified = xmlBuildQName(root->name, root->ns->prefix, NULL, 0);
    assert(qualified && xmlValidateQName(qualified, 0) == 0);
    xmlChar *serialized = NULL;
    int size = 0;
    xmlDocDumpMemory(doc, &serialized, &size);
    assert(serialized != NULL && size > 0);
    xmlFreeDoc(doc);
    assert(xmlValidateQName(qualified, 0) == 0);
    doc = xmlReadMemory((const char *)serialized, size, NULL, NULL, 0);
    assert(doc && xmlValidateNCName(xmlDocGetRootElement(doc)->name, 0) == 0);
    xmlFree(qualified);
    xmlFree(serialized);
    xmlFreeDoc(doc);
}

static void test_qname_building(void) {
    static const struct {
        const char *name, *prefix, *expected;
    } cases[] = {
        {"name", "p", "p:name"}, {"値", "名", "名:値"},
        {"name", "", ":name"}, {"", "p", "p:"}, {"", "", ":"},
        {"a:b", "p:q", "p:q:a:b"}, {"a b", "1", "1:a b"},
        {"\xff", "\xc0", "\xc0:\xff"}, {"a\0ignored", "p\0ignored", "p:a"}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        const xmlChar *name = BAD_CAST cases[i].name;
        const xmlChar *prefix = BAD_CAST cases[i].prefix;
        size_t needed = strlen(cases[i].expected) + 1;
        xmlChar *built = xmlBuildQName(name, prefix, NULL, 0);
        assert(built && built != name && built != prefix);
        assert(strcmp((const char *)built, cases[i].expected) == 0);
        xmlFree(built);
        int capacities[] = {0, (int)needed - 1, (int)needed, (int)needed + 1};
        for (size_t j = 0; j < sizeof(capacities) / sizeof(*capacities); ++j) {
            xmlChar storage[64], before[64];
            memset(storage, '!', sizeof(storage));
            memcpy(before, storage, sizeof(storage));
            xmlChar *buffer = storage + 1;
            built = xmlBuildQName(name, prefix, buffer, capacities[j]);
            assert(built && strcmp((const char *)built, cases[i].expected) == 0);
            if ((size_t)capacities[j] >= needed) {
                assert(built == buffer && storage[0] == '!' && storage[needed + 1] == '!');
            } else {
                assert(built != buffer && memcmp(storage, before, sizeof(storage)) == 0);
                xmlFree(built);
            }
        }
    }
    {
        const xmlChar name[] = "name";
        xmlChar buffer[] = "unchanged";
        assert(xmlBuildQName(name, NULL, buffer, sizeof(buffer)) == name);
        assert(xmlBuildQName(name, NULL, NULL, 0) == name);
        assert(!xmlBuildQName(name, NULL, buffer, -1));
        assert(!xmlBuildQName(name, BAD_CAST "p", buffer, -1));
        assert(!xmlBuildQName(NULL, BAD_CAST "p", buffer, sizeof(buffer)));
        assert(strcmp((const char *)buffer, "unchanged") == 0);
    }
#ifndef XML3_REFERENCE_VERSION
    /* The reference's overlapping memcpy inputs are undefined. */
    {
        xmlChar buffer[32] = "name";
        assert(xmlBuildQName(buffer, BAD_CAST "p", buffer, sizeof(buffer)) == buffer);
        assert(strcmp((const char *)buffer, "p:name") == 0);
        strcpy((char *)buffer, "prefix");
        assert(xmlBuildQName(buffer + 3, buffer, buffer + 1, sizeof(buffer) - 1) == buffer + 1);
        assert(strcmp((const char *)buffer + 1, "prefix:fix") == 0);
    }
#endif
}

static void test_qname_splitting(void) {
    static const struct {
        const char *input, *prefix, *local;
    } cases[] = {
        {NULL, NULL, NULL}, {"", NULL, NULL}, {"name", NULL, NULL},
        {":name", NULL, NULL}, {"name:", NULL, NULL}, {":", NULL, NULL},
        {"p:name", "p", "name"}, {"名:値", "名", "値"},
        {"p:a:b", "p", "a:b"}, {"a::b", "a", ":b"}, {"a:b:", "a", "b:"},
        {"1:a b", "1", "a b"}, {"a: ", "a", " "},
        {"\xff:\xc0", "\xff", "\xc0"}, {"p:one\0:two", "p", "one"},
        {"p\0:ignored", NULL, NULL}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        const xmlChar *input = BAD_CAST cases[i].input;
        xmlChar *prefix = (xmlChar *)1;
        xmlChar *local = xmlSplitQName2(input, &prefix);
        int length = -97;
        const xmlChar *view = xmlSplitQName3(input, &length);
        if (cases[i].prefix) {
            assert(local && prefix);
            assert(strcmp((const char *)prefix, cases[i].prefix) == 0);
            assert(strcmp((const char *)local, cases[i].local) == 0);
            assert(length == (int)strlen(cases[i].prefix));
            assert(view == input + length + 1);
            assert(strcmp((const char *)view, cases[i].local) == 0);
        } else {
            assert(!local && !prefix && !view && length == -97);
        }
        xmlFree(local);
        xmlFree(prefix);
    }
    assert(!xmlSplitQName2(BAD_CAST "p:name", NULL));
    assert(!xmlSplitQName3(BAD_CAST "p:name", NULL));
#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (size_t i = 1; i < sizeof(cases) / sizeof(*cases); ++i) {
        size_t size = strlen(cases[i].input) + 1;
        char *input = mapping + page - size;
        memcpy(input, cases[i].input, size);
        int length = -97;
        const xmlChar *view = xmlSplitQName3(BAD_CAST input, &length);
        if (cases[i].prefix) {
            assert(length == (int)strlen(cases[i].prefix));
            assert(view == BAD_CAST (input + length + 1));
        } else {
            assert(view == NULL && length == -97);
        }
    }
    int length = -97;
    mapping[page - 1] = ':';
    assert(xmlSplitQName3(BAD_CAST (mapping + page - 1), &length) == NULL);
    assert(length == -97);
    assert(xmlSplitQName3(BAD_CAST (mapping + page), NULL) == NULL);
    assert(xmlSplitQName3(NULL, (int *)(mapping + page)) == NULL);
    assert(xmlSplitQName3(BAD_CAST (mapping + page - 1), (int *)(mapping + page)) == NULL);
    memcpy(mapping + page - 3, "p:\xf0", 3);
    assert(xmlSplitQName3(BAD_CAST (mapping + page - 3), &length) == BAD_CAST (mapping + page - 1));
    assert(length == 1);
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif
    {
        xmlChar input[] = "prefix:local";
        xmlChar *prefix = NULL;
        xmlChar *local = xmlSplitQName2(input, &prefix);
        int length = 0;
        const xmlChar *view = xmlSplitQName3(input, &length);
        assert(local && prefix && view == input + 7 && length == 6);
        memset(input, 'x', sizeof(input) - 1);
        assert(strcmp((const char *)prefix, "prefix") == 0);
        assert(strcmp((const char *)local, "local") == 0);
        assert(strcmp((const char *)view, "xxxxx") == 0);
        xmlFree(local);
        xmlFree(prefix);
    }
    {
        xmlChar *input = xmlStrdup(BAD_CAST "p:root");
        assert(input);
        int length = -1;
        const xmlChar *view = xmlSplitQName3(input, &length);
        assert(view && length == 1);
        xmlChar *prefix = xmlStrndup(input, length);
        xmlChar *local = xmlStrdup(view);
        assert(prefix && local);
        xmlFree(input);
        assert(xmlValidateNCName(prefix, 0) == 0 && xmlValidateNCName(local, 0) == 0);
        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root = xmlNewNode(NULL, local);
        assert(doc && root);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        xmlNsPtr ns = xmlNewNs(root, BAD_CAST "urn:n", prefix);
        assert(ns);
        xmlSetNs(root, ns);
        xmlFree(prefix);
        xmlFree(local);
        xmlChar *serialized = NULL;
        int size = 0;
        xmlDocDumpMemory(doc, &serialized, &size);
        assert(serialized && size > 0);
        xmlFreeDoc(doc);
        doc = xmlReadMemory((const char *)serialized, size, NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        assert(root && root->ns && xmlStrEqual(root->name, BAD_CAST "root"));
        assert(xmlStrEqual(root->ns->prefix, BAD_CAST "p"));
        xmlFree(serialized);
        xmlFreeDoc(doc);
    }
}

static xmlDocPtr parse(const char *input) {
    return xmlReadMemory(input, (int)strlen(input), NULL, NULL,
                         XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
}

static void test_names(void) {
    xmlDocPtr doc = parse("<?処理 開始?><名:根 xmlns:名='urn:one' 名:属性='値'>"
                          "<名:子 xmlns:名='urn:two'/><名:子/>"
                          "<é/><e\xcc\x81/></名:根>");
    assert(doc);
    assert(xmlStrEqual(doc->children->name, BAD_CAST "処理"));
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(xmlStrEqual(root->name, BAD_CAST "根"));
    assert(xmlStrEqual(root->ns->prefix, BAD_CAST "名"));
    assert(xmlSearchNs(doc, root, BAD_CAST "名") == root->ns);
    xmlChar *value = xmlGetNsProp(root, BAD_CAST "属性", BAD_CAST "urn:one");
    assert(value && xmlStrEqual(value, BAD_CAST "値"));
    xmlFree(value);
    xmlNodePtr child = xmlFirstElementChild(root);
    assert(xmlStrEqual(child->ns->href, BAD_CAST "urn:two"));
    child = xmlNextElementSibling(child);
    assert(child->ns == root->ns);
    child = xmlNextElementSibling(child);
    assert(xmlStrEqual(child->name, BAD_CAST "é"));
    child = xmlNextElementSibling(child);
    assert(xmlStrEqual(child->name, BAD_CAST "e\xcc\x81"));
    xmlFreeDoc(doc);
    assert(!parse("<é></e\xcc\x81>"));
}

static void encode(unsigned c, char out[5]) {
    size_t n;
    if (c < 0x80) { out[0] = (char)c; n = 1; }
    else if (c < 0x800) {
        out[0] = (char)(0xc0 | (c >> 6)); out[1] = (char)(0x80 | (c & 63)); n = 2;
    } else if (c < 0x10000) {
        out[0] = (char)(0xe0 | (c >> 12)); out[1] = (char)(0x80 | ((c >> 6) & 63));
        out[2] = (char)(0x80 | (c & 63)); n = 3;
    } else {
        out[0] = (char)(0xf0 | (c >> 18)); out[1] = (char)(0x80 | ((c >> 12) & 63));
        out[2] = (char)(0x80 | ((c >> 6) & 63)); out[3] = (char)(0x80 | (c & 63)); n = 4;
    }
    out[n] = 0;
}

static void test_ranges(void) {
    /* XML 1.0 fifth edition [4]/[4a], excluding the namespace separator. */
    static const unsigned starts[] = {
        0xc0,0xd6,0xd8,0xf6,0xf8,0x2ff,0x370,0x37d,0x37f,0x1fff,
        0x200c,0x200d,0x2070,0x218f,0x2c00,0x2fef,0x3001,0xd7ff,
        0xf900,0xfdcf,0xfdf0,0xfffd,0x10000,0x1f600,0xeffff
    };
    static const unsigned continuations[] = {0x30,0x39,0x2d,0x2e,0xb7,0x300,0x36f,0x203f,0x2040};
    static const unsigned neither[] = {
        0xbf,0xd7,0xf7,0x37e,0x200b,0x200e,0x206f,0x2190,0x2bff,
        0x2ff0,0x3000,0xd800,0xdfff,0xe000,0xf8ff,0xfdd0,0xfdef,
        0xfffe,0xffff,0xf0000,0x10ffff
    };
    char name[5], input[32];
    for (size_t group = 0; group < 3; ++group) {
        const unsigned *codes = group == 0 ? starts : group == 1 ? continuations : neither;
        size_t count = group == 0 ? sizeof(starts)/sizeof(*starts) :
                       group == 1 ? sizeof(continuations)/sizeof(*continuations) :
                                    sizeof(neither)/sizeof(*neither);
        for (size_t i = 0; i < count; ++i) {
            encode(codes[i], name);
            for (int initial = 0; initial < 2; ++initial) {
                snprintf(input, sizeof(input), "<%s%s/>", initial ? "" : "a", name);
                xmlDocPtr doc = parse(input);
                assert((doc != NULL) == (group == 0 || (group == 1 && !initial)));
                xmlFreeDoc(doc);
                snprintf(input, sizeof(input), "%s%s", initial ? "" : "a", name);
                for (size_t f = 0; f < sizeof(validators) / sizeof(*validators); ++f) {
                    int valid = group == 0 || (group == 1 && (!initial || f == 3));
                    assert(validators[f](BAD_CAST input, 0) == (valid ? 0 : 1));
                }
            }
        }
    }
    const char *invalid[] = {"<\xc0\xaf/>", "<\xe3\x81/>", "<\x80/>",
                             "<\xf4\x90\x80\x80/>", "<a\xe2\x28\xa1/>"};
    for (size_t i = 0; i < sizeof(invalid)/sizeof(*invalid); ++i) assert(!parse(invalid[i]));
}

static void test_xhtml_identifiers(void) {
    static const char *system_ids[] = {
        NULL,
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd",
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd",
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd",
        "", "https://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd",
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtdx", "\xff"
    };
    static const char *public_ids[] = {
        NULL, "-//W3C//DTD XHTML 1.0 Strict//EN", "-//W3C//DTD XHTML 1.0 Frameset//EN",
        "-//W3C//DTD XHTML 1.0 Transitional//EN", "", "-//W3C//DTD XHTML 1.1//EN",
        "-//w3c//DTD XHTML 1.0 Strict//EN", " -//W3C//DTD XHTML 1.0 Strict//EN"
    };
    xmlResetLastError();
    for (size_t i = 0; i < sizeof(system_ids) / sizeof(*system_ids); ++i)
        for (size_t j = 0; j < sizeof(public_ids) / sizeof(*public_ids); ++j) {
            int expected = i == 0 && j == 0 ? -1 :
                           ((i >= 1 && i <= 3) || (j >= 1 && j <= 3));
            assert(xmlIsXHTML(BAD_CAST system_ids[i], BAD_CAST public_ids[j]) == expected);
        }
    assert(xmlGetLastError() == NULL);
#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (int is_public = 0; is_public <= 1; ++is_public)
        for (size_t i = 1; i <= 3; ++i) {
            const char *identifier = is_public ? public_ids[i] : system_ids[i];
            size_t length = strlen(identifier);
            for (size_t prefix = 0; prefix <= length; ++prefix) {
                char *at_end = mapping + page - prefix - 1;
                memcpy(at_end, identifier, prefix);
                at_end[prefix] = 0;
                int result = is_public ? xmlIsXHTML(NULL, BAD_CAST at_end) :
                                         xmlIsXHTML(BAD_CAST at_end, NULL);
                assert(result == (prefix == length));
            }
        }
    mapping[page - 1] = '!';
    assert(xmlIsXHTML(BAD_CAST (mapping + page - 1),
                      BAD_CAST (mapping + page - 1)) == 0);
    for (size_t i = 1; i <= 3; ++i)
        assert(xmlIsXHTML(BAD_CAST (mapping + page), BAD_CAST public_ids[i]) == 1);
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky);
    assert(xmlIsXHTML(NULL, NULL) == -1);
    assert(xmlIsXHTML(BAD_CAST "unknown", NULL) == 0);
    assert(xmlIsXHTML(NULL, BAD_CAST public_ids[1]) == 1);
    assert(xmlGetLastError() == sticky);
    xmlResetLastError();
}

static void test_predefined_entities(void) {
    static const struct {
        const char *name;
        char value;
    } cases[] = {
        {"lt", '<'}, {"gt", '>'}, {"amp", '&'}, {"apos", '\''}, {"quot", '"'}
    };
    xmlEntityPtr entities[sizeof(cases) / sizeof(*cases)];

    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        const char *name = cases[i].name;
        char value = cases[i].value;
        xmlEntityPtr entity = xmlGetPredefinedEntity(BAD_CAST name);
        assert(entity != NULL);
        entities[i] = entity;
        assert(entity->_private == NULL);
        assert(entity->type == XML_ENTITY_DECL);
        assert(entity->name != NULL);
        assert(strcmp((const char *)entity->name, name) == 0);
        assert(entity->children == NULL && entity->last == NULL);
        assert(entity->parent == NULL && entity->next == NULL);
        assert(entity->prev == NULL && entity->doc == NULL);
        assert(entity->orig != NULL && entity->content == entity->orig);
        assert(entity->content[0] == (xmlChar)value);
        assert(entity->content[1] == 0);
        assert(entity->length == 1);
        assert(entity->etype == XML_INTERNAL_PREDEFINED_ENTITY);
        assert(entity->ExternalID == NULL && entity->SystemID == NULL);
        assert(entity->nexte == NULL && entity->URI == NULL);
        assert(entity->owner == 0 && entity->flags == 0);
        assert(entity->expandedSize == 0);
        assert(xmlGetPredefinedEntity(BAD_CAST name) == entity);

        char *owned_name = malloc(strlen(name) + 1);
        assert(owned_name != NULL);
        strcpy(owned_name, name);
        assert(xmlGetPredefinedEntity((const xmlChar *)owned_name) == entity);
        free(owned_name);

        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr text = xmlNewText(entity->content);
        assert(doc != NULL && root != NULL && text != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, text) == text);

        xmlChar *serialized = NULL;
        int serialized_size = 0;
        xmlDocDumpMemory(doc, &serialized, &serialized_size);
        assert(serialized != NULL && serialized_size > 0);
        xmlFreeDoc(doc);

        xmlDocPtr reparsed = xmlReadMemory((const char *)serialized,
                                           serialized_size, NULL, NULL, 0);
        assert(reparsed != NULL);
        xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(reparsed));
        assert(content != NULL);
        assert(content[0] == (xmlChar)value && content[1] == 0);
        xmlFree(content);
        xmlFreeDoc(reparsed);
        xmlFree(serialized);
    }

    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i)
        for (size_t j = i + 1; j < sizeof(cases) / sizeof(*cases); ++j)
            assert(entities[i] != entities[j]);

    static const char *invalid[] = {
        "", "l", "ltx", "LT", "lt;", "&amp;", "#38", "\xc3\xa9"
    };
    for (size_t i = 0; i < sizeof(invalid) / sizeof(*invalid); ++i)
        assert(xmlGetPredefinedEntity(BAD_CAST invalid[i]) == NULL);
    const xmlChar embedded[] = {'a', 'm', 'p', 0, 'x', 0};
    assert(xmlGetPredefinedEntity(embedded) == entities[2]);
    assert(xmlGetPredefinedEntity(NULL) == NULL);

    xmlDocPtr numeric = xmlReadMemory("<r>&#38;</r>", 12, NULL, NULL, 0);
    assert(numeric != NULL);
    xmlChar *numeric_content =
        xmlNodeGetContent(xmlDocGetRootElement(numeric));
    assert(numeric_content != NULL &&
           numeric_content[0] == '&' && numeric_content[1] == 0);
    xmlFree(numeric_content);
    xmlFreeDoc(numeric);
    xmlDocPtr unknown = xmlReadMemory("<r>&unknown;</r>", 16, NULL, NULL, 0);
    assert(unknown == NULL);
    xmlResetLastError();

#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        size_t length = strlen(cases[i].name);
        char *at_end = mapping + page - length - 1;
        memcpy(at_end, cases[i].name, length + 1);
        assert(xmlGetPredefinedEntity((const xmlChar *)at_end) == entities[i]);
    }
    char *prefix = mapping + page - 2;
    prefix[0] = 'l';
    prefix[1] = 0;
    assert(xmlGetPredefinedEntity((const xmlChar *)prefix) == NULL);
    mapping[page - 1] = 'x';
    assert(xmlGetPredefinedEntity((const xmlChar *)(mapping + page - 1)) == NULL);
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif

    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky != NULL);
    assert(xmlGetPredefinedEntity(BAD_CAST "amp") == entities[2]);
    assert(xmlGetPredefinedEntity(BAD_CAST "missing") == NULL);
    assert(xmlGetPredefinedEntity(NULL) == NULL);
    assert(xmlGetLastError() == sticky);
    xmlResetLastError();

    xmlCleanupParser();
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        xmlEntityPtr entity =
            xmlGetPredefinedEntity(BAD_CAST cases[i].name);
        assert(entity == entities[i]);
        assert(strcmp((const char *)entity->name, cases[i].name) == 0);
        assert(entity->content[0] == (xmlChar)cases[i].value);
        assert(entity->content[1] == 0);
    }
    xmlInitParser();
}

static void test_document_entities(void) {
    static const char *names[] = {"lt", "gt", "amp", "apos", "quot"};
    const char expected[] = "<>&'\"";
    xmlEntityPtr entities[5];
    xmlDocPtr doc = xmlReadMemory("<root/>", 7, NULL, NULL, 0);
    assert(doc != NULL);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root != NULL);
    for (size_t i = 0; i < sizeof(names) / sizeof(*names); ++i) {
        entities[i] = xmlGetDocEntity(doc, BAD_CAST names[i]);
        assert(entities[i] == xmlGetPredefinedEntity(BAD_CAST names[i]));
        assert(entities[i] != NULL);
        assert(xmlGetDocEntity(NULL, BAD_CAST names[i]) == entities[i]);
        xmlNodePtr text = xmlNewText(entities[i]->content);
        assert(text != NULL && xmlAddChild(root, text) != NULL);
    }

    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky != NULL);
    int code = sticky->code;
    const char *message = sticky->message;
    assert(xmlGetDocEntity(doc, BAD_CAST "amp") == entities[2]);
    assert(xmlGetDocEntity(doc, BAD_CAST "custom") == NULL);
    assert(xmlGetDocEntity(doc, BAD_CAST "AMP") == NULL);
    assert(xmlGetDocEntity(doc, BAD_CAST "") == NULL);
    assert(xmlGetDocEntity(doc, NULL) == NULL);
    assert(xmlGetDocEntity(NULL, NULL) == NULL);
#ifndef XML3_REFERENCE_VERSION
    assert(xmlGetDocEntity((xmlDocPtr)1, NULL) == NULL);
#endif
    assert(xmlGetLastError() == sticky && sticky->code == code);
    assert(sticky->message == message);
    xmlResetLastError();

#ifndef XML3_REFERENCE_VERSION
    assert(xmlGetDocEntity((xmlDocPtr)root, BAD_CAST "amp") == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    assert(xmlGetDocEntity((xmlDocPtr)1, (const xmlChar *)1) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
#endif
#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    memcpy(mapping + page - 4, "amp", 4);
    assert(xmlGetDocEntity(doc, BAD_CAST (mapping + page - 4)) == entities[2]);
#ifndef XML3_REFERENCE_VERSION
    assert(xmlGetDocEntity((xmlDocPtr)(mapping + page),
                           BAD_CAST (mapping + page)) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
#endif
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif

    xmlChar *serialized = NULL;
    int size = 0;
    xmlDocDumpMemory(doc, &serialized, &size);
    assert(serialized != NULL && size > 0);
    xmlFreeDoc(doc);
    for (size_t i = 0; i < sizeof(names) / sizeof(*names); ++i)
        assert(entities[i]->content[0] == (xmlChar)expected[i]);
    xmlDocPtr parsed = xmlReadMemory((const char *)serialized, size, NULL, NULL, 0);
    assert(parsed != NULL);
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(parsed));
    assert(content != NULL && strcmp((const char *)content, expected) == 0);
    assert(xmlGetDocEntity(parsed, BAD_CAST "amp") == entities[2]);
    xmlFree(content);
    xmlFreeDoc(parsed);
    xmlFree(serialized);
}

static void test_name_values(void) {
    int (*validators[])(const xmlChar *) = {
        xmlValidateNameValue, xmlValidateNamesValue,
        xmlValidateNmtokenValue, xmlValidateNmtokensValue
    };
    static const struct { const char *value; int expected[4]; } cases[] = {
        {NULL, {0, 0, 0, 0}}, {"", {0, 0, 0, 0}}, {" \t\r\n", {0, 0, 0, 0}},
        {"a", {1, 1, 1, 1}}, {":", {1, 1, 1, 1}}, {"a:b:c", {1, 1, 1, 1}},
        {"9", {0, 0, 1, 1}}, {"-a", {0, 0, 1, 1}}, {".a", {0, 0, 1, 1}},
        {"a  b", {0, 1, 0, 1}}, {"a :b", {0, 1, 0, 1}},
        {"a 9", {0, 0, 0, 1}}, {"a b ", {0, 0, 0, 1}},
        {" a", {0, 0, 0, 1}}, {"\ta b ", {0, 0, 0, 1}},
        {"a\tb", {0, 0, 0, 0}}, {"a\t", {0, 0, 0, 0}},
        {"a \n", {0, 0, 0, 0}}, {"a/b", {0, 0, 0, 0}},
        {"\xC2\xB7", {0, 0, 1, 1}}, {"\xCC\x81", {0, 0, 1, 1}},
        {"a\xC2\xB7", {1, 1, 1, 1}}, {"名前 名前", {0, 1, 0, 1}},
        {"\xF0\x90\x80\x80", {1, 1, 1, 1}},
        {"\xF3\xAF\xBF\xBF", {1, 1, 1, 1}},
        {"\xF3\xB0\x80\x80", {0, 0, 0, 0}},
        {"\xEF\xBF\xBE", {0, 0, 0, 0}}, {"\xC3", {0, 0, 0, 0}},
        {"\xF0\x90\x80", {0, 0, 0, 0}}, {"\xC1\xA1", {0, 0, 0, 0}},
        {"\xED\xA0\x80", {0, 0, 0, 0}}, {"a\0 bad", {1, 1, 1, 1}}
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i)
        for (size_t j = 0; j < sizeof(validators) / sizeof(*validators); ++j)
            assert(validators[j](BAD_CAST cases[i].value) == cases[i].expected[j]);
    for (unsigned int byte = 0; byte <= 255; ++byte) {
        xmlChar value[5] = {(xmlChar)byte, 0, 0, 0, 0};
        int name = byte == ':' || byte == '_' || (byte >= 'a' && byte <= 'z') ||
                   (byte >= 'A' && byte <= 'Z');
        int token = name || byte == '-' || byte == '.' || (byte >= '0' && byte <= '9');
        assert(xmlValidateNameValue(value) == name);
        assert(xmlValidateNamesValue(value) == name);
        assert(xmlValidateNmtokenValue(value) == token);
        assert(xmlValidateNmtokensValue(value) == token);
    }
#if defined(__unix__)
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (size_t i = 1; i < sizeof(cases) / sizeof(*cases); ++i) {
        size_t size = strlen(cases[i].value) + 1;
        char *value = mapping + page - size;
        memcpy(value, cases[i].value, size);
        for (size_t j = 0; j < sizeof(validators) / sizeof(*validators); ++j)
            assert(validators[j](BAD_CAST value) == cases[i].expected[j]);
    }
    mapping[page - 1] = '!';
    for (size_t j = 0; j < sizeof(validators) / sizeof(*validators); ++j)
        assert(validators[j](BAD_CAST (mapping + page - 1)) == 0);
    assert(munmap(mapping, (size_t)page * 2) == 0);
#endif
    assert(!xmlReadMemory("<", 1, NULL, NULL, 0));
    const xmlError *sticky = xmlGetLastError();
    assert(sticky != NULL);
    int code = sticky->code;
    const char *message = sticky->message;
    for (size_t j = 0; j < sizeof(validators) / sizeof(*validators); ++j) {
        assert(validators[j](BAD_CAST "name") == 1);
        assert(validators[j](BAD_CAST "!") == 0);
        assert(validators[j](NULL) == 0);
    }
    assert(xmlGetLastError() == sticky && sticky->code == code && sticky->message == message);
    xmlResetLastError();

    assert(xmlValidateNameValue(BAD_CAST "record") == 1);
    assert(xmlValidateNamesValue(BAD_CAST "alpha beta") == 1);
    assert(xmlValidateNmtokensValue(BAD_CAST "9 -tag") == 1);
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "record");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlSetProp(root, BAD_CAST "refs", BAD_CAST "alpha beta") != NULL);
    assert(xmlSetProp(root, BAD_CAST "tokens", BAD_CAST "9 -tag") != NULL);
    xmlChar *serialized = NULL;
    int size = 0;
    xmlDocDumpMemory(doc, &serialized, &size);
    assert(serialized != NULL && size > 0);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)serialized, size, NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    xmlChar *refs = xmlGetProp(root, BAD_CAST "refs");
    xmlChar *tokens = xmlGetProp(root, BAD_CAST "tokens");
    assert(refs && strcmp((const char *)refs, "alpha beta") == 0);
    assert(tokens && strcmp((const char *)tokens, "9 -tag") == 0);
    assert(xmlValidateNamesValue(refs) == 1 && xmlValidateNmtokensValue(tokens) == 1);
    xmlFree(refs);
    xmlFree(tokens);
    xmlFree(serialized);
    xmlFreeDoc(doc);
}

int main(void) {
    test_name_values();
    test_uri_paths();
    test_uri_unescaping();
    test_uri_escaping();
    test_utf8_writing();
    test_character_range_groups();
    test_xhtml_identifiers();
    test_character_classes();
    test_escaping(0);
    test_escaping(1);
    test_string_duplicates();
    test_byte_search();
    test_string_slice();
    test_substring_search();
    test_qname_equality();
    test_char_string_duplicates();
    test_string_concatenation();
    test_bounded_string_comparisons();
    test_full_string_comparisons();
    test_string_append();
    test_string_length();
    test_utf8_check();
    test_utf8_char();
    test_utf8_length();
    test_utf8_position();
    test_utf8_prefix_size();
    test_utf8_prefix_copy();
    test_utf8_slice();
    test_utf8_lead_size();
    test_utf8_location();
    test_utf8_character_compare();
#ifdef XML3_REFERENCE_VERSION
    if (strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) != 0) {
        fprintf(stderr, "wrong reference runtime: %s\n", xmlParserVersion);
        return 1;
    }
#endif
    test_names();
    test_ranges();
    test_validation();
    test_qname_splitting();
    test_qname_building();
    test_predefined_entities();
    test_document_entities();
    puts("Unicode name tests passed");
}
