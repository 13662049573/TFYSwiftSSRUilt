#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit/openssl"
VERSION="3.1.4"
LIB_NAME="openssl"

# 设置编译环境
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# 架构
IOS_ARCHS="arm64"
MACOS_ARCHS="arm64"

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
        rm -rf "$DEPS_ROOT/build"
        rm -rf "$DEPS_ROOT/install/ios"
        rm -rf "$DEPS_ROOT/install/macos"
    else
        log_info "Keeping build files for debugging..."
    fi
}

# 创建必要的目录
mkdir -p "$DEPS_ROOT"

# 下载和构建
build_openssl() {
    local BUILD_DIR="$DEPS_ROOT/build"
    local INSTALL_DIR="$DEPS_ROOT/install"
    
    log_info "Building $LIB_NAME version $VERSION..."
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
    cd "$BUILD_DIR"
    
    # 下载源码
    if [ ! -f "${LIB_NAME}.tar.gz" ]; then
        log_info "Downloading $LIB_NAME..."
        local DOWNLOAD_URL="https://www.openssl.org/source/openssl-${VERSION}.tar.gz"
        if ! curl -L --retry 3 --retry-delay 2 -o "${LIB_NAME}.tar.gz" "$DOWNLOAD_URL"; then
            log_error "Failed to download $LIB_NAME"
            return 1
        fi
    fi
    
    # 解压源码
    if [ ! -d "${LIB_NAME}-${VERSION}" ]; then
        log_info "Extracting ${LIB_NAME}.tar.gz..."
        if ! tar xzf "${LIB_NAME}.tar.gz"; then
            log_error "Failed to extract ${LIB_NAME}.tar.gz"
            return 1
        fi
    fi
    
    cd "${LIB_NAME}-${VERSION}"
    
    # 通用配置选项
    local COMMON_CONFIG_OPTS="no-shared \
                            no-dso \
                            no-hw \
                            no-engine \
                            no-async \
                            no-comp \
                            no-idea \
                            no-mdc2 \
                            no-rc5 \
                            no-tests \
                            --prefix="
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    
    # 设置 iOS 编译环境
    export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
    export CROSS_SDK="iPhoneOS.sdk"
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CXX="$(xcrun -find -sdk iphoneos clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
    
    if ! ./Configure ios64-cross \
        $COMMON_CONFIG_OPTS"$INSTALL_DIR/ios"; then
        log_error "iOS configure failed"
        return 1
    fi
    
    if ! make clean; then
        log_error "iOS make clean failed"
        return 1
    fi
    
    if ! make -j$(sysctl -n hw.ncpu) build_libs; then
        log_error "iOS make failed"
        return 1
    fi
    
    if ! make install_dev; then
        log_error "iOS make install failed"
        return 1
    fi
    
    # macOS 构建
    log_info "Building for macOS..."
    for ARCH in $MACOS_ARCHS; do
        log_info "Building for macOS architecture: $ARCH"
        
        # 设置 macOS 编译环境
        unset CROSS_TOP CROSS_SDK
        export CC="$(xcrun -find -sdk macosx clang)"
        export CXX="$(xcrun -find -sdk macosx clang++)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        
        local OPENSSL_PLATFORM
        if [ "$ARCH" = "arm64" ]; then
            OPENSSL_PLATFORM="darwin64-arm64-cc"
        else
            OPENSSL_PLATFORM="darwin64-x86_64-cc"
        fi
        
        if ! ./Configure "$OPENSSL_PLATFORM" \
            $COMMON_CONFIG_OPTS"$INSTALL_DIR/macos/$ARCH"; then
            log_error "macOS $ARCH configure failed"
            return 1
        fi
        
        if ! make clean; then
            log_error "macOS $ARCH make clean failed"
            return 1
        fi
        
        if ! make -j$(sysctl -n hw.ncpu) build_libs; then
            log_error "macOS $ARCH make failed"
            return 1
        fi
        
        if ! make install_dev; then
            log_error "macOS $ARCH make install failed"
            return 1
        fi
    done
    
    return 0
}

# 创建通用库
create_universal_library() {
    local INSTALL_DIR="$DEPS_ROOT/install"
    mkdir -p "$INSTALL_DIR/lib"
    
    log_info "Creating universal libraries..."
    
    # 分别为 libcrypto 和 libssl 创建通用库
    for lib in "libcrypto" "libssl"; do
        # iOS 通用库
        log_info "Creating iOS universal library for $lib..."
        if ! cp "$INSTALL_DIR/ios/lib/${lib}.a" "$INSTALL_DIR/lib/${lib}_ios.a"; then
            log_error "Failed to create iOS universal library for $lib"
            return 1
        fi
        
        # macOS 通用库
        log_info "Creating macOS universal library for $lib..."
        if ! xcrun lipo -create \
            "$INSTALL_DIR/macos/arm64/lib/${lib}.a" \
            "$INSTALL_DIR/macos/x86_64/lib/${lib}.a" \
            -output "$INSTALL_DIR/lib/${lib}_macos.a"; then
            log_error "Failed to create macOS universal library for $lib"
            return 1
        fi
    done
    
    # 复制头文件
    log_info "Copying headers..."
    if ! cp -R "$INSTALL_DIR/ios/include" "$INSTALL_DIR/"; then
        log_error "Failed to copy headers"
        return 1
    fi
    
    # 验证生成的库
    log_info "Verifying libraries..."
    for lib in "libcrypto" "libssl"; do
        if [ ! -f "$INSTALL_DIR/lib/${lib}_ios.a" ] || [ ! -f "$INSTALL_DIR/lib/${lib}_macos.a" ]; then
            log_error "Library verification failed for $lib"
            return 1
        fi
        
        log_info "iOS $lib info:"
        xcrun lipo -info "$INSTALL_DIR/lib/${lib}_ios.a"
        
        log_info "macOS $lib info:"
        xcrun lipo -info "$INSTALL_DIR/lib/${lib}_macos.a"
    done
    
    return 0
}

# 主函数
main() {
    # 检查必要工具
    local REQUIRED_TOOLS="perl"
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
    
    # 清理旧的构建文件
    cleanup
    
    # 构建流程
    if build_openssl && create_universal_library; then
        cleanup
        log_info "Build completed successfully!"
        log_info "Libraries available at: $DEPS_ROOT/install/lib"
        log_info "Headers available at: $DEPS_ROOT/install/include"
        return 0
    else
        log_error "Build failed"
        cleanup
        return 1
    fi
}

# 运行脚本
main 