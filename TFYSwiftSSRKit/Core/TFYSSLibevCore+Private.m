#import "TFYSSLibevCore+Private.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>

// 全局变量
int shadowsocks_errno = 0;
static void *ss_listener = NULL; // 用于跟踪 shadowsocks 的 listener
static ANCONN an_connection = NULL; // 用于跟踪 antinat 连接
static uint64_t ss_upload_traffic = 0; // 上传流量统计
static uint64_t ss_download_traffic = 0; // 下载流量统计

// 回调函数，用于获取 listener
static void ss_callback(int fd, void *data) {
    // 保存 listener（这里假设 data 就是 listener）
    ss_listener = data;
}

// 流量统计回调函数
static void ss_traffic_callback(uint64_t upload, uint64_t download) {
    ss_upload_traffic = upload;
    ss_download_traffic = download;
}

// shadowsocks 包装函数实现
int shadowsocks_init(void) {
    // 重置流量统计
    ss_upload_traffic = 0;
    ss_download_traffic = 0;
    return 0;
}

int shadowsocks_start(shadowsocks_config_t *config) {
    if (!config || !config->server || !config->local_addr || !config->method || !config->password) {
        return -2; // 无效配置
    }
    
    // 将我们的配置结构转换为shadowsocks库的profile_t结构
    profile_t profile;
    memset(&profile, 0, sizeof(profile_t)); // 确保结构体初始化为零
    
    profile.remote_host = (char *)config->server;
    profile.remote_port = config->server_port;
    profile.local_addr = (char *)config->local_addr;
    profile.local_port = config->local_port;
    profile.method = (char *)config->method;
    profile.password = (char *)config->password;
    profile.timeout = config->timeout;
    
    // 其他可选参数从config中获取，而不是使用硬编码的默认值
    profile.acl = (char *)config->acl;
    profile.log = (char *)config->log;
    profile.fast_open = config->fast_open;
    profile.mode = config->mode;
    profile.mtu = config->mtu;
    profile.mptcp = config->mptcp;
    profile.verbose = config->verbose;
    
    // 设置SSR特有字段
    profile.protocol = (char *)config->protocol;
    profile.obfs = (char *)config->obfs;
    profile.obfs_param = (char *)config->obfs_param;
    
    // 流量统计注意事项:
    // 在 shadowsocks.h 中没有定义 set_traffic_status_callback 函数
    // 根据项目设计，我们通过 ss_callback 回调函数获取到 ss_listener 后，
    // 可以在 shadowsocks_get_traffic 函数中实现流量统计的获取
    // 每次调用 shadowsocks_get_traffic 时，可通过 ss_listener 或其他方式获取当前流量
    
    // 调用shadowsocks库的函数，使用回调来获取listener
    return start_ss_local_server(profile, ss_callback, NULL);
}

void shadowsocks_stop(void) {
    // 调用 shadowsocks 库的停止函数
    if (ss_listener) {
        start_ss_local_server_stop(ss_listener);
        ss_listener = NULL;
    }
}

void shadowsocks_get_traffic(uint64_t *upload, uint64_t *download) {
    // 返回流量统计
    // 注意：由于 shadowsocks 库本身没有提供直接的流量统计接口
    // 这里使用全局变量来存储流量统计信息
    // 理想情况下，应该通过某种方式从 ss_listener 获取实时流量信息
    // 或者通过 API hook / 系统网络接口获取
    
    // 如果有需要，可以在这里添加实时获取流量的代码
    // 例如，通过查询系统网络接口、解析日志文件等方式
    
    if (upload) *upload = ss_upload_traffic;
    if (download) *download = ss_download_traffic;
}

const char *shadowsocks_version(void) {
    // 返回版本信息
    return "3.3.5"; // 替换为实际版本
}

const char *shadowsocks_strerror(int err) {
    // 返回错误描述
    switch (err) {
        case 0:
            return "Success";
        case -1:
            return "Failed to start local server";
        case -2:
            return "Invalid configuration";
        default:
            return "Unknown error";
    }
}

