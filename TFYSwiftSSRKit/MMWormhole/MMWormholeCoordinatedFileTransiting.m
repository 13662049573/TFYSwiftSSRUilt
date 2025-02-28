//
// MMWormholeCoordinatedFileTransiting.h
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

#import "MMWormholeCoordinatedFileTransiting.h"

@implementation MMWormholeCoordinatedFileTransiting

#pragma mark - MMWormholeTransiting Methods

- (BOOL)writeMessageObject:(id<NSCoding>)messageObject forIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return NO;
    }
    
    if (messageObject) {
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
        
        NSString *filePath = [self filePathForIdentifier:identifier];
        
        if (filePath == nil) {
            return NO;
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block BOOL success = NO;
        
        [coordinator coordinateWritingItemAtURL:fileURL options:0 error:&error byAccessor:^(NSURL *newURL) {
            success = [data writeToFile:filePath atomically:YES];
        }];
        
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
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block NSData *data = nil;
    __block NSError *error = nil;
    
    [coordinator coordinateReadingItemAtURL:fileURL options:0 error:&error byAccessor:^(NSURL *newURL) {
        data = [NSData dataWithContentsOfFile:filePath];
    }];
    
    if (data == nil) {
        return nil;
    }
    
    id messageObject = nil;
    NSError *unarchiveError = nil;
    messageObject = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&unarchiveError];
    if (unarchiveError) {
        NSLog(@"Error unarchiving message object: %@", unarchiveError);
        return nil;
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
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block NSError *error = nil;
    
    [coordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:&error byAccessor:^(NSURL *newURL) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    }];
}

@end
