//
//  TFYOCLibevManager.m
//  TFYSwiftSSRKit
//
//  Created for TFYSwiftSSRKit on 2024
//  Copyright © 2024 TFYSwiftSSRKit. All rights reserved.
//

#import "TFYOCLibevManager.h"
#import "TFYOCLibevConnection.h"
#import <pthread.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <stdatomic.h>

// 导入shadowsocks-libev头文件
#include "shadowsocks.h"

// 导入antinat和privoxy管理器
#import "TFYOCLibevAntinatManager.h"
#import "TFYOCLibevPrivoxyManager.h"

// 导入CocoaAsyncSocket
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>

// 导入MMWormhole
#import <MMWormhole/MMWormhole.h>

// 错误域和错误码
NSString * const TFYOCLibevErrorDomain = @"com.tfyswiftssrkit.libev";

typedef NS_ENUM(NSInteger, TFYOCLibevErrorCode) {
    TFYOCLibevErrorCodeServerEmpty = 1001,
    TFYOCLibevErrorCodeConnectionFailed = 1002,
    TFYOCLibevErrorCodeStartFailed = 1003
};

// 常量定义
static NSString * const kAppGroupIdentifier = @"group.com.tfyswiftssrkit";
static NSString * const kWormholeDirectory = @"wormhole";
static NSString * const kTrafficUpdateIdentifier = @"trafficUpdate";
static NSString * const kProxyStatusIdentifier = @"proxyStatus";
static NSString * const kCommandIdentifier = @"command";

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
        _mtu = 0;
    }
    return self;
}

+ (instancetype)configWithServerHost:(nonnull NSString *)serverHost
                          serverPort:(int)serverPort
                            password:(nonnull NSString *)password
                              method:(nonnull NSString *)method {
    TFYProxyConfig *config = [[TFYProxyConfig alloc] init];
    config.serverHost = [serverHost copy];
    config.serverPort = serverPort;
    config.password = [password copy];
    config.method = [method copy];
    return config;
}

- (profile_t)toProfile {
    profile_t profile;
    memset(&profile, 0, sizeof(profile_t));
    
    // 设置服务器地址和端口
    profile.remote_host = strdup(self.serverHost.UTF8String);
    profile.remote_port = self.serverPort;
    
    // 设置本地地址和端口
    profile.local_addr = strdup(self.localAddress.UTF8String);
    profile.local_port = self.localPort;
    
    // 设置密码和加密方法
    profile.password = strdup(self.password.UTF8String);
    profile.method = strdup(self.method.UTF8String);
    
    // 设置超时时间和其他选项
    profile.timeout = self.timeout;
    profile.fast_open = self.enableFastOpen ? 1 : 0;
    profile.mptcp = self.enableMPTCP ? 1 : 0;
    profile.mtu = self.mtu;
    profile.verbose = self.verbose ? 1 : 0;
    profile.mode = self.enableUDP ? 1 : 0;
    
    // 设置ACL和日志文件路径
    if (self.aclFilePath) {
        profile.acl = strdup(self.aclFilePath.UTF8String);
    }
    if (self.logFilePath) {
        profile.log = strdup(self.logFilePath.UTF8String);
    }
    
    return profile;
}

@end

// 定义私有属性和方法
@interface TFYOCLibevManager () <GCDAsyncSocketDelegate, TFYOCLibevPrivoxyManagerDelegate>

@property (nonatomic, assign) TFYProxyStatus status;
@property (nonatomic, assign) uint64_t uploadBytes;
@property (nonatomic, assign) uint64_t downloadBytes;
@property (nonatomic, assign) uint64_t totalConnections;
@property (nonatomic, assign) uint64_t activeConnections;

// 代理线程
@property (nonatomic, strong, nullable) NSThread *proxyThread;
// 代理监听器
@property (nonatomic, assign) void *proxyListener;
// 上次流量统计时间
@property (nonatomic, strong, nullable) NSDate *lastTrafficUpdateTime;
// 上次上传和下载字节数
@property (nonatomic, assign) uint64_t lastUploadBytes;
@property (nonatomic, assign) uint64_t lastDownloadBytes;

