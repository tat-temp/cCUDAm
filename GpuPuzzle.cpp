#include <iostream>
#include <cstring>
#include <cinttypes> // Required for PRIu64
#include <cuda_runtime.h>

#include "GpuPuzzle.h"
#include "Math.h"
#include "Utils.h"
#include "Ec.h"

#define BYTES_PER_THREAD (2ull*4ull*sizeof(uint64_t))

void CallGpuKernel(TKparams& Kparams);
cudaError_t CudaCopyTargetWords(const void* value);
cudaError_t CudaCopyGx(const void* value, size_t size);
cudaError_t CudaCopyGy(const void* value, size_t size);
cudaError_t CudaCopyJx(const void* value);
cudaError_t CudaCopyJy(const void* value);

struct THparams
{
	uint64_t* counts;
	uint64_t* scalars;
	uint64_t* px;
	uint64_t* py;
	const uint64_t* gx;
	const uint64_t* gy;
	uint64_t bx[4];
	uint64_t by[4];
};

uint64_t PickThreadsPerBlock(cudaDeviceProp* prop);
uint64_t GetMaxThreadsByMem(cudaDeviceProp* prop);
uint64_t PickThreadsTotal(uint64_t upper, uint64_t threadsPerBlock, uint64_t totalBatches);
uint64_t GetThreadsCount(cudaDeviceProp* prop, const uint64_t* range, uint64_t blockPerSm, uint64_t threadsPerBlock, uint64_t batchSize, uint64_t slises);
bool AreRunParametersValid(const uint64_t* range, uint64_t threadsTotal, uint64_t batchSize);
void ClearHParams(THparams* hParams);
void ClearKParams(TKparams* kParams);
bool PrepareHost(THparams* hParams, const uint64_t* start, const uint64_t* range, const uint8_t* hash160, uint64_t threadsTotal, uint64_t batchSize);
bool PrepareCuda(TKparams* kParams, const THparams* hParams, uint64_t threadsTotal, uint64_t batchSize);

void GpuPuzzle::GpuPuzzle() {
	
}

bool GpuPuzzle::Start() {
	
	return true;
}

void GpuPuzzle::Release() {
	ClearKParams(&Kparams);
}

bool GpuPuzzle::Prepare(const uint64_t* pStart, const uint64_t* pRange, const uint8_t* pHash, const uint64_t* gx, const uint64_t* gy, uint64_t batchSize, uint64_t blockPerSm, uint32_t dwSlices) {
	THparams hParams;
	bool result = false;
	cudaError_t err;
	cudaDeviceProp prop{};

    std::memset(m_speed_stat, 0, sizeof(m_speed_stat));
    std::memset(&hParams, 0, sizeof(THparams));
    std::memset(&this->Kparams, 0, sizeof(TKparams));

#ifndef NO_GPU_MODE	
	if (cudaGetDeviceProperties(&prop, CudaIndex) != cudaSuccess) {
        std::cerr << "CUDA init error\n";
		return result;
    }
	
	err = cudaSetDevice(CudaIndex);
	if (err != cudaSuccess) {
		return result;
	}
#else
	printf("GPU %d: Batch: %llu Blocks/SM %llu Slices: %i\r\n", CudaIndex, (unsigned long long)batchSize, (unsigned long long)blockPerSm, dwSlices);

	prop.maxThreadsPerBlock = 1024;
	prop.totalGlobalMem = (uint64_t)32 * 1024 * 1024 * 1024;
	prop.multiProcessorCount = 170;
#endif
	
	//cudaDeviceSetCacheConfig(cudaFuncCachePreferL1);
	uint64_t threadsPerBlock = PickThreadsPerBlock(&prop);
	uint64_t threadsTotal = GetThreadsCount(&prop, pRange, blockPerSm, threadsPerBlock, batchSize, (uint64_t)dwSlices);

#if DEBUG_MODE > 0
	printf("GPU %d: Threads/Block: %llu Total threads: %llu\r\n", CudaIndex, (unsigned long long)threadsPerBlock, (unsigned long long)threadsTotal);
#endif
	
	if (!AreRunParametersValid(pRange, threadsTotal, batchSize)) {
		return result;
	}

	if (!PrepareHost(&hParams, pStart, pRange, pHash, threadsTotal, batchSize)) {
		return result;
	}

	hParams.gx = gx;
	hParams.gy = gy;

#ifndef NO_GPU_MODE
	if (!PrepareCuda(&this->Kparams, (const THparams*)&hParams, threadsTotal, batchSize)) {
		goto LExit;
	}
#endif

	Kparams.BlockCnt = SMCnt * blockPerSm;
	Kparams.BlockSize = threadsPerBlock;
	Kparams.points_per_run = batchSize * threadsTotal * dwSlices;
	Kparams.batch_size = batchSize;
	Kparams.batches_per_launch = dwSlices;
	Kparams.threads_total = threadsTotal;

	result = true;
	
LExit:

	ClearHParams(&hParams);
	
	if (!result) {
		ClearKParams(&Kparams);
	}

	return result;
}

