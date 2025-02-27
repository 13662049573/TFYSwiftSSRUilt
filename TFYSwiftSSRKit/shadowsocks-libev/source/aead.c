/*
 * aead.c - Manage AEAD ciphers
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

#include <mbedtls/version.h>
#define CIPHER_UNSUPPORTED "unsupported"
#include <time.h>
#include <stdio.h>
#include <assert.h>

#include <sodium.h>
#ifndef __MINGW32__
#include <arpa/inet.h>
#endif

#include "ppbloom.h"
#include "aead.h"
#include "utils.h"
#include "winsock.h"

// Add function declaration at the top
void crypto_aead_aes256gcm_free_state(void *ctx);

#define NONE                    (-1)
#define AES128GCM               0
#define AES192GCM               1
#define AES256GCM               2
/*
 * methods above requires gcm context
 * methods below doesn't require it,
 * then we need to fake one
 */
#define CHACHA20POLY1305IETF    3

#ifdef FS_HAVE_XCHACHA20IETF
#define XCHACHA20POLY1305IETF   4
#endif

#define CHUNK_SIZE_LEN          2
#define CHUNK_SIZE_MASK         0x3FFF

/*
 * Spec: http://shadowsocks.org/en/spec/AEAD-Ciphers.html
 *
 * The way Shadowsocks using AEAD ciphers is specified in SIP004 and amended in SIP007. SIP004 was proposed by @Mygod
 * with design inspirations from @wongsyrone, @Noisyfox and @breakwa11. SIP007 was proposed by @riobard with input from
 * @madeye, @Mygod, @wongsyrone, and many others.
 *
 * Key Derivation
 *
 * HKDF_SHA1 is a function that takes a secret key, a non-secret salt, an info string, and produces a subkey that is
 * cryptographically strong even if the input secret key is weak.
 *
 *      HKDF_SHA1(key, salt, info) => subkey
 *
 * The info string binds the generated subkey to a specific application context. In our case, it must be the string
 * "ss-subkey" without quotes.
 *
 * We derive a per-session subkey from a pre-shared master key using HKDF_SHA1. Salt must be unique through the entire
 * life of the pre-shared master key.
 *
 * TCP
 *
 * An AEAD encrypted TCP stream starts with a randomly generated salt to derive the per-session subkey, followed by any
 * number of encrypted chunks. Each chunk has the following structure:
 *
 *      [encrypted payload length][length tag][encrypted payload][payload tag]
 *
 * Payload length is a 2-byte big-endian unsigned integer capped at 0x3FFF. The higher two bits are reserved and must be
 * set to zero. Payload is therefore limited to 16*1024 - 1 bytes.
 *
 * The first AEAD encrypt/decrypt operation uses a counting nonce starting from 0. After each encrypt/decrypt operation,
 * the nonce is incremented by one as if it were an unsigned little-endian integer. Note that each TCP chunk involves
 * two AEAD encrypt/decrypt operation: one for the payload length, and one for the payload. Therefore each chunk
 * increases the nonce twice.
 *
 * UDP
 *
 * An AEAD encrypted UDP packet has the following structure:
 *
 *      [salt][encrypted payload][tag]
 *
 * The salt is used to derive the per-session subkey and must be generated randomly to ensure uniqueness. Each UDP
 * packet is encrypted/decrypted independently, using the derived subkey and a nonce with all zero bytes.
 *
 */

const char *supported_aead_ciphers[AEAD_CIPHER_NUM] = {
    "aes-128-gcm",
    "aes-192-gcm",
    "aes-256-gcm",
    "chacha20-ietf-poly1305",
#ifdef FS_HAVE_XCHACHA20IETF
    "xchacha20-ietf-poly1305"
#endif
};

/*
 * use mbed TLS cipher wrapper to unify handling
 */
static const char *supported_aead_ciphers_mbedtls[AEAD_CIPHER_NUM] = {
    "AES-128-GCM",
    "AES-192-GCM",
    "AES-256-GCM",
    CIPHER_UNSUPPORTED,
#ifdef FS_HAVE_XCHACHA20IETF
    CIPHER_UNSUPPORTED
#endif
};

static const int supported_aead_ciphers_nonce_size[AEAD_CIPHER_NUM] = {
    12, 12, 12, 12,
#ifdef FS_HAVE_XCHACHA20IETF
    24
#endif
};

