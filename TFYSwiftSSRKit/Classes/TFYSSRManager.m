#import "TFYSSRManager.h"
#import "shadowsocks.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netdb.h>

@implementation TFYSSRConfiguration

+ (instancetype)configurationWithHost:(NSString *)host
                               port:(NSInteger)port
                          password:(NSString *)password
                           method:(NSString *)method {
    TFYSSRConfiguration *config = [[TFYSSRConfiguration alloc] init];
    config.remoteHost = host;
    config.remotePort = port;
    config.password = password;
    config.method = method;
    config.localAddress = @"127.0.0.1";
    config.localPort = 1080;
    config.timeout = 600;
    return config;
}

@end

@interface TFYSSRManager ()

@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) TFYSSRConfiguration *currentConfig;
@property (nonatomic, assign) profile_t *profile;
@property (nonatomic, strong) dispatch_queue_t ssrQueue;

@end

@implementation TFYSSRManager

+ (instancetype)sharedManager {
    static TFYSSRManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TFYSSRManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ssrQueue = dispatch_queue_create("com.tfy.ssr.queue", DISPATCH_QUEUE_SERIAL);
        _isRunning = NO;
    }
    return self;
}

- (BOOL)startWithConfiguration:(TFYSSRConfiguration *)config {
    if (self.isRunning) {
        return NO;
    }
    
    self.currentConfig = config;
    
    // 创建并配置profile
    profile_t profile = {0};
    profile.remote_host = strdup([config.remoteHost UTF8String]);
    profile.remote_port = (int)config.remotePort;
    profile.local_addr = strdup([config.localAddress UTF8String]);
    profile.local_port = (int)config.localPort;
    profile.password = strdup([config.password UTF8String]);
    profile.method = strdup([config.method UTF8String]);
    profile.timeout = (int)config.timeout;
    
    // 可选配置
    profile.acl = NULL;
    profile.log = NULL;
    profile.fast_open = 0;
    profile.mode = 0;
    profile.mtu = 0;
    profile.mptcp = 0;
    profile.verbose = 0;
    
    self.profile = malloc(sizeof(profile_t));
    memcpy(self.profile, &profile, sizeof(profile_t));
    
    // 在后台线程启动服务
    dispatch_async(self.ssrQueue, ^{
        int result = start_ss_local_server(*self.profile);
        if (result == -1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isRunning = NO;
                [self cleanup];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isRunning = YES;
            });
        }
    });
    
    return YES;
}

- (void)stop {
    if (!self.isRunning) {
        return;
    }
    
    // 发送SIGUSR1信号来停止服务
    pthread_kill(pthread_self(), SIGUSR1);
    [self cleanup];
    self.isRunning = NO;
}

- (void)cleanup {
    if (self.profile) {
        if (self.profile->remote_host) free(self.profile->remote_host);
        if (self.profile->local_addr) free(self.profile->local_addr);
        if (self.profile->password) free(self.profile->password);
        if (self.profile->method) free(self.profile->method);
        free(self.profile);
        self.profile = NULL;
    }
}

+ (NSArray<NSString *> *)supportedMethods {
    return @[
        @"aes-256-cfb",
        @"aes-128-cfb",
        @"chacha20",
        @"chacha20-ietf",
        @"aes-256-gcm",
        @"aes-128-gcm",
        @"chacha20-ietf-poly1305",
        @"xchacha20-ietf-poly1305"
    ];
}

- (void)testServerDelay:(NSString *)host 
                  port:(NSInteger)port 
             complete:(void(^)(NSTimeInterval delay, NSError * _Nullable error))complete {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSTimeInterval delay = -1;
        
        // 创建socket
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            error = [NSError errorWithDomain:@"com.tfy.ssr" code:-1 
                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to create socket"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                complete(delay, error);
            });
            return;
        }
        
        // 设置超时
        struct timeval timeout;
        timeout.tv_sec = 5;
        timeout.tv_usec = 0;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        
        // 解析主机地址
        struct hostent *server = gethostbyname([host UTF8String]);
        if (server == NULL) {
            error = [NSError errorWithDomain:@"com.tfy.ssr" code:-2 
                                  userInfo:@{NSLocalizedDescriptionKey: @"Could not resolve host"}];
            close(sock);
            dispatch_async(dispatch_get_main_queue(), ^{
                complete(delay, error);
            });
            return;
        }
        
        // 设置服务器地址
        struct sockaddr_in serv_addr;
        memset(&serv_addr, 0, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        memcpy(&serv_addr.sin_addr.s_addr, server->h_addr, server->h_length);
        serv_addr.sin_port = htons(port);
        
        // 记录开始时间
        NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
        
        // 尝试连接
        int result = connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr));
        
        // 记录结束时间
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970];
        
        if (result < 0) {
            error = [NSError errorWithDomain:@"com.tfy.ssr" code:-3 
                                  userInfo:@{NSLocalizedDescriptionKey: @"Connection failed"}];
        } else {
            delay = (endTime - startTime) * 1000; // 转换为毫秒
        }
        
        close(sock);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            complete(delay, error);
        });
    });
}

- (void)dealloc {
    [self stop];
}

@end 