// antinat 包装函数实现
int antinat_init(void) {
    // 初始化 antinat
    // 检查是否已经有连接
    if (an_connection != NULL) {
        an_destroy(an_connection);
        an_connection = NULL;
    }
    
    // 创建新连接
    an_connection = an_new_connection();
    if (an_connection == NULL) {
        return AN_ERROR_NOMEM;
    }
    
    // 设置为非阻塞模式
    if (an_set_blocking(an_connection, AN_CONN_NONBLOCKING) != AN_ERROR_SUCCESS) {
        an_destroy(an_connection);
        an_connection = NULL;
        return AN_ERROR_NETWORK;
    }
    
    return AN_ERROR_SUCCESS;
}

int antinat_start(antinat_config_t *config) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER; // 需要先调用 antinat_init
    }
    
    // 设置代理服务器
    if (an_set_proxy(an_connection, AN_SERV_SOCKS5, AN_PF_INET, config->server, config->server_port) != AN_ERROR_SUCCESS) {
        return AN_ERROR_PROXY;
    }
    
    // 设置匿名认证
    if (an_set_authscheme(an_connection, AN_AUTH_ANON) != AN_ERROR_SUCCESS) {
        return AN_ERROR_AUTH;
    }
    
    return AN_ERROR_SUCCESS;
}

void antinat_stop(void) {
    // 停止 antinat 服务
    if (an_connection != NULL) {
        an_close(an_connection);
        an_destroy(an_connection);
        an_connection = NULL;
    }
}

int antinat_detect(antinat_info_t *info) {
    if (an_connection == NULL || info == NULL) {
        return AN_ERROR_INVALIDARG;
    }
    
    // 尝试连接到 STUN 服务器（这里使用 Google 的 STUN 服务器作为示例）
    if (an_connect_tohostname(an_connection, "stun.l.google.com", 19302) != AN_ERROR_SUCCESS) {
        return AN_ERROR_NETWORK;
    }
    
    // 获取对端信息
    struct sockaddr_in peer_addr;
    int peer_len = sizeof(peer_addr);
    if (an_getpeername(an_connection, (struct sockaddr *)&peer_addr, &peer_len) != AN_ERROR_SUCCESS) {
        return AN_ERROR_NETWORK;
    }
    
    // 获取本地信息
    struct sockaddr_in local_addr;
    int local_len = sizeof(local_addr);
    if (an_getsockname(an_connection, (struct sockaddr *)&local_addr, &local_len) != AN_ERROR_SUCCESS) {
        return AN_ERROR_NETWORK;
    }
    
    // 填充 NAT 信息
    // 这里简化处理，实际 NAT 类型检测需要更复杂的逻辑
    info->nat_type = TFYSSNATTypeFullCone; // 假设是完全锥形 NAT
    
    // 安全地处理IP地址，使用静态缓冲区以避免内存问题
    static char ip_buffer[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &peer_addr.sin_addr, ip_buffer, sizeof(ip_buffer));
    info->public_ip = ip_buffer;
    info->public_port = ntohs(peer_addr.sin_port);
    
    return AN_ERROR_SUCCESS;
}

// 新增 antinat 功能实现

// 设置认证凭据
int antinat_set_credentials(const char *username, const char *password) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_set_credentials(an_connection, username, password);
}

// 设置认证方案
int antinat_set_auth_scheme(unsigned int scheme) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_set_authscheme(an_connection, scheme);
}

// 清除所有认证方案
int antinat_clear_auth_schemes(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_clear_authschemes(an_connection);
}

// 通过主机名连接
int antinat_connect_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_connect_tohostname(an_connection, hostname, port);
}

// 通过 sockaddr 连接
int antinat_connect_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_connect_tosockaddr(an_connection, sa, sa_len);
}

// 通过主机名绑定
int antinat_bind_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_bind_tohostname(an_connection, hostname, port);
}

// 通过 sockaddr 绑定
int antinat_bind_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_bind_tosockaddr(an_connection, sa, sa_len);
}

// 监听连接
int antinat_listen(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_listen(an_connection);
}

// 接受连接
int antinat_accept(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_accept(an_connection, sa, sa_len);
}

// 发送数据
int antinat_send(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_send(an_connection, buf, len, flags);
}

// 接收数据
int antinat_recv(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_recv(an_connection, buf, len, flags);
}

// 获取对端名称
int antinat_getpeername(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_getpeername(an_connection, sa, sa_len);
}

// 获取套接字名称
int antinat_getsockname(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_getsockname(an_connection, sa, sa_len);
}

// 获取错误描述
const char *antinat_strerror(int err) {
    return an_geterror(err);
}

// 获取版本
unsigned int antinat_getversion(void) {
    return an_getversion();
}

