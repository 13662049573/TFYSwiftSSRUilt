//
//  TFYSwiftSSRKit.h
//  TFYSwiftSSRKit
//
//  Created by tianfengyou on 2024/03/15.
//  Copyright © 2024 tianfengyou. All rights reserved.
//

#ifndef TFYSwiftSSRKit_h
#define TFYSwiftSSRKit_h

#import <Foundation/Foundation.h>

//! Project version number for TFYSwiftSSRKit.
FOUNDATION_EXPORT double TFYSwiftSSRKitVersionNumber;

//! Project version string for TFYSwiftSSRKit.
FOUNDATION_EXPORT const unsigned char TFYSwiftSSRKitVersionString[];

// Base
#import "TFYSSTypes.h"
#import "TFYSSError.h"
#import "TFYSSConfig.h"

// Core
#import "TFYSSCoreProtocol.h"
#import "TFYSSRustCore.h"
#import "TFYSSLibevCore.h"
#import "TFYSSCoreFactory.h"

// Service
#import "TFYSSProxyService.h"
#import "TFYSSVPNService.h"
#import "TFYSSPacketTunnelProvider.h"

// 注意：以下组件需要单独添加到项目中
// - LibevOCClass: Objective-C 包装类
// - RustOCClass: Rust 包装类
// - NetworkExtension: 需要在项目中添加 NetworkExtension.framework

#endif /* TFYSwiftSSRKit_h */
