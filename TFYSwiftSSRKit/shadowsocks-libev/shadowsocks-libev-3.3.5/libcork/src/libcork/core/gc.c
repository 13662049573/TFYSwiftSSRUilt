#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdatomic.h>

#include "libcork/core/allocator.h"
#include "libcork/core/callbacks.h"
#include "libcork/core/container.h"
#include "libcork/core/gc.h"
#include "libcork/core/types.h"
#include "libcork/ds/dllist.h"
#include "libcork/threads/basics.h"

struct cork_gc {
    /* The number of objects that have been allocated but not yet
     * collected. */
    size_t allocated_count;
    /* The number of objects that we've collected in the current
     * collection cycle that are still waiting to be freed. */
    size_t collected_count;
    /* A list of every object that's been allocated but not yet
     * collected. */
    struct cork_dllist allocated;
    /* A list of every object that's been collected but not yet freed. */
    struct cork_dllist collected;
    /* A list of every object that's been freed, and can be reused for
     * future allocations. */
    struct cork_dllist free;
};

static pthread_key_t cork_gc_key;
static pthread_once_t cork_gc_once = PTHREAD_ONCE_INIT;

static void
cork_gc_free_data(void *vgc)
{
    struct cork_gc  *gc = vgc;
    struct cork_dllist_item  *curr;
    struct cork_dllist_item  *next;

    for (curr = gc->allocated.head.next; curr != &gc->allocated.head; curr = next) {
        next = curr->next;
        free(curr);
    }

    for (curr = gc->collected.head.next; curr != &gc->collected.head; curr = next) {
        next = curr->next;
        free(curr);
    }

    for (curr = gc->free.head.next; curr != &gc->free.head; curr = next) {
        next = curr->next;
        free(curr);
    }

    free(gc);
}

static void
cork_gc_init(void)
{
    pthread_key_create(&cork_gc_key, cork_gc_free_data);
}

static struct cork_gc *
cork_gc_get(void)
{
    pthread_once(&cork_gc_once, cork_gc_init);
    struct cork_gc  *gc = pthread_getspecific(cork_gc_key);
    if (CORK_UNLIKELY(gc == NULL)) {
        gc = cork_calloc(1, sizeof(struct cork_gc));
        cork_dllist_init(&gc->allocated);
        cork_dllist_init(&gc->collected);
        cork_dllist_init(&gc->free);
        pthread_setspecific(cork_gc_key, gc);
    }
    return gc;
}

void
cork_gc_init_object(struct cork_gc_object *obj)
{
    obj->ref_count = 1;
    cork_dllist_init(&obj->incoming);
}

struct cork_gc_object *
cork_gc_incref(struct cork_gc_object *obj)
{
    if (CORK_LIKELY(obj != NULL)) {
        atomic_fetch_add(&obj->ref_count, 1);
    }
    return obj;
}

static void
cork_gc_decref_step(struct cork_gc *gc, struct cork_gc_object *obj)
{
    if (atomic_fetch_sub(&obj->ref_count, 1) == 1) {
        struct cork_dllist_item *curr;
        struct cork_dllist_item *next;
        for (curr = obj->incoming.head.next;
             curr != &obj->incoming.head;
             curr = next) {
            struct cork_gc_edge *edge =
                cork_container_of(curr, struct cork_gc_edge, edge);
            next = curr->next;
            cork_gc_decref_step(gc, edge->source);
        }
        cork_dllist_add(&gc->collected, &obj->allocation);
        gc->collected_count++;
    }
}

void
cork_gc_decref(struct cork_gc_object *obj)
{
    if (CORK_LIKELY(obj != NULL)) {
        struct cork_gc *gc = cork_gc_get();
        cork_gc_decref_step(gc, obj);
    }
}

void
cork_gc_collect_cycles(struct cork_gc *gc)
{
    struct cork_dllist_item *curr;
    struct cork_dllist_item *next;

    /* First pass: Decrement the reference count of each object in the
     * collected list. */
    for (curr = gc->collected.head.next;
         curr != &gc->collected.head;
         curr = curr->next) {
        struct cork_gc_object *obj =
            cork_container_of(curr, struct cork_gc_object, allocation);
        atomic_fetch_sub(&obj->ref_count, 1);
    }

    /* Second pass: Free any objects whose reference count is 0. */
    for (curr = gc->collected.head.next;
         curr != &gc->collected.head;
         curr = next) {
        struct cork_gc_object *obj =
            cork_container_of(curr, struct cork_gc_object, allocation);
        next = curr->next;
        if (obj->ref_count == 0) {
            cork_dllist_remove(curr);
            gc->collected_count--;
            cork_dllist_add(&gc->free, curr);
        }
    }
}

void
cork_gc_add_edge(struct cork_gc_edge *edge,
                struct cork_gc_object *source,
                struct cork_gc_object *target)
{
    edge->source = source;
    cork_dllist_add(&target->incoming, &edge->edge);
}

void
cork_gc_remove_edge(struct cork_gc_edge *edge)
{
    cork_dllist_remove(&edge->edge);
}
