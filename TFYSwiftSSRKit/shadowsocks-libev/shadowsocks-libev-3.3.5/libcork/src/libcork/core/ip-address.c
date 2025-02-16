/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011-2013, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#include <stdio.h>
#include <string.h>

#include "libcork/core/byte-order.h"
#include "libcork/core/error.h"
#include "libcork/core/net-addresses.h"
#include "libcork/core/types.h"

#ifndef CORK_IP_ADDRESS_DEBUG
#define CORK_IP_ADDRESS_DEBUG 0
#endif

#if CORK_IP_ADDRESS_DEBUG
#include <stdio.h>
#define DEBUG(...) \
    do { \
        fprintf(stderr, __VA_ARGS__); \
    } while (0)
#else
#define DEBUG(...) /* nothing */
#endif


/*-----------------------------------------------------------------------
 * IP addresses
 */

/*** IPv4 ***/

static inline const char *
cork_ipv4_parse(struct cork_ipv4 *addr, const char *str)
{
    const char  *ch;
    bool  seen_digit_in_octet = false;
    unsigned int  octets = 0;
    unsigned int  digit = 0;
    uint8_t  result[4];

    for (ch = str; *ch != '\0'; ch++) {
        DEBUG("%2u: %c\t", (unsigned int) (ch-str), *ch);
        switch (*ch) {
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                seen_digit_in_octet = true;
                digit *= 10;
                digit += (*ch - '0');
                DEBUG("digit = %u\n", digit);
                if (CORK_UNLIKELY(digit > 255)) {
                    DEBUG("\t");
                    goto parse_error;
                }
                break;

            case '.':
                /* If this would be the fourth octet, it can't have a trailing
                 * period. */
                if (CORK_UNLIKELY(octets == 3)) {
                    goto parse_error;
                }
                DEBUG("octet %u = %u\n", octets, digit);
                result[octets] = digit;
                digit = 0;
                octets++;
                seen_digit_in_octet = false;
                break;

            default:
                /* Any other character is a parse error. */
                goto parse_error;
        }
    }

    /* If we have a valid octet at the end, and that would be the fourth octet,
     * then we've got a valid final parse. */
    DEBUG("%2u:\t", (unsigned int) (ch-str));
    if (CORK_LIKELY(seen_digit_in_octet && octets == 3)) {
#if CORK_IP_ADDRESS_DEBUG
        char  parsed_ipv4[CORK_IPV4_STRING_LENGTH];
#endif
        DEBUG("octet %u = %u\n", octets, digit);
        result[octets] = digit;
        addr->addr = *(uint32_t *)result;
#if CORK_IP_ADDRESS_DEBUG
        cork_ipv4_to_raw_string(addr, parsed_ipv4);
        DEBUG("\tParsed address: %s\n", parsed_ipv4);
#endif
        return ch;
    }

parse_error:
    DEBUG("parse error\n");
    cork_parse_error("Invalid IPv4 address: \"%s\"", str);
    return NULL;
}

int
cork_ipv4_init(struct cork_ipv4 *addr, const char *str)
{
    return cork_ipv4_parse(addr, str) == NULL? -1: 0;
}

void
cork_ipv4_copy(struct cork_ipv4 *dest, const void *src)
{
    dest->addr = *(const uint32_t *)src;
}

bool
cork_ipv4_equal_(const struct cork_ipv4 *addr1, const struct cork_ipv4 *addr2)
{
    return addr1->addr == addr2->addr;
}

void
cork_ipv4_to_raw_string(const struct cork_ipv4 *addr, char *dest)
{
    uint8_t  *bytes = (uint8_t *) &addr->addr;
    snprintf(dest, CORK_IPV4_STRING_LENGTH, "%u.%u.%u.%u",
             bytes[0], bytes[1], bytes[2], bytes[3]);
}

bool
cork_ipv4_is_valid_network(const struct cork_ipv4 *addr,
                           unsigned int cidr_prefix)
{
    uint32_t  cidr_mask;

    if (cidr_prefix > 32) {
        return false;
    } else if (cidr_prefix == 32) {
        /* This handles undefined behavior for overflow bit shifts. */
        cidr_mask = 0;
    } else {
        cidr_mask = 0xffffffff >> cidr_prefix;
    }

    return (CORK_UINT32_BIG_TO_HOST(addr->addr) & cidr_mask) == 0;
}

