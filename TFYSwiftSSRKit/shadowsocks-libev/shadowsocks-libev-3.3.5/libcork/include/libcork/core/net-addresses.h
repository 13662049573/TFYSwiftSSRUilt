/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011-2013, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_NET_ADDRESSES_H
#define LIBCORK_CORE_NET_ADDRESSES_H

#include <string.h>

#include <libcork/core/api.h>
#include <libcork/core/types.h>

/* Function declarations */
CORK_API void
cork_ipv4_copy(struct cork_ipv4 *dest, const void *src);

CORK_API void
cork_ipv6_copy(struct cork_ipv6 *dest, const void *src);

CORK_API bool
cork_ipv4_equal(const struct cork_ipv4 *addr1, const struct cork_ipv4 *addr2);

CORK_API bool
cork_ipv6_equal(const struct cork_ipv6 *addr1, const struct cork_ipv6 *addr2);

CORK_API void
cork_ipv4_to_raw_string(const struct cork_ipv4 *addr, char *buf);

CORK_API void
cork_ipv6_to_raw_string(const struct cork_ipv6 *addr, char *buf);

CORK_API void
cork_ip_to_raw_string(const struct cork_ip *addr, char *buf);

CORK_API int
cork_ipv4_init(struct cork_ipv4 *addr, const char *str);

CORK_API int
cork_ipv6_init(struct cork_ipv6 *addr, const char *str);

CORK_API int
cork_ip_init(struct cork_ip *addr, const char *str);

CORK_API bool
cork_ipv4_is_valid_network(const struct cork_ipv4 *addr, unsigned int cidr_prefix);

CORK_API bool
cork_ipv6_is_valid_network(const struct cork_ipv6 *addr, unsigned int cidr_prefix);

CORK_API bool
cork_ip_is_valid_network(const struct cork_ip *addr, unsigned int cidr_prefix);

#endif /* LIBCORK_CORE_NET_ADDRESSES_H */