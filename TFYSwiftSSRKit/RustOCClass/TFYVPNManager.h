#ifndef TFYVPNManager_h
#define TFYVPNManager_h

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import "TFYSSManager.h"

NS_ASSUME_NONNULL_BEGIN

/// VPN 状态
typedef NS_ENUM(NSInteger, TFYVpnStatus) {
    TFYVpnStatusInvalid = 0,        ///< VPN 不可用
    TFYVpnStatusDisconnected = 1,   ///< VPN 未连接
    TFYVpnStatusConnecting = 2,     ///< VPN 连接中
    TFYVpnStatusConnected = 3,      ///< VPN 已连接上
    TFYVpnStatusDisconnecting = 4   ///< VPN 断开连接中
} NS_SWIFT_NAME(VPNStatus);

/// VPN 连接回调
typedef void(^TFYVPNConnectCallback)(NSInteger connectStatus, BOOL succeed) NS_SWIFT_NAME(VPNConnectCallback);

/// VPN 管理器代理
NS_SWIFT_NAME(VPNManagerDelegate)
@protocol TFYVpnManagerDelegate <NSObject>
/// 状态变更回调
- (void)nbVpnStatusDidChange:(TFYVpnStatus)status;
@optional
/// VIP 检查回调
- (void)nbNotVipJumpToPurchase;
@end

/// VPN 管理器
NS_SWIFT_NAME(VPNManager)
@interface TFYVPNManager : NSObject

/// 代理对象
@property (nonatomic, weak, nullable) id<TFYVpnManagerDelegate> delegate;
/// 连接时间
@property (nonatomic, strong, nullable) NSDate *connectDate;
/// 当前状态
@property (nonatomic, readonly) TFYVpnStatus currentStatus;

/// 获取共享实例
+ (instancetype)shared;

/// 恢复 VPN 监听
- (void)resumeVPNListen;

/// 启动 VPN
/// @param config SS 配置
/// @param status VIP 状态
/// @param successBlock 回调
- (void)startVPN:(nullable TFYSSConfig *)config 
      withStatus:(BOOL)status 
         success:(nullable TFYVPNConnectCallback)successBlock NS_SWIFT_NAME(startVPN(_:status:success:));

/// 停止 VPN
- (void)stopVPNConnect;

/// 注册代理
- (void)registerDelegate:(nullable id)target;

/// 移除代理
- (void)removeDelegate;

@end

NS_ASSUME_NONNULL_END

#endif /* TFYVPNManager_h */ 
