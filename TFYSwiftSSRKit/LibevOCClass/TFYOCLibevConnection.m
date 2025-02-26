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

// 错误域
NSString * const TFYOCLibevConnectionErrorDomain = @"com.tfyswiftssrkit.connection";

// 私有接口
@interface TFYOCLibevConnection () <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>

// 可写属性
@property (nonatomic, assign, readwrite) TFYConnectionType type;
@property (nonatomic, assign, readwrite) TFYConnectionStatus status;
@property (nonatomic, copy, readwrite) NSString *remoteHost;
@property (nonatomic, assign, readwrite) uint16_t remotePort;
@property (nonatomic, assign, readwrite) uint16_t localPort;
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, strong, readwrite) NSDate *startTime;
@property (nonatomic, assign, readwrite) uint64_t uploadBytes;
@property (nonatomic, assign, readwrite) uint64_t downloadBytes;

// 私有属性
@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;

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
        _uploadBytes = 0;
        _downloadBytes = 0;
        
        // 创建唯一标识符
        _identifier = [[NSUUID UUID] UUIDString];
        
        // 创建socket队列
        NSString *queueName = [NSString stringWithFormat:@"com.tfyswiftssrkit.connection.%@", _identifier];
        _socketQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // 根据连接类型创建相应的socket
        if (type == TFYConnectionTypeTCP) {
            _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        } else {
            _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        }
        
        // 将连接添加到管理器
        [[TFYOCLibevConnectionManager sharedManager] addConnection:self];
    }
    return self;
}

- (void)dealloc {
    [self close];
}

#pragma mark - 公共方法

- (BOOL)connect {
    if (self.status == TFYConnectionStatusConnecting || self.status == TFYConnectionStatusConnected) {
        return NO;
    }
    
    self.status = TFYConnectionStatusConnecting;
    [self notifyStatusChange];
    
    NSError *error = nil;
    BOOL success = NO;
    
    if (self.type == TFYConnectionTypeTCP) {
        // TCP连接
        success = [self.tcpSocket connectToHost:self.remoteHost onPort:self.remotePort error:&error];
    } else {
        // UDP连接
        success = [self.udpSocket bindToPort:self.localPort error:&error];
        if (success) {
            [self.udpSocket beginReceiving:&error];
            if (!error) {
                // UDP连接成功后立即设置为已连接状态
                self.status = TFYConnectionStatusConnected;
                [self notifyStatusChange];
            } else {
                success = NO;
            }
        }
    }
    
    if (!success) {
        self.status = TFYConnectionStatusError;
        [self notifyStatusChange];
        [self notifyError:error];
    }
    
    return success;
}

- (BOOL)sendData:(NSData *)data {
    if (self.status != TFYConnectionStatusConnected) {
        return NO;
    }
    
    if (!data || data.length == 0) {
        return NO;
    }
    
    if (self.type == TFYConnectionTypeTCP) {
        // TCP发送数据
        [self.tcpSocket writeData:data withTimeout:-1 tag:0];
    } else {
        // UDP发送数据
        [self.udpSocket sendData:data toHost:self.remoteHost port:self.remotePort withTimeout:-1 tag:0];
    }
    
    // 更新上传字节数
    self.uploadBytes += data.length;
    
    return YES;
}

- (void)close {
    if (self.status == TFYConnectionStatusDisconnected) {
        return;
    }
    
    if (self.type == TFYConnectionTypeTCP) {
        [self.tcpSocket disconnect];
    } else {
        [self.udpSocket close];
    }
    
    self.status = TFYConnectionStatusDisconnected;
    [self notifyStatusChange];
    [self notifyConnectionDidClose];
    
    // 从管理器中移除
    [[TFYOCLibevConnectionManager sharedManager] removeConnection:self];
}

#pragma mark - 私有方法

- (void)notifyStatusChange {
    if ([self.delegate respondsToSelector:@selector(connectionStatusDidChange:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionStatusDidChange:self.status];
        });
    }
}

- (void)notifyDataReceived:(NSData *)data {
    if ([self.delegate respondsToSelector:@selector(connectionDidReceiveData:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidReceiveData:data];
        });
    }
}

- (void)notifyError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(connectionDidEncounterError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidEncounterError:error];
        });
    }
}

- (void)notifyConnectionDidClose {
    if ([self.delegate respondsToSelector:@selector(connectionDidClose)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidClose];
        });
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    self.status = TFYConnectionStatusConnected;
    [self notifyStatusChange];
    
    // 开始读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    // 更新下载字节数
    self.downloadBytes += data.length;
    
    // 通知接收到数据
    [self notifyDataReceived:data];
    
    // 继续读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err) {
        self.status = TFYConnectionStatusError;
        [self notifyError:err];
    } else {
        self.status = TFYConnectionStatusDisconnected;
    }
    
    [self notifyStatusChange];
    [self notifyConnectionDidClose];
    
    // 从管理器中移除
    [[TFYOCLibevConnectionManager sharedManager] removeConnection:self];
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    // 更新下载字节数
    self.downloadBytes += data.length;
    
    // 通知接收到数据
    [self notifyDataReceived:data];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    [self notifyError:error];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    if (error) {
        self.status = TFYConnectionStatusError;
        [self notifyError:error];
    } else {
        self.status = TFYConnectionStatusDisconnected;
    }
    
    [self notifyStatusChange];
    [self notifyConnectionDidClose];
    
    // 从管理器中移除
    [[TFYOCLibevConnectionManager sharedManager] removeConnection:self];
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
