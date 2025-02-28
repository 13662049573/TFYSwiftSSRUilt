//
// MMWormholeSessionFileTransiting.m
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

#import "MMWormholeSessionFileTransiting.h"

#if TARGET_OS_IOS || TARGET_OS_WATCH
#import <WatchConnectivity/WatchConnectivity.h>
#endif

@interface MMWormholeSessionFileTransiting () <WCSessionDelegate>
#if TARGET_OS_IOS || TARGET_OS_WATCH
@property (nonatomic, strong) WCSession *session;
#endif
@end

@implementation MMWormholeSessionFileTransiting

- (instancetype)initWithApplicationGroupIdentifier:(nullable NSString *)identifier
                                 optionalDirectory:(nullable NSString *)directory {
    if ((self = [super initWithApplicationGroupIdentifier:identifier optionalDirectory:directory])) {
#if TARGET_OS_IOS || TARGET_OS_WATCH
        // Setup transiting with the default session
        _session = [WCSession defaultSession];
        
        // Ensure that the MMWormholeSession's delegate is set to enable message sending
        NSAssert(_session.delegate != nil, @"WCSession's delegate is required to be set before you can send messages. Please initialize the MMWormholeSession sharedListeningSession object prior to creating a separate wormhole using the MMWormholeSessionTransiting classes.");
#endif
    }
    
    return self;
}


#pragma mark - MMWormholeFileTransiting Subclass Methods

- (nullable NSString *)messagePassingDirectoryPath {
    return nil;
}


#pragma mark - MMWormholeTransiting Protocol Methods

- (BOOL)writeMessageObject:(id<NSCoding>)messageObject forIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return NO;
    }
    
    if (messageObject) {
#if TARGET_OS_IOS || TARGET_OS_WATCH
        NSData *data = nil;
        NSError *error = nil;
        data = [NSKeyedArchiver archivedDataWithRootObject:messageObject requiringSecureCoding:NO error:&error];
        if (error) {
            NSLog(@"Error archiving message object: %@", error);
            return NO;
        }
        
        if (data == nil) {
            return NO;
        }
        
        if ([self.session isReachable]) {
            [self.session
             sendMessage:@{identifier : data}
             replyHandler:nil
             errorHandler:^(NSError * __nonnull error) {
                 
             }];
        }
#endif
    }
    
    return NO;
}

- (nullable id<NSCoding>)messageObjectForIdentifier:(nullable NSString *)identifier {
    return nil;
}

- (void)deleteContentForIdentifier:(nullable NSString *)identifier {
}

- (void)deleteContentForAllMessages {
}

#pragma mark - WCSessionDelegate Methods

#if TARGET_OS_IOS || TARGET_OS_WATCH
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

@end
