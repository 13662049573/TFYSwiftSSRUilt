#import "TFYSSVPNService.h"
#import "TFYSSError.h"
#import <NetworkExtension/NetworkExtension.h>

// 定义 Packet Tunnel Extension 的 Bundle Identifier
#define PACKET_TUNNEL_BUNDLE_ID @"com.yourcompany.TFYSwiftSSRUilt.PacketTunnel"

@interface TFYSSVPNService () {
    dispatch_queue_t _queue;
    dispatch_source_t _trafficTimer;
}

@property (nonatomic, strong) NETunnelProviderManager *tunnelManager;
@property (nonatomic, assign) TFYSSVPNState state;
@property (nonatomic, assign) uint64_t uploadTraffic;
@property (nonatomic, assign) uint64_t downloadTraffic;
@property (nonatomic, strong) TFYSSConfig *currentConfig;
@property (nonatomic, strong) id vpnStatusObserver;

@end

@implementation TFYSSVPNService

+ (instancetype)sharedInstance {
    static TFYSSVPNService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.tfyswiftssrkit.vpn.queue", DISPATCH_QUEUE_SERIAL);
        _state = TFYSSVPNStateDisconnected;
        [self setupTrafficTimer];
        [self setupVPNStatusObserver];
    }
    return self;
}

- (void)dealloc {
    if (_trafficTimer) {
        dispatch_source_cancel(_trafficTimer);
        _trafficTimer = nil;
    }
    
    if (_vpnStatusObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_vpnStatusObserver];
        _vpnStatusObserver = nil;
    }
}

#pragma mark - Public Methods

- (void)installVPNProfileWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        // 查找现有的 VPN 配置
        [self findOrCreateTunnelProviderManagerWithCompletion:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(error);
                return;
            }
            
            self.tunnelManager = manager;
            
            // 创建 VPN 配置
            NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
            protocol.providerBundleIdentifier = PACKET_TUNNEL_BUNDLE_ID;
            protocol.serverAddress = @"TFYSwiftSSRKit VPN";
            protocol.providerConfiguration = @{
                @"tunnelType": @"shadowsocks"
            };
            
            self.tunnelManager.protocolConfiguration = protocol;
            self.tunnelManager.localizedDescription = @"TFYSwiftSSRKit VPN";
            self.tunnelManager.enabled = YES;
            
            // 保存 VPN 配置
            [self.tunnelManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (completion) completion(error);
            }];
        }];
    });
}

- (void)removeVPNProfileWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        [self findOrCreateTunnelProviderManagerWithCompletion:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(error);
                return;
            }
            
            self.tunnelManager = manager;
            self.tunnelManager.enabled = NO;
            
            [self.tunnelManager removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (completion) completion(error);
            }];
        }];
    });
}

- (void)startWithConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        // 验证配置
        NSError *error = nil;
        if (![config validate:&error]) {
            if (completion) completion(error);
            return;
        }
        
        // 如果已经在运行，先停止
        if (self.state != TFYSSVPNStateDisconnected) {
            [self stopWithCompletion:nil];
        }
        
        // 更新状态
        [self updateState:TFYSSVPNStateConnecting];
        
        // 保存配置
        self.currentConfig = config;
        
        // 查找或创建 Tunnel Provider Manager
        [self findOrCreateTunnelProviderManagerWithCompletion:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable error) {
            if (error) {
                [self handleStartFailureWithError:error completion:completion];
                return;
            }
            
            self.tunnelManager = manager;
            
            // 更新 VPN 配置
            NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *)self.tunnelManager.protocolConfiguration;
            if (!protocol || ![protocol isKindOfClass:[NETunnelProviderProtocol class]]) {
                protocol = [[NETunnelProviderProtocol alloc] init];
                protocol.providerBundleIdentifier = PACKET_TUNNEL_BUNDLE_ID;
            }
            
            protocol.serverAddress = config.serverHost;
            
            // 将配置序列化为字典
            NSMutableDictionary *providerConfig = [NSMutableDictionary dictionary];
            providerConfig[@"serverHost"] = config.serverHost;
            providerConfig[@"serverPort"] = @(config.serverPort);
            providerConfig[@"method"] = config.method;
            providerConfig[@"password"] = config.password;
            providerConfig[@"localAddress"] = config.localAddress;
            providerConfig[@"localPort"] = @(config.localPort);
            providerConfig[@"timeout"] = @(config.timeout);
            providerConfig[@"enableNAT"] = @(config.enableNAT);
            providerConfig[@"enableHTTP"] = @(config.enableHTTP);
            providerConfig[@"httpPort"] = @(config.httpPort);
            providerConfig[@"preferredCoreType"] = @(config.preferredCoreType);
            
            protocol.providerConfiguration = providerConfig;
            
            self.tunnelManager.protocolConfiguration = protocol;
            self.tunnelManager.localizedDescription = @"TFYSwiftSSRKit VPN";
            self.tunnelManager.enabled = YES;
            
            // 保存 VPN 配置
            [self.tunnelManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    [self handleStartFailureWithError:error completion:completion];
                    return;
                }
                
                // 启动 VPN
                NSError *startError = nil;
                NETunnelProviderSession *session = (NETunnelProviderSession *)self.tunnelManager.connection;
                
                // 将配置序列化为 NSData
                NSError *archiveError = nil;
                NSData *configData = [NSKeyedArchiver archivedDataWithRootObject:config requiringSecureCoding:YES error:&archiveError];
                
                if (archiveError || !configData) {
                    NSError *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:@{
                        NSLocalizedDescriptionKey: @"Failed to serialize configuration",
                        NSUnderlyingErrorKey: archiveError ?: [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:nil]
                    }];
                    [self handleStartFailureWithError:error completion:completion];
                    return;
                }
                
                NSDictionary *options = @{@"config": configData};
                
                [session startTunnelWithOptions:options andReturnError:&startError];
                
                if (startError) {
                    [self handleStartFailureWithError:startError completion:completion];
                    return;
                }
                
                if (completion) completion(nil);
            }];
        }];
    });
}

