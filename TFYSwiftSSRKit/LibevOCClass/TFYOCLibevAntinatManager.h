 //
//  TFYOCLibevAntinatManager.h
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Antinat连接类型枚举
typedef NS_ENUM(NSInteger, TFYAntinatProxyType) {
    TFYAntinatProxyTypeDirect = 0,   // 直连模式
    TFYAntinatProxyTypeSOCKS4 = 4,   // SOCKS4代理
    TFYAntinatProxyTypeSOCKS5 = 5,   // SOCKS5代理
    TFYAntinatProxyTypeHTTPS = 1     // HTTPS代理
} NS_SWIFT_NAME(AntinatProxyType);

// Antinat认证方式枚举
typedef NS_ENUM(NSInteger, TFYAntinatAuthScheme) {
    TFYAntinatAuthSchemeAnonymous = 1,   // 匿名认证
    TFYAntinatAuthSchemeCleartext = 2,   // 明文认证
    TFYAntinatAuthSchemeCHAP = 3         // CHAP认证
} NS_SWIFT_NAME(AntinatAuthScheme);

// Antinat连接配置
NS_SWIFT_NAME(AntinatConfig)
@interface TFYAntinatConfig : NSObject

@property (nonatomic, copy, nonnull) NSString *proxyHost;      // 代理服务器地址
@property (nonatomic, assign) int proxyPort;                   // 代理服务器端口
@property (nonatomic, assign) TFYAntinatProxyType proxyType;   // 代理类型
@property (nonatomic, copy, nullable) NSString *username;      // 用户名
@property (nonatomic, copy, nullable) NSString *password;      // 密码
@property (nonatomic, assign) BOOL isBlocking;                 // 是否阻塞模式
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *authSchemes; // 认证方式

// 便捷初始化方法
+ (instancetype)configWithProxyHost:(nonnull NSString *)proxyHost
                          proxyPort:(int)proxyPort
                          proxyType:(TFYAntinatProxyType)proxyType;

@end

// Antinat连接代理协议
NS_SWIFT_NAME(LibevAntinatConnectionDelegate)
@protocol TFYOCLibevAntinatConnectionDelegate <NSObject>

@optional
// 连接状态变化回调
- (void)antinatConnectionDidConnect;
// 连接错误回调
- (void)antinatConnectionDidFailWithError:(NSError *)error;
// 接收到数据回调
- (void)antinatConnectionDidReceiveData:(NSData *)data;
// 连接关闭回调
- (void)antinatConnectionDidClose;

@end

// Antinat连接类
NS_SWIFT_NAME(LibevAntinatConnection)
@interface TFYOCLibevAntinatConnection : NSObject

// 连接配置
@property (nonatomic, strong, readonly, nonnull) TFYAntinatConfig *config;
// 远程主机
@property (nonatomic, copy, readonly, nonnull) NSString *remoteHost;
// 远程端口
@property (nonatomic, assign, readonly) uint16_t remotePort;
// 连接标识符
@property (nonatomic, copy, readonly, nonnull) NSString *identifier;
// 代理对象
@property (nonatomic, weak, nullable) id<TFYOCLibevAntinatConnectionDelegate> delegate;

// 初始化方法
- (instancetype)initWithConfig:(nonnull TFYAntinatConfig *)config
                    remoteHost:(nonnull NSString *)remoteHost
                    remotePort:(uint16_t)remotePort;

// 连接到远程主机
- (BOOL)connect;
// 发送数据
- (BOOL)sendData:(nonnull NSData *)data;
// 接收数据
- (NSData *)receiveDataWithTimeout:(NSTimeInterval)timeout;
// 关闭连接
- (void)close;

@end

// Antinat管理器类
NS_SWIFT_NAME(LibevAntinatManager)
@interface TFYOCLibevAntinatManager : NSObject

// 单例方法
+ (instancetype)sharedManager;

// 创建新连接
- (nonnull TFYOCLibevAntinatConnection *)createConnectionWithConfig:(nonnull TFYAntinatConfig *)config
                                                         remoteHost:(nonnull NSString *)remoteHost
                                                         remotePort:(uint16_t)remotePort;

// 获取所有活跃连接
- (nonnull NSArray<TFYOCLibevAntinatConnection *> *)activeConnections;
// 根据标识符获取连接
- (nullable TFYOCLibevAntinatConnection *)connectionWithIdentifier:(nonnull NSString *)identifier;
// 关闭所有连接
- (void)closeAllConnections;

// 解析主机名
- (nullable NSArray<NSString *> *)resolveHostname:(nonnull NSString *)hostname;

@end

NS_ASSUME_NONNULL_END