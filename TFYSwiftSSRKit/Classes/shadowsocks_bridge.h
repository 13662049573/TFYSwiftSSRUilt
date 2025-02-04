#ifndef shadowsocks_bridge_h
#define shadowsocks_bridge_h

#include <stdio.h>
#include <string.h>
#include "shadowsocks.h"

// 定义profile_t结构体
typedef struct {
    char *remote_host;
    unsigned short remote_port;
    char *local_addr;
    unsigned short local_port;
    char *password;
    char *method;
    int timeout;
    int fast_open;
    int mode;
    int mtu;
    int mptcp;
} profile_t;

// 声明Shadowsocks函数
#ifdef __cplusplus
extern "C" {
#endif

// 初始化函数
void ss_init(void);

// 启动本地服务器
int start_ss_local_server(profile_t *profile);

// 停止本地服务器
void stop_ss_local_server(void);

// 字符串转换工具函数
static inline char* strdup_safe(const char* str) {
    return str ? strdup(str) : NULL;
}

#ifdef __cplusplus
}
#endif

#endif /* shadowsocks_bridge_h */ 