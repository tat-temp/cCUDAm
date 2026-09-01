#include <iostream>
#include <cstring>
#include <thread> // Required for std::this_thread::sleep_for
#include <algorithm> // Required for std::min
#include <cuda_runtime.h>

#include "GpuPuzzle.h"
#include "Math.h"
#include "Utils.h"
#include "Ec.h"

#define BYTES_PER_THREAD (2ull * 4ull * sizeof(uint64_t) + (MAX_BATCH_SIZE / 2) * 4ull * sizeof(uint64_t))

#define ck(e, msg) { \
	cudaError_t _ck_e = (e); \
    if (_ck_e != cudaSuccess) { \
        std::cerr << msg << ": " << cudaGetErrorString(_ck_e) << "\n"; \
        goto LExit; \
    } \
}; \

cudaError_t CallGpuKernel(TKparams& Kparams, cudaStream_t cudaStream);
cudaError_t CudaSetupKernel();

cudaError_t CallGpuMulKernel(
	uint64_t blocks,
	uint64_t blockSize,
	const uint64_t* scalars,
	uint64_t* x,
	uint64_t* y,
	uint32_t count);
	
cudaError_t CudaCopyTargetWords(const void* value);
cudaError_t CudaCopyGx(const void* value, size_t size);
cudaError_t CudaCopyGy(const void* value, size_t size);
cudaError_t CudaCopyJx(const void* value);
cudaError_t CudaCopyJy(const void* value);

struct THparams {
	uint64_t*		counts;
	uint64_t*		scalars;
	TFindResult*	find_result;
	const uint64_t* gx;
	const uint64_t* gy;
	uint64_t		bx[4];
	uint64_t		by[4];
	const uint8_t* 	hash160;
};

uint64_t GetThreadsPerBlock(cudaDeviceProp* prop);
uint64_t GetMaxThreadsByMem(cudaDeviceProp* prop);
uint64_t GetUserMaxThreads(cudaDeviceProp* prop, uint64_t threadsPerBlock, uint64_t userBlocksPerSm);
uint64_t GetMinThreads(cudaDeviceProp* prop, uint64_t threadsPerBlock);
uint64_t GetThreadsCount(cudaDeviceProp* prop, uint64_t threadsPerBlock, const uint64_t* range, uint64_t userBlocksPerSm, uint64_t batchSize, uint64_t slises);
void CalcEffectiveBatchSize(uint64_t threadsPerBlock, const uint64_t* range, uint64_t totalThreads, uint64_t* effectiveBatchSize, uint64_t* effectiveSlises);
void ClearHParams(THparams* hParams);
void ClearKParams(TKparams* kParams);
bool PrepareHost(THparams* hParams, const uint64_t* start, const uint8_t* hash160, const uint64_t* range, uint64_t threadsTotal, uint64_t batchSize);
bool PrepareCuda(TKparams* kParams, const THparams* hParams, uint64_t threadsTotal, uint64_t threadsPerBlock, uint64_t batchSize);
void DumpFound(int gpuIndex, TKparams* kParams);

bool GpuPuzzle::Start() {
	
	return true;
}

void GpuPuzzle::Release() {
	ClearKParams(&Kparams);

#ifndef NO_GPU_MODE	
	if (m_cudaStream) cudaStreamDestroy(m_cudaStream);
	m_cudaStream = nullptr;
#endif
}

