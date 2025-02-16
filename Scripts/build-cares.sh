#!/bin/bash

# 设置错误时退出
set -e

# 设置版本号
VERSION="1.19.1"

# 设置构建目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
CARES_SOURCE_DIR="$PROJECT_DIR/TFYSwiftSSRKit/c-ares"
BUILD_DIR="$CARES_SOURCE_DIR/build"
INSTALL_DIR_IOS="$CARES_SOURCE_DIR/install_arm64_ios"
INSTALL_DIR_MACOS="$CARES_SOURCE_DIR/install_arm64_macos"

# 创建必要的目录
mkdir -p "$CARES_SOURCE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR_IOS"
mkdir -p "$INSTALL_DIR_MACOS"

# 下载源码
cd "$CARES_SOURCE_DIR"
if [ ! -f "c-ares-${VERSION}.tar.gz" ]; then
    curl -LO "https://github.com/c-ares/c-ares/releases/download/cares-${VERSION//./_}/c-ares-${VERSION}.tar.gz"
fi

# 解压源码
rm -rf "c-ares-${VERSION}"
tar xzf "c-ares-${VERSION}.tar.gz"

# 构建 iOS 版本
mkdir -p "$BUILD_DIR/ios"
cd "$BUILD_DIR/ios"

# 设置 iOS 编译环境
export DEVELOPER=$(xcode-select -print-path)
export SDK_VERSION=$(xcrun -sdk iphoneos --show-sdk-version)
export IOS_SDK_PATH="${DEVELOPER}/Platforms/iPhoneOS.platform/Developer"
export IOS_SDK="${IOS_SDK_PATH}/SDKs/iPhoneOS${SDK_VERSION}.sdk"

cmake "$CARES_SOURCE_DIR/c-ares-${VERSION}" \
    -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/cmake/ios.toolchain.cmake" \
    -DPLATFORM=OS64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR_IOS" \
    -DCARES_SHARED=OFF \
    -DCARES_STATIC=ON \
    -DCARES_STATIC_PIC=ON

make -j$(sysctl -n hw.ncpu)
make install
mv "$INSTALL_DIR_IOS/lib/libcares.a" "$INSTALL_DIR_IOS/lib/libcares_ios.a"

# 构建 macOS 版本
mkdir -p "$BUILD_DIR/macos"
cd "$BUILD_DIR/macos"

cmake "$CARES_SOURCE_DIR/c-ares-${VERSION}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR_MACOS" \
    -DCARES_SHARED=OFF \
    -DCARES_STATIC=ON \
    -DCARES_STATIC_PIC=ON \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

make -j$(sysctl -n hw.ncpu)
make install
mv "$INSTALL_DIR_MACOS/lib/libcares.a" "$INSTALL_DIR_MACOS/lib/libcares_macos.a"

echo "c-ares build completed successfully" 