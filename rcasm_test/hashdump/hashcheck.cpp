// hashcheck.cpp -- HOST reference for getHash160_w2 (branch f2m, full-pipeline hash lift).
//
// Compiles GpuHash.cu on the host with the device->host shims its own header comment prescribes
// (-D__device__= etc. + a __byte_perm stub; the ror32 path already falls back to shifts when
// __CUDA_ARCH__ is undefined). Purpose:
//   1. KNOWN-ANSWER TEST: hash160(02||Gx) must be 751e76e8199196d454941c45d1b3a323f1433bd6, and
//      getHash160_w2 must equal its word 2. This validates the input-limb order, the prefix, and
//      the LE word convention -- the exact ABI the manual kernel must marshal into the lifted hash.
//   2. GOLDEN GENERATION: for N pseudo-random inputs, dump {X limbs, prefix, hw2} to hashgolden.bin
//      so the GPU-side comparator can check the lifted manual hash bit-for-bit.
//
// Build (WSL, no GPU needed):
//   g++ -O2 -I rcasm_test/hashdump/shim -I . rcasm_test/hashdump/hashcheck.cpp -o hashcheck
// (-I . so "GpuHash.cuh" resolves from repo root; run from repo root.)

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>

// ---- device -> host shims -------------------------------------------------------------------
#define __device__
#define __forceinline__ inline
#define __noinline__
#define __global__
#define __constant__
#define __restrict__

// CUDA __byte_perm(x,y,s): bytes b[0..3]=x, b[4..7]=y; out byte i = b[(s>>4i)&7], or sign-fill
// (0x00/0xFF from that byte's MSB) when bit 3 of the nibble is set.
static inline uint32_t __byte_perm(uint32_t x, uint32_t y, uint32_t s){
    unsigned char b[8];
    b[0]=x&0xff; b[1]=(x>>8)&0xff; b[2]=(x>>16)&0xff; b[3]=(x>>24)&0xff;
    b[4]=y&0xff; b[5]=(y>>8)&0xff; b[6]=(y>>16)&0xff; b[7]=(y>>24)&0xff;
    uint32_t r=0;
    for(int i=0;i<4;i++){
        uint32_t nib=(s>>(4*i))&0xf, sel=nib&0x7; unsigned char v=b[sel];
        if(nib&0x8) v=(v&0x80)?0xff:0x00;
        r |= (uint32_t)v << (8*i);
    }
    return r;
}
// __funnelshift_r is only reached under __CUDA_ARCH__>=350, which is undefined here, so ror32
// uses the shift fallback and this stub is never called -- provide it anyway for safety.
static inline uint32_t __funnelshift_r(uint32_t lo, uint32_t hi, uint32_t n){
    n&=31; return n? ((lo>>n)|(hi<<(32-n))) : lo;
}

#include "GpuHash.cu"   // brings in the real SHA-256 + trimmed RIPEMD-160 word-2

// ---- helpers --------------------------------------------------------------------------------
static U256 mk(uint64_t a,uint64_t b,uint64_t c,uint64_t d){ U256 x; x.v[0]=a;x.v[1]=b;x.v[2]=c;x.v[3]=d; return x; }

int main(int argc, char** argv){
    int N = (argc>1)? atoi(argv[1]) : 8192;
    const char* out = (argc>2)? argv[2] : "hashgolden.bin";

    // ---- KAT: compressed generator pubkey 02||Gx --------------------------------------------
    U256 Gx = mk(0x59F2815B16F81798ull, 0x029BFCDB2DCE28D9ull,
                 0x55A06295CE870B07ull, 0x79BE667EF9DCBBACull);
    H160 h = getHash160_33_from_limbs(0x02, Gx);
    // expected hash160 751e76e8 199196d4 54941c45 d1b3a323 f1433bd6, as 5 LE words:
    const uint32_t exp[5] = {0xe8761e75u,0xd4969119u,0x451c9454u,0x23a3b3d1u,0xd63b43f1u};
    printf("KAT hash160(02||Gx):");
    for(int i=0;i<5;i++) printf(" %08x", h.w[i]);
    printf("\nexpected           :");
    for(int i=0;i<5;i++) printf(" %08x", exp[i]);
    printf("\n");
    int katok = (memcmp(h.w, exp, sizeof exp)==0);
    uint32_t w2 = getHash160_w2_from_limbs(0x02, Gx);
    printf("getHash160_w2 = %08x   (H160.w[2] = %08x)  %s\n", w2, h.w[2],
           (w2==h.w[2] && katok)?"KAT PASS":"KAT FAIL");
    if(!(katok && w2==h.w[2])){ printf("*** KAT FAILED -- host reference is wrong, stop ***\n"); return 2; }

    // ---- golden generation ------------------------------------------------------------------
    uint64_t* X = (uint64_t*)malloc((size_t)N*4*sizeof(uint64_t));
    uint8_t*  P = (uint8_t*)malloc((size_t)N);
    uint32_t* HW= (uint32_t*)malloc((size_t)N*sizeof(uint32_t));
    uint64_t s = 0x9e3779b97f4a7c15ull;   // deterministic splitmix64
    auto rnd=[&](){ s+=0x9e3779b97f4a7c15ull; uint64_t z=s; z=(z^(z>>30))*0xbf58476d1ce4e5b9ull; z=(z^(z>>27))*0x94d049bb133111ebull; return z^(z>>31); };
    uint32_t chk=0;
    for(int i=0;i<N;i++){
        U256 x = mk(rnd(),rnd(),rnd(),rnd());
        uint8_t pf = (rnd()&1)?0x03:0x02;
        uint32_t hw = getHash160_w2_from_limbs(pf, x);
        for(int k=0;k<4;k++) X[i*4+k]=x.v[k];
        P[i]=pf; HW[i]=hw; chk ^= hw + i;
    }
    FILE* f=fopen(out,"wb");
    uint32_t n=(uint32_t)N; fwrite(&n,4,1,f);
    fwrite(X,sizeof(uint64_t),(size_t)N*4,f);
    fwrite(P,1,(size_t)N,f);
    fwrite(HW,sizeof(uint32_t),(size_t)N,f);
    fclose(f);
    printf("wrote %s : N=%d  golden checksum=%08x\n", out, N, chk);
    return 0;
}
