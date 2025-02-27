# TFYSwiftSSRKit

TFYSwiftSSRKit 是一个功能强大的网络代理工具包，为 iOS 和 macOS 应用提供高性能的代理服务。该库基于 shadowsocks-libev、antinat 和 privoxy 等开源项目，提供了完整的 Objective-C 实现，同时支持 Swift 调用。

## 功能特点

- **多协议支持**：支持 Shadowsocks、SOCKS5、HTTP 等多种代理协议
- **高性能实现**：基于 C/C++ 核心库，提供高效的网络代理服务
- **完整的 API**：提供简洁易用的 Objective-C 接口，支持 Swift 调用
- **流量统计**：实时监控上传和下载流量，计算网络速度
- **HTTP 代理**：集成 Privoxy 提供 HTTP 代理服务，支持过滤规则
- **网络连接管理**：通过 Antinat 管理网络连接，支持多种代理类型
- **过滤规则**：支持自定义过滤规则，控制网络访问
- **全局代理**：在 macOS 上支持设置系统全局代理
- **服务器延迟测试**：测试服务器连接延迟，优化服务器选择

## 系统要求

- iOS 15.0+ / macOS 12.0+
- Xcode 14.0+
- Swift 5.0+

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

### 基本用法

```swift
import TFYSwiftSSRKit

// 创建代理配置
let config = ProxyConfig(serverHost: "your-server.com", 
                         serverPort: 8388, 
                         password: "your-password", 
                         method: "aes-256-gcm")

// 获取代理管理器
let manager = LibevManager.sharedManager()

// 设置代理配置
manager.config = config

// 设置代理模式
manager.proxyMode = .global

// 启动代理
manager.startProxy()

// 停止代理
manager.stopProxy()
```

### 代理状态监听

```swift
// 设置代理
class YourClass: LibevManagerDelegate {
    
    func setup() {
        let manager = LibevManager.sharedManager()
        manager.delegate = self
    }
    
    // 代理状态变化回调
    func proxyStatusDidChange(_ status: ProxyStatus) {
        switch status {
        case .stopped:
            print("代理已停止")
        case .starting:
            print("代理正在启动")
        case .running:
            print("代理正在运行")
        case .stopping:
            print("代理正在停止")
        case .error:
            print("代理发生错误")
        @unknown default:
            break
        }
    }
    
    // 代理错误回调
    func proxyDidEncounterError(_ error: Error) {
        print("代理错误: \(error.localizedDescription)")
    }
    
    // 流量统计回调
    func proxyTrafficUpdate(_ uploadBytes: UInt64, downloadBytes: UInt64) {
        print("上传: \(uploadBytes) 字节, 下载: \(downloadBytes) 字节")
    }
    
    // 日志回调
    func proxyLogMessage(_ message: String, level: Int32) {
        print("日志: \(message), 级别: \(level)")
    }
}
```

### HTTP 代理和过滤规则

```swift
// 添加 HTTP 过滤规则
let rule = PrivoxyFilterRule(pattern: "example.com", action: .block, description: "屏蔽示例网站")
LibevManager.sharedManager().addPrivoxyFilterRule(rule)

// 切换过滤状态
LibevManager.sharedManager().togglePrivoxyFiltering(true)

// 切换压缩状态
LibevManager.sharedManager().togglePrivoxyCompression(true)

// 清除所有过滤规则
LibevManager.sharedManager().clearAllPrivoxyFilterRules()
```

### Antinat 连接管理

```swift
// 创建 Antinat 配置
let antinatConfig = AntinatConfig(proxyHost: "proxy.example.com", proxyPort: 1080, proxyType: .socks5)
antinatConfig.username = "username"
antinatConfig.password = "password"

// 创建连接
let connection = LibevManager.sharedManager().createAntinatConnection(with: antinatConfig, 
                                                                     remoteHost: "target.com", 
                                                                     remotePort: 80)

// 连接到远程主机
connection.connect()

// 发送数据
let data = "Hello, World!".data(using: .utf8)!
connection.send(data)

// 关闭连接
connection.close()

// 获取所有活跃连接
let connections = LibevManager.sharedManager().activeAntinatConnections()

// 关闭所有连接
LibevManager.sharedManager().closeAllAntinatConnections()
```

## 架构

TFYSwiftSSRKit 由以下主要组件组成：

1. **TFYOCLibevManager**：核心管理器，负责协调各个组件的工作
2. **TFYOCLibevPrivoxyManager**：管理 Privoxy HTTP 代理服务和过滤规则
3. **TFYOCLibevAntinatManager**：管理 Antinat 网络连接和代理
4. **TFYOCLibevConnection**：通用网络连接类
5. **TFYOCLibevSOCKS5Handler**：处理 SOCKS5 协议

## 高级功能

### 测试服务器延迟

```swift
LibevManager.sharedManager().testServerLatency { (latency, error) in
    if let error = error {
        print("测试失败: \(error.localizedDescription)")
    } else {
        print("服务器延迟: \(latency) 毫秒")
    }
}
```

### 获取网络速度

```swift
LibevManager.sharedManager().getCurrentSpeed { (uploadSpeed, downloadSpeed) in
    print("上传速度: \(uploadSpeed) 字节/秒")
    print("下载速度: \(downloadSpeed) 字节/秒")
}
```

### 设置全局代理（仅 macOS）

```swift
#if os(macOS)
// 设置全局代理
LibevManager.sharedManager().setupGlobalProxy()

// 移除全局代理
LibevManager.sharedManager().removeGlobalProxy()
#endif
```

## 许可证

TFYSwiftSSRKit 使用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 致谢

TFYSwiftSSRKit 基于以下开源项目：

- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [antinat](http://antinat.sourceforge.net/)
- [privoxy](https://www.privoxy.org/)
- [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)
- [MMWormhole](https://github.com/mutualmobile/MMWormhole)

感谢这些项目的贡献者们！ 