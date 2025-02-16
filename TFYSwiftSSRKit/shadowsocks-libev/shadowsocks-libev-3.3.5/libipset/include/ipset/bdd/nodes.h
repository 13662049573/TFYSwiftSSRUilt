/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2010-2013, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the LICENSE.txt file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef IPSET_BDD_NODES_H
#define IPSET_BDD_NODES_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include <libcork/core.h>
#include <libcork/ds.h>

#include <ipset/bits.h>
#include <ipset/errors.h>

/* Node types */
enum ipset_node_type {
    IPSET_NONTERMINAL_NODE = 0,
    IPSET_TERMINAL_NODE = 1
};

/* Node type macros */
#define ipset_node_get_type(node_id)  ((node_id) & 0x01)

#define IPSET_NODE_ID_FORMAT  "%s%u"
#define IPSET_NODE_ID_VALUES(node_id) \
    (ipset_node_get_type((node_id)) == IPSET_NONTERMINAL_NODE? "s": ""), \
    ((node_id) >> 1)

/* Node ID macros */
#define ipset_terminal_node_id(value) \
    (((value) << 1) | IPSET_TERMINAL_NODE)

#define ipset_nonterminal_node_id(value) \
    (((value) << 1) | IPSET_NONTERMINAL_NODE)

/* Node cache macros */
#define IPSET_BDD_NODE_CACHE_BIT_SIZE  6
#define IPSET_BDD_NODE_CACHE_SIZE  (1 << IPSET_BDD_NODE_CACHE_BIT_SIZE)
#define IPSET_BDD_NODE_CACHE_MASK  (IPSET_BDD_NODE_CACHE_SIZE - 1)
#define IPSET_NULL_INDEX  ((ipset_value) -1)

/* Node value macros */
#define ipset_terminal_value(node_id)  ((node_id) >> 1)
#define ipset_nonterminal_value(node_id) ((node_id) >> 1)

/* Node cache access macros */
#define ipset_nonterminal_chunk_index(index) \
    ((index) >> IPSET_BDD_NODE_CACHE_BIT_SIZE)

#define ipset_nonterminal_chunk_offset(index) \
    ((index) & IPSET_BDD_NODE_CACHE_MASK)

#define ipset_node_cache_get_nonterminal_by_index(cache, index) \
    (&cork_array_at(&(cache)->chunks, ipset_nonterminal_chunk_index((index))) \
     [ipset_nonterminal_chunk_offset((index))])

#define ipset_node_cache_get_nonterminal(cache, node_id) \
    (ipset_node_cache_get_nonterminal_by_index \
     ((cache), ipset_nonterminal_value((node_id))))

/*-----------------------------------------------------------------------
 * Preliminaries
 */

/**
 * Each variable in a BDD is referred to by number.
 */
typedef unsigned int  ipset_variable;

/**
 * Each BDD terminal represents an integer value.  The integer must be
 * non-negative, but must be within the range of the <i>signed</i>
 * integer type.
 */
typedef unsigned int  ipset_value;

/**
 * An identifier for each distinct node in a BDD.
 */
typedef uint32_t ipset_node_id;

/* Node structure */
struct ipset_node {
    /** The reference count for this node. */
    unsigned int  refcount;
    /** The variable that this node represents. */
    ipset_variable  variable;
    /** The subtree node for when the variable is false. */
    ipset_node_id  low;
    /** The subtree node for when the variable is true. */
    ipset_node_id  high;
};

/* Node cache structure */
struct ipset_node_cache {
    /** The storage for the nodes managed by this cache. */
    cork_array(struct ipset_node *)  chunks;
    /** The largest nonterminal index that has been handed out. */
    ipset_value  largest_index;
    /** The index of the first node in the free list. */
    ipset_value  free_list;
    /** A cache of the nonterminal nodes, keyed by their contents. */
    struct cork_hash_table  *node_cache;
};

/* Assignment function type */
typedef bool
(*ipset_assignment_func)(const void *user_data,
                         ipset_variable variable);

/* Assignment structure */
struct ipset_assignment {
    /**
     * The underlying variable assignments are stored in a vector of
     * tribools.  Every variable that has a true or false value must
     * appear in the vector.  Variables that are EITHER only have to
     * appear to prevent gaps in the vector.  Any variables outside
     * the range of the vector are assumed to be EITHER.
     */
    cork_array(enum ipset_tribool)  values;
};

