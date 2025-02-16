#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit"
VERSION="3.5.1"
LIB_NAME="mbedtls"
SOURCE_DIR="${DEPS_ROOT}/${LIB_NAME}"

# 设置编译环境
export DEVELOPER_DIR="$(xcode-select -p)"
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOSX_DEPLOYMENT_TARGET="13.0"

# 设置SDK路径
export IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
export MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path)"

# 创建目录
mkdir -p "${SOURCE_DIR}"/{include,lib}

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# 准备源码
prepare_source() {
    cd "${SOURCE_DIR}"
    
    if [ ! -f "v${VERSION}.tar.gz" ]; then
        curl -LO "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v${VERSION}.tar.gz"
    fi
    
    rm -rf build
    mkdir -p build
    tar xzf "v${VERSION}.tar.gz" --strip-components=1 -C build

    # 创建配置文件
    cat > build/include/mbedtls/config.h << EOF
#ifndef MBEDTLS_CONFIG_H
#define MBEDTLS_CONFIG_H

#define MBEDTLS_PLATFORM_C
#define MBEDTLS_HAVE_ASM
#define MBEDTLS_AES_C
#define MBEDTLS_CIPHER_C
#define MBEDTLS_CIPHER_MODE_GCM
#define MBEDTLS_CIPHER_MODE_CFB
#define MBEDTLS_GCM_C
#define MBEDTLS_MD5_C

#include "check_config.h"

#endif /* MBEDTLS_CONFIG_H */
EOF
}

# 构建函数
build_for_platform() {
    local platform=$1
    local arch=$2
    local min_version=$3
    local sdk=$4
    
    echo "[INFO] Building for ${platform} (${arch})..."
    
    local build_dir="${SOURCE_DIR}/build/_${platform}"
    mkdir -p "${build_dir}"
    cd "${build_dir}"
    
    export CC="$(xcrun -find -sdk ${platform} clang)"
    export CFLAGS="-arch ${arch} -isysroot ${sdk} -m${platform}-version-min=${min_version}"
    [ "${platform}" = "iphoneos" ] && CFLAGS="${CFLAGS} -fembed-bitcode"
    export LDFLAGS="${CFLAGS}"
    
    cmake -S "${SOURCE_DIR}/build" -B . \
        -DCMAKE_INSTALL_PREFIX="${build_dir}/install" \
        -DCMAKE_SYSTEM_NAME="$([ "${platform}" = "iphoneos" ] && echo "iOS" || echo "Darwin")" \
        -DCMAKE_OSX_SYSROOT="${sdk}" \
        -DCMAKE_OSX_ARCHITECTURES="${arch}" \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
        -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
        -DINSTALL_MBEDTLS_HEADERS=ON || return 1
    
    cmake --build . -j$(sysctl -n hw.ncpu) || return 1
    cmake --install . || return 1
    
    # 复制库文件
    cp install/lib/libmbedcrypto.a "${SOURCE_DIR}/lib/libmbedcrypto_${platform}.a"
    
    # 首次构建时复制头文件
    if [ ! -d "${SOURCE_DIR}/include/mbedtls" ]; then
        cp -R install/include/mbedtls "${SOURCE_DIR}/include/"
    fi
}

# 主函数
main() {
    prepare_source
    
    # 构建 iOS 版本
    build_for_platform "iphoneos" "arm64" "${IPHONEOS_DEPLOYMENT_TARGET}" "${IOS_SDK}" || exit 1
    mv "${SOURCE_DIR}/lib/libmbedcrypto_iphoneos.a" "${SOURCE_DIR}/lib/libmbedcrypto_ios.a"
    
    # 构建 macOS 版本
    build_for_platform "macosx" "arm64" "${MACOSX_DEPLOYMENT_TARGET}" "${MACOS_SDK}" || exit 1
    mv "${SOURCE_DIR}/lib/libmbedcrypto_macosx.a" "${SOURCE_DIR}/lib/libmbedcrypto_macos.a"
    
    # 清理构建目录
    rm -rf "${SOURCE_DIR}/build"
    
    echo "[INFO] Build completed successfully"
}

# 执行主函数
main 