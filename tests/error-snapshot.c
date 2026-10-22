#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

#include <assert.h>
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

static unsigned char hex_value(char byte) {
    if (byte >= '0' && byte <= '9')
        return (unsigned char)(byte - '0');
    if (byte >= 'a' && byte <= 'f')
        return (unsigned char)(byte - 'a' + 10);
    if (byte >= 'A' && byte <= 'F')
        return (unsigned char)(byte - 'A' + 10);
    abort();
}

int main(int argc, char **argv) {
    size_t hex_length;
    size_t input_length;
    unsigned char *input;
    xmlDocPtr doc;
    const xmlError *error;

    check_reference_version();
    assert(argc == 2);
    hex_length = strlen(argv[1]);
    assert(hex_length % 2 == 0);
    input_length = hex_length / 2;
    input = malloc(input_length == 0 ? 1 : input_length);
    assert(input != NULL);
    for (size_t i = 0; i < input_length; ++i)
        input[i] = (unsigned char)((hex_value(argv[1][2 * i]) << 4) |
                                   hex_value(argv[1][2 * i + 1]));

    xmlResetLastError();
    doc = xmlReadMemory((const char *)input, (int)input_length,
                        "fixture.xml", NULL,
                        XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
    error = xmlGetLastError();
    printf("{\"tree\":%s,\"domain\":", doc != NULL ? "true" : "false");
    if (error == NULL) {
        puts("null,\"code\":null,\"level\":null,\"line\":null,"
             "\"int1\":null,\"int2\":null}");
    } else {
        printf("%d,\"code\":%d,\"level\":%d,\"line\":%d,"
               "\"int1\":%d,\"int2\":%d}\n",
               error->domain, error->code, error->level, error->line,
               error->int1, error->int2);
    }
    if (doc != NULL)
        xmlFreeDoc(doc);
    free(input);
    return 0;
}
