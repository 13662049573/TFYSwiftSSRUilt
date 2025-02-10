#!/bin/bash

# 设置错误时退出
set -e

# 基础配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
DEPS_ROOT="${PROJECT_ROOT}/TFYSwiftSSRKit"
VERSION="3.3.5"
LIB_NAME="shadowsocks"

# 设置编译环境
export IPHONEOS_DEPLOYMENT_TARGET="15.0"
export MACOS_DEPLOYMENT_TARGET="12.0"

# 架构
IOS_ARCHS="arm64"
MACOS_ARCHS="x86_64 arm64"

# 设置SDK路径
export DEVELOPER_DIR="$(xcode-select -p)"
export IOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer"
export IOS_SDK="${IOS_SDK_PATH}/SDKs/iPhoneOS.sdk"
export MACOS_SDK_PATH="${DEVELOPER_DIR}/Platforms/MacOSX.platform/Developer"
export MACOS_SDK="${MACOS_SDK_PATH}/SDKs/MacOSX.sdk"

# 设置构建目标（可以是 "ios"、"macos" 或 "all"）
BUILD_TARGET="${BUILD_TARGET:-all}"

# 设置环境变量
export BUILD_DIR="${PROJECT_ROOT}/build"
export MBEDTLS_PREFIX="${DEPS_ROOT}/mbedtls"
export PCRE_PREFIX="${DEPS_ROOT}/pcre"
export LIBSODIUM_PREFIX="${DEPS_ROOT}/libsodium"
export LIBMAXMINDDB_PREFIX="${DEPS_ROOT}/libmaxminddb"
export OPENSSL_PREFIX="${DEPS_ROOT}/openssl"
export SHADOWSOCKS_PREFIX="${DEPS_ROOT}/shadowsocks"

# 设置编译器工具链
export PATH="${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin:${DEVELOPER_DIR}/usr/bin:${PATH}"

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# 错误处理
handle_error() {
    log_error "An error occurred in function: $1"
    log_error "Error on line $2"
    exit 1
}

trap 'handle_error "${FUNCNAME[0]}" $LINENO' ERR

# 检查 Xcode 环境
check_xcode_env() {
    log_info "Checking Xcode environment..."
    
    # 检查 Xcode 命令行工具
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode Command Line Tools not installed"
        log_error "Please install them using: xcode-select --install"
        return 1
    fi
    
    # 检查 SDK 路径
    if [ ! -d "${IOS_SDK}" ]; then
        log_error "iOS SDK not found at: ${IOS_SDK}"
        log_error "Please verify your Xcode installation"
        return 1
    fi
    
    # 检查编译器
    if ! xcrun -f clang &>/dev/null; then
        log_error "Clang compiler not found"
        log_error "Please verify your Xcode installation"
        return 1
    fi
    
    log_info "Xcode environment check passed"
    return 0
}

# 检查必要的工具
check_dependencies() {
    log_info "Checking dependencies..."
    local missing_tools=()
    
    # 检查基本构建工具
    for tool in curl tar autoconf automake libtool pkg-config make cmake; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install them using: brew install ${missing_tools[*]}"
        return 1
    fi
    
    log_info "All required tools are available"
    return 0
}

# 检查依赖库
check_libraries() {
    log_info "Checking library dependencies..."
    
    # 检查依赖库
    local required_libs=(
        "${MBEDTLS_PREFIX}"
        "${PCRE_PREFIX}"
        "${LIBSODIUM_PREFIX}"
        "${LIBMAXMINDDB_PREFIX}"
        "${OPENSSL_PREFIX}"
    )
    
    local lib_names=(
        "mbedtls"
        "pcre"
        "sodium"
        "maxminddb"
        "ssl"
    )
    
    local index=0
    for lib in "${required_libs[@]}"; do
        if [ ! -d "$lib" ]; then
            log_error "Required library directory not found: $lib"
            return 1
        fi
        
        # 检查静态库文件
        local lib_name="${lib_names[$index]}"
        local lib_file="$lib/lib/lib${lib_name}.a"
        if [ ! -f "$lib_file" ]; then
            log_warning "Library file not found: $lib_file"
            log_warning "Build process will continue, but might fail if libraries are not properly installed"
        fi
        
        # 检查头文件
        local include_dir="$lib/include"
        if [ ! -d "$include_dir" ]; then
            log_warning "Include directory not found: $include_dir"
            log_warning "Build process will continue, but might fail if headers are not properly installed"
        fi
        
        index=$((index + 1))
    done
    
    log_info "Library dependency check completed"
    return 0
}

