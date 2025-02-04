#!/bin/bash

# 设置错误时退出
set -e

# 显示帮助信息
show_help() {
    cat << EOF
Usage: $0 [options]

Options:
  --clean-all    Clean all builds and start fresh
  --verbose      Show detailed build output
  --help         Show this help message

Example:
  $0 --clean-all        # Clean everything and rebuild
  $0 --verbose          # Show detailed build output
EOF
}

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit"
BUILD_STATUS_FILE="$DEPS_ROOT/.build_status"

# 创建必要的目录
mkdir -p "$DEPS_ROOT"

# 设置编译环境
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# iOS 架构
IOS_ARCHS="arm64"
# macOS 架构
MACOS_ARCHS="x86_64 arm64"

# 日志相关函数
LOG_FILE="$DEPS_ROOT/build.log"

setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "Build started at $(date)" > "$LOG_FILE"
    # 同时输出到终端和日志文件
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S'): $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S'): $1" >&2
}

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# 检查库是否已经成功构建
check_library_status() {
    local LIB_NAME=$1
    if [ -f "$BUILD_STATUS_FILE" ]; then
        if grep -q "^${LIB_NAME}=success$" "$BUILD_STATUS_FILE"; then
            return 0  # 库已经成功构建
        fi
    fi
    return 1  # 库需要构建
}

# 标记库构建状态
mark_library_status() {
    local LIB_NAME=$1
    local STATUS=$2
    touch "$BUILD_STATUS_FILE"
    sed -i '' "/^${LIB_NAME}=/d" "$BUILD_STATUS_FILE"
    echo "${LIB_NAME}=${STATUS}" >> "$BUILD_STATUS_FILE"
}

# 编译指定库
build_library() {
    local LIB_NAME=$1
    local VERSION=$2
    local DOWNLOAD_URL=$3
    local NEED_AUTORECONF=${4:-false}
    
    # 检查是否已经成功构建
    if check_library_status "$LIB_NAME"; then
        echo "$LIB_NAME already built successfully, skipping..."
        return 0
    fi
    
    log_info "Building $LIB_NAME..."
    
    # 为每个库创建独立的构建和安装目录
    local LIB_BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local LIB_INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    # 检查是否已有安装文件
    if [ -d "$LIB_INSTALL_DIR" ] && [ -f "$LIB_INSTALL_DIR/build_complete" ]; then
        echo "$LIB_NAME already installed, skipping..."
        mark_library_status "$LIB_NAME" "success"
        return 0
    fi
    
    mkdir -p "$LIB_BUILD_DIR" "$LIB_INSTALL_DIR"
    cd "$LIB_BUILD_DIR"
    
    # 检查是否已有源码
    local SOURCE_DIR="$LIB_NAME-$VERSION"
    if [ ! -d "$SOURCE_DIR" ] || [ ! -f "${LIB_NAME}.tar.gz" ]; then
        # 下载源码
        echo "Downloading $LIB_NAME..."
        local MAX_RETRIES=3
        local RETRY_COUNT=0
        local DOWNLOAD_SUCCESS=false
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
            if curl -L --retry 3 --retry-delay 2 --http1.1 -o "${LIB_NAME}.tar.gz" "$DOWNLOAD_URL"; then
                DOWNLOAD_SUCCESS=true
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                echo "Download failed, attempt $RETRY_COUNT of $MAX_RETRIES"
                sleep 2
            fi
        done
        
        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            mark_library_status "$LIB_NAME" "failed"
            log_error "Failed to download $LIB_NAME after $MAX_RETRIES attempts"
            exit 1
        fi
        
        # 解压源码
        echo "Extracting $LIB_NAME..."
        if ! tar xzf "${LIB_NAME}.tar.gz"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to extract ${LIB_NAME}.tar.gz"
            exit 1
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    # 如果需要，运行 autoreconf
    if [ "$NEED_AUTORECONF" = true ]; then
        echo "Running autoreconf..."
        autoreconf -fi || { echo "autoreconf failed"; exit 1; }
    fi
    
    # 修复configure脚本
    if [ -f "configure" ]; then
        sed -i '' 's/cross_compiling=maybe/cross_compiling=yes/g' configure
    fi
    
    # iOS 编译
    echo "Building for iOS (arm64)..."
    for ARCH in $IOS_ARCHS; do
        echo "Building for architecture: $ARCH"
        
        # 设置编译环境
        export CC="$(xcrun -find -sdk iphoneos clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
        
        # 显示编译环境信息
        echo "Building with:"
        echo "CC: $CC"
        echo "CFLAGS: $CFLAGS"
        echo "LDFLAGS: $LDFLAGS"
        
        # 运行配置和编译
        ./configure \
            --prefix="$LIB_INSTALL_DIR/ios/$ARCH" \
            --host=arm-apple-darwin \
            --build="$(./config.guess)" \
            --enable-static \
            --disable-shared \
            --disable-tests \
            --disable-dependency-tracking \
            || { echo "Configure failed for iOS $ARCH"; exit 1; }
        
        make clean
        make -j$(sysctl -n hw.ncpu) || { echo "Make failed for iOS $ARCH"; exit 1; }
        make install || { echo "Make install failed for iOS $ARCH"; exit 1; }
        
        echo "Successfully built $LIB_NAME for iOS $ARCH"
    done
    
    # macOS 编译
    echo "Building for macOS..."
    for ARCH in $MACOS_ARCHS; do
        echo "Building for architecture: $ARCH"
        
        # 设置编译环境
        export CC="$(xcrun -find -sdk macosx clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        
        # 为不同架构设置正确的主机类型
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        # 显示编译环境信息
        echo "Building with:"
        echo "CC: $CC"
        echo "CFLAGS: $CFLAGS"
        echo "LDFLAGS: $LDFLAGS"
        echo "HOST_ARCH: $HOST_ARCH"
        
        # 运行配置和编译
        ./configure \
            --prefix="$LIB_INSTALL_DIR/macos/$ARCH" \
            --host="$HOST_ARCH" \
            --build="$(./config.guess)" \
            --enable-static \
            --disable-shared \
            --disable-tests \
            --disable-dependency-tracking \
            || { echo "Configure failed for macOS $ARCH"; exit 1; }
        
        make clean
        make -j$(sysctl -n hw.ncpu) || { echo "Make failed for macOS $ARCH"; exit 1; }
        make install || { echo "Make install failed for macOS $ARCH"; exit 1; }
        
        echo "Successfully built $LIB_NAME for macOS $ARCH"
    done
    
    # 创建通用库
    create_universal_library "$LIB_INSTALL_DIR" "$LIB_NAME"
    
    # 复制头文件
    copy_headers "$LIB_INSTALL_DIR" "$LIB_NAME"
    
    # 标记构建完成
    touch "$LIB_INSTALL_DIR/build_complete"
    mark_library_status "$LIB_NAME" "success"
    
    echo "$LIB_NAME build completed"
}