bool GpuPuzzle::Prepare(const uint64_t* pStart, const uint64_t* pRange, const uint8_t* pHash, const uint64_t* gx, const uint64_t* gy, uint64_t batchSize, uint64_t maxUserBlockPerSm, uint32_t dwSlices) {
	THparams hParams = {0};
	bool result = false;
	cudaDeviceProp prop{};
	uint64_t threadsPerBlock;
	uint64_t threadsTotal;
	uint64_t effectiveBatchSize;
	uint64_t effectiveSlises;
	uint64_t runsTotal[4] = {0};
	uint64_t remRunsTotal;

    std::memset(m_speed_stat, 0, sizeof(m_speed_stat));
    std::memset(&this->Kparams, 0, sizeof(TKparams));

	std::cout << "=======================================\r\n";
	std::cout << std::left << std::setw(20) << " Device (GPU)       " << " : " << CudaIndex << "\r\n";
	std::cout << "============== Input ==================\r\n";
	std::cout << std::left << std::setw(20) << " Points/Batch       " << " : " << batchSize << "\r\n";
	std::cout << std::left << std::setw(20) << " Slices             " << " : " << dwSlices << "\r\n";
	std::cout << std::left << std::setw(20) << " Blocks/SM (max)    " << " : " << maxUserBlockPerSm << "\r\n";	

#ifndef NO_GPU_MODE	
	ck(cudaGetDeviceProperties(&prop, CudaIndex), "CUDA init error");
	
	ck(cudaSetDevice(CudaIndex), "cudaSetDevice failed");
	
	ck(cudaSetDeviceFlags(cudaDeviceMapHost | cudaDeviceScheduleBlockingSync), "set device flags");
	ck(cudaDeviceSetCacheConfig(cudaFuncCachePreferL1), "set cache config");	
#else
	prop.maxThreadsPerBlock = 1024;
	prop.totalGlobalMem = (uint64_t)32 * 1024 * 1024 * 1024;
	prop.multiProcessorCount = 170;
#endif

	effectiveBatchSize = batchSize;
	effectiveSlises = (uint64_t)dwSlices;

	threadsPerBlock = GetThreadsPerBlock(&prop);
	
	threadsTotal = GetThreadsCount(&prop, threadsPerBlock, pRange, maxUserBlockPerSm, effectiveBatchSize, effectiveSlises);
		
	CalcEffectiveBatchSize(threadsPerBlock, pRange, threadsTotal, &effectiveBatchSize, &effectiveSlises);

	if (threadsTotal == 0llu) {
		std::cerr << "Search interval is too small for the specified parameters.\r\n";
		goto LExit;
	}

	if (!PrepareHost(&hParams, pStart, pHash, pRange, threadsTotal, effectiveBatchSize)) {
		std::cerr << "Prepare Host data failed.\r\n";
		goto LExit;
	}

	hParams.gx = gx;
	hParams.gy = gy;

#ifndef NO_GPU_MODE
	if (!PrepareCuda(&this->Kparams, (const THparams*)&hParams, threadsTotal, threadsPerBlock, effectiveBatchSize)) {
		std::cerr << "Prepare CUDA data failed.\r\n";
		goto LExit;
	}
#else
	Kparams.h_find_result = hParams.find_result;
#endif

	// The pinned result page now belongs to Kparams: the ClearHParams at LExit must not free a page
	// Kparams still points at. Paths reaching LExit before this point still own it there.
	hParams.find_result = nullptr;

	Kparams.block_count = threadsTotal / threadsPerBlock;
	Kparams.block_size = threadsPerBlock;
	Kparams.points_per_run = effectiveBatchSize * threadsTotal * effectiveSlises;
	Kparams.batch_size = effectiveBatchSize;
	Kparams.batches_per_launch = effectiveSlises;
	Kparams.threads_total = threadsTotal;

	div_256_u64(pRange, Kparams.points_per_run, runsTotal, &remRunsTotal);
	if (remRunsTotal) {
		add_256_u64(runsTotal, 1ull, runsTotal);
	}
	if (runsTotal[1] | runsTotal[2] | runsTotal[3]) {
		std::cerr << "Runs total exceeds u64 value.\r\n";
		goto LExit;
	}
	Kparams.runs_total = runsTotal[0];

	std::cout << "============ Calculated ===============\r\n";
	std::cout << std::left << std::setw(20) << " Points/Batch       " << " : " << Kparams.batch_size << "\r\n";
	std::cout << std::left << std::setw(20) << " Slices             " << " : " << Kparams.batches_per_launch << "\r\n";
	std::cout << std::left << std::setw(20) << " Blocks/SM          " << " : " << Kparams.block_count / prop.multiProcessorCount << "\r\n";	
	std::cout << std::left << std::setw(20) << " Threads/Block      " << " : " << Kparams.block_size << "\r\n";
	std::cout << std::left << std::setw(20) << " Blocks             " << " : " << Kparams.block_count << "\r\n";
	std::cout << std::left << std::setw(20) << " Threads            " << " : " << Kparams.threads_total << "\r\n";	
	std::cout << std::left << std::setw(20) << " Points/run         " << " : " << Kparams.points_per_run <<  "\r\n";
	std::cout << std::left << std::setw(20) << " Runs               " << " : " << Kparams.runs_total <<  "\r\n";

	ck(cudaStreamCreateWithFlags(&m_cudaStream, cudaStreamNonBlocking), "create stream");
	
	result = true;
	
LExit:

	ClearHParams(&hParams);
	
	if (!result) {
		ClearKParams(&Kparams);
	}

	return result;
}

