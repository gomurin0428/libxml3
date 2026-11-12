/* The allocator of libxml2 2.15.4's xmlmemory.h.  Every block the library
 * hands to its callers, or releases for them, goes through the functions
 * set by xmlMemSetup or xmlGcMemSetup (the C library's by default), so a
 * caller's allocator also owns what xmlFree releases.  The debug allocator
 * (xmlMemMalloc and its family) keeps libxml2's size header and counters.
 * These are trusted native shims: they hold function pointers and call
 * them; no decision of the library is made here. */
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#if defined(__GNUC__) || defined(__clang__)
#define XML3_INTERNAL __attribute__((visibility("hidden")))
#else
#define XML3_INTERNAL
#endif

typedef void (*xml3_free_func)(void *);
typedef void *(*xml3_malloc_func)(size_t);
typedef void *(*xml3_realloc_func)(void *, size_t);
typedef char *(*xml3_strdup_func)(const char *);

static char *default_strdup(const char *text);

static xml3_free_func free_hook = free;
static xml3_malloc_func malloc_hook = malloc;
static xml3_malloc_func malloc_atomic_hook = malloc;
static xml3_realloc_func realloc_hook = realloc;
static xml3_strdup_func strdup_hook = default_strdup;

/* libxml2's default xmlMemStrdup copies with the current xmlMalloc. */
static char *default_strdup(const char *text) {
    size_t size;
    char *copy;

    if (text == NULL)
        return NULL;
    size = strlen(text) + 1;
    copy = malloc_hook(size);
    if (copy != NULL)
        memcpy(copy, text, size);
    return copy;
}

/* The allocation the Ada units and the I/O helper use. */
XML3_INTERNAL void *xml3MemAllocate(size_t size) {
    return malloc_hook(size);
}

XML3_INTERNAL void *xml3MemReallocate(void *block, size_t size) {
    return realloc_hook(block, size);
}

XML3_INTERNAL void xml3MemRelease(void *block) {
    if (block != NULL)
        free_hook(block);
}

/* xmlMalloc, xmlMallocAtomic, xmlRealloc and xmlMemStrdup are variables
 * holding the functions in libxml2; here they are functions calling them. */
void *xmlMalloc(size_t size) {
    return malloc_hook(size);
}

void *xmlMallocAtomic(size_t size) {
    return malloc_atomic_hook(size);
}

void *xmlRealloc(void *block, size_t size) {
    return realloc_hook(block, size);
}

char *xmlMemStrdup(const char *text) {
    return strdup_hook(text);
}

int xmlMemSetup(xml3_free_func free_func, xml3_malloc_func malloc_func,
                xml3_realloc_func realloc_func, xml3_strdup_func strdup_func) {
    if (free_func == NULL || malloc_func == NULL || realloc_func == NULL ||
        strdup_func == NULL)
        return -1;
    free_hook = free_func;
    malloc_hook = malloc_func;
    malloc_atomic_hook = malloc_func;
    realloc_hook = realloc_func;
    strdup_hook = strdup_func;
    return 0;
}

int xmlMemGet(xml3_free_func *free_func, xml3_malloc_func *malloc_func,
              xml3_realloc_func *realloc_func, xml3_strdup_func *strdup_func) {
    if (free_func != NULL)
        *free_func = free_hook;
    if (malloc_func != NULL)
        *malloc_func = malloc_hook;
    if (realloc_func != NULL)
        *realloc_func = realloc_hook;
    if (strdup_func != NULL)
        *strdup_func = strdup_hook;
    return 0;
}

int xmlGcMemSetup(xml3_free_func free_func, xml3_malloc_func malloc_func,
                  xml3_malloc_func malloc_atomic_func,
                  xml3_realloc_func realloc_func,
                  xml3_strdup_func strdup_func) {
    if (free_func == NULL || malloc_func == NULL ||
        malloc_atomic_func == NULL || realloc_func == NULL ||
        strdup_func == NULL)
        return -1;
    free_hook = free_func;
    malloc_hook = malloc_func;
    malloc_atomic_hook = malloc_atomic_func;
    realloc_hook = realloc_func;
    strdup_hook = strdup_func;
    return 0;
}

int xmlGcMemGet(xml3_free_func *free_func, xml3_malloc_func *malloc_func,
                xml3_malloc_func *malloc_atomic_func,
                xml3_realloc_func *realloc_func,
                xml3_strdup_func *strdup_func) {
    if (free_func != NULL)
        *free_func = free_hook;
    if (malloc_func != NULL)
        *malloc_func = malloc_hook;
    if (malloc_atomic_func != NULL)
        *malloc_atomic_func = malloc_atomic_hook;
    if (realloc_func != NULL)
        *realloc_func = realloc_hook;
    if (strdup_func != NULL)
        *strdup_func = strdup_hook;
    return 0;
}

