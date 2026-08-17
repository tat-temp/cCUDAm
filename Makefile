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

# Points-only build. `make NO_HASH=1` compiles the hash layer out of TestKernel's hot path,
# leaving the EC walk -- the batch-inversion ladder, the +/- walk and the point jump -- as the
# whole kernel. This is the reference a hand-written-SASS TestKernel has to reproduce: the SASS
# route rewrites the arithmetic and lifts the hash verbatim, so the arithmetic is what needs an
# independent, measurable baseline. See asm/TESTKERNEL_TEMPLATE.md.
#
# It CANNOT find a key. Every candidate is folded into a sink instead of hashed (GpuCore.cu), so
# `found` is never set from a match. Do not run proof.py against this build.
NO_HASH ?=
ifneq ($(strip $(NO_HASH)),)
NVCCFLAGS += -DNO_HASH=1
endif

# P3, first half -- MEASURED AND REFUTED, kept as the reproducer. `make INLINE_HASH_W2=1` drops
# __noinline__ from the hot hash entry getHash160_w2_from_limbs and lets ptxas decide; it decides
# to inline, at all four call sites. On an RTX 5090 that is 0.8-1.3% SLOWER (2,209 launches a
# side, interleaved, both sides REG 126 and 2 blocks/SM, neither spilling -- so code layout is
# the only variable). It could not have won: the recoverable overhead is 2 CALL + 2 RET per walk
# iteration against ~5,900 instructions, i.e. 0.07%, and it buys that with +60% code size.
# Default off. Do not re-litigate without reading the DEVPLAN section.
#
# A flag rather than an edit, because the whole point of P3 is that it is UNMEASURED and the
# measurement needs both sides buildable from one tree. Measured resource cost, sm_120:
#
#   shipped build   122 -> 128 registers, 0 spill either way, 9984 -> 15960 instructions
#   -rdc build      126 -> 126 registers, 0 spill either way, 10080 -> 16016 instructions
#
# 128 is exactly the __launch_bounds__(256,2) ceiling, so occupancy does NOT change and the
# spill cliff that hardening item 10 warned about is not reached. What DOES change is code size:
# one 2,021-instruction body becomes four copies, and the walk streams through two of them every
# iteration. That is the thing this trade is actually about, and it is why the flag exists rather
# than a commit flipping the attribute.
INLINE_HASH_W2 ?=
ifneq ($(strip $(INLINE_HASH_W2)),)
NVCCFLAGS += -DINLINE_HASH_W2=1
endif

# P3, second half. `make HOIST_INV_CHAIN=1` moves the walk's `inverse *= (c_Gx[i] - x1)` from the
# bottom of the loop body to the top, immediately after the dx_inv_i that reads the old value.
# `inverse` is the iteration's only loop-carried value, so this resolves the recurrence first and
# lets the point arithmetic overlap it rather than trail it. Pure reordering at source level --
# same operands, same results.
#
# MEASURED AND NULL, kept as the reproducer. On an RTX 5090 it is exactly nothing: medians
# 80.0834 against 80.0915 ms over 2,219 launches a side, B/A 1.000. ptxas schedules against the
# dependence graph of the basic block, so the source order of two independent operations is not
# a constraint it inherits -- a source-level reordering is a hint to a compiler that already has
# the information. Default off, because it is not free even at zero benefit:
#
# Hoisting extends the live ranges of `inverse` and `gxmi` across the entire point body,
# so it buys scheduling freedom with register pressure and the shipped build pays:
#
#   config                     plain regs / spill      -rdc regs / spill
#   (default)                     122 /  0                126 / 0
#   INLINE_HASH_W2=1              128 /  0                126 / 0
#   HOIST_INV_CHAIN=1             128 /  8                128 / 0
#   both                          127 / 32                128 / 0
#
# Read the two shapes apart. `-rdc` -- what `make cubin` emits and therefore what every abtest
# A/B loads -- spills in NO configuration, so the A/B measures schedule and code size cleanly.
# The plain build is what ships, and there the hoist costs 8 bytes of spill and the pair 32. A
# win in the cubin A/B therefore has to be re-checked against `make ptxinfo` before it is adopted.
HOIST_INV_CHAIN ?=
ifneq ($(strip $(HOIST_INV_CHAIN)),)
NVCCFLAGS += -DHOIST_INV_CHAIN=1
endif

CPU_SRC := cCUDAHurricane.cpp EcInt.cpp GpuPuzzle.cpp EcPoint.cpp Ec.cpp
GPU_SRC := GpuCore.cu GpuEc.cu
HDRS    := $(wildcard *.h *.cuh)

