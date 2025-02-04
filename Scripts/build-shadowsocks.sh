#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit/shadowsocks"
VERSION="v1.22.0"
DOWNLOAD_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/$VERSION/shadowsocks-$VERSION.aarch64-apple-darwin.tar.xz"
ARCHIVE_NAME="shadowsocks-$VERSION.aarch64-apple-darwin.tar.xz"

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

# 清理函数
cleanup() {
    if [ "$1" = "success" ]; then
        log_info "Cleaning up build files after successful build..."
        rm -rf "$DEPS_ROOT/build"
    else
        log_info "Keeping build files for debugging..."
    fi
}

# 构建 shadowsocks-rust
build_shadowsocks() {
    local BUILD_DIR="$DEPS_ROOT/build"
    local INSTALL_DIR="$DEPS_ROOT/install"
    
    log_info "Building shadowsocks-rust $VERSION..."
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
    cd "$BUILD_DIR"
    
    # 下载预编译的二进制文件
    log_info "Downloading pre-built binaries..."
    if ! curl -L --http1.1 -o "$ARCHIVE_NAME" "$DOWNLOAD_URL"; then
        log_error "Failed to download shadowsocks-rust binary"
        return 1
    fi
    
    # 检查文件是否存在和大小是否正确
    if [ ! -f "$ARCHIVE_NAME" ] || [ ! -s "$ARCHIVE_NAME" ]; then
        log_error "Downloaded file is missing or empty"
        return 1
    fi
    
    # 解压文件
    log_info "Extracting archive..."
    if ! tar xf "$ARCHIVE_NAME"; then
        log_error "Failed to extract archive"
        return 1
    fi
    
    # 创建输出目录
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/include"
    
    # 复制文件
    log_info "Installing files..."
    for binary in sslocal ssserver ssurl ssmanager; do
        if [ -f "$binary" ]; then
            cp "$binary" "$INSTALL_DIR/bin/" || {
                log_error "Failed to copy $binary"
                return 1
            }
        else
            log_error "Binary $binary not found in archive"
            return 1
        fi
    done
    
    # 设置权限
    chmod +x "$INSTALL_DIR/bin/"* || {
        log_error "Failed to set executable permissions"
        return 1
    }
    
    # 生成简单的 C 头文件
    log_info "Generating header file..."
    cat > "$INSTALL_DIR/include/shadowsocks.h" << 'EOF'
#ifndef SHADOWSOCKS_H
#define SHADOWSOCKS_H

#ifdef __cplusplus
extern "C" {
#endif

// Shadowsocks configuration structure
typedef struct {
    const char* server;
    const char* server_port;
    const char* password;
    const char* method;
    const char* local_address;
    const char* local_port;
} shadowsocks_config;

#ifdef __cplusplus
}
#endif

#endif // SHADOWSOCKS_H
EOF
    
    log_info "Installation completed successfully"
    log_info "Binaries installed to: $INSTALL_DIR/bin"
    log_info "Header file installed to: $INSTALL_DIR/include"
    
    return 0
}

# 主函数
main() {
    # 检查必要工具
    local REQUIRED_TOOLS="curl tar"
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
    if build_shadowsocks; then
        cleanup success
        log_info "Build completed successfully!"
        log_info "Binaries available at: $DEPS_ROOT/install/bin"
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