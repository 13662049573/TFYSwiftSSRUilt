# TFYSwiftSSRKit

TFYSwiftSSRKit是一个iOS/macOS通用的网络加速器库，基于shadowsocks-libev实现，支持iOS 15+和macOS 12+。

## 功能特点

- 支持iOS 15+和macOS 12+
- 支持多种加密方法
- 支持TCP和UDP协议
- 支持SOCKS5代理
- 支持流量统计
- 支持服务器延迟测试
- 支持全局代理设置（仅macOS）
- 提供Swift和Objective-C接口

## 安装

### CocoaPods

```ruby
pod 'TFYSwiftSSRKit'
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/TFYSwiftSSRKit.git", .upToNextMajor(from: "1.0.0"))
]
```

## 使用方法

### Swift

```swift
import TFYSwiftSSRKit

// 启动加速器
let success = TFYLibevExampleController.shared.startAccelerator(
    serverHost: "your_server_host",
    serverPort: 8388,
    password: "your_password",
    method: "aes-256-gcm",
    localPort: 1080
)

// 停止加速器
TFYLibevExampleController.shared.stopAccelerator()

// 重启加速器
TFYLibevExampleController.shared.restartAccelerator()

// 测试服务器延迟
TFYLibevExampleController.shared.testServerLatency { latency, error in
    if let error = error {
        print("测试延迟失败: \(error.localizedDescription)")
    } else {
        print("服务器延迟: \(latency) 毫秒")
    }
}

// 获取当前状态
let status = TFYLibevExampleController.shared.currentStatus()

// 获取当前上传和下载速度
let uploadSpeed = TFYLibevExampleController.shared.currentUploadSpeed()
let downloadSpeed = TFYLibevExampleController.shared.currentDownloadSpeed()

// 获取总上传和下载字节数
let totalUploadBytes = TFYLibevExampleController.shared.totalUploadBytes()
let totalDownloadBytes = TFYLibevExampleController.shared.totalDownloadBytes()

// 获取连接统计信息
let statistics = TFYLibevExampleController.shared.connectionStatistics()

// 获取所有活跃连接
let connections = TFYLibevExampleController.shared.activeConnections()

// 关闭所有连接
TFYLibevExampleController.shared.closeAllConnections()

// 设置全局代理（仅macOS）
#if os(macOS)
TFYLibevExampleController.shared.setupGlobalProxy()
TFYLibevExampleController.shared.removeGlobalProxy()
#endif

// 监听通知
NotificationCenter.default.addObserver(self, selector: #selector(handleStatusChange(_:)), name: NSNotification.Name("TFYAcceleratorStatusChangeNotification"), object: nil)
NotificationCenter.default.addObserver(self, selector: #selector(handleError(_:)), name: NSNotification.Name("TFYAcceleratorErrorNotification"), object: nil)
NotificationCenter.default.addObserver(self, selector: #selector(handleTrafficUpdate(_:)), name: NSNotification.Name("TFYAcceleratorTrafficUpdateNotification"), object: nil)
NotificationCenter.default.addObserver(self, selector: #selector(handleSpeedUpdate(_:)), name: NSNotification.Name("TFYAcceleratorSpeedUpdateNotification"), object: nil)
NotificationCenter.default.addObserver(self, selector: #selector(handleLog(_:)), name: NSNotification.Name("TFYAcceleratorLogNotification"), object: nil)

// 处理通知
@objc func handleStatusChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let statusValue = userInfo["status"] as? Int,
          let status = TFYSwiftProxyStatus(rawValue: statusValue) else {
        return
    }
    
    print("加速器状态变化: \(status)")
}

@objc func handleError(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let error = userInfo["error"] as? Error else {
        return
    }
    
    print("加速器错误: \(error.localizedDescription)")
}

@objc func handleTrafficUpdate(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let uploadBytes = userInfo["uploadBytes"] as? UInt64,
          let downloadBytes = userInfo["downloadBytes"] as? UInt64 else {
        return
    }
    
    print("总上传: \(uploadBytes) 字节, 总下载: \(downloadBytes) 字节")
}

@objc func handleSpeedUpdate(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let uploadSpeed = userInfo["uploadSpeed"] as? UInt64,
          let downloadSpeed = userInfo["downloadSpeed"] as? UInt64 else {
        return
    }
    
    print("上传速度: \(uploadSpeed) 字节/秒, 下载速度: \(downloadSpeed) 字节/秒")
}

@objc func handleLog(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let message = userInfo["message"] as? String,
          let level = userInfo["level"] as? Int else {
        return
    }
    
    print("加速器日志[\(level)]: \(message)")
}
```

### Objective-C

