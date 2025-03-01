#import "TFYSSProxyService.h"
#import "TFYSSLibevCore.h"
#import "TFYSSRustCore.h"
#import "TFYSSCoreProtocol.h"
#import "TFYSSRuleManager.h"

@interface TFYSSProxyService ()

@property (nonatomic, readwrite) TFYSSProxyState state;
@property (nonatomic, readwrite, strong) TFYSSConfig *currentConfig;
@property (nonatomic, readwrite, strong) TFYSSRuleManager *ruleManager;
@property (nonatomic, strong) id<TFYSSCoreProtocol> proxyCore;
@property (nonatomic, assign) uint64_t uploadTraffic;
@property (nonatomic, assign) uint64_t downloadTraffic;
@property (nonatomic, strong) NSTimer *trafficTimer;

@end

@implementation TFYSSProxyService

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static TFYSSProxyService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = TFYSSProxyStateStopped;
        _uploadTraffic = 0;
        _downloadTraffic = 0;
        _ruleManager = [TFYSSRuleManager sharedManager];
    }
    return self;
}

- (void)dealloc {
    [self stopTrafficTimer];
}

#pragma mark - Public Methods

- (void)startWithConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    if (self.state == TFYSSProxyStateStarting || self.state == TFYSSProxyStateRunning) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Proxy service is already running"}];
            completion(error);
        }
        return;
    }
    
    self.state = TFYSSProxyStateStarting;
    self.currentConfig = config;
    
    // 创建代理核心
    if (config.useRust) {
        self.proxyCore = [[TFYSSRustCore alloc] init];
    } else {
        self.proxyCore = [[TFYSSLibevCore alloc] init];
    }
    
    // 设置流量统计回调
    __weak typeof(self) weakSelf = self;
    [self.proxyCore setTrafficStatsCallback:^(uint64_t uploadBytes, uint64_t downloadBytes) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.uploadTraffic = uploadBytes;
            strongSelf.downloadTraffic = downloadBytes;
            
            if ([strongSelf.delegate respondsToSelector:@selector(proxyService:didUpdateTraffic:download:)]) {
                [strongSelf.delegate proxyService:strongSelf didUpdateTraffic:uploadBytes download:downloadBytes];
            }
        }
    }];
    
    // 启动代理
    NSError *error = nil;
    BOOL success = [self.proxyCore startWithConfig:config error:&error];
    
    if (success) {
        self.state = TFYSSProxyStateRunning;
        [self startTrafficTimer];
        
        if ([self.delegate respondsToSelector:@selector(proxyService:didChangeState:)]) {
            [self.delegate proxyService:self didChangeState:self.state];
        }
        
        if (completion) {
            completion(nil);
        }
    } else {
        self.state = TFYSSProxyStateStopped;
        
        if ([self.delegate respondsToSelector:@selector(proxyService:didEncounterError:)]) {
            [self.delegate proxyService:self didEncounterError:error];
        }
        
        if (completion) {
            completion(error);
        }
    }
}

- (void)stopWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.state == TFYSSProxyStateStopped || self.state == TFYSSProxyStateStopping) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks" code:101 userInfo:@{NSLocalizedDescriptionKey: @"Proxy service is not running"}];
            completion(error);
        }
        return;
    }
    
    self.state = TFYSSProxyStateStopping;
    
    [self stopTrafficTimer];
    
    // 停止代理
    [self.proxyCore stop];
    
    self.state = TFYSSProxyStateStopped;
    
    if ([self.delegate respondsToSelector:@selector(proxyService:didChangeState:)]) {
        [self.delegate proxyService:self didChangeState:self.state];
    }
    
    if (completion) {
        completion(nil);
    }
}

- (void)updateConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    // 如果代理正在运行，先停止再重启
    if (self.state == TFYSSProxyStateRunning || self.state == TFYSSProxyStateStarting) {
        __weak typeof(self) weakSelf = self;
        [self stopWithCompletion:^(NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf startWithConfig:config completion:completion];
            }
        }];
    } else {
        // 如果代理未运行，直接更新配置
        self.currentConfig = config;
        if (completion) {
            completion(nil);
        }
    }
}

- (void)resetTrafficStats {
    self.uploadTraffic = 0;
    self.downloadTraffic = 0;
    
    if ([self.delegate respondsToSelector:@selector(proxyService:didUpdateTraffic:download:)]) {
        [self.delegate proxyService:self didUpdateTraffic:self.uploadTraffic download:self.downloadTraffic];
    }
}

#pragma mark - Rule-based Routing

- (void)enableRuleRouting:(BOOL)enable completion:(void (^)(NSError * _Nullable))completion {
    if (!self.currentConfig) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks" code:102 userInfo:@{NSLocalizedDescriptionKey: @"No active configuration"}];
            completion(error);
            return;
        }
    }
    
    // 更新配置
    TFYSSConfig *updatedConfig = [self.currentConfig copy];
    updatedConfig.enableRule = enable;
    
    // 如果启用规则但没有设置活动规则集，使用默认规则集
    if (enable && !updatedConfig.activeRuleSetName) {
        TFYSSRuleSet *defaultRuleSet = [self.ruleManager.ruleSets firstObject];
        if (defaultRuleSet) {
            updatedConfig.activeRuleSetName = defaultRuleSet.name;
        }
    }
    
    [self updateConfig:updatedConfig completion:completion];
}

