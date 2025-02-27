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

post_install do |installer| installer.pods_project.targets.each do |target|
  target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      if config.name == 'Debug'
          config.build_settings["VALID_ARCHS"] = "arm64"
        else
          config.build_settings["VALID_ARCHS"] = "arm64 arm64e"
      end
    end
  end
end
