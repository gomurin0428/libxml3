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

static int io_code(int err);

/* A failed write or close answers the negated XML_IO_* code of errno, as
 * xmlOutputBufferClose does. */
static long write_all(int fd, const char *data, size_t length) {
    size_t done = 0;

    while (done < length) {
        ssize_t written = write(fd, data + done, length - done);

        if (written < 0) {
            if (errno == EINTR)
                continue;
            return -io_code(errno);
        }
        done += (size_t)written;
    }
    return length > (size_t)0x7fffffff ? 0x7fffffff : (long)length;
}

/* Writes length bytes to path, or to standard output when standard_output
 * is nonzero.  Returns the byte count, -1 when the file cannot be opened
 * (libxml2 creates no output buffer then), or the negated XML_IO_* code
 * when writing or closing fails. */
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
    if (close(fd) < 0 && result >= 0)
        result = -io_code(errno);
    return result;
}

/* Opens the output of a save context, as xmlSaveToFilename does: the file
 * created or truncated with mode 0666, or a dup of standard output.
 * Returns the descriptor, or -1 when it cannot be opened (libxml2 creates
 * no context then and reports nothing). */
XML3_INTERNAL int xml3FileOpenWrite(const char *path, int standard_output) {
    if (standard_output)
        return dup(STDOUT_FILENO);
    if (path == NULL)
        return -1;
    return open(path, O_WRONLY | O_CREAT | O_TRUNC, 0666);
}

/* xmlFdWrite: writes all length bytes; returns length or the negated
 * XML_IO_* code of the first failure. */
XML3_INTERNAL int xml3FdWrite(int fd, const void *data, int length) {
    const char *at = (const char *)data;
    int done = 0;

    while (done < length) {
        ssize_t written = write(fd, at + done, (size_t)(length - done));

        if (written < 0) {
            if (errno == EINTR)
                continue;
            return -io_code(errno);
        }
        done += (int)written;
    }
    return done;
}

/* xmlFdClose: 0, or the XML_IO_* code of a failed close. */
XML3_INTERNAL int xml3FdClose(int fd) {
    if (close(fd) < 0)
        return io_code(errno);
    return 0;
}

/* Writes length bytes to a caller's FILE and flushes it.  Returns the byte
 * count, -1 for a NULL stream, or the negated XML_IO_* code of a write or
 * flush error. */
XML3_INTERNAL long xml3FileWriteStream(void *stream, const void *data,
                                       size_t length) {
    FILE *file = (FILE *)stream;

    if (file == NULL)
        return -1;
    if (length > 0 && fwrite(data, 1, length, file) != length)
        return -io_code(errno);
    if (fflush(file) != 0)
        return -io_code(errno);
    return length > (size_t)0x7fffffff ? 0x7fffffff : (long)length;
}

/* xmlFileWrite: writes length bytes to a caller's FILE; the length, or
 * the negated XML_IO_* code of a short write. */
XML3_INTERNAL int xml3StreamWrite(void *stream, const void *data,
                                  int length) {
    size_t written;

    if (stream == NULL || data == NULL)
        return -1;
    errno = 0;
    written = fwrite(data, 1, (size_t)length, (FILE *)stream);
    if (written < (size_t)length)
        return -io_code(errno);
    return length;
}

/* xmlFileFlush: 0, or the XML_IO_* code of a failed fflush. */
XML3_INTERNAL int xml3StreamFlush(void *stream) {
    if (stream == NULL)
        return -1;
    if (fflush((FILE *)stream) != 0)
        return io_code(errno);
    return 0;
}

/* The standard output stream, for xmlBufferDump with a NULL stream. */
XML3_INTERNAL void *xml3FileStandardOutput(void) {
    return stdout;
}

#include <stdlib.h>
#include <string.h>

void *xml3MemAllocate(size_t size);
void *xml3MemReallocate(void *block, size_t size);
void xml3MemRelease(void *block);

