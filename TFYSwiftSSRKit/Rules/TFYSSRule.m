#import "TFYSSRule.h"
#import <regex.h>

@interface TFYSSRule () {
    regex_t _regex;
    BOOL _regexCompiled;
}

@end

@implementation TFYSSRule

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = TFYSSRuleTypePattern;
        _action = TFYSSRuleActionProxy;
        _priority = 0;
        _regexCompiled = NO;
    }
    return self;
}

- (instancetype)initWithPattern:(NSString *)pattern type:(TFYSSRuleType)type action:(TFYSSRuleAction)action {
    return [self initWithPattern:pattern type:type action:action tag:nil priority:0];
}

- (instancetype)initWithPattern:(NSString *)pattern type:(TFYSSRuleType)type action:(TFYSSRuleAction)action tag:(NSString *)tag {
    return [self initWithPattern:pattern type:type action:action tag:tag priority:0];
}

- (instancetype)initWithPattern:(NSString *)pattern type:(TFYSSRuleType)type action:(TFYSSRuleAction)action tag:(NSString *)tag priority:(NSInteger)priority {
    self = [self init];
    if (self) {
        _pattern = [pattern copy];
        _type = type;
        _action = action;
        _tag = [tag copy];
        _priority = priority;
        
        // 如果是正则表达式类型，预编译正则表达式
        if (type == TFYSSRuleTypePattern) {
            [self compileRegex];
        }
    }
    return self;
}

- (void)dealloc {
    if (_regexCompiled) {
        regfree(&_regex);
    }
}

#pragma mark - Private Methods

- (void)compileRegex {
    if (_regexCompiled) {
        regfree(&_regex);
        _regexCompiled = NO;
    }
    
    if (_pattern.length == 0) {
        return;
    }
    
    int result = regcomp(&_regex, [_pattern UTF8String], REG_EXTENDED | REG_NOSUB);
    if (result == 0) {
        _regexCompiled = YES;
    } else {
        char errorBuffer[100];
        regerror(result, &_regex, errorBuffer, sizeof(errorBuffer));
        NSLog(@"Failed to compile regex pattern '%@': %s", _pattern, errorBuffer);
    }
}

- (BOOL)matchRegex:(NSString *)string {
    if (!_regexCompiled || string.length == 0) {
        return NO;
    }
    
    int result = regexec(&_regex, [string UTF8String], 0, NULL, 0);
    return result == 0;
}

- (BOOL)matchDomain:(NSString *)domain {
    if (_pattern.length == 0 || domain.length == 0) {
        return NO;
    }
    
    // 完全匹配
    if ([_pattern isEqualToString:domain]) {
        return YES;
    }
    
    // 子域名匹配 (.example.com 匹配 sub.example.com)
    if ([_pattern hasPrefix:@"."]) {
        NSString *suffix = [_pattern substringFromIndex:1];
        return [domain hasSuffix:suffix];
    }
    
    // 前缀匹配 (example.* 匹配 example.com)
    if ([_pattern hasSuffix:@".*"]) {
        NSString *prefix = [_pattern substringToIndex:_pattern.length - 2];
        return [domain hasPrefix:prefix];
    }
    
    return NO;
}

- (BOOL)matchKeyword:(NSString *)string {
    if (_pattern.length == 0 || string.length == 0) {
        return NO;
    }
    
    return [string containsString:_pattern];
}

- (BOOL)matchIPCIDR:(NSString *)ip {
    // 简单实现，实际应该使用 IP 库进行 CIDR 匹配
    if ([_pattern isEqualToString:ip]) {
        return YES;
    }
    
    // 如果是 CIDR 格式 (如 192.168.1.0/24)，需要进行网段匹配
    // 这里简化处理，实际应该使用专门的 IP 库
    if ([_pattern containsString:@"/"]) {
        NSArray<NSString *> *parts = [_pattern componentsSeparatedByString:@"/"];
        if (parts.count == 2) {
            NSString *baseIP = parts[0];
            NSInteger prefix = [parts[1] integerValue];
            
            // 简单实现，只检查 IP 前缀是否匹配
            // 实际应该进行完整的 CIDR 匹配
            NSArray<NSString *> *ipParts = [ip componentsSeparatedByString:@"."];
            NSArray<NSString *> *baseParts = [baseIP componentsSeparatedByString:@"."];
            
            if (ipParts.count == 4 && baseParts.count == 4) {
                NSInteger matchBytes = prefix / 8;
                for (NSInteger i = 0; i < matchBytes && i < 4; i++) {
                    if (![ipParts[i] isEqualToString:baseParts[i]]) {
                        return NO;
                    }
                }
                
                // 如果有部分位需要匹配
                if (prefix % 8 != 0 && matchBytes < 4) {
                    NSInteger ipByte = [ipParts[matchBytes] integerValue];
                    NSInteger baseByte = [baseParts[matchBytes] integerValue];
                    NSInteger mask = 0xFF << (8 - (prefix % 8));
                    
                    if ((ipByte & mask) != (baseByte & mask)) {
                        return NO;
                    }
                }
                
                return YES;
            }
        }
    }
    
    return NO;
}

