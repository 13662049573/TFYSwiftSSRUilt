#import "TFYTunnelManager.h"
#import <MMWormhole/MMWormhole.h>

@interface TFYTunnelManager ()

@property (nonatomic, strong) NEVPNManager *vpnManager;
@property (nonatomic, strong) NETunnelProviderManager *tunnelManager;
@property (nonatomic, strong) MMWormhole *wormhole;
@property (nonatomic, strong) NSUserDefaults *sharedDefaults;

@end

@implementation TFYTunnelManager

+ (instancetype)sharedManager {
    static TFYTunnelManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TFYTunnelManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _vpnManager = [NEVPNManager sharedManager];
        _sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.tfy.ssr"];
        [self setupWormhole];
        [self loadTunnelManager];
    }
    return self;
}

- (void)setupWormhole {
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.tfy.ssr"
                                                         optionalDirectory:@"tunnel"];
}

- (void)loadTunnelManager {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to load tunnel manager: %@", error);
            return;
        }
        
        if (managers.count > 0) {
            self.tunnelManager = managers.firstObject;
        } else {
            self.tunnelManager = [[NETunnelProviderManager alloc] init];
            NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
            protocol.providerBundleIdentifier = @"com.tfy.ssr.tunnel";
            protocol.serverAddress = @"127.0.0.1";
            self.tunnelManager.protocolConfiguration = protocol;
            self.tunnelManager.localizedDescription = @"TFY SSR VPN";
            
            [self.tunnelManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Failed to save tunnel manager: %@", error);
                }
            }];
        }
    }];
}

- (BOOL)isConnected {
    return self.tunnelManager.connection.status == NEVPNStatusConnected;
}

- (void)startTunnelWithConfiguration:(NSDictionary *)config
                        completion:(void(^)(NSError * _Nullable error))completion {
    // 保存配置到共享存储
    [self.sharedDefaults setObject:config forKey:@"SSRConfig"];
    [self.sharedDefaults synchronize];
    
    // 启动隧道
    NSError *error = nil;
    [self.tunnelManager.connection startVPNTunnelAndReturnError:&error];
    
    if (completion) {
        completion(error);
    }
}

- (void)stopTunnelWithCompletion:(void(^)(NSError * _Nullable error))completion {
    [self.tunnelManager.connection stopVPNTunnel];
    if (completion) {
        completion(nil);
    }
}

- (void)getTunnelStatusWithCompletion:(void(^)(NSDictionary *status, NSError * _Nullable error))completion {
    NETunnelProviderSession *session = (NETunnelProviderSession *)self.tunnelManager.connection;
    
    [session sendProviderMessage:[@"GetStatus" dataUsingEncoding:NSUTF8StringEncoding]
               responseHandler:^(NSData * _Nullable responseData) {
        if (!responseData) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"com.tfy.tunnel"
                                                   code:-1
                                               userInfo:@{NSLocalizedDescriptionKey: @"No response from tunnel provider"}];
                completion(nil, error);
            }
            return;
        }
        
        NSError *error = nil;
        NSDictionary *status = [NSJSONSerialization JSONObjectWithData:responseData
                                                             options:0
                                                               error:&error];
        if (completion) {
            completion(status, error);
        }
    }];
}

- (void)updateConfiguration:(NSDictionary *)config
                completion:(void(^)(NSError * _Nullable error))completion {
    // 保存新配置
    [self.sharedDefaults setObject:config forKey:@"SSRConfig"];
    [self.sharedDefaults synchronize];
    
    // 通知隧道提供者更新配置
    [self.wormhole passMessageObject:config identifier:@"ConfigUpdate"];
    
    if (completion) {
        completion(nil);
    }
}

@end 