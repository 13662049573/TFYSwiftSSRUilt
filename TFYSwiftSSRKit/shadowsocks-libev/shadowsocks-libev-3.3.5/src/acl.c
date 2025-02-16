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

#include <ctype.h>

#ifdef USE_SYSTEM_SHARED_LIB
#include <libcorkipset/ipset.h>
#else
#include <ipset/ipset.h>
#endif

#include "rule.h"
#include "netutils.h"
#include "utils.h"
#include "cache.h"
#include "acl.h"

static struct ip_set white_list_ipv4;
static struct ip_set white_list_ipv6;

static struct ip_set black_list_ipv4;
static struct ip_set black_list_ipv6;

static struct ip_set outbound_block_list_ipv4;
static struct ip_set outbound_block_list_ipv6;

static rule_t *black_list_rules;
static rule_t *white_list_rules;
static rule_t *outbound_block_list_rules;

static int acl_mode = BLACK_LIST;

static void
parse_addr_cidr(const char *str, char *host, int *cidr)
{
    int ret = -1;
    char *pch;

    pch = strchr(str, '/');
    while (pch != NULL) {
        ret = sscanf(pch + 1, "%d", cidr);
        *pch = '\0';
        break;
    }
    if (ret == -1) {
        *cidr = -1;
    }

    strcpy(host, str);
}

static int
parse_line(char *line, char *host, int *cidr)
{
    char *line_buffer = line;
    char *pch;

    while (isspace(*line_buffer)) {
        line_buffer++;
    }

    if (*line_buffer == 0 || *line_buffer == '#') {
        return 0;
    }

    pch = strchr(line_buffer, '#');
    if (pch != NULL) {
        *pch = '\0';
    }

    parse_addr_cidr(line_buffer, host, cidr);

    return 1;
}

