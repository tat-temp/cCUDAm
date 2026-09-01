#include "Defs.h"
#include "Math.cuh"
#include "GpuCore.cuh"
#include "GpuHash.cuh"
#include "GpuHash.cu"
#include "Math.cuh"

// ---- Native cubin path (make NATIVE_CUBIN=...) ---------------------------------
// TestKernel is launched from a prebuilt .cubin through the driver API instead of the
// runtime <<<>>> launch. Only the launch and the constant uploads are rerouted.
#if USE_NATIVE_CUBIN
#include "CallCubin.h"
#include <stdio.h>
#include <mutex>

#ifndef NATIVE_CUBIN_PATH
#define NATIVE_CUBIN_PATH "GpuCore.cubin"
#endif

// One module per GPU, not per thread: Prepare() uploads the constants from the main
// thread while Execute() launches from the worker thread, and both must reach the same module.
static TCubinCall g_cubin[MAX_GPU_CNT];
static bool       g_cubin_ready[MAX_GPU_CNT];
static std::mutex g_cubin_lock;

static TCubinCall* NativeCubin()
{
	int dev = 0;
	if ((cudaGetDevice(&dev) != cudaSuccess) || (dev < 0) || (dev >= MAX_GPU_CNT))
		return NULL;

	std::lock_guard<std::mutex> guard(g_cubin_lock);
	if (!g_cubin_ready[dev])
	{
		if (!g_cubin[dev].LoadCubin(NATIVE_CUBIN_PATH))
			return NULL;
		g_cubin_ready[dev] = true;
		printf("GPU %d: loaded native cubin %s\n", dev, NATIVE_CUBIN_PATH);
	}
	return &g_cubin[dev];
}

// The six __constant__ tables live in the cubin's own module, so cudaMemcpyToSymbol
// -- which addresses the runtime-linked module -- would write to the wrong place.
static cudaError_t NativeToSymbol(const char* name, const void* value, size_t size)
{
	TCubinCall* cc = NativeCubin();
	if (!cc)
		return cudaErrorInitializationError;
	return cc->CopyToSymbol(name, const_cast<void*>(value), (int)size)
		? cudaSuccess : cudaErrorInvalidSymbol;
}
#endif

#define BLOCK_CNT	gridDim.x
#define BLOCK_X		blockIdx.x
#define THREAD_X	threadIdx.x

// 4 limbs as two 128-bit accesses. idx counts LIMBS, so ptr must be flat: for a [N][4] array
// pass the row (SAVE_VAL_256(subp[i], acc, 0)), never the array with a row index.
#define LOAD_VAL_256(dst, ptr, idx) { *((int4*)&(dst)[0]) = *((int4*)&(ptr)[idx]); *((int4*)&(dst)[2]) = *((int4*)&(ptr)[idx + 2]); }
#define SAVE_VAL_256(ptr, src, idx) { *((int4*)&(ptr)[idx]) = *((int4*)&(src)[0]); *((int4*)&(ptr)[idx + 2]) = *((int4*)&(src)[2]); }

