#import <Foundation/Foundation.h>
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TFYNetworkStatus) {
    TFYNetworkStatusUnknown,
    TFYNetworkStatusNotReachable,
    TFYNetworkStatusReachableViaWiFi,
    TFYNetworkStatusReachableViaCellular
};

@protocol TFYNetworkMonitorDelegate <NSObject>

- (void)networkStatusDidChange:(TFYNetworkStatus)status;

@end

@interface TFYNetworkMonitor : NSObject

@property (nonatomic, readonly) TFYNetworkStatus currentStatus;
@property (nonatomic, weak) id<TFYNetworkMonitorDelegate> delegate;

+ (instancetype)sharedMonitor;

- (void)startMonitoring;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END 