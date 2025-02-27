source 'https://github.com/CocoaPods/Specs.git'

# 设置iOS和macOS平台
platform :ios, '15.0'

# 忽略所有警告
inhibit_all_warnings!

# 使用静态框架
use_frameworks! :linkage => :static

# 禁用未使用的 master specs repo 警告
install! 'cocoapods', 
  :warn_for_unused_master_specs_repo => false,
  :generate_multiple_pod_projects => true,
  :disable_input_output_paths => true

target 'TFYSwiftSSRUilt' do
  # 使用本地的 TFYSwiftSSRKit
  pod 'TFYSwiftSSRKit', :path => './'
  pod 'CocoaAsyncSocket'
  pod 'MMWormhole'
  
  target 'PacketSwift' do
    pod 'TFYSwiftSSRKit', :path => './'
    pod 'CocoaAsyncSocket'
    pod 'MMWormhole'
  end
end

# 针对 Apple Silicon 和 Intel 芯片的设置
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # iOS 模拟器设置
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = ''
      
      # 设置最低部署版本
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'
      
      # 禁用 bitcode
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      
      # Swift 版本
      if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.framework"
        config.build_settings['SWIFT_VERSION'] = '5.0'
      end
      
      # 添加这些设置
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      config.build_settings['SKIP_INSTALL'] = 'NO'
      config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
      config.build_settings['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
      
      # 确保支持 arm64 和 x86_64 架构
      config.build_settings['VALID_ARCHS'] = 'arm64 x86_64'
      
      # 模块化支持
      config.build_settings['DEFINES_MODULE'] = 'YES'
      config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
      
      # 确保 Swift 可以找到 Objective-C 模块
      config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
      
      # 添加链接器标志
      config.build_settings['OTHER_LDFLAGS'] = '$(inherited) -ObjC -lc++'
    end
  end
end

