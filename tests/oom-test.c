#define _POSIX_C_SOURCE 200809L
#include <libxml3.h>

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void xml3_oom_enable(long index);
void xml3_oom_disable(void);
long xml3_oom_count(void);
int xml3_oom_was_injected(void);
void xml3_oom_watch_free(const void *ptr);
int xml3_oom_free_count(void);

static char *copy_test_string(const char *value) {
    size_t length = strlen(value) + 1;
    char *copy = malloc(length);
    assert(copy != NULL);
    memcpy(copy, value, length);
    return copy;
}

static void init_test_error(xmlError *error, const char *prefix) {
    char value[64];

    memset(error, 0, sizeof(*error));
    error->domain = XML_FROM_PARSER;
    error->code = XML_ERR_INVALID_CHAR;
    error->level = XML_ERR_FATAL;
    error->line = 17;
    error->int1 = 23;
    error->int2 = 42;
#define SET_FIELD(field, suffix)             \
    do {                                      \
        snprintf(value, sizeof(value), "%s %s", prefix, suffix); \
        error->field = copy_test_string(value); \
    } while (0)
    SET_FIELD(message, "message");
    SET_FIELD(file, "file");
    SET_FIELD(str1, "str1");
    SET_FIELD(str2, "str2");
    SET_FIELD(str3, "str3");
#undef SET_FIELD
}

static void assert_error_unchanged(const xmlError *actual,
                                   const xmlError *expected) {
    assert(actual->domain == expected->domain);
    assert(actual->code == expected->code);
    assert(actual->level == expected->level);
    assert(actual->line == expected->line);
    assert(actual->int1 == expected->int1);
    assert(actual->int2 == expected->int2);
    assert(actual->ctxt == expected->ctxt);
    assert(actual->node == expected->node);
    assert(actual->message == expected->message);
    assert(actual->file == expected->file);
    assert(actual->str1 == expected->str1);
    assert(actual->str2 == expected->str2);
    assert(actual->str3 == expected->str3);
    assert(strcmp(actual->message, expected->message) == 0);
    assert(strcmp(actual->file, expected->file) == 0);
    assert(strcmp(actual->str1, expected->str1) == 0);
    assert(strcmp(actual->str2, expected->str2) == 0);
    assert(strcmp(actual->str3, expected->str3) == 0);
}

static void assert_error_copy(const xmlError *actual,
                              const xmlError *source) {
    assert(actual->domain == source->domain);
    assert(actual->code == source->code);
    assert(actual->level == source->level);
    assert(actual->line == source->line);
    assert(actual->int1 == source->int1);
    assert(actual->int2 == source->int2);
    assert(actual->message != source->message);
    assert(actual->file != source->file);
    assert(actual->str1 != source->str1);
    assert(actual->str2 != source->str2);
    assert(actual->str3 != source->str3);
    assert(strcmp(actual->message, source->message) == 0);
    assert(strcmp(actual->file, source->file) == 0);
    assert(strcmp(actual->str1, source->str1) == 0);
    assert(strcmp(actual->str2, source->str2) == 0);
    assert(strcmp(actual->str3, source->str3) == 0);
}

/* The errors a context handler receives during the context-handler walk. */
static int handled_errors;
static int handled_foreign;
static int nested_checked;
static xmlParserCtxtPtr nested_ctxt;

static void oom_context_handler(void *data, const xmlError *error) {
    handled_errors++;
    if (error->ctxt != data)
        handled_foreign++;
    /* A read through another context from an out-of-memory handler is
     * recorded for that context, even when the failed allocation was a
     * copy into the outer context's lastError. */
    if (error->code == XML_ERR_NO_MEMORY && nested_ctxt != NULL &&
        !nested_checked) {
        xmlDocPtr nested;

        nested_checked = 1;
        nested = xmlCtxtReadMemory(nested_ctxt, "<x>", 3, NULL, NULL,
                                   XML_PARSE_NOERROR);
        assert(!nested && nested_ctxt->wellFormed == 0);
        assert(nested_ctxt->errNo == 77 && xmlCtxtGetLastError(nested_ctxt));
    }
}

/* A thread handler that allocates while it handles a warning. */
static int warning_handler_failed;

static void allocating_handler(void *data, const xmlError *error) {
    xmlChar *copy;

    (void)data;
    (void)error;
    copy = xmlStrdup(BAD_CAST "handled");
    if (copy == NULL)
        warning_handler_failed = 1;
    xmlFree(copy);
}

/* A thread handler whose own reads would replace the thread's record:
 * the record it was handed must not change under it. */
static int detached_changed;

static void resetting_handler(void *data, const xmlError *error) {
    int code = error->code, line = error->line;
    xmlDocPtr nested;

    (void)data;
    xmlSetStructuredErrorFunc(NULL, NULL);
    xmlResetLastError();
    nested = xmlReadMemory("<n>\n</m>", 8, NULL, NULL, XML_PARSE_NOERROR);
    xmlFreeDoc(nested);
    if (error->code != code || error->line != line)
        detached_changed = 1;
    xmlSetStructuredErrorFunc(NULL, resetting_handler);
}

static const xmlError *require_oom_error(void) {
    const xmlError *error = xmlGetLastError();
    assert(error != NULL);
    assert(error->domain == XML_FROM_MEMORY);
    assert(error->code == XML_ERR_NO_MEMORY);
    assert(error->level == XML_ERR_FATAL);
    return error;
}

/* For context-stopped: a callback input whose second read fails with
 * XML_IO_UNKNOWN (a warning), and a handler that stops the parser. */
static int oom_warning_read(void *context, char *buffer, int length) {
    int *reads = context;
    static const char text[] = "<r a='1'><c>t</c><d>u</d></r>";

    if ((*reads)++ > 0 || length < (int)sizeof(text))
        return -1;
    memcpy(buffer, text, sizeof(text) - 1);
    return (int)sizeof(text) - 1;
}

static void oom_stop_handler(void *data, const xmlError *error) {
    (void)error;
    xmlStopParser(data);
}

/* A callback input for read-io. */
typedef struct {
    const char *text;
    size_t at;
    int closes;
} oom_source;

static int oom_source_read(void *context, char *buffer, int length) {
    oom_source *input = context;
    size_t left = strlen(input->text) - input->at;
    size_t count = left < (size_t)length ? left : (size_t)length;

    memcpy(buffer, input->text + input->at, count);
    input->at += count;
    return (int)count;
}

static int oom_source_close(void *context) {
    ((oom_source *)context)->closes++;
    return 0;
}

