#define _GNU_SOURCE
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#ifndef XML3_REFERENCE_TEST
#include <libxml3.h>
#endif

#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#ifdef XML3_REFERENCE_TEST
static void check_reference_version(void) {
    assert(LIBXML_VERSION == 21504);
    assert(xmlParserVersion != NULL);
    assert(strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) == 0);
}
#else
static void check_reference_version(void) {}
#endif

static void check_error(int code, int domain, xmlErrorLevel level,
                        int line, int column) {
    const xmlError *error = xmlGetLastError();
    assert(error != NULL);
    assert(error->code == code);
    assert(error->domain == domain);
    assert(error->level == level);
    assert(error->line == line);
    assert(error->int2 == column);
    assert(error->message != NULL);
}

static void test_lifecycle(void) {
    xmlError copy = {0};
    xmlDocPtr doc;
    char filename[] = "mutable-name.xml";
    char *owned_message;
    char *owned_file;

    xmlResetLastError();
    assert(xmlGetLastError() == NULL);

    assert(xmlReadMemory("<r>", 3, filename, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 4);
#ifndef XML3_REFERENCE_TEST
    memset(filename, 'x', sizeof(filename) - 1);
#endif
    assert(strcmp(xmlGetLastError()->file, "mutable-name.xml") == 0);

    owned_message = strdup(xmlGetLastError()->message);
    owned_file = strdup(xmlGetLastError()->file);
    assert(owned_message != NULL && owned_file != NULL);
    assert(xmlCopyError(xmlGetLastError(), &copy) == 0);
    assert(copy.message != xmlGetLastError()->message);
    assert(copy.file != xmlGetLastError()->file);

    doc = xmlReadMemory("<r/>", 4, "success.xml", NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(strcmp(xmlGetLastError()->message, owned_message) == 0);
    assert(strcmp(xmlGetLastError()->file, owned_file) == 0);
    assert(strcmp(copy.message, owned_message) == 0);
    assert(strcmp(copy.file, owned_file) == 0);

    assert(xmlCopyError(&copy, &copy) == 0);
    xmlResetError(&copy);
    assert(copy.message == NULL && copy.file == NULL);
    xmlResetError(&copy);
    assert(xmlCopyError(NULL, &copy) != 0);
    assert(xmlCopyError(xmlGetLastError(), NULL) != 0);
    xmlResetError((xmlError *)(uintptr_t)xmlGetLastError());
    assert(xmlGetLastError() == NULL);

    free(owned_message);
    free(owned_file);
    xmlResetLastError();
    assert(xmlGetLastError() == NULL);

    doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlGetLastError() == NULL);

    assert(xmlReadMemory("", 0, "empty.xml", NULL, 0) == NULL);
    check_error(XML_ERR_DOCUMENT_EMPTY, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 1);
    assert(xmlReadMemory(NULL, 1, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_DOCUMENT_EMPTY, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 1);
    assert(xmlReadMemory("<r/>", -1, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_DOCUMENT_EMPTY, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 1);
    doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    check_error(XML_ERR_DOCUMENT_EMPTY, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 1);
    assert(xmlReadMemory("<r>", 3, NULL, NULL, XML_PARSE_NOERROR) == NULL);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 4);
    doc = xmlReadMemory("<r/>", 4, NULL, NULL, XML_PARSE_NOERROR);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 4);
#ifndef XML3_REFERENCE_TEST
    {
        int status = -1;
        assert(xml3ReadMemory(NULL, 1, &status) == NULL);
        assert(status == XML3_STATUS_INVALID_ARGUMENT);
        check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                    XML_ERR_FATAL, 1, 4);
    }
#endif
    xmlResetLastError();
}

static void test_read_entrypoints(void) {
    assert(xmlParseMemory("<broken>", 8) == NULL);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 9);
    xmlResetLastError();
    assert(xmlReadDoc((const xmlChar *)"<broken>", NULL, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 9);
    xmlResetLastError();
    assert(xmlParseDoc((const xmlChar *)"<broken>") == NULL);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 9);
    xmlResetLastError();
}

