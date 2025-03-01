#import "TFYSSRuleSet.h"

@interface TFYSSRuleSet ()

@property (nonatomic, strong) NSMutableArray<TFYSSRule *> *mutableRules;

@end

@implementation TFYSSRuleSet

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _name = @"Default";
        _type = TFYSSRuleSetTypeBlacklist;
        _mutableRules = [NSMutableArray array];
        _enabled = YES;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name type:(TFYSSRuleSetType)type {
    self = [self init];
    if (self) {
        _name = [name copy];
        _type = type;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name type:(TFYSSRuleSetType)type rules:(NSArray<TFYSSRule *> *)rules {
    self = [self initWithName:name type:type];
    if (self) {
        [_mutableRules addObjectsFromArray:rules];
    }
    return self;
}

#pragma mark - Properties

- (NSArray<TFYSSRule *> *)rules {
    return [_mutableRules copy];
}

#pragma mark - Rule Management

- (void)addRule:(TFYSSRule *)rule {
    if (rule) {
        [_mutableRules addObject:rule];
        [self sortRules];
    }
}

- (void)removeRule:(TFYSSRule *)rule {
    if (rule) {
        [_mutableRules removeObject:rule];
    }
}

- (void)removeRuleAtIndex:(NSUInteger)index {
    if (index < _mutableRules.count) {
        [_mutableRules removeObjectAtIndex:index];
    }
}

- (void)clearRules {
    [_mutableRules removeAllObjects];
}

- (void)moveRuleAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (fromIndex < _mutableRules.count && toIndex < _mutableRules.count && fromIndex != toIndex) {
        TFYSSRule *rule = _mutableRules[fromIndex];
        [_mutableRules removeObjectAtIndex:fromIndex];
        
        if (fromIndex < toIndex) {
            [_mutableRules insertObject:rule atIndex:toIndex - 1];
        } else {
            [_mutableRules insertObject:rule atIndex:toIndex];
        }
    }
}

- (void)sortRules {
    [_mutableRules sortUsingComparator:^NSComparisonResult(TFYSSRule *rule1, TFYSSRule *rule2) {
        if (rule1.priority > rule2.priority) {
            return NSOrderedAscending;
        } else if (rule1.priority < rule2.priority) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
}

#pragma mark - Rule Matching

- (TFYSSRuleMatchResult)matchHost:(NSString *)host {
    TFYSSRule *rule = [self matchingRuleForHost:host];
    return [self resultForRule:rule];
}

- (TFYSSRuleMatchResult)matchIP:(NSString *)ip {
    TFYSSRule *rule = [self matchingRuleForIP:ip];
    return [self resultForRule:rule];
}

- (TFYSSRuleMatchResult)matchURL:(NSURL *)url {
    TFYSSRule *rule = [self matchingRuleForURL:url];
    return [self resultForRule:rule];
}

- (nullable TFYSSRule *)matchingRuleForHost:(NSString *)host {
    if (!host || host.length == 0 || !_enabled) {
        return nil;
    }
    
    for (TFYSSRule *rule in _mutableRules) {
        if ([rule matchesHost:host]) {
            return rule;
        }
    }
    
    return nil;
}

- (nullable TFYSSRule *)matchingRuleForIP:(NSString *)ip {
    if (!ip || ip.length == 0 || !_enabled) {
        return nil;
    }
    
    for (TFYSSRule *rule in _mutableRules) {
        if ([rule matchesIP:ip]) {
            return rule;
        }
    }
    
    return nil;
}

- (nullable TFYSSRule *)matchingRuleForURL:(NSURL *)url {
    if (!url || !_enabled) {
        return nil;
    }
    
    for (TFYSSRule *rule in _mutableRules) {
        if ([rule matchesURL:url]) {
            return rule;
        }
    }
    
    return nil;
}

- (TFYSSRuleMatchResult)resultForRule:(TFYSSRule *)rule {
    if (!rule) {
        // 如果没有匹配的规则，根据规则集类型返回默认结果
        switch (_type) {
            case TFYSSRuleSetTypeBlacklist:
                // 黑名单模式下，未匹配则使用代理
                return TFYSSRuleMatchResultProxy;
            case TFYSSRuleSetTypeWhitelist:
                // 白名单模式下，未匹配则直接连接
                return TFYSSRuleMatchResultDirect;
            case TFYSSRuleSetTypeCustom:
                // 自定义模式下，未匹配则无结果
                return TFYSSRuleMatchResultNone;
            default:
                return TFYSSRuleMatchResultNone;
        }
    }
    
    // 根据规则动作返回结果
    switch (rule.action) {
        case TFYSSRuleActionProxy:
            return TFYSSRuleMatchResultProxy;
        case TFYSSRuleActionDirect:
            return TFYSSRuleMatchResultDirect;
        case TFYSSRuleActionReject:
            return TFYSSRuleMatchResultReject;
        case TFYSSRuleActionCustom:
            return TFYSSRuleMatchResultCustom;
        default:
            return TFYSSRuleMatchResultNone;
    }
}

#pragma mark - File Operations

- (BOOL)loadFromFile:(NSString *)filePath error:(NSError **)error {
    if (!filePath || filePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleSetErrorDomain" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid file path"}];
        }
        return NO;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:error];
    if (!data) {
        return NO;
    }
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleSetErrorDomain" 
                                         code:2 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON format"}];
        }
        return NO;
    }
    
    TFYSSRuleSet *ruleSet = [TFYSSRuleSet ruleSetWithJSON:json];
    if (!ruleSet) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleSetErrorDomain" 
                                         code:3 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse rule set"}];
        }
        return NO;
    }
    
    self.name = ruleSet.name;
    self.type = ruleSet.type;
    self.enabled = ruleSet.enabled;
    self.description = ruleSet.description;
    [self.mutableRules removeAllObjects];
    [self.mutableRules addObjectsFromArray:ruleSet.rules];
    
    return YES;
}

- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error {
    if (!filePath || filePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TFYSSRuleSetErrorDomain" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid file path"}];
        }
        return NO;
    }
    
    NSDictionary *json = [self toJSON];
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:error];
    if (!data) {
        return NO;
    }
    
    return [data writeToFile:filePath options:NSDataWritingAtomic error:error];
}

#pragma mark - JSON Conversion

- (NSDictionary<NSString *, id> *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"name"] = self.name ?: @"";
    
    switch (self.type) {
        case TFYSSRuleSetTypeBlacklist:
            json[@"type"] = @"blacklist";
            break;
        case TFYSSRuleSetTypeWhitelist:
            json[@"type"] = @"whitelist";
            break;
        case TFYSSRuleSetTypeCustom:
            json[@"type"] = @"custom";
            break;
    }
    
    json[@"enabled"] = @(self.enabled);
    
    if (self.description) {
        json[@"description"] = self.description;
    }
    
    NSMutableArray *rulesArray = [NSMutableArray array];
    for (TFYSSRule *rule in self.mutableRules) {
        [rulesArray addObject:[rule toJSON]];
    }
    
    json[@"rules"] = rulesArray;
    
    return json;
}

+ (nullable instancetype)ruleSetWithJSON:(NSDictionary<NSString *, id> *)json {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSString *name = json[@"name"];
    if (![name isKindOfClass:[NSString class]]) {
        name = @"Default";
    }
    
    TFYSSRuleSetType type = TFYSSRuleSetTypeBlacklist;
    NSString *typeStr = json[@"type"];
    if ([typeStr isKindOfClass:[NSString class]]) {
        if ([typeStr isEqualToString:@"whitelist"]) {
            type = TFYSSRuleSetTypeWhitelist;
        } else if ([typeStr isEqualToString:@"custom"]) {
            type = TFYSSRuleSetTypeCustom;
        }
    }
    
    TFYSSRuleSet *ruleSet = [[TFYSSRuleSet alloc] initWithName:name type:type];
    
    if ([json[@"enabled"] isKindOfClass:[NSNumber class]]) {
        ruleSet.enabled = [json[@"enabled"] boolValue];
    }
    
    if ([json[@"description"] isKindOfClass:[NSString class]]) {
        ruleSet.description = json[@"description"];
    }
    
    NSArray *rulesArray = json[@"rules"];
    if ([rulesArray isKindOfClass:[NSArray class]]) {
        for (id ruleJSON in rulesArray) {
            if ([ruleJSON isKindOfClass:[NSDictionary class]]) {
                TFYSSRule *rule = [TFYSSRule ruleWithJSON:ruleJSON];
                if (rule) {
                    [ruleSet addRule:rule];
                }
            }
        }
    }
    
    return ruleSet;
}

@end 