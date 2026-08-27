// Count Karatsuba's additions against its saved multiplies, on the only 256x256 that matters:
// 8 x 32-bit limbs, which is what IMAD.WIDE gives. The Montgomery/K reduction is UNCHANGED by
// Karatsuba, so only the 256x256 -> 512 product is modelled here; that is exactly the part the
// 64 -> 48 multiply claim applies to.
//
// Correctness is checked before any count is taken: -DHOSTTEST builds a main() that runs the
// two against each other over random operands. A Karatsuba that is wrong would produce a
// perfectly countable and perfectly meaningless instruction mix.
typedef unsigned int u32;
typedef unsigned long long u64;

#ifdef HOSTTEST
#define DEV
#define GLB
#else
#define DEV __device__ __forceinline__
#define GLB __global__
#endif

// ---- 4x4 -> 8 limbs, 16 multiplies -------------------------------------------------
DEV void mul4(u32* r, const u32* a, const u32* b) {
#pragma unroll
    for (int i = 0; i < 8; i++) r[i] = 0;
#pragma unroll
    for (int i = 0; i < 4; i++) {
        u32 carry = 0;
#pragma unroll
        for (int j = 0; j < 4; j++) {
            u64 t = (u64)a[i] * b[j] + r[i + j] + carry;
            r[i + j] = (u32)t;
            carry = (u32)(t >> 32);
        }
        r[i + 4] = carry;
    }
}

// ---- 8x8 -> 16 limbs, 64 multiplies ------------------------------------------------
DEV void mul8_school(u32* r, const u32* a, const u32* b) {
#pragma unroll
    for (int i = 0; i < 16; i++) r[i] = 0;
#pragma unroll
    for (int i = 0; i < 8; i++) {
        u32 carry = 0;
#pragma unroll
        for (int j = 0; j < 8; j++) {
            u64 t = (u64)a[i] * b[j] + r[i + j] + carry;
            r[i + j] = (u32)t;
            carry = (u32)(t >> 32);
        }
        r[i + 8] = carry;
    }
}

// |x - y| over 4 limbs; returns 1 if x < y. Subtractive Karatsuba, so the operands stay
// 128 bits and the middle product is another 4x4 rather than a 5x5.
DEV u32 absdiff4(u32* d, const u32* x, const u32* y) {
    u32 borrow = 0;
#pragma unroll
    for (int i = 0; i < 4; i++) {
        u64 t = (u64)x[i] - y[i] - borrow;
        d[i] = (u32)t;
        borrow = (u32)((t >> 32) & 1);
    }
    if (borrow) {                       // negate in place
        u32 c = 1;
#pragma unroll
        for (int i = 0; i < 4; i++) {
            u64 t = (u64)(~d[i]) + c;
            d[i] = (u32)t;
            c = (u32)(t >> 32);
        }
    }
    return borrow;
}

// ---- Karatsuba: 3 x 16 = 48 multiplies ---------------------------------------------
DEV void mul8_karat(u32* r, const u32* a, const u32* b) {
    u32 z0[8], z2[8], m[8], dA[4], dB[4];
    mul4(z0, a, b);
    mul4(z2, a + 4, b + 4);
    u32 sA = absdiff4(dA, a + 4, a);
    u32 sB = absdiff4(dB, b + 4, b);
    mul4(m, dA, dB);
    u32 neg = sA ^ sB;                  // sign of (A1-A0)(B1-B0)

    // z1 = z0 + z2 - (A1-A0)(B1-B0) = z0 + z2 -/+ m, up to 257 bits
    u32 z1[8], k = 0;
    {
        u32 c = 0;
#pragma unroll
        for (int i = 0; i < 8; i++) {
            u64 t = (u64)z0[i] + z2[i] + c;
            z1[i] = (u32)t; c = (u32)(t >> 32);
        }
        k = c;
    }
    if (neg) {
        u32 c = 0;
#pragma unroll
        for (int i = 0; i < 8; i++) {
            u64 t = (u64)z1[i] + m[i] + c;
            z1[i] = (u32)t; c = (u32)(t >> 32);
        }
        k += c;
    } else {
        u32 bw = 0;
#pragma unroll
        for (int i = 0; i < 8; i++) {
            u64 t = (u64)z1[i] - m[i] - bw;
            z1[i] = (u32)t; bw = (u32)((t >> 32) & 1);
        }
        k -= bw;
    }

    // r = z0 + z1<<128 + z2<<256
#pragma unroll
    for (int i = 0; i < 8; i++) { r[i] = z0[i]; r[i + 8] = z2[i]; }
    u32 c = 0;
#pragma unroll
    for (int i = 0; i < 8; i++) {
        u64 t = (u64)r[i + 4] + z1[i] + c;
        r[i + 4] = (u32)t; c = (u32)(t >> 32);
    }
    c += k;
#pragma unroll
    for (int i = 12; i < 16 && c; i++) {
        u64 t = (u64)r[i] + c;
        r[i] = (u32)t; c = (u32)(t >> 32);
    }
}

#ifndef HOSTTEST
GLB void kSchool(const u32* __restrict__ a, const u32* __restrict__ b, u32* __restrict__ o) {
    u32 r[16]; mul8_school(r, a, b);
#pragma unroll
    for (int i = 0; i < 16; i++) o[i] = r[i];
}
GLB void kKarat(const u32* __restrict__ a, const u32* __restrict__ b, u32* __restrict__ o) {
    u32 r[16]; mul8_karat(r, a, b);
#pragma unroll
    for (int i = 0; i < 16; i++) o[i] = r[i];
}
#else
#include <cstdio>
#include <cstdlib>
int main() {
    srand(20260827);
    int bad = 0;
    for (int t = 0; t < 200000; t++) {
        u32 a[8], b[8], r1[16], r2[16];
        for (int i = 0; i < 8; i++) { a[i] = (rand() << 17) ^ rand(); b[i] = (rand() << 17) ^ rand(); }
        if (t < 8) {                       // edge cases: all-ones, zero, one half zero
            for (int i = 0; i < 8; i++) { a[i] = (t & 1) ? 0xFFFFFFFFu : 0; b[i] = (t & 2) ? 0xFFFFFFFFu : 0; }
            if (t & 4) for (int i = 0; i < 4; i++) a[i] = 0;
        }
        mul8_school(r1, a, b);
        mul8_karat(r2, a, b);
        for (int i = 0; i < 16; i++) if (r1[i] != r2[i]) { bad++; break; }
    }
    printf("  karatsuba vs schoolbook over 200000 operand pairs: %s (%d mismatches)\n",
           bad ? "FAIL" : "OK", bad);
    return bad != 0;
}
#endif