/*** IPv6 ***/

int
cork_ipv6_init(struct cork_ipv6 *addr, const char *str)
{
    const char  *ch;

    uint16_t  digit = 0;
    unsigned int  before_count = 0;
    uint16_t  before_double_colon[8];
    bool  seen_digit_in_component = false;
    bool  seen_double_colon = false;
    bool  seen_ipv4 = false;
    struct cork_ipv4  ipv4;

    for (ch = str; *ch != '\0'; ch++) {
        DEBUG("%2u: %c\t", (unsigned int) (ch-str), *ch);
        switch (*ch) {
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                seen_digit_in_component = true;
                digit *= 16;
                digit += (*ch - '0');
                DEBUG("digit = %u\n", digit);
                if (CORK_UNLIKELY(digit > 0xffff)) {
                    DEBUG("\t");
                    goto parse_error;
                }
                break;

            case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
                seen_digit_in_component = true;
                digit *= 16;
                digit += (*ch - 'a' + 10);
                DEBUG("digit = %u\n", digit);
                if (CORK_UNLIKELY(digit > 0xffff)) {
                    DEBUG("\t");
                    goto parse_error;
                }
                break;

            case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
                seen_digit_in_component = true;
                digit *= 16;
                digit += (*ch - 'A' + 10);
                DEBUG("digit = %u\n", digit);
                if (CORK_UNLIKELY(digit > 0xffff)) {
                    DEBUG("\t");
                    goto parse_error;
                }
                break;

            case ':':
                if (ch[1] == ':') {
                    /* We've found a double colon.  This is a valid separator, but
                     * we can only have one in an IPv6 address. */
                    DEBUG("double colon\n");
                    if (CORK_UNLIKELY(seen_double_colon)) {
                        DEBUG("\t");
                        goto parse_error;
                    }

                    if (seen_digit_in_component) {
                        DEBUG("component %u = %u\n", before_count, digit);
                        before_double_colon[before_count] = digit;
                        digit = 0;
                        before_count++;
                    }

                    seen_double_colon = true;
                    seen_digit_in_component = false;
                    ch++;
                } else {
                    /* We've found a single colon.  This is only valid if we've
                     * already seen a digit in this component. */
                    DEBUG("single colon\n");
                    if (CORK_UNLIKELY(!seen_digit_in_component)) {
                        DEBUG("\t");
                        goto parse_error;
                    }

                    DEBUG("component %u = %u\n", before_count, digit);
                    if (!seen_double_colon) {
                        before_double_colon[before_count] = digit;
                        before_count++;
                    }
                    digit = 0;
                    seen_digit_in_component = false;
                }
                break;

            case '.':
                /* If we see a dot, then we've got an embedded IPv4 address. */
                DEBUG("IPv4 address\n");
                ch--;
                if (CORK_UNLIKELY(seen_ipv4)) {
                    DEBUG("\t");
                    goto parse_error;
                }
                seen_ipv4 = true;
                const char  *ipv4_ch = cork_ipv4_parse(&ipv4, ch);
                if (CORK_UNLIKELY(ipv4_ch == NULL)) {
                    DEBUG("\t");
                    goto parse_error;
                }
                ch = ipv4_ch - 1;
                break;

            default:
                /* Any other character is a parse error. */
                goto parse_error;
        }
    }

    /* If we've seen a digit in this component, then it's a valid final
     * component. */
    DEBUG("%2u:\t", (unsigned int) (ch-str));
    if (CORK_LIKELY(seen_digit_in_component)) {
        DEBUG("component %u = %u\n", before_count, digit);
        if (!seen_double_colon) {
            before_double_colon[before_count] = digit;
            before_count++;
        }
    }

    /* The components that we've parsed are valid; now let's figure out if we have
     * a valid address. */
    if (seen_ipv4) {
        /* If we saw an IPv4 address, it takes up the last 32 bits of the IPv6
         * address, which means we can only have at most 6 16-bit components
         * before it.  (If we saw a double-colon, then we can have fewer than
         * that.) */
        if (CORK_UNLIKELY(before_count > 6)) {
            DEBUG("\t");
            goto parse_error;
        }
    } else {
        /* If we didn't see an IPv4 address, then we must have exactly 8 16-bit
         * components, or we must have seen a double-colon. */
        if (CORK_UNLIKELY(before_count == 8 && !seen_double_colon)) {
            DEBUG("\t");
            goto parse_error;
        }
        if (CORK_UNLIKELY(before_count > 8)) {
            DEBUG("\t");
            goto parse_error;
        }
    }

    /* If we've gotten here, then we have a valid IPv6 address.  The components
     * that appear before the double-colon (or all components, if there isn't a
     * double-colon) are in before_double_colon.  If there was an IPv4 address,
     * it's in ipv4. */

    /* First, fill in all of the components that appeared before the
     * double-colon. */
    memcpy(addr->addr, before_double_colon, before_count * 2);

    /* Then fill in the IPv4 address if one was present. */
    if (seen_ipv4) {
        memcpy(addr->addr + 12, &ipv4.addr, 4);
    }

    return 0;

parse_error:
    DEBUG("parse error\n");
    cork_parse_error("Invalid IPv6 address: \"%s\"", str);
    return -1;
}

