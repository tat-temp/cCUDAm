#include <iostream>
#include <cstring>
#include <cinttypes> // Required for PRIu64
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

void CallGpuKernel(TKparams& Kparams, cudaStream_t cudaStream);
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

	//cudaDeviceSetCacheConfig(cudaFuncCachePreferL1);
	threadsPerBlock = GetThreadsPerBlock(&prop);
	//printf("threadsPerBlock: %llu\r\n", (unsigned long long)threadsPerBlock);
	
	threadsTotal = GetThreadsCount(&prop, threadsPerBlock, pRange, maxUserBlockPerSm, effectiveBatchSize, effectiveSlises);
		
	CalcEffectiveBatchSize(threadsPerBlock, pRange, threadsTotal, &effectiveBatchSize, &effectiveSlises);

#if DEBUG_MODE > 0
	std::cout << "GPU " << CudaIndex << ": Threads/Block: " << threadsPerBlock << " Total threads: " << threadsTotal << "\r\n";
#endif

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
		CallGpuKernel(Kparams, m_cudaStream);
		err = cudaStreamSynchronize(m_cudaStream);
		if (err != cudaSuccess) {
			// Not ck(): that macro only prints and jumps, and it cannot set Failed because the
			// same macro is used by free functions with no such member. A kernel that dies here
			// (Xid, ECC, illegal address) must not be reported as a completed scan.
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
			//printf("GPU %d kernel time %d ms, speed %d MH\r\n", CudaIndex, (int)tm, cur_speed);
			//std::cout << "GPU " << CudaIndex << " kernel time " << tm << " ms, speed " << cur_speed << " MH Idx: " << m_stat_idx << "\r\n";

			m_speed_stat[m_stat_idx] = cur_speed;
			m_stat_idx = (m_stat_idx + 1) % STATS_WND_SIZE;
		}
	
		if (Kparams.h_find_result->found == true) {
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
    //printf("maxThreadsByMem: %llu\r\n", (unsigned long long)maxThreadsByMem);
	
	maxThreadsByUser = GetUserMaxThreads(prop, threadsPerBlock, userBlocksPerSm);
	//printf("maxThreadsByUser: %llu\r\n", (unsigned long long)maxThreadsByUser);
	
	minThreads = GetMinThreads(prop, threadsPerBlock);
	//printf("minThreads: %llu\r\n", (unsigned long long)minThreads);
	
	// max threads required
    div_256_u64(range, (uint64_t)batchSize * slises, maxThreadsByRange, &remMaxThreadsByRange);
	if (remMaxThreadsByRange) {
		add_256_u64(maxThreadsByRange, (uint64_t)1, maxThreadsByRange);
	}
	
	result = std::min(maxThreadsByMem, maxThreadsByUser);
	//printf("result (0): %llu\r\n", (unsigned long long)result);
	
	if (!(maxThreadsByRange[1] | maxThreadsByRange[2] | maxThreadsByRange[3])) {
		////printf("result (1): %llu\r\n", (unsigned long long)maxThreadsByRange[0]);
		//uint64_t roundedBlock = (maxThreadsByRange[0] + (prop->multiProcessorCount * BLOCKS_PER_SM) - 1) / (prop->multiProcessorCount * BLOCKS_PER_SM);
		////printf("result (2): %llu\r\n", (unsigned long long)roundedBlock);
		//result = std::min(roundedBlock * (prop->multiProcessorCount * BLOCKS_PER_SM), result);
		////printf("result (3): %llu\r\n", (unsigned long long)result);
		result = std::min(maxThreadsByRange[0], result);
	}
	
	result = std::max(result, minThreads);
	//printf("result (4): %llu\r\n", (unsigned long long)result);

	// The caller derives block_count = threadsTotal / threadsPerBlock with a truncating divide,
	// so anything left over here is a set of threads that gets a sub-range and a start point in
	// PrepareHost and is then never launched -- its keys are silently skipped. maxThreadsByUser
	// and minThreads are multiples of threadsPerBlock by construction; maxThreadsByMem and
	// maxThreadsByRange are arbitrary quotients, so the alignment has to happen here, after the
	// last clamp. Round DOWN: rounding up could exceed the memory budget or the user's
	// blocks/SM cap. Dropping up to threadsPerBlock-1 threads costs no coverage, because
	// PrepareHost divides the range by whatever count it is given. minThreads is at least
	// 2 * threadsPerBlock, so at least one full block always survives.
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

void ClearHParams(THparams* hParams) {
#ifndef NO_GPU_MODE
	if (hParams->counts) cudaFreeHost(hParams->counts);
	if (hParams->scalars) cudaFreeHost(hParams->scalars);
	//if (hParams->px) cudaFreeHost(hParams->px);
	//if (hParams->py) cudaFreeHost(hParams->py);
#else
	if (hParams->counts) free(hParams->counts);
	if (hParams->scalars) free(hParams->scalars);
	//if (hParams->px) free(hParams->px);
	//if (hParams->py) free(hParams->py);
#endif
}

void ClearKParams(TKparams* kParams) {
#ifndef NO_GPU_MODE
	if (kParams->counts) cudaFree(kParams->counts);
	if (kParams->scalars) cudaFree(kParams->scalars);
	if (kParams->h_find_result) cudaFree(kParams->h_find_result);
	if (kParams->px) cudaFree(kParams->px);
	if (kParams->py) cudaFree(kParams->py);
#else
	if (kParams->h_find_result) free(kParams->h_find_result);
#endif
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

	// Distribute whole BATCHES, not raw keys. The kernel consumes exactly batchSize keys per
	// iteration and stops as soon as fewer than that remain (GpuCore.cu:65) -- there is no short
	// final pass -- so a per-thread count that is not a multiple of batchSize leaves its
	// remainder permanently unscanned. Rounding the batch total up costs at most batchSize-1
	// keys of over-scan past the end of the range, which is harmless; a short tail is not.
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

	// h_counts256
	{
#if DEBUG_MODE > 0
		std::cout << "\r\n---Points/thread---\r\n";
#endif
		for (uint64_t i = 0; i < threadsTotal; ++i) {
			h_counts256[i*4+0] = per_thread_cnt[0];
			h_counts256[i*4+1] = per_thread_cnt[1];
			h_counts256[i*4+2] = per_thread_cnt[2];
			h_counts256[i*4+3] = per_thread_cnt[3];
			
			if (i < r1) {
				add_256_u64((const uint64_t*)&h_counts256[i*4], batchSize, (uint64_t*)&h_counts256[i*4]);
			}
#if DEBUG_MODE > 0
			std::cout << "[%6" << i << "]: " << formatHex256(&h_counts256[i*4]) << "\r\n";
#endif
		}
	}

	// h_start_scalars
	half = (uint32_t)batchSize >> 1;
    {
#if DEBUG_MODE > 0
		std::cout << "\r\n---Start scalars---\r\n";
#endif

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
			
#if DEBUG_MODE > 0
			std::cout << "[%6" << i << "]: " << formatHex256(&h_start_scalars[i*4]) << "\r\n";
#endif
			
            cur[0]=next[0]; cur[1]=next[1]; cur[2]=next[2]; cur[3]=next[3];
        }
    }

/*	
	// p(x,y)
	{
#if DEBUG_MODE > 0
		std::cout << "\r\n---Start points---\r\n";
#endif

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
			
#if DEBUG_MODE > 0
			std::cout << "[%6" << i << "]: x:" << formatHex256(&h_px[i*4]) << "\r\n";
			std::cout << "[%6" << i << "]: y:" << formatHex256(&h_py[i*4]) << "\r\n";
#endif
		}
	}
*/
	
	// B pointer
	{
#if DEBUG_MODE > 0
		std::cout << "\r\n---B (batch size point)---\r\n";
#endif

		EcPoint p;
		EcInt k;
		
		k.Set((u64)batchSize);
		p = Ec::MultiplyG(k);

		std::memcpy(&hParams->bx, p.x.data, 32);
		std::memcpy(&hParams->by, p.y.data, 32);

#if DEBUG_MODE > 0
		std::cout << "x:" << formatHex256((const uint64_t*)&p.x.data) << "\r\n";
		std::cout << "y:" << formatHex256((const uint64_t*)&p.y.data) << "\r\n";
#endif

	}

	// find_result
    {
		std::memset(h_find_result, 0, sizeof(TFindResult));
	}

//#if DEBUG_MODE > 0
//	for (uint64_t i = 0; i < threadsTotal; ++i) {
//		printf("[%6" PRIu64 "]: threads: %s\r\n", i, formatHex256(&h_counts256[i*4]).c_str());
//		printf("[%6" PRIu64 "]: start:   %s\r\n", i, formatHex256(&h_start_scalars[i*4]).c_str());
//		printf("[%6" PRIu64 "]: x:       %s\r\n", i, formatHex256(&h_px[i*4]).c_str());
//		printf("[%6" PRIu64 "]: y:       %s\r\n", i, formatHex256(&h_py[i*4]).c_str());
//	}
//#endif
	
	hParams->counts = h_counts256;
	hParams->scalars = h_start_scalars;
	hParams->find_result = h_find_result;
	hParams->hash160 = hash160;
	
	result = true;
	
LExit:	

	if (!result) {
#ifndef NO_GPU_MODE		
		if (h_counts256) cudaFreeHost(h_counts256);
		if (h_start_scalars) cudaFreeHost(h_start_scalars);
		if (h_find_result) cudaFreeHost(h_find_result);
#else
		if (h_counts256) free(h_counts256);
		if (h_start_scalars) free(h_start_scalars);
		if (h_find_result) free(h_find_result);
#endif
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

	// Start points P(x1, y1)
	{
#if DEBUG_MODE > 0
		std::cout << "\r\n---Start points---\r\n";
#endif
		uint64_t mulBlocks = (uint64_t)((threadsTotal + threadsPerBlock - 1) / threadsPerBlock);;
		
		ck(CallGpuMulKernel(mulBlocks, threadsPerBlock, d_start_scalars, d_Px, d_Py, (uint32_t)threadsTotal), "GpuMulKernel call");

		ck(cudaDeviceSynchronize(), "gpuMulKernel sync");
        ck(cudaGetLastError(), "gpuMulKernel launch");
		
		for (uint64_t i = 0; i < threadsTotal; ++i) {
#if DEBUG_MODE > 0
			std::cout << "[%6" << i << "]: x:" << formatHex256(&d_Px[i*4]) << "\r\n";
			std::cout << "[%6" << i << "]: y:" << formatHex256(&d_Py[i*4]) << "\r\n";
#endif
		}
	}

	// c_target_words
	{
#if DEBUG_MODE > 0
		std::cout << "\r\n---Target hash (truncated)---\r\n" << formatHex256((uint64_t*)hParams->hash160) << "\r\n";
#endif
        uint32_t target_words[5];
        target_words[0] = (uint32_t)hParams->hash160[ 0] | ((uint32_t)hParams->hash160[ 1] << 8) | ((uint32_t)hParams->hash160[ 2] << 16) | ((uint32_t)hParams->hash160[ 3] << 24);
        target_words[1] = (uint32_t)hParams->hash160[ 4] | ((uint32_t)hParams->hash160[ 5] << 8) | ((uint32_t)hParams->hash160[ 6] << 16) | ((uint32_t)hParams->hash160[ 7] << 24);
        target_words[2] = (uint32_t)hParams->hash160[ 8] | ((uint32_t)hParams->hash160[ 9] << 8) | ((uint32_t)hParams->hash160[10] << 16) | ((uint32_t)hParams->hash160[11] << 24);
        target_words[3] = (uint32_t)hParams->hash160[12] | ((uint32_t)hParams->hash160[13] << 8) | ((uint32_t)hParams->hash160[14] << 16) | ((uint32_t)hParams->hash160[15] << 24);
        target_words[4] = (uint32_t)hParams->hash160[16] | ((uint32_t)hParams->hash160[17] << 8) | ((uint32_t)hParams->hash160[18] << 16) | ((uint32_t)hParams->hash160[19] << 24);
        //cudaMemcpyToSymbol(c_target_words, target_words, sizeof(target_words));
		ck(CudaCopyTargetWords(&target_words), "ToSymbol c_target_words");
    }
	//ck(cudaMemcpyToSymbol(c_Gx, 	hParams->gx, 		(batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gx");
	//ck(cudaMemcpyToSymbol(c_Gy, 	hParams->gy, 		(batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gy");
	//ck(cudaMemcpyToSymbol(c_Jx, 	hParams->bx, 		4 * sizeof(uint64_t)), "ToSymbol c_Jx");
	//ck(cudaMemcpyToSymbol(c_Jy, 	hParams->by, 		4 * sizeof(uint64_t)), "ToSymbol c_Jy");
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
		if (d_counts) cudaFree(d_counts);
		if (d_start_scalars) cudaFree(d_start_scalars);
		if (d_Px) cudaFree(d_Px);
		if (d_Py) cudaFree(d_Py);
	}

	return result;
}

void DumpFound(int gpuIndex, TKparams* kParams) {
	if (!kParams || !kParams->h_find_result || !kParams->h_find_result->found) return;
	
	EcPoint p;
	EcInt k;
		
	k.LoadFromBuffer64((u64*)&kParams->h_find_result->scalar);
	p = Ec::MultiplyG(k);
	
	std::cout << "\r\n======== FOUND MATCH! =================================\r\n";
	std::cout << std::left << std::setw(20) << " Device (GPU)       " << " : " << gpuIndex << "\r\n";
	std::cout << std::left << std::setw(20) << " Private Key        " << " : " << formatHex256((const uint64_t*)&kParams->h_find_result->scalar) << "\r\n";
	std::cout << std::left << std::setw(20) << " Public Key         " << " : " << formatCompressedPubHex((const uint64_t*)&p.x.data, (const uint64_t*)&p.y.data) << "\r\n";
	
}
