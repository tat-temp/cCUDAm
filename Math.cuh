#pragma once

#include <cstdint>

//PTX asm. "volatile" is required: these chains pass carries through CC.CF with no clobber declared, so they must not be reordered or dropped.
#define add_64(res, a, b)				asm volatile ("add.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b)  );
#define add_cc_64(res, a, b)			asm volatile ("add.cc.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b)  );
#define addc_64(res, a, b)				asm volatile ("addc.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b));
#define addc_cc_64(res, a, b)			asm volatile ("addc.cc.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b)  );

#define add_32(res, a, b)				asm volatile ("add.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b)  );
#define add_cc_32(res, a, b)			asm volatile ("add.cc.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b)  );
#define addc_32(res, a, b)				asm volatile ("addc.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b));
#define addc_cc_32(res, a, b)			asm volatile ("addc.cc.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b)  );

#define sub_64(res, a, b)				asm volatile ("sub.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b));
#define sub_cc_64(res, a, b)			asm volatile ("sub.cc.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b) );
#define subc_cc_64(res, a, b)			asm volatile ("subc.cc.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b)  );
#define subc_64(res, a, b)				asm volatile ("subc.u64 %0, %1, %2;" : "=l"(res) : "l"(a), "l"(b));

#define sub_32(res, a, b)				asm volatile ("sub.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b) );
#define sub_cc_32(res, a, b)			asm volatile ("sub.cc.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b) );
#define subc_cc_32(res, a, b)			asm volatile ("subc.cc.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b)  );
#define subc_32(res, a, b)				asm volatile ("subc.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b));

#define madc_lo_32(res, a, b, c)		asm volatile ("madc.lo.u32 %0, %1, %2, %3;" : "=r"(res) : "r"(a), "r"(b), "r"(c));
#define mad_lo_cc(res,a,b,c)   			asm volatile ("mad.lo.cc.u32 %0, %1, %2, %3;"  : "=r"(res) : "r"(a), "r"(b), "r"(c));
#define madc_hi_cc(res,a,b,c)  			asm volatile ("madc.hi.cc.u32 %0, %1, %2, %3;" : "=r"(res) : "r"(a), "r"(b), "r"(c));
#define madc_lo_cc(res,a,b,c)  			asm volatile ("madc.lo.cc.u32 %0, %1, %2, %3;" : "=r"(res) : "r"(a), "r"(b), "r"(c));
#define mad_wide_32(res,a,b,c)			asm volatile ("mad.wide.u32 %0, %1, %2, %3;" : "=l"(res) : "r"(a), "r"(b), "l"(c) );

#define mul_wide_32(res, a, b)			asm volatile ("mul.wide.u32 %0, %1, %2;" : "=l"(res) : "r"(a), "r"(b));
#define mul_lo_32(res, a, b) 			asm volatile ("mul.lo.u32 %0, %1, %2;" : "=r"(res) : "r"(a), "r"(b));

//P-related constants
#define P_0			0xFFFFFFFEFFFFFC2Full
#define P_123		0xFFFFFFFFFFFFFFFFull

#define P_INV32		0x000003D1

#define Copy_u64_x4(dst, src) {\
  ((uint64_t*)(dst))[0] = ((uint64_t*)(src))[0]; \
  ((uint64_t*)(dst))[1] = ((uint64_t*)(src))[1]; \
  ((uint64_t*)(dst))[2] = ((uint64_t*)(src))[2]; \
  ((uint64_t*)(dst))[3] = ((uint64_t*)(src))[3]; }

// r = -r (mod P), in place
__device__ __forceinline__ void neg_mod(uint64_t* r)
{
    sub_cc_64(r[0], P_0, r[0]);
	subc_cc_64(r[1], P_123, r[1]);
	subc_cc_64(r[2], P_123, r[2]);
	subc_64(r[3], P_123, r[3]);
}

// r = a + b (mod P)
__device__ __forceinline__ void add_mod(uint64_t* r, const uint64_t* a, const uint64_t* b)
{
    uint64_t tmp[4];
	uint32_t carry;
	
	add_cc_64(tmp[0], a[0], b[0]);
	addc_cc_64(tmp[1], a[1], b[1]);
	addc_cc_64(tmp[2], a[2], b[2]);
	addc_cc_64(tmp[3], a[3], b[3]);	
	addc_32(carry, 0, 0);
	Copy_u64_x4(r, tmp);

	sub_cc_64(r[0], r[0], P_0);
	subc_cc_64(r[1], r[1], P_123);
	subc_cc_64(r[2], r[2], P_123);
	subc_cc_64(r[3], r[3], P_123);
	subc_cc_32(carry, carry, 0);
	subc_32(carry, 0, 0);
	if (carry)
		Copy_u64_x4(r, tmp);
}

// r = a - b (mod P)
__device__ __forceinline__ void sub_mod(uint64_t* r, const uint64_t* a, const uint64_t* b)
{
	uint32_t carry;
	
    sub_cc_64(r[0], a[0], b[0]);
    subc_cc_64(r[1], a[1], b[1]);
    subc_cc_64(r[2], a[2], b[2]);
    subc_cc_64(r[3], a[3], b[3]);
    subc_32(carry, 0, 0);
	
    if (carry)
    { 
		add_cc_64(r[0], r[0], P_0);
		addc_cc_64(r[1], r[1], P_123);
		addc_cc_64(r[2], r[2], P_123);
		addc_64(r[3], r[3], P_123);
    }
}

