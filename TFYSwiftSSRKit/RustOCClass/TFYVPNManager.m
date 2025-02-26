#import "TFYVPNManager.h"
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

#define vpnWeakSelf __weak typeof(self) weakSelf = self;
#define vpnStrongSelf __strong typeof(weakSelf) strongSelf = weakSelf;

@implementation TFYVPNConfiguration
@end

@interface TFYVPNManager ()

@property (nonatomic, strong) NETunnelProviderManager *providerManager;
@property (nonatomic, assign) BOOL observerAdded;
@property (nonatomic, assign) BOOL isConnecting;

// 是否是合法连接，也可以做只连接一次处理
@property (nonatomic, assign) BOOL legallyStart;
// 是否保存了配置，也可用于是否直连判断
@property (nonatomic, assign) BOOL savedPreference;
//ipv4
@property (nonatomic, copy) NSArray *ipV4Array;
//ipv6
@property (nonatomic, copy) NSArray *ipV6Array;
//ipv4
@property (nonatomic, copy) NSData *ipV4Data;
//ipv6
@property (nonatomic, copy) NSData *ipV6Data;
//连接配置
@property (nonatomic, copy, nullable) NSDictionary *configDic;

@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, strong) NSTimer *connectionCheckTimer;

@end

@implementation TFYVPNManager

#pragma mark - Singleton

+ (instancetype)shared {
    static TFYVPNManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadProviderManager:^(NETunnelProviderManager *manager) {
            if (manager) {
                self.providerManager = manager;
                [self updateVPNStatus:manager];
            }
        }];
        [self addVPNStatusObserver];
        _legallyStart = NO;
        _savedPreference = NO;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)registerDelegate:(nullable id)target {
    self.delegate = target;
}

- (void)removeDelegate {
    self.delegate = nil;
}

- (void)resumeVPNListen {
    [self addVPNStatusObserver];
}

- (void)startVPN:(nullable TFYSSConfig *)config
     withStatus:(BOOL)status
       success:(nullable TFYVPNConnectCallback)successBlock {
    
    // 1. 检查 VIP 状态
    if (!status) {
        if ([self.delegate respondsToSelector:@selector(nbNotVipJumpToPurchase)]) {
            [self.delegate nbNotVipJumpToPurchase];
        }
        return;
    }
    
    // 2. 检查是否正在连接
    if (self.isConnecting) {
        if (successBlock) {
            successBlock(0, NO); // 正在连接中
        }
        return;
    }
    
    // 3. 检查配置有效性
    if (!config || !config.serverAddress || !config.providerBundleIdentifier) {
        if (successBlock) {
            successBlock(-1, NO); // 配置无效
        }
        return;
    }
    
    NSLog(@"=== 开始配置 VPN ===");
    NSLog(@"服务器地址: %@", config.serverAddress);
    NSLog(@"服务器端口: %d", config.serverPort);
    NSLog(@"Bundle ID: %@", config.providerBundleIdentifier);
    NSLog(@"加密方法: %@", config.method);
    NSLog(@"超时时间: %ld", (long)config.timeout);
    
    self.isConnecting = YES;
    
    // 4. 加载或创建 VPN 配置
    [self loadAndCreateProviderManager:^(NETunnelProviderManager *manager, NSError *error) {
        if (error || !manager) {
            self.isConnecting = NO;
            if (successBlock) {
                successBlock(-1, NO); // 配置加载失败
            }
            return;
        }
        
        // 5. 配置 VPN
        NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
        protocol.providerBundleIdentifier = config.providerBundleIdentifier;
        protocol.serverAddress = config.serverAddress;
    protocol.disconnectOnSleep = NO;
        
        // 添加完整的 SS 配置到 providerConfiguration
        NSMutableDictionary *providerConfig = [NSMutableDictionary dictionary];
        [providerConfig addEntriesFromDictionary:config.toDictionary];
        protocol.providerConfiguration = providerConfig;
        
        // 设置 VPN 连接规则
        NSMutableArray *rules = [NSMutableArray array];
        NEOnDemandRuleConnect *connectRule = [[NEOnDemandRuleConnect alloc] init];
        connectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
        [rules addObject:connectRule];
        
        manager.protocolConfiguration = protocol;
        manager.onDemandRules = rules;
        manager.localizedDescription = config.settingsTitle ?: @"VPN";
        manager.enabled = YES;
        
        // 6. 保存 VPN 配置
        [manager saveToPreferencesWithCompletionHandler:^(NSError *error) {
            if (error) {
                self.isConnecting = NO;
                NSLog(@"保存 VPN 配置失败: %@", error);
                if (successBlock) {
                    successBlock(2, NO); // 保存配置失败
                }
                return;
            }
            
            // 7. 加载保存的配置
            [manager loadFromPreferencesWithCompletionHandler:^(NSError *error) {
                if (error) {
                    self.isConnecting = NO;
                    NSLog(@"加载 VPN 配置失败: %@", error);
                    if (successBlock) {
                        successBlock(2, NO); // 加载配置失败
                    }
                    return;
                }
                
                // 8. 启动 VPN 连接
                NSError *startError = nil;
                BOOL started = [manager.connection startVPNTunnelAndReturnError:&startError];
                
                self.isConnecting = NO;
                if (startError || !started) {
                    NSLog(@"启动 VPN 连接失败: %@", startError);
                    if ([startError.domain isEqualToString:NEVPNErrorDomain]) {
                        switch (startError.code) {
                            case NEVPNErrorConfigurationInvalid:
                                NSLog(@"VPN 配置无效");
                                break;
                            case NEVPNErrorConfigurationDisabled:
                                NSLog(@"VPN 配置已禁用");
                                break;
                            case NEVPNErrorConnectionFailed:
                                NSLog(@"VPN 连接失败");
                                break;
                            default:
                                NSLog(@"其他 VPN 错误: %ld", (long)startError.code);
                                break;
                        }
                    }
                    if (successBlock) {
                        successBlock(2, NO); // 启动失败
                    }
                } else {
                    NSLog(@"VPN 连接启动成功");
                    if (successBlock) {
                        successBlock(3, YES); // 启动成功
                    }
                }
            }];
        }];
    }];
    
    // 启动连接检查
    [self startConnectionCheck];
}

