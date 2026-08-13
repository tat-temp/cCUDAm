// RCAsm template for a hand-written TestKernel.
// Signature copied verbatim from GpuCore.cu:106-115. Body deliberately trivial:
// DEVPLAN warns that ptxas idioms (HFMA2-as-MOV, IADD.64, WARPSYNC, BRA.DIV ...)
// have no RCAsm encoder, so the template must not provoke them. RCAsm only splices
// its own instruction stream between ".text.TestKernel:" and the ".L_x_N" end label,
// so the body's *code* is thrown away -- only the ELF shell, the .nv.info parameter
// attributes and the .nv.constant0/.nv.constant3 layout survive.
//
// TFindResult is copied verbatim from Defs.h:32-38 (NOT a stand-in).
// THREADS_PER_BLOCK / BLOCKS_PER_SM copied from Defs.h:14,16.

#include <cstdint>

#define THREADS_PER_BLOCK	256
#define BLOCKS_PER_SM		2
#define MAX_BATCH_SIZE		1024

struct TFindResult {
    uint64_t scalar[4];
    uint64_t rx[4];
    uint64_t ry[4];
    uint32_t claimed;
    uint32_t found;
};

// The five __constant__ tables, verbatim from GpuCore.cu:63-67. They must be here:
// they define .nv.constant3 and the host reaches them through cuModuleGetGlobal.
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
	TFindResult* __restrict__ find_result,
	uint64_t threadsTotal,
    uint32_t batch_size,
    uint32_t batches_per_launch)
{
	// Touch every parameter and every constant table exactly once, with plain
	// 64-bit adds and 64-bit stores. No loops, no branches, no divergence.
	const uint64_t t = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
	if (t >= threadsTotal) return;
	const uint64_t v = t + batch_size + batches_per_launch
	                 + c_Gx[0] + c_Gy[0] + c_Jx[0] + c_Jy[0] + c_target_words[2];
	Px[t] = v;
	Py[t] = v;
	start_scalars[t] = v;
	counts256[t] = v;
	find_result->scalar[0] = v;
}