static const int supported_aead_ciphers_key_size[AEAD_CIPHER_NUM] = {
    16, 24, 32, 32,
#ifdef FS_HAVE_XCHACHA20IETF
    32
#endif
};

static const int supported_aead_ciphers_tag_size[AEAD_CIPHER_NUM] = {
    16, 16, 16, 16,
#ifdef FS_HAVE_XCHACHA20IETF
    16
#endif
};

static int
aead_cipher_encrypt(struct cipher_ctx *ctx,
                   uint8_t *c, size_t *clen,
                   uint8_t *m, size_t mlen,
                   uint8_t *ad, size_t adlen,
                   uint8_t *n, uint8_t *k)
{
    int err = CRYPTO_OK;
    size_t nlen = ctx->cipher->nonce_len;
    size_t tlen = ctx->cipher->tag_len;

    switch (ctx->cipher->method) {
    case AES256GCM:
        if (ctx->aes256gcm_ctx != NULL) {
            unsigned long long long_clen = 0;
            err = crypto_aead_aes256gcm_encrypt_afternm(c, &long_clen, m, mlen,
                                                       ad, adlen, NULL, n,
                                                       ctx->aes256gcm_ctx);
            *clen = (size_t)long_clen;
            break;
        }
    case AES192GCM:
    case AES128GCM:
        err = mbedtls_cipher_auth_encrypt_ext(ctx->evp, n, nlen,
                                            ad, adlen,
                                            m, mlen,
                                            c, mlen + tlen,
                                            clen, tlen);
        break;
    case CHACHA20POLY1305IETF:
        {
            unsigned long long long_clen = 0;
            err = crypto_aead_chacha20poly1305_ietf_encrypt(c, &long_clen, m, mlen,
                                                           ad, adlen, NULL, n, k);
            *clen = (size_t)long_clen;
        }
        break;
#ifdef FS_HAVE_XCHACHA20IETF
    case XCHACHA20POLY1305IETF:
        {
            unsigned long long long_clen = 0;
            err = crypto_aead_xchacha20poly1305_ietf_encrypt(c, &long_clen, m, mlen,
                                                            ad, adlen, NULL, n, k);
            *clen = (size_t)long_clen;
        }
        break;
#endif
    default:
        return CRYPTO_ERROR;
    }

    return err;
}

static int
aead_cipher_decrypt(struct cipher_ctx *ctx,
                   uint8_t *p, size_t *plen,
                   uint8_t *m, size_t mlen,
                   uint8_t *ad, size_t adlen,
                   uint8_t *n, uint8_t *k)
{
    int err = CRYPTO_ERROR;
    size_t nlen = ctx->cipher->nonce_len;
    size_t tlen = ctx->cipher->tag_len;

    switch (ctx->cipher->method) {
    case AES256GCM:
        if (ctx->aes256gcm_ctx != NULL) {
            unsigned long long long_plen = 0;
            err = crypto_aead_aes256gcm_decrypt_afternm(p, &long_plen, NULL, m, mlen,
                                                       ad, adlen, n,
                                                       ctx->aes256gcm_ctx);
            *plen = (size_t)long_plen;
            break;
        }
    case AES192GCM:
    case AES128GCM:
        err = mbedtls_cipher_auth_decrypt_ext(ctx->evp, n, nlen,
                                            ad, adlen,
                                            m, mlen,
                                            p, mlen - tlen,
                                            plen, tlen);
        break;
    case CHACHA20POLY1305IETF:
        {
            unsigned long long long_plen = 0;
            err = crypto_aead_chacha20poly1305_ietf_decrypt(p, &long_plen, NULL, m, mlen,
                                                           ad, adlen, n, k);
            *plen = (size_t)long_plen;
        }
        break;
#ifdef FS_HAVE_XCHACHA20IETF
    case XCHACHA20POLY1305IETF:
        {
            unsigned long long long_plen = 0;
            err = crypto_aead_xchacha20poly1305_ietf_decrypt(p, &long_plen, NULL, m, mlen,
                                                            ad, adlen, n, k);
            *plen = (size_t)long_plen;
        }
        break;
#endif
    default:
        return CRYPTO_ERROR;
    }

    return err;
}

