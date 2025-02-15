#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFYTunnelManager : NSObject

@property (nonatomic, strong, readonly) NEVPNManager *vpnManager;
@property (nonatomic, strong, readonly) NETunnelProviderManager *tunnelManager;
@property (nonatomic, assign, readonly) BOOL isConnected;

+ (instancetype)sharedManager;

// 启动隧道
- (void)startTunnelWithConfiguration:(NSDictionary *)config
                        completion:(void(^)(NSError * _Nullable error))completion;

// 停止隧道
- (void)stopTunnelWithCompletion:(void(^)(NSError * _Nullable error))completion;

// 获取隧道状态
- (void)getTunnelStatusWithCompletion:(void(^)(NSDictionary *status, NSError * _Nullable error))completion;

// 更新配置
- (void)updateConfiguration:(NSDictionary *)config
                completion:(void(^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 