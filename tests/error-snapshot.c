#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

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

static unsigned char hex_value(char byte) {
    if (byte >= '0' && byte <= '9')
        return (unsigned char)(byte - '0');
    if (byte >= 'a' && byte <= 'f')
        return (unsigned char)(byte - 'a' + 10);
    if (byte >= 'A' && byte <= 'F')
        return (unsigned char)(byte - 'A' + 10);
    abort();
}

static void snapshot(const char *input, int input_length) {
    xmlDocPtr doc = xmlReadMemory(input, input_length, "fixture.xml", NULL,
                                 XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
    const xmlError *error = xmlGetLastError();
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
}

int main(int argc, char **argv) {
    size_t input_length;
    unsigned char *input;

    check_reference_version();
    assert(argc >= 2);
    xmlResetLastError();
    if (strcmp(argv[1], "--sequence") == 0) {
        assert(argc == 2);
        snapshot("<r></s>", 7);
        snapshot("<r/>", 4);
        snapshot(NULL, 0);
        snapshot("<r/>", -1);
        xmlResetLastError();
        snapshot("<r/>", 4);
        return 0;
    }
    if (strcmp(argv[1], "--stdin") == 0) {
        char *end;
        long length;
        assert(argc == 3);
        errno = 0;
        length = strtol(argv[2], &end, 10);
        assert(errno == 0 && end != argv[2] && *end == '\0');
        assert(length >= 0 && length <= INT_MAX);
        input_length = (size_t)length;
        input = malloc(input_length == 0 ? 1 : input_length);
        assert(input != NULL);
        assert(fread(input, 1, input_length, stdin) == input_length);
        assert(getchar() == EOF && !ferror(stdin));
    } else {
        size_t hex_length;
        assert(argc == 2);
        hex_length = strlen(argv[1]);
        assert(hex_length % 2 == 0);
        input_length = hex_length / 2;
        assert(input_length <= INT_MAX);
        input = malloc(input_length == 0 ? 1 : input_length);
        assert(input != NULL);
        for (size_t i = 0; i < input_length; ++i)
            input[i] = (unsigned char)((hex_value(argv[1][2 * i]) << 4) |
                                       hex_value(argv[1][2 * i + 1]));
    }
    snapshot((const char *)input, (int)input_length);
    free(input);
    return 0;
}
