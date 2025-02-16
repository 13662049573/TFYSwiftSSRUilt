VERSION_INFO = 2:0:0

if platform_suffix_ios
AM_CFLAGS = -g -O2 -Wall -Werror -Wno-deprecated-declarations -fno-strict-aliasing -fPIC -arch arm64 -isysroot `xcrun --sdk iphoneos --show-sdk-path` -mios-version-min=15.0
else
AM_CFLAGS = -g -O2 -Wall -Werror -Wno-deprecated-declarations -fno-strict-aliasing -fPIC -arch arm64 -isysroot `xcrun --sdk macosx --show-sdk-path` -mmacosx-version-min=12.0
endif

AM_CFLAGS += $(PTHREAD_CFLAGS)
if !USE_SYSTEM_SHARED_LIB
AM_CFLAGS += -I$(top_srcdir)/libbloom
AM_CFLAGS += -I$(top_srcdir)/libcork/include
AM_CFLAGS += -I$(top_srcdir)/libipset/include
endif
AM_CFLAGS += -I/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/pcre/include

SS_COMMON_LIBS = $(INET_NTOP_LIB)
if !USE_SYSTEM_SHARED_LIB
SS_COMMON_LIBS += $(top_builddir)/libbloom/libbloom.la \
                  $(top_builddir)/libcork/libcork.la \
                  $(top_builddir)/libipset/libipset.la
endif
SS_COMMON_LIBS += -lev_$(platform_suffix) \
                  -lmaxminddb_$(platform_suffix) \
                  -lsodium_$(platform_suffix) \
                  -lmbedcrypto_$(platform_suffix) \
                  -lmbedtls_$(platform_suffix) \
                  -lmbedx509_$(platform_suffix) \
                  -lssl_$(platform_suffix) \
                  -lcrypto_$(platform_suffix) \
                  -lpcre_$(platform_suffix) \
                  -lcares_$(platform_suffix)

bin_PROGRAMS = ss-local ss-tunnel ss-server ss-manager

acl_src = rule.c \
          acl.c

crypto_src = crypto.c \
             aead.c \
             stream.c \
             ppbloom.c \
             base64.c

plugin_src = plugin.c

common_src = utils.c \
             jconf.c \
             json.c \
             udprelay.c \
             cache.c \
             netutils.c

if BUILD_WINCOMPAT
common_src += winsock.c
endif

ss_local_SOURCES = utils.c \
                   jconf.c \
                   json.c \
                   udprelay.c \
                   cache.c \
                   acl.c \
                   netutils.c \
                   local.c \
                   plugin.c \
                   ppbloom.c \
                   rule.c \
                   base64.c \
                   stream.c \
                   aead.c \
                   crypto.c

ss_tunnel_SOURCES = utils.c \
                    jconf.c \
                    json.c \
                    udprelay.c \
                    cache.c \
                    netutils.c \
                    tunnel.c \
                    plugin.c \
                    ppbloom.c \
                    base64.c \
                    stream.c \
                    aead.c \
                    crypto.c

ss_server_SOURCES = utils.c \
                    jconf.c \
                    json.c \
                    udprelay.c \
                    cache.c \
                    acl.c \
                    resolv.c \
                    netutils.c \
                    server.c \
                    plugin.c \
                    ppbloom.c \
                    rule.c \
                    base64.c \
                    stream.c \
                    aead.c \
                    crypto.c

ss_manager_SOURCES = utils.c \
                     jconf.c \
                     json.c \
                     manager.c

ss_local_LDADD = $(SS_COMMON_LIBS)
ss_tunnel_LDADD = $(SS_COMMON_LIBS)
ss_server_LDADD = $(SS_COMMON_LIBS)
ss_manager_LDADD = $(SS_COMMON_LIBS)

if platform_suffix_ios
ss_local_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk iphoneos --show-sdk-path` -mios-version-min=15.0
ss_tunnel_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk iphoneos --show-sdk-path` -mios-version-min=15.0
ss_server_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk iphoneos --show-sdk-path` -mios-version-min=15.0
ss_manager_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk iphoneos --show-sdk-path` -mios-version-min=15.0
else
ss_local_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk macosx --show-sdk-path` -mmacosx-version-min=12.0
ss_tunnel_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk macosx --show-sdk-path` -mmacosx-version-min=12.0
ss_server_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk macosx --show-sdk-path` -mmacosx-version-min=12.0
ss_manager_LDFLAGS = -arch arm64 -isysroot `xcrun --sdk macosx --show-sdk-path` -mmacosx-version-min=12.0
endif

ss_local_CFLAGS = $(AM_CFLAGS) -DMODULE_LOCAL
ss_tunnel_CFLAGS = $(AM_CFLAGS) -DMODULE_TUNNEL
ss_server_CFLAGS = $(AM_CFLAGS) -DMODULE_REMOTE
ss_manager_CFLAGS = $(AM_CFLAGS) -DMODULE_MANAGER

if BUILD_REDIRECTOR
bin_SCRIPTS = ss-nat
bin_PROGRAMS += ss-redir
ss_redir_SOURCES = utils.c \
                   jconf.c \
                   json.c \
                   netutils.c \
                   cache.c \
                   udprelay.c \
                   redir.c \
                   $(crypto_src) \
                   $(plugin_src)

ss_redir_CFLAGS = $(AM_CFLAGS) -DMODULE_REDIR
ss_redir_LDADD = $(SS_COMMON_LIBS)
ss_redir_LDADD += -lcares
endif

lib_LTLIBRARIES = libshadowsocks-libev.la
libshadowsocks_libev_la_SOURCES = $(ss_local_SOURCES)
libshadowsocks_libev_la_CFLAGS = $(ss_local_CFLAGS) -DLIB_ONLY
libshadowsocks_libev_la_LDFLAGS = -version-info $(VERSION_INFO)
libshadowsocks_libev_la_LIBADD = $(ss_local_LDADD)
include_HEADERS = shadowsocks.h

noinst_HEADERS = acl.h crypto.h stream.h aead.h json.h netutils.h redir.h server.h uthash.h \
                 cache.h local.h plugin.h resolv.h tunnel.h utils.h base64.h ppbloom.h \
                 common.h jconf.h manager.h rule.h socks5.h udprelay.h winsock.h
EXTRA_DIST = ss-nat
