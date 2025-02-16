#ifndef LIBCORK_CORE_CONTAINER_H
#define LIBCORK_CORE_CONTAINER_H

#include <libcork/core/api.h>

/* Get a pointer to the struct containing a member */
#define cork_container_of(ptr, type, member) \
    ((type *)((char *)(ptr) - offsetof(type, member)))

#endif /* LIBCORK_CORE_CONTAINER_H */ 