#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFYConfigurationManager : NSObject

@property (nonatomic, readonly) NSDictionary *currentConfiguration;
@property (nonatomic, readonly) NSArray<NSDictionary *> *savedConfigurations;

+ (instancetype)sharedManager;

- (void)loadConfigurationWithCompletion:(void(^)(NSDictionary * _Nullable configuration, NSError * _Nullable error))completion;
- (void)saveConfiguration:(NSDictionary *)configuration 
               completion:(void(^)(NSError * _Nullable error))completion;
- (void)removeConfiguration:(NSDictionary *)configuration 
                completion:(void(^)(NSError * _Nullable error))completion;
- (void)updateConfiguration:(NSDictionary *)configuration 
                completion:(void(^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 