/* Assignment functions */
struct ipset_assignment *
ipset_assignment_new(void);

void
ipset_assignment_free(struct ipset_assignment *assignment);

bool
ipset_assignment_equal(const struct ipset_assignment *assignment1,
                       const struct ipset_assignment *assignment2);

void
ipset_assignment_cut(struct ipset_assignment *assignment, ipset_variable var);

void
ipset_assignment_clear(struct ipset_assignment *assignment);

enum ipset_tribool
ipset_assignment_get(struct ipset_assignment *assignment, ipset_variable var);

void
ipset_assignment_set(struct ipset_assignment *assignment,
                     ipset_variable var, enum ipset_tribool value);

/* Expanded assignment structure */
struct ipset_expanded_assignment {
    /** Whether there are any more assignments in this iterator. */
    bool finished;

    /**
     * The variable values in the current expanded assignment.  Since
     * there won't be any EITHERs in the expanded assignment, we can
     * use a byte array, and represent each variable by a single bit.
     */
    struct cork_buffer  values;

    /**
     * An array containing all of the variables that are EITHER in the
     * original assignment.
     */
    cork_array(ipset_variable)  eithers;
};

/* Expanded assignment functions */
struct ipset_expanded_assignment *
ipset_assignment_expand(const struct ipset_assignment *assignment,
                         ipset_variable var_count);

void
ipset_expanded_assignment_free(struct ipset_expanded_assignment *exp);

void
ipset_expanded_assignment_advance(struct ipset_expanded_assignment *exp);

/* BDD iterator structure */
struct ipset_bdd_iterator {
    /** Whether there are any more assignments in this iterator. */
    bool finished;

    /** The node cache that we're iterating through. */
    struct ipset_node_cache  *cache;

    /**
     * The sequence of nonterminal nodes leading to the current
     * terminal.
     */
    cork_array(ipset_node_id)  stack;

    /** The current assignment. */
    struct ipset_assignment  *assignment;

    /**
     * The value of the BDD's function when applied to the current
     * assignment.
     */
    ipset_value  value;
};

/* BDD iterator functions */
struct ipset_bdd_iterator *
ipset_node_iterate(struct ipset_node_cache *cache, ipset_node_id root);

void
ipset_bdd_iterator_free(struct ipset_bdd_iterator *iterator);

void
ipset_bdd_iterator_advance(struct ipset_bdd_iterator *iterator);

/* Node cache functions */
struct ipset_node_cache *
ipset_node_cache_new(void);

void
ipset_node_cache_free(struct ipset_node_cache *cache);

ipset_node_id
ipset_node_cache_nonterminal(struct ipset_node_cache *cache,
                             ipset_variable variable,
                             ipset_node_id low, ipset_node_id high);

ipset_node_id
ipset_node_incref(struct ipset_node_cache *cache, ipset_node_id node);

void
ipset_node_decref(struct ipset_node_cache *cache, ipset_node_id node);

size_t
ipset_node_reachable_count(const struct ipset_node_cache *cache,
                           ipset_node_id node);

size_t
ipset_node_memory_size(const struct ipset_node_cache *cache,
                       ipset_node_id node);

ipset_node_id
ipset_node_cache_load(FILE *stream, struct ipset_node_cache *cache);

int
ipset_node_cache_save(struct cork_stream_consumer *stream,
                      struct ipset_node_cache *cache, ipset_node_id node);

bool
ipset_node_cache_nodes_equal(const struct ipset_node_cache *cache1,
                             ipset_node_id node1,
                             const struct ipset_node_cache *cache2,
                             ipset_node_id node2);

int
ipset_node_cache_save_dot(struct cork_stream_consumer *stream,
                          struct ipset_node_cache *cache, ipset_node_id node);

/* Assignment functions */
bool
ipset_bool_array_assignment(const void *user_data,
                            ipset_variable variable);

bool
ipset_bit_array_assignment(const void *user_data,
                           ipset_variable variable);

ipset_value
ipset_node_evaluate(const struct ipset_node_cache *cache, ipset_node_id node,
                    ipset_assignment_func assignment,
                    const void *user_data);

ipset_node_id
ipset_node_insert(struct ipset_node_cache *cache, ipset_node_id node,
                   ipset_assignment_func assignment,
                   const void *user_data, ipset_variable variable_count,
                   ipset_value value);

#endif /* IPSET_BDD_NODES_H */
