//
//  TFYOCLibevAntinatManager.m
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import "TFYOCLibevAntinatManager.h"
#include "antinat.h"
#import <pthread.h>
#include <arpa/inet.h>

// 错误域
NSString * const TFYOCLibevAntinatErrorDomain = @"com.tfyswiftssrkit.antinat";

// 错误码
typedef NS_ENUM(NSInteger, TFYOCLibevAntinatErrorCode) {
    TFYOCLibevAntinatErrorCodeConnectionFailed = 1001,
    TFYOCLibevAntinatErrorCodeSendFailed = 1002,
    TFYOCLibevAntinatErrorCodeReceiveFailed = 1003,
    TFYOCLibevAntinatErrorCodeInvalidConfig = 1004
};

@implementation TFYAntinatConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        // 设置默认值
        _proxyType = TFYAntinatProxyTypeDirect;
        _isBlocking = YES;
        _authSchemes = @[@(TFYAntinatAuthSchemeAnonymous)];
    }
    return self;
}

+ (instancetype)configWithProxyHost:(NSString *)proxyHost
                          proxyPort:(int)proxyPort
                          proxyType:(TFYAntinatProxyType)proxyType {
    TFYAntinatConfig *config = [[TFYAntinatConfig alloc] init];
    config.proxyHost = [proxyHost copy];
    config.proxyPort = proxyPort;
    config.proxyType = proxyType;
    return config;
}

@end

@interface TFYOCLibevAntinatConnection ()

@property (nonatomic, strong) TFYAntinatConfig *config;
@property (nonatomic, copy) NSString *remoteHost;
@property (nonatomic, assign) uint16_t remotePort;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) ANCONN connection;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, strong) dispatch_queue_t connectionQueue;

@end

@implementation TFYOCLibevAntinatConnection

- (instancetype)initWithConfig:(TFYAntinatConfig *)config
                    remoteHost:(NSString *)remoteHost
                    remotePort:(uint16_t)remotePort {
    self = [super init];
    if (self) {
        _config = config;
        _remoteHost = [remoteHost copy];
        _remotePort = remotePort;
        _identifier = [[NSUUID UUID] UUIDString];
        _isConnected = NO;
        _connectionQueue = dispatch_queue_create("com.tfyswiftssrkit.antinat.connection", DISPATCH_QUEUE_SERIAL);
        
        // 初始化antinat连接
        _connection = an_new_connection();
        if (_connection == NULL) {
            return nil;
        }
        
        // 设置代理服务器
        if (_config.proxyType != TFYAntinatProxyTypeDirect) {
            an_set_proxy(_connection, 
                         (unsigned short)_config.proxyType, 
                         AN_PF_INET, 
                         [_config.proxyHost UTF8String], 
                         (unsigned short)_config.proxyPort);
            
            // 设置认证方式
            an_clear_authschemes(_connection);
            for (NSNumber *scheme in _config.authSchemes) {
                an_set_authscheme(_connection, [scheme unsignedIntValue]);
            }
            
            // 设置认证凭据
            if (_config.username && _config.password) {
                an_set_credentials(_connection, 
                                  [_config.username UTF8String], 
                                  [_config.password UTF8String]);
            }
        }
        
        // 设置阻塞模式
        an_set_blocking(_connection, _config.isBlocking ? AN_CONN_BLOCKING : AN_CONN_NONBLOCKING);
    }
    return self;
}

- (void)dealloc {
    [self close];
}

- (BOOL)connect {
    __block BOOL success = NO;
    
    dispatch_sync(_connectionQueue, ^{
        if (self.isConnected) {
            success = YES;
            return;
        }
        
        int result = an_connect_tohostname(self.connection, 
                                          [self.remoteHost UTF8String], 
                                          (unsigned short)self.remotePort);
        
        if (result == AN_ERROR_SUCCESS) {
            self.isConnected = YES;
            success = YES;
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidConnect)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate antinatConnectionDidConnect];
                });
            }
        } else {
            NSError *error = [NSError errorWithDomain:TFYOCLibevAntinatErrorDomain
                                                 code:TFYOCLibevAntinatErrorCodeConnectionFailed
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to connect: %d", result]}];
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidFailWithError:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate antinatConnectionDidFailWithError:error];
                });
            }
        }
    });
    
    return success;
}

- (BOOL)sendData:(NSData *)data {
    if (!data || data.length == 0) {
        return NO;
    }
    
    __block BOOL success = NO;
    
    dispatch_sync(_connectionQueue, ^{
        if (!self.isConnected) {
            return;
        }
        
        int result = an_send(self.connection, (void *)data.bytes, (int)data.length, 0);
        
        if (result > 0) {
            success = YES;
        } else {
            NSError *error = [NSError errorWithDomain:TFYOCLibevAntinatErrorDomain
                                                 code:TFYOCLibevAntinatErrorCodeSendFailed
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to send data: %d", result]}];
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidFailWithError:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate antinatConnectionDidFailWithError:error];
                });
            }
        }
    });
    
    return success;
}

