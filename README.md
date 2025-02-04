# iOS/macOS SSR Network Accelerator

这是一个基于SSR协议的网络加速器项目，支持iOS和macOS平台。

## 项目依赖
本项目依赖以下开源库：
- libsodium (最新版本：1.0.20) - 用于加密操作
- libmaxminddb (最新版本：1.7.1) - 用于GeoIP查询
- OpenSSL (最新版本：3.1.4) - 用于SSL/TLS支持
- shadowsocks-libev (最新版本：3.4.0) - SSR核心功能
- Antinat (最新版本：0.93) - NAT穿透
- Privoxy (最新版本：3.0.34) - 代理服务器

## 编译环境要求
- Xcode 15.0+
- iOS 15.0+
- macOS 12.0+
- CMake 3.21+
- Autoconf
- Automake
- Libtool

## 项目结构 