void GpuPuzzle::Execute() {
	cudaError_t err;
	uint64_t pnt_cnt;
	uint64_t runs_done = 0ull;;
	uint64_t runs_total = 0ull;;

	Failed = false;

#ifndef NO_GPU_MODE
	err = cudaSetDevice(CudaIndex);
	if (err != cudaSuccess) {
		std::cerr << "GPU " << CudaIndex << ": cudaSetDevice failed: "
		          << cudaGetErrorString(err) << "\r\n";
		Failed = true;
		return;
	}
#endif

	if (!Start()) {
		Failed = true;
		return;
	}

	pnt_cnt = Kparams.points_per_run;
	runs_total = Kparams.runs_total;

	while (!m_stopFlag && runs_done < runs_total) {
		u64 t1 = GetTickCount64();

#ifndef NO_GPU_MODE	
		err = CallGpuKernel(Kparams, m_cudaStream);
		if (err != cudaSuccess) {
			// Not ck(): a REJECTED launch enqueues nothing, so the synchronize below would wait on an
			// empty stream, succeed, and count the run as scanned. Covers both paths (cuLaunchKernel's
			// status, and the last-error slot no synchronize reads). H12: first launch on a non-sm_120 card.
			std::cerr << "GPU " << CudaIndex << ": kernel launch failed: "
			          << cudaGetErrorString(err) << "\r\n";
			Failed = true;
			goto LExit;
		}

		err = cudaStreamSynchronize(m_cudaStream);
		if (err != cudaSuccess) {
			// Not ck(): that macro cannot set Failed. A kernel that dies here (Xid, ECC, illegal
			// address) must not be reported as a completed scan.
			std::cerr << "GPU " << CudaIndex << ": kernel execution failed: "
			          << cudaGetErrorString(err) << "\r\n";
			Failed = true;
			goto LExit;
		}
#else
		std::this_thread::sleep_for(std::chrono::milliseconds(11));
#endif

		runs_done++;

		{
			u64 t2 = GetTickCount64();
			u64 tm = t2 - t1;
			if (!tm) tm = 1;
			
			uint64_t cur_speed = (uint64_t)(pnt_cnt / (1000 * tm));

			m_speed_stat[m_stat_idx] = cur_speed;
			m_stat_idx = (m_stat_idx + 1) % STATS_WND_SIZE;
		}
	
		// Plain read is safe only because cudaStreamSynchronize already ordered the kernel writes. A
		// poll DURING a launch must use a volatile TFindResult*, or the compiler hoists the load of `found`.
		if (Kparams.h_find_result->found != 0u) {
			Found = true;
			
			DumpFound(CudaIndex, &Kparams);
			
			break;
		}
		
		
	}
LExit:

	Release();
}

void GpuPuzzle::Stop() {
	m_stopFlag = true;
}

uint64_t GpuPuzzle::GetStatsSpeed() {
	uint64_t res = m_speed_stat[0];
	uint64_t cnt = 1;
	
	for (int i = 1; i < STATS_WND_SIZE; i++) {
		uint64_t tmp = m_speed_stat[i];
		if (tmp) {
			res += tmp;
			cnt++;
		}
	}
	return res / cnt;
}

uint64_t GetThreadsPerBlock(cudaDeviceProp* prop) {
	int threadsPerBlock = THREADS_PER_BLOCK;
    if (threadsPerBlock > (int)prop->maxThreadsPerBlock) threadsPerBlock = prop->maxThreadsPerBlock;
    if (threadsPerBlock < 32) threadsPerBlock = MIN_THREADS_PER_BLOCK;
	return (uint64_t)threadsPerBlock;
}

