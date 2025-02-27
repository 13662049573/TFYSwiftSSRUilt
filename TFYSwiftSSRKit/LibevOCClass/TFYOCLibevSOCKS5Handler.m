//
//  TFYOCLibevSOCKS5Handler.m
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import "TFYOCLibevSOCKS5Handler.h"
#import <arpa/inet.h>
#import <netdb.h>
#import "GCDAsyncSocket.h"

// 错误域和错误码
NSString * const TFYOCLibevSOCKS5ErrorDomain = @"com.tfyswiftssrkit.socks5";

typedef NS_ENUM(NSInteger, TFYOCLibevSOCKS5ErrorCode) {
    TFYOCLibevSOCKS5ErrorCodeInvalidData = 3001,
    TFYOCLibevSOCKS5ErrorCodeInvalidAddress = 3002,
    TFYOCLibevSOCKS5ErrorCodeStreamError = 3003
};

// SOCKS5协议常量
static const uint8_t kSOCKS5Version = 0x05;
static const uint8_t kSOCKS5AuthNone = 0x00;
__unused static const uint8_t kSOCKS5IPv4 = 0x01;
__unused static const uint8_t kSOCKS5Domain = 0x03;
__unused static const uint8_t kSOCKS5IPv6 = 0x04;

// SOCKS5处理状态
typedef NS_ENUM(NSInteger, TFYSOCKS5HandlerState) {
    TFYSOCKS5HandlerStateInitial = 0,        // 初始状态
    TFYSOCKS5HandlerStateAuthNegotiation,    // 认证协商
    TFYSOCKS5HandlerStateRequest,            // 请求处理
    TFYSOCKS5HandlerStateConnecting,         // 连接中
    TFYSOCKS5HandlerStateForwarding,         // 转发数据
    TFYSOCKS5HandlerStateError               // 错误状态
};

#pragma mark - TFYSOCKS5Request

@implementation TFYSOCKS5Request

+ (nullable instancetype)requestWithData:(nonnull NSData *)data {
    if (data.length < 4) {
        return nil;
    }
    
    const uint8_t *bytes = data.bytes;
    
    // 检查SOCKS5版本
    if (bytes[0] != kSOCKS5Version) {
        return nil;
    }
    
    TFYSOCKS5Request *request = [[TFYSOCKS5Request alloc] init];
    request.command = bytes[1];
    // bytes[2]是保留字段，值为0
    request.addressType = bytes[3];
    
    // 解析目标地址和端口
    NSUInteger offset = 4;
    
    switch (request.addressType) {
        case TFYSOCKS5AddressTypeIPv4: {
            // IPv4地址（4字节）+ 端口（2字节）
            if (data.length < offset + 4 + 2) {
                return nil;
            }
            
            // 解析IPv4地址
            struct in_addr addr;
            memcpy(&addr.s_addr, bytes + offset, 4);
            char addrStr[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &addr, addrStr, sizeof(addrStr));
            request.destinationAddress = [NSString stringWithUTF8String:addrStr];
            
            offset += 4;
            break;
        }
        case TFYSOCKS5AddressTypeDomain: {
            // 域名长度（1字节）+ 域名 + 端口（2字节）
            if (data.length < offset + 1) {
                return nil;
            }
            
            uint8_t domainLength = bytes[offset];
            offset += 1;
            
            if (data.length < offset + domainLength + 2) {
                return nil;
            }
            
            // 解析域名
            NSData *domainData = [data subdataWithRange:NSMakeRange(offset, domainLength)];
            request.destinationAddress = [[NSString alloc] initWithData:domainData encoding:NSUTF8StringEncoding];
            
            offset += domainLength;
            break;
        }
        case TFYSOCKS5AddressTypeIPv6: {
            // IPv6地址（16字节）+ 端口（2字节）
            if (data.length < offset + 16 + 2) {
                return nil;
            }
            
            // 解析IPv6地址
            struct in6_addr addr;
            memcpy(&addr, bytes + offset, 16);
            char addrStr[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &addr, addrStr, sizeof(addrStr));
            request.destinationAddress = [NSString stringWithUTF8String:addrStr];
            
            offset += 16;
            break;
        }
        default:
            return nil;
    }
    
    // 解析端口（网络字节序，大端）
    if (data.length < offset + 2) {
        return nil;
    }
    
    uint16_t port;
    memcpy(&port, bytes + offset, 2);
    request.destinationPort = ntohs(port);
    
    return request;
}