# 创建通用库
create_universal_library() {
    local LIB_INSTALL_DIR=$1
    local LIB_NAME=$2
    local RESULT=0
    
    echo "Creating universal library for $LIB_NAME..."
    
    # 创建目标目录
    mkdir -p "$LIB_INSTALL_DIR/lib"
    
    # iOS 库文件
    local IOS_LIBS=""
    for arch in $IOS_ARCHS; do
        local LIB_PATH="$LIB_INSTALL_DIR/ios/$arch/lib/lib${LIB_NAME}.a"
        if [ ! -f "$LIB_PATH" ]; then
            echo "Warning: iOS library not found at $LIB_PATH"
            RESULT=1
            continue
        fi
        IOS_LIBS="$IOS_LIBS $LIB_PATH"
    done
    
    # macOS 库文件
    local MACOS_LIBS=""
    for arch in $MACOS_ARCHS; do
        local LIB_PATH="$LIB_INSTALL_DIR/macos/$arch/lib/lib${LIB_NAME}.a"
        if [ ! -f "$LIB_PATH" ]; then
            echo "Warning: macOS library not found at $LIB_PATH"
            RESULT=1
            continue
        fi
        MACOS_LIBS="$MACOS_LIBS $LIB_PATH"
    done
    
    # 创建 iOS 通用库
    if [ ! -z "$IOS_LIBS" ] && [ $(echo $IOS_LIBS | wc -w) -gt 0 ]; then
        if ! xcrun lipo -create $IOS_LIBS -output "$LIB_INSTALL_DIR/lib/${LIB_NAME}_ios.a"; then
            echo "Error: Failed to create iOS universal library for $LIB_NAME"
            RESULT=1
        fi
    fi
    
    # 创建 macOS 通用库
    if [ ! -z "$MACOS_LIBS" ] && [ $(echo $MACOS_LIBS | wc -w) -gt 0 ]; then
        if ! xcrun lipo -create $MACOS_LIBS -output "$LIB_INSTALL_DIR/lib/${LIB_NAME}_macos.a"; then
            echo "Error: Failed to create macOS universal library for $LIB_NAME"
            RESULT=1
        fi
    fi
    
    return $RESULT
}

