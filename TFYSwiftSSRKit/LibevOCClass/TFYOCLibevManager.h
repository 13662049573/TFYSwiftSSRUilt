//
//  TFYOCLibevManager.h
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import <Foundation/Foundation.h>

// 前向声明
@class TFYAntinatConfig;
@class TFYOCLibevAntinatConnection;
@class TFYPrivoxyFilterRule;

NS_ASSUME_NONNULL_BEGIN

// 代理模式枚举
typedef NS_ENUM(NSInteger, TFYProxyMode) {
    TFYProxyModeGlobal = 0,    // 全局模式
    TFYProxyModeAutomatic = 1, // 自动模式（根据规则判断）
    TFYProxyModeDirect = 2     // 直连模式
} NS_SWIFT_NAME(ProxyMode);

// 加速器状态枚举
typedef NS_ENUM(NSInteger, TFYProxyStatus) {
    TFYProxyStatusStopped = 0,  // 已停止
    TFYProxyStatusStarting = 1, // 正在启动
    TFYProxyStatusRunning = 2,  // 运行中
    TFYProxyStatusStopping = 3, // 正在停止
    TFYProxyStatusError = 4     // 错误状态
} NS_SWIFT_NAME(ProxyStatus);

// 加速器配置模型
NS_SWIFT_NAME(ProxyConfig)
@interface TFYProxyConfig : NSObject

@property (nonatomic, copy, nonnull) NSString *serverHost;     // 服务器地址
@property (nonatomic, assign) int serverPort;         // 服务器端口
@property (nonatomic, copy, nonnull) NSString *password;       // 密码
@property (nonatomic, copy, nonnull) NSString *method;         // 加密方法
@property (nonatomic, copy, nonnull) NSString *localAddress;   // 本地地址
@property (nonatomic, assign) int localPort;          // 本地端口
@property (nonatomic, assign) int timeout;            // 超时时间（秒）
@property (nonatomic, assign) BOOL enableUDP;         // 是否启用UDP
@property (nonatomic, assign) BOOL enableFastOpen;    // 是否启用TCP Fast Open
@property (nonatomic, assign) BOOL enableMPTCP;       // 是否启用多路径TCP
@property (nonatomic, copy, nullable) NSString *aclFilePath; // ACL规则文件路径
@property (nonatomic, copy, nullable) NSString *logFilePath; // 日志文件路径
@property (nonatomic, assign) int mtu;                // MTU值
@property (nonatomic, assign) BOOL verbose;           // 是否启用详细日志

// 便捷初始化方法
+ (instancetype)configWithServerHost:(nonnull NSString *)serverHost
                          serverPort:(int)serverPort
                            password:(nonnull NSString *)password
                              method:(nonnull NSString *)method;

@end

// 代理管理器代理协议
NS_SWIFT_NAME(LibevManagerDelegate)
@protocol TFYOCLibevManagerDelegate <NSObject>

@optional
// 代理状态变化回调
- (void)proxyStatusDidChange:(TFYProxyStatus)status;
// 代理错误回调
- (void)proxyDidEncounterError:(NSError *)error;
// 流量统计回调
- (void)proxyTrafficUpdate:(uint64_t)uploadBytes downloadBytes:(uint64_t)downloadBytes;
// 日志回调
- (void)proxyLogMessage:(NSString *)message level:(int)level;

@end

// 主管理器类
NS_SWIFT_NAME(LibevManager)
@interface TFYOCLibevManager : NSObject

// 单例方法
+ (instancetype)sharedManager;

// 当前代理状态
@property (nonatomic, assign, readonly) TFYProxyStatus status;
// 当前代理模式
@property (nonatomic, assign) TFYProxyMode proxyMode;
// 代理配置
@property (nonatomic, strong, nullable) TFYProxyConfig *config;
// 代理对象
@property (nonatomic, weak, nullable) id<TFYOCLibevManagerDelegate> delegate;

// 启动代理
- (BOOL)startProxy;
// 停止代理
- (void)stopProxy;
// 重启代理
- (BOOL)restartProxy;

// 测试服务器延迟（毫秒），-1表示超时或错误
- (void)testServerLatency:(void(^)(NSTimeInterval latency, NSError * _Nullable error))completion;

// 获取当前上传和下载速度（字节/秒）
- (void)getCurrentSpeed:(void(^)(uint64_t uploadSpeed, uint64_t downloadSpeed))completion;

// 设置全局代理（仅macOS）
#if TARGET_OS_OSX
- (BOOL)setupGlobalProxy;
- (BOOL)removeGlobalProxy;
#endif

#pragma mark - Antinat方法

// 创建Antinat连接
- (TFYOCLibevAntinatConnection *)createAntinatConnectionWithConfig:(TFYAntinatConfig *)config
                                                        remoteHost:(NSString *)remoteHost
                                                        remotePort:(uint16_t)remotePort;

// 获取所有活跃的Antinat连接
- (NSArray<TFYOCLibevAntinatConnection *> *)activeAntinatConnections;

// 根据标识符获取Antinat连接
- (nullable TFYOCLibevAntinatConnection *)antinatConnectionWithIdentifier:(NSString *)identifier;

// 关闭所有Antinat连接
- (void)closeAllAntinatConnections;

// 解析主机名
- (nullable NSArray<NSString *> *)resolveHostname:(NSString *)hostname;

#pragma mark - Privoxy方法

// 添加Privoxy过滤规则
- (BOOL)addPrivoxyFilterRule:(TFYPrivoxyFilterRule *)rule;

// 移除Privoxy过滤规则
- (BOOL)removePrivoxyFilterRuleWithPattern:(NSString *)pattern;

// 获取所有Privoxy过滤规则
- (NSArray<TFYPrivoxyFilterRule *> *)allPrivoxyFilterRules;

// 清除所有Privoxy过滤规则
- (BOOL)clearAllPrivoxyFilterRules;

// 切换Privoxy过滤状态
- (BOOL)togglePrivoxyFiltering:(BOOL)enabled;

// 切换Privoxy压缩状态
- (BOOL)togglePrivoxyCompression:(BOOL)enabled;

// 生成Privoxy配置文件
- (BOOL)generatePrivoxyConfigFile;

// 加载Privoxy配置文件
- (BOOL)loadPrivoxyConfigFile:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END