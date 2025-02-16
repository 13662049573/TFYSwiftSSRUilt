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
AM_CONDITIONAL(platform_suffix_ios, test "x$platform_suffix" = "xios")

# Platform specific flags
AM_CONDITIONAL([APPLE], [test "x$build_vendor" = "xapple"])

# Platform specific flags
AM_CONDITIONAL([APPLE], [test "x$build_vendor" = "xapple"])

dnl Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_INSTALL
LT_INIT([disable-shared])
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_PROG_RANLIB
AC_PROG_MKDIR_P
AC_PROG_SED

# Set platform-specific flags and SDK paths
if test "x$platform_suffix" = "xios"; then
    SDK_PATH=`xcrun --sdk iphoneos --show-sdk-path`
    CPPFLAGS="-I$SDK_PATH/usr/include"
    CFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-version-min=15.0 -fembed-bitcode"
    LDFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-version-min=15.0"
else
    SDK_PATH=`xcrun --sdk macosx --show-sdk-path`
    CPPFLAGS="-I$SDK_PATH/usr/include"
    CFLAGS="-arch arm64 -isysroot $SDK_PATH -mmacosx-version-min=12.0"
    LDFLAGS="-arch arm64 -isysroot $SDK_PATH -mmacosx-version-min=12.0"
fi

# Add dependency include paths
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libev/include"
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libmaxminddb/include"
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libsodium/include"
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/mbedtls/include"
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/openssl/include"
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/pcre/include"
CPPFLAGS="$CPPFLAGS -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/c-ares/include"

# Add library paths
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libev/lib"
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libmaxminddb/lib"
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libsodium/lib"
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/mbedtls/lib"
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/openssl/lib"
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/pcre/lib"
LDFLAGS="$LDFLAGS -L/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/c-ares/lib"

# Add library dependencies
LIBS="$LIBS -lev_${platform_suffix} -lmaxminddb_${platform_suffix} -lsodium_${platform_suffix}"
LIBS="$LIBS -lmbedcrypto_${platform_suffix} -lmbedtls_${platform_suffix} -lmbedx509_${platform_suffix}"
LIBS="$LIBS -lssl_${platform_suffix} -lcrypto_${platform_suffix} -lpcre_${platform_suffix} -lcares_${platform_suffix}"

# Export variables
AC_SUBST(CPPFLAGS)
AC_SUBST(CFLAGS)
AC_SUBST(LDFLAGS)
AC_SUBST(LIBS)

# Force all header checks to pass
ac_cv_header_limits_h=yes
ac_cv_header_sys_time_h=yes
ac_cv_header_time_h=yes
ac_cv_header_sys_socket_h=yes
ac_cv_header_netdb_h=yes
ac_cv_header_netinet_in_h=yes
ac_cv_header_arpa_inet_h=yes
ac_cv_header_netinet_tcp_h=yes
ac_cv_header_pcre_h=yes

# Force all type checks to pass
ac_cv_type_size_t=yes
ac_cv_type_ssize_t=yes
ac_cv_type_int64_t=yes
ac_cv_type_uint16_t=yes
ac_cv_type_uint32_t=yes
ac_cv_type_uint64_t=yes
ac_cv_type_uint8_t=yes
ac_cv_type_pid_t=yes

# Force all function checks to pass
ac_cv_func_malloc_0_nonnull=yes
ac_cv_func_realloc_0_nonnull=yes
ac_cv_func_mmap=yes
ac_cv_func_munmap=yes
ac_cv_func_select=yes
ac_cv_func_socket=yes
ac_cv_func_strndup=yes
ac_cv_func_fork=no
ac_cv_func_getpwnam=no
ac_cv_func_getpwuid=no
ac_cv_func_sigaction=yes
ac_cv_func_syslog=no

# Skip all header checks
AC_CHECK_HEADERS([pcre.h], [], [], [])

# Skip all type checks
AC_CHECK_TYPES([size_t], [], [], [])
AC_CHECK_TYPES([ssize_t], [], [], [])
AC_CHECK_TYPES([int64_t], [], [], [])
AC_CHECK_TYPES([uint16_t], [], [], [])
AC_CHECK_TYPES([uint32_t], [], [], [])
AC_CHECK_TYPES([uint64_t], [], [], [])
AC_CHECK_TYPES([uint8_t], [], [], [])
AC_CHECK_TYPES([pid_t], [], [], [])

# Skip all function checks
AC_CHECK_FUNCS([malloc memset socket select clock_gettime gettimeofday inet_ntoa memmove strchr strrchr strerror], [], [], [])

# Add library dependencies
PKG_CHECK_MODULES([PCRE], [libpcre >= 8.20])

AC_CONFIG_FILES([Makefile
                 libbloom/Makefile
                 libcork/Makefile
                 libipset/Makefile
                 src/Makefile
                 shadowsocks-libev.pc])
AC_OUTPUT
