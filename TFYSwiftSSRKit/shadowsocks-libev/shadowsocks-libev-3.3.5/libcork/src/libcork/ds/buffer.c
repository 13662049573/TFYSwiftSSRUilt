/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011-2014, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

#include "libcork/core/allocator.h"
#include "libcork/core/types.h"
#include "libcork/core/error.h"
#include "libcork/core/container.h"
#include "libcork/ds/buffer.h"
#include "libcork/ds/managed-buffer.h"
#include "libcork/ds/stream.h"
#include "libcork/helpers/errors.h"

#define BUFFER_DEFAULT_SIZE  16

void
cork_buffer_init(struct cork_buffer *buffer)
{
    buffer->buf = NULL;
    buffer->size = 0;
    buffer->allocated_size = 0;
}

struct cork_buffer *
cork_buffer_new(void)
{
    struct cork_buffer  *buffer = cork_new(struct cork_buffer);
    cork_buffer_init(buffer);
    return buffer;
}

void
cork_buffer_done(struct cork_buffer *buffer)
{
    if (buffer->buf != NULL) {
        cork_free(buffer->buf, buffer->allocated_size);
        buffer->buf = NULL;
        buffer->size = 0;
        buffer->allocated_size = 0;
    }
}

void
cork_buffer_free(struct cork_buffer *buffer)
{
    cork_buffer_done(buffer);
    cork_delete(struct cork_buffer, buffer);
}

bool
cork_buffer_equal(const struct cork_buffer *buffer1,
                  const struct cork_buffer *buffer2)
{
    if (buffer1->size != buffer2->size) {
        return false;
    }

    if (buffer1->size == 0) {
        return true;
    }

    return (memcmp(buffer1->buf, buffer2->buf, buffer1->size) == 0);
}

void
cork_buffer_ensure_size(struct cork_buffer *buffer, size_t desired_size)
{
    size_t  new_size;

    /* If we've got a big enough buffer, don't adjust it. */
    if (desired_size <= buffer->allocated_size) {
        return;
    }

    /* Figure out how big the new buffer should be */
    if (buffer->allocated_size == 0) {
        new_size = BUFFER_DEFAULT_SIZE;
    } else {
        new_size = buffer->allocated_size;
    }

    while (new_size < desired_size) {
        new_size *= 2;
    }

    /* Allocate the new buffer and copy the existing contents into it. */
    if (buffer->buf == NULL) {
        buffer->buf = cork_malloc(new_size);
    } else {
        buffer->buf = cork_realloc(buffer->buf, buffer->allocated_size, new_size);
    }

    buffer->allocated_size = new_size;
}

void
cork_buffer_clear(struct cork_buffer *buffer)
{
    buffer->size = 0;
}

void
cork_buffer_truncate(struct cork_buffer *buffer, size_t length)
{
    buffer->size = length;
}

void
cork_buffer_set(struct cork_buffer *buffer, const void *src, size_t length)
{
    /* Make sure the buffer is big enough to hold the new content. */
    cork_buffer_ensure_size(buffer, length);

    /* If there's any content to copy in, do so. */
    if (length > 0) {
        memcpy(buffer->buf, src, length);
    }

    buffer->size = length;
}

void
cork_buffer_append(struct cork_buffer *buffer, const void *src, size_t length)
{
    /* Make sure the buffer is big enough to hold the new content. */
    cork_buffer_ensure_size(buffer, buffer->size + length);

    /* If there's any content to copy in, do so. */
    if (length > 0) {
        memcpy(buffer->buf + buffer->size, src, length);
    }

    buffer->size += length;
}

void
cork_buffer_set_string(struct cork_buffer *buffer, const char *str)
{
    cork_buffer_set(buffer, str, strlen(str));
}

void
cork_buffer_append_string(struct cork_buffer *buffer, const char *str)
{
    cork_buffer_append(buffer, str, strlen(str));
}

