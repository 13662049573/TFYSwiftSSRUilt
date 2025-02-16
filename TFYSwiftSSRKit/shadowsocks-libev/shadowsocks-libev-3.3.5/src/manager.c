/*
 * server.c - Provide shadowsocks service
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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <locale.h>
#include <signal.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <unistd.h>
#include <getopt.h>
#include <math.h>
#include <ctype.h>
#include <limits.h>
#include <dirent.h>

#include <netdb.h>
#include <errno.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <pwd.h>
#include <libcork/core.h>

#if defined(HAVE_SYS_IOCTL_H) && defined(HAVE_NET_IF_H) && defined(__linux__)
#include <net/if.h>
#include <sys/ioctl.h>
#define SET_INTERFACE
#endif

#include "json.h"
#include "utils.h"
#include "netutils.h"
#include "manager.h"

#ifndef BUF_SIZE
#define BUF_SIZE 65535
#endif

int verbose          = 0;
char *executable     = "ss-server";
char *working_dir    = NULL;
int working_dir_size = 0;

static struct cork_hash_table *server_table;

// Function declarations
static char *get_port(char *buf, int len);
static uint64_t get_traffic(char *buf, int len);
static void start_server(struct manager_ctx *manager_ctx, struct server *server);
static void stop_server(char *prefix, char *pid_file);
static void destroy_server(struct server *server);
static void remove_server(char *prefix, char *port);

static void
destroy_server(struct server *server)
{
    if (server->method)
        ss_free(server->method);
    if (server->plugin)
        ss_free(server->plugin);
    if (server->plugin_opts)
        ss_free(server->plugin_opts);
    if (server->mode)
        ss_free(server->mode);
}

static void
build_config(char *prefix, struct manager_ctx *manager_ctx, struct server *server)
{
    char *path    = NULL;
    int path_size = strlen(prefix) + strlen(server->port) + 20;
    manager_t *manager = manager_ctx->manager;

    path = ss_malloc(path_size);
    snprintf(path, path_size, "%s/.shadowsocks_%s.conf", prefix, server->port);
    FILE *f = fopen(path, "w+");
    if (f == NULL) {
        if (verbose) {
            LOGE("unable to open config file");
        }
        ss_free(path);
        return;
    }
    fprintf(f, "{\n");
    fprintf(f, "\"server_port\":%d,\n", atoi(server->port));
    fprintf(f, "\"password\":\"%s\"", server->password);
    if (server->method)
        fprintf(f, ",\n\"method\":\"%s\"", server->method);
    else if (manager->method)
        fprintf(f, ",\n\"method\":\"%s\"", manager->method);
    if (server->fast_open[0])
        fprintf(f, ",\n\"fast_open\": %s", server->fast_open);
    else if (manager->fast_open)
        fprintf(f, ",\n\"fast_open\": true");
    if (server->no_delay[0])
        fprintf(f, ",\n\"no_delay\": %s", server->no_delay);
    else if (manager->no_delay)
        fprintf(f, ",\n\"no_delay\": true");
    if (manager->reuse_port)
        fprintf(f, ",\n\"reuse_port\": true");
    if (server->mode)
        fprintf(f, ",\n\"mode\":\"%s\"", server->mode);
    if (server->plugin)
        fprintf(f, ",\n\"plugin\":\"%s\"", server->plugin);
    if (server->plugin_opts)
        fprintf(f, ",\n\"plugin_opts\":\"%s\"", server->plugin_opts);
    fprintf(f, "\n}\n");
    fclose(f);
    ss_free(path);
}

static char *
construct_command_line(struct manager_ctx *manager_ctx, struct server *server)
{
    static char cmd[BUF_SIZE];
    int i;
    int port;
    manager_t *manager = manager_ctx->manager;

    port = atoi(server->port);
    build_config(working_dir, manager_ctx, server);

    memset(cmd, 0, BUF_SIZE);
    snprintf(cmd, BUF_SIZE,
             "%s --manager-address %s -f %s/.shadowsocks_%d.pid -c %s/.shadowsocks_%d.conf",
             manager->executable, manager->manager_address, working_dir, port, working_dir, port);

    if (manager->acl != NULL) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " --acl %s", manager->acl);
    }
    if (manager->timeout != NULL) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -t %s", manager->timeout);
    }
#ifdef HAVE_SETRLIMIT
    if (manager->nofile) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -n %d", manager->nofile);
    }
#endif
    if (manager->user != NULL) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -a %s", manager->user);
    }
    if (manager->verbose) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -v");
    }
    if (server->mode == NULL && manager->mode == UDP_ONLY) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -U");
    }
    if (server->mode == NULL && manager->mode == TCP_AND_UDP) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -u");
    }
    if (server->fast_open[0] == 0 && manager->fast_open) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " --fast-open");
    }
    if (server->no_delay[0] == 0 && manager->no_delay) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " --no-delay");
    }
    if (manager->ipv6first) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -6");
    }
    if (manager->mtu) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " --mtu %d", manager->mtu);
    }
    if (server->plugin == NULL && manager->plugin) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " --plugin \"%s\"", manager->plugin);
    }
    if (server->plugin_opts == NULL && manager->plugin_opts) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " --plugin-opts \"%s\"", manager->plugin_opts);
    }
    if (manager->nameservers) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -d \"%s\"", manager->nameservers);
    }
    for (i = 0; i < manager->host_num; i++) {
        int len = strlen(cmd);
        snprintf(cmd + len, BUF_SIZE - len, " -s %s", manager->hosts[i]);
    }

    if (verbose) {
        LOGI("cmd: %s", cmd);
    }

    return cmd;
}

static char *
get_data(char *buf, int len)
{
    char *data;
    int pos = 0;

    while (pos < len && buf[pos] != '{')
        pos++;
    if (pos == len) {
        return NULL;
    }
    data = buf + pos - 1;

    return data;
}

static char *
get_action(char *buf, int len)
{
    char *action;
    int pos = 0;

    while (pos < len && isspace((unsigned char)buf[pos]))
        pos++;
    if (pos == len) {
        return NULL;
    }
    action = buf + pos;

    while (pos < len && (!isspace((unsigned char)buf[pos]) && buf[pos] != ':'))
        pos++;
    buf[pos] = '\0';

    return action;
}

static struct server *
get_server(char *buf, int len)
{
    char *data = get_data(buf, len);
    char error_buf[512];

    if (data == NULL) {
        LOGE("No data found");
        return NULL;
    }

    json_settings settings = { 0 };
    json_value *obj        = json_parse_ex(&settings, data, strlen(data), error_buf);

    if (obj == NULL) {
        LOGE("%s", error_buf);
        return NULL;
    }

    struct server *server = ss_malloc(sizeof(struct server));
    memset(server, 0, sizeof(struct server));
    if (obj->type == json_object) {
        int i = 0;
        for (i = 0; i < obj->u.object.length; i++) {
            char *name        = obj->u.object.values[i].name;
            json_value *value = obj->u.object.values[i].value;
            if (strcmp(name, "server_port") == 0) {
                if (value->type == json_string) {
                    strncpy(server->port, value->u.string.ptr, 7);
                } else if (value->type == json_integer) {
                    snprintf(server->port, 8, "%" PRIu64 "", value->u.integer);
                }
            } else if (strcmp(name, "password") == 0) {
                if (value->type == json_string) {
                    strncpy(server->password, value->u.string.ptr, 127);
                }
            } else if (strcmp(name, "method") == 0) {
                if (value->type == json_string) {
                    server->method = strdup(value->u.string.ptr);
                }
            } else if (strcmp(name, "fast_open") == 0) {
                if (value->type == json_boolean) {
                    strncpy(server->fast_open, (value->u.boolean ? "true" : "false"), 8);
                }
            } else if (strcmp(name, "no_delay") == 0) {
                if (value->type == json_boolean) {
                    strncpy(server->no_delay, (value->u.boolean ? "true" : "false"), 8);
                }
            } else if (strcmp(name, "plugin") == 0) {
                if (value->type == json_string) {
                    server->plugin = strdup(value->u.string.ptr);
                }
            } else if (strcmp(name, "plugin_opts") == 0) {
                if (value->type == json_string) {
                    server->plugin_opts = strdup(value->u.string.ptr);
                }
            } else if (strcmp(name, "mode") == 0) {
                if (value->type == json_string) {
                    server->mode = strdup(value->u.string.ptr);
                }
            } else {
                LOGE("invalid data: %s", data);
                break;
            }
        }
    }

    json_value_free(obj);
    return server;
}

static int
create_and_bind(const char *host, const char *port, int protocol)
{
    struct addrinfo hints;
    struct addrinfo *result, *rp, *ipv4v6bindall;
    int s, listen_sock = -1;

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family   = AF_UNSPEC;                  /* Return IPv4 and IPv6 choices */
    hints.ai_socktype = protocol == IPPROTO_TCP ?
                        SOCK_STREAM : SOCK_DGRAM;   /* We want a TCP or UDP socket */
    hints.ai_flags    = AI_PASSIVE | AI_ADDRCONFIG; /* For wildcard IP address */
    hints.ai_protocol = protocol;

    s = getaddrinfo(host, port, &hints, &result);

    if (s != 0) {
        LOGE("getaddrinfo: %s", gai_strerror(s));
        return -1;
    }

    rp = result;

    /*
     * On Linux, with net.ipv6.bindv6only = 0 (the default), getaddrinfo(NULL) with
     * AI_PASSIVE returns 0.0.0.0 and :: (in this order). AI_PASSIVE was meant to
     * return a list of addresses to listen on, but it is impossible to listen on
     * 0.0.0.0 and :: at the same time, if :: implies dualstack mode.
     */
    if (!host) {
        ipv4v6bindall = result;

        /* Loop over all address infos found until a IPV6 address is found. */
        while (ipv4v6bindall) {
            if (ipv4v6bindall->ai_family == AF_INET6) {
                rp = ipv4v6bindall; /* Take first IPV6 address available */
                break;
            }
            ipv4v6bindall = ipv4v6bindall->ai_next; /* Get next address info, if any */
        }
    }

    for (/*rp = result*/; rp != NULL; rp = rp->ai_next) {
        listen_sock = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (listen_sock == -1) {
            continue;
        }

        if (rp->ai_family == AF_INET6) {
            int ipv6only = host ? 1 : 0;
            setsockopt(listen_sock, IPPROTO_IPV6, IPV6_V6ONLY, &ipv6only, sizeof(ipv6only));
        }

        int opt = 1;
        setsockopt(listen_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_NOSIGPIPE
        setsockopt(listen_sock, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof(opt));
#endif

        s = bind(listen_sock, rp->ai_addr, rp->ai_addrlen);
        if (s == 0) {
            /* We managed to bind successfully! */

            close(listen_sock);

            break;
        } else {
            ERROR("bind");
        }
    }

    if (!result) {
        freeaddrinfo(result);
    }

    if (rp == NULL) {
        LOGE("Could not bind");
        return -1;
    }

    return listen_sock;
}

