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
    if [ "$1" = "success" ] && [ $BUILD_SUCCESS -eq 1 ]; then
        log_info "Cleaning up build files after successful build..."
        # 检查文件是否存在后再删除
        if [ -d "$BUILD_DIR" ]; then
            if [ -d "$BUILD_DIR/shadowsocks-libev-$VERSION" ]; then
                rm -rf "$BUILD_DIR/shadowsocks-libev-$VERSION"
            fi
            if [ -d "$BUILD_DIR/libcork" ]; then
                rm -rf "$BUILD_DIR/libcork"
            fi
        fi
    else
        log_info "Keeping build files for debugging..."
    fi
}

# 检查目标文件是否已经存在
check_target_files() {
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    if [ -f "$INSTALL_DIR/lib/libshadowsocks_ios.a" ] && \
       [ -f "$INSTALL_DIR/lib/libshadowsocks_macos.a" ] && \
       [ -d "$INSTALL_DIR/include" ]; then
        log_info "Target files already exist, skipping build..."
        return 0
    fi
    return 1
}

# 检查源代码是否已存在
check_source_files() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local SOURCE_DIR="$BUILD_DIR/shadowsocks-libev-$VERSION"
    local ARCHIVE="$BUILD_DIR/shadowsocks-libev.tar.gz"
    
    if [ -d "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/configure.ac" ]; then
        log_info "Source code already exists, skipping download..."
        return 0
    elif [ -f "$ARCHIVE" ]; then
        log_info "Archive already exists, extracting..."
        return 2
    fi
    return 1
}

# 创建必要的目录
mkdir -p "$DEPS_ROOT/$LIB_NAME"
mkdir -p "$SCRIPT_DIR/backup"

# 下载配置文件
download_config_files() {
    log_info "Downloading config.guess and config.sub..."
    local SOURCE_DIR="$1"
    cd "$SOURCE_DIR"
    
    # 创建 build-aux 目录
    mkdir -p build-aux
    
    # 下载 config.guess
    curl -L -o build-aux/config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess'
    chmod +x build-aux/config.guess
    
    # 下载 config.sub
    curl -L -o build-aux/config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub'
    chmod +x build-aux/config.sub
    
    cd - > /dev/null
}

# 安装依赖
install_dependencies() {
    log_info "Checking and installing dependencies..."
    
    # 构建 PCRE
    if [ ! -f "$DEPS_ROOT/pcre/install/lib/libpcre_ios.a" ] || \
       [ ! -f "$DEPS_ROOT/pcre/install/lib/libpcre_macos.a" ]; then
        log_info "Building PCRE..."
        if ! build_pcre; then
            log_error "Failed to build PCRE"
            return 1
        fi
    fi
    
    # 检查并安装 mbedtls
    if ! brew list mbedtls &>/dev/null; then
        log_info "Installing mbedtls..."
        brew install mbedtls
    fi
    
    # 检查并安装 pcre
    if ! brew list pcre &>/dev/null; then
        log_info "Installing pcre..."
        brew install pcre
    fi
    
    # 配置 mbedtls
    log_info "Configuring mbedtls..."
    local MBEDTLS_CONFIG="/opt/homebrew/etc/mbedtls/config.h"
    if [ -f "$MBEDTLS_CONFIG" ]; then
        # 确保 CFB 模式已启用
        if ! grep -q "MBEDTLS_CIPHER_MODE_CFB" "$MBEDTLS_CONFIG"; then
            sudo sed -i '' 's/#define MBEDTLS_CIPHER_MODE_CBC/#define MBEDTLS_CIPHER_MODE_CBC\n#define MBEDTLS_CIPHER_MODE_CFB/g' "$MBEDTLS_CONFIG"
            brew reinstall mbedtls
        fi
    fi
    
    # 检查并构建 libcork
    if [ ! -f "/usr/local/lib/libcork.a" ]; then
        build_libcork
    else
        log_info "libcork already installed, skipping build..."
    fi
    
    return 0
}