//executes in separate thread
void GpuPuzzle::Execute() {
	cudaError_t err;
	uint64_t pnt_cnt;

	Failed = false;

#ifndef NO_GPU_MODE	
	err = cudaSetDevice(CudaIndex);
	if (err != cudaSuccess) {
		return;
	}
#endif

	if (!Start()) {
		Failed = true;
		return;
	}

	pnt_cnt = Kparams.points_per_run;

	while (!m_stopFlag) {
		u64 t1 = GetTickCount64();

#ifndef NO_GPU_MODE
		CallGpuKernel(Kparams);
#endif
		
		{
			u64 t2 = GetTickCount64();
			u64 tm = t2 - t1;
			if (!tm) tm = 1;
			
			uint64_t cur_speed = (uint64_t)(pnt_cnt / (tm * 1000));
			//printf("GPU %d kernel time %d ms, speed %d MH\r\n", CudaIndex, (int)tm, cur_speed);

			m_speed_stat[m_stat_idx] = cur_speed;
			m_stat_idx = (m_stat_idx + 1) % STATS_WND_SIZE;
		}
	}

	Release();
}

void GpuPuzzle::Stop() {
	m_stopFlag = true;
}

uint64_t GpuPuzzle::GetStatsSpeed() {
	uint64_t res = m_speed_stat[0];
	for (int i = 1; i < STATS_WND_SIZE; i++) {
		res += m_speed_stat[i];
	}
	return res / STATS_WND_SIZE;
}

uint64_t PickThreadsPerBlock(cudaDeviceProp* prop) {
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
	return maxThreadsByMem;
}

uint64_t PickThreadsTotal(uint64_t upper, uint64_t threadsPerBlock, uint64_t totalBatches) {
	if (upper < threadsPerBlock) return 0ull;
	uint64_t t = upper - (upper % threadsPerBlock);
	uint64_t q = totalBatches;
	while (t >= threadsPerBlock) {
		if ((q % t) == 0ull) return t;
		t -= threadsPerBlock;
	}
	return 0ull;
}

uint64_t GetThreadsCount(cudaDeviceProp* prop, const uint64_t* range, uint64_t blockPerSm, uint64_t threadsPerBlock, uint64_t batchSize, uint64_t slises) {
	uint64_t q_div_batch[4];
	uint64_t r_div_batch = 0ull;
	uint64_t total_batches_u64;
	uint64_t userUpper;
	uint64_t upper;
	uint64_t maxThreadsByMem;
	
	maxThreadsByMem = GetMaxThreadsByMem(prop);
    //printf("maxThreadsByMem: %llu\r\n", (unsigned long long)maxThreadsByMem);
	
	// max threads required
    div_256_u64(range, (uint64_t)batchSize * slises, q_div_batch, &r_div_batch);
	total_batches_u64 = q_div_batch[0];
	//printf("total_batches_u64: %llu\r\n", (unsigned long long)total_batches_u64);

	// user upper
	userUpper = (uint64_t)prop->multiProcessorCount * blockPerSm * threadsPerBlock;
    if (userUpper == 0ull) userUpper = UINT64_MAX;
	//printf("userUpper: %llu\r\n", (unsigned long long)userUpper);
	
	// effective upper
	upper = maxThreadsByMem;
    if (total_batches_u64 < upper) upper = total_batches_u64;
    if (userUpper         < upper) upper = userUpper;
	//printf("upper: %llu\r\n", (unsigned long long)upper);
	
	return PickThreadsTotal(upper, threadsPerBlock, total_batches_u64);
}

