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
    local DOWNLOAD_URLS=(
        "https://sourceforge.net/projects/pcre/files/pcre/$PCRE_VERSION/pcre-$PCRE_VERSION.tar.gz/download"
        "https://ftp.pcre.org/pub/pcre/pcre-$PCRE_VERSION.tar.gz"
        "https://github.com/PCRE2Project/pcre2/releases/download/pcre-$PCRE_VERSION/pcre-$PCRE_VERSION.tar.gz"
    )
    
    # 创建目录
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR/ios"
    mkdir -p "$INSTALL_DIR/macos"
    
    cd "$BUILD_DIR"
    
    # 下载 PCRE
    if [ ! -f "pcre-$PCRE_VERSION.tar.gz" ]; then
        log_info "Downloading PCRE..."
        local download_success=0
        for url in "${DOWNLOAD_URLS[@]}"; do
            log_info "Trying to download from: $url"
            if curl -L -o "pcre-$PCRE_VERSION.tar.gz" "$url"; then
                download_success=1
                break
            else
                log_warning "Failed to download from $url, trying next mirror..."
                rm -f "pcre-$PCRE_VERSION.tar.gz"
            fi
        done
        
        if [ $download_success -eq 0 ]; then
            log_error "Failed to download PCRE from all mirrors"
            return 1
        fi
    fi
    
    # 解压前检查文件是否存在
    if [ ! -f "pcre-$PCRE_VERSION.tar.gz" ]; then
        log_error "PCRE archive not found"
        return 1
    fi
    
    # 解压
    if [ ! -d "pcre-$PCRE_VERSION" ]; then
        log_info "Extracting PCRE..."
        if ! tar xzf "pcre-$PCRE_VERSION.tar.gz"; then
            log_error "Failed to extract PCRE"
            return 1
        fi
    fi
    
    # 检查目录是否存在
    if [ ! -d "pcre-$PCRE_VERSION" ]; then
        log_error "PCRE source directory not found after extraction"
        return 1
    fi
    
    cd "pcre-$PCRE_VERSION"
    
    # 下载配置文件
    curl -L -o config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess'
    curl -L -o config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub'
    chmod +x config.guess config.sub
    
    # iOS 构建
    log_info "Building PCRE for iOS..."
    
    # 设置 iOS 交叉编译环境
    export DEVELOPER="$(xcode-select -print-path)"
    export SDKVERSION="$(xcrun -sdk iphoneos --show-sdk-version)"
    export SDKROOT="$(xcrun -sdk iphoneos --show-sdk-path)"
    export TOOLCHAIN_BIN="$(xcrun -sdk iphoneos -find clang)"
    export TOOLCHAIN_PATH="$(dirname "$TOOLCHAIN_BIN")"
    export PATH="$TOOLCHAIN_PATH:$PATH"
    
    export CC="$(xcrun -sdk iphoneos -find clang)"
    export CXX="$(xcrun -sdk iphoneos -find clang++)"
    export LD="$(xcrun -sdk iphoneos -find ld)"
    export AR="$(xcrun -sdk iphoneos -find ar)"
    export AS="$CC"
    export NM="$(xcrun -sdk iphoneos -find nm)"
    export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
    export STRIP="$(xcrun -sdk iphoneos -find strip)"
    
    # 设置编译标志
    export CFLAGS="-arch arm64 -isysroot $SDKROOT -miphoneos-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode -O2"
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
    export ac_cv_prog_cc_g=no
    export ac_cv_prog_CPP="$CC -E"
    export ac_cv_build="$(./config.guess)"
    export ac_cv_host="arm-apple-darwin"
    export ac_cv_target="arm-apple-darwin"
    
    # 运行配置
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
               --disable-pcretest \
               --disable-pcre16 \
               --disable-pcre32 \
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

