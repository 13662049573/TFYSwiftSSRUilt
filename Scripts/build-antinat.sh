#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit"
VERSION="0.93"
LIB_NAME="antinat"

# 设置编译环境
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# 架构
IOS_ARCHS="arm64"
MACOS_ARCHS="x86_64 arm64"

# 依赖库检查
DEPENDENCY_PATHS=(
    "$DEPS_ROOT/libmaxminddb/install/lib/libmaxminddb_ios.a"
    "$DEPS_ROOT/libsodium/install/lib/libsodium_ios.a"
    "$DEPS_ROOT/openssl/install/lib/libssl_ios.a"
    "$DEPS_ROOT/shadowsocks/install/bin/sslocal"
)

# 日志函数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

log_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

# 错误处理
handle_error() {
    log_error "An error occurred on line $1"
    cleanup
    exit 1
}

trap 'handle_error $LINENO' ERR

# 检查依赖库
check_dependencies() {
    local missing_deps=()
    
    for path in "${DEPENDENCY_PATHS[@]}"; do
        if [ ! -f "$path" ]; then
            local dep_name=$(basename $(dirname $(dirname "$path")))
            log_warning "Missing file: $path"
            missing_deps+=($dep_name)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please check if the following dependencies are built correctly:"
        for dep in "${missing_deps[@]}"; do
            if [ "$dep" = "shadowsocks" ]; then
                log_info "  - $dep: $DEPS_ROOT/$dep/install/bin"
            else
                log_info "  - $dep: $DEPS_ROOT/$dep/install/lib"
            fi
        done
        log_info "Try rebuilding the dependencies with:"
        for dep in "${missing_deps[@]}"; do
            log_info "  ./Scripts/build-$dep.sh"
        done
        return 1
    fi
    
    # 检查头文件
    local HEADER_PATHS=(
        "$DEPS_ROOT/libmaxminddb/install/include/maxminddb.h"
        "$DEPS_ROOT/libsodium/install/include/sodium.h"
        "$DEPS_ROOT/openssl/install/include/openssl/ssl.h"
        "$DEPS_ROOT/shadowsocks/install/include/shadowsocks.h"
    )
    
    local missing_headers=()
    for path in "${HEADER_PATHS[@]}"; do
        if [ ! -f "$path" ]; then
            local dep_name=$(basename $(dirname $(dirname $(dirname "$path"))))
            log_warning "Missing header: $path"
            missing_headers+=($dep_name)
        fi
    done
    
    if [ ${#missing_headers[@]} -ne 0 ]; then
        log_error "Missing headers for: ${missing_headers[*]}"
        return 1
    fi
    
    return 0
}

# 清理函数
cleanup() {
    if [ "$1" = "success" ]; then
        log_info "Cleaning up build files after successful build..."
        rm -rf "$DEPS_ROOT/$LIB_NAME/build"
        rm -rf "$DEPS_ROOT/$LIB_NAME/install/ios"
        rm -rf "$DEPS_ROOT/$LIB_NAME/install/macos"
    else
        log_info "Keeping build files for debugging..."
    fi
}

# 创建必要的目录
mkdir -p "$DEPS_ROOT/$LIB_NAME"
mkdir -p "$SCRIPT_DIR/backup"

# 下载和构建
build_antinat() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local SRC_DIR="$BUILD_DIR/${LIB_NAME}-${VERSION}"
    
    log_info "Building $LIB_NAME version $VERSION..."
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$SRC_DIR/src"
    cd "$SRC_DIR"
    
    # 创建源代码文件
    log_info "Creating source files..."
    
    # 创建 configure.ac
    cat > configure.ac << 'EOF'
AC_INIT([antinat], [0.93])
AM_INIT_AUTOMAKE([foreign subdir-objects])
AC_CONFIG_SRCDIR([src/antinat.c])
AC_CONFIG_HEADERS([config.h])

# Checks for programs
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_PROG_RANLIB

# 添加编译器标志
CFLAGS="$CFLAGS"
LDFLAGS="$LDFLAGS"

# 检查头文件路径和设置条件
AC_ARG_WITH([maxminddb],
    [AS_HELP_STRING([--with-maxminddb=DIR], [maxminddb installation directory])],
    [
        CPPFLAGS="$CPPFLAGS -I$withval/include"
        LDFLAGS="$LDFLAGS -L$withval/lib"
        have_maxminddb=yes
    ],
    [have_maxminddb=no])
AM_CONDITIONAL([HAVE_MAXMINDDB], [test "x$have_maxminddb" = "xyes"])

AC_ARG_WITH([sodium],
    [AS_HELP_STRING([--with-sodium=DIR], [sodium installation directory])],
    [
        CPPFLAGS="$CPPFLAGS -I$withval/include"
        LDFLAGS="$LDFLAGS -L$withval/lib"
        have_sodium=yes
    ],
    [have_sodium=no])
AM_CONDITIONAL([HAVE_SODIUM], [test "x$have_sodium" = "xyes"])

AC_ARG_WITH([openssl],
    [AS_HELP_STRING([--with-openssl=DIR], [openssl installation directory])],
    [
        CPPFLAGS="$CPPFLAGS -I$withval/include"
        LDFLAGS="$LDFLAGS -L$withval/lib"
        have_openssl=yes
    ],
    [have_openssl=no])
AM_CONDITIONAL([HAVE_OPENSSL], [test "x$have_openssl" = "xyes"])

AC_ARG_WITH([shadowsocks],
    [AS_HELP_STRING([--with-shadowsocks=DIR], [shadowsocks installation directory])],
    [
        CPPFLAGS="$CPPFLAGS -I$withval/include"
        LDFLAGS="$LDFLAGS -L$withval/lib"
        have_shadowsocks=yes
    ],
    [have_shadowsocks=no])
AM_CONDITIONAL([HAVE_SHADOWSOCKS], [test "x$have_shadowsocks" = "xyes"])

# Checks for header files
AC_CHECK_HEADERS([stdlib.h string.h unistd.h])

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT
EOF
    
    # 创建顶层 Makefile.am
    cat > Makefile.am << 'EOF'
SUBDIRS = src
include_HEADERS = src/antinat.h
EOF
    
    # 创建 src/Makefile.am
    cat > src/Makefile.am << 'EOF'
lib_LIBRARIES = libantinat.a
libantinat_a_SOURCES = antinat.c antinat.h
libantinat_a_CFLAGS = -I$(top_srcdir)/src

if HAVE_MAXMINDDB
libantinat_a_CFLAGS += -I$(with_maxminddb)/include
endif

if HAVE_SODIUM
libantinat_a_CFLAGS += -I$(with_sodium)/include
endif

if HAVE_OPENSSL
libantinat_a_CFLAGS += -I$(with_openssl)/include
endif

if HAVE_SHADOWSOCKS
libantinat_a_CFLAGS += -I$(with_shadowsocks)/include
endif
EOF
    
    # 创建 src/antinat.h
    cat > src/antinat.h << 'EOF'
#ifndef ANTINAT_H
#define ANTINAT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <maxminddb.h>
#include <sodium.h>
#include <openssl/ssl.h>
#include <shadowsocks.h>

/* Version information */
#define ANTINAT_VERSION "0.93"

/* Basic functions */
int antinat_init(void);
void antinat_cleanup(void);
int antinat_start_proxy(const char *config_path);
void antinat_stop_proxy(void);

/* Error codes */
#define ANTINAT_SUCCESS 0
#define ANTINAT_ERROR_INIT -1
#define ANTINAT_ERROR_CONFIG -2
#define ANTINAT_ERROR_PROXY -3

#ifdef __cplusplus
}
#endif

#endif /* ANTINAT_H */
EOF
    
    # 创建 src/antinat.c
    cat > src/antinat.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "antinat.h"

static int initialized = 0;

int antinat_init(void) {
    if (initialized) {
        return ANTINAT_SUCCESS;
    }
    
    if (sodium_init() < 0) {
        return ANTINAT_ERROR_INIT;
    }
    
    SSL_library_init();
    
    initialized = 1;
    return ANTINAT_SUCCESS;
}

void antinat_cleanup(void) {
    if (!initialized) {
        return;
    }
    
    initialized = 0;
}

int antinat_start_proxy(const char *config_path) {
    if (!initialized) {
        return ANTINAT_ERROR_INIT;
    }
    
    if (!config_path) {
        return ANTINAT_ERROR_CONFIG;
    }
    
    // 实现代理启动逻辑
    return ANTINAT_SUCCESS;
}

void antinat_stop_proxy(void) {
    if (!initialized) {
        return;
    }
    
    // 实现代理停止逻辑
}
EOF
    
    # 在运行 autoreconf 之前，确保有 config.guess
    log_info "Installing config.guess and config.sub..."
    curl -o config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess'
    curl -o config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub'
    chmod +x config.guess config.sub
    
    # 运行 autotools 工具链
    log_info "Running autotools chain..."
    autoreconf -fiv
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CXX="$(xcrun -find -sdk iphoneos clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
    export cross_compiling=yes
    
    # 添加依赖库的头文件路径
    export CPPFLAGS="-I$DEPS_ROOT/libmaxminddb/install/include \
                     -I$DEPS_ROOT/libsodium/install/include \
                     -I$DEPS_ROOT/openssl/install/include \
                     -I$DEPS_ROOT/shadowsocks/install/include"
    
    ./configure --prefix="$INSTALL_DIR/ios" \
                --host=arm-apple-darwin \
                --build=$(./config.guess) \
                --enable-static \
                --disable-shared \
                --with-maxminddb="$DEPS_ROOT/libmaxminddb/install" \
                --with-sodium="$DEPS_ROOT/libsodium/install" \
                --with-openssl="$DEPS_ROOT/openssl/install" \
                --with-shadowsocks="$DEPS_ROOT/shadowsocks/install" \
                --disable-dependency-tracking \
                || (log_error "iOS configure failed" && return 1)
    
    make clean
    make -j$(sysctl -n hw.ncpu) || (log_error "iOS make failed" && return 1)
    make install || (log_error "iOS make install failed" && return 1)
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        log_info "Building for macOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk macosx clang)"
        export CXX="$(xcrun -find -sdk macosx clang++)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        export cross_compiling=yes
        
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        ./configure --prefix="$INSTALL_DIR/macos/$ARCH" \
                    --host="$HOST_ARCH" \
                    --build=$(./config.guess) \
                    --enable-static \
                    --disable-shared \
                    --with-maxminddb="$DEPS_ROOT/libmaxminddb/install" \
                    --with-sodium="$DEPS_ROOT/libsodium/install" \
                    --with-openssl="$DEPS_ROOT/openssl/install" \
                    --with-shadowsocks="$DEPS_ROOT/shadowsocks/install" \
                    --disable-dependency-tracking \
                    || (log_error "macOS $ARCH configure failed" && return 1)
        
        make clean
        make -j$(sysctl -n hw.ncpu) || (log_error "macOS $ARCH make failed" && return 1)
        make install || (log_error "macOS $ARCH make install failed" && return 1)
    done
    
    return 0
}

