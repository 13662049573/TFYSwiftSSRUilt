/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_TYPES_H
#define LIBCORK_CORE_TYPES_H

#include <libcork/config.h>
#include <libcork/core/api.h>

/* Basic integer types */
#if defined(__APPLE__)
#include <stdint.h>
#else
typedef signed char  int8_t;
typedef unsigned char  uint8_t;
typedef signed short  int16_t;
typedef unsigned short  uint16_t;
typedef signed int  int32_t;
typedef unsigned int  uint32_t;
typedef signed long long  int64_t;
typedef unsigned long long  uint64_t;
#endif

/* Boolean type */
#if defined(__APPLE__)
#include <stdbool.h>
#else
typedef int  bool;
#define true  1
#define false  0
#endif

/* Size type */
#if defined(__APPLE__)
#include <stddef.h>
#else
typedef unsigned long  size_t;
typedef signed long  ssize_t;
#endif

/* IP version constants */
#define CORK_IP_VERSION_4  4
#define CORK_IP_VERSION_6  6

/* IP address types */
struct cork_ipv4 {
    uint32_t  addr;
};

struct cork_ipv6 {
    uint8_t  addr[16];
};

struct cork_ip {
    unsigned int  version;
    union {
        struct cork_ipv4  v4;
        struct cork_ipv6  v6;
    } ip;
};

/* String length constants */
#define CORK_IPV4_STRING_LENGTH  16
#define CORK_IPV6_STRING_LENGTH  40
#define CORK_IP_STRING_LENGTH  CORK_IPV6_STRING_LENGTH

#endif /* LIBCORK_CORE_TYPES_H */
