#pragma once

__device__ __forceinline__ bool ge256_u64(const uint64_t a[4], uint64_t b) {
    if (a[3] | a[2] | a[1]) return true;  // >= 2^64
    return a[0] >= b;
}

__device__ __forceinline__ void sub256_u64(uint64_t a[4], uint64_t dec) {
    uint64_t borrow = (a[0] < dec) ? 1ull : 0ull;
    a[0] = a[0] - dec;
    { uint64_t ai = a[1]; a[1] = ai - borrow; borrow = (ai < borrow) ? 1ull : 0ull; }
    { uint64_t ai = a[2]; a[2] = ai - borrow; borrow = (ai < borrow) ? 1ull : 0ull; }
    { uint64_t ai = a[3]; a[3] = ai - borrow; borrow = (ai < borrow) ? 1ull : 0ull; }
}

__device__ __forceinline__ void add256_u64(uint64_t a[4], uint64_t inc) {
    a[0] = a[0] + inc;
    uint64_t carry = (a[0] < inc) ? 1ull : 0ull;
    { uint64_t ai = a[1]; a[1] = ai + carry; carry = (a[1] < ai) ? 1ull : 0ull; }
    { uint64_t ai = a[2]; a[2] = ai + carry; carry = (a[2] < ai) ? 1ull : 0ull; }
    { uint64_t ai = a[3]; a[3] = ai + carry; carry = (a[3] < ai) ? 1ull : 0ull; }
}