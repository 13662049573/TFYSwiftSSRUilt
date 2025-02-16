#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
SOURCE_DIR="${PROJECT_ROOT}/TFYSwiftSSRKit"
VERSION="3.3.5"
LIB_NAME="shadowsocks-libev"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 设置编译环境
export DEVELOPER_DIR="$(xcode-select -p)"
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# 设置SDK路径
export IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
export MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path)"

# 依赖库路径
LIBEV_PATH="${SOURCE_DIR}/libev"
LIBMAXMINDDB_PATH="${SOURCE_DIR}/libmaxminddb"
LIBSODIUM_PATH="${SOURCE_DIR}/libsodium"
MBEDTLS_PATH="${SOURCE_DIR}/mbedtls"
OPENSSL_PATH="${SOURCE_DIR}/openssl"
PCRE_PATH="${SOURCE_DIR}/pcre"
CARES_PATH="${SOURCE_DIR}/c-ares"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# 错误处理
handle_error() {
    log_error "构建过程中发生错误!"
    log_error "错误发生在: $1"
    log_error "错误行号: $2"
    exit 1
}

trap 'handle_error "${BASH_SOURCE[0]}" $LINENO' ERR

# 验证依赖库
verify_dependencies() {
    log_info "验证依赖库..."
    
    # 检查依赖库文件
    local libs=(
        "${LIBEV_PATH}/lib/libev_ios.a"
        "${LIBEV_PATH}/lib/libev_macos.a"
        "${LIBMAXMINDDB_PATH}/lib/libmaxminddb_ios.a"
        "${LIBMAXMINDDB_PATH}/lib/libmaxminddb_macos.a"
        "${LIBSODIUM_PATH}/lib/libsodium_ios.a"
        "${LIBSODIUM_PATH}/lib/libsodium_macos.a"
        "${MBEDTLS_PATH}/lib/libmbedcrypto_ios.a"
        "${MBEDTLS_PATH}/lib/libmbedcrypto_macos.a"
        "${MBEDTLS_PATH}/lib/libmbedtls_ios.a"
        "${MBEDTLS_PATH}/lib/libmbedtls_macos.a"
        "${MBEDTLS_PATH}/lib/libmbedx509_ios.a"
        "${MBEDTLS_PATH}/lib/libmbedx509_macos.a"
        "${OPENSSL_PATH}/lib/libssl_ios.a"
        "${OPENSSL_PATH}/lib/libssl_macos.a"
        "${OPENSSL_PATH}/lib/libcrypto_ios.a"
        "${OPENSSL_PATH}/lib/libcrypto_macos.a"
        "${PCRE_PATH}/lib/libpcre_ios.a"
        "${PCRE_PATH}/lib/libpcre_macos.a"
        "${CARES_PATH}/lib/libcares_ios.a"
        "${CARES_PATH}/lib/libcares_macos.a"
    )
    
    for lib in "${libs[@]}"; do
        if [ ! -f "$lib" ]; then
            log_error "依赖库文件不存在: $lib"
            return 1
        fi
        log_info "验证依赖库: $lib - 存在"
    done
    
    # 检查头文件目录
    local header_dirs=(
        "${LIBEV_PATH}/include"
        "${LIBMAXMINDDB_PATH}/include"
        "${LIBSODIUM_PATH}/include"
        "${MBEDTLS_PATH}/include"
        "${OPENSSL_PATH}/include"
        "${PCRE_PATH}/include"
        "${CARES_PATH}/include"
    )
    
    for dir in "${header_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "头文件目录不存在: $dir"
            return 1
        fi
        log_info "验证头文件目录: $dir - 存在"
    done
    
    log_success "所有依赖库验证通过"
    return 0
}

# 下载源码
download_source() {
    local source_dir="${SOURCE_DIR}/${LIB_NAME}"
    mkdir -p "${source_dir}"
    cd "${source_dir}"
    
    if [ ! -f "${LIB_NAME}-${VERSION}.tar.gz" ]; then
        log_info "下载 ${LIB_NAME}-${VERSION}.tar.gz..."
        curl -LO "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${VERSION}/${LIB_NAME}-${VERSION}.tar.gz"
    fi
    
    if [ ! -d "${LIB_NAME}-${VERSION}" ]; then
        log_info "解压 ${LIB_NAME}-${VERSION}.tar.gz..."
        tar xzf "${LIB_NAME}-${VERSION}.tar.gz"
    fi
    
    cd "${LIB_NAME}-${VERSION}"
    
    # 创建必要的目录
    mkdir -p build-aux m4
    
    # 下载 config.guess 和 config.sub
    curl -L -o "build-aux/config.guess" "https://git.savannah.gnu.org/cgit/config.git/plain/config.guess"
    curl -L -o "build-aux/config.sub" "https://git.savannah.gnu.org/cgit/config.git/plain/config.sub"
    chmod +x build-aux/config.guess build-aux/config.sub
}