- (void)stopVPNConnect {
    [self loadProviderManager:^(NETunnelProviderManager *manager) {
        [manager.connection stopVPNTunnel];
    }];
}

- (void)loadAllWithResult:(void (^)(NETunnelProviderManager *manager, BOOL savedPreference))resultBlock {
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if(error){
            NSLog(@"loadAllFromPreference出现了错误:%@", error.userInfo[NSLocalizedDescriptionKey]);
            return;
        }
        if (managers.count == 0) {
            self.providerManager = [[NETunnelProviderManager alloc] init];
            self.savedPreference = NO;
            resultBlock(self.providerManager, NO);
        }else {
            self.providerManager = managers.firstObject;
            self.savedPreference = YES;
            NEVPNConnection *connect = self.providerManager.connection;
            NEVPNStatus status = connect.status;
            if (status == NEVPNStatusConnected) {
                self.connectDate = connect.connectedDate;
            }
            resultBlock(self.providerManager, YES);
        }
    }];
}

- (void)loadVPNPreferenceSuccess:(void (^)(BOOL result))successBlock {
    if (!self.providerManager) {
        vpnWeakSelf;
        [self loadAllWithResult:^(NETunnelProviderManager * _Nullable manager, BOOL savedPreference) {
            vpnStrongSelf;
            [strongSelf.providerManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"加载 VPN 设置失败 : %@", error);
                    return;
                } else {
                    successBlock(YES);
                }
            }];
        }];
    }else{
        [self.providerManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"加载 VPN 设置失败 : %@", error);
                return;
            } else {
                successBlock(YES);
            }
        }];
    }
}

- (TFYVpnStatus)getCurrentStatus {
    
    NEVPNStatus status = _providerManager.connection.status;
    if (!self.legallyStart && status == NEVPNStatusConnecting) {
        NSLog(@"发现了非法连接，断开");
        [self stopVPNConnect];
    }
    switch (status) {
        case NEVPNStatusInvalid:
            NSLog(@"无效VPN");
            return TFYVpnStatusInvalid;
            break;
        case NEVPNStatusConnecting:
            NSLog(@"VPN连接中");
            return TFYVpnStatusConnecting;
            break;
        case NEVPNStatusConnected:
            NSLog(@"VPN连接成功");
            //合法连接结束
            self.legallyStart = NO;
            return TFYVpnStatusConnected;
            break;
        case NEVPNStatusDisconnecting:
            NSLog(@"VPN断开连接中");
            return TFYVpnStatusDisconnecting;
            break;
        case NEVPNStatusDisconnected:
            NSLog(@"VPN未连接");
            //合法连接结束
            self.legallyStart = NO;
            self.connectDate = nil;
            return TFYVpnStatusDisconnected;
            break;
        default:
            return TFYVpnStatusInvalid;
            break;
    }
}

