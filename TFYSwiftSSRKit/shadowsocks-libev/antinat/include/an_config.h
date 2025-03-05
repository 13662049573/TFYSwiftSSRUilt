/* an_config.h for AntiNAT - iOS/macOS 编译配置 */
#ifndef AN_CONFIG_H_INCLUDED
#define AN_CONFIG_H_INCLUDED

/* 确保socklen_t类型可用 */
#include <sys/socket.h>

/* 基本定义 */
#define VERSION "0.90"
#define PACKAGE "antinat"

/* 系统特性检测 */
#define HAVE_ARPA_INET_H 1
#define HAVE_ERRNO_H 1
#define HAVE_FCNTL_H 1
#define HAVE_NETDB_H 1
#define HAVE_NETINET_IN_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_SOCKET_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_STDIO_H 1
#define HAVE_CTYPE_H 1
#define HAVE_PTHREAD_H 1

/* 功能定义 */
#define WRAP_GETHOSTBYNAME 1  /* 设置为1表示我们需要包装gethostbyname */
#define HAVE_GETHOSTBYNAME_R 0
#define HAVE_PTHREAD 1
#define HAVE_PTHREAD_ATTR_SETDETACHSTATE 1
#define HAVE_GETPWNAM 1
#define HAVE_CRYPT 0
#define HAVE_CRYPT_R 0

/* iOS/macOS 特定定义 */
#define unix 1
#define __unix 1
#define __unix__ 1
#define HAVE_STDINT_H 1
#define HAVE_MEMORY_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_SIGNAL_H 1
#define HAVE_SYSLOG_H 1
#define HAVE_TIME_H 1

/* 内存管理和线程安全 */
#define HAVE_GMTIME_R 1
#define HAVE_LOCALTIME_R 1
#define HAVE_POLL 1
#define HAVE_ARC4RANDOM 1

#endif /* AN_CONFIG_H_INCLUDED */ 