// r = a - b - c (mod P)
__device__ __forceinline__ void sub_mod3(uint64_t* r, const uint64_t* a, const uint64_t* b, const uint64_t* c)
{
	uint32_t b1, b2, b3;
	
    sub_cc_64(r[0], a[0], b[0]);
    subc_cc_64(r[1], a[1], b[1]);
    subc_cc_64(r[2], a[2], b[2]);
    subc_cc_64(r[3], a[3], b[3]);
    subc_32(b1, 0, 0);				// 0 or 0xFFFFFFFFFFFFFFFF
	
	sub_cc_64(r[0], r[0], c[0]);
    subc_cc_64(r[1], r[1], c[1]);
    subc_cc_64(r[2], r[2], c[2]);
    subc_cc_64(r[3], r[3], c[3]);
    subc_32(b2, 0, 0);				// 0 or 0xFFFFFFFFFFFFFFFF
	
	// a-b-c == r - B*K (mod p), B = (#borrows) in {0,1,2}
    uint64_t BK = ((b1 & 1ULL) + (b2 & 1ULL)) * 0x1000003D1ULL;
    sub_cc_64(r[0], r[0], BK);
    subc_cc_64(r[1], r[1], 0ULL);
    subc_cc_64(r[2], r[2], 0ULL);
    subc_cc_64(r[3], r[3], 0ULL);
    subc_32(b3, 0, 0);
	
    if (b3)
    { 
		add_cc_64(r[0], r[0], P_0);
		addc_cc_64(r[1], r[1], P_123);
		addc_cc_64(r[2], r[2], P_123);
		addc_64(r[3], r[3], P_123);
    }
}

// Compressed-pubkey prefix of (a - b) mod P: 0x03 if odd, else 0x02. A borrow means +P, and P is odd.
__device__ __forceinline__ uint8_t sub_mod_is_odd_prefix(const uint64_t* a, const uint64_t* b)
{
	uint32_t borrow;
	uint64_t r[4];

    sub_cc_64(r[0], a[0], b[0]);
    subc_cc_64(r[1], a[1], b[1]);
    subc_cc_64(r[2], a[2], b[2]);
    subc_cc_64(r[3], a[3], b[3]);
    subc_32(borrow, 0, 0);

    return (uint8_t)(0x02u | ((uint32_t)r[0] ^ borrow) & 1u);
}

__device__ __forceinline__ void mul_256_by_64(uint64_t* res, uint64_t* val256, uint64_t val64)
{
	uint64_t tmp64[7];
	uint32_t* tmp = (uint32_t*)tmp64;
	uint32_t* rs = (uint32_t*)res;
	uint32_t* a = (uint32_t*)val256;
	uint32_t* b = (uint32_t*)&val64;

	mul_wide_32(res[0], a[0], b[0]);
	mul_wide_32(tmp64[0], a[1], b[0]);
	mul_wide_32(tmp64[1], a[2], b[0]);
	mul_wide_32(tmp64[2], a[3], b[0]);
	mul_wide_32(tmp64[3], a[4], b[0]);
	mul_wide_32(tmp64[4], a[5], b[0]);
	mul_wide_32(tmp64[5], a[6], b[0]);
	mul_wide_32(tmp64[6], a[7], b[0]);

	add_cc_32(rs[1], rs[1], tmp[0]);
	addc_cc_32(rs[2], tmp[1], tmp[2]);
	addc_cc_32(rs[3], tmp[3], tmp[4]);
	addc_cc_32(rs[4], tmp[5], tmp[6]);
	addc_cc_32(rs[5], tmp[7], tmp[8]);
	addc_cc_32(rs[6], tmp[9], tmp[10]);
	addc_cc_32(rs[7], tmp[11], tmp[12]);
	addc_32(rs[8], tmp[13], 0); //no carry out here: an 8+1 word product is 9 words, rs[9] is the 10th

	uint64_t kk[7];
	uint32_t* k = (uint32_t*)kk;
	mul_wide_32(kk[0], a[0], b[1]);
	mul_wide_32(tmp64[0], a[1], b[1]);
	mul_wide_32(tmp64[1], a[2], b[1]);
	mul_wide_32(tmp64[2], a[3], b[1]);
	mul_wide_32(tmp64[3], a[4], b[1]);
	mul_wide_32(tmp64[4], a[5], b[1]);
	mul_wide_32(tmp64[5], a[6], b[1]);
	mul_wide_32(tmp64[6], a[7], b[1]);

	add_cc_32(k[1], k[1], tmp[0]);
	addc_cc_32(k[2], tmp[1], tmp[2]);
	addc_cc_32(k[3], tmp[3], tmp[4]);
	addc_cc_32(k[4], tmp[5], tmp[6]);
	addc_cc_32(k[5], tmp[7], tmp[8]);
	addc_cc_32(k[6], tmp[9], tmp[10]);
	addc_cc_32(k[7], tmp[11], tmp[12]);
	addc_32(k[8], tmp[13], 0); //no carry out here: an 8+1 word product is 9 words, k[9] is the 10th

	add_cc_32(rs[1], rs[1], k[0]);
	addc_cc_32(rs[2], rs[2], k[1]);
	addc_cc_32(rs[3], rs[3], k[2]);
	addc_cc_32(rs[4], rs[4], k[3]);
	addc_cc_32(rs[5], rs[5], k[4]);
	addc_cc_32(rs[6], rs[6], k[5]);
	addc_cc_32(rs[7], rs[7], k[6]);
	addc_cc_32(rs[8], rs[8], k[7]);
	addc_32(rs[9], k[8], 0);
}

__device__ __forceinline__ void add_320_to_256(uint64_t* res, uint64_t* val)
{
	add_cc_64(res[0], res[0], val[0]);
	addc_cc_64(res[1], res[1], val[1]);
	addc_cc_64(res[2], res[2], val[2]);
	addc_cc_64(res[3], res[3], val[3]);
	addc_64(res[4], val[4], 0ull);
}

