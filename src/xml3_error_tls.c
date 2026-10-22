#include <pthread.h>
#include <libxml/xmlerror.h>

#if defined(__GNUC__) || defined(__clang__)
#define XML3_INTERNAL __attribute__((visibility("hidden")))
#else
#define XML3_INTERNAL
#endif

extern void xml3_errors__destroy_state(void *state);

static pthread_key_t xml3_error_key;
static pthread_once_t xml3_error_once = PTHREAD_ONCE_INIT;
static int xml3_error_key_ready;
static _Thread_local xmlError xml3_error_emergency_record;

static void xml3_error_destroy(void *state) {
    if (state != 0) {
        xml3_errors__destroy_state(state);
    }
}

static void xml3_error_init(void) {
    xml3_error_key_ready =
        pthread_key_create(&xml3_error_key, xml3_error_destroy) == 0;
}

XML3_INTERNAL void *xml3ErrorsTLSGet(void) {
    if (pthread_once(&xml3_error_once, xml3_error_init) != 0 ||
        !xml3_error_key_ready) {
        return 0;
    }
    return pthread_getspecific(xml3_error_key);
}

XML3_INTERNAL int xml3ErrorsTLSSet(void *state) {
    if (pthread_once(&xml3_error_once, xml3_error_init) != 0 ||
        !xml3_error_key_ready) {
        return -1;
    }
    return pthread_setspecific(xml3_error_key, state);
}

XML3_INTERNAL void *xml3ErrorsEmergencyRecord(void) {
    return &xml3_error_emergency_record;
}