// 解析主机名
int antinat_gethostbyname(const char *name, struct hostent *result, char *buf, int buflen) {
    struct hostent *ret;
    int error;
    return an_gethostbyname(name, result, buf, buflen, &ret, &error);
}

// 新增 antinat 直接连接功能

// 直接接受连接
int antinat_direct_accept(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_accept(an_connection, sa, sa_len);
}

// 直接通过主机名绑定
int antinat_direct_bind_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_bind_tohostname(an_connection, hostname, port);
}

// 直接通过 sockaddr 绑定
int antinat_direct_bind_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_bind_tosockaddr(an_connection, sa, sa_len);
}

// 直接通过主机名连接
int antinat_direct_connect_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_connect_tohostname(an_connection, hostname, port);
}

// 直接通过 sockaddr 连接
int antinat_direct_connect_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_connect_tosockaddr(an_connection, sa, sa_len);
}

// 直接关闭连接
int antinat_direct_close(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_close(an_connection);
}

// 直接获取对端名称
int antinat_direct_getpeername(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_getpeername(an_connection, sa, sa_len);
}

// 直接获取套接字名称
int antinat_direct_getsockname(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_getsockname(an_connection, sa, sa_len);
}

// 直接监听连接
int antinat_direct_listen(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_listen(an_connection);
}

// 直接发送数据
int antinat_direct_send(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_send(an_connection, buf, len, flags);
}

// 直接接收数据
int antinat_direct_recv(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_direct_recv(an_connection, buf, len, flags);
}

// 新增 antinat SOCKS4 功能

// SOCKS4 接受连接
int antinat_socks4_accept(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_accept(an_connection, sa, sa_len);
}

// SOCKS4 通过主机名绑定
int antinat_socks4_bind_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_bind_tohostname(an_connection, hostname, port);
}

// SOCKS4 通过 sockaddr 绑定
int antinat_socks4_bind_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_bind_tosockaddr(an_connection, sa, sa_len);
}

// SOCKS4 通过主机名连接
int antinat_socks4_connect_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_connect_tohostname(an_connection, hostname, port);
}

// SOCKS4 通过 sockaddr 连接
int antinat_socks4_connect_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_connect_tosockaddr(an_connection, sa, sa_len);
}

// SOCKS4 关闭连接
int antinat_socks4_close(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_close(an_connection);
}

// SOCKS4 获取对端名称
int antinat_socks4_getpeername(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_getpeername(an_connection, sa, sa_len);
}

// SOCKS4 获取套接字名称
int antinat_socks4_getsockname(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_getsockname(an_connection, sa, sa_len);
}

// SOCKS4 监听连接
int antinat_socks4_listen(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_listen(an_connection);
}

// SOCKS4 发送数据
int antinat_socks4_send(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_send(an_connection, buf, len, flags);
}

// SOCKS4 接收数据
int antinat_socks4_recv(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks4_recv(an_connection, buf, len, flags);
}

// 新增 antinat SOCKS5 功能

// SOCKS5 接受连接
int antinat_socks5_accept(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_accept(an_connection, sa, sa_len);
}

// SOCKS5 通过主机名绑定
int antinat_socks5_bind_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_bind_tohostname(an_connection, hostname, port);
}

// SOCKS5 通过 sockaddr 绑定
int antinat_socks5_bind_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_bind_tosockaddr(an_connection, sa, sa_len);
}

// SOCKS5 通过主机名连接
int antinat_socks5_connect_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_connect_tohostname(an_connection, hostname, port);
}

// SOCKS5 通过 sockaddr 连接
int antinat_socks5_connect_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_connect_tosockaddr(an_connection, sa, sa_len);
}

// SOCKS5 关闭连接
int antinat_socks5_close(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_close(an_connection);
}

// SOCKS5 获取对端名称
int antinat_socks5_getpeername(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_getpeername(an_connection, sa, sa_len);
}

// SOCKS5 获取套接字名称
int antinat_socks5_getsockname(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_getsockname(an_connection, sa, sa_len);
}

// SOCKS5 监听连接
int antinat_socks5_listen(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_listen(an_connection);
}

// SOCKS5 发送数据
int antinat_socks5_send(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_send(an_connection, buf, len, flags);
}

// SOCKS5 接收数据
int antinat_socks5_recv(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_socks5_recv(an_connection, buf, len, flags);
}

