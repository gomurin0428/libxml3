#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>

extern void *__libc_malloc(size_t size);
extern void xml3_oom_enable(long index);
extern void xml3_oom_disable(void);
extern int xml3_oom_was_injected(void);

int main(void) {
    const size_t length = 1024 * 1024;
    char *input = __libc_malloc(length + 1);
    xmlNodePtr node;
    int injected;
    const xmlError *error;

    assert(input != NULL);
    memset(input, 'x', length);
    input[length] = '\0';

    xml3_oom_enable(0);
    node = xmlNewText((const xmlChar *)input);
    injected = xml3_oom_was_injected();
    xml3_oom_disable();
    assert(injected && node == NULL);
    error = xmlGetLastError();
    assert(error != NULL && error->domain == XML_FROM_MEMORY &&
           error->code == XML_ERR_NO_MEMORY);
    xmlResetLastError();

    node = xmlNewText((const xmlChar *)input);
    assert(node != NULL);
    xmlFreeNode(node);
    free(input);
    return 0;
}
