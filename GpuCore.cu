#include "Defs.h"
#include "Math.cuh"
#include "GpuCore.cuh"
#include "GpuHash.cuh"
#include "GpuHash.cu"
#include "Math.cuh"

// ---- Native cubin path (make NATIVE_CUBIN=...) ---------------------------------
// TestKernel is launched through the driver API out of a prebuilt .cubin instead of
// the runtime <<<>>> launch, so a hand-written-SASS kernel can be dropped in without
// rebuilding the host. Everything below this kernel's own source stays compiled and
// linked as before -- only the launch and the constant uploads are rerouted.
#if USE_NATIVE_CUBIN
#include "CallCubin.h"
#include <stdio.h>
#include <mutex>

#ifndef NATIVE_CUBIN_PATH
#define NATIVE_CUBIN_PATH "GpuCore.cubin"
#endif

// One module per GPU, not per thread: a CUmodule belongs to a context, and the
// runtime's primary context is per-device and shared by every thread that selects
// that device. Prepare() uploads the constants from the main thread while Execute()
// launches from the worker thread, and both must reach the same module.
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

// The five __constant__ tables live in the cubin's own module, so cudaMemcpyToSymbol
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

__device__ __constant__ uint32_t c_target_words[5];
__device__ __constant__ uint64_t c_Gx[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ uint64_t c_Gy[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ uint64_t c_Jx[4];
__device__ __constant__ uint64_t c_Jy[4];


#define FLUSH_THRESHOLD 65536u
//#define WARP_FLUSH_HASHES() do { \
//    unsigned long long v = warp_reduce_add_ull((unsigned long long)local_hashes); \
//    if (lane == 0 && v) atomicAdd(hashes_accum, v); \
//    local_hashes = 0; \
//} while (0)
#define WARP_FLUSH_HASHES()
#define MAYBE_WARP_FLUSH() do { if ((local_hashes & (FLUSH_THRESHOLD - 1u)) == 0u) WARP_FLUSH_HASHES(); } while (0)
		
// Publish a hit into the mapped result struct, exactly once, in the order the host needs to observe
// it. Every found path goes through here.
//
// The old code stored the scalar, set found = true, and only THEN issued __threadfence_system(). A
// release fence orders what precedes it against what follows, so a fence placed after both orders
// nothing *between* them -- and Copy_u64_x4 is four separate stores (Math.cuh:37), not one wide one.
// Nothing stopped `found` from reaching the mapped page ahead of some or all of `scalar`. A host
// that saw the flag early would hand a torn scalar to DumpFound, which multiplies it out and prints
// a well-formed, self-consistent, completely wrong key -- there is no hash160 recheck host-side to
// catch that. It stayed latent only because the sole host read happens after cudaStreamSynchronize,
// which is already a full ordering point; adding the mid-launch poll that P1 wants would make it
// live.
//
// atomicCAS picks a single publisher, so a second finder cannot overwrite a scalar the host may
// already be reading. The _system variants are the ones that mean anything on mapped host memory
// (device-scope atomics do not order against the host); they need sm_60+, which init_gpus already
// requires.
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
    uint64_t* __restrict__ counts256,
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
	
	//const unsigned lane      = (unsigned)(threadIdx.x & (WARP_SIZE - 1));
	// There is no single warp mask any more. One captured here could not stay valid: the batch loop
	// below drops lanes at different iterations, so the mask has to be re-derived. See there.

	// Filter on hash160 WORD 2, not word 0: word 2 is the cheapest of the five to produce
    // (its RIPEMD-160 inputs are final 7 rounds earlier -- see CUDAHash.cu). Any single word
    // is an equally selective 32-bit filter, so this is a free choice.
    const uint32_t target_prefix = c_target_words[2];
	
	uint64_t x1[4], y1[4], s1[4], rem[4];
	// GS: cache lane ????
    { const uint64_t idx = gid*4 + 0; x1[0] = Px[idx]; y1[0] = Py[idx]; s1[0] = start_scalars[idx]; rem[0] = counts256[idx]; }
    { const uint64_t idx = gid*4 + 1; x1[1] = Px[idx]; y1[1] = Py[idx]; s1[1] = start_scalars[idx]; rem[1] = counts256[idx]; }
    { const uint64_t idx = gid*4 + 2; x1[2] = Px[idx]; y1[2] = Py[idx]; s1[2] = start_scalars[idx]; rem[2] = counts256[idx]; }
    { const uint64_t idx = gid*4 + 3; x1[3] = Px[idx]; y1[3] = Py[idx]; s1[3] = start_scalars[idx]; rem[3] = counts256[idx]; }
	
	if ((rem[0]|rem[1]|rem[2]|rem[3]) == 0ull) return;
	
	// The mask handed to a warp intrinsic has to name exactly the lanes that reach it: CUDA requires
	// every NON-EXITED thread named in a mask to execute the same intrinsic with the same mask, and
	// on Volta+ a mask naming a live thread that never arrives can stall the warp waiting for it.
	//
	// The old code captured one __activemask() at the top of the kernel and reused it for every
	// __any_sync/__syncwarp below. That breaks at the LOOP EXIT: rem is per-thread, and PrepareHost
	// gives the first r1 threads one extra batch (GpuPuzzle.cpp:455), so on the final launch a lane
	// whose warp straddles that boundary falls out of this loop one iteration before its neighbours.
	// It is still LIVE -- it goes on to the write-back at the bottom of the kernel -- yet it stayed
	// named in the captured mask and never arrived at the matching __any_sync.
	//
	// The other exits are fine and are deliberately left as they are: the rem==0 return above and
	// the found-path returns inside the loop leave the kernel entirely, and exited threads are
	// exempt from the rule. Only the loop exit produces a live absentee.
	//
	// The fix is the per-iteration __ballot_sync below, NOT the seed: every arriving lane votes, and
	// the result names precisely the lanes that enter the body -- precisely the set that reaches the
	// __any_sync calls. One ballot per batch is nothing against B keys' worth of hashing.
	//
	// Seed 0xFFFFFFFFu rather than __activemask(). Every lane of the warp either reaches the first
	// ballot or has already EXITED at :40 / :44 / :62, and exited threads named in a mask are exempt,
	// so the full mask is legal; __ballot_sync sets a bit only for a lane that is both active and
	// voted true, so the seed self-corrects on iteration 0. It is also deterministic, which
	// __activemask() is not: taken here it would be an instantaneous snapshot immediately after the
	// rem==0 return -- the kernel's first per-thread divergent branch -- and the CUDA guide states
	// outright that __activemask() cannot be used to determine which lanes execute a given branch.
	// Two lanes observing different snapshots would then enter __ballot_sync with mismatched masks,
	// which is undefined on its own. (Naming all 32 lanes is safe because blockDim.x is always a
	// multiple of 32: GetThreadsPerBlock only ever returns THREADS_PER_BLOCK=256,
	// MIN_THREADS_PER_BLOCK=32, or prop.maxThreadsPerBlock -- GpuPuzzle.cpp:283-288, Defs.h:15-16.)
	unsigned mask = 0xFFFFFFFFu;
	uint32_t batches_done = 0;
	while (true) {
		const bool live = (batches_done < batches_per_launch) && ge256_u64(rem, (uint64_t)B);
		mask = __ballot_sync(mask, live);
		if (!live) break;

		uint8_t prefix = (uint8_t)(y1[0] & 1ULL) ? 0x03 : 0x02;
		uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(x1));   // by-value ABI: 1 reg out
		
        bool pref = (hw2 == target_prefix);
		if (__any_sync(mask, pref)) {
			bool full = pref && hash160_full_match(prefix, u256_of(x1), c_target_words);
			if (full) {
				publish_found(find_result, s1);
			}
			
			if (__any_sync(mask, full)) { __syncwarp(mask); WARP_FLUSH_HASHES(); return; }
		}
		
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
		sub_mod((uint64_t*)inverse, &c_Gx[0], x1);      // d0 = c_Gx[0] - x1, straight into inverse[0..3]
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

				uint8_t odd;
				sub_mod_is_odd(&odd, s, y1);

				uint8_t prefix = odd ? 0x03 : 0x02;
				uint32_t hw2 = getHash160_w2_from_limbs(prefix, u256_of(px3));   // by-value ABI: 1 reg out
				bool pref = (hw2 == target_prefix);
				if (__any_sync(mask, pref)) {
					bool full = pref && hash160_full_match(prefix, u256_of(px3), c_target_words);
					if (full) {
						// In registers, not in the mapped struct: the old form did the add as a
						// read-modify-write straight over PCIe.
						uint64_t hit[4];
						Copy_u64_x4(hit, s1);
						add256_u64(hit, (uint64_t)i + 1ull);
						publish_found(find_result, hit);
					}
					
					if (__any_sync(mask, full)) { __syncwarp(mask); WARP_FLUSH_HASHES(); return; }
				}
				
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

				uint8_t odd;
				sub_mod_is_odd(&odd, s, y1);

				uint8_t prefix = odd ? 0x03 : 0x02;
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
					
					if (__any_sync(mask, full)) { __syncwarp(mask); WARP_FLUSH_HASHES(); return; }
				}
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

			uint8_t odd;
			sub_mod_is_odd(&odd, s, y1);

			uint8_t prefix = odd ? 0x03 : 0x02;
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
				
				if (__any_sync(mask, full)) { __syncwarp(mask); WARP_FLUSH_HASHES(); return; }
			}

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