void
cork_buffer_append_vprintf(struct cork_buffer *buffer, const char *format,
                           va_list args)
{
    size_t  available = buffer->allocated_size - buffer->size;
    int  count;
    va_list  args_copy;

    /* Try to write the formatted string into the buffer as it exists. */
    va_copy(args_copy, args);
    count = vsnprintf(buffer->buf + buffer->size, available, format, args_copy);
    va_end(args_copy);

    /* If the buffer is too small, resize it and try again. */
    if (count >= (int) available) {
        cork_buffer_ensure_size(buffer, buffer->size + count + 1);
        available = buffer->allocated_size - buffer->size;
        count = vsnprintf(buffer->buf + buffer->size, available, format, args);
    }

    /* Update the size of the buffer. */
    buffer->size += count;
}

void
cork_buffer_vprintf(struct cork_buffer *buffer, const char *format,
                    va_list args)
{
    buffer->size = 0;
    cork_buffer_append_vprintf(buffer, format, args);
}

void
cork_buffer_append_printf(struct cork_buffer *buffer, const char *format, ...)
{
    va_list  args;
    va_start(args, format);
    cork_buffer_append_vprintf(buffer, format, args);
    va_end(args);
}

void
cork_buffer_printf(struct cork_buffer *buffer, const char *format, ...)
{
    va_list  args;
    va_start(args, format);
    cork_buffer_vprintf(buffer, format, args);
    va_end(args);
}

void
cork_buffer_append_hex_dump(struct cork_buffer *buffer, size_t indent,
                           const char *src, size_t length)
{
    const uint8_t  *src_bytes = (const uint8_t *)src;
    size_t  i;
    
    /* Add the initial indent */
    for (i = 0; i < indent; i++) {
        cork_buffer_append(buffer, " ", 1);
    }
    
    /* Add the hex dump */
    for (i = 0; i < length; i++) {
        uint8_t  byte = src_bytes[i];
        char format[32];
        snprintf(format, sizeof(format), "\\x%%02%s", PRIx8);
        cork_buffer_append_printf(buffer, format, byte);
    }
}

void
cork_buffer_append_indent(struct cork_buffer *buffer, size_t indent)
{
    size_t  i;
    for (i = 0; i < indent; i++) {
        cork_buffer_append(buffer, " ", 1);
    }
}

void
cork_buffer_append_c_string(struct cork_buffer *buffer,
                           const char *src, size_t length)
{
    size_t  i;
    cork_buffer_append(buffer, "\"", 1);
    for (i = 0; i < length; i++) {
        char  ch = src[i];
        switch (ch) {
            case '\"':
                cork_buffer_append_literal(buffer, "\\\"");
                break;
            case '\\':
                cork_buffer_append_literal(buffer, "\\\\");
                break;
            case '\f':
                cork_buffer_append_literal(buffer, "\\f");
                break;
            case '\n':
                cork_buffer_append_literal(buffer, "\\n");
                break;
            case '\r':
                cork_buffer_append_literal(buffer, "\\r");
                break;
            case '\t':
                cork_buffer_append_literal(buffer, "\\t");
                break;
            case '\v':
                cork_buffer_append_literal(buffer, "\\v");
                break;
            default:
                if (ch >= 0x20 && ch <= 0x7e) {
                    cork_buffer_append(buffer, &src[i], 1);
                } else {
                    uint8_t  byte = ch;
                    char format[32];
                    snprintf(format, sizeof(format), "\\x%%02%s", PRIx8);
                    cork_buffer_append_printf(buffer, format, byte);
                }
                break;
        }
    }
    cork_buffer_append(buffer, "\"", 1);
}

void
cork_buffer_append_multiline(struct cork_buffer *buffer, size_t indent,
                            const char *src, size_t length)
{
    size_t  i;
    for (i = 0; i < length; i++) {
        char  ch = src[i];
        if (ch == '\n') {
            cork_buffer_append_literal(buffer, "\n");
            cork_buffer_append_indent(buffer, indent);
        } else {
            cork_buffer_append(buffer, &src[i], 1);
        }
    }
}

