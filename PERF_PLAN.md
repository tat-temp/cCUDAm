# Performance optimization plan — branch `f1`

Target: NVIDIA RTX 5090 (sm_120, Blackwell, 170 SMs), CUDA 13.0.88. Kernel: `TestKernel`
in `GpuCore.cu`. This plan supersedes nothing in `DEVPLAN.md` (deleted, not used); all
numbers below are either measured on the 5090 by the repo's own harnesses or modelled
statically from the current SASS on branch `f1` and labelled as such.

## 1. Where the time goes (measured, grid 680)

| build | time | share |
|---|---:|---:|
| full `TestKernel` | 74.02 ms | 100% |
| points-only (`NO_HASH=1`) | 29.14 ms | 39.4% |
| **hashing (difference)** | **44.88 ms** | **60.6%** |

Hashing is 56.8% at grid 170 and 60.6% at grid 680; call it **~59%**. EC field math plus
local-memory traffic is the other **~41%**.

Per-candidate dynamic instruction budget (static model of the current build, B=1024):

| class | instr/candidate | share |
|---|---:|---:|
| hash (`getHash160_w2`) | 2010 | 74% |
| field ALU (IADD3/LOP3/SHF/…) | 365 | 13% |
| field FMA (IMAD.WIDE) | 302 | 11% |
| control + LSU + uniform | ~42 | 2% |
| **total** | **~2719** | |

The hash body is **2026 SASS instructions, pure ALU, zero memory ops**: SHF 661, IADD3 553,
LOP3 494, LEA 280, PRMT 18. It is SHA-256 (all 64 rounds) plus RIPEMD-160 trimmed to 153 of
160 rounds for word 2 — already at its algorithmic floor.

## 2. Bottleneck verdict — RESOLVED (measured 2026-09-05 on the RTX 5090)

**The full kernel is latency-bound, not pipe-bound.** Raising occupancy from 2 to 3 resident
blocks/SM (16 → 24 warps) is worth **+7.76%** even though it costs +328 SASS instructions and
79 new scalar spill ops. A kernel whose ALU pipe was saturated could not pay that price and
still win; more warps only help when the machine is waiting on latency.

- **Full kernel → latency-bound.** 74.9% of `TestKernel`'s 8128 SASS instructions are ALU-class
  (IADD3 2331, SHF 1422, LOP3 1159, LEA 584, IADD 459, MOV/ISETP/SEL 371) against 1354 IMAD on
  the separate FMA pipe — a 4.5:1 pipe imbalance. That imbalance is **not** the limiter: the
  occupancy result proves there are idle issue slots to spare.
- **Points-only kernel → memory/latency-bound.** The 16 KB/thread `subp[512][4]` local frame,
  64 B of local load/store per key. This is the 41% half of the full kernel.

Consequence for the ranking: **P1 and P3 are the right levers; P6 is chasing a bottleneck that
does not exist** and is demoted accordingly.

## 3. Ranked levers

Gains are **for the full kernel**. "Free" = runtime flag, no rebuild. Confidence is that the
gain is real and positive.

| # | lever | expected | conf. | cost | how to measure |
|---|---|---:|---:|---|---|
| P1 | **3 blocks/SM** (`BLOCKS_PER_SM=3`) | **+7.76% MEASURED** | done | 1 line | **ADOPTED** |
| P3 | **Walk-loop ILP** — interleave the ±i point work + their 2 hashes | 0 … +5% | **high** | 2–4 d | abtest + abbench |
| P5 | **Host wave-sizing** (round threads to a whole wave) | **+2.26% modelled** | high | 1–2 d | abbench.py, Prepare timing |
| P4 | **Field lazy reduction / subp prefetch** | +2 … +5% | med | 3–5 d | abtest oracle + abbench |
| P7 | **Hand-written SASS full kernel** (`asm/tk` track) | +8 … +15% | med | weeks | rcasm_test/abtest |
| P6 | ~~Hash micro-opt~~ (pipe-balance adds to IMAD) | ~0 | **very low** | 2–4 d | **demoted: not pipe-bound** |
| P2 | ~~Batch-size sweep~~ B=1024→…→64 | **0 … −4% MEASURED** | — | — | **done: negative, skip** |
| — | ~~Compiler flags~~ | ~0 | — | — | **done: negative, skip** |
| — | ~~Hoist duplicated `c_Gx[i]` load~~ | **worse** | — | — | **done: negative, skip** |

