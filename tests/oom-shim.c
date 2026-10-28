#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

extern void *__libc_malloc(size_t size);
extern void __libc_free(void *ptr);

static _Atomic long fail_index = -1;
static _Atomic long allocation_index = 0;
static _Atomic int failure_injected = 0;
static _Atomic uintptr_t watched_address = 0;
static _Atomic int watched_free_count = 0;

void xml3_oom_watch_free(const void *ptr) {
    atomic_store(&watched_address, (uintptr_t)ptr);
    atomic_store(&watched_free_count, 0);
}

int xml3_oom_free_count(void) {
    return atomic_load(&watched_free_count);
}

void free(void *ptr) {
    if (ptr && (uintptr_t)ptr == atomic_load(&watched_address))
        atomic_fetch_add(&watched_free_count, 1);
    __libc_free(ptr);
}

void xml3_oom_enable(long index) {
    atomic_store(&allocation_index, 0);
    atomic_store(&failure_injected, 0);
    atomic_store(&fail_index, index);
}

void xml3_oom_disable(void) {
    atomic_store(&fail_index, -1);
}

long xml3_oom_count(void) {
    return atomic_load(&allocation_index);
}

int xml3_oom_was_injected(void) {
    return atomic_load(&failure_injected);
}

void *malloc(size_t size) {
    long index = atomic_load(&fail_index);
    if (index >= 0) {
        long current = atomic_fetch_add(&allocation_index, 1);
        if (current == index) {
            atomic_store(&failure_injected, 1);
            return NULL;
        }
    }
    return __libc_malloc(size);
}
