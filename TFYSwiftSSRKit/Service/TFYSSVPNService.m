#import "TFYSSVPNService.h"
#import "TFYSSError.h"
#import <NetworkExtension/NetworkExtension.h>

@interface TFYSSVPNService () {
    dispatch_queue_t _queue;
    dispatch_source_t _trafficTimer;
    dispatch_source_t _connectionTimeoutTimer;
    dispatch_source_t _connectionHealthTimer;
    dispatch_source_t _reconnectTimer;
}

@property (nonatomic, strong) NETunnelProviderManager *tunnelManager;
@property (nonatomic, assign) TFYSSVPNState state;
@property (nonatomic, assign) uint64_t uploadTraffic;
@property (nonatomic, assign) uint64_t downloadTraffic;
@property (nonatomic, strong) TFYSSConfig *currentConfig;
@property (nonatomic, strong) id vpnStatusObserver;
@property (nonatomic, assign) BOOL autoReconnect;

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
        _queue = dispatch_queue_create("com.tfyswift.ssr.vpnservice", DISPATCH_QUEUE_SERIAL);
        _state = TFYSSVPNStateDisconnected;
        _autoReconnect = NO; // 默认不自动重连
        
        // 监听 VPN 状态变化
        __weak typeof(self) weakSelf = self;
        _vpnStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf handleVPNStatusChange:note];
            }
        }];
        
        [self setupTrafficTimer];
    }
    return self;
}

- (void)dealloc {
    // 确保VPN在释放前停止
    if (self.state != TFYSSVPNStateDisconnected) {
        [self stopWithCompletion:nil];
    }
    
    // 清理所有计时器
    [self cleanupAllTimers];
    
    // 移除观察者
    if (self.tunnelManager) {
        [self.tunnelManager removeObserver:self forKeyPath:@"connection.status"];
        self.tunnelManager = nil;
    }
    
    if (self.vpnStatusObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.vpnStatusObserver];
        self.vpnStatusObserver = nil;
    }
    
    NSLog(@"TFYSSVPNService 已释放");
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
            protocol.providerBundleIdentifier = self.currentConfig.tunnelID;
            protocol.serverAddress = self.currentConfig.serverHost;
            protocol.providerConfiguration = @{
                @"tunnelType": @"shadowsocks"
            };
            
            self.tunnelManager.protocolConfiguration = protocol;
            self.tunnelManager.localizedDescription = self.currentConfig.vpnName?:@"TFYVPN";
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

/**
 * 启动VPN连接
 * @param config VPN配置
 * @param completion 完成回调，如果成功则error为nil
 */
- (void)startWithConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        // 验证配置
        NSError *validationError = [self validateConfig:config];
        if (validationError) {
            NSLog(@"VPN配置验证失败: %@", validationError.localizedDescription);
            if (completion) completion(validationError);
            return;
        }
        
        // 如果VPN已经在运行，先停止
        if (self.state != TFYSSVPNStateDisconnected) {
            NSLog(@"VPN已经在运行，先停止当前连接");
            [self stopWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"停止当前VPN连接失败: %@", error.localizedDescription);
                    if (completion) completion(error);
                    return;
                }
                
                // 延迟一段时间再启动新的连接，确保之前的连接已完全停止
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), self->_queue, ^{
                    [self startVPNWithConfig:config completion:completion];
                });
            }];
        } else {
            [self startVPNWithConfig:config completion:completion];
        }
    });
}

/**
 * 停止VPN连接
 * @param completion 完成回调，如果成功则error为nil
 */
