#import <Foundation/Foundation.h>
#import "TFYSSTypes.h"
#import "TFYSSCoreProtocol.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TFYCoreFactory)
@interface TFYSSCoreFactory : NSObject

// 创建指定类型的核心实例
+ (nullable id<TFYSSCoreProtocol>)createCoreWithType:(TFYSSCoreType)type 
    NS_SWIFT_NAME(createCore(type:));

// 获取默认的核心类型
+ (TFYSSCoreType)defaultCoreType NS_SWIFT_NAME(defaultCore());

// 获取指定类型的核心能力
+ (TFYSSCoreCapability)getCapabilities:(TFYSSCoreType)type 
    NS_SWIFT_NAME(getCapabilities(type:));

@end

NS_ASSUME_NONNULL_END 