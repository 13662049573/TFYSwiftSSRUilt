//
//  TFYOCLibevConnection.m
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import "TFYOCLibevConnection.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
#import <stdatomic.h>

// 错误域和错误码
NSString * const TFYOCLibevConnectionErrorDomain = @"com.tfyswiftssrkit.connection";

typedef NS_ENUM(NSInteger, TFYOCLibevConnectionErrorCode) {
    TFYOCLibevConnectionErrorCodeInvalidHost = 2001,
    TFYOCLibevConnectionErrorCodeConnectionFailed = 2002,
    TFYOCLibevConnectionErrorCodeSendFailed = 2003
};

// 私有接口
@interface TFYOCLibevConnection () <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>

// 连接状态（使用原子操作）
@property (nonatomic, assign) TFYConnectionStatus status;
// 连接类型
@property (nonatomic, assign) TFYConnectionType type;
// 远程主机
@property (nonatomic, copy) NSString *remoteHost;
// 远程端口
@property (nonatomic, assign) uint16_t remotePort;
// 本地端口
@property (nonatomic, assign) uint16_t localPort;
// 连接标识符
@property (nonatomic, copy) NSString *identifier;
// 连接开始时间
@property (nonatomic, strong) NSDate *startTime;
// 上传字节数（使用原子操作）
@property (nonatomic, assign) uint64_t uploadBytes;
// 下载字节数（使用原子操作）
@property (nonatomic, assign) uint64_t downloadBytes;
// TCP Socket
@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;
// UDP Socket
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;
// 队列
@property (nonatomic, strong) dispatch_queue_t connectionQueue;

@end

@implementation TFYOCLibevConnection

#pragma mark - 初始化方法

- (instancetype)initWithType:(TFYConnectionType)type
                 remoteHost:(NSString *)remoteHost
                 remotePort:(uint16_t)remotePort
                  localPort:(uint16_t)localPort {
    self = [super init];
    if (self) {
        _type = type;
        _remoteHost = [remoteHost copy];
        _remotePort = remotePort;
        _localPort = localPort;
        _status = TFYConnectionStatusDisconnected;
        _startTime = [NSDate date];
        _identifier = [[NSUUID UUID] UUIDString];
        _uploadBytes = 0;
        _downloadBytes = 0;
        
        // 创建专用队列
        NSString *queueName = [NSString stringWithFormat:@"com.tfyswiftssrkit.connection.%@", _identifier];
        _connectionQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
        
        // 初始化socket
        if (type == TFYConnectionTypeTCP) {
            _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_connectionQueue];
        } else {
            _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_connectionQueue];
        }
    }
    return self;
}

#pragma mark - 公共方法

- (BOOL)connect {
    if (self.status != TFYConnectionStatusDisconnected) {
        return NO;
    }
    
    if (!self.remoteHost || self.remoteHost.length == 0) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevConnectionErrorDomain
                                            code:TFYOCLibevConnectionErrorCodeInvalidHost
                                        userInfo:@{NSLocalizedDescriptionKey: @"远程主机地址不能为空"}]];
        return NO;
    }
    
    self.status = TFYConnectionStatusConnecting;
    [self notifyStatusChange];
    
    dispatch_async(self.connectionQueue, ^{
        if (self.type == TFYConnectionTypeTCP) {
            NSError *error = nil;
            if (![self.tcpSocket connectToHost:self.remoteHost
                                      onPort:self.remotePort
                                withTimeout:30
                                     error:&error]) {
                [self handleError:error];
            }
        } else {
            // UDP连接不需要显式连接，直接标记为已连接
            self.status = TFYConnectionStatusConnected;
            [self notifyStatusChange];
        }
    });
    
    return YES;
}

- (void)disconnect {
    if (self.status == TFYConnectionStatusDisconnected) {
        return;
    }
    
    self.status = TFYConnectionStatusDisconnecting;
    [self notifyStatusChange];
    
    dispatch_async(self.connectionQueue, ^{
        if (self.type == TFYConnectionTypeTCP) {
            [self.tcpSocket disconnect];
        } else {
            [self.udpSocket close];
            self.status = TFYConnectionStatusDisconnected;
            [self notifyStatusChange];
        }
    });
}

- (BOOL)sendData:(NSData *)data {
    if (self.status != TFYConnectionStatusConnected) {
        return NO;
    }
    
    if (!data || data.length == 0) {
        return NO;
    }
    
    dispatch_async(self.connectionQueue, ^{
        if (self.type == TFYConnectionTypeTCP) {
            [self.tcpSocket writeData:data withTimeout:30 tag:0];
        } else {
            NSError *error = nil;
            [self.udpSocket sendData:data toHost:self.remoteHost port:self.remotePort withTimeout:30 tag:0 error:&error];
            if (error) {
                [self handleError:error];
            }
        }
        
        self.uploadBytes += data.length;
        
        if ([self.delegate respondsToSelector:@selector(connection:didSendData:)]) {
            [self.delegate connection:self didSendData:data];
        }
    });
    
    return YES;
}