- (void)stopWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        if (self.state == TFYSSVPNStateDisconnected) {
            NSLog(@"VPN已经处于断开状态");
            if (completion) completion(nil);
            return;
        }
        
        NSLog(@"正在停止VPN连接...");
        [self updateState:TFYSSVPNStateDisconnecting];
        
        // 创建一个标志，用于跟踪是否已经调用了completion
        __block BOOL completionCalled = NO;
        
        // 创建一个超时计时器，确保即使VPN状态没有正确更新，也能完成操作
        dispatch_source_t timeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
        dispatch_source_set_timer(timeoutTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 0);
        
        // 超时处理
        dispatch_source_set_event_handler(timeoutTimer, ^{
            if (!completionCalled) {
                completionCalled = YES;
                NSLog(@"停止VPN连接超时，强制断开");
                self.currentConfig = nil;
                [self updateState:TFYSSVPNStateDisconnected];
                
                if (completion) {
                    NSError *timeoutError = [NSError errorWithDomain:TFYSSErrorDomain 
                                                               code:TFYSSErrorDisconnectTimeout 
                                                           userInfo:@{NSLocalizedDescriptionKey: @"停止VPN连接超时"}];
                    completion(timeoutError);
                }
            }
            
            dispatch_source_cancel(timeoutTimer);
        });
        
        // 启动超时计时器
        dispatch_resume(timeoutTimer);
        
        // 添加状态变化观察者，在状态变为已断开时调用completion
        __block id disconnectObserver = [[NSNotificationCenter defaultCenter] 
                                        addObserverForName:NEVPNStatusDidChangeNotification
                                                   object:nil
                                                    queue:nil
                                               usingBlock:^(NSNotification * _Nonnull note) {
            NEVPNConnection *connection = note.object;
            if (connection.status == NEVPNStatusDisconnected) {
                dispatch_async(self->_queue, ^{
                    if (!completionCalled) {
                        completionCalled = YES;
                        [[NSNotificationCenter defaultCenter] removeObserver:disconnectObserver];
                        dispatch_source_cancel(timeoutTimer);
                        
                        self.currentConfig = nil;
                        [self updateState:TFYSSVPNStateDisconnected];
                        
                        NSLog(@"VPN连接已成功断开");
                        if (completion) completion(nil);
                    }
                });
            }
        }];
        
        // 尝试停止VPN隧道
        if (self.tunnelManager && self.tunnelManager.connection) {
            [self.tunnelManager.connection stopVPNTunnel];
        } else {
            // 如果没有活动的连接，直接更新状态
            if (!completionCalled) {
                completionCalled = YES;
                [[NSNotificationCenter defaultCenter] removeObserver:disconnectObserver];
                dispatch_source_cancel(timeoutTimer);
                
                self.currentConfig = nil;
                [self updateState:TFYSSVPNStateDisconnected];
                
                NSLog(@"没有活动的VPN连接需要断开");
                if (completion) completion(nil);
            }
        }
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

- (void)handleVPNStatusChange:(NSNotification *)notification {
    dispatch_async(_queue, ^{
        NEVPNConnection *connection = notification.object;
        if (![connection isKindOfClass:[NEVPNConnection class]]) {
            return;
        }
        
        // 只处理当前隧道管理器的连接状态变化
        if (self.tunnelManager && connection == self.tunnelManager.connection) {
            NEVPNStatus status = connection.status;
            NSLog(@"VPN连接状态变更通知: %@", [self stringFromVPNStatus:status]);
        }
    });
}

/**
 * 更新流量统计
 * 从PacketTunnelProvider获取最新的流量统计数据
 */
