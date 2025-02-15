#import "TFYNetworkMonitor.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>
#import <CoreFoundation/CoreFoundation.h>

@interface TFYNetworkMonitor()

@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, assign) TFYNetworkStatus currentStatus;
@property (nonatomic, strong) dispatch_queue_t reachabilityQueue;

@end

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    TFYNetworkMonitor *monitor = (__bridge TFYNetworkMonitor *)info;
    [monitor reachabilityChanged:flags];
}

@implementation TFYNetworkMonitor

+ (instancetype)sharedMonitor {
    static TFYNetworkMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TFYNetworkMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reachabilityQueue = dispatch_queue_create("com.tfy.network.reachability", DISPATCH_QUEUE_SERIAL);
        [self setupReachability];
    }
    return self;
}

- (void)setupReachability {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    self.reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    
    if (self.reachabilityRef != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(self.reachabilityRef, ReachabilityCallback, &context)) {
            if (!SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, self.reachabilityQueue)) {
                SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
            }
        }
    }
}

- (void)startMonitoring {
    dispatch_async(self.reachabilityQueue, ^{
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
            [self reachabilityChanged:flags];
        }
    });
}

- (void)stopMonitoring {
    if (self.reachabilityRef != NULL) {
        SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, NULL);
    }
}

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags {
    TFYNetworkStatus newStatus = [self networkStatusForFlags:flags];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL wasReachable = self.isReachable;
        self.currentStatus = newStatus;
        BOOL isReachable = self.isReachable;
        
        if ([self.delegate respondsToSelector:@selector(networkStatusDidChange:)]) {
            [self.delegate networkStatusDidChange:newStatus];
        }
        
        if (wasReachable != isReachable) {
            if (isReachable) {
                if ([self.delegate respondsToSelector:@selector(networkDidBecomeReachable)]) {
                    [self.delegate networkDidBecomeReachable];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(networkDidBecomeUnreachable)]) {
                    [self.delegate networkDidBecomeUnreachable];
                }
            }
        }
    });
}

- (TFYNetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags {
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        return TFYNetworkStatusNotReachable;
    }
    
    TFYNetworkStatus status = TFYNetworkStatusNotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        status = TFYNetworkStatusReachableViaWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            status = TFYNetworkStatusReachableViaWiFi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        status = TFYNetworkStatusReachableViaCellular;
    }
    
    return status;
}

- (BOOL)isReachable {
    return self.currentStatus != TFYNetworkStatusNotReachable;
}

- (BOOL)isReachableViaWiFi {
    return self.currentStatus == TFYNetworkStatusReachableViaWiFi;
}

- (BOOL)isReachableViaCellular {
    return self.currentStatus == TFYNetworkStatusReachableViaCellular;
}

- (void)dealloc {
    [self stopMonitoring];
    if (self.reachabilityRef != NULL) {
        CFRelease(self.reachabilityRef);
    }
}

@end 