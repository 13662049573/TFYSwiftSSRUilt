#import <Foundation/Foundation.h>
#import "TFYSSTypes.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TFYConfig)
@interface TFYSSConfig : NSObject

// 基础配置
@property (nonatomic, copy, nullable) NSString *serverHost NS_SWIFT_NAME(server);      // 服务器地址
@property (nonatomic, assign) uint16_t serverPort;     // 服务器端口
@property (nonatomic, copy) NSString *localAddress;    // 本地地址
@property (nonatomic, assign) uint16_t localPort;      // 本地端口
@property (nonatomic, copy, nullable) NSString *method;          // 加密方法
@property (nonatomic, copy, nullable) NSString *password;        // 密码
@property (nonatomic, assign) NSTimeInterval timeout;  // 超时时间

// SSR 特有配置
@property (nonatomic, assign, getter=isSSR) BOOL SSR NS_SWIFT_NAME(isSSR);            // 是否为 SSR
@property (nonatomic, copy, nullable) NSString *protocol;        // SSR 协议
@property (nonatomic, copy, nullable) NSString *obfs;            // SSR 混淆
@property (nonatomic, copy, nullable) NSString *protocolParam;   // SSR 协议参数
@property (nonatomic, copy, nullable) NSString *obfsParam;       // SSR 混淆参数

//VPN 配置
@property (nonatomic, copy, nullable) NSString *tunnelID NS_SWIFT_NAME(tunnelID);
@property (nonatomic, copy, nullable) NSString *vpnName NS_SWIFT_NAME(vpnName);

// 高级配置
@property (nonatomic, assign) TFYSSCoreType preferredCoreType NS_SWIFT_NAME(preferredCore);  // 首选核心类型
@property (nonatomic, assign, getter=isUseRust) BOOL useRust NS_SWIFT_NAME(useRust);         // 使用 Rust 核心
@property (nonatomic, assign, getter=isNATEnabled) BOOL enableNAT NS_SWIFT_NAME(natEnabled);          // 启用 NAT 穿透
@property (nonatomic, assign, getter=isHTTPEnabled) BOOL enableHTTP NS_SWIFT_NAME(httpEnabled);         // 启用 HTTP 代理
@property (nonatomic, assign) uint16_t httpPort;       // HTTP 代理端口

// 规则配置
@property (nonatomic, assign, getter=isRuleEnabled) BOOL enableRule NS_SWIFT_NAME(ruleEnabled);        // 启用规则路由
@property (nonatomic, copy, nullable) NSString *activeRuleSetName NS_SWIFT_NAME(activeRuleSet);        // 当前激活的规则集名称

// 初始化方法
- (instancetype)initWithServer:(NSString *)server 
                        port:(uint16_t)port 
                     method:(nullable NSString *)method 
                  password:(nullable NSString *)password NS_SWIFT_NAME(init(server:port:method:password:));

// 转换方法
- (NSDictionary<NSString *, id> *)toJSON NS_SWIFT_NAME(toJSON());
- (nullable instancetype)initWithJSON:(NSDictionary<NSString *, id> *)json NS_SWIFT_NAME(init(json:));

// 验证方法
- (BOOL)validate:(NSError **)error NS_SWIFT_NAME(validate());

@end

NS_ASSUME_NONNULL_END 
