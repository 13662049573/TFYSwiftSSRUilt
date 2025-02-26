/* -*- coding: utf-8 -*-
 * ----------------------------------------------------------------------
 * Copyright © 2012, libcork authors
 * All rights reserved.
 *
 * Please see the COPYING file in this distribution for license details.
 * ----------------------------------------------------------------------
 */

#ifndef LIBCORK_CORE_API_H
#define LIBCORK_CORE_API_H

#include <libcork/config.h>
#include <libcork/core/attributes.h>
#include <libcork/config/version.h>


/*-----------------------------------------------------------------------
 * Calling conventions
 */

/* If you're using libcork as a shared library, you don't need to do anything
 * special; the following will automatically set things up so that libcork's
 * public symbols are imported from the library.  When we build the shared
 * library, we define this ourselves to export the symbols. */

#if !defined(CORK_API)
#define CORK_API  CORK_IMPORT
#endif


/*-----------------------------------------------------------------------
 * Library version
 */

/* If you need the version number of the current Cork release, you should use
 * these macros.  The version numbers in cork/core/api.h are the version of the
 * API that you're building your code against; the ones defined here are the
 * version of the implementation that you're linking against. */

/* The current version of the Cork implementation. */
#define CORK_PACKAGE_MAJOR_VERSION   CORK_CONFIG_VERSION_MAJOR
#define CORK_PACKAGE_MINOR_VERSION   CORK_CONFIG_VERSION_MINOR
#define CORK_PACKAGE_PATCH_VERSION   CORK_CONFIG_VERSION_PATCH

CORK_API const char *
cork_version_string(void)
    CORK_ATTR_CONST;

CORK_API const char *
cork_revision_string(void)
    CORK_ATTR_CONST;


#endif /* LIBCORK_CORE_API_H */
