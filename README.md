# TFYSwiftSSRKit

TFYSwiftSSRKit 是一个用于 iOS 的 Shadowsocks-libev 封装库，提供了简单的 Swift API 来管理 Shadowsocks 代理连接。

## 功能特性

- 支持 Shadowsocks 所有加密方法
- 简单的 API 接口
- 自动内存管理
- 支持后台运行
- 支持 TCP 和 UDP 代理

## 安装要求

- iOS 15.0+
- Xcode 13.0+
- Swift 5.0+

## 使用方法

1. 初始化 SSRManager：

```swift
let ssrManager = SSRManager()
```

2. 创建配置：

```swift
let config = SSRManager.Configuration(
    remoteHost: "your.server.com",
    remotePort: 8388,
    localAddress: "127.0.0.1",
    localPort: 1080,
    password: "your_password",
    method: "aes-256-cfb",
    timeout: 600
)
```

3. 启动代理服务：

```swift
let success = ssrManager.start(with: config)
if success {
    print("SSR代理服务已启动")
} else {
    print("SSR代理服务启动失败")
}
```

4. 停止代理服务：

```swift
ssrManager.stop()
```

## 示例代码

查看 `SSRExample.swift` 文件获取完整的使用示例。

## 注意事项

- 确保在使用前正确配置服务器信息
- 建议在后台任务中启动代理服务
- 注意内存管理，使用完毕后调用 stop() 方法

## 支持的加密方法

- aes-256-cfb
- aes-128-cfb
- chacha20
- chacha20-ietf
- aes-256-gcm
- aes-128-gcm
- chacha20-ietf-poly1305
- xchacha20-ietf-poly1305

## 许可证

本项目基于 GPLv3 许可证开源。 