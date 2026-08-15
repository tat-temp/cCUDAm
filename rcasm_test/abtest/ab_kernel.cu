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
// ge256_u64 / add256_u64 / sub256_u64 -- the batch loop's guard and its bookkeeping, taken
// from the real kernel's header rather than retyped, so `rem >= B` means here what it means
// there.
#include "../../GpuCore.cuh"

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

#if STAGE_LOOP
#define STAGE_JUMP 1
#endif
#if STAGE_JUMP
#define STAGE_PTS 1
#endif
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

#if STAGE_JUMP
    // The NO_HASH trap, and it bit here exactly as GpuCore.cu:70-82 warns. On the pts rung
    // the per-point px3/lam/lam^2 are written out, so the walk survives; on jump and loop
    // nothing consumes them and nvcc deletes the entire +/- walk -- MEASURED, 4392 SASS
    // instructions at pts against 2496 at jump before this sink existed. The answers would
    // still have been right (x1 after the jump depends on `inverse`, not on any px3), and
    // that is what makes it dangerous: A and B would agree, the rung would pass, and the
    // compiled side would not have run the code the hand-written side is being compared to.
    // Same escape as the real kernel's: one comparison, outside the loop, against a value
    // the arithmetic cannot be shown not to produce.
    uint64_t sink = 0ull;
#endif

#if STAGE_LOOP
    // Stage 2d part 2, GpuCore.cu:199-202 and :404-410. The guard is the real kernel's
    // `live` minus the ballot: this build's threads all take the same number of batches by
    // construction, and a ragged warp would break InvMod256 on both sides identically rather
    // than making them disagree, so the ballot is not what is under test here.
    uint32_t batches_done = 0;
    while (batches_done < batches_per_launch && ge256_u64(rem, (uint64_t)batch_size)) {
#endif

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
    // Only jump and loop need it -- the pts rung keeps the walk alive by writing its
    // intermediates out. Costs five XORs per point where the mul_mod feeding them is ~222
    // instructions.
#if STAGE_JUMP
    #define SINK_CONSUME(X, ODD) sink ^= (X)[0] ^ (X)[1] ^ (X)[2] ^ (X)[3] ^ (uint64_t)(ODD)
#else
    #define SINK_CONSUME(X, ODD) do { } while (0)
#endif
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
            SINK_CONSUME(px3, odd);                                                    \
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
#if STAGE_JUMP
        // GpuCore.cu:378-380. The tail's OWN chain update, and it was missing here until the
        // jump rung ran: without it `inverse` reaches the jump as 1/((Jx-x1)*(Gx[half-1]-x1))
        // rather than 1/(Jx-x1), so lam is off by that factor -- not congruent, so it reads as
        // WRONG rather than NON-CANON, and it moves x3 as well as y3.
        //
        // Gated on STAGE_JUMP because `inverse` is dead after this block on every lower rung, so
        // the two spellings compute the same thing there and this keeps walk/pts bit-stable. The
        // hand-written side is gated the same way, in its JUMP region, for the same reason.
        uint64_t last_dx[4];
        sub_mod(last_dx, &c_Gx[(size_t)i * 4], x1);
        mul_mod(inverse, inverse, last_dx);
#endif
    }
#endif

#if STAGE_JUMP
    // Stage 2d part 1, GpuCore.cu:383-402. The batch's centre advances by J = half*G, and
    // this is the only consumer of `inverse` itself -- every other use multiplies it into a
    // subp[] slot first. A walk that accumulates 1023 correct dx_inv_i can still hand a wrong
    // value to exactly this, which is why it is its own rung.
    {
        uint64_t lam[4], s[4], x3[4], y3[4], Jy_minus_y1[4];
        sub_mod(Jy_minus_y1, c_Jy, y1);
        mul_mod(lam, Jy_minus_y1, inverse);
        sqr_mod(x3, lam);
        uint64_t Jx_local[4];
        for (int k = 0; k < 4; k++) Jx_local[k] = c_Jx[k];
        sub_mod3(x3, x3, x1, Jx_local);
        sub_mod(s, x1, x3);
        mul_mod(y3, s, lam);
        sub_mod(y3, y3, y1);
        for (int k = 0; k < 4; k++) { x1[k] = x3[k]; y1[k] = y3[k]; }
    }
#endif

#if STAGE_LOOP
        add256_u64(s1, (uint64_t)batch_size);
        sub256_u64(rem, (uint64_t)batch_size);
        batches_done++;
    }
#endif

#if STAGE_JUMP
    // The sink's one escape. It will not fire -- 2^-64 per thread -- and this build cannot
    // report a key anyway; what it does is make ~2000 instructions per batch un-deletable.
    if (sink == 0xD1CEB0EDFACADE01ull) find_result->scalar[0] = sink;
#endif

    // STAGE_JUMP has to come FIRST in this chain, not just before STAGE_WALK: under
    // STAGE_LOOP the walk's wacc/lastpx3 are declared inside the batch loop and are not in
    // scope out here at all, so an #elif that mentions them would not merely report the wrong
    // value, it would fail to compile -- which is the preferable of the two.
    for (int k = 0; k < 4; k++) {
        const uint64_t idx = gid * 4 + k;
#if STAGE_JUMP
        // Stage 2d writes what the real kernel writes: the advanced point and the advanced
        // bookkeeping. Four arrays, four independent values, and no intermediate spent on
        // diagnostics -- the rungs below this one are where a divergence gets localised.
        Px[idx]            = x1[k];
        Py[idx]            = y1[k];
        start_scalars[idx] = s1[k];
        counts256[idx]     = rem[k];
#else
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
