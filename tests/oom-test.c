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

static const xmlError *require_oom_error(void) {
    const xmlError *error = xmlGetLastError();
    assert(error != NULL);
    assert(error->code == XML_ERR_NO_MEMORY);
    return error;
}

int main(int argc, char **argv) {
    const char *operation;
    long fail_index;
    long allocation_count;
    int injected;
    xmlDocPtr doc = NULL;
    xmlError copy = {0};
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
        assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
        error = xmlGetLastError();
        assert(error != NULL);
        xml3_oom_enable(fail_index);
        result = xmlCopyError(error, &copy);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result != 0);
            require_oom_error();
        } else {
            assert(result == 0);
            assert(copy.message != NULL);
        }
        xmlResetError(&copy);
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
            error = xmlGetLastError();
            xmlResetError((xmlError *)(uintptr_t)error);
            assert(xmlGetLastError() == NULL);
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
