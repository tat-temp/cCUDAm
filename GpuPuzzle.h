#pragma once

#include <atomic>

#include "EcInt.h"
#include "Defs.h"

#define STATS_WND_SIZE	16

class GpuPuzzle
{
private:
	std::atomic<bool> m_stopFlag;
	EcInt m_start;
	EcInt m_end;
	
	int m_stat_idx;
	uint64_t m_speed_stat[STATS_WND_SIZE];

	bool Start();
	void Release();
public:
	GpuPuzzle() : m_stopFlag(false), m_stat_idx(0), m_speed_stat{},
              CudaIndex(0), Failed(false), Found(false) { Kparams = {0}; }

	TKparams Kparams;
	int CudaIndex; //gpu index in cuda
	bool Failed;
	bool Found;

	
	bool Prepare(const uint64_t* pStart, const uint64_t* pRange, const uint8_t* pHash, const uint64_t* gx, const uint64_t* gy, uint64_t batchSize, uint64_t maxUserBlockPerSm, uint32_t dwSlices);
	void Stop();
	void Execute();

	uint64_t GetStatsSpeed();
};