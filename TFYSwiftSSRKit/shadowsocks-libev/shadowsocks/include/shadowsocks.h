/*
 * shadowsocks.h - Header files of library interfaces
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

#ifndef _SHADOWSOCKS_H
#define _SHADOWSOCKS_H

#include <stddef.h>  // for size_t

typedef struct {
    /*  Required  */
    char *remote_host;    // hostname or ip of remote server
    char *local_addr;     // local ip to bind
    char *method;         // encryption method
    char *password;       // password of remote server
    int remote_port;      // port number of remote server
    int local_port;       // port number of local server
    int timeout;          // connection timeout

    /* SSR */
    char *protocol;
    char *obfs;
    char *obfs_param;

    /*  Optional, set NULL if not valid   */
    char *acl;            // file path to acl
    char *rules;          // file path to rules
    char *log;            // file path to log
    int use_sys_log;            // file path to log
    int fast_open;        // enable tcp fast open
    int mode;             // enable udp relay
    int auth;             // enable one-time authentication
    int mtu;              // MTU of interface
    int mptcp;            // enable multipath TCP
    int verbose;          // verbose mode
} profile_t;

/* An example profile
 *
 * const profile_t EXAMPLE_PROFILE = {
 *  .remote_host = "example.com",
 *  .local_addr = "127.0.0.1",
 *  .method = "bf-cfb",
 *  .password = "barfoo!",
 *  .remote_port = 8338,
 *  .local_port = 1080,
 *  .timeout = 600;
 *  .acl = NULL,
 *  .rules = NULL,
 *  .log = NULL,
 *  .fast_open = 0,
 *  .mode = 0,
 *  .auth = 0,
 *  .verbose = 0
 * };
 */

#ifdef __cplusplus
extern "C" {
#endif

    typedef void (*shadowsocks_cb) (int fd, void*);

    /*
     * Create and start a shadowsocks local server.
     *
     * Calling this function will block the current thread forever if the server
     * starts successfully.
     *
     * Make sure start the server in a separate process to avoid any potential
     * memory and socket leak.
     *
     * If failed, -1 is returned. Errors will output to the log file.
     */
    int start_ss_local_server(profile_t profile, shadowsocks_cb cb, void *data);

    /*
     * Stop the shadowsocks local server.
     *
     * @param listener: The listener context returned by start_ss_local_server.
     */
    void start_ss_local_server_stop(void* listener);

    /*
     * Check if a host matches any rule.
     *
     * @param host: The host to check.
     * @param host_len: Length of the host string.
     * @return: 1 if matched, 0 if not matched.
     */
    int start_ss_local_check_rule(const char *host, size_t host_len);

#ifdef __cplusplus
}
#endif

// To stop the service on posix system, just kill the daemon process
// kill(pid, SIGKILL);
// Otherwise, If you start the service in a thread, you may need to send a signal SIGUSER1 to the thread.
// pthread_kill(pthread_t, SIGUSR1);

#endif // _SHADOWSOCKS_H
