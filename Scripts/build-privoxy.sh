#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit"
VERSION="3.0.34"
LIB_NAME="privoxy"
PCRE_VERSION="8.45"

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

# 构建 PCRE
build_pcre() {
    local BUILD_DIR="$DEPS_ROOT/pcre/build"
    local INSTALL_DIR="$DEPS_ROOT/pcre/install"
    local DOWNLOAD_URL="https://sourceforge.net/projects/pcre/files/pcre/$PCRE_VERSION/pcre-$PCRE_VERSION.tar.gz/download"
    local ARCHIVE="$BUILD_DIR/pcre.tar.gz"
    
    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$BUILD_DIR"
    
    # 下载 PCRE
    log_info "Downloading PCRE..."
    if ! curl -L --retry 3 --retry-delay 2 -o "$ARCHIVE" "$DOWNLOAD_URL"; then
        log_error "Failed to download PCRE"
        return 1
    fi
    
    # 解压 PCRE
    log_info "Extracting PCRE..."
    if ! tar xzf "$ARCHIVE"; then
        log_error "Failed to extract PCRE"
        return 1
    fi
    
    cd "pcre-$PCRE_VERSION"
    
    # iOS 构建
    log_info "Building PCRE for iOS..."
    
    # 设置交叉编译环境变量
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CXX="$(xcrun -find -sdk iphoneos clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
    export CROSS_COMPILE="arm-apple-darwin"
    
    # 设置交叉编译缓存变量
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap_fixed_mapped=yes
    export ac_cv_file__dev_zero=no
    export ac_cv_file__dev_random=yes
    export ac_cv_prog_cc_g=no
    export ac_cv_c_bigendian=no
    export ac_cv_sizeof_long=8
    export ac_cv_sizeof_size_t=8
    export ac_cv_sizeof_void_p=8
    export ac_cv_type_long_long=yes
    export ac_cv_type_unsigned_long_long=yes
    
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
                || return 1
    
    make clean || true
    make -j$(sysctl -n hw.ncpu) || return 1
    make install || return 1
    
    # 验证构建结果
    if [ ! -f "$INSTALL_DIR/ios/lib/libpcre.a" ]; then
        log_error "Failed to build PCRE: libpcre.a not found"
        return 1
    fi
    
    return 0
}

# 构建 Privoxy
build_privoxy() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local DOWNLOAD_URL="https://sourceforge.net/projects/ijbswa/files/Sources/$VERSION%20%28stable%29/privoxy-$VERSION-stable-src.tar.gz/download"
    local ARCHIVE="$BUILD_DIR/privoxy.tar.gz"
    
    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$BUILD_DIR"
    
    # 下载源码
    log_info "Downloading privoxy..."
    if ! curl -L --retry 3 --retry-delay 2 -o "$ARCHIVE" "$DOWNLOAD_URL"; then
        log_error "Failed to download privoxy"
        return 1
    fi
    
    # 解压源码
    log_info "Extracting privoxy..."
    if ! tar xzf "$ARCHIVE"; then
        log_error "Failed to extract privoxy"
        return 1
    fi
    
    cd "privoxy-$VERSION-stable"
    
    # 检查 PCRE 库
    if [ ! -f "$DEPS_ROOT/pcre/install/ios/lib/libpcre.a" ]; then
        log_error "PCRE library not found at $DEPS_ROOT/pcre/install/ios/lib/libpcre.a"
        return 1
    fi
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CXX="$(xcrun -find -sdk iphoneos clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -I$DEPS_ROOT/pcre/install/ios/include"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -L$DEPS_ROOT/pcre/install/ios/lib"
    export LIBS="-lpcre -lpcreposix"
    export PKG_CONFIG_PATH="$DEPS_ROOT/pcre/install/ios/lib/pkgconfig"
    export PCRE_CONFIG="$DEPS_ROOT/pcre/install/ios/bin/pcre-config"
    
    # 运行自动工具链
    autoreconf -fiv
    
    ./configure --prefix="$INSTALL_DIR/ios" \
                --host=arm-apple-darwin \
                --target=arm-apple-darwin \
                --build="$(./config.guess)" \
                --enable-static-linking \
                --disable-pthread \
                --disable-editor \
                --disable-toggle \
                --disable-force \
                --disable-trust-files \
                --disable-graceful-termination \
                --disable-compression \
                --disable-client-tags \
                --disable-accept-filter \
                --disable-external-filters \
                --with-pcre="$DEPS_ROOT/pcre/install/ios" \
                || (log_error "iOS configure failed" && return 1)
    
    make clean || true
    make -j$(sysctl -n hw.ncpu) || (log_error "iOS make failed" && return 1)
    make install || (log_error "iOS make install failed" && return 1)
    
    # macOS 构建
    for ARCH in $MACOS_ARCHS; do
        log_info "Building for macOS architecture: $ARCH"
        
        export CC="$(xcrun -find -sdk macosx clang)"
        export CXX="$(xcrun -find -sdk macosx clang++)"
        export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET -I$DEPS_ROOT/pcre/install/macos/include"
        export CXXFLAGS="$CFLAGS"
        export LDFLAGS="-arch $ARCH -isysroot $(xcrun -sdk macosx --show-sdk-path) -L$DEPS_ROOT/pcre/install/macos/lib"
        export LIBS="-lpcre -lpcreposix"
        export PKG_CONFIG_PATH="$DEPS_ROOT/pcre/install/macos/lib/pkgconfig"
        export PCRE_CONFIG="$DEPS_ROOT/pcre/install/macos/bin/pcre-config"
        
        local HOST_ARCH
        if [ "$ARCH" = "arm64" ]; then
            HOST_ARCH="aarch64-apple-darwin"
        else
            HOST_ARCH="x86_64-apple-darwin"
        fi
        
        ./configure --prefix="$INSTALL_DIR/macos/$ARCH" \
                    --host="$HOST_ARCH" \
                    --target="$HOST_ARCH" \
                    --build="$(./config.guess)" \
                    --enable-static-linking \
                    --disable-pthread \
                    --disable-editor \
                    --disable-toggle \
                    --disable-force \
                    --disable-trust-files \
                    --disable-graceful-termination \
                    --disable-compression \
                    --disable-client-tags \
                    --disable-accept-filter \
                    --disable-external-filters \
                    --with-pcre="$DEPS_ROOT/pcre/install/macos" \
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
    cp "$INSTALL_DIR/ios/lib/libprivoxy.a" "$INSTALL_DIR/lib/libprivoxy_ios.a"
    
    # macOS 通用库
    xcrun lipo -create \
        "$INSTALL_DIR/macos/arm64/lib/libprivoxy.a" \
        "$INSTALL_DIR/macos/x86_64/lib/libprivoxy.a" \
        -output "$INSTALL_DIR/lib/libprivoxy_macos.a"
    
    # 复制头文件
    cp -R "$INSTALL_DIR/ios/include" "$INSTALL_DIR/"
    
    # 验证库
    xcrun lipo -info "$INSTALL_DIR/lib/libprivoxy_ios.a"
    xcrun lipo -info "$INSTALL_DIR/lib/libprivoxy_macos.a"
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
    
    # 先构建 PCRE
    log_info "Building PCRE..."
    if ! build_pcre; then
        log_error "Failed to build PCRE"
        exit 1
    fi
    
    # 构建 Privoxy
    if build_privoxy && create_universal_library; then
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