Pod::Spec.new do |spec|
  spec.name         = "TFYSwiftSSRKit"
  spec.version      = "1.0.0"
  spec.summary      = "A powerful iOS/macOS shadowsocks client library written in Swift"
  
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
                    
  spec.homepage     = "https://github.com/TFYSwiftSSRUilt/TFYSwiftSSRKit"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "田风有" => "420144542@qq.com" }
  
  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "11.0"
  spec.swift_version = "5.0"
  
  spec.source       = { :git => "https://github.com/TFYSwiftSSRUilt/TFYSwiftSSRKit.git", :tag => "#{spec.version}" }
  
  spec.source_files = "TFYSwiftSSRKit/Classes/**/*.{h,m,swift}"
  spec.public_header_files = "TFYSwiftSSRKit/Classes/**/*.h"
  
  # 资源文件
  spec.resource_bundles = {
    'TFYSwiftSSRKit' => [
      'TFYSwiftSSRKit/Resources/*.json',
      'TFYSwiftSSRKit/Resources/*.mmdb'
    ]
  }
  
  # 预编译二进制文件
  spec.vendored_libraries = [
    'TFYSwiftSSRKit/shadowsocks/install/lib/*.{a,dylib}',
    'TFYSwiftSSRKit/libsodium/install/lib/*.{a,dylib}',
    'TFYSwiftSSRKit/openssl/install/lib/*.{a,dylib}',
    'TFYSwiftSSRKit/libmaxminddb/install/lib/*.{a,dylib}'
  ]
  
  # 二进制文件
  spec.preserve_paths = [
    'TFYSwiftSSRKit/shadowsocks/install/bin/*',
    'TFYSwiftSSRKit/shadowsocks/install/include/*',
    'TFYSwiftSSRKit/libsodium/install/include/*',
    'TFYSwiftSSRKit/openssl/install/include/*',
    'TFYSwiftSSRKit/libmaxminddb/install/include/*'
  ]
  
  # 系统框架依赖
  spec.framework = "Network"
  spec.framework = "SystemConfiguration"
  
  # 编译设置
  spec.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks/install/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/libsodium/install/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/openssl/install/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/libmaxminddb/install/include'
    ],
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks/install/lib',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/libsodium/install/lib',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/openssl/install/lib',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/libmaxminddb/install/lib'
    ],
    'SWIFT_INCLUDE_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/shadowsocks/install/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/libsodium/install/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/openssl/install/include',
      '$(PODS_TARGET_SRCROOT)/TFYSwiftSSRKit/libmaxminddb/install/include'
    ],
    'GCC_PREPROCESSOR_DEFINITIONS' => [
      'SODIUM_STATIC=1',
      'OPENSSL_STATIC=1'
    ],
    'OTHER_LDFLAGS' => [
      '-lsodium',
      '-lssl',
      '-lcrypto',
      '-lmaxminddb'
    ],
    'ENABLE_BITCODE' => 'NO'
  }
  
  # 用户工程设置
  spec.user_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/libsodium/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/openssl/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/libmaxminddb/install/include'
    ]
  }
  
  # Swift 模块映射
  spec.module_map = 'module.modulemap'
end 
