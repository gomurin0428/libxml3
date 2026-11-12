/* URI resolution and conversion: xmlBuildURI, xmlBuildURISafe,
 * xmlBuildRelativeURI, xmlBuildRelativeURISafe, xmlCanonicPath,
 * xmlPathToURI and xmlURIEscape.  The output of this program is compared
 * between libxml3 and the pinned reference libxml2 (make test-uri-build),
 * so every line must describe behavior both share. */
#include <libxml/uri.h>
#include <libxml/xmlmemory.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void put_text(const char *value) {
    if (value == NULL) {
        fputs("null", stdout);
        return;
    }
    putchar('"');
    for (; *value; ++value) {
        unsigned char c = (unsigned char)*value;
        if (c < 0x20 || c >= 0x7f || c == '"' || c == '\\')
            printf("\\x%02x", (unsigned)c);
        else
            putchar(c);
    }
    putchar('"');
}

static void put_result(const char *label, xmlChar *value) {
    printf("%s ", label);
    put_text((const char *)value);
    putchar('\n');
    xmlFree(value);
}

static const char *const bases[] = {
    "http://a/b/c/d;p?q",
    "http://a/b/c/d;p?q#f",
    "http://a",
    "http://u@a:8080/b/c",
    "file:///etc/hosts",
    "file:///",
    "/usr/share/doc/index.xml",
    "dir/sub/file.xml",
    "file.xml",
    "/",
    "",
    "not a uri ://x",
    "urn:isbn:1",
    "http://a/b/../c/./d",
};

/* RFC 3986 section 5.4 examples and libxml2-specific cases. */
static const char *const refs[] = {
    "g:h", "g", "./g", "g/", "/g", "//g", "?y", "g?y", "#s", "g#s",
    "g?y#s", ";x", "g;x", "g;x?y#s", "", ".", "./", "..", "../", "../g",
    "../..", "../../", "../../g", "../../../g", "../../../../g", "/./g",
    "/../g", "g.", ".g", "g..", "..g", "./../g", "./g/.", "g/./h", "g/../h",
    "g;x=1/./y", "g;x=1/../y", "g?y/./x", "g?y/../x", "g#s/./x",
    "g#s/../x", "a b", "a%20b", "%7e", "\xc3\xa9", "a//b", "../a/../../b",
    "./..//..", "x/..", "x/../..",
};

static void test_build(void) {
    for (size_t b = 0; b < sizeof(bases) / sizeof(bases[0]); ++b) {
        for (size_t r = 0; r < sizeof(refs) / sizeof(refs[0]); ++r) {
            xmlChar *out = NULL;
            int ret = xmlBuildURISafe(BAD_CAST refs[r], BAD_CAST bases[b],
                                      &out);
            char label[160];

            snprintf(label, sizeof(label), "build %zu/%zu %d", b, r, ret);
            put_result(label, out);
        }
    }
    put_result("build null base", xmlBuildURI(BAD_CAST "x", NULL));
    put_result("build null uri", xmlBuildURI(NULL, BAD_CAST "http://a/"));
    printf("build safe null out: %d\n",
           xmlBuildURISafe(BAD_CAST "x", BAD_CAST "y", NULL));
    put_result("build bad uri", xmlBuildURI(BAD_CAST "a b:c d",
                                           BAD_CAST "http://a/b"));
    put_result("build bad base", xmlBuildURI(BAD_CAST "g",
                                             BAD_CAST "http://a b://c"));
}

static const char *const relative_pairs[][2] = {
    {"http://a/b/c/d", "http://a/b/c/e"},
    {"http://a/b/c/d", "http://a/b/x/e"},
    {"http://a/b/c/", "http://a/b/c/d"},
    {"http://a/b/c", "http://a/b/c"},
    {"http://a/x y/z", "http://a/b/c"},
    {"http://b/c", "http://a/c"},
    {"https://a/c", "http://a/c"},
    {"http://a:81/c", "http://a/c"},
    {"/usr/share/a.xml", "/usr/share/doc/b.xml"},
    {"/usr/a.xml", "/usr/share/doc/b.xml"},
    {"rel/a.xml", "rel/b/c.xml"},
    {"rel/a.xml", "/abs/b.xml"},
    {"/abs/a.xml", "rel/b.xml"},
    {"foo/", "foo/bar"},
    {"foo/bar", "foo/"},
    {"http://a/b/c?q#f", "http://a/b/d"},
    {"http://a", "http://a/b"},
    {"http://a/b", "http://a"},
    {"a b", "x"},
    {"x", "a b"},
    {"x", ""},
    {"x", NULL},
    {"", "x"},
    {"./a/../b", "c/./d"},
    {"file:///etc/hosts", "file:///etc/passwd"},
    {"file:///etc/hosts", "/etc/passwd"},
    {"http://a/%7e/x", "http://a/%7e/y"},
};

static void test_relative(void) {
    for (size_t i = 0;
         i < sizeof(relative_pairs) / sizeof(relative_pairs[0]); ++i) {
        xmlChar *out = NULL;
        int ret = xmlBuildRelativeURISafe(BAD_CAST relative_pairs[i][0],
                                          BAD_CAST relative_pairs[i][1], &out);
        char label[64];

        snprintf(label, sizeof(label), "relative %zu %d", i, ret);
        put_result(label, out);
    }
    put_result("relative null", xmlBuildRelativeURI(NULL, BAD_CAST "x"));
    printf("relative safe null out: %d\n",
           xmlBuildRelativeURISafe(BAD_CAST "x", BAD_CAST "y", NULL));
}

static const char *const texts[] = {
    "http://a/b c?d e#f g",
    "http://a/%41[x]{y}",
    "/plain/path with space",
    "relative",
    "",
    "file:///c:/x y",
    "x://\xc3\xa9",
};

static void test_canonic(void) {
    for (size_t i = 0; i < sizeof(texts) / sizeof(texts[0]); ++i) {
        char label[64];

        snprintf(label, sizeof(label), "canonic %zu", i);
        put_result(label, xmlCanonicPath(BAD_CAST texts[i]));
        snprintf(label, sizeof(label), "path-to-uri %zu", i);
        put_result(label, xmlPathToURI(BAD_CAST texts[i]));
    }
    put_result("canonic null", xmlCanonicPath(NULL));
}

static const char *const escapes[] = {
    "http://a/b c?q=1 2#f g",
    "http://u s@h:81/p",
    "mailto:a b@c",
    "/path/with space",
    "rel{x}|y^z`",
    "http://h/%41",
    "a b c",
    "http://h/\xc3\xa9",
    "has space:x",
    "",
};

static void test_escape(void) {
    for (size_t i = 0; i < sizeof(escapes) / sizeof(escapes[0]); ++i) {
        char label[64];

        snprintf(label, sizeof(label), "escape %zu", i);
        put_result(label, xmlURIEscape(BAD_CAST escapes[i]));
    }
    put_result("escape null", xmlURIEscape(NULL));
}

int main(void) {
    test_build();
    test_relative();
    test_canonic();
    test_escape();
    puts("uri build tests passed");
    return 0;
}
