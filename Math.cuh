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

#define mul_wide_32(res, a, b)			asm volatile ("mul.wide.u32 %0, %1, %2;" : "=l"(res) : "r"(a), "r"(b));
#define mad_wide_32(res,a,b,c)			asm volatile ("mad.wide.u32 %0, %1, %2, %3;" : "=l"(res) : "r"(a), "r"(b), "l"(c) );

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

__device__ __forceinline__ void sub_mod_is_odd(uint8_t* parity, const uint64_t* a, const uint64_t* b)
{
	uint32_t borrow;
	uint64_t r[4]; 
	
    sub_cc_64(r[0], a[0], b[0]);
    subc_cc_64(r[1], a[1], b[1]);
    subc_cc_64(r[2], a[2], b[2]);
    subc_cc_64(r[3], a[3], b[3]);
	
    subc_32(borrow, 0, 0);
	
    *parity = (r[0] & 1) ^ (borrow & 1);
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

// r = a * b (mod P)
__device__ __forceinline__ void mul_mod(uint64_t *r, uint64_t *a, uint64_t *b)
{
	uint64_t buff[8], tmp[5], tmp2[2], tmp3;
	
//calc 512 bits
	mul_256_by_64(tmp, a, b[1]);
	mul_256_by_64(buff, a, b[0]);
	add_320_to_256(buff + 1, tmp);
	mul_256_by_64(tmp, a, b[2]);
	add_320_to_256(buff + 2, tmp);
	mul_256_by_64(tmp, a, b[3]);
	add_320_to_256(buff + 3, tmp);
//fast mod P
	mul_256_by_P0inv((uint32_t*)tmp, (uint32_t*)(buff + 4));
	add_cc_64(buff[0], buff[0], tmp[0]);
	addc_cc_64(buff[1], buff[1], tmp[1]);
	addc_cc_64(buff[2], buff[2], tmp[2]);
	addc_cc_64(buff[3], buff[3], tmp[3]);
	addc_64(tmp[4], tmp[4], 0ull);
//see mul_256_by_P0inv for details
	uint32_t* t32 = (uint32_t*)tmp;
	uint32_t* a32 = (uint32_t*)tmp2;
	uint32_t* k = (uint32_t*)&tmp3;
	mul_wide_32(tmp2[0], t32[8], P_INV32);
	mul_wide_32(tmp3, t32[9], P_INV32);
	add_cc_32(a32[1], a32[1], k[0]);
	addc_32(a32[2], k[1], 0); //we cannot get carry here for a32[3]
	add_cc_32(a32[1], a32[1], t32[8]);
	addc_cc_32(a32[2], a32[2], t32[9]);
	addc_32(a32[3], 0, 0);

	add_cc_64(r[0], buff[0], tmp2[0]);
	addc_cc_64(r[1], buff[1], tmp2[1]);
	addc_cc_64(r[2], buff[2], 0ull);
	addc_64(r[3], buff[3], 0ull);
}

__device__ __forceinline__ void add_320_to_256s(uint32_t* res, uint64_t _v1, uint64_t _v2, uint64_t _v3, uint64_t _v4, uint64_t _v5, uint64_t _v6, uint64_t _v7, uint64_t _v8)
{
	uint32_t* v1 = (uint32_t*)&_v1;
	uint32_t* v2 = (uint32_t*)&_v2;
	uint32_t* v3 = (uint32_t*)&_v3;
	uint32_t* v4 = (uint32_t*)&_v4;
	uint32_t* v5 = (uint32_t*)&_v5;
	uint32_t* v6 = (uint32_t*)&_v6;
	uint32_t* v7 = (uint32_t*)&_v7;
	uint32_t* v8 = (uint32_t*)&_v8;

	add_cc_32(res[0], res[0], v1[0]);
	addc_cc_32(res[1], res[1], v1[1]);
	addc_cc_32(res[2], res[2], v3[0]);
	addc_cc_32(res[3], res[3], v3[1]);
	addc_cc_32(res[4], res[4], v5[0]);
	addc_cc_32(res[5], res[5], v5[1]);
	addc_cc_32(res[6], res[6], v7[0]);
	addc_cc_32(res[7], res[7], v7[1]);
	addc_32(res[8], res[8], 0);

	add_cc_32(res[1], res[1], v2[0]);
	addc_cc_32(res[2], res[2], v2[1]);
	addc_cc_32(res[3], res[3], v4[0]);
	addc_cc_32(res[4], res[4], v4[1]);
	addc_cc_32(res[5], res[5], v6[0]);
	addc_cc_32(res[6], res[6], v6[1]);
	addc_cc_32(res[7], res[7], v8[0]);
	addc_cc_32(res[8], res[8], v8[1]);
	addc_32(res[9], 0, 0);
}

// r = a ^ 2 (mod P)
__device__ __forceinline__ void sqr_mod(uint64_t* r, uint64_t* aTmp)
{
	//buff needs 17 words, not 16: the last add_320_to_256s starts at b32+7 and writes 10 words, so it reaches b32[16].
	uint64_t buff[9], tmp[5], tmp2[2], tmp3, mm;
	uint32_t* a = (uint32_t*)aTmp;
	uint64_t mar[28];
	uint32_t* b32 = (uint32_t*)buff;
	uint32_t* m32 = (uint32_t*)mar;
//calc 512 bits
	mul_wide_32(mar[0], a[1], a[0]); //ab
	mul_wide_32(mar[1], a[2], a[0]); //ac
	mul_wide_32(mar[2], a[3], a[0]); //ad
	mul_wide_32(mar[3], a[4], a[0]); //ae
	mul_wide_32(mar[4], a[5], a[0]); //af
	mul_wide_32(mar[5], a[6], a[0]); //ag
	mul_wide_32(mar[6], a[7], a[0]); //ah
	mul_wide_32(mar[7], a[2], a[1]); //bc
	mul_wide_32(mar[8], a[3], a[1]); //bd
	mul_wide_32(mar[9], a[4], a[1]); //be
	mul_wide_32(mar[10], a[5], a[1]); //bf
	mul_wide_32(mar[11], a[6], a[1]); //bg
	mul_wide_32(mar[12], a[7], a[1]); //bh
	mul_wide_32(mar[13], a[3], a[2]); //cd
	mul_wide_32(mar[14], a[4], a[2]); //ce
	mul_wide_32(mar[15], a[5], a[2]); //cf
	mul_wide_32(mar[16], a[6], a[2]); //cg
	mul_wide_32(mar[17], a[7], a[2]); //ch
	mul_wide_32(mar[18], a[4], a[3]); //de
	mul_wide_32(mar[19], a[5], a[3]); //df
	mul_wide_32(mar[20], a[6], a[3]); //dg
	mul_wide_32(mar[21], a[7], a[3]); //dh
	mul_wide_32(mar[22], a[5], a[4]); //ef
	mul_wide_32(mar[23], a[6], a[4]); //eg
	mul_wide_32(mar[24], a[7], a[4]); //eh
	mul_wide_32(mar[25], a[6], a[5]); //fg
	mul_wide_32(mar[26], a[7], a[5]); //fh
	mul_wide_32(mar[27], a[7], a[6]); //gh
//a
	mul_wide_32(buff[0], a[0], a[0]); //aa
	add_cc_32(b32[1], b32[1], m32[0]);
	addc_cc_32(b32[2], m32[1], m32[2]);
	addc_cc_32(b32[3], m32[3], m32[4]);
	addc_cc_32(b32[4], m32[5], m32[6]);
	addc_cc_32(b32[5], m32[7], m32[8]);
	addc_cc_32(b32[6], m32[9], m32[10]);
	addc_cc_32(b32[7], m32[11], m32[12]);
	addc_cc_32(b32[8], m32[13], 0);
	b32[9] = 0;
//b+	 
	mul_wide_32(mm, a[1], a[1]); //bb
	add_320_to_256s(b32 + 1, mar[0], mm, mar[7], mar[8], mar[9], mar[10], mar[11], mar[12]);
	mul_wide_32(mm, a[2], a[2]); //cc
	add_320_to_256s(b32 + 2, mar[1], mar[7], mm, mar[13], mar[14], mar[15], mar[16], mar[17]);
	mul_wide_32(mm, a[3], a[3]); //dd
	add_320_to_256s(b32 + 3, mar[2], mar[8], mar[13], mm, mar[18], mar[19], mar[20], mar[21]);
	mul_wide_32(mm, a[4], a[4]); //ee
	add_320_to_256s(b32 + 4, mar[3], mar[9], mar[14], mar[18], mm, mar[22], mar[23], mar[24]);
	mul_wide_32(mm, a[5], a[5]); //ff
	add_320_to_256s(b32 + 5, mar[4], mar[10], mar[15], mar[19], mar[22], mm, mar[25], mar[26]);
	mul_wide_32(mm, a[6], a[6]); //gg
	add_320_to_256s(b32 + 6, mar[5], mar[11], mar[16], mar[20], mar[23], mar[25], mm, mar[27]);
	mul_wide_32(mm, a[7], a[7]); //hh
	add_320_to_256s(b32 + 7, mar[6], mar[12], mar[17], mar[21], mar[24], mar[26], mar[27], mm);
//fast mod P
	mul_256_by_P0inv((uint32_t*)tmp, (uint32_t*)(buff + 4));
	add_cc_64(buff[0], buff[0], tmp[0]);
	addc_cc_64(buff[1], buff[1], tmp[1]);
	addc_cc_64(buff[2], buff[2], tmp[2]);
	addc_cc_64(buff[3], buff[3], tmp[3]);
	addc_64(tmp[4], tmp[4], 0ull);
//see mul_256_by_P0inv for details
	uint32_t* t32 = (uint32_t*)tmp;
	uint32_t* a32 = (uint32_t*)tmp2;
	uint32_t* k = (uint32_t*)&tmp3;
	mul_wide_32(tmp2[0], t32[8], P_INV32);
	mul_wide_32(tmp3, t32[9], P_INV32);
	add_cc_32(a32[1], a32[1], k[0]);
	addc_32(a32[2], k[1], 0); //we cannot get carry here for a32[3]
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