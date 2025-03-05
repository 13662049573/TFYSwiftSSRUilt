/* ANTINAT
 * =======
 * This software is Copyright (c) 2003-05 Malcolm Smith.
 * No warranty is provided, including but not limited to
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * This code is licenced subject to the GNU General
 * Public Licence (GPL).  See the COPYING file for more.
 */

#ifndef _AN_INTERNALS_H
#define _AN_INTERNALS_H

/* 定义内核环境，使antinat.h使用内部结构 */
#ifndef __AN_KERNEL
#define __AN_KERNEL  
#endif

#define _GNU_SOURCE
#define _REENTRANT

#ifdef WIN32_NO_CONFIG_H
#define _WIN32_
#endif

/* 包含基本的系统头文件 */
#ifndef _WIN32_
#include "../an_config.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#define INVALID_SOCKET -1
#define SOCKET_ERROR -1
#define closesocket close
typedef int SOCKET;
#else
#include "../winconf.h"
#define WIN32_LEAN_AND_MEAN
#include <winsock.h>
#endif

/* 包含标准库头文件 */
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

/* 定义常量 */
#define AN_INVALID_CONNECTION (-1)
#define AN_INVALID_FAMILY (-1)
#define AN_MODE_NONE       0
#define AN_MODE_CONNECTED  1
#define AN_MODE_BOUND      2
#define AN_MODE_LISTENING  3
#define AN_MODE_ACCEPTED   4
#define AN_MODE_ASSOCIATED 5

/* 定义类型别名 */
#ifndef _WIN32_
typedef struct sockaddr_in SOCKADDR_IN;
typedef struct sockaddr SOCKADDR;
typedef struct hostent HOSTENT;
typedef HOSTENT *PHOSTENT;
#endif

#ifdef WITH_IPV6
typedef struct sockaddr_in6 SOCKADDR_IN6;
#endif

/* 包含主要的API头文件 */
#include "antinat.h"

typedef SOCKADDR_IN PI_SA;
typedef socklen_t sl_t;

/* 定义非标准库函数 */
#if !(defined(HAVE_GETHOSTBYNAME_R)||defined(HAVE_NSL_GETHOSTBYNAME_R)||defined(_WIN32_))
#define WRAP_GETHOSTBYNAME 1
#else
#undef WRAP_GETHOSTBYNAME
#endif

/* 其他内部结构体定义 */
#define AN_AUTH_UNDEF 0x80000000
#define AN_AUTH_MAX   3

/* 连接结构体定义 */
typedef struct an_conn {
    int connection;  /* 使用int而不是SOCKET，以避免循环依赖 */
    PI_SA addr;
    int state;
    int type;
    void *specific;
    int timeout;
} an_conn;

/* 数据缓冲区定义 */
typedef struct an_buffer {
    void *data;
    int len;
    int ptr;
} an_buffer;

/* 回调函数类型定义 */
typedef int (*an_conn_setup)(an_conn *);

/* 函数声明 */
int an_generic_timeout_connect(an_conn * conn, PI_SA * sa);
int an_select(an_conn ** conns, an_conn ** wreturn,
                an_conn ** returned, int timeout, int n,
                an_conn_setup setup, an_conn ** wconns);

#ifdef WRAP_GETHOSTBYNAME
#include <pthread.h>
extern pthread_mutex_t gethostbyname_lock;
#endif

#endif /* _AN_INTERNALS_H */



