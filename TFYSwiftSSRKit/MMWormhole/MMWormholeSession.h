//
//  MMWormholeSession.h
//  TFYSwiftSSRKit
//
//  Created by 田风有 on 2025/2/26.
//

#import <Foundation/Foundation.h>
#import "MMWormhole.h"
#import <WatchConnectivity/WatchConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This class extends MMWormhole to provide WatchConnectivity support.
 It manages the WCSession for communication between iOS app and WatchKit extension.
 */
@interface MMWormholeSession : MMWormhole

@property (nonatomic, strong, readonly) WCSession *session;

/**
 Returns the shared listening session instance.
 @return The shared instance of MMWormholeSession.
 */
+ (instancetype)sharedListeningSession;

/**
 Designated initializer that creates a new wormhole with an application group identifier,
 optional directory, and transiting type.
 
 @param identifier An application group identifier
 @param directory An optional directory to read/write messages
 @param transitingType The type of message transiting to use
 */
- (instancetype)initWithApplicationGroupIdentifier:(nullable NSString *)identifier
                                 optionalDirectory:(nullable NSString *)directory
                                    transitingType:(MMWormholeTransitingType)transitingType;

/**
 Activates the session for listening to messages.
 This should be called after setting up all initial listeners.
 */
- (void)activateSessionListening;

/**
 Deactivates the session and stops listening for messages.
 */
- (void)deactivateSessionListening;

@end

@interface MMWormholeSession (WatchConnectivity) <WCSessionDelegate>
@end


NS_ASSUME_NONNULL_END


