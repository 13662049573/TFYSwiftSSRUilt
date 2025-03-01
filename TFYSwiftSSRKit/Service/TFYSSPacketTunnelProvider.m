#import "TFYSSPacketTunnelProvider.h"
#import "TFYSSCoreFactory.h"
#import "TFYSSError.h"
#import "TFYSSLibevCore+Private.h"
#import <NetworkExtension/NetworkExtension.h>

@interface TFYSSPacketTunnelProvider ()

@property (nonatomic, strong) id<TFYSSCoreProtocol> ssCore;
@property (nonatomic, strong) TFYSSConfig *currentConfig;
@property (nonatomic, assign) uint64_t uploadTraffic;
@property (nonatomic, assign) uint64_t downloadTraffic;
@property (nonatomic, strong) dispatch_source_t trafficTimer;

@end

@implementation TFYSSPacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    // 从 options 中获取配置
    NSData *configData = options[@"config"];
    if (!configData) {
        // 如果没有直接传递配置数据，尝试从 providerConfiguration 中获取配置
        NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *)self.protocolConfiguration;
        NSDictionary *providerConfig = protocol.providerConfiguration;
        if (providerConfig) {
            // 从 providerConfiguration 创建配置对象
            TFYSSConfig *config = [[TFYSSConfig alloc] init];
            config.serverHost = providerConfig[@"serverHost"];
            config.serverPort = [providerConfig[@"serverPort"] unsignedShortValue];
            config.method = providerConfig[@"method"];
            config.password = providerConfig[@"password"];
            config.localAddress = providerConfig[@"localAddress"] ?: @"127.0.0.1";
            config.localPort = [providerConfig[@"localPort"] unsignedShortValue];
            config.timeout = [providerConfig[@"timeout"] doubleValue];
            config.enableNAT = [providerConfig[@"enableNAT"] boolValue];
            config.enableHTTP = [providerConfig[@"enableHTTP"] boolValue];
            config.httpPort = [providerConfig[@"httpPort"] unsignedShortValue];
            config.preferredCoreType = [providerConfig[@"preferredCoreType"] integerValue];
            
            [self startTunnelWithConfig:config completionHandler:completionHandler];
            return;
        }
        
        NSError *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:@{NSLocalizedDescriptionKey: @"No configuration provided"}];
        completionHandler(error);
        return;
    }
    
    // 反序列化配置
    NSError *unarchiveError = nil;
    TFYSSConfig *config = [NSKeyedUnarchiver unarchivedObjectOfClass:[TFYSSConfig class] fromData:configData error:&unarchiveError];
    if (!config) {
        NSError *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:@{
            NSLocalizedDescriptionKey: @"Invalid configuration data",
            NSUnderlyingErrorKey: unarchiveError ?: [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:nil]
        }];
        completionHandler(error);
        return;
    }
    
    [self startTunnelWithConfig:config completionHandler:completionHandler];
}

- (void)startTunnelWithConfig:(TFYSSConfig *)config completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    // 保存配置
    self.currentConfig = config;
    
    // 创建 Shadowsocks 核心
    self.ssCore = [TFYSSCoreFactory createCoreWithType:config.preferredCoreType];
    if (!self.ssCore) {
        NSError *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorStartFailed userInfo:@{NSLocalizedDescriptionKey: @"Failed to create core instance"}];
        completionHandler(error);
        return;
    }
    
    // 初始化引擎
    if (![self.ssCore initializeEngine]) {
        NSError *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorStartFailed userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize engine"}];
        completionHandler(error);
        return;
    }
    
    // 启动 Shadowsocks 代理
    NSError *startError = nil;
    if (![self.ssCore startWithConfig:config error:&startError]) {
        completionHandler(startError);
        return;
    }
    
    // 如果启用了 HTTP 代理，启动 Privoxy
    if (config.enableHTTP) {
        privoxy_config_t privoxyConfig;
        privoxyConfig.socks5_address = [config.localAddress UTF8String];
        privoxyConfig.socks5_port = config.localPort;
        privoxyConfig.listen_address = "127.0.0.1";
        privoxyConfig.listen_port = config.httpPort;
        
        if (ss_privoxy_init() != 0) {
            NSLog(@"Failed to initialize Privoxy");
        } else if (ss_privoxy_start(&privoxyConfig) != 0) {
            NSLog(@"Failed to start Privoxy");
            ss_privoxy_stop();
        } else {
            NSLog(@"Privoxy started successfully");
        }
    }
    
    // 配置 VPN 隧道
    [self setupTunnelNetworkSettings:config completionHandler:^(NSError * _Nullable error) {
        if (error) {
            [self.ssCore stop];
            self.ssCore = nil;
            
            // 如果启用了 HTTP 代理，停止 Privoxy
            if (config.enableHTTP) {
                ss_privoxy_stop();

            }
            
            completionHandler(error);
            return;
        }
        
        // 启动流量统计定时器
        [self setupTrafficTimer];
        
        completionHandler(nil);
    }];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    // 停止流量统计定时器
    if (self.trafficTimer) {
        dispatch_source_cancel(self.trafficTimer);
        self.trafficTimer = nil;
    }
    
    // 停止 Shadowsocks 代理
    if (self.ssCore) {
        [self.ssCore stop];
        self.ssCore = nil;
    }
    
    // 如果启用了 HTTP 代理，停止 Privoxy
    if (self.currentConfig.enableHTTP) {
        ss_privoxy_stop();
    }
    
    self.currentConfig = nil;
    
    completionHandler();
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData * _Nullable))completionHandler {
    // 处理来自主应用的消息
    NSError *error = nil;
    NSDictionary *message = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:&error];
    if (error) {
        completionHandler(nil);
        return;
    }
    
    NSString *command = message[@"command"];
    if ([command isEqualToString:@"getTraffic"]) {
        // 获取流量统计
        uint64_t upload = 0, download = 0;
        [self getTrafficWithUpload:&upload download:&download];
        
        NSDictionary *response = @{
            @"upload": @(upload),
            @"download": @(download)
        };
        
        NSData *responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
        completionHandler(responseData);
    } else if ([command isEqualToString:@"updateConfig"]) {
        // 更新配置
        NSData *configData = message[@"config"];
        if (configData) {
            TFYSSConfig *config = [NSKeyedUnarchiver unarchivedObjectOfClass:[TFYSSConfig class] fromData:configData error:nil];
            if (config) {
                // 停止当前连接
                [self.ssCore stop];
                
                // 如果启用了 HTTP 代理，停止 Privoxy
                if (self.currentConfig.enableHTTP) {
                    ss_privoxy_stop();
                }
                
                // 启动新连接
                NSError *startError = nil;
                if ([self.ssCore startWithConfig:config error:&startError]) {
                    self.currentConfig = config;
                    
                    // 如果启用了 HTTP 代理，启动 Privoxy
                    if (config.enableHTTP) {
                        privoxy_config_t privoxyConfig;
                        privoxyConfig.socks5_address = [config.localAddress UTF8String];
                        privoxyConfig.socks5_port = config.localPort;
                        privoxyConfig.listen_address = "127.0.0.1";
                        privoxyConfig.listen_port = config.httpPort;
                        
                        ss_privoxy_init();
                        ss_privoxy_start(&privoxyConfig);
                    }
                    
                    NSDictionary *response = @{@"status": @"success"};
                    NSData *responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
                    completionHandler(responseData);
                    return;
                }
            }
        }
        
        NSDictionary *response = @{@"status": @"failed"};
        NSData *responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
        completionHandler(responseData);
    } else {
        completionHandler(nil);
    }
}

- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download {
    if (!self.ssCore) {
        if (upload) *upload = 0;
        if (download) *download = 0;
        return;
    }
    
    // 直接从 shadowsocks 获取流量统计
    shadowsocks_get_traffic(upload, download);
}

#pragma mark - Private Methods

- (void)setupTunnelNetworkSettings:(TFYSSConfig *)config completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    // 创建 VPN 隧道网络设置
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:config.serverHost];
    
    // 配置 DNS 设置
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers:@[@"8.8.8.8", @"8.8.4.4"]];
    dnsSettings.matchDomains = @[@""];
    settings.DNSSettings = dnsSettings;
    
    // 配置 IPv4 设置
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"192.168.1.1"] subnetMasks:@[@"255.255.255.0"]];
    ipv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
    settings.IPv4Settings = ipv4Settings;
    
    // 配置代理设置
    NEProxySettings *proxySettings = [[NEProxySettings alloc] init];
    
    // 如果启用了 HTTP 代理
    if (config.enableHTTP) {
        proxySettings.autoProxyConfigurationEnabled = NO;
        proxySettings.HTTPEnabled = YES;
        proxySettings.HTTPServer = [[NEProxyServer alloc] initWithAddress:@"127.0.0.1" port:config.httpPort];
        proxySettings.HTTPSEnabled = YES;
        proxySettings.HTTPSServer = [[NEProxyServer alloc] initWithAddress:@"127.0.0.1" port:config.httpPort];
    } else {
        // 否则使用 SOCKS 代理
        proxySettings.HTTPEnabled = NO;
        proxySettings.HTTPSEnabled = NO;
        
        // 使用PAC文件配置代理
        NSString *pacString = [NSString stringWithFormat:@"\
function FindProxyForURL(url, host) {\
    if (isPlainHostName(host) || host === 'localhost' || host === '127.0.0.1') {\
        return 'DIRECT';\
    }\
    return 'SOCKS 127.0.0.1:%d';\
}", config.localPort];
        
        // 创建临时目录路径
        NSString *tempDir = NSTemporaryDirectory();
        NSString *pacFilePath = [tempDir stringByAppendingPathComponent:@"proxy.pac"];
        
        // 写入PAC文件
        NSError *writeError = nil;
        [pacString writeToFile:pacFilePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        if (writeError) {
            NSLog(@"Failed to write PAC file: %@", writeError);
        } else {
            // 设置PAC URL
            NSURL *pacURL = [NSURL fileURLWithPath:pacFilePath];
            proxySettings.autoProxyConfigurationEnabled = YES;
            proxySettings.proxyAutoConfigurationURL = pacURL;
        }
    }
    
    proxySettings.excludeSimpleHostnames = YES;
    proxySettings.exceptionList = @[@"localhost", @"127.0.0.1"];
    settings.proxySettings = proxySettings;
    
    // 应用网络设置
    [self setTunnelNetworkSettings:settings completionHandler:completionHandler];
}

- (void)setupTrafficTimer {
    dispatch_queue_t queue = dispatch_get_main_queue();
    self.trafficTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.trafficTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.trafficTimer, ^{
        [weakSelf updateTrafficStats];
    });
    
    dispatch_resume(self.trafficTimer);
}

- (void)updateTrafficStats {
    if (!self.ssCore) return;
    
    uint64_t upload = 0, download = 0;
    shadowsocks_get_traffic(&upload, &download);
    
    self.uploadTraffic = upload;
    self.downloadTraffic = download;
}

@end
