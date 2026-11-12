/* xmlReadFile and xmlParseFile.  The output of this program is compared
 * between libxml3 and the pinned reference libxml2 (make test-input), so
 * every line must describe behavior both share.  Paths are printed
 * relative to the test's temporary directory. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char directory[64];

static void put_text(const char *value) {
    if (value == NULL) {
        fputs("null", stdout);
        return;
    }
    /* Hide the random directory name. */
    for (const char *at = strstr(value, directory); at != NULL;
         at = strstr(value, directory)) {
        fwrite(value, 1, (size_t)(at - value), stdout);
        fputs("<dir>", stdout);
        value = at + strlen(directory);
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

static void report(const char *label, xmlDocPtr doc) {
    const xmlError *error = xmlGetLastError();

    printf("%s: doc=%s", label, doc ? "yes" : "no");
    if (doc != NULL) {
        xmlChar *memory = NULL;
        int size = 0;

        xmlDocDumpMemory(doc, &memory, &size);
        fputs(" dump=", stdout);
        put_text((const char *)memory);
        xmlFree(memory);
        xmlFreeDoc(doc);
    }
    if (error == NULL) {
        puts(" error=none");
        return;
    }
    printf(" error=%d/%d level=%d line=%d int2=%d file=", error->domain,
           error->code, error->level, error->line, error->int2);
    put_text(error->file);
    /* Parser messages are compared elsewhere; the I/O ones are new here. */
    if (error->domain == XML_FROM_IO) {
        fputs(" str1=", stdout);
        put_text(error->str1);
        fputs(" message=", stdout);
        put_text(error->message);
    }
    putchar('\n');
}

static void write_bytes(const char *name, const char *text, size_t length) {
    char path[160];
    FILE *file;

    snprintf(path, sizeof(path), "%s/%s", directory, name);
    file = fopen(path, "wb");
    assert(file != NULL);
    assert(fwrite(text, 1, length, file) == length);
    fclose(file);
}

static void write_file(const char *name, const char *text) {
    write_bytes(name, text, strlen(text));
}

static void read_case(const char *label, const char *name, int options) {
    char path[200];

    snprintf(path, sizeof(path), "%s/%s", directory, name);
    xmlResetLastError();
    report(label, xmlReadFile(path, NULL, options));
}

int main(void) {
    char path[200], uri[260];

    strcpy(directory, "/tmp/xml3-input-XXXXXX");
    assert(mkdtemp(directory) != NULL);
    write_file("ok.xml", "<?xml version='1.0'?>\n<r a='1'>\n  <c>t</c>\n</r>\n");
    write_file("bad.xml", "<r>\n<a>\n</r>");
    write_file("empty.xml", "");
    write_file("space name.xml", "<s/>");
    write_bytes("utf16.xml", "\xff\xfe<\0r\0/\0>\0", 10);

    read_case("ok", "ok.xml", 0);
    read_case("ok nonet", "ok.xml", XML_PARSE_NONET);
    read_case("malformed", "bad.xml", 0);
    read_case("empty", "empty.xml", 0);
    read_case("missing", "missing.xml", 0);
    read_case("space name", "space name.xml", 0);
    read_case("escaped name is literal", "space%20name.xml", 0);
    read_case("utf-16", "utf16.xml", 0);
    read_case("directory", "", 0);

    snprintf(path, sizeof(path), "%s/ok.xml", directory);
    xmlResetLastError();
    report("parse file", xmlParseFile(path));
    snprintf(path, sizeof(path), "%s/missing.xml", directory);
    xmlResetLastError();
    report("parse file missing", xmlParseFile(path));
    snprintf(uri, sizeof(uri), "file://%s/space%%20name.xml", directory);
    xmlResetLastError();
    report("file uri", xmlReadFile(uri, NULL, 0));
    snprintf(uri, sizeof(uri), "file://localhost%s/ok.xml", directory);
    xmlResetLastError();
    report("file localhost uri", xmlReadFile(uri, NULL, 0));
    xmlResetLastError();
    report("null name", xmlReadFile(NULL, NULL, 0));

    for (const char *name = "ok.xml bad.xml empty.xml space name.xml utf16.xml";
         *name;) {
        const char *end = strstr(name, ".xml") + 4;
        char file[80];

        snprintf(file, sizeof(file), "%.*s", (int)(end - name), name);
        snprintf(path, sizeof(path), "%s/%s", directory, file);
        unlink(path);
        name = *end ? end + 1 : end;
    }
    assert(rmdir(directory) == 0);
    puts("input tests passed");
    return 0;
}