# 构建函数
build_shadowsocks() {
    local platform=$1
    local arch=$2
    local min_version=$3
    local sdk=$4
    
    log_info "构建 ${LIB_NAME} for ${platform} (${arch})..."
    
    local install_dir="${SOURCE_DIR}/${LIB_NAME}/install_${platform}"
    local build_dir="${SOURCE_DIR}/${LIB_NAME}/build_${platform}"
    
    mkdir -p "${install_dir}"
    mkdir -p "${build_dir}"
    
    # 设置编译器和工具链
    if [ "${platform}" = "ios" ]; then
        export CC="$(xcrun -find -sdk iphoneos clang)"
        export CXX="$(xcrun -find -sdk iphoneos clang++)"
        export CFLAGS="-arch ${arch} -isysroot ${sdk} -mios-version-min=${min_version} -fembed-bitcode"
        export CXXFLAGS="${CFLAGS}"
        export LDFLAGS="${CFLAGS}"
        host="arm-apple-darwin"
    else
        export CC="$(xcrun -find -sdk macosx clang)"
        export CXX="$(xcrun -find -sdk macosx clang++)"
        export CFLAGS="-arch ${arch} -isysroot ${sdk} -mmacosx-version-min=${min_version}"
        export CXXFLAGS="${CFLAGS}"
        export LDFLAGS="${CFLAGS}"
        host="aarch64-apple-darwin"
    fi
    
    # 应用补丁
    log_info "应用补丁..."
    patch -p1 < "${SCRIPT_DIR}/patches/shadowsocks-libev-3.3.5.patch" || {
        log_error "应用补丁失败"
        return 1
    }
    
    # 预设配置检查结果
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap=yes
    export ac_cv_func_munmap=yes
    export ac_cv_func_select=yes
    export ac_cv_func_socket=yes
    export ac_cv_func_strndup=yes
    export ac_cv_func_fork=no
    export ac_cv_func_getpwnam=no
    export ac_cv_func_getpwuid=no
    export ac_cv_func_sigaction=yes
    export ac_cv_func_syslog=no
    
    # 预设头文件检查结果
    export ac_cv_header_limits_h=yes
    export ac_cv_header_netdb_h=yes
    export ac_cv_header_sys_ioctl_h=yes
    export ac_cv_header_sys_select_h=yes
    export ac_cv_header_sys_socket_h=yes
    export ac_cv_header_sys_types_h=yes
    export ac_cv_header_sys_wait_h=yes
    export ac_cv_header_unistd_h=yes
    export ac_cv_header_linux_tcp_h=no
    export ac_cv_header_linux_udp_h=no
    
    # 预设类型检查结果
    export ac_cv_type_size_t=yes
    export ac_cv_type_ssize_t=yes
    export ac_cv_type_pid_t=yes
    export ac_cv_type_uid_t=yes
    export ac_cv_type_gid_t=yes
    export ac_cv_type_int64_t=yes
    export ac_cv_type_uint16_t=yes
    export ac_cv_type_uint32_t=yes
    export ac_cv_type_uint64_t=yes
    export ac_cv_type_uint8_t=yes
    
    # 设置平台特定的库名后缀
    local platform_suffix="${platform}"
    
    # 添加依赖库
    export LIBS="-lev_${platform_suffix}"
    LIBS+=" -lmaxminddb_${platform_suffix}"
    LIBS+=" -lsodium_${platform_suffix}"
    LIBS+=" -lmbedcrypto_${platform_suffix}"
    LIBS+=" -lmbedtls_${platform_suffix}"
    LIBS+=" -lmbedx509_${platform_suffix}"
    LIBS+=" -lssl_${platform_suffix}"
    LIBS+=" -lcrypto_${platform_suffix}"
    LIBS+=" -lpcre_${platform_suffix}"
    LIBS+=" -lcares_${platform_suffix}"
    
    # 运行 autoreconf
    autoreconf -ivf
    
    # 配置构建
    ./configure \
        --prefix="${install_dir}" \
        --host="${host}" \
        --enable-static \
        --disable-shared \
        --disable-documentation \
        --disable-dependency-tracking \
        --disable-ssp \
        --disable-assert \
        --enable-silent-rules \
        --with-ev="${LIBEV_PATH}" \
        --with-mbedtls="${MBEDTLS_PATH}" \
        --with-sodium="${LIBSODIUM_PATH}" \
        --with-pcre="${PCRE_PATH}" \
        --with-cares="${CARES_PATH}" \
        CFLAGS="${CFLAGS}" \
        CXXFLAGS="${CXXFLAGS}" \
        LDFLAGS="${LDFLAGS}" \
        LIBS="${LIBS}" || {
            log_error "配置失败"
            cat config.log
            return 1
        }
    
    # 构建
    make clean
    make -j$(sysctl -n hw.ncpu) V=1 || {
        log_error "构建失败"
        return 1
    }
    
    # 安装
    make install || {
        log_error "安装失败"
        return 1
    }
    
    # 复制库文件到最终位置
    mkdir -p "${SOURCE_DIR}/${LIB_NAME}/lib"
    cp "${install_dir}/lib/libshadowsocks-libev.a" "${SOURCE_DIR}/${LIB_NAME}/lib/libshadowsocks-libev_${platform}.a"
    
    # 复制头文件
    mkdir -p "${SOURCE_DIR}/${LIB_NAME}/include"
    cp -R "${install_dir}/include/"* "${SOURCE_DIR}/${LIB_NAME}/include/"
    
    # 验证构建结果
    if [ ! -f "${SOURCE_DIR}/${LIB_NAME}/lib/libshadowsocks-libev_${platform}.a" ]; then
        log_error "构建失败: 未找到 libshadowsocks-libev_${platform}.a"
        return 1
    fi
    
    if [ ! -d "${SOURCE_DIR}/${LIB_NAME}/include" ]; then
        log_error "构建失败: 未找到头文件目录"
        return 1
    fi
    
    # 显示库文件信息
    log_info "库文件信息:"
    xcrun lipo -info "${SOURCE_DIR}/${LIB_NAME}/lib/libshadowsocks-libev_${platform}.a"
    
    log_success "构建 ${platform} 版本完成"
    return 0
}