// 流量统计定时器
@property (nonatomic, strong, nullable) NSTimer *trafficTimer;
// 进程间通信
@property (nonatomic, strong, nullable) MMWormhole *wormhole;
// 测试延迟的socket
@property (nonatomic, strong, nullable) GCDAsyncSocket *latencyTestSocket;
// 延迟测试回调
@property (nonatomic, copy, nullable) void(^latencyTestCompletion)(NSTimeInterval, NSError *);
// 延迟测试开始时间
@property (nonatomic, strong, nullable) NSDate *latencyTestStartTime;
// 队列
@property (nonatomic, strong) dispatch_queue_t proxyQueue;

// 活跃连接数组
@property (nonatomic, strong) NSMutableArray<TFYOCLibevConnection *> *connections;

// Privoxy管理器
@property (nonatomic, strong) TFYOCLibevPrivoxyManager *privoxyManager;
// Antinat管理器
@property (nonatomic, strong) TFYOCLibevAntinatManager *antinatManager;
// HTTP代理端口
@property (nonatomic, assign) int httpProxyPort;

// 添加处理代理启动的方法声明
- (void)handleProxyStarted:(int)socksFd udpFd:(int)udpFd;
// 启动HTTP代理
- (BOOL)startHTTPProxy;
// 停止HTTP代理
- (void)stopHTTPProxy;

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
        _httpProxyPort = 8118; // 默认HTTP代理端口
        _connections = [NSMutableArray array];
        
        // 创建专用队列
        _proxyQueue = dispatch_queue_create("com.tfyswiftssrkit.proxy", DISPATCH_QUEUE_SERIAL);
        
        // 初始化进程间通信
        _wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:kAppGroupIdentifier
                                                        optionalDirectory:kWormholeDirectory];
        
        // 初始化Privoxy管理器
        _privoxyManager = [TFYOCLibevPrivoxyManager sharedManager];
        _privoxyManager.delegate = self;
        
        // 初始化Antinat管理器
        _antinatManager = [TFYOCLibevAntinatManager sharedManager];
        
        // 使用弱引用避免循环引用
        __weak typeof(self) weakSelf = self;
        
        // 监听来自扩展的消息
        [_wormhole listenForMessageWithIdentifier:kTrafficUpdateIdentifier listener:^(id messageObject) {
            if (![messageObject isKindOfClass:[NSDictionary class]]) return;
            
            NSDictionary *trafficData = (NSDictionary *)messageObject;
            uint64_t upload = [trafficData[@"upload"] unsignedLongLongValue];
            uint64_t download = [trafficData[@"download"] unsignedLongLongValue];
            
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.uploadBytes = upload;
                strongSelf.downloadBytes = download;
                
                if ([strongSelf.delegate respondsToSelector:@selector(proxyTrafficUpdate:downloadBytes:)]) {
                    [strongSelf.delegate proxyTrafficUpdate:upload downloadBytes:download];
                }
            });
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
            [self.delegate proxyStatusDidChange:self.status];
        }
    });
    
    // 启动流量统计定时器
    [self startTrafficTimer];
    
    // 在后台线程启动代理
    self.proxyThread = [[NSThread alloc] initWithTarget:self selector:@selector(proxyThreadMain) object:nil];
    self.proxyThread.name = @"com.tfyswiftssrkit.proxy";
    self.proxyThread.qualityOfService = NSQualityOfServiceUserInitiated;
    [self.proxyThread start];
    
    return YES;
}

- (void)stopProxy {
    if (self.status != TFYProxyStatusRunning && self.status != TFYProxyStatusStarting) {
        return;
    }
    
    self.status = TFYProxyStatusStopping;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
            [self.delegate proxyStatusDidChange:self.status];
        }
    });
    
    // 停止流量统计定时器
    [self stopTrafficTimer];
    
    // 停止HTTP代理
    [self stopHTTPProxy];
    
    // 关闭所有Antinat连接
    [self closeAllAntinatConnections];
    
    dispatch_async(self.proxyQueue, ^{
        [self stopProxyInternal];
    });
}

// 内部方法，实际停止代理
- (void)stopProxyInternal {
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
                         identifier:kProxyStatusIdentifier];
    
    self.status = TFYProxyStatusStopped;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(proxyStatusDidChange:)]) {
            [self.delegate proxyStatusDidChange:self.status];
        }
        
        if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
            [self.delegate proxyLogMessage:@"代理服务已停止" level:0];
        }
    });
}

- (BOOL)restartProxy {
    [self stopProxy];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), self.proxyQueue, ^{
        [self startProxy];
    });
    
    return YES;
}