/*
 * get basic cipher info structure
 * it's a wrapper offered by crypto library
 */
const cipher_kt_t *
aead_get_cipher_type(int method)
{
    if (method < AES128GCM || method >= AEAD_CIPHER_NUM) {
        LOGE("aead_get_cipher_type(): Illegal method");
        return NULL;
    }

    /* cipher that don't use mbed TLS, just return */
    if (method >= CHACHA20POLY1305IETF) {
        return NULL;
    }

    const char *ciphername  = supported_aead_ciphers[method];
    const char *mbedtlsname = supported_aead_ciphers_mbedtls[method];
    if (strcmp(mbedtlsname, CIPHER_UNSUPPORTED) == 0) {
        LOGE("Cipher %s currently is not supported by mbed TLS library",
             ciphername);
        return NULL;
    }
    return mbedtls_cipher_info_from_string(mbedtlsname);
}

static void
aead_cipher_ctx_set_key(struct cipher_ctx *cipher_ctx, int enc)
{
    const digest_type_t *md = mbedtls_md_info_from_string("SHA1");
    if (md == NULL) {
        FATAL("SHA1 Digest not found in crypto library");
    }

    int err = crypto_hkdf(md,
                          cipher_ctx->salt, cipher_ctx->cipher->key_len,
                          cipher_ctx->cipher->key, cipher_ctx->cipher->key_len,
                          (uint8_t *)SUBKEY_INFO, strlen(SUBKEY_INFO),
                          cipher_ctx->skey, cipher_ctx->cipher->key_len);
    if (err) {
        FATAL("Unable to generate subkey");
    }

    memset(cipher_ctx->nonce, 0, cipher_ctx->cipher->nonce_len);

    /* cipher that don't use mbed TLS, just return */
    if (cipher_ctx->cipher->method >= CHACHA20POLY1305IETF) {
        return;
    }
    if (cipher_ctx->aes256gcm_ctx != NULL) {
        if (crypto_aead_aes256gcm_beforenm(cipher_ctx->aes256gcm_ctx,
                                           cipher_ctx->skey) != 0) {
            FATAL("Cannot set libsodium cipher key");
        }
        return;
    }
    if (mbedtls_cipher_setkey(cipher_ctx->evp, cipher_ctx->skey,
                              cipher_ctx->cipher->key_len * 8, enc) != 0) {
        FATAL("Cannot set mbed TLS cipher key");
    }
    if (mbedtls_cipher_reset(cipher_ctx->evp) != 0) {
        FATAL("Cannot finish preparation of mbed TLS cipher context");
    }
}

#ifdef __APPLE__
#pragma GCC diagnostic ignored "-Wunused-function"
#endif

static void
aead_cipher_ctx_init(struct cipher_ctx *cipher_ctx, int method, int enc)
{
    if (method < AES128GCM || method >= AEAD_CIPHER_NUM) {
        LOGE("cipher_context_init(): Illegal method");
        return;
    }

    if (method >= CHACHA20POLY1305IETF) {
        return;
    }

    const char *ciphername = supported_aead_ciphers[method];

    const cipher_kt_t *cipher = aead_get_cipher_type(method);

    if (method == AES256GCM && crypto_aead_aes256gcm_is_available()) {
        cipher_ctx->aes256gcm_ctx = (aes256gcm_ctx *)ss_aligned_malloc(sizeof(aes256gcm_ctx));
        memset(cipher_ctx->aes256gcm_ctx, 0, sizeof(aes256gcm_ctx));
    } else {
        cipher_ctx->aes256gcm_ctx = NULL;
        cipher_ctx->evp = (cipher_evp_t *)ss_malloc(sizeof(cipher_evp_t));
        memset(cipher_ctx->evp, 0, sizeof(cipher_evp_t));
        cipher_evp_t *evp = cipher_ctx->evp;
        mbedtls_cipher_init(evp);
        if (mbedtls_cipher_setup(evp, cipher) != 0) {
            FATAL("Cannot initialize mbed TLS cipher context");
        }
    }

    if (cipher == NULL) {
        LOGE("Cipher %s not found in mbed TLS library", ciphername);
        FATAL("Cannot initialize mbed TLS cipher");
    }

#ifdef SS_DEBUG
    dump("KEY", (char *)cipher_ctx->cipher->key, cipher_ctx->cipher->key_len);
#endif
}

