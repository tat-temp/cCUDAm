CUDA_PATH ?= /usr/local/cuda
NVCC      := $(CUDA_PATH)/bin/nvcc
CUOBJDUMP ?= $(CUDA_PATH)/bin/cuobjdump
CC        := g++

# Target GPU architectures (SASS). sm_120 requires CUDA Toolkit 12.8 or newer.
# Override with SM (or lowercase sm): `make SM=86`, `make sass SM=89`, or `make SM="86 89"`.
SM ?= $(sm)
ifeq ($(strip $(SM)),)
SM_ARCHS  := 120
else
SM_ARCHS  := $(SM)
endif
GENCODE   := $(foreach arch,$(SM_ARCHS),-gencode arch=compute_$(arch),code=sm_$(arch))

# Same optimization flags as cCUDA.
CXXFLAGS  := -std=c++17
NVCCFLAGS := -O3 -use_fast_math --ptxas-options=-O3 $(GENCODE) $(CXXFLAGS)
CCFLAGS   := -O3 $(CXXFLAGS) -pthread -I$(CUDA_PATH)/include
LDFLAGS   := -cudart=static -lpthread -lm

# Points-only build. `make NO_HASH=1` compiles the hash layer out of TestKernel's hot path,
# leaving the EC walk as the baseline a hand-written-SASS TestKernel has to reproduce (see
# asm/TESTKERNEL_TEMPLATE.md). It CANNOT find a key: every candidate is folded into a sink
# instead of hashed (GpuCore.cu), so `found` is never set. Do not run proof.py against it.
NO_HASH ?=
ifneq ($(strip $(NO_HASH)),)
NVCCFLAGS += -DNO_HASH=1
endif

CPU_SRC := cCUDAHurricane.cpp EcInt.cpp GpuPuzzle.cpp EcPoint.cpp Ec.cpp
GPU_SRC := GpuCore.cu GpuEc.cu
HDRS    := $(wildcard *.h *.cuh)

# Native cubin path. `make NATIVE_CUBIN=1` launches TestKernel through the driver API
# (CallCubin.cpp: cuModuleLoad + cuLaunchKernel) from a prebuilt .cubin instead of the runtime
# <<<>>> launch; give a path to name the file, default GpuCore.cubin from `make cubin`. The
# path is resolved at RUN time, relative to the process's working directory -- keep the cubin
# next to the binary. Build it with -rdc=true (see the `cubin` target): without it nvcc gives
# every device variable internal linkage and cuModuleGetGlobal cannot find the constant tables.
NATIVE_CUBIN ?=
ifneq ($(strip $(NATIVE_CUBIN)),)
ifeq ($(strip $(NATIVE_CUBIN)),1)
CUBIN_FILE := GpuCore.cubin
else
CUBIN_FILE := $(NATIVE_CUBIN)
endif
NATIVE_DEFS := -DUSE_NATIVE_CUBIN=1 -DNATIVE_CUBIN_PATH='"$(CUBIN_FILE)"'
NVCCFLAGS   += $(NATIVE_DEFS)
CCFLAGS     += $(NATIVE_DEFS)
CPU_SRC     += CallCubin.cpp
# libcuda is the driver library, not the runtime: link the stub, the real one is found at load time.
LDFLAGS     += -L$(CUDA_PATH)/lib64/stubs -lcuda
else
CUBIN_FILE := GpuCore.cubin
endif

CPP_OBJECTS := $(CPU_SRC:.cpp=.o)
CU_OBJECTS  := $(GPU_SRC:.cu=.o)

TARGET := cCUDAHurricane

.PHONY: all clean ptxinfo sass cubin nohash-cubin rdc-cubins

all: $(TARGET)

# The cubin that NATIVE_CUBIN loads, built with the shipped device flags. Single-arch only:
# -cubin with several -gencode flags does not produce one cubin.
#
# Two steps, not one: `-rdc=true -cubin` emits a RELOCATABLE cubin (ELF type REL) and
# cuModuleLoad only accepts ET_EXEC, so it has to go through a device link. -rdc=true itself is
# what gives the five __constant__ tables GLOBAL binding. It costs the shipped kernel 0.38% of
# wall clock sustained (see `rdc-cubins`) and the NO_HASH build nothing, so points-only A/B
# ratios carry no -rdc bias.
cubin: GpuCore.cu $(HDRS) GpuHash.cu
ifneq ($(words $(SM_ARCHS)),1)
	@echo "cubin: pick a single arch, e.g. make cubin SM=120 (got: $(SM_ARCHS))"; exit 1
