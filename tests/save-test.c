/* The save context API of xmlsave.h: xmlSaveToBuffer, xmlSaveToFilename,
 * xmlSaveToFd and xmlSaveToIO, xmlSaveDoc and xmlSaveTree with their
 * options, xmlSaveSetIndentString, xmlSaveFlush, xmlSaveClose and
 * xmlSaveFinish.  The output of this program is compared between libxml3
 * and the pinned reference libxml2 (make test-save), so every line must
 * describe behavior both share. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#include <libxml/xmlsave.h>

#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char directory[64];

static void put_text(const char *value, int length) {
    if (value == NULL) {
        fputs("null", stdout);
        return;
    }
    putchar('"');
    for (int i = 0; i < length; ++i) {
        unsigned char c = (unsigned char)value[i];
        if (c < 0x20 || c >= 0x7f || c == '"' || c == '\\')
            printf("\\x%02x", (unsigned)c);
        else
            putchar(c);
    }
    putchar('"');
}

static void put_error(void) {
    const xmlError *error = xmlGetLastError();

    if (error == NULL)
        fputs(" error=none", stdout);
    else
        printf(" error=%d/%d level=%d", error->domain, error->code,
               error->level);
}

static void put_buffer(xmlBufferPtr buf) {
    put_text((const char *)xmlBufferContent(buf), xmlBufferLength(buf));
}

static const char text[] =
    "<?xml version='1.0'?>\n<?pi data?>\n"
    "<r xmlns:p='urn:p' a='1'><p:c>t\xc3\xa9</p:c><e/>"
    "<f><g><h/></g></f><!--c--><m>x<n/></m></r>";

static void save_doc(xmlDocPtr doc, const char *encoding, int options) {
    xmlBufferPtr buf = xmlBufferCreate();
    xmlSaveCtxtPtr ctxt;
    long saved;
    int before, closed;

    assert(buf != NULL);
    ctxt = xmlSaveToBuffer(buf, encoding, options);
    assert(ctxt != NULL);
    saved = xmlSaveDoc(ctxt, doc);
    before = xmlBufferLength(buf);
    closed = xmlSaveClose(ctxt);
    printf("doc %s %d: saved=%ld before=%d close=%d ", encoding ? encoding : "null",
           options, saved, before, closed);
    put_buffer(buf);
    putchar('\n');
    xmlBufferFree(buf);
}

static void save_tree(const char *label, xmlNodePtr node, const char *encoding,
                      int options) {
    xmlBufferPtr buf = xmlBufferCreate();
    xmlSaveCtxtPtr ctxt;
    long saved;
    int closed;

    assert(buf != NULL);
    ctxt = xmlSaveToBuffer(buf, encoding, options);
    assert(ctxt != NULL);
    saved = xmlSaveTree(ctxt, node);
    closed = xmlSaveClose(ctxt);
    printf("tree %s %s %d: saved=%ld close=%d ", label,
           encoding ? encoding : "null", options, saved, closed);
    put_buffer(buf);
    putchar('\n');
    xmlBufferFree(buf);
}

static void test_options(xmlDocPtr doc) {
    static const int options[] = {
        0,
        XML_SAVE_FORMAT,
        XML_SAVE_NO_DECL,
        XML_SAVE_NO_EMPTY,
        XML_SAVE_FORMAT | XML_SAVE_NO_EMPTY,
        XML_SAVE_FORMAT | XML_SAVE_NO_INDENT,
        XML_SAVE_FORMAT | XML_SAVE_NO_DECL,
        XML_SAVE_FORMAT | XML_SAVE_AS_XML | XML_SAVE_NO_XHTML |
            XML_SAVE_EMPTY | XML_SAVE_INDENT,
    };
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlNodePtr f = root->children->next->next;

    for (size_t i = 0; i < sizeof(options) / sizeof(options[0]); ++i) {
        save_doc(doc, NULL, options[i]);
        save_doc(doc, "UTF-8", options[i]);
    }
    save_tree("root", root, NULL, XML_SAVE_FORMAT);
    save_tree("root", root, "UTF-8", XML_SAVE_FORMAT | XML_SAVE_NO_EMPTY);
    save_tree("f", f, NULL, XML_SAVE_FORMAT);
    save_tree("f", f, NULL, XML_SAVE_FORMAT | XML_SAVE_NO_INDENT);
    save_tree("text", root->children->children, NULL, 0);
    save_tree("text", root->children->children, "UTF-8", 0);
    save_tree("attribute", (xmlNodePtr)root->properties, NULL, 0);
    save_tree("document", (xmlNodePtr)doc, NULL, XML_SAVE_NO_DECL);
    save_tree("document", (xmlNodePtr)doc, "UTF-8", XML_SAVE_FORMAT);
}

static void test_indent(xmlDocPtr doc) {
    xmlBufferPtr buf = xmlBufferCreate();
    xmlSaveCtxtPtr ctxt = xmlSaveToBuffer(buf, "UTF-8", XML_SAVE_FORMAT);
    char long_indent[62];

    assert(buf != NULL && ctxt != NULL);
    memset(long_indent, '-', 61);
    long_indent[61] = 0;
    printf("indent null: %d\n", xmlSaveSetIndentString(ctxt, NULL));
    printf("indent empty: %d\n", xmlSaveSetIndentString(ctxt, ""));
    printf("indent too long: %d\n", xmlSaveSetIndentString(ctxt, long_indent));
    printf("indent null ctxt: %d\n", xmlSaveSetIndentString(NULL, "\t"));
    printf("indent tab: %d\n", xmlSaveSetIndentString(ctxt, "\t"));
    xmlSaveDoc(ctxt, doc);
    long_indent[60] = 0;
    long_indent[0] = '<';
    printf("indent 60: %d\n", xmlSaveSetIndentString(ctxt, long_indent));
    xmlSaveTree(ctxt, xmlDocGetRootElement(doc));
    printf("indent close: %d ", xmlSaveClose(ctxt));
    put_buffer(buf);
    putchar('\n');

    /* Deep nesting stops indenting at 60 / size levels. */
    {
        xmlNodePtr top = xmlNewNode(NULL, BAD_CAST "d");
        xmlNodePtr cur = top;

        for (int i = 0; i < 25; ++i)
            cur = xmlNewChild(cur, NULL, BAD_CAST "d", NULL);
        xmlBufferEmpty(buf);
        ctxt = xmlSaveToBuffer(buf, NULL, XML_SAVE_FORMAT);
        assert(ctxt != NULL);
        assert(xmlSaveSetIndentString(ctxt, "abcde") == 0);
        xmlSaveTree(ctxt, top);
        printf("deep close: %d ", xmlSaveClose(ctxt));
        put_buffer(buf);
        putchar('\n');
        xmlFreeNode(top);
    }
    xmlBufferFree(buf);
}

