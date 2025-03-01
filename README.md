# TFYSwiftSSRKit

TFYSwiftSSRKit 是一个用于 iOS 和 macOS 的 Shadowsocks/SSR 客户端框架，支持 Rust 和 C 两种实现。

## 特性

- 支持 Shadowsocks-libev (C) 和 Shadowsocks-rust 两种实现
- 提供统一的 API 接口
- 支持 TCP 和 UDP 代理
- 支持 NAT 穿透 (仅 libev 实现)
- 支持 HTTP 代理 (仅 libev 实现)
- 支持 Swift 和 Objective-C

## 安装

### CocoaPods

```ruby
pod 'TFYSwiftSSRKit'
```

### 手动安装

1. 将 TFYSwiftSSRKit 目录添加到你的项目中
2. 添加必要的依赖库

## 使用方法

### 基本用法

```swift
import TFYSwiftSSRKit

// 创建配置
let config = TFYConfig(server: "your_server", port: 8388, method: "aes-256-gcm", password: "your_password")

// 启动代理
TFYProxyService.shared().start(config: config) { error in
    if let error = error {
        print("启动失败: \(error.localizedDescription)")
    } else {
        print("代理已启动")
    }
}

// 停止代理
TFYProxyService.shared().stop { error in
    if let error = error {
        print("停止失败: \(error.localizedDescription)")
    } else {
        print("代理已停止")
    }
}
```

### 高级用法

```swift
// 配置高级选项
let config = TFYConfig(server: "your_server", port: 8388, method: "aes-256-gcm", password: "your_password")
config.preferredCore = .rust  // 使用 Rust 实现
config.natEnabled = true      // 启用 NAT 穿透 (仅 libev 实现)
config.httpEnabled = true     // 启用 HTTP 代理 (仅 libev 实现)
config.httpPort = 8118        // 设置 HTTP 代理端口

// 监听代理状态变化
class ProxyDelegate: TFYProxyServiceDelegate {
    func proxyService(_ service: TFYProxyService, didChangeState state: TFYProxyState) {
        switch state {
        case .stopped:
            print("代理已停止")
        case .starting:
            print("代理正在启动")
        case .running:
            print("代理正在运行")
        case .stopping:
            print("代理正在停止")
        @unknown default:
            break
        }
    }
    
    func proxyService(_ service: TFYProxyService, didUpdateTraffic upload: UInt64, download: UInt64) {
        print("上传: \(upload) 字节, 下载: \(download) 字节")
    }
    
    func proxyService(_ service: TFYProxyService, didEncounterError error: Error) {
        print("代理错误: \(error.localizedDescription)")
    }
}

// 设置代理
let delegate = ProxyDelegate()
TFYProxyService.shared().delegate = delegate
```

## 架构

TFYSwiftSSRKit 由以下几个主要部分组成：

- **Base**: 基础类型、配置和错误处理
- **Core**: 核心协议和实现 (Rust 和 C)
- **Service**: 代理服务实现

## 许可证

MIT