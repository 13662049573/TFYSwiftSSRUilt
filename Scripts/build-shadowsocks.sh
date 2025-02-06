#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit"
VERSION="3.3.5"  # shadowsocks-libev 最新版本
LIB_NAME="shadowsocks"

# 设置编译环境
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# 架构
IOS_ARCHS="arm64"
MACOS_ARCHS="x86_64 arm64"

# 日志函数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

log_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

# 错误处理
handle_error() {
    log_error "An error occurred on line $1"
    cleanup
    exit 1
}

trap 'handle_error $LINENO' ERR

# 清理函数
cleanup() {
    if [ "$1" = "success" ]; then
        log_info "Cleaning up build files after successful build..."
        rm -rf "$DEPS_ROOT/$LIB_NAME/build"
    else
        log_info "Keeping build files for debugging..."
    fi
}

# 创建必要的目录
mkdir -p "$DEPS_ROOT/$LIB_NAME"
mkdir -p "$SCRIPT_DIR/backup"

# 构建 shadowsocks-libev
build_shadowsocks() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local DOWNLOAD_URL="https://github.com/shadowsocks/shadowsocks-libev/releases/download/v$VERSION/shadowsocks-libev-$VERSION.tar.gz"
    local ARCHIVE="$BUILD_DIR/shadowsocks-libev.tar.gz"
    
    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$BUILD_DIR"
    
    # 下载源码
    log_info "Downloading shadowsocks-libev..."
    if ! curl -L --retry 3 --retry-delay 2 -o "$ARCHIVE" "$DOWNLOAD_URL"; then
        log_error "Failed to download shadowsocks-libev"
        return 1
    fi
    
    # 解压源码
    log_info "Extracting shadowsocks-libev..."
    if ! tar xzf "$ARCHIVE"; then
        log_error "Failed to extract shadowsocks-libev"
        return 1
    fi
    
    cd "shadowsocks-libev-$VERSION"
    
    # 检查依赖库
    if [ ! -f "$DEPS_ROOT/libsodium/install/ios/lib/libsodium_ios.a" ]; then
        log_error "libsodium not found. Please build libsodium first."
        return 1
    fi
    if [ ! -f "$DEPS_ROOT/openssl/install/ios/lib/libssl_ios.a" ]; then
        log_error "OpenSSL not found. Please build OpenSSL first."
        return 1
    fi
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CXX="$(xcrun -find -sdk iphoneos clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -I$DEPS_ROOT/libsodium/install/ios/include -I$DEPS_ROOT/openssl/install/ios/include"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -L$DEPS_ROOT/libsodium/install/ios/lib -L$DEPS_ROOT/openssl/install/ios/lib"
    export LIBS="-lsodium -lssl -lcrypto"
    export PKG_CONFIG_PATH="$DEPS_ROOT/libsodium/install/ios/lib/pkgconfig:$DEPS_ROOT/openssl/install/ios/lib/pkgconfig"
    
    # 运行自动工具链
    ./autogen.sh
    
    ./configure --prefix="$INSTALL_DIR/ios" \
                --host=arm-apple-darwin \
                --enable-static \
                --disable-shared \
                --disable-documentation \
                --with-sodium="$DEPS_ROOT/libsodium/install/ios" \
                --with-openssl="$DEPS_ROOT/openssl/install/ios" \
                || (log_error "iOS configure failed" && return 1)
    
    make clean || true
    make -j$(sysctl -n hw.ncpu) || (log_error "iOS make failed" && return 1)
    make install || (log_error "iOS make install failed" && return 1)
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        log_info "Building for macOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk macosx clang)"
        export CXX="$(xcrun -find -sdk macosx clang++)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET -I$DEPS_ROOT/libsodium/install/macos/include -I$DEPS_ROOT/openssl/install/macos/include"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -L$DEPS_ROOT/libsodium/install/macos/lib -L$DEPS_ROOT/openssl/install/macos/lib"
        export LIBS="-lsodium -lssl -lcrypto"
        export PKG_CONFIG_PATH="$DEPS_ROOT/libsodium/install/macos/lib/pkgconfig:$DEPS_ROOT/openssl/install/macos/lib/pkgconfig"
        
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        ./configure --prefix="$INSTALL_DIR/macos/$ARCH" \
                    --host="$HOST_ARCH" \
                    --enable-static \
                    --disable-shared \
                    --disable-documentation \
                    --with-sodium="$DEPS_ROOT/libsodium/install/macos" \
                    --with-openssl="$DEPS_ROOT/openssl/install/macos" \
                    || (log_error "macOS $ARCH configure failed" && return 1)
        
        make clean || true
        make -j$(sysctl -n hw.ncpu) || (log_error "macOS $ARCH make failed" && return 1)
        make install || (log_error "macOS $ARCH make install failed" && return 1)
    done
    
    return 0
}

# 创建通用库
create_universal_library() {
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    mkdir -p "$INSTALL_DIR/lib"
    
    # iOS 库
    cp "$INSTALL_DIR/ios/lib/libshadowsocks-libev.a" "$INSTALL_DIR/lib/libshadowsocks_ios.a"
    
    # macOS 通用库
    xcrun lipo -create \
        "$INSTALL_DIR/macos/arm64/lib/libshadowsocks-libev.a" \
        "$INSTALL_DIR/macos/x86_64/lib/libshadowsocks-libev.a" \
        -output "$INSTALL_DIR/lib/libshadowsocks_macos.a"
    
    # 复制头文件
    cp -R "$INSTALL_DIR/ios/include" "$INSTALL_DIR/"
    
    # 验证库
    xcrun lipo -info "$INSTALL_DIR/lib/libshadowsocks_ios.a"
    xcrun lipo -info "$INSTALL_DIR/lib/libshadowsocks_macos.a"
    
    # 清理不需要的文件
    rm -rf "$INSTALL_DIR/ios"
    rm -rf "$INSTALL_DIR/macos"
    rm -rf "$INSTALL_DIR/share"
    rm -rf "$INSTALL_DIR/lib/pkgconfig"
}

# 主函数
main() {
    # 检查必要工具
    local REQUIRED_TOOLS="autoconf automake libtool pkg-config"
    local MISSING_TOOLS=()
    
    for tool in $REQUIRED_TOOLS; do
        if ! command -v $tool >/dev/null 2>&1; then
            MISSING_TOOLS+=($tool)
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        log_error "Required tools are missing: ${MISSING_TOOLS[*]}"
        log_info "Install with: brew install ${MISSING_TOOLS[*]}"
        exit 1
    fi
    
    # 构建流程
    if build_shadowsocks && create_universal_library; then
        cleanup "success"
        log_info "Build completed successfully!"
        log_info "Libraries available at: $DEPS_ROOT/$LIB_NAME/install/lib"
        log_info "Headers available at: $DEPS_ROOT/$LIB_NAME/install/include"
        return 0
    else
        log_error "Build failed"
        cleanup
        return 1
    fi
}

# 运行脚本
main