- (void)stopWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        if (self.state == TFYSSVPNStateDisconnected) {
            if (completion) completion(nil);
            return;
        }
        
        [self updateState:TFYSSVPNStateDisconnecting];
        
        if (self.tunnelManager && self.tunnelManager.connection) {
            [self.tunnelManager.connection stopVPNTunnel];
        }
        
        // 等待 VPN 状态变为已断开
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), self->_queue, ^{
            self.currentConfig = nil;
            [self updateState:TFYSSVPNStateDisconnected];
            
            if (completion) completion(nil);
        });
    });
}

- (void)updateConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        // 验证配置
        NSError *error = nil;
        if (![config validate:&error]) {
            if (completion) completion(error);
            return;
        }
        
        // 如果 VPN 正在运行，发送更新配置消息
        if (self.state == TFYSSVPNStateConnected && self.tunnelManager && self.tunnelManager.connection) {
            NETunnelProviderSession *session = (NETunnelProviderSession *)self.tunnelManager.connection;
            
            // 将配置序列化为 NSData
            NSError *archiveError = nil;
            NSData *configData = [NSKeyedArchiver archivedDataWithRootObject:config requiringSecureCoding:YES error:&archiveError];
            
            if (archiveError || !configData) {
                NSError *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:@{
                    NSLocalizedDescriptionKey: @"Failed to serialize configuration",
                    NSUnderlyingErrorKey: archiveError ?: [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:nil]
                }];
                if (completion) completion(error);
                return;
            }
            
            // 发送消息给 PacketTunnelProvider 更新配置
            NSDictionary *message = @{
                @"command": @"updateConfig",
                @"config": configData
            };
            NSData *messageData = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
            
            // 使用 sendProviderMessage:returnError:responseHandler:
            NSError *providerError = nil;
            [session sendProviderMessage:messageData returnError:&providerError responseHandler:^(NSData * _Nullable responseData) {
                if (responseData) {
                    NSError *jsonError = nil;
                    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
                    if (!jsonError && response && [response[@"status"] isEqualToString:@"success"]) {
                        self.currentConfig = config;
                        if (completion) {
                            completion(nil);
                        }
                    } else {
                        if (completion) {
                            NSError *responseError = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorUpdateConfigFailed userInfo:@{NSLocalizedDescriptionKey: @"Failed to update configuration"}];
                            completion(responseError);
                        }
                    }
                } else {
                    if (completion) {
                        NSError *responseError = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorUpdateConfigFailed userInfo:@{NSLocalizedDescriptionKey: @"No response from provider"}];
                        completion(responseError);
                    }
                }
            }];
            
            if (providerError) {
                NSLog(@"Failed to send message to provider: %@", providerError);
                if (completion) {
                    completion(providerError);
                }
            }
        } else {
            self.currentConfig = config;
            if (completion) completion(nil);
        }
    });
}

- (void)resetTrafficStats {
    dispatch_async(_queue, ^{
        self.uploadTraffic = 0;
        self.downloadTraffic = 0;
        [self notifyTrafficUpdate];
    });
}

- (void)checkVPNPermissionWithCompletion:(void (^)(BOOL, NSError * _Nullable))completion {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (error) {
            completion(NO, error);
            return;
        }
        completion(YES, nil);
    }];
}