static void test_flush(xmlDocPtr doc) {
    xmlBufferPtr buf = xmlBufferCreate();
    xmlSaveCtxtPtr ctxt = xmlSaveToBuffer(buf, "UTF-8", 0);
    xmlNodePtr big;
    int before;

    assert(buf != NULL && ctxt != NULL);
    printf("flush empty: %d\n", xmlSaveFlush(ctxt));
    printf("tree: %ld\n", xmlSaveTree(ctxt, xmlDocGetRootElement(doc)));
    printf("tree again: %ld\n", xmlSaveTree(ctxt, xmlDocGetRootElement(doc)));
    printf("length before flush: %d\n", xmlBufferLength(buf));
    printf("flush: %d\n", xmlSaveFlush(ctxt));
    printf("length after flush: %d\n", xmlBufferLength(buf));
    printf("flush again: %d\n", xmlSaveFlush(ctxt));
    printf("doc: %ld\n", xmlSaveDoc(ctxt, doc));
    printf("finish: %d ", xmlSaveFinish(ctxt));
    put_buffer(buf);
    putchar('\n');

    /* Output of 4000 bytes or more reaches the buffer before a flush. */
    big = xmlNewNode(NULL, BAD_CAST "big");
    for (int i = 0; i < 600; ++i)
        xmlNewChild(big, NULL, BAD_CAST "item", NULL);
    xmlBufferEmpty(buf);
    ctxt = xmlSaveToBuffer(buf, NULL, 0);
    assert(ctxt != NULL);
    xmlSaveTree(ctxt, big);
    before = xmlBufferLength(buf);
    /* How much is written before the close depends on the size of each
     * write, so only the whole output is compared. */
    printf("big: written before close=%s", before > 0 ? "yes" : "no");
    xmlSaveClose(ctxt);
    printf(" length=%d\n", xmlBufferLength(buf));
    xmlFreeNode(big);
    xmlBufferFree(buf);
}

static int write_calls;
static int write_total;
static int close_calls;

static int io_write(void *context, const char *data, int length) {
    xmlBufferPtr buf = context;

    write_calls++;
    write_total += length;
    xmlBufferAdd(buf, (const xmlChar *)data, length);
    return length;
}

static int io_close(void *context) {
    (void)context;
    close_calls++;
    return 0;
}

static int io_fail(void *context, const char *data, int length) {
    (void)context;
    (void)data;
    (void)length;
    return -1;
}

static void read_back(const char *label, const char *path) {
    char data[512];
    FILE *file = fopen(path, "rb");
    size_t length;

    assert(file != NULL);
    length = fread(data, 1, sizeof(data), file);
    fclose(file);
    printf("%s: ", label);
    put_text(data, (int)length);
    putchar('\n');
}

