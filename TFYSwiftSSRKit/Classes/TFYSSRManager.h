#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFYSSRConfiguration : NSObject

@property (nonatomic, copy) NSString *remoteHost;
@property (nonatomic, assign) NSInteger remotePort;
@property (nonatomic, copy) NSString *localAddress;
@property (nonatomic, assign) NSInteger localPort;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, assign) NSInteger timeout;

+ (instancetype)configurationWithHost:(NSString *)host
                              port:(NSInteger)port
                         password:(NSString *)password
                          method:(NSString *)method;

@end

@interface TFYSSRManager : NSObject

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, strong, readonly) TFYSSRConfiguration *currentConfig;

+ (instancetype)sharedManager;

- (BOOL)startWithConfiguration:(TFYSSRConfiguration *)config;
- (void)stop;

// 获取支持的加密方法列表
+ (NSArray<NSString *> *)supportedMethods;

// 测试服务器延迟
- (void)testServerDelay:(NSString *)host 
                  port:(NSInteger)port 
             complete:(void(^)(NSTimeInterval delay, NSError * _Nullable error))complete;

@end

NS_ASSUME_NONNULL_END 