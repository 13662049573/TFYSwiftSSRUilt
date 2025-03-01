#import <Foundation/Foundation.h>
#import "TFYSSTypes.h"
#import "TFYSSConfig.h"

NS_ASSUME_NONNULL_BEGIN

// 流量统计回调
typedef void(^TFYSSTrafficStatsCallback)(uint64_t uploadBytes, uint64_t downloadBytes);

NS_SWIFT_NAME(TFYCoreProtocol)
@protocol TFYSSCoreProtocol <NSObject>

@property (nonatomic, readonly) TFYSSCoreType type NS_SWIFT_NAME(coreType);
@property (nonatomic, readonly, copy) NSString *version;
@property (nonatomic, readonly) TFYSSCoreCapability capabilities;

// 初始化引擎
- (BOOL)initializeEngine NS_SWIFT_NAME(initialize());

// 启动代理服务
- (BOOL)startWithConfig:(TFYSSConfig *)config 
                 error:(NSError **)error NS_SWIFT_NAME(start(config:));

// 停止代理服务
- (BOOL)stop NS_SWIFT_NAME(stop());

// 获取流量统计
- (void)getTrafficWithUpload:(uint64_t *)upload 
                   download:(uint64_t *)download NS_SWIFT_NAME(getTraffic(upload:download:));

// 更新流量统计
- (void)updateTrafficStats NS_SWIFT_NAME(updateTrafficStats());

// 设置流量统计回调
- (void)setTrafficStatsCallback:(TFYSSTrafficStatsCallback)callback NS_SWIFT_NAME(setTrafficStatsCallback(_:));

@optional
// 检测NAT类型
- (void)detectNATTypeWithCompletion:(void (^)(NSString *natType))completion NS_SWIFT_NAME(detectNATType(completion:));

// 设置HTTP代理
- (BOOL)setupHTTPProxyWithPort:(uint16_t)port error:(NSError **)error NS_SWIFT_NAME(setupHTTPProxy(port:));

// 停止HTTP代理
- (void)stopHTTPProxy NS_SWIFT_NAME(stopHTTPProxy());

// 规则路由相关方法
- (BOOL)shouldProxyHost:(NSString *)host NS_SWIFT_NAME(shouldProxy(host:));
- (BOOL)shouldProxyURL:(NSURL *)url NS_SWIFT_NAME(shouldProxy(url:));
- (BOOL)shouldProxyIP:(NSString *)ip NS_SWIFT_NAME(shouldProxy(ip:));

@end

NS_ASSUME_NONNULL_END 