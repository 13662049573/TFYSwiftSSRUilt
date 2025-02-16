/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2012-2014, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_THREADS_BASICS_H
#define LIBCORK_THREADS_BASICS_H

#include <assert.h>
#include <stdlib.h>
#include <pthread.h>

#include <libcork/core/api.h>
#include <libcork/core/attributes.h>
#include <libcork/core/callbacks.h>
#include <libcork/threads/atomics.h>

/* CPU pause for spin-wait loops */
#if defined(__APPLE__)
#if defined(__arm64__)
#define cork_pause() \
    do { \
        __asm__ volatile("yield" ::: "memory"); \
    } while (0)
#else
#define cork_pause() \
    do { \
        __asm__ volatile("pause" ::: "memory"); \
    } while (0)
#endif
#else
#define cork_pause() do { } while (0)
#endif

#if defined(__APPLE__)
/* Thread-local storage */
#define cork_tls(TYPE, NAME) \
    static pthread_key_t NAME##__key; \
    static void NAME##__destroy(void *val) { free(val); } \
    static void NAME##__init(void) { \
        pthread_key_create(&NAME##__key, NAME##__destroy); \
    } \
    static TYPE *NAME##__get(void) { \
        static pthread_once_t NAME##__once = PTHREAD_ONCE_INIT; \
        pthread_once(&NAME##__once, NAME##__init); \
        void *val = pthread_getspecific(NAME##__key); \
        if (CORK_UNLIKELY(val == NULL)) { \
            val = calloc(1, sizeof(TYPE)); \
            pthread_setspecific(NAME##__key, val); \
        } \
        return val; \
    }

/* One-time initialization */
#define cork_once(NAME, INIT) \
    do { \
        static pthread_once_t NAME##__once = PTHREAD_ONCE_INIT; \
        pthread_once(&NAME##__once, INIT); \
    } while (0)

/* Barrier implementation */
#define cork_once_barrier(name) \
    static pthread_once_t name##__once = PTHREAD_ONCE_INIT

#else
#error "No thread-local storage implementation!"
#endif

/* Thread IDs */
typedef unsigned int  cork_thread_id;
#define CORK_THREAD_NONE  ((cork_thread_id) 0)

/* Returns a valid ID for any thread */
CORK_API cork_thread_id
cork_current_thread_get_id(void);

/* Thread management */
struct cork_thread;

CORK_API struct cork_thread *
cork_current_thread_get(void);

CORK_API struct cork_thread *
cork_thread_new(const char *name,
                void *user_data, cork_free_f free_user_data,
                cork_run_f run);

CORK_API void
cork_thread_free(struct cork_thread *thread);

CORK_API const char *
cork_thread_get_name(struct cork_thread *thread);

CORK_API cork_thread_id
cork_thread_get_id(struct cork_thread *thread);

CORK_API int
cork_thread_start(struct cork_thread *thread);

CORK_API int
cork_thread_join(struct cork_thread *thread);

#endif /* LIBCORK_THREADS_BASICS_H */