- (void)testServerLatency:(void(^)(NSTimeInterval latency, NSError * _Nullable error))completion {
    if (!self.config.serverHost || self.config.serverHost.length == 0) {
        NSError *error = [NSError errorWithDomain:TFYOCLibevErrorDomain
                                           code:TFYOCLibevErrorCodeServerEmpty
                                       userInfo:@{NSLocalizedDescriptionKey: @"服务器地址不能为空"}];
        if (completion) {
            completion(-1, error);
        }
        return;
    }
    
    self.latencyTestCompletion = [completion copy];
    self.latencyTestStartTime = [NSDate date];
    
    dispatch_async(self.proxyQueue, ^{
        self.latencyTestSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.proxyQueue];
        
        NSError *error = nil;
        if (![self.latencyTestSocket connectToHost:self.config.serverHost
                                          onPort:self.config.serverPort
                                    withTimeout:5.0
                                         error:&error]) {
            if (self.latencyTestCompletion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.latencyTestCompletion(-1, error);
                });
                self.latencyTestCompletion = nil;
            }
        }
    });
}

- (void)getCurrentSpeed:(void(^)(uint64_t uploadSpeed, uint64_t downloadSpeed))completion {
    if (!completion) return;
    
    dispatch_async(self.proxyQueue, ^{
        NSTimeInterval timeDiff = MAX(1.0, [[NSDate date] timeIntervalSinceDate:self.lastTrafficUpdateTime]);
        
        uint64_t currentUpload = self.uploadBytes;
        uint64_t currentDownload = self.downloadBytes;
        uint64_t lastUpload = self.lastUploadBytes;
        uint64_t lastDownload = self.lastDownloadBytes;
        
        uint64_t uploadDiff = currentUpload - lastUpload;
        uint64_t downloadDiff = currentDownload - lastDownload;
        
        uint64_t uploadSpeed = (uint64_t)(uploadDiff / timeDiff);
        uint64_t downloadSpeed = (uint64_t)(downloadDiff / timeDiff);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(uploadSpeed, downloadSpeed);
        });
    });
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
    
    // 如果HTTP代理已启动，也设置HTTP代理
    if (self.privoxyManager.isRunning) {
        task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/sbin/networksetup"];
        [task setArguments:@[@"-setwebproxy", @"Wi-Fi", self.config.localAddress, [NSString stringWithFormat:@"%d", self.httpProxyPort]]];
        [task launch];
        [task waitUntilExit];
        
        task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/sbin/networksetup"];
        [task setArguments:@[@"-setwebproxystate", @"Wi-Fi", @"on"]];
        [task launch];
        [task waitUntilExit];
    }
    
    return task.terminationStatus == 0;
}

- (BOOL)removeGlobalProxy {
    // 禁用SOCKS代理
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/networksetup"];
    [task setArguments:@[@"-setsocksfirewallproxystate", @"Wi-Fi", @"off"]];
    [task launch];
    [task waitUntilExit];
    
    // 禁用HTTP代理
    task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/networksetup"];
    [task setArguments:@[@"-setwebproxystate", @"Wi-Fi", @"off"]];
    [task launch];
    [task waitUntilExit];
    
    return task.terminationStatus == 0;
}
#endif

#pragma mark - HTTP代理方法

- (BOOL)startHTTPProxy {
    // 配置Privoxy
    TFYPrivoxyConfig *privoxyConfig = [TFYPrivoxyConfig configWithListenPort:self.httpProxyPort
                                                          forwardSOCKS5Host:self.config.localAddress
                                                          forwardSOCKS5Port:self.config.localPort];
    
    // 设置日志文件路径
    NSString *logDir = NSTemporaryDirectory();
    privoxyConfig.logFilePath = [logDir stringByAppendingPathComponent:@"privoxy.log"];
    
    // 设置配置
    self.privoxyManager.config = privoxyConfig;
    
    // 启动Privoxy
    BOOL success = [self.privoxyManager startPrivoxy];
    
    if (success) {
        if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
            [self.delegate proxyLogMessage:@"HTTP代理服务已启动" level:0];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
            [self.delegate proxyLogMessage:@"HTTP代理服务启动失败" level:2];
        }
    }
    
    return success;
}

- (void)stopHTTPProxy {
    [self.privoxyManager stopPrivoxy];
}