void aead_ctx_init(cipher_t *cipher, struct cipher_ctx *ctx, int enc)
{
    memset(ctx, 0, sizeof(struct cipher_ctx));
    ctx->cipher = cipher;
    ctx->init = 1;
}

void aead_ctx_release(struct cipher_ctx *ctx)
{
    if (ctx->chunk != NULL) {
        bfree(ctx->chunk);
        ctx->chunk = NULL;
    }
    if (ctx->aes256gcm_ctx != NULL) {
        crypto_aead_aes256gcm_free_state(ctx->aes256gcm_ctx);
        ctx->aes256gcm_ctx = NULL;
    }
    if (ctx->evp != NULL) {
        mbedtls_cipher_free(ctx->evp);
        ctx->evp = NULL;
    }
    memset(ctx, 0, sizeof(struct cipher_ctx));
}

int
aead_encrypt(buffer_t *plaintext, cipher_ctx_t *cipher_ctx, size_t capacity)
{
    cipher_ctx_t ctx;
    aead_ctx_init(cipher_ctx->cipher, &ctx, 1);

    size_t salt_len = cipher_ctx->cipher->key_len;
    size_t tag_len = cipher_ctx->cipher->tag_len;
    int err = CRYPTO_OK;

    static buffer_t tmp = { 0, 0, 0, NULL };
    brealloc(&tmp, salt_len + tag_len + plaintext->len, capacity);
    buffer_t *ciphertext = &tmp;
    ciphertext->len = tag_len + plaintext->len;

    /* copy salt to first pos */
    memcpy(ciphertext->data, ctx.salt, salt_len);

    ppbloom_add((void *)ctx.salt, salt_len);

    aead_cipher_ctx_set_key(&ctx, 1);

    size_t clen = ciphertext->len;
    err = aead_cipher_encrypt(&ctx,
                            (uint8_t *)ciphertext->data + salt_len, &clen,
                            (uint8_t *)plaintext->data, plaintext->len,
                            NULL, 0, ctx.nonce, ctx.skey);

    aead_ctx_release(&ctx);

    if (err)
        return CRYPTO_ERROR;

    assert(ciphertext->len == clen);

    brealloc(plaintext, salt_len + ciphertext->len, capacity);
    memcpy(plaintext->data, ciphertext->data, salt_len + ciphertext->len);
    plaintext->len = salt_len + ciphertext->len;

    return CRYPTO_OK;
}

int
aead_decrypt(buffer_t *ciphertext, cipher_ctx_t *cipher_ctx, size_t capacity)
{
    size_t salt_len = cipher_ctx->cipher->key_len;
    size_t tag_len = cipher_ctx->cipher->tag_len;
    int err = CRYPTO_OK;

    if (ciphertext->len <= salt_len + tag_len) {
        return CRYPTO_ERROR;
    }

    cipher_ctx_t ctx;
    aead_ctx_init(cipher_ctx->cipher, &ctx, 0);

    static buffer_t tmp = { 0, 0, 0, NULL };
    brealloc(&tmp, ciphertext->len, capacity);
    buffer_t *plaintext = &tmp;
    plaintext->len = ciphertext->len - salt_len - tag_len;

    /* get salt */
    uint8_t *salt = ctx.salt;
    memcpy(salt, ciphertext->data, salt_len);

    if (ppbloom_check((void *)salt, salt_len) == 1) {
        LOGE("crypto: AEAD: repeat salt detected");
        return CRYPTO_ERROR;
    }

    aead_cipher_ctx_set_key(&ctx, 0);

    size_t plen = plaintext->len;
    err = aead_cipher_decrypt(&ctx,
                            (uint8_t *)plaintext->data, &plen,
                            (uint8_t *)ciphertext->data + salt_len,
                            ciphertext->len - salt_len, NULL, 0,
                            ctx.nonce, ctx.skey);

    aead_ctx_release(&ctx);

    if (err)
        return CRYPTO_ERROR;

    ppbloom_add((void *)salt, salt_len);

    brealloc(ciphertext, plaintext->len, capacity);
    memcpy(ciphertext->data, plaintext->data, plaintext->len);
    ciphertext->len = plaintext->len;

    return CRYPTO_OK;
}

