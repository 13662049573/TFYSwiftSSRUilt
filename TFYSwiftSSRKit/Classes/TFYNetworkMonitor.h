#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TFYNetworkStatus) {
    TFYNetworkStatusNotReachable = 0,
    TFYNetworkStatusReachableViaWiFi,
    TFYNetworkStatusReachableViaCellular
};

@protocol TFYNetworkMonitorDelegate <NSObject>

- (void)networkStatusDidChange:(TFYNetworkStatus)status;

@optional
- (void)networkDidBecomeReachable;
- (void)networkDidBecomeUnreachable;

@end

@interface TFYNetworkMonitor : NSObject

@property (nonatomic, weak) id<TFYNetworkMonitorDelegate> delegate;
@property (nonatomic, assign, readonly) TFYNetworkStatus currentStatus;
@property (nonatomic, assign, readonly) BOOL isReachable;
@property (nonatomic, assign, readonly) BOOL isReachableViaWiFi;
@property (nonatomic, assign, readonly) BOOL isReachableViaCellular;

+ (instancetype)sharedMonitor;

- (void)startMonitoring;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END 