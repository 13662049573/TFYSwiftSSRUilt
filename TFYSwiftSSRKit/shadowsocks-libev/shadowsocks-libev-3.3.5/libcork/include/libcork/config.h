/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license
 * details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CONFIG_H
#define LIBCORK_CONFIG_H

/* If you want to configure how libcork is built, create a config.h header
 * file, and place it somewhere that will appear in the include path before
 * libcork's include directory.  In that header file, provide any of the
 * following macros that you want to override the defaults:
 *
 * #define CORK_CONFIG_HAVE_REALLOCF  1
 *   If your system has a reallocf function
 *
 * #define CORK_CONFIG_HAVE_PTHREAD_THREAD_LOCAL  1
 *   If your system has a __thread thread-local storage qualifier
 *
 * #define CORK_CONFIG_HAVE_GCC_ATOMICS  1
 *   If your compiler provides GCC-style atomic intrinsics
 *
 * #define CORK_CONFIG_HAVE_GCC_INT128  1
 *   If your compiler provides a 128-bit integer type
 *
 * #define CORK_CONFIG_HAVE_ANONYMOUS_MAPS  1
 *   If your system has support for memory mapped files
 *
 * #define CORK_CONFIG_HAVE_CLOCK_GETTIME  1
 *   If your system has a clock_gettime function
 *
 * #define CORK_CONFIG_HAVE_DLSYM  1
 *   If your system has a dlsym function
 *
 * #define CORK_CONFIG_HAVE_GETADDRINFO  1
 *   If your system has a getaddrinfo function
 *
 * #define CORK_CONFIG_HAVE_STRNLEN  1
 *   If your system has a strnlen function
 */

#if defined(__APPLE__)
#define CORK_CONFIG_HAVE_REALLOCF  1
#define CORK_CONFIG_HAVE_PTHREAD_THREAD_LOCAL  1
#define CORK_CONFIG_HAVE_GCC_ATOMICS  1
#define CORK_CONFIG_HAVE_GCC_INT128  1
#define CORK_CONFIG_HAVE_ANONYMOUS_MAPS  1
#define CORK_CONFIG_HAVE_CLOCK_GETTIME  1
#define CORK_CONFIG_HAVE_DLSYM  1
#define CORK_CONFIG_HAVE_GETADDRINFO  1
#define CORK_CONFIG_HAVE_STRNLEN  1
#define CORK_CONFIG_IS_STATIC  1
#endif

/*** include all of the parts ***/

#include <libcork/config/config.h>

#endif /* LIBCORK_CONFIG_H */
