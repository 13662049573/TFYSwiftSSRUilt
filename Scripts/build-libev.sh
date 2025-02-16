#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit"
VERSION="4.33"
LIB_NAME="libev"

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

# 错误处理
handle_error() {
    log_error "An error occurred in function: $1"
    log_error "Error on line $2"
    exit 1
}

trap 'handle_error "${FUNCNAME[0]}" $LINENO' ERR

# 检查 Xcode 环境
check_xcode_env() {
    log_info "Checking Xcode environment..."
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode Command Line Tools not installed"
        return 1
    fi
    if [ ! -d "${IOS_SDK}" ]; then
        log_error "iOS SDK not found at: ${IOS_SDK}"
        return 1
    fi
    if [ ! -d "${MACOS_SDK}" ]; then
        log_error "macOS SDK not found at: ${MACOS_SDK}"
        return 1
    fi
    log_info "Xcode environment check passed"
    return 0
}

# 检查必要的工具
check_dependencies() {
    log_info "Checking dependencies..."
    local missing_tools=()
    for tool in curl tar autoconf automake libtool pkg-config make cmake git; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    log_info "All required tools are available"
    return 0
}

# 下载源码
download_source() {
    local source_dir="${DEPS_ROOT}/libev"
    mkdir -p "${source_dir}"
    cd "${source_dir}"
    
    if [ ! -f "libev-${VERSION}.tar.gz" ]; then
        log_info "Downloading libev-${VERSION}.tar.gz..."
        curl -LO "http://dist.schmorp.de/libev/libev-${VERSION}.tar.gz"
    fi
    
    if [ ! -d "libev-${VERSION}" ]; then
        log_info "Extracting libev-${VERSION}.tar.gz..."
        tar xzf "libev-${VERSION}.tar.gz"
    fi
}

# 构建 libev
build_libev() {
    local arch=$1
    local sdk=$2
    local min_version=$3
    local platform=$4
    
    log_info "Building libev for ${platform} (${arch})..."
    
    # 设置构建目录
    local source_dir="${DEPS_ROOT}/libev/libev-${VERSION}"
    local build_dir="${DEPS_ROOT}/libev/build_${platform}_${arch}"
    local install_dir="${DEPS_ROOT}/libev/install_${platform}_${arch}"
    
    mkdir -p "${build_dir}"
    mkdir -p "${install_dir}"
    
    # 复制源码到构建目录
    cp -R "${source_dir}"/* "${build_dir}/"
    cd "${build_dir}"
    
    # 设置编译器和工具链
    if [ "${platform}" = "ios" ]; then
        export CC="$(xcrun -sdk iphoneos -find clang)"
        export CXX="$(xcrun -sdk iphoneos -find clang++)"
        export AR="$(xcrun -sdk iphoneos -find ar)"
        export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
        export STRIP="$(xcrun -sdk iphoneos -find strip)"
        export LIBTOOL="$(xcrun -sdk iphoneos -find libtool)"
        export NM="$(xcrun -sdk iphoneos -find nm)"
        host="arm-apple-darwin"
        platform_flags="-miphoneos-version-min=${min_version}"
    else
        export CC="$(xcrun -sdk macosx -find clang)"
        export CXX="$(xcrun -sdk macosx -find clang++)"
        export AR="$(xcrun -sdk macosx -find ar)"
        export RANLIB="$(xcrun -sdk macosx -find ranlib)"
        export STRIP="$(xcrun -sdk macosx -find strip)"
        export LIBTOOL="$(xcrun -sdk macosx -find libtool)"
        export NM="$(xcrun -sdk macosx -find nm)"
        host="arm-apple-darwin"
        platform_flags="-mmacosx-version-min=${min_version}"
    fi
    
    # 设置编译标志
    export CFLAGS="-arch ${arch} -isysroot ${sdk} ${platform_flags} -O3 -fPIC"
    export CXXFLAGS="${CFLAGS}"
    export LDFLAGS="${CFLAGS}"
    
    # 预设所有可能的配置值
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap=yes
    export ac_cv_func_munmap=yes
    export ac_cv_func_clock_gettime=no
    export ac_cv_func_epoll_ctl=no
    export ac_cv_func_inotify_init=no
    export ac_cv_func_kqueue=yes
    export ac_cv_func_poll=yes
    export ac_cv_func_select=yes
    export ac_cv_func_timerfd_create=no
    export ac_cv_func_eventfd=no
    export ac_cv_func_port_create=no
    export ac_cv_header_sys_epoll_h=no
    export ac_cv_header_sys_inotify_h=no
    export ac_cv_header_sys_timerfd_h=no
    export ac_cv_header_sys_eventfd_h=no
    export ac_cv_header_port_h=no
    export ac_cv_header_sys_event_h=yes
    export ac_cv_header_sys_queue_h=yes
    export ac_cv_type_long_long=yes
    export ac_cv_type_unsigned_long_long=yes
    export ac_cv_sizeof_long=8
    export ac_cv_sizeof_size_t=8
    export ac_cv_sizeof_void_p=8
    export ac_cv_alignof_void_p=8
    export ac_cv_c_bigendian=no
    export ac_cv_prog_cc_g=no
    export ac_cv_prog_cc_c99=yes
    export ac_cv_prog_cc_c11=yes
    export ac_cv_prog_cc_static_works=yes
    export ac_cv_prog_cc_pic_works=yes
    
    log_info "Configuring build..."
    
    # 运行配置脚本
    ./configure \
        --prefix="${install_dir}" \
        --host="${host}" \
        --build="$(./config.guess)" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-doc \
        --disable-maintainer-mode \
        CC="${CC}" \
        CXX="${CXX}" \
        CFLAGS="${CFLAGS}" \
        CXXFLAGS="${CXXFLAGS}" \
        LDFLAGS="${LDFLAGS}" || {
            log_error "Configure failed for ${platform} (${arch})"
            cat config.log
            return 1
        }
    
    log_info "Building..."
    
    make clean
    make -j$(sysctl -n hw.ncpu) || {
        log_error "Make failed for ${platform} (${arch})"
        return 1
    }
    
    log_info "Installing..."
    
    make install || {
        log_error "Make install failed for ${platform} (${arch})"
        return 1
    }
    
    # 验证编译结果
    if [ ! -f "${install_dir}/lib/libev.a" ]; then
        log_error "Failed to build libev static library for ${platform} (${arch})"
        return 1
    fi
    
    log_info "Successfully built libev for ${platform} (${arch})"
    return 0
}

# 主函数
main() {
    log_info "Starting libev build process..."
    
    check_xcode_env
    check_dependencies
    download_source
    
    # 构建 iOS 版本
    build_libev "arm64" "${IOS_SDK}" "${IPHONEOS_DEPLOYMENT_TARGET}" "ios"
    
    # 构建 macOS 版本
    build_libev "arm64" "${MACOS_SDK}" "${MACOS_DEPLOYMENT_TARGET}" "macos"
    
    log_info "All builds completed successfully"
    return 0
}

# 执行主函数
main 