/* xmlIOErr: the XML_IO_* code of libxml2 2.15.4 for an errno value. */
static int io_code(int err) {
    switch (err) {
    case EACCES: return 1501;
    case EAGAIN: return 1502;
    case EBADF: return 1503;
    case EBADMSG: return 1504;
    case EBUSY: return 1505;
    case ECANCELED: return 1506;
    case ECHILD: return 1507;
    case EDEADLK: return 1508;
    case EDOM: return 1509;
    case EEXIST: return 1510;
    case EFAULT: return 1511;
    case EFBIG: return 1512;
    case EINPROGRESS: return 1513;
    case EINTR: return 1514;
    case EINVAL: return 1515;
    case EIO: return 1516;
    case EISDIR: return 1517;
    case EMFILE: return 1518;
    case EMLINK: return 1519;
    case EMSGSIZE: return 1520;
    case ENAMETOOLONG: return 1521;
    case ENFILE: return 1522;
    case ENODEV: return 1523;
    case ENOENT: return 1524;
    case ENOEXEC: return 1525;
    case ENOLCK: return 1526;
    case ENOMEM: return 1527;
    case ENOSPC: return 1528;
    case ENOSYS: return 1529;
    case ENOTDIR: return 1530;
    case ENOTEMPTY: return 1531;
    case ENOTSUP: return 1532;
    case ENOTTY: return 1533;
    case ENXIO: return 1534;
    case EPERM: return 1535;
    case EPIPE: return 1536;
    case ERANGE: return 1537;
    case EROFS: return 1538;
    case ESPIPE: return 1539;
    case ESRCH: return 1540;
    case ETIMEDOUT: return 1541;
    case EXDEV: return 1542;
    case ENOTSOCK: return 1550;
    case EISCONN: return 1551;
    case ECONNREFUSED: return 1552;
    case ENETUNREACH: return 1553;
    case EADDRINUSE: return 1554;
    case EALREADY: return 1555;
    case EAFNOSUPPORT: return 1556;
    default: return 1500;
    }
}

/* Reads a whole file (or standard input) into a new allocation, as
 * libxml2's default input callback does.  Returns 0 with the bytes in
 * *data (to be freed by the caller) and their count in *length; -1 when an
 * allocation fails; otherwise the XML_IO_* code, with *read_stage set to
 * 0 when opening failed and 1 when reading failed; -2 as soon as the
 * input exceeds limit bytes, before reading further.  Opening reports ENOENT
 * and EINVAL as XML_IO_ENOENT, as xmlFdOpen does. */
XML3_INTERNAL int xml3FileReadPath(const char *path, int standard_input,
                                   size_t limit, void **data, size_t *length,
                                   int *read_stage) {
    int fd;
    size_t size = 0, capacity = 4096;
    char *buffer;

    *data = NULL;
    *length = 0;
    *read_stage = 0;
    if (standard_input)
        fd = dup(STDIN_FILENO);
    else
        fd = open(path, O_RDONLY);
    if (fd < 0) {
        int err = errno;
        if (!standard_input && (err == ENOENT || err == EINVAL))
            return 1524;
        return io_code(err);
    }
    *read_stage = 1;
    buffer = xml3MemAllocate(capacity);
    if (buffer == NULL) {
        close(fd);
        return -1;
    }
    for (;;) {
        ssize_t count;

        if (size == capacity) {
            char *grown;

            if (capacity > ((size_t)-1) / 2) {
                xml3MemRelease(buffer);
                close(fd);
                return -1;
            }
            grown = xml3MemReallocate(buffer, capacity * 2);
            if (grown == NULL) {
                xml3MemRelease(buffer);
                close(fd);
                return -1;
            }
            buffer = grown;
            capacity *= 2;
        }
        count = read(fd, buffer + size, capacity - size);
        if (count < 0) {
            int err = errno;
            if (err == EINTR)
                continue;
            xml3MemRelease(buffer);
            close(fd);
            return io_code(err);
        }
        if (count == 0)
            break;
        size += (size_t)count;
        if (size > limit) {
            xml3MemRelease(buffer);
            close(fd);
            return -2;
        }
    }
    close(fd);
    *data = buffer;
    *length = size;
    return 0;
}

