#pragma once

#include <cstdint>
#include <cuda_runtime.h>
#include <cstring>

struct H160 { uint32_t w[5]; };   // 5-word hash160, returned in registers
struct U256 { uint64_t v[4]; };   // 256-bit x-coordinate, passed in registers

// Pack 4 limbs into the by-value carrier. __forceinline__, so this is register moves, not a copy.
__device__ __forceinline__ U256 u256_of(const uint64_t x[4]) {
    U256 r; r.v[0] = x[0]; r.v[1] = x[1]; r.v[2] = x[2]; r.v[3] = x[3]; return r;
}

// Hot path: hash160 word 2 only (the cheapest of the five to produce -- see the trim rationale
// on RIPEMD160Transform in CUDAHash.cu). Returning one register instead of five also narrows
__device__ uint32_t getHash160_w2_from_limbs(uint8_t prefix02_03, U256 x);

// Cold path: the full 160-bit digest, for confirming a word-2 filter hit (~2^-32 of keys).
__device__ H160 getHash160_33_from_limbs(uint8_t prefix02_03, U256 x);