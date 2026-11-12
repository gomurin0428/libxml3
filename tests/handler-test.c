/* Structured error handlers: xmlSetStructuredErrorFunc and
 * xmlCtxtSetErrorHandler.  The output of this program is compared between
 * libxml3 and the pinned reference libxml2 (make test-handler), so every
 * line must describe behavior both share. */
#define _POSIX_C_SOURCE 200809L
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static xmlParserCtxtPtr current;
static int reenter;

static void put_error(const char *who, const xmlError *error) {
    printf("  %s: %d/%d level=%d line=%d int2=%d own=%s file=%s\n", who,
           error->domain, error->code, error->level, error->line, error->int2,
           /* A plain read has no context of the caller's: libxml2 names
            * its internal one, libxml3 none. */
           current != NULL && error->ctxt == (void *)current ? "ctxt" : "-",
           error->file ? error->file : "null");
}

static void global_handler(void *data, const xmlError *error) {
    put_error((const char *)data, error);
    if (reenter) {
        /* The handler may call back into the library. */
        xmlNodePtr node = xmlNewNode(NULL, BAD_CAST "inside");
        xmlDocPtr doc = xmlReadMemory("<ok/>", 5, NULL, NULL, 0);

        assert(node != NULL && doc != NULL);
        printf("  reentered: root=%s\n",
               (const char *)xmlDocGetRootElement(doc)->name);
        xmlFreeNode(node);
        xmlFreeDoc(doc);
    }
}

static void context_handler(void *data, const xmlError *error) {
    put_error((const char *)data, error);
    if (current != NULL)
        printf("  in handler: wellFormed=%d errNo=%d\n", current->wellFormed,
               current->errNo);
}

/* A context handler that parses malformed XML itself: with a plain read,
 * or through a second context. */
static xmlParserCtxtPtr inner;
static int nested_depth;

static void nested_handler(void *data, const xmlError *error) {
    xmlDocPtr doc;
    int code = error->code, line = error->line;

    put_error((const char *)data, error);
    if (nested_depth > 0)
        return;
    nested_depth++;
    printf("  in handler: wellFormed=%d errNo=%d\n", current->wellFormed,
           current->errNo);
    if (inner == NULL) {
        doc = xmlReadMemory("<plain>", 7, "plain.xml", NULL, 0);
        printf("  plain read in handler: doc=%s\n", doc ? "yes" : "no");
    } else {
        doc = xmlCtxtReadMemory(inner, "<inner>", 7, "inner.xml", NULL, 0);
        printf("  context read in handler: doc=%s inner wellFormed=%d"
               " errNo=%d\n", doc ? "yes" : "no", inner->wellFormed,
               inner->errNo);
    }
    xmlFreeDoc(doc);
    /* The record handed to the handler is not replaced by its own reads. */
    printf("  record kept: %s\n",
           error->code == code && error->line == line ? "yes" : "no");
    nested_depth--;
}

static void put_context(const char *label, xmlParserCtxtPtr ctxt) {
    const xmlError *error = xmlCtxtGetLastError(ctxt);

    printf("  %s: wellFormed=%d errNo=%d last=", label, ctxt->wellFormed,
           ctxt->errNo);
    if (error == NULL)
        puts("none");
    else
        printf("%d/%d level=%d file=%s own=%s\n", error->domain, error->code,
               error->level, error->file ? error->file : "null",
               error->ctxt == (void *)ctxt ? "ctxt" : "-");
}

static void test_nested(void) {
    xmlParserCtxtPtr outer = xmlNewParserCtxt();
    xmlDocPtr doc;

    assert(outer != NULL);
    xmlSetStructuredErrorFunc((void *)"global", global_handler);
    xmlCtxtSetErrorHandler(outer, nested_handler, (void *)"outer");

    puts("plain read in context handler:");
    current = outer;
    inner = NULL;
    doc = xmlCtxtReadMemory(outer, "<a>", 3, "outer.xml", NULL, 0);
    xmlFreeDoc(doc);
    put_context("outer", outer);

    puts("context read in context handler:");
    inner = xmlNewParserCtxt();
    assert(inner != NULL);
    doc = xmlCtxtReadFile(outer, "/nonexistent-xml3/missing.xml", NULL, 0);
    xmlFreeDoc(doc);
    put_context("outer", outer);
    put_context("inner", inner);
    xmlFreeParserCtxt(inner);
    inner = NULL;
    xmlFreeParserCtxt(outer);
    current = NULL;
    xmlSetStructuredErrorFunc(NULL, NULL);
}

