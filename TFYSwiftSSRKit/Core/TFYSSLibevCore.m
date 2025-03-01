#import "TFYSSLibevCore.h"
#import "TFYSSLibevCore+Private.h"
#import "TFYSSError.h"

@interface TFYSSLibevCore () {
    shadowsocks_config_t _ssConfig;
    BOOL _isRunning;
    uint64_t _uploadTraffic;
    uint64_t _downloadTraffic;
}

@property (nonatomic, strong) TFYSSConfig *config;
@property (nonatomic, copy, readwrite) NSString *version;
@property (nonatomic, assign, readwrite) TFYSSCoreType type;
@property (nonatomic, assign, readwrite) TFYSSCoreCapability capabilities;

@end

@implementation TFYSSLibevCore

@synthesize type = _type;
@synthesize version = _version;
@synthesize capabilities = _capabilities;

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = NO;
        _uploadTraffic = 0;
        _downloadTraffic = 0;
        _enableNAT = NO;
        _enableHTTP = NO;
        
        // 设置核心类型和能力
        _type = TFYSSCoreTypeC;
        _version = [self getLibevVersion];
        _capabilities = TFYSSCoreCapabilityTCP | TFYSSCoreCapabilityUDP | TFYSSCoreCapabilityFastOpen | 
                       TFYSSCoreCapabilityNAT | TFYSSCoreCapabilityHTTP;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (NSString *)getLibevVersion {
    // 获取 libev 版本
    const char *version = shadowsocks_version();
    return version ? [NSString stringWithUTF8String:version] : @"Unknown";
}

#pragma mark - TFYSSCoreProtocol

- (BOOL)initializeEngine {
    // 初始化 shadowsocks 引擎
    if (shadowsocks_init() != 0) {
        NSLog(@"Failed to initialize shadowsocks engine");
        return NO;
    }
    return YES;
}

- (BOOL)startWithConfig:(TFYSSConfig *)config error:(NSError **)error {
    if (!config) {
        if (error) {
            *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorConfigInvalid userInfo:@{
                NSLocalizedDescriptionKey: @"Configuration is nil"
            }];
        }
        return NO;
    }
    
    // 验证配置
    NSError *validationError = nil;
    if (![config validate:&validationError]) {
        if (error) {
            *error = validationError;
        }
        return NO;
    }
    
    self.config = config;
    self.enableNAT = config.enableNAT;
    self.enableHTTP = config.enableHTTP;
    
    // 重置流量统计
    _uploadTraffic = 0;
    _downloadTraffic = 0;
    
    if (_isRunning) {
        [self stop];
    }
    
    // 配置 shadowsocks
    memset(&_ssConfig, 0, sizeof(shadowsocks_config_t));
    _ssConfig.server = strdup([self.config.serverHost UTF8String]);
    _ssConfig.server_port = (int)self.config.serverPort;
    _ssConfig.local_addr = strdup([self.config.localAddress UTF8String]);
    _ssConfig.local_port = (int)self.config.localPort;
    _ssConfig.method = strdup([self.config.method UTF8String]);
    _ssConfig.password = strdup([self.config.password UTF8String]);
    _ssConfig.timeout = (int)self.config.timeout;
    
    // 启动 shadowsocks
    int result = shadowsocks_start(&_ssConfig);
    if (result != 0) {
        if (error) {
            *error = [NSError errorWithDomain:TFYSSErrorDomain code:TFYSSErrorStartFailed userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to start shadowsocks: %s", shadowsocks_strerror(shadowsocks_errno)]
            }];
        }
        return NO;
    }
    
    _isRunning = YES;
    
    // 如果启用了 HTTP 代理，启动 Privoxy
    if (self.enableHTTP) {
        [self startHTTPProxy:self.config.localAddress port:self.config.httpPort];
    }
    
    // 如果启用了 NAT 穿透，启动 antinat
    if (self.enableNAT) {
        [self enableNATTraversal:self.config.serverHost port:self.config.serverPort];
    }
    
    return YES;
}

