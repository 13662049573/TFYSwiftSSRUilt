#ifndef LIBCORK_POSIX_ENV_H
#define LIBCORK_POSIX_ENV_H

#include <libcork/core/api.h>
#include <libcork/core/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Get an environment variable */
CORK_API const char *
cork_env_get_raw(const char *name);

/* Set an environment variable */
CORK_API int
cork_env_set_raw(const char *name, const char *value);

/* Remove an environment variable */
CORK_API int
cork_env_unset_raw(const char *name);

/* Get an environment variable with default value */
CORK_API const char *
cork_env_get(const char *name, const char *default_value);

/* Get an environment variable as a boolean */
CORK_API bool
cork_env_get_bool(const char *name, bool default_value);

/* Get an environment variable as an integer */
CORK_API int
cork_env_get_int(const char *name, int default_value);

/* Get an environment variable as an unsigned integer */
CORK_API unsigned int
cork_env_get_uint(const char *name, unsigned int default_value);

/* Set an environment variable with error checking */
CORK_API int
cork_env_set(const char *name, const char *value);

/* Remove an environment variable with error checking */
CORK_API int
cork_env_unset(const char *name);

#ifdef __cplusplus
}
#endif

#endif /* LIBCORK_POSIX_ENV_H */ 