# 复制头文件
copy_headers() {
    local LIB_INSTALL_DIR=$1
    local LIB_NAME=$2
    local RESULT=0
    
    echo "Copying headers for $LIB_NAME..."
    
    # 创建目标目录
    mkdir -p "$LIB_INSTALL_DIR/include"
    
    # 复制 iOS 头文件
    if [ -d "$LIB_INSTALL_DIR/ios/arm64/include" ]; then
        if ! cp -R "$LIB_INSTALL_DIR/ios/arm64/include/" "$LIB_INSTALL_DIR/include/"; then
            echo "Error: Failed to copy iOS headers for $LIB_NAME"
            RESULT=1
        fi
        echo "Copied headers for iOS"
    fi
    
    # 复制 macOS 头文件
    if [ -d "$LIB_INSTALL_DIR/macos/arm64/include" ]; then
        if ! cp -R "$LIB_INSTALL_DIR/macos/arm64/include/" "$LIB_INSTALL_DIR/include/"; then
            echo "Error: Failed to copy macOS headers for $LIB_NAME"
            RESULT=1
        fi
        echo "Copied headers for macOS"
    fi
    
    return $RESULT
}

# 清理函数
cleanup() {
    local CLEAN_ALL=${1:-false}  # 默认不清理所有
    echo "Cleaning up..."
    
    if [ -d "$DEPS_ROOT" ]; then
        if [ "$CLEAN_ALL" = true ]; then
            echo "Performing complete cleanup..."
            # 完全清理
            if [ -f "$BUILD_STATUS_FILE" ]; then
                mv "$BUILD_STATUS_FILE" /tmp/build_status.tmp
            fi
            
            if ! rm -rf "$DEPS_ROOT"; then
                echo "Warning: Failed to clean up $DEPS_ROOT"
            fi
            
            mkdir -p "$DEPS_ROOT"
            
            if [ -f "/tmp/build_status.tmp" ]; then
                mv /tmp/build_status.tmp "$BUILD_STATUS_FILE"
            fi
        else
            echo "Cleaning only incomplete builds..."
            # 只清理未完成的构建
            for lib in $(check_incomplete_builds); do
                echo "Cleaning incomplete build: $lib"
                rm -rf "$DEPS_ROOT/$lib"
            done
        fi
    fi
}

