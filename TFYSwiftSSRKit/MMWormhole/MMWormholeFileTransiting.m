//
// MMWormholeFileTransiting.m
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

#import <Foundation/Foundation.h>

#import "MMWormholeFileTransiting.h"

@interface MMWormholeFileTransiting ()

@property (nonatomic, copy) NSString *applicationGroupIdentifier;
@property (nonatomic, copy) NSString *directory;
@property (nonatomic, copy) NSString *basePath;

@end

@implementation MMWormholeFileTransiting

- (instancetype)initWithApplicationGroupIdentifier:(nullable NSString *)identifier
                                 optionalDirectory:(nullable NSString *)directory {
    if ((self = [super init])) {
        _applicationGroupIdentifier = identifier;
        _directory = directory;
        
        if (identifier.length > 0) {
            NSURL *appGroupContainer = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:identifier];
            
            if (appGroupContainer) {
                _basePath = [appGroupContainer path];
            }
        }
        
        if (_basePath.length == 0) {
            // Fallback to a temporary directory
            _basePath = NSTemporaryDirectory();
        }
        
        if (directory.length > 0) {
            _basePath = [_basePath stringByAppendingPathComponent:directory];
        }
        
        [self createDirectoryAtPath:_basePath];
    }
    
    return self;
}


#pragma mark - Private Methods

- (void)createDirectoryAtPath:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL] == NO) {
        NSError *directoryCreationError = nil;
        
        if ([[NSFileManager defaultManager] createDirectoryAtPath:path
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:&directoryCreationError] == NO) {
            NSLog(@"Failed to create directory at path %@ with error %@", path, directoryCreationError);
        }
    }
}


#pragma mark - MMWormholeTransiting Protocol Methods

- (NSString *)messagePassingDirectoryPath {
    return self.basePath;
}

- (NSString *)filePathForIdentifier:(NSString *)identifier {
    if (identifier == nil || identifier.length == 0) {
        return nil;
    }
    
    NSString *fileName = [NSString stringWithFormat:@"%@.archive", identifier];
    NSString *filePath = [self.messagePassingDirectoryPath stringByAppendingPathComponent:fileName];
    
    return filePath;
}

- (BOOL)writeMessageObject:(id<NSCoding>)messageObject forIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return NO;
    }
    
    if (messageObject) {
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
        
        NSString *filePath = [self filePathForIdentifier:identifier];
        
        if (filePath == nil) {
            return NO;
        }
        
        BOOL success = [data writeToFile:filePath atomically:YES];
        
        if (success) {
            return YES;
        }
    } else {
        [self deleteContentForIdentifier:identifier];
        
        return YES;
    }
    
    return NO;
}

- (id<NSCoding>)messageObjectForIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return nil;
    }
    
    NSString *filePath = [self filePathForIdentifier:identifier];
    
    if (filePath == nil) {
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
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
}

- (void)deleteContentForIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return;
    }
    
    NSString *filePath = [self filePathForIdentifier:identifier];
    
    if (filePath == nil) {
        return;
    }
    
    NSError *fileError = nil;
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
}

- (void)deleteContentForAllMessages {
    NSArray *messageFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.messagePassingDirectoryPath error:NULL];
    
    for (NSString *path in messageFiles) {
        if ([path hasSuffix:@".archive"]) {
            NSString *identifier = [path stringByDeletingPathExtension];
            [self deleteContentForIdentifier:identifier];
        }
    }
}

@end