//mul 256bit by 0x1000003D1
__device__ __forceinline__ void mul_256_by_P0inv(uint32_t* res, uint32_t* val)
{
	uint64_t tmp64[7];
	uint32_t* tmp = (uint32_t*)tmp64;
	mul_wide_32(*(uint64_t*)res, val[0], P_INV32);
	mul_wide_32(tmp64[0], val[1], P_INV32);
	mul_wide_32(tmp64[1], val[2], P_INV32);
	mul_wide_32(tmp64[2], val[3], P_INV32);
	mul_wide_32(tmp64[3], val[4], P_INV32);
	mul_wide_32(tmp64[4], val[5], P_INV32);
	mul_wide_32(tmp64[5], val[6], P_INV32);
	mul_wide_32(tmp64[6], val[7], P_INV32);

	add_cc_32(res[1], res[1], tmp[0]);
	addc_cc_32(res[2], tmp[1], tmp[2]);
	addc_cc_32(res[3], tmp[3], tmp[4]);
	addc_cc_32(res[4], tmp[5], tmp[6]);
	addc_cc_32(res[5], tmp[7], tmp[8]);
	addc_cc_32(res[6], tmp[9], tmp[10]);
	addc_cc_32(res[7], tmp[11], tmp[12]);
	addc_32(res[8], tmp[13], 0); //t[13] cannot be MAX_UINT so we wont have carry here for r[9]

	add_cc_32(res[1], res[1], val[0]);
	addc_cc_32(res[2], res[2], val[1]);
	addc_cc_32(res[3], res[3], val[2]);
	addc_cc_32(res[4], res[4], val[3]);
	addc_cc_32(res[5], res[5], val[4]);
	addc_cc_32(res[6], res[6], val[5]);
	addc_cc_32(res[7], res[7], val[6]);
	addc_cc_32(res[8], res[8], val[7]);
	addc_32(res[9], 0, 0);
}


