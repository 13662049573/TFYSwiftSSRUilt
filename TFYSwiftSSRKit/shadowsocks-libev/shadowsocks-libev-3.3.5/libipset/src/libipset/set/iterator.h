#ifndef IPSET_ITERATOR_H
#define IPSET_ITERATOR_H

#include <libcork/core.h>
#include <ipset/bdd/nodes.h>
#include <ipset/bits.h>

/* Iterator states */
enum ipset_iterator_state {
    IPSET_ITERATOR_NORMAL,
    IPSET_ITERATOR_MULTIPLE_IPV4,
    IPSET_ITERATOR_MULTIPLE_IPV6
};

/* Iterator structure */
struct ipset_iterator {
    /* The BDD iterator */
    struct ipset_bdd_iterator *bdd_iterator;
    /* The expanded assignment iterator */
    struct ipset_expanded_assignment *assignment_iterator;
    /* The current IP address */
    struct cork_ip addr;
    /* The CIDR prefix length */
    unsigned int cidr_prefix;
    /* Whether to summarize networks */
    bool summarize;
    /* The current state of multiple expansion */
    enum ipset_iterator_state multiple_expansion_state;
    /* Whether the iterator is finished */
    bool finished;
    /* The desired value for the iterator */
    int desired_value;
};

/* Function declarations */
void process_assignment(struct ipset_iterator *iterator);
void expand_ipv6(struct ipset_iterator *iterator);
void create_ip_address(struct ipset_iterator *iterator);
void advance_assignment(struct ipset_iterator *iterator);
void process_expanded_assignment(struct ipset_iterator *iterator);
void expand_ipv4(struct ipset_iterator *iterator);

#endif /* IPSET_ITERATOR_H */ 