uint64_t GetMaxThreadsByMem(cudaDeviceProp* prop) {
	const uint64_t bytesPerThread = BYTES_PER_THREAD;
    size_t totalGlobalMem = prop->totalGlobalMem;
    const uint64_t reserveBytes = 64ull * 1024 * 1024;
    uint64_t usableMem = (totalGlobalMem > reserveBytes) ? (totalGlobalMem - reserveBytes) : (totalGlobalMem / 2);
    uint64_t maxThreadsByMem = usableMem / bytesPerThread;
	return maxThreadsByMem - (maxThreadsByMem % prop->multiProcessorCount);
}

uint64_t GetUserMaxThreads(cudaDeviceProp* prop, uint64_t threadsPerBlock, uint64_t userBlocksPerSm) {
	return prop->multiProcessorCount * userBlocksPerSm * threadsPerBlock;
}

uint64_t GetMinThreads(cudaDeviceProp* prop, uint64_t threadsPerBlock) {
	return prop->multiProcessorCount * threadsPerBlock * BLOCKS_PER_SM;
}

uint64_t GetThreadsCount(cudaDeviceProp* prop, uint64_t threadsPerBlock, const uint64_t* range, uint64_t userBlocksPerSm, uint64_t batchSize, uint64_t slises) {
	uint64_t result = 0ull;
	uint64_t maxThreadsByMem;
	uint64_t maxThreadsByUser;
	uint64_t minThreads;
	uint64_t maxThreadsByRange[4] = {0};
	uint64_t remMaxThreadsByRange = 0ull;

	maxThreadsByMem = GetMaxThreadsByMem(prop);
	
	maxThreadsByUser = GetUserMaxThreads(prop, threadsPerBlock, userBlocksPerSm);
	
	minThreads = GetMinThreads(prop, threadsPerBlock);
	
    div_256_u64(range, (uint64_t)batchSize * slises, maxThreadsByRange, &remMaxThreadsByRange);
	if (remMaxThreadsByRange) {
		add_256_u64(maxThreadsByRange, (uint64_t)1, maxThreadsByRange);
	}
	
	result = std::min(maxThreadsByMem, maxThreadsByUser);
	
	if (!(maxThreadsByRange[1] | maxThreadsByRange[2] | maxThreadsByRange[3])) {
		result = std::min(maxThreadsByRange[0], result);
	}
	
	result = std::max(result, minThreads);

	// block_count = threadsTotal / threadsPerBlock truncates, so leftover threads still get a
	// sub-range and start point in PrepareHost but are never launched -- their keys are silently
	// skipped. Round DOWN: rounding up could exceed the memory budget or the user's blocks/SM cap.
	result -= result % threadsPerBlock;

	return result;
}

void CalcEffectiveBatchSize(uint64_t threadsPerBlock, const uint64_t* range, uint64_t totalThreads, uint64_t* effectiveBatchSize, uint64_t* effectiveSlises) {
	uint64_t threadRangeSize[4] = {0};
	uint64_t remThreadRangeSize = 0ull;
	uint64_t userThreadRangeSize[4] = {0};
	uint64_t tmp[4] = {0};
	
	div_256_u64(range, totalThreads, threadRangeSize, &remThreadRangeSize);
	if (remThreadRangeSize) {
		add_256_u64(threadRangeSize, (uint64_t)1, threadRangeSize);
	}
	
	userThreadRangeSize[0] = (*effectiveBatchSize) * (*effectiveSlises);
	
	while (sub_256(threadRangeSize, userThreadRangeSize, tmp)) {
		if ((*effectiveSlises) > 1) (*effectiveSlises)--;
		else {
			if ((*effectiveBatchSize) > 3) *effectiveBatchSize = (*effectiveBatchSize) - 2;
			else break;
		}
		
		userThreadRangeSize[0] = (*effectiveBatchSize) * (*effectiveSlises);
	} 
	
}

// The two deallocators are not interchangeable and the mistake is silent: cudaFree on a cudaHostAlloc
// pointer fails with cudaErrorInvalidValue and frees nothing, and the error then sits in this thread's
// last-error slot until PrepareCuda's post-launch check blames the NEXT GPU. So: name it, drain the slot.
static void free_host_pinned(void* p, const char* what) {
	if (!p) return;
#ifndef NO_GPU_MODE
	cudaError_t e = cudaFreeHost(p);
	if (e != cudaSuccess) {
		std::cerr << "cudaFreeHost(" << what << ") failed: " << cudaGetErrorString(e) << "\r\n";
		cudaGetLastError();
	}
#else
	(void)what;
	free(p);
#endif
}