- (void)setActiveRuleSet:(NSString *)ruleSetName completion:(void (^)(NSError * _Nullable))completion {
    if (!self.currentConfig) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks" code:102 userInfo:@{NSLocalizedDescriptionKey: @"No active configuration"}];
            completion(error);
            return;
        }
    }
    
    // 验证规则集是否存在
    if (ruleSetName && ![self.ruleManager ruleSetWithName:ruleSetName]) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks" code:103 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Rule set '%@' not found", ruleSetName]}];
            completion(error);
            return;
        }
    }
    
    // 更新配置
    TFYSSConfig *updatedConfig = [self.currentConfig copy];
    updatedConfig.activeRuleSetName = ruleSetName;
    
    // 如果设置了规则集但规则路由未启用，自动启用
    if (ruleSetName && !updatedConfig.enableRule) {
        updatedConfig.enableRule = YES;
    }
    
    [self updateConfig:updatedConfig completion:completion];
}

- (BOOL)shouldProxyHost:(NSString *)host {
    if (!self.currentConfig.enableRule || !self.currentConfig.activeRuleSetName) {
        // 如果规则路由未启用或没有活动规则集，默认使用代理
        return YES;
    }
    
    TFYSSRuleSet *activeRuleSet = [self.ruleManager ruleSetWithName:self.currentConfig.activeRuleSetName];
    if (!activeRuleSet) {
        // 如果找不到活动规则集，默认使用代理
        return YES;
    }
    
    TFYSSRuleMatchResult result = [activeRuleSet matchHost:host];
    
    // 通知代理规则匹配结果
    if ([self.delegate respondsToSelector:@selector(proxyService:didMatchHost:result:ruleSet:)]) {
        [self.delegate proxyService:self didMatchHost:host result:result ruleSet:activeRuleSet];
    }
    
    // 根据规则集类型和匹配结果决定是否使用代理
    switch (activeRuleSet.type) {
        case TFYSSRuleSetTypeBlacklist:
            // 黑名单模式：匹配则使用代理，不匹配则直连
            return (result == TFYSSRuleMatchResultProxy);
            
        case TFYSSRuleSetTypeWhitelist:
            // 白名单模式：匹配则直连，不匹配则使用代理
            return (result == TFYSSRuleMatchResultDirect) ? NO : YES;
            
        case TFYSSRuleSetTypeCustom:
            // 自定义模式：根据规则的代理标志决定
            return (result == TFYSSRuleMatchResultProxy);
            
        default:
            return YES;
    }
}

- (BOOL)shouldProxyURL:(NSURL *)url {
    if (!url) {
        return YES;
    }
    
    NSString *host = url.host;
    if (!host) {
        return YES;
    }
    
    return [self shouldProxyHost:host];
}

- (BOOL)shouldProxyIP:(NSString *)ip {
    if (!self.currentConfig.enableRule || !self.currentConfig.activeRuleSetName) {
        // 如果规则路由未启用或没有活动规则集，默认使用代理
        return YES;
    }
    
    TFYSSRuleSet *activeRuleSet = [self.ruleManager ruleSetWithName:self.currentConfig.activeRuleSetName];
    if (!activeRuleSet) {
        // 如果找不到活动规则集，默认使用代理
        return YES;
    }
    
    TFYSSRuleMatchResult result = [activeRuleSet matchIP:ip];
    
    // 通知代理规则匹配结果
    if ([self.delegate respondsToSelector:@selector(proxyService:didMatchHost:result:ruleSet:)]) {
        [self.delegate proxyService:self didMatchHost:ip result:result ruleSet:activeRuleSet];
    }
    
    // 根据规则集类型和匹配结果决定是否使用代理
    switch (activeRuleSet.type) {
        case TFYSSRuleSetTypeBlacklist:
            return (result == TFYSSRuleMatchResultProxy);
            
        case TFYSSRuleSetTypeWhitelist:
            return (result == TFYSSRuleMatchResultDirect) ? NO : YES;
            
        case TFYSSRuleSetTypeCustom:
            return (result == TFYSSRuleMatchResultProxy);
            
        default:
            return YES;
    }
}

#pragma mark - Private Methods

- (void)startTrafficTimer {
    [self stopTrafficTimer];
    
    self.trafficTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTrafficStats) userInfo:nil repeats:YES];
}

- (void)stopTrafficTimer {
    if (self.trafficTimer) {
        [self.trafficTimer invalidate];
        self.trafficTimer = nil;
    }
}

- (void)updateTrafficStats {
    if (self.state == TFYSSProxyStateRunning && self.proxyCore) {
        [self.proxyCore updateTrafficStats];
    }
}

@end 