static void read_memory(const char *label, const char *text, int options) {
    xmlDocPtr doc;

    printf("%s:\n", label);
    doc = xmlReadMemory(text, (int)strlen(text), "mem.xml", NULL, options);
    printf("  doc=%s\n", doc ? "yes" : "no");
    xmlFreeDoc(doc);
}

static void context_read(const char *label, xmlParserCtxtPtr ctxt,
                         const char *text, int options) {
    xmlDocPtr doc;

    printf("%s:\n", label);
    current = ctxt;
    doc = xmlCtxtReadMemory(ctxt, text, (int)strlen(text), NULL, NULL,
                            options);
    printf("  doc=%s wellFormed=%d errNo=%d\n", doc ? "yes" : "no",
           ctxt->wellFormed, ctxt->errNo);
    xmlFreeDoc(doc);
}

static void context_file(const char *label, xmlParserCtxtPtr ctxt,
                         int options) {
    xmlDocPtr doc;

    printf("%s:\n", label);
    current = ctxt;
    doc = xmlCtxtReadFile(ctxt, "/nonexistent-xml3/missing.xml", NULL,
                          options);
    printf("  doc=%s wellFormed=%d errNo=%d\n", doc ? "yes" : "no",
           ctxt->wellFormed, ctxt->errNo);
    xmlFreeDoc(doc);
}

int main(void) {
    xmlParserCtxtPtr ctxt;

    read_memory("no handler", "<a>", 0);

    xmlSetStructuredErrorFunc((void *)"global", global_handler);
    read_memory("global", "<a>", 0);
    read_memory("global with NOERROR", "<a>\n<b></a>", XML_PARSE_NOERROR);
    read_memory("global well-formed", "<a/>", 0);
    reenter = 1;
    read_memory("global reentrant", "<a></b>", 0);
    reenter = 0;

    ctxt = xmlNewParserCtxt();
    assert(ctxt != NULL);
    context_read("context without handler", ctxt, "<a>", 0);
    xmlCtxtSetErrorHandler(ctxt, context_handler, (void *)"context");
    context_read("context handler", ctxt, "<a>", 0);
    context_file("context warning", ctxt, 0);
    context_read("context well-formed", ctxt, "<a/>", 0);
    context_file("context warning with NOWARNING", ctxt, XML_PARSE_NOWARNING);
    /* xmlCtxtUseOptions keeps NOWARNING and NOERROR once set. */
    context_read("context error with NOWARNING kept", ctxt, "<a>", 0);
    context_read("context handler with NOERROR", ctxt, "<a>",
                 XML_PARSE_NOERROR);
    context_file("context warning with NOERROR kept", ctxt, 0);
    xmlFreeParserCtxt(ctxt);

    ctxt = xmlNewParserCtxt();
    assert(ctxt != NULL);
    xmlCtxtSetErrorHandler(ctxt, context_handler, (void *)"context");
    xmlCtxtSetErrorHandler(ctxt, NULL, NULL);
    context_read("context handler removed", ctxt, "<a>", 0);
    xmlCtxtSetErrorHandler(NULL, context_handler, NULL);
    xmlSetStructuredErrorFunc(NULL, NULL);
    xmlCtxtSetErrorHandler(ctxt, context_handler, (void *)"context");
    context_read("context handler alone", ctxt, "<a>", 0);
    context_read("context handler alone with NOERROR", ctxt, "<a>",
                 XML_PARSE_NOERROR);
    xmlFreeParserCtxt(ctxt);
    current = NULL;

    test_nested();

    xmlSetStructuredErrorFunc(NULL, NULL);
    read_memory("handler removed", "<a>", 0);
    printf("last=%d\n", xmlGetLastError() ? xmlGetLastError()->code : 0);
    puts("handler tests passed");
    return 0;
}
