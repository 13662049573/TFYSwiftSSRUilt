#import <Foundation/Foundation.h>
#import "TFYSSConfig.h"
#import "TFYSSTypes.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TFYSSVPNServiceDelegate;

NS_SWIFT_NAME(TFYVPNService)
@interface TFYSSVPNService : NSObject

// VPN 状态
@property (nonatomic, readonly) TFYSSVPNState state NS_SWIFT_NAME(state);

// 流量统计
@property (nonatomic, readonly) uint64_t uploadTraffic NS_SWIFT_NAME(uploadTraffic);
@property (nonatomic, readonly) uint64_t downloadTraffic NS_SWIFT_NAME(downloadTraffic);

// VPN 配置
@property (nonatomic, readonly, strong) TFYSSConfig *currentConfig NS_SWIFT_NAME(currentConfig);

// VPN 回调
@property (nonatomic, weak) id<TFYSSVPNServiceDelegate> delegate;

// 单例方法
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

// 安装 VPN 配置
- (void)installVPNProfileWithCompletion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(installVPNProfile(completion:));

// 移除 VPN 配置
- (void)removeVPNProfileWithCompletion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(removeVPNProfile(completion:));

// 启动 VPN
- (void)startWithConfig:(TFYSSConfig *)config 
             completion:(nullable void (^)(NSError * _Nullable error))completion 
    NS_SWIFT_NAME(start(config:completion:));

// 停止 VPN
- (void)stopWithCompletion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(stop(completion:));

// 更新配置
- (void)updateConfig:(TFYSSConfig *)config 
          completion:(nullable void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(update(config:completion:));

// 重置流量统计
- (void)resetTrafficStats NS_SWIFT_NAME(resetTrafficStats());

// 检查 VPN 权限
- (void)checkVPNPermissionWithCompletion:(void (^)(BOOL granted, NSError * _Nullable error))completion
    NS_SWIFT_NAME(checkVPNPermission(completion:));

// 自动重连
@property (nonatomic, readonly) BOOL autoReconnect NS_SWIFT_NAME(autoReconnect);

/**
 * 设置是否自动重连
 * @param enable 是否启用自动重连
 */
- (void)setAutoReconnectEnabled:(BOOL)enable NS_SWIFT_NAME(setAutoReconnectEnabled(_:));

@end

// VPN 服务回调协议
NS_SWIFT_NAME(TFYVPNServiceDelegate)
@protocol TFYSSVPNServiceDelegate <NSObject>

@optional
// 状态变化回调
- (void)vpnService:(TFYSSVPNService *)service 
     didChangeState:(TFYSSVPNState)state 
    NS_SWIFT_NAME(vpnService(_:didChangeState:));

// 流量更新回调
- (void)vpnService:(TFYSSVPNService *)service 
    didUpdateTraffic:(uint64_t)uploadTraffic 
           download:(uint64_t)downloadTraffic
    NS_SWIFT_NAME(vpnService(_:didUpdateTraffic:download:));

// 错误回调
- (void)vpnService:(TFYSSVPNService *)service 
    didEncounterError:(NSError *)error
    NS_SWIFT_NAME(vpnService(_:didEncounterError:));

@end

NS_ASSUME_NONNULL_END 