#ifdef XML3_REFERENCE_TEST
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#include <libxml/xmlversion.h>
#else
#include <libxml3.h>
#endif

#include <assert.h>
#include <errno.h>
#include <limits.h>
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

static void print_hex(const xmlChar *value) {
    if (value == NULL) {
        fputs("null", stdout);
        return;
    }
    putchar('"');
    for (const unsigned char *byte = value; *byte != 0; ++byte)
        printf("%02x", *byte);
    putchar('"');
}

static void snapshot(const unsigned char *input, int input_length,
                    const char *encoding) {
    xmlDocPtr doc;
    xmlNodePtr root;
    xmlChar *content = NULL;
    xmlChar *attribute = NULL;
    const xmlError *error;

    xmlResetLastError();
    doc = xmlReadMemory((const char *)input, input_length, "encoding.xml",
                        encoding, XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
    error = xmlGetLastError();
    root = doc == NULL ? NULL : xmlDocGetRootElement(doc);
    if (root != NULL) {
        content = xmlNodeGetContent(root);
        attribute = xmlGetProp(root, BAD_CAST "attr");
    }

    printf("{\"tree\":%s,\"domain\":",
           doc == NULL ? "false" : "true");
    if (error == NULL) {
        fputs("null,\"code\":null,\"level\":null,\"line\":null,"
              "\"int1\":null,\"int2\":null", stdout);
    } else {
        printf("%d,\"code\":%d,\"level\":%d,\"line\":%d,"
               "\"int1\":%d,\"int2\":%d",
               error->domain, error->code, error->level, error->line,
               error->int1, error->int2);
    }
    fputs(",\"name_hex\":", stdout);
    print_hex(root == NULL ? NULL : root->name);
    fputs(",\"content_hex\":", stdout);
    print_hex(content);
    fputs(",\"attribute_hex\":", stdout);
    print_hex(attribute);
    puts("}");

    xmlFree(content);
    xmlFree(attribute);
    if (doc != NULL)
        xmlFreeDoc(doc);
}

int main(int argc, char **argv) {
    char *end;
    long length;
    unsigned char *input;
    const char *encoding;

    check_reference_version();
    assert(argc == 3);
    errno = 0;
    length = strtol(argv[1], &end, 10);
    assert(errno == 0 && end != argv[1] && *end == '\0');
    assert(length >= 0 && length <= INT_MAX);
    encoding = strcmp(argv[2], "-") == 0 ? NULL : argv[2];
    input = malloc(length == 0 ? 1 : (size_t)length);
    assert(input != NULL);
    assert(fread(input, 1, (size_t)length, stdin) == (size_t)length);
    assert(getchar() == EOF && !ferror(stdin));
    snapshot(input, (int)length, encoding);
    free(input);
    return 0;
}