// 新增 antinat SSL 功能

// SSL 通过主机名连接
int antinat_ssl_connect_to_hostname(const char *hostname, unsigned short port) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_ssl_connect_tohostname(an_connection, hostname, port);
}

// SSL 通过 sockaddr 连接
int antinat_ssl_connect_to_sockaddr(struct sockaddr *sa, int sa_len) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_ssl_connect_tosockaddr(an_connection, sa, sa_len);
}

// SSL 关闭连接
int antinat_ssl_close(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_ssl_close(an_connection);
}

// SSL 发送数据
int antinat_ssl_send(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_ssl_send(an_connection, buf, len, flags);
}

// SSL 接收数据
int antinat_ssl_recv(void *buf, int len, int flags) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_ssl_recv(an_connection, buf, len, flags);
}

// 取消代理设置
int antinat_unset_proxy(void) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_unset_proxy(an_connection);
}

// 通过 URL 设置代理
int antinat_set_proxy_url(const char *url) {
    if (an_connection == NULL) {
        return AN_ERROR_ORDER;
    }
    
    return an_set_proxy_url(an_connection, url);
}

// fd_set 操作函数
void antinat_fd_clr(fd_set *fds) {
    if (an_connection != NULL) {
        AN_FD_CLR(an_connection, fds);
    }
}

int antinat_fd_set(fd_set *fds, int max_fd) {
    if (an_connection == NULL) {
        return max_fd;
    }
    
    return AN_FD_SET(an_connection, fds, max_fd);
}

int antinat_fd_isset(fd_set *fds) {
    if (an_connection == NULL) {
        return 0;
    }
    
    return AN_FD_ISSET(an_connection, fds);
}

// privoxy 包装函数实现 - 使用更新后的函数名
int ss_privoxy_init(void) {
    // 调用privoxy库的初始化函数，传递NULL参数表示使用默认配置
    return privoxy_init(NULL);
}

int ss_privoxy_start(privoxy_config_t *config) {
    if (!config || !config->socks5_address || !config->listen_address) {
        return -1; // 无效的参数
    }
    
    // 初始化 Privoxy（如果还没有初始化）
    if (privoxy_init(NULL) != 0) {
        return -3; // 初始化失败
    }
    
    // 创建一个简单的配置文件内容，指定 SOCKS5 代理
    char config_content[1024];
    snprintf(config_content, sizeof(config_content), 
             "forward-socks5 / %s:%d .\n"
             "listen-address %s:%d\n"
             "toggle-compression-inhibited 0\n"
             "enable-compression 0\n"
             "enable-remote-toggle 0\n"
             "enable-remote-http-toggle 0\n"
             "enable-edit-actions 0\n"
             "buffer-limit 4096\n"
             "connection-sharing 0\n"
             "socket-timeout 300\n"
             "max-client-connections 256\n"
             "handle-as-empty-doc-returns-ok 1\n"
             "enable-proxy-authentication-forwarding 0\n"
             "forwarded-connect-retries 0\n"
             "accept-intercepted-requests 0\n"
             "allow-cgi-request-crunching 0\n"
             "split-large-forms 0\n"
             "keep-alive-timeout 5\n"
             "tolerate-pipelining 1\n"
             "default-server-timeout 60\n"
             "debug 0\n",
             config->socks5_address, config->socks5_port,
             config->listen_address, config->listen_port);
    
    // 将配置内容写入临时文件
    char temp_file[] = "/tmp/privoxy_config_XXXXXX";
    int fd = mkstemp(temp_file);
    if (fd == -1) {
        return -1; // 创建临时文件失败
    }
    
    // 写入配置内容，并检查是否成功
    ssize_t bytes_written = write(fd, config_content, strlen(config_content));
    if (bytes_written == -1 || (size_t)bytes_written != strlen(config_content)) {
        close(fd);
        unlink(temp_file);
        return -2; // 写入配置失败
    }
    
    close(fd);
    
    // 启动 privoxy 服务，仅使用端口参数
    int init = privoxy_init(config);
    if ( init != 0) {
        return -1;
    }
    int result = privoxy_start(config->listen_port);
    
    // 删除临时文件
    unlink(temp_file);
    
    return result;
}

void ss_privoxy_stop(void) {
    // 停止privoxy服务
    privoxy_stop();
    privoxy_cleanup();
}

