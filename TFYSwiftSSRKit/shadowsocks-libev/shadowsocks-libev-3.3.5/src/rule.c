/*
 * Copyright (c) 2011 and 2012, Dustin Lundquist <dustin@null-ptr.net>
 * Copyright (c) 2011 Manuel Kasper <mk@neon1.net>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "rule.h"
#include "utils.h"

rule_t *
create_rule(const char *pattern,
           int port,
           int mode)
{
    rule_t *rule = (rule_t *)calloc(1, sizeof(rule_t));
    if (rule == NULL) {
        return NULL;
    }

    rule->port = port;
    rule->mode = mode;

    const char *error;
    int erroffset;
    rule->pattern_re = pcre_compile(pattern, 0, &error, &erroffset, NULL);
    if (rule->pattern_re == NULL) {
        LOGE("PCRE compilation failed at offset %d: %s", erroffset, error);
        free(rule);
        return NULL;
    }

    rule->next = NULL;
    return rule;
}

int
delete_rule(rule_t *rule)
{
    if (rule == NULL) {
        return 0;
    }

    if (rule->pattern_re != NULL) {
        pcre_free(rule->pattern_re);
    }

    free(rule);
    return 0;
}

void
release_rules(rule_t *rules)
{
    rule_t *curr = rules;
    while (curr != NULL) {
        rule_t *next = curr->next;
        delete_rule(curr);
        curr = next;
    }
}

rule_t *
get_rule(const char *pattern,
         int port,
         int mode,
         rule_t *rules)
{
    rule_t *curr = rules;
    while (curr != NULL) {
        if (curr->port == port && curr->mode == mode) {
            int ovector[30];
            int rc = pcre_exec(curr->pattern_re, NULL, pattern, strlen(pattern),
                             0, 0, ovector, 30);
            if (rc >= 0) {
                return curr;
            }
        }
        curr = curr->next;
    }
    return NULL;
}
