#import "TFYShadowsocksError.h"

NSString * const TFYShadowsocksErrorDomain = @"com.tfy.shadowsocks.error";

@implementation TFYShadowsocksError

+ (NSError *)errorWithCode:(TFYShadowsocksErrorCode)code {
    return [self errorWithCode:code userInfo:nil];
}

+ (NSError *)errorWithCode:(TFYShadowsocksErrorCode)code userInfo:(nullable NSDictionary *)userInfo {
    NSMutableDictionary *finalUserInfo = [NSMutableDictionary dictionary];
    
    if (userInfo) {
        [finalUserInfo addEntriesFromDictionary:userInfo];
    }
    
    if (!finalUserInfo[NSLocalizedDescriptionKey]) {
        finalUserInfo[NSLocalizedDescriptionKey] = [self localizedDescriptionForErrorCode:code];
    }
    
    return [NSError errorWithDomain:TFYShadowsocksErrorDomain code:code userInfo:finalUserInfo];
}

+ (NSString *)localizedDescriptionForErrorCode:(TFYShadowsocksErrorCode)code {
    switch (code) {
        case TFYShadowsocksErrorCodeUnknown:
            return NSLocalizedString(@"An unknown error occurred", nil);
            
        case TFYShadowsocksErrorCodeInvalidConfiguration:
            return NSLocalizedString(@"The configuration is invalid", nil);
            
        case TFYShadowsocksErrorCodeConnectionFailed:
            return NSLocalizedString(@"Failed to establish connection", nil);
            
        case TFYShadowsocksErrorCodeAuthenticationFailed:
            return NSLocalizedString(@"Authentication failed", nil);
            
        case TFYShadowsocksErrorCodeEncryptionFailed:
            return NSLocalizedString(@"Failed to encrypt data", nil);
            
        case TFYShadowsocksErrorCodeDecryptionFailed:
            return NSLocalizedString(@"Failed to decrypt data", nil);
            
        case TFYShadowsocksErrorCodeNetworkUnreachable:
            return NSLocalizedString(@"Network is unreachable", nil);
            
        case TFYShadowsocksErrorCodeServerUnreachable:
            return NSLocalizedString(@"Server is unreachable", nil);
            
        case TFYShadowsocksErrorCodeTimeout:
            return NSLocalizedString(@"Connection timed out", nil);
    }
}

@end 