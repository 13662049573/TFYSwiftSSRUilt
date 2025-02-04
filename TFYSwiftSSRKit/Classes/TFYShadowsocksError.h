#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const TFYShadowsocksErrorDomain;

typedef NS_ENUM(NSInteger, TFYShadowsocksErrorCode) {
    TFYShadowsocksErrorCodeUnknown = -1,
    TFYShadowsocksErrorCodeInvalidConfiguration = 1000,
    TFYShadowsocksErrorCodeConnectionFailed = 1001,
    TFYShadowsocksErrorCodeAuthenticationFailed = 1002,
    TFYShadowsocksErrorCodeEncryptionFailed = 1003,
    TFYShadowsocksErrorCodeDecryptionFailed = 1004,
    TFYShadowsocksErrorCodeNetworkUnreachable = 1005,
    TFYShadowsocksErrorCodeServerUnreachable = 1006,
    TFYShadowsocksErrorCodeTimeout = 1007
};

@interface TFYShadowsocksError : NSObject

+ (NSError *)errorWithCode:(TFYShadowsocksErrorCode)code;
+ (NSError *)errorWithCode:(TFYShadowsocksErrorCode)code userInfo:(nullable NSDictionary *)userInfo;
+ (NSString *)localizedDescriptionForErrorCode:(TFYShadowsocksErrorCode)code;

@end

NS_ASSUME_NONNULL_END 