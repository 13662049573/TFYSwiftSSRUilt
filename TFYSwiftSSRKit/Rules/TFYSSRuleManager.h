#import <Foundation/Foundation.h>
#import "TFYSSRuleSet.h"

NS_ASSUME_NONNULL_BEGIN

// 规则管理器代理协议
@protocol TFYSSRuleManagerDelegate;

NS_SWIFT_NAME(TFYRuleManager)
@interface TFYSSRuleManager : NSObject

// 单例方法
+ (instancetype)sharedManager NS_SWIFT_NAME(shared());

// 规则集管理
@property (nonatomic, readonly) NSArray<TFYSSRuleSet *> *ruleSets;
@property (nonatomic, weak) id<TFYSSRuleManagerDelegate> delegate;
@property (nonatomic, copy, nullable) NSString *rulesDirectory;

// 添加规则集
- (void)addRuleSet:(TFYSSRuleSet *)ruleSet NS_SWIFT_NAME(add(ruleSet:));

// 移除规则集
- (void)removeRuleSet:(TFYSSRuleSet *)ruleSet NS_SWIFT_NAME(remove(ruleSet:));
- (void)removeRuleSetAtIndex:(NSUInteger)index NS_SWIFT_NAME(removeRuleSet(at:));

// 获取规则集
- (nullable TFYSSRuleSet *)ruleSetWithName:(NSString *)name NS_SWIFT_NAME(ruleSet(withName:));
- (nullable TFYSSRuleSet *)ruleSetAtIndex:(NSUInteger)index NS_SWIFT_NAME(ruleSet(at:));

// 规则匹配
- (TFYSSRuleMatchResult)matchHost:(NSString *)host NS_SWIFT_NAME(match(host:));
- (TFYSSRuleMatchResult)matchIP:(NSString *)ip NS_SWIFT_NAME(match(ip:));
- (TFYSSRuleMatchResult)matchURL:(NSURL *)url NS_SWIFT_NAME(match(url:));

// 获取匹配的规则集和规则
- (nullable TFYSSRuleSet *)matchingRuleSetForHost:(NSString *)host NS_SWIFT_NAME(matchingRuleSet(for:));
- (nullable TFYSSRuleSet *)matchingRuleSetForIP:(NSString *)ip NS_SWIFT_NAME(matchingRuleSet(for:));
- (nullable TFYSSRuleSet *)matchingRuleSetForURL:(NSURL *)url NS_SWIFT_NAME(matchingRuleSet(for:));

// 文件操作
- (BOOL)loadRuleSetsFromDirectory:(NSString *)directory error:(NSError **)error NS_SWIFT_NAME(loadRuleSets(from:));
- (BOOL)saveRuleSetsToDirectory:(NSString *)directory error:(NSError **)error NS_SWIFT_NAME(saveRuleSets(to:));

// 导入导出
- (BOOL)importRuleSetFromFile:(NSString *)filePath error:(NSError **)error NS_SWIFT_NAME(importRuleSet(from:));
- (BOOL)exportRuleSet:(TFYSSRuleSet *)ruleSet toFile:(NSString *)filePath error:(NSError **)error NS_SWIFT_NAME(export(ruleSet:to:));

// 预设规则集
- (TFYSSRuleSet *)createDefaultGFWListRuleSet NS_SWIFT_NAME(createDefaultGFWListRuleSet());
- (TFYSSRuleSet *)createDefaultChinaListRuleSet NS_SWIFT_NAME(createDefaultChinaListRuleSet());
- (TFYSSRuleSet *)createDefaultPrivacyRuleSet NS_SWIFT_NAME(createDefaultPrivacyRuleSet());

@end

// 规则管理器代理协议
NS_SWIFT_NAME(TFYRuleManagerDelegate)
@protocol TFYSSRuleManagerDelegate <NSObject>

@optional
// 规则集变更通知
- (void)ruleManager:(TFYSSRuleManager *)manager didAddRuleSet:(TFYSSRuleSet *)ruleSet NS_SWIFT_NAME(ruleManager(_:didAdd:));
- (void)ruleManager:(TFYSSRuleManager *)manager didRemoveRuleSet:(TFYSSRuleSet *)ruleSet NS_SWIFT_NAME(ruleManager(_:didRemove:));
- (void)ruleManager:(TFYSSRuleManager *)manager didUpdateRuleSet:(TFYSSRuleSet *)ruleSet NS_SWIFT_NAME(ruleManager(_:didUpdate:));

// 规则匹配通知
- (void)ruleManager:(TFYSSRuleManager *)manager didMatchHost:(NSString *)host result:(TFYSSRuleMatchResult)result ruleSet:(nullable TFYSSRuleSet *)ruleSet rule:(nullable TFYSSRule *)rule NS_SWIFT_NAME(ruleManager(_:didMatch:result:ruleSet:rule:));

@end

NS_ASSUME_NONNULL_END 