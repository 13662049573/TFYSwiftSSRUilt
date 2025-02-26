//
//  TFYOCLibevSOCKS5Handler.h
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// SOCKS5命令类型
typedef NS_ENUM(uint8_t, TFYSOCKS5Command) {
    TFYSOCKS5CommandConnect = 0x01,      // 连接
    TFYSOCKS5CommandBind = 0x02,         // 绑定
    TFYSOCKS5CommandUDPAssociate = 0x03  // UDP关联
};

// SOCKS5地址类型
typedef NS_ENUM(uint8_t, TFYSOCKS5AddressType) {
    TFYSOCKS5AddressTypeIPv4 = 0x01,     // IPv4地址
    TFYSOCKS5AddressTypeDomain = 0x03,   // 域名
    TFYSOCKS5AddressTypeIPv6 = 0x04      // IPv6地址
};

// SOCKS5回复代码
typedef NS_ENUM(uint8_t, TFYSOCKS5ReplyCode) {
    TFYSOCKS5ReplySuccess = 0x00,                // 成功
    TFYSOCKS5ReplyGeneralFailure = 0x01,         // 一般性失败
    TFYSOCKS5ReplyConnectionNotAllowed = 0x02,   // 规则不允许连接
    TFYSOCKS5ReplyNetworkUnreachable = 0x03,     // 网络不可达
    TFYSOCKS5ReplyHostUnreachable = 0x04,        // 主机不可达
    TFYSOCKS5ReplyConnectionRefused = 0x05,      // 连接被拒绝
    TFYSOCKS5ReplyTTLExpired = 0x06,             // TTL过期
    TFYSOCKS5ReplyCommandNotSupported = 0x07,    // 不支持的命令
    TFYSOCKS5ReplyAddressTypeNotSupported = 0x08 // 不支持的地址类型
};

// SOCKS5请求结构
@interface TFYSOCKS5Request : NSObject

@property (nonatomic, assign) TFYSOCKS5Command command;
@property (nonatomic, assign) TFYSOCKS5AddressType addressType;
@property (nonatomic, copy) NSString *destinationAddress;
@property (nonatomic, assign) uint16_t destinationPort;

// 从数据解析请求
+ (nullable instancetype)requestWithData:(NSData *)data;
// 转换为数据
- (NSData *)toData;

@end

// SOCKS5回复结构
@interface TFYSOCKS5Reply : NSObject

@property (nonatomic, assign) TFYSOCKS5ReplyCode replyCode;
@property (nonatomic, assign) TFYSOCKS5AddressType addressType;
@property (nonatomic, copy) NSString *boundAddress;
@property (nonatomic, assign) uint16_t boundPort;

// 创建成功回复
+ (instancetype)successReplyWithAddress:(NSString *)address port:(uint16_t)port;
// 创建失败回复
+ (instancetype)failureReplyWithCode:(TFYSOCKS5ReplyCode)code;
// 转换为数据
- (NSData *)toData;

@end

// SOCKS5处理器代理协议
@protocol TFYOCLibevSOCKS5HandlerDelegate <NSObject>

@optional
// 收到连接请求回调
- (void)socks5Handler:(id)handler didReceiveConnectRequestToHost:(NSString *)host port:(uint16_t)port;
// 收到绑定请求回调
- (void)socks5Handler:(id)handler didReceiveBindRequestToHost:(NSString *)host port:(uint16_t)port;
// 收到UDP关联请求回调
- (void)socks5Handler:(id)handler didReceiveUDPAssociateRequestToHost:(NSString *)host port:(uint16_t)port;
// 处理错误回调
- (void)socks5Handler:(id)handler didEncounterError:(NSError *)error;

@end

// SOCKS5处理器类
@interface TFYOCLibevSOCKS5Handler : NSObject

// 代理对象
@property (nonatomic, weak) id<TFYOCLibevSOCKS5HandlerDelegate> delegate;

// 处理客户端连接
- (void)handleClientConnection:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;
// 发送回复
- (void)sendReply:(TFYSOCKS5Reply *)reply toOutputStream:(NSOutputStream *)outputStream;
// 处理SOCKS5请求数据
- (void)processSOCKS5RequestData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END 