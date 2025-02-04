#ifndef SHADOWSOCKS_H
#define SHADOWSOCKS_H

#ifdef __cplusplus
extern "C" {
#endif

// Shadowsocks configuration structure
typedef struct {
    const char* server;
    const char* server_port;
    const char* password;
    const char* method;
    const char* local_address;
    const char* local_port;
} shadowsocks_config;

#ifdef __cplusplus
}
#endif

#endif // SHADOWSOCKS_H
