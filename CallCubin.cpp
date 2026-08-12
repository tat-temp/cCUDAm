#include "CallCubin.h"
#include <stdio.h>
#ifdef _MSC_VER
#pragma comment(lib, "cuda.lib")
#pragma warning(disable : 4996)
#endif

TCubinCall::TCubinCall()
{
	cuModule = NULL;
}

TCubinCall::~TCubinCall()
{
	Unload();
}

void TCubinCall::Unload()
{
	if (cuModule)
	{
		::cuModuleUnload(cuModule);
		cuModule = NULL;
	}
}

bool TCubinCall::LoadCubin(const char* fn)
{
	Unload(); //a second LoadCubin would otherwise leak the first module

	// cuModuleLoad needs a context current on the calling thread. The runtime's
	// primary context is created lazily, so cudaSetDevice() alone does not make
	// one -- without this the load fails with CUDA_ERROR_INVALID_CONTEXT (201).
	cudaFree(0);

	CUresult res = ::cuModuleLoad(&cuModule, fn);
	if (res != CUDA_SUCCESS)
	{
		const char* name = NULL;
		::cuGetErrorName(res, &name);
		printf("cuModuleLoad(\"%s\") failed, err %d (%s)\n", fn, res, name ? name : "?");
		cuModule = NULL;
		return false;
	}
	return true;
}

bool TCubinCall::CallKernel(TCallKernelParams params)
{
	dim3 gridDim, blockDim;
	gridDim.x = params.blockCnt; gridDim.y = 1; gridDim.z = 1;
	blockDim.x = params.blockSize; blockDim.y = 1; blockDim.z = 1;

	// cuLaunchKernel reads one kernelParams entry per declared parameter. A caller
	// that supplies an explicit array (TestKernel: 8) gets it verbatim; otherwise
	// fall back to the single-struct-by-value convention.
	void* one_arg[1];
	void** args;
	if (params.kernel_args && (params.kernel_arg_cnt > 0))
		args = params.kernel_args;
	else
	{
		one_arg[0] = params.kernel_param_ptr;
		args = one_arg;
	}

	CUfunction f = NULL;
	CUresult res = ::cuModuleGetFunction(&f, cuModule, params.kernel_name);
	if (res != CUDA_SUCCESS)
	{
		printf("cuModuleGetFunction(\"%s\") failed, err %d\r\n", params.kernel_name, res);
		return false;
	}

	if (params.sharedSize > 0)
	{
		CUresult err = ::cuFuncSetAttribute(f, CU_FUNC_ATTRIBUTE_MAX_DYNAMIC_SHARED_SIZE_BYTES, params.sharedSize);
		if (err != CUDA_SUCCESS)
		{
			printf("cuFuncSetAttribute failed, err %d\r\n", err);
			return false;
		}
	}

	res = ::cuLaunchKernel(f, gridDim.x, gridDim.y, gridDim.z, blockDim.x, blockDim.y, blockDim.z, params.sharedSize, params.stream, args, NULL);

	if (res != CUDA_SUCCESS)
	{
		printf("cuLaunchKernel failed, err %d\r\n", res);
		return false;
	}
	return true;
}

bool TCubinCall::CopyToSymbol(const char* sym_name, void* data, int size)
{
	CUdeviceptr dptr = 0;
	size_t symBytes = 0;
	CUresult res = cuModuleGetGlobal(&dptr, &symBytes, cuModule, sym_name);
	if (res != CUDA_SUCCESS)
	{
		// CUDA_ERROR_NOT_FOUND (500) here means the symbol is STB_LOCAL in the cubin.
		// nvcc gives every __device__/__constant__ variable internal linkage unless
		// the cubin is built with -rdc=true, and the driver only resolves globals.
		printf("cuModuleGetGlobal(\"%s\") failed, err %d%s\r\n", sym_name, res,
			(res == CUDA_ERROR_NOT_FOUND) ? " (NOT_FOUND -- symbol is not global; build the cubin with -rdc=true)" : "");
		return false;
	}

	if ((size_t)size > symBytes)
	{
		printf("CopyToSymbol(\"%s\"): %d bytes into a %zu-byte symbol\r\n", sym_name, size, symBytes);
		return false;
	}

	res = cuMemcpyHtoD(dptr, data, size);
	if (res != CUDA_SUCCESS)
	{
		printf("cuMemcpyHtoD(\"%s\") failed, err %d\r\n", sym_name, res);
		return false;
	}

	return true;
}