Pod::Spec.new do |spec|
  spec.name         = "TFYSwiftSSRKit"
  spec.version      = "1.0.1"
  spec.summary      = "iOS/macOS Shadowsocks客户端框架，集成Rust和Libev核心，支持Antinat和Privoxy"
  spec.description  = <<-DESC
                     TFYSwiftSSRKit是一个iOS/macOS框架，提供Shadowsocks客户端功能。
                     它同时支持Rust和Libev实现，以获得高性能和安全性，
                     并使用Objective-C接口包装，便于集成到iOS/macOS应用中。
                     该框架还包括用于网络连接管理的Antinat和
                     具有过滤功能的HTTP代理Privoxy。
                     DESC

  spec.homepage     = "https://github.com/13662049573/TFYSwiftSSRKit"

  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author       = { "田风有" => "420144542@qq.com" }

  spec.ios.deployment_target = '15.0'
  
  spec.osx.deployment_target = '12.0'
  
  # 使用本地路径进行验证
  spec.source       = { :git => "file:///Users/tianfengyou/Desktop/MyLibrary/TFYSwiftSSRUilt", :tag => "#{spec.version}" }

  # 明确指定源文件，避免自动扫描
  spec.source_files = [
    # 主头文件
    "TFYSwiftSSRKit/TFYSwiftSSRKit.h",
    
    # LibevOCClass 目录下的所有 Objective-C 文件
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevConnection.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevManager.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevSOCKS5Handler.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevAntinatManager.{h,m}",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevPrivoxyManager.{h,m}",
    
    # RustOCClass 目录下的所有 Objective-C 文件
    "TFYSwiftSSRKit/RustOCClass/TFYSSManager.{h,m}",
    "TFYSwiftSSRKit/RustOCClass/TFYVPNManager.{h,m}",
    
    # shadowsocks-rust 和 shadowsocks-libev 的头文件
    "TFYSwiftSSRKit/shadowsocks-rust/output/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/antinat/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/privoxy.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/config.h"
  ]
  
  # 排除文件 - 添加这一部分来排除不需要的目录
  spec.exclude_files = [
    # 排除源代码目录，因为我们只需要编译好的库
    "TFYSwiftSSRKit/shadowsocks-rust/src/**/*",
    
    # 排除 Cargo 文件
    "TFYSwiftSSRKit/shadowsocks-rust/Cargo.lock",
    "TFYSwiftSSRKit/shadowsocks-rust/Cargo.toml",
    
    # 排除 Privoxy 原始头文件，但保留我们自定义的 privoxy.h 和 config.h
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/acconfig.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/actionlist.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/actions.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/cgi.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/cgiedit.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/cgisimple.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/client-tags.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/cygwin.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/deanimate.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/encode.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/errlog.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/filters.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/gateway.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/jbsockets.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/jcc.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/list.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/loadcfg.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/loaders.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/miscutil.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/parsers.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/pcrs.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/project.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/ssl.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/ssl_common.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/ssplit.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/strptime.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/urlmatch.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/w32log.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/w32res.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/w32svrapi.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/w32taskbar.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/win32.h"
  ]
  
  # 公共头文件
  spec.public_header_files = [
    # 主头文件
    "TFYSwiftSSRKit/TFYSwiftSSRKit.h",
    
    # LibevOCClass 目录下的所有头文件
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevConnection.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevManager.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevSOCKS5Handler.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevAntinatManager.h",
    "TFYSwiftSSRKit/LibevOCClass/TFYOCLibevPrivoxyManager.h",
    
    # RustOCClass 目录下的所有头文件
    "TFYSwiftSSRKit/RustOCClass/TFYSSManager.h",
    "TFYSwiftSSRKit/RustOCClass/TFYVPNManager.h",
    
    # shadowsocks-rust 和 shadowsocks-libev 的头文件
    "TFYSwiftSSRKit/shadowsocks-rust/output/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/antinat/include/*.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/privoxy.h",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/include/config.h"
  ]

  # iOS静态库
  spec.ios.vendored_libraries = [
    "TFYSwiftSSRKit/shadowsocks-rust/output/ios/libss_ios.a",
    "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib/libshadowsocks-libev_ios.a",
    "TFYSwiftSSRKit/shadowsocks-libev/antinat/lib/libantinat_ios.a",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib/libprivoxy_ios.a"
  ]
  
  # macOS静态库
  spec.osx.vendored_libraries = [
    "TFYSwiftSSRKit/shadowsocks-rust/output/macos/libss_macos.a",
    "TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib/libshadowsocks-libev_macos.a",
    "TFYSwiftSSRKit/shadowsocks-libev/antinat/lib/libantinat_macos.a",
    "TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib/libprivoxy_macos.a"
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
    "TFYSwiftSSRKit/TFYSwiftSSRKit.h",
    "module.modulemap",
    "TFYSwiftSSRKit/module.modulemap",
    "LICENSE",
    "TFYSwiftSSRKit/README.md",
    "TFYSwiftSSRKit/DIRECTORY_STRUCTURE.md"
  ]
  
  # 模块映射 - 使用根目录的 module.modulemap
  spec.module_map = "module.modulemap"

  # 构建设置
  spec.pod_target_xcconfig = {
    'VALID_ARCHS[sdk=iphoneos*]' => 'arm64',
    'VALID_ARCHS[sdk=macosx*]' => 'arm64',
    'ENABLE_BITCODE' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=macosx*]' => '',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'MACOSX_DEPLOYMENT_TARGET' => '12.0',
    'LIBRARY_SEARCH_PATHS' => [
      '$(inherited)',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/output/ios',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/output/macos',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/antinat/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/lib'
    ].join(' '),
    'HEADER_SEARCH_PATHS' => [
      '$(inherited)',
      '$(PODS_ROOT)',
      '$(PODS_ROOT)/TFYSwiftSSRKit',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-rust/output/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/shadowsocks/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/antinat/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/shadowsocks-libev/privoxy/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/LibevOCClass',
      '$(PODS_ROOT)/TFYSwiftSSRKit/RustOCClass'
    ].join(' '),
    'CLANG_ENABLE_MODULES' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-ObjC',
    'MODULEMAP_FILE' => '$(PODS_ROOT)/module.modulemap',
    'GCC_PREPROCESSOR_DEFINITIONS' => ['$(inherited)', 'HAVE_CONFIG_H=1']
  }

  spec.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=macosx*]' => '',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'MACOSX_DEPLOYMENT_TARGET' => '12.0'
  }

  # Swift 支持
  spec.swift_version = '5.0'

  # 添加依赖
  spec.dependency 'CocoaAsyncSocket'
  spec.dependency 'MMWormhole'
end