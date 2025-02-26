//
//  TFYOCLibevManager.m
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import "TFYOCLibevManager.h"
#import <pthread.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>

// 导入shadowsocks-libev头文件
#include "shadowsocks.h"

// 导入CocoaAsyncSocket
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>

// 导入MMWormhole
#import <MMWormhole/MMWormhole.h>

// 错误域
NSString * const TFYOCLibevErrorDomain = @"com.tfyswiftssrkit.libev";

// 定义私有属性和方法
@interface TFYProxyConfig ()
// 转换为shadowsocks-libev的profile_t结构
- (profile_t)toProfile;
@end

@implementation TFYProxyConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        // 设置默认值
        _localAddress = @"127.0.0.1";
        _localPort = 1080;
        _timeout = 600;
        _method = @"aes-256-gcm";
        _mtu = 0; // 默认值
    }
    return self;
}

+ (instancetype)configWithServerHost:(NSString *)serverHost
                          serverPort:(int)serverPort
                            password:(NSString *)password
                              method:(NSString *)method {
    TFYProxyConfig *config = [[TFYProxyConfig alloc] init];
    config.serverHost = serverHost;
    config.serverPort = serverPort;
    config.password = password;
    config.method = method;
    return config;
}

- (profile_t)toProfile {
    profile_t profile = {0}; // 初始化所有字段为0
    
    // 必填字段
    if (self.serverHost) {
        profile.remote_host = strdup(self.serverHost.UTF8String);
    }
    
    if (self.localAddress) {
        profile.local_addr = strdup(self.localAddress.UTF8String);
    }
    
    if (self.method) {
        profile.method = strdup(self.method.UTF8String);
    }
    
    if (self.password) {
        profile.password = strdup(self.password.UTF8String);
    }
    
    profile.remote_port = self.serverPort;
    profile.local_port = self.localPort;
    profile.timeout = self.timeout;
    
    // 可选字段
    if (self.aclFilePath) {
        profile.acl = strdup(self.aclFilePath.UTF8String);
    } else {
        profile.acl = NULL;
    }
    
    if (self.logFilePath) {
        profile.log = strdup(self.logFilePath.UTF8String);
    } else {
        profile.log = NULL;
    }
    
    profile.fast_open = self.enableFastOpen ? 1 : 0;
    profile.mode = self.enableUDP ? 1 : 0;
    profile.mtu = self.mtu;
    profile.mptcp = self.enableMPTCP ? 1 : 0;
    profile.verbose = self.verbose ? 1 : 0;
    
    return profile;
}

@end

// 定义私有属性和方法
@interface TFYOCLibevManager () <GCDAsyncSocketDelegate>

// 代理状态
@property (nonatomic, assign, readwrite) TFYProxyStatus status;
// 代理线程
@property (nonatomic, strong) NSThread *proxyThread;
// 代理监听器
@property (nonatomic, assign) void *proxyListener;
// 流量统计
@property (nonatomic, assign) uint64_t uploadBytes;
@property (nonatomic, assign) uint64_t downloadBytes;
// 上次流量统计时间
@property (nonatomic, strong) NSDate *lastTrafficUpdateTime;
// 上次上传和下载字节数
@property (nonatomic, assign) uint64_t lastUploadBytes;
@property (nonatomic, assign) uint64_t lastDownloadBytes;
// 流量统计定时器
@property (nonatomic, strong) NSTimer *trafficTimer;
// 进程间通信
@property (nonatomic, strong) MMWormhole *wormhole;
// 测试延迟的socket
@property (nonatomic, strong) GCDAsyncSocket *latencyTestSocket;
// 延迟测试回调
@property (nonatomic, copy) void(^latencyTestCompletion)(NSTimeInterval, NSError *);
// 延迟测试开始时间
@property (nonatomic, strong) NSDate *latencyTestStartTime;

// 添加处理代理启动的方法声明
- (void)handleProxyStarted:(int)socksFd udpFd:(int)udpFd;

@end

// 修改回调函数名称，避免与shadowsocks-libev库中的函数冲突
static void tfy_ss_local_callback(int socks_fd, int udp_fd, void *data) {
    TFYOCLibevManager *manager = (__bridge TFYOCLibevManager *)data;
    dispatch_async(dispatch_get_main_queue(), ^{
        [manager handleProxyStarted:socks_fd udpFd:udp_fd];
    });
}

@implementation TFYOCLibevManager

#pragma mark - 单例方法

