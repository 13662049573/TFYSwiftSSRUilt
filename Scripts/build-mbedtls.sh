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
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
    done
}

# 设置编译环境
export DEVELOPER_DIR="$(xcode-select -p)"
export IPHONEOS_SDK_VERSION=$(xcrun -sdk iphoneos --show-sdk-version)
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOSX_DEPLOYMENT_TARGET="13.0"

# 设置SDK路径
export IOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer"
export IOS_SDK="${IOS_SDK_PATH}/SDKs/iPhoneOS.sdk"
export MACOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/MacOSX.platform/Developer"
export MACOS_SDK="${MACOS_SDK_PATH}/SDKs/MacOSX.sdk"

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
    
    # 清理并重新解压源码
    rm -rf build/*
    tar xzf "v${VERSION}.tar.gz" --strip-components=1 -C .

    # 创建自定义配置文件
    cat > include/mbedtls/config.h << EOF
#ifndef MBEDTLS_CONFIG_H
#define MBEDTLS_CONFIG_H

#define MBEDTLS_PLATFORM_C
#define MBEDTLS_HAVE_ASM
#define MBEDTLS_AES_C
#define MBEDTLS_CIPHER_C
#define MBEDTLS_CIPHER_MODE_GCM
#define MBEDTLS_GCM_C

#include "check_config.h"

#endif /* MBEDTLS_CONFIG_H */
EOF

    # 复制配置文件到 mbedtls_config.h
    cp include/mbedtls/config.h include/mbedtls/mbedtls_config.h
}

# 构建函数
build_for_platform() {
    local platform=$1
    local arch=$2
    local min_version=$3
    
    log_info "Building for ${platform} (${arch})..."
    
    # 清理之前的构建
    rm -rf build_${platform}
    mkdir -p build_${platform}
    cd build_${platform}
    
    # 设置编译器和标志
    if [ "${platform}" = "ios" ]; then
        export CC="${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
        export CFLAGS="-arch ${arch} -isysroot ${IOS_SDK} -miphoneos-version-min=${min_version} -fembed-bitcode"
        export LDFLAGS="-arch ${arch} -isysroot ${IOS_SDK}"
        local install_dir="${SOURCE_DIR}/install_${arch}_ios"
        local sysroot="${IOS_SDK}"
        local system_name="iOS"
    else
        export CC="${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
        export CFLAGS="-arch ${arch} -isysroot ${MACOS_SDK} -mmacosx-version-min=${min_version}"
        export LDFLAGS="-arch ${arch} -isysroot ${MACOS_SDK}"
        local install_dir="${SOURCE_DIR}/install_${arch}_macos"
        local sysroot="${MACOS_SDK}"
        local system_name="Darwin"
    fi
    
    # 配置构建
    cmake -S "${SOURCE_DIR}" -B . \
        -DCMAKE_INSTALL_PREFIX="${install_dir}" \
        -DCMAKE_SYSTEM_NAME=${system_name} \
        -DCMAKE_OSX_SYSROOT="${sysroot}" \
        -DCMAKE_OSX_ARCHITECTURES=${arch} \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${min_version}" \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
        -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
        -DINSTALL_MBEDTLS_HEADERS=ON \
        -DMBEDTLS_CONFIG_FILE="${SOURCE_DIR}/include/mbedtls/config.h" || {
            log_error "Configure failed for ${platform}"
            return 1
        }
    
    # 编译
    cmake --build . -j$(sysctl -n hw.ncpu) || {
        log_error "Build failed for ${platform}"
        return 1
    }
    
    # 安装
    cmake --install . || {
        log_error "Install failed for ${platform}"
        return 1
    }
    
    # 重命名库文件
    if [ -f "${install_dir}/lib/libmbedcrypto.a" ]; then
        mv "${install_dir}/lib/libmbedcrypto.a" "${install_dir}/lib/libmbedcrypto_${platform}.a"
    fi
    if [ -f "${install_dir}/lib/libmbedtls.a" ]; then
        mv "${install_dir}/lib/libmbedtls.a" "${install_dir}/lib/libmbedtls_${platform}.a"
    fi
    if [ -f "${install_dir}/lib/libmbedx509.a" ]; then
        mv "${install_dir}/lib/libmbedx509.a" "${install_dir}/lib/libmbedx509_${platform}.a"
    fi
}

# 主函数
main() {
    create_directories
    prepare_source
    
    # 构建 iOS 版本
    build_for_platform "ios" "arm64" "${IPHONEOS_DEPLOYMENT_TARGET}"
    
    # 构建 macOS 版本
    build_for_platform "macos" "arm64" "${MACOSX_DEPLOYMENT_TARGET}"
    
    log_info "Build completed successfully"
}

# 执行主函数
main 