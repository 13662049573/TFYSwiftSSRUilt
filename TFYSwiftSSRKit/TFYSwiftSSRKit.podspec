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
                    
  spec.homepage     = "https://github.com/13662049573/TFYSwiftSSRUilt"

  spec.license      = { :type => "MIT", :file => "LICENSE" }
  
  spec.author       = { "田风有" => "420144542@qq.com" }
  
  spec.ios.deployment_target = "15.0"
  spec.osx.deployment_target = "12.0"
  spec.swift_version = "5.0"
  
  spec.source       = { :git => "https://github.com/13662049573/TFYSwiftSSRUilt.git", :tag => "#{spec.version}" }
  
  # Swift 源文件和头文件
  spec.source_files = "Classes/**/*"
  
  # 资源文件
  spec.resource_bundles = {
    'TFYSwiftSSRKit' => ["Resources/**/*"]
  }
  
  # 系统框架依赖
  spec.framework = "Network"
  spec.framework = "SystemConfiguration"
  
  # 编译设置
  spec.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/shadowsocks/**/*',
      '$(PODS_TARGET_SRCROOT)/libsodium/**/*',
      '$(PODS_TARGET_SRCROOT)/openssl/**/*',
      '$(PODS_TARGET_SRCROOT)/libmaxminddb/**/*'
    ],
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/shadowsocks/**/*',
      '$(PODS_TARGET_SRCROOT)/libsodium/**/*',
      '$(PODS_TARGET_SRCROOT)/openssl/**/*',
      '$(PODS_TARGET_SRCROOT)/libmaxminddb/**/*'
    ],
    'SWIFT_INCLUDE_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/shadowsocks/**/*',
      '$(PODS_TARGET_SRCROOT)/libsodium/**/*',
      '$(PODS_TARGET_SRCROOT)/openssl/**/*',
      '$(PODS_TARGET_SRCROOT)/libmaxminddb/**/*'
    ],
    'ENABLE_BITCODE' => 'NO'
  }
  
  # Swift 模块映射
  spec.module_map = 'module.modulemap'
end 