static int
check_port(struct manager_ctx *manager_ctx, struct server *server)
{
    manager_t *manager = manager_ctx->manager;
    bool both_tcp_udp = manager->mode == TCP_AND_UDP;
    int fd_count      = manager->host_num * (both_tcp_udp ? 2 : 1);
    int bind_err      = 0;

    int *sock_fds = (int *)ss_malloc(fd_count * sizeof(int));
    memset(sock_fds, 0, fd_count * sizeof(int));

    /* try to bind each interface */
    for (int i = 0; i < manager->host_num; i++) {
        LOGI("try to bind interface: %s, port: %s", manager->hosts[i], server->port);

        if (manager->mode == UDP_ONLY) {
            sock_fds[i] = create_and_bind(manager->hosts[i], server->port, IPPROTO_UDP);
        } else {
            sock_fds[i] = create_and_bind(manager->hosts[i], server->port, IPPROTO_TCP);
        }

        if (both_tcp_udp) {
            sock_fds[i + manager->host_num] = create_and_bind(manager->hosts[i], server->port, IPPROTO_UDP);
        }

        if (sock_fds[i] == -1 || (both_tcp_udp && sock_fds[i + manager->host_num] == -1)) {
            bind_err = -1;
            break;
        }
    }

    /* clean socks */
    for (int i = 0; i < fd_count; i++)
        if (sock_fds[i] > 0) {
            close(sock_fds[i]);
        }

    ss_free(sock_fds);

    return bind_err == -1 ? -1 : 0;
}

