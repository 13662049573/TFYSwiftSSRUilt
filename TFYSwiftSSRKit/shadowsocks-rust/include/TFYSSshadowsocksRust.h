/**
 * Shadowsocks-Rust C API
 * 由TFYSSRRust自动生成
 * 
 * 此头文件基于 shadowsocks-rust-master/src/lib.rs 中的 C FFI 接口实现
 * 支持复杂的配置选项，包括多服务器、多本地端口、各种协议等
 */

#ifndef TFYSSshadowsocksRust_H
#define TFYSSshadowsocksRust_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>

/**
 * 初始化Shadowsocks
 * @param config_json JSON格式的配置字符串，包含服务器信息、加密方法、密码等
 *                   支持完整的Shadowsocks-Rust配置格式，包括多服务器、多本地端口、
 *                   各种协议(SOCKS5/HTTP/Tunnel/DNS/Redir/Tun/FakeDNS)等
 * @return 成功返回0，失败返回-1
 */
int ss_init(const char* config_json);

/**
 * 启动Shadowsocks服务
 * 必须在调用 ss_init 之后调用
 * @return 成功返回0，失败返回-1
 */
int ss_start(void);

/**
 * 停止Shadowsocks服务
 * @return 成功返回0，服务未启动或停止失败返回-1
 */
int ss_stop(void);

/**
 * 获取版本信息
 * @return 版本字符串，不需要释放
 */
const char* ss_get_version(void);

/**
 * 设置日志级别
 * @param level 日志级别（0:禁用, 1:错误, 2:警告, 3:信息, 4:调试, 5:跟踪）
 * @note 只有在编译时启用logging特性时此函数才有效
 */
void ss_set_log_level(int level);

/**
 * 获取最后一次错误信息
 * @return 错误信息字符串，不需要释放
 */
const char* ss_get_last_error(void);

/**
 * 获取当前状态
 * @return 状态码（0:停止, 1:启动中, 2:运行中, 3:错误）
 */
int ss_get_state(void);

/**
 * 设置代理模式
 * @param mode 代理模式（0:全局, 1:PAC）
 * @return 成功返回0，失败返回-1。服务未运行时返回-1。
 */
int ss_set_mode(int mode);

/**
 * 更新PAC文件
 * @param pac_url PAC文件URL
 * @return 成功返回0，失败返回-1。服务未运行时返回-1。
 */
int ss_update_pac(const char* pac_url);

/**
 * 获取流量统计信息
 * @param rx 接收字节数指针，不能为NULL
 * @param tx 发送字节数指针，不能为NULL
 * @return 成功返回0，失败返回-1。服务未运行时返回-1。
 */
int ss_get_traffic(uint64_t* rx, uint64_t* tx);

#ifdef __cplusplus
}
#endif

#endif /* TFYSSshadowsocksRust_H */