- (nonnull NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    
    // 添加版本、命令、保留字段和地址类型
    uint8_t header[4] = {kSOCKS5Version, self.command, 0x00, self.addressType};
    [data appendBytes:header length:4];
    
    // 添加目标地址
    switch (self.addressType) {
        case TFYSOCKS5AddressTypeIPv4: {
            // IPv4地址（4字节）
            struct in_addr addr;
            inet_pton(AF_INET, [self.destinationAddress UTF8String], &addr);
            [data appendBytes:&addr.s_addr length:4];
            break;
        }
        case TFYSOCKS5AddressTypeDomain: {
            // 域名长度（1字节）+ 域名
            uint8_t length = (uint8_t)self.destinationAddress.length;
            [data appendBytes:&length length:1];
            [data appendData:[self.destinationAddress dataUsingEncoding:NSUTF8StringEncoding]];
            break;
        }
        case TFYSOCKS5AddressTypeIPv6: {
            // IPv6地址（16字节）
            struct in6_addr addr;
            inet_pton(AF_INET6, [self.destinationAddress UTF8String], &addr);
            [data appendBytes:&addr length:16];
            break;
        }
    }
    
    // 添加端口（网络字节序，大端）
    uint16_t port = htons(self.destinationPort);
    [data appendBytes:&port length:2];
    
    return data;
}

@end

#pragma mark - TFYSOCKS5Reply

@implementation TFYSOCKS5Reply

+ (instancetype)successReplyWithAddress:(nonnull NSString *)address port:(uint16_t)port {
    TFYSOCKS5Reply *reply = [[TFYSOCKS5Reply alloc] init];
    reply.replyCode = TFYSOCKS5ReplySuccess;
    
    // 自动检测地址类型
    if ([address containsString:@":"]) {
        reply.addressType = TFYSOCKS5AddressTypeIPv6;
    } else if ([self isIPv4Address:address]) {
        reply.addressType = TFYSOCKS5AddressTypeIPv4;
    } else {
        reply.addressType = TFYSOCKS5AddressTypeDomain;
    }
    
    reply.boundAddress = address;
    reply.boundPort = port;
    
    return reply;
}

+ (instancetype)failureReplyWithCode:(TFYSOCKS5ReplyCode)code {
    TFYSOCKS5Reply *reply = [[TFYSOCKS5Reply alloc] init];
    reply.replyCode = code;
    reply.addressType = TFYSOCKS5AddressTypeIPv4;
    reply.boundAddress = @"0.0.0.0";
    reply.boundPort = 0;
    
    return reply;
}

+ (BOOL)isIPv4Address:(NSString *)address {
    struct in_addr addr;
    return inet_pton(AF_INET, [address UTF8String], &addr) == 1;
}

- (nonnull NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    
    // 添加版本、回复代码、保留字段和地址类型
    uint8_t header[4] = {kSOCKS5Version, self.replyCode, 0x00, self.addressType};
    [data appendBytes:header length:4];
    
    // 添加绑定地址
    switch (self.addressType) {
        case TFYSOCKS5AddressTypeIPv4: {
            // IPv4地址（4字节）
            struct in_addr addr;
            inet_pton(AF_INET, [self.boundAddress UTF8String], &addr);
            [data appendBytes:&addr.s_addr length:4];
            break;
        }
        case TFYSOCKS5AddressTypeDomain: {
            // 域名长度（1字节）+ 域名
            uint8_t length = (uint8_t)self.boundAddress.length;
            [data appendBytes:&length length:1];
            [data appendData:[self.boundAddress dataUsingEncoding:NSUTF8StringEncoding]];
            break;
        }
        case TFYSOCKS5AddressTypeIPv6: {
            // IPv6地址（16字节）
            struct in6_addr addr;
            inet_pton(AF_INET6, [self.boundAddress UTF8String], &addr);
            [data appendBytes:&addr length:16];
            break;
        }
    }
    
    // 添加端口（网络字节序，大端）
    uint16_t port = htons(self.boundPort);
    [data appendBytes:&port length:2];
    
    return data;
}

@end

#pragma mark - TFYOCLibevSOCKS5Handler

@interface TFYOCLibevSOCKS5Handler () <NSStreamDelegate>

// 处理状态
@property (nonatomic, assign) TFYSOCKS5HandlerState state;
// 输入流
@property (nonatomic, strong, nullable) NSInputStream *inputStream;
// 输出流
@property (nonatomic, strong, nullable) NSOutputStream *outputStream;
// 缓冲区
@property (nonatomic, strong, nullable) NSMutableData *buffer;
// 当前请求
@property (nonatomic, strong, nullable) TFYSOCKS5Request *currentRequest;
@property (nonatomic, strong) dispatch_queue_t handlerQueue;

@end

@implementation TFYOCLibevSOCKS5Handler

#pragma mark - 初始化方法

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = TFYSOCKS5HandlerStateInitial;
        _buffer = [NSMutableData data];
        _handlerQueue = dispatch_queue_create("com.tfyswiftssrkit.socks5.handler", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - 公共方法

- (void)handleClientConnection:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    self.inputStream = inputStream;
    self.outputStream = outputStream;
    
    dispatch_async(self.handlerQueue, ^{
        [self.inputStream setDelegate:self];
        [self.outputStream setDelegate:self];
        
        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.inputStream open];
        [self.outputStream open];
        
        // 开始处理SOCKS5握手
        [self handleSOCKS5Handshake];
    });
}

