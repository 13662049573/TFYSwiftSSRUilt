#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
DEPS_ROOT="$PROJECT_ROOT/TFYSwiftSSRKit/shadowsocks"
FRAMEWORK_RESOURCES="$PROJECT_ROOT/TFYSwiftSSRKit/Resources"

# 日志函数
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

# 错误处理
handle_error() {
    log_error "An error occurred on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# 主函数
main() {
    # 创建资源目录
    mkdir -p "$FRAMEWORK_RESOURCES"
    
    # 复制二进制文件
    log_info "Copying binary files..."
    cp "$DEPS_ROOT/install/bin/sslocal" "$FRAMEWORK_RESOURCES/"
    cp "$DEPS_ROOT/install/bin/ssserver" "$FRAMEWORK_RESOURCES/"
    cp "$DEPS_ROOT/install/bin/ssurl" "$FRAMEWORK_RESOURCES/"
    cp "$DEPS_ROOT/install/bin/ssmanager" "$FRAMEWORK_RESOURCES/"
    
    # 设置权限
    chmod +x "$FRAMEWORK_RESOURCES/"*
    
    log_info "Binary files copied successfully to: $FRAMEWORK_RESOURCES"
    return 0
}

# 运行脚本
main 