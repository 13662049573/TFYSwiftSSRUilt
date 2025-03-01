#import "TFYSSRuleManager.h"

@interface TFYSSRuleManager ()

@property (nonatomic, strong) NSMutableArray<TFYSSRuleSet *> *mutableRuleSets;

@end

@implementation TFYSSRuleManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static TFYSSRuleManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableRuleSets = [NSMutableArray array];
        
        // 设置默认规则目录
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        _rulesDirectory = [documentsPath stringByAppendingPathComponent:@"Rules"];
        
        // 创建规则目录
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:_rulesDirectory]) {
            NSError *error = nil;
            [fileManager createDirectoryAtPath:_rulesDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                NSLog(@"Failed to create rules directory: %@", error);
            }
        }
        
        // 尝试加载规则
        NSError *error = nil;
        if (![self loadRuleSetsFromDirectory:_rulesDirectory error:&error]) {
            NSLog(@"Failed to load rule sets: %@", error);
            
            // 如果没有规则，创建默认规则集
            [self addRuleSet:[self createDefaultGFWListRuleSet]];
        }
    }
    return self;
}

#pragma mark - Properties

- (NSArray<TFYSSRuleSet *> *)ruleSets {
    return [_mutableRuleSets copy];
}

#pragma mark - Rule Set Management

- (void)addRuleSet:(TFYSSRuleSet *)ruleSet {
    if (!ruleSet) {
        return;
    }
    
    // 检查是否已存在同名规则集
    for (TFYSSRuleSet *existingRuleSet in _mutableRuleSets) {
        if ([existingRuleSet.name isEqualToString:ruleSet.name]) {
            // 更新现有规则集
            NSUInteger index = [_mutableRuleSets indexOfObject:existingRuleSet];
            [_mutableRuleSets replaceObjectAtIndex:index withObject:ruleSet];
            
            if ([self.delegate respondsToSelector:@selector(ruleManager:didUpdateRuleSet:)]) {
                [self.delegate ruleManager:self didUpdateRuleSet:ruleSet];
            }
            
            return;
        }
    }
    
    // 添加新规则集
    [_mutableRuleSets addObject:ruleSet];
    
    if ([self.delegate respondsToSelector:@selector(ruleManager:didAddRuleSet:)]) {
        [self.delegate ruleManager:self didAddRuleSet:ruleSet];
    }
}

- (void)removeRuleSet:(TFYSSRuleSet *)ruleSet {
    if (!ruleSet) {
        return;
    }
    
    if ([_mutableRuleSets containsObject:ruleSet]) {
        [_mutableRuleSets removeObject:ruleSet];
        
        if ([self.delegate respondsToSelector:@selector(ruleManager:didRemoveRuleSet:)]) {
            [self.delegate ruleManager:self didRemoveRuleSet:ruleSet];
        }
    }
}

- (void)removeRuleSetAtIndex:(NSUInteger)index {
    if (index < _mutableRuleSets.count) {
        TFYSSRuleSet *ruleSet = _mutableRuleSets[index];
        [_mutableRuleSets removeObjectAtIndex:index];
        
        if ([self.delegate respondsToSelector:@selector(ruleManager:didRemoveRuleSet:)]) {
            [self.delegate ruleManager:self didRemoveRuleSet:ruleSet];
        }
    }
}

- (nullable TFYSSRuleSet *)ruleSetWithName:(NSString *)name {
    if (!name) {
        return nil;
    }
    
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if ([ruleSet.name isEqualToString:name]) {
            return ruleSet;
        }
    }
    
    return nil;
}

- (nullable TFYSSRuleSet *)ruleSetAtIndex:(NSUInteger)index {
    if (index < _mutableRuleSets.count) {
        return _mutableRuleSets[index];
    }
    
    return nil;
}

#pragma mark - Rule Matching

- (TFYSSRuleMatchResult)matchHost:(NSString *)host {
    if (!host || host.length == 0) {
        return TFYSSRuleMatchResultNone;
    }
    
    TFYSSRuleSet *matchingRuleSet = nil;
    TFYSSRule *matchingRule = nil;
    TFYSSRuleMatchResult result = TFYSSRuleMatchResultNone;
    
    // 遍历所有启用的规则集
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if (!ruleSet.enabled) {
            continue;
        }
        
        TFYSSRule *rule = [ruleSet matchingRuleForHost:host];
        if (rule) {
            matchingRuleSet = ruleSet;
            matchingRule = rule;
            result = [ruleSet matchHost:host];
            break;
        }
    }
    
    // 如果没有匹配的规则，默认使用代理
    if (result == TFYSSRuleMatchResultNone) {
        result = TFYSSRuleMatchResultProxy;
    }
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(ruleManager:didMatchHost:result:ruleSet:rule:)]) {
        [self.delegate ruleManager:self didMatchHost:host result:result ruleSet:matchingRuleSet rule:matchingRule];
    }
    
    return result;
}

