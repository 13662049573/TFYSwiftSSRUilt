AC_PREREQ([2.67])
AC_INIT([shadowsocks-libev], [3.3.5], [max.c.lv@gmail.com])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_AUX_DIR([auto])
AC_CONFIG_MACRO_DIR([m4])
AC_USE_SYSTEM_EXTENSIONS

AM_INIT_AUTOMAKE([foreign -Wall -Werror subdir-objects])
m4_ifdef([AM_PROG_AR], [AM_PROG_AR])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])
AM_MAINTAINER_MODE
AM_DEP_TRACK

# Define conditional flags
AM_CONDITIONAL([USE_SYSTEM_SHARED_LIB], [test "x$enable_system_shared_lib" = "xyes"])
AM_CONDITIONAL([ENABLE_DOCUMENTATION], [test "x$enable_documentation" = "xyes"])
AM_CONDITIONAL([BUILD_WINCOMPAT], [test "x$build_wincompat" = "xyes"])
AM_CONDITIONAL([BUILD_REDIRECTOR], [test "x$build_redirector" = "xyes"])

dnl Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_INSTALL
LT_INIT([disable-shared])
AC_PROG_LN_S
AC_PROG_MAKE_SET

dnl Checks for header files.
AC_CHECK_HEADERS([limits.h stdint.h inttypes.h stdlib.h string.h unistd.h])
AC_CHECK_HEADERS([sys/time.h time.h])
AC_CHECK_HEADERS([sys/socket.h])
AC_CHECK_HEADERS([netdb.h netinet/in.h])
AC_CHECK_HEADERS([arpa/inet.h])
AC_CHECK_HEADERS([linux/tcp.h linux/udp.h])
AC_CHECK_HEADERS([netinet/tcp.h])

dnl Checks for typedefs, structures, and compiler characteristics.
AC_C_BIGENDIAN
AC_C_INLINE
AC_TYPE_SSIZE_T
AC_TYPE_SIZE_T
AC_TYPE_INT64_T
AC_TYPE_UINT16_T
AC_TYPE_UINT32_T
AC_TYPE_UINT64_T
AC_TYPE_UINT8_T
AC_TYPE_PID_T

dnl Checks for library functions.
AC_CHECK_FUNCS([malloc memset socket])
AC_CHECK_FUNCS([select])
AC_CHECK_FUNCS([clock_gettime])
AC_CHECK_FUNCS([gettimeofday])
AC_CHECK_FUNCS([inet_ntoa])
AC_CHECK_FUNCS([memmove])
AC_CHECK_FUNCS([memset])
AC_CHECK_FUNCS([select])
AC_CHECK_FUNCS([socket])
AC_CHECK_FUNCS([strchr])
AC_CHECK_FUNCS([strrchr])
AC_CHECK_FUNCS([strerror])

AC_CONFIG_FILES([Makefile
                 libbloom/Makefile
                 libcork/Makefile
                 libipset/Makefile
                 src/Makefile])
AC_OUTPUT
