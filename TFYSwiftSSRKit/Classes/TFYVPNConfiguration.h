#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFYVPNConfiguration : NSObject

@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, assign) NSInteger serverPort;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *vpnName;
@property (nonatomic, assign) NEVPNProtocolType protocolType;
@property (nonatomic, copy, nullable) NSString *proxyServerAddress;
@property (nonatomic, assign) NSInteger proxyServerPort;

+ (instancetype)configurationWithServer:(NSString *)server
                                 port:(NSInteger)port
                            username:(NSString *)username
                            password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END 