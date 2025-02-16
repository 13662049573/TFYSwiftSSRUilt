#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# 错误处理
handle_error() {
    log_error "构建过程中发生错误!"
    log_error "错误发生在: $1"
    log_error "错误行号: $2"
    exit 1
}

trap 'handle_error "${BASH_SOURCE[0]}" $LINENO' ERR

# 检查构建环境
check_build_env() {
    log_info "检查构建环境..."
    
    # 检查 Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        log_error "未安装 Xcode Command Line Tools"
        log_info "请运行: xcode-select --install"
        return 1
    fi
    
    # 检查必要的工具
    local tools=(
        "curl" "tar" "git" "make" "cmake" 
        "autoconf" "automake" "libtool" "pkg-config"
    )
    
    local missing_tools=()
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要的工具: ${missing_tools[*]}"
        log_info "请使用 brew install 安装缺失的工具"
        return 1
    fi
    
    log_success "构建环境检查通过"
    return 0
}

# 清理函数
clean_build() {
    log_info "清理旧的构建文件..."
    
    # 清理各个库的构建目录
    local libs=(
        "libev" "libmaxminddb" "libsodium" "mbedtls" 
        "openssl" "pcre" "c-ares" "shadowsocks-libev"
    )
    
    for lib in "${libs[@]}"; do
        if [ -d "${DEPS_ROOT}/${lib}/build" ]; then
            rm -rf "${DEPS_ROOT}/${lib}/build"
        fi
    done
    
    log_success "清理完成"
}

# 验证构建结果
verify_build() {
    log_info "验证构建结果..."
    
    # 检查所有必要的库文件
    local required_libs=(
        "libev/lib/libev_ios.a"
        "libev/lib/libev_macos.a"
        "libmaxminddb/lib/libmaxminddb_ios.a"
        "libmaxminddb/lib/libmaxminddb_macos.a"
        "libsodium/lib/libsodium_ios.a"
        "libsodium/lib/libsodium_macos.a"
        "mbedtls/lib/libmbedcrypto_ios.a"
        "mbedtls/lib/libmbedcrypto_macos.a"
        "mbedtls/lib/libmbedtls_ios.a"
        "mbedtls/lib/libmbedtls_macos.a"
        "mbedtls/lib/libmbedx509_ios.a"
        "mbedtls/lib/libmbedx509_macos.a"
        "openssl/lib/libssl_ios.a"
        "openssl/lib/libssl_macos.a"
        "openssl/lib/libcrypto_ios.a"
        "openssl/lib/libcrypto_macos.a"
        "pcre/lib/libpcre_ios.a"
        "pcre/lib/libpcre_macos.a"
        "c-ares/lib/libcares_ios.a"
        "c-ares/lib/libcares_macos.a"
    )
    
    local missing_libs=()
    for lib in "${required_libs[@]}"; do
        if [ ! -f "${DEPS_ROOT}/${lib}" ]; then
            missing_libs+=("${lib}")
        fi
    done
    
    if [ ${#missing_libs[@]} -ne 0 ]; then
        log_error "以下库文件缺失:"
        for lib in "${missing_libs[@]}"; do
            log_error "  - ${lib}"
        done
        return 1
    fi
    
    log_success "所有必要的库文件验证通过"
    return 0
}

# 主构建流程
main() {
    log_info "开始构建流程..."
    
    # 检查构建环境
    check_build_env || exit 1
    
    # 清理旧的构建文件
    clean_build
    
    # 按顺序构建各个依赖库
    log_info "构建 libev..."
    "${SCRIPT_DIR}/build-libev.sh" || exit 1
    log_success "libev 构建完成"
    
    log_info "构建 libmaxminddb..."
    "${SCRIPT_DIR}/build-libmaxminddb.sh" || exit 1
    log_success "libmaxminddb 构建完成"
    
    log_info "构建 libsodium..."
    "${SCRIPT_DIR}/build-libsodium.sh" || exit 1
    log_success "libsodium 构建完成"
    
    log_info "构建 mbedtls..."
    "${SCRIPT_DIR}/build-mbedtls.sh" || exit 1
    log_success "mbedtls 构建完成"
    
    log_info "构建 openssl..."
    "${SCRIPT_DIR}/build-openssl.sh" || exit 1
    log_success "openssl 构建完成"
    
    log_info "构建 pcre..."
    "${SCRIPT_DIR}/build-pcre.sh" || exit 1
    log_success "pcre 构建完成"
    
    log_info "构建 c-ares..."
    "${SCRIPT_DIR}/build-c-ares.sh" || exit 1
    log_success "c-ares 构建完成"
    
    log_info "构建 shadowsocks-libev..."
    "${SCRIPT_DIR}/build-shadowsocks-libev.sh" || exit 1
    log_success "shadowsocks-libev 构建完成"
    
    # 验证构建结果
    verify_build || exit 1
    
    log_success "所有组件构建完成!"
    return 0
}

# 执行主函数
main 