# 构建 libcork
build_libcork() {
    log_info "Building libcork..."
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    cd "$BUILD_DIR"
    
    # 定义 libcork 仓库 URL 列表
    local LIBCORK_URLS=(
        "https://github.com/redjack/libcork.git"
        "https://hub.fastgit.xyz/redjack/libcork.git"
        "https://gitclone.com/github.com/redjack/libcork.git"
        "https://gh.api.99988866.xyz/https://github.com/redjack/libcork.git"
    )
    
    # 如果目录已存在，尝试更新
    if [ -d "libcork" ]; then
        cd libcork
        if git pull origin master; then
            log_info "Successfully updated libcork"
        else
            cd ..
            rm -rf libcork
            log_warning "Failed to update libcork, will try fresh clone"
        fi
        cd ..
    fi
    
    # 如果需要克隆
    if [ ! -d "libcork" ]; then
        CLONE_SUCCESS=0
        for url in "${LIBCORK_URLS[@]}"; do
            log_info "Trying to clone libcork from: $url"
            if git clone --depth 1 "$url" libcork 2>/dev/null; then
                CLONE_SUCCESS=1
                break
            else
                log_warning "Failed to clone from $url, trying next..."
                rm -rf libcork
            fi
        done
        
        if [ $CLONE_SUCCESS -eq 0 ]; then
            log_error "Failed to clone libcork repository from all mirrors"
            return 1
        fi
    fi
    
    cd libcork
    
    # 检查 CMakeLists.txt
    if [ ! -f "CMakeLists.txt" ]; then
        log_error "CMakeLists.txt not found in libcork directory"
        return 1
    fi
    
    # 构建
    rm -rf build
    mkdir -p build
    cd build
    
    # 配置 CMake
    cmake .. -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_SHARED=OFF \
            -DENABLE_TESTS=OFF \
            -DCMAKE_C_FLAGS="-Wno-error=format -fPIC" \
            -DCMAKE_INSTALL_PREFIX=/usr/local
    
    # 编译和安装
    make clean || true
    if ! make -j$(sysctl -n hw.ncpu); then
        log_error "Failed to build libcork"
        return 1
    fi
    
    if ! sudo make install; then
        log_error "Failed to install libcork"
        return 1
    fi
    
    sudo chown -R $(whoami) .
    cd "$BUILD_DIR"
    return 0
}

# 构建 PCRE
build_pcre() {
    log_info "Building PCRE for iOS and macOS..."
    local BUILD_DIR="$DEPS_ROOT/pcre/build"
    local INSTALL_DIR="$DEPS_ROOT/pcre/install"
    local PCRE_VERSION="8.45"
    local DOWNLOAD_URL="https://sourceforge.net/projects/pcre/files/pcre/$PCRE_VERSION/pcre-$PCRE_VERSION.tar.gz"
    
    # 创建目录
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR/ios"
    mkdir -p "$INSTALL_DIR/macos"
    
    cd "$BUILD_DIR"
    
    # 下载 PCRE
    if [ ! -f "pcre-$PCRE_VERSION.tar.gz" ]; then
        log_info "Downloading PCRE..."
        curl -L -o "pcre-$PCRE_VERSION.tar.gz" "$DOWNLOAD_URL"
    fi
    
    # 解压
    if [ ! -d "pcre-$PCRE_VERSION" ]; then
        tar xzf "pcre-$PCRE_VERSION.tar.gz"
    fi
    
    cd "pcre-$PCRE_VERSION"
    
    # 下载配置文件
    curl -L -o config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess'
    curl -L -o config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub'
    chmod +x config.guess config.sub
    
    # iOS 构建
    log_info "Building PCRE for iOS..."
    
    # 设置 iOS 交叉编译环境
    export DEVROOT="$(xcode-select -print-path)"
    export SDKROOT="$(xcrun -sdk iphoneos --show-sdk-path)"
    export CC="$(xcrun -sdk iphoneos -find clang)"
    export CXX="$(xcrun -sdk iphoneos -find clang++)"
    export LD="$(xcrun -sdk iphoneos -find ld)"
    export AR="$(xcrun -sdk iphoneos -find ar)"
    export AS="$CC"
    export NM="$(xcrun -sdk iphoneos -find nm)"
    export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
    export STRIP="$(xcrun -sdk iphoneos -find strip)"
    
    export CFLAGS="-arch arm64 -isysroot $SDKROOT -miphoneos-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $SDKROOT"
    
    # 设置交叉编译缓存变量
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap_fixed_mapped=yes
    export ac_cv_file__dev_zero=no
    export ac_cv_file__dev_random=yes
    export ac_cv_func_clock_gettime=no
    export ac_cv_func_memset_s=no
    export ac_cv_func_setcontext=no
    export ac_cv_func_strlcpy=yes
    export ac_cv_func_strlcat=yes
    export ac_cv_func_getentropy=no
    export cross_compiling=yes
    
    ./configure --host=arm-apple-darwin \
               --build="$(./config.guess)" \
               --prefix="$INSTALL_DIR/ios" \
               --enable-static \
               --disable-shared \
               --enable-utf8 \
               --enable-unicode-properties \
               --disable-cpp \
               --with-pic \
               --disable-dependency-tracking \
               || return 1
    
    make clean
    make -j$(sysctl -n hw.ncpu) || return 1
    make install || return 1
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        log_info "Building PCRE for macOS ($ARCH)..."
        
        export SDKROOT="$(xcrun -sdk macosx --show-sdk-path)"
        export CC="$(xcrun -sdk macosx -find clang)"
        export CXX="$(xcrun -sdk macosx -find clang++)"
        export LD="$(xcrun -sdk macosx -find ld)"
        export AR="$(xcrun -sdk macosx -find ar)"
        export AS="$CC"
        export NM="$(xcrun -sdk macosx -find nm)"
        export RANLIB="$(xcrun -sdk macosx -find ranlib)"
        export STRIP="$(xcrun -sdk macosx -find strip)"
        
        export CFLAGS="-arch $ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch $ARCH -isysroot $SDKROOT"
        
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        ./configure --host="$HOST_ARCH" \
                   --build="$(./config.guess)" \
                   --prefix="$INSTALL_DIR/macos/$ARCH" \
                   --enable-static \
                   --disable-shared \
                   --enable-utf8 \
                   --enable-unicode-properties \
                   --disable-cpp \
                   --with-pic \
                   --disable-dependency-tracking \
                   || return 1
        
        make clean
        make -j$(sysctl -n hw.ncpu) || return 1
        make install || return 1
    done
    
    # 创建通用库
    mkdir -p "$INSTALL_DIR/lib"
    
    # iOS
    cp "$INSTALL_DIR/ios/lib/libpcre.a" "$INSTALL_DIR/lib/libpcre_ios.a"
    
    # macOS
    xcrun lipo -create \
        "$INSTALL_DIR/macos/arm64/lib/libpcre.a" \
        "$INSTALL_DIR/macos/x86_64/lib/libpcre.a" \
        -output "$INSTALL_DIR/lib/libpcre_macos.a"
    
    return 0
}

