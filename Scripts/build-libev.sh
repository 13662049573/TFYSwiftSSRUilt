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
MACOS_ARCHS="x86_64 arm64"

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
    local platform_suffix=$4
    
    log_info "Building libev for ${arch} on ${sdk}..."
    
    # 设置构建目录
    local source_dir="${DEPS_ROOT}/libev/libev-${VERSION}"
    local build_dir="${DEPS_ROOT}/libev/build_${arch}"
    local install_dir="${DEPS_ROOT}/libev/install"
    
    mkdir -p "${build_dir}"
    mkdir -p "${install_dir}"
    
    cd "${source_dir}"
    
    # 设置编译器和工具链
    if [[ "${sdk}" == *"iPhoneOS"* ]]; then
        export CC="$(xcrun -sdk iphoneos -find clang)"
        export CXX="$(xcrun -sdk iphoneos -find clang++)"
        export AR="$(xcrun -sdk iphoneos -find ar)"
        export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
        export STRIP="$(xcrun -sdk iphoneos -find strip)"
        export LIBTOOL="$(xcrun -sdk iphoneos -find libtool)"
        export NM="$(xcrun -sdk iphoneos -find nm)"
        host_alias="aarch64-apple-darwin"
        platform_flags="-miphoneos-version-min=${min_version}"
        
        # iOS 特定的交叉编译配置
        export ac_cv_func_malloc_0_nonnull=yes
        export ac_cv_func_realloc_0_nonnull=yes
        export ac_cv_func_setrlimit=no
        export ac_cv_func_clock_gettime=no
        export ac_cv_func_mmap=no
    else
        export CC="$(xcrun -sdk macosx -find clang)"
        export CXX="$(xcrun -sdk macosx -find clang++)"
        export AR="$(xcrun -sdk macosx -find ar)"
        export RANLIB="$(xcrun -sdk macosx -find ranlib)"
        export STRIP="$(xcrun -sdk macosx -find strip)"
        export LIBTOOL="$(xcrun -sdk macosx -find libtool)"
        export NM="$(xcrun -sdk macosx -find nm)"
        if [[ "${arch}" == "arm64" ]]; then
            host_alias="aarch64-apple-darwin"
        else
            host_alias="x86_64-apple-darwin"
        fi
        platform_flags="-mmacosx-version-min=${min_version}"
    fi
    
    # 基本编译标志
    local base_cflags="-arch ${arch} -isysroot ${sdk} -O2 -fPIC ${platform_flags}"
    local base_ldflags="-arch ${arch} -isysroot ${sdk} ${platform_flags}"
    
    # 设置最终的编译标志
    export CFLAGS="${base_cflags}"
    export CXXFLAGS="${CFLAGS}"
    export LDFLAGS="${base_ldflags}"
    
    # 运行配置脚本
    cd "${build_dir}"
    
    # 更新 config.guess 和 config.sub
    cp "/opt/homebrew/share/libtool/build-aux/config.guess" "${source_dir}/config.guess"
    cp "/opt/homebrew/share/libtool/build-aux/config.sub" "${source_dir}/config.sub"
    
    "${source_dir}/configure" \
        CC="${CC}" \
        CFLAGS="${CFLAGS}" \
        LDFLAGS="${LDFLAGS}" \
        --prefix="${install_dir}" \
        --disable-shared \
        --enable-static \
        --host="${host_alias}" \
        --build="$(${source_dir}/config.guess)"
    
    if [ $? -ne 0 ]; then
        log_error "Configure failed for libev"
        return 1
    fi
    
    make clean
    make -j$(sysctl -n hw.ncpu)
    
    if [ $? -ne 0 ]; then
        log_error "Build failed for libev"
        return 1
    fi
    
    make install
    
    if [ $? -ne 0 ]; then
        log_error "Install failed for libev"
        return 1
    fi
    
    log_info "Successfully built libev for ${arch}"
    return 0
}

# 主函数
main() {
    check_xcode_env
    check_dependencies
    download_source
    
    # 构建 iOS 版本
    build_libev "arm64" "${IOS_SDK}" "${IPHONEOS_DEPLOYMENT_TARGET}" "ios"
    
    log_info "All builds completed successfully"
    return 0
}

main 