/* Input from a descriptor or from caller callbacks (xmlReadFd, xmlReadIO
 * and their context forms).  libxml2 reads its input in requests of 4000
 * bytes (MINLEN) until the read answers 0 or fails; the whole input is
 * read here the same way before the parse. */
typedef int (*xml3_input_read)(void *context, char *buffer, int length);
typedef int (*xml3_input_close)(void *context);

enum { XML3_READ_REQUEST = 4000 };

/* Reads until the source answers 0 or fails.  Returns 0 with the bytes in
 * *data (to be freed by the caller) and their count in *length, *failure
 * being the code of a failed read (0 when the input ended): -1 becomes
 * XML_IO_UNKNOWN, another negative answer is negated, as
 * xmlParserInputBufferGrow does.  Returns -1 when an allocation fails
 * and -2 as soon as the input exceeds limit bytes. */
static int read_all(xml3_input_read source, void *context, size_t limit,
                    void **data, size_t *length, int *failure) {
    size_t size = 0, capacity = XML3_READ_REQUEST;
    char *buffer = xml3MemAllocate(capacity);

    *data = NULL;
    *length = 0;
    *failure = 0;
    if (buffer == NULL)
        return -1;
    for (;;) {
        int count;

        if (capacity - size < XML3_READ_REQUEST) {
            char *grown;

            if (capacity > ((size_t)-1) / 2) {
                xml3MemRelease(buffer);
                return -1;
            }
            grown = xml3MemReallocate(buffer, capacity * 2);
            if (grown == NULL) {
                xml3MemRelease(buffer);
                return -1;
            }
            buffer = grown;
            capacity *= 2;
        }
        count = source(context, buffer + size, XML3_READ_REQUEST);
        if (count < 0) {
            *failure = count == -1 ? 1500 : -count;
            break;
        }
        if (count == 0)
            break;
        if (count > XML3_READ_REQUEST) {
            /* More than requested: libxml2 cannot add it to its buffer
             * and fails the read with XML_ERR_NO_MEMORY. */
            *failure = 2;
            break;
        }
        size += (size_t)count;
        if (size > limit) {
            xml3MemRelease(buffer);
            return -2;
        }
    }
    *data = buffer;
    *length = size;
    return 0;
}

/* xmlFdRead: fills the request unless the input ends; a failure after
 * some bytes returns them, the next read reports it. */
static int fd_read(void *context, char *buffer, int length) {
    int fd = *(int *)context;
    int done = 0;

    while (length > 0) {
        ssize_t count = read(fd, buffer, (size_t)length);

        if (count < 0) {
            if (errno == EINTR)
                continue;
            if (done > 0)
                break;
            return -io_code(errno);
        }
        if (count == 0)
            break;
        done += (int)count;
        buffer += count;
        length -= (int)count;
    }
    return done;
}

/* xmlReadFd's input: a duplicate of fd is read and closed, the caller's
 * descriptor stays open (at the position the reads left).  A failed dup
 * answers -1: libxml2 then reports a memory failure. */
XML3_INTERNAL int xml3FdReadAll(int fd, size_t limit, void **data,
                                size_t *length, int *failure) {
    int copy = dup(fd);
    int result;

    *data = NULL;
    *length = 0;
    *failure = 0;
    if (copy < 0)
        return -1;
    result = read_all(fd_read, &copy, limit, data, length, failure);
    close(copy);
    return result;
}

/* xmlReadIO's input, read with the caller's callback. */
XML3_INTERNAL int xml3IOReadAll(xml3_input_read source, void *context,
                                size_t limit, void **data, size_t *length,
                                int *failure) {
    return read_all(source, context, limit, data, length, failure);
}

/* Calls the caller's close callback, when there is one, as libxml2 does
 * when it frees the input. */
XML3_INTERNAL void xml3IOClose(xml3_input_close closer, void *context) {
    if (closer != NULL)
        closer(context);
}