#pragma mark - Private Methods

- (void)addVPNStatusObserver {
    if (self.observerAdded) {
        return;
    }
    
    [self loadProviderManager:^(NETunnelProviderManager *manager) {
        if (manager) {
            self.observerAdded = YES;
            [[NSNotificationCenter defaultCenter] addObserver:self 
                                                   selector:@selector(vpnStatusDidChange:) 
                                                       name:NEVPNStatusDidChangeNotification 
                                                     object:manager.connection];
        }
    }];
}

- (void)vpnStatusDidChange:(NSNotification *)notification {
    NEVPNConnection *connection = notification.object;
    NEVPNStatus status = connection.status;
    
    NSLog(@"=== VPN 状态变更 ===");
    switch (status) {
        case NEVPNStatusInvalid:
            NSLog(@"状态: 无效");
            if ([connection.manager.protocolConfiguration isKindOfClass:[NETunnelProviderProtocol class]]) {
                NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *)connection.manager.protocolConfiguration;
                NSLog(@"错误信息: %@", protocol.providerConfiguration);
            }
            break;
        case NEVPNStatusDisconnected:
            NSLog(@"状态: 已断开");
            if ([connection.manager.protocolConfiguration isKindOfClass:[NETunnelProviderProtocol class]]) {
                NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *)connection.manager.protocolConfiguration;
                NSLog(@"配置信息: %@", protocol.providerConfiguration);
            }
            self.connectDate = nil;
            break;
        case NEVPNStatusConnecting:
            NSLog(@"状态: 连接中");
            break;
        case NEVPNStatusConnected:
            NSLog(@"状态: 已连接");
            self.connectDate = connection.connectedDate;
            break;
        case NEVPNStatusDisconnecting:
            NSLog(@"状态: 断开中");
            break;
        default:
            break;
    }
    
    [self updateVPNStatus:connection.manager];
}

- (void)updateVPNStatus:(NETunnelProviderManager *)manager {
    TFYVpnStatus status;
    
    switch (manager.connection.status) {
        case NEVPNStatusConnected:
            status = TFYVpnStatusConnected;
            break;
        case NEVPNStatusConnecting:
            status = TFYVpnStatusConnecting;
            break;
        case NEVPNStatusDisconnecting:
            status = TFYVpnStatusDisconnecting;
            break;
        case NEVPNStatusDisconnected:
        case NEVPNStatusInvalid:
            status = TFYVpnStatusDisconnected;
            break;
        default:
            status = TFYVpnStatusInvalid;
            break;
    }
    
    if ([self.delegate respondsToSelector:@selector(nbVpnStatusDidChange:)]) {
        [self.delegate nbVpnStatusDidChange:status];
    }
}

- (void)loadProviderManager:(void (^)(NETunnelProviderManager *manager))completion {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (managers.count > 0) {
            completion(managers[0]);
        } else {
            completion(nil);
        }
    }];
}

- (void)loadAndCreateProviderManager:(void (^)(NETunnelProviderManager *manager, NSError *error))completion {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NETunnelProviderManager *manager = managers.firstObject ?: [[NETunnelProviderManager alloc] init];
        completion(manager, nil);
    }];
}

#pragma mark - Properties

- (TFYVpnStatus)currentStatus {
    return [self getCurrentStatus];
}

- (void)startConnectionCheck {
    [self stopConnectionCheck];
    
    self.retryCount = 0;
    self.connectionCheckTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(checkConnectionStatus)
                                                             userInfo:nil
                                                              repeats:YES];
}

- (void)stopConnectionCheck {
    [self.connectionCheckTimer invalidate];
    self.connectionCheckTimer = nil;
}

- (void)checkConnectionStatus {
    if (self.retryCount >= 30) { // 30秒超时
        [self stopConnectionCheck];
        [self stopVPNConnect];
        if ([self.delegate respondsToSelector:@selector(nbVpnStatusDidChange:)]) {
            [self.delegate nbVpnStatusDidChange:TFYVpnStatusDisconnected];
        }
        return;
    }
    
    NEVPNStatus status = self.providerManager.connection.status;
    if (status == NEVPNStatusConnected) {
        [self stopConnectionCheck];
    } else if (status == NEVPNStatusDisconnected || status == NEVPNStatusInvalid) {
        [self stopConnectionCheck];
        [self stopVPNConnect];
    }
    
    self.retryCount++;
}

@end 
