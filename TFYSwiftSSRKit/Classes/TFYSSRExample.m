#import "TFYSSRExample.h"

@interface TFYSSRExample ()

@property (nonatomic, strong) TFYNetworkMonitor *networkMonitor;
@property (nonatomic, strong) TFYVPNManager *vpnManager;
@property (nonatomic, strong) TFYTunnelManager *tunnelManager;

@end

@implementation TFYSSRExample

- (instancetype)init {
    self = [super init];
    if (self) {
        _networkMonitor = [TFYNetworkMonitor sharedMonitor];
        _networkMonitor.delegate = self;
        [_networkMonitor startMonitoring];
        
        _vpnManager = [TFYVPNManager sharedManager];
        _vpnManager.delegate = self;
        
        _tunnelManager = [TFYTunnelManager sharedManager];
    }
    return self;
}

#pragma mark - SSR Methods

- (void)startSSRProxyWithHost:(NSString *)host
                        port:(NSInteger)port
                    password:(NSString *)password
                     method:(NSString *)method
                  completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    // 首先检查网络状态
    if (!self.networkMonitor.isReachable) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.ssr"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Network is not reachable"}];
        if (completion) {
            completion(NO, error);
        }
        return;
    }
    
    // 创建配置
    TFYSSRConfiguration *config = [TFYSSRConfiguration configurationWithHost:host
                                                                    port:port
                                                               password:password
                                                                method:method];
    
    // 启动代理
    BOOL success = [[TFYSSRManager sharedManager] startWithConfiguration:config];
    
    if (completion) {
        if (success) {
            completion(YES, nil);
        } else {
            NSError *error = [NSError errorWithDomain:@"com.tfy.ssr"
                                               code:-2
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to start SSR proxy"}];
            completion(NO, error);
        }
    }
}

- (void)stopSSRProxy {
    [[TFYSSRManager sharedManager] stop];
}

- (void)testServerDelay:(NSString *)host
                   port:(NSInteger)port
              complete:(void(^)(NSTimeInterval delay, NSError * _Nullable error))complete {
    [[TFYSSRManager sharedManager] testServerDelay:host port:port complete:complete];
}

- (TFYNetworkStatus)currentNetworkStatus {
    return self.networkMonitor.currentStatus;
}

#pragma mark - VPN Methods

- (void)setupVPNWithServer:(NSString *)server
                     port:(NSInteger)port
                username:(NSString *)username
                password:(NSString *)password
              completion:(void(^)(NSError * _Nullable error))completion {
    [self.vpnManager setupVPNWithServer:server
                                  port:port
                             username:username
                             password:password
                           completion:completion];
}

- (void)connectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion {
    [self.vpnManager connectVPNWithCompletion:completion];
}

- (void)disconnectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion {
    [self.vpnManager disconnectVPNWithCompletion:completion];
}

#pragma mark - Tunnel Methods

- (void)startTunnelWithHost:(NSString *)host
                      port:(NSInteger)port
                  password:(NSString *)password
                   method:(NSString *)method
               completion:(void(^)(NSError * _Nullable error))completion {
    NSDictionary *config = @{
        @"host": host,
        @"port": @(port),
        @"password": password,
        @"method": method
    };
    
    [self.tunnelManager startTunnelWithConfiguration:config completion:completion];
}

- (void)stopTunnelWithCompletion:(void(^)(NSError * _Nullable error))completion {
    [self.tunnelManager stopTunnelWithCompletion:completion];
}

- (void)getTunnelStatusWithCompletion:(void(^)(NSDictionary *status, NSError * _Nullable error))completion {
    [self.tunnelManager getTunnelStatusWithCompletion:completion];
}

#pragma mark - TFYNetworkMonitorDelegate

