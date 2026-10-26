#define _DEFAULT_SOURCE

#include <libxml/tree.h>
#include <assert.h>
#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>

static size_t page_size;

void *projection_page_allocate(void) {
    void *mapping;
    if (page_size == 0)
        page_size = (size_t)sysconf(_SC_PAGESIZE);
    mapping = mmap(NULL, page_size, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping == MAP_FAILED)
        return NULL;
    return (char *)mapping + page_size / 2;
}

void projection_page_readonly(void *facade) {
    void *mapping = (void *)((uintptr_t)facade - page_size / 2);
    assert(mprotect(mapping, page_size, PROT_READ) == 0);
}

void projection_page_writable(void *facade) {
    void *mapping = (void *)((uintptr_t)facade - page_size / 2);
    assert(mprotect(mapping, page_size, PROT_READ | PROT_WRITE) == 0);
}

void projection_page_free(void *facade) {
    void *mapping = (void *)((uintptr_t)facade - page_size / 2);
    assert(munmap(mapping, page_size) == 0);
}

void *projection_marker(void) {
    return (void *)(uintptr_t)0x12340;
}

int projection_check_node(void *facade, void *parent) {
    xmlNodePtr node = facade;
    return node->type == XML_ELEMENT_NODE &&
           node->name == projection_marker() &&
           node->parent == parent;
}

int projection_check_document(void *facade, void *version) {
    xmlDocPtr doc = facade;
    return doc->type == XML_DOCUMENT_NODE &&
           doc->name == projection_marker() &&
           (void *)doc->version == version;
}

int projection_check_namespace(void *facade, void *next) {
    xmlNsPtr ns = facade;
    return ns->type == XML_NAMESPACE_DECL &&
           ns->href == projection_marker() &&
           ns->prefix == projection_marker() &&
           ns->next == next && ns->context == NULL;
}
