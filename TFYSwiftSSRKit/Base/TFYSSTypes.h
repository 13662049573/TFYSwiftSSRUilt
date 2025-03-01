#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 核心类型
typedef NS_ENUM(NSInteger, TFYSSCoreType) {
    TFYSSCoreTypeRust = 0,    // Rust 核心实现
    TFYSSCoreTypeC = 1        // C 核心实现
} NS_SWIFT_NAME(TFYCoreType);

// 核心能力
typedef NS_OPTIONS(NSUInteger, TFYSSCoreCapability) {
    TFYSSCoreCapabilityNone      = 0,          // 无特殊能力
    TFYSSCoreCapabilityTCP       = 1 << 0,     // TCP 代理
    TFYSSCoreCapabilityUDP       = 1 << 1,     // UDP 代理
    TFYSSCoreCapabilityFastOpen  = 1 << 2,     // TCP 快速打开
    TFYSSCoreCapabilityNAT       = 1 << 3,     // NAT 穿透
    TFYSSCoreCapabilityHTTP      = 1 << 4      // HTTP 代理
} NS_SWIFT_NAME(TFYCoreCapability);

// 代理状态
typedef NS_ENUM(NSInteger, TFYSSProxyState) {
    TFYSSProxyStateStopped = 0,     // 已停止
    TFYSSProxyStateStarting,         // 正在启动
    TFYSSProxyStateRunning,          // 运行中
    TFYSSProxyStateStopping          // 正在停止
} NS_SWIFT_NAME(TFYProxyState);

// VPN 状态
typedef NS_ENUM(NSInteger, TFYSSVPNState) {
    TFYSSVPNStateDisconnected = 0,   // 已断开连接
    TFYSSVPNStateConnecting,         // 正在连接
    TFYSSVPNStateConnected,          // 已连接
    TFYSSVPNStateDisconnecting,      // 正在断开连接
    TFYSSVPNStateReconnecting,       // 正在重新连接
    TFYSSVPNStateInvalid             // 无效状态
} NS_SWIFT_NAME(TFYVPNState);

// NAT 类型
typedef NS_ENUM(NSInteger, TFYSSNATType) {
    TFYSSNATTypeUnknown = 0,         // 未知
    TFYSSNATTypeNone,                // 无 NAT
    TFYSSNATTypeFullCone,            // 完全锥形
    TFYSSNATTypeRestricted,          // 受限锥形
    TFYSSNATTypePortRestricted,      // 端口受限锥形
    TFYSSNATTypeSymmetric            // 对称型
} NS_SWIFT_NAME(TFYNATType);

NS_ASSUME_NONNULL_END