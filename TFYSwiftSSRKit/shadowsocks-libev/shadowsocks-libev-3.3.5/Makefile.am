if USE_SYSTEM_SHARED_LIB
SUBDIRS = src
else
SUBDIRS = libcork libbloom libipset src
endif

if ENABLE_DOCUMENTATION
SUBDIRS += doc
endif

ACLOCAL_AMFLAGS = -I m4

pkgconfiglibdir = $(libdir)/pkgconfig
pkgconfiglib_DATA = shadowsocks-libev.pc

EXTRA_DIST = acl.h \
             crypto.h \
             include.am \
             README.md \
             Changes \
             LICENSE \
             COPYING \
             shadowsocks-libev.pc.in
