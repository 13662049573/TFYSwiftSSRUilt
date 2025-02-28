//
//  MMWormholeSession.h
//  TFYSwiftSSRKit
//
//  Created by 田风有 on 2025/2/26.
//

#import <Foundation/Foundation.h>
#import "MMWormhole.h"

#if defined(__IPHONE_15_0)
#import <WatchConnectivity/WatchConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMWormholeSession : MMWormhole <WCSessionDelegate>

@property (nonatomic, strong, readonly) WCSession *session;

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

NS_ASSUME_NONNULL_END

#endif