#pragma mark - Public Methods

- (void)setPattern:(NSString *)pattern {
    if (![_pattern isEqualToString:pattern]) {
        _pattern = [pattern copy];
        if (_type == TFYSSRuleTypePattern) {
            [self compileRegex];
        }
    }
}

- (void)setType:(TFYSSRuleType)type {
    if (_type != type) {
        _type = type;
        if (_type == TFYSSRuleTypePattern) {
            [self compileRegex];
        }
    }
}

- (BOOL)matchesHost:(NSString *)host {
    if (host.length == 0) {
        return NO;
    }
    
    switch (_type) {
        case TFYSSRuleTypePattern:
            return [self matchRegex:host];
        case TFYSSRuleTypeDomain:
            return [self matchDomain:host];
        case TFYSSRuleTypeKeyword:
            return [self matchKeyword:host];
        case TFYSSRuleTypeIPCIDR:
            return [self matchIPCIDR:host];
        default:
            return NO;
    }
}

- (BOOL)matchesIP:(NSString *)ip {
    if (ip.length == 0) {
        return NO;
    }
    
    if (_type == TFYSSRuleTypeIPCIDR) {
        return [self matchIPCIDR:ip];
    } else if (_type == TFYSSRuleTypePattern) {
        return [self matchRegex:ip];
    }
    
    return NO;
}

- (BOOL)matchesURL:(NSURL *)url {
    if (!url) {
        return NO;
    }
    
    NSString *host = url.host;
    if (host.length == 0) {
        return NO;
    }
    
    // 先匹配主机名
    if ([self matchesHost:host]) {
        return YES;
    }
    
    // 如果是关键词类型，也匹配完整 URL
    if (_type == TFYSSRuleTypeKeyword || _type == TFYSSRuleTypePattern) {
        NSString *absoluteString = url.absoluteString;
        if (absoluteString.length > 0) {
            if (_type == TFYSSRuleTypeKeyword) {
                return [self matchKeyword:absoluteString];
            } else {
                return [self matchRegex:absoluteString];
            }
        }
    }
    
    return NO;
}

#pragma mark - JSON Conversion

- (NSDictionary<NSString *, id> *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"pattern"] = _pattern ?: @"";
    
    switch (_type) {
        case TFYSSRuleTypePattern:
            json[@"type"] = @"pattern";
            break;
        case TFYSSRuleTypeIPCIDR:
            json[@"type"] = @"ipcidr";
            break;
        case TFYSSRuleTypeDomain:
            json[@"type"] = @"domain";
            break;
        case TFYSSRuleTypeKeyword:
            json[@"type"] = @"keyword";
            break;
    }
    
    switch (_action) {
        case TFYSSRuleActionProxy:
            json[@"action"] = @"proxy";
            break;
        case TFYSSRuleActionDirect:
            json[@"action"] = @"direct";
            break;
        case TFYSSRuleActionReject:
            json[@"action"] = @"reject";
            break;
        case TFYSSRuleActionCustom:
            json[@"action"] = @"custom";
            break;
    }
    
    if (_tag) {
        json[@"tag"] = _tag;
    }
    
    json[@"priority"] = @(_priority);
    
    return json;
}

+ (nullable instancetype)ruleWithJSON:(NSDictionary<NSString *, id> *)json {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSString *pattern = json[@"pattern"];
    if (![pattern isKindOfClass:[NSString class]] || pattern.length == 0) {
        return nil;
    }
    
    TFYSSRuleType type = TFYSSRuleTypePattern;
    NSString *typeStr = json[@"type"];
    if ([typeStr isKindOfClass:[NSString class]]) {
        if ([typeStr isEqualToString:@"ipcidr"]) {
            type = TFYSSRuleTypeIPCIDR;
        } else if ([typeStr isEqualToString:@"domain"]) {
            type = TFYSSRuleTypeDomain;
        } else if ([typeStr isEqualToString:@"keyword"]) {
            type = TFYSSRuleTypeKeyword;
        }
    }
    
    TFYSSRuleAction action = TFYSSRuleActionProxy;
    NSString *actionStr = json[@"action"];
    if ([actionStr isKindOfClass:[NSString class]]) {
        if ([actionStr isEqualToString:@"direct"]) {
            action = TFYSSRuleActionDirect;
        } else if ([actionStr isEqualToString:@"reject"]) {
            action = TFYSSRuleActionReject;
        } else if ([actionStr isEqualToString:@"custom"]) {
            action = TFYSSRuleActionCustom;
        }
    }
    
    NSString *tag = nil;
    if ([json[@"tag"] isKindOfClass:[NSString class]]) {
        tag = json[@"tag"];
    }
    
    NSInteger priority = 0;
    if ([json[@"priority"] isKindOfClass:[NSNumber class]]) {
        priority = [json[@"priority"] integerValue];
    }
    
    return [[TFYSSRule alloc] initWithPattern:pattern type:type action:action tag:tag priority:priority];
}

@end 