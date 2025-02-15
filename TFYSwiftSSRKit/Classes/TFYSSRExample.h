#import <Foundation/Foundation.h>
#import "TFYSSRManager.h"
#import "TFYNetworkMonitor.h"
#import "TFYVPNManager.h"
#import "TFYTunnelManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TFYSSRExample : NSObject <TFYNetworkMonitorDelegate, TFYVPNManagerDelegate>

// 启动SSR代理
- (void)startSSRProxyWithHost:(NSString *)host
                        port:(NSInteger)port
                    password:(NSString *)password
                     method:(NSString *)method
                  completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

// 停止SSR代理
- (void)stopSSRProxy;

// 测试服务器延迟
- (void)testServerDelay:(NSString *)host
                   port:(NSInteger)port
              complete:(void(^)(NSTimeInterval delay, NSError * _Nullable error))complete;

// 获取当前网络状态
- (TFYNetworkStatus)currentNetworkStatus;

// VPN相关方法
- (void)setupVPNWithServer:(NSString *)server
                     port:(NSInteger)port
                username:(NSString *)username
                password:(NSString *)password
              completion:(void(^)(NSError * _Nullable error))completion;

- (void)connectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion;
- (void)disconnectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion;

// 隧道相关方法
- (void)startTunnelWithHost:(NSString *)host
                      port:(NSInteger)port
                  password:(NSString *)password
                   method:(NSString *)method
               completion:(void(^)(NSError * _Nullable error))completion;

- (void)stopTunnelWithCompletion:(void(^)(NSError * _Nullable error))completion;

- (void)getTunnelStatusWithCompletion:(void(^)(NSDictionary *status, NSError * _Nullable error))completion;

// 示例方法
+ (void)runExample;

@end

NS_ASSUME_NONNULL_END 