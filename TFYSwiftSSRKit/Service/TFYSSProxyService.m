#import "TFYSSProxyService.h"
#import "TFYSSCoreFactory.h"
#import "TFYSSError.h"

@interface TFYSSProxyService () {
    dispatch_queue_t _queue;
    dispatch_source_t _trafficTimer;
}

@property (nonatomic, strong) id<TFYSSCoreProtocol> currentCore;
@property (nonatomic, assign) TFYSSProxyState state;
@property (nonatomic, assign) uint64_t uploadTraffic;
@property (nonatomic, assign) uint64_t downloadTraffic;
@property (nonatomic, strong) TFYSSConfig *currentConfig;

@end

@implementation TFYSSProxyService

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
        _queue = dispatch_queue_create("com.tfyswiftssrkit.proxy.queue", DISPATCH_QUEUE_SERIAL);
        _state = TFYSSProxyStateStopped;
        [self setupTrafficTimer];
    }
    return self;
}

- (void)dealloc {
    if (_trafficTimer) {
        dispatch_source_cancel(_trafficTimer);
        _trafficTimer = nil;
    }
}

#pragma mark - Public Methods

- (void)startWithConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        // 验证配置
        NSError *error = nil;
        if (![config validate:&error]) {
            if (completion) completion(error);
            return;
        }
        
        // 如果已经在运行，先停止
        if (self.state != TFYSSProxyStateStopped) {
            [self stopWithCompletion:nil];
        }
        
        // 更新状态
        [self updateState:TFYSSProxyStateStarting];
        
        // 创建核心实例
        self.currentCore = [TFYSSCoreFactory createCoreWithType:config.preferredCoreType];
        if (!self.currentCore) {
            NSError *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorStartFailed, @"Failed to create core instance");
            [self handleStartFailureWithError:error completion:completion];
            return;
        }
        
        // 初始化引擎
        if (![self.currentCore initializeEngine]) {
            NSError *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorStartFailed, @"Failed to initialize engine");
            [self handleStartFailureWithError:error completion:completion];
            return;
        }
        
        // 启动代理
        NSError *startError = nil;
        if (![self.currentCore startWithConfig:config error:&startError]) {
            [self handleStartFailureWithError:startError completion:completion];
            return;
        }
        
        // 更新状态和配置
        self.currentConfig = config;
        [self updateState:TFYSSProxyStateRunning];
        
        if (completion) completion(nil);
    });
}

- (void)stopWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        if (self.state == TFYSSProxyStateStopped) {
            if (completion) completion(nil);
            return;
        }
        
        [self updateState:TFYSSProxyStateStopping];
        
        if (self.currentCore) {
            [self.currentCore stop];
            self.currentCore = nil;
        }
        
        self.currentConfig = nil;
        [self updateState:TFYSSProxyStateStopped];
        
        if (completion) completion(nil);
    });
}

- (void)updateConfig:(TFYSSConfig *)config completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(_queue, ^{
        // 验证配置
        NSError *error = nil;
        if (![config validate:&error]) {
            if (completion) completion(error);
            return;
        }
        
        // 如果代理正在运行，重启代理
        if (self.state == TFYSSProxyStateRunning) {
            [self stopWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    if (completion) completion(error);
                    return;
                }
                [self startWithConfig:config completion:completion];
            }];
        } else {
            self.currentConfig = config;
            if (completion) completion(nil);
        }
    });
}

- (void)resetTrafficStats {
    dispatch_async(_queue, ^{
        self.uploadTraffic = 0;
        self.downloadTraffic = 0;
        [self notifyTrafficUpdate];
    });
}

#pragma mark - Private Methods

- (void)setupTrafficTimer {
    _trafficTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_trafficTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_trafficTimer, ^{
        [weakSelf updateTrafficStats];
    });
    
    dispatch_resume(_trafficTimer);
}

- (void)updateTrafficStats {
    if (self.state != TFYSSProxyStateRunning || !self.currentCore) return;
    
    uint64_t upload = 0, download = 0;
    [self.currentCore getTrafficWithUpload:&upload download:&download];
    
    if (upload != self.uploadTraffic || download != self.downloadTraffic) {
        self.uploadTraffic = upload;
        self.downloadTraffic = download;
        [self notifyTrafficUpdate];
    }
}

- (void)updateState:(TFYSSProxyState)newState {
    if (_state == newState) return;
    
    _state = newState;
    [self notifyStateChange];
}

- (void)handleStartFailureWithError:(NSError *)error completion:(void (^)(NSError * _Nullable))completion {
    self.currentCore = nil;
    self.currentConfig = nil;
    [self updateState:TFYSSProxyStateStopped];
    
    [self notifyError:error];
    
    if (completion) completion(error);
}

#pragma mark - Delegate Notifications

- (void)notifyStateChange {
    if (!self.delegate) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(proxyService:didChangeState:)]) {
            [self.delegate proxyService:self didChangeState:self.state];
        }
    });
}

- (void)notifyTrafficUpdate {
    if (!self.delegate) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(proxyService:didUpdateTraffic:download:)]) {
            [self.delegate proxyService:self didUpdateTraffic:self.uploadTraffic download:self.downloadTraffic];
        }
    });
}

- (void)notifyError:(NSError *)error {
    if (!self.delegate) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(proxyService:didEncounterError:)]) {
            [self.delegate proxyService:self didEncounterError:error];
        }
    });
}

@end 