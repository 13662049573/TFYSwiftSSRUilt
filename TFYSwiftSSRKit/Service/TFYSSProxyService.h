#import <Foundation/Foundation.h>
#import "TFYSSConfig.h"
#import "TFYSSTypes.h"
#import "TFYSSRuleManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TFYSSProxyServiceDelegate;

NS_SWIFT_NAME(TFYProxyService)
@interface TFYSSProxyService : NSObject

// 代理状态
@property (nonatomic, readonly) TFYSSProxyState state NS_SWIFT_NAME(state);

// 流量统计
@property (nonatomic, readonly) uint64_t uploadTraffic NS_SWIFT_NAME(uploadTraffic);
@property (nonatomic, readonly) uint64_t downloadTraffic NS_SWIFT_NAME(downloadTraffic);

// 代理配置
@property (nonatomic, readonly, strong) TFYSSConfig *currentConfig NS_SWIFT_NAME(currentConfig);

// 规则管理器
@property (nonatomic, readonly, strong) TFYSSRuleManager *ruleManager NS_SWIFT_NAME(ruleManager);

// 代理回调
@property (nonatomic, weak) id<TFYSSProxyServiceDelegate> delegate;

// 单例方法
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

// 启动代理
- (void)startWithConfig:(TFYSSConfig *)config 
             completion:(nullable void (^)(NSError * _Nullable error))completion 
    NS_SWIFT_NAME(start(config:completion:));

// 停止代理
- (void)stopWithCompletion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(stop(completion:));

// 更新配置
- (void)updateConfig:(TFYSSConfig *)config 
          completion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(update(config:completion:));

// 重置流量统计
- (void)resetTrafficStats NS_SWIFT_NAME(resetTrafficStats());

// 规则相关方法
- (void)enableRuleRouting:(BOOL)enable 
               completion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(enableRuleRouting(_:completion:));

- (void)setActiveRuleSet:(nullable NSString *)ruleSetName 
              completion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(setActiveRuleSet(_:completion:));

// 判断主机是否应该使用代理
- (BOOL)shouldProxyHost:(NSString *)host NS_SWIFT_NAME(shouldProxy(host:));
- (BOOL)shouldProxyURL:(NSURL *)url NS_SWIFT_NAME(shouldProxy(url:));
- (BOOL)shouldProxyIP:(NSString *)ip NS_SWIFT_NAME(shouldProxy(ip:));

@end

// 代理服务回调协议
NS_SWIFT_NAME(TFYProxyServiceDelegate)
@protocol TFYSSProxyServiceDelegate <NSObject>

@optional
// 状态变化回调
- (void)proxyService:(TFYSSProxyService *)service 
     didChangeState:(TFYSSProxyState)state 
    NS_SWIFT_NAME(proxyService(_:didChangeState:));

// 流量更新回调
- (void)proxyService:(TFYSSProxyService *)service 
    didUpdateTraffic:(uint64_t)uploadTraffic 
           download:(uint64_t)downloadTraffic
    NS_SWIFT_NAME(proxyService(_:didUpdateTraffic:download:));

// 错误回调
- (void)proxyService:(TFYSSProxyService *)service 
    didEncounterError:(NSError *)error
    NS_SWIFT_NAME(proxyService(_:didEncounterError:));

// 规则匹配回调
- (void)proxyService:(TFYSSProxyService *)service 
         didMatchHost:(NSString *)host 
              result:(TFYSSRuleMatchResult)result 
             ruleSet:(nullable TFYSSRuleSet *)ruleSet
    NS_SWIFT_NAME(proxyService(_:didMatchHost:result:ruleSet:));

@end

NS_ASSUME_NONNULL_END 