static int
add_server(struct manager_ctx *manager_ctx, struct server *server)
{
    int ret = check_port(manager_ctx, server);

    if (ret == -1) {
        LOGE("port is not available, please check.");
        return -1;
    }

    bool new = false;
    cork_hash_table_put(server_table, (void *)server->port, (void *)server, &new, NULL, NULL);

    char *cmd = construct_command_line(manager_ctx, server);
    
    // Replace system() with fork() + execl()
    pid_t pid = fork();
    if (pid < 0) {
        ERROR("fork");
        return -1;
    }
    
    if (pid == 0) {
        // Child process
        char *args[] = {"/bin/sh", "-c", cmd, NULL};
        execv("/bin/sh", args);
        _exit(127); // Only reached if execv fails
    }
    
    // Parent process
    int status;
    waitpid(pid, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        ERROR("Failed to execute command");
        return -1;
    }

    return 0;
}

static char *
get_port(char *buf, int len)
{
    char *port = NULL;
    char *data = get_data(buf, len);
    
    if (data == NULL) {
        return NULL;
    }
    
    json_settings settings = { 0 };
    char error_buf[512];
    json_value *obj = json_parse_ex(&settings, data, strlen(data), error_buf);
    
    if (obj != NULL && obj->type == json_object) {
        for (unsigned int i = 0; i < obj->u.object.length; i++) {
            char *name = obj->u.object.values[i].name;
            json_value *value = obj->u.object.values[i].value;
            if (value->type == json_integer) {
                port = strdup(name);
                break;
            }
        }
        json_value_free(obj);
    }
    
    return port;
}