# 构建配置
configure_build() {
    local PLATFORM=$1
    local ARCH=$2
    local INSTALL_PREFIX=$3
    
    # 设置基础工具链
    if [ "$PLATFORM" = "iphoneos" ]; then
        export DEVELOPER="$(xcode-select -print-path)"
        export SDKVERSION="$(xcrun -sdk iphoneos --show-sdk-version)"
        export IPHONEOS_DEPLOYMENT_TARGET="15.0"
        export SDKROOT="$(xcrun -sdk iphoneos --show-sdk-path)"
        export TOOLCHAIN_BIN="$(xcrun -sdk iphoneos -find clang)"
        export TOOLCHAIN_PATH="$(dirname "$TOOLCHAIN_BIN")"
        export PATH="$TOOLCHAIN_PATH:$PATH"
        
        # 设置编译器和工具链
        export CC="$(xcrun -sdk iphoneos -find clang)"
        export CXX="$(xcrun -sdk iphoneos -find clang++)"
        export LD="$(xcrun -sdk iphoneos -find ld)"
        export AR="$(xcrun -sdk iphoneos -find ar)"
        export AS="$CC"
        export NM="$(xcrun -sdk iphoneos -find nm)"
        export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
        export STRIP="$(xcrun -sdk iphoneos -find strip)"
        
        # 设置编译标志
        export CFLAGS="-arch arm64 -isysroot $SDKROOT -miphoneos-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch arm64 -isysroot $SDKROOT"
        
        # 设置交叉编译参数
        export CROSS_TOP="$SDKROOT"
        export CROSS_SDK="$(basename $SDKROOT)"
        export BUILD_TOOLS="$DEVELOPER"
        export HOST="arm-apple-darwin"
        export BUILD="$(./build-aux/config.guess)"
        
        # 设置 pkg-config 路径
        export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:/opt/homebrew/opt/mbedtls/lib/pkgconfig"
        
        # 设置依赖库路径
        export SODIUM_INCLUDE="$DEPS_ROOT/libsodium/install/include"
        export SODIUM_LIB="$DEPS_ROOT/libsodium/install/lib"
        export OPENSSL_INCLUDE="$DEPS_ROOT/openssl/install/include"
        export OPENSSL_LIB="$DEPS_ROOT/openssl/install/lib"
        
        # 设置交叉编译缓存变量
        export ac_cv_func_malloc_0_nonnull=yes
        export ac_cv_func_realloc_0_nonnull=yes
        export ac_cv_func_mmap_fixed_mapped=yes
        export ac_cv_file__dev_zero=no
        export ac_cv_file__dev_random=yes
        export ac_cv_func_clock_gettime=no
        export ac_cv_func_memset_s=no
        export ac_cv_func_setcontext=no
        export ac_cv_func_strlcpy=yes
        export ac_cv_func_strlcat=yes
        export ac_cv_func_getentropy=no
        
        # 修改 PCRE 配置
        export PCRE_INCLUDE="$DEPS_ROOT/pcre/install/ios/include"
        export PCRE_LIB="$DEPS_ROOT/pcre/install/ios/lib"
        export CFLAGS="$CFLAGS -I$PCRE_INCLUDE"
        export LDFLAGS="$LDFLAGS -L$PCRE_LIB"
        
        # 配置命令
        ./configure --prefix="$INSTALL_PREFIX" \
            --host="$HOST" \
            --build="$BUILD" \
            --enable-static \
            --disable-shared \
            --disable-documentation \
            --disable-ssp \
            --disable-dependency-tracking \
            --with-sodium-include="$SODIUM_INCLUDE" \
            --with-sodium-lib="$SODIUM_LIB" \
            --with-openssl-include="$OPENSSL_INCLUDE" \
            --with-openssl-lib="$OPENSSL_LIB" \
            --with-mbedtls=/opt/homebrew/opt/mbedtls \
            --with-pcre="$DEPS_ROOT/pcre/install/ios" \
            || return 1
            
    else
        # macOS 构建配置
        export SDKROOT="$(xcrun -sdk macosx --show-sdk-path)"
        export MACOSX_DEPLOYMENT_TARGET="12.0"
        export CC="$(xcrun -sdk macosx -find clang)"
        export CXX="$(xcrun -sdk macosx -find clang++)"
        export CFLAGS="-arch $ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch $ARCH -isysroot $SDKROOT"
        
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        ./configure --prefix="$INSTALL_PREFIX" \
            --host="$HOST_ARCH" \
            --build="$(./build-aux/config.guess)" \
            --enable-static \
            --disable-shared \
            --disable-documentation \
            --with-sodium="$DEPS_ROOT/libsodium/install" \
            --with-mbedtls=/opt/homebrew/opt/mbedtls \
            --with-pcre=/opt/homebrew/opt/pcre \
            || return 1
    fi
    
    return 0
}

