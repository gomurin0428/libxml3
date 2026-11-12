/* The parser context API: xmlNewParserCtxt, the option functions, the
 * xmlCtxtRead* functions, the context's error state and its accessors
 * (xmlCtxtGetStatus, xmlCtxtIsStopped, xmlStopParser and the others).  The output of
 * this program is compared between libxml3 and the pinned reference
 * libxml2 (make test-context), so every line must describe behavior both
 * share.  Paths are printed relative to the test's temporary directory. */
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

static void put_error(const char *label, const xmlError *error,
                      xmlParserCtxtPtr ctxt) {
    printf(" %s=", label);
    if (error == NULL) {
        fputs("none", stdout);
        return;
    }
    printf("%d/%d level=%d line=%d int2=%d own=%s file=", error->domain,
           error->code, error->level, error->line, error->int2,
           error->ctxt == NULL ? "null"
           : error->ctxt == (void *)ctxt ? "ctxt" : "other");
    put_text(error->file);
    /* Parser messages are compared elsewhere; the I/O ones are shared. */
    if (error->domain == XML_FROM_IO) {
        fputs(" str1=", stdout);
        put_text(error->str1);
        fputs(" message=", stdout);
        put_text(error->message);
    }
}

/* Prints the state of ctxt after an operation, with the document it
 * returned (freed here) and the thread's last error. */
static void report(const char *label, xmlParserCtxtPtr ctxt, xmlDocPtr doc) {
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
    printf(" wellFormed=%d errNo=%d myDoc=%s options=%d",
           ctxt->wellFormed, ctxt->errNo,
           ctxt->myDoc ? "yes" : "no", xmlCtxtGetOptions(ctxt));
    put_error("ctxt", xmlCtxtGetLastError(ctxt), ctxt);
    put_error("last", xmlGetLastError(), ctxt);
    putchar('\n');
}

static void write_file(const char *name, const char *text) {
    char path[160];
    FILE *file;

    snprintf(path, sizeof(path), "%s/%s", directory, name);
    file = fopen(path, "wb");
    assert(file != NULL);
    assert(fwrite(text, 1, strlen(text), file) == strlen(text));
    fclose(file);
}

static xmlDocPtr read_memory(xmlParserCtxtPtr ctxt, const char *text,
                             const char *url, int options) {
    return xmlCtxtReadMemory(ctxt, text, (int)strlen(text), url, NULL,
                             options);
}

static void test_options(void) {
    xmlParserCtxtPtr ctxt = xmlNewParserCtxt();

    assert(ctxt != NULL);
    report("new", ctxt, NULL);
    printf("use unknown: %d\n",
           xmlCtxtUseOptions(ctxt, XML_PARSE_NOERROR | (1 << 10) |
                                       (1 << 15) | (1 << 18) | (1 << 27)));
    printf("after use: %d\n", xmlCtxtGetOptions(ctxt));
    printf("use none: %d\n", xmlCtxtUseOptions(ctxt, 0));
    printf("kept: %d\n", xmlCtxtGetOptions(ctxt));
    printf("use more: %d\n",
           xmlCtxtUseOptions(ctxt, XML_PARSE_NONET | XML_PARSE_HUGE |
                                       (1 << 12) | (1 << 0)));
    printf("merged: %d\n", xmlCtxtGetOptions(ctxt));
    printf("use dropped: %d\n", xmlCtxtUseOptions(ctxt, XML_PARSE_NOWARNING));
    printf("after drop: %d\n", xmlCtxtGetOptions(ctxt));
    printf("set: %d\n", xmlCtxtSetOptions(ctxt, XML_PARSE_NOWARNING));
    printf("after set: %d\n", xmlCtxtGetOptions(ctxt));
    printf("set unknown: %d\n", xmlCtxtSetOptions(ctxt, (1 << 10) | (1 << 29)));
    printf("after set unknown: %d\n", xmlCtxtGetOptions(ctxt));
    printf("set negative: %d\n", xmlCtxtSetOptions(ctxt, -1));
    printf("after negative: %d\n", xmlCtxtGetOptions(ctxt));
    printf("set none: %d\n", xmlCtxtSetOptions(ctxt, 0));
    printf("after none: %d\n", xmlCtxtGetOptions(ctxt));
    xmlFreeParserCtxt(ctxt);
}