static uint64_t
get_traffic(char *buf, int len)
{
    uint64_t traffic = 0;
    char *data = get_data(buf, len);
    
    if (data == NULL) {
        return 0;
    }
    
    json_settings settings = { 0 };
    char error_buf[512];
    json_value *obj = json_parse_ex(&settings, data, strlen(data), error_buf);
    
    if (obj != NULL && obj->type == json_object) {
        for (unsigned int i = 0; i < obj->u.object.length; i++) {
            json_value *value = obj->u.object.values[i].value;
            if (value->type == json_integer) {
                traffic = value->u.integer;
                break;
            }
        }
        json_value_free(obj);
    }
    
    return traffic;
}

static void
start_server(struct manager_ctx *manager_ctx, struct server *server)
{
    // Implementation of start_server
    int ret = add_server(manager_ctx, server);
    if (ret == -1) {
        LOGE("Failed to start server for port: %s", server->port);
    }
}

static void
stop_server(char *prefix, char *pid_file)
{
#ifndef __MINGW32__
    int pid = -1;
    FILE *fp = fopen(pid_file, "r");
    if (fp == NULL) {
        if (verbose) {
            LOGE("unable to open pid file");
        }
        return;
    }
    if (fscanf(fp, "%d", &pid) != EOF) {
        kill(pid, SIGTERM);
    }
    fclose(fp);
    unlink(pid_file);
#endif
}

static void
remove_server(char *prefix, char *port)
{
    char *old_port            = NULL;
    struct server *old_server = NULL;

    cork_hash_table_delete(server_table, (void *)port, (void **)&old_port, (void **)&old_server);

    if (old_server != NULL) {
        destroy_server(old_server);
        ss_free(old_server);
    }

    stop_server(prefix, port);
}