static inline int
aead_chunk_encrypt(struct cipher_ctx *ctx, uint8_t *p, uint8_t *c,
                   uint8_t *n, uint16_t plen)
{
    size_t nlen = ctx->cipher->nonce_len;
    size_t tlen = ctx->cipher->tag_len;

    assert(plen <= CHUNK_SIZE_MASK);

    int err;
    size_t clen;
    uint8_t len_buf[CHUNK_SIZE_LEN];
    uint16_t t = htons(plen & CHUNK_SIZE_MASK);
    memcpy(len_buf, &t, CHUNK_SIZE_LEN);

    clen = CHUNK_SIZE_LEN + tlen;
    err  = aead_cipher_encrypt(ctx, c, &clen, len_buf, CHUNK_SIZE_LEN,
                               NULL, 0, n, ctx->skey);
    if (err)
        return CRYPTO_ERROR;

    assert(clen == CHUNK_SIZE_LEN + tlen);

    sodium_increment(n, nlen);

    clen = plen + tlen;
    err  = aead_cipher_encrypt(ctx, c + CHUNK_SIZE_LEN + tlen, &clen, p, plen,
                               NULL, 0, n, ctx->skey);
    if (err)
        return CRYPTO_ERROR;

    assert(clen == plen + tlen);

    sodium_increment(n, nlen);

    return CRYPTO_OK;
}

static inline int
aead_chunk_decrypt(cipher_ctx_t *ctx, uint8_t *p, size_t *plen,
                   uint8_t *c, size_t clen, uint8_t *n, uint16_t tlen)
{
    int err;
    size_t mlen;

    if (clen <= 2 * tlen) {
        return CRYPTO_ERROR;
    }

    uint8_t len_buf[2];
    err = aead_cipher_decrypt(ctx, len_buf, &mlen, c, CHUNK_SIZE_LEN + tlen,
                            NULL, 0, n, ctx->skey);
    if (err) {
        return CRYPTO_ERROR;
    }

    uint16_t chunk_len = ntohs(*(uint16_t *)len_buf);
    if (chunk_len > CHUNK_SIZE_MASK) {
        return CRYPTO_ERROR;
    }

    if (clen < CHUNK_SIZE_LEN + tlen + chunk_len + tlen) {
        return CRYPTO_ERROR;
    }

    err = aead_cipher_decrypt(ctx, p, plen,
                            c + CHUNK_SIZE_LEN + tlen, chunk_len + tlen,
                            NULL, 0, n, ctx->skey);
    if (err) {
        return CRYPTO_ERROR;
    }

    assert(*plen == chunk_len);

    return CRYPTO_OK;
}

/* TCP */
int
aead_encrypt_tcp(cipher_ctx_t *cipher_ctx, size_t nlen,
             uint8_t *n, size_t adlen, uint8_t *ad,
             size_t mlen, uint8_t *m, uint8_t *c)
{
    int err                      = CRYPTO_OK;
    size_t clen                 = 0;
    size_t tag_len              = cipher_ctx->cipher->tag_len;
    uint8_t *ctext              = c;
    uint8_t *ptext              = m;
    size_t plen                 = mlen;

    err = mbedtls_cipher_auth_encrypt_ext(cipher_ctx->evp, n, nlen, ad, adlen,
                                         ptext, plen, ctext, mlen + tag_len,
                                         &clen, tag_len);

    if (err) {
        return CRYPTO_ERROR;
    }

    return CRYPTO_OK;
}

int
aead_decrypt_tcp(cipher_ctx_t *cipher_ctx, size_t nlen,
             uint8_t *n, size_t adlen, uint8_t *ad,
             size_t clen, uint8_t *c, uint8_t *m)
{
    int err                      = CRYPTO_OK;
    size_t mlen                 = 0;
    size_t tag_len              = cipher_ctx->cipher->tag_len;
    uint8_t *ctext              = c;
    uint8_t *ptext              = m;
    size_t plen                 = clen - tag_len;

    err = mbedtls_cipher_auth_decrypt_ext(cipher_ctx->evp, n, nlen, ad, adlen,
                                         ctext, clen, ptext, plen,
                                         &mlen, tag_len);

    if (err) {
        return CRYPTO_ERROR;
    }

    return CRYPTO_OK;
}