- (void)sendReply:(TFYSOCKS5Reply *)reply toOutputStream:(NSOutputStream *)outputStream {
    if (!reply || !outputStream) {
        return;
    }
    
    NSData *replyData = [reply toData];
    if (!replyData) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                            code:TFYOCLibevSOCKS5ErrorCodeInvalidData
                                        userInfo:@{NSLocalizedDescriptionKey: @"无效的回复数据"}]];
        return;
    }
    
    dispatch_async(self.handlerQueue, ^{
        NSInteger written = [outputStream write:replyData.bytes maxLength:replyData.length];
        if (written != replyData.length) {
            [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                                code:TFYOCLibevSOCKS5ErrorCodeStreamError
                                            userInfo:@{NSLocalizedDescriptionKey: @"写入回复数据失败"}]];
        }
    });
}

- (void)processSOCKS5RequestData:(NSData *)data {
    if (!data || data.length < 3) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                            code:TFYOCLibevSOCKS5ErrorCodeInvalidData
                                        userInfo:@{NSLocalizedDescriptionKey: @"无效的请求数据"}]];
        return;
    }
    
    dispatch_async(self.handlerQueue, ^{
        TFYSOCKS5Request *request = [TFYSOCKS5Request requestWithData:data];
        if (!request) {
            [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                                code:TFYOCLibevSOCKS5ErrorCodeInvalidData
                                            userInfo:@{NSLocalizedDescriptionKey: @"解析请求数据失败"}]];
            return;
        }
        
        // 根据请求类型调用相应的代理方法
        switch (request.command) {
            case TFYSOCKS5CommandConnect:
                if ([self.delegate respondsToSelector:@selector(socks5Handler:didReceiveConnectRequestToHost:port:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate socks5Handler:self
                     didReceiveConnectRequestToHost:request.destinationAddress
                                             port:request.destinationPort];
                    });
                }
                break;
                
            case TFYSOCKS5CommandBind:
                if ([self.delegate respondsToSelector:@selector(socks5Handler:didReceiveBindRequestToHost:port:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate socks5Handler:self
                        didReceiveBindRequestToHost:request.destinationAddress
                                             port:request.destinationPort];
                    });
                }
                break;
                
            case TFYSOCKS5CommandUDPAssociate:
                if ([self.delegate respondsToSelector:@selector(socks5Handler:didReceiveUDPAssociateRequestToHost:port:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate socks5Handler:self
                 didReceiveUDPAssociateRequestToHost:request.destinationAddress
                                              port:request.destinationPort];
                    });
                }
                break;
        }
    });
}

#pragma mark - 私有方法

- (void)handleSOCKS5Handshake {
    uint8_t handshakeData[] = {kSOCKS5Version, 1, kSOCKS5AuthNone};
    NSInteger written = [self.outputStream write:handshakeData maxLength:sizeof(handshakeData)];
    
    if (written != sizeof(handshakeData)) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                            code:TFYOCLibevSOCKS5ErrorCodeStreamError
                                        userInfo:@{NSLocalizedDescriptionKey: @"写入握手数据失败"}]];
    }
}

- (void)handleError:(NSError *)error {
    self.state = TFYSOCKS5HandlerStateError;
    
    if ([self.delegate respondsToSelector:@selector(socks5Handler:didEncounterError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate socks5Handler:self didEncounterError:error];
        });
    }
    
    // 关闭流
    [self.inputStream close];
    [self.outputStream close];
    
    // 从运行循环中移除
    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.inputStream = nil;
    self.outputStream = nil;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable: {
            if (stream == self.inputStream) {
                uint8_t buffer[4096];
                NSInteger bytesRead = [(NSInputStream *)stream read:buffer maxLength:sizeof(buffer)];
                
                if (bytesRead > 0) {
                    [self.buffer appendBytes:buffer length:bytesRead];
                    [self processSOCKS5RequestData:self.buffer];
                } else if (bytesRead < 0) {
                    [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                                        code:TFYOCLibevSOCKS5ErrorCodeStreamError
                                                    userInfo:@{NSLocalizedDescriptionKey: @"读取数据失败"}]];
                }
            }
            break;
        }
            
        case NSStreamEventErrorOccurred: {
            [self handleError:[stream streamError]];
            break;
        }
            
        case NSStreamEventEndEncountered: {
            // 流结束，关闭连接
            [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                                  code:TFYOCLibevSOCKS5ErrorCodeStreamError
                                              userInfo:@{NSLocalizedDescriptionKey: @"连接已关闭"}]];
            break;
        }
            
        default:
            break;
    }
}

@end 