# TFYSwiftSSRKit

A powerful iOS/macOS shadowsocks client library written in Objective-C.

## Features

* Multiple encryption methods support (OpenSSL & libsodium)
* GeoIP based routing
* TLS support
* Automatic network monitoring and reconnection
* Rule-based proxy configuration
* Traffic statistics

## Requirements

* iOS 15.0+ / macOS 12.0+
* Xcode 14.0+

## Installation

### CocoaPods

```ruby
pod 'TFYSwiftSSRKit'
```

## Project Structure

```
TFYSwiftSSRKit
├── Classes
│   ├── TFYShadowsocksManager.h/m
│   ├── TFYConfigurationManager.h/m
│   ├── TFYNetworkMonitor.h/m
│   ├── TFYShadowsocksError.h/m
├── Resources
│   ├── default_rules.json
│   ├── GeoLite2-Country.mmdb
│   └── user_rules.json
└── Libraries
    ├── libmaxminddb
    ├── libsodium
    ├── openssl
    └── shadowsocks
```

## Usage

### Basic Setup

```objc
#import <TFYSwiftSSRKit/TFYShadowsocksManager.h>

// Configure and start the shadowsocks client
NSDictionary *config = @{
    @"server": @"example.com",
    @"server_port": @8388,
    @"password": @"password",
    @"method": @"aes-256-gcm",
    @"local_port": @1080
};

[[TFYShadowsocksManager sharedManager] startWithConfiguration:config completion:^(NSError * _Nullable error) {
    if (error) {
        NSLog(@"Failed to start shadowsocks: %@", error);
        return;
    }
    NSLog(@"Shadowsocks started successfully");
}];
```

### Network Monitoring

```objc
#import <TFYSwiftSSRKit/TFYNetworkMonitor.h>

@interface YourClass () <TFYNetworkMonitorDelegate>
@end

@implementation YourClass

- (void)startMonitoring {
    [TFYNetworkMonitor sharedMonitor].delegate = self;
    [[TFYNetworkMonitor sharedMonitor] startMonitoring];
}

- (void)networkStatusDidChange:(TFYNetworkStatus)status {
    switch (status) {
        case TFYNetworkStatusReachableViaWiFi:
            NSLog(@"Connected via WiFi");
            break;
        case TFYNetworkStatusReachableViaCellular:
            NSLog(@"Connected via Cellular");
            break;
        case TFYNetworkStatusNotReachable:
            NSLog(@"Network not reachable");
            break;
        default:
            break;
    }
}

@end
```

### Configuration Management

```objc
#import <TFYSwiftSSRKit/TFYConfigurationManager.h>

// Save a configuration
NSDictionary *config = @{
    @"server": @"example.com",
    @"server_port": @8388,
    @"password": @"password",
    @"method": @"aes-256-gcm",
    @"local_port": @1080
};

[[TFYConfigurationManager sharedManager] saveConfiguration:config completion:^(NSError * _Nullable error) {
    if (error) {
        NSLog(@"Failed to save configuration: %@", error);
        return;
    }
    NSLog(@"Configuration saved successfully");
}];

// Load saved configurations
[[TFYConfigurationManager sharedManager] loadConfigurationWithCompletion:^(NSDictionary * _Nullable configuration, NSError * _Nullable error) {
    if (error) {
        NSLog(@"Failed to load configuration: %@", error);
        return;
    }
    if (configuration) {
        NSLog(@"Loaded configuration: %@", configuration);
    }
}];
```

## Dependencies

* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) - For asynchronous socket communications
* [MMWormhole](https://github.com/mutualmobile/MMWormhole) - For inter-process communication

## License

TFYSwiftSSRKit is available under the MIT license. See the LICENSE file for more info. 