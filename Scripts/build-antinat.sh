#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit/shadowsocks-libev"
VERSION="0.90"
LIB_NAME="antinat"
REPO_URL="https://github.com/m3l3m01t/antinat.git"

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
    exit 1
}

trap 'handle_error $LINENO' ERR

# 检查命令执行状态
check_status() {
    if [ $? -ne 0 ]; then
        log_error "$1 failed"
        exit 1
    fi
}

# 修复源代码问题
fix_source_code() {
    local REPO_DIR="$1"
    
    # 修复 an_internals.h 中的类型定义
    log_info "Fixing type definitions in an_internals.h..."
    sed -i '' 's/typedef SOCKADDR_IN PI_SA;/typedef SOCKADDR_IN PI_SA;\ntypedef int sl_t;/' "$REPO_DIR/client/an_internals.h"
    
    # 修复 an_core.c 中的 pthread 问题
    log_info "Fixing pthread issues in an_core.c..."
    sed -i '' 's/pthread_mutex_t gethostbyname_lock = PTHREAD_MUTEX_INITIALIZER;/pthread_mutex_t gethostbyname_lock;/' "$REPO_DIR/client/an_core.c"
    sed -i '' 's/pthread_mutex_lock (&gethostbyname_lock);/\/\* pthread_mutex_lock (&gethostbyname_lock); \*\//' "$REPO_DIR/client/an_core.c"
    sed -i '' 's/pthread_mutex_unlock (&gethostbyname_lock);/\/\* pthread_mutex_unlock (&gethostbyname_lock); \*\//' "$REPO_DIR/client/an_core.c"
    
    # 修复 an_ssl.c 中缺少 stdio.h 的问题
    log_info "Fixing missing stdio.h in an_ssl.c..."
    sed -i '' '1s/^/#include <stdio.h>\n/' "$REPO_DIR/client/an_ssl.c"
}

# 编译客户端源文件
build_client() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local REPO_DIR="$BUILD_DIR/repo"
    
    # 创建目录
    mkdir -p "$BUILD_DIR/ios/obj"
    mkdir -p "$BUILD_DIR/macos/obj"
    mkdir -p "$INSTALL_DIR/ios/include/antinat"
    mkdir -p "$INSTALL_DIR/ios/lib"
    mkdir -p "$INSTALL_DIR/macos/include/antinat"
    mkdir -p "$INSTALL_DIR/macos/lib"
    
    # 创建临时的 config.h 文件
    cat > "$REPO_DIR/config.h" << EOF
/* Manually created config.h for iOS/macOS build */
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_SOCKET_H 1
#define HAVE_NETDB_H 1
#define HAVE_NETINET_IN_H 1
#define HAVE_FCNTL_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_ERRNO_H 1
#define HAVE_SYS_SELECT_H 1
#define HAVE_MEMMOVE 1
#define STDC_HEADERS 1
#define HAVE_PTHREAD_H 1
#define HAVE_STDIO_H 1
EOF
    
    # 复制头文件
    cp -f "$REPO_DIR/client/antinat.h" "$INSTALL_DIR/ios/include/"
    cp -f "$REPO_DIR/client/antinat.h" "$INSTALL_DIR/ios/include/antinat/"
    cp -f "$REPO_DIR/client/an_core.h" "$INSTALL_DIR/ios/include/antinat/"
    
    cp -f "$REPO_DIR/client/antinat.h" "$INSTALL_DIR/macos/include/"
    cp -f "$REPO_DIR/client/antinat.h" "$INSTALL_DIR/macos/include/antinat/"
    cp -f "$REPO_DIR/client/an_core.h" "$INSTALL_DIR/macos/include/antinat/"
    
    # 定义所有客户端源文件
    CLIENT_SOURCES=(
        "$REPO_DIR/client/an_core.c"
        "$REPO_DIR/client/an_proxy.c"
        "$REPO_DIR/client/an_direct.c"
        "$REPO_DIR/client/an_socks4.c"
        "$REPO_DIR/client/an_socks5.c"
        "$REPO_DIR/client/an_ssl.c"
        "$REPO_DIR/client/iscmd5.c"
    )
    
    # 编译 iOS 版本
    log_info "Compiling for iOS..."
    export CC="$(xcrun -find -sdk iphoneos clang)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk iphoneos --show-sdk-path) -mios-version-min=$IPHONEOS_DEPLOYMENT_TARGET -fembed-bitcode -I$REPO_DIR -I$REPO_DIR/client -I$REPO_DIR/expat -D_GNU_SOURCE=1 -D_REENTRANT=1 -DHAVE_CONFIG_H -DWRAP_GETHOSTBYNAME=0"
    
    # 编译客户端源文件
    for SRC in "${CLIENT_SOURCES[@]}"; do
        FILENAME=$(basename "$SRC")
        OBJNAME="${FILENAME%.c}.o"
        log_info "Compiling $FILENAME for iOS..."
        $CC $CFLAGS -c "$SRC" -o "$BUILD_DIR/ios/obj/$OBJNAME"
        if [ $? -ne 0 ]; then
            log_error "Failed to compile $FILENAME for iOS"
            exit 1
        fi
    done
    
    # 创建静态库
    log_info "Creating iOS static library..."
    ar rcs "$INSTALL_DIR/ios/lib/libantinat.a" "$BUILD_DIR/ios/obj/"*.o
    check_status "iOS library creation"
    
    # 编译 macOS 版本
    log_info "Compiling for macOS..."
    export CC="$(xcrun -find -sdk macosx clang)"
    export CFLAGS="-arch arm64 -isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET -I$REPO_DIR -I$REPO_DIR/client -I$REPO_DIR/expat -D_GNU_SOURCE=1 -D_REENTRANT=1 -DHAVE_CONFIG_H -DWRAP_GETHOSTBYNAME=0"
    
    # 编译客户端源文件
    for SRC in "${CLIENT_SOURCES[@]}"; do
        FILENAME=$(basename "$SRC")
        OBJNAME="${FILENAME%.c}.o"
        log_info "Compiling $FILENAME for macOS..."
        $CC $CFLAGS -c "$SRC" -o "$BUILD_DIR/macos/obj/$OBJNAME"
        if [ $? -ne 0 ]; then
            log_error "Failed to compile $FILENAME for macOS"
            exit 1
        fi
    done
    
    # 创建静态库
    log_info "Creating macOS static library..."
    ar rcs "$INSTALL_DIR/macos/lib/libantinat.a" "$BUILD_DIR/macos/obj/"*.o
    check_status "macOS library creation"
    
    return 0
}

