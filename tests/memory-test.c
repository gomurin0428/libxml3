/* The allocator of xmlmemory.h: xmlMemSetup, xmlMemGet, xmlGcMemSetup,
 * xmlGcMemGet, the xmlMalloc family and the debug allocator.  The output
 * of this program is compared between libxml3 and the pinned reference
 * libxml2 (make test-memory), so every line must describe behavior both
 * share; allocation counts differ between the libraries and are only
 * compared with zero. */
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlmemory.h>
#include <libxml/xmlstring.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static long hooked_allocations;
static long hooked_frees;
static void *last_block;

static void *counting_malloc(size_t size) {
    hooked_allocations++;
    return last_block = malloc(size);
}

static void *counting_realloc(void *block, size_t size) {
    hooked_allocations++;
    return last_block = realloc(block, size);
}

static void counting_free(void *block) {
    if (block != NULL)
        hooked_frees++;
    free(block);
}

static char *counting_strdup(const char *text) {
    size_t size = strlen(text) + 1;
    char *copy = counting_malloc(size);

    if (copy != NULL)
        memcpy(copy, text, size);
    return copy;
}

int main(void) {
    xmlFreeFunc saved_free;
    xmlMallocFunc saved_malloc;
    xmlReallocFunc saved_realloc;
    xmlStrdupFunc saved_strdup;
    xmlFreeFunc got_free;
    xmlMallocFunc got_malloc, got_atomic;
    xmlReallocFunc got_realloc;
    xmlStrdupFunc got_strdup;
    xmlDocPtr doc;
    xmlChar *dump = NULL, *copy;
    int size = 0, used, blocks;
    void *debug;

    xmlInitParser();
    printf("get: %d\n", xmlMemGet(&saved_free, &saved_malloc, &saved_realloc,
                                  &saved_strdup));
    printf("defaults set: %d %d %d %d\n", saved_free != NULL,
           saved_malloc != NULL, saved_realloc != NULL, saved_strdup != NULL);
    printf("get with nulls: %d\n", xmlMemGet(NULL, NULL, NULL, NULL));
    printf("setup null free: %d\n", xmlMemSetup(NULL, counting_malloc,
                                                counting_realloc,
                                                counting_strdup));
    printf("setup null strdup: %d\n", xmlMemSetup(counting_free,
                                                  counting_malloc,
                                                  counting_realloc, NULL));
    printf("gc setup null atomic: %d\n",
           xmlGcMemSetup(counting_free, counting_malloc, NULL,
                         counting_realloc, counting_strdup));

    printf("setup: %d\n", xmlMemSetup(counting_free, counting_malloc,
                                      counting_realloc, counting_strdup));
    xmlMemGet(&got_free, &got_malloc, &got_realloc, &got_strdup);
    printf("get hooks: %d %d %d %d\n", got_free == counting_free,
           got_malloc == counting_malloc, got_realloc == counting_realloc,
           got_strdup == counting_strdup);
    xmlGcMemGet(&got_free, &got_malloc, &got_atomic, &got_realloc,
                &got_strdup);
    printf("gc get hooks: %d %d %d\n", got_malloc == counting_malloc,
           got_atomic == counting_malloc, got_strdup == counting_strdup);

    /* What the library hands back comes from the caller's allocator. */
    hooked_allocations = hooked_frees = 0;
    copy = xmlStrdup(BAD_CAST "copied");
    printf("strdup hooked: %s last=%s\n", hooked_allocations > 0 ? "yes" : "no",
           (void *)copy == last_block ? "yes" : "no");
    xmlFree(copy);
    printf("free hooked: %s\n", hooked_frees == 1 ? "yes" : "no");
    copy = xmlMalloc(8);
    printf("xmlMalloc hooked: %s\n", copy == last_block ? "yes" : "no");
    copy = xmlRealloc(copy, 16);
    printf("xmlRealloc hooked: %s\n", copy == last_block ? "yes" : "no");
    xmlFree(copy);
    copy = (xmlChar *)xmlMemStrdup("dup");
    printf("xmlMemStrdup hooked: %s \"%s\"\n",
           (void *)copy == last_block ? "yes" : "no", (const char *)copy);
    xmlFree(copy);

    doc = xmlReadMemory("<r a='1'><c>t</c></r>", 21, NULL, NULL, 0);
    xmlDocDumpMemory(doc, &dump, &size);
    printf("dump hooked: %s \"%s\"\n",
           (void *)dump == last_block ? "yes" : "no", (const char *)dump);
    xmlFree(dump);
    xmlFreeDoc(doc);
    printf("parse allocated through hooks: %s\n",
           hooked_allocations > 3 ? "yes" : "no");

    printf("gc setup: %d\n",
           xmlGcMemSetup(saved_free, saved_malloc, saved_malloc,
                         saved_realloc, saved_strdup));
    xmlMemGet(&got_free, NULL, NULL, NULL);
    printf("restored: %s\n", got_free == saved_free ? "yes" : "no");

    /* The debug allocator. */
    used = xmlMemUsed();
    blocks = xmlMemBlocks();
    debug = xmlMemMalloc(10);
    printf("debug malloc: size=%zu used=+%d blocks=+%d\n", xmlMemSize(debug),
           xmlMemUsed() - used, xmlMemBlocks() - blocks);
    debug = xmlMemRealloc(debug, 25);
    printf("debug realloc: size=%zu used=+%d blocks=+%d\n", xmlMemSize(debug),
           xmlMemUsed() - used, xmlMemBlocks() - blocks);
    xmlMemFree(debug);
    printf("debug free: used=+%d blocks=+%d\n", xmlMemUsed() - used,
           xmlMemBlocks() - blocks);
    debug = xmlMemoryStrdup("abc");
    printf("debug strdup: \"%s\" size=%zu\n", (char *)debug, xmlMemSize(debug));
    xmlMemFree(debug);
    debug = xmlMallocLoc(3, "file", 1);
    debug = xmlReallocLoc(debug, 5, "file", 2);
    printf("debug loc: size=%zu\n", xmlMemSize(debug));
    xmlMemFree(debug);
    debug = xmlMemStrdupLoc("xy", "file", 3);
    printf("debug strdup loc: \"%s\"\n", (char *)debug);
    xmlMemFree(debug);
    printf("debug size null: %zu\n", xmlMemSize(NULL));
    xmlMemFree(NULL);
    debug = xmlMemRealloc(NULL, 4);
    printf("debug realloc null: size=%zu\n", xmlMemSize(debug));
    xmlMemFree(debug);
    printf("debug balanced: used=+%d blocks=+%d\n", xmlMemUsed() - used,
           xmlMemBlocks() - blocks);
    xmlMemDisplay(stdout);
    xmlMemDisplayLast(stdout, 10);
    xmlMemShow(stdout, 1);
    xmlMemoryDump();

    /* The debug allocator as the library's allocator. */
    printf("debug setup: %d\n",
           xmlMemSetup(xmlMemFree, xmlMemMalloc, xmlMemRealloc,
                       xmlMemoryStrdup));
    blocks = xmlMemBlocks();
    copy = xmlStrdup(BAD_CAST "tracked");
    printf("tracked: size=%zu blocks=+%d\n", xmlMemSize(copy),
           xmlMemBlocks() - blocks);
    xmlFree(copy);
    printf("tracked freed: blocks=+%d\n", xmlMemBlocks() - blocks);
    xmlMemSetup(saved_free, saved_malloc, saved_realloc, saved_strdup);
    puts("memory tests passed");
    return 0;
}
