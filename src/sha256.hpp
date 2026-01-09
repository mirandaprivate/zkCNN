#ifndef ZKCNN_SHA256_HPP
#define ZKCNN_SHA256_HPP

#include <vector>
#include <string>
#include <cstring>
#include <cstdint>

class SHA256 {
public:
    SHA256() { init(); }

    void update(const uint8_t* data, size_t length) {
        size_t i = 0;
        size_t index = (count[0] >> 3) & 0x3f;
        if ((count[0] += ((uint32_t)length << 3)) < ((uint32_t)length << 3)) count[1]++;
        count[1] += ((uint32_t)length >> 29);
        size_t partLen = 64 - index;
        if (length >= partLen) {
            memcpy(&buffer[index], data, partLen);
            transform(buffer);
            for (i = partLen; i + 63 < length; i += 64) transform(&data[i]);
            index = 0;
        }
        memcpy(&buffer[index], &data[i], length - i);
    }

    void final(uint8_t digest[32]) {
        uint8_t bits[8];
        // Standard SHA256 requires 64-bit length in big-endian (high 32 bits first)
        encode(bits, &count[1], 4);
        encode(bits + 4, &count[0], 4);
        size_t index = (count[0] >> 3) & 0x3f;
        size_t padLen = (index < 56) ? (56 - index) : (120 - index);
        static const uint8_t PADDING[64] = {0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        update(PADDING, padLen);
        update(bits, 8);
        encode(digest, state, 32);
        init();
    }

private:
    uint32_t state[8];
    uint32_t count[2];
    uint8_t buffer[64];

    void init() {
        state[0] = 0x6a09e667; state[1] = 0xbb67ae85; state[2] = 0x3c6ef372; state[3] = 0xa54ff53a;
        state[4] = 0x510e527f; state[5] = 0x9b05688c; state[6] = 0x1f83d9ab; state[7] = 0x5be0cd19;
        count[0] = count[1] = 0;
    }

    void transform(const uint8_t block[64]) {
        uint32_t a = state[0], b = state[1], c = state[2], d = state[3], e = state[4], f = state[5], g = state[6], h = state[7], x[16];
        decode(x, block, 64);
        #define S(x, n) (((x) >> (n)) | ((uint32_t)(x) << (32 - (n))))
        #define R(x, n) ((x) >> (n))
        #define Ch(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
        #define Maj(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
        #define Sigma0(x) (S(x, 2) ^ S(x, 13) ^ S(x, 22))
        #define Sigma1(x) (S(x, 6) ^ S(x, 11) ^ S(x, 25))
        #define gamma0(x) (S(x, 7) ^ S(x, 18) ^ R(x, 3))
        #define gamma1(x) (S(x, 17) ^ S(x, 19) ^ R(x, 10))
        uint32_t w[64];
        for (int i = 0; i < 16; i++) w[i] = x[i];
        for (int i = 16; i < 64; i++) w[i] = gamma1(w[i - 2]) + w[i - 7] + gamma0(w[i - 15]) + w[i - 16];
        static const uint32_t k[64] = {
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        };
        for (int i = 0; i < 64; i++) {
            uint32_t t1 = h + Sigma1(e) + Ch(e, f, g) + k[i] + w[i];
            uint32_t t2 = Sigma0(a) + Maj(a, b, c);
            h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        state[0] += a; state[1] += b; state[2] += c; state[3] += d;
        state[4] += e; state[5] += f; state[6] += g; state[7] += h;
    }

    void encode(uint8_t* output, const uint32_t* input, size_t len) {
        for (size_t i = 0, j = 0; j < len; i++, j += 4) {
            output[j] = (uint8_t)((input[i] >> 24) & 0xff);
            output[j+1] = (uint8_t)((input[i] >> 16) & 0xff);
            output[j+2] = (uint8_t)((input[i] >> 8) & 0xff);
            output[j+3] = (uint8_t)(input[i] & 0xff);
        }
    }

    void decode(uint32_t* output, const uint8_t* input, size_t len) {
        for (size_t i = 0, j = 0; j < len; i++, j += 4)
            output[i] = ((uint32_t)input[j] << 24) | ((uint32_t)input[j+1] << 16) | ((uint32_t)input[j+2] << 8) | (uint32_t)input[j+3];
    }
};

#endif
