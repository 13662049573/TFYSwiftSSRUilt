/*
 * server.h - Define shadowsocks server's buffers and callbacks
 *
 * Copyright (C) 2013 - 2016, Max Lv <max.c.lv@gmail.com>
 *
 * This file is part of the shadowsocks-libev.
 *
 * shadowsocks-libev is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * shadowsocks-libev is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with shadowsocks-libev; see the file COPYING. If not, see
 * <http://www.gnu.org/licenses/>.
 */

#ifndef _SERVER_H
#define _SERVER_H

#include <ev.h>
#include <time.h>
#include <libcork/ds.h>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif

#include "encrypt.h"
#include "jconf.h"
#include "resolv.h"

#include "common.h"

// 常量定义
#define BUF_SIZE 2048
#define MAX_CONNECTIONS 1024
#define UPDATE_INTERVAL 30

// 上下文结构体
typedef struct listen_ctx {
    ev_io io;
    int fd;
    int timeout;
    int method;
    char *iface;
    struct ev_loop *loop;
#ifdef __APPLE__
    CFSocketRef socket;
    CFRunLoopSourceRef source;
#endif
} listen_ctx_t;

typedef struct server_ctx {
    ev_io io;
    ev_timer watcher;
    int connected;
    struct server *server;
} server_ctx_t;

typedef struct server {
    int fd;
    int stage;
    buffer_t *buf;
    ssize_t buf_capacity;

    int auth;
    struct chunk *chunk;

    struct enc_ctx *e_ctx;
    struct enc_ctx *d_ctx;
    struct server_ctx *recv_ctx;
    struct server_ctx *send_ctx;
    struct listen_ctx *listen_ctx;
    struct remote *remote;

    struct ResolvQuery *query;

    struct cork_dllist_item entries;

#ifdef __APPLE__
    CFSocketRef socket;
    CFRunLoopSourceRef source;
#endif
} server_t;

typedef struct query {
    server_t *server;
    char hostname[257];
} query_t;

typedef struct remote_ctx {
    ev_io io;
    int connected;
    struct remote *remote;
} remote_ctx_t;

typedef struct remote {
    int fd;
    buffer_t *buf;
    ssize_t buf_capacity;
    struct remote_ctx *recv_ctx;
    struct remote_ctx *send_ctx;
    struct server *server;
#ifdef __APPLE__
    CFSocketRef socket;
    CFRunLoopSourceRef source;
#endif
} remote_t;

// 函数声明
void start_ss_server(const char *server_host, const char *server_port,
                    const char *password, const char *method,
                    const char *timeout, const char *iface);

void stop_ss_server(void);

#endif // _SERVER_H