static void free_device(void* p, const char* what) {
	if (!p) return;
#ifndef NO_GPU_MODE
	cudaError_t e = cudaFree(p);
	if (e != cudaSuccess) {
		std::cerr << "cudaFree(" << what << ") failed: " << cudaGetErrorString(e) << "\r\n";
		cudaGetLastError();
	}
#else
	(void)p; (void)what;	// NO_GPU_MODE never reaches PrepareCuda
#endif
}

void ClearHParams(THparams* hParams) {
	free_host_pinned(hParams->counts, "counts");
	free_host_pinned(hParams->scalars, "scalars");
	// find_result belongs here only until PrepareCuda takes it (Prepare nulls the field at the
	// handoff); without this line a failure inside that window orphans the page outright.
	free_host_pinned(hParams->find_result, "find_result");

	hParams->counts = nullptr;
	hParams->scalars = nullptr;
	hParams->find_result = nullptr;
}

void ClearKParams(TKparams* kParams) {
	free_device(kParams->counts, "d_counts");
	free_device(kParams->scalars, "d_start_scalars");
	free_device(kParams->px, "d_Px");
	free_device(kParams->py, "d_Py");
	// h_find_result came from cudaHostAlloc, so it takes cudaFreeHost. d_find_result is only the
	// device-side alias of that same mapped page -- an address, not an allocation -- never free it.
	free_host_pinned(kParams->h_find_result, "h_find_result");

	kParams->counts = nullptr;
	kParams->scalars = nullptr;
	kParams->px = nullptr;
	kParams->py = nullptr;
	kParams->h_find_result = nullptr;
	kParams->d_find_result = nullptr;
}

