#import <Foundation/Foundation.h>
#import "TFYSSCoreProtocol.h"

NS_ASSUME_NONNULL_BEGIN

// C回调函数声明
#ifdef __cplusplus
extern "C" {
#endif

BOOL TFYSSRustShouldProxyHost(const char *host);
BOOL TFYSSRustShouldProxyIP(const char *ip);

#ifdef __cplusplus
}
#endif

NS_SWIFT_NAME(TFYRustCore)
@interface TFYSSRustCore : NSObject <TFYSSCoreProtocol>

@end

NS_ASSUME_NONNULL_END
