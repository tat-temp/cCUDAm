// RCAsm template for a hand-written TestKernel.
//
// Signature copied verbatim from GpuCore.cu:106-115. RCAsm splices its own instruction
// stream between ".text.TestKernel:" and the ".L_x_N" end label, so the body's *code* is
// thrown away -- what survives is the ELF shell, the .nv.info parameter attributes, the
// .nv.constant0/.nv.constant3 layout, and the declared LOCAL FRAME SIZE. The last of
// those is why this body is no longer trivial; see the comment on subp below.
//
// An earlier revision kept the body branchless on the theory that ptxas idioms with no
// RCAsm encoder (HFMA2-as-MOV, IADD.64, WARPSYNC, BRA.DIV) had to be avoided here. That
// was wrong twice over: inject_kernel replaces the instruction stream before the
// assembler ever sees it -- measured, the template cubin fails a plain round-trip and
// succeeds under injection -- and the encoder gap itself turned out to be an untaught
// repository rather than missing encoders (asm/TESTKERNEL_TEMPLATE.md §9.3).
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

	// Force the SAME 16 KB local frame the shipped kernel allocates, and it is not
	// cosmetic. GpuCore's prologue is
	//     LDC   R1, c[0x0][0x37c]
	//     IADD3 R1, PT, PT, R1, -0x4000, RZ
	// and a hand-written body doing the same thing has real storage behind that
	// subtraction only if .nv.info declares the frame -- the template is where the
	// frame size comes from, because injection replaces the instruction stream and
	// keeps the metadata. With the old zero-frame body, an injected kernel that
	// spilled subp would write into local memory the driver never reserved: no
	// fault, no diagnostic, just corruption of whatever the allocator put there.
	//
	// The index has to be genuinely runtime, or ptxas promotes the array into
	// registers and the frame collapses back to zero. Check the result rather than
	// trusting it: `cuobjdump -res-usage` must report 16384 bytes of local memory.
	uint64_t subp[MAX_BATCH_SIZE / 2][4];
	const uint32_t j = batch_size & (MAX_BATCH_SIZE / 2 - 1);
	const uint32_t k = batches_per_launch & (MAX_BATCH_SIZE / 2 - 1);
	subp[j][0] = v; subp[j][1] = v; subp[j][2] = v; subp[j][3] = v;

	Px[t] = subp[k][0] + v;
	Py[t] = subp[k][1] + v;
	start_scalars[t] = subp[k][2] + v;
	counts256[t] = subp[k][3] + v;
	find_result->scalar[0] = v;
}