- (void)updateTrafficStats {
    // 如果 VPN 连接已建立，从 PacketTunnelProvider 获取流量统计
    if (self.state == TFYSSVPNStateConnected && self.tunnelManager && self.tunnelManager.connection) {
        NETunnelProviderSession *session = (NETunnelProviderSession *)self.tunnelManager.connection;
        
        // 检查上次请求是否完成，避免过多的并发请求
        static BOOL isRequestingTraffic = NO;
        if (isRequestingTraffic) {
            return;
        }
        
        // 发送消息给 PacketTunnelProvider 获取流量统计
        NSDictionary *message = @{@"command": @"getTraffic"};
        NSData *messageData = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
        
        // 使用 sendProviderMessage:returnError:responseHandler:
        NSError *providerError = nil;
        isRequestingTraffic = YES;
        
        [session sendProviderMessage:messageData returnError:&providerError responseHandler:^(NSData * _Nullable responseData) {
            isRequestingTraffic = NO;
            
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
                } else {
                    NSLog(@"解析流量统计响应失败: %@", error.localizedDescription);
                }
            } else {
                NSLog(@"获取流量统计没有响应数据");
            }
        }];
        
        if (providerError) {
            isRequestingTraffic = NO;
            NSLog(@"发送流量统计消息到提供者失败: %@", providerError);
            
            // 如果连续多次获取流量失败，可能需要重新连接
            static int failureCount = 0;
            failureCount++;
            
            if (failureCount > 5) {
                NSLog(@"连续多次获取流量失败，尝试重新连接VPN");
                failureCount = 0;
                
                // 尝试重新连接
                if (self.currentConfig) {
                    dispatch_async(self->_queue, ^{
                        [self updateState:TFYSSVPNStateReconnecting];
                        [self stopWithCompletion:^(NSError * _Nullable error) {
                            [self startWithConfig:self.currentConfig completion:nil];
                        }];
                    });
                }
            }
        } else {
            // 重置失败计数
            static int failureCount = 0;
            failureCount = 0;
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

/**
 * 启动VPN的核心逻辑
 * @param config VPN配置
 * @param completion 完成回调，如果成功则error为nil
 */
- (void)startVPNWithConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    // 更新状态
    [self updateState:TFYSSVPNStateConnecting];
    
    // 保存当前配置
    self.currentConfig = config;
    
    // 创建隧道提供者管理器
    [self createTunnelProviderManager:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable error) {
        if (error) {
            NSLog(@"创建隧道提供者管理器失败: %@", error.localizedDescription);
            [self updateState:TFYSSVPNStateDisconnected];
            if (completion) completion(error);
            return;
        }
        
        self.tunnelManager = manager;
        
        // 配置VPN
        [self configureVPN:manager withConfig:config];
        
        // 保存VPN配置
        [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"保存VPN配置失败: %@", error.localizedDescription);
                [self updateState:TFYSSVPNStateDisconnected];
                if (completion) completion(error);
                return;
            }
            
            // 启动VPN
            NSError *startError;
            BOOL started = [self startTunnel:manager error:&startError];
            
            if (!started) {
                NSLog(@"启动VPN隧道失败: %@", startError.localizedDescription);
                [self updateState:TFYSSVPNStateDisconnected];
                if (completion) completion(startError);
                return;
            }
            
            // 添加KVO观察者
            [manager addObserver:self forKeyPath:@"connection.status" options:NSKeyValueObservingOptionNew context:nil];
            
            if (completion) completion(nil);
        }];
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"connection.status"]) {
        dispatch_async(_queue, ^{
            NEVPNStatus status = self.tunnelManager.connection.status;
            NSLog(@"VPN连接状态变更: %@", [self stringFromVPNStatus:status]);
            
            switch (status) {
                case NEVPNStatusInvalid:
                    // 无效状态，可能需要重置
                    [self updateState:TFYSSVPNStateDisconnected];
                    [self resetConnectionIfNeeded];
                    break;
                    
                case NEVPNStatusDisconnected:
                    if (self.state != TFYSSVPNStateDisconnected) {
                        [self updateState:TFYSSVPNStateDisconnected];
                        // 如果不是主动断开，尝试自动重连
                        if (self.state != TFYSSVPNStateDisconnecting && self.autoReconnect) {
                            [self scheduleReconnect];
                        }
                    }
                    break;
                    
                case NEVPNStatusConnecting:
                    [self updateState:TFYSSVPNStateConnecting];
                    // 启动连接超时检查
                    [self startConnectionTimeoutCheck];
                    break;
                    
                case NEVPNStatusConnected:
                    [self updateState:TFYSSVPNStateConnected];
                    // 连接成功，取消任何重连计划
                    [self cancelReconnectTimer];
                    // 启动连接健康检查
                    [self startConnectionHealthCheck];
                    break;
                    
                case NEVPNStatusReasserting:
                    // 重新建立连接中
                    [self updateState:TFYSSVPNStateReconnecting];
                    break;
                    
                case NEVPNStatusDisconnecting:
                    [self updateState:TFYSSVPNStateDisconnecting];
                    break;
                    
                default:
                    break;
            }
        });
    }
}

