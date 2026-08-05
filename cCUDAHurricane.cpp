// CUDAHurricane — GPU secp256k1 Bitcoin-puzzle solver.

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <string>
#include <thread>
#include <chrono>
#include <cmath>
#include <csignal>
#include <atomic>
#include <vector>
#include <cinttypes> // Required for PRIu64

#include "cuda_runtime.h"
#include "cuda.h"

#include "Defs.h"
#include "Utils.h"
#include "Math.h"
#include "Ec.h"
#include "GpuPuzzle.h"

struct TOutParams {
	uint32_t runtime_points_batch_size;
    uint32_t runtime_batches_per_sm;
    uint32_t slices_per_launch;
	uint64_t range_start[4];
	uint64_t range_end[4];
	uint64_t range[4];
	uint8_t target_hash160[20];
	uint64_t* Gx;
	uint64_t* Gy;
};

struct TInParams {
	uint32_t runtime_points_batch_size;
    uint32_t runtime_batches_per_sm;
    uint32_t slices_per_launch;
	std::string target_hash_hex;
	std::string range_hex;
	std::string address_b58;
};

static volatile sig_atomic_t g_sigint = 0;
static int g_gpucnt = 0;
static bool g_inited = false;
static int g_threadcnt = 0;
static GpuPuzzle* g_GpuPuzzles[MAX_GPU_CNT];

static void handle_sigint(int) {
	g_sigint = 1;
	std::cerr << "\n[Ctrl+C] Interrupt received. Finishing current kernel slice and exiting...\n";
}
static int parse_params(TInParams& pParams, int argc, char** argv);
static int validate_params(TInParams& pInParams, TOutParams& pOutParams, char** argv);
static void init_gpus();
static int init_g_points(TOutParams& pOutParams);
#ifdef _WIN32
static uint32_t __stdcall puzzle_thr_proc(void* data);
#else
static void* puzzle_thr_proc(void* data);
#endif
void show_stat(u64 tm_start, u64 range);
static bool find_key(TOutParams& pParams);

int main(int argc, char** argv) {
    std::signal(SIGINT, handle_sigint);
	
	int exit_code = EXIT_SUCCESS;
	TInParams inParams = {0};
	TOutParams outParams = {0};
	
	std::cout << "********************************************************************************\r\n" <<
				"*                    CUDAHurricane v1.0 (c) 2026                               *\r\n" <<
				"********************************************************************************\r\n\r\n";

#ifdef _WIN32
	std::cout << "Windows version\r\n";
#else
	std::cout << "Linux version\r\n";
#endif

	Ec::InitEc();
	
	int res = parse_params(inParams, argc, argv);
	if (0 != res) {
		return res;
	}
	
	res = validate_params(inParams, outParams, argv);
	if (0 != res) {
		return res;
	}

	res = init_g_points(outParams);
	if (0 != res) {
		exit_code = res;
		goto lEnd;
	}
	
	init_gpus();
	
	if (g_inited) {
		if (!find_key(outParams)) {
		}
	}

lEnd:
    if (g_inited) {
		for (int i = 0; i < g_gpucnt; i++)
			delete g_GpuPuzzles[i];
	}
	
	if (outParams.Gx != nullptr) {
		free(outParams.Gx);
	}
	
	if (outParams.Gy != nullptr) {
		free(outParams.Gy);
	}
	
	return exit_code;
}

