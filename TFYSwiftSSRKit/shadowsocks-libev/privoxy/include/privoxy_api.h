/**
 * privoxy_api.h - Privoxy API内部头文件
 *
 * 这个文件声明privoxy_api.c中使用的内部函数和变量，
 * 仅供Privoxy内部使用，不对外暴露。
 */

#ifndef PRIVOXY_API_H
#define PRIVOXY_API_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <pthread.h>
#include <time.h>
#include <errno.h>
#include <stdint.h>
#include <stdbool.h>

#include "config.h"
#include "project.h"

/* 常量定义 */
#define DEFAULT_PRIVOXY_PORT 8118
#define MAX_CONFIG_ARGS 10

/* 全局变量声明 */
extern int privoxy_initialized;
extern int privoxy_running;
extern pthread_t privoxy_thread;
extern int config_port;
extern char *config_file_path;

/* 内部函数声明 */
static int get_privoxy_running_status(void);
static void set_privoxy_running_status(int running);
static void *privoxy_main_thread(void *data);

/* 对外API函数声明 - */

/**
 * @brief 初始化Privoxy服务
 * @param config_file_path 配置文件路径，如果为NULL则使用默认配置
 * @return 成功返回0，失败返回非0值
 */
int privoxy_init(const char *config_file_path);

/**
 * @brief 启动Privoxy服务
 * @param port 代理服务器端口号
 * @return 成功返回0，失败返回非0值
 */
int privoxy_start(uint16_t port);

/**
 * @brief 停止Privoxy服务
 * @return 成功返回0，失败返回非0值
 */
int privoxy_stop(void);

/**
 * @brief 清理Privoxy服务资源
 * @return 成功返回0，失败返回非0值
 */
int privoxy_cleanup(void);

/**
 * @brief 获取Privoxy服务状态
 * @return true表示服务正在运行，false表示服务已停止
 */
bool privoxy_is_running(void);

/**
 * @brief 设置Privoxy日志级别
 * @param level 日志级别（0-5，0表示禁用日志，5表示最详细）
 * @return 成功返回0，失败返回非0值
 */
int privoxy_set_log_level(int level);

/**
 * @brief 获取Privoxy版本信息
 * @return 版本字符串
 */
const char* privoxy_get_version(void);

/**
 * @brief 获取最后一次错误的描述
 * @return 错误描述字符串
 */
const char* privoxy_get_last_error(void);

#ifdef __cplusplus
}
#endif

#endif /* PRIVOXY_API_H */ 