# 在 build_library 函数后添加 build_openssl 函数
build_openssl() {
    local VERSION="3.1.4"
    local LIB_NAME="openssl"
    
    # 检查是否已经成功构建
    if check_library_status "$LIB_NAME"; then
        echo "$LIB_NAME already built successfully, skipping..."
        return 0
    fi
    
    echo "Building $LIB_NAME..."
    
    # 为 OpenSSL 创建独立的构建和安装目录
    local LIB_BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local LIB_INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    # 检查是否已有安装文件
    if [ -d "$LIB_INSTALL_DIR" ] && [ -f "$LIB_INSTALL_DIR/build_complete" ]; then
        echo "$LIB_NAME already installed, skipping..."
        mark_library_status "$LIB_NAME" "success"
        return 0
    fi
    
    mkdir -p "$LIB_BUILD_DIR" "$LIB_INSTALL_DIR"
    cd "$LIB_BUILD_DIR"
    
    # 检查是否已有源码
    local SOURCE_DIR="$LIB_NAME-$VERSION"
    if [ ! -d "$SOURCE_DIR" ] || [ ! -f "${LIB_NAME}.tar.gz" ]; then
        # 下载源码
        echo "Downloading $LIB_NAME..."
        if ! curl -L --retry 3 --retry-delay 2 -o "${LIB_NAME}.tar.gz" "https://www.openssl.org/source/openssl-${VERSION}.tar.gz"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to download $LIB_NAME"
            exit 1
        fi
        
        echo "Extracting $LIB_NAME..."
        if ! tar xzf "${LIB_NAME}.tar.gz"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to extract ${LIB_NAME}.tar.gz"
            exit 1
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    # iOS 编译
    echo "Building for iOS (arm64)..."
    for ARCH in $IOS_ARCHS; do
        echo "Building for architecture: $ARCH"
        
        # 清理之前的构建
        make clean >/dev/null 2>&1 || true
        
        # 设置 iOS 编译环境
        export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
        export CROSS_SDK="iPhoneOS.sdk"
        export CC="$(xcrun -find -sdk iphoneos clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
        
        # 配置和编译
        ./Configure ios64-cross \
            no-shared \
            no-dso \
            no-hw \
            no-engine \
            no-async \
            no-tests \
            --prefix="$LIB_INSTALL_DIR/ios/$ARCH" \
            --openssldir="$LIB_INSTALL_DIR/ios/$ARCH" \
            || { echo "Configure failed for iOS $ARCH"; exit 1; }
        
        make -j$(sysctl -n hw.ncpu) build_libs || { echo "Make failed for iOS $ARCH"; exit 1; }
        make install_dev || { echo "Make install failed for iOS $ARCH"; exit 1; }
        
        echo "Successfully built $LIB_NAME for iOS $ARCH"
    done
    
    # macOS 编译
    echo "Building for macOS..."
    for ARCH in $MACOS_ARCHS; do
        echo "Building for architecture: $ARCH"
        
        # 清理之前的构建
        make clean >/dev/null 2>&1 || true
        
        # 设置 macOS 编译环境
        unset CROSS_TOP CROSS_SDK
        export CC="$(xcrun -find -sdk macosx clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        
        local OPENSSL_PLATFORM
        if [ "$ARCH" = "arm64" ]; then
            OPENSSL_PLATFORM="darwin64-arm64-cc"
        else
            OPENSSL_PLATFORM="darwin64-x86_64-cc"
        fi
        
        # 配置和编译
        ./Configure "$OPENSSL_PLATFORM" \
            no-shared \
            no-dso \
            no-hw \
            no-engine \
            no-async \
            no-tests \
            --prefix="$LIB_INSTALL_DIR/macos/$ARCH" \
            --openssldir="$LIB_INSTALL_DIR/macos/$ARCH" \
            || { echo "Configure failed for macOS $ARCH"; exit 1; }
        
        make -j$(sysctl -n hw.ncpu) build_libs || { echo "Make failed for macOS $ARCH"; exit 1; }
        make install_dev || { echo "Make install failed for macOS $ARCH"; exit 1; }
        
        echo "Successfully built $LIB_NAME for macOS $ARCH"
    done
    
    # 分别为 libcrypto 和 libssl 创建通用库
    for lib in "libcrypto" "libssl"; do
        # 创建目标目录
        mkdir -p "$LIB_INSTALL_DIR/lib"
        
        # iOS 库文件
        local IOS_LIBS=""
        for arch in $IOS_ARCHS; do
            IOS_LIBS="$IOS_LIBS $LIB_INSTALL_DIR/ios/$arch/lib/${lib}.a"
        done
        
        # macOS 库文件
        local MACOS_LIBS=""
        for arch in $MACOS_ARCHS; do
            MACOS_LIBS="$MACOS_LIBS $LIB_INSTALL_DIR/macos/$arch/lib/${lib}.a"
        done
        
        # 创建 iOS 通用库
        if [ ! -z "$IOS_LIBS" ]; then
            xcrun lipo -create $IOS_LIBS -output "$LIB_INSTALL_DIR/lib/${lib}_ios.a"
        fi
        
        # 创建 macOS 通用库
        if [ ! -z "$MACOS_LIBS" ]; then
            xcrun lipo -create $MACOS_LIBS -output "$LIB_INSTALL_DIR/lib/${lib}_macos.a"
        fi
    done
    
    # 复制头文件
    copy_headers "$LIB_INSTALL_DIR" "$LIB_NAME"
    
    # 标记构建完成
    touch "$LIB_INSTALL_DIR/build_complete"
    mark_library_status "$LIB_NAME" "success"
    
    echo "$LIB_NAME build completed"
}

