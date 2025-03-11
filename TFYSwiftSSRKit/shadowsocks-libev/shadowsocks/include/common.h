/*
 * common.h - Provide global definitions
 *
 * Copyright (C) 2013 - 2016, Max Lv <max.c.lv@gmail.com>
 *
 * This file is part of the shadowsocks-libev.
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

#ifndef _COMMON_H
#define _COMMON_H

#include <ev.h>
#include "encrypt.h"
#include "obfs.h"
#include "jconf.h"
#include <libcork/ds.h>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#endif

// only enable TCP_FASTOPEN on linux
#if defined(__linux__)

/*  conditional define for TCP_FASTOPEN */
#ifndef TCP_FASTOPEN
#define TCP_FASTOPEN   23
#endif

/*  conditional define for MSG_FASTOPEN */
#ifndef MSG_FASTOPEN
#define MSG_FASTOPEN   0x20000000
#endif

#elif !defined(__APPLE__)

#ifdef TCP_FASTOPEN
#undef TCP_FASTOPEN
#endif

#endif

#define DEFAULT_CONF_PATH "/etc/shadowsocks-libev/config.json"

#ifndef SOL_TCP
#define SOL_TCP IPPROTO_TCP
#endif

#if defined(MODULE_TUNNEL) || defined(MODULE_REDIR)
#define MODULE_LOCAL
#endif

// Common structure definitions
typedef struct server_ctx {
    ev_io io;
    ev_timer watcher;
    int connected;
    struct server *server;
} server_ctx_t;

typedef struct remote_ctx {
    ev_io io;
    ev_timer watcher;
    int connected;
    struct remote *remote;
} remote_ctx_t;

typedef struct listen_ctx {
    ev_io io;
    int fd;
    int timeout;
    int method;
    char *iface;
    struct ev_loop *loop;
    int remote_num;
    int mptcp;
    struct sockaddr **remote_addr;
    // SSR
    char *protocol_name;
    char *obfs_name;
    char *obfs_param;
    void **list_protocol_global;
    void **list_obfs_global;
#ifdef __APPLE__
    CFSocketRef socket;
    CFRunLoopSourceRef source;
#endif
    ss_addr_t tunnel_addr;
} listen_ctx_t;

typedef listen_ctx_t listener_t;  // Added: Define listener_t as an alias for listen_ctx_t

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
    struct listen_ctx *listener;
    struct remote *remote;
    struct ResolvQuery *query;
    struct cork_dllist_item entries;
    // SSR
    obfs *protocol;
    obfs *obfs;
    obfs_class *protocol_plugin;
    obfs_class *obfs_plugin;
    ss_addr_t destaddr;
#ifdef __APPLE__
    CFSocketRef socket;
    CFRunLoopSourceRef source;
#endif
} server_t;

typedef struct remote {
    int fd;
    buffer_t *buf;
    ssize_t buf_capacity;
    struct remote_ctx *recv_ctx;
    struct remote_ctx *send_ctx;
    struct server *server;
    int direct;
    uint32_t counter;
    struct sockaddr_storage addr;
    int addr_len;
    // SSR
    int remote_index;
#ifdef __APPLE__
    CFSocketRef socket;
    CFRunLoopSourceRef source;
#endif
} remote_t;

// Function declarations
int init_udprelay(const char *server_host, const char *server_port,
#ifdef MODULE_LOCAL
                  const struct sockaddr *remote_addr, const int remote_addr_len,
#ifdef MODULE_TUNNEL
                  const ss_addr_t tunnel_addr,
#endif
#endif
                  int mtu, int method, int auth, int timeout, const char *iface);

void free_udprelay(void);

#ifdef ANDROID
int protect_socket(int fd);
int send_traffic_stat(uint64_t tx, uint64_t rx);
#endif

#endif // _COMMON_H