+ (instancetype)sharedManager {
    static TFYOCLibevManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - 初始化方法

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = TFYProxyStatusStopped;
        _proxyMode = TFYProxyModeGlobal;
        _config = [[TFYProxyConfig alloc] init];
        _uploadBytes = 0;
        _downloadBytes = 0;
        _lastTrafficUpdateTime = [NSDate date];
        
        // 初始化进程间通信
        _wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.tfyswiftssrkit"
                                                        optionalDirectory:@"wormhole"];
        
        // 监听来自扩展的消息
        [_wormhole listenForMessageWithIdentifier:@"trafficUpdate" listener:^(id messageObject) {
            if ([messageObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *trafficData = (NSDictionary *)messageObject;
                uint64_t upload = [trafficData[@"upload"] unsignedLongLongValue];
                uint64_t download = [trafficData[@"download"] unsignedLongLongValue];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.uploadBytes = upload;
                    self.downloadBytes = download;
                    
                    if ([self.delegate respondsToSelector:@selector(proxyTrafficUpdate:downloadBytes:)]) {
                        [self.delegate proxyTrafficUpdate:self.uploadBytes downloadBytes:self.downloadBytes];
                    }
                });
            }
        }];
    }
    return self;
}

#pragma mark - 公共方法

- (BOOL)startProxy {
    if (self.status != TFYProxyStatusStopped) {
        return NO;
    }
    
    self.status = TFYProxyStatusStarting;
    if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
        [self.delegate proxyStatusDidChange:self.status];
    }
    
    // 启动流量统计定时器
    [self startTrafficTimer];
    
    // 在后台线程启动代理
    self.proxyThread = [[NSThread alloc] initWithTarget:self selector:@selector(proxyThreadMain) object:nil];
    [self.proxyThread start];
    
    return YES;
}

- (void)stopProxy {
    if (self.status != TFYProxyStatusRunning && self.status != TFYProxyStatusStarting) {
        return;
    }
    
    self.status = TFYProxyStatusStopping;
    if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
        [self.delegate proxyStatusDidChange:self.status];
    }
    
    // 停止流量统计定时器
    [self stopTrafficTimer];
    
    // 停止代理
    if (self.proxyListener) {
        plexsocks_servver_stop(self.proxyListener);
        self.proxyListener = NULL;
    }
    
    // 取消线程
    if (self.proxyThread && ![self.proxyThread isFinished]) {
        [self performSelector:@selector(cancelProxyThread) onThread:self.proxyThread withObject:nil waitUntilDone:NO];
    }
    
    // 通知扩展代理已停止
    [self.wormhole passMessageObject:@{@"status": @"stopped"}
                         identifier:@"proxyStatus"];
    
    self.status = TFYProxyStatusStopped;
    if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
        [self.delegate proxyStatusDidChange:self.status];
    }
    
    // 记录日志
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:@"代理服务已停止" level:0];
    }
}

- (BOOL)restartProxy {
    [self stopProxy];
    
    // 等待一小段时间确保代理完全停止
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startProxy];
    });
    
    return YES;
}

- (void)testServerLatency:(void(^)(NSTimeInterval latency, NSError * _Nullable error))completion {
    if (!self.config.serverHost || [self.config.serverHost length] == 0) {
        NSError *error = [NSError errorWithDomain:TFYOCLibevErrorDomain
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"服务器地址不能为空"}];
        if (completion) {
            completion(-1, error);
        }
        return;
    }
    
    self.latencyTestCompletion = completion;
    self.latencyTestStartTime = [NSDate date];
    
    // 创建socket连接
    self.latencyTestSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    if (![self.latencyTestSocket connectToHost:self.config.serverHost onPort:self.config.serverPort withTimeout:5.0 error:&error]) {
        if (self.latencyTestCompletion) {
            self.latencyTestCompletion(-1, error);
            self.latencyTestCompletion = nil;
        }
    }
}

- (void)getCurrentSpeed:(void(^)(uint64_t uploadSpeed, uint64_t downloadSpeed))completion {
    if (!completion) return;
    
    NSTimeInterval timeDiff = [[NSDate date] timeIntervalSinceDate:self.lastTrafficUpdateTime];
    if (timeDiff <= 0) timeDiff = 1.0;
    
    uint64_t uploadDiff = self.uploadBytes - self.lastUploadBytes;
    uint64_t downloadDiff = self.downloadBytes - self.lastDownloadBytes;
    
    uint64_t uploadSpeed = (uint64_t)(uploadDiff / timeDiff);
    uint64_t downloadSpeed = (uint64_t)(downloadDiff / timeDiff);
    
    completion(uploadSpeed, downloadSpeed);
}

