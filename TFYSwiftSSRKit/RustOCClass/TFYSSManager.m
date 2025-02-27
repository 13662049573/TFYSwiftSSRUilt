#import "TFYSSManager.h"
#import "shadowsocks-rust/include/ss.h"

NS_ASSUME_NONNULL_BEGIN

@interface TFYSSManager ()
@property (nonatomic, strong) NSDictionary *currentConfig;
@end

@implementation TFYSSConfig

- (instancetype)initWithServerAddress:(NSString *)serverAddress
                         serverPort:(uint16_t)serverPort
                          password:(NSString *)password
                           method:(NSString *)method
                          timeout:(NSInteger)timeout {
    self = [super init];
    if (self) {
        _serverAddress = [serverAddress copy];
        _serverPort = serverPort;
        _password = [password copy];
        _method = [method copy];
        _timeout = timeout;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        // 基本配置
        @"server": self.serverAddress ?: @"",
        @"server_port": @(self.serverPort),
        @"password": self.password ?: @"",
        @"method": self.method ?: @"",
        @"timeout": @(self.timeout),
        
        // 本地服务器配置
        @"local_address": @"127.0.0.1",
        @"local_port": @(1080),
        @"mode": @"tcp_and_udp",  // 支持 TCP 和 UDP
        
        // 协议和混淆配置
        @"protocol": @"origin",
        @"protocol_param": @"",
        @"obfs": @"plain",
        @"obfs_param": @"",
        
        // DNS 配置
        @"dns": @"google",  // 使用 Google DNS
        @"dns_cache_size": @(1024),
        
        // TCP 配置
        @"no_delay": @(YES),
        @"keep_alive": @(15),
        
        // UDP 配置
        @"udp_timeout": @(300),
        @"udp_max_associations": @(512),
        
        // IPv6 配置
        @"ipv6_first": @(NO),
        @"ipv6_only": @(NO),
        
        // 日志配置
        @"log": @{
            @"level": @(1),
            @"format": @{
                @"without_time": @(NO)
            }
        }
    };
}

- (nullable NSString *)toJSONString {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self toDictionary]
                                                      options:0
                                                        error:&error];
    if (error) {
        NSLog(@"转换 JSON 失败: %@", error);
        return nil;
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end

@implementation TFYSSManager

+ (TFYSSManager *)shared {
    static TFYSSManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logLevel = TFYSSLogLevelInfo;
        _proxyMode = TFYSSProxyModePAC;
    }
    return self;
}

- (void)setup {
    NSLog(@"初始化 SS 管理器");
    ss_init();
    ss_set_log_level((int32_t)self.logLevel);
}

- (BOOL)startWithConfig:(NSDictionary *)config NS_SWIFT_NAME(startProxy(withConfig:)) {
    NSLog(@"启动 SS 服务: %@", config);
    
    self.currentConfig = config; // 保存当前配置
    
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:config 
                                                      options:0 
                                                        error:&jsonError];
    if (!jsonData) {
        NSLog(@"配置转换失败: %@", jsonError);
        return NO;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    int32_t result = ss_start(jsonString.UTF8String);
    
    if (result != 0) {
        NSLog(@"SS 启动失败: %@", self.lastError);
        return NO;
    }
    
    NSLog(@"SS 启动成功");
    return YES;
}

- (void)stop {
    NSLog(@"停止 SS 服务");
    self.currentConfig = nil;
    ss_stop();
}

- (BOOL)updatePACRules:(NSString *)rules NS_SWIFT_NAME(updatePacrules(rules:)) {
    NSLog(@"更新 PAC 规则");
    int32_t result = ss_update_pac(rules.UTF8String);
    if (result != 0) {
        NSLog(@"更新 PAC 规则失败: %@", self.lastError);
        return NO;
    }
    NSLog(@"更新 PAC 规则成功");
    return YES;
}

#pragma mark - Properties

- (NSString *)version {
    return @(ss_get_version());
}

- (TFYSSState)state {
    return (TFYSSState)ss_get_state();
}

- (void)setLogLevel:(TFYSSLogLevel)logLevel {
    _logLevel = logLevel;
    ss_set_log_level((int32_t)logLevel);
}

- (void)setProxyMode:(TFYSSProxyMode)proxyMode {
    _proxyMode = proxyMode;
    ss_set_mode((int32_t)proxyMode);
}

- (NSString *)lastError {
    return @(ss_get_last_error());
}

- (uint64_t)uploadTraffic {
    uint64_t upload = 0;
    ss_get_traffic(&upload, NULL);
    return upload;
}

- (uint64_t)downloadTraffic {
    uint64_t download = 0;
    ss_get_traffic(NULL, &download);
    return download;
}

- (NSString *)serverAddress {
    return [self.currentConfig objectForKey:@"server"] ?: @"";
}

- (uint16_t)serverPort {
    return [[self.currentConfig objectForKey:@"server_port"] unsignedShortValue];
}

@end

NS_ASSUME_NONNULL_END 