# 配置构建参数
configure_build() {
    local platform="$1"
    local arch="$2"
    local prefix="$3"
    
    # 设置依赖库路径
    local mbedtls_dir="$prefix"
    local pcre_dir="$prefix"
    
    # 配置参数
    local configure_args=(
        "--prefix=$prefix"
        "--disable-documentation"
        "--disable-shared"
        "--enable-static"
        "--with-mbedtls=$mbedtls_dir"
        "--with-mbedtls-include=$mbedtls_dir/include"
        "--with-mbedtls-lib=$mbedtls_dir/lib"
        "--with-pcre=$pcre_dir"
        "--with-pcre-include=$pcre_dir/include"
        "--with-pcre-lib=$pcre_dir/lib"
        "--host=arm-apple-darwin"
        "--build=$(./config.guess)"
        "--disable-ssp"
        "--disable-dependency-tracking"
    )
    
    # 运行配置
    if ! ./configure "${configure_args[@]}"; then
        log_error "$platform $arch configure failed"
        return 1
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
    log_info "Verifying build environment..."
    
    # 检查 Xcode 命令行工具
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode command line tools not found. Please install them using: xcode-select --install"
        return 1
    fi
    
    # 检查 iOS SDK
    if ! xcrun --sdk iphoneos --show-sdk-path &>/dev/null; then
        log_error "iOS SDK not found. Please install Xcode and iOS SDK"
        return 1
    fi
    
    # 检查编译器
    if ! command -v clang &>/dev/null; then
        log_error "clang compiler not found"
        return 1
    fi
    
    # 检查构建工具
    local required_tools=("make" "cmake" "git" "curl" "tar" "xz")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "$tool not found. Please install it using Homebrew: brew install $tool"
            return 1
        fi
    done
    
    # 检查 Homebrew
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew not found. Please install it from https://brew.sh"
        return 1
    fi
    
    log_info "Build environment verification completed successfully"
    return 0
}

# 构建特定平台
build_platform() {
    local PLATFORM=$1
    local ARCH=$2
    local INSTALL_PREFIX=$3
    
    log_info "Building for $PLATFORM ($ARCH)..."
    
    # 验证编译环境
    verify_build_env || return 1
    
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
    
    # 验证构建结果
    if ! verify_build_result "$PLATFORM" "$INSTALL_PREFIX"; then
        log_error "Build verification failed for $PLATFORM"
        return 1
    fi
    
    return 0
}

# 下载源码
download_and_verify_source() {
    local url="$1"
    local output_file="$2"
    local expected_sha256="$3"
    
    log_info "Downloading from $url..."
    if ! curl -L --retry 3 --retry-delay 2 -o "$output_file" "$url"; then
        log_error "Failed to download from $url"
        return 1
    fi
    
    if [ -n "$expected_sha256" ]; then
        log_info "Verifying checksum..."
        local actual_sha256
        if ! actual_sha256=$(shasum -a 256 "$output_file" | cut -d' ' -f1); then
            log_error "Failed to calculate SHA256 checksum"
            return 1
        fi
        
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            log_error "Checksum verification failed"
            log_error "Expected: $expected_sha256"
            log_error "Actual: $actual_sha256"
            return 1
        fi
        
        log_info "Checksum verification passed"
    fi
    
    return 0
}

# 在下载源码的地方使用这个函数
download_source() {
    local name="$1"
    local url="$2"
    local output_file="$3"
    local expected_sha256="$4"
    
    if [ -f "$output_file" ]; then
        log_info "Using existing $name source file: $output_file"
        return 0
    fi
    
    log_info "Downloading $name source..."
    if ! download_and_verify_source "$url" "$output_file" "$expected_sha256"; then
        log_error "Failed to download $name source"
        return 1
    fi
    
    return 0
}

# 下载源码
download_shadowsocks() {
    local BUILD_DIR="$1"
    local VERSION="$2"
    local ARCHIVE="$BUILD_DIR/shadowsocks-libev-$VERSION.tar.gz"
    
    # 定义多个下载源
    local DOWNLOAD_URLS=(
        "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v$VERSION/shadowsocks-libev-$VERSION.tar.gz"
        "https://github.com/shadowsocks/shadowsocks-libev/archive/v$VERSION.tar.gz"
        "https://hub.fastgit.xyz/shadowsocks/shadowsocks-libev/archive/v$VERSION.tar.gz"
        "https://ghproxy.com/https://github.com/shadowsocks/shadowsocks-libev/archive/v$VERSION.tar.gz"
    )
    
    if [ -f "$ARCHIVE" ]; then
        log_info "Shadowsocks archive already exists, skipping download"
        return 0
    fi
    
    for url in "${DOWNLOAD_URLS[@]}"; do
        log_info "Trying to download from: $url"
        if curl -L --retry 5 --retry-delay 3 -o "$ARCHIVE" "$url"; then
            if [ -f "$ARCHIVE" ]; then
                local file_size=$(stat -f%z "$ARCHIVE")
                if [ "$file_size" -gt 100000 ]; then  # 确保文件大小大于100KB
                    log_info "Successfully downloaded shadowsocks-libev"
                    return 0
                else
                    log_warning "Downloaded file is too small, might be corrupted"
                    rm -f "$ARCHIVE"
                fi
            fi
        fi
        log_warning "Failed to download from $url, trying next mirror..."
    done
    
    log_error "Failed to download shadowsocks-libev from all mirrors"
    return 1
}