static void test_copy_ownership(void) {
    xmlError source = {0};
    xmlError destination = {0};
    char *source_fields[5];
    char *destination_fields[5];
    char **source_slots[] = {
        &source.message, &source.file, &source.str1, &source.str2, &source.str3
    };
    char **destination_slots[] = {
        &destination.message, &destination.file, &destination.str1,
        &destination.str2, &destination.str3
    };
    static const char *const source_values[] = {
        "source message", "source file", "source one", "source two", "source three"
    };
    static const char *const destination_values[] = {
        "old message", "old file", "old one", "old two", "old three"
    };

    for (size_t i = 0; i < 5; ++i) {
        source_fields[i] = strdup(source_values[i]);
        destination_fields[i] = strdup(destination_values[i]);
        assert(source_fields[i] != NULL && destination_fields[i] != NULL);
        *source_slots[i] = source_fields[i];
        *destination_slots[i] = destination_fields[i];
    }
    source.domain = XML_FROM_PARSER;
    source.code = XML_ERR_INVALID_CHAR;
    source.level = XML_ERR_FATAL;
    destination.domain = XML_FROM_IO;
    destination.code = XML_ERR_INTERNAL_ERROR;
    assert(xmlCopyError(&source, &destination) == 0);
    assert(destination.domain == source.domain && destination.code == source.code);
    assert(destination.level == source.level);
    for (size_t i = 0; i < 5; ++i) {
        assert(*destination_slots[i] != source_fields[i]);
        assert(strcmp(*destination_slots[i], source_values[i]) == 0);
    }
    for (size_t i = 0; i < 5; ++i) {
        free(source_fields[i]);
        *source_slots[i] = NULL;
    }
    assert(strcmp(destination.message, "source message") == 0);
    assert(strcmp(destination.file, "source file") == 0);
    assert(strcmp(destination.str1, "source one") == 0);
    assert(strcmp(destination.str2, "source two") == 0);
    assert(strcmp(destination.str3, "source three") == 0);
    xmlResetError(&destination);
    assert(destination.message == NULL && destination.file == NULL);
    assert(destination.str1 == NULL && destination.str2 == NULL &&
           destination.str3 == NULL);
    {
        xmlError empty = {0};
        assert(xmlCopyError(&empty, &destination) == 0);
        assert(destination.message == NULL && destination.file == NULL);
        assert(destination.str1 == NULL && destination.str2 == NULL &&
               destination.str3 == NULL);
    }
    xmlResetError(&destination);
}

