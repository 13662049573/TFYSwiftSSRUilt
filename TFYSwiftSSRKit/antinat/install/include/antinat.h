#ifndef ANTINAT_H
#define ANTINAT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <maxminddb.h>
#include <sodium.h>
#include <openssl/ssl.h>
#include <shadowsocks.h>

/* Version information */
#define ANTINAT_VERSION "0.93"

/* Basic functions */
int antinat_init(void);
void antinat_cleanup(void);
int antinat_start_proxy(const char *config_path);
void antinat_stop_proxy(void);

/* Error codes */
#define ANTINAT_SUCCESS 0
#define ANTINAT_ERROR_INIT -1
#define ANTINAT_ERROR_CONFIG -2
#define ANTINAT_ERROR_PROXY -3

#ifdef __cplusplus
}
#endif

#endif /* ANTINAT_H */
