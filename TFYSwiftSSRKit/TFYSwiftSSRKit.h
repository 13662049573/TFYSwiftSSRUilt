//
//  TFYSwiftSSRKit.h
//  TFYSwiftSSRKit
//
//  Created by 田风有 on 2025/2/26.
//

#ifndef TFYSwiftSSRKit_h
#define TFYSwiftSSRKit_h

// Objective-C 包装类
#import "LibevOCClass/TFYOCLibevConnection.h"
#import "LibevOCClass/TFYOCLibevManager.h"
#import "LibevOCClass/TFYOCLibevSOCKS5Handler.h"
#import "LibevOCClass/TFYOCLibevAntinatManager.h"
#import "LibevOCClass/TFYOCLibevPrivoxyManager.h"
#import "RustOCClass/TFYSSManager.h"
#import "RustOCClass/TFYVPNManager.h"

// GCDAsyncSocket
#import "GCDAsyncSocket/GCDAsyncSocket.h"
#import "GCDAsyncSocket/GCDAsyncUdpSocket.h"

// MMWormhole
#import "MMWormhole/MMWormhole.h"
#import "MMWormhole/MMWormholeSession.h"
#import "MMWormhole/MMWormholeTransiting.h"
#import "MMWormhole/MMWormholeFileTransiting.h"
#import "MMWormhole/MMWormholeCoordinatedFileTransiting.h"
#import "MMWormhole/MMWormholeSessionContextTransiting.h"
#import "MMWormhole/MMWormholeSessionFileTransiting.h"
#import "MMWormhole/MMWormholeSessionMessageTransiting.h"

// 注意：以下C库头文件不需要在此处导入
// 它们会在各自的实现文件中按需导入
// 这样可以避免"umbrella header"警告

#endif /* TFYSwiftSSRKit_h */