# 主函数
main() {
    # 验证依赖
    verify_dependencies || exit 1
    
    # 下载源码
    download_source
    
    # 构建 iOS 版本
    build_shadowsocks "ios" "arm64" "${IPHONEOS_DEPLOYMENT_TARGET}" "${IOS_SDK}" || exit 1
    
    # 构建 macOS 版本
    build_shadowsocks "macos" "arm64" "${MACOS_DEPLOYMENT_TARGET}" "${MACOS_SDK}" || exit 1
    
    # 显示最终的库文件大小
    log_info "最终库文件大小:"
    ls -lh "${SOURCE_DIR}/${LIB_NAME}/lib/"*.a
    
    # 验证头文件
    log_info "验证头文件..."
    if [ ! -f "${SOURCE_DIR}/${LIB_NAME}/include/shadowsocks.h" ]; then
        log_error "缺少主要头文件: shadowsocks.h"
        exit 1
    fi
    
    # 清理构建目录
    log_info "清理构建目录..."
    rm -rf "${SOURCE_DIR}/${LIB_NAME}/build_ios"
    rm -rf "${SOURCE_DIR}/${LIB_NAME}/build_macos"
    rm -rf "${SOURCE_DIR}/${LIB_NAME}/install_ios"
    rm -rf "${SOURCE_DIR}/${LIB_NAME}/install_macos"
    
    log_success "构建完成! 库文件位置:"
    log_success "  iOS: ${SOURCE_DIR}/${LIB_NAME}/lib/libshadowsocks-libev_ios.a"
    log_success "  macOS: ${SOURCE_DIR}/${LIB_NAME}/lib/libshadowsocks-libev_macos.a"
    log_success "头文件位置: ${SOURCE_DIR}/${LIB_NAME}/include"
    
    return 0
}

# 执行主函数
main 