#import "TFYPacketTunnelProvider.h"
#import "TFYSSRManager.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <MMWormhole/MMWormhole.h>

@interface TFYPacketTunnelProvider () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) TFYSSRManager *ssrManager;
@property (nonatomic, strong) GCDAsyncSocket *tunnelSocket;
@property (nonatomic, strong) MMWormhole *wormhole;
@property (nonatomic, strong) NSMutableArray<NSData *> *pendingPackets;
@property (nonatomic, strong) dispatch_queue_t tunnelQueue;

@end

@implementation TFYPacketTunnelProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _tunnelQueue = dispatch_queue_create("com.tfy.tunnel.queue", DISPATCH_QUEUE_SERIAL);
        _pendingPackets = [NSMutableArray array];
        [self setupWormhole];
    }
    return self;
}

- (void)setupWormhole {
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.tfy.ssr"
                                                         optionalDirectory:@"tunnel"];
    
    __weak typeof(self) weakSelf = self;
    [self.wormhole listenForMessageWithIdentifier:@"ConfigUpdate" listener:^(id messageObject) {
        if ([messageObject isKindOfClass:[NSDictionary class]]) {
            [weakSelf updateConfigurationWithDictionary:messageObject];
        }
    }];
}

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    // 设置隧道配置
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];
    
    // 配置DNS
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers:@[@"8.8.8.8", @"8.8.4.4"]];
    settings.DNSSettings = dnsSettings;
    
    // 配置IPv4
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"192.168.1.1"]
                                                                subnetMasks:@[@"255.255.255.0"]];
    ipv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
    settings.IPv4Settings = ipv4Settings;
    
    // 配置代理
    NEProxySettings *proxySettings = [[NEProxySettings alloc] init];
    proxySettings.HTTPEnabled = YES;
    proxySettings.HTTPSEnabled = YES;
    proxySettings.matchDomains = @[@""];
    settings.proxySettings = proxySettings;
    
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        if (error) {
            completionHandler(error);
            return;
        }
        
        // 启动SSR
        [self startSSRWithCompletionHandler:^(NSError *ssrError) {
            if (ssrError) {
                completionHandler(ssrError);
                return;
            }
            
            // 启动Socket
            [self startTunnelSocket];
            
            completionHandler(nil);
        }];
    }];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    [self.ssrManager stop];
    [self.tunnelSocket disconnect];
    self.tunnelSocket.delegate = nil;
    self.tunnelSocket = nil;
    [self.pendingPackets removeAllObjects];
    
    completionHandler();
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSError *error = nil;
    NSDictionary *message = [NSJSONSerialization JSONObjectWithData:messageData
                                                           options:0
                                                             error:&error];
    if (error) {
        completionHandler(nil);
        return;
    }
    
    NSString *command = message[@"command"];
    if ([command isEqualToString:@"GetStatus"]) {
        NSDictionary *status = @{
            @"isConnected": @(self.tunnelSocket.isConnected),
            @"pendingPackets": @(self.pendingPackets.count)
        };
        
        NSData *responseData = [NSJSONSerialization dataWithJSONObject:status
                                                             options:0
                                                               error:&error];
        completionHandler(responseData);
    } else {
        completionHandler(nil);
    }
}

#pragma mark - SSR Methods

- (void)startSSRWithCompletionHandler:(void (^)(NSError *))completionHandler {
    // 从用户默认设置获取配置
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.tfy.ssr"];
    NSDictionary *config = [sharedDefaults objectForKey:@"SSRConfig"];
    
    if (!config) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.ssr"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"No SSR configuration found"}];
        completionHandler(error);
        return;
    }
    
    TFYSSRConfiguration *ssrConfig = [TFYSSRConfiguration configurationWithHost:config[@"host"]
                                                                       port:[config[@"port"] integerValue]
                                                                  password:config[@"password"]
                                                                   method:config[@"method"]];
    
    self.ssrManager = [TFYSSRManager sharedManager];
    BOOL success = [self.ssrManager startWithConfiguration:ssrConfig];
    
    if (success) {
        completionHandler(nil);
    } else {
        NSError *error = [NSError errorWithDomain:@"com.tfy.ssr"
                                           code:-2
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to start SSR"}];
        completionHandler(error);
    }
}

#pragma mark - Socket Methods

- (void)startTunnelSocket {
    self.tunnelSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.tunnelQueue];
    
    NSError *error = nil;
    if (![self.tunnelSocket connectToHost:@"127.0.0.1"
                                onPort:self.ssrManager.currentConfig.localPort
                           withTimeout:30
                                error:&error]) {
        NSLog(@"Failed to connect to local SSR proxy: %@", error);
        return;
    }
}

- (void)handlePacket:(NSData *)packet completionHandler:(void (^)(NSError *))completionHandler {
    if (!self.tunnelSocket.isConnected) {
        [self.pendingPackets addObject:packet];
        completionHandler(nil);
        return;
    }
    
    [self.tunnelSocket writeData:packet withTimeout:-1 tag:0];
    completionHandler(nil);
}

#pragma mark - Configuration Methods

- (void)updateConfigurationWithDictionary:(NSDictionary *)config {
    [self.ssrManager stop];
    
    TFYSSRConfiguration *ssrConfig = [TFYSSRConfiguration configurationWithHost:config[@"host"]
                                                                       port:[config[@"port"] integerValue]
                                                                  password:config[@"password"]
                                                                   method:config[@"method"]];
    
    [self.ssrManager startWithConfiguration:ssrConfig];
    [self startTunnelSocket];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"Connected to local SSR proxy");
    
    // 处理待处理的数据包
    for (NSData *packet in self.pendingPackets) {
        [self.tunnelSocket writeData:packet withTimeout:-1 tag:0];
    }
    [self.pendingPackets removeAllObjects];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"Disconnected from local SSR proxy: %@", err);
    
    // 重新连接
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.tunnelQueue, ^{
        [self startTunnelSocket];
    });
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    // 将数据包写回TUN接口
    [self.packetFlow writePackets:@[data] withProtocols:@[@(AF_INET)]];
    
    // 继续读取数据
    [self.tunnelSocket readDataWithTimeout:-1 tag:0];
}

@end 