static void test_null(void) {
    printf("null get: %d\n", xmlCtxtGetOptions(NULL));
    printf("null use: %d\n", xmlCtxtUseOptions(NULL, 0));
    printf("null set: %d\n", xmlCtxtSetOptions(NULL, 0));
    printf("null last error: %s\n", xmlCtxtGetLastError(NULL) ? "yes" : "no");
    xmlResetLastError();
    printf("null read memory: %s\n",
           xmlCtxtReadMemory(NULL, "<a/>", 4, NULL, NULL, 0) ? "yes" : "no");
    printf("null read doc: %s\n",
           xmlCtxtReadDoc(NULL, BAD_CAST "<a/>", NULL, NULL, 0) ? "yes" : "no");
    printf("null read file: %s\n",
           xmlCtxtReadFile(NULL, "x.xml", NULL, 0) ? "yes" : "no");
    xmlCtxtReset(NULL);
    xmlCtxtResetLastError(NULL);
    xmlFreeParserCtxt(NULL);
    printf("null last: %s\n", xmlGetLastError() ? "yes" : "no");
}

static void test_reads(void) {
    xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
    char path[200];

    assert(ctxt != NULL);
    xmlResetLastError();
    report("ok", ctxt, read_memory(ctxt, "<a><b x='1'/></a>", "mem.xml", 0));
    report("malformed", ctxt,
           read_memory(ctxt, "<a>\n<b></a>", "bad.xml", XML_PARSE_NOERROR));
    report("ok after malformed", ctxt, read_memory(ctxt, "<c/>", NULL, 0));
    report("malformed again", ctxt,
           read_memory(ctxt, "<a>", NULL, XML_PARSE_NOERROR));
    report("negative size", ctxt,
           xmlCtxtReadMemory(ctxt, "<a/>", -1, NULL, NULL, 0));
    report("empty", ctxt, xmlCtxtReadMemory(ctxt, "", 0, NULL, NULL, 0));
    xmlCtxtResetLastError(ctxt);
    report("reset last error", ctxt, NULL);
    xmlCtxtReset(ctxt);
    report("reset", ctxt, NULL);

    /* Rejected documents and warnings of the parser itself differ by
     * design (docs/compatibility.md); the warning case is the missing
     * file below. */
    xmlResetLastError();
    report("doc", ctxt,
           xmlCtxtReadDoc(ctxt, BAD_CAST "<d>text</d>", "doc.xml", NULL, 0));
    report("doc malformed", ctxt,
           xmlCtxtReadDoc(ctxt, BAD_CAST "<d>", "doc.xml", NULL, 0));

    xmlResetLastError();
    snprintf(path, sizeof(path), "%s/ok.xml", directory);
    report("file", ctxt, xmlCtxtReadFile(ctxt, path, NULL, 0));
    snprintf(path, sizeof(path), "%s/bad.xml", directory);
    report("file malformed", ctxt, xmlCtxtReadFile(ctxt, path, NULL, 0));
    snprintf(path, sizeof(path), "%s/missing.xml", directory);
    report("file missing", ctxt, xmlCtxtReadFile(ctxt, path, NULL, 0));
    report("file ok again", ctxt,
           read_memory(ctxt, "<e/>", NULL, 0));
    xmlFreeParserCtxt(ctxt);

    /* The thread's last error may outlive the context that raised it. */
    ctxt = xmlNewParserCtxt();
    assert(ctxt != NULL);
    xmlResetLastError();
    report("before free", ctxt, read_memory(ctxt, "<z>", NULL, 0));
    xmlFreeParserCtxt(ctxt);
    printf("after free: last=%d\n",
           xmlGetLastError() ? xmlGetLastError()->code : 0);
}

