//
// MMWormholeSessionContextTransiting.m
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

#import "MMWormholeSessionContextTransiting.h"

#if TARGET_OS_IOS || TARGET_OS_WATCH
#import <WatchConnectivity/WatchConnectivity.h>
#endif

@interface MMWormholeSessionContextTransiting ()
#if TARGET_OS_IOS || TARGET_OS_WATCH
@property (nonatomic, strong) WCSession *session;
#endif
@end

@implementation MMWormholeSessionContextTransiting

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
        if (@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)) {
            NSError *error = nil;
            data = [NSKeyedArchiver archivedDataWithRootObject:messageObject requiringSecureCoding:NO error:&error];
            if (error) {
                NSLog(@"Error archiving message object: %@", error);
                return NO;
            }
        } else {
            data = [NSKeyedArchiver archivedDataWithRootObject:messageObject];
        }
        
        if (data == nil) {
            return NO;
        }
        
        NSError *error = nil;
        
        BOOL success = [self.session updateApplicationContext:@{identifier : data} error:&error];
        
        if (error) {
            NSLog(@"Error updating application context: %@", error);
        }
        
        return success;
#endif
    }
    
    return NO;
}

- (nullable id<NSCoding>)messageObjectForIdentifier:(nullable NSString *)identifier {
#if TARGET_OS_IOS || TARGET_OS_WATCH
    if (identifier == nil) {
        return nil;
    }
    
    NSDictionary *applicationContext = self.session.applicationContext;
    
    if (applicationContext == nil) {
        return nil;
    }
    
    NSData *data = applicationContext[identifier];
    
    if (data == nil) {
        return nil;
    }
    
    id messageObject = nil;
    if (@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)) {
        NSError *error = nil;
        messageObject = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
        if (error) {
            NSLog(@"Error unarchiving message object: %@", error);
            return nil;
        }
    } else {
        messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return messageObject;
#else
    return nil;
#endif
}

- (void)deleteContentForIdentifier:(nullable NSString *)identifier {
    // Not supported for WatchConnectivity context
}

- (void)deleteContentForAllMessages {
    // Not supported for WatchConnectivity context
}

@end