__device__ __constant__ uint32_t c_target_words[5];
// __align__(16): each 4-limb entry starts on a 32-byte boundary, so a point reads as two
// LDCU.128 instead of four LDCU.64 (see load4_const).
__device__ __constant__ __align__(16) uint64_t c_Gx[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ __align__(16) uint64_t c_Gy[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ __align__(16) uint64_t c_GyNeg[(MAX_BATCH_SIZE/2) * 4];   // P - Gy[k], negated on the host
__device__ __constant__ __align__(16) uint64_t c_Jx[4];
__device__ __constant__ __align__(16) uint64_t c_Jy[4];

// 4 limbs out of a 16-byte-aligned __constant__ table, as two 128-bit loads.
__device__ __forceinline__ void load4_const(uint64_t* r, const uint64_t* src)
{
	((int4*)r)[0] = ((const int4*)src)[0];
	((int4*)r)[1] = ((const int4*)src)[1];
}


// Points-only build: `make NO_HASH=1`. Compiles the hash layer out of the hot path so the EC walk
// can be measured on its own (asm/TESTKERNEL_TEMPLATE.md §9). Without the sink below, px3/lam/s
// are dead and nvcc deletes essentially the whole walk -- only the inverse chain and the point
// jump survive -- so a "points/sec" number off such a build measures nothing. This build cannot
// find a key and is not meant to: `found` is never set from a hash match.
#ifndef NO_HASH
#define NO_HASH 0
#endif

#if NO_HASH
#define HASH_CONSUME(sink, prefix, X) \
	do { (sink) ^= (X)[0] ^ (X)[1] ^ (X)[2] ^ (X)[3] ^ (uint64_t)(prefix); } while (0)
#endif

		
// Publish a hit into the mapped result struct, exactly once. Every found path goes through here.
//
// H7: the fence must stay BETWEEN the scalar stores and the flag. Copy_u64_x4 is four separate
// stores (Math.cuh:37) and a fence after both orders nothing between them; a host that saw `found`
// early would hand a torn scalar to DumpFound, which prints a well-formed, self-consistent,
// completely WRONG key -- no host-side hash160 recheck catches that. Latent only because the sole
// host read follows cudaStreamSynchronize; the mid-launch poll P1 wants would make it live.
// atomicCAS picks a single publisher; only the _system atomics order against the host (sm_60+).
__device__ __forceinline__ void publish_found(TFindResult* __restrict__ find_result,
                                              const uint64_t scalar[4])
{
	if (atomicCAS_system(&find_result->claimed, 0u, 1u) != 0u) return;

	Copy_u64_x4(find_result->scalar, scalar);
	__threadfence_system();								// scalar lands before the flag can
	atomicExch_system(&find_result->found, 1u);
}

extern "C" __launch_bounds__(THREADS_PER_BLOCK, BLOCKS_PER_SM)
__global__ void TestKernel(
	uint64_t* __restrict__ Px,
    uint64_t* __restrict__ Py,
	uint64_t* __restrict__ start_scalars,
	TFindResult* __restrict__ find_result, //found_scalar,
	uint64_t threadsTotal,
    uint32_t batch_size,
    uint32_t batches_per_launch)
{
	const uint32_t B = (uint32_t)batch_size;
	if (B <= 0 || (B & 1) || B > MAX_BATCH_SIZE) return;
    const uint32_t half = B >> 1;
	
	const uint64_t gid = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (gid >= threadsTotal) return;
	
	// No warp mask is captured here: it is re-derived every iteration (see the __ballot_sync below).

	// Filter on hash160 WORD 2, not word 0: any single word is an equally selective 32-bit filter,
    // and word 2 is the cheapest of the five to produce (see CUDAHash.cu).
    const uint32_t target_prefix = c_target_words[2];
	
	// The per-thread remaining-key counter (rem, and the counts256 array behind it) is gone. The
	// HOST now owns the batch budget: every thread is given the SAME number of batches, and the
	// final launch is shortened by passing a smaller batches_per_launch rather than by letting
	// each thread notice it has run out (GpuPuzzle.cpp, PrepareHost/Execute). That is the
	// precondition asm/tk/main.asm always assumed and could not enforce.
	//
	// What this buys, in order of importance:
	//   * Every lane of a warp now runs exactly the same number of iterations BY CONSTRUCTION.
	//     InvMod256 "requires all active threads in warp" (asm/mod_inv.asm:189), and the
	//     straddling warp H4 patched -- one lane leaving the loop an iteration early while still
	//     live for the write-back -- can no longer be built, at any range, not just a
	//     power-of-two one.
	//   * A 256-bit compare and a 256-bit subtract leave the batch loop.
	//   * 32 bytes/thread of device memory, its pinned host mirror and its H2D copy are gone,
	//     as are four loads at entry and four stores at exit.
	__align__(16) uint64_t x1[4], y1[4], s1[4];
	// GS: cache lane ????
    //{ const uint64_t idx = gid*4 + 0; x1[0] = Px[idx]; y1[0] = Py[idx]; s1[0] = start_scalars[idx]; }
    //{ const uint64_t idx = gid*4 + 1; x1[1] = Px[idx]; y1[1] = Py[idx]; s1[1] = start_scalars[idx]; }
    //{ const uint64_t idx = gid*4 + 2; x1[2] = Px[idx]; y1[2] = Py[idx]; s1[2] = start_scalars[idx]; }
    //{ const uint64_t idx = gid*4 + 3; x1[3] = Px[idx]; y1[3] = Py[idx]; s1[3] = start_scalars[idx]; }
	const uint64_t idx = gid*4 + 0;
	LOAD_VAL_256(x1, Px, idx);
	LOAD_VAL_256(y1, Py, idx);
	LOAD_VAL_256(s1, start_scalars, idx);

	// A mask handed to a warp intrinsic must name exactly the lanes that reach it: CUDA requires
	// every NON-EXITED thread named in a mask to run the same intrinsic with the same mask, and on
	// Volta+ a mask naming a live thread that never arrives can stall the warp.
	//
	// H4: one captured __activemask() cannot serve this loop. The per-iteration __ballot_sync
	// names exactly the lanes that enter the body; the other exits leave the kernel entirely,
	// and exited threads are exempt.
	//
	// The divergence H4 was originally patching is now GONE at the source: `live` below depends
	// only on batches_per_launch, which is a kernel argument and therefore warp-uniform, so no
	// lane can leave this loop while another stays in it. The ballot is kept anyway, and it is
	// not vestigial -- a lane that publishes a find RETURNS from inside the body, so the set of
	// arriving lanes still shrinks mid-loop, and the ballot is what keeps the mask naming that
	// set. It also costs one instruction per batch against B keys' worth of hashing.
	//
	// The seed must stay 0xFFFFFFFFu: the full mask is legal (every lane either reaches the first
	// ballot or has exited) and the ballot self-corrects on iteration 0, whereas __activemask() here
	// is a nondeterministic post-divergence snapshot, and lanes seeing different snapshots would call
	// __ballot_sync with mismatched masks -- undefined. All 32 lanes is safe: blockDim.x is always a
	// multiple of 32 (GpuPuzzle.cpp:283-288, Defs.h:15-16).
	unsigned mask = 0xFFFFFFFFu;
	uint32_t batches_done = 0;
#if NO_HASH
	uint64_t sink = 0ull;
#endif
	while (true) {
		const bool live = (batches_done < batches_per_launch);
		mask = __ballot_sync(mask, live);
		if (!live) break;

		uint8_t prefix = (uint8_t)(y1[0] & 1ULL) ? 0x03 : 0x02;
#if NO_HASH
		HASH_CONSUME(sink, prefix, x1);
#else
		uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(x1));   // by-value ABI: 1 reg out

        bool pref = (hw2 == target_prefix);
		if (__any_sync(mask, pref)) {
			bool full = pref && hash160_full_match(prefix, u256_of(x1), c_target_words);
			if (full) {
				publish_found(find_result, s1);
			}

			if (__any_sync(mask, full)) { __syncwarp(mask); return; }
		}
#endif

		__align__(16) uint64_t subp[MAX_BATCH_SIZE / 2][4];
		__align__(16) uint64_t acc[4], tmp[4];
		
		sub_mod(acc, c_Jx, x1);
		
		#pragma unroll
		for(int i = 0; i < 4; i++) subp[half-1][i] = acc[i];

		for (int i = half - 2; i >= 0; --i) {
            __align__(16) uint64_t gx_i[4];
			load4_const(gx_i, &c_Gx[(size_t)(i + 1) * 4]);
            sub_mod(tmp, gx_i, x1);
            mul_mod(acc, acc, tmp);
            //subp[i][0] = acc[0]; subp[i][1] = acc[1];
            //subp[i][2] = acc[2]; subp[i][3] = acc[3];
			SAVE_VAL_256(subp[i], acc, 0);
        }

		__align__(16) uint64_t inverse[5];
		sub_mod((uint64_t*)inverse, &c_Gx[0], x1);      // d0 = c_Gx[0] - x1, straight into inverse[0..3]
        mul_mod(inverse, inverse, subp[0]);
		
		inv_mod((uint32_t*)inverse);
		
		for (int i = 0; i < half - 1; ++i) {
            uint64_t dx_inv_i[4];
            mul_mod(dx_inv_i, subp[i], inverse);

			{
				uint64_t px3[4], s[4], lam[4];
                __align__(16) uint64_t px_i[4], py_i[4];
				
				// GS: Cache lane???
                load4_const(px_i, &c_Gx[(size_t)i*4]);
                load4_const(py_i, &c_Gy[(size_t)i*4]);

                sub_mod(s, py_i, y1);
                mul_mod(lam, s, dx_inv_i);

                sqr_mod(px3, lam);
                sub_mod3(px3, px3, x1, px_i);   // px3 = lam^2 - x1 - px_i (fused, one reduction)

                sub_mod(s, x1, px3); 
                mul_mod(s, s, lam);

				uint8_t prefix = sub_mod_is_odd_prefix(s, y1);
#if NO_HASH
				HASH_CONSUME(sink, prefix, px3);
#else
				uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(px3));   // by-value ABI: 1 reg out
				bool pref = (hw2 == target_prefix);
				if (__any_sync(mask, pref)) {
					bool full = pref && hash160_full_match(prefix, u256_of(px3), c_target_words);
					if (full) {
						// Add in registers, not as a read-modify-write over PCIe into the mapped struct.
						uint64_t hit[4];
						Copy_u64_x4(hit, s1);
						add256_u64(hit, (uint64_t)i + 1ull);
						publish_found(find_result, hit);
					}

					if (__any_sync(mask, full)) { __syncwarp(mask); return; }
				}
#endif
			}
			
			{
				uint64_t px3[4], s[4], lam[4];
                __align__(16) uint64_t px_i[4], py_i[4];
				
				// GS: Cache lane???
                load4_const(px_i, &c_Gx[(size_t)i*4]);
                load4_const(py_i, &c_GyNeg[(size_t)i*4]);

                sub_mod(s, py_i, y1);
                mul_mod(lam, s, dx_inv_i);

                sqr_mod(px3, lam);
                sub_mod3(px3, px3, x1, px_i);   // px3 = lam^2 - x1 - px_i (fused, one reduction)

                sub_mod(s, x1, px3);
                mul_mod(s, s, lam);

				uint8_t prefix = sub_mod_is_odd_prefix(s, y1);
#if NO_HASH
				HASH_CONSUME(sink, prefix, px3);
#else
				uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(px3));   // by-value ABI: 1 reg out
				bool pref = (hw2 == target_prefix);
				if (__any_sync(mask, pref)) {
					bool full = pref && hash160_full_match(prefix, u256_of(px3), c_target_words);
					if (full) {
						uint64_t hit[4];
						Copy_u64_x4(hit, s1);
						sub256_u64(hit, (uint64_t)i + 1ull);
						publish_found(find_result, hit);
					}

					if (__any_sync(mask, full)) { __syncwarp(mask); return; }
				}
#endif
			}
			
			uint64_t gxmi[4];
			__align__(16) uint64_t gx_i[4];
            load4_const(gx_i, &c_Gx[(size_t)i*4]);
            sub_mod(gxmi, gx_i, x1);
            mul_mod(inverse, inverse, gxmi);
		}
		
		{
            const int i = half - 1;
            uint64_t dx_inv_i[4];
            mul_mod(dx_inv_i, subp[i], inverse);

            uint64_t px3[4], s[4], lam[4];
            __align__(16) uint64_t px_i[4], py_i[4];
			
            load4_const(px_i, &c_Gx[(size_t)i*4]);
            load4_const(py_i, &c_GyNeg[(size_t)i*4]);

            sub_mod(s, py_i, y1);
            mul_mod(lam, s, dx_inv_i);

            sqr_mod(px3, lam);
            sub_mod3(px3, px3, x1, px_i);   // px3 = lam^2 - x1 - px_i (fused, one reduction)

            sub_mod(s, x1, px3);
            mul_mod(s, s, lam);

			uint8_t prefix = sub_mod_is_odd_prefix(s, y1);
#if NO_HASH
			HASH_CONSUME(sink, prefix, px3);
#else
			uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(px3));   // by-value ABI: 1 reg out
			bool pref = (hw2 == target_prefix);
			if (__any_sync(mask, pref)) {
				bool full = pref && hash160_full_match(prefix, u256_of(px3), c_target_words);
				if (full) {
					uint64_t hit[4];
					Copy_u64_x4(hit, s1);
					sub256_u64(hit, (uint64_t)half);
					publish_found(find_result, hit);
				}

				if (__any_sync(mask, full)) { __syncwarp(mask); return; }
			}
#endif

            uint64_t last_dx[4];
            __align__(16) uint64_t gx_last[4];
			load4_const(gx_last, &c_Gx[(size_t)i*4]);
            sub_mod(last_dx, gx_last, x1);
            mul_mod(inverse, inverse, last_dx);
        }
		
		{
            uint64_t lam[4], s[4], x3[4], y3[4];
            uint64_t Jy_minus_y1[4];
			
            sub_mod(Jy_minus_y1, c_Jy, y1);

            mul_mod(lam, Jy_minus_y1, inverse);
            sqr_mod(x3, lam);
            __align__(16) uint64_t Jx_local[4];
			load4_const(Jx_local, c_Jx);
            sub_mod3(x3, x3, x1, Jx_local);   // x3 = lam^2 - x1 - Jx (fused, one reduction)

            sub_mod(s, x1, x3);
            mul_mod(y3, s, lam);
            sub_mod(y3, y3, y1);

            x1[0] = x3[0]; y1[0] = y3[0];
            x1[1] = x3[1]; y1[1] = y3[1];
            x1[2] = x3[2]; y1[2] = y3[2];
            x1[3] = x3[3]; y1[3] = y3[3];
        }
		
		add256_u64(s1, (uint64_t)B);

		batches_done++;
	}
	
