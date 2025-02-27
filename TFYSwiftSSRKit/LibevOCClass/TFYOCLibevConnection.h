//
//  TFYOCLibevConnection.h
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 连接类型枚举
typedef NS_ENUM(NSInteger, TFYConnectionType) {
    TFYConnectionTypeTCP = 0,  // TCP连接
    TFYConnectionTypeUDP = 1   // UDP连接
} NS_SWIFT_NAME(ConnectionType);

// 连接状态枚举
typedef NS_ENUM(NSInteger, TFYConnectionStatus) {
    TFYConnectionStatusConnecting = 0,  // 连接中
    TFYConnectionStatusConnected = 1,    // 已连接
    TFYConnectionStatusDisconnected = 2, // 已断开
    TFYConnectionStatusError = 3         // 错误
} NS_SWIFT_NAME(ConnectionStatus);

@class TFYOCLibevConnection;

// 连接代理协议
NS_SWIFT_NAME(LibevConnectionDelegate)
@protocol TFYOCLibevConnectionDelegate <NSObject>

@optional
// 连接状态变化回调
- (void)connectionStatusDidChange:(TFYConnectionStatus)status;
// 连接成功回调
- (void)connectionDidConnect:(TFYOCLibevConnection *)connection;
// 连接断开回调
- (void)connectionDidDisconnect:(TFYOCLibevConnection *)connection withError:(nullable NSError *)error;
// 接收到数据回调
- (void)connection:(TFYOCLibevConnection *)connection didReceiveData:(NSData *)data;
// 发送数据回调
- (void)connection:(TFYOCLibevConnection *)connection didSendData:(NSData *)data;
// 连接错误回调
- (void)connectionDidEncounterError:(NSError *)error;

@end

// 连接类
NS_SWIFT_NAME(LibevConnection)
@interface TFYOCLibevConnection : NSObject

// 连接类型
@property (nonatomic, assign, readonly) TFYConnectionType type;
// 连接状态
@property (nonatomic, assign, readonly) TFYConnectionStatus status;
// 远程主机
@property (nonatomic, copy, readonly, nonnull) NSString *remoteHost;
// 远程端口
@property (nonatomic, assign, readonly) uint16_t remotePort;
// 本地端口
@property (nonatomic, assign, readonly) uint16_t localPort;
// 连接标识符
@property (nonatomic, copy, readonly, nonnull) NSString *identifier;
// 连接开始时间
@property (nonatomic, strong, readonly, nonnull) NSDate *startTime;
// 上传字节数
@property (nonatomic, assign, readonly) uint64_t uploadBytes;
// 下载字节数
@property (nonatomic, assign, readonly) uint64_t downloadBytes;
// 代理对象
@property (nonatomic, weak, nullable) id<TFYOCLibevConnectionDelegate> delegate;

// 初始化方法
- (instancetype)initWithType:(TFYConnectionType)type
                  remoteHost:(nonnull NSString *)remoteHost
                  remotePort:(uint16_t)remotePort
                   localPort:(uint16_t)localPort;

// 连接到远程主机
- (BOOL)connect;
// 发送数据
- (BOOL)sendData:(nonnull NSData *)data;
// 关闭连接
- (void)disconnect;
// 兼容旧方法
- (void)close;

@end

// 连接管理器类
NS_SWIFT_NAME(LibevConnectionManager)
@interface TFYOCLibevConnectionManager : NSObject

// 单例方法
+ (instancetype)sharedManager;

// 获取所有活跃连接
- (nonnull NSArray<TFYOCLibevConnection *> *)activeConnections;
// 根据标识符获取连接
- (nullable TFYOCLibevConnection *)connectionWithIdentifier:(nonnull NSString *)identifier;
// 关闭所有连接
- (void)closeAllConnections;
// 获取连接统计信息
- (nonnull NSDictionary *)connectionStatistics;

// 添加连接到管理器
- (void)addConnection:(nonnull TFYOCLibevConnection *)connection;
// 从管理器中移除连接
- (void)removeConnection:(nonnull TFYOCLibevConnection *)connection;

@end

NS_ASSUME_NONNULL_END 
