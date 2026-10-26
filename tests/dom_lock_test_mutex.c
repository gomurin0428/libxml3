#include <errno.h>

static int lock_count;
static int unlock_count;
static int fail_lock;
static int fail_unlock;

void dom_lock_test_reset(void) {
    lock_count = 0;
    unlock_count = 0;
    fail_lock = 0;
    fail_unlock = 0;
}

void dom_lock_test_fail_next_lock(void) {
    fail_lock = 1;
}

void dom_lock_test_fail_next_unlock(void) {
    fail_unlock = 1;
}

int dom_lock_test_lock_count(void) {
    return lock_count;
}

int dom_lock_test_unlock_count(void) {
    return unlock_count;
}

int xml3_dom_mutex_lock(void) {
    ++lock_count;
    if (fail_lock) {
        fail_lock = 0;
        return EBUSY;
    }
    return 0;
}

int xml3_dom_mutex_unlock(void) {
    ++unlock_count;
    if (fail_unlock) {
        fail_unlock = 0;
        return EBUSY;
    }
    return 0;
}