# Native cubin path. `make NATIVE_CUBIN=1` launches TestKernel through the driver
# API (CallCubin.cpp: cuModuleLoad + cuLaunchKernel) out of a prebuilt .cubin
# instead of the runtime <<<>>> launch, so a hand-written-SASS kernel can be
# swapped in without rebuilding the host. Give a path to name the file:
# `make NATIVE_CUBIN=asm/TestKernel.cubin`. Default GpuCore.cubin, which
# `make cubin` produces. The path is resolved at RUN time, relative to the
# process's working directory -- keep the cubin next to the binary.
#
# The cubin must export the five __constant__ tables, so build it with -rdc=true
# (see the `cubin` target): without it nvcc gives every device variable internal
# linkage and cuModuleGetGlobal cannot find c_Gx/c_Gy/c_Jx/c_Jy/c_target_words.
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
# libcuda is the driver library, not part of the runtime. A build host with no
# driver installed links against the stub; the real one is found at load time.
LDFLAGS     += -L$(CUDA_PATH)/lib64/stubs -lcuda
else
CUBIN_FILE := GpuCore.cubin
endif

CPP_OBJECTS := $(CPU_SRC:.cpp=.o)
CU_OBJECTS  := $(GPU_SRC:.cu=.o)

TARGET := cCUDAHurricane

.PHONY: all clean ptxinfo sass cubin nohash-cubin p3-cubins

all: $(TARGET)

# The cubin that NATIVE_CUBIN loads, built with the shipped device flags.
#
# Two steps, not one: `-rdc=true -cubin` emits a RELOCATABLE cubin (ELF type REL,
# with ~10 undefined symbols), and cuModuleLoad only accepts ET_EXEC -- so it has to
# go through a device link. -rdc=true itself is needed because without it nvcc gives
# every __device__/__constant__ variable internal linkage and cuModuleGetGlobal
# cannot find the constant tables.
#
# It is not free. -rdc stops getHash160_33/_w2 being emitted inside
# .text.TestKernel and gives them their own sections, so the device code is NOT the
# same as the default build: .text.TestKernel 0x27000 -> 0x17700 plus 0x8080 +
# 0x7e80 of hash, i.e. 159744 -> 161280 bytes total (+96 instructions, +0.96%).
# Diff against `make sass` before treating a timing difference as a real one.
#
# Single-arch only: -cubin with several -gencode flags does not produce one cubin.
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
# rcasm_test/abtest speed run and of the occupancy comparison in asm/tk/README.md.
#
# It is a target rather than a note in a README because it was neither. *.cubin is gitignored,
# so this file is not in a fresh clone; nothing in the tree said how to rebuild it; and the
# harness's error for a missing side A is CUDA_ERROR_FILE_NOT_FOUND, which names the file and
# not the command. Every measured ratio in this project has this on one side, so it has to be
# reproducible from the repo by someone who was not there when it was first built.
nohash-cubin:
	$(MAKE) cubin NO_HASH=1 CUBIN_FILE=GpuCore_nohash.cubin SM=$(SM_ARCHS)

# P3's A/B, both sides. These are FULL kernels -- hashing included -- because P3 is the only
# item that touches the 57-61% of wall clock that hashing costs, and a points-only build cannot
# see it at all. Side A is the shipped kernel and must be rebuilt from the same tree as side B,
# not carried over from an earlier session: only a same-run comparison is worth anything here.
# Four, not two: P3's two halves have different costs and must be attributable separately. The
# inline trades call overhead for +60% code size; the hoist trades a shorter loop-carried chain
# for register pressure. Bundling them leaves a combined number that cannot say which half paid
# for it -- and if they cancel, a bundled A/B reports "no effect" over two real ones.
p3-cubins:
	$(MAKE) cubin CUBIN_FILE=GpuCore_p3base.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin INLINE_HASH_W2=1 CUBIN_FILE=GpuCore_p3inl.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin HOIST_INV_CHAIN=1 CUBIN_FILE=GpuCore_p3hoist.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin INLINE_HASH_W2=1 HOIST_INV_CHAIN=1 CUBIN_FILE=GpuCore_p3both.cubin SM=$(SM_ARCHS)

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
	rm -f $(CPP_OBJECTS) $(CU_OBJECTS) $(TARGET) $(PTXINFO_OBJS) $(SASS_OBJS) GpuCore-rdc.o