/**
 * 启动连接超时检查
 * 如果VPN连接在指定时间内未完成，则尝试重新连接
 */
- (void)startConnectionTimeoutCheck {
    // 取消之前的超时检查
    [self cancelConnectionTimeoutCheck];
    
    // 创建新的超时检查
    _connectionTimeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_connectionTimeoutTimer, 
                             dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), 
                             DISPATCH_TIME_FOREVER, 
                             (int64_t)(1 * NSEC_PER_SEC));
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_connectionTimeoutTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.state == TFYSSVPNStateConnecting) {
            NSLog(@"VPN连接超时，尝试重新连接");
            [strongSelf stopWithCompletion:^(NSError * _Nullable error) {
                if (strongSelf.autoReconnect) {
                    [strongSelf scheduleReconnect];
                }
            }];
        }
        [strongSelf cancelConnectionTimeoutCheck];
    });
    
    dispatch_resume(_connectionTimeoutTimer);
}

- (void)cancelConnectionTimeoutCheck {
    if (_connectionTimeoutTimer) {
        dispatch_source_cancel(_connectionTimeoutTimer);
        _connectionTimeoutTimer = nil;
    }
}

/**
 * 启动连接健康检查
 * 定期检查VPN连接的健康状态，如果发现问题则尝试重新连接
 */
- (void)startConnectionHealthCheck {
    // 取消之前的健康检查
    [self cancelConnectionHealthCheck];
    
    // 创建新的健康检查
    _connectionHealthTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_connectionHealthTimer, 
                             dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), 
                             (int64_t)(60 * NSEC_PER_SEC), 
                             (int64_t)(1 * NSEC_PER_SEC));
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_connectionHealthTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.state == TFYSSVPNStateConnected) {
            [strongSelf checkConnectionHealth];
        }
    });
    
    dispatch_resume(_connectionHealthTimer);
}

- (void)cancelConnectionHealthCheck {
    if (_connectionHealthTimer) {
        dispatch_source_cancel(_connectionHealthTimer);
        _connectionHealthTimer = nil;
    }
}

/**
 * 检查连接健康状态
 * 通过监控流量变化来判断连接是否健康
 */
- (void)checkConnectionHealth {
    // 检查最近的流量统计，如果长时间没有流量可能表示连接有问题
    static NSUInteger noTrafficCount = 0;
    static uint64_t lastTotalBytes = 0;
    
    uint64_t currentTotalBytes = self.uploadTraffic + self.downloadTraffic;
    
    if (currentTotalBytes == lastTotalBytes) {
        noTrafficCount++;
        NSLog(@"检测到无流量，计数: %lu", (unsigned long)noTrafficCount);
        
        // 如果连续5分钟没有流量，尝试重新连接
        if (noTrafficCount >= 5) {
            NSLog(@"长时间无流量，尝试重新连接VPN");
            noTrafficCount = 0;
            
            [self stopWithCompletion:^(NSError * _Nullable error) {
                if (self.autoReconnect) {
                    [self scheduleReconnect];
                }
            }];
        }
    } else {
        // 有流量，重置计数
        noTrafficCount = 0;
        lastTotalBytes = currentTotalBytes;
    }
}

/**
 * 重置连接
 * 清理当前连接并在需要时重新连接
 */
