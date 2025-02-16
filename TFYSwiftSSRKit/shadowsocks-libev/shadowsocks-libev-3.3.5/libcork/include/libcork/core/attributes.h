/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_ATTRIBUTES_H
#define LIBCORK_CORE_ATTRIBUTES_H

#include <libcork/config.h>

/* API visibility macros */
#if defined(_WIN32) || defined(__CYGWIN__)
  #ifdef BUILDING_DLL
    #ifdef __GNUC__
      #define CORK_EXPORT __attribute__ ((dllexport))
    #else
      #define CORK_EXPORT __declspec(dllexport)
    #endif
  #else
    #ifdef __GNUC__
      #define CORK_EXPORT __attribute__ ((dllimport))
    #else
      #define CORK_EXPORT __declspec(dllimport)
    #endif
  #endif
  #define CORK_LOCAL
#else
  #if __GNUC__ >= 4
    #define CORK_EXPORT __attribute__ ((visibility ("default")))
    #define CORK_LOCAL  __attribute__ ((visibility ("hidden")))
  #else
    #define CORK_EXPORT
    #define CORK_LOCAL
  #endif
#endif

/* Function attributes */
#if defined(__GNUC__) || defined(__clang__)
#define CORK_ATTR_CONST  __attribute__((const))
#define CORK_ATTR_PURE  __attribute__((pure))
#define CORK_ATTR_MALLOC  __attribute__((malloc))
#define CORK_ATTR_NOINLINE  __attribute__((noinline))
#define CORK_ATTR_UNUSED  __attribute__((unused))
#define CORK_ATTR_PRINTF(format_index, args_index) \
    __attribute__((format(printf, format_index, args_index)))
#define CORK_ATTR_SENTINEL  __attribute__((sentinel))
#else
#define CORK_ATTR_CONST
#define CORK_ATTR_PURE
#define CORK_ATTR_MALLOC
#define CORK_ATTR_NOINLINE
#define CORK_ATTR_UNUSED
#define CORK_ATTR_PRINTF(format_index, args_index)
#define CORK_ATTR_SENTINEL
#endif

/* Likely/Unlikely macros */
#if defined(__GNUC__) || defined(__clang__)
#define CORK_LIKELY(expr)  __builtin_expect((expr), 1)
#define CORK_UNLIKELY(expr)  __builtin_expect((expr), 0)
#else
#define CORK_LIKELY(expr)  (expr)
#define CORK_UNLIKELY(expr)  (expr)
#endif

/* Initializer macro */
#if defined(__GNUC__) || defined(__clang__)
#define CORK_INITIALIZER(name) \
__attribute__((constructor)) \
static void \
name(void)
#else
#error "Don't know how to implement initialization functions on this platform"
#endif

#endif /* LIBCORK_CORE_ATTRIBUTES_H */
