#import <NetworkExtension/NetworkExtension.h>
#import "TFYSSConfig.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TFYPacketTunnelProvider)
@interface TFYSSPacketTunnelProvider : NEPacketTunnelProvider

// 启动隧道
- (void)startTunnelWithConfig:(TFYSSConfig *)config completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

// 停止隧道
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler;

// 获取流量统计
- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download;

@end

NS_ASSUME_NONNULL_END 