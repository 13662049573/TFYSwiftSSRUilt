/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_API_H
#define LIBCORK_CORE_API_H

#include <libcork/config.h>
#include <libcork/core/attributes.h>

/*-----------------------------------------------------------------------
 * Visibility macros
 */

#if !defined(CORK_EXPORT)
#if defined(__GNUC__) && __GNUC__ >= 4
    #define CORK_EXPORT  __attribute__((visibility("default")))
    #define CORK_IMPORT  __attribute__((visibility("default")))
    #define CORK_LOCAL   __attribute__((visibility("hidden")))
#elif defined(__GNUC__)
    #define CORK_EXPORT
    #define CORK_IMPORT
    #define CORK_LOCAL
#elif defined(_WIN32) || defined(_WIN64)
    #define CORK_EXPORT  __declspec(dllexport)
    #define CORK_IMPORT  __declspec(dllimport)
    #define CORK_LOCAL
#else
    #define CORK_EXPORT
    #define CORK_IMPORT
    #define CORK_LOCAL
#endif
#endif

#if !defined(CORK_API)
#ifdef CORK_CONFIG_IS_STATIC
    #define CORK_API
#else
    #ifdef CORK_CONFIG_IS_LIBRARY
        #define CORK_API  CORK_EXPORT
    #else
        #define CORK_API  CORK_IMPORT
    #endif
#endif
#endif

/*-----------------------------------------------------------------------
 * Library version
 */

#define CORK_VERSION_MAJOR  CORK_CONFIG_VERSION_MAJOR
#define CORK_VERSION_MINOR  CORK_CONFIG_VERSION_MINOR
#define CORK_VERSION_PATCH  CORK_CONFIG_VERSION_PATCH

#define CORK_MAKE_VERSION(major, minor, patch) \
    ((major * 1000000) + (minor * 1000) + patch)

#define CORK_VERSION  \
    CORK_MAKE_VERSION(CORK_VERSION_MAJOR, \
                      CORK_VERSION_MINOR, \
                      CORK_VERSION_PATCH)

CORK_API const char *
cork_version_string(void)
    CORK_ATTR_CONST;

CORK_API const char *
cork_revision_string(void)
    CORK_ATTR_CONST;


#endif /* LIBCORK_CORE_API_H */