cipher_t *
aead_key_init(int method, const char *pass, const char *key)
{
    if (method < AEAD_CIPHER_NUM) {
        cipher_t *cipher = (cipher_t *)ss_malloc(sizeof(cipher_t));
        if (cipher == NULL) {
            return NULL;
        }
        memset(cipher, 0, sizeof(cipher_t));

        if (method >= AES128GCM && method <= AES256GCM) {
            const cipher_kt_t *info = mbedtls_cipher_info_from_values(MBEDTLS_CIPHER_ID_AES,
                                                          supported_aead_ciphers_key_size[method] * 8,
                                                          MBEDTLS_MODE_GCM);
            if (info == NULL) {
                FATAL("Failed to get cipher info");
            }
            cipher->info = (cipher_kt_t *)info;
        } else {
            cipher->info = NULL;
        }

        cipher->method = method;
        cipher->nonce_len = supported_aead_ciphers_nonce_size[method];
        cipher->key_len = supported_aead_ciphers_key_size[method];
        cipher->tag_len = supported_aead_ciphers_tag_size[method];
        cipher->key = NULL;

        if (key != NULL) {
            cipher->key = (uint8_t *)ss_malloc(cipher->key_len);
            if (cipher->key != NULL) {
                memcpy(cipher->key, key, cipher->key_len);
            } else {
                ss_free(cipher);
                return NULL;
            }
        }

        return cipher;
    }

    LOGE("aead_key_init(): Illegal method");
    return NULL;
}

cipher_t *
aead_init(const char *pass, const char *key, const char *method)
{
    int m = AES128GCM;
    if (method != NULL) {
        /* check method validity */
        for (m = AES128GCM; m < AEAD_CIPHER_NUM; m++)
            if (strcmp(method, supported_aead_ciphers[m]) == 0) {
                break;
            }
        if (m >= AEAD_CIPHER_NUM) {
            LOGE("Invalid cipher name: %s, use chacha20-ietf-poly1305 instead", method);
            m = CHACHA20POLY1305IETF;
        }
    }
    return aead_key_init(m, pass, key);
}

int
aead_encrypt_all(buffer_t *plaintext, cipher_t *cipher, size_t capacity)
{
    size_t salt_len = cipher->key_len;
    size_t tag_len = cipher->tag_len;
    int err = CRYPTO_OK;

    struct cipher_ctx ctx;
    aead_ctx_init(cipher, &ctx, 1);

    // Generate random salt
    rand_bytes(ctx.salt, salt_len);

    // Derive key from password
    const char *key = (const char *)cipher->key;  // Add explicit cast
    crypto_derive_key(key, ctx.skey, salt_len);

    size_t clen = plaintext->len + tag_len;
    err = aead_cipher_encrypt(&ctx,
                            (uint8_t *)plaintext->data, &clen,
                            (uint8_t *)plaintext->data, plaintext->len,
                            NULL, 0, ctx.nonce, ctx.skey);

    if (!err) {
        plaintext->len = clen;
    }

    aead_ctx_release(&ctx);

    return err;
}

int
aead_decrypt_all(buffer_t *ciphertext, cipher_t *cipher, size_t capacity)
{
    size_t salt_len = cipher->key_len;
    size_t tag_len = cipher->tag_len;
    int err = CRYPTO_OK;

    struct cipher_ctx ctx;
    aead_ctx_init(cipher, &ctx, 0);

    // Copy salt
    memcpy(ctx.salt, ciphertext->data, salt_len);

    // Derive key from password
    const char *key = (const char *)cipher->key;  // Add explicit cast
    crypto_derive_key(key, ctx.skey, salt_len);

    size_t plen = ciphertext->len - tag_len;
    err = aead_cipher_decrypt(&ctx,
                            (uint8_t *)ciphertext->data, &plen,
                            (uint8_t *)ciphertext->data, ciphertext->len,
                            NULL, 0, ctx.nonce, ctx.skey);

    if (!err) {
        ciphertext->len = plen;
    }

    aead_ctx_release(&ctx);

    return err;
}

// Add function implementation
void crypto_aead_aes256gcm_free_state(void *ctx)
{
    if (ctx != NULL) {
        ss_aligned_free(ctx);
    }
}
