/* Output buffers of xmlIO.h: xmlAllocOutputBuffer, the
 * xmlOutputBufferCreate* functions, xmlOutputBufferWrite, WriteString,
 * Flush, Close, GetContent and GetSize, and the serializers that write
 * into them (xmlNodeDumpOutput, xmlSaveFileTo, xmlSaveFormatFileTo).  The
 * output of this program is compared between libxml3 and the pinned
 * reference libxml2 (make test-output-buffer), so every line must describe
 * behavior both share. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlIO.h>

#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char directory[64];

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

/* A callback target: it takes at most limit bytes per call (0: all of
 * them), answers failure once fail_at calls were made (0: never), and
 * prints each call. */
typedef struct {
    int calls;
    int limit;
    int fail_at;
    int failure;
    int closes;
    int close_result;
    size_t total;
} sink;

static int sink_write(void *context, const char *buffer, int len) {
    sink *target = context;
    int taken;

    (void)buffer;
    taken = target->limit > 0 && len > target->limit ? target->limit : len;

    target->calls++;
    if (target->fail_at > 0 && target->calls >= target->fail_at) {
        printf("  write %d bytes -> %d\n", len, target->failure);
        return target->failure;
    }
    printf("  write %d bytes -> %d\n", len, taken);
    target->total += (size_t)taken;
    return taken;
}

static int sink_close(void *context) {
    sink *target = context;

    target->closes++;
    printf("  close -> %d\n", target->close_result);
    return target->close_result;
}

static void put_state(const char *label, xmlOutputBufferPtr out) {
    printf("%s: written=%d error=%d size=%zu", label, out->written,
           out->error, xmlOutputBufferGetSize(out));
    if (xmlOutputBufferGetContent(out) == NULL)
        fputs(" content=null", stdout);
    putchar('\n');
}

static void fill(char *data, size_t length) {
    for (size_t i = 0; i < length; ++i)
        data[i] = (char)('a' + i % 26);
}

static void test_memory(void) {
    xmlOutputBufferPtr out = xmlAllocOutputBuffer(NULL);
    const xmlChar *content;

    assert(out != NULL);
    printf("memory new: written=%d error=%d size=%zu content=%s\n",
           out->written, out->error, xmlOutputBufferGetSize(out),
           xmlOutputBufferGetContent(out) ? "set" : "null");
    printf("write: %d\n", xmlOutputBufferWrite(out, 5, "hello"));
    printf("write string: %d\n", xmlOutputBufferWriteString(out, " world"));
    printf("write empty string: %d\n", xmlOutputBufferWriteString(out, ""));
    printf("write null string: %d\n", xmlOutputBufferWriteString(out, NULL));
    printf("write negative: %d\n", xmlOutputBufferWrite(out, -3, "abc"));
    printf("write zero: %d\n", xmlOutputBufferWrite(out, 0, "abc"));
    content = xmlOutputBufferGetContent(out);
    fputs("content: ", stdout);
    put_text((const char *)content, xmlOutputBufferGetSize(out));
    putchar('\n');
    printf("flush: %d\n", xmlOutputBufferFlush(out));
    put_state("memory", out);
    {
        char large[9000];

        fill(large, sizeof(large));
        printf("write large: %d\n",
               xmlOutputBufferWrite(out, (int)sizeof(large), large));
    }
    put_state("memory large", out);
    printf("close: %d\n", xmlOutputBufferClose(out));

    printf("null: write=%d string=%d flush=%d close=%d content=%s size=%zu\n",
           xmlOutputBufferWrite(NULL, 1, "x"),
           xmlOutputBufferWriteString(NULL, "x"), xmlOutputBufferFlush(NULL),
           xmlOutputBufferClose(NULL),
           xmlOutputBufferGetContent(NULL) ? "set" : "null",
           xmlOutputBufferGetSize(NULL));
}

static void io_case(const char *label, int limit, int fail_at, int failure,
                    int close_result, size_t first, size_t second) {
    sink target = {0, limit, fail_at, failure, 0, close_result, 0};
    xmlOutputBufferPtr out =
        xmlOutputBufferCreateIO(sink_write, sink_close, &target, NULL);
    char *data = malloc(first + second + 1);

    assert(out != NULL && data != NULL);
    fill(data, first + second);
    printf("%s\n", label);
    printf(" write %zu: %d\n", first,
           xmlOutputBufferWrite(out, (int)first, data));
    put_state(" after first", out);
    printf(" write %zu: %d\n", second,
           xmlOutputBufferWrite(out, (int)second, data + first));
    put_state(" after second", out);
    printf(" flush: %d\n", xmlOutputBufferFlush(out));
    put_state(" after flush", out);
    printf(" close: %d\n", xmlOutputBufferClose(out));
    printf(" calls=%d closes=%d total=%zu\n", target.calls, target.closes,
           target.total);
    free(data);
}