```objective-c
#import <TFYSwiftSSRKit/TFYSwiftSSRKit-Swift.h>

// 启动加速器
BOOL success = [[TFYLibevExampleController shared] startAcceleratorWithServerHost:@"your_server_host"
                                                                       serverPort:8388
                                                                         password:@"your_password"
                                                                           method:@"aes-256-gcm"
                                                                        localPort:1080];

// 停止加速器
[[TFYLibevExampleController shared] stopAccelerator];

// 重启加速器
[[TFYLibevExampleController shared] restartAccelerator];

// 测试服务器延迟
[[TFYLibevExampleController shared] testServerLatencyWithCompletion:^(NSTimeInterval latency, NSError * _Nullable error) {
    if (error) {
        NSLog(@"测试延迟失败: %@", error.localizedDescription);
    } else {
        NSLog(@"服务器延迟: %f 毫秒", latency);
    }
}];

// 获取当前状态
TFYSwiftProxyStatus status = [[TFYLibevExampleController shared] currentStatus];

// 获取当前上传和下载速度
uint64_t uploadSpeed = [[TFYLibevExampleController shared] currentUploadSpeed];
uint64_t downloadSpeed = [[TFYLibevExampleController shared] currentDownloadSpeed];

// 获取总上传和下载字节数
uint64_t totalUploadBytes = [[TFYLibevExampleController shared] totalUploadBytes];
uint64_t totalDownloadBytes = [[TFYLibevExampleController shared] totalDownloadBytes];

// 获取连接统计信息
NSDictionary *statistics = [[TFYLibevExampleController shared] connectionStatistics];

// 获取所有活跃连接
NSArray<TFYOCLibevConnection *> *connections = [[TFYLibevExampleController shared] activeConnections];

// 关闭所有连接
[[TFYLibevExampleController shared] closeAllConnections];

// 设置全局代理（仅macOS）
#if TARGET_OS_OSX
[[TFYLibevExampleController shared] setupGlobalProxy];
[[TFYLibevExampleController shared] removeGlobalProxy];
#endif

// 监听通知
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleStatusChange:)
                                             name:@"TFYAcceleratorStatusChangeNotification"
                                           object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleError:)
                                             name:@"TFYAcceleratorErrorNotification"
                                           object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleTrafficUpdate:)
                                             name:@"TFYAcceleratorTrafficUpdateNotification"
                                           object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleSpeedUpdate:)
                                             name:@"TFYAcceleratorSpeedUpdateNotification"
                                           object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleLog:)
                                             name:@"TFYAcceleratorLogNotification"
                                           object:nil];

// 处理通知
- (void)handleStatusChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *statusValue = userInfo[@"status"];
    
    NSLog(@"加速器状态变化: %@", statusValue);
}

- (void)handleError:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSError *error = userInfo[@"error"];
    
    NSLog(@"加速器错误: %@", error.localizedDescription);
}

- (void)handleTrafficUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *uploadBytes = userInfo[@"uploadBytes"];
    NSNumber *downloadBytes = userInfo[@"downloadBytes"];
    
    NSLog(@"总上传: %@ 字节, 总下载: %@ 字节", uploadBytes, downloadBytes);
}

- (void)handleSpeedUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *uploadSpeed = userInfo[@"uploadSpeed"];
    NSNumber *downloadSpeed = userInfo[@"downloadSpeed"];
    
    NSLog(@"上传速度: %@ 字节/秒, 下载速度: %@ 字节/秒", uploadSpeed, downloadSpeed);
}

- (void)handleLog:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *message = userInfo[@"message"];
    NSNumber *level = userInfo[@"level"];
    
    NSLog(@"加速器日志[%@]: %@", level, message);
}
```

## 支持的加密方法

- aes-128-gcm
- aes-192-gcm
- aes-256-gcm
- chacha20-ietf-poly1305
- xchacha20-ietf-poly1305
- aes-128-cfb
- aes-192-cfb
- aes-256-cfb
- aes-128-ctr
- aes-192-ctr
- aes-256-ctr
- camellia-128-cfb
- camellia-192-cfb
- camellia-256-cfb
- bf-cfb
- chacha20-ietf
- salsa20
- rc4-md5

## 架构

TFYSwiftSSRKit由以下几个主要部分组成：

1. **核心库**：基于shadowsocks-libev实现的C语言库，提供核心加密和代理功能。
2. **OC封装**：对核心库的Objective-C封装，提供更友好的接口。
3. **Swift封装**：对OC封装的Swift封装，提供更现代化的接口。
4. **示例控制器**：提供一个简单的示例控制器，展示如何使用该库。

## 依赖库

- shadowsocks-libev
- CocoaAsyncSocket
- MMWormhole

## 许可证

TFYSwiftSSRKit使用MIT许可证。详见LICENSE文件。

## 作者

TFYSwiftSSRKit由TFYSwiftSSRKit团队开发。

## 贡献

欢迎提交Pull Request和Issue。 