// Does the CUDA driver accept an RCAsm-assembled cubin?
//
// This is the one step that cannot be answered without a GPU. It deliberately stops at
// cuModuleGetFunction + attribute query and does NOT launch: launching Kernel01's mulKernel
// needs its by-value parameter struct filled in correctly, and a wrong launch is a hang, not
// an error message. Load + resolve is what the RCAsm question actually turns on.
//
//   nvcc -o rcasm_load_test rcasm_load_test.cpp -lcuda
//   ./rcasm_load_test kernel_sm120.cubin mulKernel
#include <cuda.h>
#include <cstdio>

static bool chk(CUresult r, const char* what)
{
	if (r == CUDA_SUCCESS)
		return true;
	const char *nm = nullptr, *ds = nullptr;
	cuGetErrorName(r, &nm);
	cuGetErrorString(r, &ds);
	printf("  FAIL  %-24s %s (%d): %s\n", what, nm ? nm : "?", (int)r, ds ? ds : "?");
	return false;
}

int main(int argc, char** argv)
{
	const char* path = (argc > 1) ? argv[1] : "kernel_sm120.cubin";
	const char* kname = (argc > 2) ? argv[2] : "mulKernel";

	printf("cubin  : %s\nkernel : %s\n\n", path, kname);

	if (!chk(cuInit(0), "cuInit"))
		return 1;

	CUdevice dev;
	if (!chk(cuDeviceGet(&dev, 0), "cuDeviceGet"))
		return 1;

	char name[256] = {0};
	int major = 0, minor = 0;
	cuDeviceGetName(name, sizeof(name), dev);
	cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev);
	cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev);
	printf("  device: %s (sm_%d%d)\n", name, major, minor);

	// Primary context, not cuCtxCreate: CUDA 13 renamed cuCtxCreate to _v4 with a new
	// signature, and this is also what the runtime hands out -- the same context
	// CallCubin.cpp ends up in via cudaFree(0).
	CUcontext ctx;
	if (!chk(cuDevicePrimaryCtxRetain(&ctx, dev), "cuDevicePrimaryCtxRetain"))
		return 1;
	if (!chk(cuCtxSetCurrent(ctx), "cuCtxSetCurrent"))
		return 1;

	// The whole question, in one call.
	CUmodule mod;
	if (!chk(cuModuleLoad(&mod, path), "cuModuleLoad"))
	{
		printf("\nVERDICT: the driver REJECTED the RCAsm cubin.\n");
		return 2;
	}
	printf("  OK    cuModuleLoad\n");

	CUfunction fn;
	if (!chk(cuModuleGetFunction(&fn, mod, kname), "cuModuleGetFunction"))
	{
		printf("\nVERDICT: loaded, but '%s' did not resolve.\n", kname);
		return 3;
	}
	printf("  OK    cuModuleGetFunction\n");

	struct { CUfunction_attribute a; const char* n; } attrs[] = {
		{ CU_FUNC_ATTRIBUTE_NUM_REGS,                    "NUM_REGS"        },
		{ CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK,       "MAX_THREADS"     },
		{ CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES,           "SHARED_BYTES"    },
		{ CU_FUNC_ATTRIBUTE_LOCAL_SIZE_BYTES,            "LOCAL_BYTES"     },
		{ CU_FUNC_ATTRIBUTE_CONST_SIZE_BYTES,            "CONST_BYTES"     },
		{ CU_FUNC_ATTRIBUTE_BINARY_VERSION,              "BINARY_VERSION"  },
	};
	printf("\n  function attributes (driver's own view of the image):\n");
	for (unsigned i = 0; i < sizeof(attrs) / sizeof(attrs[0]); i++)
	{
		int v = -1;
		if (cuFuncGetAttribute(&v, attrs[i].a, fn) == CUDA_SUCCESS)
			printf("    %-15s %d\n", attrs[i].n, v);
	}

	cuModuleUnload(mod);
	cuDevicePrimaryCtxRelease(dev);
	printf("\nVERDICT: the driver ACCEPTED the RCAsm cubin and resolved '%s'.\n", kname);
	return 0;
}