void
cork_buffer_append_binary(struct cork_buffer *buffer, size_t indent,
                         const char *src, size_t length)
{
    size_t  i;
    bool  newline = false;

    /* If there are any non-printable characters, print out a hex dump */
    for (i = 0; i < length; i++) {
        if ((src[i] <= 0x20 || src[i] > 0x7e) && src[i] != '\n') {
            cork_buffer_append_literal(buffer, "(hex)\n");
            cork_buffer_append_indent(buffer, indent);
            cork_buffer_append_hex_dump(buffer, indent, src, length);
            return;
        } else if (src[i] == '\n') {
            newline = true;
            /* Don't immediately use the multiline format, since there might be
             * a non-printable character later on that kicks us over to the hex
             * dump format. */
        }
    }

    if (newline) {
        cork_buffer_append_literal(buffer, "(multiline)\n");
        cork_buffer_append_indent(buffer, indent);
        cork_buffer_append_multiline(buffer, indent, src, length);
    } else {
        cork_buffer_append(buffer, src, length);
    }
}

struct cork_buffer__managed_buffer {
    /* must be first! */
    struct cork_managed_buffer  parent;
    /* A copy of the buffer's contents.  The struct cork_managed_buffer
     * header will point at this content. */
    char  content[];
};

struct cork_managed_buffer *
cork_buffer_to_managed_buffer(struct cork_buffer *buffer)
{
    size_t  size = buffer->size;
    struct cork_buffer__managed_buffer  *managed_buffer;

    managed_buffer = cork_malloc(sizeof(struct cork_buffer__managed_buffer) +
                                size);
    managed_buffer->parent.buf = managed_buffer->content;
    managed_buffer->parent.size = size;
    managed_buffer->parent.ref_count = 1;
    managed_buffer->parent.iface = NULL;  /* No interface needed */
    memcpy(managed_buffer->content, buffer->buf, size);
    return &managed_buffer->parent;
}

struct cork_buffer__stream_consumer {
    /* must be first! */
    struct cork_stream_consumer  consumer;
    /* The buffer to fill in */
    struct cork_buffer  *buffer;
    /* Whether the buffer should be cleared before filling it in */
    bool  clear_first;
};

static int
cork_buffer__stream_consumer_data(struct cork_stream_consumer *consumer,
                                  const void *buf, size_t size, bool is_first_chunk)
{
    struct cork_buffer__stream_consumer  *bconsumer =
        cork_container_of(consumer, struct cork_buffer__stream_consumer, consumer);
    if (is_first_chunk && bconsumer->clear_first) {
        cork_buffer_clear(bconsumer->buffer);
    }
    cork_buffer_append(bconsumer->buffer, buf, size);
    return 0;
}

static int
cork_buffer__stream_consumer_eof(struct cork_stream_consumer *consumer)
{
    struct cork_buffer__stream_consumer  *bconsumer =
        cork_container_of(consumer, struct cork_buffer__stream_consumer, consumer);
    cork_delete(struct cork_buffer__stream_consumer, bconsumer);
    return 0;
}

struct cork_stream_consumer *
cork_buffer_to_stream_consumer(struct cork_buffer *buffer)
{
    struct cork_buffer__stream_consumer  *bconsumer =
        cork_new(struct cork_buffer__stream_consumer);
    bconsumer->consumer.data = cork_buffer__stream_consumer_data;
    bconsumer->consumer.eof = cork_buffer__stream_consumer_eof;
    bconsumer->buffer = buffer;
    bconsumer->clear_first = true;
    return &bconsumer->consumer;
}

struct cork_stream_consumer *
cork_buffer_to_stream_appender(struct cork_buffer *buffer)
{
    struct cork_buffer__stream_consumer  *bconsumer =
        cork_new(struct cork_buffer__stream_consumer);
    bconsumer->consumer.data = cork_buffer__stream_consumer_data;
    bconsumer->consumer.eof = cork_buffer__stream_consumer_eof;
    bconsumer->buffer = buffer;
    bconsumer->clear_first = false;
    return &bconsumer->consumer;
}
