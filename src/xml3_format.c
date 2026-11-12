/* xmlStrPrintf and xmlStrVPrintf: printf formatting into a caller's
 * buffer.  Variable arguments cannot cross into Ada, so this thin trusted
 * shim keeps libxml2 2.15.4's checks (a NULL buffer or format, or a
 * length of 0 or less, answers -1) and calls vsnprintf, whose result
 * (the length the output would have, or a negative error) is returned. */
#include <stdarg.h>
#include <stdio.h>

typedef unsigned char xml3_char;

int xmlStrVPrintf(xml3_char *buf, int len, const char *msg, va_list ap) {
    int ret;

    if (buf == NULL || msg == NULL || len <= 0)
        return -1;
    ret = vsnprintf((char *)buf, (size_t)len, msg, ap);
    buf[len - 1] = 0;
    return ret;
}

int xmlStrPrintf(xml3_char *buf, int len, const char *msg, ...) {
    va_list args;
    int ret;

    if (buf == NULL || msg == NULL || len <= 0)
        return -1;
    va_start(args, msg);
    ret = vsnprintf((char *)buf, (size_t)len, msg, args);
    va_end(args);
    buf[len - 1] = 0;
    return ret;
}
