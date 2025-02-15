#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit"
VERSION="3.3.5"
LIB_NAME="shadowsocks-libev"
SOURCE_DIR="${DEPS_ROOT}/${LIB_NAME}"

# 创建必要的目录
create_directories() {
    local dirs=(
        "${SOURCE_DIR}"
        "${SOURCE_DIR}/build"
        "${SOURCE_DIR}/src"
        "${SOURCE_DIR}/install_arm64_ios/lib"
        "${SOURCE_DIR}/install_arm64_ios/include"
        "${SOURCE_DIR}/install_arm64_macos/lib"
        "${SOURCE_DIR}/install_arm64_macos/include"
        "${SOURCE_DIR}/install_macos/lib"
        "${SOURCE_DIR}/install_macos/include"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
    done
}

# 设置编译环境
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# 架构
IOS_ARCHS="arm64"
MACOS_ARCHS="arm64"

# 设置SDK路径
export DEVELOPER_DIR="$(xcode-select -p)"
export IOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer"
export IOS_SDK="${IOS_SDK_PATH}/SDKs/iPhoneOS.sdk"
export MACOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/MacOSX.platform/Developer"
export MACOS_SDK="${MACOS_SDK_PATH}/SDKs/MacOSX.sdk"

# 设置环境变量
export BUILD_DIR="${SOURCE_DIR}/build"
export MBEDTLS_PREFIX="${DEPS_ROOT}/mbedtls/install"
export PCRE_PREFIX="${DEPS_ROOT}/pcre/install"
export LIBSODIUM_PREFIX="${DEPS_ROOT}/libsodium/install"
export LIBMAXMINDDB_PREFIX="${DEPS_ROOT}/libmaxminddb/install"
export OPENSSL_PREFIX="${DEPS_ROOT}/openssl/install"
export LIBEV_PREFIX="${DEPS_ROOT}/libev/install"

# 添加pkg-config路径
export PKG_CONFIG_PATH="${PCRE_PREFIX}/lib/pkgconfig:${MBEDTLS_PREFIX}/lib/pkgconfig:${LIBSODIUM_PREFIX}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig"

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# 检查依赖库
check_dependencies() {
    log_info "Checking dependencies..."
    
    # 检查 libev
    if [ ! -f "${LIBEV_PREFIX}/lib/libev.a" ] && [ ! -f "${LIBEV_PREFIX}/lib/libev.la" ]; then
        log_error "Missing libev library"
        return 1
    fi
    
    # 检查 libmaxminddb
    if [ ! -f "${LIBMAXMINDDB_PREFIX}/lib/libmaxminddb_ios.a" ] && [ ! -f "${LIBMAXMINDDB_PREFIX}/lib/libmaxminddb_macos.a" ]; then
        log_error "Missing libmaxminddb library"
        return 1
    fi
    
    # 检查 libsodium
    if [ ! -f "${LIBSODIUM_PREFIX}/lib/libsodium_ios.a" ] && [ ! -f "${LIBSODIUM_PREFIX}/lib/libsodium_macos.a" ]; then
        log_error "Missing libsodium library"
        return 1
    fi
    
    # 检查 mbedtls
    local mbedtls_libs=(
        "libmbedcrypto.a"
        "libmbedtls.a"
        "libmbedx509.a"
    )
    for lib in "${mbedtls_libs[@]}"; do
        if [ ! -f "${MBEDTLS_PREFIX}/lib/${lib}" ]; then
            log_error "Missing mbedtls library: ${lib}"
            return 1
        fi
    done
    
    # 检查 openssl
    if [ ! -f "${OPENSSL_PREFIX}/lib/libcrypto_ios.a" ] && [ ! -f "${OPENSSL_PREFIX}/lib/libcrypto_macos.a" ]; then
        if [ ! -f "${OPENSSL_PREFIX}/lib/libssl_ios.a" ] && [ ! -f "${OPENSSL_PREFIX}/lib/libssl_macos.a" ]; then
            log_error "Missing openssl libraries"
            return 1
        fi
    fi
    
    # 检查 pcre
    if [ ! -f "${PCRE_PREFIX}/lib/libpcre.a" ] && [ ! -f "${PCRE_PREFIX}/lib/libpcre.la" ]; then
        log_error "Missing pcre library"
        return 1
    fi
    
    log_info "All dependencies found"
    return 0
}

# 下载和准备源码
prepare_source() {
    cd "${SOURCE_DIR}/src"
    
    if [ ! -f "${LIB_NAME}-${VERSION}.tar.gz" ]; then
        curl -LO "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${VERSION}/${LIB_NAME}-${VERSION}.tar.gz"
    fi
    
    if [ ! -d "${LIB_NAME}-${VERSION}" ]; then
        tar xzf "${LIB_NAME}-${VERSION}.tar.gz"
        cp -R "${LIB_NAME}-${VERSION}"/* "${BUILD_DIR}/"
    fi
}

# 构建函数
build_for_platform() {
    local arch=$1
    local sdk=$2
    local min_version=$3
    local platform=$4
    
    log_info "Building for ${arch} on ${platform}..."
    
    local install_dir="${SOURCE_DIR}/install_${arch}_${platform}"
    mkdir -p "${install_dir}"
    
    cd "${BUILD_DIR}"
    
    # 设置编译器和标志
    if [ "${platform}" = "ios" ]; then
        # iOS 平台特定设置
        export CC="$(xcrun -sdk iphoneos -find clang)"
        export CXX="$(xcrun -sdk iphoneos -find clang++)"
        export CFLAGS="-arch ${arch} -isysroot ${sdk} -miphoneos-version-min=${min_version}"
        
        # 修改构建目标和交叉编译配置
        export host_alias="arm-apple-darwin"
        export build_alias="arm-apple-darwin"
        export target_alias="arm-apple-darwin"
        
        # 添加系统头文件路径
        export CFLAGS="${CFLAGS} \
            -I${sdk}/usr/include \
            -I${sdk}/usr/local/include \
            -I${MBEDTLS_PREFIX}/include \
            -I${PCRE_PREFIX}/include \
            -I${LIBSODIUM_PREFIX}/include \
            -I${LIBMAXMINDDB_PREFIX}/include \
            -I${OPENSSL_PREFIX}/include \
            -I${LIBEV_PREFIX}/include"
        
        # 设置交叉编译所需的环境变量
        export ac_cv_func_malloc_0_nonnull=yes
        export ac_cv_func_realloc_0_nonnull=yes
        export ac_cv_func_setrlimit=yes
        export ac_cv_func_clock_gettime=yes
        export ac_cv_func_mmap=yes
        export ac_cv_func_getpwnam=yes
        export ac_cv_func_inet_ntop=yes
        export ac_cv_func_inet_pton=yes
        export ac_cv_func_setrlimit=yes
        export ac_cv_func_setsockopt=yes
        export ac_cv_func_socket=yes
        export ac_cv_header_sys_ioctl_h=yes
        export ac_cv_header_sys_socket_h=yes
        export ac_cv_header_sys_sockio_h=yes
        export ac_cv_header_net_if_h=yes
        export ac_cv_header_net_route_h=yes
        
        local lib_suffix="_ios"
    else
        # macOS 平台特定设置
        export CC="$(xcrun -sdk macosx -find clang)"
        export CXX="$(xcrun -sdk macosx -find clang++)"
        export CFLAGS="-arch ${arch} -isysroot ${sdk} -mmacosx-version-min=${min_version}"
        unset host_alias
        unset build_alias
        unset cross_compiling
        
        # 添加系统头文件路径
        export CFLAGS="${CFLAGS} \
            -I${sdk}/usr/include \
            -I${sdk}/usr/local/include"
        
        # 清除所有交叉编译相关的环境变量
        unset ac_cv_func_malloc_0_nonnull
        unset ac_cv_func_realloc_0_nonnull
        unset ac_cv_func_setrlimit
        unset ac_cv_func_clock_gettime
        unset ac_cv_func_mmap
        unset ac_cv_func_getpwnam
        unset ac_cv_func_inet_ntop
        unset ac_cv_func_inet_pton
        unset ac_cv_func_setrlimit
        unset ac_cv_func_setsockopt
        unset ac_cv_func_socket
        unset ac_cv_header_sys_ioctl_h
        unset ac_cv_header_sys_socket_h
        unset ac_cv_header_sys_sockio_h
        unset ac_cv_header_net_if_h
        unset ac_cv_header_net_route_h
        
        local lib_suffix="_macos"
    fi
    
    export CXXFLAGS="${CFLAGS}"
    export LDFLAGS="${CFLAGS}"
    
    # 设置库名称
    local LIBMAXMINDDB_LIB="libmaxminddb${lib_suffix}.a"
    local LIBSODIUM_LIB="libsodium${lib_suffix}.a"
    local OPENSSL_CRYPTO_LIB="libcrypto${lib_suffix}.a"
    local OPENSSL_SSL_LIB="libssl${lib_suffix}.a"
    
    log_info "Using CC: ${CC}"
    log_info "Using CXX: ${CXX}"
    log_info "Using CFLAGS: ${CFLAGS}"
    log_info "Using LDFLAGS: ${LDFLAGS}"
    
    # 配置构建
    if [ "${platform}" = "ios" ]; then
        ./configure \
            --prefix="${install_dir}" \
            --disable-documentation \
            --disable-shared \
            --enable-static \
            --with-mbedtls="${MBEDTLS_PREFIX}" \
            --with-pcre="${PCRE_PREFIX}" \
            --with-sodium="${LIBSODIUM_PREFIX}" \
            --with-ev="${LIBEV_PREFIX}" \
            --disable-ssp \
            --disable-assert \
            --host="${host_alias}" \
            --build="${build_alias}" \
            --target="${target_alias}" \
            --disable-dependency-tracking \
            LDFLAGS="${LDFLAGS}" \
            LIBS="${LIBEV_PREFIX}/lib/libev.a ${MBEDTLS_PREFIX}/lib/libmbedtls.a ${MBEDTLS_PREFIX}/lib/libmbedcrypto.a ${MBEDTLS_PREFIX}/lib/libmbedx509.a ${PCRE_PREFIX}/lib/libpcre.a ${LIBSODIUM_PREFIX}/lib/${LIBSODIUM_LIB} ${LIBMAXMINDDB_PREFIX}/lib/${LIBMAXMINDDB_LIB} ${OPENSSL_PREFIX}/lib/${OPENSSL_SSL_LIB} ${OPENSSL_PREFIX}/lib/${OPENSSL_CRYPTO_LIB}" || {
                log_error "Configure failed for ${platform}"
                cat config.log
                return 1
            }
    else
        ./configure \
            --prefix="${install_dir}" \
            --disable-documentation \
            --disable-shared \
            --enable-static \
            --with-mbedtls="${MBEDTLS_PREFIX}" \
            --with-pcre="${PCRE_PREFIX}" \
            --with-sodium="${LIBSODIUM_PREFIX}" \
            --with-ev="${LIBEV_PREFIX}" \
            --disable-ssp \
            --disable-assert \
            --host="${host_alias}" \
            --build="${build_alias}" \
            --target="${target_alias}" \
            --disable-dependency-tracking \
            LDFLAGS="${LDFLAGS}" \
            LIBS="${LIBEV_PREFIX}/lib/libev.a ${MBEDTLS_PREFIX}/lib/libmbedtls.a ${MBEDTLS_PREFIX}/lib/libmbedcrypto.a ${MBEDTLS_PREFIX}/lib/libmbedx509.a ${PCRE_PREFIX}/lib/libpcre.a ${LIBSODIUM_PREFIX}/lib/${LIBSODIUM_LIB} ${LIBMAXMINDDB_PREFIX}/lib/${LIBMAXMINDDB_LIB} ${OPENSSL_PREFIX}/lib/${OPENSSL_SSL_LIB} ${OPENSSL_PREFIX}/lib/${OPENSSL_CRYPTO_LIB}" || {
                log_error "Configure failed for ${platform}"
                cat config.log
                return 1
            }
    fi
    
    make clean
    make V=1 -j$(sysctl -n hw.ncpu) || {
        log_error "Make failed for ${platform}"
        return 1
    }
    
    make install || {
        log_error "Make install failed for ${platform}"
        return 1
    }
    
    # 重命名生成的库文件
    if [ -f "${install_dir}/lib/libshadowsocks-libev.a" ]; then
        mv "${install_dir}/lib/libshadowsocks-libev.a" "${install_dir}/lib/libshadowsocks-libev${lib_suffix}.a"
    fi
}

# 主函数
main() {
    create_directories
    
    # 检查依赖
    check_dependencies || exit 1
    
    # 准备源码
    prepare_source
    
    # 构建 iOS 版本
    build_for_platform "arm64" "${IOS_SDK}" "${IPHONEOS_DEPLOYMENT_TARGET}" "ios"
    
    # 构建 macOS 版本
    build_for_platform "arm64" "${MACOS_SDK}" "${MACOS_DEPLOYMENT_TARGET}" "macos"
    
    # 创建符号链接以保持兼容性
    cd "${SOURCE_DIR}/install_macos/lib"
    ln -sf libshadowsocks-libev_macos.a libshadowsocks-libev.a
    
    log_info "Build completed successfully"
}

# 执行主函数
main 