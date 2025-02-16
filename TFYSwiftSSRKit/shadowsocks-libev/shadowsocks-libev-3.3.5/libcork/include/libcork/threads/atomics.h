/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2012, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_THREADS_ATOMICS_H
#define LIBCORK_THREADS_ATOMICS_H

#include <libcork/config.h>
#include <libcork/core/types.h>

#if defined(__APPLE__)
#include <stdatomic.h>

/* Integer atomic operations */
#define cork_int_atomic_add(dest, val) \
    atomic_fetch_add((atomic_int*)(dest), (val))

#define cork_int_atomic_pre_add(dest, val) \
    atomic_fetch_add((atomic_int*)(dest), (val))

#define cork_int_atomic_sub(dest, val) \
    atomic_fetch_sub((atomic_int*)(dest), (val))

#define cork_int_atomic_pre_sub(dest, val) \
    atomic_fetch_sub((atomic_int*)(dest), (val))

#define cork_int_cas(dest, old, new) \
    atomic_compare_exchange_strong((atomic_int*)(dest), &(old), (new))

/* Pointer atomic operations */
#define cork_ptr_cas(dest, old, new) \
    atomic_compare_exchange_strong((atomic_uintptr_t*)(dest), (uintptr_t*)&(old), (uintptr_t)(new))

/* Atomic initialization */
#define cork_int_atomic_new() \
    ATOMIC_VAR_INIT(0)

#define cork_ptr_atomic_new() \
    ATOMIC_VAR_INIT(NULL)

/* Memory barriers */
#define cork_memory_barrier() \
    atomic_thread_fence(memory_order_seq_cst)

#else
#error "No atomics implementation!"
#endif

#endif /* LIBCORK_THREADS_ATOMICS_H */