### P1 — 3 resident blocks per SM — **ADOPTED, +7.76% measured**

One line in `Defs.h`: `BLOCKS_PER_SM 2` → `3`. The full occupancy ladder, built and timed:

| blocks/SM | reg ceiling | regs used | spill st / ld | warps/SM | TestKernel instr | **median MKeys/s** | **delta** |
|---:|---:|---:|---|---:|---:|---:|---:|
| 2 (was) | 128 | 118 | 0 / 0 | 16 | 8128 | 10517 | — |
| **3 (now)** | 85 | 80 | 184 / 300 | 24 | 8456 | **11333** | **+7.76%** |
| 4 | 64 | 64 | 408 / 796 | 32 | 8824 | 10960 | +4.21% |
| 5 | 51 | 48 | 928 / 1496 | 40 | — | see §7 | — |

The peak is at 3: past it the spill traffic grows faster than the extra warps can hide it.
Every added instruction is a **32-bit scalar spill** in `TestKernel` proper — the 128-bit `subp`
accesses stay at 6 LDL / 6 STL, and `getHash160_w2_from_limbs` reports a 0-byte frame with 0
spill at *every* setting, so nothing lands in the 153-round RIPEMD body. Correctness re-verified
at 3 and 4 blocks: 17/17 planted keys plus the negative.

There is no register headroom left to claw back: 3 blocks caps at ⌊65536/(256·3)⌋ = 85 regs and
ptxas already allocates 80 (the next step down the 8-reg granularity ladder), so `-maxrregcount`
tuning cannot buy a cheaper 3-block build.

### P2 — batch-size sweep — **CLOSED, negative in both directions**

Smaller B is monotonically worse. Measured, interleaved, 3 rounds each:

| grid (B) | median MKeys/s | vs 1024 | spread |
|---|---:|---:|---:|
| **1024** | **10514** | — | 2.77% |
| 512 | 10480 | −0.32% | 1.45% |
| 256 | 10405 | −1.04% | 0.56% |
| 128 | 10292 | −2.11% | 0.29% |
| 64 | 10090 | −4.03% | 0.12% |

The premise was wrong: **`subp[MAX_BATCH_SIZE/2][4]` is statically sized**, so a smaller *runtime*
B does not shrink the 16 KB frame or improve occupancy at all — it only reduces bytes touched.
That cache win is real but far smaller than the loss from amortizing the once-per-batch inversion
over fewer keys, exactly as the ~10 → ~160 instr/key model predicted.

Larger B is closed too. The gain per doubling is halving (64→128 +2.00%, 128→256 +1.09%,
256→512 +0.72%, 512→1024 +0.32%), so 1024→2048 extrapolates to ~+0.15% — and it does not even
compile: `MAX_BATCH_SIZE` also sizes `c_Gx`/`c_Gy`/`c_GyNeg` at `(B/2)·4·8` = 16 KB each, so 2048
needs 96 KB of `__constant__` against a 64 KB bank (`ptxas error: File uses too much global
constant data (0x18060 bytes, 0x10000 max)`). Buying ~0.15% would cost moving 48 KB of tables to
global memory. **1024 is the right batch size; stop tuning this dimension.**

### P3 — walk-loop ILP

The `+i` and `-i` point computations are independent (shared `dx_inv` only) and are emitted as two
separate blocks each ending in a hash CALL, with 40 BSSY/BSYNC reconvergence pairs and 8 VOTE
filter checks in the hot path. Interleaving the two point computations — and issuing both hashes
back-to-back — exposes ILP that helps a latency-bound kernel *without* more warps. Fold the
duplicated blocks and the `i==half-1` tail into one 2-lane body. Watch register pressure (already
118). Validate bit-exact with `rcasm_test/abtest` (EXACT/NON-CANON/WRONG oracle), then abbench.

### P4 — field lazy reduction + subp prefetch

`mul_mod`/`sqr_mod` already skip the final conditional subtract (C8, results in `[0,2^256)`).
Extend laziness: keep intermediate field values non-canonical through the ladder and walk, reduce
fully only where canonical form is required (the parity byte and the hashed x-coordinate). Prefetch
`subp[i+1]` one iteration ahead into registers. Both touch only the 41% half; points-only
instruction cuts historically returned 11–16% there. Correctness risk is the parity/prefix byte
(P is odd → a non-canonical value flips bit 0) — gate every variant through `verify.py` and
`proof.py`.

