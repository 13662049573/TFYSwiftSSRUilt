#import "TFYSSRustCore.h"
#import "TFYSSError.h"
#import "../shadowsocks-rust/include/ss.h"

@interface TFYSSRustCore () {
    BOOL _isInitialized;
    BOOL _isRunning;
}

@property (nonatomic, strong) TFYSSConfig *currentConfig;

@end

@implementation TFYSSRustCore

@synthesize type = _type;
@synthesize version = _version;
@synthesize capabilities = _capabilities;

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = TFYSSCoreTypeRust;
        _version = [self getVersion];
        _capabilities = TFYSSCoreCapabilityTCP | TFYSSCoreCapabilityUDP | TFYSSCoreCapabilityFastOpen;
        _isInitialized = NO;
        _isRunning = NO;
    }
    return self;
}

- (BOOL)initializeEngine {
    if (_isInitialized) return YES;
    
    ss_init();
    _isInitialized = YES;
    return YES;
}

- (BOOL)startWithConfig:(TFYSSConfig *)config error:(NSError **)error {
    if (!_isInitialized) {
        if (error) {
            *error = [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorStartFailed
                                   userInfo:@{NSLocalizedDescriptionKey: @"Engine not initialized"}];
        }
        return NO;
    }
    
    if (_isRunning) {
        [self stop];
    }
    
    // 将配置转换为JSON字符串
    NSDictionary *configDict = @{
        @"server": config.serverHost ?: @"",
        @"server_port": @(config.serverPort),
        @"local_address": config.localAddress ?: @"127.0.0.1",
        @"local_port": @(config.localPort),
        @"method": config.method ?: @"",
        @"password": config.password ?: @"",
        @"timeout": @((int)config.timeout)
    };
    
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:configDict options:0 error:&jsonError];
    if (!jsonData) {
        if (error) {
            *error = [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorStartFailed
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to serialize config to JSON",
                                       NSUnderlyingErrorKey: jsonError
                                   }];
        }
        return NO;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    // 启动服务
    if (!ss_start([jsonString UTF8String])) {
        if (error) {
            NSString *lastError = [NSString stringWithUTF8String:ss_get_last_error()];
            *error = [NSError errorWithDomain:TFYSSErrorDomain
                                       code:TFYSSErrorStartFailed
                                   userInfo:@{NSLocalizedDescriptionKey: lastError}];
        }
        return NO;
    }
    
    _currentConfig = config;
    _isRunning = YES;
    return YES;
}

- (BOOL)stop {
    if (!_isRunning) return YES;
    
    ss_stop();
    _isRunning = NO;
    _currentConfig = nil;
    return YES;
}

- (void)getTrafficWithUpload:(uint64_t *)upload download:(uint64_t *)download {
    if (!_isRunning) {
        if (upload) *upload = 0;
        if (download) *download = 0;
        return;
    }
    
    ss_get_traffic(upload, download);
}

#pragma mark - Private Methods

- (NSString *)getVersion {
    const char *version = ss_get_version();
    return version ? @(version) : @"unknown";
}

@end 