# 检查依赖库
check_dependencies() {
    log_info "Checking dependencies..."
    
    # 检查 libsodium
    if [ ! -f "$DEPS_ROOT/libsodium/install/lib/libsodium_ios.a" ] || \
       [ ! -f "$DEPS_ROOT/libsodium/install/lib/libsodium_macos.a" ]; then
        log_error "libsodium libraries not found. Please run build-libsodium.sh first."
        return 1
    fi
    
    # 检查 OpenSSL
    if [ ! -f "$DEPS_ROOT/openssl/install/lib/libssl_ios.a" ] || \
       [ ! -f "$DEPS_ROOT/openssl/install/lib/libcrypto_ios.a" ] || \
       [ ! -f "$DEPS_ROOT/openssl/install/lib/libssl_macos.a" ] || \
       [ ! -f "$DEPS_ROOT/openssl/install/lib/libcrypto_macos.a" ]; then
        log_error "OpenSSL libraries not found. Please run build-openssl.sh first."
        return 1
    fi
    
    # 检查 PCRE
    if ! brew list pcre &>/dev/null; then
        log_error "PCRE not installed. Will be installed during dependency installation."
    fi
    
    # 检查 mbedTLS
    if ! brew list mbedtls &>/dev/null; then
        log_error "mbedTLS not installed. Will be installed during dependency installation."
    fi
    
    return 0
}

