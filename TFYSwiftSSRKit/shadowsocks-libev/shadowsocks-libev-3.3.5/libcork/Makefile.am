VERSION_INFO = 1:0:0

AM_CFLAGS = -I$(top_srcdir)/libcork/include \
            -DCORK_CONFIG_SKIP_AUTODETECT=1

lib_LTLIBRARIES = libcork.la

libcork_la_SOURCES = \
    src/libcork/cli/commands.c \
    src/libcork/core/allocator.c \
    src/libcork/core/error.c \
    src/libcork/core/gc.c \
    src/libcork/core/hash.c \
    src/libcork/core/ip-address.c \
    src/libcork/core/mempool.c \
    src/libcork/core/timestamp.c \
    src/libcork/core/u128.c \
    src/libcork/ds/array.c \
    src/libcork/ds/bitset.c \
    src/libcork/ds/buffer.c \
    src/libcork/ds/dllist.c \
    src/libcork/ds/file-stream.c \
    src/libcork/ds/hash-table.c \
    src/libcork/ds/managed-buffer.c \
    src/libcork/ds/ring-buffer.c \
    src/libcork/ds/slice.c \
    src/libcork/posix/directory-walker.c \
    src/libcork/posix/env.c \
    src/libcork/posix/exec.c \
    src/libcork/posix/files.c \
    src/libcork/posix/process.c \
    src/libcork/posix/subprocess.c \
    src/libcork/pthreads/thread.c

libcork_la_LDFLAGS = -version-info $(VERSION_INFO)

nobase_include_HEADERS = \
    include/libcork/cli.h \
    include/libcork/cli/commands.h \
    include/libcork/config.h \
    include/libcork/config/arch.h \
    include/libcork/config/config.h \
    include/libcork/config/custom.h \
    include/libcork/config/gcc.h \
    include/libcork/config/linux.h \
    include/libcork/config/macosx.h \
    include/libcork/config/version.h \
    include/libcork/core.h \
    include/libcork/core/allocator.h \
    include/libcork/core/api.h \
    include/libcork/core/attributes.h \
    include/libcork/core/byte-order.h \
    include/libcork/core/callbacks.h \
    include/libcork/core/error.h \
    include/libcork/core/gc.h \
    include/libcork/core/hash.h \
    include/libcork/core/id.h \
    include/libcork/core/mempool.h \
    include/libcork/core/net-addresses.h \
    include/libcork/core/timestamp.h \
    include/libcork/core/types.h \
    include/libcork/core/u128.h \
    include/libcork/ds.h \
    include/libcork/ds/array.h \
    include/libcork/ds/bitset.h \
    include/libcork/ds/buffer.h \
    include/libcork/ds/dllist.h \
    include/libcork/ds/file-stream.h \
    include/libcork/ds/hash-table.h \
    include/libcork/ds/managed-buffer.h \
    include/libcork/ds/ring-buffer.h \
    include/libcork/ds/slice.h \
    include/libcork/ds/stream.h \
    include/libcork/helpers/errors.h \
    include/libcork/helpers/gc.h \
    include/libcork/os.h \
    include/libcork/os/files.h \
    include/libcork/os/process.h \
    include/libcork/os/subprocess.h \
    include/libcork/threads.h \
    include/libcork/threads/atomics.h \
    include/libcork/threads/basics.h
