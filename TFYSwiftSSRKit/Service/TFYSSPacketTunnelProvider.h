#import <NetworkExtension/NetworkExtension.h>
#import "TFYSSConfig.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TFYPacketTunnelProvider)
@interface TFYSSPacketTunnelProvider : NEPacketTunnelProvider

// 启动隧道
- (void)startTunnelWithConfig:(TFYSSConfig *)config completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(startTunnel(with:completionHandler:));

// 停止隧道
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler NS_SWIFT_NAME(stopTunnel(with:completionHandler:));

// 获取流量统计
- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download NS_SWIFT_NAME(getTraffic(withUpload:download:));

// 发送消息到应用
- (void)sendMessageToApp:(NSData *)messageData completionHandler:(nullable void (^)(NSData * _Nullable responseData))completionHandler NS_SWIFT_NAME(sendMessage(toApp:completionHandler:));

// 更新配置
- (void)updateConfig:(TFYSSConfig *)config completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(update(config:completionHandler:));

// 重置流量统计
- (void)resetTrafficStats NS_SWIFT_NAME(resetTrafficStats());

// 检查隧道状态
- (BOOL)isTunnelActive NS_SWIFT_NAME(isTunnelActive());

@end

NS_ASSUME_NONNULL_END 