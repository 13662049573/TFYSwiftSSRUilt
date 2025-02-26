//
//  TFYOCLibevSOCKS5Handler.m
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import "TFYOCLibevSOCKS5Handler.h"
#import <arpa/inet.h>

// 错误域
NSString * const TFYOCLibevSOCKS5ErrorDomain = @"com.tfyswiftssrkit.socks5";

// SOCKS5协议常量
static const uint8_t kSOCKS5Version = 0x05;
static const uint8_t kSOCKS5AuthNone = 0x00;
static const uint8_t kSOCKS5Reserved = 0x00;

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

+ (instancetype)requestWithData:(NSData *)data {
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
    
    NSUInteger index = 4;
    NSString *address = nil;
    
    // 解析地址
    switch (request.addressType) {
        case TFYSOCKS5AddressTypeIPv4: {
            if (data.length < index + 4 + 2) {
                return nil;
            }
            
            struct in_addr addr;
            memcpy(&addr, bytes + index, 4);
            address = [NSString stringWithUTF8String:inet_ntoa(addr)];
            index += 4;
            break;
        }
            
        case TFYSOCKS5AddressTypeDomain: {
            uint8_t domainLength = bytes[index++];
            if (data.length < index + domainLength + 2) {
                return nil;
            }
            
            NSData *domainData = [data subdataWithRange:NSMakeRange(index, domainLength)];
            address = [[NSString alloc] initWithData:domainData encoding:NSUTF8StringEncoding];
            index += domainLength;
            break;
        }
            
        case TFYSOCKS5AddressTypeIPv6: {
            if (data.length < index + 16 + 2) {
                return nil;
            }
            
            char ipv6[INET6_ADDRSTRLEN];
            const void *src = bytes + index;
            if (inet_ntop(AF_INET6, src, ipv6, INET6_ADDRSTRLEN) != NULL) {
                address = [NSString stringWithUTF8String:ipv6];
            } else {
                return nil;
            }
            
            index += 16;
            break;
        }
            
        default:
            return nil;
    }
    
    // 解析端口（网络字节序）
    uint16_t port;
    memcpy(&port, bytes + index, 2);
    request.destinationPort = ntohs(port);
    request.destinationAddress = address;
    
    return request;
}

- (NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    
    // 添加版本、命令、保留字段和地址类型
    uint8_t header[4] = {kSOCKS5Version, self.command, kSOCKS5Reserved, self.addressType};
    [data appendBytes:header length:4];
    
    // 添加地址
    switch (self.addressType) {
        case TFYSOCKS5AddressTypeIPv4: {
            struct in_addr addr;
            inet_aton([self.destinationAddress UTF8String], &addr);
            [data appendBytes:&addr length:4];
            break;
        }
            
        case TFYSOCKS5AddressTypeDomain: {
            NSData *domainData = [self.destinationAddress dataUsingEncoding:NSUTF8StringEncoding];
            uint8_t domainLength = (uint8_t)domainData.length;
            [data appendBytes:&domainLength length:1];
            [data appendData:domainData];
            break;
        }
            
        case TFYSOCKS5AddressTypeIPv6: {
            struct in6_addr addr;
            inet_pton(AF_INET6, [self.destinationAddress UTF8String], &addr);
            [data appendBytes:&addr length:16];
            break;
        }
    }
    
    // 添加端口（网络字节序）
    uint16_t port = htons(self.destinationPort);
    [data appendBytes:&port length:2];
    
    return data;
}

@end

#pragma mark - TFYSOCKS5Reply

@implementation TFYSOCKS5Reply

