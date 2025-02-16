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
LIBMAXMINDDB_PATH="$SOURCE_DIR/libmaxminddb"
LIBSODIUM_PATH="$SOURCE_DIR/libsodium"
MBEDTLS_PATH="$SOURCE_DIR/mbedtls"
OPENSSL_PATH="$SOURCE_DIR/openssl"
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
    local libs=(
        "$LIBEV_PATH/lib/libev_ios.a"
        "$LIBEV_PATH/lib/libev_macos.a"
        "$LIBMAXMINDDB_PATH/lib/libmaxminddb_ios.a"
        "$LIBMAXMINDDB_PATH/lib/libmaxminddb_macos.a"
        "$LIBSODIUM_PATH/lib/libsodium_ios.a"
        "$LIBSODIUM_PATH/lib/libsodium_macos.a"
        "$MBEDTLS_PATH/lib/libmbedcrypto_ios.a"
        "$MBEDTLS_PATH/lib/libmbedcrypto_macos.a"
        "$MBEDTLS_PATH/lib/libmbedtls_ios.a"
        "$MBEDTLS_PATH/lib/libmbedtls_macos.a"
        "$MBEDTLS_PATH/lib/libmbedx509_ios.a"
        "$MBEDTLS_PATH/lib/libmbedx509_macos.a"
        "$OPENSSL_PATH/lib/libssl_ios.a"
        "$OPENSSL_PATH/lib/libssl_macos.a"
        "$OPENSSL_PATH/lib/libcrypto_ios.a"
        "$OPENSSL_PATH/lib/libcrypto_macos.a"
        "$PCRE_PATH/lib/libpcre_ios.a"
        "$PCRE_PATH/lib/libpcre_macos.a"
        "$CARES_PATH/lib/libcares_ios.a"
        "$CARES_PATH/lib/libcares_macos.a"
    )
    
    for lib in "${libs[@]}"; do
        if [ ! -f "$lib" ]; then
            error "库文件不存在: $lib"
            return 1
        fi
        info "验证库文件: $lib - 存在"
    done
    
    # 检查头文件
    local header_dirs=(
        "$LIBEV_PATH/include"
        "$LIBMAXMINDDB_PATH/include"
        "$LIBSODIUM_PATH/include"
        "$MBEDTLS_PATH/include/mbedtls"
        "$MBEDTLS_PATH/include/psa"
        "$OPENSSL_PATH/include"
        "$PCRE_PATH/include"
        "$CARES_PATH/include"
    )
    
    for dir in "${header_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            error "头文件目录不存在: $dir"
            return 1
        fi
        info "验证头文件目录: $dir - 存在"
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
    local sdk_path
    if [ "$platform" = "ios" ]; then
        install_dir="$INSTALL_DIR_IOS"
        sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
        export SDKROOT="$sdk_path"
        export DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
        host="arm-apple-darwin"
        platform_suffix="ios"
    else
        install_dir="$INSTALL_DIR_MACOS"
        sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
        export SDKROOT="$sdk_path"
        export DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
        host="aarch64-apple-darwin"
        platform_suffix="macos"
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
    export CFLAGS="-arch ${arch} -isysroot ${sdk_path} -O2 -fPIC"
    export CPPFLAGS="${CFLAGS}"
    export LDFLAGS="${CFLAGS}"
    
    if [ "$platform" = "ios" ]; then
        CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        CXXFLAGS="$CXXFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        LDFLAGS="$LDFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
    else
        CFLAGS="$CFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
        CXXFLAGS="$CXXFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
        LDFLAGS="$LDFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
    fi
    
    # Add include paths
    CFLAGS="$CFLAGS -I$LIBEV_PATH/include"
    CFLAGS="$CFLAGS -I$LIBMAXMINDDB_PATH/include"
    CFLAGS="$CFLAGS -I$LIBSODIUM_PATH/include"
    CFLAGS="$CFLAGS -I$MBEDTLS_PATH/include"
    CFLAGS="$CFLAGS -I$OPENSSL_PATH/include"
    CFLAGS="$CFLAGS -I$PCRE_PATH/include"
    CFLAGS="$CFLAGS -I$CARES_PATH/include"
    
    # Add library paths
    LDFLAGS="$LDFLAGS -L$LIBEV_PATH/lib"
    LDFLAGS="$LDFLAGS -L$LIBMAXMINDDB_PATH/lib"
    LDFLAGS="$LDFLAGS -L$LIBSODIUM_PATH/lib"
    LDFLAGS="$LDFLAGS -L$MBEDTLS_PATH/lib"
    LDFLAGS="$LDFLAGS -L$OPENSSL_PATH/lib"
    LDFLAGS="$LDFLAGS -L$PCRE_PATH/lib"
    LDFLAGS="$LDFLAGS -L$CARES_PATH/lib"
    
    # Add library dependencies
    export LIBS="-lev_${platform_suffix} -lmaxminddb_${platform_suffix} -lsodium_${platform_suffix} \
                 -lmbedcrypto_${platform_suffix} -lmbedtls_${platform_suffix} -lmbedx509_${platform_suffix} \
                 -lssl_${platform_suffix} -lcrypto_${platform_suffix} -lpcre_${platform_suffix} -lcares_${platform_suffix}"
    
    # Configure cache variables
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
    
    # Configure with correct library paths and names
    ./configure \
        --prefix="$install_dir" \
        --host="$host" \
        --build="$(./build-aux/config.guess)" \
        --enable-static \
        --disable-shared \
        --disable-ssp \
        --disable-documentation \
        --with-ev="$LIBEV_PATH" \
        --with-sodium="$LIBSODIUM_PATH" \
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
        LIBS="$LIBS" || {
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
            mv "$lib" "${lib%.a}_${platform_suffix}.a"
        fi
    done
    
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