#if NO_HASH
	// The one escape for the sink: without it nvcc deletes the walk (see NO_HASH above). Outside the
	// loop, and compared against a value the arithmetic cannot be shown not to produce, which is what
	// makes it un-eliminable. It will not fire (2^-64/thread), and this build cannot report a key.
	if (sink == 0xD1CEB0EDFACADE01ull) publish_found(find_result, s1);
#endif
	SAVE_VAL_256(Px, x1, idx);
	SAVE_VAL_256(Py, y1, idx);
	SAVE_VAL_256(start_scalars, s1, idx);
    
}

// Returns cudaSuccess when the launch was ACCEPTED -- not when the kernel finished.
//
// A rejected launch enqueues nothing, so the cudaStreamSynchronize in Execute() waits on an empty
// stream and returns cudaSuccess: the run loop counts launches that never happened and the program
// exits 2, "Range exhausted: key not found", having computed nothing. Native cuLaunchKernel returns
// its status directly; <<<>>> DISCARDS cudaLaunchKernel's return and leaves synchronous rejections
// (H12 cudaErrorNoKernelImageForDevice on a non-sm_120 card, LaunchOutOfResources,
// InvalidConfiguration, the local-memory failure TestKernel's 16 KB frame invites) only in the
// per-thread last-error slot, which a synchronize does NOT report. The slot is therefore drained
// immediately before the launch, so the value read after it describes only that launch -- that is
// what keeps the H6 item-3 misattribution out.
cudaError_t CallGpuKernel(TKparams& Kparams, cudaStream_t cudaStream) {
#if USE_NATIVE_CUBIN
	TCubinCall* cc = NativeCubin();
	if (!cc)
		return cudaErrorInitializationError;

	// One entry per declared parameter; cuLaunchKernel reads exactly as many as the signature has.
	// NOTE: dropping counts256 shifted every parameter after it down one slot, so a cubin built
	// against the old 8-parameter layout will read find_result where threadsTotal now lives and
	// launch into nonsense. asm/tmpl_TestKernel.cu and asm/tk/main.asm carry the matching layout
	// and were updated with this; the committed asm/tk/*.cubin fixtures were NOT rebuilt (that
	// needs RCAsm and a card) and are stale until they are.
	void* args[7] = {
		&Kparams.px,
		&Kparams.py,
		&Kparams.scalars,
		&Kparams.d_find_result,
		&Kparams.threads_total,
		&Kparams.batch_size,
		&Kparams.batches_per_launch
	};

	TCallKernelParams p = {};
	snprintf(p.kernel_name, sizeof(p.kernel_name), "TestKernel");
	p.blockSize      = (int)Kparams.block_size;
	p.blockCnt       = (int)Kparams.block_count;
	p.sharedSize     = 0;
	p.stream         = cudaStream;
	p.kernel_args    = args;
	p.kernel_arg_cnt = 7;
	if (!cc->CallKernel(p))
		return cudaErrorLaunchFailure;   // CallKernel has already printed the CUresult
	return cudaSuccess;
#else
	cudaGetLastError();   // drain, so the read below can only describe this launch

	TestKernel <<< Kparams.block_count, Kparams.block_size, 0, cudaStream >>> (
		Kparams.px,
		Kparams.py,
		Kparams.scalars,
		Kparams.d_find_result,
		Kparams.threads_total,
		Kparams.batch_size,
		Kparams.batches_per_launch
	);

	return cudaGetLastError();
#endif
}