# 验证编译环境
verify_build_env() {
    local PLATFORM=$1
    local ARCH=$2
    
    log_info "Verifying build environment for $PLATFORM ($ARCH)..."
    
    # 检查 Xcode 命令行工具
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode command line tools not found. Please install them first."
        return 1
    fi
    
    # 检查 SDK
    if [ "$PLATFORM" = "iphoneos" ]; then
        if ! xcrun --sdk iphoneos --show-sdk-path &>/dev/null; then
            log_error "iOS SDK not found. Please install Xcode and iOS SDK first."
            return 1
        fi
    else
        if ! xcrun --sdk macosx --show-sdk-path &>/dev/null; then
            log_error "macOS SDK not found. Please install Xcode and macOS SDK first."
            return 1
        fi
    fi
    
    # 检查编译器
    if [ "$PLATFORM" = "iphoneos" ]; then
        if ! xcrun -sdk iphoneos -find clang &>/dev/null; then
            log_error "iOS clang compiler not found."
            return 1
        fi
    else
        if ! xcrun -sdk macosx -find clang &>/dev/null; then
            log_error "macOS clang compiler not found."
            return 1
        fi
    fi
    
    # 检查构建工具
    local REQUIRED_TOOLS="ar ranlib strip nm ld"
    for tool in $REQUIRED_TOOLS; do
        if [ "$PLATFORM" = "iphoneos" ]; then
            if ! xcrun -sdk iphoneos -find $tool &>/dev/null; then
                log_error "iOS $tool not found."
                return 1
            fi
        else
            if ! xcrun -sdk macosx -find $tool &>/dev/null; then
                log_error "macOS $tool not found."
                return 1
            fi
        fi
    done
    
    return 0
}

# 构建特定平台
build_platform() {
    local PLATFORM=$1
    local ARCH=$2
    local INSTALL_PREFIX=$3
    
    log_info "Building for $PLATFORM ($ARCH)..."
    
    # 验证编译环境
    if ! verify_build_env "$PLATFORM" "$ARCH"; then
        log_error "Build environment verification failed"
        return 1
    fi
    
    # 确保构建目录存在
    mkdir -p "$(dirname "$INSTALL_PREFIX")"
    
    # 配置构建
    if ! configure_build "$PLATFORM" "$ARCH" "$INSTALL_PREFIX"; then
        log_error "$PLATFORM $ARCH configure failed"
        return 1
    fi
    
    # 清理之前的构建
    if [ -f Makefile ]; then
        make clean || true
    fi
    
    # 编译
    if ! make -j$(sysctl -n hw.ncpu); then
        log_error "$PLATFORM $ARCH make failed"
        return 1
    fi
    
    # 安装
    if ! make install; then
        log_error "$PLATFORM $ARCH make install failed"
        return 1
    fi
    
    return 0
}

# 下载源码
download_shadowsocks() {
    local ARCHIVE="$1"
    local VERSION="$2"
    local MIRRORS=(
        "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v$VERSION/shadowsocks-libev-$VERSION.tar.gz"
        "https://github.com/shadowsocks/shadowsocks-libev/archive/v$VERSION.tar.gz"
        "https://hub.fastgit.xyz/shadowsocks/shadowsocks-libev/archive/v$VERSION.tar.gz"
        "https://gitclone.com/github.com/shadowsocks/shadowsocks-libev/archive/v$VERSION.tar.gz"
    )
    
    for url in "${MIRRORS[@]}"; do
        log_info "Trying to download from: $url"
        if curl -L --retry 3 --retry-delay 2 -o "$ARCHIVE" "$url"; then
            return 0
        else
            log_warning "Failed to download from $url, trying next mirror..."
            rm -f "$ARCHIVE"
        fi
    done
    
    return 1
}

# 构建 shadowsocks-libev
build_shadowsocks() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local ARCHIVE="$BUILD_DIR/shadowsocks-libev.tar.gz"
    local SOURCE_DIR="$BUILD_DIR/shadowsocks-libev-$VERSION"
    
    # 检查目标文件
    if check_target_files; then
        return 0
    fi
    
    # 创建构建目录（如果不存在）
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$BUILD_DIR"
    
    # 检查源代码
    local source_status=0
    if [ -d "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/configure.ac" ]; then
        log_info "Source code already exists, skipping download..."
        source_status=1
    elif [ -f "$ARCHIVE" ]; then
        log_info "Archive already exists, extracting..."
        source_status=2
    fi
    
    if [ $source_status -eq 0 ]; then
        # 下载源码
        log_info "Downloading shadowsocks-libev..."
        if ! download_shadowsocks "$ARCHIVE" "$VERSION"; then
            log_error "Failed to download shadowsocks-libev from all mirrors"
            return 1
        fi
        source_status=2
    fi
    
    if [ $source_status -eq 2 ]; then
        # 解压源码
        log_info "Extracting shadowsocks-libev..."
        if ! tar xzf "$ARCHIVE"; then
            log_error "Failed to extract shadowsocks-libev"
            return 1
        fi
    fi
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found after extraction"
        return 1
    fi
    
    cd "$SOURCE_DIR"
    
    # 下载配置文件
    download_config_files "$SOURCE_DIR"
    
    # 运行自动工具链
    log_info "Running autotools..."
    autoreconf -ivf
    
    # 创建构建目录
    mkdir -p "$INSTALL_DIR/ios"
    mkdir -p "$INSTALL_DIR/macos"
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    if ! build_platform "iphoneos" "arm64" "$INSTALL_DIR/ios"; then
        log_error "iOS build failed"
        return 1
    fi
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        log_info "Building for macOS architecture: $ARCH"
        if ! build_platform "macosx" "$ARCH" "$INSTALL_DIR/macos/$ARCH"; then
            log_error "macOS $ARCH build failed"
            return 1
        fi
    done
    
    return 0
}