/* The debug allocator: each block carries libxml2's header (a tag and the
 * size), and the bytes and blocks in use are counted. */
#define MEMTAG 0x5aa5U

typedef struct {
    unsigned int tag;
    size_t size;
} memory_header;

#define ALIGN_SIZE sizeof(double)
#define RESERVE_SIZE \
    (((sizeof(memory_header) + ALIGN_SIZE - 1) / ALIGN_SIZE) * ALIGN_SIZE)

static pthread_mutex_t debug_mutex = PTHREAD_MUTEX_INITIALIZER;
static size_t debug_size;
static int debug_blocks;

static memory_header *header_of(void *block) {
    return (memory_header *)((char *)block - RESERVE_SIZE);
}

static void *client_of(memory_header *header) {
    return (char *)header + RESERVE_SIZE;
}

void *xmlMemMalloc(size_t size) {
    memory_header *header;

    if (size > SIZE_MAX - RESERVE_SIZE)
        return NULL;
    header = malloc(RESERVE_SIZE + size);
    if (header == NULL)
        return NULL;
    header->tag = MEMTAG;
    header->size = size;
    pthread_mutex_lock(&debug_mutex);
    debug_size += size;
    debug_blocks++;
    pthread_mutex_unlock(&debug_mutex);
    return client_of(header);
}

void *xmlMemRealloc(void *block, size_t size) {
    memory_header *header, *grown;
    size_t old_size;

    if (block == NULL)
        return xmlMemMalloc(size);
    if (size > SIZE_MAX - RESERVE_SIZE)
        return NULL;
    header = header_of(block);
    if (header->tag != MEMTAG) {
        fputs("xmlMemRealloc: Tag error\n", stderr);
        return NULL;
    }
    old_size = header->size;
    header->tag = ~MEMTAG;
    grown = realloc(header, RESERVE_SIZE + size);
    if (grown == NULL) {
        header->tag = MEMTAG;
        return NULL;
    }
    grown->tag = MEMTAG;
    grown->size = size;
    pthread_mutex_lock(&debug_mutex);
    debug_size -= old_size;
    debug_size += size;
    pthread_mutex_unlock(&debug_mutex);
    return client_of(grown);
}

void xmlMemFree(void *block) {
    memory_header *header;

    if (block == NULL)
        return;
    if (block == (void *)-1) {
        fputs("xmlMemFree: Pointer from freed area\n", stderr);
        return;
    }
    header = header_of(block);
    if (header->tag != MEMTAG) {
        fputs("xmlMemFree: Tag error\n", stderr);
        return;
    }
    header->tag = ~MEMTAG;
    memset(block, -1, header->size);
    pthread_mutex_lock(&debug_mutex);
    debug_size -= header->size;
    debug_blocks--;
    pthread_mutex_unlock(&debug_mutex);
    free(header);
}

char *xmlMemoryStrdup(const char *text) {
    size_t size = strlen(text) + 1;
    char *copy = xmlMemMalloc(size);

    if (copy != NULL)
        memcpy(copy, text, size);
    return copy;
}

void *xmlMallocLoc(size_t size, const char *file, int line) {
    (void)file;
    (void)line;
    return xmlMemMalloc(size);
}

void *xmlMallocAtomicLoc(size_t size, const char *file, int line) {
    (void)file;
    (void)line;
    return xmlMemMalloc(size);
}

void *xmlReallocLoc(void *block, size_t size, const char *file, int line) {
    (void)file;
    (void)line;
    return xmlMemRealloc(block, size);
}

char *xmlMemStrdupLoc(const char *text, const char *file, int line) {
    (void)file;
    (void)line;
    return xmlMemoryStrdup(text);
}

size_t xmlMemSize(void *block) {
    memory_header *header;

    if (block == NULL)
        return 0;
    header = header_of(block);
    if (header->tag != MEMTAG)
        return 0;
    return header->size;
}

int xmlMemUsed(void) {
    return (int)debug_size;
}

int xmlMemBlocks(void) {
    int blocks;

    pthread_mutex_lock(&debug_mutex);
    blocks = debug_blocks;
    pthread_mutex_unlock(&debug_mutex);
    return blocks;
}

/* No allocation log is kept (as in libxml2 2.15). */
void xmlMemDisplayLast(FILE *stream, long bytes) {
    (void)stream;
    (void)bytes;
}

void xmlMemDisplay(FILE *stream) {
    (void)stream;
}

void xmlMemShow(FILE *stream, int count) {
    (void)stream;
    (void)count;
}

void xmlMemoryDump(void) {
}

/* Deprecated initialization and cleanup: nothing to do. */
int xmlInitMemory(void) {
    return 0;
}

void xmlCleanupMemory(void) {
}