static void test_targets(xmlDocPtr doc) {
    char path[160];
    xmlSaveCtxtPtr ctxt;
    xmlBufferPtr buf = xmlBufferCreate();
    int fd;

    assert(buf != NULL);
    snprintf(path, sizeof(path), "%s/out.xml", directory);
    ctxt = xmlSaveToFilename(path, "UTF-8", XML_SAVE_FORMAT);
    assert(ctxt != NULL);
    printf("file created at open: %s\n", access(path, F_OK) == 0 ? "yes" : "no");
    printf("file doc: %ld\n", xmlSaveDoc(ctxt, doc));
    printf("file close: %d\n", xmlSaveClose(ctxt));
    read_back("file", path);

    snprintf(path, sizeof(path), "%s/missing/out.xml", directory);
    xmlResetLastError();
    ctxt = xmlSaveToFilename(path, NULL, 0);
    printf("file missing directory: %s", ctxt ? "yes" : "no");
    put_error();
    putchar('\n');
    if (ctxt != NULL)
        xmlSaveClose(ctxt);

    snprintf(path, sizeof(path), "%s/fd.xml", directory);
    fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    assert(fd >= 0);
    ctxt = xmlSaveToFd(fd, NULL, XML_SAVE_NO_DECL);
    assert(ctxt != NULL);
    printf("fd tree: %ld\n", xmlSaveTree(ctxt, xmlDocGetRootElement(doc)));
    printf("fd finish: %d\n", xmlSaveFinish(ctxt));
    printf("fd still open: %s\n", write(fd, "!", 1) == 1 ? "yes" : "no");
    close(fd);
    read_back("fd", path);
    unlink(path);
    snprintf(path, sizeof(path), "%s/out.xml", directory);
    unlink(path);

    write_calls = write_total = close_calls = 0;
    ctxt = xmlSaveToIO(io_write, io_close, buf, NULL, 0);
    assert(ctxt != NULL);
    {
        long saved = xmlSaveDoc(ctxt, doc);
        int closed;

        printf("io doc: %ld calls=%d\n", saved, write_calls);
        closed = xmlSaveClose(ctxt);
        printf("io close: %d calls=%d total=%d closes=%d ", closed,
               write_calls, write_total, close_calls);
    }
    put_buffer(buf);
    putchar('\n');

    close_calls = 0;
    ctxt = xmlSaveToIO(io_fail, io_close, NULL, NULL, 0);
    assert(ctxt != NULL);
    printf("io failing doc: %ld\n", xmlSaveDoc(ctxt, doc));
    printf("io failing flush: %d\n", xmlSaveFlush(ctxt));
    printf("io failing flush again: %d\n", xmlSaveFlush(ctxt));
    {
        int finished = xmlSaveFinish(ctxt);

        printf("io failing finish: %d closes=%d\n", finished, close_calls);
    }

    ctxt = xmlSaveToIO(io_fail, NULL, NULL, NULL, 0);
    assert(ctxt != NULL);
    xmlSaveDoc(ctxt, doc);
    printf("io failing close: %d\n", xmlSaveClose(ctxt));
    xmlBufferFree(buf);
}

static void test_arguments(xmlDocPtr doc) {
    xmlBufferPtr buf = xmlBufferCreate();
    xmlSaveCtxtPtr ctxt;

    assert(buf != NULL);
    xmlResetLastError();
    printf("null buffer: %s\n", xmlSaveToBuffer(NULL, NULL, 0) ? "yes" : "no");
    printf("null io: %s\n",
           xmlSaveToIO(NULL, NULL, NULL, NULL, 0) ? "yes" : "no");
    printf("null name: %s\n", xmlSaveToFilename(NULL, NULL, 0) ? "yes" : "no");
    printf("null ctxt doc: %ld\n", xmlSaveDoc(NULL, doc));
    printf("null ctxt tree: %ld\n", xmlSaveTree(NULL, (xmlNodePtr)doc));
    printf("null ctxt flush: %d\n", xmlSaveFlush(NULL));
    printf("null ctxt close: %d\n", xmlSaveClose(NULL));
    printf("null ctxt finish: %d", xmlSaveFinish(NULL));
    put_error();
    putchar('\n');

    ctxt = xmlSaveToBuffer(buf, NULL, 0);
    assert(ctxt != NULL);
    printf("null doc: %ld\n", xmlSaveDoc(ctxt, NULL));
    printf("null node: %ld\n", xmlSaveTree(ctxt, NULL));
    printf("element as doc: %ld", xmlSaveDoc(ctxt, (xmlDocPtr)xmlDocGetRootElement(doc)));
    put_error();
    putchar('\n');
    printf("close: %d", xmlSaveClose(ctxt));
    printf(" length=%d\n", xmlBufferLength(buf));

    xmlResetLastError();
    ctxt = xmlSaveToBuffer(buf, "bogus-encoding", 0);
    printf("unknown encoding: %s", ctxt ? "yes" : "no");
    put_error();
    putchar('\n');
    if (ctxt != NULL)
        xmlSaveClose(ctxt);
    xmlBufferFree(buf);
}

int main(void) {
    xmlDocPtr doc;

    strcpy(directory, "/tmp/xml3-save-XXXXXX");
    assert(mkdtemp(directory) != NULL);
    doc = xmlReadMemory(text, (int)strlen(text), NULL, NULL, 0);
    assert(doc != NULL);

    test_options(doc);
    test_indent(doc);
    test_flush(doc);
    test_targets(doc);
    test_arguments(doc);

    xmlFreeDoc(doc);
    assert(rmdir(directory) == 0);
    puts("save tests passed");
    return 0;
}
