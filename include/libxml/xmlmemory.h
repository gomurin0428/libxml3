#ifndef LIBXML3_XMLMEMORY_H
#define LIBXML3_XMLMEMORY_H

#include <stddef.h>
#include <stdio.h>
#include <libxml/xmlversion.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*xmlFreeFunc)(void *mem);
typedef void *(*xmlMallocFunc)(size_t size);
typedef void *(*xmlReallocFunc)(void *mem, size_t size);
typedef char *(*xmlStrdupFunc)(const char *str);

/* The allocator of the library: every block it returns to a caller, or
 * releases for one, goes through the functions set by xmlMemSetup (the C
 * library's by default).  In libxml2 xmlFree, xmlMalloc, xmlMallocAtomic,
 * xmlRealloc and xmlMemStrdup are variables holding those functions; here
 * they are functions calling them, so they can be called but not
 * assigned. */
void xmlFree(void *mem);
void *xmlMalloc(size_t size);
void *xmlMallocAtomic(size_t size);
void *xmlRealloc(void *mem, size_t size);
char *xmlMemStrdup(const char *str);

int xmlMemSetup(xmlFreeFunc freeFunc, xmlMallocFunc mallocFunc,
                xmlReallocFunc reallocFunc, xmlStrdupFunc strdupFunc);
int xmlMemGet(xmlFreeFunc *freeFunc, xmlMallocFunc *mallocFunc,
              xmlReallocFunc *reallocFunc, xmlStrdupFunc *strdupFunc);
int xmlGcMemSetup(xmlFreeFunc freeFunc, xmlMallocFunc mallocFunc,
                  xmlMallocFunc mallocAtomicFunc, xmlReallocFunc reallocFunc,
                  xmlStrdupFunc strdupFunc);
int xmlGcMemGet(xmlFreeFunc *freeFunc, xmlMallocFunc *mallocFunc,
                xmlMallocFunc *mallocAtomicFunc, xmlReallocFunc *reallocFunc,
                xmlStrdupFunc *strdupFunc);

/* The debug allocator: libxml2's size header and usage counters. */
void *xmlMemMalloc(size_t size);
void *xmlMemRealloc(void *ptr, size_t size);
void xmlMemFree(void *ptr);
char *xmlMemoryStrdup(const char *str);
void *xmlMallocLoc(size_t size, const char *file, int line);
void *xmlMallocAtomicLoc(size_t size, const char *file, int line);
void *xmlReallocLoc(void *ptr, size_t size, const char *file, int line);
char *xmlMemStrdupLoc(const char *str, const char *file, int line);
size_t xmlMemSize(void *ptr);
int xmlMemUsed(void);
int xmlMemBlocks(void);
void xmlMemDisplayLast(FILE *fp, long nbBytes);
void xmlMemDisplay(FILE *fp);
void xmlMemShow(FILE *fp, int nr);
void xmlMemoryDump(void);
int xmlInitMemory(void);
void xmlCleanupMemory(void);

#ifdef __cplusplus
}
#endif

#endif