# 添加新的构建函数
build_shadowsocks() {
    local VERSION="3.3.5"
    local LIB_NAME="shadowsocks-libev"
    local DOWNLOAD_URL="https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${VERSION}/shadowsocks-libev-${VERSION}.tar.gz"
    local MIRROR_URL="https://ghproxy.com/https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${VERSION}/shadowsocks-libev-${VERSION}.tar.gz"
    
    # 检查构建所需工具
    if ! command -v autoconf >/dev/null 2>&1 || ! command -v automake >/dev/null 2>&1 || ! command -v libtool >/dev/null 2>&1; then
        echo "Error: autoconf, automake, and libtool are required for building shadowsocks-libev"
        return 1
    fi
    
    # 检查是否已经成功构建
    if check_library_status "$LIB_NAME"; then
        echo "$LIB_NAME already built successfully, skipping..."
        return 0
    fi
    
    echo "Building $LIB_NAME..."
    
    # 创建构建目录
    local LIB_BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local LIB_INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    # 检查是否已有安装文件
    if [ -d "$LIB_INSTALL_DIR" ] && [ -f "$LIB_INSTALL_DIR/build_complete" ]; then
        echo "$LIB_NAME already installed, skipping..."
        mark_library_status "$LIB_NAME" "success"
        return 0
    fi
    
    mkdir -p "$LIB_BUILD_DIR" "$LIB_INSTALL_DIR"
    cd "$LIB_BUILD_DIR"
    
    # 检查是否已有源码
    local SOURCE_DIR="$LIB_NAME-$VERSION"
    if [ ! -d "$SOURCE_DIR" ] || [ ! -f "${LIB_NAME}.tar.gz" ]; then
        echo "Downloading $LIB_NAME..."
        local MAX_RETRIES=3
        local RETRY_COUNT=0
        local DOWNLOAD_SUCCESS=false
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
            if curl -L --retry 3 --retry-delay 2 -o "${LIB_NAME}.tar.gz" "$DOWNLOAD_URL"; then
                DOWNLOAD_SUCCESS=true
            else
                echo "Primary download failed, trying mirror..."
                if curl -L --retry 3 --retry-delay 2 -o "${LIB_NAME}.tar.gz" "$MIRROR_URL"; then
                    DOWNLOAD_SUCCESS=true
                else
                    RETRY_COUNT=$((RETRY_COUNT + 1))
                    echo "Download failed, attempt $RETRY_COUNT of $MAX_RETRIES"
                    sleep 2
                fi
            fi
        done
        
        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to download $LIB_NAME after $MAX_RETRIES attempts"
            exit 1
        fi
        
        # 验证下载的文件
        if [ ! -s "${LIB_NAME}.tar.gz" ]; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Downloaded file is empty"
            exit 1
        fi
        
        echo "Extracting $LIB_NAME..."
        if ! tar xzf "${LIB_NAME}.tar.gz"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to extract ${LIB_NAME}.tar.gz"
            exit 1
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    # 手动运行自动工具链
    echo "Running autotools chain..."
    if ! autoreconf -if; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to run autoreconf"
        exit 1
    fi
    
    if ! automake --add-missing; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to run automake"
        exit 1
    fi
    
    if ! autoconf; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to run autoconf"
        exit 1
    fi
    
    # 添加超时检测函数
    wait_with_timeout() {
        local pid=$1
        local timeout=${2:-300}  # 默认5分钟超时
        local count=0
        
        while kill -0 $pid 2>/dev/null; do
            sleep 1
            count=$((count + 1))
            if [ $count -ge $timeout ]; then
                echo "Process timed out after ${timeout} seconds"
                kill -9 $pid 2>/dev/null
                return 1
            fi
            # 每30秒显示一次进度
            if [ $((count % 30)) -eq 0 ]; then
                echo "Still building... (${count}s)"
            fi
        done
        
        wait $pid
        return $?
    }

    # 配置和编译 iOS 版本
    for ARCH in $IOS_ARCHS; do
        echo "Building for iOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk iphoneos clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
        
        # 添加依赖库的路径
        export CFLAGS="$CFLAGS -I$DEPS_ROOT/libsodium/install/ios/$ARCH/include -I$DEPS_ROOT/openssl/install/ios/$ARCH/include"
        export LDFLAGS="$LDFLAGS -L$DEPS_ROOT/libsodium/install/ios/$ARCH/lib -L$DEPS_ROOT/openssl/install/ios/$ARCH/lib"
        
        # 将配置命令输出重定向到日志文件
        (./configure --prefix="$LIB_INSTALL_DIR/ios/$ARCH" \
                     --host="arm-apple-darwin" \
                     --enable-static \
                     --disable-shared \
                     --disable-documentation \
                     --with-sodium-include="$DEPS_ROOT/libsodium/install/ios/$ARCH/include" \
                     --with-sodium-lib="$DEPS_ROOT/libsodium/install/ios/$ARCH/lib" \
                     --with-mbedtls-include="$DEPS_ROOT/openssl/install/ios/$ARCH/include" \
                     --with-mbedtls-lib="$DEPS_ROOT/openssl/install/ios/$ARCH/lib") > >(tee -a "$LOG_FILE") 2>&1 &
        
        configure_pid=$!
        # 显示进度并等待完成
        echo "Configuring... This may take a few minutes"
        if ! wait_with_timeout $configure_pid 300; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Configure process timed out"
            exit 1
        fi
        
        make clean
        if ! make -j$(sysctl -n hw.ncpu); then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make failed for iOS $ARCH"
            exit 1
        fi
        
        if ! make install; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make install failed for iOS $ARCH"
            exit 1
        fi
        
        echo "Successfully built $LIB_NAME for iOS $ARCH"
    done
    
    # macOS 编译
    echo "Building for macOS..."
    for ARCH in $MACOS_ARCHS; do
        echo "Building for architecture: $ARCH"
        
        # 设置编译环境
        export CC="$(xcrun -find -sdk macosx clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        
        # 为不同架构设置正确的主机类型
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        # 显示编译环境信息
        echo "Building with:"
        echo "CC: $CC"
        echo "CFLAGS: $CFLAGS"
        echo "LDFLAGS: $LDFLAGS"
        echo "HOST_ARCH: $HOST_ARCH"
        
        # 运行配置和编译
        ./configure \
            --prefix="$LIB_INSTALL_DIR/macos/$ARCH" \
            --host="$HOST_ARCH" \
            --build="$(./config.guess)" \
            --enable-static \
            --disable-shared \
            --disable-tests \
            --disable-dependency-tracking \
            || { echo "Configure failed for macOS $ARCH"; exit 1; }
        
        make clean
        make -j$(sysctl -n hw.ncpu) || { echo "Make failed for macOS $ARCH"; exit 1; }
        make install || { echo "Make install failed for macOS $ARCH"; exit 1; }
        
        echo "Successfully built $LIB_NAME for macOS $ARCH"
    done
    
    # 创建通用库
    create_universal_library "$LIB_INSTALL_DIR" "$LIB_NAME"
    
    # 复制头文件
    copy_headers "$LIB_INSTALL_DIR" "$LIB_NAME"
    
    # 标记构建完成
    touch "$LIB_INSTALL_DIR/build_complete"
    mark_library_status "$LIB_NAME" "success"
    
    echo "$LIB_NAME build completed"
}

