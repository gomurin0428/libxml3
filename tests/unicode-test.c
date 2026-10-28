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
