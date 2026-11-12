/* The encoding a parse records in the document (doc->encoding) and the
 * serializations that use it when they are given no encoding:
 * xmlDocDumpMemory, xmlDocDumpFormatMemory, xmlDocDumpMemoryEnc with NULL,
 * xmlDocDump, xmlSaveFile, xmlSaveDoc and xmlSaveTree of a save context
 * without an encoding, xmlSaveFileTo, and xmlCopyDoc.  The output of this
 * program is compared between libxml3 and the pinned reference libxml2
 * (make test-doc-encoding), so every line must describe behavior both
 * share. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlIO.h>
#include <libxml/xmlsave.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void put_text(const char *value, size_t length) {
    putchar('"');
    for (size_t i = 0; i < length; ++i) {
        unsigned char c = (unsigned char)value[i];
        if (c < 0x20 || c >= 0x7f || c == '"' || c == '\\')
            printf("\\x%02x", (unsigned)c);
        else
            putchar(c);
    }
    putchar('"');
}

static void put_line(const char *label, const xmlChar *text, int size) {
    printf("  %s: ", label);
    if (text == NULL)
        fputs("null", stdout);
    else
        put_text((const char *)text, (size_t)size);
    putchar('\n');
}

static void put_buffer(const char *label, xmlBufferPtr buffer) {
    put_line(label, xmlBufferContent(buffer), xmlBufferLength(buffer));
    xmlBufferFree(buffer);
}

static void serializations(xmlDocPtr doc) {
    xmlChar *text = NULL;
    int size = 0;
    xmlBufferPtr buffer;
    xmlSaveCtxtPtr save;
    xmlDocPtr copy;
    char path[] = "/tmp/xml3-doc-encoding-XXXXXX";
    FILE *file;
    int fd;
    char read_back[256];
    size_t count;

    xmlDocDumpMemory(doc, &text, &size);
    put_line("dump", text, size);
    xmlFree(text);
    xmlDocDumpFormatMemory(doc, &text, &size, 1);
    put_line("dump formatted", text, size);
    xmlFree(text);
    xmlDocDumpMemoryEnc(doc, &text, &size, NULL);
    put_line("dump null encoding", text, size);
    xmlFree(text);
    /* An explicit encoding wins over the document's. */
    xmlDocDumpMemoryEnc(doc, &text, &size, "UTF-8");
    put_line("dump UTF-8", text, size);
    xmlFree(text);

    buffer = xmlBufferCreate();
    save = xmlSaveToBuffer(buffer, NULL, 0);
    xmlSaveDoc(save, doc);
    xmlSaveClose(save);
    put_buffer("save doc", buffer);
    buffer = xmlBufferCreate();
    save = xmlSaveToBuffer(buffer, NULL, 0);
    xmlSaveTree(save, (xmlNodePtr)doc);
    xmlSaveClose(save);
    put_buffer("save tree", buffer);
    buffer = xmlBufferCreate();
    xmlSaveFileTo(xmlOutputBufferCreateBuffer(buffer, NULL), doc, NULL);
    put_buffer("save file to", buffer);

    fd = mkstemp(path);
    assert(fd >= 0);
    close(fd);
    xmlSaveFile(path, doc);
    file = fopen(path, "r");
    count = fread(read_back, 1, sizeof(read_back), file);
    fclose(file);
    put_line("save file", (const xmlChar *)read_back, (int)count);
    file = fopen(path, "w+");
    xmlDocDump(file, doc);
    rewind(file);
    count = fread(read_back, 1, sizeof(read_back), file);
    fclose(file);
    put_line("doc dump", (const xmlChar *)read_back, (int)count);
    unlink(path);

    copy = xmlCopyDoc(doc, 1);
    printf("  copy encoding: %s\n",
           copy->encoding ? (const char *)copy->encoding : "null");
    xmlDocDumpMemory(copy, &text, &size);
    put_line("copy dump", text, size);
    xmlFree(text);
    xmlFreeDoc(copy);
    /* Node copies of a document copy its encoding too. */
    copy = (xmlDocPtr)xmlCopyNode((xmlNodePtr)doc, 1);
    printf("  node copy encoding: %s\n",
           copy && copy->encoding ? (const char *)copy->encoding : "null");
    xmlFreeDoc(copy);
    copy = (xmlDocPtr)xmlDocCopyNode((xmlNodePtr)doc, NULL, 1);
    printf("  doc node copy encoding: %s\n",
           copy && copy->encoding ? (const char *)copy->encoding : "null");
    xmlFreeDoc(copy);
    copy = xmlCopyDoc(doc, 0);
    printf("  shallow copy encoding: %s\n",
           copy->encoding ? (const char *)copy->encoding : "null");
    xmlFreeDoc(copy);
}

/* With serialize 0 only the recorded encoding is compared: libxml2 writes
 * a UTF-16 document in UTF-16, which the libxml3 serializer cannot. */
static void read_case(const char *label, const char *input, int length,
                      const char *encoding, int serialize) {
    xmlDocPtr doc = xmlReadMemory(input, length, NULL, encoding, 0);

    printf("%s: ", label);
    if (doc == NULL) {
        puts("no document");
        return;
    }
    printf("encoding=%s\n",
           doc->encoding ? (const char *)doc->encoding : "null");
    if (serialize)
        serializations(doc);
    xmlFreeDoc(doc);
}

#define READ(label, input, encoding) \
    read_case(label, input, (int)sizeof(input) - 1, encoding, 1)
#define READ_ONLY(label, input, encoding) \
    read_case(label, input, (int)sizeof(input) - 1, encoding, 0)

int main(void) {
    xmlDocPtr doc;

    READ("declared UTF-8",
         "<?xml version='1.0' encoding='UTF-8'?><r a='\xc3\xa9'>\xc3\xa9"
         "<c>t</c></r>",
         NULL);
    READ("declared utf-8", "<?xml version='1.0' encoding='utf-8'?><r>\xc3\xa9</r>",
         NULL);
    READ("declared Utf-8", "<?xml version=\"1.0\" encoding=\"Utf-8\" ?><r/>",
         NULL);
    READ("no encoding declared", "<?xml version='1.0'?><r>\xc3\xa9</r>", NULL);
    READ("no declaration", "<r>\xc3\xa9</r>", NULL);
    READ("requested UTF-8", "<r>\xc3\xa9</r>", "UTF-8");
    READ("requested utf8", "<r>\xc3\xa9</r>", "utf8");
    READ("requested over declared",
         "<?xml version='1.0' encoding='utf-8'?><r>\xc3\xa9</r>", "UTF-8");
    READ("byte order mark", "\xef\xbb\xbf<r>\xc3\xa9</r>", NULL);
    READ("byte order mark and declaration",
         "\xef\xbb\xbf<?xml version='1.0' encoding='utf-8'?><r>\xc3\xa9</r>",
         NULL);
    READ("utf-16 without declaration", "\xff\xfe<\0r\0/\0>\0", NULL);
    READ_ONLY("requested UTF-16", "\xff\xfe<\0r\0/\0>\0", "UTF-16");
    READ_ONLY("requested UTF-16LE", "<\0r\0/\0>\0", "UTF-16LE");
    READ_ONLY("requested UTF-16BE", "\0<\0r\0/\0>", "UTF-16BE");

    doc = xmlNewDoc(BAD_CAST "1.0");
    printf("new document: encoding=%s\n",
           doc->encoding ? (const char *)doc->encoding : "null");
    xmlDocSetRootElement(doc, xmlNewNode(NULL, BAD_CAST "n"));
    serializations(doc);
    xmlFreeDoc(doc);
    puts("document encoding tests passed");
    return 0;
}