int main(int argc, char **argv) {
    const char *operation;
    long fail_index;
    long allocation_count;
    int injected;
    xmlDocPtr doc = NULL;
    xmlNodePtr dom_node = NULL;
    xmlNodePtr merge_left = NULL;
    xmlNodePtr merge_right = NULL;
    xmlError copy = {0};
    xmlError source = {0};
    const xmlError *error;
    int result = 0;

    assert(argc == 3);
    operation = argv[1];
    fail_index = strtol(argv[2], NULL, 10);
    xmlResetLastError();

    if (strcmp(operation, "strcat") == 0 || strcmp(operation, "strncat") == 0) {
        int bounded = strcmp(operation, "strncat") == 0;
        xmlChar *cur = xmlStrdup(BAD_CAST "consume");
        assert(cur);
        xml3_oom_watch_free(cur);
        cur = xmlStrncat(cur, BAD_CAST "x", -1);
        assert(!cur && xml3_oom_free_count() == 1);
        xml3_oom_watch_free(NULL);
        cur = xmlStrdup(BAD_CAST "pre");
        assert(cur);
        xml3_oom_watch_free(cur);
        xml3_oom_enable(fail_index);
        assert(xmlStrcat(cur, NULL) == cur);
        assert(xmlStrcat(cur, BAD_CAST "") == cur);
        assert(xmlStrncat(cur, cur, 0) == cur);
        assert(xmlStrncat(cur, NULL, -1) == cur);
        assert(xml3_oom_count() == 0 && xml3_oom_free_count() == 0);
        cur = bounded ? xmlStrncat(cur, cur + 1, 2) : xmlStrcat(cur, cur + 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(xml3_oom_free_count() == 1);
        xml3_oom_watch_free(NULL);
        if (injected) {
            assert(!cur);
            require_oom_error();
        } else {
            assert(cur && xmlStrEqual(cur, BAD_CAST "prere"));
        }
        xmlFree(cur);
        cur = xmlStrdup(BAD_CAST "pre");
        assert(cur);
        cur = bounded ? xmlStrncat(cur, BAD_CAST "re", 2) : xmlStrcat(cur, BAD_CAST "re");
        assert(cur && xmlStrEqual(cur, BAD_CAST "prere"));
        xmlFree(cur);
    } else if (strcmp(operation, "utf8-check") == 0) {
        xml3_oom_enable(0);
        assert(xmlUTF8Charcmp(NULL, NULL) == 0);
        assert(xmlUTF8Charcmp(BAD_CAST "名", BAD_CAST "名suffix") == 0);
        assert(xmlUTF8Charcmp(BAD_CAST "a", BAD_CAST "z") == 'a' - 'z');
        assert(xmlUTF8Charcmp(BAD_CAST "\xe2x", BAD_CAST "\xe3y") == -1);
        assert(xmlUTF8Size(NULL) == -1 && xmlUTF8Size(BAD_CAST "") == 1);
        assert(xmlUTF8Size(BAD_CAST "a") == 1 && xmlUTF8Size(BAD_CAST "名") == 3);
        assert(xmlUTF8Size(BAD_CAST "\xc2") == 2);
        assert(xmlUTF8Size(BAD_CAST "\xf4") == 4);
        assert(xmlUTF8Size(BAD_CAST "\xf5") == -1);
        assert(xmlUTF8Size(BAD_CAST "\xc0\x80") == -1);
        assert(xmlUTF8Strloc(BAD_CAST "A名名", BAD_CAST "名suffix") == 1);
        assert(xmlUTF8Strloc(BAD_CAST "abc", BAD_CAST "z") == -1);
        assert(xmlUTF8Strloc(BAD_CAST "\xc0\x80z", BAD_CAST "z") == -1);
        assert(xmlUTF8Strloc(BAD_CAST "z", BAD_CAST "\xc0\x80") == -1);
        assert(xmlUTF8Strloc(BAD_CAST "x", BAD_CAST "") == 0);
        assert(xmlUTF8Strloc(BAD_CAST "", BAD_CAST "") == -1);
        assert(xmlCheckUTF8(NULL) == 0 && xmlCheckUTF8(BAD_CAST "") == 1);
        assert(xmlCheckUTF8(BAD_CAST "ASCII名é") == 1);
        assert(xmlCheckUTF8(BAD_CAST "\x01\xef\xbf\xbe") == 1);
        assert(xmlCheckUTF8(BAD_CAST "\xc0\x80") == 0);
        assert(xmlCheckUTF8(BAD_CAST "\xed\xa0\x80") == 0);
        assert(xmlCheckUTF8(BAD_CAST "\xf4\x90\x80\x80") == 0);
        int len = 4;
        assert(xmlGetUTF8Char(BAD_CAST "\xf4\x8f\xbf\xbf", &len) == 0x10ffff && len == 4);
        len = 4;
        assert(xmlGetUTF8Char(BAD_CAST "\xfc\x80\x80\x80", &len) == -1 && len == 0);
        assert(xmlUTF8Strlen(NULL) == -1 && xmlUTF8Strlen(BAD_CAST "") == 0);
        assert(xmlUTF8Strlen(BAD_CAST "A名é") == 3);
        assert(xmlUTF8Strlen(BAD_CAST "a\xed\xa0\x80") == -1);
        const xmlChar position_text[] = "A名";
        assert(xmlUTF8Strpos(position_text, 1) == position_text + 1);
        assert(xmlUTF8Strpos(position_text, 2) == position_text + 4);
        assert(!xmlUTF8Strpos(position_text, 3));
        assert(xmlUTF8Strsize(position_text, 1) == 1);
        assert(xmlUTF8Strsize(position_text, 3) == 4);
        assert(xmlUTF8Strsize(NULL, 2) == 0);
        assert(xmlUTF8Strsize(BAD_CAST "a\xed\xa0\x80", 2) == -1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "dom-adjacent-sibling") == 0) {
        xmlNodePtr root;
        xmlNodePtr left;
        xmlNodePtr right;
        xmlNodePtr child;

        doc = xmlNewDoc(BAD_CAST "1.0");
        root = xmlNewNode(NULL, BAD_CAST "root");
        left = xmlNewText(BAD_CAST "left");
        right = xmlNewText(BAD_CAST "right");
        child = xmlNewText(BAD_CAST "child");
        assert(doc && root && left && right && child);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, left) == left);
        assert(xmlAddPrevSibling(left, right) == right);
        xml3_oom_enable(fail_index);
        assert(xmlAddPrevSibling(right, child) == child);
        assert(xml3_oom_count() == 0);
        assert(root->children == child && child->next == right);
        assert(right->prev == child && right->next == left);
        assert(left->prev == right);
        assert(left->content != child->content);
        assert(xmlAddNextSibling(child, left) == left);
        assert(xml3_oom_count() == 0);
        assert(child->next == left && left->prev == child);
        assert(left->content != child->content);
        xml3_oom_disable();
        xmlFreeDoc(doc);
        doc = NULL;
    } else if (strcmp(operation, "utf8-charcmp-error") == 0) {
        const xmlChar invalid[] = {0xe2, 'x', 0};
        xml3_oom_enable(fail_index);
        assert(xmlUTF8Charcmp(invalid, invalid) == -1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(injected && allocation_count >= 1);
        require_oom_error();
        assert(invalid[0] == 0xe2 && invalid[1] == 'x' && invalid[2] == 0);
        xmlResetLastError();
        assert(xmlUTF8Charcmp(invalid, invalid) == -1);
        assert(xmlGetLastError() && xmlGetLastError()->code == XML_ERR_INVALID_CHAR);
        xmlResetLastError();
        assert(xmlUTF8Charcmp(BAD_CAST "名", BAD_CAST "名") == 0);
        assert(!xmlGetLastError());
    } else if (strcmp(operation, "string-length") == 0) {
        xml3_oom_enable(0);
        assert(xmlStrlen(NULL) == 0);
        assert(xmlStrlen(BAD_CAST "") == 0);
        assert(xmlStrlen(BAD_CAST "名é") == 5);
        assert(xmlStrlen(BAD_CAST "a\0tail") == 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "full-string-compare") == 0) {
        xml3_oom_enable(0);
        assert(xmlStrcmp(BAD_CAST "abc", BAD_CAST "abd") == -1);
        assert(xmlStrcasecmp(BAD_CAST "aBc[", BAD_CAST "AbC{") == 0);
        assert(xmlStrcasecmp(BAD_CAST "a", BAD_CAST "B") == -1);
        assert(xmlStrcasecmp(NULL, NULL) == 0);
        assert(xmlStrcasecmp(NULL, BAD_CAST "") == -1);
        assert(xmlStrEqual(BAD_CAST "abc", BAD_CAST "abc") == 1);
        assert(!xmlStrEqual(BAD_CAST "a", BAD_CAST "b"));
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "substring-search") == 0) {
        xmlChar source[] = "aB[aB";
        xml3_oom_enable(0);
        assert(xmlStrstr(source, BAD_CAST "aB") == source);
        assert(xmlStrcasestr(source, BAD_CAST "ab") == source);
        assert(xmlStrcasestr(source, BAD_CAST "{") == source + 2);
        assert(!xmlStrstr(source, BAD_CAST "missing"));
        assert(xmlStrstr(source, BAD_CAST "") == source);
        assert(!xmlStrcasestr(NULL, BAD_CAST "x"));
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "qname-equal") == 0) {
        xml3_oom_enable(0);
        assert(xmlStrQEqual(BAD_CAST "p", BAD_CAST "名", BAD_CAST "p:名") == 1);
        assert(xmlStrQEqual(BAD_CAST "p", BAD_CAST "n", BAD_CAST "p:x") == 0);
        assert(xmlStrQEqual(NULL, NULL, NULL) == 1);
        assert(xmlStrQEqual(BAD_CAST "", BAD_CAST "", BAD_CAST "") == 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "string-search") == 0) {
        xmlChar source[] = "ab";
        xml3_oom_enable(0);
        assert(xmlStrchr(source, 'b') == source + 1);
        assert(!xmlStrchr(source, 'z') && !xmlStrchr(source, 0));
        assert(!xmlStrchr(NULL, 'b'));
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "char-strdup") == 0 || strcmp(operation, "char-strndup") == 0 ||
               strcmp(operation, "char-strndup-empty") == 0) {
        char source[] = {'a', (char)0xff, 0, 'z'};
        const xmlChar expected[] = {'a', 0xff, 0};
        int bounded = strcmp(operation, "char-strdup") != 0;
        int empty = strcmp(operation, "char-strndup-empty") == 0;
        int length = empty ? 0 : (int)sizeof(source);
        xml3_oom_enable(fail_index);
        assert(!xmlCharStrdup(NULL) && !xmlCharStrndup(NULL, 0));
        assert(!xmlCharStrndup(source, -1) && xml3_oom_count() == 0);
        xmlChar *copy = bounded ? xmlCharStrndup(source, length) : xmlCharStrdup(source);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && (empty ? copy[0] == 0 :
                           memcmp(copy, expected, sizeof(expected)) == 0));
        }
        xmlFree(copy);
        assert(source[0] == 'a' && (unsigned char)source[1] == 0xff && source[2] == 0 && source[3] == 'z');
        copy = bounded ? xmlCharStrndup(source, length) : xmlCharStrdup(source);
        assert(copy && (empty ? copy[0] == 0 :
                       memcmp(copy, expected, sizeof(expected)) == 0));
        xmlFree(copy);
    } else if (strcmp(operation, "string-compare") == 0) {
        xml3_oom_enable(0);
        assert(xmlStrncmp(BAD_CAST "abc", BAD_CAST "abd", 3) == -1);
        assert(xmlStrncasecmp(BAD_CAST "aBc", BAD_CAST "AbC", 3) == 0);
        assert(xmlStrncasecmp(BAD_CAST "[", BAD_CAST "{", 1) == 0);
        assert(xmlStrncmp(NULL, NULL, 1) == 0);
        assert(xmlStrncasecmp(NULL, BAD_CAST "a", 0) == 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "strncat-new") == 0 ||
               strcmp(operation, "strncat-new-empty") == 0) {
        int empty = strcmp(operation, "strncat-new-empty") == 0;
        xmlChar left[] = "L", right[] = {'a', 0, 'b', 0xff};
        const xmlChar expected[] = {'L', 'a', 0, 'b', 0xff, 0};
        xml3_oom_enable(fail_index);
        assert(!xmlStrncatNew(NULL, NULL, -1) && xml3_oom_count() == 0);
        xmlChar *copy = xmlStrncatNew(empty ? NULL : left, right,
                                     empty ? 0 : (int)sizeof(right));
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && (empty ? copy[0] == 0 :
                           memcmp(copy, expected, sizeof(expected)) == 0));
        }
        xmlFree(copy);
        assert(left[0] == 'L' && left[1] == 0);
        assert(right[0] == 'a' && right[1] == 0 && right[2] == 'b' && right[3] == 0xff);
        copy = xmlStrncatNew(empty ? NULL : left, right, empty ? 0 : (int)sizeof(right));
        assert(copy && (empty ? copy[0] == 0 :
                       memcmp(copy, expected, sizeof(expected)) == 0));
        xmlFree(copy);
    } else if (strcmp(operation, "utf8-strsub") == 0) {
        const xmlChar source[] = "A名\xf0\x9f\x98\x80";
        xml3_oom_enable(fail_index);
        assert(!xmlUTF8Strsub(NULL, 0, 0) && !xmlUTF8Strsub(source, -1, 1));
        assert(!xmlUTF8Strsub(source, 1, -1) && !xmlUTF8Strsub(source, 4, 0));
        assert(!xmlUTF8Strsub(BAD_CAST "\xed\xa0\x80x", 1, 0));
        assert(!xmlUTF8Strsub(BAD_CAST "a\xed\xa0\x80", 1, 1));
        assert(xml3_oom_count() == 0);
        xmlChar *copy = xmlUTF8Strsub(source, 1, 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && !memcmp(copy, source + 1, 3) && copy[3] == 0);
        }
        xmlFree(copy);
        assert(!memcmp(source, "A名\xf0\x9f\x98\x80", sizeof(source)));
        copy = xmlUTF8Strsub(source, 1, 1);
        assert(copy && !memcmp(copy, source + 1, 3) && copy[3] == 0);
        xmlFree(copy);
        xml3_oom_enable(0);
        copy = xmlUTF8Strsub(source, 3, 0);
        assert(!copy && xml3_oom_was_injected());
        xml3_oom_disable();
        require_oom_error();
        copy = xmlUTF8Strsub(source, 3, 0);
        assert(copy && copy[0] == 0);
        xmlFree(copy);
    } else if (strcmp(operation, "utf8-strndup") == 0) {
        const xmlChar source[] = "A名\xf0\x9f\x98\x80";
        xml3_oom_enable(fail_index);
        assert(!xmlUTF8Strndup(NULL, 0) && !xmlUTF8Strndup(source, -1));
        assert(!xmlUTF8Strndup(BAD_CAST "a\xed\xa0\x80", 2));
        assert(xml3_oom_count() == 0);
        xmlChar *copy = xmlUTF8Strndup(source, 2);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && copy != source && !memcmp(copy, source, 4) && copy[4] == 0);
        }
        xmlFree(copy);
        assert(!memcmp(source, "A名\xf0\x9f\x98\x80", sizeof(source)));
        copy = xmlUTF8Strndup(source, 2);
        assert(copy && !memcmp(copy, source, 4) && copy[4] == 0);
        xmlFree(copy);
        xml3_oom_enable(0);
        copy = xmlUTF8Strndup(source, 0);
        assert(!copy && xml3_oom_was_injected() && xml3_oom_count() >= 1);
        xml3_oom_disable();
        require_oom_error();
        copy = xmlUTF8Strndup(source, 0);
        assert(copy && copy[0] == 0);
        xmlFree(copy);
    } else if (strcmp(operation, "strsub") == 0) {
        const xmlChar source[] = {'x', 'a', 0, 'b', 0xff};
        xml3_oom_enable(fail_index);
        assert(!xmlStrsub(NULL, 0, 0));
        assert(!xmlStrsub(source, -1, 1) && !xmlStrsub(source, 0, -1));
        assert(!xmlStrsub(source, 2, 0) && xml3_oom_count() == 0);
        xmlChar *copy = xmlStrsub(source, 1, 4);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && !memcmp(copy, source + 1, 4) && copy[4] == 0);
        }
        xmlFree(copy);
        assert(source[0] == 'x' && source[1] == 'a' && source[2] == 0 &&
               source[3] == 'b' && source[4] == 0xff);
        copy = xmlStrsub(source, 1, 4);
        assert(copy && !memcmp(copy, source + 1, 4) && copy[4] == 0);
        xmlFree(copy);
    } else if (strcmp(operation, "strdup") == 0 || strcmp(operation, "strndup") == 0) {
        const xmlChar source[] = {'a', 0, 'b', 0xff};
        int bounded = strcmp(operation, "strndup") == 0;
        size_t length = bounded ? sizeof(source) : 1;
        xml3_oom_enable(fail_index);
        assert(!xmlStrdup(NULL) && !xmlStrndup(NULL, 0));
        assert(!xmlStrndup(source, -1) && xml3_oom_count() == 0);
        xmlChar *copy = bounded ? xmlStrndup(source, sizeof(source)) : xmlStrdup(source);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && copy != source && memcmp(copy, source, length) == 0);
            assert(copy[length] == 0);
        }
        xmlFree(copy);
        assert(source[0] == 'a' && source[1] == 0 && source[2] == 'b' && source[3] == 0xff);
        copy = bounded ? xmlStrndup(source, sizeof(source)) : xmlStrdup(source);
        assert(copy && memcmp(copy, source, length) == 0 && copy[length] == 0);
        xmlFree(copy);
    } else if (strcmp(operation, "node-copy") == 0 ||
               strcmp(operation, "node-copy-doc") == 0 ||
               strcmp(operation, "prop-copy") == 0 ||
               strcmp(operation, "doc-copy") == 0) {
        static const char text[] =
            "<r xmlns:a='urn:a'><a:c a:k='v' b='w'>t<d xmlns='urn:d'>u</d>"
            "<!--c--></a:c></r>";
        xmlChar *before = NULL, *after = NULL;
        int before_size = 0, after_size = 0;
        xmlDocPtr target = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root, source, other;
        xmlNodePtr copy = NULL;

        doc = xmlReadMemory(text, (int)strlen(text), NULL, NULL, 0);
        assert(doc && target);
        root = xmlDocGetRootElement(doc);
        source = root->children;
        /* The property copy target binds the prefix to another name, so
         * the copy needs a reconciled declaration. */
        other = xmlNewDocNode(target, NULL, BAD_CAST "o", NULL);
        assert(other && xmlNewNs(other, BAD_CAST "urn:other", BAD_CAST "a"));
        xmlDocSetRootElement(target, other);
        xmlDocDumpMemory(doc, &before, &before_size);
        assert(before);
        xml3_oom_enable(fail_index);
        if (strcmp(operation, "node-copy") == 0)
            copy = xmlCopyNode(source, 1);
        else if (strcmp(operation, "node-copy-doc") == 0)
            copy = xmlDocCopyNode(source, target, 1);
        else if (strcmp(operation, "prop-copy") == 0)
            copy = (xmlNodePtr)xmlCopyProp(other, source->properties);
        else
            copy = (xmlNodePtr)xmlCopyDoc(doc, 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy);
            if (strcmp(operation, "prop-copy") == 0) {
                assert(copy->type == XML_ATTRIBUTE_NODE && copy->ns &&
                       xmlStrEqual(copy->ns->href, BAD_CAST "urn:a"));
                xmlFreeProp((xmlAttrPtr)copy);
            } else if (strcmp(operation, "doc-copy") == 0) {
                xmlDocDumpMemory((xmlDocPtr)copy, &after, &after_size);
                assert(after && after_size == before_size &&
                       memcmp(after, before, (size_t)before_size) == 0);
                xmlFree(after);
                after = NULL;
                xmlFreeDoc((xmlDocPtr)copy);
            } else {
                assert(copy->type == XML_ELEMENT_NODE && copy->parent == NULL &&
                       copy->ns && xmlStrEqual(copy->ns->href, BAD_CAST "urn:a"));
                xmlFreeNode(copy);
            }
        }
        /* A failed or successful copy leaves the source unchanged. */
        xmlDocDumpMemory(doc, &after, &after_size);
        assert(after && after_size == before_size &&
               memcmp(after, before, (size_t)before_size) == 0);
        xmlFree(after);
        xmlFree(before);
        xmlFreeDoc(target);
        xmlFreeDoc(doc);
        doc = NULL;
    } else if (strcmp(operation, "buffer-ops") == 0) {
        /* Every buffer operation that allocates leaves a usable buffer
         * with its previous content when the allocation fails. */
        char big[400];
        xmlBufferPtr buf;
        int add_result, head_result;
        xmlChar *detached;

        memset(big, 'z', sizeof(big) - 1);
        big[sizeof(big) - 1] = 0;
        xml3_oom_enable(fail_index);
        buf = xmlBufferCreate();
        if (buf == NULL) {
            injected = xml3_oom_was_injected();
            allocation_count = xml3_oom_count();
            xml3_oom_disable();
            assert(injected);
        } else {
            add_result = xmlBufferAdd(buf, BAD_CAST "abc", -1);
            assert(add_result == 0);
            add_result = xmlBufferAdd(buf, BAD_CAST big, -1);
            assert(add_result == 0 || add_result == XML_ERR_NO_MEMORY);
            assert(xmlBufferLength(buf) ==
                   (add_result == 0 ? 3 + (int)strlen(big) : 3));
            assert(memcmp(xmlBufferContent(buf), "abc", 3) == 0);
            assert(xmlBufferShrink(buf, 1) == 1);
            head_result = xmlBufferAddHead(buf, BAD_CAST big, -1);
            assert(head_result == 0 || head_result == -1);
            detached = xmlBufferDetach(buf);
            injected = xml3_oom_was_injected();
            allocation_count = xml3_oom_count();
            xml3_oom_disable();
            if (detached != NULL) {
                assert(strstr((const char *)detached, "bc") != NULL);
                xmlFree(detached);
            }
            assert(xmlBufferLength(buf) == 0 && xmlBufferContent(buf) == NULL);
            assert(xmlBufferAdd(buf, BAD_CAST "again", -1) == 0);
            assert(strcmp((const char *)xmlBufferContent(buf), "again") == 0);
            xmlBufferFree(buf);
        }
    } else if (strcmp(operation, "node-dump") == 0 ||
               strcmp(operation, "save-file") == 0) {
        static const char text[] =
            "<r xmlns:a='urn:a'><a:c k='v'>t<d/><!--c--></a:c></r>";
        xmlBufferPtr buf = xmlBufferCreate();
        char path[] = "/tmp/xml3-oom-save-XXXXXX";
        int fd = -1;
        int result;

        doc = xmlReadMemory(text, (int)strlen(text), NULL, NULL, 0);
        assert(doc && buf);
        assert(xmlBufferCCat(buf, "keep|") == 0);
        if (strcmp(operation, "save-file") == 0) {
            fd = mkstemp(path);
            assert(fd >= 0);
            close(fd);
        }
        xml3_oom_enable(fail_index);
        if (strcmp(operation, "node-dump") == 0)
            result = xmlNodeDump(buf, doc, xmlDocGetRootElement(doc), 1, 1);
        else
            result = xmlSaveFormatFile(path, doc, 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            if (strcmp(operation, "node-dump") == 0)
                assert(strcmp((const char *)xmlBufferContent(buf), "keep|") == 0);
        } else {
            assert(result > 0);
        }
        if (strcmp(operation, "save-file") == 0)
            unlink(path);
        xmlBufferFree(buf);
        xmlFreeDoc(doc);
        doc = NULL;
    } else if (strcmp(operation, "read-file") == 0) {
        /* A file: URI path, the file contents and the parse each
         * allocate; every failure returns NULL with the out-of-memory
         * error. */
        char path[] = "/tmp/xml3-oom-read-XXXXXX";
        char uri[64];
        int fd = mkstemp(path);
        static const char text[] = "<r a='1'><c>t</c></r>";

        assert(fd >= 0);
        assert(write(fd, text, sizeof(text) - 1) == (ssize_t)(sizeof(text) - 1));
        close(fd);
        snprintf(uri, sizeof(uri), "file://%s", path);
        xml3_oom_enable(fail_index);
        doc = xmlReadFile(uri, NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        unlink(path);
        if (injected) {
            assert(!doc);
            require_oom_error();
        } else {
            assert(doc && xmlDocGetRootElement(doc));
            xmlFreeDoc(doc);
        }
        doc = NULL;
    } else if (strcmp(operation, "read-fd") == 0 ||
               strcmp(operation, "read-io") == 0) {
        /* The read buffer and the parse each allocate; every failure
         * returns NULL with the out-of-memory error, and the callback
         * input is still closed. */
        static const char text[] = "<r a='1'><c>t</c></r>";
        int pipes[2];
        oom_source input = {text, 0, 0};

        assert(pipe(pipes) == 0);
        assert(write(pipes[1], text, sizeof(text) - 1) == (ssize_t)(sizeof(text) - 1));
        close(pipes[1]);
        xml3_oom_enable(fail_index);
        if (strcmp(operation, "read-fd") == 0)
            doc = xmlReadFd(pipes[0], "pipe.xml", NULL, 0);
        else
            doc = xmlReadIO(oom_source_read, oom_source_close, &input,
                            "io.xml", NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        close(pipes[0]);
        if (strcmp(operation, "read-io") == 0)
            assert(input.closes == 1);
        if (injected) {
            assert(!doc);
            require_oom_error();
        } else {
            assert(doc && xmlDocGetRootElement(doc));
            xmlFreeDoc(doc);
        }
        doc = NULL;
    } else if (strcmp(operation, "save-context") == 0) {
        /* Creating a save context, saving a document into its pending
         * bytes and closing it each allocate.  A failure leaves no context
         * (with the out-of-memory error), a -1 save, or a close that
         * reports the failed write. */
        static const char text[] = "<r a='1'><c>t\xc3\xa9</c><e/></r>";
        xmlBufferPtr buf = xmlBufferCreate();
        xmlSaveCtxtPtr ctxt;
        long saved = -1;
        int closed = -1;

        doc = xmlReadMemory(text, (int)strlen(text), NULL, NULL, 0);
        assert(doc && buf);
        /* Output this serializer cannot produce is refused up front. */
        assert(!xmlSaveToBuffer(buf, NULL, XML_SAVE_XHTML));
        assert(!xmlSaveToBuffer(buf, NULL, XML_SAVE_WSNONSIG));
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        assert(!xmlSaveToBuffer(buf, "ISO-8859-1", 0));
        assert(xmlGetLastError() && xmlGetLastError()->code == 32);
        xml3_oom_enable(fail_index);
        ctxt = xmlSaveToBuffer(buf, "UTF-8", XML_SAVE_FORMAT);
        if (ctxt != NULL) {
            saved = xmlSaveDoc(ctxt, doc);
            closed = xmlSaveClose(ctxt);
        }
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (!injected) {
            assert(ctxt && saved == 0 && closed == xmlBufferLength(buf));
            assert(strstr((const char *)xmlBufferContent(buf),
                          "  <c>t\xc3\xa9</c>\n  <e/>\n") != NULL);
        } else if (ctxt == NULL) {
            require_oom_error();
        } else {
            assert(saved == -1 || closed == -1 || closed == xmlBufferLength(buf));
        }
        xmlBufferFree(buf);
        xmlFreeDoc(doc);
        doc = NULL;
    } else if (strcmp(operation, "context-handler") == 0) {
        /* Every error a read publishes, an out-of-memory one included,
         * names the context when its handler receives it. */
        xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
        const xmlError *error;

        assert(ctxt);
        nested_ctxt = xmlNewParserCtxt();
        assert(nested_ctxt);
        nested_checked = 0;
        xmlCtxtSetErrorHandler(ctxt, oom_context_handler, ctxt);
        handled_errors = handled_foreign = 0;
        xml3_oom_enable(fail_index);
        doc = xmlCtxtReadMemory(ctxt, "<r><c/>", 7, "h.xml", NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!doc);
        assert(handled_errors >= 1 && handled_foreign == 0);
        error = xmlCtxtGetLastError(ctxt);
        assert(error && error->ctxt == (void *)ctxt);
        assert(ctxt->wellFormed == 0 && ctxt->errNo == error->code);
        if (!injected)
            assert(error->code == 77);
        xmlFreeParserCtxt(ctxt);
        xmlFreeParserCtxt(nested_ctxt);
        nested_ctxt = NULL;
    } else if (strcmp(operation, "uri-parse") == 0) {
        /* Creating the struct and copying or unescaping each component
         * allocate; a failure answers -1 and leaves no struct. */
        xmlURIPtr uri = NULL;
        xmlChar *saved = NULL;
        int ret;

        xml3_oom_enable(fail_index);
        ret = xmlParseURISafe("http://u%40@h:80/p%20q?x=1#f", &uri);
        if (ret == 0)
            saved = xmlSaveUri(uri);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (ret == 0) {
            assert(uri && uri->port == 80);
            assert(strcmp(uri->user, "u@") == 0 && strcmp(uri->path, "/p q") == 0);
            if (saved != NULL)
                assert(strcmp((const char *)saved,
                              "http://u%40@h:80/p%20q?x=1#f") == 0);
            else
                assert(injected);
        } else {
            assert(injected && ret == -1 && uri == NULL);
        }
        xmlFree(saved);
        xmlFreeURI(uri);
    } else if (strcmp(operation, "uri-build") == 0) {
        /* Resolving, relativizing and escaping each allocate; a failure
         * answers -1 and no string, otherwise the result is complete. */
        xmlChar *built = NULL, *relative = NULL, *escaped;
        int build_ret, relative_ret;

        xml3_oom_enable(fail_index);
        build_ret = xmlBuildURISafe(BAD_CAST "../g?y#s",
                                    BAD_CAST "http://a/b/c/d;p?q", &built);
        relative_ret = xmlBuildRelativeURISafe(BAD_CAST "http://a/b/x%20y/z",
                                               BAD_CAST "http://a/b/c/d",
                                               &relative);
        escaped = xmlURIEscape(BAD_CAST "rel{x}|y");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (build_ret == 0)
            assert(built && strcmp((const char *)built, "http://a/b/g?y#s") == 0);
        else
            assert(injected && build_ret == -1 && built == NULL);
        if (relative_ret == 0)
            assert(relative &&
                   strcmp((const char *)relative, "../x%20y/z") == 0);
        else
            assert(injected && relative_ret == -1 && relative == NULL);
        if (escaped != NULL)
            assert(strcmp((const char *)escaped, "rel%7Bx%7D%7Cy") == 0);
        else
            assert(injected);
        xmlFree(built);
        xmlFree(relative);
        xmlFree(escaped);
    } else if (strcmp(operation, "handler-detached") == 0) {
        /* Whether or not the handler gets a copy of the record, its own
         * reset and failing read do not change the record it holds. */
        detached_changed = 0;
        xmlSetStructuredErrorFunc(NULL, resetting_handler);
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory("<r><c/>", 7, "d.xml", NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        xmlSetStructuredErrorFunc(NULL, NULL);
        assert(!doc && !detached_changed);
    } else if (strcmp(operation, "handler-warning") == 0) {
        /* A failed allocation inside the handler of a warning does not
         * change the result of the read that published it. */
        static const unsigned char input[] = {
            0xef, 0xbb, 0xbf, '<', '?', 'x', 'm', 'l', ' ',
            'v', 'e', 'r', 's', 'i', 'o', 'n', '=', '\'', '1', '.', '0',
            '\'', ' ', 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g', '=', '\'',
            'U', 'T', 'F', '-', '1', '6', '\'', '?', '>', '<', 'r', '/', '>'
        };

        warning_handler_failed = 0;
        xmlSetStructuredErrorFunc(NULL, allocating_handler);
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory((const char *)input, sizeof(input), NULL, NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        xmlSetStructuredErrorFunc(NULL, NULL);
        if (!injected || warning_handler_failed)
            assert(doc != NULL);
        xmlFreeDoc(doc);
        doc = NULL;
    } else if (strcmp(operation, "context-new") == 0) {
        xmlParserCtxtPtr ctxt;

        xml3_oom_enable(fail_index);
        ctxt = xmlNewParserCtxt();
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!ctxt);
            require_oom_error();
        } else {
            assert(ctxt && ctxt->wellFormed == 1 && ctxt->errNo == 0);
            assert(xmlCtxtGetOptions(ctxt) == (1 << 12));
            assert(!xmlCtxtGetLastError(ctxt));
            xmlFreeParserCtxt(ctxt);
        }
    } else if (strcmp(operation, "context-read") == 0) {
        /* A good read, then a malformed one whose error the context
         * copies.  A failed parse or copy leaves the context with the
         * out-of-memory error. */
        static const char good[] = "<r a='1'><c>t</c></r>";
        xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
        xmlDocPtr bad;
        const xmlError *error;
        int good_well_formed, good_errno, good_status, good_stopped;

        assert(ctxt);
        xml3_oom_enable(fail_index);
        doc = xmlCtxtReadMemory(ctxt, good, (int)strlen(good), NULL, NULL, 0);
        good_well_formed = ctxt->wellFormed;
        good_errno = ctxt->errNo;
        good_status = xmlCtxtGetStatus(ctxt);
        good_stopped = xmlCtxtIsStopped(ctxt);
        bad = xmlCtxtReadMemory(ctxt, "<r>", 3, "bad.xml", NULL,
                                XML_PARSE_NOERROR);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (doc != NULL) {
            assert(good_well_formed == 1 && good_errno == 0);
            assert(good_status == 0 && !good_stopped);
            xmlFreeDoc(doc);
        } else {
            assert(injected);
            assert(good_well_formed == 0 && good_errno == XML_ERR_NO_MEMORY);
            /* A memory failure is catastrophic and stops the parser. */
            assert(good_status == 11 && good_stopped);
        }
        doc = NULL;
        assert(!bad && ctxt->wellFormed == 0);
        error = xmlCtxtGetLastError(ctxt);
        assert(error && error->ctxt == (void *)ctxt);
        assert(ctxt->errNo == error->code);
        if (injected)
            assert(error->code == 77 || error->code == XML_ERR_NO_MEMORY);
        else
            assert(error->code == 77 && error->line == 1);
        assert(xmlCtxtIsStopped(ctxt));
        assert(xmlCtxtGetStatus(ctxt) ==
               (error->code == XML_ERR_NO_MEMORY ? 11 : 1));
        xmlCtxtReset(ctxt);
        assert(!xmlCtxtGetLastError(ctxt) && ctxt->wellFormed == 1);
        xmlFreeParserCtxt(ctxt);
    } else if (strcmp(operation, "context-warning") == 0) {
        /* The warning of a failed callback read, copied into the context's
         * lastError; a failed copy is a memory failure, which stops the
         * parser and makes the status catastrophic. */
        xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
        int reads = 0;

        assert(ctxt);
        xml3_oom_enable(fail_index);
        doc = xmlCtxtReadIO(ctxt, oom_warning_read, NULL, &reads, NULL, NULL,
                            0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!doc && ctxt->errNo == XML_ERR_NO_MEMORY);
            assert(xmlCtxtIsStopped(ctxt) && xmlCtxtGetStatus(ctxt) == 11);
        } else {
            assert(doc && ctxt->errNo == 0 && !xmlCtxtIsStopped(ctxt));
            assert(xmlCtxtGetLastError(ctxt)->code == 1500);
            assert(xmlCtxtGetStatus(ctxt) == 0);
            xmlFreeDoc(doc);
        }
        doc = NULL;
        xmlFreeParserCtxt(ctxt);
    } else if (strcmp(operation, "context-stopped") == 0) {
        /* A handler stops the read on the warning of a failed callback
         * read; the parse goes on, and a memory failure is still recorded
         * as the catastrophic error it is. */
        xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
        int reads = 0;
        const xmlError *error;

        assert(ctxt);
        xmlCtxtSetErrorHandler(ctxt, oom_stop_handler, ctxt);
        xml3_oom_enable(fail_index);
        doc = xmlCtxtReadIO(ctxt, oom_warning_read, NULL, &reads, NULL, NULL,
                            0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!doc && xmlCtxtIsStopped(ctxt) && ctxt->wellFormed == 0);
        error = xmlCtxtGetLastError(ctxt);
        assert(error);
        if (injected) {
            /* Wherever the failure falls, before or after the stop, the
             * context records it. */
            assert(ctxt->errNo == XML_ERR_NO_MEMORY);
            assert(error->code == XML_ERR_NO_MEMORY);
            assert(xmlCtxtGetStatus(ctxt) == 11);
        } else {
            assert(ctxt->errNo == 111 && error->code == 111);
            assert(xmlCtxtGetStatus(ctxt) == 1);
        }
        xmlFreeParserCtxt(ctxt);
    } else if (strcmp(operation, "ns-copy") == 0) {
        dom_node = xmlNewNode(NULL, BAD_CAST "root");
        assert(dom_node);
        xmlNsPtr source = xmlNewNs(dom_node, BAD_CAST "urn:p", BAD_CAST "p");
        xmlNsPtr next = xmlNewNs(dom_node, BAD_CAST "urn:q", BAD_CAST "q");
        assert(source && next);
        xml3_oom_enable(fail_index);
        xmlNsPtr copy = xmlCopyNamespace(source);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(dom_node->nsDef == source && source->next == next && !next->next);
        assert(xmlStrEqual(source->href, BAD_CAST "urn:p") && xmlStrEqual(source->prefix, BAD_CAST "p"));
        if (injected) {
            assert(!copy);
            require_oom_error();
        } else {
            assert(copy && copy != source && !copy->next);
            assert(xmlStrEqual(copy->href, source->href));
            xmlFreeNs(copy);
        }
        copy = xmlCopyNamespace(source);
        assert(copy && copy != source && !copy->next);
        xmlFreeNode(dom_node);
        dom_node = NULL;
        assert(xmlStrEqual(copy->href, BAD_CAST "urn:p") && xmlStrEqual(copy->prefix, BAD_CAST "p"));
        xmlFreeNs(copy);
    } else if (strcmp(operation, "qname-build") == 0 ||
               strcmp(operation, "qname-build-alias") == 0) {
        int alias = strcmp(operation, "qname-build-alias") == 0;
        const xmlChar name[] = "name";
        xmlChar buffer[32], before[32];
        xmlChar empty[2] = {0, '!'};
        xml3_oom_enable(fail_index);
        assert(xmlBuildQName(name, NULL, buffer, sizeof(buffer)) == name);
        assert(xmlBuildQName(name, BAD_CAST "p", buffer, 7) == buffer);
        assert(xmlBuildQName(empty, empty, empty, 2) == empty && xmlStrEqual(empty, BAD_CAST ":"));
        assert(xml3_oom_count() == 0);
        assert(xmlStrEqual(buffer, BAD_CAST "p:name"));
        memset(buffer, '!', sizeof(buffer));
        if (alias) strcpy((char *)buffer, "name");
        memcpy(before, buffer, sizeof(buffer));
        xmlChar *built = xmlBuildQName(alias ? buffer : name, BAD_CAST "p", buffer,
                                      alias ? (int)sizeof(buffer) : 6);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected || !alias) assert(memcmp(buffer, before, sizeof(buffer)) == 0);
        if (injected) {
            assert(!built);
            require_oom_error();
        } else {
            assert(built && (alias ? built == buffer : built != buffer));
            assert(xmlStrEqual(built, BAD_CAST "p:name"));
        }
        if (!alias) xmlFree(built);
        memcpy(buffer, before, sizeof(buffer));
        built = xmlBuildQName(alias ? buffer : name, BAD_CAST "p", buffer,
                              alias ? (int)sizeof(buffer) : 6);
        assert(built && (alias ? built == buffer : built != buffer));
        assert(xmlStrEqual(built, BAD_CAST "p:name"));
        if (!alias) {
            assert(memcmp(buffer, before, sizeof(buffer)) == 0);
            xmlFree(built);
        }
    } else if (strcmp(operation, "qname-split") == 0) {
        const xmlChar input[] = "p:name";
        xmlChar *prefix = (xmlChar *)1;
        int length = -1;
        xmlResetLastError();
        assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
        assert(xmlGetLastError() != NULL);
        int saved_error = xmlGetLastError()->code;
        xml3_oom_enable(fail_index);
        assert(xmlSplitQName3(input, &length) == input + 2 && length == 1);
        assert(xmlSplitQName3(BAD_CAST ":", &length) == NULL && length == 1);
        assert(xmlSplitQName3(BAD_CAST "p:", &length) == NULL && length == 1);
        assert(xmlSplitQName3(NULL, &length) == NULL && length == 1);
        xmlChar *unused = (xmlChar *)1;
        assert(xmlSplitQName2(BAD_CAST ":ignored", &unused) == NULL && unused == NULL);
        assert(xmlSplitQName2(BAD_CAST "name", &unused) == NULL && unused == NULL);
        assert(xml3_oom_count() == 0);
        assert(xmlGetLastError() && xmlGetLastError()->code == saved_error);
        xmlChar *local = xmlSplitQName2(input, &prefix);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!local && !prefix);
            require_oom_error();
        } else {
            assert(local && prefix);
            assert(xmlStrEqual(local, BAD_CAST "name"));
            assert(xmlStrEqual(prefix, BAD_CAST "p"));
        }
        xmlFree(local);
        xmlFree(prefix);
        local = xmlSplitQName2(input, &prefix);
        assert(local && prefix && xmlStrEqual(local, BAD_CAST "name")
               && xmlStrEqual(prefix, BAD_CAST "p"));
        xmlFree(local);
        xmlFree(prefix);
    } else if (strcmp(operation, "ns-list") == 0) {
        dom_node = xmlNewNode(NULL, BAD_CAST "root");
        assert(dom_node);
        xmlNsPtr ns = xmlNewNs(dom_node, BAD_CAST "urn:p", BAD_CAST "p");
        assert(ns);
        xmlNsPtr *list = (xmlNsPtr *)1;
        xml3_oom_enable(fail_index);
        int code = xmlGetNsListSafe(NULL, dom_node, &list);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(code == -1 && list == NULL);
            require_oom_error();
        } else {
            assert(code == 0 && list && list[0] == ns && !list[1]);
        }
        xmlFree(list);
        assert(dom_node->nsDef == ns && !ns->next);
        list = xmlGetNsList(NULL, dom_node);
        assert(list && list[0] == ns && !list[1]);
        xmlFree(list);
    } else if (strcmp(operation, "validate-name") == 0) {
        assert(!xmlReadMemory("<", 1, NULL, NULL,
                              XML_PARSE_NOERROR | XML_PARSE_NOWARNING));
        error = xmlGetLastError();
        assert(error && error->code != XML_ERR_OK);
        int saved_code = error->code;
        xml3_oom_enable(fail_index);
        assert(xmlValidateName(BAD_CAST "p:名", 0) == 0);
        assert(xmlValidateNCName(BAD_CAST "p:名", 0) == 1);
        assert(xmlValidateQName(BAD_CAST " \tp:名\r\n", -1) == 0);
        assert(xmlValidateNMToken(BAD_CAST "1:名", 0) == 0);
        assert(xmlValidateName(NULL, 0) == -1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        assert(xmlGetLastError() == error && error->code == saved_code);
    } else if (strcmp(operation, "success") == 0) {
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory("<r><x/></r>", 11, &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(doc != NULL);
            assert(status == XML3_STATUS_OK);
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "arena-growth") == 0) {
        enum { siblings = 3000, length = 7 + siblings * 4 };
        char input[length];
        memcpy(input, "<r>", 3);
        for (int i = 0; i < siblings; ++i)
            memcpy(input + 3 + i * 4, "<x/>", 4);
        memcpy(input + 3 + siblings * 4, "</r>", 4);
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory(input, length, &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!doc && status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
            doc = xml3ReadMemory(input, length, &status);
        }
        memset(input, 0, sizeof(input));
        assert(doc && status == XML3_STATUS_OK);
        assert(xmlChildElementCount(xmlDocGetRootElement(doc)) == siblings);
    } else if (strcmp(operation, "parsed-pi") == 0) {
        const char *input = "<r><?bare?><?empty ?></r>";
        const char *expected = "<?xml version=\"1.0\"?>\n<r><?bare?><?empty ?></r>\n";
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory(input, (int)strlen(input), &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL && status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
            doc = xml3ReadMemory(input, (int)strlen(input), &status);
        }
        assert(doc && status == XML3_STATUS_OK);
        xmlNodePtr bare = xmlDocGetRootElement(doc)->children;
        assert(bare->content == NULL && bare->next->content);
        assert(bare->next->content[0] == 0);
        xmlChar *memory = NULL;
        int size = 0;
        xmlDocDumpMemory(doc, &memory, &size);
        assert(memory && size == (int)strlen(expected));
        assert(strcmp((const char *)memory, expected) == 0);
        xmlFree(memory);
    } else if (strcmp(operation, "option-rejection") == 0) {
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory("<r/>", 4, NULL, NULL, XML_PARSE_HUGE | 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!doc);
        if (injected) {
            require_oom_error();
        } else {
            error = xmlGetLastError();
            assert(error && error->domain == XML_FROM_PARSER && error->code == 115);
        }
        xmlResetLastError();
        doc = xmlReadMemory("<r/>", 4, NULL, NULL, XML_PARSE_HUGE);
        assert(doc && xmlGetLastError() == NULL);
    } else if (strcmp(operation, "malformed") == 0) {
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory("<r><x></r>", 10, &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(doc == NULL);
        if (injected) {
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(status == XML3_STATUS_MALFORMED);
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_TAG_NAME_MISMATCH);
        }
    } else if (strcmp(operation, "utf16") == 0 ||
               strcmp(operation, "utf16-empty") == 0) {
        static const unsigned char input[] = {
            0xff, 0xfe, '<', 0, 'r', 0, '/', 0, '>', 0
        };
        int status = -1;
        int empty = strcmp(operation, "utf16-empty") == 0;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory((const char *)input, empty ? 2 : sizeof(input), &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else if (empty) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_MALFORMED);
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_DOCUMENT_EMPTY);
        } else {
            assert(doc != NULL);
            assert(status == XML3_STATUS_OK);
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "warning") == 0) {
        static const unsigned char input[] = {
            0xef, 0xbb, 0xbf, '<', '?', 'x', 'm', 'l', ' ',
            'v', 'e', 'r', 's', 'i', 'o', 'n', '=', '\'', '1', '.', '0',
            '\'', ' ', 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g', '=', '\'',
            'U', 'T', 'F', '-', '1', '6', '\'', '?', '>', '<', 'r', '/', '>'
        };
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory((const char *)input, sizeof(input), &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(doc != NULL);
            assert(status == XML3_STATUS_OK);
            error = xmlGetLastError();
            assert(error != NULL && error->code == 113);
            assert(error->level == XML_ERR_WARNING);
        }
    } else if (strcmp(operation, "copy") == 0 || strcmp(operation, "copy-empty") == 0) {
        xmlError source_before;
        xmlError destination_before;

        xml3_oom_disable();
        init_test_error(&source, "source");
        init_test_error(&copy, "destination");
        if (strcmp(operation, "copy-empty") == 0) {
            source.message[0] = source.file[0] = source.str1[0] = '\0';
            source.str2[0] = source.str3[0] = '\0';
        }
        source_before = source;
        destination_before = copy;
        xml3_oom_enable(fail_index);
        result = xmlCopyError(&source, &copy);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result != 0);
            require_oom_error();
            assert_error_unchanged(&source, &source_before);
            assert_error_unchanged(&copy, &destination_before);
        } else {
            assert(result == 0);
            assert_error_unchanged(&source, &source_before);
            assert_error_copy(&copy, &source);
        }
        xmlResetLastError();
        assert(xmlCopyError(&source, &copy) == 0);
        assert_error_copy(&copy, &source);
        xmlResetError(&copy);
        xmlResetError(&source);
    } else if (strcmp(operation, "replacement") == 0) {
        assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
        assert(xmlGetLastError() != NULL);
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory("<r><x></r>", 10, NULL, NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(doc == NULL);
        if (injected)
            require_oom_error();
        else {
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_TAG_NAME_MISMATCH);
        }
    } else if (strcmp(operation, "tls") == 0) {
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory("<r/>", 4, NULL, "latin1", 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(doc == NULL);
        if (injected)
            require_oom_error();
        else {
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_UNSUPPORTED_ENCODING);
        }
        if (injected) {
            error = require_oom_error();
            const char *emergency_message = error->message;
            assert(xmlCopyError(error, &copy) == 0);
            assert(copy.message != NULL);
            assert(copy.message != error->message);
            assert(copy.domain == XML_FROM_MEMORY);
            assert(copy.code == XML_ERR_NO_MEMORY);
            assert(copy.level == XML_ERR_FATAL);
            xmlResetError((xmlError *)(uintptr_t)error);
            assert(xmlGetLastError() == NULL);
            assert(strcmp(emergency_message, "out of memory\n") == 0);
            assert(strcmp(copy.message, "out of memory\n") == 0);
            xmlResetError(&copy);
            assert(strcmp(emergency_message, "out of memory\n") == 0);
        }
    } else if (strcmp(operation, "dom-new-doc") == 0 ||
               strcmp(operation, "dom-new-doc-version") == 0 ||
               strcmp(operation, "dom-new-doc-empty") == 0) {
        xmlChar version_text[] = "1.0";
        const xmlChar *version = strcmp(operation, "dom-new-doc") == 0 ? NULL
            : version_text + (strcmp(operation, "dom-new-doc-empty") == 0 ? 3 : 0);
        xml3_oom_enable(fail_index);
        doc = xmlNewDoc(version);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            require_oom_error();
            xmlResetLastError();
            doc = xmlNewDoc(version);
        }
        assert(doc != NULL && doc->version != NULL);
        assert(strcmp((const char *)doc->version, version ? (const char *)version : "1.0") == 0);
        assert(strcmp((const char *)version_text, "1.0") == 0);
        xmlFreeDoc(doc);
        doc = NULL;
        assert(xmlGetLastError() == NULL);
    } else if (strcmp(operation, "dom-new-node") == 0) {
        xml3_oom_enable(fail_index);
        dom_node = xmlNewNode(NULL, BAD_CAST "new-node");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            require_oom_error();
        } else {
            assert(dom_node != NULL);
            xmlFreeNode(dom_node);
            dom_node = NULL;
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "dom-new-doc-text") == 0 ||
               strcmp(operation, "dom-new-doc-text-len") == 0 ||
               strcmp(operation, "string-node-list") == 0 ||
               strcmp(operation, "string-node-list-len") == 0 ||
               strcmp(operation, "dom-new-doc-comment") == 0 ||
               strcmp(operation, "dom-new-doc-pi") == 0 ||
               strcmp(operation, "dom-new-doc-pi-empty") == 0 ||
               strcmp(operation, "dom-new-cdata") == 0) {
        int bounded = strcmp(operation, "dom-new-doc-text-len") == 0;
        int list = strcmp(operation, "string-node-list") == 0;
        int list_len = strcmp(operation, "string-node-list-len") == 0;
        int comment = strcmp(operation, "dom-new-doc-comment") == 0;
        int empty_pi = strcmp(operation, "dom-new-doc-pi-empty") == 0;
        int pi = strcmp(operation, "dom-new-doc-pi") == 0 || empty_pi;
        const xmlChar *pi_name = empty_pi ? BAD_CAST "" : BAD_CAST "target";
        int cdata = strcmp(operation, "dom-new-cdata") == 0;
        static const xmlChar input[] = {'t', 'e', 'x', 't'};
        xmlDocPtr owner_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        assert(owner_doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(owner_doc, root) == NULL);
        xml3_oom_enable(fail_index);
        dom_node = bounded ? xmlNewDocTextLen(owner_doc, input, 4)
            : list ? xmlStringGetNodeList(owner_doc, BAD_CAST "te&#120;t")
            : list_len ? xmlStringLenGetNodeList(owner_doc, BAD_CAST "te&#120;tX", 9)
            : cdata ? xmlNewCDataBlock(owner_doc, input, 4)
            : comment ? xmlNewDocComment(owner_doc, BAD_CAST "text")
            : pi ? xmlNewDocPI(owner_doc, pi_name, BAD_CAST "text")
            : xmlNewDocText(owner_doc, BAD_CAST "text");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(owner_doc->children == root && owner_doc->last == root);
        assert(root->parent == (xmlNodePtr)owner_doc && root->children == NULL);
        if (injected) {
            assert(dom_node == NULL);
            require_oom_error();
            dom_node = bounded ? xmlNewDocTextLen(owner_doc, input, 4)
                : list ? xmlStringGetNodeList(owner_doc, BAD_CAST "te&#120;t")
                : list_len ? xmlStringLenGetNodeList(owner_doc, BAD_CAST "te&#120;tX", 9)
                : cdata ? xmlNewCDataBlock(owner_doc, input, 4)
                : comment ? xmlNewDocComment(owner_doc, BAD_CAST "text")
                : pi ? xmlNewDocPI(owner_doc, pi_name, BAD_CAST "text")
                : xmlNewDocText(owner_doc, BAD_CAST "text");
        }
        assert(dom_node != NULL && dom_node->doc == owner_doc);
        assert(dom_node->parent == NULL);
        xmlFreeDoc(owner_doc);
        if (pi) assert(strcmp((const char *)dom_node->name, (const char *)pi_name) == 0);
        if (cdata) assert(dom_node->name == NULL);
        assert(strcmp((const char *)dom_node->content, "text") == 0);
        assert(xmlNodeAddContent(dom_node, BAD_CAST "!") == 0);
        assert(strcmp((const char *)dom_node->content, "text!") == 0);
        xmlFreeNode(dom_node);
        dom_node = NULL;
    } else if (strcmp(operation, "dom-new-text-len") == 0) {
        static const xmlChar input[] = {'t', 'e', 'x', 't'};
        xml3_oom_enable(fail_index);
        dom_node = xmlNewTextLen(input, 4);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            require_oom_error();
            dom_node = xmlNewTextLen(input, 4);
        }
        assert(dom_node != NULL && dom_node->content != NULL);
        assert(strcmp((const char *)dom_node->content, "text") == 0);
        xmlFreeNode(dom_node);
        dom_node = NULL;
    } else if (strcmp(operation, "dom-new-text") == 0 ||
               strcmp(operation, "dom-new-comment") == 0 ||
               strcmp(operation, "dom-new-pi") == 0 ||
               strcmp(operation, "dom-new-pi-empty") == 0) {
        int empty_pi = strcmp(operation, "dom-new-pi-empty") == 0;
        int pi = strcmp(operation, "dom-new-pi") == 0 || empty_pi;
        const xmlChar *pi_name = empty_pi ? BAD_CAST "" : BAD_CAST "target";
        xml3_oom_enable(fail_index);
        dom_node = strcmp(operation, "dom-new-comment") == 0
            ? xmlNewComment(BAD_CAST "text")
            : pi ? xmlNewPI(pi_name, BAD_CAST "text")
                : xmlNewText(BAD_CAST "text");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            require_oom_error();
            dom_node = strcmp(operation, "dom-new-comment") == 0
                ? xmlNewComment(BAD_CAST "text")
                : pi ? xmlNewPI(pi_name, BAD_CAST "text")
                    : xmlNewText(BAD_CAST "text");
        } else {
            assert(xmlGetLastError() == NULL);
        }
        assert(dom_node != NULL);
        if (pi) assert(strcmp((const char *)dom_node->name, (const char *)pi_name) == 0);
        assert(strcmp((const char *)dom_node->content, "text") == 0);
        xmlFreeNode(dom_node);
        dom_node = NULL;
    } else if (strcmp(operation, "dom-text-merge") == 0) {
        static const char input[] = "<r>left<!--gap-->right<x/></r>";
        xmlNodePtr root, first, second, gap, last, merged;
        xmlChar *first_content, *second_content;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        first = root->children;
        gap = first->next;
        second = gap->next;
        last = root->last;
        first_content = first->content;
        second_content = second->content;
        xml3_oom_enable(fail_index);
        merged = xmlTextMerge(first, second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(merged == NULL);
            assert(root->children == first && root->last == last);
            assert(first->parent == root && second->parent == root);
            assert(first->next == gap && gap->prev == first);
            assert(gap->next == second && second->prev == gap);
            assert(second->next == last && last->prev == second);
            assert(first->content == first_content && second->content == second_content);
            assert(strcmp((const char *)first->content, "left") == 0);
            assert(strcmp((const char *)second->content, "right") == 0);
            require_oom_error();
            xmlResetLastError();
            merged = xmlTextMerge(first, second);
        }
        assert(merged == first && first->parent == root && first->doc == doc);
        assert(root->children == first && root->last == last);
        assert(first->next == gap && gap->next == last && last->prev == gap);
        assert(strcmp((const char *)first->content, "leftright") == 0);
        assert(xmlGetLastError() == NULL);
    } else if (strcmp(operation, "dom-merge") == 0 ||
               strcmp(operation, "dom-sibling") == 0) {
        xmlNodePtr root;
        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        merge_left = xmlNewText(BAD_CAST "left");
        merge_right = xmlNewText(BAD_CAST "right");
        assert(doc != NULL && root != NULL && merge_left != NULL &&
               merge_right != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, merge_left) == merge_left);
        xml3_oom_enable(fail_index);
        dom_node = strcmp(operation, "dom-sibling") == 0
            ? xmlAddSibling(merge_left, merge_right)
            : xmlAddChild(root, merge_right);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            assert(root->children == merge_left && root->last == merge_left);
            assert(merge_left->parent == root && merge_left->next == NULL);
            assert(merge_right->parent == NULL && merge_right->prev == NULL &&
                   merge_right->next == NULL);
            assert(strcmp((const char *)merge_left->content, "left") == 0);
            assert(strcmp((const char *)merge_right->content, "right") == 0);
            require_oom_error();
            if (strcmp(operation, "dom-sibling") == 0) {
                xmlResetLastError();
                assert(xmlAddSibling(merge_left, merge_right) == merge_left);
                assert(strcmp((const char *)merge_left->content, "leftright") == 0);
                merge_right = NULL;
            }
        } else {
            assert(dom_node == merge_left);
            assert(root->children == merge_left && root->last == merge_left);
            assert(strcmp((const char *)merge_left->content, "leftright") == 0);
            merge_right = NULL;
        }
    } else if (strcmp(operation, "attr-new") == 0 ||
               strcmp(operation, "attr-new-empty") == 0) {
        const char *value = strcmp(operation, "attr-new-empty") == 0 ? "" : "value";
        xmlNodePtr root;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        before = xmlNewProp(root, BAD_CAST "before", BAD_CAST "left");
        after = xmlNewProp(root, BAD_CAST "after", BAD_CAST "right");
        assert(before != NULL && after != NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlNewProp(root, BAD_CAST "middle", BAD_CAST value);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == before);
            assert(before->next == after && after->prev == before);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->children->content, value) == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "attr-detached") == 0 ||
               strcmp(operation, "attr-detached-null") == 0) {
        const xmlChar *value = strcmp(operation, "attr-detached-null") == 0
            ? NULL : BAD_CAST "value";
        xmlAttrPtr created;

        xml3_oom_enable(fail_index);
        created = xmlNewProp(NULL, BAD_CAST "standalone", value);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            require_oom_error();
        } else {
            assert(created != NULL && created->parent == NULL &&
                   created->doc == NULL);
            assert((created->children != NULL) == (value != NULL));
            if (value)
                assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "attr-set-new") == 0) {
        xmlNodePtr root;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        before = xmlNewProp(root, BAD_CAST "before", BAD_CAST "left");
        after = xmlNewProp(root, BAD_CAST "after", BAD_CAST "right");
        assert(before != NULL && after != NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlSetProp(root, BAD_CAST "added", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == before);
            assert(before->next == after && after->prev == before);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "attr-set") == 0) {
        static const char input[] =
            "<root before='left' target='old' after='right'/>";
        xmlNodePtr root;
        xmlAttrPtr before, target, after, result_attr;
        xmlNodePtr old_children;
        xmlChar *old_content;
        int private_marker;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        before = root->properties;
        assert(before != NULL);
        target = before->next;
        assert(target != NULL);
        after = target->next;
        assert(after != NULL);
        old_children = target->children;
        old_content = old_children->content;
        target->_private = &private_marker;
        xml3_oom_enable(fail_index);
        result_attr = xmlSetProp(root, BAD_CAST "target", BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result_attr == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == target && target->prev == before);
            assert(target->next == after && after->prev == target);
            assert(after->next == NULL && target->_private == &private_marker);
            assert(target->children == old_children);
            assert(old_children->content == old_content);
            assert(strcmp((const char *)old_content, "old") == 0);
            require_oom_error();
        } else {
            assert(result_attr == target);
            assert(root->properties == before && before->next == target);
            assert(target->prev == before && target->next == after);
            assert(after->prev == target && after->next == NULL);
            assert(target->_private == &private_marker);
            assert(target->children != old_children);
            assert(strcmp((const char *)target->children->content,
                          "replacement") == 0);
        }
    } else if (strcmp(operation, "ns-new") == 0) {
        xmlNodePtr root;
        xmlNsPtr first, second, created;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        first = xmlNewNs(root, BAD_CAST "urn:first", BAD_CAST "p");
        second = xmlNewNs(root, BAD_CAST "urn:second", BAD_CAST "q");
        assert(first != NULL && second != NULL);
        xml3_oom_enable(fail_index);
        created = xmlNewNs(root, BAD_CAST "urn:third", BAD_CAST "r");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->nsDef == first && first->next == second);
            assert(second->next == NULL);
            assert(strcmp((const char *)first->href, "urn:first") == 0);
            assert(strcmp((const char *)second->href, "urn:second") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->nsDef == first);
            assert(first->next == second && second->next == created);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->href, "urn:third") == 0);
            assert(strcmp((const char *)created->prefix, "r") == 0);
        }
    } else if (strcmp(operation, "ns-detached") == 0) {
        xmlNsPtr created;

        xml3_oom_enable(fail_index);
        created = xmlNewNs(NULL, BAD_CAST "urn:detached", BAD_CAST "d");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            require_oom_error();
        } else {
            assert(created != NULL && created->context == NULL);
            assert(strcmp((const char *)created->href, "urn:detached") == 0);
            assert(strcmp((const char *)created->prefix, "d") == 0);
            xmlFreeNs(created);
        }
    } else if (strcmp(operation, "ns-prop-new") == 0) {
        xmlNodePtr root;
        xmlNsPtr ns;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        ns = xmlNewNs(root, BAD_CAST "urn:qualified", BAD_CAST "p");
        before = xmlNewProp(root, BAD_CAST "before", BAD_CAST "left");
        after = xmlNewProp(root, BAD_CAST "after", BAD_CAST "right");
        assert(ns != NULL && before != NULL && after != NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlNewNsProp(root, ns, BAD_CAST "middle", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(root->nsDef == ns && ns->next == NULL);
            assert(strcmp((const char *)ns->href, "urn:qualified") == 0);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == before);
            assert(before->next == after && after->prev == before);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL && created->ns == ns);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "ns-prop-set") == 0) {
        static const char input[] =
            "<root xmlns:p='urn:same' xmlns:q='urn:same' "
            "before='left' p:a='old' after='right'/>";
        xmlNodePtr root;
        xmlNsPtr old_ns, alias;
        xmlAttrPtr before, target, after, result_attr;
        xmlNodePtr old_children;
        xmlChar *old_content;
        int private_marker;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        old_ns = root->nsDef;
        assert(old_ns != NULL);
        alias = old_ns->next;
        before = root->properties;
        assert(before != NULL);
        target = before->next;
        assert(target != NULL);
        after = target->next;
        assert(after != NULL);
        assert(alias != NULL && alias != old_ns);
        assert(target->ns == old_ns && target->children != NULL);
        old_children = target->children;
        old_content = old_children->content;
        target->_private = &private_marker;
        xml3_oom_enable(fail_index);
        result_attr = xmlSetNsProp(root, alias, BAD_CAST "a",
                                   BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result_attr == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == target && target->prev == before);
            assert(target->next == after && after->prev == target);
            assert(after->next == NULL && target->ns == old_ns);
            assert(target->_private == &private_marker);
            assert(target->children == old_children);
            assert(old_children->content == old_content);
            assert(strcmp((const char *)old_content, "old") == 0);
            require_oom_error();
        } else {
            assert(result_attr == target && target->ns == alias);
            assert(root->properties == before && before->next == target);
            assert(target->prev == before && target->next == after);
            assert(after->prev == target && after->next == NULL);
            assert(target->_private == &private_marker);
            assert(target->children != old_children);
            assert(strcmp((const char *)target->children->content,
                          "replacement") == 0);
        }
    } else if (strcmp(operation, "ns-qname-set") == 0) {
        static const char input[] =
            "<root xmlns:p='urn:qualified' before='left' after='right'/>";
        xmlNodePtr root;
        xmlNsPtr ns;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        ns = root->nsDef;
        before = root->properties;
        assert(ns != NULL && before != NULL);
        after = before->next;
        assert(after != NULL && after->next == NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlSetProp(root, BAD_CAST "p:created", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->nsDef == ns && ns->next == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            assert(strcmp((const char *)ns->href, "urn:qualified") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && created->ns == ns);
            assert(root->properties == before && before->next == after);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "ns-xml-qname") == 0) {
        xmlNodePtr root;
        xmlNsPtr ns;
        xmlAttrPtr created;

        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(root != NULL && root->doc == NULL);
        xml3_oom_enable(fail_index);
        created = xmlSetProp(root, BAD_CAST "xml:lang", BAD_CAST "ja");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL && root->properties == NULL);
            assert(root->nsDef == NULL);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == created);
            ns = root->nsDef;
            assert(ns != NULL && created->ns == ns);
            assert(xmlSearchNs(NULL, root, BAD_CAST "xml") == ns);
            assert(strcmp((const char *)created->children->content, "ja") == 0);
        }
        xmlFreeNode(root);
    } else if (strcmp(operation, "dom-get-lang") == 0) {
        static const char input[] = "<r xml:lang='old'/>";
        xmlDocPtr query_doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        xmlNodePtr root;
        xmlChar *value;
        assert(query_doc);
        root = xmlDocGetRootElement(query_doc);
        xml3_oom_enable(fail_index);
        value = xmlNodeGetLang(root);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(value == NULL);
            require_oom_error();
            xmlResetLastError();
            value = xmlNodeGetLang(root);
        }
        assert(value && strcmp((const char *)value, "old") == 0);
        xmlFree(value);
        xmlFreeDoc(query_doc);
    } else if (strcmp(operation, "dom-get-space") == 0) {
        static const char input[] = "<r xml:space='preserve'><c/></r>";
        xmlDocPtr query_doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        xmlNodePtr root, child;
        xmlNsPtr xml_ns;
        xmlAttrPtr root_attr, child_attr;
        xmlChar *root_content, *child_content;
        assert(query_doc);
        root = xmlDocGetRootElement(query_doc);
        child = root->children;
        xml_ns = xmlSearchNsByHref(query_doc, child, XML_XML_NAMESPACE);
        assert(xml_ns);
        root_attr = xmlHasNsProp(root, BAD_CAST "space", XML_XML_NAMESPACE);
        child_attr = xmlSetNsProp(child, xml_ns, BAD_CAST "space", BAD_CAST "unknown");
        assert(root_attr && child_attr);
        root_content = root_attr->children->content;
        child_content = child_attr->children->content;
        xml3_oom_enable(fail_index);
        result = xmlNodeGetSpacePreserve(child);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->properties == root_attr && child->properties == child_attr);
            assert(root_attr->children->content == root_content);
            assert(child_attr->children->content == child_content);
            assert(strcmp((const char *)root_content, "preserve") == 0);
            assert(strcmp((const char *)child_content, "unknown") == 0);
            require_oom_error();
            xmlResetLastError();
            result = xmlNodeGetSpacePreserve(child);
        }
        assert(result == 1);
        xmlFreeDoc(query_doc);
    } else if (strcmp(operation, "dom-set-lang-new") == 0) {
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        assert(root && root->nsDef == NULL && root->properties == NULL);
        xml3_oom_enable(fail_index);
        result = xmlNodeSetLang(root, BAD_CAST "new");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->nsDef == NULL && root->properties == NULL);
            require_oom_error();
            xmlResetLastError();
            result = xmlNodeSetLang(root, BAD_CAST "new");
        }
        assert(result == 0);
        assert(root->nsDef != NULL && root->properties != NULL);
        assert(strcmp((const char *)root->properties->children->content, "new") == 0);
        xmlFreeNode(root);
    } else if (strcmp(operation, "dom-set-space-new") == 0) {
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        assert(root && root->nsDef == NULL && root->properties == NULL);
        xml3_oom_enable(fail_index);
        result = xmlNodeSetSpacePreserve(root, 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->nsDef == NULL && root->properties == NULL);
            require_oom_error();
            xmlResetLastError();
            result = xmlNodeSetSpacePreserve(root, 1);
        }
        assert(result == 0);
        assert(root->nsDef != NULL && root->properties != NULL);
        assert(strcmp((const char *)root->properties->children->content,
                      "preserve") == 0);
        xmlFreeNode(root);
    } else if (strcmp(operation, "dom-set-lang-update") == 0) {
        static const char input[] = "<r xml:lang='old'/>";
        xmlDocPtr query_doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        xmlNodePtr root;
        xmlNsPtr original_ns, original_nsdef;
        xmlAttrPtr original_attr;
        xmlChar *original_content;
        assert(query_doc);
        root = xmlDocGetRootElement(query_doc);
        original_attr = root->properties;
        original_ns = original_attr->ns;
        original_nsdef = root->nsDef;
        original_content = original_attr->children->content;
        xml3_oom_enable(fail_index);
        result = xmlNodeSetLang(root, BAD_CAST "new");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->properties == original_attr && original_attr->ns == original_ns);
            assert(root->nsDef == original_nsdef);
            assert(original_attr->children->content == original_content);
            assert(strcmp((const char *)original_content, "old") == 0);
            require_oom_error();
            xmlResetLastError();
            result = xmlNodeSetLang(root, BAD_CAST "new");
        }
        assert(result == 0);
        assert(root->properties == original_attr && original_attr->ns == original_ns);
        assert(strcmp((const char *)original_attr->children->content, "new") == 0);
        xmlFreeDoc(query_doc);
    } else if (strcmp(operation, "dom-content-replace") == 0 ||
               strcmp(operation, "dom-content-append-len") == 0 ||
               strcmp(operation, "dom-text-concat") == 0) {
        int concat = strcmp(operation, "dom-text-concat") == 0;
        int bounded = concat || strcmp(operation, "dom-content-append-len") == 0;
        int (*append)(xmlNodePtr, const xmlChar *, int) =
            concat ? xmlTextConcat : xmlNodeAddContentLen;
        xmlNodePtr text = xmlNewText(BAD_CAST "old");
        xmlChar *original_content;
        assert(text != NULL);
        original_content = text->content;
        xml3_oom_enable(fail_index);
        result = bounded
            ? append(text, BAD_CAST "-new-ignored", 4)
            : xmlNodeAddContent(text, BAD_CAST "-new");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(text->content == original_content);
            assert(strcmp((const char *)text->content, "old") == 0);
            require_oom_error();
            assert((bounded
                ? append(text, BAD_CAST "-new-ignored", 4)
                : xmlNodeAddContent(text, BAD_CAST "-new")) == 0);
            assert(strcmp((const char *)text->content, "old-new") == 0);
        } else {
            assert(result == 0);
            assert(strcmp((const char *)text->content, "old-new") == 0);
        }
        xmlFreeNode(text);
    } else if (strcmp(operation, "dom-content-child") == 0 ||
               strcmp(operation, "dom-content-child-len") == 0 ||
               strcmp(operation, "dom-content-child-len-empty") == 0) {
        int bounded = strcmp(operation, "dom-content-child") != 0;
        int empty = strcmp(operation, "dom-content-child-len-empty") == 0;
        const char *input = empty ? "" : "after-ignored";
        const char *expected = empty ? "" : "after";
        int length = empty ? 1 : 5;
        xmlDocPtr content_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr comment = xmlNewComment(BAD_CAST "before");
        xmlChar *original_comment_content;
        assert(content_doc != NULL && root != NULL && comment != NULL);
        original_comment_content = comment->content;
        assert(xmlDocSetRootElement(content_doc, root) == NULL);
        assert(xmlAddChild(root, comment) == comment);
        xml3_oom_enable(fail_index);
        result = bounded
            ? xmlNodeAddContentLen(root, BAD_CAST input, length)
            : xmlNodeAddContent(root, BAD_CAST "after");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->children == comment && root->last == comment);
            assert(comment->parent == root && comment->next == NULL);
            assert(comment->content == original_comment_content);
            assert(strcmp((const char *)comment->content, "before") == 0);
            require_oom_error();
            assert((bounded
                ? xmlNodeAddContentLen(root, BAD_CAST input, length)
                : xmlNodeAddContent(root, BAD_CAST "after")) == 0);
            assert(root->children == comment && root->last != comment);
            assert(comment->next == root->last && comment->next->prev == comment);
            assert(root->last->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->last->content, expected) == 0);
        } else {
            assert(result == 0);
            assert(root->children == comment && root->last != comment);
            assert(comment->next == root->last);
            assert(root->last->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->last->content, expected) == 0);
        }
        xmlFreeDoc(content_doc);
    } else if (strcmp(operation, "dom-new-doc-prop") == 0) {
        xmlDocPtr property_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlAttrPtr attr;
        assert(property_doc && root);
        assert(xmlDocSetRootElement(property_doc, root) == NULL);
        xml3_oom_enable(fail_index);
        attr = xmlNewDocProp(property_doc, BAD_CAST "a", BAD_CAST "new&amp;value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(xmlDocGetRootElement(property_doc) == root && root->properties == NULL);
        if (injected) {
            assert(attr == NULL);
            require_oom_error();
            attr = xmlNewDocProp(property_doc, BAD_CAST "a", BAD_CAST "new&amp;value");
        }
        assert(attr && attr->doc == property_doc && attr->parent == NULL);
        assert(attr->children && attr->children->doc == property_doc);
        assert(strcmp((const char *)attr->children->content, "new&value") == 0);
        xmlFreeDoc(property_doc);
        assert(strcmp((const char *)attr->children->content, "new&value") == 0);
        xmlFreeProp(attr);
    } else if (strcmp(operation, "dom-new-child") == 0 ||
               strcmp(operation, "dom-new-text-child") == 0 ||
               strcmp(operation, "dom-new-doc-node") == 0 ||
               strcmp(operation, "dom-new-doc-raw-node") == 0) {
        int raw = strcmp(operation, "dom-new-text-child") == 0 ||
                  strcmp(operation, "dom-new-doc-raw-node") == 0;
        int affiliated = strcmp(operation, "dom-new-doc-node") == 0 ||
                         strcmp(operation, "dom-new-doc-raw-node") == 0;
        xmlNodePtr (*construct_child)(xmlNodePtr, xmlNsPtr, const xmlChar *,
                                      const xmlChar *) = raw ? xmlNewTextChild : xmlNewChild;
        xmlNodePtr (*construct_doc)(xmlDocPtr, xmlNsPtr, const xmlChar *,
                                    const xmlChar *) = raw ? xmlNewDocRawNode : xmlNewDocNode;
        xmlDocPtr content_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr old = xmlNewComment(BAD_CAST "before");
        xmlNodePtr child;
        xmlNsPtr ns;
        assert(content_doc != NULL && root != NULL && old != NULL);
        assert(xmlDocSetRootElement(content_doc, root) == NULL);
        assert(xmlAddChild(root, old) == old);
        ns = xmlNewNs(root, BAD_CAST "urn:parent", BAD_CAST "p");
        assert(ns != NULL);
        xmlSetNs(root, ns);
        xml3_oom_enable(fail_index);
        child = affiliated
            ? construct_doc(content_doc, ns, BAD_CAST "child", BAD_CAST "new&amp;text")
            : construct_child(root, NULL, BAD_CAST "child", BAD_CAST "new&amp;text");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(child == NULL);
            assert(root->children == old && root->last == old && root->ns == ns);
            assert(old->parent == root && old->next == NULL && old->prev == NULL);
            assert(strcmp((const char *)ns->href, "urn:parent") == 0);
            require_oom_error();
            child = affiliated
                ? construct_doc(content_doc, ns, BAD_CAST "child", BAD_CAST "new&amp;text")
                : construct_child(root, NULL, BAD_CAST "child", BAD_CAST "new&amp;text");
        }
        assert(child != NULL && child->doc == content_doc && child->ns == ns);
        if (affiliated) {
            assert(child->parent == NULL && child->prev == NULL && child->next == NULL);
            assert(root->children == old && root->last == old && old->next == NULL);
        } else {
            assert(child->parent == root && root->last == child && child->prev == old);
            assert(root->children == old && old->next == child && child->next == NULL);
        }
        assert(child->children != NULL && child->children->doc == content_doc);
        assert(strcmp((const char *)child->children->content,
                      raw ? "new&amp;text" : "new&text") == 0);
        xmlFreeDoc(content_doc);
        if (affiliated) {
            assert(strcmp((const char *)ns->href, "urn:parent") == 0);
            assert(strcmp((const char *)child->children->content,
                          raw ? "new&amp;text" : "new&text") == 0);
            xmlFreeNode(child);
        }
    } else if (strcmp(operation, "dom-content-set-scalar") == 0 ||
               strcmp(operation, "dom-content-set-len") == 0) {
        int bounded = strcmp(operation, "dom-content-set-len") == 0;
        xmlNodePtr text = xmlNewText(BAD_CAST "old");
        xmlChar *original_content;
        assert(text != NULL);
        original_content = text->content;
        xml3_oom_enable(fail_index);
        result = bounded
            ? xmlNodeSetContentLen(text, BAD_CAST "replacement-ignored", 11)
            : xmlNodeSetContent(text, BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(text->content == original_content);
            assert(strcmp((const char *)text->content, "old") == 0);
            require_oom_error();
            assert((bounded
                ? xmlNodeSetContentLen(text, BAD_CAST "replacement-ignored", 11)
                : xmlNodeSetContent(text, BAD_CAST "replacement")) == 0);
            assert(strcmp((const char *)text->content, "replacement") == 0);
        } else {
            assert(result == 0);
            assert(strcmp((const char *)text->content, "replacement") == 0);
        }
        xmlFreeNode(text);
    } else if (strcmp(operation, "dom-content-set-tree") == 0 ||
               strcmp(operation, "dom-content-set-tree-len") == 0) {
        int bounded = strcmp(operation, "dom-content-set-tree-len") == 0;
        xmlDocPtr content_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr child = xmlNewNode(NULL, BAD_CAST "old");
        xmlNodePtr nested = xmlNewNode(NULL, BAD_CAST "nested");
        xmlNodePtr tail = xmlNewComment(BAD_CAST "tail");
        xmlNodePtr borrower = xmlNewNode(NULL, BAD_CAST "borrower");
        xmlNsPtr ns;
        assert(content_doc != NULL && root != NULL && child != NULL &&
               nested != NULL && tail != NULL && borrower != NULL);
        assert(xmlDocSetRootElement(content_doc, root) == NULL);
        assert(xmlAddChild(child, nested) == nested);
        assert(xmlAddChild(root, child) == child);
        assert(xmlAddChild(root, tail) == tail);
        ns = xmlNewNs(child, BAD_CAST "urn:retired", BAD_CAST "p");
        assert(ns != NULL);
        xmlSetNs(borrower, ns);
        assert(borrower->ns == ns);
        xml3_oom_enable(fail_index);
        result = bounded
            ? xmlNodeSetContentLen(root, BAD_CAST "replacement-ignored", 11)
            : xmlNodeSetContent(root, BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->children == child && root->last == tail);
            assert(child->parent == root && child->next == tail);
            assert(tail->parent == root && tail->prev == child);
            assert(child->children == nested && nested->parent == child);
            assert(child->nsDef == ns && borrower->ns == ns);
            assert(strcmp((const char *)ns->href, "urn:retired") == 0);
            require_oom_error();
            assert((bounded
                ? xmlNodeSetContentLen(root, BAD_CAST "replacement-ignored", 11)
                : xmlNodeSetContent(root, BAD_CAST "replacement")) == 0);
            assert(root->children == root->last);
            assert(root->children->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->children->content,
                          "replacement") == 0);
        } else {
            assert(result == 0);
            assert(root->children == root->last);
            assert(root->children->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->children->content,
                          "replacement") == 0);
        }
        assert(borrower->ns == ns);
        assert(strcmp((const char *)ns->href, "urn:retired") == 0);
        xmlFreeDoc(content_doc);
        assert(borrower->ns == ns);
        assert(strcmp((const char *)ns->href, "urn:retired") == 0);
        xmlFreeNode(borrower);
    } else if (strcmp(operation, "escape-special") == 0 ||
               strcmp(operation, "escape-special-empty") == 0 ||
               strcmp(operation, "escape-entities") == 0 ||
               strcmp(operation, "escape-entities-empty") == 0) {
        int entities = strcmp(operation, "escape-entities") == 0 ||
            strcmp(operation, "escape-entities-empty") == 0;
        int empty = strcmp(operation, "escape-special-empty") == 0 ||
            strcmp(operation, "escape-entities-empty") == 0;
        xmlChar input[] = "<&>\"\r名";
        const xmlChar *source = empty ? BAD_CAST "" : input;
        const char *expected = empty ? "" : entities
            ? "&lt;&amp;&gt;\"&#13;&#x540D;" : "&lt;&amp;&gt;&quot;&#13;名";
        if (entities) {
            doc = xmlNewDoc(NULL);
            assert(doc && xmlDocGetRootElement(doc) == NULL);
        }
        xml3_oom_enable(fail_index);
        xmlChar *escaped = entities ? xmlEncodeEntitiesReentrant(doc, source)
            : xmlEncodeSpecialChars(NULL, source);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(strcmp((const char *)input, "<&>\"\r名") == 0);
        if (injected) {
            assert(escaped == NULL);
            require_oom_error();
            escaped = entities ? xmlEncodeEntitiesReentrant(doc, source)
                : xmlEncodeSpecialChars(NULL, source);
        }
        assert(escaped && strcmp((const char *)escaped, expected) == 0);
        if (entities) assert(xmlDocGetRootElement(doc) == NULL);
        xmlFree(escaped);
    } else if (strcmp(operation, "serialization-formatted") == 0 ||
               strcmp(operation, "serialization-formatted-utf8") == 0) {
        int explicit_encoding = strcmp(operation, "serialization-formatted-utf8") == 0;
        const char *input = "<r a='名'><child>é</child><empty/></r>";
        const char *expected = explicit_encoding
            ? "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
              "<r a=\"名\">\n  <child>é</child>\n  <empty/>\n</r>\n"
            : "<?xml version=\"1.0\"?>\n"
              "<r a=\"&#x540D;\">\n  <child>&#xE9;</child>\n  <empty/>\n</r>\n";
        xmlChar *memory = (xmlChar *)1;
        int size = 99;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        xmlNodePtr root = xmlDocGetRootElement(doc);
        xmlNodePtr child = root->children;
        xml3_oom_enable(fail_index);
        if (explicit_encoding)
            xmlDocDumpFormatMemoryEnc(doc, &memory, &size, "UTF-8", 1);
        else xmlDocDumpFormatMemory(doc, &memory, &size, 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(memory == NULL && size == 0);
            require_oom_error();
            if (explicit_encoding)
                xmlDocDumpFormatMemoryEnc(doc, &memory, &size, "UTF-8", 1);
            else xmlDocDumpFormatMemory(doc, &memory, &size, 1);
        }
        assert(memory && size == (int)strlen(expected));
        assert(strcmp((const char *)memory, expected) == 0);
        xmlFree(memory);
        assert(root->children == child && child->next == root->last);
        assert(strcmp((const char *)root->properties->children->content, "名") == 0);
        assert(strcmp((const char *)child->children->content, "é") == 0);
    } else if (strcmp(operation, "serialization") == 0 ||
               strcmp(operation, "serialization-default") == 0 ||
               strcmp(operation, "serialization-null-encoding") == 0) {
        int wrapper = strcmp(operation, "serialization-default") == 0;
        int implicit = strcmp(operation, "serialization") != 0;
        const char *encoding = implicit ? NULL : "UTF-8";
        const char *input = implicit ? "<r a='名'>é</r>" : "<r a='v'>text</r>";
        xmlNodePtr root;
        xmlChar *memory = (xmlChar *)1;
        int size = 77;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        assert(root != NULL && root->properties != NULL);
        xml3_oom_enable(fail_index);
        if (wrapper) xmlDocDumpMemory(doc, &memory, &size);
        else xmlDocDumpMemoryEnc(doc, &memory, &size, encoding);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(memory == NULL && size == 0);
            require_oom_error();
            if (wrapper) xmlDocDumpMemory(doc, &memory, &size);
            else xmlDocDumpMemoryEnc(doc, &memory, &size, encoding);
        }
        assert(memory != NULL && size > 0 && memory[size] == 0);
        if (implicit) assert(strcmp((const char *)memory,
            "<?xml version=\"1.0\"?>\n<r a=\"&#x540D;\">&#xE9;</r>\n") == 0);
        xmlFree(memory);
        assert(strcmp((const char *)root->properties->children->content,
                      implicit ? "名" : "v") == 0);
        assert(strcmp((const char *)root->children->content,
                      implicit ? "é" : "text") == 0);
    } else if (strcmp(operation, "node-list-raw") == 0 ||
               strcmp(operation, "node-list-escaped") == 0 ||
               strcmp(operation, "node-list-entities") == 0 ||
               strcmp(operation, "node-list-entities-attr") == 0 ||
               strcmp(operation, "node-list-raw-empty") == 0) {
        int attr_mode = strcmp(operation, "node-list-entities-attr") == 0;
        int entities = attr_mode || strcmp(operation, "node-list-entities") == 0;
        int escape = strcmp(operation, "node-list-escaped") == 0;
        int empty = strcmp(operation, "node-list-raw-empty") == 0;
        const char *input = empty ? "<r><e>skip</e></r>"
            : attr_mode ? "<r a='&#xE9;&#9;&quot;'>child</r>"
            : entities ? "<r>é&amp;<![CDATA[b<]]><e>skip</e>c</r>"
            : "<r>a&amp;<![CDATA[b<]]><e>skip</e>c</r>";
        xmlNodePtr root, parent, first, last;
        xmlChar *value;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        parent = attr_mode ? (xmlNodePtr)root->properties : root;
        assert(parent);
        first = parent->children;
        last = parent->last;
        assert(first);
        xml3_oom_enable(fail_index);
        value = entities ? xmlNodeListGetString(doc, first, 0)
            : xmlNodeListGetRawString(doc, first, !escape);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(value == NULL);
            require_oom_error();
            value = entities ? xmlNodeListGetString(doc, first, 0)
                : xmlNodeListGetRawString(doc, first, !escape);
        }
        assert(value);
        assert(strcmp((const char *)value,
                      empty ? "" : attr_mode ? "&#xE9;&#9;&quot;"
                      : entities ? "&#xE9;&amp;b&lt;c"
                      : escape ? "a&amp;b&lt;c" : "a&b<c") == 0);
        assert(parent->children == first && parent->last == last);
        assert(first->parent == parent && last->parent == parent);
        xmlFree(value);
    } else if (strcmp(operation, "node-path") == 0) {
        xmlNodePtr root;
        xmlNodePtr first;
        xmlNodePtr second;
        xmlNsPtr ns;
        xmlChar *path;

        doc = xmlNewDoc(BAD_CAST "1.0");
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        ns = xmlNewNs(root, BAD_CAST "urn:test", BAD_CAST "p");
        first = xmlNewChild(root, ns, BAD_CAST "item", NULL);
        second = xmlNewChild(root, ns, BAD_CAST "item", NULL);
        assert(ns != NULL && first != NULL && second != NULL);
        xml3_oom_enable(fail_index);
        path = xmlGetNodePath(second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(path == NULL);
            require_oom_error();
            path = xmlGetNodePath(second);
        }
        assert(path != NULL);
        assert(strcmp((const char *)path, "/root/p:item[2]") == 0);
        xmlFree(path);
        assert(root->children == first && first->next == second);
        assert(first->ns == ns && second->ns == ns);
    } else if (strcmp(operation, "node-set-name") == 0) {
        static const char input[] = "<root xmlns:p='urn:name'><p:old>value</p:old></root>";
        xmlNodePtr root;
        xmlNodePtr node;
        xmlNodePtr child;
        xmlNsPtr ns;
        const xmlChar *old_name;
        xmlChar *path;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        node = root->children;
        ns = node->ns;
        child = node->children;
        assert(root != NULL && node != NULL && ns != NULL && child != NULL);
        xmlNodeSetName(node, BAD_CAST "before");
        assert(strcmp((const char *)node->name, "before") == 0);
        old_name = node->name;
        xmlResetLastError();
        xml3_oom_enable(fail_index);
        xmlNodeSetName(node, BAD_CAST "after");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(node->name == old_name);
            assert(node->parent == root && node->children == child);
            assert(node->ns == ns);
            require_oom_error();
            xmlResetLastError();
            xmlNodeSetName(node, BAD_CAST "after");
        }
        assert(strcmp((const char *)node->name, "after") == 0);
        path = xmlGetNodePath(node);
        assert(path != NULL && strcmp((const char *)path, "/root/p:after") == 0);
        xmlFree(path);
        assert(node->parent == root && node->children == child && node->ns == ns);
    } else if (strcmp(operation, "attr-unset") == 0) {
        xmlNodePtr node = xmlNewNode(NULL, BAD_CAST "node");
        assert(node);
        xmlNsPtr ns = xmlNewNs(node, BAD_CAST "urn:p", BAD_CAST "p");
        assert(ns);
        xmlAttrPtr plain = xmlNewProp(node, BAD_CAST "name", BAD_CAST "plain");
        xmlAttrPtr qualified = xmlNewNsProp(node, ns, BAD_CAST "name", BAD_CAST "qualified");
        assert(plain && qualified);
        xml3_oom_enable(0);
        assert(xmlUnsetProp(node, plain->name) == 0);
        assert(node->properties == qualified && qualified->prev == NULL);
        assert(xmlUnsetNsProp(node, ns, qualified->name) == 0);
        assert(node->properties == NULL);
        assert(xmlUnsetProp(node, BAD_CAST "name") == -1);
        assert(xmlUnsetNsProp(node, ns, BAD_CAST "name") == -1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        xmlFreeNode(node);
    } else if (strcmp(operation, "ns-noalloc") == 0) {
        xmlNodePtr node = xmlNewNode(NULL, BAD_CAST "node");
        xmlNsPtr first = xmlNewNs(NULL, BAD_CAST "urn:first", BAD_CAST "p");
        xmlNsPtr second = xmlNewNs(NULL, BAD_CAST "urn:second", BAD_CAST "q");
        assert(node != NULL && first != NULL && second != NULL);

        xml3_oom_enable(0);
        xmlSetNs(node, first);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0 && node->ns == first);

        xml3_oom_enable(0);
        xmlSetNs(node, second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0 && node->ns == second);

        xml3_oom_enable(0);
        xmlSetNs(node, NULL);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0 && node->ns == NULL);

        xml3_oom_enable(0);
        xmlFreeNs(first);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);

        xml3_oom_enable(0);
        xmlFreeNs(second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        xmlFreeNode(node);
    } else if (strcmp(operation, "ns-search-prefix") == 0 ||
               strcmp(operation, "ns-search-href") == 0) {
        const xmlChar *uri = BAD_CAST "http://www.w3.org/XML/1998/namespace";
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNsPtr existing, result;
        int by_href = strcmp(operation, "ns-search-href") == 0;
        assert(root);
        existing = xmlNewNs(root, BAD_CAST "urn:p", BAD_CAST "p");
        assert(existing);
        xml3_oom_enable(0);
        assert(!xmlSearchNs(NULL, root, BAD_CAST "missing"));
        assert(!xml3_oom_was_injected() && xml3_oom_count() == 0);
        xml3_oom_disable();
        xml3_oom_enable(fail_index);
        result = by_href ? xmlSearchNsByHref(NULL, root, uri)
                         : xmlSearchNs(NULL, root, BAD_CAST "xml");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!result && root->nsDef == existing && !existing->next);
            require_oom_error();
        } else {
            assert(result && xmlStrEqual(result->href, uri));
        }
        xmlResetLastError();
        result = xmlSearchNs(NULL, root, BAD_CAST "xml");
        assert(result && xmlStrEqual(result->href, uri));
        assert(xmlSearchNs(NULL, root, BAD_CAST "p") == existing);
        xml3_oom_enable(0);
        assert(xmlSearchNsByHref(NULL, root, uri) == result);
        assert(xmlSearchNs(NULL, root, BAD_CAST "xml") == result);
        assert(!xml3_oom_was_injected() && xml3_oom_count() == 0);
        xml3_oom_disable();
        assert(xmlGetLastError() == NULL);
        xmlFreeNode(root);
    } else if (strcmp(operation, "attr-value") == 0) {
        static const char input[] = "<root xmlns:p='urn:p' p:a='value'/>";
        xmlNodePtr root;
        xmlChar *value;
        int result;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        value = (xmlChar *)root;
        xml3_oom_enable(0);
        result = xmlNodeGetAttrValue(root, BAD_CAST "missing", NULL, &value);
        assert(result == 1 && value == NULL);
        assert(xmlHasProp(root, BAD_CAST "a") == root->properties);
        assert(xmlHasNsProp(root, BAD_CAST "a", BAD_CAST "urn:p") == root->properties);
        assert(xmlHasNsProp(root, BAD_CAST "a", NULL) == NULL);
        assert(!xml3_oom_was_injected() && xml3_oom_count() == 0);
        xml3_oom_disable();
        value = (xmlChar *)root;
        xml3_oom_enable(fail_index);
        result = xmlNodeGetAttrValue(root, BAD_CAST "a", BAD_CAST "urn:p", &value);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1 && value == NULL);
            require_oom_error();
        } else {
            assert(result == 0 && value);
            assert(strcmp((const char *)value, "value") == 0);
            xmlFree(value);
        }
        xmlResetLastError();
        assert(xmlNodeGetAttrValue(root, BAD_CAST "a", BAD_CAST "urn:p", &value) == 0);
        assert(value && strcmp((const char *)value, "value") == 0);
        xmlFree(value);
        assert(xmlGetLastError() == NULL);
    } else if (strcmp(operation, "release-lists") == 0) {
        static const char input[] = "<root a='one' b='two'><one/><two/></root>";
        xmlNodePtr root;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        xml3_oom_enable(0);
        xmlFreePropList(root->properties);
        xmlFreeNodeList(root->children);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        assert(root->properties == NULL && root->children == NULL && root->last == NULL);
    } else if (strcmp(operation, "xhtml-identifiers") == 0) {
        xml3_oom_enable(0);
        assert(xmlIsXHTML(NULL, NULL) == -1);
        assert(xmlIsXHTML(BAD_CAST "unknown", BAD_CAST "") == 0);
        assert(xmlIsXHTML(NULL, BAD_CAST "-//W3C//DTD XHTML 1.0 Strict//EN") == 1);
        assert(xmlIsXHTML(BAD_CAST "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd",
                          NULL) == 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "replace-node") == 0) {
        xmlNodePtr root;
        xmlNodePtr old;
        xmlNodePtr replacement;
        doc = xmlReadMemory("<r><before/><old/><after/></r>", 30,
                            NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        old = root->children->next;
        replacement = xmlNewNode(NULL, BAD_CAST "replacement");
        assert(old != NULL && replacement != NULL);
        xml3_oom_enable(0);
        assert(xmlReplaceNode(old, replacement) == old);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        assert(root->children->next == replacement &&
               replacement->parent == root &&
               replacement->prev == root->children &&
               replacement->next == root->last);
        assert(old->parent == NULL && old->prev == NULL && old->next == NULL);
        xmlFreeNode(old);
    } else if (strcmp(operation, "node-line-number") == 0) {
        doc = xmlReadMemory("<r>\n<a/></r>",
                            (int)strlen("<r>\n<a/></r>"), NULL, NULL, 0);
        assert(doc != NULL);
        xml3_oom_enable(0);
        assert(xmlGetLineNo((xmlNodePtr)doc) == -1);
        assert(xmlGetLineNo(xmlDocGetRootElement(doc)) == 1);
        assert(xmlGetLineNo(xmlDocGetRootElement(doc)->children) == 2);
        assert(xmlGetLineNo(NULL) == -1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "uri-normalize") == 0) {
        char relative[] = "..//../a/./b/..";
        char absolute[] = "/a/../../b";
        char empty[] = "";
        xml3_oom_enable(fail_index);
        assert(xmlNormalizeURIPath(relative) == 0);
        assert(strcmp(relative, "../../a/") == 0);
        assert(xmlNormalizeURIPath(absolute) == 0 && strcmp(absolute, "/b") == 0);
        assert(xmlNormalizeURIPath(empty) == 0);
        assert(xmlNormalizeURIPath(NULL) == -1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "name-values") == 0) {
        int (*validators[])(const xmlChar *) = {
            xmlValidateNameValue, xmlValidateNamesValue,
            xmlValidateNmtokenValue, xmlValidateNmtokensValue
        };
        xml3_oom_enable(fail_index);
        for (size_t i = 0; i < sizeof(validators) / sizeof(*validators); ++i) {
            assert(validators[i](BAD_CAST "name") == 1);
            assert(validators[i](BAD_CAST "!") == 0);
            assert(validators[i](NULL) == 0);
        }
        assert(xmlValidateNamesValue(BAD_CAST "name other") == 1);
        assert(xmlValidateNmtokensValue(BAD_CAST "\t9 -tag ") == 1);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "document-entity") == 0) {
        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        assert(doc != NULL);
        xml3_oom_enable(fail_index);
        assert(xmlGetDocEntity(doc, BAD_CAST "amp") != NULL);
        assert(xmlGetDocEntity(NULL, BAD_CAST "lt") != NULL);
        assert(xmlGetDocEntity(doc, BAD_CAST "missing") == NULL);
        assert(xmlGetDocEntity(doc, NULL) == NULL);
        assert(xmlGetDocEntity(NULL, NULL) == NULL);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        xmlFreeDoc(doc);
    } else if (strcmp(operation, "predefined-entity") == 0) {
        static const char *names[] = {"lt", "gt", "amp", "apos", "quot"};
        xml3_oom_enable(fail_index);
        for (size_t i = 0; i < sizeof(names) / sizeof(*names); ++i)
            assert(xmlGetPredefinedEntity(BAD_CAST names[i]) != NULL);
        assert(xmlGetPredefinedEntity(BAD_CAST "missing") == NULL);
        assert(xmlGetPredefinedEntity(NULL) == NULL);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "uri-unescape-inplace") == 0) {
        char buffer[] = "a%20%00x+";
        const char expected[] = {'a', ' ', 0, 'x', '+', 0};
        xml3_oom_enable(fail_index);
        assert(xmlURIUnescapeString(buffer, 0, buffer) == buffer);
        assert(memcmp(buffer, expected, sizeof(expected)) == 0);
        assert(!xmlURIUnescapeString(NULL, 0, buffer));
        assert(xmlURIUnescapeString("", 0, buffer) == buffer && buffer[0] == 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "uri-unescape") == 0 ||
               strcmp(operation, "uri-unescape-empty") == 0 ||
               strcmp(operation, "uri-unescape-buffer") == 0) {
        char input[] = "a%20%FF";
        char target[16] = "unchanged";
        const char *source = strcmp(operation, "uri-unescape-empty") == 0 ? "" : input;
        char *destination = strcmp(operation, "uri-unescape-buffer") == 0 ? target : NULL;
        const char *expected = source[0] == 0 ? "" : "a \xff";
        xml3_oom_enable(fail_index);
        char *result = xmlURIUnescapeString(source, 0, destination);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!result && strcmp(target, "unchanged") == 0);
            assert(strcmp(input, "a%20%FF") == 0);
            require_oom_error();
            xmlResetLastError();
            result = xmlURIUnescapeString(source, 0, destination);
        }
        assert(result && strcmp(result, expected) == 0);
        if (destination) assert(result == destination);
        else xmlFree(result);
    } else if (strcmp(operation, "uri-escape") == 0 ||
               strcmp(operation, "uri-escape-empty") == 0) {
        const xmlChar *input = strcmp(operation, "uri-escape-empty") == 0 ?
                               BAD_CAST "" : BAD_CAST "a b/\xff";
        const char *expected = input[0] == 0 ? "" : "a%20b/%FF";
        xmlChar *result;
        xml3_oom_enable(fail_index);
        result = xmlURIEscapeStr(input, BAD_CAST "/");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(!result);
            require_oom_error();
            xmlResetLastError();
            result = xmlURIEscapeStr(input, BAD_CAST "/");
        }
        assert(result && strcmp((const char *)result, expected) == 0);
        xmlFree(result);
    } else if (strcmp(operation, "utf8-write") == 0) {
        xmlChar output[5] = {0xa5, 0xa5, 0xa5, 0xa5, 0xa5};
        xml3_oom_enable(0);
        assert(xmlCopyCharMultiByte(output, 0x1f642) == 4);
        assert(memcmp(output, "\xf0\x9f\x99\x82", 4) == 0 && output[4] == 0xa5);
        assert(xmlCopyChar(0, output, 0x3a9) == 2);
        assert(output[0] == 0xce && output[1] == 0xa9 && output[2] == 0x99);
        assert(xmlCopyCharMultiByte(output, 0xd800) == 0);
        assert(xmlCopyChar(4, output, -1) == 0);
        assert(xmlCopyCharMultiByte(NULL, 'x') == 0);
        assert(output[0] == 0xce && output[1] == 0xa9 && output[2] == 0x99);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "character-range") == 0) {
        const xmlChSRange short_ranges[] = {{65, 90}};
        const xmlChLRange long_ranges[] = {{0x10000, 0x10ffff}};
        const xmlChRangeGroup group = {1, 1, short_ranges, long_ranges};
        xml3_oom_enable(0);
        assert(xmlCharInRange(65, &group) == 1);
        assert(xmlCharInRange(91, &group) == 0);
        assert(xmlCharInRange(0x10000, &group) == 1);
        assert(xmlCharInRange(0x110000, &group) == 0);
        assert(xmlCharInRange(65, NULL) == 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "character-classes") == 0) {
        xml3_oom_enable(0);
        assert(xmlIsChar('x') == 1 && xmlIsChar(0x10ffff) == 1);
        assert(xmlIsChar(0xd800) == 0 && xmlIsChar(~0u) == 0);
        assert(xmlIsBlank('\t') == 1 && xmlIsBlank(' ') == 1);
        assert(xmlIsBlank(0xa0) == 0 && xmlIsBlank(~0u) == 0);
        assert(xmlIsDigit(0x660) == 1 && xmlIsDigit(0xbe6) == 0);
        assert(xmlIsDigit(~0u) == 0);
        assert(xmlIsExtender(0x30fc) == 1 && xmlIsExtender(0x30ff) == 0);
        assert(xmlIsExtender(~0u) == 0);
        assert(xmlIsIdeographic(0x9fa5) == 1 && xmlIsIdeographic(0x9fa6) == 0);
        assert(xmlIsIdeographic(~0u) == 0);
        assert(xmlIsPubidChar('%') == 1 && xmlIsPubidChar('\t') == 0);
        assert(xmlIsPubidChar(~0u) == 0);
        assert(xmlIsBaseChar(0xd7a3) == 1 && xmlIsBaseChar(0xd7a4) == 0);
        assert(xmlIsBaseChar(0x4e00) == 0 && xmlIsBaseChar(~0u) == 0);
        assert(xmlIsCombining(0x345) == 1 && xmlIsCombining(0x346) == 0);
        assert(xmlIsCombining(~0u) == 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "last-child") == 0) {
        static const char input[] = "<root a='value'><one/>text<!--last--></root>";
        xmlNodePtr root;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        xml3_oom_enable(0);
        assert(xmlGetLastChild(root) == root->last);
        assert(xmlGetLastChild((const xmlNode *)doc) == root);
        assert(xmlGetLastChild((const xmlNode *)root->properties) == root->properties->last);
        assert(xmlGetLastChild(root->children) == NULL);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
    } else if (strcmp(operation, "attr-unlink") == 0) {
        static const char input[] = "<root a='keep' b='detached' c='last'/>";
        xmlNodePtr root;
        xmlAttrPtr first, attr, last;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        root = xmlDocGetRootElement(doc);
        first = root->properties;
        attr = first->next;
        last = attr->next;
        xml3_oom_enable(0);
        xmlUnlinkNode((xmlNodePtr)attr);
        xmlUnlinkNode((xmlNodePtr)attr);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        assert(root->properties == first && first->next == last && last->prev == first);
        assert(attr->parent == NULL && attr->prev == NULL && attr->next == NULL);
        assert(attr->doc == doc && attr->children->doc == doc);
        assert(strcmp((const char *)attr->children->content, "detached") == 0);
        assert(xmlAddChild(root, (xmlNodePtr)attr) == (xmlNodePtr)attr);
    } else if (strcmp(operation, "attr-attach") == 0) {
        static const char input[] =
            "<root><source a='moved'/><target a='old' b='keep'/></root>";
        xmlNodePtr root;
        xmlNodePtr source, result;
        xmlAttrPtr attr, old, tail;
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc);
        source = xmlDocGetRootElement(doc)->children;
        root = source->next;
        attr = source->properties;
        old = root->properties;
        tail = old->next;
        assert(attr && old && tail);
        xml3_oom_enable(0);
        result = xmlAddChild(root, (xmlNodePtr)attr);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(result == (xmlNodePtr)attr && !injected && allocation_count == 0);
        assert(source->properties == NULL && root->properties == tail);
        assert(tail->next == attr && attr->prev == tail && attr->next == NULL);
        assert(attr->parent == root && attr->doc == doc && attr->children->doc == doc);
        xmlFreeNode(source);
        assert(strcmp((const char *)attr->children->content, "moved") == 0);
    } else if (strcmp(operation, "attr-delete") == 0) {
        xmlNodePtr root;
        xmlAttrPtr first, second, third;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        first = xmlNewProp(root, BAD_CAST "first", BAD_CAST "one");
        second = xmlNewProp(root, BAD_CAST "second", BAD_CAST "two");
        third = xmlNewProp(root, BAD_CAST "third", BAD_CAST "three");
        assert(first != NULL && second != NULL && third != NULL);
        xml3_oom_enable(0);
        result = xmlRemoveProp(first);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(result == 0 && !injected && allocation_count == 0);
        assert(root->properties == second && second->prev == NULL);
        assert(second->next == third && third->prev == second);
        xml3_oom_enable(0);
        xmlFreeProp(second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        assert(root->properties == third && third->prev == NULL);
        xml3_oom_enable(0);
        result = xmlUnsetProp(root, BAD_CAST "third");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(result == 0 && !injected && allocation_count == 0);
        assert(root->properties == NULL);
    } else {
        assert(0);
        return 1;
    }
    if (doc != NULL)
        xmlFreeDoc(doc);
    if (merge_right != NULL)
        xmlFreeNode(merge_right);
    xmlResetLastError();
    doc = xmlReadMemory("<recovered/>", 12, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlGetLastError() == NULL);
    if (strcmp(operation, "substring-search") == 0) {
        puts("substring search used no native allocations");
        return 0;
    }
    if (strcmp(operation, "qname-equal") == 0) {
        puts("QName equality used no native allocations");
        return 0;
    }
    if (strcmp(operation, "string-search") == 0) {
        puts("byte search used no native allocations");
        return 0;
    }
    if (strcmp(operation, "string-compare") == 0) {
        puts("bounded string comparisons used no native allocations");
        return 0;
    }
    if (strcmp(operation, "full-string-compare") == 0) {
        puts("full string comparisons used no native allocations");
        return 0;
    }
    if (strcmp(operation, "string-length") == 0) {
        puts("string length used no native allocations");
        return 0;
    }
    if (strcmp(operation, "utf8-check") == 0) {
        puts("UTF-8 validation used no native allocations");
        return 0;
    }
    if (strcmp(operation, "utf8-charcmp-error") == 0) {
        puts("UTF-8 comparison diagnostic OOM and retry passed");
        return 0;
    }
    if (strcmp(operation, "release-lists") == 0) {
        puts("list release used no native allocations");
        return 0;
    }
    if (strcmp(operation, "last-child") == 0) {
        puts("last-child queries used no native allocations");
        return 0;
    }
    if (strcmp(operation, "character-classes") == 0) {
        puts("character classification used no native allocations");
        return 0;
    }
    if (strcmp(operation, "character-range") == 0) {
        puts("character range lookup used no native allocations");
        return 0;
    }
    if (strcmp(operation, "utf8-write") == 0) {
        puts("UTF-8 character writing used no native allocations");
        return 0;
    }
    if (strcmp(operation, "uri-unescape-inplace") == 0) {
        puts("in-place URI unescaping used no native allocations");
        return 0;
    }
    if (strcmp(operation, "uri-normalize") == 0) {
        puts("URI path normalization used no native allocations");
        return 0;
    }
    if (strcmp(operation, "predefined-entity") == 0) {
        puts("predefined entity lookup used no native allocations");
        return 0;
    }
    if (strcmp(operation, "document-entity") == 0) {
        puts("valid document entity queries used no native allocations");
        return 0;
    }
    if (strcmp(operation, "name-values") == 0) {
        puts("name value validators used no native allocations");
        return 0;
    }
    if (strcmp(operation, "xhtml-identifiers") == 0) {
        puts("XHTML identification used no native allocations");
        return 0;
    }
    if (strcmp(operation, "replace-node") == 0) {
        puts("node replacement used no native allocations");
        return 0;
    }
    if (strcmp(operation, "node-line-number") == 0) {
        puts("node line-number queries used no native allocations");
        return 0;
    }
    if (strcmp(operation, "attr-unlink") == 0) {
        puts("attribute unlink used no native allocations");
        return 0;
    }
    if (strcmp(operation, "attr-attach") == 0) {
        puts("attribute attachment and replacement used no native allocations");
        return 0;
    }
    if (strcmp(operation, "attr-delete") == 0) {
        puts("attribute deletion used no allocations");
        return 0;
    }
    if (strcmp(operation, "validate-name") == 0) {
        puts("name validation used no native allocations");
        return 0;
    }
    if (strcmp(operation, "ns-noalloc") == 0) {
        puts("namespace setters and standalone free used no allocations");
        return 0;
    }
    if (strcmp(operation, "attr-unset") == 0) {
        puts("property removal used no native allocations");
        return 0;
    }
    if (strcmp(operation, "dom-adjacent-sibling") == 0) {
        puts("adjacent sibling insertion used no native allocations");
        return 0;
    }
    if (!injected)
        return 2;
    printf("allocation failure hit: operation=%s index=%ld count=%ld\n",
           operation, fail_index, allocation_count);
    return 0;
}
