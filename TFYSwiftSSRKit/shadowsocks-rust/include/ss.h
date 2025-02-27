#ifndef SS_H
#define SS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 初始化
void ss_init(void);

// 启动代理
// @param config JSON格式的配置
// @return 0表示成功,其他值表示错误码
int32_t ss_start(const char* config);

// 停止代理
void ss_stop(void);

// 获取版本号
const char* ss_get_version(void);

// 设置日志级别
// @param level 日志级别(0:error, 1:warn, 2:info, 3:debug, 4:trace)
void ss_set_log_level(int32_t level);

// 获取最后一次错误信息
const char* ss_get_last_error(void);

// 获取当前状态
// @return 0:已停止, 1:运行中, -1:错误
int32_t ss_get_state(void);

// 设置全局代理模式
// @param mode 0:PAC模式, 1:全局模式
void ss_set_mode(int32_t mode);

// 更新PAC规则
// @param rules PAC规则文本
// @return 0表示成功,其他值表示错误码
int32_t ss_update_pac(const char* rules);

// 获取当前流量统计
// @param upload 上传流量(字节)
// @param download 下载流量(字节)
void ss_get_traffic(uint64_t* upload, uint64_t* download);

#ifdef __cplusplus
}
#endif

#endif /* SS_H */