# 构建 shadowsocks-libev
build_shadowsocks() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local SOURCE_DIR="$BUILD_DIR/shadowsocks-libev-$VERSION"
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$BUILD_DIR" || {
        log_error "Failed to change directory to $BUILD_DIR"
        return 1
    }
    
    # 下载源码
    if ! download_shadowsocks "$BUILD_DIR" "$VERSION"; then
        return 1
    fi
    
    # 如果源码目录已存在，先删除
    if [ -d "$SOURCE_DIR" ]; then
        log_info "Removing existing source directory..."
        rm -rf "$SOURCE_DIR"
    fi
    
    # 解压源码
    log_info "Extracting shadowsocks-libev..."
    if ! tar xzf "shadowsocks-libev-$VERSION.tar.gz"; then
        log_error "Failed to extract shadowsocks-libev"
        return 1
    fi
    
    # 确认源码目录存在
    if [ ! -d "$SOURCE_DIR" ]; then
        # 检查是否解压到了不同的目录名
        local extracted_dir=$(find . -maxdepth 1 -type d -name "shadowsocks-libev*" | head -n 1)
        if [ -n "$extracted_dir" ]; then
            mv "$extracted_dir" "$SOURCE_DIR"
        else
            log_error "Could not find extracted shadowsocks-libev directory"
            return 1
        fi
    fi
    
    cd "$SOURCE_DIR" || {
        log_error "Failed to change directory to $SOURCE_DIR"
        return 1
    }
    
    # 下载配置文件
    log_info "Downloading config.guess and config.sub..."
    mkdir -p build-aux
    curl -L -o build-aux/config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess' || {
        log_error "Failed to download config.guess"
        return 1
    }
    curl -L -o build-aux/config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub' || {
        log_error "Failed to download config.sub"
        return 1
    }
    chmod +x build-aux/config.guess build-aux/config.sub
    
    # 运行 autotools
    log_info "Running autotools..."
    autoreconf -ivf
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    
    # 设置 iOS 编译环境
    export CC="$(xcrun -sdk iphoneos -find clang)"
    export CXX="$(xcrun -sdk iphoneos -find clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -I$DEPS_ROOT/pcre/install/ios/include"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -L$DEPS_ROOT/pcre/install/ios/lib"
    
    # 设置交叉编译环境变量
    export cross_compiling=yes
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
    export ac_cv_prog_cc_g=no
    export ac_cv_c_bigendian=no
    export ac_cv_type_signal=void
    export ac_cv_func_malloc=yes
    export ac_cv_func_realloc=yes
    export ac_cv_func_memset=yes
    export ac_cv_func_strchr=yes
    export ac_cv_func_strrchr=yes
    export ac_cv_func_strstr=yes
    export ac_cv_func_strtol=yes
    export ac_cv_func_strtoul=yes
    export ac_cv_func_strtoll=yes
    export ac_cv_func_strtoull=yes
    export ac_cv_func_getpwnam=no
    export ac_cv_func_getpwuid=no
    export ac_cv_func_getspnam=no
    export ac_cv_func_getgrnam=no
    export ac_cv_func_getgrgid=no
    
    # 配置构建
    ./configure --host=arm-apple-darwin \
                --prefix="$INSTALL_DIR/ios" \
                --disable-documentation \
                --disable-shared \
                --enable-static \
                --with-pcre="$DEPS_ROOT/pcre/install/ios" \
                --with-mbedtls="$DEPS_ROOT/mbedtls/install/ios" \
                --disable-ssp \
                --disable-dependency-tracking \
                --disable-silent-rules \
                --disable-assert \
                || return 1
    
    make clean
    make -j$(sysctl -n hw.ncpu) || return 1
    make install || return 1
    
    # macOS 构建
    log_info "Building for macOS..."
    make clean
    
    export CC="$(xcrun -sdk macosx -find clang)"
    export CXX="$(xcrun -sdk macosx -find clang++)"
    export CFLAGS="-arch arm64 -arch x86_64 -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET -I$DEPS_ROOT/pcre/install/macos/include"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -arch x86_64 -isysroot $(xcrun -sdk macosx --show-sdk-path) -L$DEPS_ROOT/pcre/install/macos/lib"
    
    ./configure --host=$(./config.guess) \
                --prefix="$INSTALL_DIR/macos" \
                --disable-documentation \
                --disable-shared \
                --enable-static \
                --with-pcre="$DEPS_ROOT/pcre/install/macos" \
                --with-mbedtls="$DEPS_ROOT/mbedtls/install/macos" \
                --disable-ssp \
                --disable-dependency-tracking \
                || return 1
    
    make -j$(sysctl -n hw.ncpu) || return 1
    make install || return 1
    
    return 0
}

