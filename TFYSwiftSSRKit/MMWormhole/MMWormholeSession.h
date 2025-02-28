//
//  MMWormholeSession.h
//  TFYSwiftSSRKit
//
//  Created by 田风有 on 2025/2/26.
//

#import <Foundation/Foundation.h>
#import "MMWormhole.h"

#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif

#if TARGET_OS_IOS || TARGET_OS_WATCH
#import <WatchConnectivity/WatchConnectivity.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IOS || TARGET_OS_WATCH
@interface MMWormholeSession : MMWormhole <WCSessionDelegate>
#else
@interface MMWormholeSession : MMWormhole
#endif

/**
 Returns the shared listening session instance.
 @return The shared instance of MMWormholeSession.
 */
+ (instancetype)sharedListeningSession;

/**
 Activates the session for listening to messages.
 This should be called after setting up all initial listeners.
 */
- (void)activateSessionListening;

@end

NS_ASSUME_NONNULL_END

