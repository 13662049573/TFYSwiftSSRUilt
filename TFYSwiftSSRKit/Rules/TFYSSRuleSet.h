#import <Foundation/Foundation.h>
#import "TFYSSRule.h"

NS_ASSUME_NONNULL_BEGIN

// 规则集类型
typedef NS_ENUM(NSInteger, TFYSSRuleSetType) {
    TFYSSRuleSetTypeBlacklist = 0,    // 黑名单模式
    TFYSSRuleSetTypeWhitelist,         // 白名单模式
    TFYSSRuleSetTypeCustom             // 自定义模式
} NS_SWIFT_NAME(TFYRuleSetType);

// 规则集匹配结果
typedef NS_ENUM(NSInteger, TFYSSRuleMatchResult) {
    TFYSSRuleMatchResultNone = 0,      // 无匹配
    TFYSSRuleMatchResultProxy,         // 使用代理
    TFYSSRuleMatchResultDirect,        // 直接连接
    TFYSSRuleMatchResultReject,        // 拒绝连接
    TFYSSRuleMatchResultCustom         // 自定义结果
} NS_SWIFT_NAME(TFYRuleMatchResult);

NS_SWIFT_NAME(TFYRuleSet)
@interface TFYSSRuleSet : NSObject

// 规则集属性
@property (nonatomic, copy) NSString *name;                  // 规则集名称
@property (nonatomic, assign) TFYSSRuleSetType type;         // 规则集类型
@property (nonatomic, readonly) NSArray<TFYSSRule *> *rules; // 规则列表
@property (nonatomic, assign) BOOL enabled;                  // 是否启用
@property (nonatomic, copy, nullable) NSString *description; // 规则集描述

// 初始化方法
- (instancetype)initWithName:(NSString *)name type:(TFYSSRuleSetType)type NS_SWIFT_NAME(init(name:type:));
- (instancetype)initWithName:(NSString *)name type:(TFYSSRuleSetType)type rules:(NSArray<TFYSSRule *> *)rules NS_SWIFT_NAME(init(name:type:rules:));

// 规则管理
- (void)addRule:(TFYSSRule *)rule NS_SWIFT_NAME(add(rule:));
- (void)removeRule:(TFYSSRule *)rule NS_SWIFT_NAME(remove(rule:));
- (void)removeRuleAtIndex:(NSUInteger)index NS_SWIFT_NAME(removeRule(at:));
- (void)clearRules NS_SWIFT_NAME(clearRules());
- (void)moveRuleAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex NS_SWIFT_NAME(moveRule(from:to:));

// 规则匹配
- (TFYSSRuleMatchResult)matchHost:(NSString *)host NS_SWIFT_NAME(match(host:));
- (TFYSSRuleMatchResult)matchIP:(NSString *)ip NS_SWIFT_NAME(match(ip:));
- (TFYSSRuleMatchResult)matchURL:(NSURL *)url NS_SWIFT_NAME(match(url:));

// 获取匹配的规则
- (nullable TFYSSRule *)matchingRuleForHost:(NSString *)host NS_SWIFT_NAME(matchingRule(for:));
- (nullable TFYSSRule *)matchingRuleForIP:(NSString *)ip NS_SWIFT_NAME(matchingRule(for:));
- (nullable TFYSSRule *)matchingRuleForURL:(NSURL *)url NS_SWIFT_NAME(matchingRule(for:));

// 文件操作
- (BOOL)loadFromFile:(NSString *)filePath error:(NSError **)error NS_SWIFT_NAME(load(from:));
- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error NS_SWIFT_NAME(save(to:));

// 转换方法
- (NSDictionary<NSString *, id> *)toJSON NS_SWIFT_NAME(toJSON());
+ (nullable instancetype)ruleSetWithJSON:(NSDictionary<NSString *, id> *)json NS_SWIFT_NAME(ruleSet(json:));

@end

NS_ASSUME_NONNULL_END 