#pragma mark - Antinat方法

- (TFYOCLibevAntinatConnection *)createAntinatConnectionWithConfig:(TFYAntinatConfig *)config
                                                        remoteHost:(NSString *)remoteHost
                                                        remotePort:(uint16_t)remotePort {
    return [self.antinatManager createConnectionWithConfig:config
                                                remoteHost:remoteHost
                                                remotePort:remotePort];
}

- (NSArray<TFYOCLibevAntinatConnection *> *)activeAntinatConnections {
    return [self.antinatManager activeConnections];
}

- (TFYOCLibevAntinatConnection *)antinatConnectionWithIdentifier:(NSString *)identifier {
    return [self.antinatManager connectionWithIdentifier:identifier];
}

- (void)closeAllAntinatConnections {
    [self.antinatManager closeAllConnections];
}

- (NSArray<NSString *> *)resolveHostname:(NSString *)hostname {
    return [self.antinatManager resolveHostname:hostname];
}

#pragma mark - Privoxy方法

- (BOOL)addPrivoxyFilterRule:(TFYPrivoxyFilterRule *)rule {
    return [self.privoxyManager addFilterRule:rule];
}

- (BOOL)removePrivoxyFilterRuleWithPattern:(NSString *)pattern {
    return [self.privoxyManager removeFilterRuleWithPattern:pattern];
}

- (NSArray<TFYPrivoxyFilterRule *> *)allPrivoxyFilterRules {
    return [self.privoxyManager allFilterRules];
}

- (BOOL)clearAllPrivoxyFilterRules {
    return [self.privoxyManager clearAllFilterRules];
}

- (BOOL)togglePrivoxyFiltering:(BOOL)enabled {
    return [self.privoxyManager toggleFiltering:enabled];
}

- (BOOL)togglePrivoxyCompression:(BOOL)enabled {
    return [self.privoxyManager toggleCompression:enabled];
}

- (BOOL)generatePrivoxyConfigFile {
    return [self.privoxyManager generateConfigFile];
}

- (BOOL)loadPrivoxyConfigFile:(NSString *)filePath {
    return [self.privoxyManager loadConfigFile:filePath];
}

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
                                                     code:TFYOCLibevErrorCodeStartFailed
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
                         identifier:kProxyStatusIdentifier];
    
    // 记录日志
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:@"代理服务已启动" level:0];
    }
    
    // 启动HTTP代理
    [self startHTTPProxy];
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
                         identifier:kCommandIdentifier];
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
                                                                  code:TFYOCLibevErrorCodeConnectionFailed
                                                              userInfo:@{NSLocalizedDescriptionKey: @"连接服务器失败"}]);
        self.latencyTestCompletion = nil;
        self.latencyTestSocket = nil;
    }
}

#pragma mark - TFYOCLibevPrivoxyManagerDelegate

- (void)privoxyDidStart {
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:@"HTTP代理服务已启动" level:0];
    }
}

- (void)privoxyDidStop {
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:@"HTTP代理服务已停止" level:0];
    }
}

- (void)privoxyDidEncounterError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:[NSString stringWithFormat:@"HTTP代理服务错误: %@", error.localizedDescription] level:2];
    }
}

- (void)privoxyLogMessage:(NSString *)message {
    if ([self.delegate respondsToSelector:@selector(proxyLogMessage:level:)]) {
        [self.delegate proxyLogMessage:[NSString stringWithFormat:@"[Privoxy] %@", message] level:1];
    }
}

- (NSDictionary *)getTrafficStatistics {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    
    // 获取当前连接的流量统计
    uint64_t totalUpload = 0;
    uint64_t totalDownload = 0;
    
    for (TFYOCLibevConnection *connection in self.connections) {
        totalUpload += connection.uploadBytes;
        totalDownload += connection.downloadBytes;
    }
    
    // 更新总流量
    self.totalConnections = self.connections.count;
    self.activeConnections = 0;
    
    for (TFYOCLibevConnection *connection in self.connections) {
        if (connection.status == TFYConnectionStatusConnected) {
            self.activeConnections++;
        }
    }
    
    stats[@"upload"] = @(totalUpload);
    stats[@"download"] = @(totalDownload);
    stats[@"totalConnections"] = @(self.totalConnections);
    stats[@"activeConnections"] = @(self.activeConnections);
    
    return [stats copy];
}

@end