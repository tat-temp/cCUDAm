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

#if STAGE_PTS
#define STAGE_WALK 1
#endif
#if STAGE_WALK
#define STAGE_INV 1
#endif
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

#if STAGE_WALK
    // Stage 2c-i, GpuCore.cu:240-331 with the point arithmetic left out. Acc is the product
    // of every dx_inv_i, so one wrong subp[] slot moves it -- reporting only the last one
    // would leave 511 of the 512 reads untested.
    uint64_t wacc[4] = {1, 0, 0, 0};

#if STAGE_PTS
    // Stage 2c-ii: the +/- point arithmetic, GpuCore.cu:244-327, with the two branches
    // folded into one loop because they differ only by neg_mod. The parity is computed and
    // NOT accumulated -- see the note in asm/tk/main.asm: a non-canonical s flips it, so it
    // is not a well-defined function of the inputs until C8 is fixed.
    #define PTS_BRANCH(NEG)                                                            \
        do {                                                                           \
            uint64_t px3[4], s[4], lam[4], px_i[4], py_i[4];                           \
            for (int k = 0; k < 4; k++) {                                              \
                px_i[k] = c_Gx[(size_t)i * 4 + k];                                     \
                py_i[k] = c_Gy[(size_t)i * 4 + k];                                     \
            }                                                                          \
            if (NEG) neg_mod(py_i);                                                    \
            sub_mod(s, py_i, y1);                                                      \
            mul_mod(lam, s, dx_inv_i);                                                 \
            uint64_t sq[4];                                                            \
            sqr_mod(sq, lam);                                                          \
            sub_mod3(px3, sq, x1, px_i);                                               \
            sub_mod(s, x1, px3);                                                       \
            mul_mod(s, s, lam);                                                        \
            uint8_t odd; sub_mod_is_odd(&odd, s, y1); (void)odd;                       \
            mul_mod(wacc, wacc, px3);                                                  \
            for (int k = 0; k < 4; k++) {                                              \
                lastpx3[k] = px3[k]; lastlam[k] = lam[k]; lastsqr[k] = sq[k];          \
            }                                                                          \
        } while (0)
    // The tail point's chain, one link per output array: Px = the product, Py = px3,
    // start_scalars = lam, counts256 = lam^2. Four arrays, four links, so a single launch
    // says WHICH link diverges rather than only that the product does.
    uint64_t lastpx3[4] = {0, 0, 0, 0};
    uint64_t lastlam[4] = {0, 0, 0, 0};
    uint64_t lastsqr[4] = {0, 0, 0, 0};
#endif

    for (int i = 0; i < (int)half - 1; ++i) {
        uint64_t dx_inv_i[4], gxmi[4];
        mul_mod(dx_inv_i, subp[i], inverse);
#if STAGE_PTS
        PTS_BRANCH(0);
        PTS_BRANCH(1);
#else
        mul_mod(wacc, wacc, dx_inv_i);
#endif
        sub_mod(gxmi, &c_Gx[(size_t)i * 4], x1);
        mul_mod(inverse, inverse, gxmi);
    }
    {
        const int i = (int)half - 1;
        uint64_t dx_inv_i[4];
        mul_mod(dx_inv_i, subp[i], inverse);
#if STAGE_PTS
        PTS_BRANCH(1);                     // the tail is the minus branch alone
#else
        mul_mod(wacc, wacc, dx_inv_i);
#endif
    }
#endif

    for (int k = 0; k < 4; k++) {
        const uint64_t idx = gid * 4 + k;
#if STAGE_WALK
        Px[idx]            = wacc[k];
#elif STAGE_INV
        Px[idx]            = inverse[k];
#else
        Px[idx]            = acc[k];
#endif
#if STAGE_PTS
        // The tail's point on its own -- i = half-1, minus branch. A product of 1023 points
        // cannot say which one is wrong; one point can.
        Py[idx]            = lastpx3[k];
#else
        Py[idx]            = subp[half - 1][k];   // written before the loop, highest address
#endif
#if STAGE_PTS
        start_scalars[idx] = lastlam[k];
        counts256[idx]     = lastsqr[k];
#else
        start_scalars[idx] = s1[k];
        counts256[idx]     = rem[k];
#endif
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
