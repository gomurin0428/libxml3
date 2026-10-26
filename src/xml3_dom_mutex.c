#include <pthread.h>

static pthread_mutex_t dom_mutex = PTHREAD_MUTEX_INITIALIZER;

int xml3_dom_mutex_lock(void) {
    return pthread_mutex_lock(&dom_mutex);
}

int xml3_dom_mutex_unlock(void) {
    return pthread_mutex_unlock(&dom_mutex);
}
