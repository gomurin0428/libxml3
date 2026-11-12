/* URI parsing and serialization: xmlCreateURI, xmlParseURI,
 * xmlParseURISafe, xmlParseURIRaw, xmlParseURIReference, xmlSaveUri,
 * xmlPrintURI and xmlFreeURI.  The output of this program is compared
 * between libxml3 and the pinned reference libxml2 (make test-uri), so
 * every line must describe behavior both share. */
#include <libxml/uri.h>
#include <libxml/xmlmemory.h>

#include <assert.h>
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

static void put_field(const char *name, const char *value) {
    printf(" %s=", name);
    put_text(value);
}

static void put_uri(xmlURIPtr uri) {
    xmlChar *saved;

    if (uri == NULL) {
        puts(" uri=null");
        return;
    }
    put_field("scheme", uri->scheme);
    put_field("opaque", uri->opaque);
    put_field("authority", uri->authority);
    put_field("server", uri->server);
    put_field("user", uri->user);
    printf(" port=%d", uri->port);
    put_field("path", uri->path);
    put_field("query", uri->query);
    put_field("fragment", uri->fragment);
    printf(" cleanup=%d", uri->cleanup);
    put_field("query_raw", uri->query_raw);
    saved = xmlSaveUri(uri);
    put_field("saved", (const char *)saved);
    xmlFree(saved);
    putchar('\n');
}

static const char *const inputs[] = {
    "http://example.com/a/b?q=1#f",
    "http://user:pw@example.com:8080/p%20q?x=%41#%42",
    "http://example.com",
    "http://example.com:/x",
    "http://[::1]:80/v6",
    "http://[::1/broken",
    "http://192.168.0.1/ip",
    "http://25:0.1/odd",
    "http://h:99999999999/big",
    "http://a/b?#frag",
    "http://a/b?#",
    "http://a/b#",
    "http://a/b?",
    "file:///etc/hosts",
    "file:///c:/dir/x y",
    "file:/rel",
    "file:",
    "mailto:someone@example.com",
    "urn:isbn:0451450523",
    "x:",
    "a+b-c.d:rest",
    "1abc:rest",
    "//host/only/authority",
    "///triple",
    "/absolute/path",
    "relative/path",
    "rel:colon",
    "./rel:colon",
    "?only-query",
    "#only-fragment",
    "",
    "has space",
    "bad%zzescape",
    "pct%41%62",
    "http://h/%7e%7E",
    "http://h/a b",
    "http://h/\xc3\xa9",
    "http://h/[x]",
    "http://h/{x}",
    "http://h/|",
    "http://u%40@h/",
    "http://@h/",
    "http://h:/",
    "http:///p",
    "http:",
    "http:?q",
    "http:#f",
    "foo://h/p;a=b",
    "foo:/p?a&b=c$d,e+f",
};

static void test_parse(void) {
    for (size_t i = 0; i < sizeof(inputs) / sizeof(inputs[0]); ++i) {
        xmlURIPtr uri = NULL;
        int ret;

        printf("parse ");
        put_text(inputs[i]);
        putchar('\n');
        ret = xmlParseURISafe(inputs[i], &uri);
        printf(" safe=%d", ret);
        put_uri(uri);
        xmlFreeURI(uri);
        uri = xmlParseURIRaw(inputs[i], 1);
        printf(" raw:");
        put_uri(uri);
        xmlFreeURI(uri);
    }
}

