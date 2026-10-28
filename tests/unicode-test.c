#define _GNU_SOURCE
#ifdef XML3_REFERENCE_VERSION
#include <libxml/parser.h>
#include <libxml/tree.h>
#else
#include <libxml3.h>
#endif
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
static const bounded_compare_fn bounded_comparisons[] = {xmlStrncmp, xmlStrncasecmp};
typedef const xmlChar *(*substring_fn)(const xmlChar *, const xmlChar *);
static const substring_fn substring_searches[] = {xmlStrstr, xmlStrcasestr};

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

int main(void) {
    test_string_duplicates();
    test_byte_search();
    test_string_slice();
    test_substring_search();
    test_qname_equality();
    test_char_string_duplicates();
    test_string_concatenation();
    test_bounded_string_comparisons();
    test_full_string_comparisons();
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
    puts("Unicode name tests passed");
}
