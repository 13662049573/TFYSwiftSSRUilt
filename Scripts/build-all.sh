#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
LOG_DIR="$PROJECT_ROOT/build_logs"

# 创建必要的目录
mkdir -p "$PROJECT_ROOT/TFYSwiftSSRKit"
mkdir -p "$LOG_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 下载函数，支持多个镜像源
download_with_mirrors() {
    local url=$1
    local output=$2
    local max_retries=3
    local retry_count=0
    
    local mirrors=(
        "https://mirror.ghproxy.com/"
        "https://ghproxy.com/"
        ""  # 原始URL
    )
    
    for mirror in "${mirrors[@]}"; do
        local full_url="${mirror}${url}"
        log_info "Trying to download from: $full_url"
        if curl -L --http1.1 --retry 3 --retry-delay 2 --connect-timeout 30 \
            --progress-bar -o "$output" "$full_url" && [ -f "$output" ] && [ -s "$output" ]; then
            if file "$output" | grep -q "gzip compressed data"; then
                log_info "Successfully downloaded and verified $output"
                return 0
            else
                log_warning "Downloaded file is not a valid gzip archive"
                rm -f "$output"
            fi
        fi
        log_warning "Failed to download from $full_url"
    done
    log_error "All download attempts failed"
    return 1
}

# 导出所有函数和颜色变量
export RED GREEN YELLOW NC
export -f log_info log_error log_warning download_with_mirrors

# 构建单个库
build_library() {
    local script_name=$1
    local lib_name=$(echo $script_name | sed 's/build-//;s/.sh//')
    local log_file="$LOG_DIR/${lib_name}_build.log"
    
    # 确保脚本有执行权限
    chmod +x "$SCRIPT_DIR/$script_name"
    
    log_info "Building $lib_name..."
    
    # 创建一个临时脚本来导出函数
    local tmp_script=$(mktemp)
    declare -f download_with_mirrors log_info log_error log_warning > "$tmp_script"
    echo "export RED='$RED' GREEN='$GREEN' YELLOW='$YELLOW' NC='$NC'" >> "$tmp_script"
    echo "export CROSS_COMPILING=yes" >> "$tmp_script"
    echo "source \"$SCRIPT_DIR/$script_name\"" >> "$tmp_script"
    
    # 使用临时文件来捕获退出状态
    local exit_status_file=$(mktemp)
    (cd "$PROJECT_ROOT" && CROSS_COMPILING=yes bash "$tmp_script" 2>&1; echo $? > "$exit_status_file") | tee "$log_file"
    local exit_status=$(cat "$exit_status_file")
    rm -f "$exit_status_file"
    
    if [ "$exit_status" -eq 0 ]; then
        log_info "$lib_name build completed successfully"
        rm -f "$tmp_script"
        return 0
    else
        log_error "$lib_name build failed"
        log_error "Check $log_file for details"
        rm -f "$tmp_script"
        return 1
    fi
}

# 检查依赖工具
check_prerequisites() {
    local missing_tools=()
    
    for tool in autoconf automake libtool cmake perl; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "The following tools are required but not installed:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo "Install with: brew install ${missing_tools[@]}"
        exit 1
    fi
    
    # 检查 Xcode 命令行工具
    if ! xcode-select -p >/dev/null 2>&1; then
        log_error "Xcode Command Line Tools are not installed"
        echo "Install with: xcode-select --install"
        exit 1
    fi
}

# 清理函数
cleanup() {
    local clean_all=$1
    
    if [ "$clean_all" = true ]; then
        log_info "Cleaning all build artifacts..."
        rm -rf "$PROJECT_ROOT/TFYSwiftSSRKit/"{libsodium,libmaxminddb,openssl,shadowsocks-libev,antinat,privoxy}
        rm -rf "$LOG_DIR"
    else
        log_info "Cleaning build logs..."
        rm -rf "$LOG_DIR"
    fi
    
    # 重新创建目录
    mkdir -p "$PROJECT_ROOT/TFYSwiftSSRKit"
    mkdir -p "$LOG_DIR"
}

# 显示帮助
show_help() {
    cat << EOF
Usage: $0 [options]

Options:
    --clean         Clean build logs before building
    --clean-all    Clean all build artifacts and logs before building
    --help         Show this help message
    
Example:
    $0              # Build all libraries
    $0 --clean     # Clean logs and build
    $0 --clean-all # Clean everything and build
EOF
}

# 主函数
main() {
    local start_time=$(date +%s)
    local clean_all=false
    local failed_builds=()
    
    # 检查是否有参数
    if [ $# -gt 0 ]; then
        case "$1" in
            --clean)
                cleanup false
                ;;
            --clean-all)
                cleanup true
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    fi
    
    # 检查依赖工具
    check_prerequisites
    
    # 构建所有库
    local build_scripts=(
        "build-libsodium.sh"
        "build-libmaxminddb.sh"
        "build-openssl.sh"
        "build-shadowsocks.sh"
        "build-antinat.sh"
        "build-privoxy.sh"
    )
    
    for script in "${build_scripts[@]}"; do
        log_info "Starting build of $script..."
        if ! build_library "$script"; then
            failed_builds+=("$script")
            log_error "Build of $script failed"
            # 如果是依赖库失败，就停止构建
            case "$script" in
                "build-libsodium.sh"|"build-openssl.sh")
                    log_error "Critical dependency failed, stopping build process"
                    break
                    ;;
            esac
        fi
    done
    
    # 计算构建时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    log_info "Build completed in ${hours}h ${minutes}m ${seconds}s"
    
    if [ ${#failed_builds[@]} -eq 0 ]; then
        log_info "All libraries built successfully"
        return 0
    else
        log_error "The following builds failed:"
        for script in "${failed_builds[@]}"; do
            local lib_name=$(echo $script | sed 's/build-//;s/.sh//')
            echo "  - $lib_name"
        done
        return 1
    fi
}

# 设置错误处理
trap 'echo "Error on line $LINENO"' ERR

# 运行脚本
main "$@" 