#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit/libmaxminddb"
VERSION="1.7.1"
LIB_NAME="libmaxminddb"

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
build_libmaxminddb() {
    local BUILD_DIR="$DEPS_ROOT/build"
    local INSTALL_DIR="$DEPS_ROOT/install"
    
    log_info "Building $LIB_NAME version $VERSION..."
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
    cd "$BUILD_DIR"
    
    # 下载源码
    if [ ! -f "${LIB_NAME}.tar.gz" ]; then
        log_info "Downloading $LIB_NAME..."
        local DOWNLOAD_URL="https://github.com/maxmind/libmaxminddb/releases/download/${VERSION}/libmaxminddb-${VERSION}.tar.gz"
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
    
    # 运行 autoreconf
    log_info "Running autoreconf..."
    if ! autoreconf -fi; then
        log_error "autoreconf failed"
        return 1
    fi
    
    # 通用配置选项
    local COMMON_CONFIG_OPTS="--enable-static \
                            --disable-shared \
                            --disable-dependency-tracking \
                            --disable-tests \
                            --disable-binaries"
    
    # iOS 构建
    log_info "Building for iOS (arm64)..."
    
    # 设置 iOS 编译环境
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CXX="$(xcrun -find -sdk iphoneos clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"
    
    # 预设配置检查结果
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap=yes
    export ac_cv_func_munmap=yes
    export ac_cv_type_ssize_t=yes
    export ac_cv_type_size_t=yes
    export ac_cv_func_memset=yes
    export ac_cv_func_strdup=yes
    
    if ! ./configure --prefix="$INSTALL_DIR/ios" \
                    --host="arm-apple-darwin" \
                    --build="$(./config.guess)" \
                    $COMMON_CONFIG_OPTS; then
        log_error "iOS configure failed"
        return 1
    fi
    
    make clean
    if ! make -j$(sysctl -n hw.ncpu); then
        log_error "iOS make failed"
        return 1
    fi
    
    if ! make install; then
        log_error "iOS make install failed"
        return 1
    fi
    
    # macOS 构建
    log_info "Building for macOS..."
    
    # 设置 macOS 编译环境
    export CC="$(xcrun -find -sdk macosx clang)"
    export CXX="$(xcrun -find -sdk macosx clang++)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -isysroot $(xcrun -sdk macosx --show-sdk-path)"
    
    if ! ./configure --prefix="$INSTALL_DIR/macos" \
                    --host="aarch64-apple-darwin" \
                    --build="$(./config.guess)" \
                    $COMMON_CONFIG_OPTS; then
        log_error "macOS configure failed"
        return 1
    fi
    
    make clean
    if ! make -j$(sysctl -n hw.ncpu); then
        log_error "macOS make failed"
        return 1
    fi
    
    if ! make install; then
        log_error "macOS make install failed"
        return 1
    fi
    
    return 0
}

# 创建最终库文件
create_final_libraries() {
    local INSTALL_DIR="$DEPS_ROOT"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/include"
    
    log_info "Creating final libraries..."
    
    # iOS 库
    log_info "Creating iOS library..."
    if ! cp "$INSTALL_DIR/install/ios/lib/libmaxminddb.a" "$INSTALL_DIR/lib/libmaxminddb_ios.a"; then
        log_error "Failed to create iOS library"
        return 1
    fi
    
    # macOS 库
    log_info "Creating macOS library..."
    if ! cp "$INSTALL_DIR/install/macos/lib/libmaxminddb.a" "$INSTALL_DIR/lib/libmaxminddb_macos.a"; then
        log_error "Failed to create macOS library"
        return 1
    fi
    
    # 复制头文件
    log_info "Copying headers..."
    if ! cp -R "$INSTALL_DIR/install/ios/include/." "$INSTALL_DIR/include/"; then
        log_error "Failed to copy headers"
        return 1
    fi
    
    # 验证生成的库
    log_info "Verifying libraries..."
    if [ ! -f "$INSTALL_DIR/lib/libmaxminddb_ios.a" ] || [ ! -f "$INSTALL_DIR/lib/libmaxminddb_macos.a" ]; then
        log_error "Library verification failed"
        return 1
    fi
    
    # 显示库信息
    log_info "iOS library info:"
    xcrun lipo -info "$INSTALL_DIR/lib/libmaxminddb_ios.a"
    
    log_info "macOS library info:"
    xcrun lipo -info "$INSTALL_DIR/lib/libmaxminddb_macos.a"
    
    return 0
}

# 主函数
main() {
    # 检查必要工具
    local REQUIRED_TOOLS="autoconf automake libtool"
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
    if build_libmaxminddb && create_final_libraries; then
        cleanup "success"
        log_info "Build completed successfully!"
        log_info "Libraries available at: $DEPS_ROOT/lib"
        log_info "Headers available at: $DEPS_ROOT/include"
        return 0
    else
        log_error "Build failed"
        cleanup
        return 1
    fi
}

# 运行脚本
main 