#pragma once

#include <cstdint>
#include <cuda_runtime.h>
#include <cstring>

struct H160 { uint32_t w[5]; };   // 5-word hash160, returned in registers
struct U256 { uint64_t v[4]; };   // 256-bit x-coordinate, passed in registers

// Hot path: hash160 word 2 only -- the cheapest of the five to produce (see the trim rationale
// on RIPEMD160Transform in GpuHash.cu).
__device__ uint32_t getHash160_w2_from_limbs(uint8_t prefix02_03, U256 x);

// Cold path: the full 160-bit digest, for confirming a word-2 filter hit (~2^-32 of keys).
__device__ H160 getHash160_33_from_limbs(uint8_t prefix02_03, U256 x);

// h5/target_w hold a hash160 as 5 little-endian 32-bit words (word i = bytes [4i..4i+3]).
// There is deliberately no `prefix_equals(h5, w0)` helper: the 32-bit filter runs on WORD 2 and
// never materializes an H160 -- it compares getHash160_w2_from_limbs()'s return directly.
static __device__ __forceinline__ bool hash160_matches_full(
    const uint32_t h5[5], const uint32_t target_w[5])
{
    if (h5[0] != target_w[0]) return false;
    if (h5[1] != target_w[1]) return false;
    if (h5[2] != target_w[2]) return false;
    if (h5[3] != target_w[3]) return false;
    if (h5[4] != target_w[4]) return false;
    return true;
}

// Pack 4 limbs into the by-value carrier. __forceinline__, so this is register moves, not a copy.
__device__ __forceinline__ U256 u256_of(const uint64_t x[4]) {
    U256 r; r.v[0] = x[0]; r.v[1] = x[1]; r.v[2] = x[2]; r.v[3] = x[3]; return r;
}

// Rare path (~2^-32 of keys): on a word-2 filter hit, recompute the full 160-bit digest with the
// untrimmed hash and compare all five words. Must stay __forceinline__ so each call site keeps
// its `bool full = pref && ...` shape -- the found path's loop structure is load-bearing (see the
// found-path-refactor regression).
__device__ __forceinline__ bool hash160_full_match(uint8_t prefix02_03, U256 x,
                                                   const uint32_t target_w[5]) {
    H160 h5 = getHash160_33_from_limbs(prefix02_03, x);
    return hash160_matches_full(h5.w, target_w);
}