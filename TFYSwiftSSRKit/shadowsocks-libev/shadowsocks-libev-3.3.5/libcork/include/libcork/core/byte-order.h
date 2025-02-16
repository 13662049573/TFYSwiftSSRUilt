/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_BYTE_ORDER_H
#define LIBCORK_CORE_BYTE_ORDER_H

#include <libcork/config.h>

/* Figure out the endianness of the platform */
#if defined(__APPLE__)
#include <machine/endian.h>

#if defined(__LITTLE_ENDIAN__)
#define CORK_LITTLE_ENDIAN  1
#define CORK_BIG_ENDIAN     0
#elif defined(__BIG_ENDIAN__)
#define CORK_LITTLE_ENDIAN  0
#define CORK_BIG_ENDIAN     1
#else
#define CORK_LITTLE_ENDIAN  1  /* Default to little endian for Apple ARM64 */
#define CORK_BIG_ENDIAN     0
#endif

#elif defined(__linux__) || defined(__CYGWIN__)
#include <endian.h>

#if __BYTE_ORDER == __LITTLE_ENDIAN
#define CORK_LITTLE_ENDIAN  1
#define CORK_BIG_ENDIAN     0
#elif __BYTE_ORDER == __BIG_ENDIAN
#define CORK_LITTLE_ENDIAN  0
#define CORK_BIG_ENDIAN     1
#else
#error "Unknown endianness"
#endif

#else
#if CORK_CONFIG_IS_BIG_ENDIAN
#define CORK_LITTLE_ENDIAN  0
#define CORK_BIG_ENDIAN     1
#else
#define CORK_LITTLE_ENDIAN  1
#define CORK_BIG_ENDIAN     0
#endif
#endif

/* Declare the byte-swapping functions that we'll implement */
#define CORK_SWAP_UINT16(u16) \
    ((uint16_t) ( \
        (((uint16_t) (u16) & (uint16_t) 0x00ffU) << 8) | \
        (((uint16_t) (u16) & (uint16_t) 0xff00U) >> 8)))

#define CORK_SWAP_UINT32(u32) \
    ((uint32_t) ( \
        (((uint32_t) (u32) & (uint32_t) 0x000000ffU) << 24) | \
        (((uint32_t) (u32) & (uint32_t) 0x0000ff00U) <<  8) | \
        (((uint32_t) (u32) & (uint32_t) 0x00ff0000U) >>  8) | \
        (((uint32_t) (u32) & (uint32_t) 0xff000000U) >> 24)))

#define CORK_SWAP_UINT64(u64) \
    ((uint64_t) ( \
        (((uint64_t) (u64) & (uint64_t) 0x00000000000000ffULL) << 56) | \
        (((uint64_t) (u64) & (uint64_t) 0x000000000000ff00ULL) << 40) | \
        (((uint64_t) (u64) & (uint64_t) 0x0000000000ff0000ULL) << 24) | \
        (((uint64_t) (u64) & (uint64_t) 0x00000000ff000000ULL) <<  8) | \
        (((uint64_t) (u64) & (uint64_t) 0x000000ff00000000ULL) >>  8) | \
        (((uint64_t) (u64) & (uint64_t) 0x0000ff0000000000ULL) >> 24) | \
        (((uint64_t) (u64) & (uint64_t) 0x00ff000000000000ULL) >> 40) | \
        (((uint64_t) (u64) & (uint64_t) 0xff00000000000000ULL) >> 56)))