- (void)resetConnectionIfNeeded {
    if (self.tunnelManager) {
        [self.tunnelManager removeObserver:self forKeyPath:@"connection.status"];
        self.tunnelManager = nil;
    }
    
    // 如果配置有效且自动重连开启，尝试重新连接
    if (self.currentConfig && self.autoReconnect) {
        [self scheduleReconnect];
    }
}

/**
 * 安排重新连接
 * 在指定延迟后尝试重新连接VPN
 */
- (void)scheduleReconnect {
    // 取消之前的重连计划
    [self cancelReconnectTimer];
    
    NSLog(@"计划在5秒后重新连接VPN");
    
    // 创建新的重连计时器
    _reconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_reconnectTimer, 
                             dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), 
                             DISPATCH_TIME_FOREVER, 
                             (int64_t)(1 * NSEC_PER_SEC));
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_reconnectTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.currentConfig) {
            NSLog(@"执行VPN自动重连");
            [strongSelf startWithConfig:strongSelf.currentConfig completion:nil];
        }
        [strongSelf cancelReconnectTimer];
    });
    
    dispatch_resume(_reconnectTimer);
}

/**
 * 取消重连计时器
 */
- (void)cancelReconnectTimer {
    if (_reconnectTimer) {
        dispatch_source_cancel(_reconnectTimer);
        _reconnectTimer = nil;
    }
}

/**
 * 将VPN状态转换为字符串，用于日志
 * @param status VPN状态
 * @return 状态的字符串描述
 */
- (NSString *)stringFromVPNStatus:(NEVPNStatus)status {
    switch (status) {
        case NEVPNStatusInvalid:
            return @"无效";
        case NEVPNStatusDisconnected:
            return @"已断开";
        case NEVPNStatusConnecting:
            return @"连接中";
        case NEVPNStatusConnected:
            return @"已连接";
        case NEVPNStatusReasserting:
            return @"重新连接中";
        case NEVPNStatusDisconnecting:
            return @"断开中";
        default:
            return @"未知";
    }
}

/**
 * 清理所有计时器
 * 在对象释放前调用，确保所有计时器都被取消
 */
- (void)cleanupAllTimers {
    [self cancelConnectionTimeoutCheck];
    [self cancelConnectionHealthCheck];
    [self cancelReconnectTimer];
    
    if (_trafficTimer) {
        dispatch_source_cancel(_trafficTimer);
        _trafficTimer = nil;
    }
}

/**
 * 设置是否自动重连
 * @param enable 是否启用自动重连
 */
- (void)setAutoReconnectEnabled:(BOOL)enable {
    dispatch_async(_queue, ^{
        self->_autoReconnect = enable;
        NSLog(@"VPN自动重连已%@", enable ? @"启用" : @"禁用");
    });
}

/**
 * 验证VPN配置是否有效
 * @param config 要验证的配置
 * @return 如果配置无效，返回错误；如果有效，返回nil
 */
- (NSError *)validateConfig:(TFYSSConfig *)config {
    if (!config) {
        return [NSError errorWithDomain:TFYSSErrorDomain
                                   code:TFYSSErrorConfigInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"配置为空"}];
    }
    
    // 检查服务器地址
    if (!config.serverHost || [config.serverHost length] == 0) {
        return [NSError errorWithDomain:TFYSSErrorDomain
                                   code:TFYSSErrorConfigInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"服务器地址为空"}];
    }
    
    // 检查端口
    if (config.serverPort <= 0 || config.serverPort > 65535) {
        return [NSError errorWithDomain:TFYSSErrorDomain
                                   code:TFYSSErrorConfigInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"服务器端口无效"}];
    }
    
    // 检查密码
    if (!config.password || [config.password length] == 0) {
        return [NSError errorWithDomain:TFYSSErrorDomain
                                   code:TFYSSErrorConfigInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"密码为空"}];
    }
    
    // 检查加密方法
    if (!config.method || [config.method length] == 0) {
        return [NSError errorWithDomain:TFYSSErrorDomain
                                   code:TFYSSErrorConfigInvalid
                               userInfo:@{NSLocalizedDescriptionKey: @"加密方法为空"}];
    }
    
    // 如果是SSR，检查协议和混淆
    if (config.isSSR) {
        if (!config.protocol || [config.protocol length] == 0) {
            return [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorConfigInvalid
                                   userInfo:@{NSLocalizedDescriptionKey: @"协议为空"}];
        }
        
        if (!config.obfs || [config.obfs length] == 0) {
            return [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorConfigInvalid
                                   userInfo:@{NSLocalizedDescriptionKey: @"混淆为空"}];
        }
    }
    
    return nil;
}