void
cork_ipv6_copy(struct cork_ipv6 *dest, const void *src)
{
    memcpy(dest->addr, src, sizeof(dest->addr));
}

bool
cork_ipv6_equal_(const struct cork_ipv6 *addr1, const struct cork_ipv6 *addr2)
{
    return memcmp(addr1->addr, addr2->addr, sizeof(addr1->addr)) == 0;
}

void
cork_ipv6_to_raw_string(const struct cork_ipv6 *addr, char *dest)
{
    const uint8_t  *src = addr->addr;
    unsigned int  i;
    unsigned int  in_zeros = 0;
    unsigned int  zeros_start = 0;
    unsigned int  max_zeros_start = 0;
    unsigned int  max_zeros_len = 0;

    /* First find the longest run of zeros in the address.  We do this before
     * starting to fill in the result string, since we need the longest run of
     * zeros to decide whether we want to use :: compression or not. */
    for (i = 0; i < 8; i++) {
        uint16_t  curr = CORK_UINT16_BIG_TO_HOST(*(uint16_t *) (src + 2*i));
        if (curr == 0) {
            if (in_zeros) {
                /* This component is zero, and we're already in a run of zeros.
                 * Don't need to do anything. */
            } else {
                /* We've found a new run of zeros. */
                zeros_start = i;
                in_zeros = true;
            }
        } else {
            if (in_zeros) {
                /* We've found the end of a run of zeros.  See if it's the longest
                 * so far. */
                unsigned int  zeros_len = i - zeros_start;
                if (zeros_len > max_zeros_len) {
                    max_zeros_start = zeros_start;
                    max_zeros_len = zeros_len;
                }
                in_zeros = false;
            }
        }
    }

    /* If we were still in a run of zeros when we ended, then we need to check
     * once more whether we've found a new maximum run of zeros. */
    if (in_zeros) {
        unsigned int  zeros_len = i - zeros_start;
        if (zeros_len > max_zeros_len) {
            max_zeros_start = zeros_start;
            max_zeros_len = zeros_len;
        }
    }

    /* If there was more than one zero in the longest run of zeros, then we want
     * to use :: compression.  Otherwise, we'll just write out the address in
     * long form. */
    if (max_zeros_len > 1) {
        unsigned int  pos = 0;
        /* Write out the components before the run of zeros */
        for (i = 0; i < max_zeros_start; i++) {
            uint16_t  curr = CORK_UINT16_BIG_TO_HOST(*(uint16_t *) (src + 2*i));
            pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                          "%x:", curr);
        }

        /* Write out the :: */
        if (max_zeros_start == 0) {
            pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                          ":");
        }
        pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                      ":");

        /* Write out the components after the run of zeros */
        for (i = max_zeros_start + max_zeros_len; i < 8; i++) {
            uint16_t  curr = CORK_UINT16_BIG_TO_HOST(*(uint16_t *) (src + 2*i));
            pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                          "%x", curr);
            if (i < 7) {
                pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                              ":");
            }
        }

        if (max_zeros_start + max_zeros_len == 8) {
            pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                          ":");
        }
    } else {
        unsigned int  pos = 0;
        for (i = 0; i < 8; i++) {
            uint16_t  curr = CORK_UINT16_BIG_TO_HOST(*(uint16_t *) (src + 2*i));
            pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                          "%x", curr);
            if (i < 7) {
                pos += snprintf(dest + pos, CORK_IPV6_STRING_LENGTH - pos,
                              ":");
            }
        }
    }
}