static void test_io(void) {
    io_case("io small", 0, 0, 0, 0, 10, 20);
    io_case("io threshold", 0, 0, 0, 0, 3999, 1);
    io_case("io large", 0, 0, 0, 0, 5000, 9000);
    io_case("io partial", 1500, 0, 0, 0, 5000, 100);
    io_case("io failure -1", 0, 1, -1, 0, 4500, 10);
    io_case("io failure code", 0, 1, -1530, 0, 4500, 10);
    io_case("io takes nothing", 1, 1, 0, 0, 4500, 10);
    io_case("io flush failure", 0, 1, -1, 0, 10, 10);
    io_case("io close failure", 0, 0, 0, 1503, 10, 10);
    io_case("io close negative", 0, 0, 0, -7, 10, 10);
    io_case("io failure then close failure", 0, 1, -1, 1503, 4500, 10);
    printf("io without write: %s\n",
           xmlOutputBufferCreateIO(NULL, sink_close, NULL, NULL) ? "made"
                                                                 : "null");
    {
        sink target = {0, 0, 0, 0, 0, 0, 0};
        xmlOutputBufferPtr out =
            xmlOutputBufferCreateIO(sink_write, NULL, &target, NULL);

        int written = xmlOutputBufferWriteString(out, "abc");

        printf("io without close: write=%d", written);
        printf(" close=%d calls=%d\n", xmlOutputBufferClose(out),
               target.calls);
    }
}

static void test_targets(void) {
    xmlBufferPtr buffer = xmlBufferCreate();
    xmlOutputBufferPtr out;
    char path[200], text[64];
    int fd, pipes[2];
    ssize_t count;
    FILE *file;

    out = xmlOutputBufferCreateBuffer(buffer, NULL);
    printf("buffer: write=%d", xmlOutputBufferWriteString(out, "into "));
    printf(" pending=%zu", xmlOutputBufferGetSize(out));
    printf(" flush=%d", xmlOutputBufferFlush(out));
    printf(" write=%d", xmlOutputBufferWriteString(out, "buffer"));
    printf(" close=%d content=", xmlOutputBufferClose(out));
    put_text((const char *)xmlBufferContent(buffer),
             (size_t)xmlBufferLength(buffer));
    putchar('\n');
    xmlBufferFree(buffer);
    printf("buffer null: %s\n",
           xmlOutputBufferCreateBuffer(NULL, NULL) ? "made" : "null");

    assert(pipe(pipes) == 0);
    out = xmlOutputBufferCreateFd(pipes[1], NULL);
    printf("fd: write=%d", xmlOutputBufferWriteString(out, "through a pipe"));
    printf(" close=%d", xmlOutputBufferClose(out));
    /* The descriptor stays open. */
    printf(" open=%d", fcntl(pipes[1], F_GETFD) != -1);
    close(pipes[1]);
    count = read(pipes[0], text, sizeof(text));
    close(pipes[0]);
    printf(" read=");
    put_text(text, count > 0 ? (size_t)count : 0);
    putchar('\n');
    printf("fd negative: %s\n",
           xmlOutputBufferCreateFd(-1, NULL) ? "made" : "null");

    snprintf(path, sizeof(path), "%s/out.xml", directory);
    out = xmlOutputBufferCreateFilename(path, NULL, 0);
    printf("filename: write=%d", xmlOutputBufferWriteString(out, "a file"));
    printf(" close=%d", xmlOutputBufferClose(out));
    fd = open(path, O_RDONLY);
    count = read(fd, text, sizeof(text));
    close(fd);
    printf(" read=");
    put_text(text, count > 0 ? (size_t)count : 0);
    putchar('\n');
    snprintf(path, sizeof(path), "%s/missing/out.xml", directory);
    printf("filename missing directory: %s\n",
           xmlOutputBufferCreateFilename(path, NULL, 0) ? "made" : "null");
    printf("filename null: %s\n",
           xmlOutputBufferCreateFilename(NULL, NULL, 0) ? "made" : "null");

    snprintf(path, sizeof(path), "%s/stream.xml", directory);
    file = fopen(path, "w+");
    assert(file != NULL);
    out = xmlOutputBufferCreateFile(file, NULL);
    printf("file: write=%d", xmlOutputBufferWriteString(out, "a stream"));
    printf(" close=%d", xmlOutputBufferClose(out));
    rewind(file);
    count = (ssize_t)fread(text, 1, sizeof(text), file);
    fclose(file);
    printf(" read=");
    put_text(text, count > 0 ? (size_t)count : 0);
    putchar('\n');
    printf("file null: %s\n",
           xmlOutputBufferCreateFile(NULL, NULL) ? "made" : "null");
    unlink(path);
    snprintf(path, sizeof(path), "%s/out.xml", directory);
    unlink(path);
}

