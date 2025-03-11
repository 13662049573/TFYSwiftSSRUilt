Pod::Spec.new do |spec|
  spec.name         = "TFYSwiftSSRKit"

  spec.version      = "1.0.9"

  spec.summary      = "iOS/macOS Shadowsocks/SSR 客户端框架，支持 Rust 和 C 两种实现"

  spec.description  = <<-DESC
                    TFYSwiftSSRKit 是一个用于 iOS 和 macOS 的 Shadowsocks/SSR 客户端框架，
                    支持 Rust 和 C 两种实现。提供统一的 API 接口，支持 TCP 和 UDP 代理，
                    以及 NAT 穿透和 HTTP 代理功能（仅 libev 实现）。
                    现已添加规则管理功能，支持黑白名单和自定义规则。
                    DESC

  spec.homepage     = "https://github.com/13662049573/TFYSwiftSSRUilt"
  
  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author       = { "tianfengyou" => "420144542@qq.com" }
  
  spec.ios.deployment_target = "15.0"

  spec.osx.deployment_target = "12.0"
  
  spec.source       = { :git => "https://github.com/13662049573/TFYSwiftSSRUilt.git", :tag => "#{spec.version}" }
  
  # 核心文件
  spec.source_files = "TFYSwiftSSRKit/*.{h,m}", 
                      "TFYSwiftSSRKit/Base/*.{h,m}", 
                      "TFYSwiftSSRKit/Core/*.{h,m}", 
                      "TFYSwiftSSRKit/Service/*.{h,m}",
                      "TFYSwiftSSRKit/TFYCoreFactory/*.{h,m}",
                      "TFYSwiftSSRKit/Rules/*.{h,m}"
  
  # 模块映射文件
  spec.module_map = "module.modulemap"
  
  # 公开头文件
  spec.public_header_files = "TFYSwiftSSRKit/TFYSwiftSSRKit.h",
                            "TFYSwiftSSRKit/Base/TFYSSTypes.h",
                            "TFYSwiftSSRKit/Base/TFYSSError.h",
                            "TFYSwiftSSRKit/Base/TFYSSConfig.h",
                            "TFYSwiftSSRKit/Core/TFYSSCoreProtocol.h",
                            "TFYSwiftSSRKit/Core/TFYSSRustCore.h",
                            "TFYSwiftSSRKit/Core/TFYSSLibevCore.h",
                            "TFYSwiftSSRKit/TFYCoreFactory/TFYSSCoreFactory.h",
                            "TFYSwiftSSRKit/Service/TFYSSProxyService.h",
                            "TFYSwiftSSRKit/Service/TFYSSVPNService.h",
                            "TFYSwiftSSRKit/Service/TFYSSPacketTunnelProvider.h",
                            "TFYSwiftSSRKit/Rules/TFYSSRule.h",
                            "TFYSwiftSSRKit/Rules/TFYSSRuleSet.h",
                            "TFYSwiftSSRKit/Rules/TFYSSRuleManager.h"
  
  # Shadowsocks-libev
  spec.subspec 'shadowsocks-libev' do |libev|
    libev.source_files = "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include/*.h",
                      "TFYSwiftSSRKit/shadowsocks-libev/antinat/include/**/*.h",
                      "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/*.h"
    
    # iOS 静态库
    libev.ios.vendored_libraries = "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib/libshadowsocks-libev_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libev/lib/libev_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libsodium/lib/libsodium_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/openssl/lib/libcrypto_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/openssl/lib/libssl_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/c-ares/lib/libcares_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/pcre/lib/libpcre_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/pcre/lib/libpcreposix_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libcork/lib/libcork_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libipset/lib/libipset_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib/libmbedtls_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib/libmbedcrypto_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib/libmbedx509_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/lib/libmaxminddb_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/antinat/lib/libantinat_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib/libprivoxy_ios.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/udns/lib/libudns_ios.a"
    
    # macOS 静态库
    libev.osx.vendored_libraries = "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib/libshadowsocks-libev_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libev/lib/libev_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libsodium/lib/libsodium_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/openssl/lib/libcrypto_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/openssl/lib/libssl_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/c-ares/lib/libcares_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/pcre/lib/libpcre_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/pcre/lib/libpcreposix_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libcork/lib/libcork_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libipset/lib/libipset_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib/libmbedtls_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib/libmbedcrypto_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/lib/libmbedx509_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/libmaxminddb/lib/libmaxminddb_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/antinat/lib/libantinat_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib/libprivoxy_macos.a",
                               "TFYSwiftSSRKit/shadowsocks-libev/udns/lib/libudns_macos.a"
    
    libev.private_header_files = "TFYSwiftSSRKit/shadowsocks-libev/**/*.h"
    libev.libraries = "c", "resolv", "z"
  end
  
  # Shadowsocks-rust
  spec.subspec 'shadowsocks-rust' do |rust|
    rust.source_files = "TFYSwiftSSRKit/shadowsocks-rust/include/*.h"
    
    # iOS 静态库
    rust.ios.vendored_libraries = "TFYSwiftSSRKit/shadowsocks-rust/lib/libss_ios.a"
    
    # macOS 静态库
    rust.osx.vendored_libraries = "TFYSwiftSSRKit/shadowsocks-rust/lib/libss_macos.a"
    
    rust.private_header_files = "TFYSwiftSSRKit/shadowsocks-rust/include/*.h"
  end
  
  # 框架设置
  spec.requires_arc = true
  spec.frameworks = "Foundation"
  spec.ios.frameworks = "UIKit", "NetworkExtension"
  spec.osx.frameworks = "AppKit", "NetworkExtension"
  
  # 编译设置
  spec.pod_target_xcconfig = { 
    'VALID_ARCHS' => 'arm64 arm64e x86_64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'SWIFT_VERSION' => '5.0',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT) $(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit $(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks-libev/libsodium/include',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => ['$(inherited)', 'HAVE_CONFIG_H=1'],
    'DEFINES_MODULE' => 'YES',
    'MODULEMAP_FILE' => '$(PODS_TARGET_SRCROOT)/module.modulemap',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_CONFIGURATION_BUILD_DIR)',
    'OTHER_CFLAGS' => '-fmodule-map-file=$(PODS_TARGET_SRCROOT)/module.modulemap'
  }
  
  spec.user_target_xcconfig = { 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/TFYSwiftSSRKit $(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libsodium/include',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_ROOT)/TFYSwiftSSRKit',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_CONFIGURATION_BUILD_DIR)'
  }
  
  # 保留路径，确保模块映射文件和头文件被正确包含
  spec.preserve_paths = 'module.modulemap', 'TFYSwiftSSRKit/**/*.h'
  
  # Swift版本兼容性
  spec.swift_versions = ['5.0']
  
end 