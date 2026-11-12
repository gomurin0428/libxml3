/* The push parser: xmlCreatePushParserCtxt, xmlParseChunk and
 * xmlCtxtResetPush.  The output of this program is compared between
 * libxml3 and the pinned reference libxml2 (make test-push), so every line
 * must describe behavior both share.  libxml3 parses the input when it is
 * terminated, so malformed input is pushed in the terminating call and
 * the partial document libxml2 leaves in myDoc is not compared. */
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void put_error(void) {
    const xmlError *error = xmlGetLastError();

    if (error == NULL || error->code == 0) {
        puts(" error=none");
        return;
    }
    printf(" error=%d/%d level=%d line=%d file=%s\n", error->domain,
           error->code, (int)error->level, error->line,
           error->file ? error->file : "null");
}

static void put_context(const char *label, xmlParserCtxtPtr ctxt, int ret) {
    printf("%s: ret=%d wellFormed=%d errNo=%d", label, ret, ctxt->wellFormed,
           ctxt->errNo);
    put_error();
    xmlResetLastError();
}

/* Takes the document the push left in myDoc. */
static void put_document(xmlParserCtxtPtr ctxt) {
    xmlChar *text = NULL;
    int size = 0;

    if (ctxt->myDoc == NULL) {
        puts("  doc: none");
        return;
    }
    xmlDocDumpMemory(ctxt->myDoc, &text, &size);
    printf("  doc: %s", (const char *)text);
    xmlFree(text);
    xmlFreeDoc(ctxt->myDoc);
    ctxt->myDoc = NULL;
}

static void push_case(const char *label, const char *first,
                      const char *const *chunks, int count,
                      const char *filename) {
    xmlParserCtxtPtr ctxt = xmlCreatePushParserCtxt(
        NULL, NULL, first, first ? (int)strlen(first) : 0, filename);
    char name[64];
    int ret;

    assert(ctxt != NULL);
    printf("%s: options=%d user=%d\n", label, xmlCtxtGetOptions(ctxt),
           xmlCtxtGetUserData(ctxt) == ctxt);
    for (int i = 0; i < count; ++i) {
        ret = xmlParseChunk(ctxt, chunks[i], (int)strlen(chunks[i]), 0);
        snprintf(name, sizeof(name), " chunk %d", i);
        put_context(name, ctxt, ret);
    }
    ret = xmlParseChunk(ctxt, NULL, 0, 1);
    put_context(" terminate", ctxt, ret);
    put_document(ctxt);
    xmlFreeParserCtxt(ctxt);
}

/* Malformed input, pushed in the terminating call. */
static void failing_case(const char *label, const char *text,
                         const char *filename) {
    xmlParserCtxtPtr ctxt =
        xmlCreatePushParserCtxt(NULL, NULL, NULL, 0, filename);
    int ret;

    assert(ctxt != NULL);
    ret = xmlParseChunk(ctxt, text, (int)strlen(text), 1);
    put_context(label, ctxt, ret);
    /* The parser is stopped: later chunks answer the error. */
    ret = xmlParseChunk(ctxt, "<x/>", 4, 0);
    printf("  later chunk: %d\n", ret);
    if (ctxt->myDoc != NULL) {
        xmlFreeDoc(ctxt->myDoc);
        ctxt->myDoc = NULL;
    }
    xmlFreeParserCtxt(ctxt);
}

static int handler_calls;

static void handler(void *data, const xmlError *error) {
    (void)data;
    handler_calls++;
    printf("  handler: %d/%d line=%d\n", error->domain, error->code,
           error->line);
}

static void test_arguments(void) {
    xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
    xmlParserCtxtPtr push;
    xmlDocPtr doc;

    assert(ctxt != NULL);
    printf("plain context: %d\n", xmlParseChunk(ctxt, "<r/>", 4, 1));
    printf("null context: %d\n", xmlParseChunk(NULL, "<r/>", 4, 1));
    push = xmlCreatePushParserCtxt(NULL, NULL, NULL, 0, NULL);
    assert(push != NULL);
    printf("negative size: %d\n", xmlParseChunk(push, "x", -1, 0));
    printf("null bytes: %d\n", xmlParseChunk(push, NULL, 3, 0));
    printf("empty chunk: %d\n", xmlParseChunk(push, "", 0, 0));
    printf("null empty chunk: %d\n", xmlParseChunk(push, NULL, 0, 0));
    /* xmlCtxtReset drops the push input. */
    xmlCtxtReset(push);
    printf("after reset: %d\n", xmlParseChunk(push, "<r/>", 4, 1));
    printf("reset push null: %d\n",
           xmlCtxtResetPush(NULL, NULL, 0, NULL, NULL));

    /* xmlCtxtResetPush gives any context a push input. */
    printf("reset push: %d\n",
           xmlCtxtResetPush(ctxt, "<q a='1'>", 9, "q.xml", NULL));
    printf("  chunk: %d\n", xmlParseChunk(ctxt, "t</q>", 5, 0));
    put_context("  terminate", ctxt, xmlParseChunk(ctxt, NULL, 0, 1));
    put_document(ctxt);
    printf("reset push utf-8: %d\n",
           xmlCtxtResetPush(ctxt, NULL, 0, "u.xml", "UTF-8"));
    put_context("  chunk", ctxt,
                xmlParseChunk(ctxt, "<u>\xc3\xa9</u>", 9, 1));
    /* libxml2 also records the encoding in the document, which libxml3
     * does not do for an encoding argument; the document is not shown. */
    printf("  doc: %s\n", ctxt->myDoc ? "made" : "none");
    xmlFreeDoc(ctxt->myDoc);
    ctxt->myDoc = NULL;
    printf("reset push after error: %d\n",
           xmlCtxtResetPush(ctxt, "<r>", 3, NULL, NULL));
    put_context("  terminate", ctxt, xmlParseChunk(ctxt, "</r>", 4, 1));
    put_document(ctxt);

    /* A read through the context resets it, which drops the input. */
    xmlCtxtResetPush(ctxt, "<r>", 3, NULL, NULL);
    doc = xmlCtxtReadMemory(ctxt, "<z/>", 4, NULL, NULL, 0);
    printf("read: %s chunk after read: %d\n", doc ? "doc" : "null",
           xmlParseChunk(ctxt, "</r>", 4, 1));
    xmlFreeDoc(doc);

    /* A stopped parser answers its error. */
    xmlCtxtResetPush(ctxt, "<r>", 3, NULL, NULL);
    xmlStopParser(ctxt);
    printf("stopped: %d\n", xmlParseChunk(ctxt, "</r>", 4, 1));

    xmlFreeParserCtxt(ctxt);
    xmlFreeParserCtxt(push);
}

