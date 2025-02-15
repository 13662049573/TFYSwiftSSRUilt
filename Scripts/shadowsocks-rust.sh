#!/bin/bash
# 网络优化版编译脚本

# 核心配置参数
PROJECT_ROOT="/Users/tianfengyou/Desktop/自己库/TFYSwiftSSRUilt/TFYSwiftSSRKit/shadowsocks-rust"
CARGO_TOML="${PROJECT_ROOT}/Cargo.toml"
TARGET_DIR="${PROJECT_ROOT}/target"

# 设置镜像源
export RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rust-static"
export RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rust-static/rustup"
export CARGO_HTTP_MULTIPLEXING=false
export CARGO_NET_RETRY=10

# 初始化环境
init_env() {
    echo "🔧 初始化环境..."
    
    # 配置Cargo镜像
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml <<EOF
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"

[net]
git-fetch-with-cli = true
retry = 10
EOF

    # 安装必要工具链
    rustup target add aarch64-apple-ios x86_64-apple-darwin
    rustup component add rust-src
    cargo install cargo-lipo --force --index https://mirrors.ustc.edu.cn/crates.io-index/
}

# 生成Cargo配置
init_project() {
    echo "🛠️ 初始化项目结构到：${PROJECT_ROOT}"
    mkdir -p "${PROJECT_ROOT}"
    cd "${PROJECT_ROOT}"  # 关键路径修正
    
    # 确保在正确目录执行命令
    if [ ! -f "Cargo.toml" ]; then
        mkdir -p "${PROJECT_ROOT}/"{src,include,scripts,build}
        
        cat > "${CARGO_TOML}" <<EOF
[package]
name = "shadowsocks-rust"
version = "1.22.0"
edition = "2021"
authors = ["TFYSwiftSSRKit"]
description = "Shadowsocks Rust implementation for iOS/macOS"

[lib]
name = "ss"
crate-type = ["staticlib"]

[dependencies]
shadowsocks = { version = "1.22.0", features = ["stream-cipher", "local"] }
libc = { version = "0.2.155", features = ["extra_traits"] }
EOF

        # 生成基础Rust代码
        cat > "${PROJECT_ROOT}/src/lib.rs" <<EOF
#[no_mangle]
pub extern "C" fn ss_init() {
    shadowsocks::logger::init().unwrap();
}

#[no_mangle]
pub extern "C" fn ss_start(config: *const u8) -> i32 {
    // 实现启动逻辑
    0
}
EOF

        echo "🔍 验证依赖版本..."
        cargo update -p shadowsocks-rust --precise 1.22.0
    fi
}

# 主流程
main() {
    init_env
    init_project
    cd "${PROJECT_ROOT}"
    
    echo "📦 安装依赖..."
    cargo update
    
    echo "📱 编译iOS版本..."
    cargo lipo --release --targets aarch64-apple-ios
    
    echo "💻 编译macOS版本..."
    cargo build --release --target x86_64-apple-darwin
    
    echo "✅ 编译完成！产物位置：${TARGET_DIR}"
}

main