int parse_params(TInParams& pParams, int argc, char** argv) {
	
	pParams.runtime_points_batch_size = 1024;
    pParams.runtime_batches_per_sm    = 512;
    pParams.slices_per_launch         = 64;
	
	auto parse_grid = [](const std::string& s, uint32_t& a_out, uint32_t& b_out)->bool {
        size_t comma = s.find(',');
        if (comma == std::string::npos) return false;
        auto trim = [](std::string& z){
            size_t p1 = z.find_first_not_of(" \t");
            size_t p2 = z.find_last_not_of(" \t");
            if (p1 == std::string::npos) { z.clear(); return; }
            z = z.substr(p1, p2 - p1 + 1);
        };
        std::string a_str = s.substr(0, comma);
        std::string b_str = s.substr(comma + 1);
        trim(a_str); trim(b_str);
        if (a_str.empty() || b_str.empty()) return false;
        char* endp=nullptr;
        unsigned long aa = std::strtoul(a_str.c_str(), &endp, 10); if (*endp) return false;
        endp=nullptr;
        unsigned long bb = std::strtoul(b_str.c_str(), &endp, 10); if (*endp) return false;
        if (aa == 0ul || bb == 0ul) return false;
        if (aa > (1ul<<20) || bb > (1ul<<20)) return false;
        a_out=(uint32_t)aa; b_out=(uint32_t)bb; return true;
    };
	
	for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if      (arg == "--target-hash160" && i + 1 < argc) pParams.target_hash_hex = argv[++i];
        else if (arg == "--address"        && i + 1 < argc) pParams.address_b58     = argv[++i];
        else if (arg == "--range"          && i + 1 < argc) pParams.range_hex       = argv[++i];
        else if (arg == "--grid"           && i + 1 < argc) {
            uint32_t a=0, b=0;
            if (!parse_grid(argv[++i], a, b)) {
                std::cerr << "Error: --grid expects \"A,B\" (positive integers).\n";
                return EXIT_FAILURE;
            }
            pParams.runtime_points_batch_size = a;
            pParams.runtime_batches_per_sm    = b;
        }
        else if (arg == "--slices" && i + 1 < argc) {
            char* endp=nullptr;
            unsigned long v = std::strtoul(argv[++i], &endp, 10);
            if (*endp != '\0' || v == 0ul || v > (1ul<<20)) {
                std::cerr << "Error: --slices must be in 1.." << (1u<<20) << "\n";
                return EXIT_FAILURE;
            }
            pParams.slices_per_launch = (uint32_t)v;
        }
    }
	
	return 0;
}

int validate_params(TInParams& pInParams, TOutParams& pOutParams, char** argv) {
	std::string start_hex;
    std::string end_hex;
	size_t colon_pos;
	uint64_t range_start[4];
	uint64_t range_end[4];
	
	if (pInParams.range_hex.empty() || (pInParams.target_hash_hex.empty() && pInParams.address_b58.empty())) {
        std::cerr << "Usage: " << argv[0]
                  << " --range <start_hex>:<end_hex> (--address <base58> | --target-hash160 <hash160_hex>) [--grid A,B] [--slices N]\n";
        return EXIT_FAILURE;
    }
	
    if (!pInParams.target_hash_hex.empty() && !pInParams.address_b58.empty()) {
        std::cerr << "Error: provide either --address or --target-hash160, not both.\n";
        return EXIT_FAILURE;
    }
	
	colon_pos = pInParams.range_hex.find(':');
    if (colon_pos == std::string::npos) {
		std::cerr << "Error: range format must be start:end\n";
		return EXIT_FAILURE;
	}

    start_hex = pInParams.range_hex.substr(0, colon_pos);
    end_hex   = pInParams.range_hex.substr(colon_pos + 1);

    if (!hexToLE64(start_hex, range_start) || !hexToLE64(end_hex, range_end)) {
        std::cerr << "Error: invalid range hex\n"; return EXIT_FAILURE;
    }
	
	sub_256(range_end, range_start, pOutParams.range);
	add_256(pOutParams.range, num_256_1, pOutParams.range);

    if (!pInParams.address_b58.empty()) {
        if (!decode_p2pkh_address(pInParams.address_b58, pOutParams.target_hash160)) {
            std::cerr << "Error: invalid P2PKH address\n"; return EXIT_FAILURE;
        }
    } else {
        if (!hexToHash160(pInParams.target_hash_hex, pOutParams.target_hash160)) {
            std::cerr << "Error: invalid target hash160 hex\n"; return EXIT_FAILURE;
        }
    }

    auto is_pow2 = [](uint32_t v)->bool { return v && ((v & (v-1)) == 0); };
    if (!is_pow2(pInParams.runtime_points_batch_size) || (pInParams.runtime_points_batch_size & 1u)) {
        std::cerr << "Error: batch size must be even and a power of two.\n";
        return EXIT_FAILURE;
    }
    if (pInParams.runtime_points_batch_size > MAX_BATCH_SIZE) {
        std::cerr << "Error: batch size must be <= " << MAX_BATCH_SIZE << " (kernel limit).\n";
        return EXIT_FAILURE;
    }
	
	std::memcpy(pOutParams.range_start, range_start, sizeof(pOutParams.range_start));
	std::memcpy(pOutParams.range_end, range_end, sizeof(pOutParams.range_end));
	
	pOutParams.runtime_points_batch_size = pInParams.runtime_points_batch_size;
	pOutParams.runtime_batches_per_sm = pInParams.runtime_batches_per_sm;
	pOutParams.slices_per_launch = pInParams.slices_per_launch;
	
	return 0;
}

