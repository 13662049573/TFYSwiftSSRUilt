Pod::Spec.new do |spec|
  spec.name         = "TFYSwiftSSRKit"
  spec.version      = "1.0.0"
  spec.summary      = "iOS/macOS Shadowsocks client framework with Rust and Libev cores"
  spec.description  = <<-DESC
                     TFYSwiftSSRKit is an iOS/macOS framework that provides Shadowsocks client functionality.
                     It supports both Rust and Libev implementations for high performance and security,
                     wrapped with Objective-C interfaces for easy integration into iOS/macOS apps.
                     DESC

  spec.homepage     = "https://github.com/13662049573/TFYSwiftSSRKit"

  spec.license      = { :type => "MIT", :file => "TFYSwiftSSRKit/LICENSE" }

  spec.author       = { "田风有" => "420144542@qq.com" }

  spec.ios.deployment_target = '15.0'
  
  spec.osx.deployment_target = '12.0'
  
  spec.source       = { 
    :git => "https://github.com/13662049573/TFYSwiftSSRKit.git", 
    :tag => "#{spec.version}" 
  }

  # 明确指定源文件，避免自动扫描
  spec.source_files = [
    # LibevOCClass 目录下的所有 Objective-C 文件
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevBridge.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevConnection.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevManager.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevSOCKS5Handler.{h,m}",
    
    # RustOCClass 目录下的所有 Objective-C 文件
    "TFYSwiftSSRKit/RustOCClass/TFYSSManager.{h,m}",
    "TFYSwiftSSRKit/RustOCClass/TFYVPNManager.{h,m}",
    
    # shadowsocks-rust 和 shadowsocks-libev 的头文件
    "TFYSwiftSSRKit/shadowsocks-rust/output/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libs/include/*.h"
  ]
  
  # 排除文件 - 添加这一部分来排除不需要的目录
  spec.exclude_files = [
    # 排除源代码目录，因为我们只需要编译好的库
    "TFYSwiftSSRKit/shadowsocks-libev/source/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/libipset/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/mbedtls/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/libcork/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/pcre/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/c-ares/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/libsodium/**/*",
    "TFYSwiftSSRKit/shadowsocks-libev/libev/**/*",
    "TFYSwiftSSRKit/shadowsocks-rust/src/**/*",
    
    # 排除 Cargo 文件
    "TFYSwiftSSRKit/shadowsocks-rust/Cargo.lock",
    "TFYSwiftSSRKit/shadowsocks-rust/Cargo.toml"
  ]
  
  # 公共头文件
  spec.public_header_files = [
    # LibevOCClass 目录下的所有头文件
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevBridge.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevConnection.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevManager.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevSOCKS5Handler.h",
    
    # RustOCClass 目录下的所有头文件
    "TFYSwiftSSRKit/RustOCClass/TFYSSManager.h",
    "TFYSwiftSSRKit/RustOCClass/TFYVPNManager.h",
    
    # shadowsocks-rust 和 shadowsocks-libev 的头文件
    "TFYSwiftSSRKit/shadowsocks-rust/output/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/libs/include/*.h"
  ]

  # iOS静态库
  spec.ios.vendored_libraries = [
    "TFYSwiftSSRKit/shadowsocks-rust/output/ios/libss_ios.a",
    "TFYSwiftSSRKit/shadowsocks-libev/libs/ios/libshadowsocks-libev.a",
    "TFYSwiftSSRKit/shadowsocks-libev/libs/ios/libshadowsocks-libev_ios.a"
  ]
  
  # macOS静态库
  spec.osx.vendored_libraries = [
    "TFYSwiftSSRKit/shadowsocks-rust/output/macos/libss_macos.a",
    "TFYSwiftSSRKit/shadowsocks-libev/libs/macos/libshadowsocks-libev.a",
    "TFYSwiftSSRKit/shadowsocks-libev/libs/macos/libshadowsocks-libev_macos.a"
  ]

  # 框架依赖
  spec.frameworks = [
    "Foundation",
    "NetworkExtension",
    "SystemConfiguration",
    "Security"
  ]

  spec.requires_arc = true
  spec.static_framework = true

  # 保留路径 - 只保留必要的文件
  spec.preserve_paths = [
    "TFYSwiftSSRKit/module.modulemap",
    "TFYSwiftSSRKit/shadowsocks-rust/output/include/module/module.modulemap",
    "TFYSwiftSSRKit/LICENSE",
    "TFYSwiftSSRKit/README.md",
    "TFYSwiftSSRKit/DIRECTORY_STRUCTURE.md"
  ]
  
  # 模块映射
  spec.module_map = "TFYSwiftSSRKit/module.modulemap"

  # 构建设置
  spec.pod_target_xcconfig = {
    'VALID_ARCHS[sdk=iphoneos*]' => 'arm64',
    'VALID_ARCHS[sdk=macosx*]' => 'arm64',
    'ENABLE_BITCODE' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=macosx*]' => '',
    'LIBRARY_SEARCH_PATHS' => [
      '$(inherited)',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/output/ios',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/output/macos',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libs/ios',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libs/macos'
    ].join(' '),
    'HEADER_SEARCH_PATHS' => [
      '$(inherited)',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/output/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/libs/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/LibevOCClass',
      '$(PODS_ROOT)/TFYSwiftSSRKit/RustOCClass'
    ].join(' '),
    'CLANG_ENABLE_MODULES' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-ObjC'
  }

  spec.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=macosx*]' => ''
  }

  # 添加依赖
  spec.dependency 'CocoaAsyncSocket'
  spec.dependency 'MMWormhole'
end