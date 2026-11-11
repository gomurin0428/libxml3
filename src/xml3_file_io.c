/* Native file output for xmlSaveFile, xmlDocDump and xmlElemDump.  The
 * bytes, the path and whether standard output is meant are decided by the
 * SPARK serializer and path planner; this file only performs the system
 * calls, as libxml2's default output callbacks do (open with O_CREAT and
 * O_TRUNC, mode 0666; a dup of standard output for "-"). */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <unistd.h>

#if defined(__GNUC__) || defined(__clang__)
#define XML3_INTERNAL __attribute__((visibility("hidden")))
#else
#define XML3_INTERNAL
#endif

static long write_all(int fd, const char *data, size_t length) {
    size_t done = 0;

    while (done < length) {
        ssize_t written = write(fd, data + done, length - done);

        if (written < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        done += (size_t)written;
    }
    return length > (size_t)0x7fffffff ? 0x7fffffff : (long)length;
}

/* Writes length bytes to path, or to standard output when standard_output
 * is nonzero.  Returns the byte count, or -1 when the file cannot be
 * opened, written or closed. */
XML3_INTERNAL long xml3FileWritePath(const char *path, int standard_output,
                                     const void *data, size_t length) {
    int fd;
    long result;

    if (standard_output)
        fd = dup(STDOUT_FILENO);
    else if (path == NULL)
        return -1;
    else
        fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0)
        return -1;
    result = write_all(fd, (const char *)data, length);
    if (close(fd) < 0)
        result = -1;
    return result;
}

/* Writes length bytes to a caller's FILE and flushes it.  Returns the byte
 * count, or -1 for a NULL stream or a write error. */
XML3_INTERNAL long xml3FileWriteStream(void *stream, const void *data,
                                       size_t length) {
    FILE *file = (FILE *)stream;

    if (file == NULL)
        return -1;
    if (length > 0 && fwrite(data, 1, length, file) != length)
        return -1;
    if (fflush(file) != 0)
        return -1;
    return length > (size_t)0x7fffffff ? 0x7fffffff : (long)length;
}

/* The standard output stream, for xmlBufferDump with a NULL stream. */
XML3_INTERNAL void *xml3FileStandardOutput(void) {
    return stdout;
}