void init_gpus() {
	int gcnt = 0;
	int drv, rt;
	char drvver[100];
	cudaError_t cudaStatus;
	
	g_gpucnt = 0;
	
#ifdef NO_GPU_MODE
	{
		g_GpuPuzzles[g_gpucnt] = new GpuPuzzle();
		g_GpuPuzzles[g_gpucnt]->CudaIndex = 0;
		g_GpuPuzzles[g_gpucnt]->SMCnt = 170;
		g_gpucnt++;
		
		g_inited = true;
	
		std::cout << "Total GPUs for work: "<< g_gpucnt << "\r\n";
		
		return;
	}
#endif
	
	cudaGetDeviceCount(&gcnt);
	if (gcnt > MAX_GPU_CNT) {
		gcnt = MAX_GPU_CNT;
	}
	
	if (!gcnt) {
		std::cout << "No suitable CUDA devices found.\r\n";
		return;
	}
	
	cudaRuntimeGetVersion(&rt);
	cudaDriverGetVersion(&drv);
	sprintf(drvver, "%d.%d/%d.%d", drv / 1000, (drv % 100) / 10, rt / 1000, (rt % 100) / 10);
	
	std::cout << "CUDA devices: " << gcnt << ", CUDA driver/runtime: " << drvver << "\r\n";
	
	for (int i = 0; i < gcnt; i++)
	{
		cudaStatus = cudaSetDevice(i);
		if (cudaStatus != cudaSuccess)
		{
			std::cout << "cudaSetDevice for gpu " << i << " failed!\r\n";
			continue;
		}

		//if (!gGPUs_Mask[i])
		//	continue;

		cudaDeviceProp deviceProp;
		cudaGetDeviceProperties(&deviceProp, i);
		std::cout << "GPU " << i << ": " << deviceProp.name <<", " <<
			std::fixed << std::setprecision(2) << std::setw(10) << ((float)(deviceProp.totalGlobalMem / (1024 * 1024))) / 1024.0f << " GB, " <<
			deviceProp.multiProcessorCount << " CUs, cap " << deviceProp.major << "." << deviceProp.minor <<
			", PCI " << deviceProp.pciBusID << ", L2 size: " << deviceProp.l2CacheSize / 1024 << " KB\r\n";
		
		if (deviceProp.major < 6)
		{
			std::cout << "GPU " << i << " - not supported, skip\r\n";
			continue;
		}

		cudaSetDeviceFlags(cudaDeviceScheduleBlockingSync);

		g_GpuPuzzles[g_gpucnt] = new GpuPuzzle();
		g_GpuPuzzles[g_gpucnt]->CudaIndex = i;
		g_GpuPuzzles[g_gpucnt]->SMCnt = deviceProp.multiProcessorCount;
		g_gpucnt++;
	}
	
	g_inited = g_gpucnt > 0;
	
	std::cout << "Total GPUs for work: " << g_gpucnt << "\r\n";
}

int init_g_points(TOutParams& pOutParams) {
	EcPoint p;
    EcInt k;
    EcInt i1;
	uint32_t half;

	i1.Set((u64)1);

	half = pOutParams.runtime_points_batch_size >> 1;

	pOutParams.Gx = (uint64_t*)malloc(4 * sizeof(uint64_t) * half);
	pOutParams.Gy = (uint64_t*)malloc(4 * sizeof(uint64_t) * half);
	
	if (pOutParams.Gx != nullptr && pOutParams.Gy != nullptr) {
		k.Set((u64)1);
		
		for(int i = 0; i < half; i++) {
			p = Ec::MultiplyG(k);
			
			memcpy(&pOutParams.Gx[4*i], p.x.data, 4 * sizeof(uint64_t));
			memcpy(&pOutParams.Gy[4*i], p.y.data, 4 * sizeof(uint64_t));
			
			k.Add(i1);
		}
	}
	
	return (pOutParams.Gx == nullptr && pOutParams.Gy == nullptr) ? 1 : 0;
}

#ifdef _WIN32
uint32_t __stdcall puzzle_thr_proc(void* data)
{
	GpuPuzzle* puzzle = (GpuPuzzle*)data;
	puzzle->Execute();
	InterlockedDecrement(&g_threadcnt);
	return 0;
}
#else
void* puzzle_thr_proc(void* data)
{
	GpuPuzzle* puzzle = (GpuPuzzle*)data;
	puzzle->Execute();
	__sync_fetch_and_sub(&g_threadcnt, 1);
	return 0;
}
#endif