// generated: even/odd column-split 256x256 -> 512, fused MAC form
__device__ __forceinline__ void mul512_split(uint32_t* p, const uint32_t* a, const uint32_t* b)
{
	uint32_t e[16], o[16];
	#pragma unroll
	for (int i = 0; i < 16; i++) { e[i] = 0; o[i] = 0; }
	mad_lo_cc(e[0], a[0], b[0], e[0]);
	madc_hi_cc(e[1], a[0], b[0], e[1]);
	madc_lo_cc(e[2], a[0], b[2], e[2]);
	madc_hi_cc(e[3], a[0], b[2], e[3]);
	madc_lo_cc(e[4], a[0], b[4], e[4]);
	madc_hi_cc(e[5], a[0], b[4], e[5]);
	madc_lo_cc(e[6], a[0], b[6], e[6]);
	madc_hi_cc(e[7], a[0], b[6], e[7]);
	madc_lo_cc(e[8], a[1], b[7], e[8]);
	madc_hi_cc(e[9], a[1], b[7], e[9]);
	madc_lo_cc(e[10], a[3], b[7], e[10]);
	madc_hi_cc(e[11], a[3], b[7], e[11]);
	madc_lo_cc(e[12], a[5], b[7], e[12]);
	madc_hi_cc(e[13], a[5], b[7], e[13]);
	madc_lo_cc(e[14], a[7], b[7], e[14]);
	madc_hi_cc(e[15], a[7], b[7], e[15]);
	mad_lo_cc(e[2], a[1], b[1], e[2]);
	madc_hi_cc(e[3], a[1], b[1], e[3]);
	madc_lo_cc(e[4], a[1], b[3], e[4]);
	madc_hi_cc(e[5], a[1], b[3], e[5]);
	madc_lo_cc(e[6], a[1], b[5], e[6]);
	madc_hi_cc(e[7], a[1], b[5], e[7]);
	madc_lo_cc(e[8], a[2], b[6], e[8]);
	madc_hi_cc(e[9], a[2], b[6], e[9]);
	madc_lo_cc(e[10], a[4], b[6], e[10]);
	madc_hi_cc(e[11], a[4], b[6], e[11]);
	madc_lo_cc(e[12], a[6], b[6], e[12]);
	madc_hi_cc(e[13], a[6], b[6], e[13]);
	addc_32(e[14], e[14], 0);
	mad_lo_cc(e[2], a[2], b[0], e[2]);
	madc_hi_cc(e[3], a[2], b[0], e[3]);
	madc_lo_cc(e[4], a[2], b[2], e[4]);
	madc_hi_cc(e[5], a[2], b[2], e[5]);
	madc_lo_cc(e[6], a[2], b[4], e[6]);
	madc_hi_cc(e[7], a[2], b[4], e[7]);
	madc_lo_cc(e[8], a[3], b[5], e[8]);
	madc_hi_cc(e[9], a[3], b[5], e[9]);
	madc_lo_cc(e[10], a[5], b[5], e[10]);
	madc_hi_cc(e[11], a[5], b[5], e[11]);
	madc_lo_cc(e[12], a[7], b[5], e[12]);
	madc_hi_cc(e[13], a[7], b[5], e[13]);
	addc_32(e[14], e[14], 0);
	mad_lo_cc(e[4], a[3], b[1], e[4]);
	madc_hi_cc(e[5], a[3], b[1], e[5]);
	madc_lo_cc(e[6], a[3], b[3], e[6]);
	madc_hi_cc(e[7], a[3], b[3], e[7]);
	madc_lo_cc(e[8], a[4], b[4], e[8]);
	madc_hi_cc(e[9], a[4], b[4], e[9]);
	madc_lo_cc(e[10], a[6], b[4], e[10]);
	madc_hi_cc(e[11], a[6], b[4], e[11]);
	addc_32(e[12], e[12], 0);
	mad_lo_cc(e[4], a[4], b[0], e[4]);
	madc_hi_cc(e[5], a[4], b[0], e[5]);
	madc_lo_cc(e[6], a[4], b[2], e[6]);
	madc_hi_cc(e[7], a[4], b[2], e[7]);
	madc_lo_cc(e[8], a[5], b[3], e[8]);
	madc_hi_cc(e[9], a[5], b[3], e[9]);
	madc_lo_cc(e[10], a[7], b[3], e[10]);
	madc_hi_cc(e[11], a[7], b[3], e[11]);
	addc_32(e[12], e[12], 0);
	mad_lo_cc(e[6], a[5], b[1], e[6]);
	madc_hi_cc(e[7], a[5], b[1], e[7]);
	madc_lo_cc(e[8], a[6], b[2], e[8]);
	madc_hi_cc(e[9], a[6], b[2], e[9]);
	addc_32(e[10], e[10], 0);
	mad_lo_cc(e[6], a[6], b[0], e[6]);
	madc_hi_cc(e[7], a[6], b[0], e[7]);
	madc_lo_cc(e[8], a[7], b[1], e[8]);
	madc_hi_cc(e[9], a[7], b[1], e[9]);
	addc_32(e[10], e[10], 0);
	mad_lo_cc(o[0], a[0], b[1], o[0]);
	madc_hi_cc(o[1], a[0], b[1], o[1]);
	madc_lo_cc(o[2], a[0], b[3], o[2]);
	madc_hi_cc(o[3], a[0], b[3], o[3]);
	madc_lo_cc(o[4], a[0], b[5], o[4]);
	madc_hi_cc(o[5], a[0], b[5], o[5]);
	madc_lo_cc(o[6], a[0], b[7], o[6]);
	madc_hi_cc(o[7], a[0], b[7], o[7]);
	madc_lo_cc(o[8], a[2], b[7], o[8]);
	madc_hi_cc(o[9], a[2], b[7], o[9]);
	madc_lo_cc(o[10], a[4], b[7], o[10]);
	madc_hi_cc(o[11], a[4], b[7], o[11]);
	madc_lo_cc(o[12], a[6], b[7], o[12]);
	madc_hi_cc(o[13], a[6], b[7], o[13]);
	addc_32(o[14], o[14], 0);
	mad_lo_cc(o[0], a[1], b[0], o[0]);
	madc_hi_cc(o[1], a[1], b[0], o[1]);
	madc_lo_cc(o[2], a[1], b[2], o[2]);
	madc_hi_cc(o[3], a[1], b[2], o[3]);
	madc_lo_cc(o[4], a[1], b[4], o[4]);
	madc_hi_cc(o[5], a[1], b[4], o[5]);
	madc_lo_cc(o[6], a[1], b[6], o[6]);
	madc_hi_cc(o[7], a[1], b[6], o[7]);
	madc_lo_cc(o[8], a[3], b[6], o[8]);
	madc_hi_cc(o[9], a[3], b[6], o[9]);
	madc_lo_cc(o[10], a[5], b[6], o[10]);
	madc_hi_cc(o[11], a[5], b[6], o[11]);
	madc_lo_cc(o[12], a[7], b[6], o[12]);
	madc_hi_cc(o[13], a[7], b[6], o[13]);
	addc_32(o[14], o[14], 0);
	mad_lo_cc(o[2], a[2], b[1], o[2]);
	madc_hi_cc(o[3], a[2], b[1], o[3]);
	madc_lo_cc(o[4], a[2], b[3], o[4]);
	madc_hi_cc(o[5], a[2], b[3], o[5]);
	madc_lo_cc(o[6], a[2], b[5], o[6]);
	madc_hi_cc(o[7], a[2], b[5], o[7]);
	madc_lo_cc(o[8], a[4], b[5], o[8]);
	madc_hi_cc(o[9], a[4], b[5], o[9]);
	madc_lo_cc(o[10], a[6], b[5], o[10]);
	madc_hi_cc(o[11], a[6], b[5], o[11]);
	addc_32(o[12], o[12], 0);
	mad_lo_cc(o[2], a[3], b[0], o[2]);
	madc_hi_cc(o[3], a[3], b[0], o[3]);
	madc_lo_cc(o[4], a[3], b[2], o[4]);
	madc_hi_cc(o[5], a[3], b[2], o[5]);
	madc_lo_cc(o[6], a[3], b[4], o[6]);
	madc_hi_cc(o[7], a[3], b[4], o[7]);
	madc_lo_cc(o[8], a[5], b[4], o[8]);
	madc_hi_cc(o[9], a[5], b[4], o[9]);
	madc_lo_cc(o[10], a[7], b[4], o[10]);
	madc_hi_cc(o[11], a[7], b[4], o[11]);
	addc_32(o[12], o[12], 0);
	mad_lo_cc(o[4], a[4], b[1], o[4]);
	madc_hi_cc(o[5], a[4], b[1], o[5]);
	madc_lo_cc(o[6], a[4], b[3], o[6]);
	madc_hi_cc(o[7], a[4], b[3], o[7]);
	madc_lo_cc(o[8], a[6], b[3], o[8]);
	madc_hi_cc(o[9], a[6], b[3], o[9]);
	addc_32(o[10], o[10], 0);
	mad_lo_cc(o[4], a[5], b[0], o[4]);
	madc_hi_cc(o[5], a[5], b[0], o[5]);
	madc_lo_cc(o[6], a[5], b[2], o[6]);
	madc_hi_cc(o[7], a[5], b[2], o[7]);
	madc_lo_cc(o[8], a[7], b[2], o[8]);
	madc_hi_cc(o[9], a[7], b[2], o[9]);
	addc_32(o[10], o[10], 0);
	mad_lo_cc(o[6], a[6], b[1], o[6]);
	madc_hi_cc(o[7], a[6], b[1], o[7]);
	addc_32(o[8], o[8], 0);
	mad_lo_cc(o[6], a[7], b[0], o[6]);
	madc_hi_cc(o[7], a[7], b[0], o[7]);
	addc_32(o[8], o[8], 0);
	// p = e + (o << 32)
	add_cc_32(p[1], e[1], o[0]);
	addc_cc_32(p[2], e[2], o[1]);
	addc_cc_32(p[3], e[3], o[2]);
	addc_cc_32(p[4], e[4], o[3]);
	addc_cc_32(p[5], e[5], o[4]);
	addc_cc_32(p[6], e[6], o[5]);
	addc_cc_32(p[7], e[7], o[6]);
	addc_cc_32(p[8], e[8], o[7]);
	addc_cc_32(p[9], e[9], o[8]);
	addc_cc_32(p[10], e[10], o[9]);
	addc_cc_32(p[11], e[11], o[10]);
	addc_cc_32(p[12], e[12], o[11]);
	addc_cc_32(p[13], e[13], o[12]);
	addc_cc_32(p[14], e[14], o[13]);
	addc_cc_32(p[15], e[15], o[14]);
	p[0] = e[0];
}