- (void)close {
    [self disconnect];
}

#pragma mark - 私有方法

- (void)handleError:(NSError *)error {
    self.status = TFYConnectionStatusError;
    [self notifyStatusChange];
    
    if ([self.delegate respondsToSelector:@selector(connectionDidEncounterError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidEncounterError:error];
        });
    }
}

- (void)notifyStatusChange {
    if ([self.delegate respondsToSelector:@selector(connectionStatusDidChange:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionStatusDidChange:self.status];
        });
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    self.status = TFYConnectionStatusConnected;
    [self notifyStatusChange];
    
    if ([self.delegate respondsToSelector:@selector(connectionDidConnect:)]) {
        [self.delegate connectionDidConnect:self];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    self.status = TFYConnectionStatusDisconnected;
    [self notifyStatusChange];
    
    if (err && err.code != GCDAsyncSocketClosedError) {
        [self handleError:err];
    }
    
    if ([self.delegate respondsToSelector:@selector(connectionDidDisconnect:withError:)]) {
        [self.delegate connectionDidDisconnect:self withError:err];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    self.downloadBytes += data.length;
    
    if ([self.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        [self.delegate connection:self didReceiveData:data];
    }
    
    // 继续读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    self.downloadBytes += data.length;
    
    if ([self.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        [self.delegate connection:self didReceiveData:data];
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    if (error) {
        [self handleError:error];
    } else {
        self.status = TFYConnectionStatusDisconnected;
        [self notifyStatusChange];
    }
}

@end

#pragma mark - TFYOCLibevConnectionManager

@interface TFYOCLibevConnectionManager ()

// 活跃连接字典
@property (nonatomic, strong) NSMutableDictionary<NSString *, TFYOCLibevConnection *> *connections;
// 锁对象
@property (nonatomic, strong) NSLock *lock;

@end

@implementation TFYOCLibevConnectionManager

#pragma mark - 单例方法

+ (instancetype)sharedManager {
    static TFYOCLibevConnectionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - 初始化方法

- (instancetype)init {
    self = [super init];
    if (self) {
        _connections = [NSMutableDictionary dictionary];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

#pragma mark - 公共方法

- (NSArray<TFYOCLibevConnection *> *)activeConnections {
    [self.lock lock];
    NSArray *connections = [self.connections.allValues copy];
    [self.lock unlock];
    return connections;
}

- (TFYOCLibevConnection *)connectionWithIdentifier:(NSString *)identifier {
    if (!identifier) {
        return nil;
    }
    
    [self.lock lock];
    TFYOCLibevConnection *connection = self.connections[identifier];
    [self.lock unlock];
    
    return connection;
}

- (void)closeAllConnections {
    [self.lock lock];
    NSArray *connections = [self.connections.allValues copy];
    [self.lock unlock];
    
    for (TFYOCLibevConnection *connection in connections) {
        [connection close];
    }
}

- (NSDictionary *)connectionStatistics {
    [self.lock lock];
    
    NSUInteger totalConnections = self.connections.count;
    NSUInteger tcpConnections = 0;
    NSUInteger udpConnections = 0;
    uint64_t totalUploadBytes = 0;
    uint64_t totalDownloadBytes = 0;
    
    for (TFYOCLibevConnection *connection in self.connections.allValues) {
        if (connection.type == TFYConnectionTypeTCP) {
            tcpConnections++;
        } else {
            udpConnections++;
        }
        
        totalUploadBytes += connection.uploadBytes;
        totalDownloadBytes += connection.downloadBytes;
    }
    
    [self.lock unlock];
    
    return @{
        @"totalConnections": @(totalConnections),
        @"tcpConnections": @(tcpConnections),
        @"udpConnections": @(udpConnections),
        @"totalUploadBytes": @(totalUploadBytes),
        @"totalDownloadBytes": @(totalDownloadBytes)
    };
}

#pragma mark - 内部方法

- (void)addConnection:(TFYOCLibevConnection *)connection {
    if (!connection || !connection.identifier) {
        return;
    }
    
    [self.lock lock];
    self.connections[connection.identifier] = connection;
    [self.lock unlock];
}

- (void)removeConnection:(TFYOCLibevConnection *)connection {
    if (!connection || !connection.identifier) {
        return;
    }
    
    [self.lock lock];
    [self.connections removeObjectForKey:connection.identifier];
    [self.lock unlock];
}

@end 
