//
//  TFYOCLibevPrivoxyManager.h
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Privoxy过滤动作枚举
typedef NS_ENUM(NSInteger, TFYPrivoxyFilterAction) {
    TFYPrivoxyFilterActionBlock = 0,     // 阻止
    TFYPrivoxyFilterActionAllow = 1,     // 允许
    TFYPrivoxyFilterActionFilter = 2     // 过滤
} NS_SWIFT_NAME(PrivoxyFilterAction);

// Privoxy配置模型
NS_SWIFT_NAME(PrivoxyConfig)
@interface TFYPrivoxyConfig : NSObject

@property (nonatomic, copy, nonnull) NSString *listenAddress;      // 监听地址
@property (nonatomic, assign) int listenPort;                      // 监听端口
@property (nonatomic, copy, nullable) NSString *forwardSOCKS5Host; // SOCKS5转发主机
@property (nonatomic, assign) int forwardSOCKS5Port;               // SOCKS5转发端口
@property (nonatomic, copy, nullable) NSString *forwardHTTPHost;   // HTTP转发主机
@property (nonatomic, assign) int forwardHTTPPort;                 // HTTP转发端口
@property (nonatomic, copy, nullable) NSString *configFilePath;    // 配置文件路径
@property (nonatomic, copy, nullable) NSString *logFilePath;       // 日志文件路径
@property (nonatomic, assign) BOOL enableFiltering;                // 是否启用过滤
@property (nonatomic, assign) BOOL enableCompression;              // 是否启用压缩
@property (nonatomic, assign) BOOL enableRemoteToggle;             // 是否启用远程切换
@property (nonatomic, assign) int connectionTimeout;               // 连接超时（秒）
@property (nonatomic, assign) int socketTimeout;                   // Socket超时（秒）
@property (nonatomic, assign) int maxClientConnections;            // 最大客户端连接数

// 便捷初始化方法
+ (instancetype)configWithListenPort:(int)listenPort
                   forwardSOCKS5Host:(nullable NSString *)forwardSOCKS5Host
                   forwardSOCKS5Port:(int)forwardSOCKS5Port;

@end

// Privoxy过滤规则模型
NS_SWIFT_NAME(PrivoxyFilterRule)
@interface TFYPrivoxyFilterRule : NSObject

@property (nonatomic, copy, nonnull) NSString *pattern;            // 匹配模式
@property (nonatomic, assign) TFYPrivoxyFilterAction action;       // 过滤动作
@property (nonatomic, copy, nullable) NSString *description;       // 规则描述

// 便捷初始化方法
+ (instancetype)ruleWithPattern:(nonnull NSString *)pattern
                         action:(TFYPrivoxyFilterAction)action
                    description:(nullable NSString *)description;

@end

// Privoxy管理器代理协议
NS_SWIFT_NAME(LibevPrivoxyManagerDelegate)
@protocol TFYOCLibevPrivoxyManagerDelegate <NSObject>

@optional
// 代理状态变化回调
- (void)privoxyDidStart;
- (void)privoxyDidStop;
// 代理错误回调
- (void)privoxyDidEncounterError:(NSError *)error;
// 日志回调
- (void)privoxyLogMessage:(NSString *)message;

@end

// Privoxy管理器类
NS_SWIFT_NAME(LibevPrivoxyManager)
@interface TFYOCLibevPrivoxyManager : NSObject

// 单例方法
+ (instancetype)sharedManager;

// 当前配置
@property (nonatomic, strong, nullable) TFYPrivoxyConfig *config;
// 是否正在运行
@property (nonatomic, assign, readonly) BOOL isRunning;
// 代理对象
@property (nonatomic, weak, nullable) id<TFYOCLibevPrivoxyManagerDelegate> delegate;

// 启动Privoxy
- (BOOL)startPrivoxy;
// 停止Privoxy
- (void)stopPrivoxy;
// 重启Privoxy
- (BOOL)restartPrivoxy;

// 添加过滤规则
- (BOOL)addFilterRule:(nonnull TFYPrivoxyFilterRule *)rule;
// 移除过滤规则
- (BOOL)removeFilterRuleWithPattern:(nonnull NSString *)pattern;
// 获取所有过滤规则
- (nonnull NSArray<TFYPrivoxyFilterRule *> *)allFilterRules;
// 清除所有过滤规则
- (BOOL)clearAllFilterRules;

// 切换过滤状态
- (BOOL)toggleFiltering:(BOOL)enabled;
// 切换压缩状态
- (BOOL)toggleCompression:(BOOL)enabled;

// 生成配置文件
- (BOOL)generateConfigFile;
// 加载配置文件
- (BOOL)loadConfigFile:(nonnull NSString *)filePath;

@end

NS_ASSUME_NONNULL_END