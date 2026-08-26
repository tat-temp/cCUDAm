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
# MEASURED AND NULL, twice, kept as the reproducer. On an RTX 5090 it is exactly nothing: B/A
# 1.000 on the median in two independent runs of ~2,200 launches a side, and 1.000 on the best in
# the second. It is zero in combination with INLINE_HASH_W2 too -- both together cost what the
# inline costs alone. ptxas schedules against the dependence graph of the basic block, so the
# source order of two independent operations is not a constraint it inherits; a source-level
# reordering is a hint to a compiler that already has the information.
#
# The zero is measured, not assumed: side A's median reproduced to 0.031% across four separate
# invocations of the harness, so it resolves far below the effect being asked about.
#
# Default off, because it is not free even at zero benefit:
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

# P2. `make MAX_BATCH=256` sizes the kernel for a 256-key batch instead of 1024, which shrinks
# TestKernel's subp[] local frame 16 KB -> 4 KB per thread and the c_Gx/c_Gy constant tables
# 16 KB -> 4 KB each. Defs.h guards the default with #ifndef, so this is the whole of the change.
#
# P2 as filed BUNDLES TWO CHANGES, and they have to be separated or the result cannot be read.
# MAX_BATCH_SIZE is both the size of the frame and the ceiling on the run-time batch, so building
# at 256 forces the batch to 256 as well -- but the frame is compile-time and the batch is the
# `batch_size` kernel argument, so they move independently and can be measured apart:
#
#   the FRAME  changes what is ALLOCATED: 16 KB -> 4 KB per thread, and with it the driver's
#              local reservation, which is P2's original complaint (4.28 GB) and a capacity
#              matter rather than a speed one. At a FIXED batch it does not change which bytes
#              the kernel touches -- both cubins at batch 256 write and read the same subp[0..127]
#              -- so the honest prediction is that it is worth nothing on the clock, and what is
#              actually being tested is whether the unused tail of the allocation costs anything
#              anyway (page-table reach, a different stride through L2). Predicting nil and
#              measuring it is the point; this session has already had two offline predictions
#              about P3 come out backwards.
#
#   the BATCH  changes what is TOUCHED: at 1024 a thread rounds 16 KB of local memory between the
#              ladder and the walk, and 512 resident threads per SM make that 8 MB of live local
#              data; at 256 it is 2 MB. That is the reuse-distance claim, and it is the half with
#              a mechanism behind it. It is not free -- one inv_mod (890 instructions) per batch
#              is 0.87 instructions per key at 1024 and 3.5 at 256.
#
# Neither half reduces TRAFFIC: subp[] is written once and read once per key either way, 32 B/key.
# Anyone expecting a bandwidth win here is expecting the wrong thing.
MAX_BATCH ?=
ifneq ($(strip $(MAX_BATCH)),)
NVCCFLAGS += -DMAX_BATCH_SIZE=$(MAX_BATCH)
endif

# P6's probe. `make SUBP_WRAP=32` masks every subp[] index to the low 32 slots -- deliberately
# wrong arithmetic, holding the instruction stream and the memory-op count fixed while shrinking
# the WORKING SET. See the long note at the flag in GpuCore.cu for what it isolates and why P2's
# 4 KB step could not have shown it. Must be a power of two. 512 is the identity on [0,511] and
# is therefore both the matched baseline and arithmetically correct.
SUBP_WRAP ?=
ifneq ($(strip $(SUBP_WRAP)),)
NVCCFLAGS += -DSUBP_WRAP=$(SUBP_WRAP)
endif

# P6's cost half. `make SUBP_PASSES=2` adds two extra chunk-product passes -- the ladder's
# arithmetic with the stores removed, which is exactly what multi-level batch inversion pays for
# its smaller buffer. NO_HASH only (it escapes through that build's sink). Paired with SUBP_WRAP
# it simulates a multi-level kernel's wall clock before the real arithmetic is written.
SUBP_PASSES ?=
ifneq ($(strip $(SUBP_PASSES)),)
NVCCFLAGS += -DSUBP_PASSES=$(SUBP_PASSES)
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

.PHONY: all clean ptxinfo sass cubin nohash-cubin p2-cubins p3-cubins rdc-cubins subp-cubins ml-cubins

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

