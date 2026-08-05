CUDA_PATH ?= /usr/local/cuda
NVCC      := $(CUDA_PATH)/bin/nvcc
CUOBJDUMP ?= $(CUDA_PATH)/bin/cuobjdump
CC        := g++

# Target GPU architectures (SASS): Turing (75), Ampere (86), Ada (89), Blackwell (120).
# sm_120 requires CUDA Toolkit 12.8 or newer.
# Compute mode(s) are overridable with SM (or lowercase sm), e.g. `make SM=86`,
# `make sass SM=89`, or a space-separated list `make SM="86 89"`. Empty = all archs above.
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

# Per-kernel GPU timing (CUDA events). `make TIMING=100` prints a KernelA/B/C
# millisecond + %-share breakdown every N main-loop iterations. Unset => no
# instrumentation compiled in (release build is unchanged).
TIMING ?=
ifneq ($(strip $(TIMING)),)
NVCCFLAGS += -DKERNEL_TIMING=$(TIMING)
endif

CPU_SRC := cCUDAHurricane.cpp EcInt.cpp GpuPuzzle.cpp EcPoint.cpp Ec.cpp
GPU_SRC := GpuCore.cu GpuEc.cu
HDRS    := $(wildcard *.h *.cuh)

CPP_OBJECTS := $(CPU_SRC:.cpp=.o)
CU_OBJECTS  := $(GPU_SRC:.cu=.o)

TARGET := cCUDAHurricane

.PHONY: all clean ptxinfo sass

all: $(TARGET)

$(TARGET): $(CPP_OBJECTS) $(CU_OBJECTS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp $(HDRS)
	$(CC) $(CCFLAGS) -c $< -o $@

%.o: %.cu $(HDRS) GpuHash.cu
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

# ---- Codegen inspection (no effect on the shipped binary), like cCUDA's ptxinfo target ----
# Each device TU is compiled separately: nvcc rejects -o together with -c when given more
# than one input, so these must iterate over $(GPU_SRC) rather than pass it as one list.
# GpuHash.cu is #included by GpuCore.cu, so its kernels are covered by that TU's report.
PTXINFO_OBJS := $(GPU_SRC:.cu=-ptxinfo.o)
SASS_OBJS    := $(GPU_SRC:.cu=-sass.o)

# Verbose ptxas resource report -- registers/thread, spill stores/loads, stack frame -- for
# every kernel, printed once per target arch, with the shipped flags so the numbers match
# the release build.
ptxinfo: $(GPU_SRC) $(HDRS)
	@for src in $(GPU_SRC); do \
		obj=`echo $$src | sed 's/\.cu$$/-ptxinfo.o/'`; \
		echo "==== $$src ===="; \
		$(NVCC) $(NVCCFLAGS) -Xptxas -v -c $$src -o $$obj; st=$$?; \
		rm -f $$obj; \
		[ $$st -eq 0 ] || exit $$st; \
	done

# Full SASS (device disassembly) of every kernel, freshly compiled for the selected compute
# mode(s) so `make sass SM=89` shows exactly that arch.
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
	rm -f $(CPP_OBJECTS) $(CU_OBJECTS) $(TARGET) $(PTXINFO_OBJS) $(SASS_OBJS)