static void test_reference(void) {
    xmlURIPtr uri = xmlCreateURI();

    assert(uri != NULL);
    printf("created:");
    put_uri(uri);
    /* A reused structure keeps its port and cleanup flags. */
    printf("ref port: %d", xmlParseURIReference(uri, "http://h:81/x"));
    put_uri(uri);
    printf("ref keeps port: %d", xmlParseURIReference(uri, "/p"));
    put_uri(uri);
    printf("ref empty server: %d", xmlParseURIReference(uri, "http:///p"));
    put_uri(uri);
    uri->port = 0;
    printf("ref empty server again: %d", xmlParseURIReference(uri, "http:///p"));
    put_uri(uri);
    printf("ref failure: %d", xmlParseURIReference(uri, "a b"));
    put_uri(uri);
    printf("ref null: %d\n", xmlParseURIReference(uri, NULL));
    uri->cleanup = 1;
    printf("ref unwise: %d", xmlParseURIReference(uri, "http://h/{a}|b^`"));
    put_uri(uri);
    uri->cleanup = 4;
    printf("ref ucschar: %d", xmlParseURIReference(uri, "http://h/a b<c>\"\xc3\xa9"));
    put_uri(uri);
    uri->cleanup = 2;
    printf("ref raw: %d", xmlParseURIReference(uri, "http://h/%41?%42#%43"));
    put_uri(uri);
    xmlFreeURI(uri);

    uri = NULL;
    printf("safe null string: %d %s\n", xmlParseURISafe(NULL, &uri),
           uri ? "uri" : "null");
    printf("safe null out: %d\n", xmlParseURISafe("x", NULL));
    printf("parse null: %s\n", xmlParseURI(NULL) ? "uri" : "null");
    printf("raw null: %s\n", xmlParseURIRaw(NULL, 0) ? "uri" : "null");
    printf("reference null uri: %d\n", xmlParseURIReference(NULL, "x"));
    printf("save null: %s\n", xmlSaveUri(NULL) ? "text" : "null");
    xmlFreeURI(NULL);
}

static char *dup(const char *text) {
    return text ? (char *)xmlStrdup((const xmlChar *)text) : NULL;
}

static void test_save(void) {
    struct {
        const char *scheme, *opaque, *authority, *server, *user;
        int port;
        const char *path, *query, *fragment, *query_raw;
    } cases[] = {
        {"s", "op aque/?#\xc3\xa9", NULL, "h", NULL, 0, "/p", "q", "f", NULL},
        {"s", NULL, "a b@c:d", NULL, NULL, 0, "/p", NULL, NULL, NULL},
        {"s", NULL, "ignored", "h", "u s;:&=+$,@", 8, "/p q", NULL, NULL, NULL},
        {NULL, NULL, NULL, NULL, NULL, -1, "/p", NULL, NULL, NULL},
        {NULL, NULL, NULL, NULL, NULL, 5, NULL, NULL, NULL, NULL},
        {"file", NULL, NULL, NULL, NULL, 0, "/c:/x y", NULL, NULL, NULL},
        {"FILE", NULL, NULL, NULL, NULL, 0, "/c:/x", NULL, NULL, NULL},
        {"s", NULL, NULL, NULL, NULL, 0, "p/;@&=+$,?#[]", "a b?/[]#",
         "f g#[]", NULL},
        {"s", NULL, NULL, NULL, NULL, 0, NULL, "cooked", NULL, "raw b%20"},
        {NULL, NULL, NULL, "h", NULL, 2147483647, NULL, NULL, NULL, NULL},
        {NULL, NULL, NULL, "[::1]", NULL, 0, "", "", "", NULL},
    };

    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        xmlURIPtr uri = xmlCreateURI();

        assert(uri != NULL);
        uri->scheme = dup(cases[i].scheme);
        uri->opaque = dup(cases[i].opaque);
        uri->authority = dup(cases[i].authority);
        uri->server = dup(cases[i].server);
        uri->user = dup(cases[i].user);
        uri->port = cases[i].port;
        uri->path = dup(cases[i].path);
        uri->query = dup(cases[i].query);
        uri->fragment = dup(cases[i].fragment);
        uri->query_raw = dup(cases[i].query_raw);
        printf("save %zu:", i);
        put_uri(uri);
        if (i == 0) {
            printf("print: ");
            fflush(stdout);
            xmlPrintURI(stdout, uri);
            putchar('\n');
        }
        xmlFreeURI(uri);
    }
}

int main(void) {
    test_parse();
    test_reference();
    test_save();
    puts("uri tests passed");
    return 0;
}
