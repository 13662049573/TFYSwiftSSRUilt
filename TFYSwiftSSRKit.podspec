Pod::Spec.new do |s|
  s.name             = 'TFYSwiftSSRKit'
  s.version          = '1.0.0'
  s.summary          = 'A Swift wrapper for shadowsocks-libev'
  s.description      = <<-DESC
TFYSwiftSSRKit is an iOS library that provides a Swift interface for shadowsocks-libev.
It supports various encryption methods and provides a simple API for managing shadowsocks connections.
                       DESC

  s.homepage         = 'https://github.com/13662049573/TFYSwiftSSRUilt'
  s.license          = { :type => 'GPLv3', :file => 'LICENSE' }
  s.author           = { 'tianfengyou' => '420144542@qq.com' }
  s.source           = { :git => 'https://github.com/13662049573/TFYSwiftSSRUilt.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  s.source_files = [
    'TFYSwiftSSRKit/Classes/**/*.{h,m,swift}',
    'TFYSwiftSSRKit/shadowsocks/install_arm64/include/**/*.h'
  ]
  
  s.public_header_files = [
    'TFYSwiftSSRKit/Classes/**/*.h',
    'TFYSwiftSSRKit/shadowsocks/install_arm64/include/**/*.h'
  ]
  
  s.resources = [
    'TFYSwiftSSRKit/Assets/**/*',
    'Scripts/*.sh'
  ]
  
  s.ios.vendored_libraries = [
    'TFYSwiftSSRKit/shadowsocks-libev/install_arm64_ios/lib/libshadowsocks-libev_ios.a',
    'TFYSwiftSSRKit/libev/install/lib/libev.a',
    'TFYSwiftSSRKit/mbedtls/install/lib/libmbedcrypto.a',
    'TFYSwiftSSRKit/mbedtls/install/lib/libmbedtls.a',
    'TFYSwiftSSRKit/mbedtls/install/lib/libmbedx509.a',
    'TFYSwiftSSRKit/pcre/install/lib/libpcre.a',
    'TFYSwiftSSRKit/libsodium/install/lib/libsodium_ios.a',
    'TFYSwiftSSRKit/libmaxminddb/install/lib/libmaxminddb_ios.a',
    'TFYSwiftSSRKit/openssl/install/lib/libcrypto_ios.a',
    'TFYSwiftSSRKit/openssl/install/lib/libssl_ios.a'
  ]
  
  s.osx.vendored_libraries = [
    'TFYSwiftSSRKit/shadowsocks-libev/install_macos/lib/libshadowsocks-libev_macos.a',
    'TFYSwiftSSRKit/libev/install/lib/libev.a',
    'TFYSwiftSSRKit/mbedtls/install/lib/libmbedcrypto.a',
    'TFYSwiftSSRKit/mbedtls/install/lib/libmbedtls.a',
    'TFYSwiftSSRKit/mbedtls/install/lib/libmbedx509.a',
    'TFYSwiftSSRKit/pcre/install/lib/libpcre.a',
    'TFYSwiftSSRKit/libsodium/install/lib/libsodium_macos.a',
    'TFYSwiftSSRKit/libmaxminddb/install/lib/libmaxminddb_macos.a',
    'TFYSwiftSSRKit/openssl/install/lib/libcrypto_macos.a',
    'TFYSwiftSSRKit/openssl/install/lib/libssl_macos.a'
  ]
  
  s.preserve_paths = [
    'TFYSwiftSSRKit/shadowsocks/install_arm64/include/**/*.h',
    'TFYSwiftSSRKit/libev/install/include/**/*.h',
    'TFYSwiftSSRKit/mbedtls/install/include/**/*.h',
    'TFYSwiftSSRKit/pcre/install/include/**/*.h',
    'TFYSwiftSSRKit/libsodium/install/include/**/*.h',
    'TFYSwiftSSRKit/libmaxminddb/install/include/**/*.h',
    'Scripts/*.sh'
  ]
  
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/shadowsocks/install_arm64/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/libev/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/mbedtls/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/pcre/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/libsodium/install/include',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/libmaxminddb/install/include'
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/shadowsocks/install_arm64/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/libev/install/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/mbedtls/install/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/pcre/install/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/libsodium/install/lib',
      '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/libmaxminddb/install/lib'
    ].join(' ')
  }
  
  s.dependency 'CocoaAsyncSocket'
  s.dependency 'MMWormhole'
  
  s.frameworks = [
    'NetworkExtension',
    'SystemConfiguration',
    'Security',
    'CoreFoundation'
  ]
  
  s.pod_target_xcconfig = {
    'VALID_ARCHS' => 'arm64',
    'ENABLE_BITCODE' => 'NO',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_ROOT)/TFYSwiftSSRKit/TFYSwiftSSRKit/shadowsocks/install_arm64/include',
    'GCC_PREPROCESSOR_DEFINITIONS' => ['USE_SYSTEM_SHARED_LIB=1', 'WITHOUT_CARES=1']
  }
  
  s.user_target_xcconfig = {
    'VALID_ARCHS' => 'arm64',
    'ENABLE_BITCODE' => 'NO'
  }
  
  s.requires_arc = true
end