/* xmlReadFile, xmlParseFile, xmlReadFd, xmlReadIO, xmlCtxtReadFd and
 * xmlCtxtReadIO.  The output of this program is compared
 * between libxml3 and the pinned reference libxml2 (make test-input), so
 * every line must describe behavior both share.  Paths are printed
 * relative to the test's temporary directory. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

#include <assert.h>
#include <fcntl.h>
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

/* A callback input: the bytes of text, at most chunk per read, and the
 * failure code answered once fail_at bytes have been read (fail_at < 0:
 * none). */
typedef struct {
    const char *text;
    size_t at;
    int chunk;
    long fail_at;
    int failure;
    int reads;
    int closes;
} source;

static int source_read(void *context, char *buffer, int length) {
    source *input = context;
    size_t left = strlen(input->text) - input->at;
    int count = input->chunk < length ? input->chunk : length;

    input->reads++;
    if (input->fail_at >= 0 && input->at >= (size_t)input->fail_at)
        return input->failure;
    if ((size_t)count > left)
        count = (int)left;
    memcpy(buffer, input->text + input->at, (size_t)count);
    input->at += (size_t)count;
    return count;
}

static int source_close(void *context) {
    ((source *)context)->closes++;
    return 0;
}

static void io_case(const char *label, const char *text, int chunk,
                    long fail_at, int failure, const char *url) {
    source input = {text, 0, chunk, fail_at, failure, 0, 0};

    xmlResetLastError();
    report(label, xmlReadIO(source_read, source_close, &input, url, NULL, 0));
    printf("  reads=%d closes=%d\n", input.reads, input.closes);
}

static int open_file(const char *name, int flags) {
    char path[200];

    snprintf(path, sizeof(path), "%s/%s", directory, name);
    return open(path, flags);
}

static void fd_case(const char *label, const char *name, int flags,
                    const char *url) {
    int fd = open_file(name, flags);

    assert(fd >= 0);
    xmlResetLastError();
    report(label, xmlReadFd(fd, url, NULL, 0));
    /* The caller's descriptor stays open, after what was read. */
    printf("  open=%d offset=%ld\n", fcntl(fd, F_GETFD) != -1,
           (long)lseek(fd, 0, SEEK_CUR));
    close(fd);
}

static void put_context(xmlParserCtxtPtr ctxt) {
    const xmlError *error = xmlCtxtGetLastError(ctxt);

    printf("  ctxt wellFormed=%d errNo=%d lastError=%d/%d\n",
           ctxt->wellFormed, ctxt->errNo, error ? error->code : 0,
           error ? (int)error->level : 0);
}