static void test_copy_boundaries(void) {
    static const char *const values[] = {"", "診断é", "raw\xff\x80", "guarded.xml"};
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 64);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (size_t sample = 0; sample < sizeof(values) / sizeof(*values); ++sample) {
        size_t length = strlen(values[sample]) + 1;
        char *input = mapping + page - length;
        memcpy(input, values[sample], length);
        xmlError source = {0}, copy = {0}, saved = {0};
        char **source_fields[] = {&source.message, &source.file, &source.str1,
                                  &source.str2, &source.str3};
        char **copy_fields[] = {&copy.message, &copy.file, &copy.str1,
                                &copy.str2, &copy.str3};
        char **saved_fields[] = {&saved.message, &saved.file, &saved.str1,
                                 &saved.str2, &saved.str3};
        source.domain = XML_FROM_PARSER;
        source.code = XML_ERR_INVALID_CHAR;
        source.level = XML_ERR_FATAL;
        source.line = 17;
        source.int1 = 23;
        source.int2 = 42;
        for (size_t field = 0; field < 5; ++field)
            *source_fields[field] =
                sample == 1 && field != 0 && field % 2 == 0 ? NULL : input;
        assert(xmlCopyError(&source, &copy) == 0);
        assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
        for (size_t field = 0; field < 5; ++field) {
            if (*source_fields[field] == NULL) {
                assert(*copy_fields[field] == NULL);
            } else {
                assert(*copy_fields[field] && *copy_fields[field] != input);
                assert(strcmp(*copy_fields[field], values[sample]) == 0);
                for (size_t previous = 0; previous < field; ++previous)
                    assert(*copy_fields[field] != *copy_fields[previous]);
            }
        }
        assert(xmlCopyError(&copy, &saved) == 0);
        xmlResetError(&copy);
        assert(saved.domain == source.domain && saved.code == source.code);
        assert(saved.level == source.level && saved.line == source.line);
        assert(saved.int1 == source.int1 && saved.int2 == source.int2);
        for (size_t field = 0; field < 5; ++field) {
            if (*source_fields[field] == NULL)
                assert(*saved_fields[field] == NULL);
            else
                assert(*saved_fields[field] && strcmp(*saved_fields[field], values[sample]) == 0);
        }
        if (sample == 3) {
            xmlResetLastError();
            assert(!xmlReadMemory("<r>", 3, saved.file, NULL, 0));
            xmlResetError(&saved);
            assert(xmlGetLastError() && strcmp(xmlGetLastError()->file, values[sample]) == 0);
            assert(xmlCopyError(xmlGetLastError(), &saved) == 0);
            xmlResetLastError();
            assert(saved.file && strcmp(saved.file, values[sample]) == 0);
            xmlDocPtr doc = xmlReadMemory("<r/>", 4, saved.file, NULL, 0);
            assert(doc && xmlDocGetRootElement(doc));
            xmlFreeDoc(doc);
        }
        xmlResetError(&saved);
        assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
    }
    assert(munmap(mapping, (size_t)page * 2) == 0);
    xmlResetLastError();
}

static pthread_barrier_t error_ready;
static pthread_barrier_t success_done;