// r = a * b (mod P)   [split-column fused-MAC 512-bit core]
__device__ __forceinline__ void mul_mod(uint64_t *r, uint64_t *a, uint64_t *b)
{
	__align__(16) uint64_t buff[8];
	uint64_t tmp[5], tmp2[2];
	mul512_split((uint32_t*)buff, (const uint32_t*)a, (const uint32_t*)b);
	mul_256_by_P0inv((uint32_t*)tmp, (uint32_t*)(buff + 4));
	add_cc_64(buff[0], buff[0], tmp[0]);
	addc_cc_64(buff[1], buff[1], tmp[1]);
	addc_cc_64(buff[2], buff[2], tmp[2]);
	addc_cc_64(buff[3], buff[3], tmp[3]);
	addc_64(tmp[4], tmp[4], 0ull);
	uint32_t* t32 = (uint32_t*)tmp;
	uint32_t* a32 = (uint32_t*)tmp2;
	mul_wide_32(tmp2[0], t32[8], P_INV32);
	uint32_t k0; mul_lo_32(k0, t32[9], P_INV32);   // t32[9] <= 2, so 977*t32[9] < 2^32
	add_cc_32(a32[1], a32[1], k0);
	addc_32(a32[2], 0, 0);
	add_cc_32(a32[1], a32[1], t32[8]);
	addc_cc_32(a32[2], a32[2], t32[9]);
	addc_32(a32[3], 0, 0);
	add_cc_64(r[0], buff[0], tmp2[0]);
	addc_cc_64(r[1], buff[1], tmp2[1]);
	addc_cc_64(r[2], buff[2], 0ull);
	addc_64(r[3], buff[3], 0ull);
}

