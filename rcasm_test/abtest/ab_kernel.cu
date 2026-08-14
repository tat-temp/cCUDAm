// The COMPILED side of the A/B: a TestKernel that computes exactly what the
// hand-written SASS kernel (asm/tk/main.asm) currently computes, so the two are
// diffable.
//
// Signature, constant tables and launch bounds are identical to the real TestKernel --
// this is deliberately not a reduced stand-in, because the parameter ABI is one of the
// things under test.
//
// Stage 1b semantics (default):
//     Px       = mul_mod(x1, y1)      <- the operation being compared
//     Py       = y1                   <- identity
//     scalars  = s1                   <- identity
//     counts   = rem                  <- identity
//
// Stage 2a semantics (-DSTAGE_SUFP=1), mirroring GpuCore.cu:224-233 exactly:
//     Px       = acc                  <- the whole suffix product
//     Py       = subp[half-1]         <- read back out of the local frame
//     scalars  = s1                   <- identity
//     counts   = rem                  <- identity
//
// Build it the same way the template is built (-rdc=true, two-step device link), so the
// five __constant__ tables get GLOBAL binding and one harness can upload to both cubins
// through cuModuleGetGlobal.

#include <cstdint>

#define THREADS_PER_BLOCK   256
#define BLOCKS_PER_SM       2
#define MAX_BATCH_SIZE      1024

struct TFindResult {
    uint64_t scalar[4];
    uint64_t rx[4];
    uint64_t ry[4];
    uint32_t claimed;
    uint32_t found;
};

#include "../../Math.cuh"

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
    const uint64_t gid = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (gid >= threadsTotal) return;

    uint64_t x1[4], y1[4], s1[4], rem[4];
    for (int k = 0; k < 4; k++) {
        const uint64_t idx = gid * 4 + k;
        x1[k]  = Px[idx];
        y1[k]  = Py[idx];
        s1[k]  = start_scalars[idx];
        rem[k] = counts256[idx];
    }

    // The SASS kernel bails here too; keeping it makes the two agree on which threads
    // write anything at all.
    if ((rem[0] | rem[1] | rem[2] | rem[3]) == 0ull) return;

#if STAGE_INV
#define STAGE_SUFP 1
#endif

#if STAGE_SUFP
    // The suffix-product ladder, transcribed from GpuCore.cu with nothing else attached.
    // subp lives in a local array of the same shape as the real kernel's so the frame is
    // the same 16 KB and the two sides are comparable on cost as well as on answers.
    const uint32_t half = batch_size >> 1;
    uint64_t subp[MAX_BATCH_SIZE / 2][4];
    uint64_t acc[4], tmp[4];

    sub_mod(acc, c_Jx, x1);
    #pragma unroll
    for (int k = 0; k < 4; k++) subp[half - 1][k] = acc[k];

    for (int i = (int)half - 2; i >= 0; --i) {
        sub_mod(tmp, &c_Gx[(size_t)(i + 1) * 4], x1);
        mul_mod(acc, acc, tmp);
        subp[i][0] = acc[0]; subp[i][1] = acc[1]; subp[i][2] = acc[2]; subp[i][3] = acc[3];
    }

#if STAGE_INV
    // Stage 2b, GpuCore.cu:236-239. inverse is uint64_t[5] because inv_mod works on 288
    // bits; sub_mod fills [0..3] and inv_mod writes r[8] = 0 itself.
    uint64_t inverse[5];
    sub_mod((uint64_t*)inverse, &c_Gx[0], x1);
    mul_mod(inverse, inverse, subp[0]);
    inv_mod((uint32_t*)inverse);
#endif

    for (int k = 0; k < 4; k++) {
        const uint64_t idx = gid * 4 + k;
#if STAGE_INV
        Px[idx]            = inverse[k];
#else
        Px[idx]            = acc[k];
#endif
        Py[idx]            = subp[half - 1][k];   // written before the loop, highest address
        start_scalars[idx] = s1[k];
        counts256[idx]     = rem[k];
    }
#else
    uint64_t prod[4];
    mul_mod(prod, x1, y1);

    for (int k = 0; k < 4; k++) {
        const uint64_t idx = gid * 4 + k;
        Px[idx]            = prod[k];
        Py[idx]            = y1[k];
        start_scalars[idx] = s1[k];
        counts256[idx]     = rem[k];
    }
#endif
}
