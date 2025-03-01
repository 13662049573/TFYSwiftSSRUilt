# TFYSwiftSSRKit

TFYSwiftSSRKit 是一个用于 iOS 和 macOS 的 Shadowsocks/SSR 客户端框架，支持 Rust 和 C 两种实现。

## 特性

- 支持 Shadowsocks-libev (C) 和 Shadowsocks-rust 两种实现
- 提供统一的 API 接口
- 支持 TCP 和 UDP 代理
- 支持 NAT 穿透 (仅 libev 实现)
- 支持 HTTP 代理 (仅 libev 实现)
- 支持基于规则的路由
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

### 基于规则的路由

TFYSwiftSSRKit 提供了强大的基于规则的路由系统，允许您根据主机、IP 或 URL 模式选择性地通过代理路由流量。

```swift
import TFYSwiftSSRKit

// 创建启用规则路由的配置
let config = TFYConfig(server: "your_server", port: 8388, method: "aes-256-gcm", password: "your_password")
config.ruleEnabled = true

// 获取规则管理器
let ruleManager = TFYRuleManager.shared()

// 创建黑名单规则集
let blacklistRuleSet = TFYRuleSet(name: "我的黑名单", type: .blacklist)

// 添加一些规则
blacklistRuleSet.addRule(TFYRule(pattern: "facebook.com", type: .host))
blacklistRuleSet.addRule(TFYRule(pattern: "twitter.com", type: .host))
blacklistRuleSet.addRule(TFYRule(pattern: "*.google.com", type: .wildcard))

// 将规则集添加到管理器
ruleManager.addRuleSet(blacklistRuleSet)

// 设置活动规则集
config.activeRuleSet = blacklistRuleSet.name

// 启动带有基于规则路由的代理服务
let proxyService = TFYProxyService.shared()
proxyService.start(config: config) { error in
    if let error = error {
        print("启动失败: \(error.localizedDescription)")
    } else {
        print("代理已启动，启用基于规则的路由")
    }
}

// 检查主机是否应该使用代理
let shouldProxy = proxyService.shouldProxy(host: "facebook.com")
print("是否应该代理 facebook.com: \(shouldProxy)") // true

let shouldNotProxy = proxyService.shouldProxy(host: "example.com")
print("是否应该代理 example.com: \(shouldNotProxy)") // false
```

### 规则类型

TFYSwiftSSRKit 支持多种规则类型：

- **主机**：精确的主机匹配（例如，"example.com"）
- **IP**：IP 地址匹配（例如，"192.168.1.1"）
- **CIDR**：CIDR 表示法的 IP 范围（例如，"192.168.1.0/24"）
- **通配符**：通配符匹配（例如，"*.example.com"）
- **正则表达式**：正则表达式匹配（例如，"^(.*\\.)?example\\.com$"）

### 规则集类型

- **黑名单**：只有匹配规则的主机才会通过代理
- **白名单**：只有不匹配规则的主机才会通过代理
- **自定义**：每条规则指定是否通过代理或直接连接

### 高级用法

```swift
// 配置高级选项
let config = TFYConfig(server: "your_server", port: 8388, method: "aes-256-gcm", password: "your_password")
config.preferredCore = .rust  // 使用 Rust 实现
config.natEnabled = true      // 启用 NAT 穿透 (仅 libev 实现)
config.httpEnabled = true     // 启用 HTTP 代理 (仅 libev 实现)
config.httpPort = 8118        // 设置 HTTP 代理端口
config.ruleEnabled = true     // 启用基于规则的路由

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
    
    func proxyService(_ service: TFYProxyService, didMatchHost host: String, result: TFYRuleMatchResult, ruleSet: TFYRuleSet?) {
        print("主机 \(host) 匹配结果: \(result), 规则集: \(ruleSet?.name ?? "无")")
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
- **Rules**: 基于规则的路由系统

## 规则模块

规则模块由以下几个主要组件组成：

- **TFYSSRule**: 单个规则，包含匹配模式和类型
- **TFYSSRuleSet**: 规则集合，可以是黑名单、白名单或自定义类型
- **TFYSSRuleManager**: 管理多个规则集，提供加载/保存和匹配功能

### 创建和管理规则

```swift
// 创建规则
let hostRule = TFYRule(pattern: "example.com", type: .host)
let wildcardRule = TFYRule(pattern: "*.google.com", type: .wildcard)
let cidrRule = TFYRule(pattern: "192.168.1.0/24", type: .cidr)
let regexRule = TFYRule(pattern: "^(.*\\.)?facebook\\.com$", type: .regex)

// 创建规则集
let blacklist = TFYRuleSet(name: "黑名单", type: .blacklist)
blacklist.addRule(hostRule)
blacklist.addRule(wildcardRule)

// 添加到规则管理器
TFYRuleManager.shared().addRuleSet(blacklist)

// 保存规则集到文件
TFYRuleManager.shared().saveRuleSets()

// 从文件加载规则集
TFYRuleManager.shared().loadRuleSets()

// 创建预定义的规则集
let gfwList = TFYRuleManager.shared().createGFWList()
let chinaList = TFYRuleManager.shared().createChinaList()
let privacyList = TFYRuleManager.shared().createPrivacyRules()
```

## 许可证

MIT