static void put_state(const char *label, xmlParserCtxtPtr ctxt) {
    const xmlError *error = xmlCtxtGetLastError(ctxt);

    printf("%s: stopped=%d status=%d wellFormed=%d errNo=%d last=%d\n",
           label, xmlCtxtIsStopped(ctxt), xmlCtxtGetStatus(ctxt),
           ctxt->wellFormed, ctxt->errNo, error ? error->code : 0);
}

static int handler_calls;
static int stop_at;

static void state_handler(void *data, const xmlError *error) {
    xmlParserCtxtPtr ctxt = data;

    handler_calls++;
    printf("  handler %d: %d/%d level=%d stopped=%d status=%d\n",
           handler_calls, error->domain, error->code, (int)error->level,
           xmlCtxtIsStopped(ctxt), xmlCtxtGetStatus(ctxt));
    if (handler_calls == stop_at)
        xmlStopParser(ctxt);
}

/* Reads text with the context; with show_doc 0 only the context's state
 * is compared (libxml3 keeps no document after a namespace error). */
static void state_read(xmlParserCtxtPtr ctxt, const char *label,
                       const char *text, int stop, int show_doc) {
    xmlDocPtr doc;

    handler_calls = 0;
    stop_at = stop;
    doc = read_memory(ctxt, text, NULL, 0);
    if (show_doc)
        printf("%s: doc=%s calls=%d\n", label, doc ? "yes" : "no",
               handler_calls);
    put_state(label, ctxt);
    xmlFreeDoc(doc);
}

/* A callback input whose second read fails with XML_IO_UNKNOWN, which is
 * a warning: the bytes read are parsed. */
static int warning_read(void *context, char *buffer, int length) {
    int *reads = context;

    (void)length;
    if ((*reads)++ > 0)
        return -1;
    memcpy(buffer, "<r/>", 4);
    return 4;
}