/**
 * 创建隧道提供者管理器
 * @param completion 完成回调，返回创建的管理器或错误
 */
- (void)createTunnelProviderManager:(void (^)(NETunnelProviderManager * _Nullable, NSError * _Nullable))completion {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (error) {
            NSLog(@"加载VPN配置失败: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        // 查找现有的 VPN 配置
        NETunnelProviderManager *manager = nil;
        for (NETunnelProviderManager *m in managers) {
            if ([m.localizedDescription isEqualToString:self.currentConfig.vpnName ?: @"TFYVPN"]) {
                manager = m;
                break;
            }
        }
        
        // 如果没有找到，创建一个新的
        if (!manager) {
            manager = [[NETunnelProviderManager alloc] init];
            NSLog(@"创建新的VPN配置");
        } else {
            NSLog(@"使用现有的VPN配置");
        }
        
        if (completion) completion(manager, nil);
    }];
}

- (void)configureVPN:(NETunnelProviderManager *)manager withConfig:(TFYSSConfig *)config {
    // 创建隧道协议
    NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
    protocol.providerBundleIdentifier = config.tunnelID ?: @"com.tfyswift.ssr.tunnel";
    protocol.serverAddress = config.serverHost;
    
    // 将配置序列化为字典
    NSMutableDictionary *providerConfig = [NSMutableDictionary dictionary];
    [providerConfig setObject:@"shadowsocks" forKey:@"tunnelType"];
    
    // 添加配置信息
    NSError *archiveError = nil;
    NSData *configData = [NSKeyedArchiver archivedDataWithRootObject:config requiringSecureCoding:YES error:&archiveError];
    if (!archiveError && configData) {
        [providerConfig setObject:configData forKey:@"config"];
    } else {
        NSLog(@"配置序列化失败: %@", archiveError.localizedDescription);
    }
    
    protocol.providerConfiguration = providerConfig;
    
    // 设置隧道配置
    manager.protocolConfiguration = protocol;
    manager.localizedDescription = config.vpnName ?: @"TFYVPN";
    manager.enabled = YES;
    
    NSLog(@"VPN配置已设置: %@", config.serverHost);
}

- (BOOL)startTunnel:(NETunnelProviderManager *)manager error:(NSError **)error {
    if (!manager || !manager.connection) {
        if (error) {
            *error = [NSError errorWithDomain:TFYSSErrorDomain
                                         code:TFYSSErrorStartFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"无效的VPN连接"}];
        }
        return NO;
    }
    
    // 启动VPN隧道
    NSError *startError = nil;
    [manager.connection startVPNTunnelWithOptions:nil andReturnError:&startError];
    
    if (startError) {
        NSLog(@"启动VPN隧道失败: %@", startError.localizedDescription);
        if (error) {
            *error = startError;
        }
        return NO;
    }
    
    NSLog(@"VPN隧道启动请求已发送");
    return YES;
}

#pragma mark - Getters

- (BOOL)isConnected {
    return self.state == TFYSSVPNStateConnected;
}

- (BOOL)isConnecting {
    return self.state == TFYSSVPNStateConnecting || self.state == TFYSSVPNStateReconnecting;
}

@end 