# 创建通用库
create_universal_library() {
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    mkdir -p "$INSTALL_DIR/lib"
    
    # 检查源文件是否存在
    if [ ! -f "$INSTALL_DIR/ios/lib/libshadowsocks-libev.a" ]; then
        log_error "iOS library not found at $INSTALL_DIR/ios/lib/libshadowsocks-libev.a"
        return 1
    fi
    
    if [ ! -f "$INSTALL_DIR/macos/arm64/lib/libshadowsocks-libev.a" ] || \
       [ ! -f "$INSTALL_DIR/macos/x86_64/lib/libshadowsocks-libev.a" ]; then
        log_error "macOS libraries not found"
        return 1
    fi
    
    # iOS 库
    log_info "Creating iOS universal library..."
    cp "$INSTALL_DIR/ios/lib/libshadowsocks-libev.a" "$INSTALL_DIR/lib/libshadowsocks_ios.a"
    
    # macOS 通用库
    log_info "Creating macOS universal library..."
    xcrun lipo -create \
        "$INSTALL_DIR/macos/arm64/lib/libshadowsocks-libev.a" \
        "$INSTALL_DIR/macos/x86_64/lib/libshadowsocks-libev.a" \
        -output "$INSTALL_DIR/lib/libshadowsocks_macos.a"
    
    # 复制头文件
    log_info "Copying header files..."
    if [ -d "$INSTALL_DIR/ios/include" ]; then
        cp -R "$INSTALL_DIR/ios/include" "$INSTALL_DIR/"
    else
        log_error "Header files not found at $INSTALL_DIR/ios/include"
        return 1
    fi
    
    # 验证库
    log_info "Verifying libraries..."
    xcrun lipo -info "$INSTALL_DIR/lib/libshadowsocks_ios.a"
    xcrun lipo -info "$INSTALL_DIR/lib/libshadowsocks_macos.a"
    
    return 0
}

# 添加函数来检查编译环境
check_build_environment() {
    log_info "Checking build environment..."
    
    # 检查 Xcode 和命令行工具
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode command line tools not found"
        log_info "Please run: xcode-select --install"
        return 1
    fi
    
    # 检查必要的工具
    local REQUIRED_TOOLS="autoconf automake libtool pkg-config cmake"
    local MISSING_TOOLS=()
    
    for tool in $REQUIRED_TOOLS; do
        if ! command -v $tool >/dev/null 2>&1; then
            MISSING_TOOLS+=($tool)
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        log_error "Required tools are missing: ${MISSING_TOOLS[*]}"
        log_info "Installing missing tools..."
        brew install ${MISSING_TOOLS[@]}
    fi
    
    # 检查依赖库
    local BREW_DEPS="mbedtls pcre"
    for dep in $BREW_DEPS; do
        if ! brew list $dep &>/dev/null; then
            log_info "Installing $dep..."
            brew install $dep
        fi
    done
    
    return 0
}

# 修改主函数，添加环境检查
main() {
    # 检查编译环境
    if ! check_build_environment; then
        log_error "Build environment check failed"
        return 1
    fi
    
    # 检查依赖库
    if ! check_dependencies; then
        log_error "Dependency check failed"
        return 1
    fi
    
    # 安装依赖
    if ! install_dependencies; then
        log_error "Failed to install dependencies"
        return 1
    fi
    
    # 构建 shadowsocks
    if ! build_shadowsocks; then
        log_error "Failed to build shadowsocks"
        return 1
    fi
    
    # 创建通用库
    if ! create_universal_library; then
        log_error "Failed to create universal library"
        return 1
    fi
    
    log_info "Build completed successfully!"
    log_info "Libraries available at: $DEPS_ROOT/$LIB_NAME/install/lib"
    log_info "Headers available at: $DEPS_ROOT/$LIB_NAME/install/include"
    
    return 0
}

# 运行脚本
main