- (TFYSSRuleMatchResult)matchIP:(NSString *)ip {
    if (!ip || ip.length == 0) {
        return TFYSSRuleMatchResultNone;
    }
    
    TFYSSRuleSet *matchingRuleSet = nil;
    TFYSSRule *matchingRule = nil;
    TFYSSRuleMatchResult result = TFYSSRuleMatchResultNone;
    
    // 遍历所有启用的规则集
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if (!ruleSet.enabled) {
            continue;
        }
        
        TFYSSRule *rule = [ruleSet matchingRuleForIP:ip];
        if (rule) {
            matchingRuleSet = ruleSet;
            matchingRule = rule;
            result = [ruleSet matchIP:ip];
            break;
        }
    }
    
    // 如果没有匹配的规则，默认使用代理
    if (result == TFYSSRuleMatchResultNone) {
        result = TFYSSRuleMatchResultProxy;
    }
    
    return result;
}

- (TFYSSRuleMatchResult)matchURL:(NSURL *)url {
    if (!url) {
        return TFYSSRuleMatchResultNone;
    }
    
    TFYSSRuleSet *matchingRuleSet = nil;
    TFYSSRule *matchingRule = nil;
    TFYSSRuleMatchResult result = TFYSSRuleMatchResultNone;
    
    // 遍历所有启用的规则集
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if (!ruleSet.enabled) {
            continue;
        }
        
        TFYSSRule *rule = [ruleSet matchingRuleForURL:url];
        if (rule) {
            matchingRuleSet = ruleSet;
            matchingRule = rule;
            result = [ruleSet matchURL:url];
            break;
        }
    }
    
    // 如果没有匹配的规则，默认使用代理
    if (result == TFYSSRuleMatchResultNone) {
        result = TFYSSRuleMatchResultProxy;
    }
    
    return result;
}

- (nullable TFYSSRuleSet *)matchingRuleSetForHost:(NSString *)host {
    if (!host || host.length == 0) {
        return nil;
    }
    
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if (!ruleSet.enabled) {
            continue;
        }
        
        TFYSSRule *rule = [ruleSet matchingRuleForHost:host];
        if (rule) {
            return ruleSet;
        }
    }
    
    return nil;
}

- (nullable TFYSSRuleSet *)matchingRuleSetForIP:(NSString *)ip {
    if (!ip || ip.length == 0) {
        return nil;
    }
    
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if (!ruleSet.enabled) {
            continue;
        }
        
        TFYSSRule *rule = [ruleSet matchingRuleForIP:ip];
        if (rule) {
            return ruleSet;
        }
    }
    
    return nil;
}

- (nullable TFYSSRuleSet *)matchingRuleSetForURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        if (!ruleSet.enabled) {
            continue;
        }
        
        TFYSSRule *rule = [ruleSet matchingRuleForURL:url];
        if (rule) {
            return ruleSet;
        }
    }
    
    return nil;
}

#pragma mark - File Operations

- (BOOL)loadRuleSetsFromDirectory:(NSString *)directory error:(NSError **)error {
    if (!directory || directory.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleManagerErrorDomain" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid directory path"}];
        }
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directory]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleManagerErrorDomain" 
                                         code:2 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Directory does not exist"}];
        }
        return NO;
    }
    
    NSArray *fileURLs = [fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directory] 
                                   includingPropertiesForKeys:nil 
                                                      options:NSDirectoryEnumerationSkipsHiddenFiles 
                                                        error:error];
    if (!fileURLs) {
        return NO;
    }
    
    [_mutableRuleSets removeAllObjects];
    
    BOOL success = YES;
    for (NSURL *fileURL in fileURLs) {
        if ([[fileURL pathExtension] isEqualToString:@"json"]) {
            NSError *loadError = nil;
            TFYSSRuleSet *ruleSet = [[TFYSSRuleSet alloc] init];
            if ([ruleSet loadFromFile:fileURL.path error:&loadError]) {
                [_mutableRuleSets addObject:ruleSet];
            } else {
                NSLog(@"Failed to load rule set from %@: %@", fileURL.path, loadError);
                success = NO;
            }
        }
    }
    
    return success;
}