static void test_accessors(void) {
    xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
    int value = 0, reads = 0, fd;
    char path[200];
    xmlDocPtr doc;

    assert(ctxt != NULL);
    printf("new: private=%d user=%d html=%d subset=%d node=%d doc=%d\n",
           xmlCtxtGetPrivate(ctxt) == NULL, xmlCtxtGetUserData(ctxt) == ctxt,
           xmlCtxtIsHtml(ctxt), xmlCtxtIsInSubset(ctxt),
           xmlCtxtGetNode(ctxt) == NULL, xmlCtxtGetDocument(ctxt) == NULL);
    put_state("new", ctxt);
    xmlCtxtSetPrivate(ctxt, &value);
    printf("private set: %d\n", xmlCtxtGetPrivate(ctxt) == &value);
    xmlCtxtSetPrivate(NULL, &value);
    xmlStopParser(NULL);
    printf("null: private=%d user=%d html=%d subset=%d stopped=%d status=%d "
           "node=%d doc=%d\n",
           xmlCtxtGetPrivate(NULL) == NULL, xmlCtxtGetUserData(NULL) == NULL,
           xmlCtxtIsHtml(NULL), xmlCtxtIsInSubset(NULL),
           xmlCtxtIsStopped(NULL), xmlCtxtGetStatus(NULL),
           xmlCtxtGetNode(NULL) == NULL, xmlCtxtGetDocument(NULL) == NULL);

    state_read(ctxt, "well-formed", "<r/>", 0, 1);
    state_read(ctxt, "malformed", "<r>", 0, 1);
    state_read(ctxt, "namespace error", "<a:b/>", 0, 0);
    state_read(ctxt, "empty namespace", "<r xmlns:a=''/>", 0, 0);
    xmlCtxtSetErrorHandler(ctxt, state_handler, ctxt);
    state_read(ctxt, "handled malformed", "<r><a></r>", 0, 1);
    state_read(ctxt, "handled namespace error", "<a:b/>", 0, 0);
    state_read(ctxt, "stop on fatal", "<r><a></r>", 1, 1);
    /* Stopping on a warning clears wellFormed (errNo was XML_ERR_OK), so
     * the read keeps no document. */
    handler_calls = 0;
    stop_at = 1;
    doc = xmlCtxtReadIO(ctxt, warning_read, NULL, &reads, NULL, NULL, 0);
    printf("stop on warning: doc=%s calls=%d\n", doc ? "yes" : "no",
           handler_calls);
    put_state("stop on warning", ctxt);
    xmlFreeDoc(doc);
    reads = 0;
    handler_calls = 0;
    stop_at = 0;
    doc = xmlCtxtReadIO(ctxt, warning_read, NULL, &reads, NULL, NULL, 0);
    printf("warning: doc=%s\n", doc ? "yes" : "no");
    put_state("warning", ctxt);
    xmlFreeDoc(doc);
    xmlCtxtSetErrorHandler(ctxt, NULL, NULL);

    /* A catastrophic error: a descriptor that cannot be read. */
    snprintf(path, sizeof(path), "%s/ok.xml", directory);
    fd = open(path, O_WRONLY);
    assert(fd >= 0);
    doc = xmlCtxtReadFd(ctxt, fd, NULL, NULL, 0);
    close(fd);
    assert(doc == NULL);
    put_state("catastrophic", ctxt);
    /* XML_PARSE_DTDVALID asks for validation, which then counts as
     * failed too. */
    xmlCtxtUseOptions(ctxt, 1 << 4);
    put_state("catastrophic validating", ctxt);
    xmlCtxtReset(ctxt);
    put_state("reset", ctxt);

    xmlStopParser(ctxt);
    put_state("stopped", ctxt);
    xmlStopParser(ctxt);
    put_state("stopped again", ctxt);
    state_read(ctxt, "read after stop", "<r/>", 0, 1);
    state_read(ctxt, "malformed", "<r>", 0, 1);
    xmlStopParser(ctxt);
    put_state("stopped after error", ctxt);

    xmlCtxtReset(ctxt);
    ctxt->myDoc = xmlNewDoc(BAD_CAST "1.0");
    printf("node is myDoc: %d\n",
           xmlCtxtGetNode(ctxt) == (xmlNodePtr)ctxt->myDoc);
    doc = xmlCtxtGetDocument(ctxt);
    printf("document: %s myDoc=%s\n", doc ? "yes" : "no",
           ctxt->myDoc ? "kept" : "cleared");
    xmlFreeDoc(doc);
    ctxt->myDoc = xmlNewDoc(BAD_CAST "1.0");
    ctxt->wellFormed = 0;
    ctxt->errNo = XML_ERR_DOCUMENT_END;
    doc = xmlCtxtGetDocument(ctxt);
    printf("document not well-formed: %s myDoc=%s\n", doc ? "yes" : "no",
           ctxt->myDoc ? "kept" : "cleared");
    xmlFreeParserCtxt(ctxt);
}

int main(void) {
    char path[200];

    strcpy(directory, "/tmp/xml3-context-XXXXXX");
    assert(mkdtemp(directory) != NULL);
    write_file("ok.xml", "<?xml version='1.0'?>\n<r a='1'>\n  <c>t</c>\n</r>\n");
    write_file("bad.xml", "<r>\n<a>\n</r>");

    test_options();
    test_null();
    test_reads();
    test_accessors();

    snprintf(path, sizeof(path), "%s/ok.xml", directory);
    unlink(path);
    snprintf(path, sizeof(path), "%s/bad.xml", directory);
    unlink(path);
    assert(rmdir(directory) == 0);
    puts("context tests passed");
    return 0;
}
