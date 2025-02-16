/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2011, RedJack, LLC.
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CONFIG_CUSTOM_H
#define LIBCORK_CONFIG_CUSTOM_H

/* Version info */
#define CORK_CONFIG_VERSION_MAJOR  1
#define CORK_CONFIG_VERSION_MINOR  0
#define CORK_CONFIG_VERSION_PATCH  0

/* Architecture */
#define CORK_CONFIG_ARCH_X64  0
#define CORK_CONFIG_ARCH_X86  0
#define CORK_CONFIG_ARCH_ARM64  1

/* Endianness */
#define CORK_CONFIG_IS_BIG_ENDIAN  0

/* Platform specific features */
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
#define CORK_CONFIG_HAVE_PTHREAD_CLEANUP  1
#define CORK_CONFIG_HAVE_PTHREAD_SETNAME_NP  1
#define CORK_CONFIG_HAVE_KQUEUE  1
#define CORK_CONFIG_HAVE_POLL  1
#define CORK_CONFIG_HAVE_SELECT  1
#endif

/* API visibility */
#if defined(__GNUC__) && !defined(__CYGWIN__) && !defined(__MINGW32__)
#define CORK_API  __attribute__((visibility("default")))
#else
#define CORK_API
#endif

/* Thread local storage */
#if defined(__APPLE__)
#define CORK_THREAD_LOCAL __thread
#else
#define CORK_THREAD_LOCAL
#endif

#endif /* LIBCORK_CONFIG_CUSTOM_H */ 