# 创建通用库
create_universal_libraries() {
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    
    # 创建目录
    mkdir -p "$INSTALL_DIR/universal/lib"
    mkdir -p "$INSTALL_DIR/universal/include"
    
    # 复制头文件
    cp -R "$INSTALL_DIR/ios/include/" "$INSTALL_DIR/universal/include/"
    
    # 创建通用库
    log_info "Creating universal libraries..."
    
    local libs=(
        "libshadowsocks-libev.a"
        "libcork.a"
        "libipset.a"
        "libbloom.a"
    )
    
    for lib in "${libs[@]}"; do
        if [ -f "$INSTALL_DIR/ios/lib/$lib" ] && [ -f "$INSTALL_DIR/macos/lib/$lib" ]; then
            log_info "Creating universal library: $lib"
            lipo -create \
                "$INSTALL_DIR/ios/lib/$lib" \
                "$INSTALL_DIR/macos/lib/$lib" \
                -output "$INSTALL_DIR/universal/lib/$lib"
            
            # 验证架构
            lipo -info "$INSTALL_DIR/universal/lib/$lib"
        else
            log_warning "Skipping $lib: source libraries not found"
        fi
    done
    
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

handle_build_error() {
    local error_code=$1
    local stage=$2
    local component=$3
    
    if [ $error_code -ne 0 ]; then
        log_error "Build failed during $stage for $component"
        
        case $stage in
            "configure")
                if [ -f config.log ]; then
                    log_error "Configuration errors (last 10 lines of config.log):"
                    tail -n 10 config.log | while IFS= read -r line; do
                        log_error "    $line"
                    done
                fi
                ;;
            "make")
                log_error "Make errors (last build command):"
                if [ -f Makefile ]; then
                    log_error "    $(tail -n 1 Makefile)"
                fi
                ;;
            "install")
                log_error "Installation errors:"
                log_error "    Check if you have write permissions to $INSTALL_DIR"
                log_error "    Check if there's enough disk space"
                ;;
        esac
        
        log_error "Build artifacts and logs can be found in: $BUILD_DIR"
        return 1
    fi
    
    return 0
}

# 在构建过程中使用这个函数
build_component() {
    local name="$1"
    local configure_args="$2"
    
    log_info "Building $name..."
    
    # 配置
    if ! ./configure $configure_args; then
        handle_build_error $? "configure" "$name"
        return 1
    fi
    
    # 编译
    if ! make -j$(sysctl -n hw.ncpu); then
        handle_build_error $? "make" "$name"
        return 1
    fi
    
    # 安装
    if ! make install; then
        handle_build_error $? "install" "$name"
        return 1
    fi
    
    return 0
}

# 修改主函数，添加环境检查
main() {
    local keep_files=0
    
    # 解析命令行参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --keep-files)
                keep_files=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
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
    if ! create_universal_libraries; then
        log_error "Failed to create universal libraries"
        return 1
    fi
    
    log_info "Build completed successfully!"
    log_info "Libraries available at: $DEPS_ROOT/$LIB_NAME/install/universal/lib"
    log_info "Headers available at: $DEPS_ROOT/$LIB_NAME/install/universal/include"
    
    # 清理构建目录
    cleanup_build "$keep_files"
    
    return 0
}

