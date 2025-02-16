#!/bin/bash

# 设置错误时退出
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Version
VERSION="3.3.5"
LIB_NAME="shadowsocks-libev"

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$PROJECT_DIR/TFYSwiftSSRKit"
BUILD_DIR="$SOURCE_DIR/$LIB_NAME/build"
INSTALL_DIR_IOS="$SOURCE_DIR/$LIB_NAME/install_arm64_ios"
INSTALL_DIR_MACOS="$SOURCE_DIR/$LIB_NAME/install_arm64_macos"

# Target platforms
PLATFORMS="ios macos"
IOS_ARCHS="arm64"
MACOS_ARCHS="arm64"

# iOS SDK and deployment target
IOS_SDK="iphoneos"
IOS_DEPLOYMENT_TARGET="15.0"
MACOS_DEPLOYMENT_TARGET="12.0"

# Dependencies paths
LIBEV_PATH="$SOURCE_DIR/libev"
LIBMAXMINDDB_PATH="$SOURCE_DIR/libmaxminddb/install"
LIBSODIUM_PATH="$SOURCE_DIR/libsodium"
MBEDTLS_PATH="$SOURCE_DIR/mbedtls"
OPENSSL_PATH="$SOURCE_DIR/openssl/install"
PCRE_PATH="$SOURCE_DIR/pcre"
CARES_PATH="$SOURCE_DIR/c-ares"

# Function to print info messages
info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to print error messages
error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Function to print warning messages
warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to verify dependencies
verify_dependencies() {
    # 检查依赖库文件
    if [ ! -f "$LIBEV_PATH/lib/libev_ios.a" ] || [ ! -f "$LIBEV_PATH/lib/libev_macos.a" ]; then
        error "libev 库文件不存在"
        return 1
    fi
    
    if [ ! -f "$LIBMAXMINDDB_PATH/lib/libmaxminddb_ios.a" ] || [ ! -f "$LIBMAXMINDDB_PATH/lib/libmaxminddb_macos.a" ]; then
        error "libmaxminddb 库文件不存在"
        return 1
    fi
    
    if [ ! -f "$LIBSODIUM_PATH/lib/libsodium_ios.a" ] || [ ! -f "$LIBSODIUM_PATH/lib/libsodium_macos.a" ]; then
        error "libsodium 库文件不存在"
        return 1
    fi
    
    if [ ! -f "$MBEDTLS_PATH/lib/libmbedcrypto_ios.a" ] || [ ! -f "$MBEDTLS_PATH/lib/libmbedcrypto_macos.a" ]; then
        error "mbedtls 库文件不存在"
        return 1
    fi
    
    if [ ! -f "$OPENSSL_PATH/lib/libssl_ios.a" ] || [ ! -f "$OPENSSL_PATH/lib/libssl_macos.a" ]; then
        error "openssl 库文件不存在"
        return 1
    fi
    
    if [ ! -f "$PCRE_PATH/lib/libpcre_ios.a" ] || [ ! -f "$PCRE_PATH/lib/libpcre_macos.a" ]; then
        error "pcre 库文件不存在"
        return 1
    fi
    
    if [ ! -f "$CARES_PATH/lib/libcares_ios.a" ] || [ ! -f "$CARES_PATH/lib/libcares_macos.a" ]; then
        error "c-ares 库文件不存在"
        return 1
    fi
    
    # 检查头文件
    local header_dirs=(
        "$LIBEV_PATH/include"
        "$LIBMAXMINDDB_PATH/include"
        "$LIBSODIUM_PATH/include"
        "$MBEDTLS_PATH/include"
        "$OPENSSL_PATH/include"
        "$PCRE_PATH/include"
        "$CARES_PATH/include"
    )
    
    for dir in "${header_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            error "头文件目录不存在: $dir"
            return 1
        fi
    done
    
    return 0
}

