/*
 * encrypt.h - Define the enryptor's interface
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

#ifndef _ENCRYPT_H
#define _ENCRYPT_H

#include <sys/socket.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

// 加密库定义 - 专注于 iOS/macOS 平台
#include <sodium.h>
#include <mbedtls/cipher.h>
#include <mbedtls/md.h>

// Apple CommonCrypto 支持
#include <CommonCrypto/CommonCrypto.h>

// 类型定义
typedef mbedtls_cipher_info_t cipher_kt_t;
typedef mbedtls_cipher_context_t cipher_evp_t;
typedef mbedtls_md_info_t digest_type_t;

// 使用 libsodium 的 aes256gcm_ctx 定义
typedef crypto_aead_aes256gcm_state aes256gcm_ctx;

// 常量定义
#define MAX_KEY_LENGTH 64
#define MAX_IV_LENGTH MBEDTLS_MAX_IV_LENGTH
#define MAX_MD_SIZE MBEDTLS_MD_MAX_SIZE
#define SODIUM_BLOCK_SIZE 64

// 加密方法定义
#define TABLE -1
#define RC4 0
#define RC4_MD5 1
#define RC4_MD5_6 2
#define CIPHER_NUM 8

// 缓冲区结构
typedef struct buffer {
    size_t idx;
    size_t len;
    size_t capacity;
    char   *array;
} buffer_t;

// 数据块结构
typedef struct chunk {
    uint32_t idx;
    uint32_t len;
    uint32_t counter;
    buffer_t *buf;
} chunk_t;

// Apple CommonCrypto 支持
typedef struct {
    CCCryptorRef cryptor;
    int valid;
    CCOperation encrypt;
    CCAlgorithm cipher;
    CCMode mode;
    CCPadding padding;
    uint8_t iv[MAX_IV_LENGTH];
    uint8_t key[MAX_KEY_LENGTH];
    size_t iv_len;
    size_t key_len;
} cipher_cc_t;

// 加密器结构
typedef struct {
    cipher_kt_t *info;
    size_t key_len;
    size_t iv_len;
    size_t nonce_len;
    size_t tag_len;
    int method;
    uint8_t *key;
    aes256gcm_ctx *aes256gcm_ctx;
} cipher_t;

// 加密上下文结构
typedef struct {
    cipher_evp_t *evp;
    cipher_t *cipher;
    uint8_t *key;
    uint8_t *iv;
    size_t iv_len;
    int method;
    int enc;
    int init;
    chunk_t *chunk;
    aes256gcm_ctx *aes256gcm_ctx;
#ifdef USE_CRYPTO_APPLECC
    cipher_cc_t cc;
#endif
} cipher_ctx_t;

// 加密上下文
typedef struct enc_ctx {
    uint8_t init;
    uint64_t counter;
    cipher_ctx_t evp;
} enc_ctx_t;

// 现代加密方法
enum cipher_method {
    NONE = -1,
    AES_128_CFB,
    AES_192_CFB,
    AES_256_CFB,
    CHACHA20,
    CHACHA20IETF,
    SALSA20,
    AES_256_GCM,
    CHACHA20POLY1305
};

// 认证标志和常量
#define ONETIMEAUTH_FLAG 0x10
#define ADDRTYPE_MASK 0xF
#define ONETIMEAUTH_BYTES 10U
#define CLEN_BYTES 2U
#define AUTH_BYTES (ONETIMEAUTH_BYTES + CLEN_BYTES)

// 工具宏
#define min(a, b) (((a) < (b)) ? (a) : (b))
#define max(a, b) (((a) > (b)) ? (a) : (b))

// 函数声明
// 加密/解密函数
int ss_encrypt_all(buffer_t *plaintext, int method, int auth, size_t capacity);
int ss_decrypt_all(buffer_t *ciphertext, int method, int auth, size_t capacity);
int ss_encrypt(buffer_t *plaintext, enc_ctx_t *ctx, size_t capacity);
int ss_decrypt(buffer_t *ciphertext, enc_ctx_t *ctx, size_t capacity);

// 上下文管理
void enc_ctx_init(int method, enc_ctx_t *ctx, int enc);
int enc_init(const char *pass, const char *method);
void cipher_context_release(cipher_ctx_t *evp);

// 密钥和IV管理
int enc_get_iv_len(void);
uint8_t* enc_get_key(void);
int enc_get_key_len(void);
int rand_bytes(uint8_t *output, int len);
int crypto_parse_key(const char *key, uint8_t *buf, size_t buf_len);
int crypto_derive_key(const char *pass, uint8_t *key, size_t key_len);

// 哈希和认证
unsigned char *enc_md5(const unsigned char *d, size_t n, unsigned char *md);
int ss_sha1_hmac(char *auth, char *msg, int msg_len, uint8_t *iv);
int ss_sha1_hmac_with_key(char *auth, char *msg, int msg_len, uint8_t *auth_key, int key_len);
int ss_onetimeauth(buffer_t *buf, uint8_t *iv, size_t capacity);
int ss_onetimeauth_verify(buffer_t *buf, uint8_t *iv);

// 哈希检查和生成
int ss_check_hash(buffer_t *buf, chunk_t *chunk, enc_ctx_t *ctx, size_t capacity);
int ss_gen_hash(buffer_t *buf, uint32_t *counter, enc_ctx_t *ctx, size_t capacity);

// 缓冲区管理
int balloc(buffer_t *ptr, size_t capacity);
int brealloc(buffer_t *ptr, size_t len, size_t capacity);
void bfree(buffer_t *ptr);

#endif // _ENCRYPT_H
