#ifndef MAXMINDDB_H
#define MAXMINDDB_H

#ifdef __cplusplus
extern "C" {
#endif

/* 基本类型定义 */
typedef struct MMDB_s {
    int dummy;
} MMDB_s;

/* 基本函数声明 */
int MMDB_open(const char *filename, int flags, MMDB_s *mmdb);
void MMDB_close(MMDB_s *mmdb);

#ifdef __cplusplus
}
#endif

#endif /* MAXMINDDB_H */