- (void)networkStatusDidChange:(TFYNetworkStatus)status {
    switch (status) {
        case TFYNetworkStatusNotReachable:
            NSLog(@"Network became unreachable");
            [self stopSSRProxy];
            [self disconnectVPNWithCompletion:nil];
            [self stopTunnelWithCompletion:nil];
            break;
            
        case TFYNetworkStatusReachableViaWiFi:
            NSLog(@"Network is reachable via WiFi");
            break;
            
        case TFYNetworkStatusReachableViaCellular:
            NSLog(@"Network is reachable via Cellular");
            break;
    }
}

- (void)networkDidBecomeReachable {
    NSLog(@"Network became reachable");
}

- (void)networkDidBecomeUnreachable {
    NSLog(@"Network became unreachable");
    [self stopSSRProxy];
    [self disconnectVPNWithCompletion:nil];
    [self stopTunnelWithCompletion:nil];
}

#pragma mark - TFYVPNManagerDelegate

- (void)vpnStatusDidChange:(TFYVPNStatus)status {
    NSLog(@"VPN status changed: %ld", (long)status);
}

- (void)vpnDidConnect {
    NSLog(@"VPN connected successfully");
}

- (void)vpnDidDisconnect {
    NSLog(@"VPN disconnected");
}

- (void)vpnConnectDidFail:(NSError *)error {
    NSLog(@"VPN connection failed: %@", error.localizedDescription);
}

#pragma mark - Example

+ (void)runExample {
    TFYSSRExample *example = [[TFYSSRExample alloc] init];
    
    // 测试服务器延迟
    [example testServerDelay:@"example.com" port:8388 complete:^(NSTimeInterval delay, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to test server delay: %@", error.localizedDescription);
            return;
        }
        
        NSLog(@"Server delay: %.2f ms", delay);
        
        // 如果延迟可接受，启动隧道模式
        if (delay < 1000) { // 延迟小于1秒
            [example startTunnelWithHost:@"example.com"
                                  port:8388
                              password:@"password"
                               method:@"aes-256-cfb"
                           completion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Failed to start tunnel: %@", error.localizedDescription);
                    
                    // 如果隧道模式失败，尝试VPN模式
                    [example setupVPNWithServer:@"vpn.example.com"
                                         port:1194
                                    username:@"vpnuser"
                                    password:@"vpnpass"
                                  completion:^(NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"Failed to setup VPN: %@", error.localizedDescription);
                            
                            // 如果VPN也失败，尝试普通SSR代理模式
                            [example startSSRProxyWithHost:@"example.com"
                                                    port:8388
                                                password:@"password"
                                                 method:@"aes-256-cfb"
                                              completion:^(BOOL success, NSError * _Nullable error) {
                                if (success) {
                                    NSLog(@"SSR proxy started successfully");
                                } else {
                                    NSLog(@"Failed to start SSR proxy: %@", error.localizedDescription);
                                }
                            }];
                            return;
                        }
                        
                        [example connectVPNWithCompletion:^(NSError * _Nullable error) {
                            if (error) {
                                NSLog(@"Failed to connect VPN: %@", error.localizedDescription);
                            } else {
                                NSLog(@"VPN connected successfully");
                            }
                        }];
                    }];
                } else {
                    NSLog(@"Tunnel started successfully");
                    
                    // 监控隧道状态
                    [example getTunnelStatusWithCompletion:^(NSDictionary *status, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"Failed to get tunnel status: %@", error.localizedDescription);
                        } else {
                            NSLog(@"Tunnel status: %@", status);
                        }
                    }];
                }
            }];
        } else {
            NSLog(@"Server delay too high: %.2f ms", delay);
        }
    }];
    
    // 等待一段时间后停止所有服务
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [example stopTunnelWithCompletion:^(NSError * _Nullable error) {
            [example disconnectVPNWithCompletion:^(NSError * _Nullable error) {
                [example stopSSRProxy];
                NSLog(@"All services stopped");
            }];
        }];
    });
}

- (void)dealloc {
    [self.networkMonitor stopMonitoring];
    [self stopSSRProxy];
    [self disconnectVPNWithCompletion:nil];
    [self stopTunnelWithCompletion:nil];
}

@end