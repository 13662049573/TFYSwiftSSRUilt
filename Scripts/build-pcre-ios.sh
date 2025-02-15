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

# 设置SDK路径
export DEVELOPER_DIR="$(xcode-select -p)"
export IOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer"
export IOS_SDK="${IOS_SDK_PATH}/SDKs/iPhoneOS.sdk"

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# 检查 Xcode 环境
check_xcode_env() {
    log_info "Checking Xcode environment..."
    if [ ! -d "${IOS_SDK}" ]; then
        log_error "iOS SDK not found at: ${IOS_SDK}"
        return 1
    fi
    log_info "Xcode environment check passed"
    return 0
}

# 下载源码
download_source() {
    local source_dir="${DEPS_ROOT}/${LIB_NAME}/src"
    local download_url="https://sourceforge.net/projects/pcre/files/pcre/${VERSION}/pcre-${VERSION}.tar.gz"
    
    mkdir -p "${source_dir}"
    cd "${source_dir}"
    
    if [ ! -f "pcre-${VERSION}.tar.gz" ]; then
        log_info "Downloading ${LIB_NAME} source..."
        curl -L -o "pcre-${VERSION}.tar.gz" "${download_url}"
    fi
    
    if [ ! -d "pcre-${VERSION}" ]; then
        log_info "Extracting ${LIB_NAME} source..."
        tar xzf "pcre-${VERSION}.tar.gz"
    fi
}

# 构建 PCRE
build_pcre() {
    local source_dir="${DEPS_ROOT}/${LIB_NAME}/src/pcre-${VERSION}"
    local build_dir="${DEPS_ROOT}/${LIB_NAME}/build"
    local install_dir="${DEPS_ROOT}/${LIB_NAME}/install"
    
    # 清理旧的构建和安装目录
    rm -rf "${build_dir}" "${install_dir}"
    mkdir -p "${build_dir}" "${install_dir}"
    
    cd "${build_dir}"
    
    # 设置编译器和工具链
    export CC="$(xcrun -sdk iphoneos -find clang)"
    export CXX="$(xcrun -sdk iphoneos -find clang++)"
    export AR="$(xcrun -sdk iphoneos -find ar)"
    export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
    export STRIP="$(xcrun -sdk iphoneos -find strip)"
    export LIBTOOL="$(xcrun -sdk iphoneos -find libtool)"
    export NM="$(xcrun -sdk iphoneos -find nm)"
    
    # 基本编译标志
    export CFLAGS="-arch arm64 -isysroot ${IOS_SDK} -O2 -fPIC -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET} -fembed-bitcode"
    export CXXFLAGS="${CFLAGS}"
    export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET}"
    
    # 创建配置文件
    cat > config.site << EOF
ac_cv_func_malloc_0_nonnull=yes
ac_cv_func_realloc_0_nonnull=yes
ac_cv_func_mmap=no
EOF
    
    # 运行配置脚本
    CONFIG_SITE="./config.site" "${source_dir}/configure" \
        --prefix="${install_dir}" \
        --host="aarch64-apple-darwin" \
        --enable-static \
        --disable-shared \
        --enable-utf8 \
        --enable-unicode-properties \
        --disable-cpp \
        --with-pic \
        --disable-dependency-tracking \
        --disable-stack-for-recursion \
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
}

# 主函数
main() {
    check_xcode_env || exit 1
    download_source || exit 1
    build_pcre || exit 1
    log_info "PCRE build completed successfully"
}

main 