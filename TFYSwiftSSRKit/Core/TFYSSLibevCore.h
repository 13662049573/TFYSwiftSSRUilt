#import <Foundation/Foundation.h>
#import "TFYSSCoreProtocol.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TFYLibevCore)
@interface TFYSSLibevCore : NSObject <TFYSSCoreProtocol>

@property (nonatomic, assign, getter=isNATEnabled) BOOL enableNAT NS_SWIFT_NAME(natEnabled);       // 启用 NAT 穿透
@property (nonatomic, assign, getter=isHTTPEnabled) BOOL enableHTTP NS_SWIFT_NAME(httpEnabled);      // 启用 HTTP 代理

// 实现 TFYSSCoreProtocol 协议的方法
- (BOOL)initializeEngine NS_SWIFT_NAME(initialize());
- (BOOL)startWithConfig:(TFYSSConfig *)config error:(NSError **)error NS_SWIFT_NAME(start(config:));
- (BOOL)stop NS_SWIFT_NAME(stop());
- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download NS_SWIFT_NAME(getTraffic(upload:download:));

// NAT 相关方法
- (nullable NSDictionary<NSString *, id> *)detectNATType NS_SWIFT_NAME(detectNATType());
- (BOOL)enableNATTraversal:(NSString *)server 
                     port:(NSInteger)port NS_SWIFT_NAME(enableNATTraversal(server:port:));

// HTTP 代理方法
- (BOOL)startHTTPProxy:(NSString *)listenAddr 
                 port:(NSInteger)port NS_SWIFT_NAME(startHTTPProxy(address:port:));
- (void)stopHTTPProxy NS_SWIFT_NAME(stopHTTPProxy());

@end

NS_ASSUME_NONNULL_END 