bool AreRunParametersValid(const uint64_t* range, uint64_t threadsTotal, uint64_t batchSize) {
	uint64_t per_thread_cnt[4];
	uint64_t r_u64 = 0ull;
	uint64_t qq[4];
	uint64_t rr = 0ull;

    div_256_u64(range, threadsTotal, per_thread_cnt, &r_u64);
	if (r_u64 != 0ull) {
		std::cerr << "Internal error: range_len not divisible by threadsTotal.\n";
		return false;
	}
	
	div_256_u64(per_thread_cnt, batchSize, qq, &rr);
    if (rr != 0ull) {
		std::cerr << "Internal error: per-thread count is not a multiple of batch size.\n";
		return false;
	}
	
	return true;
}

void ClearHParams(THparams* hParams) {
#ifndef NO_GPU_MODE
	if (hParams->counts) cudaFreeHost(hParams->counts);
	if (hParams->scalars) cudaFreeHost(hParams->scalars);
	if (hParams->px) cudaFreeHost(hParams->px);
	if (hParams->py) cudaFreeHost(hParams->py);
#else
	if (hParams->counts) free(hParams->counts);
	if (hParams->scalars) free(hParams->scalars);
	if (hParams->px) free(hParams->px);
	if (hParams->py) free(hParams->py);
#endif
}

void ClearKParams(TKparams* kParams) {
#ifndef NO_GPU_MODE
	if (kParams->counts) cudaFree(kParams->counts);
	if (kParams->scalars) cudaFree(kParams->scalars);
	if (kParams->px) cudaFree(kParams->px);
	if (kParams->py) cudaFree(kParams->py);
	if (kParams->rx) cudaFree(kParams->rx);
	if (kParams->ry) cudaFree(kParams->ry);
#endif
}