// generated: split-column fused-MAC 256-bit square -> 512
__device__ __forceinline__ void sqr512_split(uint32_t* p, const uint32_t* a)
{
	uint32_t e[16], o[16];
	#pragma unroll
	for (int i = 0; i < 16; i++) { e[i] = 0; o[i] = 0; }
	mad_lo_cc(e[2], a[0], a[2], e[2]);
	madc_hi_cc(e[3], a[0], a[2], e[3]);
	madc_lo_cc(e[4], a[0], a[4], e[4]);
	madc_hi_cc(e[5], a[0], a[4], e[5]);
	madc_lo_cc(e[6], a[0], a[6], e[6]);
	madc_hi_cc(e[7], a[0], a[6], e[7]);
	madc_lo_cc(e[8], a[1], a[7], e[8]);
	madc_hi_cc(e[9], a[1], a[7], e[9]);
	madc_lo_cc(e[10], a[3], a[7], e[10]);
	madc_hi_cc(e[11], a[3], a[7], e[11]);
	madc_lo_cc(e[12], a[5], a[7], e[12]);
	madc_hi_cc(e[13], a[5], a[7], e[13]);
	addc_32(e[14], e[14], 0);
	mad_lo_cc(e[4], a[1], a[3], e[4]);
	madc_hi_cc(e[5], a[1], a[3], e[5]);
	madc_lo_cc(e[6], a[1], a[5], e[6]);
	madc_hi_cc(e[7], a[1], a[5], e[7]);
	madc_lo_cc(e[8], a[2], a[6], e[8]);
	madc_hi_cc(e[9], a[2], a[6], e[9]);
	madc_lo_cc(e[10], a[4], a[6], e[10]);
	madc_hi_cc(e[11], a[4], a[6], e[11]);
	addc_32(e[12], e[12], 0);
	mad_lo_cc(e[6], a[2], a[4], e[6]);
	madc_hi_cc(e[7], a[2], a[4], e[7]);
	madc_lo_cc(e[8], a[3], a[5], e[8]);
	madc_hi_cc(e[9], a[3], a[5], e[9]);
	addc_32(e[10], e[10], 0);
	mad_lo_cc(o[0], a[0], a[1], o[0]);
	madc_hi_cc(o[1], a[0], a[1], o[1]);
	madc_lo_cc(o[2], a[0], a[3], o[2]);
	madc_hi_cc(o[3], a[0], a[3], o[3]);
	madc_lo_cc(o[4], a[0], a[5], o[4]);
	madc_hi_cc(o[5], a[0], a[5], o[5]);
	madc_lo_cc(o[6], a[0], a[7], o[6]);
	madc_hi_cc(o[7], a[0], a[7], o[7]);
	madc_lo_cc(o[8], a[2], a[7], o[8]);
	madc_hi_cc(o[9], a[2], a[7], o[9]);
	madc_lo_cc(o[10], a[4], a[7], o[10]);
	madc_hi_cc(o[11], a[4], a[7], o[11]);
	madc_lo_cc(o[12], a[6], a[7], o[12]);
	madc_hi_cc(o[13], a[6], a[7], o[13]);
	addc_32(o[14], o[14], 0);
	mad_lo_cc(o[2], a[1], a[2], o[2]);
	madc_hi_cc(o[3], a[1], a[2], o[3]);
	madc_lo_cc(o[4], a[1], a[4], o[4]);
	madc_hi_cc(o[5], a[1], a[4], o[5]);
	madc_lo_cc(o[6], a[1], a[6], o[6]);
	madc_hi_cc(o[7], a[1], a[6], o[7]);
	madc_lo_cc(o[8], a[3], a[6], o[8]);
	madc_hi_cc(o[9], a[3], a[6], o[9]);
	madc_lo_cc(o[10], a[5], a[6], o[10]);
	madc_hi_cc(o[11], a[5], a[6], o[11]);
	addc_32(o[12], o[12], 0);
	mad_lo_cc(o[4], a[2], a[3], o[4]);
	madc_hi_cc(o[5], a[2], a[3], o[5]);
	madc_lo_cc(o[6], a[2], a[5], o[6]);
	madc_hi_cc(o[7], a[2], a[5], o[7]);
	madc_lo_cc(o[8], a[4], a[5], o[8]);
	madc_hi_cc(o[9], a[4], a[5], o[9]);
	addc_32(o[10], o[10], 0);
	mad_lo_cc(o[6], a[3], a[4], o[6]);
	madc_hi_cc(o[7], a[3], a[4], o[7]);
	addc_32(o[8], o[8], 0);
	// p = 2*(e + (o << 32))
	add_cc_32(p[1], e[1], o[0]);
	addc_cc_32(p[2], e[2], o[1]);
	addc_cc_32(p[3], e[3], o[2]);
	addc_cc_32(p[4], e[4], o[3]);
	addc_cc_32(p[5], e[5], o[4]);
	addc_cc_32(p[6], e[6], o[5]);
	addc_cc_32(p[7], e[7], o[6]);
	addc_cc_32(p[8], e[8], o[7]);
	addc_cc_32(p[9], e[9], o[8]);
	addc_cc_32(p[10], e[10], o[9]);
	addc_cc_32(p[11], e[11], o[10]);
	addc_cc_32(p[12], e[12], o[11]);
	addc_cc_32(p[13], e[13], o[12]);
	addc_cc_32(p[14], e[14], o[13]);
	addc_cc_32(p[15], e[15], o[14]);
	p[0] = e[0];
	add_cc_32(p[0], p[0], p[0]);
	addc_cc_32(p[1], p[1], p[1]);
	addc_cc_32(p[2], p[2], p[2]);
	addc_cc_32(p[3], p[3], p[3]);
	addc_cc_32(p[4], p[4], p[4]);
	addc_cc_32(p[5], p[5], p[5]);
	addc_cc_32(p[6], p[6], p[6]);
	addc_cc_32(p[7], p[7], p[7]);
	addc_cc_32(p[8], p[8], p[8]);
	addc_cc_32(p[9], p[9], p[9]);
	addc_cc_32(p[10], p[10], p[10]);
	addc_cc_32(p[11], p[11], p[11]);
	addc_cc_32(p[12], p[12], p[12]);
	addc_cc_32(p[13], p[13], p[13]);
	addc_cc_32(p[14], p[14], p[14]);
	addc_cc_32(p[15], p[15], p[15]);
	// += diagonal squares a[i]^2 at column 2i
	mad_lo_cc(p[0], a[0], a[0], p[0]);
	madc_hi_cc(p[1], a[0], a[0], p[1]);
	madc_lo_cc(p[2], a[1], a[1], p[2]);
	madc_hi_cc(p[3], a[1], a[1], p[3]);
	madc_lo_cc(p[4], a[2], a[2], p[4]);
	madc_hi_cc(p[5], a[2], a[2], p[5]);
	madc_lo_cc(p[6], a[3], a[3], p[6]);
	madc_hi_cc(p[7], a[3], a[3], p[7]);
	madc_lo_cc(p[8], a[4], a[4], p[8]);
	madc_hi_cc(p[9], a[4], a[4], p[9]);
	madc_lo_cc(p[10], a[5], a[5], p[10]);
	madc_hi_cc(p[11], a[5], a[5], p[11]);
	madc_lo_cc(p[12], a[6], a[6], p[12]);
	madc_hi_cc(p[13], a[6], a[6], p[13]);
	madc_lo_cc(p[14], a[7], a[7], p[14]);
	madc_hi_cc(p[15], a[7], a[7], p[15]);
}


// r = a ^ 2 (mod P)   [split-column fused-MAC 512-bit core]
__device__ __forceinline__ void sqr_mod(uint64_t* r, uint64_t* aTmp)
{
	__align__(16) uint64_t buff[8];
	uint64_t tmp[5], tmp2[2];
	sqr512_split((uint32_t*)buff, (const uint32_t*)aTmp);
	mul_256_by_P0inv((uint32_t*)tmp, (uint32_t*)(buff + 4));
	add_cc_64(buff[0], buff[0], tmp[0]);
	addc_cc_64(buff[1], buff[1], tmp[1]);
	addc_cc_64(buff[2], buff[2], tmp[2]);
	addc_cc_64(buff[3], buff[3], tmp[3]);
	addc_64(tmp[4], tmp[4], 0ull);
	uint32_t* t32 = (uint32_t*)tmp;
	uint32_t* a32 = (uint32_t*)tmp2;
	mul_wide_32(tmp2[0], t32[8], P_INV32);
	uint32_t k0; mul_lo_32(k0, t32[9], P_INV32);   // t32[9] <= 2, so 977*t32[9] < 2^32
	add_cc_32(a32[1], a32[1], k0);
	addc_32(a32[2], 0, 0);
	add_cc_32(a32[1], a32[1], t32[8]);
	addc_cc_32(a32[2], a32[2], t32[9]);
	addc_32(a32[3], 0, 0);
	add_cc_64(r[0], buff[0], tmp2[0]);
	addc_cc_64(r[1], buff[1], tmp2[1]);
	addc_cc_64(r[2], buff[2], 0ull);
	addc_64(r[3], buff[3], 0ull);
}

