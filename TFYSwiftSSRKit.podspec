Pod::Spec.new do |spec|
  spec.name         = "TFYSwiftSSRKit"
  spec.version      = "1.0.5"
  spec.summary      = "iOS/macOS Shadowsocks客户端框架，集成Rust和Libev核心，支持Antinat和Privoxy"
  spec.description  = <<-DESC
                     TFYSwiftSSRKit是一个iOS/macOS框架，提供Shadowsocks客户端功能。
                     它同时支持Rust和Libev实现，以获得高性能和安全性，
                     并使用Objective-C接口包装，便于集成到iOS/macOS应用中。
                     该框架还包括用于网络连接管理的Antinat和
                     具有过滤功能的HTTP代理Privoxy。
                     DESC

  spec.homepage     = "https://github.com/13662049573/TFYSwiftSSRUilt"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "田风有" => "420144542@qq.com" }
  
  # 平台支持 - 确保使用较高的部署目标版本
  spec.ios.deployment_target = '15.0'
  spec.osx.deployment_target = '12.0'
  
  # CocoaPods 版本要求
  spec.cocoapods_version = '>= 1.10.0'
  
  # Swift 版本要求
  spec.swift_versions = ['5.0']
  
  # 源代码
  spec.source       = { :git => "https://github.com/13662049573/TFYSwiftSSRUilt.git", :tag => "#{spec.version}" }
  spec.header_mappings_dir = 'TFYSwiftSSRKit'
  
  # 源文件和头文件
  spec.source_files = [
    "TFYSwiftSSRKit/TFYSwiftSSRKit.h",
    "TFYSwiftSSRKit/LibevOCClass/*.{h,m}",
    "TFYSwiftSSRKit/RustOCClass/*.{h,m}",
    "TFYSwiftSSRKit/shadowsocks-rust/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-rust/include/module/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/antinat/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/privoxy.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/config.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libsodium/include/sodium.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libsodium/include/sodium/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libev/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/include/**/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/pcre/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/c-ares/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libcork/include/**/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libipset/include/**/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/openssl/include/**/*.h",
    # 添加 GCDAsyncSocket 源文件
    "TFYSwiftSSRKit/GCDAsyncSocket/*.{h,m}",
    # 添加 MMWormhole 源文件
    "TFYSwiftSSRKit/MMWormhole/*.{h,m}"
  ]
  
  # 排除不需要的文件
  spec.exclude_files = [
    "TFYSwiftSSRKit/shadowsocks-rust/src/**/*",
    "TFYSwiftSSRKit/shadowsocks-rust/Cargo.lock",
    "TFYSwiftSSRKit/shadowsocks-rust/Cargo.toml"
  ]
  
  # 公共头文件
  spec.public_header_files = [
    "TFYSwiftSSRKit/TFYSwiftSSRKit.h",
    "TFYSwiftSSRKit/LibevOCClass/*.h",
    "TFYSwiftSSRKit/RustOCClass/*.h",
    # 添加 GCDAsyncSocket 公共头文件
    "TFYSwiftSSRKit/GCDAsyncSocket/*.h",
    # 添加 MMWormhole 公共头文件
    "TFYSwiftSSRKit/MMWormhole/*.h"
  ]
  
  # 私有头文件 - 这些头文件不会被暴露给使用者，但会被框架内部使用
  spec.private_header_files = [
    "TFYSwiftSSRKit/shadowsocks-rust/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-rust/include/module/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/antinat/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/privoxy.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/config.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libsodium/include/sodium.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libsodium/include/sodium/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libev/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/include/**/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/pcre/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/c-ares/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libcork/include/**/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libipset/include/**/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/openssl/include/**/*.h"
  ]
  
  # iOS静态库
  ios_libs = [
    "shadowsocks-rust/lib/libss_ios.a",
    "shadowsocks-libev/shadowsocks/lib/libshadowsocks-libev_ios.a",
    "shadowsocks-libev/antinat/lib/libantinat_ios.a",
    "shadowsocks-libev/privoxy/lib/libprivoxy_ios.a",
    "shadowsocks-libev/libsodium/lib/libsodium_ios.a",
    "shadowsocks-libev/libev/lib/libev_ios.a",
    "shadowsocks-libev/mbedtls/lib/libmbedtls_ios.a",
    "shadowsocks-libev/mbedtls/lib/libmbedcrypto_ios.a",
    "shadowsocks-libev/mbedtls/lib/libmbedx509_ios.a",
    "shadowsocks-libev/pcre/lib/libpcre_ios.a",
    "shadowsocks-libev/c-ares/lib/libcares_ios.a",
    "shadowsocks-libev/libcork/lib/libcork_ios.a",
    "shadowsocks-libev/libipset/lib/libipset_ios.a",
    "shadowsocks-libev/libmaxminddb/lib/libmaxminddb_ios.a",
    "shadowsocks-libev/openssl/lib/libcrypto_ios.a",
    "shadowsocks-libev/openssl/lib/libssl_ios.a"
  ]
  spec.ios.vendored_libraries = ios_libs.map { |lib| "TFYSwiftSSRKit/#{lib}" }
  
  # macOS静态库
  macos_libs = [
    "shadowsocks-rust/lib/libss_macos.a",
    "shadowsocks-libev/shadowsocks/lib/libshadowsocks-libev_macos.a",
    "shadowsocks-libev/antinat/lib/libantinat_macos.a",
    "shadowsocks-libev/privoxy/lib/libprivoxy_macos.a",
    "shadowsocks-libev/libsodium/lib/libsodium_macos.a",
    "shadowsocks-libev/libev/lib/libev_macos.a",
    "shadowsocks-libev/mbedtls/lib/libmbedtls_macos.a",
    "shadowsocks-libev/mbedtls/lib/libmbedcrypto_macos.a",
    "shadowsocks-libev/mbedtls/lib/libmbedx509_macos.a",
    "shadowsocks-libev/pcre/lib/libpcre_macos.a",
    "shadowsocks-libev/c-ares/lib/libcares_macos.a",
    "shadowsocks-libev/libcork/lib/libcork_macos.a",
    "shadowsocks-libev/libipset/lib/libipset_macos.a",
    "shadowsocks-libev/libmaxminddb/lib/libmaxminddb_macos.a",
    "shadowsocks-libev/openssl/lib/libcrypto_macos.a",
    "shadowsocks-libev/openssl/lib/libssl_macos.a"
  ]
  spec.osx.vendored_libraries = macos_libs.map { |lib| "TFYSwiftSSRKit/#{lib}" }
  
  # 通用配置
  common_xcconfig = {
    'VALID_ARCHS' => 'arm64',
    'ONLY_ACTIVE_ARCH' => 'YES',
    'ENABLE_BITCODE' => 'NO',
    'CLANG_ENABLE_MODULES' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => ['$(inherited)', 'HAVE_CONFIG_H=1'],
    'MODULEMAP_FILE' => '$(PODS_TARGET_SRCROOT)/module.modulemap',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'TFYSwiftSSRKit-Swift.h',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }
  
  # iOS配置
  ios_xcconfig = common_xcconfig.merge({
    'SUPPORTS_MACCATALYST' => 'NO',
    'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD' => 'NO',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC -lc++ -lmbedtls_ios -lmbedcrypto_ios -lmbedx509_ios -lsodium_ios -lss_ios -lprivoxy_ios',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib" "$(SRCROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib" "$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib" "$(SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib"',
    'LD_VERIFY_BITCODE' => 'NO'
  })
  
  spec.ios.pod_target_xcconfig = ios_xcconfig
  spec.ios.user_target_xcconfig = ios_xcconfig
  
  # macOS配置
  macos_xcconfig = common_xcconfig.merge({
    'OTHER_LDFLAGS' => '$(inherited) -ObjC -lc++ -lmbedtls_macos -lmbedcrypto_macos -lmbedx509_macos -lsodium_macos -lss_macos -lprivoxy_macos',
    'MACOSX_DEPLOYMENT_TARGET' => '12.0',
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib" "$(SRCROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib" "$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib" "$(SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib"',
    'LD_VERIFY_BITCODE' => 'NO'
  })
  
  spec.osx.pod_target_xcconfig = macos_xcconfig
  spec.osx.user_target_xcconfig = macos_xcconfig
  
  # 搜索路径配置
  header_search_paths = [
    '$(inherited)',
    '$(PODS_ROOT)/TFYSwiftSSRKit',
    '$(SRCROOT)/TFYSwiftSSRKit',
    '$(PODS_ROOT)/TFYSwiftSSRKit/LibevOCClass',
    '$(PODS_ROOT)/TFYSwiftSSRKit/RustOCClass',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/include/module',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/antinat/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libsodium/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libev/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/mbedtls/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/pcre/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/c-ares/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libcork/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libipset/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/include',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/openssl/include',
    # 添加 GCDAsyncSocket 和 MMWormhole 头文件搜索路径
    '$(PODS_ROOT)/TFYSwiftSSRKit/GCDAsyncSocket',
    '$(PODS_ROOT)/TFYSwiftSSRKit/MMWormhole'
  ].join(' ')
  
  ios_lib_search_paths = [
    '$(inherited)',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib',
    '$(SRCROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/antinat/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libsodium/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libev/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/pcre/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/c-ares/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libcork/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libipset/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/openssl/lib'
  ].join(' ')
  
  macos_lib_search_paths = [
    '$(inherited)',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib',
    '$(SRCROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/antinat/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libsodium/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libev/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/pcre/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/c-ares/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libcork/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libipset/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/lib',
    '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/openssl/lib'
  ].join(' ')
  
  spec.pod_target_xcconfig = {
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-rust/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/GCDAsyncSocket',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/MMWormhole',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/mbedtls/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/libsodium/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/libcork/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/libev/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/c-ares/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/pcre/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/openssl/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/antinat/include'
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-rust/lib',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib'
    ].join(' '),
    'GCC_PREPROCESSOR_DEFINITIONS' => [
      'GCD_ASYNC_SOCKET_HEADER="GCDAsyncSocket.h"',
      'HAVE_CONFIG_H=1'
    ]
  }
  
  # 框架依赖
  spec.frameworks = [
    'Foundation', 
    'UIKit', 
    'CoreFoundation', 
    'Security', 
    'SystemConfiguration', 
    'NetworkExtension',
    'WatchConnectivity'
  ]
  
  # 库依赖
  spec.libraries = ['c++', 'z']
  
  # 要求ARC
  spec.requires_arc = true
  
  # 静态框架
  spec.static_framework = true
  
  # 模块映射
  spec.module_map = 'module.modulemap'
  
  # 添加 preserve_paths 确保库文件被保留
  spec.preserve_paths = [
    'TFYSwiftSSRKit/shadowsocks-rust/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-rust/lib/*.a',
    'TFYSwiftSSRKit/shadowsocks-libev/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib/*.a',
    'TFYSwiftSSRKit/shadowsocks-libev/mbedtls/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/libsodium/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/libcork/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/libev/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/c-ares/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/pcre/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/openssl/include/**/*.h',
    'TFYSwiftSSRKit/shadowsocks-libev/antinat/include/**/*.h'
  ]
end 