bool PrepareHost(THparams* hParams, const uint64_t* start, const uint64_t* range, const uint8_t* hash160, uint64_t threadsTotal, uint64_t batchSize) {
	uint64_t per_thread_cnt[4];
	uint64_t r1 = 0ull;
	uint64_t* h_counts256     = nullptr;
    uint64_t* h_start_scalars = nullptr;
    uint64_t* h_px = nullptr;
    uint64_t* h_py = nullptr;
	uint32_t half;
	bool result = false;

	div_256_u64(range, threadsTotal, per_thread_cnt, &r1);

#ifndef NO_GPU_MODE
    cudaHostAlloc(&h_counts256,     threadsTotal * 4 * sizeof(uint64_t), cudaHostAllocWriteCombined | cudaHostAllocMapped);
    cudaHostAlloc(&h_start_scalars, threadsTotal * 4 * sizeof(uint64_t), cudaHostAllocWriteCombined | cudaHostAllocMapped);
    cudaHostAlloc(&h_px,			threadsTotal * 4 * sizeof(uint64_t), cudaHostAllocWriteCombined | cudaHostAllocMapped);
    cudaHostAlloc(&h_py,			threadsTotal * 4 * sizeof(uint64_t), cudaHostAllocWriteCombined | cudaHostAllocMapped);
#else
    h_counts256 = (uint64_t*)malloc(threadsTotal * 4 * sizeof(uint64_t));
    h_start_scalars = (uint64_t*)malloc(threadsTotal * 4 * sizeof(uint64_t));
    h_px = (uint64_t*)malloc(threadsTotal * 4 * sizeof(uint64_t));
    h_py = (uint64_t*)malloc(threadsTotal * 4 * sizeof(uint64_t));
#endif

	// h_counts256
	{
#if DEBUG_MODE > 0
		printf("\r\n---Points/thread---\r\n");
#endif
		for (uint64_t i = 0; i < threadsTotal; ++i) {
			h_counts256[i*4+0] = per_thread_cnt[0];
			h_counts256[i*4+1] = per_thread_cnt[1];
			h_counts256[i*4+2] = per_thread_cnt[2];
			h_counts256[i*4+3] = per_thread_cnt[3];
			
			if (i < r1) {
				add_256_u64((const uint64_t*)&h_counts256[i*4], (uint64_t)1, (uint64_t*)&h_counts256[i*4]);
			}
#if DEBUG_MODE > 0
			printf("[%6" PRIu64 "]: %s\r\n", i, formatHex256(&h_counts256[i*4]).c_str());
#endif
		}
	}

	// h_start_scalars
	half = (uint32_t)batchSize >> 1;
    {
#if DEBUG_MODE > 0
		printf("\r\n---Start scalars---\r\n");
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
				add_256_u64((const uint64_t*)&next, (uint64_t)1, (uint64_t*)&next);
			}
			
#if DEBUG_MODE > 0
			printf("[%6" PRIu64 "]: %s\r\n", i, formatHex256(&h_start_scalars[i*4]).c_str());
#endif
			
            cur[0]=next[0]; cur[1]=next[1]; cur[2]=next[2]; cur[3]=next[3];
        }
    }
	
	// c_target_words
	{
#if DEBUG_MODE > 0
		printf("\r\n---Target hash (truncated)---\r\n%s\r\n", formatHex256((uint64_t*)hash160).c_str());
#endif
        uint32_t target_words[5];
        target_words[0] = (uint32_t)hash160[ 0] | ((uint32_t)hash160[ 1] << 8) | ((uint32_t)hash160[ 2] << 16) | ((uint32_t)hash160[ 3] << 24);
        target_words[1] = (uint32_t)hash160[ 4] | ((uint32_t)hash160[ 5] << 8) | ((uint32_t)hash160[ 6] << 16) | ((uint32_t)hash160[ 7] << 24);
        target_words[2] = (uint32_t)hash160[ 8] | ((uint32_t)hash160[ 9] << 8) | ((uint32_t)hash160[10] << 16) | ((uint32_t)hash160[11] << 24);
        target_words[3] = (uint32_t)hash160[12] | ((uint32_t)hash160[13] << 8) | ((uint32_t)hash160[14] << 16) | ((uint32_t)hash160[15] << 24);
        target_words[4] = (uint32_t)hash160[16] | ((uint32_t)hash160[17] << 8) | ((uint32_t)hash160[18] << 16) | ((uint32_t)hash160[19] << 24);
        //cudaMemcpyToSymbol(c_target_words, target_words, sizeof(target_words));
		CudaCopyTargetWords(&target_words);
    }
	
	// p(x,y)
	{
#if DEBUG_MODE > 0
		printf("\r\n---Start points---\r\n");
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
			printf("[%6" PRIu64 "]: x:%s\r\n", i, formatHex256(&h_px[i*4]).c_str());
			printf("[%6" PRIu64 "]: y:%s\r\n", i, formatHex256(&h_py[i*4]).c_str());
#endif
		}
	}
	
	// B pointer
	{
#if DEBUG_MODE > 0
		printf("\r\n---B (batch size point)---\r\n");
#endif

		EcPoint p;
		EcInt k;
		
		k.Set((u64)batchSize);
		p = Ec::MultiplyG(k);

		std::memcpy(&hParams->bx, p.x.data, 32);
		std::memcpy(&hParams->by, p.y.data, 32);

#if DEBUG_MODE > 0
		printf("x:%s\r\n", formatHex256((const uint64_t*)&p.x.data).c_str());
		printf("y:%s\r\n", formatHex256((const uint64_t*)&p.y.data).c_str());
#endif

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
	hParams->px = h_px;
	hParams->py = h_py;
	
	result = true;
	
LExit:	

	if (!result) {
#ifndef NO_GPU_MODE		
		if (h_counts256) cudaFreeHost(h_counts256);
		if (h_start_scalars) cudaFreeHost(h_start_scalars);
		if (h_px) cudaFreeHost(h_px);
		if (h_py) cudaFreeHost(h_py);
#else
		if (h_counts256) free(h_counts256);
		if (h_start_scalars) free(h_start_scalars);
		if (h_px) free(h_px);
		if (h_py) free(h_py);
#endif
	}

	return result;
}

