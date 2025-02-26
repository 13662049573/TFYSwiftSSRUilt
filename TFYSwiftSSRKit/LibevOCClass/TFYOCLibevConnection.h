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
};

// 连接状态枚举
typedef NS_ENUM(NSInteger, TFYConnectionStatus) {
    TFYConnectionStatusConnecting = 0,  // 连接中
    TFYConnectionStatusConnected = 1,    // 已连接
    TFYConnectionStatusDisconnected = 2, // 已断开
    TFYConnectionStatusError = 3         // 错误
};

// 连接代理协议
@protocol TFYOCLibevConnectionDelegate <NSObject>

@optional
// 连接状态变化回调
- (void)connectionStatusDidChange:(TFYConnectionStatus)status;
// 接收到数据回调
- (void)connectionDidReceiveData:(NSData *)data;
// 连接错误回调
- (void)connectionDidEncounterError:(NSError *)error;
// 连接关闭回调
- (void)connectionDidClose;

@end

// 连接类
@interface TFYOCLibevConnection : NSObject

// 连接类型
@property (nonatomic, assign, readonly) TFYConnectionType type;
// 连接状态
@property (nonatomic, assign, readonly) TFYConnectionStatus status;
// 远程主机
@property (nonatomic, copy, readonly) NSString *remoteHost;
// 远程端口
@property (nonatomic, assign, readonly) uint16_t remotePort;
// 本地端口
@property (nonatomic, assign, readonly) uint16_t localPort;
// 连接标识符
@property (nonatomic, copy, readonly) NSString *identifier;
// 连接开始时间
@property (nonatomic, strong, readonly) NSDate *startTime;
// 上传字节数
@property (nonatomic, assign, readonly) uint64_t uploadBytes;
// 下载字节数
@property (nonatomic, assign, readonly) uint64_t downloadBytes;
// 代理对象
@property (nonatomic, weak) id<TFYOCLibevConnectionDelegate> delegate;

// 初始化方法
- (instancetype)initWithType:(TFYConnectionType)type
                  remoteHost:(NSString *)remoteHost
                  remotePort:(uint16_t)remotePort
                   localPort:(uint16_t)localPort;

// 连接到远程主机
- (BOOL)connect;
// 发送数据
- (BOOL)sendData:(NSData *)data;
// 关闭连接
- (void)close;

@end

// 连接管理器类
@interface TFYOCLibevConnectionManager : NSObject

// 单例方法
+ (instancetype)sharedManager;

// 获取所有活跃连接
- (NSArray<TFYOCLibevConnection *> *)activeConnections;
// 根据标识符获取连接
- (nullable TFYOCLibevConnection *)connectionWithIdentifier:(NSString *)identifier;
// 关闭所有连接
- (void)closeAllConnections;
// 获取连接统计信息
- (NSDictionary *)connectionStatistics;

// 添加连接到管理器
- (void)addConnection:(TFYOCLibevConnection *)connection;
// 从管理器中移除连接
- (void)removeConnection:(TFYOCLibevConnection *)connection;

@end

NS_ASSUME_NONNULL_END 
