#pragma once

#include "EcInt.h"
#include "Defs.h"

#define STATS_WND_SIZE	16

class GpuPuzzle
{
private:
	bool m_stopFlag;
	EcInt m_start;
	EcInt m_end;
	
	TKparams Kparams;

	int m_stat_idx;
	uint64_t m_speed_stat[STATS_WND_SIZE];

	bool Start();
	void Release();
public:
	int CudaIndex; //gpu index in cuda
	int SMCnt;
	bool Failed;

	
	bool Prepare(const uint64_t* pStart, const uint64_t* pRange, const uint8_t* pHash, const uint64_t* gx, const uint64_t* gy, uint64_t batchSize, uint64_t blockPerSm, uint32_t dwSlices);
	void Stop();
	void Execute();

	uint64_t GetStatsSpeed();
};