bool PrepareCuda(TKparams* kParams, const THparams* hParams, uint64_t threadsTotal, uint64_t batchSize) {
	bool result = false;
	uint64_t* d_start_scalars = nullptr;
	uint64_t* d_Px = nullptr;
	uint64_t* d_Py = nullptr;
	uint64_t* d_Rx = nullptr;
	uint64_t* d_Ry = nullptr;
	uint64_t* d_counts = nullptr;
    int *d_found_flag=nullptr;
	//FoundResult *d_found_result=nullptr;
    unsigned long long *d_hashes_accum=nullptr; unsigned int *d_any_left=nullptr;
	
	#define ck(e, msg) { \
        if (e != cudaSuccess) { \
            std::cerr << msg << ": " << cudaGetErrorString(e) << "\n"; \
            goto LExit; \
        } \
    }; \
	
	ck(cudaMalloc(&d_start_scalars, threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_start_scalars)");
	ck(cudaMalloc(&d_counts,        threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_counts)");
	ck(cudaMalloc(&d_Px,            threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_Px)");
    ck(cudaMalloc(&d_Py,            threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_Py)");
    ck(cudaMalloc(&d_Rx,            threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_Rx)");
    ck(cudaMalloc(&d_Ry,            threadsTotal * 4 * sizeof(uint64_t)), "cudaMalloc(d_Ry)");
    

    ck(cudaMemcpy(d_start_scalars, 	hParams->scalars, 	threadsTotal * 4 * sizeof(uint64_t), cudaMemcpyHostToDevice), "cpy scalars");
    ck(cudaMemcpy(d_counts,        	hParams->counts,  	threadsTotal * 4 * sizeof(uint64_t), cudaMemcpyHostToDevice), "cpy counts");
    ck(cudaMemcpy(d_Px,        		hParams->px,  		threadsTotal * 4 * sizeof(uint64_t), cudaMemcpyHostToDevice), "cpy px");
    ck(cudaMemcpy(d_Py,        		hParams->py,  		threadsTotal * 4 * sizeof(uint64_t), cudaMemcpyHostToDevice), "cpy py");

	//ck(cudaMemcpyToSymbol(c_Gx, 	hParams->gx, 		(batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gx");
	//ck(cudaMemcpyToSymbol(c_Gy, 	hParams->gy, 		(batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gy");
	//ck(cudaMemcpyToSymbol(c_Jx, 	hParams->bx, 		4 * sizeof(uint64_t)), "ToSymbol c_Jx");
	//ck(cudaMemcpyToSymbol(c_Jy, 	hParams->by, 		4 * sizeof(uint64_t)), "ToSymbol c_Jy");
	ck(CudaCopyGx(hParams->gx, (batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gx");
	ck(CudaCopyGy(hParams->gy, (batchSize >> 1) * 4 * sizeof(uint64_t)), "ToSymbol c_Gy");
	ck(CudaCopyJx(&hParams->bx), "ToSymbol c_Jx");
	ck(CudaCopyJy(&hParams->by), "ToSymbol c_Jy");

	kParams->scalars = d_start_scalars;
	kParams->counts = d_counts;
	kParams->px = d_Px;
	kParams->py = d_Py;
	kParams->rx = d_Rx;
	kParams->ry = d_Ry;

	result = true;
	
LExit:	

	if (!result) {
		if (d_counts) cudaFree(d_counts);
		if (d_start_scalars) cudaFree(d_start_scalars);
		if (d_Px) cudaFree(d_Px);
		if (d_Py) cudaFree(d_Py);
		if (d_Rx) cudaFree(d_Rx);
		if (d_Ry) cudaFree(d_Ry);
	}

	return result;
}


