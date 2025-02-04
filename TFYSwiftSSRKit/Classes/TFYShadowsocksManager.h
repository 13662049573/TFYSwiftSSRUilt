#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TFYShadowsocksState) {
    TFYShadowsocksStateIdle,
    TFYShadowsocksStateStarting,
    TFYShadowsocksStateRunning,
    TFYShadowsocksStateStopping,
    TFYShadowsocksStateError
};

@interface TFYShadowsocksManager : NSObject

@property (nonatomic, readonly) TFYShadowsocksState state;
@property (nonatomic, readonly) NSError *lastError;
@property (nonatomic, readonly) NSUInteger localPort;
@property (nonatomic, readonly) NSString *serverAddress;
@property (nonatomic, readonly) NSUInteger serverPort;

+ (instancetype)sharedManager;

- (void)startWithConfiguration:(NSDictionary *)configuration 
                  completion:(void(^)(NSError * _Nullable error))completion;
- (void)stopWithCompletion:(void(^)(NSError * _Nullable error))completion;
- (void)updateConfiguration:(NSDictionary *)configuration 
                completion:(void(^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 