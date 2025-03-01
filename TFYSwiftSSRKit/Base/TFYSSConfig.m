#import "TFYSSConfig.h"
#import "TFYSSError.h"

@implementation TFYSSConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _serverPort = 8388;
        _localPort = 1080;
        _timeout = 300;
        _method = @"aes-256-gcm";
        _localAddress = @"127.0.0.1";
        _preferredCoreType = TFYSSCoreTypeC;
        _enableNAT = NO;
        _enableHTTP = NO;
        _httpPort = 8118;
    }
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [self init];
    if (self) {
        if (json[@"server"]) _serverHost = json[@"server"];
        if (json[@"server_port"]) _serverPort = [json[@"server_port"] unsignedShortValue];
        if (json[@"local_port"]) _localPort = [json[@"local_port"] unsignedShortValue];
        if (json[@"password"]) _password = json[@"password"];
        if (json[@"method"]) _method = json[@"method"];
        if (json[@"timeout"]) _timeout = [json[@"timeout"] doubleValue];
        if (json[@"local_address"]) _localAddress = json[@"local_address"];
        if (json[@"core_type"]) _preferredCoreType = [json[@"core_type"] integerValue];
        if (json[@"enable_nat"]) _enableNAT = [json[@"enable_nat"] boolValue];
        if (json[@"enable_http"]) _enableHTTP = [json[@"enable_http"] boolValue];
        if (json[@"http_port"]) _httpPort = [json[@"http_port"] unsignedShortValue];
    }
    return self;
}

- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    if (_serverHost) json[@"server"] = _serverHost;
    json[@"server_port"] = @(_serverPort);
    json[@"local_port"] = @(_localPort);
    if (_password) json[@"password"] = _password;
    if (_method) json[@"method"] = _method;
    json[@"timeout"] = @(_timeout);
    if (_localAddress) json[@"local_address"] = _localAddress;
    json[@"core_type"] = @(_preferredCoreType);
    json[@"enable_nat"] = @(_enableNAT);
    json[@"enable_http"] = @(_enableHTTP);
    json[@"http_port"] = @(_httpPort);
    
    return [json copy];
}

- (BOOL)validate:(NSError **)error {
    if (!_serverHost.length) {
        if (error) {
            *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorConfigInvalid, @"Server address is required");
        }
        return NO;
    }
    
    if (!_password.length) {
        if (error) {
            *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorConfigInvalid, @"Password is required");
        }
        return NO;
    }
    
    if (!_method.length) {
        if (error) {
            *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorConfigInvalid, @"Encryption method is required");
        }
        return NO;
    }
    
    // 验证端口范围
    if (_serverPort == 0 || _serverPort > 65535) {
        if (error) {
            *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorConfigInvalid, @"Invalid server port");
        }
        return NO;
    }
    
    if (_localPort == 0 || _localPort > 65535) {
        if (error) {
            *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorConfigInvalid, @"Invalid local port");
        }
        return NO;
    }
    
    if (_enableHTTP && (_httpPort == 0 || _httpPort > 65535)) {
        if (error) {
            *error = TFYSSErrorWithCodeAndMessage(TFYSSErrorConfigInvalid, @"Invalid HTTP port");
        }
        return NO;
    }
    
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    TFYSSConfig *copy = [[TFYSSConfig alloc] init];
    copy.serverHost = [_serverHost copy];
    copy.serverPort = _serverPort;
    copy.localPort = _localPort;
    copy.password = [_password copy];
    copy.method = [_method copy];
    copy.timeout = _timeout;
    copy.localAddress = [_localAddress copy];
    copy.preferredCoreType = _preferredCoreType;
    copy.enableNAT = _enableNAT;
    copy.enableHTTP = _enableHTTP;
    copy.httpPort = _httpPort;
    return copy;
}

@end 