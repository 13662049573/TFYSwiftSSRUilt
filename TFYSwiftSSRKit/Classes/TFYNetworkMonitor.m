#import "TFYNetworkMonitor.h"

@interface TFYNetworkMonitor ()

@property (nonatomic, strong) nw_path_monitor_t monitor;
@property (nonatomic, strong) dispatch_queue_t monitorQueue;
@property (nonatomic, assign) TFYNetworkStatus status;

@end

@implementation TFYNetworkMonitor

+ (instancetype)sharedMonitor {
    static TFYNetworkMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = TFYNetworkStatusUnknown;
        _monitorQueue = dispatch_queue_create("com.tfy.shadowsocks.network_monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
}

#pragma mark - Public Methods

- (void)startMonitoring {
    if (self.monitor) {
        return;
    }
    
    self.monitor = nw_path_monitor_create();
    nw_path_monitor_set_queue(self.monitor, self.monitorQueue);
    
    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_update_handler(self.monitor, ^(nw_path_t _Nonnull path) {
        TFYNetworkStatus newStatus = TFYNetworkStatusUnknown;
        
        if (nw_path_get_status(path) == nw_path_status_satisfied) {
            if (nw_path_uses_interface_type(path, nw_interface_type_wifi)) {
                newStatus = TFYNetworkStatusReachableViaWiFi;
            } else if (nw_path_uses_interface_type(path, nw_interface_type_cellular)) {
                newStatus = TFYNetworkStatusReachableViaCellular;
            }
        } else {
            newStatus = TFYNetworkStatusNotReachable;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.status != newStatus) {
                weakSelf.status = newStatus;
                if ([weakSelf.delegate respondsToSelector:@selector(networkStatusDidChange:)]) {
                    [weakSelf.delegate networkStatusDidChange:newStatus];
                }
            }
        });
    });
    
    nw_path_monitor_start(self.monitor);
}

- (void)stopMonitoring {
    if (self.monitor) {
        nw_path_monitor_cancel(self.monitor);
        self.monitor = nil;
    }
}

#pragma mark - Properties

- (TFYNetworkStatus)currentStatus {
    return self.status;
}

@end 