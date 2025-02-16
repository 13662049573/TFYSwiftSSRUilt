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
    local deps=(
        "$LIBEV_PATH"
        "$LIBMAXMINDDB_PATH"
        "$LIBSODIUM_PATH"
        "$MBEDTLS_PATH"
        "$OPENSSL_PATH"
        "$PCRE_PATH"
        "$CARES_PATH"
    )
    
    for dep in "${deps[@]}"; do
        if [ ! -d "$dep" ]; then
            error "依赖库目录不存在: $dep"
            return 1
        fi
        
        # 检查lib目录
        if [ ! -d "$dep/lib" ]; then
            error "依赖库文件目录不存在: $dep/lib"
            return 1
        fi
        
        # 检查include目录
        if [ ! -d "$dep/include" ]; then
            error "依赖库头文件目录不存在: $dep/include"
            return 1
        fi
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
    if [ "$platform" = "ios" ]; then
        install_dir="$INSTALL_DIR_IOS"
        export SDKROOT=$(xcrun --sdk $IOS_SDK --show-sdk-path)
        export DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
    else
        install_dir="$INSTALL_DIR_MACOS"
        export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
        export DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
    fi
    
    mkdir -p "$install_dir"
    
    local build_dir="$BUILD_DIR/$platform/$arch"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Set compiler flags
    export CC="$(xcrun -f clang)"
    export CXX="$(xcrun -f clang++)"
    export CFLAGS="-arch $arch -isysroot $SDKROOT -O2 -fPIC"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="$CFLAGS"
    
    if [ "$platform" = "ios" ]; then
        CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        CXXFLAGS="$CXXFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        LDFLAGS="$LDFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
    else
        CFLAGS="$CFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
        CXXFLAGS="$CXXFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
        LDFLAGS="$LDFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
    fi
    
    # Add dependencies to flags
    CFLAGS="$CFLAGS -I$LIBEV_PATH/include -I$LIBMAXMINDDB_PATH/include -I$LIBSODIUM_PATH/include -I$MBEDTLS_PATH/include -I$OPENSSL_PATH/include -I$PCRE_PATH/include -I$CARES_PATH/include"
    LDFLAGS="$LDFLAGS -L$LIBEV_PATH/lib -L$LIBMAXMINDDB_PATH/lib -L$LIBSODIUM_PATH/lib -L$MBEDTLS_PATH/lib -L$OPENSSL_PATH/lib -L$PCRE_PATH/lib -L$CARES_PATH/lib"
    
    # Configure and build
    cmake -S "$SOURCE_DIR/$LIB_NAME/${LIB_NAME}-${VERSION}" -B . \
          -DCMAKE_INSTALL_PREFIX="$install_dir" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_SYSTEM_NAME=$platform \
          -DCMAKE_OSX_SYSROOT="$SDKROOT" \
          -DCMAKE_OSX_ARCHITECTURES="$arch" \
          -DCMAKE_C_FLAGS="$CFLAGS" \
          -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
          -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
          -DWITH_STATIC=ON \
          -DWITH_EMBEDDED_SRC=ON \
          -DUSE_SYSTEM_SHARED_LIB=OFF \
          -DWITH_STATIC_LINK=ON \
          -DWITH_MBEDTLS=ON \
          -DWITH_OPENSSL=ON \
          -DWITH_SODIUM=ON \
          -DWITH_CARES=ON \
          -DWITH_PCRE=ON \
          -DWITH_MAXMINDDB=ON \
          -DWITH_LIBEV=ON \
          -DWITH_DOC=OFF \
          -DWITH_DOCUMENTATION=OFF \
          -DWITH_CONNTRACK=OFF \
          -DWITH_COVERAGE=OFF \
          -DWITH_PROFILE=OFF \
          -DWITH_DEBUGGING=OFF
    
    make -j$(sysctl -n hw.ncpu)
    make install
    
    # 重命名库文件
    cd "$install_dir/lib"
    for lib in *.a; do
        if [ -f "$lib" ]; then
            mv "$lib" "${lib%.a}_${platform}.a"
        fi
    done
    
    # 验证编译结果
    if [ ! -d "$install_dir/lib" ] || [ ! -d "$install_dir/include" ]; then
        error "编译失败：安装目录结构不完整"
        return 1
    fi
    
    info "Successfully built ${LIB_NAME} for $platform ($arch)"
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