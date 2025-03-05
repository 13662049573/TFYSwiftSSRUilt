/*
 * aead.h - Define the AEAD interface for iOS/macOS platforms
 */

#ifndef _AEAD_H
#define _AEAD_H

#include <stdint.h>
#include <stddef.h>
#include <sodium.h>
#include <mbedtls/cipher.h>
#include <mbedtls/md.h>
#include "encrypt.h"  // 包含所有基本类型定义

#ifdef USE_CRYPTO_APPLECC
#include <CommonCrypto/CommonCrypto.h>

// Apple CommonCrypto 上下文
typedef struct cc_ctx {
    CCCryptorRef cryptor;
    int valid;
    CCOperation encrypt;
    CCAlgorithm cipher;
    CCMode mode;
    CCPadding padding;
    uint8_t iv[32];  // MAX_IV_LENGTH
    uint8_t key[64]; // MAX_KEY_LENGTH
    size_t iv_len;
    size_t key_len;
} cc_ctx_t;
#endif

// 常量定义
#define CRYPTO_ERROR -1
#define CRYPTO_OK 0
#define SUBKEY_INFO "ss-subkey"
#define SUBKEY_INFO_LEN 9

#define CHUNK_SIZE_LEN 2
#define CHUNK_SIZE_MASK 0x3FFF

// AEAD 加密方法定义
#define AEAD_CIPHER_NUM 4
#define AES_128_GCM 0
#define AES_192_GCM 1
#define AES_256_GCM 2
#define CHACHA20_IETF_POLY1305 3

// AEAD 加密/解密函数
int aead_encrypt_all(buffer_t *plaintext, cipher_t *cipher, size_t capacity);
int aead_decrypt_all(buffer_t *ciphertext, cipher_t *cipher, size_t capacity);

// 流式加密/解密
int aead_encrypt(buffer_t *plaintext, cipher_ctx_t *ctx, size_t capacity);
int aead_decrypt(buffer_t *ciphertext, cipher_ctx_t *ctx, size_t capacity);

// TCP 加密/解密
int aead_encrypt_tcp(cipher_ctx_t *ctx, size_t nlen, uint8_t *n, uint16_t plen,
                    uint8_t *p, uint8_t *c);
int aead_decrypt_tcp(cipher_ctx_t *ctx, size_t nlen, uint8_t *n, size_t clen,
                    uint8_t *c, uint8_t *p);

// 上下文管理
void aead_ctx_init(cipher_t *cipher, cipher_ctx_t *ctx, int enc);
void aead_ctx_release(cipher_ctx_t *ctx);

// 密钥初始化
cipher_t *aead_init(int method, const char *pass, const char *key);

// 内部函数声明
int crypto_hkdf(const mbedtls_md_info_t *md, const unsigned char *salt,
                size_t salt_len, const unsigned char *ikm, size_t ikm_len,
                const unsigned char *info, size_t info_len, unsigned char *okm,
                size_t okm_len);

int balloc(buffer_t *ptr, size_t capacity);
int brealloc(buffer_t *ptr, size_t len, size_t capacity);

#ifdef USE_CRYPTO_APPLECC
void crypto_aead_aes256gcm_init_with_cc(void);
void crypto_aead_aes256gcm_release_with_cc(void);
int crypto_aead_aes256gcm_encrypt_with_cc(uint8_t *c, unsigned long long *clen,
                                         const uint8_t *m, unsigned long long mlen,
                                         const uint8_t *ad, unsigned long long adlen,
                                         const uint8_t *nsec, const uint8_t *npub,
                                         const uint8_t *k);
int crypto_aead_aes256gcm_decrypt_with_cc(uint8_t *m, unsigned long long *mlen,
                                         uint8_t *nsec,
                                         const uint8_t *c, unsigned long long clen,
                                         const uint8_t *ad, unsigned long long adlen,
                                         const uint8_t *npub, const uint8_t *k);
#endif

void crypto_aead_aes256gcm_free_state(void *ctx);

#endif // _AEAD_H
