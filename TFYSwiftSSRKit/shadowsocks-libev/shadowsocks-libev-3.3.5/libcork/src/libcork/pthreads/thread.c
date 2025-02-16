/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2013-2015, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#if defined(__linux)
/* This is needed on Linux to get the pthread_setname_np function. */
#if !defined(_GNU_SOURCE)
#define _GNU_SOURCE 1
#endif
#endif

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdatomic.h>

#include "libcork/core/allocator.h"
#include "libcork/core/callbacks.h"
#include "libcork/core/hash.h"
#include "libcork/core/types.h"
#include "libcork/ds/buffer.h"
#include "libcork/threads/basics.h"

struct cork_thread_descriptor {
    struct cork_thread *thread;
    cork_thread_id id;
};

static _Atomic unsigned int last_thread_descriptor = 0;

cork_tls(struct cork_thread_descriptor, cork_thread_descriptor)

struct cork_thread {
    const char *name;
    void *user_data;
    cork_free_f free_user_data;
    cork_run_f run;
    cork_thread_id id;
    bool started;
    bool joined;
    pthread_t thread_id;
};

struct cork_thread *
cork_current_thread_get(void)
{
    struct cork_thread_descriptor *desc = cork_thread_descriptor__get();
    return desc->thread;
}

cork_thread_id
cork_current_thread_get_id(void)
{
    struct cork_thread_descriptor *desc = cork_thread_descriptor__get();
    return desc->id;
}

struct cork_thread *
cork_thread_new(const char *name,
                void *user_data, cork_free_f free_user_data,
                cork_run_f run)
{
    struct cork_thread *self = cork_new(struct cork_thread);
    self->name = cork_strdup(name);
    self->user_data = user_data;
    self->free_user_data = free_user_data;
    self->run = run;
    self->id = atomic_fetch_add(&last_thread_descriptor, 1) + 1;
    self->started = false;
    self->joined = false;
    return self;
}

void
cork_thread_free(struct cork_thread *self)
{
    if (self->started && !self->joined) {
        cork_thread_join(self);
    }
    if (self->free_user_data != NULL) {
        self->free_user_data(self->user_data);
    }
    cork_strfree(self->name);
    cork_delete(struct cork_thread, self);
}

const char *
cork_thread_get_name(struct cork_thread *self)
{
    return self->name;
}

cork_thread_id
cork_thread_get_id(struct cork_thread *self)
{
    return self->id;
}

static void *
cork_thread_body(void *self_)
{
    struct cork_thread *self = self_;
    struct cork_thread_descriptor *desc = cork_thread_descriptor__get();
    desc->thread = self;
    self->run(self->user_data);
    return NULL;
}

int
cork_thread_start(struct cork_thread *self)
{
    int rc;
    assert(!self->started);
    assert(!self->joined);
    rc = pthread_create(&self->thread_id, NULL, cork_thread_body, self);
    if (rc == 0) {
        self->started = true;
        return 0;
    } else {
        return rc;
    }
}

int
cork_thread_join(struct cork_thread *self)
{
    int rc;
    assert(self->started);
    assert(!self->joined);
    rc = pthread_join(self->thread_id, NULL);
    if (rc == 0) {
        self->joined = true;
        return 0;
    } else {
        return rc;
    }
}
