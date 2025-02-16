/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2013, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>

#include "libcork/core/types.h"
#include "libcork/posix/env.h"
#include "libcork/helpers/errors.h"

/* Get raw environment variable value */
const char *
cork_env_get_raw(const char *name)
{
    return getenv(name);
}

/* Set raw environment variable */
int
cork_env_set_raw(const char *name, const char *value)
{
#if defined(__APPLE__)
    if (value == NULL) {
        unsetenv(name);
        return 0;
    } else {
        return setenv(name, value, 1);
    }
#else
    if (value == NULL) {
        return unsetenv(name);
    } else {
        return setenv(name, value, 1);
    }
#endif
}

/* Remove raw environment variable */
int
cork_env_unset_raw(const char *name)
{
#if defined(__APPLE__)
    unsetenv(name);
    return 0;
#else
    return unsetenv(name);
#endif
}

/* Get environment variable with default value */
const char *
cork_env_get(const char *name, const char *default_value)
{
    const char *value = cork_env_get_raw(name);
    return (value == NULL)? default_value: value;
}

/* Get boolean environment variable */
bool
cork_env_get_bool(const char *name, bool default_value)
{
    const char *value = cork_env_get_raw(name);
    if (value == NULL) {
        return default_value;
    }

    switch (value[0]) {
        case '1':
        case 't':
        case 'T':
        case 'y':
        case 'Y':
            return true;
        
        case '0':
        case 'f':
        case 'F':
        case 'n':
        case 'N':
            return false;
        
        default:
            return default_value;
    }
}

/* Get integer environment variable */
int
cork_env_get_int(const char *name, int default_value)
{
    const char *value = cork_env_get_raw(name);
    if (value == NULL) {
        return default_value;
    }

    char *endptr;
    long result = strtol(value, &endptr, 10);
    
    if (*endptr != '\0' || result > INT_MAX || result < INT_MIN) {
        return default_value;
    }
    
    return (int)result;
}

/* Get unsigned integer environment variable */
unsigned int
cork_env_get_uint(const char *name, unsigned int default_value)
{
    const char *value = cork_env_get_raw(name);
    if (value == NULL) {
        return default_value;
    }

    char *endptr;
    unsigned long result = strtoul(value, &endptr, 10);
    
    if (*endptr != '\0' || result > UINT_MAX) {
        return default_value;
    }
    
    return (unsigned int)result;
}

/* Set environment variable with error checking */
int
cork_env_set(const char *name, const char *value)
{
    int rc = cork_env_set_raw(name, value);
    if (rc != 0) {
        cork_system_error_set();
        return -1;
    }
    return 0;
}

/* Remove environment variable with error checking */
int
cork_env_unset(const char *name)
{
    int rc = cork_env_unset_raw(name);
    if (rc != 0) {
        cork_system_error_set();
        return -1;
    }
    return 0;
}