#define APPLY_DIV_SHIFT()	matrix[0] <<= index; matrix[1] <<= index; kbnt -= index; _val >>= index;  
#define DO_INV_STEP()		{kbnt = -kbnt; int tmp = -_modp; _modp = _val; _val = tmp; tmp = -matrix[0]; \
							matrix[0] = matrix[2]; matrix[2] = tmp; tmp = -matrix[1]; matrix[1] = matrix[3]; matrix[3] = tmp;}

__device__ __forceinline__ void add_288(uint32_t* res, uint32_t* val1, uint32_t* val2)
{
	add_cc_32(res[0], val1[0], val2[0]);
	addc_cc_32(res[1], val1[1], val2[1]);
	addc_cc_32(res[2], val1[2], val2[2]);
	addc_cc_32(res[3], val1[3], val2[3]);
	addc_cc_32(res[4], val1[4], val2[4]);
	addc_cc_32(res[5], val1[5], val2[5]);
	addc_cc_32(res[6], val1[6], val2[6]);
	addc_cc_32(res[7], val1[7], val2[7]);
	addc_32(res[8], val1[8], val2[8]);
}

__device__ __forceinline__ void neg_288(uint32_t* res)
{
	sub_cc_32(res[0], 0, res[0]);
	subc_cc_32(res[1], 0, res[1]);
	subc_cc_32(res[2], 0, res[2]);
	subc_cc_32(res[3], 0, res[3]);
	subc_cc_32(res[4], 0, res[4]);
	subc_cc_32(res[5], 0, res[5]);
	subc_cc_32(res[6], 0, res[6]);
	subc_cc_32(res[7], 0, res[7]);
	subc_32(res[8], 0, res[8]);
}

__device__ __forceinline__ void mul_288_by_i32(uint32_t* res, uint32_t* val288, int ival32)
{
	uint32_t val32 = abs(ival32);
	uint64_t tmp64[4];
	uint32_t* tmp = (uint32_t*)tmp64;
	uint64_t* r32 = (uint64_t*)res; 
	mul_wide_32(r32[0], val288[0], val32);
	mul_wide_32(r32[1], val288[2], val32);
	mul_wide_32(r32[2], val288[4], val32);
	mul_wide_32(r32[3], val288[6], val32);
	mul_wide_32(tmp64[0], val288[1], val32);
	mul_wide_32(tmp64[1], val288[3], val32);
	mul_wide_32(tmp64[2], val288[5], val32);
	mul_wide_32(tmp64[3], val288[7], val32);

	add_cc_32(res[1], res[1], tmp[0]);
	addc_cc_32(res[2], res[2], tmp[1]);
	addc_cc_32(res[3], res[3], tmp[2]);
	addc_cc_32(res[4], res[4], tmp[3]);
	addc_cc_32(res[5], res[5], tmp[4]);
	addc_cc_32(res[6], res[6], tmp[5]);
	addc_cc_32(res[7], res[7], tmp[6]);
	madc_lo_32(res[8], val288[8], val32, tmp[7]);

	if (ival32 < 0)
		neg_288(res);
}

__device__ __forceinline__ void set_288_i32(uint32_t* res, int val)
{
	res[0] = val;
	res[1] = (val < 0) ? 0xFFFFFFFF : 0;
	res[2] = res[1];
	res[3] = res[1];
	res[4] = res[1];
	res[5] = res[1];
	res[6] = res[1];
	res[7] = res[1];
	res[8] = res[1];
}

//mul P by 32bit, get 288bit result
__device__ __forceinline__ void mul_P_by_32(uint32_t* res, uint32_t val)
{
	__align__(8) uint32_t tmp[3];
	mul_wide_32(*(uint64_t*)tmp, val, P_INV32);
	add_cc_32(tmp[1], tmp[1], val);
	addc_32(tmp[2], 0, 0);

	sub_cc_32(res[0], 0, tmp[0]);
	subc_cc_32(res[1], 0, tmp[1]);
	subc_cc_32(res[2], 0, tmp[2]);
	subc_cc_32(res[3], 0, 0);
	subc_cc_32(res[4], 0, 0);
	subc_cc_32(res[5], 0, 0);
	subc_cc_32(res[6], 0, 0);
	subc_cc_32(res[7], 0, 0);
	subc_32(res[8], val, 0);
}

__device__ __forceinline__ void shiftR_288_by_30(uint32_t* res)
{
	res[0] = __funnelshift_r(res[0], res[1], 30);
	res[1] = __funnelshift_r(res[1], res[2], 30);
	res[2] = __funnelshift_r(res[2], res[3], 30);
	res[3] = __funnelshift_r(res[3], res[4], 30);
	res[4] = __funnelshift_r(res[4], res[5], 30);
	res[5] = __funnelshift_r(res[5], res[6], 30);
	res[6] = __funnelshift_r(res[6], res[7], 30);
	res[7] = __funnelshift_r(res[7], res[8], 30);
	res[8] = ((int)res[8]) >> 30;
}

__device__ __forceinline__ void add_288_P(uint32_t* res)
{
	add_cc_32(res[0], res[0], 0xFFFFFC2F);
	addc_cc_32(res[1], res[1], 0xFFFFFFFE);
	addc_cc_32(res[2], res[2], 0xFFFFFFFF);
	addc_cc_32(res[3], res[3], 0xFFFFFFFF);
	addc_cc_32(res[4], res[4], 0xFFFFFFFF);
	addc_cc_32(res[5], res[5], 0xFFFFFFFF);
	addc_cc_32(res[6], res[6], 0xFFFFFFFF);
	addc_cc_32(res[7], res[7], 0xFFFFFFFF);
	addc_32(res[8], res[8], 0);
}

