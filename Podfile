source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '15.0'

# 忽略所有警告
inhibit_all_warnings!

# 使用 framework 而不是 static library
use_frameworks! :linkage => :static

# 禁用未使用的 master specs repo 警告
install! 'cocoapods', 
  :warn_for_unused_master_specs_repo => false,
  :generate_multiple_pod_projects => true,
  :disable_input_output_paths => true

target 'TFYSwiftSSRUilt' do
  # 使用本地的 TFYSwiftSSRKit
  pod 'TFYSwiftSSRKit', :path => './'
  
  target 'PacketSwift' do
    pod 'TFYSwiftSSRKit', :path => './'
  end
end

# 针对 M1 芯片的设置
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # 启用 ARM64 架构
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      
      # 设置最低部署版本
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      
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
      
    end
  end
end