cudaError_t CudaCopyTargetWords(const void* value) {
#if USE_NATIVE_CUBIN
	return NativeToSymbol("c_target_words", value, 5 * sizeof(uint32_t));
#else
	return cudaMemcpyToSymbol(c_target_words, value, 5 * sizeof(uint32_t));
#endif
}

cudaError_t CudaCopyGx(const void* value, size_t size) {
#if USE_NATIVE_CUBIN
	return NativeToSymbol("c_Gx", value, size);
#else
	return cudaMemcpyToSymbol(c_Gx, value, size);
#endif
}

cudaError_t CudaCopyGy(const void* value, size_t size) {
#if USE_NATIVE_CUBIN
	return NativeToSymbol("c_Gy", value, size);
#else
	return cudaMemcpyToSymbol(c_Gy, value, size);
#endif
}

cudaError_t CudaCopyGyNeg(const void* value, size_t size) {
#if USE_NATIVE_CUBIN
	return NativeToSymbol("c_GyNeg", value, size);
#else
	return cudaMemcpyToSymbol(c_GyNeg, value, size);
#endif
}

cudaError_t CudaCopyJx(const void* value) {
#if USE_NATIVE_CUBIN
	return NativeToSymbol("c_Jx", value, 4 * sizeof(uint64_t));
#else
	return cudaMemcpyToSymbol(c_Jx, value, 4 * sizeof(uint64_t));
#endif
}

cudaError_t CudaCopyJy(const void* value) {
#if USE_NATIVE_CUBIN
	return NativeToSymbol("c_Jy", value, 4 * sizeof(uint64_t));
#else
	return cudaMemcpyToSymbol(c_Jy, value, 4 * sizeof(uint64_t));
#endif
}

cudaError_t CudaSetupKernel() {
#if USE_NATIVE_CUBIN
	// cudaFuncSetCacheConfig would configure the runtime-linked TestKernel, not the one being
	// launched. DEVPLAN records PreferL1 as a verified non-win, so there is nothing to reproduce.
	return cudaSuccess;
#else
	return cudaFuncSetCacheConfig(TestKernel, cudaFuncCachePreferL1);
#endif
}