__device__ __forceinline__ void sub_288_P(uint32_t* res)
{
	sub_cc_32(res[0], res[0], 0xFFFFFC2F);
	subc_cc_32(res[1], res[1], 0xFFFFFFFE);
	subc_cc_32(res[2], res[2], 0xFFFFFFFF);
	subc_cc_32(res[3], res[3], 0xFFFFFFFF);
	subc_cc_32(res[4], res[4], 0xFFFFFFFF);
	subc_cc_32(res[5], res[5], 0xFFFFFFFF);
	subc_cc_32(res[6], res[6], 0xFFFFFFFF);
	subc_cc_32(res[7], res[7], 0xFFFFFFFF);
	subc_32(res[8], res[8], 0);
}


// r = a^-1 (mod P), in place. r must be backed by uint64_t[5] (InvModP writes word 8).
__device__ __forceinline__ void inv_mod(uint32_t* r)
{
    int matrix[4], _val, _modp, index, cnt, mx, kbnt;
	__align__(8) uint32_t modp[9];
	__align__(8) uint32_t val[9];
	__align__(8) uint32_t a[9];
	__align__(8) uint32_t tmp[4][9+1]; //+1 because we need alignment 64bit for tmp[>0]

	((uint64_t*)modp)[0] = P_0;
	((uint64_t*)modp)[1] = P_123;
	((uint64_t*)modp)[2] = P_123;
	((uint64_t*)modp)[3] = P_123;
	modp[8] = 0;
	r[8] = 0;
	val[0] = r[0]; val[1] = r[1]; val[2] = r[2]; val[3] = r[3];
	val[4] = r[4]; val[5] = r[5]; val[6] = r[6]; val[7] = r[7];
	val[8] = 0;
	matrix[0] = matrix[3] = 1;
	matrix[1] = matrix[2] = 0;
	kbnt = -1;
	_val = (int)r[0];
	_modp = (int)P_0;
	index = __ffs(_val | 0x40000000) - 1;
	APPLY_DIV_SHIFT();
	cnt = 30 - index;
	while (cnt > 0)
	{
		if (kbnt < 0)
			DO_INV_STEP();
		mx = (kbnt + 1 < cnt) ? 31 - kbnt : 32 - cnt;
		int mul = (-_modp * _val) & 7;
		mul &= 0xFFFFFFFF >> mx;
		_val += _modp * mul;
		matrix[2] += matrix[0] * mul;
		matrix[3] += matrix[1] * mul;
		index = __ffs(_val | (1 << cnt)) - 1;
		APPLY_DIV_SHIFT();
		cnt -= index;
	}
	mul_288_by_i32(tmp[0], modp, matrix[0]);
	mul_288_by_i32(tmp[1], val, matrix[1]);
	mul_288_by_i32(tmp[2], modp, matrix[2]);
	mul_288_by_i32(tmp[3], val, matrix[3]);
	add_288(modp, tmp[0], tmp[1]);
	shiftR_288_by_30(modp);
	add_288(val, tmp[2], tmp[3]);
	shiftR_288_by_30(val);
	set_288_i32(tmp[1], matrix[1]);
	set_288_i32(tmp[3], matrix[3]);
	mul_P_by_32(r, (tmp[1][0] * 0xD2253531) & 0x3FFFFFFF);
	add_288(r, r, tmp[1]);
	shiftR_288_by_30(r);
	mul_P_by_32(a, (tmp[3][0] * 0xD2253531) & 0x3FFFFFFF);
	add_288(a, a, tmp[3]);
	shiftR_288_by_30(a);
	while (1)
	{
		matrix[0] = matrix[3] = 1;
		matrix[1] = matrix[2] = 0;
		_val = val[0];
		_modp = modp[0];
		index = __ffs(_val | 0x40000000) - 1;
		APPLY_DIV_SHIFT();
		cnt = 30 - index;
		while (cnt > 0)
		{
			if (kbnt < 0)
				DO_INV_STEP();
			mx = (kbnt + 1 < cnt) ? 31 - kbnt : 32 - cnt;
			int mul = (-_modp * _val) & 7;
			mul &= 0xFFFFFFFF >> mx;
			_val += _modp * mul;
			matrix[2] += matrix[0] * mul;
			matrix[3] += matrix[1] * mul;
			index = __ffs(_val | (1 << cnt)) - 1;
			APPLY_DIV_SHIFT();
			cnt -= index;
		}
		mul_288_by_i32(tmp[0], modp, matrix[0]);
		mul_288_by_i32(tmp[1], val, matrix[1]);
		mul_288_by_i32(tmp[2], modp, matrix[2]);
		mul_288_by_i32(tmp[3], val, matrix[3]);
		add_288(modp, tmp[0], tmp[1]);
		shiftR_288_by_30(modp);
		add_288(val, tmp[2], tmp[3]);
		shiftR_288_by_30(val);
		mul_288_by_i32(tmp[0], r, matrix[0]);
		mul_288_by_i32(tmp[1], a, matrix[1]);

		if ((val[0] | val[1] | val[2] | val[3] | val[4] | val[5] | val[6] | val[7]) == 0)
			break;

		mul_288_by_i32(tmp[2], r, matrix[2]);
		mul_288_by_i32(tmp[3], a, matrix[3]);
		mul_P_by_32(r, ((tmp[0][0] + tmp[1][0]) * 0xD2253531) & 0x3FFFFFFF);
		add_288(r, r, tmp[0]);
		add_288(r, r, tmp[1]);
		shiftR_288_by_30(r);
		mul_P_by_32(a, ((tmp[2][0] + tmp[3][0]) * 0xD2253531) & 0x3FFFFFFF);
		add_288(a, a, tmp[2]);
		add_288(a, a, tmp[3]);	
		shiftR_288_by_30(a);
	}
	mul_P_by_32(r, ((tmp[0][0] + tmp[1][0]) * 0xD2253531) & 0x3FFFFFFF);
	add_288(r, r, tmp[0]);
	add_288(r, r, tmp[1]);
	shiftR_288_by_30(r);
	if ((int)modp[8] < 0)
		neg_288(r);	
	while ((int)r[8] < 0)
		add_288_P(r);
	while ((int)r[8] > 0)
		sub_288_P(r);
}