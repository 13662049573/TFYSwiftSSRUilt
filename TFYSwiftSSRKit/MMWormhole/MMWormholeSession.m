//
// MMWormholeSession.m
//
// Copyright (c) 2015 Mutual Mobile (http://www.mutualmobile.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MMWormholeSession.h"

#if TARGET_OS_IOS || TARGET_OS_WATCH
#import <WatchConnectivity/WatchConnectivity.h>
#endif

// Define the missing enum value
#ifndef MMWormholeTransitingTypeSessionUserInfo
#define MMWormholeTransitingTypeSessionUserInfo 5
#endif

@interface MMWormholeSession ()
#if TARGET_OS_IOS || TARGET_OS_WATCH
@property (nonatomic, strong) WCSession *session;
#endif
@property (nonatomic, strong) NSOperationQueue *messageQueue;
@property (nonatomic, strong) NSMutableDictionary *listenerBlocks;
@property (nonatomic, assign) MMWormholeTransitingType transitingType;
@end

@implementation MMWormholeSession

+ (instancetype)sharedListeningSession {
    static MMWormholeSession *sharedSession = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSession = [[MMWormholeSession alloc] initWithApplicationGroupIdentifier:nil
                                                                     optionalDirectory:nil
                                                                            transitingType:MMWormholeTransitingTypeSessionContext];
    });
    
    return sharedSession;
}

- (instancetype)initWithApplicationGroupIdentifier:(nullable NSString *)identifier
                                 optionalDirectory:(nullable NSString *)directory
                                    transitingType:(MMWormholeTransitingType)transitingType {
    if ((self = [super initWithApplicationGroupIdentifier:identifier
                                        optionalDirectory:directory
                                           transitingType:transitingType])) {
#if TARGET_OS_IOS || TARGET_OS_WATCH
        // Setup the default session
        _session = [WCSession defaultSession];
        _session.delegate = self;
        [_session activateSession];
        
        // Initialize message queue and listener blocks
        _messageQueue = [[NSOperationQueue alloc] init];
        _listenerBlocks = [NSMutableDictionary dictionary];
        _transitingType = transitingType;
#endif
    }
    
    return self;
}

- (void)activateSessionListening {
    // Implementation of the method declared in the header
    // This method is called after all initial listeners are set up
#if TARGET_OS_IOS || TARGET_OS_WATCH
    if (_session) {
        // Activate the session if it's not already activated
        if (_session.activationState != WCSessionActivationStateActivated) {
            [_session activateSession];
        }
        
        // Process any pending application context
        if (_session.receivedApplicationContext.count > 0) {
            [self session:_session didReceiveApplicationContext:_session.receivedApplicationContext];
        }
        
        // Check for any pending messages that might have been received before listeners were set up
        if (_session.hasContentPending) {
            NSLog(@"WCSession has pending content. Listeners will receive it when available.");
        }
    }
#endif
}

#pragma mark - WCSessionDelegate Methods

#if TARGET_OS_IOS || TARGET_OS_WATCH
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message {
    for (NSString *identifier in message) {
        NSData *data = message[identifier];
        
        id messageObject = nil;
        if (@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)) {
            NSError *error = nil;
            messageObject = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
            if (error) {
                NSLog(@"Error unarchiving message object: %@", error);
                continue;
            }
        } else {
            messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        
        [self passMessageObject:messageObject identifier:identifier];
    }
}

- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo {
    for (NSString *identifier in userInfo) {
        NSData *data = userInfo[identifier];
        
        id messageObject = nil;
        if (@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)) {
            NSError *error = nil;
            messageObject = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
            if (error) {
                NSLog(@"Error unarchiving message object: %@", error);
                continue;
            }
        } else {
            messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        
        [self passMessageObject:messageObject identifier:identifier];
    }
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *,id> *)applicationContext {
    for (NSString *identifier in applicationContext) {
        NSData *data = applicationContext[identifier];
        
        id messageObject = nil;
        if (@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)) {
            NSError *error = nil;
            messageObject = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
            if (error) {
                NSLog(@"Error unarchiving message object: %@", error);
                continue;
            }
        } else {
            messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        
        [self passMessageObject:messageObject identifier:identifier];
    }
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
    if (error) {
        NSLog(@"WCSession activation failed with error: %@", error);
    }
}