static void *thread_error(void *unused) {
    int result;
    (void)unused;
    xmlResetLastError();
    assert(xmlGetLastError() == NULL);
    assert(xmlReadMemory("<a>", 3, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 4);
    result = pthread_barrier_wait(&error_ready);
    assert(result == 0 || result == PTHREAD_BARRIER_SERIAL_THREAD);
    result = pthread_barrier_wait(&success_done);
    assert(result == 0 || result == PTHREAD_BARRIER_SERIAL_THREAD);
    check_error(XML_ERR_TAG_NOT_FINISHED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 4);
    return NULL;
}

static void *thread_success(void *unused) {
    int result;
    (void)unused;
    xmlDocPtr doc;
    xmlResetLastError();
    assert(xmlGetLastError() == NULL);
    result = pthread_barrier_wait(&error_ready);
    assert(result == 0 || result == PTHREAD_BARRIER_SERIAL_THREAD);
    doc = xmlReadMemory("<b/>", 4, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlGetLastError() == NULL);
    result = pthread_barrier_wait(&success_done);
    assert(result == 0 || result == PTHREAD_BARRIER_SERIAL_THREAD);
    return NULL;
}

static void test_thread_isolation(void) {
    pthread_t first;
    pthread_t second;
    assert(pthread_barrier_init(&error_ready, NULL, 2) == 0);
    assert(pthread_barrier_init(&success_done, NULL, 2) == 0);
    assert(pthread_create(&first, NULL, thread_error, NULL) == 0);
    assert(pthread_create(&second, NULL, thread_success, NULL) == 0);
    assert(pthread_join(first, NULL) == 0);
    assert(pthread_join(second, NULL) == 0);
    assert(pthread_barrier_destroy(&error_ready) == 0);
    assert(pthread_barrier_destroy(&success_done) == 0);
    assert(xmlGetLastError() == NULL);
}

static void test_numeric_compatibility(void) {
    xmlDocPtr doc;

    xmlResetLastError();
    assert(xmlReadMemory(" ", 1, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_DOCUMENT_EMPTY, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 2);

    xmlResetLastError();
    assert(xmlReadMemory("<r></s>", 7, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NAME_MISMATCH, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 8);

    xmlResetLastError();
    assert(xmlReadMemory("<r a=\"1\" a=\"2\"/>", 16, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_ATTRIBUTE_REDEFINED, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 15);

    xmlResetLastError();
    assert(xmlReadMemory("<r>&#65;&bad;</r>", 17, NULL, NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == XML_ERR_UNDECLARED_ENTITY);
    assert(xmlGetLastError()->domain == XML_FROM_PARSER);
    assert(xmlGetLastError()->level == XML_ERR_FATAL);
    assert(xmlGetLastError()->line == 1);
    assert(xmlGetLastError()->int2 > 4);

    {
        static const unsigned char invalid_char[] = "\n<r>\001</r>";
        xmlResetLastError();
        assert(xmlReadMemory((const char *)invalid_char,
                             (int)sizeof(invalid_char) - 1,
                             NULL, NULL, 0) == NULL);
        check_error(XML_ERR_INVALID_CHAR, XML_FROM_PARSER,
                    XML_ERR_FATAL, 2, 4);
        assert(xmlGetLastError()->int1 == 1);
    }

    xmlResetLastError();
    doc = xmlReadMemory("<p:r/>", 6, NULL, NULL, 0);
#ifdef XML3_REFERENCE_TEST
    assert(doc != NULL);
#else
    assert(doc == NULL);
#endif
    check_error(XML_NS_ERR_UNDEFINED_NAMESPACE, XML_FROM_NAMESPACE,
                XML_ERR_ERROR, 1, 5);
    if (doc != NULL)
        xmlFreeDoc(doc);
    xmlResetLastError();
}

static void test_location_variants(void) {
    static const char lf[] = "<r>\n<a></b>\n</r>";
    static const char cr[] = "<r>\r<a></b></r>";
    static const char unicode[] = "<r>é<a></b></r>";
    static const unsigned char invalid_utf8[] =
        {'<', 'r', '>', 0xff, '<', '/', 'r', '>'};
    static const unsigned char surrogate_utf8[] =
        {'<', 'r', '>', 0xed, 0xa0, 0x80, '<', '/', 'r', '>'};
    static const unsigned char out_of_range_utf8[] =
        {'<', 'r', '>', 0xf4, 0x90, 0x80, 0x80, '<', '/', 'r', '>'};

    xmlResetLastError();
    assert(xmlReadMemory(lf, (int)sizeof(lf) - 1, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NAME_MISMATCH, XML_FROM_PARSER,
                XML_ERR_FATAL, 2, 8);
    assert(xmlGetLastError()->int1 == 2);

    xmlResetLastError();
    assert(xmlReadMemory(cr, (int)sizeof(cr) - 1, NULL, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NAME_MISMATCH, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 12);
    assert(xmlGetLastError()->int1 == 1);

    {
        char input[] = "<r>\r\né😀\t<a></b></r>";
        xmlError saved = {0};
        xmlResetLastError();
        assert(!xmlReadMemory(input, (int)sizeof(input) - 1, "location.xml", NULL, 0));
        check_error(XML_ERR_TAG_NAME_MISMATCH, XML_FROM_PARSER, XML_ERR_FATAL, 2, 11);
        assert(xmlGetLastError()->int1 == 2);
        assert(xmlCopyError(xmlGetLastError(), &saved) == 0);
        memset(input, '!', sizeof(input));
        xmlResetLastError();
        xmlDocPtr doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
        assert(doc && xmlGetLastError() == NULL);
        xmlFreeDoc(doc);
        assert(saved.line == 2 && saved.int1 == 2 && saved.int2 == 11);
        assert(saved.code == XML_ERR_TAG_NAME_MISMATCH);
        xmlResetError(&saved);
    }

    xmlResetLastError();
    assert(xmlReadMemory(unicode, (int)sizeof(unicode) - 1,
                         NULL, NULL, 0) == NULL);
    check_error(XML_ERR_TAG_NAME_MISMATCH, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 12);
    assert(xmlGetLastError()->int1 == 1);

    xmlResetLastError();
    assert(xmlReadMemory((const char *)invalid_utf8,
                         (int)sizeof(invalid_utf8), NULL, NULL, 0) == NULL);
    check_error(XML_ERR_INVALID_ENCODING, XML_FROM_IO,
                XML_ERR_FATAL, 1, 4);

    xmlResetLastError();
    assert(xmlReadMemory((const char *)surrogate_utf8,
                         (int)sizeof(surrogate_utf8), NULL, NULL, 0) == NULL);
    check_error(XML_ERR_INVALID_ENCODING, XML_FROM_IO,
                XML_ERR_FATAL, 1, 4);

    xmlResetLastError();
    assert(xmlReadMemory((const char *)out_of_range_utf8,
                         (int)sizeof(out_of_range_utf8), NULL, NULL, 0) == NULL);
    check_error(XML_ERR_INVALID_ENCODING, XML_FROM_IO,
                XML_ERR_FATAL, 1, 4);
    xmlResetLastError();
}

static void test_message_categories(void) {
    xmlResetLastError();
    assert(xmlReadMemory("", 0, "empty.xml", NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == XML_ERR_DOCUMENT_EMPTY);
#ifndef XML3_REFERENCE_TEST
    assert(strstr(xmlGetLastError()->message, "Document is empty") != NULL);
#endif

    xmlResetLastError();
    assert(xmlReadMemory("junk", 4, NULL, NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == XML_ERR_DOCUMENT_EMPTY);
#ifndef XML3_REFERENCE_TEST
    assert(strstr(xmlGetLastError()->message,
                  "Start tag expected, '<' not found") != NULL);
#endif

    xmlResetLastError();
    assert(xmlReadMemory("<r/><s/>", 8, NULL, NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == XML_ERR_DOCUMENT_END);
#ifndef XML3_REFERENCE_TEST
    assert(strstr(xmlGetLastError()->message, "Extra content") != NULL);
#endif

    xmlResetLastError();
    assert(xmlReadMemory("<r>", 3, NULL, NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == XML_ERR_TAG_NOT_FINISHED);
#ifndef XML3_REFERENCE_TEST
    assert(strstr(xmlGetLastError()->message, "Tag is not finished") != NULL);
#endif
    xmlResetLastError();

    assert(xmlReadMemory("<?xml version='1.0'junk?><r/>", 29,
                         NULL, NULL, 0) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->code == 57);
    assert(strstr(xmlGetLastError()->message,
                  "XML declaration is not finished") != NULL);
#endif
    xmlResetLastError();

#ifndef XML3_REFERENCE_TEST
    {
        xmlDocPtr doc = xmlReadMemory("<r>text</r>", 11, NULL, NULL, 0);
        xmlNodePtr root;

        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        assert(root != NULL);
        xmlNodeSetName(root, (const xmlChar *)"1bad");
        assert(xmlGetLastError() != NULL);
        assert(xmlGetLastError()->domain == 2);
        assert(strstr(xmlGetLastError()->message,
                      "Unsupported parser option or feature") != NULL);
        xmlFreeDoc(doc);
        xmlResetLastError();
    }
#endif
}

static void test_unsupported_feature(void) {
    xmlDocPtr doc = xmlReadMemory("<!DOCTYPE r><r/>", 16, NULL, NULL,
                                  XML_PARSE_HUGE | XML_PARSE_NOERROR);
#ifdef XML3_REFERENCE_TEST
    assert(doc != NULL);
#else
    assert(doc == NULL);
    check_error(XML_ERR_ARGUMENT, XML_FROM_PARSER,
                XML_ERR_FATAL, 1, 1);
#endif
    if (doc != NULL)
        xmlFreeDoc(doc);
    xmlResetLastError();
}

int main(void) {
    check_reference_version();
    test_lifecycle();
    test_read_entrypoints();
    test_copy_ownership();
    test_copy_boundaries();
    test_thread_isolation();
    test_numeric_compatibility();
    test_location_variants();
    test_message_categories();
    test_unsupported_feature();
    puts("error tests passed");
    return 0;
}