+ (instancetype)successReplyWithAddress:(NSString *)address port:(uint16_t)port {
    TFYSOCKS5Reply *reply = [[TFYSOCKS5Reply alloc] init];
    reply.replyCode = TFYSOCKS5ReplySuccess;
    reply.boundAddress = address;
    reply.boundPort = port;
    
    // 根据地址类型设置地址类型
    if ([address rangeOfString:@":"].location != NSNotFound) {
        // IPv6地址
        reply.addressType = TFYSOCKS5AddressTypeIPv6;
    } else if ([address rangeOfString:@"."].location != NSNotFound) {
        // IPv4地址
        reply.addressType = TFYSOCKS5AddressTypeIPv4;
    } else {
        // 域名
        reply.addressType = TFYSOCKS5AddressTypeDomain;
    }
    
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

- (NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    
    // 添加版本、回复代码、保留字段和地址类型
    uint8_t header[4] = {kSOCKS5Version, self.replyCode, kSOCKS5Reserved, self.addressType};
    [data appendBytes:header length:4];
    
    // 添加地址
    switch (self.addressType) {
        case TFYSOCKS5AddressTypeIPv4: {
            struct in_addr addr;
            inet_aton([self.boundAddress UTF8String], &addr);
            [data appendBytes:&addr length:4];
            break;
        }
            
        case TFYSOCKS5AddressTypeDomain: {
            NSData *domainData = [self.boundAddress dataUsingEncoding:NSUTF8StringEncoding];
            uint8_t domainLength = (uint8_t)domainData.length;
            [data appendBytes:&domainLength length:1];
            [data appendData:domainData];
            break;
        }
            
        case TFYSOCKS5AddressTypeIPv6: {
            struct in6_addr addr;
            inet_pton(AF_INET6, [self.boundAddress UTF8String], &addr);
            [data appendBytes:&addr length:16];
            break;
        }
    }
    
    // 添加端口（网络字节序）
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
@property (nonatomic, strong) NSInputStream *inputStream;
// 输出流
@property (nonatomic, strong) NSOutputStream *outputStream;
// 缓冲区
@property (nonatomic, strong) NSMutableData *buffer;
// 当前请求
@property (nonatomic, strong) TFYSOCKS5Request *currentRequest;

@end

@implementation TFYOCLibevSOCKS5Handler

#pragma mark - 初始化方法

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = TFYSOCKS5HandlerStateInitial;
        _buffer = [NSMutableData data];
    }
    return self;
}

#pragma mark - 公共方法

- (void)handleClientConnection:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    self.inputStream = inputStream;
    self.outputStream = outputStream;
    
    // 设置代理
    self.inputStream.delegate = self;
    self.outputStream.delegate = self;
    
    // 设置运行循环
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // 打开流
    [self.inputStream open];
    [self.outputStream open];
    
    // 设置状态为认证协商
    self.state = TFYSOCKS5HandlerStateAuthNegotiation;
}

- (void)sendReply:(TFYSOCKS5Reply *)reply toOutputStream:(NSOutputStream *)outputStream {
    NSData *replyData = [reply toData];
    [outputStream write:replyData.bytes maxLength:replyData.length];
}

- (void)processSOCKS5RequestData:(NSData *)data {
    if (data.length < 4) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                              code:1001
                                          userInfo:@{NSLocalizedDescriptionKey: @"无效的SOCKS5请求数据"}]];
        return;
    }
    
    TFYSOCKS5Request *request = [TFYSOCKS5Request requestWithData:data];
    if (!request) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                              code:1002
                                          userInfo:@{NSLocalizedDescriptionKey: @"解析SOCKS5请求失败"}]];
        return;
    }
    
    self.currentRequest = request;
    
    // 根据命令类型处理请求
    switch (request.command) {
        case TFYSOCKS5CommandConnect:
            if ([self.delegate respondsToSelector:@selector(socks5Handler:didReceiveConnectRequestToHost:port:)]) {
                [self.delegate socks5Handler:self didReceiveConnectRequestToHost:request.destinationAddress port:request.destinationPort];
            }
            break;
            
        case TFYSOCKS5CommandBind:
            if ([self.delegate respondsToSelector:@selector(socks5Handler:didReceiveBindRequestToHost:port:)]) {
                [self.delegate socks5Handler:self didReceiveBindRequestToHost:request.destinationAddress port:request.destinationPort];
            }
            break;
            
        case TFYSOCKS5CommandUDPAssociate:
            if ([self.delegate respondsToSelector:@selector(socks5Handler:didReceiveUDPAssociateRequestToHost:port:)]) {
                [self.delegate socks5Handler:self didReceiveUDPAssociateRequestToHost:request.destinationAddress port:request.destinationPort];
            }
            break;
            
        default: {
            // 不支持的命令
            TFYSOCKS5Reply *reply = [TFYSOCKS5Reply failureReplyWithCode:TFYSOCKS5ReplyCommandNotSupported];
            [self sendReply:reply toOutputStream:self.outputStream];
            [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                                  code:1003
                                              userInfo:@{NSLocalizedDescriptionKey: @"不支持的SOCKS5命令"}]];
            break;
        }
    }
}

