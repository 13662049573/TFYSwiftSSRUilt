/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_GC_H
#define LIBCORK_CORE_GC_H

#include <stdatomic.h>
#include <libcork/core/api.h>
#include <libcork/core/attributes.h>
#include <libcork/core/types.h>
#include <libcork/ds/dllist.h>

struct cork_gc_object {
    /* The reference count for this object */
    _Atomic unsigned int ref_count;
    /* A list of all incoming references to this object */
    struct cork_dllist incoming;
    /* Used to track this object in the garbage collector's lists */
    struct cork_dllist_item allocation;
};

struct cork_gc_edge {
    /* The source object of this edge */
    struct cork_gc_object *source;
    /* Used to include this edge in a target object's incoming list */
    struct cork_dllist_item edge;
};

/* Initialize a new garbage-collected object */
CORK_API void
cork_gc_init_object(struct cork_gc_object *obj);

/* Increment an object's reference count */
CORK_API struct cork_gc_object *
cork_gc_incref(struct cork_gc_object *obj);

/* Decrement an object's reference count */
CORK_API void
cork_gc_decref(struct cork_gc_object *obj);

/* Add a new edge between two objects */
CORK_API void
cork_gc_add_edge(struct cork_gc_edge *edge,
                struct cork_gc_object *source,
                struct cork_gc_object *target);

/* Remove an edge between two objects */
CORK_API void
cork_gc_remove_edge(struct cork_gc_edge *edge);

#endif /* LIBCORK_CORE_GC_H */
