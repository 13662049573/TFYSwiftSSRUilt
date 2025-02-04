#import "TFYShadowsocksManager.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <MMWormhole/MMWormhole.h>
#import "shadowsocks_bridge.h"

@interface TFYShadowsocksManager () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *localSocket;
@property (nonatomic, strong) MMWormhole *wormhole;
@property (nonatomic, strong) NSMutableDictionary *activeSockets;
@property (nonatomic, assign) TFYShadowsocksState currentState;
@property (nonatomic, strong) NSError *currentError;
@property (nonatomic, assign) NSUInteger currentLocalPort;
@property (nonatomic, strong) NSString *currentServerAddress;
@property (nonatomic, assign) NSUInteger currentServerPort;

@end

@implementation TFYShadowsocksManager

+ (instancetype)sharedManager {
    static TFYShadowsocksManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeSockets = [NSMutableDictionary dictionary];
        _currentState = TFYShadowsocksStateIdle;
        _wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.tfy.shadowsocks"
                                                         optionalDirectory:@"wormhole"];
        
        [self setupWormholeListener];
    }
    return self;
}

- (void)setupWormholeListener {
    [self.wormhole listenForMessageWithIdentifier:@"ss_status" listener:^(id messageObject) {
        if ([messageObject isKindOfClass:[NSDictionary class]]) {
            [self handleStatusUpdate:messageObject];
        }
    }];
}

- (void)handleStatusUpdate:(NSDictionary *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *state = status[@"state"];
        if ([state isEqualToString:@"running"]) {
            self.currentState = TFYShadowsocksStateRunning;
        } else if ([state isEqualToString:@"error"]) {
            self.currentState = TFYShadowsocksStateError;
            // Handle error
            NSString *errorMessage = status[@"error"];
            if (errorMessage) {
                self.currentError = [NSError errorWithDomain:@"com.tfy.shadowsocks"
                                                      code:-1
                                                  userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
            }
        }
    });
}

- (void)startWithConfiguration:(NSDictionary *)configuration completion:(void (^)(NSError * _Nullable))completion {
    if (self.currentState == TFYShadowsocksStateRunning) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    
    self.currentState = TFYShadowsocksStateStarting;
    
    // 配置Shadowsocks
    NSString *serverAddress = configuration[@"server"];
    NSNumber *serverPort = configuration[@"server_port"];
    NSString *password = configuration[@"password"];
    NSString *method = configuration[@"method"];
    NSNumber *localPort = configuration[@"local_port"];
    
    if (!serverAddress || !serverPort || !password || !method || !localPort) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid configuration"}];
        if (completion) {
            completion(error);
        }
        return;
    }
    
    self.currentServerAddress = serverAddress;
    self.currentServerPort = [serverPort unsignedIntegerValue];
    self.currentLocalPort = [localPort unsignedIntegerValue];
    
    // 启动本地服务器
    self.localSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    if (![self.localSocket acceptOnPort:self.currentLocalPort error:&error]) {
        self.currentState = TFYShadowsocksStateError;
        self.currentError = error;
        if (completion) {
            completion(error);
        }
        return;
    }
    
    // 初始化Shadowsocks
    profile_t profile;
    memset(&profile, 0, sizeof(profile_t));
    
    profile.remote_host = strdup_safe([serverAddress UTF8String]);
    profile.remote_port = (unsigned short)[serverPort unsignedShortValue];
    profile.local_addr = strdup_safe("127.0.0.1");
    profile.local_port = (unsigned short)[localPort unsignedShortValue];
    profile.password = strdup_safe([password UTF8String]);
    profile.method = strdup_safe([method UTF8String]);
    profile.timeout = 600;
    profile.fast_open = 0;
    profile.mode = 0;
    profile.mtu = 1500;
    profile.mptcp = 0;
    
    // 启动Shadowsocks
    ss_init();
    int result = start_ss_local_server(&profile);
    
    // 释放内存
    free(profile.remote_host);
    free(profile.local_addr);
    free(profile.password);
    free(profile.method);
    
    if (result != 0) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks"
                                           code:result
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to start shadowsocks server"}];
        self.currentState = TFYShadowsocksStateError;
        self.currentError = error;
        if (completion) {
            completion(error);
        }
        return;
    }
    
    self.currentState = TFYShadowsocksStateRunning;
    
    if (completion) {
        completion(nil);
    }
}

- (void)stopWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.currentState != TFYShadowsocksStateRunning) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    
    self.currentState = TFYShadowsocksStateStopping;
    
    // 停止本地服务器
    [self.localSocket disconnect];
    self.localSocket = nil;
    
    // 停止所有活动连接
    [self.activeSockets removeAllObjects];
    
    // 停止Shadowsocks
    stop_ss_local_server();
    
    self.currentState = TFYShadowsocksStateIdle;
    
    if (completion) {
        completion(nil);
    }
}

- (void)updateConfiguration:(NSDictionary *)configuration completion:(void (^)(NSError * _Nullable))completion {
    [self stopWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(error);
            }
            return;
        }
        
        [self startWithConfiguration:configuration completion:completion];
    }];
}

#pragma mark - Properties

- (TFYShadowsocksState)state {
    return self.currentState;
}

- (NSError *)lastError {
    return self.currentError;
}

- (NSUInteger)localPort {
    return self.currentLocalPort;
}

- (NSString *)serverAddress {
    return self.currentServerAddress;
}

- (NSUInteger)serverPort {
    return self.currentServerPort;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    // 为新连接创建一个唯一标识符
    NSString *connectionId = [[NSUUID UUID] UUIDString];
    self.activeSockets[connectionId] = newSocket;
    
    // 开始读取数据
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    // 处理接收到的数据
    // 这里需要实现Shadowsocks协议的数据处理逻辑
    
    // 继续读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    // 从活动连接中移除断开的socket
    NSString *disconnectedId = nil;
    for (NSString *connectionId in self.activeSockets) {
        if (self.activeSockets[connectionId] == sock) {
            disconnectedId = connectionId;
            break;
        }
    }
    
    if (disconnectedId) {
        [self.activeSockets removeObjectForKey:disconnectedId];
    }
}

@end 