// Returns cudaSuccess when the launch was ACCEPTED -- not when the kernel finished.
//
// Both paths need this and neither gets it for free. A rejected launch enqueues
// nothing, so the cudaStreamSynchronize in Execute() then waits on an empty stream
// and returns cudaSuccess: the run loop counts launches that never happened and the
// program exits 2, "Range exhausted: key not found", having computed nothing.
//
//  - native: cuLaunchKernel returns its status directly and never touches the
//    runtime's error slot.
//  - runtime: <<<>>> expands to cudaLaunchKernel and DISCARDS its return. Synchronous
//    rejections -- cudaErrorNoKernelImageForDevice (i.e. H12, on any card that is not
//    sm_120), cudaErrorLaunchOutOfResources, cudaErrorInvalidConfiguration, and the
//    local-memory allocation failure TestKernel's 16 KB frame invites -- are left in
//    the per-thread last-error slot, which only cudaGetLastError reads. A synchronize
//    does NOT report them; it only reports failures of a kernel that actually started.
//    This is the same hole as the native path, through a different slot.
//
// The slot is drained immediately before the launch so the value read after it can
// only describe that launch. That is what keeps the H6 item-3 misattribution out --
// a stale error latched earlier in this thread cannot be reported as a launch
// failure if it is no longer there. GpuEc.cu's CallGpuMulKernel already uses the
// launch-then-cudaGetLastError half of this pattern, and PrepareCuda the drain half.
cudaError_t CallGpuKernel(TKparams& Kparams, cudaStream_t cudaStream) {
#if USE_NATIVE_CUBIN
	TCubinCall* cc = NativeCubin();
	if (!cc)
		return cudaErrorInitializationError;

	// One entry per declared parameter; cuLaunchKernel reads exactly as many as the
	// signature has and copies each by that parameter's size.
	void* args[8] = {
		&Kparams.px,
		&Kparams.py,
		&Kparams.scalars,
		&Kparams.counts,
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
	p.kernel_arg_cnt = 8;
	if (!cc->CallKernel(p))
		return cudaErrorLaunchFailure;   // CallKernel has already printed the CUresult
	return cudaSuccess;
#else
	cudaGetLastError();   // drain, so the read below can only describe this launch

	TestKernel <<< Kparams.block_count, Kparams.block_size, 0, cudaStream >>> (
		Kparams.px,
		Kparams.py,
		Kparams.scalars,
		Kparams.counts,
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
	// cudaFuncSetCacheConfig would configure the runtime-linked TestKernel, which is
	// not the one being launched. DEVPLAN records PreferL1 as a verified non-win, so
	// there is nothing to reproduce against the cubin's function here.
	return cudaSuccess;
#else
	return cudaFuncSetCacheConfig(TestKernel, cudaFuncCachePreferL1);
#endif
}