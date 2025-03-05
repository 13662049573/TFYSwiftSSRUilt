/*
 * utils.h - Misc utilities
 *
 * Copyright (C) 2013 - 2016, Max Lv <max.c.lv@gmail.com>
 * Copyright (C) 2024, TFY SSR Team
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

#ifndef _UTILS_H
#define _UTILS_H

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <fcntl.h>

#define PORTSTRLEN 16
#define SS_ADDRSTRLEN (INET6_ADDRSTRLEN + PORTSTRLEN + 1)

// Time format for logging
#define TIME_FORMAT "%Y-%m-%d %H:%M:%S"

// Logging macros optimized for iOS/macOS
#ifdef DEBUG
    #define LOGI(format, ...) do { \
        time_t now = time(NULL); \
        char timestr[20]; \
        strftime(timestr, 20, TIME_FORMAT, localtime(&now)); \
        fprintf(stderr, " %s INFO: " format "\n", timestr, ##__VA_ARGS__); \
        fflush(stderr); \
    } while(0)

    #define LOGE(format, ...) do { \
        time_t now = time(NULL); \
        char timestr[20]; \
        strftime(timestr, 20, TIME_FORMAT, localtime(&now)); \
        fprintf(stderr, " %s ERROR: " format "\n", timestr, ##__VA_ARGS__); \
        fflush(stderr); \
    } while(0)
#else
    #define LOGI(format, ...)
    #define LOGE(format, ...)
#endif

// Memory management
void *ss_malloc(size_t size);
void *ss_realloc(void *ptr, size_t new_size);
#define ss_free(ptr) do { free(ptr); ptr = NULL; } while(0)

// String utilities
char *ss_itoa(int i);
char *ss_strndup(const char *s, size_t n);

// Error handling
void FATAL(const char *msg);
void ERROR(const char *s);

// Process management
int run_as(const char *user);
void daemonize(const char *path);

// Resource management
#ifdef HAVE_SETRLIMIT
int set_nofile(int nofile);
#endif

// Command line interface
void usage(void);

// Additional utility functions
int setnonblocking(int fd);
void USE_TTY(void);
void USE_SYSLOG(const char* ident);

#endif // _UTILS_H