bool
cork_ipv6_is_valid_network(const struct cork_ipv6 *addr,
                           unsigned int cidr_prefix)
{
    uint64_t  cidr_mask[2];

    if (cidr_prefix > 128) {
        return false;
    } else if (cidr_prefix == 128) {
        /* This handles undefined behavior for overflow bit shifts. */
        cidr_mask[0] = 0;
        cidr_mask[1] = 0;
    } else if (cidr_prefix > 64) {
        /* high order bits all 0, low order bits depend on prefix */
        cidr_mask[0] = 0;
        cidr_mask[1] = 0xffffffffffffffffULL >> (cidr_prefix - 64);
    } else {
        /* low order bits all 1, high order bits depend on prefix */
        cidr_mask[0] = 0xffffffffffffffffULL >> cidr_prefix;
        cidr_mask[1] = 0xffffffffffffffffULL;
    }

    const uint64_t  *addr_bits = (const uint64_t *) addr->addr;
    return (CORK_UINT64_BIG_TO_HOST(addr_bits[0] & cidr_mask[0]) == 0) &&
           (CORK_UINT64_BIG_TO_HOST(addr_bits[1] & cidr_mask[1]) == 0);
}

/*** Generic IP addresses ***/

void
cork_ip_from_ipv4_(struct cork_ip *addr, const void *src)
{
    addr->version = CORK_IP_VERSION_4;
    cork_ipv4_copy(&addr->ip.v4, src);
}

void
cork_ip_from_ipv6_(struct cork_ip *addr, const void *src)
{
    addr->version = CORK_IP_VERSION_6;
    cork_ipv6_copy(&addr->ip.v6, src);
}

int
cork_ip_init(struct cork_ip *addr, const char *str)
{
    const char  *ch;
    bool  contains_colon = false;
    for (ch = str; *ch != '\0'; ch++) {
        if (*ch == ':') {
            contains_colon = true;
            break;
        }
    }

    if (contains_colon) {
        addr->version = CORK_IP_VERSION_6;
        return cork_ipv6_init(&addr->ip.v6, str);
    } else {
        addr->version = CORK_IP_VERSION_4;
        return cork_ipv4_init(&addr->ip.v4, str);
    }
}

bool
cork_ip_equal_(const struct cork_ip *addr1, const struct cork_ip *addr2)
{
    if (addr1->version != addr2->version) {
        return false;
    }

    switch (addr1->version) {
        case CORK_IP_VERSION_4:
            return cork_ipv4_equal_(&addr1->ip.v4, &addr2->ip.v4);
        case CORK_IP_VERSION_6:
            return cork_ipv6_equal_(&addr1->ip.v6, &addr2->ip.v6);
        default:
            return false;
    }
}

void
cork_ip_to_raw_string(const struct cork_ip *addr, char *dest)
{
    switch (addr->version) {
        case CORK_IP_VERSION_4:
            cork_ipv4_to_raw_string(&addr->ip.v4, dest);
            break;
        case CORK_IP_VERSION_6:
            cork_ipv6_to_raw_string(&addr->ip.v6, dest);
            break;
        default:
            strcpy(dest, "<INVALID>");
            break;
    }
}

bool
cork_ip_is_valid_network(const struct cork_ip *addr, unsigned int cidr_prefix)
{
    switch (addr->version) {
        case CORK_IP_VERSION_4:
            return cork_ipv4_is_valid_network(&addr->ip.v4, cidr_prefix);
        case CORK_IP_VERSION_6:
            return cork_ipv6_is_valid_network(&addr->ip.v6, cidr_prefix);
        default:
            return false;
    }
} 