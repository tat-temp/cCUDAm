#include "Defs.h"
#include "Math.cuh"
#include "GpuCore.cuh"
#include "Math.cuh"

#define BLOCK_CNT	gridDim.x
#define BLOCK_X		blockIdx.x
#define THREAD_X	threadIdx.x

__device__ __constant__ uint32_t c_target_words[5];
__device__ __constant__ uint64_t c_Gx[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ uint64_t c_Gy[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ uint64_t c_Jx[4];
__device__ __constant__ uint64_t c_Jy[4];

extern "C" __launch_bounds__(THREADS_PER_BLOCK, BLOCKS_PER_SM)
__global__ void TestKernel(
	uint64_t* __restrict__ Px,
    uint64_t* __restrict__ Py,
	uint64_t* __restrict__ start_scalars,
    uint64_t* __restrict__ counts256,
	uint64_t threadsTotal,
    uint32_t batch_size,
    uint32_t batches_per_launch)
{
	const uint32_t B = (uint32_t)batch_size;
	if (B <= 0 || (B & 1) || B > MAX_BATCH_SIZE) return;
    const uint32_t half = B >> 1;
	
	const uint64_t gid = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (gid >= threadsTotal) return;
	
	//const unsigned lane      = (unsigned)(threadIdx.x & (WARP_SIZE - 1));
    //const unsigned full_mask = 0xFFFFFFFFu;
	
	// Filter on hash160 WORD 2, not word 0: word 2 is the cheapest of the five to produce
    // (its RIPEMD-160 inputs are final 7 rounds earlier -- see CUDAHash.cu). Any single word
    // is an equally selective 32-bit filter, so this is a free choice.
    //const uint32_t target_prefix = c_target_words[2];
	
	uint64_t x1[4], y1[4], s1[4], rem[4];
	// GS: cache lane ????
    { const uint64_t idx = gid*4 + 0; x1[0] = Px[idx]; y1[0] = Py[idx]; s1[0] = start_scalars[idx]; rem[0] = counts256[idx]; }
    { const uint64_t idx = gid*4 + 1; x1[1] = Px[idx]; y1[1] = Py[idx]; s1[1] = start_scalars[idx]; rem[1] = counts256[idx]; }
    { const uint64_t idx = gid*4 + 2; x1[2] = Px[idx]; y1[2] = Py[idx]; s1[2] = start_scalars[idx]; rem[2] = counts256[idx]; }
    { const uint64_t idx = gid*4 + 3; x1[3] = Px[idx]; y1[3] = Py[idx]; s1[3] = start_scalars[idx]; rem[3] = counts256[idx]; }
	
	if ((rem[0]|rem[1]|rem[2]|rem[3]) == 0ull) return;
	
	uint32_t batches_done = 0;
	while (batches_done < batches_per_launch && ge256_u64(rem, (uint64_t)B)) {
		//uint8_t prefix = (uint8_t)(y1[0] & 1ULL) ? 0x03 : 0x02;
		//uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(x1));   // by-value ABI: 1 reg out
        //bool pref = (hw2 == target_prefix);
		
		uint64_t subp[MAX_BATCH_SIZE / 2][4];
		uint64_t acc[4], tmp[4];
		
		sub_mod(acc, c_Jx, x1);
		
		#pragma unroll
		for(int i = 0; i < 4; i++) subp[half-1][i] = acc[i];
		
		for (int i = half - 2; i >= 0; --i) {
            sub_mod(tmp, &c_Gx[(size_t)(i + 1) * 4], x1);
            mul_mod(acc, acc, tmp);
            subp[i][0] = acc[0]; subp[i][1] = acc[1]; subp[i][2] = acc[2]; subp[i][3] = acc[3];
        }
		
		uint64_t inverse[5];
		sub_mod((uint64_t*)inverse, (const uint64_t*)c_Gx[0], x1);      // d0 = c_Gx[0] - x1, straight into inverse[0..3]
        mul_mod(inverse, inverse, subp[0]);
		
		inv_mod((uint32_t*)inverse);
		
		for (int i = 0; i < half - 1; ++i) {
            uint64_t dx_inv_i[4];
            mul_mod(dx_inv_i, subp[i], inverse);
			
			{
				uint64_t px3[4], s[4], lam[4];
                uint64_t px_i[4], py_i[4];
				
				// GS: Cache lane???
                px_i[0]=c_Gx[(size_t)i*4+0]; px_i[1]=c_Gx[(size_t)i*4+1]; px_i[2]=c_Gx[(size_t)i*4+2]; px_i[3]=c_Gx[(size_t)i*4+3];
                py_i[0]=c_Gy[(size_t)i*4+0]; py_i[1]=c_Gy[(size_t)i*4+1]; py_i[2]=c_Gy[(size_t)i*4+2]; py_i[3]=c_Gy[(size_t)i*4+3];

                sub_mod(s, py_i, y1);
                mul_mod(lam, s, dx_inv_i);

                sqr_mod(px3, lam);
                sub_mod3(px3, px3, x1, px_i);   // px3 = lam^2 - x1 - px_i (fused, one reduction)

                sub_mod(s, x1, px3); 
                mul_mod(s, s, lam);
			}
			
			{
				uint64_t px3[4], s[4], lam[4];
                uint64_t px_i[4], py_i[4];
				
				// GS: Cache lane???
                px_i[0]=c_Gx[(size_t)i*4+0]; px_i[1]=c_Gx[(size_t)i*4+1]; px_i[2]=c_Gx[(size_t)i*4+2]; px_i[3]=c_Gx[(size_t)i*4+3];
                py_i[0]=c_Gy[(size_t)i*4+0]; py_i[1]=c_Gy[(size_t)i*4+1]; py_i[2]=c_Gy[(size_t)i*4+2]; py_i[3]=c_Gy[(size_t)i*4+3];
                
				neg_mod(py_i); 

                sub_mod(s, py_i, y1);
                mul_mod(lam, s, dx_inv_i);

                sqr_mod(px3, lam);
                sub_mod3(px3, px3, x1, px_i);   // px3 = lam^2 - x1 - px_i (fused, one reduction)

                sub_mod(s, x1, px3);
                mul_mod(s, s, lam);
			}
			
			uint64_t gxmi[4];
            sub_mod(gxmi, &c_Gx[(size_t)i*4], x1);
            mul_mod(inverse, inverse, gxmi);
		}
		
		{
            const int i = half - 1;
            uint64_t dx_inv_i[4];
            mul_mod(dx_inv_i, subp[i], inverse);

            uint64_t px3[4], s[4], lam[4];
            uint64_t px_i[4], py_i[4];
			
            px_i[0]=c_Gx[(size_t)i*4+0]; px_i[1]=c_Gx[(size_t)i*4+1]; px_i[2]=c_Gx[(size_t)i*4+2]; px_i[3]=c_Gx[(size_t)i*4+3];
            py_i[0]=c_Gy[(size_t)i*4+0]; py_i[1]=c_Gy[(size_t)i*4+1]; py_i[2]=c_Gy[(size_t)i*4+2]; py_i[3]=c_Gy[(size_t)i*4+3];
            
			neg_mod(py_i);

            sub_mod(s, py_i, y1);
            mul_mod(lam, s, dx_inv_i);

            sqr_mod(px3, lam);
            sub_mod3(px3, px3, x1, px_i);   // px3 = lam^2 - x1 - px_i (fused, one reduction)

            sub_mod(s, x1, px3);
            mul_mod(s, s, lam);

            uint64_t last_dx[4];
            sub_mod(last_dx, &c_Gx[(size_t)i*4], x1);
            mul_mod(inverse, inverse, last_dx);
        }
		
		{
            uint64_t lam[4], s[4], x3[4], y3[4];
            uint64_t Jy_minus_y1[4];
			
            sub_mod(Jy_minus_y1, c_Jy, y1);

            mul_mod(lam, Jy_minus_y1, inverse);
            sqr_mod(x3, lam);
            uint64_t Jx_local[4]; Jx_local[0]=c_Jx[0]; Jx_local[1]=c_Jx[1]; Jx_local[2]=c_Jx[2]; Jx_local[3]=c_Jx[3];
            sub_mod3(x3, x3, x1, Jx_local);   // x3 = lam^2 - x1 - Jx (fused, one reduction)

            sub_mod(s, x1, x3);
            mul_mod(y3, s, lam);
            sub_mod(y3, y3, y1);

            x1[0] = x3[0]; y1[0] = y3[0];
            x1[1] = x3[1]; y1[1] = y3[1];
            x1[2] = x3[2]; y1[2] = y3[2];
            x1[3] = x3[3]; y1[3] = y3[3];
        }
		
		{
			add256_u64(s1, (uint64_t)B);
            sub256_u64(rem, (uint64_t)B);
        }
		
		batches_done++;
	}
	
	{ const uint64_t idx = gid*4 + 0; Px[idx] = x1[0]; Py[idx] = y1[0]; counts256[idx] = rem[0]; start_scalars[idx] = s1[0]; }
    { const uint64_t idx = gid*4 + 1; Px[idx] = x1[1]; Py[idx] = y1[1]; counts256[idx] = rem[1]; start_scalars[idx] = s1[1]; }
    { const uint64_t idx = gid*4 + 2; Px[idx] = x1[2]; Py[idx] = y1[2]; counts256[idx] = rem[2]; start_scalars[idx] = s1[2]; }
    { const uint64_t idx = gid*4 + 3; Px[idx] = x1[3]; Py[idx] = y1[3]; counts256[idx] = rem[3]; start_scalars[idx] = s1[3]; }
    
}

void CallGpuKernel(TKparams& Kparams) {
	TestKernel <<< Kparams.BlockCnt, Kparams.BlockSize, 0 >>> (
		Kparams.px,
		Kparams.py,
		Kparams.scalars,
		Kparams.counts,
		Kparams.threads_total,
		Kparams.batch_size,
		Kparams.batches_per_launch
	);
}

cudaError_t CudaCopyTargetWords(uint32_t value[5]) {
	return cudaMemcpyToSymbol(c_target_words, value, sizeof(value));
}

cudaError_t CudaCopyGx(const void* value, size_t size) {
	return cudaMemcpyToSymbol(c_Gx, value, size);
}

cudaError_t CudaCopyGy(const void* value, size_t size) {
	return cudaMemcpyToSymbol(c_Gy, value, size);
}

cudaError_t CudaCopyJx(const void* value) {
	return cudaMemcpyToSymbol(c_Jx, value, 4 * sizeof(uint64_t));
}

cudaError_t CudaCopyJy(const void* value) {
	return cudaMemcpyToSymbol(c_Jy, value, 4 * sizeof(uint64_t));
}