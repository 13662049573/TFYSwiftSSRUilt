# TFYSwiftSSRKit 目录结构

```
TFYSwiftSSRKit/
├── README.md                           # 项目说明文档
├── DIRECTORY_STRUCTURE.md              # 目录结构说明（本文件）
├── TFYSwiftSSRKit/                     # 主项目目录
│   ├── shadowsocks-libev/              # shadowsocks-libev 库
│   │   ├── libs/                       # 编译好的库文件
│   │   │   ├── include/                # 头文件
│   │   │   │   └── shadowsocks.h       # 主头文件
│   │   │   ├── ios/                    # iOS 库文件
│   │   │   │   ├── libshadowsocks-libev.a        # 符号链接
│   │   │   │   └── libshadowsocks-libev_ios.a    # iOS 静态库
│   │   │   └── macos/                  # macOS 库文件
│   │   │       ├── libshadowsocks-libev.a        # 符号链接
│   │   │       └── libshadowsocks-libev_macos.a  # macOS 静态库
│   │   └── source/                     # 源代码
│   │       └── ...                     # 源代码文件
│   ├── c-ares/                         # c-ares 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libcares_ios.a          # iOS 静态库
│   │       └── libcares_macos.a        # macOS 静态库
│   ├── libev/                          # libev 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libev_ios.a             # iOS 静态库
│   │       └── libev_macos.a           # macOS 静态库
│   ├── libsodium/                      # libsodium 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libsodium_ios.a         # iOS 静态库
│   │       └── libsodium_macos.a       # macOS 静态库
│   ├── mbedtls/                        # mbedtls 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libmbedcrypto_ios.a     # iOS 静态库
│   │       ├── libmbedcrypto_macos.a   # macOS 静态库
│   │       ├── libmbedtls_ios.a        # iOS 静态库
│   │       ├── libmbedtls_macos.a      # macOS 静态库
│   │       ├── libmbedx509_ios.a       # iOS 静态库
│   │       └── libmbedx509_macos.a     # macOS 静态库
│   ├── pcre/                           # pcre 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libpcre_ios.a           # iOS 静态库
│   │       └── libpcre_macos.a         # macOS 静态库
│   ├── libcork/                        # libcork 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libcork_ios.a           # iOS 静态库
│   │       └── libcork_macos.a         # macOS 静态库
│   ├── libipset/                       # libipset 库
│   │   ├── include/                    # 头文件
│   │   └── lib/                        # 库文件
│   │       ├── libipset_ios.a          # iOS 静态库
│   │       └── libipset_macos.a        # macOS 静态库
│   ├── LibevOCClass/                   # Objective-C 封装类
│   │   ├── TFYOCLibevManager.h         # 管理器头文件
│   │   ├── TFYOCLibevManager.m         # 管理器实现文件
│   │   ├── TFYOCLibevConnection.h      # 连接类头文件
│   │   ├── TFYOCLibevConnection.m      # 连接类实现文件
│   │   ├── TFYOCLibevSOCKS5Handler.h   # SOCKS5处理器头文件
│   │   ├── TFYOCLibevSOCKS5Handler.m   # SOCKS5处理器实现文件
│   │   ├── TFYOCLibevBridge.h          # 桥接类头文件
│   │   ├── TFYOCLibevBridge.m          # 桥接类实现文件
│   │   ├── TFYSwiftSSRKit-Bridging-Header.h  # Swift 桥接头文件
│   │   ├── TFYSwiftLibevManager.swift  # Swift 封装类
│   │   └── TFYLibevExampleController.swift  # 示例控制器
└── Scripts/                            # 构建脚本
    ├── build-shadowsocks-libev.sh      # shadowsocks-libev 构建脚本
    ├── build-c-ares.sh                 # c-ares 构建脚本
    ├── build-libev.sh                  # libev 构建脚本
    ├── build-libsodium.sh              # libsodium 构建脚本
    ├── build-mbedtls.sh                # mbedtls 构建脚本
    ├── build-pcre.sh                   # pcre 构建脚本
    ├── build-libcork.sh                # libcork 构建脚本
    └── build-libipset.sh               # libipset 构建脚本
```

## 目录说明

### 主要组件

1. **shadowsocks-libev**: 核心库，提供加密和代理功能
2. **依赖库**: c-ares, libev, libsodium, mbedtls, pcre, libcork, libipset
3. **Objective-C 封装类**: 对核心库的 Objective-C 封装
4. **Swift 封装类**: 对 Objective-C 封装的 Swift 封装
5. **示例项目**: 展示如何使用该库的示例应用

### 文件说明

- **TFYOCLibevManager**: 管理器类，负责启动和停止代理服务
- **TFYOCLibevConnection**: 连接类，负责处理网络连接
- **TFYOCLibevSOCKS5Handler**: SOCKS5 处理器，负责处理 SOCKS5 协议
- **TFYOCLibevBridge**: 桥接类，用于 Swift 调用 Objective-C 代码
- **TFYSwiftLibevManager**: Swift 封装类，提供更现代化的接口
- **TFYLibevExampleController**: 示例控制器，展示如何使用该库
- **TFYSwiftSSRKitExample**: 示例应用，提供完整的用户界面

### 构建脚本

构建脚本用于编译各个依赖库，生成 iOS 和 macOS 的静态库文件。每个脚本都会生成对应库的 iOS 和 macOS 版本，并将它们放置在相应的目录中。 