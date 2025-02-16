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
AM_CONDITIONAL([platform_suffix_ios], [test "x$platform_suffix" = "xios"])

dnl Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_INSTALL
LT_INIT([disable-shared])
AC_PROG_LN_S
AC_PROG_MAKE_SET

# Add include paths for dependencies
LIBEV_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libev"
LIBMAXMINDDB_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libmaxminddb"
LIBSODIUM_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/libsodium"
MBEDTLS_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/mbedtls"
OPENSSL_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/openssl"
PCRE_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/pcre"
CARES_PATH="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/c-ares"

# Set platform-specific flags and SDK paths
if test "x$platform_suffix" = "xios"; then
    SDK_PATH=`xcrun --sdk iphoneos --show-sdk-path`
    CPPFLAGS="-I$SDK_PATH/usr/include"
    CFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-version-min=15.0"
    LDFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-version-min=15.0"
else
    SDK_PATH=`xcrun --sdk macosx --show-sdk-path`
    CPPFLAGS="-I$SDK_PATH/usr/include"
    CFLAGS="-arch arm64 -isysroot $SDK_PATH -mmacosx-version-min=12.0"
    LDFLAGS="-arch arm64 -isysroot $SDK_PATH -mmacosx-version-min=12.0"
fi

# Add dependency include paths
CPPFLAGS="$CPPFLAGS -I$LIBEV_PATH/include"
CPPFLAGS="$CPPFLAGS -I$LIBMAXMINDDB_PATH/include"
CPPFLAGS="$CPPFLAGS -I$LIBSODIUM_PATH/include"
CPPFLAGS="$CPPFLAGS -I$MBEDTLS_PATH/include"
CPPFLAGS="$CPPFLAGS -I$OPENSSL_PATH/include"
CPPFLAGS="$CPPFLAGS -I$PCRE_PATH/include"
CPPFLAGS="$CPPFLAGS -I$CARES_PATH/include"

# Add library paths for dependencies
LDFLAGS="$LDFLAGS -L$LIBEV_PATH/lib"
LDFLAGS="$LDFLAGS -L$LIBMAXMINDDB_PATH/lib"
LDFLAGS="$LDFLAGS -L$LIBSODIUM_PATH/lib"
LDFLAGS="$LDFLAGS -L$MBEDTLS_PATH/lib"
LDFLAGS="$LDFLAGS -L$OPENSSL_PATH/lib"
LDFLAGS="$LDFLAGS -L$PCRE_PATH/lib"
LDFLAGS="$LDFLAGS -L$CARES_PATH/lib"

# Add library dependencies with platform suffix
LIBS="$LIBS -lev_\${platform_suffix} -lmaxminddb_\${platform_suffix} -lsodium_\${platform_suffix}"
LIBS="$LIBS -lmbedcrypto_\${platform_suffix} -lmbedtls_\${platform_suffix} -lmbedx509_\${platform_suffix}"
LIBS="$LIBS -lssl_\${platform_suffix} -lcrypto_\${platform_suffix} -lpcre_\${platform_suffix} -lcares_\${platform_suffix}"

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
ac_cv_func_malloc=yes
ac_cv_func_memset=yes
ac_cv_func_socket=yes
ac_cv_func_select=yes
ac_cv_func_clock_gettime=yes
ac_cv_func_gettimeofday=yes
ac_cv_func_inet_ntoa=yes
ac_cv_func_memmove=yes
ac_cv_func_strchr=yes
ac_cv_func_strrchr=yes
ac_cv_func_strerror=yes

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

AC_CONFIG_FILES([Makefile
                 libbloom/Makefile
                 libcork/Makefile
                 libipset/Makefile
                 src/Makefile])
AC_OUTPUT
