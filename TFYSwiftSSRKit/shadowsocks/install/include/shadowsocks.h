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
    const char* timeout;
    const char* plugin;
    const char* plugin_opts;
} shadowsocks_config;

// Error codes
typedef enum {
    SHADOWSOCKS_OK = 0,
    SHADOWSOCKS_ERR_INVALID_CONFIG = -1,
    SHADOWSOCKS_ERR_MEMORY = -2,
    SHADOWSOCKS_ERR_NETWORK = -3,
    SHADOWSOCKS_ERR_PLUGIN = -4
} shadowsocks_err;

// Initialize shadowsocks with config
shadowsocks_err shadowsocks_init(const shadowsocks_config* config);

// Start the shadowsocks proxy
shadowsocks_err shadowsocks_start(void);

// Stop the shadowsocks proxy
void shadowsocks_stop(void);

// Cleanup and free resources
void shadowsocks_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif // SHADOWSOCKS_H
