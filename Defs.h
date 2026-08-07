#pragma once

#include <cstdint>

//#define NO_GPU_MODE				1
#define DEBUG_MODE				0

#define SHOW_STAT_INTERVAL_SECS	5

#ifndef MAX_BATCH_SIZE
#define MAX_BATCH_SIZE			1024
#endif

#define MAX_GPU_CNT				32
#define THREADS_PER_BLOCK		256
#define MIN_THREADS_PER_BLOCK	32
#define BLOCKS_PER_SM			2
#define WARP_SIZE				32

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef int i32;
typedef unsigned short u16;
typedef short i16;
typedef unsigned char u8;
typedef char i8;
typedef __uint128_t uint128_t;

struct TFindResult {
    uint64_t scalar[4];
    uint64_t rx[4];
    uint64_t ry[4];
	bool     found;
};

//gpu kernel parameters
struct TKparams {
	uint64_t* scalars;
	uint64_t* counts;
	uint64_t* px;
	uint64_t* py;
	TFindResult* d_find_result;
	TFindResult* h_find_result;
	uint64_t points_per_run;
	uint64_t batch_size;
	uint64_t batches_per_launch;
	uint64_t threads_total;
	
	uint32_t block_count;
	uint32_t block_size;
};

#ifdef _WIN32

#else
static inline void _BitScanReverse64(u32* index, u64 msk) 
{
    *index = 63 - __builtin_clzll(msk); 
}

static inline void _BitScanForward64(u32* index, u64 msk) 
{
    *index = __builtin_ffsll(msk) - 1; 
}

static inline u64 _umul128(u64 m1, u64 m2, u64* hi) 
{ 
    uint128_t ab = (uint128_t)m1 * m2; *hi = (u64)(ab >> 64); return (u64)ab; 
}

static inline u64 __shiftright128 (u64 LowPart, u64 HighPart, u8 Shift)
{
   u64 ret;
   __asm__ ("shrd {%[Shift],%[HighPart],%[LowPart]|%[LowPart], %[HighPart], %[Shift]}" 
      : [ret] "=r" (ret)
      : [LowPart] "0" (LowPart), [HighPart] "r" (HighPart), [Shift] "Jc" (Shift)
      : "cc");
   return ret;
}

static inline u64 __shiftleft128 (u64 LowPart, u64 HighPart, u8 Shift)
{
   u64 ret;
   __asm__ ("shld {%[Shift],%[LowPart],%[HighPart]|%[HighPart], %[LowPart], %[Shift]}" 
      : [ret] "=r" (ret)
      : [LowPart] "r" (LowPart), [HighPart] "0" (HighPart), [Shift] "Jc" (Shift)
      : "cc");
   return ret;
}

#include <math.h>
#include <pthread.h>
#include <unistd.h>
	
static inline u64 GetTickCount64()
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
	return (u64)(ts.tv_nsec / 1000000) + ((u64)ts.tv_sec * 1000ull);
}
#endif