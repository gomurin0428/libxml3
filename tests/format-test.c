/* xmlStrPrintf and xmlStrVPrintf.  The output of this program is compared
 * between libxml3 and the pinned reference libxml2 (make test-format). */
#include <libxml/xmlstring.h>

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

static int vformat(xmlChar *buf, int len, const char *msg, ...) {
    va_list ap;
    int ret;

    va_start(ap, msg);
    ret = xmlStrVPrintf(buf, len, msg, ap);
    va_end(ap);
    return ret;
}

int main(void) {
    xmlChar buf[16];
    int ret;

    memset(buf, '#', sizeof(buf));
    ret = xmlStrPrintf(buf, sizeof(buf), "%s-%d-%c", "ab", 42, 'z');
    printf("fits: %d \"%s\"\n", ret, (const char *)buf);
    memset(buf, '#', sizeof(buf));
    ret = xmlStrPrintf(buf, 6, "%s", "truncated text");
    printf("truncated: %d \"%s\" next=%c\n", ret, (const char *)buf, buf[6]);
    memset(buf, '#', sizeof(buf));
    ret = xmlStrPrintf(buf, 1, "%d", 12345);
    printf("one byte: %d empty=%d next=%c\n", ret, buf[0] == 0, buf[1]);
    printf("zero length: %d\n", xmlStrPrintf(buf, 0, "x"));
    printf("negative length: %d\n", xmlStrPrintf(buf, -1, "x"));
    printf("null buffer: %d\n", xmlStrPrintf(NULL, 4, "x"));
    printf("null format: %d\n", xmlStrPrintf(buf, 4, NULL));
    memset(buf, '#', sizeof(buf));
    ret = vformat(buf, sizeof(buf), "%05.1f|%x", 3.25, 255);
    printf("vprintf: %d \"%s\"\n", ret, (const char *)buf);
    ret = vformat(buf, 4, "%s", "abcdef");
    printf("vprintf truncated: %d \"%s\"\n", ret, (const char *)buf);
    printf("vprintf null: %d %d %d\n", vformat(NULL, 4, "x"),
           vformat(buf, 4, NULL), vformat(buf, 0, "x"));
    puts("format tests passed");
    return 0;
}
