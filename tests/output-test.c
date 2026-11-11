/* xmlBuffer, xmlNodeDump and the stream and file serializers.  The output
 * of this program is compared between libxml3 and the pinned reference
 * libxml2 (make test-output), so every line must describe behavior both
 * share. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char directory[64];

static void put_bytes(const unsigned char *value, size_t length) {
    putchar('"');
    for (size_t i = 0; i < length; ++i) {
        if (value[i] < 0x20 || value[i] >= 0x7f || value[i] == '"' ||
            value[i] == '\\')
            printf("\\x%02x", (unsigned)value[i]);
        else
            putchar(value[i]);
    }
    putchar('"');
}

static void put_buffer(const char *label, xmlBufferPtr buf) {
    const xmlChar *content = xmlBufferContent(buf);
    int length = xmlBufferLength(buf);

    printf("%s: length=%d size=%u content=", label, length, buf->size);
    if (content == NULL)
        fputs("null", stdout);
    else {
        assert(content[length] == 0);
        put_bytes(content, (size_t)length);
    }
    putchar('\n');
}

static void test_buffers(void) {
    xmlBufferPtr buf = xmlBufferCreate();
    xmlBufferPtr sized;
    xmlChar *detached;
    char big[600];

    assert(buf != NULL);
    put_buffer("created", buf);
    printf("add=%d\n", xmlBufferAdd(buf, BAD_CAST "hello", -1));
    printf("add part=%d\n", xmlBufferAdd(buf, BAD_CAST ", world!", 7));
    printf("cat=%d ccat=%d\n", xmlBufferCat(buf, BAD_CAST "<"),
           xmlBufferCCat(buf, ">"));
    put_buffer("after adds", buf);
    printf("shrink=%d\n", xmlBufferShrink(buf, 3));
    put_buffer("after shrink", buf);
    printf("add head (into shrunk room)=%d\n",
           xmlBufferAddHead(buf, BAD_CAST "AB", 2));
    put_buffer("after head", buf);
    printf("add head (moving)=%d\n", xmlBufferAddHead(buf, BAD_CAST "xyz", -1));
    put_buffer("after head move", buf);
    printf("shrink too far=%d shrink 0=%d\n", xmlBufferShrink(buf, 1000),
           xmlBufferShrink(buf, 0));
    memset(big, 'b', sizeof(big) - 1);
    big[sizeof(big) - 1] = 0;
    printf("grow by add=%d\n", xmlBufferAdd(buf, BAD_CAST big, -1));
    put_buffer("after growth", buf);
    printf("grow small=%d\n", xmlBufferGrow(buf, 10));
    printf("grow large=%d\n", xmlBufferGrow(buf, 5000));
    printf("resize smaller=%d resize larger=%d\n", xmlBufferResize(buf, 10),
           xmlBufferResize(buf, 20000));
    printf("size after resize=%u\n", buf->size);
    xmlBufferEmpty(buf);
    put_buffer("emptied", buf);
    xmlBufferWriteCHAR(buf, BAD_CAST "a");
    xmlBufferWriteChar(buf, "b");
    xmlBufferWriteQuotedString(buf, BAD_CAST "plain");
    xmlBufferWriteQuotedString(buf, BAD_CAST "say \"hi\"");
    xmlBufferWriteQuotedString(buf, BAD_CAST "it's \"both\"");
    put_buffer("written", buf);
    xmlBufferShrink(buf, 2);
    detached = xmlBufferDetach(buf);
    printf("detached=");
    put_bytes(detached, strlen((const char *)detached));
    putchar('\n');
    xmlFree(detached);
    put_buffer("after detach", buf);
    printf("add after detach=%d\n", xmlBufferAdd(buf, BAD_CAST "again", -1));
    put_buffer("reused", buf);
    xmlBufferFree(buf);

    sized = xmlBufferCreateSize(0);
    put_buffer("size 0", sized);
    printf("add to size 0=%d\n", xmlBufferAdd(sized, BAD_CAST "x", 1));
    put_buffer("size 0 after add", sized);
    xmlBufferFree(sized);
    sized = xmlBufferCreateSize(10);
    put_buffer("size 10", sized);
    xmlBufferFree(sized);
    sized = xmlBufferCreateStatic((void *)"static text", 6);
    put_buffer("static", sized);
    xmlBufferFree(sized);

    printf("null args: add=%d head=%d cat=%d ccat=%d shrink=%d grow=%d "
           "resize=%d length=%d content=%s detach=%s\n",
           xmlBufferAdd(NULL, BAD_CAST "x", 1),
           xmlBufferAddHead(NULL, BAD_CAST "x", 1),
           xmlBufferCat(NULL, BAD_CAST "x"), xmlBufferCCat(NULL, "x"),
           xmlBufferShrink(NULL, 1), xmlBufferGrow(NULL, 1),
           xmlBufferResize(NULL, 1), xmlBufferLength(NULL),
           xmlBufferContent(NULL) ? "set" : "null",
           xmlBufferDetach(NULL) ? "set" : "null");
    buf = xmlBufferCreate();
    printf("null text: add=%d head=%d\n", xmlBufferAdd(buf, NULL, 1),
           xmlBufferAddHead(buf, NULL, 1));
    xmlBufferFree(buf);
    xmlBufferFree(NULL);
    xmlBufferEmpty(NULL);
}

static const char sample[] =
    "<r xmlns:a='urn:a'><a:x k='v&amp;' a:k='w'><y>t&lt;</y><!--c-->"
    "<?pi data?><![CDATA[<cd>]]><z/></a:x><m>mixed<b/>text</m></r>";

static void dump_node(const char *label, xmlNodePtr node, int level,
                      int format) {
    xmlBufferPtr buf = xmlBufferCreate();
    int result = xmlNodeDump(buf, node->doc, node, level, format);

    printf("%s level=%d format=%d: %d ", label, level, format, result);
    put_bytes(xmlBufferContent(buf), (size_t)xmlBufferLength(buf));
    putchar('\n');
    xmlBufferFree(buf);
}

static void test_node_dumps(void) {
    xmlDocPtr doc = xmlReadMemory(sample, (int)strlen(sample), NULL, NULL, 0);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlNodePtr x = root->children;
    xmlNodePtr m = x->next;
    static const int levels[] = {0, 1, 3, -5, 200};
    xmlBufferPtr buf;

    for (size_t i = 0; i < sizeof(levels) / sizeof(levels[0]); ++i)
        for (int format = 0; format <= 1; ++format)
            dump_node("element", x, levels[i], format);
    dump_node("mixed", m, 1, 1);
    dump_node("root", root, 0, 1);
    dump_node("root", root, 2, 1);
    dump_node("root", root, 40, 1);
    for (xmlNodePtr child = x->children; child; child = child->next)
        dump_node("child", child, 2, 1);
    dump_node("attribute", (xmlNodePtr)x->properties, 0, 0);
    dump_node("prefixed attribute", (xmlNodePtr)x->properties->next, 0, 0);
    dump_node("document", (xmlNodePtr)doc, 0, 0);
    dump_node("document formatted", (xmlNodePtr)doc, 0, 1);

    buf = xmlBufferCreate();
    xmlBufferCCat(buf, "prefix|");
    printf("append to content: %d ", xmlNodeDump(buf, doc, x->children, 0, 0));
    put_buffer("", buf);
    printf("null args: %d %d\n", xmlNodeDump(NULL, doc, x, 0, 0),
           xmlNodeDump(buf, doc, NULL, 0, 0));
    xmlBufferFree(buf);
    xmlFreeDoc(doc);
}

static void put_file(const char *label, const char *path) {
    FILE *file = fopen(path, "rb");
    unsigned char data[2048];
    size_t length;

    printf("%s: ", label);
    if (file == NULL) {
        puts("missing");
        return;
    }
    length = fread(data, 1, sizeof(data), file);
    fclose(file);
    put_bytes(data, length);
    putchar('\n');
    unlink(path);
}

static void test_streams_and_files(void) {
    xmlDocPtr doc = xmlReadMemory(sample, (int)strlen(sample), NULL, NULL, 0);
    xmlNodePtr x = xmlDocGetRootElement(doc)->children;
    char path[160], name[200];
    FILE *file;
    int result;

    snprintf(path, sizeof(path), "%s/stream.xml", directory);
    file = fopen(path, "wb");
    assert(file != NULL);
    xmlElemDump(file, doc, x);
    result = xmlDocDump(file, doc);
    printf("xmlDocDump=%d\n", result);
    result = xmlDocFormatDump(file, doc, 1);
    printf("xmlDocFormatDump=%d\n", result);
    fclose(file);
    put_file("stream", path);
    printf("null stream: %d %d\n", xmlDocDump(NULL, doc),
           xmlDocFormatDump(NULL, doc, 1));
    xmlElemDump(NULL, doc, x);

    snprintf(path, sizeof(path), "%s/plain.xml", directory);
    printf("xmlSaveFile=%d\n", xmlSaveFile(path, doc));
    put_file("plain", path);
    snprintf(path, sizeof(path), "%s/formatted.xml", directory);
    printf("xmlSaveFormatFile=%d\n", xmlSaveFormatFile(path, doc, 1));
    put_file("formatted", path);
    snprintf(path, sizeof(path), "%s/encoded.xml", directory);
    printf("xmlSaveFileEnc=%d\n", xmlSaveFileEnc(path, doc, "UTF-8"));
    put_file("encoded", path);
    snprintf(path, sizeof(path), "%s/both.xml", directory);
    printf("xmlSaveFormatFileEnc=%d\n",
           xmlSaveFormatFileEnc(path, doc, "UTF-8", 1));
    put_file("both", path);

    /* A name without a scheme is URI-unescaped. */
    snprintf(name, sizeof(name), "%s/space%%20name.xml", directory);
    snprintf(path, sizeof(path), "%s/space name.xml", directory);
    printf("escaped name=%d\n", xmlSaveFile(name, doc));
    put_file("escaped", path);
    /* A file: URI is unescaped after its prefix. */
    snprintf(path, sizeof(path), "%s/uri.xml", directory);
    if (path[0] == '/') {
        snprintf(name, sizeof(name), "file://%s", path);
        printf("file uri=%d\n", xmlSaveFile(name, doc));
        put_file("file uri", path);
    }
    snprintf(path, sizeof(path), "%s/missing/dir.xml", directory);
    printf("missing directory=%d\n", xmlSaveFile(path, doc));
    printf("null args: %d %d\n", xmlSaveFile(NULL, doc),
           xmlSaveFile(path, NULL));
    xmlFreeDoc(doc);
}

int main(void) {
    char cwd[256];

    strcpy(directory, "/tmp/xml3-output-XXXXXX");
    assert(mkdtemp(directory) != NULL);
    assert(getcwd(cwd, sizeof(cwd)) != NULL);
    test_buffers();
    test_node_dumps();
    test_streams_and_files();
    assert(rmdir(directory) == 0);
    puts("output tests passed");
    return 0;
}