#if TARGET_OS_OSX
- (BOOL)setupGlobalProxy {
    // macOS系统代理设置
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/networksetup"];
    
    // 设置SOCKS代理
    [task setArguments:@[@"-setsocksfirewallproxy", @"Wi-Fi", self.config.localAddress, [NSString stringWithFormat:@"%d", self.config.localPort]]];
    [task launch];
    [task waitUntilExit];
    
    // 启用SOCKS代理
    task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/networksetup"];
    [task setArguments:@[@"-setsocksfirewallproxystate", @"Wi-Fi", @"on"]];
    [task launch];
    [task waitUntilExit];
    
    return task.terminationStatus == 0;
}

- (BOOL)removeGlobalProxy {
    // 禁用SOCKS代理
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/networksetup"];
    [task setArguments:@[@"-setsocksfirewallproxystate", @"Wi-Fi", @"off"]];
    [task launch];
    [task waitUntilExit];
    
    return task.terminationStatus == 0;
}
#endif

#pragma mark - 私有方法

- (void)proxyThreadMain {
    @autoreleasepool {
        // 转换配置为shadowsocks-libev的profile_t结构
        profile_t profile = [self.config toProfile];
        
        // 启动shadowsocks-libev本地服务器，使用修改后的回调函数
        int result = start_ss_local_server_with_callback(profile, tfy_ss_local_callback, (__bridge void *)self);
        
        // 释放profile中分配的内存
        free(profile.remote_host);
        free(profile.local_addr);
        free(profile.method);
        free(profile.password);
        if (profile.acl) free(profile.acl);
        if (profile.log) free(profile.log);
        
        // 处理启动失败的情况
        if (result == -1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.status = TFYProxyStatusError;
                
                NSError *error = [NSError errorWithDomain:TFYOCLibevErrorDomain
                                                     code:1000
                                                 userInfo:@{NSLocalizedDescriptionKey: @"启动代理服务失败"}];
                
                if ([self.delegate respondsToSelector:@selector(proxyDidEncounterError:)]) {
                    [self.delegate proxyDidEncounterError:error];
                }
                
                if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
                    [self.delegate proxyStatusDidChange:self.status];
                }
            });
        }
    }
}

- (void)cancelProxyThread {
    [NSThread exit];
}

- (void)handleProxyStarted:(int)socksFd udpFd:(int)udpFd {
    // 保存代理监听器
    self.proxyListener = (void *)(intptr_t)socksFd;
    
    // 更新状态
    self.status = TFYProxyStatusRunning;
    if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
        [self.delegate proxyStatusDidChange:self.status];
    }
    
    // 发送通知到扩展
    [self.wormhole passMessageObject:@{@"status": @"running",
                                      @"socksFd": @(socksFd),
                                      @"udpFd": @(udpFd)}
                         identifier:@"proxyStatus"];
    
    // 记录日志
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:@"代理服务已启动" level:0];
    }
}

#pragma mark - 流量统计

- (void)startTrafficTimer {
    [self stopTrafficTimer];
    
    self.lastUploadBytes = self.uploadBytes;
    self.lastDownloadBytes = self.downloadBytes;
    self.lastTrafficUpdateTime = [NSDate date];
    
    self.trafficTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updateTrafficStats)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopTrafficTimer {
    if (self.trafficTimer) {
        [self.trafficTimer invalidate];
        self.trafficTimer = nil;
    }
}

- (void)updateTrafficStats {
    // 保存上次的值用于计算速度
    self.lastUploadBytes = self.uploadBytes;
    self.lastDownloadBytes = self.downloadBytes;
    self.lastTrafficUpdateTime = [NSDate date];
    
    // 请求扩展更新流量统计
    [self.wormhole passMessageObject:@{@"command": @"getTrafficStats"}
                         identifier:@"command"];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    // 连接成功，计算延迟
    NSTimeInterval latency = [[NSDate date] timeIntervalSinceDate:self.latencyTestStartTime] * 1000; // 转换为毫秒
    
    if (self.latencyTestCompletion) {
        self.latencyTestCompletion(latency, nil);
        self.latencyTestCompletion = nil;
    }
    
    // 断开连接
    [sock disconnect];
    self.latencyTestSocket = nil;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (sock == self.latencyTestSocket && self.latencyTestCompletion) {
        self.latencyTestCompletion(-1, err ?: [NSError errorWithDomain:TFYOCLibevErrorDomain
                                                                  code:1002
                                                              userInfo:@{NSLocalizedDescriptionKey: @"连接服务器失败"}]);
        self.latencyTestCompletion = nil;
        self.latencyTestSocket = nil;
    }
}

@end 