build_antinat() {
    local VERSION="0.93"
    local LIB_NAME="antinat"
    local DOWNLOAD_URL="https://sourceforge.net/projects/antinat/files/antinat/antinat-${VERSION}/antinat-${VERSION}.tar.gz"
    
    # 检查是否已经成功构建
    if check_library_status "$LIB_NAME"; then
        echo "$LIB_NAME already built successfully, skipping..."
        return 0
    fi
    
    echo "Building $LIB_NAME..."
    
    local LIB_BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local LIB_INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    # 检查是否已有安装文件
    if [ -d "$LIB_INSTALL_DIR" ] && [ -f "$LIB_INSTALL_DIR/build_complete" ]; then
        echo "$LIB_NAME already installed, skipping..."
        mark_library_status "$LIB_NAME" "success"
        return 0
    fi
    
    mkdir -p "$LIB_BUILD_DIR" "$LIB_INSTALL_DIR"
    cd "$LIB_BUILD_DIR"
    
    # 检查是否已有源码
    local SOURCE_DIR="antinat-${VERSION}"
    if [ ! -d "$SOURCE_DIR" ] || [ ! -f "${LIB_NAME}.tar.gz" ]; then
        echo "Downloading $LIB_NAME..."
        if ! curl -L --retry 3 --retry-delay 2 -o "${LIB_NAME}.tar.gz" "$DOWNLOAD_URL"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to download $LIB_NAME"
            exit 1
        fi
        
        # 验证下载的文件
        if [ ! -s "${LIB_NAME}.tar.gz" ]; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Downloaded file is empty"
            exit 1
        fi
        
        echo "Extracting $LIB_NAME..."
        if ! tar xzf "${LIB_NAME}.tar.gz"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to extract ${LIB_NAME}.tar.gz"
            exit 1
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    # iOS 构建
    for ARCH in $IOS_ARCHS; do
        echo "Building for iOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk iphoneos clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
        
        if ! ./configure --prefix="$LIB_INSTALL_DIR/ios/$ARCH" \
                   --host="arm-apple-darwin" \
                   --enable-static \
                   --disable-shared; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Configure failed for iOS $ARCH"
            exit 1
        fi
                    
        make clean
        if ! make -j$(sysctl -n hw.ncpu); then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make failed for iOS $ARCH"
            exit 1
        fi
        
        if ! make install; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make install failed for iOS $ARCH"
            exit 1
        fi
        
        echo "Successfully built $LIB_NAME for iOS $ARCH"
    done
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        echo "Building for macOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk macosx clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        
        if ! ./configure --prefix="$LIB_INSTALL_DIR/macos/$ARCH" \
                   --host="$ARCH-apple-darwin" \
                   --enable-static \
                   --disable-shared; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Configure failed for macOS $ARCH"
            exit 1
        fi
                    
        make clean
        if ! make -j$(sysctl -n hw.ncpu); then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make failed for macOS $ARCH"
            exit 1
        fi
        
        if ! make install; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make install failed for macOS $ARCH"
            exit 1
        fi
        
        echo "Successfully built $LIB_NAME for macOS $ARCH"
    done
    
    # 创建通用库
    if ! create_universal_library "$LIB_INSTALL_DIR" "$LIB_NAME"; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to create universal library for $LIB_NAME"
        exit 1
    fi
    
    # 复制头文件
    if ! copy_headers "$LIB_INSTALL_DIR" "$LIB_NAME"; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to copy headers for $LIB_NAME"
        exit 1
    fi
    
    # 标记构建完成
    touch "$LIB_INSTALL_DIR/build_complete"
    mark_library_status "$LIB_NAME" "success"
    
    echo "$LIB_NAME build completed"
}

