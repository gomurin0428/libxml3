#include <libxml3.h>

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void xml3_oom_enable(long index);
void xml3_oom_disable(void);
long xml3_oom_count(void);
int xml3_oom_was_injected(void);

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

static const xmlError *require_oom_error(void) {
    const xmlError *error = xmlGetLastError();
    assert(error != NULL);
    assert(error->domain == XML_FROM_MEMORY);
    assert(error->code == XML_ERR_NO_MEMORY);
    assert(error->level == XML_ERR_FATAL);
    return error;
}

int main(int argc, char **argv) {
    const char *operation;
    long fail_index;
    long allocation_count;
    int injected;
    xmlDocPtr doc = NULL;
    xmlError copy = {0};
    xmlError source = {0};
    const xmlError *error;
    int result = 0;

    assert(argc == 3);
    operation = argv[1];
    fail_index = strtol(argv[2], NULL, 10);
    xmlResetLastError();

    if (strcmp(operation, "success") == 0) {
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
    } else if (strcmp(operation, "copy") == 0) {
        xmlError source_before;
        xmlError destination_before;

        xml3_oom_disable();
        init_test_error(&source, "source");
        init_test_error(&copy, "destination");
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
    } else {
        assert(0);
        return 1;
    }
    if (doc != NULL)
        xmlFreeDoc(doc);
    xmlResetLastError();
    doc = xmlReadMemory("<recovered/>", 12, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlGetLastError() == NULL);
    if (!injected)
        return 2;
    printf("allocation failure hit: operation=%s index=%ld count=%ld\n",
           operation, fail_index, allocation_count);
    return 0;
}
