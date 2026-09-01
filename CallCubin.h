#pragma once

#include "cuda_runtime.h"
#include "cuda.h"

struct TCallKernelParams
{
	char kernel_name[256];
	int blockSize;
	int blockCnt;
	int sharedSize; //LDS size
	cudaStream_t stream;
	void* kernel_param_ptr;
	int kernel_param_size;

	// cuLaunchKernel reads one kernelParams entry per declared parameter. Leave zero to
	// pass kernel_param_ptr as the single struct argument; a multi-argument kernel such as
	// TestKernel (8 params) must set them, or the launch reads off the end of a 1-entry array.
	void** kernel_args;
	int kernel_arg_cnt;
};

class TCubinCall
{
private:
	CUmodule cuModule;

public:
	TCubinCall();
	~TCubinCall();

	// The module is a raw driver handle owned by this object: a copy would unload it twice.
	TCubinCall(const TCubinCall&) = delete;
	TCubinCall& operator=(const TCubinCall&) = delete;

	bool LoadCubin(const char* fn);
	void Unload();
	bool CallKernel(TCallKernelParams params);
	bool CopyToSymbol(const char* sym_name, void* data, int size);
};