- (BOOL)saveRuleSetsToDirectory:(NSString *)directory error:(NSError **)error {
    if (!directory || directory.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleManagerErrorDomain" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid directory path"}];
        }
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directory]) {
        NSError *createError = nil;
        if (![fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&createError]) {
            if (error) {
                *error = createError;
            }
            return NO;
        }
    }
    
    BOOL success = YES;
    for (TFYSSRuleSet *ruleSet in _mutableRuleSets) {
        NSString *fileName = [NSString stringWithFormat:@"%@.json", ruleSet.name];
        NSString *filePath = [directory stringByAppendingPathComponent:fileName];
        
        NSError *saveError = nil;
        if (![ruleSet saveToFile:filePath error:&saveError]) {
            NSLog(@"Failed to save rule set %@ to %@: %@", ruleSet.name, filePath, saveError);
            success = NO;
            
            if (error && !*error) {
                *error = saveError;
            }
        }
    }
    
    return success;
}

- (BOOL)importRuleSetFromFile:(NSString *)filePath error:(NSError **)error {
    if (!filePath || filePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleManagerErrorDomain" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid file path"}];
        }
        return NO;
    }
    
    TFYSSRuleSet *ruleSet = [[TFYSSRuleSet alloc] init];
    if (![ruleSet loadFromFile:filePath error:error]) {
        return NO;
    }
    
    [self addRuleSet:ruleSet];
    return YES;
}

- (BOOL)exportRuleSet:(TFYSSRuleSet *)ruleSet toFile:(NSString *)filePath error:(NSError **)error {
    if (!ruleSet) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleManagerErrorDomain" 
                                         code:3 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid rule set"}];
        }
        return NO;
    }
    
    if (!filePath || filePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleManagerErrorDomain" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid file path"}];
        }
        return NO;
    }
    
    return [ruleSet saveToFile:filePath error:error];
}

#pragma mark - Default Rule Sets

- (TFYSSRuleSet *)createDefaultGFWListRuleSet {
    TFYSSRuleSet *ruleSet = [[TFYSSRuleSet alloc] initWithName:@"GFWList" type:TFYSSRuleSetTypeBlacklist];
    ruleSet.description = @"中国大陆防火墙屏蔽网站列表";
    
    // 添加一些常见的被屏蔽网站规则
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".google.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Google" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".youtube.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"YouTube" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".facebook.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Facebook" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".twitter.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Twitter" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".instagram.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Instagram" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".wikipedia.org" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Wikipedia" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".github.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"GitHub" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".medium.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Medium" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".dropbox.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Dropbox" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".telegram.org" type:TFYSSRuleTypeDomain action:TFYSSRuleActionProxy tag:@"Telegram" priority:100]];
    
    return ruleSet;
}

- (TFYSSRuleSet *)createDefaultChinaListRuleSet {
    TFYSSRuleSet *ruleSet = [[TFYSSRuleSet alloc] initWithName:@"ChinaList" type:TFYSSRuleSetTypeWhitelist];
    ruleSet.description = @"中国大陆网站列表";
    
    // 添加一些常见的中国大陆网站规则
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".baidu.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"百度" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".qq.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"腾讯" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".taobao.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"淘宝" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".jd.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"京东" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".163.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"网易" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".weibo.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"微博" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".alipay.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"支付宝" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".tmall.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"天猫" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".bilibili.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"哔哩哔哩" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".zhihu.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionDirect tag:@"知乎" priority:100]];
    
    return ruleSet;
}

- (TFYSSRuleSet *)createDefaultPrivacyRuleSet {
    TFYSSRuleSet *ruleSet = [[TFYSSRuleSet alloc] initWithName:@"Privacy" type:TFYSSRuleSetTypeCustom];
    ruleSet.description = @"隐私保护规则";
    
    // 添加一些隐私保护规则
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".doubleclick.net" type:TFYSSRuleTypeDomain action:TFYSSRuleActionReject tag:@"广告" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".googleadservices.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionReject tag:@"广告" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".googlesyndication.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionReject tag:@"广告" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".adnxs.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionReject tag:@"广告" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".adsrvr.org" type:TFYSSRuleTypeDomain action:TFYSSRuleActionReject tag:@"广告" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".scorecardresearch.com" type:TFYSSRuleTypeDomain action:TFYSSRuleActionReject tag:@"跟踪" priority:100]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".analytics" type:TFYSSRuleTypeKeyword action:TFYSSRuleActionReject tag:@"分析" priority:90]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".tracker" type:TFYSSRuleTypeKeyword action:TFYSSRuleActionReject tag:@"跟踪" priority:90]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".advert" type:TFYSSRuleTypeKeyword action:TFYSSRuleActionReject tag:@"广告" priority:90]];
    [ruleSet addRule:[[TFYSSRule alloc] initWithPattern:@".stats" type:TFYSSRuleTypeKeyword action:TFYSSRuleActionReject tag:@"统计" priority:90]];
    
    return ruleSet;
}

@end