bool PrepareHost(THparams* hParams, const uint64_t* start, const uint8_t* hash160, const uint64_t* range, uint64_t threadsTotal, uint64_t batchSize) {
	uint64_t per_thread_cnt[4];
	uint64_t batch_cnt[4];
	uint64_t r1 = 0ull;
	uint64_t rem_batch = 0ull;
	uint64_t* h_counts256     	= nullptr;
    uint64_t* h_start_scalars 	= nullptr;
	TFindResult* h_find_result	= nullptr;
	uint32_t half;
	bool result = false;

	// Distribute whole BATCHES, not raw keys: the kernel consumes exactly batchSize keys per
	// iteration and stops as soon as fewer remain (GpuCore.cu:65), so a per-thread count that is
	// not a multiple of batchSize leaves its remainder permanently unscanned. Rounding the batch
	// total up over-scans by at most batchSize-1 keys, which is harmless; a short tail is not.
	// r1 counts the threads that get one EXTRA batch.
	div_256_u64(range, batchSize, batch_cnt, &rem_batch);
	if (rem_batch) {
		add_256_u64((const uint64_t*)&batch_cnt, 1ull, (uint64_t*)&batch_cnt);
	}
	div_256_u64((const uint64_t*)&batch_cnt, threadsTotal, per_thread_cnt, &r1);
	mul_256_u64((const uint64_t*)&per_thread_cnt, batchSize, (uint64_t*)&per_thread_cnt);

#ifndef NO_GPU_MODE
    ck(cudaHostAlloc(&h_counts256,     threadsTotal * 4 * sizeof(uint64_t), cudaHostAllocWriteCombined | cudaHostAllocMapped), "h_counts256 alloc");
    ck(cudaHostAlloc(&h_start_scalars, threadsTotal * 4 * sizeof(uint64_t), cudaHostAllocWriteCombined | cudaHostAllocMapped), "h_start_scalars alloc");
    ck(cudaHostAlloc(&h_find_result,   sizeof(TFindResult), cudaHostAllocMapped), "h_found_scalar alloc");
#else
    h_counts256 = (uint64_t*)malloc(threadsTotal * 4 * sizeof(uint64_t));
    h_start_scalars = (uint64_t*)malloc(threadsTotal * 4 * sizeof(uint64_t));
    h_find_result = (TFindResult*)malloc(sizeof(TFindResult));
#endif

	{
		for (uint64_t i = 0; i < threadsTotal; ++i) {
			h_counts256[i*4+0] = per_thread_cnt[0];
			h_counts256[i*4+1] = per_thread_cnt[1];
			h_counts256[i*4+2] = per_thread_cnt[2];
			h_counts256[i*4+3] = per_thread_cnt[3];
			
			if (i < r1) {
				add_256_u64((const uint64_t*)&h_counts256[i*4], batchSize, (uint64_t*)&h_counts256[i*4]);
			}
		}
	}

	half = (uint32_t)batchSize >> 1;
    {
        uint64_t cur[4] = { start[0], start[1], start[2], start[3] };
		
        for (uint64_t i = 0; i < threadsTotal; ++i) {
            uint64_t scalar_effective[4]; add_256_u64((const uint64_t*)&cur, (uint64_t)half, (uint64_t*)&scalar_effective); 
            h_start_scalars[i*4+0] = scalar_effective[0];
            h_start_scalars[i*4+1] = scalar_effective[1];
            h_start_scalars[i*4+2] = scalar_effective[2];
            h_start_scalars[i*4+3] = scalar_effective[3];

            uint64_t next[4];
			add_256((const uint64_t*)&cur, (const uint64_t*)&per_thread_cnt, (uint64_t*)&next);
			if (i < r1) {
				add_256_u64((const uint64_t*)&next, batchSize, (uint64_t*)&next);
			}

            cur[0]=next[0]; cur[1]=next[1]; cur[2]=next[2]; cur[3]=next[3];
        }
    }

/*
	// p(x,y)
	{
		EcPoint p;
		EcInt k;

		for (uint64_t i = 0; i < threadsTotal; ++i) {
			k.LoadFromBuffer32((uint8_t*)&h_start_scalars[i*4]);
			p = Ec::MultiplyG(k);

			h_px[i*4+0] = p.x.data[0];
			h_px[i*4+1] = p.x.data[1];
			h_px[i*4+2] = p.x.data[2];
			h_px[i*4+3] = p.x.data[3];

			h_py[i*4+0] = p.y.data[0];
			h_py[i*4+1] = p.y.data[1];
			h_py[i*4+2] = p.y.data[2];
			h_py[i*4+3] = p.y.data[3];
		}
	}
*/

	{
		EcPoint p;
		EcInt k;
		
		k.Set((u64)batchSize);
		p = Ec::MultiplyG(k);

		std::memcpy(&hParams->bx, p.x.data, 32);
		std::memcpy(&hParams->by, p.y.data, 32);
	}

    {
		std::memset(h_find_result, 0, sizeof(TFindResult));
	}

	hParams->counts = h_counts256;
	hParams->scalars = h_start_scalars;
	hParams->find_result = h_find_result;
	hParams->hash160 = hash160;
	
	result = true;
	
LExit:	

	if (!result) {
		free_host_pinned(h_counts256, "h_counts256");
		free_host_pinned(h_start_scalars, "h_start_scalars");
		free_host_pinned(h_find_result, "h_find_result");
	}

	return result;
}

