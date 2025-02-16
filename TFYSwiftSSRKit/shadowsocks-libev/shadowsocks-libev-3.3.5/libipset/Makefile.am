VERSION_INFO = 1:0:0

if platform_suffix_ios
AM_CFLAGS = -I$(top_srcdir)/libipset/include -I$(top_srcdir)/libcork/include -arch arm64 -isysroot `xcrun --sdk iphoneos --show-sdk-path` -mios-version-min=15.0
else
AM_CFLAGS = -I$(top_srcdir)/libipset/include -I$(top_srcdir)/libcork/include -arch arm64 -isysroot `xcrun --sdk macosx --show-sdk-path` -mmacosx-version-min=12.0
endif

lib_LTLIBRARIES = libipset.la

libipset_la_SOURCES = \
    src/libipset/general.c \
    src/libipset/bdd/assignments.c \
    src/libipset/bdd/basics.c \
    src/libipset/bdd/bdd-iterator.c \
    src/libipset/bdd/expanded.c \
    src/libipset/bdd/reachable.c \
    src/libipset/bdd/read.c \
    src/libipset/bdd/write.c \
    src/libipset/map/allocation.c \
    src/libipset/map/inspection.c \
    src/libipset/map/ipv4_map.c \
    src/libipset/map/ipv6_map.c \
    src/libipset/map/storage.c \
    src/libipset/set/ipv4_set.c \
    src/libipset/set/ipv6_set.c \
    src/libipset/set/iterator.c

libipset_la_LDFLAGS = -version-info $(VERSION_INFO)

include_HEADERS = \
    include/ipset/bdd/nodes.h \
    include/ipset/bits.h \
    include/ipset/errors.h \
    include/ipset/ipset.h