### P5 — host wave-sizing + setup kernel

`GetMaxThreadsByMem` charges a phantom 16 KB/thread (`subp` is local memory, provisioned by the
driver, not a device allocation), capping threads at ~2.08M and producing ~24 waves with a
last-wave quantization loss of **0.2–2.1%** depending on the driver-reported VRAM. Size
`threadsTotal` to a whole number of waves via `cudaOccupancyMaxActiveBlocksPerMultiprocessor`
instead of the memory estimate. Separately, the setup kernel `scalarMulKernelBase` (GpuEc.cu,
double-and-add with one inversion per bit for ~2M threads) delays every `Prepare`; a Jacobian or
batch-inversion rewrite cuts that latency. A prototype patch lives under the scratchpad.

### P6 — hash micro-opt (near floor)

SHF (661/candidate) is the largest op class. A probe confirmed an opaque multiplier keeps an add
on the IMAD pipe, but it then loses IADD3 3-input and LEA.HI rotate-add fusion — likely a wash.
The hash is already rotate-hoisted, LOP3-fused and 153-round-trimmed. Expected gain is low and is
throttled ~5× by multi-warp absorption (repo-measured). Do this only if §4 shows the ALU pipe
saturated.

### Compiler flags — settled negative

The full matrix is byte-identical or worse: `-dlcm`/`-dscm`/`--extra-device-vectorization`/
`--allow-expensive-optimizations`/`-O1..O4`/`--register-usage-level` all reproduce 118 reg / 8176
instr, and CUDA 13.1 is within 8 instructions of 13.0. Do not spend time here.

### P7 — hand-written SASS (long horizon)

The `asm/tk` points-only hand-written kernel measured +22% vs compiled points-only (~8.8% on the
full program), and the RCAsm "lift the hash" result shows the hash bodies re-encode byte-identical.
A full hand-written `TestKernel` is a plausible +8–15% at weeks of effort and high risk. Gate it on
P1–P5 being exhausted and on an Nsight profile that says the compiled kernel is issue-bound.

## 4. The decision hinge — ANSWERED without the profiler

The hinge (pipe-bound vs latency-bound → P1/P3 vs P6) was settled **experimentally** by the
occupancy ladder in §7: more warps win by +7.76% while *adding* instructions, which only happens
on a latency-bound kernel. No profile was needed.

**Nsight Compute is unavailable on the current GPU host** and this is not fixable from inside it:

```
==ERROR== ERR_NVGPUCTRPERM - The user does not have permission to access
          NVIDIA GPU Performance Counters on the target device 0.
```

The container runs as root but with the stock Docker capability set (`CapEff=0xa80405fb`); bit 21
`CAP_SYS_ADMIN` is clear, and `ncu` requires it. To profile, the vast.ai instance must be
**re-created** with `--cap-add SYS_ADMIN` in its docker options — no in-container setting will do
it. Worth doing before attempting P3/P4/P7, where per-pipe and stall-reason counters would guide
the work rather than merely confirm it. The command to run once counters are available:

```bash
ncu -k TestKernel --launch-skip 4 --launch-count 1 \
  --section SpeedOfLight --section Occupancy \
  --section WarpStateStats --section MemoryWorkloadAnalysis \
  ./cCUDAHurricane --range 100000000:1FFFFFFFF --target-hash160 <no-hit> --grid 1024,512
```

| profile shows | verdict | do |
|---|---|---|
| ALU/`fma`/`lsu` pipe >80% busy, low stalls | pipe-bound | P6 (fewer hash ops); P1 will **not** help |
| pipes <60%, stalls = long-scoreboard / no-instruction | latency-bound | **P1 + P3** |
| top stall = local-memory throughput / L1 miss | memory-bound half | **P2 + P4** |

Record `sm__throughput`, `smsp__issue_active`, `sm__inst_executed_pipe_*` per pipe, warp stall
reasons, `l1tex__t_sectors_pipe_lsu_mem_local_op_{ld,st}`, `lts__t_sector_hit_rate`,
`dram__throughput`, achieved occupancy.

## 5. Measurement protocol (every change)

1. **Correctness first.** `verify.py --path ./cCUDAHurricane` (planted keys + one negative);
   for field-math changes also `rcasm_test/abtest` (EXACT/NON-CANON/WRONG) and a `proof.py` pass.
   A speed number for an unverified kernel is worth nothing.
