#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit"
VERSION="8.45"
LIB_NAME="pcre"

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
    local source_dir="${DEPS_ROOT}/${LIB_NAME}/src"
    local download_url="https://sourceforge.net/projects/pcre/files/pcre/${VERSION}/pcre-${VERSION}.tar.gz"
    
    if [ ! -d "${source_dir}" ]; then
        mkdir -p "${source_dir}"
    fi
    
    cd "${source_dir}"
    
    if [ ! -f "pcre-${VERSION}.tar.gz" ]; then
        log_info "Downloading ${LIB_NAME} source..."
        curl -L -o "pcre-${VERSION}.tar.gz" "${download_url}"
    fi
    
    if [ ! -d "pcre-${VERSION}" ]; then
        log_info "Extracting ${LIB_NAME} source..."
        tar xzf "pcre-${VERSION}.tar.gz"
    fi
    
    cd "pcre-${VERSION}"
}

# 构建 PCRE
build_pcre() {
    local arch=$1
    local sdk=$2
    local min_version=$3
    local platform_suffix=$4
    
    log_info "Building ${LIB_NAME} for ${arch} on ${sdk}..."
    
    local source_dir="${DEPS_ROOT}/${LIB_NAME}/src/pcre-${VERSION}"
    local build_dir="${DEPS_ROOT}/${LIB_NAME}/build_${arch}"
    local install_dir="${DEPS_ROOT}/${LIB_NAME}/install_${arch}"
    
    # 清理并创建构建目录
    rm -rf "${build_dir}" "${install_dir}"
    mkdir -p "${build_dir}" "${install_dir}"
    
    cd "${build_dir}"
    
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
    export CFLAGS="-arch ${arch} -isysroot ${sdk} -O2 -fPIC ${platform_flags} -fembed-bitcode"
    export CXXFLAGS="${CFLAGS}"
    export LDFLAGS="-arch ${arch} -isysroot ${sdk} ${platform_flags}"
    
    # 创建配置文件
    cat > config.site << EOF
ac_cv_func_malloc_0_nonnull=yes
ac_cv_func_realloc_0_nonnull=yes
ac_cv_func_setrlimit=no
ac_cv_func_clock_gettime=no
ac_cv_func_mmap=no
ac_cv_file__dev_zero=no
ac_cv_file__dev_random=yes
ac_cv_func_getentropy=no
ac_cv_func_syscall=no
ac_cv_func_secure_getenv=no
ac_cv_func___secure_getenv=no
ac_cv_prog_cc_c99=no
ac_cv_c_bigendian=no
ac_cv_type_long_long=yes
ac_cv_type_unsigned_long_long=yes
EOF
    
    # 运行配置脚本
    CONFIG_SITE="./config.site" "${source_dir}/configure" \
        --prefix="${install_dir}" \
        --host="${host_alias}" \
        --enable-static \
        --disable-shared \
        --enable-utf8 \
        --enable-unicode-properties \
        --disable-cpp \
        --with-pic \
        --disable-dependency-tracking \
        --disable-stack-for-recursion \
        CC="${CC}" \
        CXX="${CXX}" \
        CFLAGS="${CFLAGS}" \
        CXXFLAGS="${CXXFLAGS}" \
        LDFLAGS="${LDFLAGS}" \
        || {
            log_error "Configure failed"
            return 1
        }
    
    # 清理并重新构建
    make clean
    make -j$(sysctl -n hw.ncpu) || {
        log_error "Make failed"
        return 1
    }
    
    make install || {
        log_error "Make install failed"
        return 1
    }
    
    # 验证生成的库文件
    if [ -f "${install_dir}/lib/libpcre.a" ]; then
        log_info "Verifying architecture of libpcre.a..."
        lipo -info "${install_dir}/lib/libpcre.a"
        file "${install_dir}/lib/libpcre.a"
    else
        log_error "libpcre.a not found at ${install_dir}/lib/libpcre.a"
        return 1
    fi
    
    log_info "Successfully built ${LIB_NAME} for ${arch}"
    return 0
}

# 创建通用二进制
create_universal_binary() {
    log_info "Creating universal binary..."
    
    local arm64_dir="${DEPS_ROOT}/${LIB_NAME}/install_arm64"
    local x86_64_dir="${DEPS_ROOT}/${LIB_NAME}/install_x86_64"
    local universal_dir="${DEPS_ROOT}/${LIB_NAME}/install"
    
    # 创建目标目录
    mkdir -p "${universal_dir}/lib"
    mkdir -p "${universal_dir}/include"
    mkdir -p "${universal_dir}/lib/pkgconfig"
    
    # 创建通用二进制
    if [ -f "${arm64_dir}/lib/libpcre.a" ] && [ -f "${x86_64_dir}/lib/libpcre.a" ]; then
        lipo -create \
            "${arm64_dir}/lib/libpcre.a" \
            "${x86_64_dir}/lib/libpcre.a" \
            -output "${universal_dir}/lib/libpcre.a"
        
        # 复制头文件和pkg-config文件
        cp -R "${arm64_dir}/include/"* "${universal_dir}/include/"
        cp -R "${arm64_dir}/lib/pkgconfig/"* "${universal_dir}/lib/pkgconfig/"
        
        # 验证通用二进制
        log_info "Verifying universal binary..."
        lipo -info "${universal_dir}/lib/libpcre.a"
        file "${universal_dir}/lib/libpcre.a"
    else
        log_error "Missing library files for universal binary creation"
        return 1
    fi
}

# 主函数
main() {
    # 检查环境
    check_xcode_env || exit 1
    check_dependencies || exit 1
    
    # 下载源码
    download_source || exit 1
    
    # 构建 iOS arm64 版本
    build_pcre "arm64" "${IOS_SDK}" "${IPHONEOS_DEPLOYMENT_TARGET}" "_ios" || exit 1
    
    # 构建 macOS x86_64 版本
    build_pcre "x86_64" "${MACOS_SDK}" "${MACOS_DEPLOYMENT_TARGET}" "_macos" || exit 1
    
    # 创建通用二进制
    create_universal_binary || exit 1
    
    log_info "All builds completed successfully"
    return 0
}

main 