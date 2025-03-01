#import <Foundation/Foundation.h>
#import "TFYSSTypes.h"
#import "TFYSSConfig.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TFYCoreProtocol)
@protocol TFYSSCoreProtocol <NSObject>

@property (nonatomic, readonly) TFYSSCoreType type NS_SWIFT_NAME(coreType);
@property (nonatomic, readonly, copy) NSString *version;
@property (nonatomic, readonly) TFYSSCoreCapability capabilities;

// 初始化引擎
- (BOOL)initializeEngine NS_SWIFT_NAME(initialize());

// 启动代理服务
- (BOOL)startWithConfig:(TFYSSConfig *)config 
                 error:(NSError **)error NS_SWIFT_NAME(start(config:));

// 停止代理服务
- (BOOL)stop NS_SWIFT_NAME(stop());

// 获取流量统计
- (void)getTrafficWithUpload:(uint64_t *)upload 
                   download:(uint64_t *)download NS_SWIFT_NAME(getTraffic(upload:download:));

@end

NS_ASSUME_NONNULL_END 