# P3's A/B, both sides. These are FULL kernels -- hashing included -- because P3 is the only
# item that touches the 57-61% of wall clock that hashing costs, and a points-only build cannot
# see it at all. Side A is the shipped kernel and must be rebuilt from the same tree as side B,
# not carried over from an earlier session: only a same-run comparison is worth anything here.
# Four, not two: P3's two halves have different costs and must be attributable separately. The
# inline trades call overhead for +60% code size; the hoist trades a shorter loop-carried chain
# for register pressure. Bundling them leaves a combined number that cannot say which half paid
# for it -- and if they cancel, a bundled A/B reports "no effect" over two real ones.
# P2's A/B, and ONE run answers both of its questions.
#
#   ./abtest GpuCore_b1024.cubin GpuCore_b256.cubin 174080 180s loop 256
#
#   B vs A in that run    -- both at batch 256, so the FRAME is the only variable.
#   A vs the anchor       -- side A is byte-identical to GpuCore_p3base, so side A's own number
#                            here IS the batch-size effect. STALE AS WRITTEN: this read
#                            "A vs 80.07-80.09 ms" from the four P3 runs, and that median moved
#                            2.1% by 2026-08-26 on an unchanged binary and an unchanged toolkit.
#                            Anchor on the BEST across sessions (75.15-75.55 ms, 0.52% over three
#                            sessions) and re-take the median anchor in the same session as any
#                            comparison that leans on it. See `rdc-cubins` for the evidence.
#
# That second comparison is why the four P3 runs were worth their wall clock beyond P3 itself,
# and it is the first time this project has cashed in the reproducibility rather than just noting
# it. GpuCore_b1024 is built under its own name rather than reusing GpuCore_p3base because a
# measurement whose side A is named after a different experiment is one someone will mis-cite.
p2-cubins:
	$(MAKE) cubin CUBIN_FILE=GpuCore_b1024.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin MAX_BATCH=256 CUBIN_FILE=GpuCore_b256.cubin SM=$(SM_ARCHS)

p3-cubins:
	$(MAKE) cubin CUBIN_FILE=GpuCore_p3base.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin INLINE_HASH_W2=1 CUBIN_FILE=GpuCore_p3inl.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin HOIST_INV_CHAIN=1 CUBIN_FILE=GpuCore_p3hoist.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin INLINE_HASH_W2=1 HOIST_INV_CHAIN=1 CUBIN_FILE=GpuCore_p3both.cubin SM=$(SM_ARCHS)

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

# P6's probe series: does crossing the L2 boundary do anything? Four points, one variable.
# NO_HASH on every rung -- the traffic under test is the EC walk's, and the hash layer would
# dilute the effect by 60% for nothing. Side A is ALWAYS w512.
#
#   ./abtest ../../GpuCore_w512.cubin ../../GpuCore_w128.cubin 174080 180s loop
#   ./abtest ../../GpuCore_w512.cubin ../../GpuCore_w32.cubin  174080 180s loop
#   ./abtest ../../GpuCore_w512.cubin ../../GpuCore_w8.cubin   174080 180s loop
#
# RUN AT THE DEFAULT BATCH (1024) -- do not pass a batch argument. w512's correctness depends
# on `i & 511` being the identity over [0, half-1], which holds only while half == 512. At any
# smaller batch side A is wrong too and the series loses its anchor.
#
# w512 is the identity mask, so it must report 174,080/174,080 EXACT and its median is an
# absolute anchor across the three runs -- if it drifts, the session moved and the ratios go
# with it. w128/w32/w8 are WRONG BY CONSTRUCTION and the harness will say so; that is the
# expected reading, exactly as the id/local rungs of the SASS ladder are read for launch
# success only. Only the timing column means anything on those three.
#
# VERIFIED OFFLINE, and the isolation is the tightest in this repo. All four rungs: 5,496
# instructions, REG:128, STACK:16384, 6 LDL / 4 STL / 22 LDC.64, and instruction text identical
# once hex is stripped. The entire difference is FIVE immediates -- ptxas folded the wrap into
# the byte offset, so one LOP3 per access site carries 0x3fe0 (511*32), 0x3e0 (31*32) or 0xe0
# (7*32). The frame stays 16 KB on every rung, so P2's frame variable is held constant too and
# only the TOUCHED range moves. For comparison the stall dose changed 3,246 encoded words.
#
# What the answer decides. A flat series kills multi-level batch inversion outright: the
# +10-23% instruction cost buys nothing and P2's verdict generalises after all. A step down
# between w128 and w32/w8 sizes the prize, and the decision is then arithmetic -- two-level
# reaches 48 slots for ~+10%, three-level 24 slots for ~+23%, both at zero register cost
# (the kernel has exactly ONE spare register, R125, so nothing can move into them).
subp-cubins:
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=512 CUBIN_FILE=GpuCore_w512.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=128 CUBIN_FILE=GpuCore_w128.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=32  CUBIN_FILE=GpuCore_w32.cubin  SM=$(SM_ARCHS)
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=8   CUBIN_FILE=GpuCore_w8.cubin   SM=$(SM_ARCHS)