#pragma mark - Private Methods

- (void)findOrCreateTunnelProviderManagerWithCompletion:(void (^)(NETunnelProviderManager * _Nullable, NSError * _Nullable))completion {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        // 查找现有的 TFYSwiftSSRKit VPN 配置
        NETunnelProviderManager *manager = nil;
        for (NETunnelProviderManager *m in managers) {
            if ([m.localizedDescription isEqualToString:@"TFYSwiftSSRKit VPN"]) {
                manager = m;
                break;
            }
        }
        
        // 如果没有找到，创建一个新的
        if (!manager) {
            manager = [[NETunnelProviderManager alloc] init];
        }
        
        completion(manager, nil);
    }];
}

- (void)setupTrafficTimer {
    _trafficTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_trafficTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_trafficTimer, ^{
        [weakSelf updateTrafficStats];
    });
    
    dispatch_resume(_trafficTimer);
}

- (void)setupVPNStatusObserver {
    __weak typeof(self) weakSelf = self;
    _vpnStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification
                                                                           object:nil
                                                                            queue:nil
                                                                       usingBlock:^(NSNotification * _Nonnull note) {
        NEVPNConnection *connection = note.object;
        [weakSelf handleVPNStatusChange:connection.status];
    }];
}

- (void)handleVPNStatusChange:(NEVPNStatus)status {
    dispatch_async(_queue, ^{
        switch (status) {
            case NEVPNStatusDisconnected:
                [self updateState:TFYSSVPNStateDisconnected];
                break;
            case NEVPNStatusConnecting:
                [self updateState:TFYSSVPNStateConnecting];
                break;
            case NEVPNStatusConnected:
                [self updateState:TFYSSVPNStateConnected];
                break;
            case NEVPNStatusDisconnecting:
                [self updateState:TFYSSVPNStateDisconnecting];
                break;
            case NEVPNStatusReasserting:
                [self updateState:TFYSSVPNStateReconnecting];
                break;
            case NEVPNStatusInvalid:
                [self updateState:TFYSSVPNStateInvalid];
                break;
        }
    });
}

- (void)updateTrafficStats {
    // 如果 VPN 连接已建立，从 PacketTunnelProvider 获取流量统计
    if (self.state == TFYSSVPNStateConnected && self.tunnelManager && self.tunnelManager.connection) {
        NETunnelProviderSession *session = (NETunnelProviderSession *)self.tunnelManager.connection;
        
        // 发送消息给 PacketTunnelProvider 获取流量统计
        NSDictionary *message = @{@"command": @"getTraffic"};
        NSData *messageData = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
        
        // 使用 sendProviderMessage:returnError:responseHandler:
        NSError *providerError = nil;
        [session sendProviderMessage:messageData returnError:&providerError responseHandler:^(NSData * _Nullable responseData) {
            if (responseData) {
                NSError *error = nil;
                NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
                if (!error && response) {
                    NSNumber *upload = response[@"upload"];
                    NSNumber *download = response[@"download"];
                    
                    if (upload && download) {
                        dispatch_async(self->_queue, ^{
                            self.uploadTraffic = upload.unsignedLongLongValue;
                            self.downloadTraffic = download.unsignedLongLongValue;
                            [self notifyTrafficUpdate];
                        });
                    }
                }
            }
        }];
        
        if (providerError) {
            NSLog(@"Failed to send traffic stats message to provider: %@", providerError);
        }
    }
}

- (void)updateState:(TFYSSVPNState)newState {
    if (_state == newState) return;
    
    _state = newState;
    [self notifyStateChange];
}

- (void)handleStartFailureWithError:(NSError *)error completion:(void (^)(NSError * _Nullable))completion {
    self.currentConfig = nil;
    [self updateState:TFYSSVPNStateDisconnected];
    
    [self notifyError:error];
    
    if (completion) completion(error);
}

#pragma mark - Delegate Notifications

- (void)notifyStateChange {
    if (!self.delegate) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(vpnService:didChangeState:)]) {
            [self.delegate vpnService:self didChangeState:self.state];
        }
    });
}

- (void)notifyTrafficUpdate {
    if (!self.delegate) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(vpnService:didUpdateTraffic:download:)]) {
            [self.delegate vpnService:self didUpdateTraffic:self.uploadTraffic download:self.downloadTraffic];
        }
    });
}

- (void)notifyError:(NSError *)error {
    if (!self.delegate) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(vpnService:didEncounterError:)]) {
            [self.delegate vpnService:self didEncounterError:error];
        }
    });
}

@end 