static void
update_stat(char *port, uint64_t traffic)
{
    if (verbose) {
        LOGI("update traffic %" PRIu64 " for port %s", traffic, port);
    }
    void *ret = cork_hash_table_get(server_table, (void *)port);
    if (ret != NULL) {
        struct server *server = (struct server *)ret;
        server->traffic = traffic;
    }
}

static void
manager_recv_cb(EV_P_ ev_io *w, int revents)
{
    struct manager_ctx *manager_ctx = (struct manager_ctx *)w;
    size_t r;
    struct sockaddr_un claddr;
    char buf[BUF_SIZE];
    socklen_t len = sizeof(struct sockaddr_un);

    memset(buf, 0, BUF_SIZE);
    r = recvfrom(manager_ctx->fd, buf, BUF_SIZE, 0, (struct sockaddr *)&claddr, &len);
    if (r == -1) {
        ERROR("recvfrom");
        return;
    }

    if (r > BUF_SIZE - 1) {
        ERROR("too long message");
        return;
    }

    char *action = get_action(buf, r);
    if (action == NULL) {
        return;
    }

    if (strcmp(action, "add") == 0) {
        struct server *server = get_server(buf, r);

        if (server == NULL || server->port[0] == 0 || server->password[0] == 0) {
            LOGE("invalid command: %s:%s", buf, action);
            if (server != NULL) {
                ss_free(server);
            }
            goto ERROR_MSG;
        }

        remove_server(working_dir, server->port);
        start_server(manager_ctx, server);
        ss_free(server);
    } else if (strcmp(action, "remove") == 0) {
        struct server *server = get_server(buf, r);

        if (server == NULL || server->port[0] == 0) {
            LOGE("invalid command: %s:%s", buf, action);
            if (server != NULL) {
                ss_free(server);
            }
            goto ERROR_MSG;
        }

        remove_server(working_dir, server->port);
        ss_free(server);
    } else if (strcmp(action, "stat") == 0) {
        char *port = get_port(buf, r);
        uint64_t traffic = get_traffic(buf, r);

        if (port == NULL || traffic == 0) {
            LOGE("invalid command: %s:%s", buf, action);
            if (port != NULL) {
                ss_free(port);
            }
            goto ERROR_MSG;
        }

        update_stat(port, traffic);
        ss_free(port);
    } else if (strcmp(action, "ping") == 0) {
        if ((sendto(manager_ctx->fd, "pong", 4, 0, (struct sockaddr *)&claddr, len)) != 4) {
            ERROR("ping");
        }
    }

ERROR_MSG:
    ss_free(action);
}

static void
signal_cb(EV_P_ ev_signal *w, int revents)
{
    if (revents & EV_SIGNAL) {
        switch (w->signum) {
        case SIGINT:
        case SIGTERM:
            ev_unloop(EV_A_ EVUNLOOP_ALL);
        }
    }
}

