/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2009-2012, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the LICENSE.txt file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef IPSET_H
#define IPSET_H

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <libcork/core.h>
#include <libcork/ds.h>

#include <ipset/bits.h>
#include <ipset/errors.h>
#include <ipset/bdd/nodes.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Initialize the ipset library */
CORK_API void
ipset_init(void);

/* Clean up the ipset library */
CORK_API void
ipset_done(void);

struct ip_set {
    /* The node cache for this set */
    struct ipset_node_cache *cache;
    /* The BDD that represents this set */
    ipset_node_id set_bdd;
    /* The assignments that we use to fill in the BDD's variables */
    struct assignment_list *assignments;
};

/* Create a new IP set */
CORK_API int
ip_set_init(struct ip_set *set);

/* Free the contents of an IP set */
CORK_API void
ip_set_done(struct ip_set *set);

/* Add an IP address to a set */
CORK_API int
ip_set_add(struct ip_set *set, struct cork_ip *addr);

/* Remove an IP address from a set */
CORK_API int
ip_set_remove(struct ip_set *set, struct cork_ip *addr);

/* Test whether an IP address is in a set */
CORK_API bool
ip_set_contains(struct ip_set *set, struct cork_ip *addr);

/* Save a set to a file */
CORK_API int
ip_set_save(struct ip_set *set, FILE *fp);

/* Load a set from a file */
CORK_API int
ip_set_load(struct ip_set *set, FILE *fp);

struct ip_map {
    struct ipset_node_cache  *cache;
    ipset_node_id  map_bdd;
    ipset_node_id  default_bdd;
};

/*---------------------------------------------------------------------
 * IP map functions
 */

void
ipmap_init(struct ip_map *map, int default_value);

void
ipmap_done(struct ip_map *map);

struct ip_map *
ipmap_new(int default_value);

void
ipmap_free(struct ip_map *map);

bool
ipmap_is_empty(const struct ip_map *map);

bool
ipmap_is_equal(const struct ip_map *map1, const struct ip_map *map2);

size_t
ipmap_memory_size(const struct ip_map *map);

int
ipmap_save(FILE *stream, const struct ip_map *map);

int
ipmap_save_to_stream(struct cork_stream_consumer *stream,
                     const struct ip_map *map);

struct ip_map *
ipmap_load(FILE *stream);

void
ipmap_ipv4_set(struct ip_map *map, struct cork_ipv4 *elem, int value);

void
ipmap_ipv4_set_network(struct ip_map *map, struct cork_ipv4 *elem,
                       unsigned int cidr_prefix, int value);

int
ipmap_ipv4_get(struct ip_map *map, struct cork_ipv4 *elem);

void
ipmap_ipv6_set(struct ip_map *map, struct cork_ipv6 *elem, int value);

void
ipmap_ipv6_set_network(struct ip_map *map, struct cork_ipv6 *elem,
                       unsigned int cidr_prefix, int value);

int
ipmap_ipv6_get(struct ip_map *map, struct cork_ipv6 *elem);

void
ipmap_ip_set(struct ip_map *map, struct cork_ip *addr, int value);

void
ipmap_ip_set_network(struct ip_map *map, struct cork_ip *addr,
                     unsigned int cidr_prefix, int value);

int
ipmap_ip_get(struct ip_map *map, struct cork_ip *addr);

#ifdef __cplusplus
}
#endif

#endif  /* IPSET_H */
