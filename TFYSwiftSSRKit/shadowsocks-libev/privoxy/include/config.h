/* config.h for Privoxy - iOS/macOS 编译配置 */
#ifndef CONFIG_H_INCLUDED
#define CONFIG_H_INCLUDED

/* 基本定义 */
#define VERSION "3.0.34"
#define CODE_STATUS "stable"

/* Feature flags */
#define FEATURE_PTHREAD 1
#define FEATURE_COOKIE_JAR 0
#define FEATURE_COMPRESSION 0
#define FEATURE_HTTPS_INSPECTION 0
#define FEATURE_CLIENT_TAGS 0
#define FEATURE_CONNECTION_KEEP_ALIVE 1
#define FEATURE_CONNECTION_SHARING 0
#define FEATURE_STRPTIME_SANITY_CHECKS 0
#define FEATURE_EXTENDED_STATISTICS 0
#define FEATURE_TOGGLE 0
#define FEATURE_ACL 0
#define FEATURE_EXTERNAL_FILTERS 0
#define FEATURE_GRACEFUL_TERMINATION 1
#define FEATURE_FAST_REDIRECTS 0
#define FEATURE_FORCE_LOAD 0
#define FEATURE_CGI_EDIT_ACTIONS 0
#define FEATURE_NO_GIFS 1
#define FEATURE_PCRE 1

/* 系统特性检测 */
#define HAVE_PCRE 1
#define HAVE_MEMMOVE 1
#define HAVE_STRERROR 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_CTYPE_H 1
#define STATIC_PCRE 1
#define HAVE_PTHREAD 1
#define HAVE_PTHREAD_ATTR_SETDETACHSTATE 1

/* 路径定义 */
#define CONFDIR "/tmp"
#define SHARE_CONFDIR "/tmp"
#define LOGDIR "/tmp"

/* iOS/macOS 特定定义 */
#define unix 1
#define __unix 1
#define __unix__ 1
#define HAVE_STDBOOL_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_MEMORY_H 1
#define HAVE_STRINGS_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SIGNAL_H 1
#define HAVE_PTHREAD_H 1
#define HAVE_SYSLOG_H 1
#define HAVE_TIME_H 1

/* 内存管理和线程安全 */
#define HAVE_GMTIME_R 1
#define HAVE_LOCALTIME_R 1
#define HAVE_GETHOSTBYADDR_R 0
#define HAVE_GETHOSTBYNAME_R 0
#define HAVE_POLL 1
#define HAVE_ARC4RANDOM 1

#endif /* CONFIG_H_INCLUDED */