int
create_server_socket(const char *host, const char *port)
{
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    int s, server_sock;

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_UNSPEC;                 /* Return IPv4 and IPv6 choices */
    hints.ai_socktype = SOCK_DGRAM;              /* We want a UDP socket */
    hints.ai_flags = AI_PASSIVE | AI_ADDRCONFIG; /* For wildcard IP address */
    hints.ai_protocol = IPPROTO_UDP;

    s = getaddrinfo(host, port, &hints, &result);
    if (s != 0) {
        LOGE("getaddrinfo: %s", gai_strerror(s));
        return -1;
    }

    rp = result;

    /*
     * On Linux, with net.ipv6.bindv6only = 0 (the default), getaddrinfo(NULL) with
     * AI_PASSIVE returns 0.0.0.0 and :: with AI_PASSIVE set -- a dual-stack bind.
     */
    if (!host) {
        /* Loop over all address families, both IPv4 and IPv6 */
        for (rp = result; rp != NULL; rp = rp->ai_next) {
            int family = rp->ai_family;
            if (family == AF_INET6) {
                continue;
            }
            break;
        }
    }

    for (/*rp = result*/; rp != NULL; rp = rp->ai_next) {
        server_sock = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (server_sock == -1) {
            continue;
        }

        if (rp->ai_family == AF_INET6) {
            int ipv6only = host ? 1 : 0;
            setsockopt(server_sock, IPPROTO_IPV6, IPV6_V6ONLY, &ipv6only, sizeof(ipv6only));
        }

        int opt = 1;
        setsockopt(server_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_NOSIGPIPE
        setsockopt(server_sock, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof(opt));
#endif

        s = bind(server_sock, rp->ai_addr, rp->ai_addrlen);
        if (s == 0) {
            /* We managed to bind successfully! */
            break;
        } else {
            ERROR("bind");
        }

        close(server_sock);
    }

    if (rp == NULL) {
        LOGE("cannot bind");
        return -1;
    }

    freeaddrinfo(result);

    return server_sock;
}

int
main(int argc, char **argv)
{
    int c;
    int pid_flags   = 0;
    char *acl = NULL;
    char *user = NULL;
    char *password = NULL;
    char *timeout = NULL;
    char *method = NULL;
    char *pid_path = NULL;
    char *conf_path = NULL;
    char *iface = NULL;
    char *manager_address = NULL;
    char *executable = "ss-server";

    int fast_open = 0;
    int mode = TCP_ONLY;
    int mtu = 0;
    int ipv6first = 0;

    char *server_port = NULL;
    char *server_host = NULL;

    char *plugin = NULL;
    char *plugin_opts = NULL;

    char *working_dir = NULL;

    int option_index = 0;
    static struct option long_options[] = {
        { "fast-open",       no_argument,       NULL, GETOPT_VAL_FAST_OPEN   },
        { "acl",            required_argument, NULL, GETOPT_VAL_ACL         },
        { "manager-address", required_argument, NULL, GETOPT_VAL_MANAGER_ADDRESS },
        { "executable",      required_argument, NULL, GETOPT_VAL_EXECUTABLE      },
        { "mtu",            required_argument, NULL, GETOPT_VAL_MTU         },
        { "plugin",         required_argument, NULL, GETOPT_VAL_PLUGIN      },
        { "plugin-opts",    required_argument, NULL, GETOPT_VAL_PLUGIN_OPTS },
        { "password",       required_argument, NULL, GETOPT_VAL_PASSWORD    },
        { "help",           no_argument,       NULL, GETOPT_VAL_HELP        },
        { NULL,                    0,                 NULL,  0 }
    };

    opterr = 0;

    USE_TTY();

    while ((c = getopt_long(argc, argv, "f:s:l:k:t:m:c:i:d:a:n:huUv6",
                           long_options, &option_index)) != -1)
        switch (c) {
        case GETOPT_VAL_FAST_OPEN:
            fast_open = 1;
            break;
        case GETOPT_VAL_ACL:
            acl = optarg;
            break;
        case GETOPT_VAL_MANAGER_ADDRESS:
            manager_address = optarg;
            break;
        case GETOPT_VAL_EXECUTABLE:
            executable = optarg;
            break;
        case GETOPT_VAL_MTU:
            mtu = atoi(optarg);
            break;
        case GETOPT_VAL_PLUGIN:
            plugin = optarg;
            break;
        case GETOPT_VAL_PLUGIN_OPTS:
            plugin_opts = optarg;
            break;
        case 's':
            server_host = optarg;
            break;
        case 'k':
            password = optarg;
            break;
        case 'f':
            pid_flags = 1;
            pid_path = optarg;
            break;
        case 't':
            timeout = optarg;
            break;
        case 'm':
            method = optarg;
            break;
        case 'c':
            conf_path = optarg;
            break;
        case 'i':
            iface = optarg;
            break;
        case 'd':
            working_dir = optarg;
            break;
        case 'a':
            user = optarg;
            break;
        case 'u':
            mode = TCP_AND_UDP;
            break;
        case 'U':
            mode = UDP_ONLY;
            break;
        case 'v':
            verbose = 1;
            break;
        case 'h':
        case GETOPT_VAL_HELP:
            usage();
            exit(EXIT_SUCCESS);
        case '6':
            ipv6first = 1;
            break;
        case '?':
            // The option character is not recognized.
            opterr = 1;
            break;
        }

    if (opterr) {
        usage();
        exit(EXIT_FAILURE);
    }

    if (conf_path != NULL) {
        jconf_t *conf = read_jconf(conf_path);
        if (server_host == NULL) {
            server_host = conf->remote_addr[0].host;
        }
        if (server_port == NULL) {
            server_port = conf->remote_addr[0].port;
        }
        if (password == NULL) {
            password = conf->password;
        }
        if (method == NULL) {
            method = conf->method;
        }
        if (timeout == NULL) {
            timeout = conf->timeout;
        }
        if (user == NULL) {
            user = conf->user;
        }
        if (plugin == NULL) {
            plugin = conf->plugin;
        }
        if (plugin_opts == NULL) {
            plugin_opts = conf->plugin_opts;
        }
        if (mode == TCP_ONLY) {
            mode = conf->mode;
        }
        if (mtu == 0) {
            mtu = conf->mtu;
        }
        if (ipv6first == 0) {
            ipv6first = conf->ipv6_first;
        }
        if (fast_open == 0) {
            fast_open = conf->fast_open;
        }
        if (acl == NULL) {
            acl = conf->acl;
        }
    }

    if (server_host == NULL) {
        server_host = "0.0.0.0";
    }

    if (method == NULL) {
        method = "chacha20-ietf-poly1305";
    }

    if (timeout == NULL) {
        timeout = "60";
    }

    if (pid_flags) {
        USE_SYSLOG(argv[0], pid_flags);
        daemonize(pid_path);
    }

    if (ipv6first) {
        LOGI("resolving hostname to IPv6 address first");
    }

    if (fast_open == 1) {
#ifdef TCP_FASTOPEN
        LOGI("using tcp fast open");
#else
        LOGE("tcp fast open is not supported by this environment");
        fast_open = 0;
#endif
    }

    if (plugin != NULL) {
        LOGI("plugin \"%s\" enabled", plugin);
    }

    // initialize ev loop
    struct ev_loop *loop = EV_DEFAULT;

    // initialize manager
    manager_t manager;
    memset(&manager, 0, sizeof(manager_t));
    manager.fast_open = fast_open;
    manager.verbose = verbose;
    manager.mode = mode;
    manager.password = password;
    manager.timeout = timeout;
    manager.method = method;
    manager.iface = iface;
    manager.acl = acl;
    manager.user = user;
    manager.manager_address = manager_address;
    manager.host = server_host;
    manager.port = server_port;
    manager.plugin = plugin;
    manager.plugin_opts = plugin_opts;
    manager.mtu = mtu;
    manager.ipv6first = ipv6first;
    manager.executable = executable;
    manager.working_dir = working_dir;

    // initialize ev signals
    struct ev_signal sigint_watcher;
    struct ev_signal sigterm_watcher;
    ev_signal_init(&sigint_watcher, signal_cb, SIGINT);
    ev_signal_init(&sigterm_watcher, signal_cb, SIGTERM);
    ev_signal_start(loop, &sigint_watcher);
    ev_signal_start(loop, &sigterm_watcher);

    struct manager_ctx ctx;
    memset(&ctx, 0, sizeof(struct manager_ctx));
    ctx.manager = &manager;
    ctx.loop = loop;

    if (manager_address != NULL) {
        ctx.fd = create_server_socket(manager_address, NULL);
        if (ctx.fd == -1) {
            FATAL("failed to bind to manager address");
        }
    }

    // initialize ev io
    ev_io_init(&ctx.io, manager_recv_cb, ctx.fd, EV_READ);
    ev_io_start(loop, &ctx.io);

    // start ev loop
    ev_run(loop, 0);

    if (verbose) {
        LOGI("closed gracefully");
    }

    // clean up
    ev_signal_stop(loop, &sigint_watcher);
    ev_signal_stop(loop, &sigterm_watcher);
    ev_io_stop(loop, &ctx.io);

    if (ctx.fd != -1) {
        close(ctx.fd);
    }

    return 0;
}
