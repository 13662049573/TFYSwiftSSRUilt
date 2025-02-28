//
//  MMWormholeSession.h
//  TFYSwiftSSRKit
//
//  Created by 田风有 on 2025/2/26.
//

#ifndef MMWormholeSession_h
#define MMWormholeSession_h

#import <Foundation/Foundation.h>
#import "MMWormhole.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) || defined(__WATCH_OS_VERSION_MIN_REQUIRED)
#import <WatchConnectivity/WatchConnectivity.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface MMWormholeSession : MMWormhole

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) || defined(__WATCH_OS_VERSION_MIN_REQUIRED)
@property (nonatomic, strong, readonly) WCSession *session;
#endif

/**
 Returns the shared listening session instance.
 @return The shared instance of MMWormholeSession.
 */
+ (instancetype)sharedListeningSession;

- (instancetype)initWithApplicationGroupIdentifier:(nullable NSString *)identifier
                                 optionalDirectory:(nullable NSString *)directory
                                    transitingType:(MMWormholeTransitingType)transitingType NS_DESIGNATED_INITIALIZER;

/**
 Activates the session for listening to messages.
 This should be called after setting up all initial listeners.
 */
- (void)activateSessionListening;
- (void)deactivateSessionListening;

@end

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) || defined(__WATCH_OS_VERSION_MIN_REQUIRED)
@interface MMWormholeSession (WatchConnectivity) <WCSessionDelegate>
@end
#endif

NS_ASSUME_NONNULL_END

#endif /* MMWormholeSession_h */

