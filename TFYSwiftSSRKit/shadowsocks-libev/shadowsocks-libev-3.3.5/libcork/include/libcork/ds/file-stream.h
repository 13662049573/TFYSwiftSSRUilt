/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_DS_FILE_STREAM_H
#define LIBCORK_DS_FILE_STREAM_H

#include <stdio.h>
#include <libcork/core/api.h>
#include <libcork/core/types.h>
#include <libcork/ds/stream.h>

#ifdef __cplusplus
extern "C" {
#endif

/* A stream implementation that reads from or writes to a FILE* stream. */
struct cork_file_stream;

/* Create a new stream that reads from a FILE* stream.  The file stream must
 * have been opened in read mode.  The file will be closed when the stream is
 * freed. */
CORK_API struct cork_stream_consumer *
cork_file_stream_consumer_new(FILE *fp);

/* Create a new stream that writes to a FILE* stream.  The file stream must
 * have been opened in write mode.  The file will be closed when the stream
 * is freed. */
CORK_API struct cork_stream_consumer *
cork_file_stream_consumer_new_write(FILE *fp);

/* Create a new stream that reads from a file given its name.  Returns NULL
 * if the file can't be opened. */
CORK_API struct cork_stream_consumer *
cork_file_stream_consumer_new_from_path(const char *path);

/* Create a new stream that writes to a file given its name.  Returns NULL if
 * the file can't be opened. */
CORK_API struct cork_stream_consumer *
cork_file_stream_consumer_new_from_path_write(const char *path);

#ifdef __cplusplus
}
#endif

#endif /* LIBCORK_DS_FILE_STREAM_H */ 