#if TARGET_OS_IOS
- (void)sessionDidBecomeInactive:(WCSession *)session {
    // Handle session becoming inactive
}

- (void)sessionDidDeactivate:(WCSession *)session {
    // Handle session deactivation
    // Typically you would reactivate the session
    [WCSession.defaultSession activateSession];
}
#endif
#endif

- (void)notifyListenerForMessageWithIdentifier:(NSString *)identifier {
    // Get the message object from the parent class
    id messageObject = [self messageWithIdentifier:identifier];
    
    if (messageObject) {
        [self.messageQueue addOperationWithBlock:^{
            [self.listenerBlocks enumerateKeysAndObjectsUsingBlock:^(NSString *blockIdentifier, id listenerBlock, BOOL *stop) {
                if ([blockIdentifier isEqualToString:identifier]) {
                    ((void (^)(id))listenerBlock)(messageObject);
                }
            }];
        }];
    }
}

- (void)passMessageObject:(id)messageObject identifier:(NSString *)identifier {
    if (messageObject && identifier) {
        // First, let the parent class handle the message passing
        [super passMessageObject:messageObject identifier:identifier];
        
        // Then directly notify our listeners with the message object
        // (No need to call notifyListenerForMessageWithIdentifier: as it would get the message again)
        [self.messageQueue addOperationWithBlock:^{
            [self.listenerBlocks enumerateKeysAndObjectsUsingBlock:^(NSString *blockIdentifier, id listenerBlock, BOOL *stop) {
                if ([blockIdentifier isEqualToString:identifier]) {
                    ((void (^)(id))listenerBlock)(messageObject);
                }
            }];
        }];
    }
}

- (void)sendMessageWithIdentifier:(NSString *)identifier messageObject:(id<NSCoding>)messageObject {
#if TARGET_OS_IOS || TARGET_OS_WATCH
    if (messageObject) {
        NSData *data = nil;
        if (@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)) {
            NSError *error = nil;
            data = [NSKeyedArchiver archivedDataWithRootObject:messageObject requiringSecureCoding:NO error:&error];
            if (error) {
                NSLog(@"Error archiving message object: %@", error);
                return;
            }
        } else {
            data = [NSKeyedArchiver archivedDataWithRootObject:messageObject];
        }
        
        if (data) {
            switch (self.transitingType) {
                case MMWormholeTransitingTypeSessionContext:
                    [self.session updateApplicationContext:@{identifier : data} error:nil];
                    break;
                case MMWormholeTransitingTypeSessionMessage:
                    [self.session sendMessage:@{identifier : data} replyHandler:nil errorHandler:nil];
                    break;
                case MMWormholeTransitingTypeSessionUserInfo:
                    [self.session transferUserInfo:@{identifier : data}];
                    break;
                default:
                    [super passMessageObject:messageObject identifier:identifier];
                    break;
            }
        }
    }
#else
    [super passMessageObject:messageObject identifier:identifier];
#endif
}

- (void)listenForMessageWithIdentifier:(NSString *)identifier listener:(void (^)(id messageObject))listener {
    // First, let the parent class register the listener
    [super listenForMessageWithIdentifier:identifier listener:listener];
    
    // Then store the listener in our own dictionary for direct notifications
    if (identifier != nil && listener != nil) {
        [self.listenerBlocks setValue:[listener copy] forKey:identifier];
    }
}

- (void)stopListeningForMessageWithIdentifier:(NSString *)identifier {
    // First, let the parent class unregister the listener
    [super stopListeningForMessageWithIdentifier:identifier];
    
    // Then remove the listener from our own dictionary
    if (identifier != nil) {
        [self.listenerBlocks removeObjectForKey:identifier];
    }
}

@end