/* Define the host-to-network and network-to-host functions */
#if CORK_BIG_ENDIAN
#define CORK_UINT16_HOST_TO_BIG(u16)     (u16)
#define CORK_UINT16_HOST_TO_LITTLE(u16)  CORK_SWAP_UINT16(u16)
#define CORK_UINT16_BIG_TO_HOST(u16)     (u16)
#define CORK_UINT16_LITTLE_TO_HOST(u16)  CORK_SWAP_UINT16(u16)
#define CORK_UINT32_HOST_TO_BIG(u32)     (u32)
#define CORK_UINT32_HOST_TO_LITTLE(u32)  CORK_SWAP_UINT32(u32)
#define CORK_UINT32_BIG_TO_HOST(u32)     (u32)
#define CORK_UINT32_LITTLE_TO_HOST(u32)  CORK_SWAP_UINT32(u32)
#define CORK_UINT64_HOST_TO_BIG(u64)     (u64)
#define CORK_UINT64_HOST_TO_LITTLE(u64)  CORK_SWAP_UINT64(u64)
#define CORK_UINT64_BIG_TO_HOST(u64)     (u64)
#define CORK_UINT64_LITTLE_TO_HOST(u64)  CORK_SWAP_UINT64(u64)
#else
#define CORK_UINT16_HOST_TO_BIG(u16)     CORK_SWAP_UINT16(u16)
#define CORK_UINT16_HOST_TO_LITTLE(u16)  (u16)
#define CORK_UINT16_BIG_TO_HOST(u16)     CORK_SWAP_UINT16(u16)
#define CORK_UINT16_LITTLE_TO_HOST(u16)  (u16)
#define CORK_UINT32_HOST_TO_BIG(u32)     CORK_SWAP_UINT32(u32)
#define CORK_UINT32_HOST_TO_LITTLE(u32)  (u32)
#define CORK_UINT32_BIG_TO_HOST(u32)     CORK_SWAP_UINT32(u32)
#define CORK_UINT32_LITTLE_TO_HOST(u32)  (u32)
#define CORK_UINT64_HOST_TO_BIG(u64)     CORK_SWAP_UINT64(u64)
#define CORK_UINT64_HOST_TO_LITTLE(u64)  (u64)
#define CORK_UINT64_BIG_TO_HOST(u64)     CORK_SWAP_UINT64(u64)
#define CORK_UINT64_LITTLE_TO_HOST(u64)  (u64)
#endif

/* Define some helper functions for reading big-endian integers from a
 * byte stream. */
#define CORK_UINT16_BIG_INLINE(bytes) \
    (CORK_UINT16_BIG_TO_HOST( \
        ((uint16_t) ((uint8_t *) (bytes))[0] << 8) | \
        ((uint16_t) ((uint8_t *) (bytes))[1])))

#define CORK_UINT32_BIG_INLINE(bytes) \
    (CORK_UINT32_BIG_TO_HOST( \
        ((uint32_t) ((uint8_t *) (bytes))[0] << 24) | \
        ((uint32_t) ((uint8_t *) (bytes))[1] << 16) | \
        ((uint32_t) ((uint8_t *) (bytes))[2] <<  8) | \
        ((uint32_t) ((uint8_t *) (bytes))[3])))

#define CORK_UINT64_BIG_INLINE(bytes) \
    (CORK_UINT64_BIG_TO_HOST( \
        ((uint64_t) ((uint8_t *) (bytes))[0] << 56) | \
        ((uint64_t) ((uint8_t *) (bytes))[1] << 48) | \
        ((uint64_t) ((uint8_t *) (bytes))[2] << 40) | \
        ((uint64_t) ((uint8_t *) (bytes))[3] << 32) | \
        ((uint64_t) ((uint8_t *) (bytes))[4] << 24) | \
        ((uint64_t) ((uint8_t *) (bytes))[5] << 16) | \
        ((uint64_t) ((uint8_t *) (bytes))[6] <<  8) | \
        ((uint64_t) ((uint8_t *) (bytes))[7])))

/* Define the in-place host-to-network and network-to-host macros */
#define CORK_UINT16_BIG_TO_HOST_IN_PLACE(u16) \
    do { \
        u16 = CORK_UINT16_BIG_TO_HOST(u16); \
    } while (0)

#define CORK_UINT32_BIG_TO_HOST_IN_PLACE(u32) \
    do { \
        u32 = CORK_UINT32_BIG_TO_HOST(u32); \
    } while (0)

#define CORK_UINT64_BIG_TO_HOST_IN_PLACE(u64) \
    do { \
        u64 = CORK_UINT64_BIG_TO_HOST(u64); \
    } while (0)

#define CORK_UINT16_HOST_TO_BIG_IN_PLACE(u16) \
    do { \
        u16 = CORK_UINT16_HOST_TO_BIG(u16); \
    } while (0)

#define CORK_UINT32_HOST_TO_BIG_IN_PLACE(u32) \
    do { \
        u32 = CORK_UINT32_HOST_TO_BIG(u32); \
    } while (0)

#define CORK_UINT64_HOST_TO_BIG_IN_PLACE(u64) \
    do { \
        u64 = CORK_UINT64_HOST_TO_BIG(u64); \
    } while (0)

#endif /* LIBCORK_CORE_BYTE_ORDER_H */
