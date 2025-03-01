#import "TFYSSRustCore.h"
#import "TFYSSProxyService.h"
#import "TFYSSError.h"
#import "../shadowsocks-rust/include/ss.h"

@interface TFYSSRustCore () {
    BOOL _isInitialized;
    BOOL _isRunning;
}

@property (nonatomic, strong) TFYSSConfig *currentConfig;
@property (nonatomic, copy) TFYSSTrafficStatsCallback trafficCallback;
@property (nonatomic, assign) uint64_t lastUploadTraffic;
@property (nonatomic, assign) uint64_t lastDownloadTraffic;

@end

@implementation TFYSSRustCore

@synthesize type = _type;
@synthesize version = _version;
@synthesize capabilities = _capabilities;

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = TFYSSCoreTypeRust;
        _version = [self getVersion];
        _capabilities = TFYSSCoreCapabilityTCP | TFYSSCoreCapabilityUDP | TFYSSCoreCapabilityFastOpen;
        _isInitialized = NO;
        _isRunning = NO;
        _lastUploadTraffic = 0;
        _lastDownloadTraffic = 0;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

#pragma mark - TFYSSCoreProtocol

- (BOOL)initializeEngine {
    if (_isInitialized) return YES;
    
    // 初始化 Rust 引擎
    ss_init();
    _isInitialized = YES;
    return YES;
}

- (BOOL)startWithConfig:(TFYSSConfig *)config error:(NSError **)error {
    if (!_isInitialized) {
        if (![self initializeEngine]) {
            if (error) {
                *error = [NSError errorWithDomain:TFYSSErrorDomain
                                           code:TFYSSErrorStartFailed
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize engine"}];
            }
            return NO;
        }
    }
    
    if (_isRunning) {
        [self stop];
    }
    
    self.currentConfig = config;
    
    // 创建 JSON 配置
    NSMutableDictionary *jsonConfig = [NSMutableDictionary dictionary];
    NSMutableDictionary *serverConfig = [NSMutableDictionary dictionary];
    
    // 设置服务器信息
    if (config.serverHost) {
        NSString *serverAddress = [NSString stringWithFormat:@"%@:%d", config.serverHost, (int)config.serverPort];
        [serverConfig setObject:serverAddress forKey:@"server"];
    }
    
    // 设置密码和加密方法
    if (config.password) {
        [serverConfig setObject:config.password forKey:@"password"];
    }
    
    if (config.method) {
        [serverConfig setObject:config.method forKey:@"method"];
    }
    
    // 设置本地地址和端口
    [jsonConfig setObject:@"127.0.0.1" forKey:@"local_address"];
    [jsonConfig setObject:@(config.localPort) forKey:@"local_port"];
    
    // 设置超时
    [jsonConfig setObject:@(config.timeout) forKey:@"timeout"];
    
    // 设置规则路由
    if (config.enableRule) {
        [jsonConfig setObject:@YES forKey:@"enable_rule"];
    }
    
    // 添加服务器配置
    [jsonConfig setObject:serverConfig forKey:@"server"];
    
    // 转换为 JSON 字符串
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonConfig options:0 error:&jsonError];
    if (jsonError) {
        if (error) {
            *error = [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorConfigInvalid
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to serialize config: %@", jsonError.localizedDescription]}];
        }
        return NO;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    // 启动 shadowsocks-rust
    int result = ss_start([jsonString UTF8String]);
    if (result != 0) {
        if (error) {
            const char *errorMsg = ss_get_last_error();
            NSString *errorString = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"Unknown error";
            *error = [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorStartFailed
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to start shadowsocks: %@", errorString]}];
        }
        return NO;
    }
    
    _isRunning = YES;
    
    // 重置流量统计
    _lastUploadTraffic = 0;
    _lastDownloadTraffic = 0;
    
    return YES;
}

- (BOOL)stop {
    if (!_isRunning) return YES;
    
    // 停止 shadowsocks-rust
    ss_stop();
    
    self.currentConfig = nil;
    _isRunning = NO;
    return YES;
}

- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download {
    if (!_isRunning) {
        if (upload) *upload = _lastUploadTraffic;
        if (download) *download = _lastDownloadTraffic;
        return;
    }
    
    uint64_t up = 0, down = 0;
    ss_get_traffic(&up, &down);
    
    _lastUploadTraffic = up;
    _lastDownloadTraffic = down;
    
    if (upload) *upload = up;
    if (download) *download = down;
}

- (void)updateTrafficStats {
    if (!_isRunning || !self.trafficCallback) {
        return;
    }
    
    uint64_t upload = 0, download = 0;
    [self getTrafficWithUpload:&upload download:&download];
    
    self.trafficCallback(upload, download);
}

- (void)setTrafficStatsCallback:(TFYSSTrafficStatsCallback)callback {
    self.trafficCallback = callback;
}

#pragma mark - Private Methods

- (NSString *)getVersion {
    const char *version = ss_get_version();
    return version ? @(version) : @"unknown";
}

#pragma mark - Rule-based Routing

- (BOOL)shouldProxyHost:(NSString *)host {
    if (!self.currentConfig.enableRule) {
        return YES;
    }
    
    TFYSSProxyService *proxyService = [TFYSSProxyService sharedInstance];
    return [proxyService shouldProxyHost:host];
}

- (BOOL)shouldProxyURL:(NSURL *)url {
    if (!self.currentConfig.enableRule) {
        return YES;
    }
    
    TFYSSProxyService *proxyService = [TFYSSProxyService sharedInstance];
    return [proxyService shouldProxyURL:url];
}

- (BOOL)shouldProxyIP:(NSString *)ip {
    if (!self.currentConfig.enableRule) {
        return YES;
    }
    
    TFYSSProxyService *proxyService = [TFYSSProxyService sharedInstance];
    return [proxyService shouldProxyIP:ip];
}

@end

#pragma mark - C Callbacks for Rust

// C回调函数，用于判断主机是否应该使用代理
BOOL TFYSSRustShouldProxyHost(const char *host) {
    if (host == NULL) {
        return YES;
    }
    
    NSString *hostString = [NSString stringWithUTF8String:host];
    return [[TFYSSProxyService sharedInstance] shouldProxyHost:hostString];
}

// C回调函数，用于判断IP是否应该使用代理
BOOL TFYSSRustShouldProxyIP(const char *ip) {
    if (ip == NULL) {
        return YES;
    }
    
    NSString *ipString = [NSString stringWithUTF8String:ip];
    return [[TFYSSProxyService sharedInstance] shouldProxyIP:ipString];
} 