2. **Speed.** `python abbench.py --base main --head f1 --seconds 120 --rounds 5 --grid <cfg> --verify`,
   interleaved A,B; trust the **median** (replicates to ~0.05%); anchor absolute times against the
   reference's own history (cross-session drift is several %). A delta inside the reported noise
   floor is not a result.
3. Adopt only on **registers ≤ target AND no new spill in the hash body AND correctness green AND**
   a median delta above the noise floor.

## 6. Build & environment

**Dev laptop (no GPU, cannot time anything).** Compile in WSL `Ubuntu-22.04` (CUDA 13.0.88 + g++ 11;
the `Ubuntu` distro's g++ 15 breaks CUDA's math headers). `-maxrregcount` is ignored because
`__launch_bounds__` wins — patch `BLOCKS_PER_SM` in `Defs.h` to change occupancy.

**GPU host** (vast.ai, `root@ssh8.vast.ai:15957`, working copy in `/tmp/cCUDAm`): RTX 5090
(sm_120, 170 SMs, 32 GB, 3105 MHz, persistence on), driver 580.82.09, Ubuntu 24.04.4, 128 vCPU,
**CUDA 12.8.93 + g++ 13.3**. A full rebuild is 2.3 s.

**CUDA 12.8 and 13.0 generate equivalent code**, so the static analysis transfers between the two
machines: both give `TestKernel` 118 registers, a 16384-byte stack frame and 0 spill, and the SASS
differs by 48 instructions in 8176 (0.6%). Two host-side gotchas: `python3` has no `ecdsa` (needed
by `verify.py`/`proof.py`) until `pip install ecdsa`, and copying a built tree with `cp -r` then
editing only a `.cu` leaves stale `.o` files that fail to link — `make clean` first.

## 7. Measurement log — 2026-09-05, RTX 5090

Method: each configuration run for 40 s, the binary's own `Speed:` line sampled, first two
samples dropped as warm-up, configurations **interleaved** round-robin (never all of A then all
of B), median over all rounds. Within-side spread is reported next to every number.

Thermal ramp is real and it is why interleaving matters: the very first run of a session read
10700–10848 MKeys/s, and every warm run afterwards read 10516–10517. **The honest baseline is
10517 MKeys/s, not the ~10800 a naive first measurement gives.** Cross-run drift on an identical
binary was 0.33% (lb3 measured 11333 and 11370 in two separate sessions), so treat anything under
~0.5% as noise.

**Occupancy ladder (P1)** — grid `1024,512`, 3 rounds:

| blocks/SM | regs | spill st / ld | warps/SM | median MKeys/s | spread | vs baseline |
|---:|---:|---|---:|---:|---:|---:|
| 2 | 118 | 0 / 0 | 16 | 10517 | 1.84%¹ | — |
| **3** | 80 | 184 / 300 | 24 | **11333** | 0.67% | **+7.76%** |
| 4 | 64 | 408 / 796 | 32 | 10960 | 0.17% | +4.21% |
| 5 | 48 | 928 / 1496 | 40 | 10576 | 0.26% | +0.56% |

¹ inflated by the cold first round; warm rounds were 10517 and 10516.

**Batch-size sweep (P2)** — see §3, monotonically negative, 1024 is optimal.

**Rejected micro-optimization.** `load4_const(px_i, &c_Gx[i*4])` is issued twice per walk
iteration, once in the `+i` block and once in `−i`, for the identical value. Hoisting it to a
single shared load made everything worse: **118 → 122 registers, 8128 → 8304 instructions, and
LDC 37 → 40** — the metric it targeted moved the wrong way. The reason is that `px_i` must then
stay live across block A's non-inlined `getHash160_w2_from_limbs` **CALL**, so it is saved and
restored around the call; re-loading from constant memory afterwards is cheaper. The compiler was
rematerializing correctly, not missing a CSE. Do not revisit.

**Still open.** P3 (walk-loop ILP) is now the top candidate: each ±i block is a strictly serial
6-deep field chain (`sub→mul→sqr→sub3→sub→mul`) and the two chains are independent apart from the
shared `dx_inv_i`, so interleaving them doubles ILP without needing more warps — the right shape
of fix for a kernel just proven latency-bound. The cost to watch is ~24 extra live registers for
the duplicated `px3`/`s`/`lam` temporaries, against a budget that is now 80, not 118.
