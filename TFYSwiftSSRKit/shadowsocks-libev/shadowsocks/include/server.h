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

// Constants
#define BUF_SIZE 2048
#define MAX_CONNECTIONS 1024
#define UPDATE_INTERVAL 30

// Type definitions
typedef listen_ctx_t listener_t;

typedef struct query {
    server_t *server;
    char hostname[257];
} query_t;

// Function declarations
void start_ss_server(const char *server_host, const char *server_port,
                    const char *password, const char *method,
                    const char *timeout, const char *iface);

void stop_ss_server(void);

#endif // _SERVER_H
