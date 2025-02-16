#import "TFYVPNManager.h"

@interface TFYVPNManager ()

@property (nonatomic, strong) NEVPNManager *vpnManager;
@property (nonatomic, assign) TFYVPNStatus status;
@property (nonatomic, strong) TFYVPNConfiguration *currentConfiguration;
@property (nonatomic, strong) id vpnStatusObserver;

@end

@implementation TFYVPNManager

+ (instancetype)sharedManager {
    static TFYVPNManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TFYVPNManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _vpnManager = [NEVPNManager sharedManager];
        _status = TFYVPNStatusDisconnected;
        [self setupVPNStatusObserver];
    }
    return self;
}

- (void)setupVPNStatusObserver {
    __weak typeof(self) weakSelf = self;
    self.vpnStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification
                                                                            object:nil
                                                                             queue:[NSOperationQueue mainQueue]
                                                                        usingBlock:^(NSNotification * _Nonnull note) {
        NEVPNConnection *connection = note.object;
        [weakSelf handleVPNStatusChange:connection.status];
    }];
}

- (void)handleVPNStatusChange:(NEVPNStatus)vpnStatus {
    TFYVPNStatus newStatus;
    switch (vpnStatus) {
        case NEVPNStatusDisconnected:
            newStatus = TFYVPNStatusDisconnected;
            break;
        case NEVPNStatusConnecting:
            newStatus = TFYVPNStatusConnecting;
            break;
        case NEVPNStatusConnected:
            newStatus = TFYVPNStatusConnected;
            break;
        case NEVPNStatusDisconnecting:
            newStatus = TFYVPNStatusDisconnecting;
            break;
        case NEVPNStatusInvalid:
            newStatus = TFYVPNStatusInvalid;
            break;
        case NEVPNStatusReasserting:
            newStatus = TFYVPNStatusReasserting;
            break;
    }
    
    self.status = newStatus;
    
    if ([self.delegate respondsToSelector:@selector(vpnStatusDidChange:)]) {
        [self.delegate vpnStatusDidChange:newStatus];
    }
    
    if (newStatus == TFYVPNStatusConnected) {
        if ([self.delegate respondsToSelector:@selector(vpnDidConnect)]) {
            [self.delegate vpnDidConnect];
        }
    } else if (newStatus == TFYVPNStatusDisconnected) {
        if ([self.delegate respondsToSelector:@selector(vpnDidDisconnect)]) {
            [self.delegate vpnDidDisconnect];
        }
    }
}

- (void)requestVPNPermissionWithCompletion:(void(^)(BOOL granted, NSError * _Nullable error))completion {
    [self.vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(NO, error);
            }
            return;
        }
        
        if (completion) {
            completion(YES, nil);
        }
    }];
}

- (void)configureVPNWithConfiguration:(TFYVPNConfiguration *)configuration
                         completion:(void(^)(NSError * _Nullable error))completion {
    self.currentConfiguration = configuration;
    
    [self.vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(error);
            }
            return;
        }
        
        NEVPNProtocolIPSec *protocol = [[NEVPNProtocolIPSec alloc] init];
        protocol.username = configuration.username;
        protocol.passwordReference = [self keyChainPasswordRefForPassword:configuration.password];
        protocol.serverAddress = configuration.serverAddress;
        protocol.authenticationMethod = NEVPNIKEAuthenticationMethodSharedSecret;
        
        // 设置代理
        if (configuration.proxyServerAddress) {
            NEProxySettings *proxySettings = [[NEProxySettings alloc] init];
            proxySettings.HTTPEnabled = YES;
            proxySettings.HTTPSEnabled = YES;
            proxySettings.HTTPServer = [[NEProxyServer alloc] initWithAddress:configuration.proxyServerAddress
                                                                       port:configuration.proxyServerPort];
            proxySettings.HTTPSServer = [[NEProxyServer alloc] initWithAddress:configuration.proxyServerAddress
                                                                        port:configuration.proxyServerPort];
            self.vpnManager.protocolConfiguration.proxySettings = proxySettings;
        }
        
        self.vpnManager.protocolConfiguration = protocol;
        self.vpnManager.localizedDescription = configuration.vpnName;
        self.vpnManager.enabled = YES;
        
        [self.vpnManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (completion) {
                completion(error);
            }
        }];
    }];
}

- (void)connectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion {
    NSError *error = nil;
    [self.vpnManager.connection startVPNTunnelAndReturnError:&error];
    
    if (error) {
        if ([self.delegate respondsToSelector:@selector(vpnConnectDidFail:)]) {
            [self.delegate vpnConnectDidFail:error];
        }
    }
    
    if (completion) {
        completion(error);
    }
}

- (void)disconnectVPNWithCompletion:(void(^)(NSError * _Nullable error))completion {
    [self.vpnManager.connection stopVPNTunnel];
    if (completion) {
        completion(nil);
    }
}

- (void)removeVPNConfiguration:(void(^)(NSError * _Nullable error))completion {
    [self.vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(error);
            }
            return;
        }
        
        self.vpnManager.protocolConfiguration = nil;
        self.vpnManager.enabled = NO;
        
        [self.vpnManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (completion) {
                completion(error);
            }
        }];
    }];
}

- (void)loadVPNConfigurationsWithCompletion:(void(^)(NSArray<NEVPNConnection *> * _Nullable configurations, NSError * _Nullable error))completion {
    [self.vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        if (completion) {
            completion(@[self.vpnManager.connection], nil);
        }
    }];
}

#pragma mark - Helper Methods

- (NSData *)keyChainPasswordRefForPassword:(NSString *)password {
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: @"VPNPassword",
        (__bridge id)kSecValueData: passwordData,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock
    };
    
    SecItemDelete((__bridge CFDictionaryRef)query);
    
    CFTypeRef result = NULL;
    SecItemAdd((__bridge CFDictionaryRef)query, &result);
    
    return (__bridge_transfer NSData *)result;
}

- (void)dealloc {
    if (self.vpnStatusObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.vpnStatusObserver];
    }
}

@end
