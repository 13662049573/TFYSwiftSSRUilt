/*
 * tunnel.h - Define tunnel's buffers and callbacks
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

#ifndef _TUNNEL_H
#define _TUNNEL_H

#include <ev.h>
#include "encrypt.h"
#include "obfs.h"
#include "jconf.h"
#include "common.h"

// Function declarations
void start_ss_tunnel(const char *server_host, const char *server_port,
                    const char *local_addr, const char *local_port,
                    const char *password, const char *method,
                    const char *timeout, const char *iface);

void stop_ss_tunnel(void);

#endif // _TUNNEL_H