build_privoxy() {
    local VERSION="3.0.34"
    local LIB_NAME="privoxy"
    local DOWNLOAD_URL="https://sourceforge.net/projects/ijbswa/files/Sources/${VERSION}%20%28stable%29/privoxy-${VERSION}-stable-src.tar.gz"
    
    # 检查是否已经成功构建
    if check_library_status "$LIB_NAME"; then
        echo "$LIB_NAME already built successfully, skipping..."
        return 0
    fi
    
    echo "Building $LIB_NAME..."
    
    local LIB_BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local LIB_INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    # 检查是否已有安装文件
    if [ -d "$LIB_INSTALL_DIR" ] && [ -f "$LIB_INSTALL_DIR/build_complete" ]; then
        echo "$LIB_NAME already installed, skipping..."
        mark_library_status "$LIB_NAME" "success"
        return 0
    fi
    
    mkdir -p "$LIB_BUILD_DIR" "$LIB_INSTALL_DIR"
    cd "$LIB_BUILD_DIR"
    
    # 检查是否已有源码
    local SOURCE_DIR="privoxy-${VERSION}-stable"
    if [ ! -d "$SOURCE_DIR" ] || [ ! -f "${LIB_NAME}.tar.gz" ]; then
        echo "Downloading $LIB_NAME..."
        if ! curl -L --retry 3 --retry-delay 2 -o "${LIB_NAME}.tar.gz" "$DOWNLOAD_URL"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to download $LIB_NAME"
            exit 1
        fi
        
        # 验证下载的文件
        if [ ! -s "${LIB_NAME}.tar.gz" ]; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Downloaded file is empty"
            exit 1
        fi
        
        echo "Extracting $LIB_NAME..."
        if ! tar xzf "${LIB_NAME}.tar.gz"; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Failed to extract ${LIB_NAME}.tar.gz"
            exit 1
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    # iOS 构建
    for ARCH in $IOS_ARCHS; do
        echo "Building for iOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk iphoneos clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
        
        if ! autoheader; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Autoheader failed for iOS $ARCH"
            exit 1
        fi
        
        if ! autoconf; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Autoconf failed for iOS $ARCH"
            exit 1
        fi
        
        if ! ./configure --prefix="$LIB_INSTALL_DIR/ios/$ARCH" \
                   --host="arm-apple-darwin" \
                   --enable-static \
                   --disable-shared \
                   --disable-pcre; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Configure failed for iOS $ARCH"
            exit 1
        fi
                    
        make clean
        if ! make -j$(sysctl -n hw.ncpu); then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make failed for iOS $ARCH"
            exit 1
        fi
        
        if ! make install; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make install failed for iOS $ARCH"
            exit 1
        fi
        
        echo "Successfully built $LIB_NAME for iOS $ARCH"
    done
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        echo "Building for macOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk macosx clang)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path)"
        
        if ! autoheader; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Autoheader failed for macOS $ARCH"
            exit 1
        fi
        
        if ! autoconf; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Autoconf failed for macOS $ARCH"
            exit 1
        fi
        
        if ! ./configure --prefix="$LIB_INSTALL_DIR/macos/$ARCH" \
                   --host="$ARCH-apple-darwin" \
                   --enable-static \
                   --disable-shared \
                   --disable-pcre; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Configure failed for macOS $ARCH"
            exit 1
        fi
                    
        make clean
        if ! make -j$(sysctl -n hw.ncpu); then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make failed for macOS $ARCH"
            exit 1
        fi
        
        if ! make install; then
            mark_library_status "$LIB_NAME" "failed"
            echo "Make install failed for macOS $ARCH"
            exit 1
        fi
        
        echo "Successfully built $LIB_NAME for macOS $ARCH"
    done
    
    # 创建通用库
    if ! create_universal_library "$LIB_INSTALL_DIR" "$LIB_NAME"; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to create universal library for $LIB_NAME"
        exit 1
    fi
    
    # 复制头文件
    if ! copy_headers "$LIB_INSTALL_DIR" "$LIB_NAME"; then
        mark_library_status "$LIB_NAME" "failed"
        echo "Failed to copy headers for $LIB_NAME"
        exit 1
    fi
    
    # 标记构建完成
    touch "$LIB_INSTALL_DIR/build_complete"
    mark_library_status "$LIB_NAME" "success"
    
    echo "$LIB_NAME build completed"
}

