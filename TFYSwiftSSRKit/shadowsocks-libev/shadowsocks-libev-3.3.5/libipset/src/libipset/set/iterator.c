/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2010-2012, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the LICENSE.txt file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#include <stdlib.h>
#include <string.h>
#include <libcork/core.h>
#include <ipset/bdd/nodes.h>
#include <ipset/bits.h>
#include <ipset/ipset.h>
#include "iterator.h"

#define IPV4_BIT_SIZE  32
#define IPV6_BIT_SIZE  128


/* Forward declarations */

static void
process_assignment(struct ipset_iterator *iterator);

static void
expand_ipv6(struct ipset_iterator *iterator);


/**
 * Find the highest non-EITHER bit in an assignment, starting from the
 * given bit index.
 */
static unsigned int
find_last_non_either_bit(struct ipset_assignment *assignment,
                         unsigned int starting_bit)
{
    unsigned int  i;

    for (i = starting_bit; i >= 1; i--) {
        enum ipset_tribool  value = ipset_assignment_get(assignment, i);
        if (value != IPSET_EITHER) {
            return i;
        }
    }

    return 0;
}


/**
 * Create a generic IP address object from the current expanded
 * assignment.
 */
static void
create_ip_address(struct ipset_iterator *iterator)
{
    memset(&iterator->addr, 0, sizeof(struct cork_ip));
    enum ipset_tribool *values = iterator->bdd_iterator->assignment->values;
    
    if (iterator->multiple_expansion_state == IPSET_ITERATOR_MULTIPLE_IPV4) {
        iterator->addr.version = CORK_IP_VERSION_4;
        for (int i = 0; i < iterator->cidr_prefix; i++) {
            if (values[i+1] == IPSET_TRUE) {
                uint8_t *addr = (uint8_t *)&iterator->addr.ip.v4.addr;
                IPSET_BIT_SET(addr, i);
            }
        }
    } else {
        iterator->addr.version = CORK_IP_VERSION_6;
        for (int i = 0; i < iterator->cidr_prefix; i++) {
            if (values[i+1] == IPSET_TRUE) {
                IPSET_BIT_SET(iterator->addr.ip.v6.addr, i);
            }
        }
    }
}


/**
 * Advance the BDD iterator, taking into account that some assignments
 * need to be expanded twice.
 */
static void
advance_assignment(struct ipset_iterator *iterator)
{
    if (CORK_LIKELY(iterator->multiple_expansion_state == IPSET_ITERATOR_NORMAL)) {
        ipset_bdd_iterator_advance(iterator->bdd_iterator);
        process_assignment(iterator);
        return;
    }

    if (iterator->multiple_expansion_state == IPSET_ITERATOR_MULTIPLE_IPV4) {
        // Handle IPv4 advancement
        iterator->multiple_expansion_state = IPSET_ITERATOR_MULTIPLE_IPV6;
        ipset_assignment_set(iterator->bdd_iterator->assignment, 0, IPSET_FALSE);
        expand_ipv6(iterator);
    } else if (iterator->multiple_expansion_state == IPSET_ITERATOR_MULTIPLE_IPV6) {
        // Move to next assignment
        ipset_assignment_set(iterator->bdd_iterator->assignment, 0, IPSET_EITHER);
        ipset_bdd_iterator_advance(iterator->bdd_iterator);
        process_assignment(iterator);
    }
}


/**
 * Process the current expanded assignment in the current BDD
 * assignment.
 */
static void
process_expanded_assignment(struct ipset_iterator *iterator)
{
    if (iterator->assignment_iterator->finished) {
        // Current expanded assignment is done; move to next assignment
        ipset_expanded_assignment_free(iterator->assignment_iterator);
        iterator->assignment_iterator = NULL;
        advance_assignment(iterator);
        return;
    }

    create_ip_address(iterator);
}


/**
 * Expand the current assignment as IPv4 addresses.
 */
static void
expand_ipv4(struct ipset_iterator *iterator)
{
    // IPv4 expansion logic
    if (iterator->summarize) {
        // Summarize networks when possible
        memset(&iterator->addr, 0, sizeof(struct cork_ip));
        iterator->addr.version = CORK_IP_VERSION_4;
        
        // Copy the IPv4 address bits from the assignment
        enum ipset_tribool *values = iterator->bdd_iterator->assignment->values;
        for (int i = 1; i <= 32; i++) {
            if (values[i] == IPSET_TRUE) {
                uint8_t *addr = (uint8_t *)&iterator->addr.ip.v4.addr;
                IPSET_BIT_SET(addr, i-1);
            }
        }
    }
}


/**
 * Expand the current assignment as IPv6 addresses.
 */
static void
expand_ipv6(struct ipset_iterator *iterator)
{
    // IPv6 expansion logic
    memset(&iterator->addr, 0, sizeof(struct cork_ip));
    iterator->addr.version = CORK_IP_VERSION_6;
    
    // Copy the IPv6 address bits from the assignment
    enum ipset_tribool *values = iterator->bdd_iterator->assignment->values;
    for (int i = 1; i <= 128; i++) {
        if (values[i] == IPSET_TRUE) {
            IPSET_BIT_SET(iterator->addr.ip.v6.addr, i-1);
        }
    }
}


/**
 * Process the current assignment in the BDD iterator.
 */

static void
process_assignment(struct ipset_iterator *iterator)
{
    enum ipset_tribool *values = iterator->bdd_iterator->assignment->values;
    if (values[0] == IPSET_TRUE) {
        // IPv4 address
        iterator->multiple_expansion_state = IPSET_ITERATOR_MULTIPLE_IPV4;
        expand_ipv4(iterator);
    } else {
        // IPv6 address
        iterator->multiple_expansion_state = IPSET_ITERATOR_MULTIPLE_IPV6;
        expand_ipv6(iterator);
    }
}


static struct ipset_iterator *
create_iterator(struct ip_set *set, bool desired_value, bool summarize)
{
    /* First allocate the iterator itself. */
    struct ipset_iterator  *iterator = cork_new(struct ipset_iterator);
    iterator->finished = false;
    iterator->assignment_iterator = NULL;
    iterator->desired_value = desired_value;
    iterator->summarize = summarize;

    /* Then create the iterator that returns each BDD assignment. */
    DEBUG("Iterating set");
    iterator->bdd_iterator = ipset_node_iterate(set->cache, set->set_bdd);

    /* Then drill down from the current BDD assignment, creating an
     * expanded assignment for it. */
    process_assignment(iterator);
    return iterator;
}


struct ipset_iterator *
ipset_iterate(struct ip_set *set, bool desired_value)
{
    return create_iterator(set, desired_value, false);
}


struct ipset_iterator *
ipset_iterate_networks(struct ip_set *set, bool desired_value)
{
    return create_iterator(set, desired_value, true);
}


void
ipset_iterator_free(struct ipset_iterator *iterator)
{
    if (iterator->bdd_iterator != NULL) {
        ipset_bdd_iterator_free(iterator->bdd_iterator);
    }
    if (iterator->assignment_iterator != NULL) {
        ipset_expanded_assignment_free(iterator->assignment_iterator);
    }
    free(iterator);
}


void
ipset_iterator_advance(struct ipset_iterator *iterator)
{
    /* If we're already at the end of the iterator, don't do anything. */

    if (CORK_UNLIKELY(iterator->finished)) {
        return;
    }

    /* Otherwise, advance the expanded assignment iterator to the next
     * assignment, and then drill down into it. */

    DEBUG("Advancing set iterator");
    ipset_expanded_assignment_advance(iterator->assignment_iterator);
    process_expanded_assignment(iterator);
}
