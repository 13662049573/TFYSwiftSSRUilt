#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 错误域
extern NSString *const TFYSSErrorDomain;

// 错误码定义
typedef NS_ENUM(NSInteger, TFYSSErrorCode) {
    TFYSSErrorUnknown = 999,           // 未知错误
    TFYSSErrorConfigInvalid = 1000,    // 配置无效
    TFYSSErrorStartFailed,             // 启动失败
    TFYSSErrorStopFailed,              // 停止失败
    TFYSSErrorEngineInitFailed,        // 引擎初始化失败
    TFYSSErrorNATInitFailed,           // NAT 初始化失败
    TFYSSErrorHTTPInitFailed,          // HTTP 代理初始化失败
    TFYSSErrorNetworkUnavailable,      // 网络不可用
    TFYSSErrorNetworkUnreachable,      // 网络不可达
    TFYSSErrorServerUnreachable,       // 服务器不可达
    TFYSSErrorAuthenticationFailed,     // 认证失败
    TFYSSErrorEncryptionFailed,        // 加密失败
    TFYSSErrorDecryptionFailed,        // 解密失败
    TFYSSErrorUpdateConfigFailed,      // 更新配置失败
    TFYSSErrorVPNStartFailure,         // VPN 启动失败
} NS_SWIFT_NAME(TFYError);

// 为了保持兼容性，定义 TFYSSError 作为 TFYSSErrorCode 的别名
typedef TFYSSErrorCode TFYSSError;

// 错误工具函数
NSError * TFYSSErrorWithCodeAndMessage(TFYSSErrorCode code, NSString *message) NS_SWIFT_NAME(TFYError(code:message:));
NSError * TFYSSErrorWithCode(TFYSSErrorCode code) NS_SWIFT_NAME(TFYError(code:));
BOOL TFYSSIsError(NSError *error, TFYSSErrorCode code) NS_SWIFT_NAME(isTFYError(error:code:));

NS_ASSUME_NONNULL_END 