static void test_handler(void) {
    xmlParserCtxtPtr ctxt =
        xmlCreatePushParserCtxt(NULL, NULL, NULL, 0, "h.xml");
    int ret;

    assert(ctxt != NULL);
    xmlCtxtSetErrorHandler(ctxt, handler, NULL);
    handler_calls = 0;
    ret = xmlParseChunk(ctxt, "<r>\n<a></r>", 11, 1);
    printf("handled: ret=%d calls=%d errNo=%d\n", ret, handler_calls,
           ctxt->errNo);
    if (ctxt->myDoc != NULL) {
        xmlFreeDoc(ctxt->myDoc);
        ctxt->myDoc = NULL;
    }
    xmlFreeParserCtxt(ctxt);
}

int main(void) {
    static const char *const ok[] = {"<r a='1'>te", "xt<c/>", "</r>"};
    static const char *const declared[] = {"<c/>", "</r>"};
    static const char *const split[] = {"<", "r", ">", "&am", "p;", "<",
                                        "/r>"};
    static const char *const comment[] = {"<!-- c -->", "<r/>",
                                          "<?pi x?>"};
    static const char *const lines[] = {"<r>\r", "\n</r>"};
    static const char *const nothing[] = {""};
    char large[20000];

    push_case("well-formed", NULL, ok, 3, "push.xml");
    push_case("first chunk", "<?xml version='1.0'?><r>", declared, 2, NULL);
    push_case("split bytes", NULL, split, 7, NULL);
    push_case("prolog and epilog", NULL, comment, 3, NULL);
    push_case("carriage return", NULL, lines, 2, NULL);
    {
        /* UTF-16 with a byte order mark, split inside a character. */
        xmlParserCtxtPtr ctxt =
            xmlCreatePushParserCtxt(NULL, NULL, "\xff\xfe<", 3, NULL);

        put_context("utf-16 chunk", ctxt,
                    xmlParseChunk(ctxt, "\0r\0/\0>\0", 7, 0));
        put_context("utf-16 terminate", ctxt, xmlParseChunk(ctxt, NULL, 0, 1));
        put_document(ctxt);
        xmlFreeParserCtxt(ctxt);
    }
    push_case("nothing pushed", NULL, nothing, 1, NULL);
    {
        const char *chunks[200];

        memset(large, 'x', sizeof(large) - 1);
        large[sizeof(large) - 1] = '\0';
        chunks[0] = "<r>";
        for (int i = 1; i < 199; ++i)
            chunks[i] = large + i * 97 % 5000;
        chunks[199] = "</r>";
        {
            xmlParserCtxtPtr ctxt =
                xmlCreatePushParserCtxt(NULL, NULL, NULL, 0, NULL);
            int ret = 0;

            for (int i = 0; i < 200; ++i)
                ret |= xmlParseChunk(ctxt, chunks[i], (int)strlen(chunks[i]),
                                     0);
            ret |= xmlParseChunk(ctxt, NULL, 0, 1);
            printf("many chunks: ret=%d wellFormed=%d content=%zu\n", ret,
                   ctxt->wellFormed,
                   strlen((const char *)xmlDocGetRootElement(ctxt->myDoc)
                              ->children->content));
            xmlFreeDoc(ctxt->myDoc);
            xmlFreeParserCtxt(ctxt);
        }
    }

    failing_case("malformed", "<r>\n<a>\n</r>", "bad.xml");
    failing_case("unfinished", "<r><a>", NULL);
    failing_case("empty", "", NULL);
    failing_case("only space", "   ", NULL);
    failing_case("extra content", "<r/><s/>", "extra.xml");
    failing_case("bad character", "<r>\x01</r>", NULL);

    test_arguments();
    test_handler();
    puts("push tests passed");
    return 0;
}