# 构建 antinat
build_antinat() {
    local BUILD_DIR="$DEPS_ROOT/$LIB_NAME/build"
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME/install"
    local REPO_DIR="$BUILD_DIR/repo"
    
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR/ios/include"
    mkdir -p "$INSTALL_DIR/ios/lib"
    mkdir -p "$INSTALL_DIR/macos/include"
    mkdir -p "$INSTALL_DIR/macos/lib"
    
    # 克隆仓库
    log_info "Cloning antinat repository..."
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
    check_status "Repository cloning"
    
    cd "$REPO_DIR"
    
    # 检查源代码是否存在
    if [ ! -d "client" ]; then
        log_error "Client directory not found in repository"
        exit 1
    fi
    
    # 检查必要的源文件
    for file in antinat.h an_core.h an_core.c an_proxy.c an_direct.c an_socks4.c an_socks5.c an_ssl.c iscmd5.c; do
        if [ ! -f "client/$file" ]; then
            log_error "Required file client/$file not found"
            exit 1
        fi
    done
    
    log_info "Source code verification completed"
    
    # 修复源代码问题
    fix_source_code "$REPO_DIR"
    
    # 编译客户端
    build_client
    check_status "Client build"
    
    # 创建最终的库文件结构
    create_final_library
    
    return 0
}

# 创建最终的库文件结构
create_final_library() {
    local INSTALL_DIR="$DEPS_ROOT/$LIB_NAME"
    local BUILD_DIR="$INSTALL_DIR/install"
    
    # 确保目录存在
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/include"
    mkdir -p "$INSTALL_DIR/include/antinat"
    
    # 复制iOS库
    if [ -f "$BUILD_DIR/ios/lib/libantinat.a" ]; then
        cp "$BUILD_DIR/ios/lib/libantinat.a" "$INSTALL_DIR/lib/libantinat_ios.a"
        check_status "Copying iOS library"
    else
        log_error "iOS library not found, build failed"
        exit 1
    fi
    
    # 复制macOS库
    if [ -f "$BUILD_DIR/macos/lib/libantinat.a" ]; then
        cp "$BUILD_DIR/macos/lib/libantinat.a" "$INSTALL_DIR/lib/libantinat_macos.a"
        check_status "Copying macOS library"
    else
        log_error "macOS library not found, build failed"
        exit 1
    fi
    
    # 创建通用库
    if [ -f "$INSTALL_DIR/lib/libantinat_ios.a" ] && [ -f "$INSTALL_DIR/lib/libantinat_macos.a" ]; then
        cp "$INSTALL_DIR/lib/libantinat_ios.a" "$INSTALL_DIR/lib/libantinat.a"
        check_status "Creating universal library"
    else
        log_error "Could not create universal library"
        exit 1
    fi
    
    # 复制头文件
    if [ -f "$BUILD_DIR/ios/include/antinat.h" ]; then
        cp "$BUILD_DIR/ios/include/antinat.h" "$INSTALL_DIR/include/"
        cp "$BUILD_DIR/ios/include/antinat/antinat.h" "$INSTALL_DIR/include/antinat/"
        
        # 复制其他头文件
        if [ -f "$BUILD_DIR/ios/include/antinat/an_core.h" ]; then
            cp "$BUILD_DIR/ios/include/antinat/an_core.h" "$INSTALL_DIR/include/antinat/"
        fi
        check_status "Copying header files"
    else
        log_error "Header files not found, build failed"
        exit 1
    fi
    
    # 验证库
    log_info "Verifying libraries..."
    if [ -f "$INSTALL_DIR/lib/libantinat_ios.a" ]; then
        xcrun lipo -info "$INSTALL_DIR/lib/libantinat_ios.a" || { log_error "Could not get info for iOS library"; exit 1; }
    else
        log_error "iOS library not found"
        exit 1
    fi
    
    if [ -f "$INSTALL_DIR/lib/libantinat_macos.a" ]; then
        xcrun lipo -info "$INSTALL_DIR/lib/libantinat_macos.a" || { log_error "Could not get info for macOS library"; exit 1; }
    else
        log_error "macOS library not found"
        exit 1
    fi
    
    if [ -f "$INSTALL_DIR/lib/libantinat.a" ]; then
        xcrun lipo -info "$INSTALL_DIR/lib/libantinat.a" || { log_error "Could not get info for universal library"; exit 1; }
    else
        log_error "Universal library not found"
        exit 1
    fi
}

# 主函数
main() {
    # 检查必要工具
    local REQUIRED_TOOLS="git"
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
    
    # 构建 antinat
    if build_antinat; then
        log_info "AntiNAT build completed successfully!"
        log_info "Libraries available at: $DEPS_ROOT/$LIB_NAME/lib"
        log_info "Headers available at: $DEPS_ROOT/$LIB_NAME/include"
        return 0
    else
        log_error "Build failed"
        exit 1
    fi
}

# 运行脚本
main