# 运行脚本
main

build_mbedtls() {
    local platform="$1"
    local arch="$2"
    local install_dir="$3"
    local mbedtls_version="3.5.2"
    local mbedtls_dir="$BUILD_DIR/mbedtls-$mbedtls_version"
    local mbedtls_file="mbedtls-$mbedtls_version.tar.gz"
    
    log_info "Building mbedTLS for $platform ($arch)..."
    
    # 下载 mbedTLS
    if [ ! -f "$BUILD_DIR/$mbedtls_file" ]; then
        log_info "Downloading mbedTLS..."
        if ! curl -L "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v$mbedtls_version.tar.gz" -o "$BUILD_DIR/$mbedtls_file"; then
            log_error "Failed to download mbedTLS"
            return 1
        fi
    fi
    
    # 解压
    if [ ! -d "$mbedtls_dir" ]; then
        log_info "Extracting mbedTLS..."
        if ! tar -xzf "$BUILD_DIR/$mbedtls_file" -C "$BUILD_DIR"; then
            log_error "Failed to extract mbedTLS"
            return 1
        fi
    fi
    
    # 创建构建目录
    local build_dir="$mbedtls_dir/build-$platform-$arch"
    mkdir -p "$build_dir"
    cd "$build_dir" || return 1
    
    # 配置 CMake
    log_info "Configuring mbedTLS..."
    if [ "$platform" = "iphoneos" ]; then
        cmake -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/ios.toolchain.cmake" \
              -DPLATFORM=OS64 \
              -DENABLE_BITCODE=0 \
              -DENABLE_ARC=0 \
              -DENABLE_VISIBILITY=1 \
              -DDEPLOYMENT_TARGET="$IPHONEOS_DEPLOYMENT_TARGET" \
              -DCMAKE_INSTALL_PREFIX="$install_dir" \
              -DENABLE_PROGRAMS=OFF \
              -DENABLE_TESTING=OFF \
              -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
              -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
              -DCMAKE_BUILD_TYPE=Release \
              .. || return 1
    else
        cmake -DCMAKE_OSX_ARCHITECTURES="$arch" \
              -DCMAKE_INSTALL_PREFIX="$install_dir" \
              -DENABLE_PROGRAMS=OFF \
              -DENABLE_TESTING=OFF \
              -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
              -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
              -DCMAKE_BUILD_TYPE=Release \
              .. || return 1
    fi
    
    # 编译
    log_info "Building mbedTLS..."
    if ! make -j$(sysctl -n hw.ncpu); then
        log_error "Failed to build mbedTLS"
        return 1
    fi
    
    # 安装
    log_info "Installing mbedTLS..."
    if ! make install; then
        log_error "Failed to install mbedTLS"
        return 1
    fi
    
    return 0
}

# 在 build_dependencies 函数中添加 mbedTLS 构建
build_dependencies() {
    local platform="$1"
    local arch="$2"
    local install_dir="$3"
    
    # 构建 mbedTLS
    if ! build_mbedtls "$platform" "$arch" "$install_dir"; then
        log_error "Failed to build mbedTLS"
        return 1
    fi
    
    # ... 其他依赖项的构建 ...
    return 0
}

download_ios_toolchain() {
    local toolchain_file="$BUILD_DIR/ios.toolchain.cmake"
    
    if [ ! -f "$toolchain_file" ]; then
        log_info "Downloading iOS CMake toolchain..."
        if ! curl -L "https://raw.githubusercontent.com/leetal/ios-cmake/master/ios.toolchain.cmake" -o "$toolchain_file"; then
            log_error "Failed to download iOS CMake toolchain"
            return 1
        fi
    fi
    
    return 0
}

# 在 prepare_build_env 函数中添加工具链下载
prepare_build_env() {
    # 创建必要的目录
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # 下载 iOS CMake 工具链
    if ! download_ios_toolchain; then
        log_error "Failed to download iOS CMake toolchain"
        return 1
    fi
    
    return 0
}

