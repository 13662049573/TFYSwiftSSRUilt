#ifndef TFYSSManager_h
#define TFYSSManager_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// SS 日志级别
typedef NS_ENUM(NSInteger, TFYSSLogLevel) {
    TFYSSLogLevelError = 0,
    TFYSSLogLevelWarn = 1,
    TFYSSLogLevelInfo = 2,
    TFYSSLogLevelDebug = 3,
    TFYSSLogLevelTrace = 4
} NS_SWIFT_NAME(SSLogLevel);

/// SS 代理模式
typedef NS_ENUM(NSInteger, TFYSSProxyMode) {
    TFYSSProxyModePAC = 0,
    TFYSSProxyModeGlobal = 1
} NS_SWIFT_NAME(SSProxyMode);

/// SS 状态
typedef NS_ENUM(NSInteger, TFYSSState) {
    TFYSSStateStopped = 0,
    TFYSSStateRunning = 1,
    TFYSSStateError = -1
} NS_SWIFT_NAME(SSState);

/// SS 配置
NS_SWIFT_NAME(SSConfig)
@interface TFYSSConfig : NSObject

/// 服务器地址
@property (nonatomic, copy) NSString *serverAddress;
/// 提供者 Bundle ID
@property (nonatomic, copy) NSString *providerBundleIdentifier;
/// 设置标题
@property (nonatomic, copy) NSString *settingsTitle;
/// 服务器端口
@property (nonatomic, assign) uint16_t serverPort;
/// 密码
@property (nonatomic, copy) NSString *password;
/// 加密方法
@property (nonatomic, copy) NSString *method;
/// 超时时间
@property (nonatomic, assign) NSInteger timeout;

/// 初始化配置
- (instancetype)initWithServerAddress:(NSString *)serverAddress
                         serverPort:(uint16_t)serverPort
                          password:(NSString *)password
                           method:(NSString *)method
                          timeout:(NSInteger)timeout NS_SWIFT_NAME(init(serverAddress:serverPort:password:method:timeout:));

/// 转换为字典
- (NSDictionary *)toDictionary;
/// 转换为 JSON 字符串
- (nullable NSString *)toJSONString;

@end

/// SS 管理器
NS_SWIFT_NAME(SSManager)
@interface TFYSSManager : NSObject

/// 共享实例
@property (class, readonly) TFYSSManager *shared;
/// 版本号
@property (nonatomic, readonly) NSString *version;
/// 当前状态
@property (nonatomic, readonly) TFYSSState state;
/// 日志级别
@property (nonatomic, assign) TFYSSLogLevel logLevel;
/// 代理模式
@property (nonatomic, assign) TFYSSProxyMode proxyMode;
/// 最后的错误信息
@property (nonatomic, readonly) NSString *lastError;
/// 上传流量
@property (nonatomic, readonly) uint64_t uploadTraffic;
/// 下载流量
@property (nonatomic, readonly) uint64_t downloadTraffic;
/// 服务器地址
@property (nonatomic, readonly) NSString *serverAddress;
/// 服务器端口
@property (nonatomic, readonly) uint16_t serverPort;

/// 初始化设置
- (void)setup;

/// 启动服务
/// @param config 配置信息
/// @return 是否成功启动
- (BOOL)startWithConfig:(NSDictionary *)config NS_SWIFT_NAME(startProxy(withConfig:));

/// 停止服务
- (void)stop;

/// 更新 PAC 规则
/// @param rules 规则内容
/// @return 是否成功更新
- (BOOL)updatePACRules:(NSString *)rules NS_SWIFT_NAME(updatePacrules(rules:));

@end

NS_ASSUME_NONNULL_END

#endif /* TFYSSManager_h */ 
