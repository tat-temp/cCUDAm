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

.PHONY: all clean ptxinfo sass cubin nohash-cubin rdc-cubins

all: $(TARGET)

# The cubin that NATIVE_CUBIN loads, built with the shipped device flags.
#
# Two steps, not one: `-rdc=true -cubin` emits a RELOCATABLE cubin (ELF type REL,
# with ~10 undefined symbols), and cuModuleLoad only accepts ET_EXEC -- so it has to
# go through a device link. -rdc=true itself is needed because without it nvcc gives
# every __device__/__constant__ variable internal linkage and cuModuleGetGlobal
# cannot find the constant tables.
#
# It is not free, and as of 2026-08-26 the price is measured rather than counted:
# 0.38% of wall clock sustained (1.36% at peak clock) -- see `rdc-cubins` below.
# -rdc stops getHash160_33/_w2 being emitted inside .text.TestKernel and gives them
# their own sections, so the device code is NOT the same as the default build:
# .text.TestKernel 0x27000 -> 0x17700 plus 0x8080 + 0x7e80 of hash, i.e.
# 159744 -> 161280 bytes total (+96 instructions, +0.96%) and REG 122 -> 126.
# Occupancy is unaffected -- both are under the __launch_bounds__(256,2) ceiling of
# 128 and neither spills -- so what the 0.38% buys is code layout.
#
# It costs the NO_HASH build NOTHING: same REG 128, one .text section either way, and
# 5,520 instructions against plain's 5,528. With the hash compiled out there is nothing
# to out-line. So GpuCore_nohash.cubin -- side A of every points-only A/B in this repo --
# carries no -rdc bias, and those ratios stand as measured.
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

# What -rdc=true costs the SHIPPED kernel. MEASURED, 2026-08-26: 0.38% sustained and 1.36%
# at peak clock, two runs of ~2,230 launches a side, both sides 174,080/174,080 EXACT.
#
#   ./abtest ../../GpuCore_rdc.cubin ../../GpuCore_plain.cubin 174080 180s loop
#
#              A -rdc          B plain         B/A best   B/A median
#   run 1      75.2346/78.3519 74.1165/78.0045   0.985      0.996
#   run 2      75.1508/78.4621 74.2316/78.2083   0.988      0.997
#
# The best and the median disagree by ~1% REPRODUCIBLY (1.0% and 0.9%), so that gap is a
# result and not noise: B's lead shrinks as the card derates, which puts the mechanism on the
# core-clock side -- instruction fetch, where keeping both hash bodies inside the kernel's own
# section pays. Quote the MEDIAN; the shipped program runs 14-27 s launches and never sees a
# best. Kept as a target because the pair has to be rebuildable from one tree.
#
# THIS COMPARISON WAS NOT BUILDABLE UNTIL NOW, and the reason is circular: -rdc's only
# purpose here is to give the five __constant__ tables GLOBAL binding, so the cheaper build
# is exactly the one the harness cannot load. cubin_globalize.py breaks the circle by
# flipping the binding nibble after the fact -- 10 bytes, 5 symbols x 2 symbol tables,
# verified to leave all 19,968 encoded SASS words untouched. See that file for why not
# reordering the symbol table is correct rather than merely convenient.
#
# What actually differs between the two sides, from `cuobjdump` on both:
#
#   A  -rdc   REG 126   .text.TestKernel 6,000 instr + two hash sections   10,080 total
#   B  plain  REG 122   .text.TestKernel 9,984 instr, hash bodies inside    9,984 total
#
# So it is +4 registers and +96 instructions, but the interesting variable is CODE LAYOUT:
# -rdc moves getHash160_33/_w2 out of the kernel's own section. Both are under the
# __launch_bounds__(256,2) ceiling of 128 and neither spills, so occupancy is held equal by
# construction and layout is most of what is left.
#
# THE ANCHOR TO CHECK AGAINST IS THE BEST, NOT THE MEDIAN, and this pair is what established
# that. Side A is byte-identical to GpuCore_p3base, which on 2026-08-17 gave a median of
# 80.0835/80.0915/80.0667/80.0824 ms -- a 0.031% spread that looked like the tightest anchor
# in the project. Nine days later the same binary gave 78.3519 and 78.4621: 0.14% from each
# other and 2.1% from that anchor, with GpuCore.cu unchanged bar a comment, the same CUDA
# 13.0 and EIATTR_REGCOUNT still 126. A healthy card's SUSTAINED clock drifts; its ceiling
# barely does. Across all three sessions A's best is 75.5450/75.2346/75.1508 -- 0.52% -- while
# its median spans 2.19%. So: anchor on the best across sessions, read the ratio off the
# median within a run. Current anchor, grid 680 / batch 1024 / bpl 4 / 180s:
#
#   full kernel, -rdc     best 75.15-75.24 ms     median 78.35-78.46 ms
#
# Both sides must come back 174,080 of 174,080 EXACT. That is not a formality on this pair:
# it is the only thing that proves the patched symbols actually fed the kernel, since a
# cubin whose constant tables were never filled still loads, still launches and still runs
# at full speed. A cuModuleGetGlobal that fails is caught earlier and louder by abtest.
rdc-cubins:
	$(MAKE) cubin CUBIN_FILE=GpuCore_rdc.cubin SM=$(SM_ARCHS)
	$(NVCC) $(NVCCFLAGS) -cubin -o GpuCore_plain.cubin GpuCore.cu
	python3 cubin_globalize.py GpuCore_plain.cubin c_Gx c_Gy c_Jx c_Jy c_target_words

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