#pragma mark - 私有方法

- (void)handleAuthNegotiation:(NSData *)data {
    if (data.length < 2) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                              code:1004
                                          userInfo:@{NSLocalizedDescriptionKey: @"无效的认证协商数据"}]];
        return;
    }
    
    const uint8_t *bytes = data.bytes;
    
    // 检查SOCKS5版本
    if (bytes[0] != kSOCKS5Version) {
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                              code:1005
                                          userInfo:@{NSLocalizedDescriptionKey: @"不支持的SOCKS版本"}]];
        return;
    }
    
    // 检查是否支持无认证方式
    uint8_t numMethods = bytes[1];
    BOOL supportsNoAuth = NO;
    
    for (NSUInteger i = 0; i < numMethods && i + 2 < data.length; i++) {
        if (bytes[i + 2] == kSOCKS5AuthNone) {
            supportsNoAuth = YES;
            break;
        }
    }
    
    // 发送认证方法选择响应
    uint8_t response[2] = {kSOCKS5Version, supportsNoAuth ? kSOCKS5AuthNone : 0xFF};
    [self.outputStream write:response maxLength:2];
    
    if (supportsNoAuth) {
        // 设置状态为请求处理
        self.state = TFYSOCKS5HandlerStateRequest;
    } else {
        // 不支持无认证方式，关闭连接
        [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                              code:1006
                                          userInfo:@{NSLocalizedDescriptionKey: @"不支持无认证方式"}]];
    }
}

- (void)handleError:(NSError *)error {
    self.state = TFYSOCKS5HandlerStateError;
    
    if ([self.delegate respondsToSelector:@selector(socks5Handler:didEncounterError:)]) {
        [self.delegate socks5Handler:self didEncounterError:error];
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

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable: {
            if (aStream == self.inputStream) {
                uint8_t buffer[4096];
                NSInteger bytesRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
                
                if (bytesRead > 0) {
                    [self.buffer appendBytes:buffer length:bytesRead];
                    
                    // 根据当前状态处理数据
                    switch (self.state) {
                        case TFYSOCKS5HandlerStateAuthNegotiation:
                            [self handleAuthNegotiation:self.buffer];
                            [self.buffer setLength:0];
                            break;
                            
                        case TFYSOCKS5HandlerStateRequest:
                            [self processSOCKS5RequestData:self.buffer];
                            [self.buffer setLength:0];
                            break;
                            
                        case TFYSOCKS5HandlerStateForwarding:
                            // 在转发状态下，直接将数据转发到目标服务器
                            // 这部分逻辑由代理对象处理
                            break;
                            
                        default:
                            break;
                    }
                }
            }
            break;
        }
            
        case NSStreamEventErrorOccurred: {
            NSError *error = [aStream streamError];
            [self handleError:error];
            break;
        }
            
        case NSStreamEventEndEncountered: {
            // 流结束，关闭连接
            [self handleError:[NSError errorWithDomain:TFYOCLibevSOCKS5ErrorDomain
                                                  code:1007
                                              userInfo:@{NSLocalizedDescriptionKey: @"连接已关闭"}]];
            break;
        }
            
        default:
            break;
    }
}

@end 