static void test_descriptors(void) {
    int fd, pipes[2];
    xmlParserCtxtPtr ctxt;
    xmlDocPtr doc;
    source input;

    fd_case("fd", "ok.xml", O_RDONLY, "doc.xml");
    fd_case("fd without url", "ok.xml", O_RDONLY, NULL);
    fd_case("fd malformed", "bad.xml", O_RDONLY, "bad.xml");
    fd_case("fd empty", "empty.xml", O_RDONLY, NULL);
    fd_case("fd utf-16", "utf16.xml", O_RDONLY, NULL);
    fd_case("fd write only", "ok.xml", O_WRONLY, "w.xml");
    fd = open(directory, O_RDONLY);
    assert(fd >= 0);
    xmlResetLastError();
    report("fd directory", xmlReadFd(fd, "dir", NULL, 0));
    close(fd);

    fd = open_file("prefix.xml", O_RDONLY);
    assert(fd >= 0 && lseek(fd, 4, SEEK_SET) == 4);
    xmlResetLastError();
    report("fd from offset", xmlReadFd(fd, NULL, NULL, 0));
    close(fd);

    assert(pipe(pipes) == 0);
    assert(write(pipes[1], "<p>piped</p>", 12) == 12);
    close(pipes[1]);
    xmlResetLastError();
    report("pipe", xmlReadFd(pipes[0], NULL, NULL, 0));
    close(pipes[0]);

    /* A negative descriptor makes no input and reports nothing; the
     * previous error stays. */
    read_case("before negative fd", "missing.xml", 0);
    report("negative fd", xmlReadFd(-1, NULL, NULL, 0));
    /* A descriptor that cannot be duplicated: libxml2 reports a memory
     * failure (the record's domain is not compared). */
    fd = open_file("ok.xml", O_RDONLY);
    close(fd);
    xmlResetLastError();
    doc = xmlReadFd(fd, NULL, NULL, 0);
    printf("closed fd: doc=%s code=%d\n", doc ? "yes" : "no",
           xmlGetLastError() ? xmlGetLastError()->code : 0);

    io_case("io", "<r a='1'>text<c/></r>", 3, -1, 0, "io.xml");
    io_case("io one read", "<r/>", 4000, -1, 0, NULL);
    io_case("io unknown failure after data", "<r>text</r>", 4000, 4, -1,
            "io.xml");
    io_case("io not found at start", "<r/>", 4000, 0, -1524, NULL);
    io_case("io unknown failure at start", "<r/>", 4000, 0, -1, "u.xml");
    io_case("io fatal at start", "<r/>", 4000, 0, -1503, "f.xml");
    io_case("io fatal after data", "<r>text</r>", 5, 5, -1516, NULL);
    io_case("io malformed", "<r><a></r>", 4000, -1, 0, "m.xml");
    io_case("io empty", "", 4000, -1, 0, NULL);
    {
        char large[10001];

        large[0] = '<';
        large[1] = 'r';
        large[2] = '>';
        memset(large + 3, 'x', 9993);
        memcpy(large + 9996, "</r>", 5);
        io_case("io large", large, 4000, -1, 0, NULL);
    }
    input = (source){"<r/>", 0, 4000, -1, 0, 0, 0};
    xmlResetLastError();
    report("io without close", xmlReadIO(source_read, NULL, &input, NULL,
                                         NULL, 0));
    xmlResetLastError();
    report("io without read", xmlReadIO(NULL, source_close, &input, NULL,
                                        NULL, 0));
    printf("  closes=%d\n", input.closes);

    ctxt = xmlNewParserCtxt();
    assert(ctxt != NULL);
    fd = open_file("ok.xml", O_RDONLY);
    report("ctxt fd", xmlCtxtReadFd(ctxt, fd, "c.xml", NULL, 0));
    put_context(ctxt);
    close(fd);
    fd = open_file("bad.xml", O_RDONLY);
    report("ctxt fd malformed", xmlCtxtReadFd(ctxt, fd, NULL, NULL, 0));
    put_context(ctxt);
    close(fd);
    /* The context is reset before the descriptor is looked at. */
    report("ctxt negative fd", xmlCtxtReadFd(ctxt, -1, NULL, NULL, 0));
    put_context(ctxt);
    input = (source){"<q>t</q>", 0, 2, -1, 0, 0, 0};
    report("ctxt io", xmlCtxtReadIO(ctxt, source_read, source_close, &input,
                                    "q.xml", NULL, 0));
    put_context(ctxt);
    printf("  reads=%d closes=%d\n", input.reads, input.closes);
    input = (source){"<q/>", 0, 4000, 0, -1530, 0, 0};
    report("ctxt io fatal", xmlCtxtReadIO(ctxt, source_read, source_close,
                                          &input, "q.xml", NULL, 0));
    put_context(ctxt);
    printf("  reads=%d closes=%d\n", input.reads, input.closes);
    input = (source){"<q/>", 0, 4000, 0, -1, 0, 0};
    report("ctxt io warning", xmlCtxtReadIO(ctxt, source_read, source_close,
                                            &input, NULL, NULL, 0));
    put_context(ctxt);
    report("ctxt io without read", xmlCtxtReadIO(ctxt, NULL, source_close,
                                                 &input, NULL, NULL, 0));
    put_context(ctxt);
    xmlFreeParserCtxt(ctxt);
    printf("null ctxt: %d %d\n", xmlCtxtReadFd(NULL, 0, NULL, NULL, 0) == NULL,
           xmlCtxtReadIO(NULL, source_read, NULL, &input, NULL, NULL, 0)
               == NULL);
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
    write_file("prefix.xml", "skip<f>from offset</f>");

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

    test_descriptors();

    for (const char *name =
             "ok.xml bad.xml empty.xml space name.xml utf16.xml prefix.xml";
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
