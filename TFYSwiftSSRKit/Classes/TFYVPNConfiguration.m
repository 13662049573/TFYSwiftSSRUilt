#import "TFYVPNConfiguration.h"

@implementation TFYVPNConfiguration

+ (instancetype)configurationWithServer:(NSString *)server
                                 port:(NSInteger)port
                            username:(NSString *)username
                            password:(NSString *)password {
    TFYVPNConfiguration *config = [[TFYVPNConfiguration alloc] init];
    config.serverAddress = server;
    config.serverPort = port;
    config.username = username;
    config.password = password;
    config.vpnName = @"TFY VPN";
    config.protocolType = NEVPNProtocolTypeIPSec;
    return config;
}

@end 