# 准备构建环境
prepare_build_env() {
    log_info "Preparing build environment..."
    
    # 创建构建目录
    if ! mkdir -p "${BUILD_DIR}"; then
        log_error "Failed to create build directory: ${BUILD_DIR}"
        return 1
    fi
    
    # 创建shadowsocks安装目录
    if ! mkdir -p "${SHADOWSOCKS_PREFIX}"; then
        log_error "Failed to create shadowsocks directory: ${SHADOWSOCKS_PREFIX}"
        return 1
    fi
    
    # 设置环境变量
    export PKG_CONFIG_PATH="${MBEDTLS_PREFIX}/lib/pkgconfig:${PCRE_PREFIX}/lib/pkgconfig:${LIBSODIUM_PREFIX}/lib/pkgconfig"
    export ACLOCAL_PATH="${MBEDTLS_PREFIX}/share/aclocal:${PCRE_PREFIX}/share/aclocal:$ACLOCAL_PATH"
    export LD_LIBRARY_PATH="${MBEDTLS_PREFIX}/lib:${PCRE_PREFIX}/lib:${LIBSODIUM_PREFIX}/lib"
    
    log_info "Build environment prepared successfully"
    return 0
}

# 清理构建目录
cleanup_build_dir() {
    if [ -d "${BUILD_DIR}" ]; then
        log_info "Cleaning up build directory..."
        if ! rm -rf "${BUILD_DIR}"/*; then
            log_error "Failed to clean build directory"
            return 1
        fi
    fi
    return 0
}

# 验证构建结果
verify_build() {
    local prefix="$1"
    local lib_name="$2"
    
    log_info "Verifying build for ${lib_name}..."
    
    if [ ! -d "${prefix}" ]; then
        log_error "Build failed: ${prefix} directory not found"
        return 1
    fi
    
    if [ ! -d "${prefix}/lib" ]; then
        log_error "Build failed: ${prefix}/lib directory not found"
        return 1
    fi
    
    local lib_files=($(find "${prefix}/lib" -name "lib${lib_name}*.a"))
    if [ ${#lib_files[@]} -eq 0 ]; then
        log_error "Build failed: no static libraries found for ${lib_name}"
        return 1
    fi
    
    # 验证库文件的架构
    for lib in "${lib_files[@]}"; do
        if ! lipo -info "${lib}" | grep -q "arm64"; then
            log_error "Build failed: ${lib} is not built for arm64 architecture"
            return 1
        fi
    done
    
    log_info "Build verified successfully for ${lib_name}"
    return 0
}

# 构建 mbedTLS
build_mbedtls() {
    local prefix="$1"
    local arch="$2"
    local sdk="$3"
    local min_version="$4"
    
    log_info "Building mbedTLS..."
    
    cd "${BUILD_DIR}"
    curl -L -o mbedtls-2.28.3.tar.gz https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v2.28.3.tar.gz
    tar xf mbedtls-2.28.3.tar.gz
    cd mbedtls-2.28.3
    
    mkdir build && cd build
    
    cmake -DCMAKE_INSTALL_PREFIX="${prefix}" \
          -DCMAKE_OSX_SYSROOT="${sdk}" \
          -DCMAKE_OSX_ARCHITECTURES="${arch}" \
          -DCMAKE_OSX_DEPLOYMENT_TARGET="${min_version}" \
          -DENABLE_PROGRAMS=OFF \
          -DENABLE_TESTING=OFF \
          -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
          -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
          ..
    
    make -j$(sysctl -n hw.ncpu)
    make install
    
    cd ../..
    rm -rf mbedtls-2.28.3*
}

# 构建 PCRE
build_pcre() {
    local prefix="$1"
    local arch="$2"
    local sdk="$3"
    local min_version="$4"
    
    log_info "Building PCRE..."
    
    cd "${BUILD_DIR}"
    curl -L -o pcre-8.45.tar.gz https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz/download
    tar xf pcre-8.45.tar.gz
    cd pcre-8.45
    
    export CFLAGS="-arch ${arch} -isysroot ${sdk} -mios-version-min=${min_version} -fembed-bitcode"
    export CXXFLAGS="${CFLAGS} -fvisibility-inlines-hidden"
    export LDFLAGS="-arch ${arch} -isysroot ${sdk}"
    
    ./configure --prefix="${prefix}" \
                --host=arm-apple-darwin \
                --disable-shared \
                --enable-static \
                --enable-utf8 \
                --enable-unicode-properties
    
    make clean
    make -j$(sysctl -n hw.ncpu)
    make install
    
    cd ..
    rm -rf pcre-8.45*
}

# 下载 shadowsocks-libev 源代码
download_shadowsocks_source() {
    local version="3.3.5"
    local archive="v${version}.tar.gz"
    local url="https://github.com/shadowsocks/shadowsocks-libev/archive/refs/tags/${archive}"
    
    log_info "Downloading shadowsocks-libev v${version}..."
    if ! curl -L -o "${archive}" "${url}"; then
        log_error "Failed to download shadowsocks-libev source"
        return 1
    fi
    
    log_info "Extracting shadowsocks-libev source..."
    if ! tar xf "${archive}"; then
        log_error "Failed to extract shadowsocks-libev source"
        return 1
    fi
    
    rm -f "${archive}"
    cd "shadowsocks-libev-${version}" || exit 1
    
    if [ ! -f "configure.ac" ]; then
        log_error "configure.ac not found in extracted source"
        return 1
    fi
    
    return 0
}

# 构建 shadowsocks-libev
build_shadowsocks() {
    local prefix="$1"
    local arch="$2"
    local sdk="$3"
    local min_version="$4"
    
    log_info "Building shadowsocks-libev..."
    
    # 使用已下载的源码目录
    local source_dir="${DEPS_ROOT}/shadowsocks/build/shadowsocks-libev-${VERSION}"
    if [ ! -d "${source_dir}" ]; then
        log_error "Shadowsocks source directory not found: ${source_dir}"
        return 1
    fi
    
    cd "${source_dir}" || {
        log_error "Failed to change to source directory: ${source_dir}"
        return 1
    }
    
    # 创建必要的目录
    mkdir -p m4
    mkdir -p libbloom
    mkdir -p libcork
    mkdir -p libipset
    
    # 创建必要的 Makefile.in 文件
    touch libbloom/Makefile.in
    touch libcork/Makefile.in
    touch libipset/Makefile.in
    
    # 设置构建环境变量
    if [[ "${sdk}" == *"iPhoneOS"* ]]; then
        export CC="$(xcrun -sdk iphoneos -find clang)"
        export CXX="$(xcrun -sdk iphoneos -find clang++)"
        export AR="$(xcrun -sdk iphoneos -find ar)"
        export RANLIB="$(xcrun -sdk iphoneos -find ranlib)"
        export STRIP="$(xcrun -sdk iphoneos -find strip)"
        export LIBTOOL="$(xcrun -sdk iphoneos -find libtool)"
        export NM="$(xcrun -sdk iphoneos -find nm)"
        export CFLAGS="-arch ${arch} -isysroot ${sdk} -I${MBEDTLS_PREFIX}/include -I${PCRE_PREFIX}/include -I${LIBSODIUM_PREFIX}/include -fembed-bitcode -O2 -mios-version-min=${min_version}"
        export host_alias="arm-apple-darwin"
        export build_alias="x86_64-apple-darwin"
        export target_alias="arm-apple-darwin"
        export cross_compiling="yes"
    else
        export CC="$(xcrun -sdk macosx -find clang)"
        export CXX="$(xcrun -sdk macosx -find clang++)"
        export AR="$(xcrun -sdk macosx -find ar)"
        export RANLIB="$(xcrun -sdk macosx -find ranlib)"
        export STRIP="$(xcrun -sdk macosx -find strip)"
        export LIBTOOL="$(xcrun -sdk macosx -find libtool)"
        export NM="$(xcrun -sdk macosx -find nm)"
        export CFLAGS="-arch ${arch} -isysroot ${sdk} -I${MBEDTLS_PREFIX}/include -I${PCRE_PREFIX}/include -I${LIBSODIUM_PREFIX}/include -O2 -mmacosx-version-min=${min_version}"
        if [[ "${arch}" == "arm64" ]]; then
            export host_alias="arm-apple-darwin"
            export build_alias="x86_64-apple-darwin"
            export target_alias="arm-apple-darwin"
            export cross_compiling="yes"
        else
            export host_alias="x86_64-apple-darwin"
            export build_alias="x86_64-apple-darwin"
            export target_alias="x86_64-apple-darwin"
            export cross_compiling="no"
        fi
    fi
    
    # 设置通用编译标志
    export CPPFLAGS="${CFLAGS}"
    export LDFLAGS="-arch ${arch} -isysroot ${sdk} -L${MBEDTLS_PREFIX}/lib -L${PCRE_PREFIX}/lib -L${LIBSODIUM_PREFIX}/lib"
    
    # 设置pkg-config路径
    export PKG_CONFIG_PATH="${MBEDTLS_PREFIX}/lib/pkgconfig:${PCRE_PREFIX}/lib/pkgconfig:${LIBSODIUM_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
    
    # 设置PCRE相关变量
    export PCRE_LIBS="-L${PCRE_PREFIX}/lib -lpcre"
    export PCRE_CFLAGS="-I${PCRE_PREFIX}/include"
    
    # 设置交叉编译环境变量
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export ac_cv_func_mmap=yes
    export ac_cv_func_mmap_fixed_mapped=yes
    export ac_cv_func_munmap=yes
    export ac_cv_func_select=yes
    export ac_cv_func_socket=yes
    export ac_cv_func_connect=yes
    export ac_cv_func_gethostbyname=yes
    export ac_cv_func_getaddrinfo=yes
    export ac_cv_header_sys_socket_h=yes
    export ac_cv_header_netdb_h=yes
    export ac_cv_header_netinet_in_h=yes
    export ac_cv_header_arpa_inet_h=yes
    export ac_cv_header_sys_select_h=yes
    export ac_cv_header_sys_ioctl_h=yes
    export ac_cv_header_sys_un_h=yes
    export ac_cv_prog_cc_c99=yes
    export ac_cv_c_bigendian=no
    export ac_cv_func_fork=no
    export ac_cv_func_vfork=no
    export ac_cv_func_pipe=yes
    export ac_cv_func_setuid=no
    export ac_cv_func_setsid=no
    export ac_cv_func_setreuid=no
    export ac_cv_func_setresuid=no
    export ac_cv_func_setgid=no
    export ac_cv_func_setregid=no
    export ac_cv_func_setresgid=no
    export ac_cv_func_clock_gettime=yes
    
    # 清理之前的构建
    if [ -f "Makefile" ]; then
        make distclean || true
    fi
    
    # 运行 autogen.sh
    if [ -f "./autogen.sh" ]; then
        chmod +x ./autogen.sh
        ./autogen.sh || {
            log_error "autogen.sh failed"
            return 1
        }
    fi
    
    # 更新config.guess和config.sub
    if [ -f "/usr/local/share/libtool/build-aux/config.guess" ]; then
        cp /usr/local/share/libtool/build-aux/config.guess ./config.guess
    fi
    if [ -f "/usr/local/share/libtool/build-aux/config.sub" ]; then
        cp /usr/local/share/libtool/build-aux/config.sub ./config.sub
    fi
    
    # 配置构建，添加超时控制
    timeout 300 ./configure --prefix="${prefix}" \
                --host="${host_alias}" \
                --build="${build_alias}" \
                --target="${target_alias}" \
                --disable-documentation \
                --disable-shared \
                --enable-static \
                --disable-ssp \
                --disable-assert \
                --with-mbedtls="${MBEDTLS_PREFIX}" \
                --with-pcre="${PCRE_PREFIX}" \
                --with-sodium="${LIBSODIUM_PREFIX}" \
                PCRE_LIBS="${PCRE_LIBS}" \
                PCRE_CFLAGS="${PCRE_CFLAGS}" \
                LIBS="-lpcre" || {
        log_error "Configure failed for shadowsocks-libev"
        return 1
    }
    
    make clean
    make -j$(sysctl -n hw.ncpu) V=1 || {
        log_error "Build failed for shadowsocks-libev"
        return 1
    }
    make install || {
        log_error "Install failed for shadowsocks-libev"
        return 1
    }
    
    cd - > /dev/null
    
    # 验证构建结果
    verify_build "${prefix}" "shadowsocks-libev"
}

# 主函数
main() {
    log_info "Starting build process..."
    
    # 检查环境
    if ! check_xcode_env; then
        exit 1
    fi
    
    if ! check_dependencies; then
        exit 1
    fi
    
    if ! check_libraries; then
        exit 1
    fi
    
    if ! prepare_build_env; then
        exit 1
    fi
    
    if ! cleanup_build_dir; then
        exit 1
    fi
    
    # iOS 构建
    if [[ $BUILD_TARGET == "ios" || $BUILD_TARGET == "all" ]]; then
        log_info "Building for iOS (arm64)..."
        if ! build_shadowsocks "${SHADOWSOCKS_PREFIX}" "arm64" "${IOS_SDK}" "${IPHONEOS_DEPLOYMENT_TARGET}"; then
            log_error "Failed to build shadowsocks for iOS"
            exit 1
        fi
    fi
    
    # macOS 构建
    if [[ $BUILD_TARGET == "macos" || $BUILD_TARGET == "all" ]]; then
        log_info "Building for macOS..."
        for arch in $MACOS_ARCHS; do
            log_info "Building for macOS ($arch)..."
            if ! build_shadowsocks "${SHADOWSOCKS_PREFIX}_macos_${arch}" "$arch" "${MACOS_SDK}" "${MACOS_DEPLOYMENT_TARGET}"; then
                log_error "Failed to build shadowsocks for macOS ($arch)"
                exit 1
            fi
        done
        
        # 合并 macOS 架构
        if [ "$MACOS_ARCHS" != "" ]; then
            log_info "Creating universal binary for macOS..."
            mkdir -p "${SHADOWSOCKS_PREFIX}_macos/lib"
            local lib_files=($(find "${SHADOWSOCKS_PREFIX}_macos_${MACOS_ARCHS%% *}/lib" -name "*.a"))
            for lib in "${lib_files[@]}"; do
                local lib_name=$(basename "$lib")
                local lipo_cmd="lipo -create"
                for arch in $MACOS_ARCHS; do
                    lipo_cmd="$lipo_cmd ${SHADOWSOCKS_PREFIX}_macos_${arch}/lib/${lib_name}"
                done
                lipo_cmd="$lipo_cmd -output ${SHADOWSOCKS_PREFIX}_macos/lib/${lib_name}"
                eval "$lipo_cmd" || {
                    log_error "Failed to create universal binary for $lib_name"
                    exit 1
                }
            done
        fi
    fi
    
    log_info "Build process completed successfully"
    
    # 显示构建结果摘要
    log_info "Build Summary:"
    if [[ $BUILD_TARGET == "ios" || $BUILD_TARGET == "all" ]]; then
        log_info "iOS build: ${SHADOWSOCKS_PREFIX}"
        lipo -info "${SHADOWSOCKS_PREFIX}/lib/libshadowsocks-libev.a" || true
    fi
    if [[ $BUILD_TARGET == "macos" || $BUILD_TARGET == "all" ]]; then
        log_info "macOS build: ${SHADOWSOCKS_PREFIX}_macos"
        lipo -info "${SHADOWSOCKS_PREFIX}_macos/lib/libshadowsocks-libev.a" || true
    fi
}

main 