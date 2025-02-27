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
} NS_SWIFT_NAME(SOCKS5Command);

// SOCKS5地址类型
typedef NS_ENUM(uint8_t, TFYSOCKS5AddressType) {
    TFYSOCKS5AddressTypeIPv4 = 0x01,     // IPv4地址
    TFYSOCKS5AddressTypeDomain = 0x03,   // 域名
    TFYSOCKS5AddressTypeIPv6 = 0x04      // IPv6地址
} NS_SWIFT_NAME(SOCKS5AddressType);

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
} NS_SWIFT_NAME(SOCKS5ReplyCode);

// SOCKS5请求结构
NS_SWIFT_NAME(SOCKS5Request)
@interface TFYSOCKS5Request : NSObject

@property (nonatomic, assign) TFYSOCKS5Command command;
@property (nonatomic, assign) TFYSOCKS5AddressType addressType;
@property (nonatomic, copy, nonnull) NSString *destinationAddress;
@property (nonatomic, assign) uint16_t destinationPort;

// 从数据解析请求
+ (nullable instancetype)requestWithData:(nonnull NSData *)data;
// 转换为数据
- (nonnull NSData *)toData;

@end

// SOCKS5回复结构
NS_SWIFT_NAME(SOCKS5Reply)
@interface TFYSOCKS5Reply : NSObject

@property (nonatomic, assign) TFYSOCKS5ReplyCode replyCode;
@property (nonatomic, assign) TFYSOCKS5AddressType addressType;
@property (nonatomic, copy, nonnull) NSString *boundAddress;
@property (nonatomic, assign) uint16_t boundPort;

// 创建成功回复
+ (instancetype)successReplyWithAddress:(nonnull NSString *)address port:(uint16_t)port;
// 创建失败回复
+ (instancetype)failureReplyWithCode:(TFYSOCKS5ReplyCode)code;
// 转换为数据
- (nonnull NSData *)toData;

@end

// SOCKS5处理器代理协议
NS_SWIFT_NAME(LibevSOCKS5HandlerDelegate)
@protocol TFYOCLibevSOCKS5HandlerDelegate <NSObject>

@optional
// 收到连接请求回调
- (void)socks5Handler:(nonnull id)handler didReceiveConnectRequestToHost:(nonnull NSString *)host port:(uint16_t)port;
// 收到绑定请求回调
- (void)socks5Handler:(nonnull id)handler didReceiveBindRequestToHost:(nonnull NSString *)host port:(uint16_t)port;
// 收到UDP关联请求回调
- (void)socks5Handler:(nonnull id)handler didReceiveUDPAssociateRequestToHost:(nonnull NSString *)host port:(uint16_t)port;
// 处理错误回调
- (void)socks5Handler:(nonnull id)handler didEncounterError:(nonnull NSError *)error;

@end

// SOCKS5处理器类
NS_SWIFT_NAME(LibevSOCKS5Handler)
@interface TFYOCLibevSOCKS5Handler : NSObject

// 代理对象
@property (nonatomic, weak, nullable) id<TFYOCLibevSOCKS5HandlerDelegate> delegate;

// 处理客户端连接
- (void)handleClientConnection:(nonnull NSInputStream *)inputStream outputStream:(nonnull NSOutputStream *)outputStream;
// 发送回复
- (void)sendReply:(nonnull TFYSOCKS5Reply *)reply toOutputStream:(nonnull NSOutputStream *)outputStream;
// 处理SOCKS5请求数据
- (void)processSOCKS5RequestData:(nonnull NSData *)data;

@end

NS_ASSUME_NONNULL_END 