# Function to download and extract source
download_source() {
    local source_dir="$SOURCE_DIR/$LIB_NAME"
    mkdir -p "$source_dir"
    cd "$source_dir"
    
    # Download source code if not exists
    if [ ! -f "${LIB_NAME}-${VERSION}.tar.gz" ]; then
        info "Downloading ${LIB_NAME}-${VERSION}.tar.gz..."
        curl -LO "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${VERSION}/${LIB_NAME}-${VERSION}.tar.gz"
    fi
    
    # Extract source code
    if [ ! -d "${LIB_NAME}-${VERSION}" ]; then
        info "Extracting ${LIB_NAME}-${VERSION}.tar.gz..."
        tar xzf "${LIB_NAME}-${VERSION}.tar.gz"
    fi
    
    cd "${LIB_NAME}-${VERSION}"
    
    # 创建必要的目录
    mkdir -p build-aux
    
    # 下载 config.guess 和 config.sub
    curl -L -o "build-aux/config.guess" "https://git.savannah.gnu.org/cgit/config.git/plain/config.guess"
    curl -L -o "build-aux/config.sub" "https://git.savannah.gnu.org/cgit/config.git/plain/config.sub"
    chmod +x build-aux/config.guess build-aux/config.sub
    
    # 备份原始的 configure.ac
    cp configure.ac configure.ac.bak
    
    # 创建新的 configure.ac
    cat > configure.ac << 'EOF'
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

dnl Add library dependencies
AC_CHECK_LIB([ev], [ev_time], [], [AC_MSG_ERROR([Couldn't find libev. Try installing libev-dev or libev-devel.])])
AC_CHECK_LIB([sodium], [sodium_init], [], [AC_MSG_ERROR([Couldn't find libsodium. Try installing libsodium-dev or libsodium-devel.])])

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
EOF
    
    # 运行 autoreconf
    autoreconf -ivf
}

# Function to build shadowsocks-libev
build_shadowsocks() {
    local platform=$1
    local arch=$2
    
    info "Building ${LIB_NAME} for $platform ($arch)..."
    
    # 验证依赖库
    if ! verify_dependencies; then
        error "依赖库验证失败"
        return 1
    fi
    
    local install_dir
    if [ "$platform" = "ios" ]; then
        install_dir="$INSTALL_DIR_IOS"
        export SDKROOT=$(xcrun --sdk $IOS_SDK --show-sdk-path)
        export DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
        host="arm-apple-darwin"
        export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
        export CROSS_SDK="iPhoneOS.sdk"
        export PLATFORM_DIR="$(xcrun --sdk iphoneos --show-sdk-platform-path)"
    else
        install_dir="$INSTALL_DIR_MACOS"
        export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
        export DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
        host="aarch64-apple-darwin"
        unset CROSS_TOP CROSS_SDK PLATFORM_DIR
    fi
    
    mkdir -p "$install_dir"
    
    local build_dir="$BUILD_DIR/$platform/$arch"
    mkdir -p "$build_dir"
    
    # Copy source to build directory
    cp -R "$SOURCE_DIR/$LIB_NAME/${LIB_NAME}-${VERSION}/"* "$build_dir/"
    cd "$build_dir"
    
    # Set compiler flags
    export CC="$(xcrun -f clang)"
    export CXX="$(xcrun -f clang++)"
    export AR="$(xcrun -f ar)"
    export RANLIB="$(xcrun -f ranlib)"
    export STRIP="$(xcrun -f strip)"
    export NM="$(xcrun -f nm)"
    export LD="$(xcrun -f ld)"
    
    # Set basic flags
    export CFLAGS="-arch $arch -isysroot $SDKROOT -O2 -fPIC"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="$CFLAGS"
    
    if [ "$platform" = "ios" ]; then
        CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        CXXFLAGS="$CXXFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        LDFLAGS="$LDFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
    else
        CFLAGS="$CFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
        CXXFLAGS="$CXXFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
        LDFLAGS="$LDFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
    fi
    
    # Add libev-related configuration
    export ac_cv_header_ev_h=yes
    export ac_cv_header_libev_ev_h=yes
    export ac_cv_search_ev_time="-lev_${platform}"
    export ac_cv_lib_ev_ev_time=yes
    
    # Add library linking flags
    export LIBS="-lev_${platform} -lmaxminddb_${platform} -lsodium_${platform} -lmbedcrypto_${platform} -lssl_${platform} -lpcre_${platform} -lcares_${platform}"
    
    # Add library header file paths
    CFLAGS="$CFLAGS -I$LIBEV_PATH/include -I$LIBMAXMINDDB_PATH/include -I$LIBSODIUM_PATH/include -I$MBEDTLS_PATH/include -I$OPENSSL_PATH/include -I$PCRE_PATH/include -I$CARES_PATH/include"
    LDFLAGS="$LDFLAGS -L$LIBEV_PATH/lib -L$LIBMAXMINDDB_PATH/lib -L$LIBSODIUM_PATH/lib -L$MBEDTLS_PATH/lib -L$OPENSSL_PATH/lib -L$PCRE_PATH/lib -L$CARES_PATH/lib"
    
    # Set cross-compilation cache variables
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap=yes
    export ac_cv_func_munmap=yes
    export ac_cv_func_select=yes
    export ac_cv_func_socket=yes
    export ac_cv_func_strndup=yes
    export ac_cv_func_fork=no
    export ac_cv_prog_cc_c99=yes
    export ac_cv_c_bigendian=no
    export ac_cv_func_getpwnam=no
    export ac_cv_func_getpwuid=no
    export ac_cv_func_sigaction=yes
    export ac_cv_func_syslog=no
    export ac_cv_header_sys_ioctl_h=yes
    export ac_cv_header_sys_select_h=yes
    export ac_cv_header_sys_socket_h=yes
    export ac_cv_header_sys_types_h=yes
    export ac_cv_header_sys_wait_h=yes
    export ac_cv_header_unistd_h=yes
    export cross_compiling=yes
    
    # Configure and build
    ./configure \
        --prefix="$install_dir" \
        --host="$host" \
        --build="$(./build-aux/config.guess)" \
        --enable-static \
        --disable-shared \
        --disable-documentation \
        --disable-ssp \
        --disable-assert \
        --disable-silent-rules \
        --with-mbedtls="$MBEDTLS_PATH" \
        --with-sodium="$LIBSODIUM_PATH" \
        --with-cares="$CARES_PATH" \
        --with-pcre="$PCRE_PATH" \
        --with-ev="$LIBEV_PATH" \
        CC="$CC" \
        CXX="$CXX" \
        AR="$AR" \
        RANLIB="$RANLIB" \
        STRIP="$STRIP" \
        NM="$NM" \
        LD="$LD" \
        CFLAGS="$CFLAGS" \
        CXXFLAGS="$CXXFLAGS" \
        LDFLAGS="$LDFLAGS" \
        LIBS="$LIBS" \
        || {
            error "Configure failed for $platform ($arch)"
            cat config.log
            return 1
        }
    
    make clean
    make -j$(sysctl -n hw.ncpu) V=1 || {
        error "Make failed for $platform ($arch)"
        return 1
    }
    
    make install || {
        error "Make install failed for $platform ($arch)"
        return 1
    }
    
    # 重命名库文件
    cd "$install_dir/lib"
    for lib in *.a; do
        if [ -f "$lib" ]; then
            mv "$lib" "${lib%.a}_${platform}.a"
        fi
    done
    
    # 验证编译结果
    if [ ! -d "$install_dir/lib" ] || [ ! -d "$install_dir/include" ]; then
        error "编译失败：安装目录结构不完整"
        return 1
    fi
    
    info "Successfully built ${LIB_NAME} for $platform ($arch)"
    return 0
}

# Clean build directories
clean() {
    info "Cleaning build directories..."
    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR_IOS"
    rm -rf "$INSTALL_DIR_MACOS"
}

# Main build process
main() {
    # Download and extract source code
    download_source
    
    # Create necessary directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR_IOS"
    mkdir -p "$INSTALL_DIR_MACOS"
    
    # Build for all platforms
    for platform in $PLATFORMS; do
        archs="$IOS_ARCHS"
        if [ "$platform" = "macos" ]; then
            archs="$MACOS_ARCHS"
        fi
        
        for arch in $archs; do
            if ! build_shadowsocks "$platform" "$arch"; then
                error "Build failed for $platform ($arch)"
                exit 1
            fi
        done
    done
    
    info "Build completed successfully!"
}

# Run main function
main 