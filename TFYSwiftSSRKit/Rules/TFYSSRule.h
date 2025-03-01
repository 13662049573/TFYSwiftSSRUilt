#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 规则类型
typedef NS_ENUM(NSInteger, TFYSSRuleType) {
    TFYSSRuleTypePattern = 0,    // 正则表达式模式
    TFYSSRuleTypeIPCIDR,         // IP CIDR 格式
    TFYSSRuleTypeDomain,         // 域名匹配
    TFYSSRuleTypeKeyword         // 关键词匹配
} NS_SWIFT_NAME(TFYRuleType);

// 规则动作
typedef NS_ENUM(NSInteger, TFYSSRuleAction) {
    TFYSSRuleActionProxy = 0,    // 使用代理
    TFYSSRuleActionDirect,       // 直接连接
    TFYSSRuleActionReject,       // 拒绝连接
    TFYSSRuleActionCustom        // 自定义动作
} NS_SWIFT_NAME(TFYRuleAction);

NS_SWIFT_NAME(TFYRule)
@interface TFYSSRule : NSObject

// 规则属性
@property (nonatomic, copy) NSString *pattern;           // 匹配模式
@property (nonatomic, assign) TFYSSRuleType type;        // 规则类型
@property (nonatomic, assign) TFYSSRuleAction action;    // 规则动作
@property (nonatomic, copy, nullable) NSString *tag;     // 规则标签
@property (nonatomic, assign) NSInteger priority;        // 规则优先级

// 初始化方法
- (instancetype)initWithPattern:(NSString *)pattern 
                          type:(TFYSSRuleType)type 
                        action:(TFYSSRuleAction)action NS_SWIFT_NAME(init(pattern:type:action:));

// 带标签的初始化方法
- (instancetype)initWithPattern:(NSString *)pattern 
                          type:(TFYSSRuleType)type 
                        action:(TFYSSRuleAction)action 
                           tag:(nullable NSString *)tag NS_SWIFT_NAME(init(pattern:type:action:tag:));

// 完整的初始化方法
- (instancetype)initWithPattern:(NSString *)pattern 
                          type:(TFYSSRuleType)type 
                        action:(TFYSSRuleAction)action 
                           tag:(nullable NSString *)tag 
                      priority:(NSInteger)priority NS_SWIFT_NAME(init(pattern:type:action:tag:priority:));

// 匹配方法
- (BOOL)matchesHost:(NSString *)host NS_SWIFT_NAME(matches(host:));
- (BOOL)matchesIP:(NSString *)ip NS_SWIFT_NAME(matches(ip:));
- (BOOL)matchesURL:(NSURL *)url NS_SWIFT_NAME(matches(url:));

// 转换方法
- (NSDictionary<NSString *, id> *)toJSON NS_SWIFT_NAME(toJSON());
+ (nullable instancetype)ruleWithJSON:(NSDictionary<NSString *, id> *)json NS_SWIFT_NAME(rule(json:));

@end

NS_ASSUME_NONNULL_END 