#import "TFYConfigurationManager.h"
#import <MMWormhole/MMWormhole.h>

static NSString * const kConfigurationsKey = @"com.tfy.shadowsocks.configurations";
static NSString * const kCurrentConfigurationKey = @"com.tfy.shadowsocks.current_configuration";

@interface TFYConfigurationManager ()

@property (nonatomic, strong) MMWormhole *wormhole;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *configurations;
@property (nonatomic, strong) NSDictionary *current;

@end

@implementation TFYConfigurationManager

+ (instancetype)sharedManager {
    static TFYConfigurationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configurations = [NSMutableArray array];
        _wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.tfy.shadowsocks"
                                                        optionalDirectory:@"wormhole"];
        [self loadSavedConfigurations];
    }
    return self;
}

- (void)loadSavedConfigurations {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedConfigs = [defaults arrayForKey:kConfigurationsKey];
    if (savedConfigs) {
        [self.configurations addObjectsFromArray:savedConfigs];
    }
    
    self.current = [defaults dictionaryForKey:kCurrentConfigurationKey];
}

- (void)saveConfigurations {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.configurations forKey:kConfigurationsKey];
    [defaults synchronize];
}

#pragma mark - Public Methods

- (void)loadConfigurationWithCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    if (completion) {
        completion(self.current, nil);
    }
}

- (void)saveConfiguration:(NSDictionary *)configuration completion:(void (^)(NSError * _Nullable))completion {
    if (!configuration) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid configuration"}];
        if (completion) {
            completion(error);
        }
        return;
    }
    
    [self.configurations addObject:configuration];
    [self saveConfigurations];
    
    // 如果是第一个配置，设置为当前配置
    if (!self.current) {
        self.current = configuration;
        [[NSUserDefaults standardUserDefaults] setObject:configuration forKey:kCurrentConfigurationKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 通知其他进程配置已更新
    [self.wormhole passMessageObject:@{@"type": @"configuration_updated"} identifier:@"ss_config"];
    
    if (completion) {
        completion(nil);
    }
}

- (void)removeConfiguration:(NSDictionary *)configuration completion:(void (^)(NSError * _Nullable))completion {
    if (!configuration) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid configuration"}];
        if (completion) {
            completion(error);
        }
        return;
    }
    
    NSUInteger index = [self.configurations indexOfObject:configuration];
    if (index != NSNotFound) {
        [self.configurations removeObjectAtIndex:index];
        [self saveConfigurations];
        
        // 如果删除的是当前配置，清空当前配置
        if ([self.current isEqual:configuration]) {
            self.current = nil;
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentConfigurationKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        // 通知其他进程配置已更新
        [self.wormhole passMessageObject:@{@"type": @"configuration_removed"} identifier:@"ss_config"];
    }
    
    if (completion) {
        completion(nil);
    }
}

- (void)updateConfiguration:(NSDictionary *)configuration completion:(void (^)(NSError * _Nullable))completion {
    if (!configuration) {
        NSError *error = [NSError errorWithDomain:@"com.tfy.shadowsocks"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid configuration"}];
        if (completion) {
            completion(error);
        }
        return;
    }
    
    // 更新当前配置
    self.current = configuration;
    [[NSUserDefaults standardUserDefaults] setObject:configuration forKey:kCurrentConfigurationKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 更新配置列表
    NSUInteger index = [self.configurations indexOfObject:configuration];
    if (index != NSNotFound) {
        self.configurations[index] = configuration;
        [self saveConfigurations];
    } else {
        [self.configurations addObject:configuration];
        [self saveConfigurations];
    }
    
    // 通知其他进程配置已更新
    [self.wormhole passMessageObject:@{@"type": @"configuration_updated"} identifier:@"ss_config"];
    
    if (completion) {
        completion(nil);
    }
}

#pragma mark - Properties

- (NSDictionary *)currentConfiguration {
    return self.current;
}

- (NSArray<NSDictionary *> *)savedConfigurations {
    return [self.configurations copy];
}

@end 