/*
 * udprelay.h - Define UDP relay's buffers and callbacks
 *
 * Copyright (C) 2013 - 2019, Max Lv <max.c.lv@gmail.com>
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

#ifndef _UDPRELAY_H
#define _UDPRELAY_H

#include <ev.h>
#include <time.h>

#include "crypto.h"
#include "utils.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_UDP_PACKET_SIZE 65507
#define MAX_ADDR_HEADER_SIZE 384
#define PACKET_HEADER_SIZE (1 + 28 + 2 + 64)
#define DEFAULT_PACKET_SIZE 1397
#define MAX_REMOTE_NUM 10
#define MIN_UDP_TIMEOUT 10
#define HASH_KEY_LEN (sizeof(struct sockaddr_storage) + sizeof(int))

#ifdef MODULE_TUNNEL
typedef struct {
    char *host;
    char *port;
} tunnel_addr_t;
#endif

typedef struct server_ctx {
    ev_io io;
    int fd;
    crypto_t *crypto;
    int timeout;
    const char *iface;
    struct cache *conn_cache;
    struct ev_loop *loop;
    const struct sockaddr *remote_addr;
    int remote_addr_len;
#ifdef MODULE_TUNNEL
    tunnel_addr_t tunnel_addr;
#endif
} server_ctx_t;

typedef struct remote_ctx {
    ev_io io;
    int fd;
    buffer_t *buf;
    int af;
    struct sockaddr_storage src_addr;
    struct sockaddr_storage dst_addr;
    struct ev_timer watcher;
    server_ctx_t *server_ctx;
} remote_ctx_t;

typedef struct query_ctx {
    ev_io io;
    buffer_t *buf;
    size_t addr_header_len;
    char addr_header[MAX_ADDR_HEADER_SIZE];
    struct sockaddr_storage src_addr;
    server_ctx_t *server_ctx;
    remote_ctx_t *remote_ctx;
} query_ctx_t;

// 函数声明
#ifdef MODULE_LOCAL
int init_udprelay(const char *server_host, const char *server_port,
                 const struct sockaddr *remote_addr, const int remote_addr_len,
                 int mtu, crypto_t *crypto, int timeout, const char *iface);
#else
int init_udprelay(const char *server_host, const char *server_port,
                 int mtu, crypto_t *crypto, int timeout, const char *iface);
#endif

// 添加 parse_udprelay_header 函数声明
int parse_udprelay_header(const char *buf, size_t buf_len,
                         char *host, char *port,
                         struct sockaddr_storage *storage);

void free_udprelay(void);

// DNS解析相关函数声明
void resolv_cb(struct sockaddr *addr, void *data);
void resolv_free_cb(void *data);
void resolv_start(const char *hostname, uint16_t port,
                void (*callback)(struct sockaddr *addr, void *data),
                void (*free_cb)(void *data), void *data);

#ifdef __cplusplus
}
#endif

#endif // _UDPRELAY_H