int
init_acl(const char *path)
{
    FILE *f = fopen(path, "r");
    if (f == NULL) {
        LOGE("Invalid acl path.");
        return -1;
    }

    char line[257];
    char host[257];
    int cidr;

    ipset_init(&white_list_ipv4);
    ipset_init(&white_list_ipv6);
    ipset_init(&black_list_ipv4);
    ipset_init(&black_list_ipv6);
    ipset_init(&outbound_block_list_ipv4);
    ipset_init(&outbound_block_list_ipv6);

    black_list_rules = NULL;
    white_list_rules = NULL;
    outbound_block_list_rules = NULL;

    while (!feof(f)) {
        if (fgets(line, 256, f) == NULL) {
            break;
        }

        // Trim the newline
        int len = strlen(line);
        if (len > 0 && line[len - 1] == '\n') {
            line[len - 1] = '\0';
        }

        if (parse_line(line, host, &cidr) == 0) {
            continue;
        }

        if (strcmp(host, "[outbound_block_list]") == 0) {
            acl_mode = OUTBOUND_BLOCK_LIST;
            continue;
        } else if (strcmp(host, "[black_list]") == 0) {
            acl_mode = BLACK_LIST;
            continue;
        } else if (strcmp(host, "[white_list]") == 0) {
            acl_mode = WHITE_LIST;
            continue;
        } else if (strcmp(host, "[reject_all]") == 0) {
            acl_mode = REJECT_ALL;
            continue;
        } else if (strcmp(host, "[accept_all]") == 0) {
            acl_mode = ACCEPT_ALL;
            continue;
        }

        if (cidr >= 0) {
            struct cork_ipv4 addr;
            struct cork_ipv6 addr6;
            int err;
            if ((err = cork_ipv4_init(&addr, host)) != -1) {
                if (acl_mode == BLACK_LIST) {
                    ipset_ipv4_add_network(&black_list_ipv4, &addr, cidr);
                } else if (acl_mode == WHITE_LIST) {
                    ipset_ipv4_add_network(&white_list_ipv4, &addr, cidr);
                } else if (acl_mode == OUTBOUND_BLOCK_LIST) {
                    ipset_ipv4_add_network(&outbound_block_list_ipv4, &addr, cidr);
                }
            } else if ((err = cork_ipv6_init(&addr6, host)) != -1) {
                if (acl_mode == BLACK_LIST) {
                    ipset_ipv6_add_network(&black_list_ipv6, &addr6, cidr);
                } else if (acl_mode == WHITE_LIST) {
                    ipset_ipv6_add_network(&white_list_ipv6, &addr6, cidr);
                } else if (acl_mode == OUTBOUND_BLOCK_LIST) {
                    ipset_ipv6_add_network(&outbound_block_list_ipv6, &addr6, cidr);
                }
            }
        } else {
            rule_t *rule = create_rule(host, 0, acl_mode);
            if (rule != NULL) {
                if (acl_mode == BLACK_LIST) {
                    rule->next = black_list_rules;
                    black_list_rules = rule;
                } else if (acl_mode == WHITE_LIST) {
                    rule->next = white_list_rules;
                    white_list_rules = rule;
                } else if (acl_mode == OUTBOUND_BLOCK_LIST) {
                    rule->next = outbound_block_list_rules;
                    outbound_block_list_rules = rule;
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
    ipset_done(&black_list_ipv4);
    ipset_done(&black_list_ipv6);
    ipset_done(&white_list_ipv4);
    ipset_done(&white_list_ipv6);
    ipset_done(&outbound_block_list_ipv4);
    ipset_done(&outbound_block_list_ipv6);

    release_rules(black_list_rules);
    release_rules(white_list_rules);
    release_rules(outbound_block_list_rules);
}

int
acl_match_host(const char *host)
{
    struct cork_ipv4 addr;
    struct cork_ipv6 addr6;
    int ret;

    if (acl_mode == ACCEPT_ALL) {
        return 1;
    }

    if (acl_mode == REJECT_ALL) {
        return 0;
    }

    if ((ret = cork_ipv4_init(&addr, host)) != -1) {
        if (acl_mode == BLACK_LIST) {
            ret = ipset_contains_ipv4(&black_list_ipv4, &addr);
            if (ret) {
                return 0;
            }
            ret = get_rule(host, 0, BLACK_LIST, black_list_rules) != NULL;
            if (ret) {
                return 0;
            }
            return 1;
        } else if (acl_mode == WHITE_LIST) {
            ret = ipset_contains_ipv4(&white_list_ipv4, &addr);
            if (ret) {
                return 1;
            }
            ret = get_rule(host, 0, WHITE_LIST, white_list_rules) != NULL;
            if (ret) {
                return 1;
            }
            return 0;
        }
    } else if ((ret = cork_ipv6_init(&addr6, host)) != -1) {
        if (acl_mode == BLACK_LIST) {
            ret = ipset_contains_ipv6(&black_list_ipv6, &addr6);
            if (ret) {
                return 0;
            }
            ret = get_rule(host, 0, BLACK_LIST, black_list_rules) != NULL;
            if (ret) {
                return 0;
            }
            return 1;
        } else if (acl_mode == WHITE_LIST) {
            ret = ipset_contains_ipv6(&white_list_ipv6, &addr6);
            if (ret) {
                return 1;
            }
            ret = get_rule(host, 0, WHITE_LIST, white_list_rules) != NULL;
            if (ret) {
                return 1;
            }
            return 0;
        }
    } else {
        if (acl_mode == BLACK_LIST) {
            ret = get_rule(host, 0, BLACK_LIST, black_list_rules) != NULL;
            if (ret) {
                return 0;
            }
            return 1;
        } else if (acl_mode == WHITE_LIST) {
            ret = get_rule(host, 0, WHITE_LIST, white_list_rules) != NULL;
            if (ret) {
                return 1;
            }
            return 0;
        }
    }

    return 1;
}

int
acl_add_ip(const char *ip)
{
    struct cork_ipv4 addr;
    struct cork_ipv6 addr6;
    int err;

    if ((err = cork_ipv4_init(&addr, ip)) != -1) {
        if (acl_mode == BLACK_LIST) {
            ipset_ipv4_add(&black_list_ipv4, &addr);
        } else if (acl_mode == WHITE_LIST) {
            ipset_ipv4_add(&white_list_ipv4, &addr);
        }
    } else if ((err = cork_ipv6_init(&addr6, ip)) != -1) {
        if (acl_mode == BLACK_LIST) {
            ipset_ipv6_add(&black_list_ipv6, &addr6);
        } else if (acl_mode == WHITE_LIST) {
            ipset_ipv6_add(&white_list_ipv6, &addr6);
        }
    }

    return 0;
}

int
acl_remove_ip(const char *ip)
{
    struct cork_ipv4 addr;
    struct cork_ipv6 addr6;
    int err;

    if ((err = cork_ipv4_init(&addr, ip)) != -1) {
        if (acl_mode == BLACK_LIST) {
            ipset_ipv4_remove(&black_list_ipv4, &addr);
        } else if (acl_mode == WHITE_LIST) {
            ipset_ipv4_remove(&white_list_ipv4, &addr);
        }
    } else if ((err = cork_ipv6_init(&addr6, ip)) != -1) {
        if (acl_mode == BLACK_LIST) {
            ipset_ipv6_remove(&black_list_ipv6, &addr6);
        } else if (acl_mode == WHITE_LIST) {
            ipset_ipv6_remove(&white_list_ipv6, &addr6);
        }
    }

    return 0;
}

int
get_acl_mode(void)
{
    return acl_mode;
}