# 检查未完成的构建
check_incomplete_builds() {
    local INCOMPLETE_BUILDS=()
    local ALL_LIBS=("libsodium" "libmaxminddb" "openssl" "shadowsocks-libev" "antinat" "privoxy")
    
    echo "Checking for incomplete builds..."
    
    for lib in "${ALL_LIBS[@]}"; do
        local LIB_INSTALL_DIR="$DEPS_ROOT/$lib/install"
        
        if [ -d "$LIB_INSTALL_DIR" ] && [ ! -f "$LIB_INSTALL_DIR/build_complete" ]; then
            INCOMPLETE_BUILDS+=("$lib")
        fi
    done
    
    # 只输出实际的库名
    if [ ${#INCOMPLETE_BUILDS[@]} -gt 0 ]; then
        echo "${INCOMPLETE_BUILDS[@]}"
    fi
}

# 显示构建摘要
show_build_summary() {
    local ALL_LIBS=("libsodium" "libmaxminddb" "openssl" "shadowsocks-libev" "antinat" "privoxy")
    local SUCCESS_COUNT=0
    local FAILED_COUNT=0
    
    echo "Build Summary:"
    echo "=============="
    
    for lib in "${ALL_LIBS[@]}"; do
        if check_library_status "$lib"; then
            echo "✅ $lib: Success"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "❌ $lib: Failed"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    done
    
    echo "=============="
    echo "Total: $((SUCCESS_COUNT + FAILED_COUNT))"
    echo "Successful: $SUCCESS_COUNT"
    echo "Failed: $FAILED_COUNT"
}

# 显示进度
show_spinner() {
    local pid=$1
    local message=$2
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r%s... %c" "$message" "${spin:$i:1}"
        sleep .1
    done
    printf "\r%s... Done\n" "$message"
}

# 修改 main 函数
main() {
    local BUILD_FAILED=false
    local START_TIME=$(date +%s)
    local CLEAN_ALL=false
    
    # 设置日志
    setup_logging
    
    # 处理命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean-all)
                CLEAN_ALL=true
                shift
                ;;
            --verbose)
                set -x  # 启用详细日志
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 确保目录存在
    mkdir -p "$DEPS_ROOT"
    
    # 检查未完成的构建
    check_incomplete_builds
    
    # 清理构建文件
    cleanup "$CLEAN_ALL"
    
    log_info "Starting build process..."
    echo "Build started at $(date)"
    
    # 编译 libsodium
    if ! build_library "libsodium" "1.0.20" "https://ghproxy.com/https://github.com/jedisct1/libsodium/releases/download/1.0.20-RELEASE/libsodium-1.0.20.tar.gz" false; then
        BUILD_FAILED=true
    fi
    
    # 编译 libmaxminddb
    if ! build_library "libmaxminddb" "1.7.1" "https://github.com/maxmind/libmaxminddb/archive/refs/tags/1.7.1.tar.gz" true; then
        BUILD_FAILED=true
    fi
    
    # 编译 OpenSSL
    if ! build_openssl; then
        BUILD_FAILED=true
    fi
    
    # 编译新添加的库
    if ! build_shadowsocks; then
        BUILD_FAILED=true
    fi
    
    if ! build_antinat; then
        BUILD_FAILED=true
    fi
    
    if ! build_privoxy; then
        BUILD_FAILED=true
    fi
    
    # 计算构建时间
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local HOURS=$((DURATION / 3600))
    local MINUTES=$(((DURATION % 3600) / 60))
    local SECONDS=$((DURATION % 60))
    
    echo "Build completed at $(date)"
    echo "Total build time: ${HOURS}h ${MINUTES}m ${SECONDS}s"
    
    # 显示构建摘要
    show_build_summary
    
    if [ "$BUILD_FAILED" = true ]; then
        echo "❌ Build process completed with errors"
        exit 1
    fi
    
    echo "✅ All libraries built successfully!"
    return 0
}

# 添加信号处理
trap 'echo "Build process interrupted"; show_build_summary; exit 1' INT TERM

# 检查是否已安装必要的工具
check_prerequisites() {
    local MISSING_TOOLS=()
    
    # 检查必需的工具
    for tool in autoconf automake libtool cmake; do
        if ! command -v $tool >/dev/null 2>&1; then
            MISSING_TOOLS+=($tool)
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        echo "Error: The following tools are required but not installed:"
        for tool in "${MISSING_TOOLS[@]}"; do
            echo "  - $tool (install with: brew install $tool)"
        done
        exit 1
    fi
    
    # 检查 Xcode 命令行工具
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Error: Xcode Command Line Tools are not installed"
        echo "Install with: xcode-select --install"
        exit 1
    fi
}

# 运行前检查
check_prerequisites
main