# P6, the whole trade in one run. MEASURED 2026-08-27: the wrap series priced the BENEFIT at
# 0.5% (340 MB) / 9.5% (85 MB) / 14.1% (21 MB) on the median, side A holding to 0.58% across
# the three. Multi-level batch inversion is how you would actually reach those footprints, and
# it is not free -- one extra chunk-product pass per level. These two rungs carry BOTH halves,
# so the net is measurable before the real arithmetic is written:
#
#   ./abtest ../../GpuCore_w512.cubin ../../GpuCore_ml2.cubin 174080 180s loop
#   ./abtest ../../GpuCore_w512.cubin ../../GpuCore_ml3.cubin 174080 180s loop
#
#   ml2   one extra pass    +272 static, +11.2% dynamic    wrap 32 -> 85 MB
#   ml3   two extra passes  +544 static, +22.4% dynamic    wrap 32 -> 85 MB
#
# ml2 IS THE ANSWER RUNG, and ml3 is a stress bound -- which is the opposite of how the names
# read, so: a real three-level scheme does NOT pay two full passes. Its level-1 recompute is
# 448 multiplies and its level-2 recompute only 56, so three-level costs about ONE extra pass
# plus a rounding error, the same as two-level. ml3 doubles the expensive pass and is therefore
# a pessimistic ceiling on both schemes, not a model of either.
#
# Footprint is pessimistic too. Both rungs are held at wrap 32 (85 MB, where the benefit
# measured 9.5%) because the probe cannot express a non-power-of-two mask, while the real
# schemes need 48 slots (~128 MB) and 24 slots (~64 MB). Three-level's true footprint is
# SMALLER than what ml2 simulates, so its benefit is understated here by roughly 1.5 points.
#
# Both errors point the same way -- against the change -- so a win on ml2 is a floor.
#
# VERIFIED OFFLINE: ml2 +272 and ml3 +544 instructions, exactly 2x, both REG:128 STACK:16384
# with no spill and 6 LDL / 4 STL identical to w512, so occupancy and memory-op count are held
# and the added work is pure ALU. The passes are written out rather than looped: under a
# `for (p...)` nvcc kept one body and a trip counter (+280 for two passes against +272 for one)
# and the static count could not tell two passes from one.
#
# Same reading rules as the wrap series: both report EXACT and it means nothing, timing is the
# whole signal, and side A must hold near its 34.57-34.78 ms band from the first three runs.
# B/A < 1 means the trade nets out and multi-level is worth building. B/A > 1 kills it, and
# kills it BEFORE anyone rewrites the one part of this kernel that took a ten-rung ladder to
# verify.
#
# ml2 MEASURED 2026-08-27: B/A 0.996 median, 1.024 best. Side A landed at 34.8801 median /
# 31.4004 best, holding its band to 0.89% over four runs, so the run is comparable. Read off
# the median per the -rdc rule: THE EXTRA PASS IS FREE, and the trade nets 9.5% - (0 to 2.4%)
# = 7.1-9.5% in favour. Multi-level batch inversion is worth building.
#
# The best/median split reverses the -rdc pair's sign and that is what makes it readable: there
# B had FEWER instructions and led 1.5% at best against 0.4% at median; here B has MORE and
# loses 2.4% at best against 0% at median. Instruction-count differences show at peak clock and
# compress as the card derates. The shipped program runs sustained, so 0.996 is the operational
# number and 1.024 is the conservative bound.
#
# ml3 IS STILL WORTH RUNNING, now as a margin test rather than a decision: if two passes are
# also absorbed, the absorption budget has room and a level count is not what constrains the
# design. If ml3 costs roughly 2x ml2's best-case 2.4%, the budget is at its edge and the
# scheme should stay two-level.
ml-cubins:
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=512 CUBIN_FILE=GpuCore_w512.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=32 SUBP_PASSES=1 CUBIN_FILE=GpuCore_ml2.cubin SM=$(SM_ARCHS)
	$(MAKE) cubin NO_HASH=1 SUBP_WRAP=32 SUBP_PASSES=2 CUBIN_FILE=GpuCore_ml3.cubin SM=$(SM_ARCHS)

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
