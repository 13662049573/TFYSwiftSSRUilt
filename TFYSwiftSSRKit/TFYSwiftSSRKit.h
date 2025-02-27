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
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"

// MMWormhole
#import "MMWormhole.h"
#import "MMWormholeSession.h"
#import "MMWormholeTransiting.h"
#import "MMWormholeFileTransiting.h"
#import "MMWormholeCoordinatedFileTransiting.h"
#import "MMWormholeSessionContextTransiting.h"
#import "MMWormholeSessionFileTransiting.h"
#import "MMWormholeSessionMessageTransiting.h"

// 注意：以下C库头文件不需要在此处导入
// 它们会在各自的实现文件中按需导入
// 这样可以避免"umbrella header"警告

#endif /* TFYSwiftSSRKit_h */
