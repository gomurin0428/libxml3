#ifdef XML3_REFERENCE_VERSION
#include <libxml/parser.h>
#include <libxml/tree.h>
#else
#include <libxml3.h>
#endif
#include <assert.h>
#include <stdio.h>
#include <string.h>

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
            }
        }
    }
    const char *invalid[] = {"<\xc0\xaf/>", "<\xe3\x81/>", "<\x80/>",
                             "<\xf4\x90\x80\x80/>", "<a\xe2\x28\xa1/>"};
    for (size_t i = 0; i < sizeof(invalid)/sizeof(*invalid); ++i) assert(!parse(invalid[i]));
}

int main(void) {
    test_names();
    test_ranges();
    puts("Unicode name tests passed");
}