else
	$(NVCC) $(NVCCFLAGS) -rdc=true -c -o GpuCore-rdc.o GpuCore.cu
	$(NVCC) $(NVCCFLAGS) -dlink -cubin -o $(CUBIN_FILE) GpuCore-rdc.o
	@rm -f GpuCore-rdc.o
	@echo "wrote $(CUBIN_FILE)"
endif

# The points-only reference the hand-written SASS is measured against -- side A of every
# rcasm_test/abtest speed run and of the occupancy comparison in asm/tk/README.md. A target
# rather than a README note: *.cubin is gitignored, so side A is missing from a fresh clone and
# the harness only reports CUDA_ERROR_FILE_NOT_FOUND, not how to rebuild it.
nohash-cubin:
	$(MAKE) cubin NO_HASH=1 CUBIN_FILE=GpuCore_nohash.cubin SM=$(SM_ARCHS)

# What -rdc=true costs the SHIPPED kernel: 0.38% of wall clock sustained, 1.36% at peak clock,
# from `./abtest ../../GpuCore_rdc.cubin ../../GpuCore_plain.cubin 174080 180s loop`. Read the
# ratio off the MEDIAN within a run and anchor on the BEST across sessions -- sustained clock
# drifts ~2% between sessions, the ceiling ~0.5%. Anchor, grid 680 / batch 1024 / bpl 4 / 180s:
# -rdc best 75.15-75.24 ms, median 78.35-78.46 ms. The plain side is not loadable as built
# (-rdc alone gives the five __constant__ tables GLOBAL binding), so cubin_globalize.py flips
# the binding nibble after the fact -- verified to leave all 19,968 encoded SASS words intact.
#
# Both sides must come back 174,080 of 174,080 EXACT: the only proof the patched symbols
# actually fed the kernel, since a cubin whose constant tables were never filled still loads,
# still launches and still runs at full speed.
rdc-cubins:
	$(MAKE) cubin CUBIN_FILE=GpuCore_rdc.cubin SM=$(SM_ARCHS)
	$(NVCC) $(NVCCFLAGS) -cubin -o GpuCore_plain.cubin GpuCore.cu
	python3 cubin_globalize.py GpuCore_plain.cubin c_Gx c_Gy c_GyNeg c_Jx c_Jy c_target_words

$(TARGET): $(CPP_OBJECTS) $(CU_OBJECTS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp $(HDRS)
	$(CC) $(CCFLAGS) -c $< -o $@

%.o: %.cu $(HDRS) GpuHash.cu
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

# ---- Codegen inspection (no effect on the shipped binary), like cCUDA's ptxinfo target ----
# Each device TU is compiled separately: nvcc rejects -o together with -c for more than one
# input. GpuHash.cu is #included by GpuCore.cu, so it is covered by that TU's report.
PTXINFO_OBJS := $(GPU_SRC:.cu=-ptxinfo.o)
SASS_OBJS    := $(GPU_SRC:.cu=-sass.o)

# Verbose ptxas resource report -- registers/thread, spills, stack frame -- for every kernel,
# once per target arch, with the shipped flags so the numbers match the release build.
ptxinfo: $(GPU_SRC) $(HDRS)
	@for src in $(GPU_SRC); do \
		obj=`echo $$src | sed 's/\.cu$$/-ptxinfo.o/'`; \
		echo "==== $$src ===="; \
		$(NVCC) $(NVCCFLAGS) -Xptxas -v -c $$src -o $$obj; st=$$?; \
		rm -f $$obj; \
		[ $$st -eq 0 ] || exit $$st; \
	done

# Full SASS (device disassembly) of every kernel, freshly compiled for the selected arch(es).
sass: $(GPU_SRC) $(HDRS)
	@for src in $(GPU_SRC); do \
		obj=`echo $$src | sed 's/\.cu$$/-sass.o/'`; \
		echo "==== $$src ===="; \
		$(NVCC) $(NVCCFLAGS) -c $$src -o $$obj; st=$$?; \
		[ $$st -eq 0 ] && { $(CUOBJDUMP) -sass $$obj; st=$$?; }; \
		rm -f $$obj; \
		[ $$st -eq 0 ] || exit $$st; \
	done

clean:
	rm -f $(CPP_OBJECTS) $(CU_OBJECTS) $(TARGET) $(PTXINFO_OBJS) $(SASS_OBJS) GpuCore-rdc.o