# 创建通用库
create_universal_library() {
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    mkdir -p "$INSTALL_DIR/lib"
    
    # iOS 库
    cp "$INSTALL_DIR/ios/lib/libantinat.a" "$INSTALL_DIR/lib/libantinat_ios.a"
    
    # macOS 通用库
    xcrun lipo -create \
        "$INSTALL_DIR/macos/arm64/lib/libantinat.a" \
        "$INSTALL_DIR/macos/x86_64/lib/libantinat.a" \
        -output "$INSTALL_DIR/lib/libantinat_macos.a"
    
    # 复制头文件
    cp -R "$INSTALL_DIR/ios/include" "$INSTALL_DIR/"
    
    # 验证库
    xcrun lipo -info "$INSTALL_DIR/lib/libantinat_ios.a"
    xcrun lipo -info "$INSTALL_DIR/lib/libantinat_macos.a"
}

# 主函数
main() {
    # 检查必要工具
    local REQUIRED_TOOLS="autoconf automake libtool pkg-config"
    local MISSING_TOOLS=()
    
    for tool in $REQUIRED_TOOLS; do
        if ! command -v $tool >/dev/null 2>&1; then
            MISSING_TOOLS+=($tool)
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        log_error "Required tools are missing: ${MISSING_TOOLS[*]}"
        log_info "Install with: brew install ${MISSING_TOOLS[*]}"
        exit 1
    fi
    
    # 检查依赖库
    if ! check_dependencies; then
        exit 1
    fi
    
    # 构建流程
    if build_antinat && create_universal_library; then
        cleanup "success"
        log_info "Build completed successfully!"
        log_info "Libraries available at: $DEPS_ROOT/$LIB_NAME/install/lib"
        log_info "Headers available at: $DEPS_ROOT/$LIB_NAME/install/include"
        return 0
    else
        log_error "Build failed"
        cleanup
        return 1
    fi
}

# 运行脚本
main 