#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import "TFYVPNConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TFYVPNStatus) {
    TFYVPNStatusDisconnected,
    TFYVPNStatusConnecting,
    TFYVPNStatusConnected,
    TFYVPNStatusDisconnecting,
    TFYVPNStatusInvalid,
    TFYVPNStatusReasserting
};

@protocol TFYVPNManagerDelegate <NSObject>

@optional
- (void)vpnStatusDidChange:(TFYVPNStatus)status;
- (void)vpnDidConnect;
- (void)vpnDidDisconnect;
- (void)vpnConnectDidFail:(NSError *)error;

@end

@interface TFYVPNManager : NSObject

@property (nonatomic, weak) id<TFYVPNManagerDelegate> delegate;
@property (nonatomic, assign, readonly) TFYVPNStatus status;
@property (nonatomic, strong, readonly) TFYVPNConfiguration *currentConfiguration;

+ (instancetype)sharedManager;

// 请求VPN权限
- (void)requestVPNPermissionWithCompletion:(void(^)(BOOL granted, NSError * _Nullable error))completion;

// 配置VPN
- (void)configureVPNWithConfiguration:(TFYVPNConfiguration *)configuration
                         completion:(void(^)(NSError * _Nullable error))completion;

// 连接VPN
- (void)connectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion;

// 断开VPN
- (void)disconnectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion;

// 移除VPN配置
- (void)removeVPNConfiguration:(void(^)(NSError * _Nullable error))completion;

// 获取所有VPN配置
- (void)loadVPNConfigurationsWithCompletion:(void(^)(NSArray<NEVPNConnection *> * _Nullable configurations, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 