static void dump_case(const char *label, xmlNodePtr node, int level,
                      int format, const char *encoding) {
    xmlOutputBufferPtr out = xmlAllocOutputBuffer(NULL);

    xmlNodeDumpOutput(out, node ? node->doc : NULL, node, level, format,
                      encoding);
    printf("%s: ", label);
    put_text((const char *)xmlOutputBufferGetContent(out),
             xmlOutputBufferGetSize(out));
    putchar('\n');
    xmlOutputBufferClose(out);
}

static void save_case(const char *label, xmlDocPtr doc, const char *encoding,
                      int format) {
    xmlBufferPtr buffer = xmlBufferCreate();
    xmlOutputBufferPtr out = xmlOutputBufferCreateBuffer(buffer, NULL);
    int result = format < 0 ? xmlSaveFileTo(out, doc, encoding)
                            : xmlSaveFormatFileTo(out, doc, encoding, format);

    const xmlError *error = xmlGetLastError();

    printf("%s: %d ", label, result);
    if (error != NULL && error->code != 0)
        printf("error=%d/%d/%d ", error->domain, error->code,
               (int)error->level);
    xmlResetLastError();
    put_text((const char *)xmlBufferContent(buffer),
             (size_t)xmlBufferLength(buffer));
    putchar('\n');
    xmlBufferFree(buffer);
}

static void test_serializers(void) {
    static const char text[] =
        "<?xml version='1.0'?><r a='1'><c>t\xc3\xa9</c><e/><d><f>x</f></d></r>";
    xmlDocPtr doc = xmlReadMemory(text, (int)strlen(text), NULL, NULL, 0);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    sink target = {0, 0, 0, 0, 0, 0, 0};
    xmlOutputBufferPtr out;

    assert(doc != NULL && root != NULL);
    dump_case("dump root", root, 0, 0, NULL);
    dump_case("dump formatted", root, 0, 1, NULL);
    dump_case("dump level 2", root, 2, 1, NULL);
    dump_case("dump negative level", root, -5, 1, NULL);
    dump_case("dump level 500", root->children, 500, 1, NULL);
    dump_case("dump encoding", root, 0, 0, "ISO-8859-1");
    dump_case("dump child", root->children, 0, 0, NULL);
    dump_case("dump null node", NULL, 0, 0, NULL);
    xmlNodeDumpOutput(NULL, doc, root, 0, 0, NULL);

    save_case("save", doc, NULL, -1);
    save_case("save formatted", doc, NULL, 1);
    save_case("save utf-8", doc, "UTF-8", 0);
    /* An encoding the serializer cannot produce. */
    save_case("save unknown encoding", doc, "x-unknown", 0);
    save_case("save null doc", NULL, NULL, 0);
    printf("save null buffer: %d\n", xmlSaveFileTo(NULL, doc, NULL));
    /* An element is not a document: the buffer is closed all the same. */
    out = xmlOutputBufferCreateIO(sink_write, sink_close, &target, NULL);
    printf("save element: %d", xmlSaveFormatFileTo(out, (xmlDocPtr)root, NULL, 0));
    printf(" closes=%d\n", target.closes);
    target = (sink){0, 0, 0, 0, 0, 0, 0};
    out = xmlOutputBufferCreateIO(sink_write, sink_close, &target, NULL);
    printf("save to io: %d", xmlSaveFileTo(out, doc, NULL));
    printf(" calls=%d closes=%d total=%zu\n", target.calls, target.closes,
           target.total);
    xmlFreeDoc(doc);
}

int main(void) {
    strcpy(directory, "/tmp/xml3-output-XXXXXX");
    assert(mkdtemp(directory) != NULL);
    test_memory();
    test_io();
    test_targets();
    test_serializers();
    assert(rmdir(directory) == 0);
    puts("output buffer tests passed");
    return 0;
}