- (NSData *)receiveDataWithTimeout:(NSTimeInterval)timeout {
    __block NSData *receivedData = nil;
    
    dispatch_sync(_connectionQueue, ^{
        if (!self.isConnected) {
            return;
        }
        
        // 创建缓冲区
        const int bufferSize = 4096;
        void *buffer = malloc(bufferSize);
        if (!buffer) {
            return;
        }
        
        // 设置超时
        fd_set readSet;
        FD_ZERO(&readSet);
        AN_FD_SET(self.connection, &readSet, 0);
        
        struct timeval tv;
        tv.tv_sec = (int)timeout;
        tv.tv_usec = (int)((timeout - (int)timeout) * 1000000);
        
        // 等待数据
        int selectResult = select(FD_SETSIZE, &readSet, NULL, NULL, &tv);
        
        if (selectResult > 0 && AN_FD_ISSET(self.connection, &readSet)) {
            // 接收数据
            int bytesRead = an_recv(self.connection, buffer, bufferSize, 0);
            
            if (bytesRead > 0) {
                receivedData = [NSData dataWithBytes:buffer length:bytesRead];
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidReceiveData:)]) {
                    NSData *dataCopy = [receivedData copy];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate antinatConnectionDidReceiveData:dataCopy];
                    });
                }
            } else if (bytesRead == 0) {
                // 连接已关闭
                self.isConnected = NO;
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidClose)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate antinatConnectionDidClose];
                    });
                }
            } else {
                // 接收错误
                NSError *error = [NSError errorWithDomain:TFYOCLibevAntinatErrorDomain
                                                     code:TFYOCLibevAntinatErrorCodeReceiveFailed
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to receive data: %d", bytesRead]}];
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidFailWithError:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate antinatConnectionDidFailWithError:error];
                    });
                }
            }
        }
        
        free(buffer);
    });
    
    return receivedData;
}

- (void)close {
    dispatch_sync(_connectionQueue, ^{
        if (self.connection != NULL) {
            an_close(self.connection);
            an_destroy(self.connection);
            self.connection = NULL;
            self.isConnected = NO;
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(antinatConnectionDidClose)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate antinatConnectionDidClose];
                });
            }
        }
    });
}

@end

@interface TFYOCLibevAntinatManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, TFYOCLibevAntinatConnection *> *connections;
@property (nonatomic, strong) dispatch_queue_t managerQueue;

@end

@implementation TFYOCLibevAntinatManager

+ (instancetype)sharedManager {
    static TFYOCLibevAntinatManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[TFYOCLibevAntinatManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _connections = [NSMutableDictionary dictionary];
        _managerQueue = dispatch_queue_create("com.tfyswiftssrkit.antinat.manager", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (TFYOCLibevAntinatConnection *)createConnectionWithConfig:(TFYAntinatConfig *)config
                                                 remoteHost:(NSString *)remoteHost
                                                 remotePort:(uint16_t)remotePort {
    TFYOCLibevAntinatConnection *connection = [[TFYOCLibevAntinatConnection alloc] initWithConfig:config
                                                                                      remoteHost:remoteHost
                                                                                      remotePort:remotePort];
    
    if (connection) {
        dispatch_sync(_managerQueue, ^{
            self.connections[connection.identifier] = connection;
        });
    }
    
    return connection;
}

- (NSArray<TFYOCLibevAntinatConnection *> *)activeConnections {
    __block NSArray<TFYOCLibevAntinatConnection *> *result = nil;
    
    dispatch_sync(_managerQueue, ^{
        result = [self.connections.allValues copy];
    });
    
    return result;
}

- (TFYOCLibevAntinatConnection *)connectionWithIdentifier:(NSString *)identifier {
    __block TFYOCLibevAntinatConnection *result = nil;
    
    dispatch_sync(_managerQueue, ^{
        result = self.connections[identifier];
    });
    
    return result;
}

- (void)closeAllConnections {
    dispatch_sync(_managerQueue, ^{
        for (TFYOCLibevAntinatConnection *connection in self.connections.allValues) {
            [connection close];
        }
        [self.connections removeAllObjects];
    });
}

- (NSArray<NSString *> *)resolveHostname:(NSString *)hostname {
    if (!hostname || hostname.length == 0) {
        return nil;
    }
    
    struct hostent hostbuf, *hp;
    char *buf;
    size_t buflen;
    int herr;
    
    buflen = 1024;
    buf = malloc(buflen);
    
    NSMutableArray<NSString *> *addresses = [NSMutableArray array];
    
    if (an_gethostbyname([hostname UTF8String], &hostbuf, buf, (int)buflen, &hp, &herr) == 0) {
        if (hp != NULL) {
            for (int i = 0; hp->h_addr_list[i] != NULL; i++) {
                char addrStr[INET6_ADDRSTRLEN];
                
                if (hp->h_addrtype == AF_INET) {
                    // IPv4
                    struct in_addr *addr = (struct in_addr *)hp->h_addr_list[i];
                    inet_ntop(AF_INET, addr, addrStr, sizeof(addrStr));
                    [addresses addObject:[NSString stringWithUTF8String:addrStr]];
                } else if (hp->h_addrtype == AF_INET6) {
                    // IPv6
                    struct in6_addr *addr = (struct in6_addr *)hp->h_addr_list[i];
                    inet_ntop(AF_INET6, addr, addrStr, sizeof(addrStr));
                    [addresses addObject:[NSString stringWithUTF8String:addrStr]];
                }
            }
        }
    }
    
    free(buf);
    
    return addresses.count > 0 ? [addresses copy] : nil;
}

@end