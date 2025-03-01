#import "TFYSSError.h"

NSString *const TFYSSErrorDomain = @"com.tfyswiftssrkit.error";

// 错误描述字典
static NSDictionary *TFYSSErrorDescriptions() {
    static NSDictionary *descriptions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        descriptions = @{
            @(TFYSSErrorUnknown): @"未知错误",
            @(TFYSSErrorConfigInvalid): @"配置无效",
            @(TFYSSErrorStartFailed): @"启动失败",
            @(TFYSSErrorStopFailed): @"停止失败",
            @(TFYSSErrorNetworkUnavailable): @"网络不可用",
            @(TFYSSErrorNetworkUnreachable): @"网络不可达",
            @(TFYSSErrorServerUnreachable): @"服务器不可达",
            @(TFYSSErrorEngineInitFailed): @"引擎初始化失败",
            @(TFYSSErrorNATInitFailed): @"NAT 初始化失败",
            @(TFYSSErrorHTTPInitFailed): @"HTTP 代理初始化失败",
            @(TFYSSErrorAuthenticationFailed): @"认证失败",
            @(TFYSSErrorEncryptionFailed): @"加密失败",
            @(TFYSSErrorDecryptionFailed): @"解密失败"
        };
    });
    return descriptions;
}

NSError *TFYSSErrorWithCode(TFYSSErrorCode code) {
    NSString *description = TFYSSErrorDescriptions()[@(code)] ?: @"未知错误";
    return [NSError errorWithDomain:TFYSSErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey: description}];
}

NSError *TFYSSErrorWithCodeAndMessage(TFYSSErrorCode code, NSString *message) {
    return [NSError errorWithDomain:TFYSSErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey: message}];
}

BOOL TFYSSIsError(NSError *error, TFYSSErrorCode code) {
    return [error.domain isEqualToString:TFYSSErrorDomain] && error.code == code;
}