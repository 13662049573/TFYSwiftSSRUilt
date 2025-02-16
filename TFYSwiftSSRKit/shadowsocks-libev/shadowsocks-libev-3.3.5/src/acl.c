/*
 * acl.c - Manage the ACL (Access Control List)
 *
 * Copyright (C) 2013 - 2019, Max Lv <max.c.lv@gmail.com>
 *
 * This file is part of the shadowsocks-libev.
 *
 * shadowsocks-libev is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * shadowsocks-libev is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with shadowsocks-libev; see the file COPYING. If not, see
 * <http://www.gnu.org/licenses/>.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "acl.h"
#include "utils.h"
#include "cache.h"

#ifndef __MINGW32__
#include <ctype.h>
#endif

#include <ipset/ipset.h>

#define MAX_TRIES 64
#define MALICIOUS_IP "198.18.0.0/15"
#define MALICIOUS_PORT "9988"

static struct ip_set white_list_ipv4;
static struct ip_set white_list_ipv6;
static struct ip_set black_list_ipv4;
static struct ip_set black_list_ipv6;
static struct cork_dllist black_list_rules;
static struct cork_dllist white_list_rules;

static int acl_mode = BLACK_LIST;

static int
parse_addr_cidr(const char *addr_str, char *addr_buf, int *prefix_len)
{
    int ret = -1;
    char *pch;

    pch = strchr(addr_str, '/');
    if (pch == NULL) {
        prefix_len = NULL;
        ret = 0;
        strncpy(addr_buf, addr_str, 128);
    } else {
        ret = 1;
        memcpy(addr_buf, addr_str, pch - addr_str);
        addr_buf[pch - addr_str] = '\0';
        *prefix_len = atoi(pch + 1);
    }

    return ret;
}

static int
parse_addr_port(const char *addr_str, char *addr_buf, int *port)
{
    int ret = -1;
    char *pch;

    pch = strchr(addr_str, ':');
    if (pch == NULL) {
        strncpy(addr_buf, addr_str, 128);
        *port = -1;
        ret = 0;
    } else {
        memcpy(addr_buf, addr_str, pch - addr_str);
        addr_buf[pch - addr_str] = '\0';
        *port = atoi(pch + 1);
        ret = 1;
    }

    return ret;
}

int
outbound_block_match_host(const char *host)
{
    struct cork_dllist *rules = &black_list_rules;
    struct cork_dllist_item *curr;
    struct cork_dllist_item *next;
    struct acl_rule *rule;

    if (acl_mode == WHITE_LIST) {
        rules = &white_list_rules;
    }

    if (cork_dllist_is_empty(rules)) {
        if (acl_mode == WHITE_LIST) {
            return 1;
        }
        return 0;
    }

    for (curr = rules->head.next; curr != &rules->head; curr = next) {
        next = curr->next;
        rule = cork_container_of(curr, struct acl_rule, entries);
        if (strncmp(rule->addr, host, strlen(rule->addr)) == 0) {
            return 1;
        }
    }

    return 0;
}

int
init_acl(const char *path)
{
    // Initialize ipset
    ipset_init_library();
    ipset_init(&white_list_ipv4);
    ipset_init(&white_list_ipv6);
    ipset_init(&black_list_ipv4);
    ipset_init(&black_list_ipv6);

    cork_dllist_init(&black_list_rules);
    cork_dllist_init(&white_list_rules);

    struct ip_set *list_ipv4 = &black_list_ipv4;
    struct ip_set *list_ipv6 = &black_list_ipv6;
    struct cork_dllist *rules = &black_list_rules;

    // If no path provided, just return success
    if (path == NULL) {
        return 0;
    }

    FILE *f = fopen(path, "r");
    if (f == NULL) {
        LOGE("Failed to open ACL file %s", path);
        return 1;
    }

    char buf[257];
    while (!feof(f)) {
        if (fgets(buf, 256, f)) {
            // Trim the newline
            int len = strlen(buf);
            if (len > 0 && buf[len - 1] == '\n') {
                buf[len - 1] = '\0';
            }

            if (strlen(buf) == 0) {
                continue;
            }

            if (buf[0] == '[') {
                if (strncmp(buf, "[outbound_block_list]", 20) == 0) {
                    list_ipv4 = &black_list_ipv4;
                    list_ipv6 = &black_list_ipv6;
                    rules = &black_list_rules;
                    acl_mode = BLACK_LIST;
                } else if (strncmp(buf, "[white_list]", 12) == 0) {
                    list_ipv4 = &white_list_ipv4;
                    list_ipv6 = &white_list_ipv6;
                    rules = &white_list_rules;
                    acl_mode = WHITE_LIST;
                } else if (strncmp(buf, "[black_list]", 12) == 0) {
                    list_ipv4 = &black_list_ipv4;
                    list_ipv6 = &black_list_ipv6;
                    rules = &black_list_rules;
                    acl_mode = BLACK_LIST;
                }
            } else {
                char addr_str[128];
                int prefix_len;
                int port;
                int ret = parse_addr_cidr(buf, addr_str, &prefix_len);
                if (ret == 0) {
                    ret = parse_addr_port(addr_str, addr_str, &port);
                    if (ret == 0) {
                        struct acl_rule *rule = ss_malloc(sizeof(struct acl_rule));
                        rule->addr = strdup(addr_str);
                        cork_dllist_add(rules, &rule->entries);
                    }
                } else if (ret == 1) {
                    struct cork_ipv4 addr;
                    int err = cork_ipv4_init(&addr, addr_str);
                    if (!err) {
                        // Create network address with prefix length
                        struct cork_ipv4 network_addr = addr;
                        uint32_t mask = htonl(0xffffffff << (32 - prefix_len));
                        memcpy(&network_addr, &mask, sizeof(uint32_t));
                        ipset_ipv4_add(list_ipv4, &network_addr);
                    } else {
                        struct cork_ipv6 addr;
                        err = cork_ipv6_init(&addr, addr_str);
                        if (!err) {
                            // Create network address with prefix length
                            struct cork_ipv6 network_addr = addr;
                            int i;
                            for (i = prefix_len; i < 128; i++) {
                                int byte = i / 8;
                                int bit = 7 - (i % 8);
                                uint8_t *bytes = (uint8_t *)&network_addr;
                                bytes[byte] &= ~(1 << bit);
                            }
                            ipset_ipv6_add(list_ipv6, &network_addr);
                        }
                    }
                }
            }
        }
    }

    fclose(f);
    return 0;
}

void
free_acl(void)
{
    struct cork_dllist *rules = &black_list_rules;
    struct cork_dllist_item *curr;
    struct cork_dllist_item *next;

    for (curr = rules->head.next; curr != &rules->head; curr = next) {
        next = curr->next;
        struct acl_rule *rule = cork_container_of(curr, struct acl_rule, entries);
        ss_free(rule->addr);
        ss_free(rule);
    }

    rules = &white_list_rules;
    for (curr = rules->head.next; curr != &rules->head; curr = next) {
        next = curr->next;
        struct acl_rule *rule = cork_container_of(curr, struct acl_rule, entries);
        ss_free(rule->addr);
        ss_free(rule);
    }

    ipset_done(&black_list_ipv4);
    ipset_done(&black_list_ipv6);
    ipset_done(&white_list_ipv4);
    ipset_done(&white_list_ipv6);
}

int
get_acl_mode(void)
{
    return acl_mode;
}

int
acl_match_host(const char *host)
{
    return outbound_block_match_host(host);
}