verify_build_result() {
    local platform="$1"
    local install_dir="$2"
    
    log_info "Verifying build results for $platform..."
    
    # 检查静态库
    local required_libs=(
        "libshadowsocks-libev.a"
        "libmbedcrypto.a"
        "libmbedtls.a"
        "libmbedx509.a"
        "libpcre.a"
    )
    
    for lib in "${required_libs[@]}"; do
        if [ ! -f "$install_dir/lib/$lib" ]; then
            log_error "Missing library: $lib"
            return 1
        fi
    done
    
    # 检查头文件
    local required_headers=(
        "shadowsocks.h"
        "mbedtls/ssl.h"
        "pcre.h"
    )
    
    for header in "${required_headers[@]}"; do
        if [ ! -f "$install_dir/include/$header" ]; then
            log_error "Missing header: $header"
            return 1
        fi
    done
    
    # 检查库大小
    for lib in "${required_libs[@]}"; do
        local lib_size
        lib_size=$(stat -f%z "$install_dir/lib/$lib" 2>/dev/null)
        if [ -z "$lib_size" ] || [ "$lib_size" -lt 1000 ]; then
            log_error "Library $lib is too small or empty"
            return 1
        fi
    done
    
    log_info "Build verification completed successfully"
    return 0
}

cleanup_build() {
    local keep_files="$1"
    
    if [ "$keep_files" = "1" ]; then
        log_info "Keeping build files for debugging..."
        return 0
    fi
    
    log_info "Cleaning up build directory..."
    
    # 删除构建目录
    if [ -d "$BUILD_DIR" ]; then
        log_info "Removing build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi
    
    # 删除临时文件
    local temp_files=(
        "config.log"
        "config.status"
        "config.h"
        "Makefile"
        "stamp-h1"
        "libtool"
    )
    
    for file in "${temp_files[@]}"; do
        if [ -f "$file" ]; then
            log_info "Removing temporary file: $file"
            rm -f "$file"
        fi
    done
    
    # 删除自动生成的目录
    local temp_dirs=(
        "autom4te.cache"
        ".deps"
        ".libs"
    )
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Removing temporary directory: $dir"
            rm -rf "$dir"
        fi
    done
    
    log_info "Cleanup completed"
    return 0
}

generate_podspec() {
    local version="$1"
    local podspec_file="shadowsocks.podspec"
    
    log_info "Generating podspec file..."
    
    cat > "$podspec_file" << EOF
Pod::Spec.new do |s|
  s.name         = "shadowsocks-libev"
  s.version      = "$version"
  s.summary      = "Shadowsocks-libev is a lightweight secured SOCKS5 proxy."
  s.description  = <<-DESC
                   Shadowsocks-libev is a lightweight secured SOCKS5 proxy for embedded devices and low-end boxes.
                   It is a port of Shadowsocks created by @clowwindy maintained by @madeye and @linusyang.
                   DESC
  s.homepage     = "https://github.com/shadowsocks/shadowsocks-libev"
  s.license      = { :type => "GPLv3", :file => "LICENSE" }
  s.author       = { "Max Lv" => "max.c.lv@gmail.com" }
  s.source       = { :git => "https://github.com/shadowsocks/shadowsocks-libev.git", :tag => "v#{s.version}" }
  
  s.ios.deployment_target = "15.0"
  s.osx.deployment_target = "12.0"
  
  s.requires_arc = true
  s.static_framework = true
  
  s.ios.vendored_libraries = "install/ios/lib/*.a"
  s.osx.vendored_libraries = "install/macos/lib/*.a"
  
  s.source_files = "install/universal/include/**/*.h"
  s.public_header_files = "install/universal/include/**/*.h"
  
  s.libraries = "c++"
  s.frameworks = "Foundation", "Security"
  
  s.xcconfig = {
    "HEADER_SEARCH_PATHS" => "\${PODS_ROOT}/#{s.name}/include",
    "LIBRARY_SEARCH_PATHS" => "\${PODS_ROOT}/#{s.name}/lib",
    "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES" => "YES"
  }
  
  s.prepare_command = <<-CMD
                     mkdir -p \${PODS_ROOT}/#{s.name}
                     cp -R install/universal/include \${PODS_ROOT}/#{s.name}/
                     cp -R install/universal/lib \${PODS_ROOT}/#{s.name}/
                     CMD
end
EOF
    
    log_info "Podspec file generated: $podspec_file"
    return 0
}