void show_stat(u64 tm_start, u64 range) {
	uint64_t speed = 0ull;
	
	for (int i = 0; i < g_gpucnt; i++) {
		speed += g_GpuPuzzles[i]->GetStatsSpeed();
	}

	u64 exp_sec = 0xFFFFFFFFFFFFFFFFull;
	if (speed) {
		exp_sec = range / (speed * 1000000ul); //in sec
	}

	u64 exp_days = exp_sec / (3600 * 24);
	int exp_hours = (int)(exp_sec - exp_days * (3600 * 24)) / 3600;
	int exp_min = (int)(exp_sec - exp_days * (3600 * 24) - exp_hours * 3600) / 60;

	u64 sec = (GetTickCount64() - tm_start) / 1000;
	u64 days = sec / (3600 * 24);
	int hours = (int)(sec - days * (3600 * 24)) / 3600;
	int min = (int)(sec - days * (3600 * 24) - hours * 3600) / 60;

	std::cout << "Range: " << range << " " << "Speed: " << speed << " MKeys/s, Time: " <<
		days << "d:" << std::setw(2) << hours << "h:" << std::setw(2) << min << "m/" <<
		exp_days << "d:" << std::setw(2) << exp_hours << "h:" << std::setw(2) << exp_min << "m\r\n";
	std::cout.flush();
}

bool find_key(TOutParams& pParams) {
    uint64_t current[4];
    uint64_t chunk[4];
    uint64_t chunk_effective[4];
	uint64_t remainder;
	uint64_t tmp;
	
#ifdef _WIN32
    uint32_t dwThreadId;
	HANDLE thr_handles[MAX_GPU_CNT];
#else
	pthread_t thr_handles[MAX_GPU_CNT];
#endif

	std::memset(&thr_handles, 0, sizeof(thr_handles));
    g_threadcnt = 0;

	div_256_u64(pParams.range, (uint64_t)g_gpucnt, chunk, &remainder);

    std::memcpy(&current, pParams.range_start, sizeof(current));
	
	for (int i = 0; i < g_gpucnt; i++) {
		
		std::memcpy(&chunk_effective, &chunk, sizeof(chunk_effective));
		if (i < remainder) {
			add_256((const uint64_t*)&chunk_effective, num_256_1, (uint64_t*)&chunk_effective);
		}
		
		if (!g_GpuPuzzles[i]->Prepare(
			(const uint64_t*)&current,
			(const uint64_t*)&chunk_effective,
			pParams.target_hash160,
			(const uint64_t*)pParams.Gx,
			(const uint64_t*)pParams.Gy,
			(uint64_t)pParams.runtime_points_batch_size,
			(uint64_t)pParams.runtime_batches_per_sm,
			pParams.slices_per_launch))
		{
			g_GpuPuzzles[i]->Failed = true;
			std::cout << "GPU " << g_GpuPuzzles[i]->CudaIndex << " FAILED" << "\r\n";
		} else {
			std::cout << "GPU " << g_GpuPuzzles[i]->CudaIndex << " PREPARED" << "\r\n";
			std::cout << "RangeStart:  " << formatHex256(current) << "\r\n";
			std::cout << "RangeLength: " << formatHex256(chunk_effective) << "\r\n";
			
			g_threadcnt++;
		}
		
		add_256((const uint64_t*)&current, (const uint64_t*)&chunk_effective, (uint64_t*)&current);
	}
	
	for (int i = 0; i < g_gpucnt; i++)
	{
		if (g_GpuPuzzles[i]->Failed) {
			std::cout << "GPU " << g_GpuPuzzles[i]->CudaIndex << ": Skip work.\r\n";
			continue;
		}
#ifdef _WIN32
		thr_handles[i] = (HANDLE)_beginthreadex(NULL, 0, puzzle_thr_proc, (void*)g_GpuPuzzles[i], 0, &dwThreadId);
#else
		pthread_create(&thr_handles[i], NULL, puzzle_thr_proc, (void*)g_GpuPuzzles[i]);
#endif
	}
	
	u64 tm_stats = GetTickCount64();
	u64 tm0 = tm_stats;
	
	// wait cycle
	while (g_threadcnt && !g_sigint) {
		sleep(1);
		
		if (GetTickCount64() - tm_stats > SHOW_STAT_INTERVAL_SECS * 1000)
		{
			show_stat(tm0, pParams.range[0]);
			tm_stats = GetTickCount64();
		}
	}
	
	std::cout << "Stopping work ...\r\n";
	for (int i = 0; i < g_gpucnt; i++) {
		if (g_GpuPuzzles[i]->Failed) {
			continue;
		}
		g_GpuPuzzles[i]->Stop();
	}

	while (g_threadcnt) {
		sleep(10);
	}
	
	for (int i = 0; i < g_gpucnt; i++) {
		if (!thr_handles[i]) {
			continue;
		}
#ifdef _WIN32
		CloseHandle(thr_handles[i]);
#else
		pthread_join(thr_handles[i], NULL);
#endif
	}
		
	return true;
}

