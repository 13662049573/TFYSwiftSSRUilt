Pod::Spec.new do |spec|
  spec.name         = "TFYSwiftSSRKit"
  spec.version      = "1.0.0"
  spec.summary      = "A powerful iOS/macOS shadowsocks client library written in Objective-C"
  
  spec.description  = <<-DESC
                    TFYSwiftSSRKit is a comprehensive shadowsocks client library for iOS and macOS.
                    Features:
                    * Multiple encryption methods support (OpenSSL & libsodium)
                    * GeoIP based routing
                    * TLS support
                    * Automatic network monitoring and reconnection
                    * Rule-based proxy configuration
                    * Traffic statistics
                    DESC
                    
  spec.homepage     = "https://github.com/13662049573/TFYSwiftSSRUilt"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "田风有" => "420144542@qq.com" }
  
  spec.ios.deployment_target = "15.0"
  spec.osx.deployment_target = "12.0"
  
  spec.source       = { :git => "https://github.com/13662049573/TFYSwiftSSRUilt.git", :tag => spec.version }
  
  # Objective-C 源文件
  spec.source_files = [
    "Classes/*.{h,m}",
    "libmaxminddb/install/include/*.h",
    "libsodium/install/include/*.h",
    "libsodium/install/include/sodium/*.h",
    "openssl/install/include/openssl/*.h",
    "shadowsocks/install/include/*.h"
  ]
  
  # 头文件
  spec.public_header_files = [
    "Classes/*.h",
    "libmaxminddb/install/include/*.h",
    "libsodium/install/include/*.h",
    "libsodium/install/include/sodium/*.h",
    "openssl/install/include/openssl/*.h",
    "shadowsocks/install/include/*.h"
  ]
  
  # 资源文件
  spec.resource_bundles = {
    'TFYSwiftSSRKit' => [
      "Resources/default_rules.json",
      "Resources/GeoLite2-Country.mmdb",
      "Resources/user_rules.json",
      "shadowsocks/install/bin/sslocal",
      "shadowsocks/install/bin/ssmanager",
      "shadowsocks/install/bin/ssserver",
      "shadowsocks/install/bin/ssurl"
    ]
  }
  
  # 系统框架依赖
  spec.frameworks = ["Network", "SystemConfiguration"]
  
  # 添加第三方依赖
  spec.dependency 'CocoaAsyncSocket', '~> 7.6.5'
  spec.dependency 'MMWormhole', '~> 2.0.0'
  
  # 编译设置
  spec.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)',
      '$(PODS_TARGET_SRCROOT)/libmaxminddb/install/include',
      '$(PODS_TARGET_SRCROOT)/libsodium/install/include',
      '$(PODS_TARGET_SRCROOT)/openssl/install/include',
      '$(PODS_TARGET_SRCROOT)/shadowsocks/install/include',
      '$(PODS_ROOT)/MMWormhole',
      '$(PODS_ROOT)/CocoaAsyncSocket'
    ],
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/Frameworks'
    ],
    'ENABLE_BITCODE' => 'NO',
    'OTHER_LDFLAGS' => [
      '-lmaxminddb',
      '-lsodium',
      '-lcrypto',
      '-lssl'
    ],
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => ['HAVE_CONFIG_H=1', 'HAVE_MAXMINDDB=1', 'HAVE_SODIUM=1', 'HAVE_OPENSSL=1'],
    'CLANG_ENABLE_OBJC_ARC' => 'YES',
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'NO'
  }
  
  # 添加模块映射
  spec.module_map = 'module.modulemap'
  
  # 添加库依赖
  spec.ios.vendored_libraries = [
    'Frameworks/libcrypto_ios.a',
    'Frameworks/libmaxminddb_ios.a',
    'Frameworks/libsodium_ios.a',
    'Frameworks/libssl_ios.a'
  ]
  
  spec.osx.vendored_libraries = [
    'libmaxminddb/install/lib/libmaxminddb_macos.a',
    'libsodium/install/lib/libsodium_macos.a',
    'openssl/install/lib/libcrypto_macos.a',
    'openssl/install/lib/libssl_macos.a'
  ]
  
  # 添加依赖库的头文件和库文件路径
  spec.preserve_paths = [
    'Classes/**/*',
    'Frameworks/**/*',
    'Resources/**/*',
    'libmaxminddb/install/**/*',
    'libsodium/install/**/*',
    'openssl/install/**/*',
    'shadowsocks/install/**/*',
    'module.modulemap'
  ]
end 