- (BOOL)stop {
    if (!_isRunning) {
        return YES;
    }
    
    // 停止 HTTP 代理
    if (self.enableHTTP) {
        [self stopHTTPProxy];
    }
    
    // 停止 NAT 穿透
    if (self.enableNAT) {
        antinat_stop();
    }
    
    // 停止 shadowsocks
    shadowsocks_stop();
    
    // 释放配置内存
    if (_ssConfig.server) free((void *)_ssConfig.server);
    if (_ssConfig.local_addr) free((void *)_ssConfig.local_addr);
    if (_ssConfig.method) free((void *)_ssConfig.method);
    if (_ssConfig.password) free((void *)_ssConfig.password);
    memset(&_ssConfig, 0, sizeof(shadowsocks_config_t));
    
    _isRunning = NO;
    
    return YES;
}

- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download {
    if (!_isRunning) {
        if (upload) *upload = _uploadTraffic;
        if (download) *download = _downloadTraffic;
        return;
    }
    
    uint64_t up = 0, down = 0;
    shadowsocks_get_traffic(&up, &down);
    _uploadTraffic = up;
    _downloadTraffic = down;
    
    if (upload) *upload = _uploadTraffic;
    if (download) *download = _downloadTraffic;
}

#pragma mark - NAT Methods

- (NSDictionary<NSString *, id> *)detectNATType {
    if (!_isRunning) {
        return nil;
    }
    
    antinat_info_t info;
    memset(&info, 0, sizeof(antinat_info_t));
    
    int result = antinat_detect(&info);
    if (result != 0) {
        NSLog(@"Failed to detect NAT type: %s", antinat_strerror(result));
        return nil;
    }
    
    NSString *natTypeString;
    switch (info.nat_type) {
        case TFYSSNATTypeFullCone:
            natTypeString = @"Full Cone";
            break;
        case TFYSSNATTypeRestricted:
            natTypeString = @"Restricted Cone";
            break;
        case TFYSSNATTypePortRestricted:
            natTypeString = @"Port Restricted Cone";
            break;
        case TFYSSNATTypeSymmetric:
            natTypeString = @"Symmetric";
            break;
        default:
            natTypeString = @"Unknown";
            break;
    }
    
    return @{
        @"type": @(info.nat_type),
        @"typeString": natTypeString,
        @"publicIP": info.public_ip ? @(info.public_ip) : @"",
        @"publicPort": @(info.public_port)
    };
}

- (BOOL)enableNATTraversal:(NSString *)server port:(NSInteger)port {
    if (!_isRunning) {
        return NO;
    }
    
    // 初始化 antinat
    if (antinat_init() != 0) {
        NSLog(@"Failed to initialize antinat");
        return NO;
    }
    
    // 配置 antinat
    antinat_config_t config;
    memset(&config, 0, sizeof(antinat_config_t));
    config.server = [server UTF8String];
    config.server_port = (int)port;
    
    // 启动 antinat
    int result = antinat_start(&config);
    if (result != 0) {
        NSLog(@"Failed to start antinat: %s", antinat_strerror(result));
        return NO;
    }
    
    return YES;
}

#pragma mark - HTTP Proxy Methods

- (BOOL)startHTTPProxy:(NSString *)listenAddr port:(NSInteger)port {
    if (!_isRunning) {
        return NO;
    }
    
    // 初始化 Privoxy
    if (ss_privoxy_init() != 0) {
        NSLog(@"Failed to initialize Privoxy");
        return NO;
    }
    
    // 配置 Privoxy
    privoxy_config_t config;
    memset(&config, 0, sizeof(privoxy_config_t));
    config.socks5_address = [self.config.localAddress UTF8String];
    config.socks5_port = (int)self.config.localPort;
    config.listen_address = [listenAddr UTF8String];
    config.listen_port = (int)port;
    
    // 启动 Privoxy
    int result = ss_privoxy_start(&config);
    if (result != 0) {
        NSLog(@"Failed to start Privoxy");
        return NO;
    }
    
    // 添加一些基本过滤规则
    ss_privoxy_add_filter("s@^Accept-Encoding:.*@Accept-Encoding: identity@");
    ss_privoxy_toggle_compression(1);  // 启用压缩
    
    return YES;
}

- (void)stopHTTPProxy {
    if (_isRunning) {
        ss_privoxy_stop();
    }
}

@end 