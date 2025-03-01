#import "TFYSSCoreFactory.h"
#import "TFYSSRustCore.h"
#import "TFYSSLibevCore.h"

@implementation TFYSSCoreFactory

+ (id<TFYSSCoreProtocol>)createCoreWithType:(TFYSSCoreType)type {
    switch (type) {
        case TFYSSCoreTypeRust:
            return [[TFYSSRustCore alloc] init];
        case TFYSSCoreTypeC:
            return [[TFYSSLibevCore alloc] init];
        default:
            return nil;
    }
}

+ (TFYSSCoreType)defaultCoreType {
#if TARGET_OS_OSX
    return TFYSSCoreTypeRust;  // macOS 优先使用 Rust 实现
#else
    return TFYSSCoreTypeC;     // iOS 优先使用 C 实现
#endif
}

+ (TFYSSCoreCapability)getCapabilities:(TFYSSCoreType)type {
    switch (type) {
        case TFYSSCoreTypeRust:
            return TFYSSCoreCapabilityTCP | TFYSSCoreCapabilityUDP | TFYSSCoreCapabilityFastOpen;
            
        case TFYSSCoreTypeC:
            return TFYSSCoreCapabilityTCP | TFYSSCoreCapabilityUDP | TFYSSCoreCapabilityFastOpen | 
                   TFYSSCoreCapabilityNAT | TFYSSCoreCapabilityHTTP;
            
        default:
            return TFYSSCoreCapabilityNone;
    }
}

@end