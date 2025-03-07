#ifndef TFYSSLibevCore_Private_h
#define TFYSSLibevCore_Private_h

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import "TFYSSTypes.h"
#else
#include <Foundation/Foundation.h>
#include "TFYSSTypes.h"
#endif
#include <stdio.h>
#include <stdint.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

// 定义 Libev 核心类型
#define TFYSSCoreTypeLibev 2    // Libev 核心实现

// Define sodium.h path to resolve include issues
#define SODIUM_H "../shadowsocks-libev/libsodium/include/sodium.h"

// 添加 libsodium 的包含路径
#include SODIUM_H

// 包含 shadowsocks-libev 的头文件
#include "../shadowsocks-libev/shadowsocks/include/shadowsocks-libev.h"
#include "../shadowsocks-libev/antinat/include/antinat.h"
#include "../shadowsocks-libev/privoxy/include/privoxy_api.h"

// shadowsocks 配置结构
typedef struct {
    const char *server;          // hostname or ip of remote server
    int server_port;             // port number of remote server
    const char *local_addr;      // local ip to bind
    int local_port;              // port number of local server
    const char *method;          // encryption method
    const char *password;        // password of remote server
    int timeout;                 // connection timeout
    
    // Optional fields
    const char *acl;             // file path to acl
    const char *log;             // file path to log
    int fast_open;               // enable tcp fast open
    int mode;                    // enable udp relay
    int mtu;                     // MTU of interface
    int mptcp;                   // enable multipath TCP
    int verbose;                 // verbose mode
    
    // SSR specific fields
    const char *protocol;        // SSR protocol
    const char *obfs;            // SSR obfuscation
    const char *obfs_param;      // SSR obfuscation parameter
} shadowsocks_config_t;

// 声明全局错误码
extern int shadowsocks_errno;

// antinat 配置结构
typedef struct {
    const char *server;
    int server_port;
} antinat_config_t;

// NAT 信息结构
typedef struct {
    TFYSSNATType nat_type;
    const char *public_ip;
    int public_port;
} antinat_info_t;

// privoxy 配置结构
typedef struct {
    const char *socks5_address;
    int socks5_port;
    const char *listen_address;
    int listen_port;
} privoxy_config_t;

// shadowsocks 函数声明
int shadowsocks_init(void);
int shadowsocks_start(shadowsocks_config_t *config);
void shadowsocks_stop(void);
void shadowsocks_get_traffic(uint64_t *upload, uint64_t *download);
const char *shadowsocks_version(void);
const char *shadowsocks_strerror(int err);

// antinat 函数声明
int antinat_init(void);
int antinat_start(antinat_config_t *config);
void antinat_stop(void);
int antinat_detect(antinat_info_t *info);

// 新增 antinat 函数声明
int antinat_set_credentials(const char *username, const char *password);
int antinat_set_auth_scheme(unsigned int scheme);
int antinat_clear_auth_schemes(void);
int antinat_connect_tohostname(const char *hostname, unsigned short port);
int antinat_connect_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_bind_tohostname(const char *hostname, unsigned short port);
int antinat_bind_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_listen(void);
int antinat_accept(struct sockaddr *sa, int sa_len);
int antinat_send(void *buf, int len, int flags);
int antinat_recv(void *buf, int len, int flags);
int antinat_getpeername(struct sockaddr *sa, int sa_len);
int antinat_getsockname(struct sockaddr *sa, int sa_len);
const char *antinat_strerror(int err);
unsigned int antinat_getversion(void);
int antinat_gethostbyname(const char *name, struct hostent *result, char *buf, int buflen);

// 新增 antinat 直接连接函数声明
int antinat_direct_accept(struct sockaddr *sa, int sa_len);
int antinat_direct_bind_tohostname(const char *hostname, unsigned short port);
int antinat_direct_bind_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_direct_connect_tohostname(const char *hostname, unsigned short port);
int antinat_direct_connect_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_direct_close(void);
int antinat_direct_getpeername(struct sockaddr *sa, int sa_len);
int antinat_direct_getsockname(struct sockaddr *sa, int sa_len);
int antinat_direct_listen(void);
int antinat_direct_send(void *buf, int len, int flags);
int antinat_direct_recv(void *buf, int len, int flags);

// 新增 antinat SOCKS4 函数声明
int antinat_socks4_accept(struct sockaddr *sa, int sa_len);
int antinat_socks4_bind_tohostname(const char *hostname, unsigned short port);
int antinat_socks4_bind_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_socks4_connect_tohostname(const char *hostname, unsigned short port);
int antinat_socks4_connect_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_socks4_close(void);
int antinat_socks4_getpeername(struct sockaddr *sa, int sa_len);
int antinat_socks4_getsockname(struct sockaddr *sa, int sa_len);
int antinat_socks4_listen(void);
int antinat_socks4_send(void *buf, int len, int flags);
int antinat_socks4_recv(void *buf, int len, int flags);

// 新增 antinat SOCKS5 函数声明
int antinat_socks5_accept(struct sockaddr *sa, int sa_len);
int antinat_socks5_bind_tohostname(const char *hostname, unsigned short port);
int antinat_socks5_bind_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_socks5_connect_tohostname(const char *hostname, unsigned short port);
int antinat_socks5_connect_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_socks5_close(void);
int antinat_socks5_getpeername(struct sockaddr *sa, int sa_len);
int antinat_socks5_getsockname(struct sockaddr *sa, int sa_len);
int antinat_socks5_listen(void);
int antinat_socks5_send(void *buf, int len, int flags);
int antinat_socks5_recv(void *buf, int len, int flags);

// 新增 antinat SSL 函数声明
int antinat_ssl_connect_tohostname(const char *hostname, unsigned short port);
int antinat_ssl_connect_tosockaddr(struct sockaddr *sa, int sa_len);
int antinat_ssl_close(void);
int antinat_ssl_send(void *buf, int len, int flags);
int antinat_ssl_recv(void *buf, int len, int flags);

// 新增 antinat 其他函数声明
int antinat_unset_proxy(void);
int antinat_set_proxy_url(const char *url);
void antinat_fd_clr(fd_set *fds);
int antinat_fd_set(fd_set *fds, int max_fd);
int antinat_fd_isset(fd_set *fds);

// privoxy 函数声明
int ss_privoxy_start(privoxy_config_t *config);
void ss_privoxy_stop(void);

#endif /* TFYSSLibevCore_Private_h */