bool PrepareCuda(TKparams* kParams, const THparams* hParams, uint64_t threadsTotal, uint64_t threadsPerBlock, uint64_t batchSize) {
	bool result = false;
	uint64_t* d_start_scalars = nullptr;
	uint64_t* d_Px = nullptr;
	uint64_t* d_Py = nullptr;
	uint64_t* d_counts = nullptr;
	TFindResult *d_find_result = nullptr;
	
	ck(cudaMalloc(&d_start_scalars, threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_start_scalars)");
	ck(cudaMalloc(&d_counts,        threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_counts)");
	ck(cudaMalloc(&d_Px,            threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_Px)");
    ck(cudaMalloc(&d_Py,            threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_Py)");

	ck(cudaHostGetDevicePointer((void**)&d_find_result, hParams->find_result, 0), "cudaHostGetDevicePointer(find_result)");

    ck(cudaMemcpy(d_start_scalars, 	hParams->scalars, 	threadsTotal * 4 * sizeof(uint64_t), cudaMemcpyHostToDevice), "cpy scalars");
    ck(cudaMemcpy(d_counts,        	hParams->counts,  	threadsTotal * 4 * sizeof(uint64_t), cudaMemcpyHostToDevice), "cpy counts");

	{
		uint64_t mulBlocks = (uint64_t)((threadsTotal + threadsPerBlock - 1) / threadsPerBlock);;

		// The last-error slot is per host thread and sticky: only cudaGetLastError clears it. Prepare
		// runs for every GPU on this thread, so without this the check below blames THIS setup kernel
		// for whatever failed most recently anywhere -- including the previous GPU's cleanup.
		cudaGetLastError();

		ck(CallGpuMulKernel(mulBlocks, threadsPerBlock, d_start_scalars, d_Px, d_Py, (uint32_t)threadsTotal), "GpuMulKernel call");

		ck(cudaDeviceSynchronize(), "gpuMulKernel sync");
        ck(cudaGetLastError(), "gpuMulKernel launch");
	}

	{
        uint32_t target_words[5];
        target_words[0] = (uint32_t)hParams->hash160[ 0] | ((uint32_t)hParams->hash160[ 1] << 8) | ((uint32_t)hParams->hash160[ 2] << 16) | ((uint32_t)hParams->hash160[ 3] << 24);
        target_words[1] = (uint32_t)hParams->hash160[ 4] | ((uint32_t)hParams->hash160[ 5] << 8) | ((uint32_t)hParams->hash160[ 6] << 16) | ((uint32_t)hParams->hash160[ 7] << 24);
        target_words[2] = (uint32_t)hParams->hash160[ 8] | ((uint32_t)hParams->hash160[ 9] << 8) | ((uint32_t)hParams->hash160[10] << 16) | ((uint32_t)hParams->hash160[11] << 24);
        target_words[3] = (uint32_t)hParams->hash160[12] | ((uint32_t)hParams->hash160[13] << 8) | ((uint32_t)hParams->hash160[14] << 16) | ((uint32_t)hParams->hash160[15] << 24);
        target_words[4] = (uint32_t)hParams->hash160[16] | ((uint32_t)hParams->hash160[17] << 8) | ((uint32_t)hParams->hash160[18] << 16) | ((uint32_t)hParams->hash160[19] << 24);
		ck(CudaCopyTargetWords(&target_words), "ToSymbol c_target_words");
    }
	ck(CudaCopyGx(hParams->gx, (batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gx");
	ck(CudaCopyGy(hParams->gy, (batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gy");
	ck(CudaCopyJx(&hParams->bx), "ToSymbol c_Jx");
	ck(CudaCopyJy(&hParams->by), "ToSymbol c_Jy");
	
	ck(CudaSetupKernel(), "setup MainKernel");

	kParams->scalars = d_start_scalars;
	kParams->counts = d_counts;
	kParams->d_find_result = d_find_result;
	kParams->h_find_result = hParams->find_result;
	kParams->px = d_Px;
	kParams->py = d_Py;

	result = true;
	
LExit:	

	if (!result) {
		// Only the four cudaMalloc'd buffers; d_find_result is the caller's mapped page, freed there.
		free_device(d_counts, "d_counts");
		free_device(d_start_scalars, "d_start_scalars");
		free_device(d_Px, "d_Px");
		free_device(d_Py, "d_Py");
	}

	return result;
}

void DumpFound(int gpuIndex, TKparams* kParams) {
	if (!kParams || !kParams->h_find_result || kParams->h_find_result->found == 0u) return;
	
	EcPoint p;
	EcInt k;
		
	k.LoadFromBuffer64((u64*)&kParams->h_find_result->scalar);
	p = Ec::MultiplyG(k);
	
	std::cout << "\r\n======== FOUND MATCH! =================================\r\n";
	std::cout << std::left << std::setw(20) << " Device (GPU)       " << " : " << gpuIndex << "\r\n";
	std::cout << std::left << std::setw(20) << " Private Key        " << " : " << formatHex256((const uint64_t*)&kParams->h_find_result->scalar) << "\r\n";
	std::cout << std::left << std::setw(20) << " Public Key         " << " : " << formatCompressedPubHex((const uint64_t*)&p.x.data, (const uint64_t*)&p.y.data) << "\r\n";
	
}
