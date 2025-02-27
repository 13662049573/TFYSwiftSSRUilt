#ifndef PRIVOXY_H_INCLUDED
#define PRIVOXY_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

/* Privoxy API */

/**
 * 初始化Privoxy
 * @return 成功返回0，失败返回非0值
 */
int privoxy_init(void);

/**
 * 启动Privoxy服务
 * @param port 监听端口
 * @param config_file 配置文件路径，如果为NULL则使用默认配置
 * @return 成功返回0，失败返回非0值
 */
int privoxy_start(int port, const char *config_file);

/**
 * 停止Privoxy服务
 * @return 成功返回0，失败返回非0值
 */
int privoxy_stop(void);

/**
 * 添加过滤规则
 * @param rule 规则字符串
 * @return 成功返回0，失败返回非0值
 */
int privoxy_add_filter(const char *rule);

/**
 * 移除过滤规则
 * @param rule 规则字符串
 * @return 成功返回0，失败返回非0值
 */
int privoxy_remove_filter(const char *rule);

/**
 * 清除所有过滤规则
 * @return 成功返回0，失败返回非0值
 */
int privoxy_clear_filters(void);

/**
 * 切换压缩功能
 * @param enabled 是否启用压缩
 * @return 成功返回0，失败返回非0值
 */
int privoxy_toggle_compression(int enabled);

/**
 * 切换过滤功能
 * @param enabled 是否启用过滤
 * @return 成功返回0，失败返回非0值
 */
int privoxy_toggle_filtering(int enabled);

/**
 * 获取Privoxy状态
 * @return 运行中返回1，未运行返回0
 */
int privoxy_get_status(void);

/**
 * 清理Privoxy资源
 */
void privoxy_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* PRIVOXY_H_INCLUDED */
