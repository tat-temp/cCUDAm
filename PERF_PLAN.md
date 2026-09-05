# Performance optimization plan — branch `f1`

Target: NVIDIA RTX 5090 (sm_120, Blackwell, 170 SMs); GPU host `nvcc` **13.3.73** (§P1–§P3 were
measured under 12.8.93 — see the §7 addendum), laptop 13.0.88. Kernel: `TestKernel`
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

## 2. Bottleneck verdict — a latency-hiding / register-pressure balance point, and the shipping setting sits on it

**Occupancy has an interior optimum at 16 warps/SM, and the shipping setting sits exactly on it.**
An earlier revision called the curve "monotonically decreasing in warps"; that is only the right-hand
half. Driving occupancy *below* 16 — reachable by relaxing `__launch_bounds__`, which lets ptxas take
140 registers and so fit fewer blocks — is much worse than raising it:

| warps/SM | how | registers | spill st / ld | MKeys/s | delta |
|---:|---|---:|---|---:|---:|
| 8 | `__launch_bounds__(256,1)` → 1 blk | 140 | 0 / 0 | 10782 | **−6.63%** |
| 12 | `__launch_bounds__(128,2)` → 3 blk | 140 | 0 / 0 | 11420 | −1.10% |
| **16 (shipping)** | `(256,2)` → 2 blk | 122 | 0 / 0 | **11546** | — |
| 24 | `(256,3)` → 3 blk | 80 | 184 / 300 | 11371 | −1.44% |
| 32 | `(256,4)` → 4 blk | 64 | 408 / 796 | 11366 | −1.49% |
| 40 | `(256,5)` → 5 blk | 48 | 928 / 1496 | ~10576 | ~−8% |

The two sides fail for **different** reasons, which is why the peak is where it is. Above 16 warps
the register ceiling collapses and ptxas spills. Below 16 there are no spills at all — the 8-warp
build gets 140 registers and the cleanest per-thread code of any variant here — and it still loses
6.6%, because there is not enough parallelism to hide the latency. The kernel is sitting on the
**balance point between latency hiding and register pressure**, and every direction off it is
downhill.

On the right-hand side a third explanation was also in play and had to be ruled out: 2 → 3 blocks/SM
raises the resident local footprint per SM by 50% *as well as* forcing ptxas from 122 registers down
to 80. P4 separates the two. Holding the instruction stream byte-for-byte fixed and cutting the frame
from 16 KB to 256 B, the small-frame build at 3 blocks/SM **still loses 1.93%** to its own 2-block
build, with identical registers and identical spills on both sides. **Footprint is not what makes
extra warps unprofitable — the register ceiling is.** It is a real but small second-order cost, worth
at most 4.13% in total and unreachable in practice (§P4).

- **Instruction mix is not the limiter.** 78.6% of `TestKernel`'s 8304 SASS instructions are
  ALU-class (IADD 2210, SHF 1422, LOP3 1243, IADD3 597, LEA 584, MOV/SEL/ISETP 425) against 1354
  IMAD (16.3%) on the separate FMA pipe — a 4.8:1 imbalance. Rebalancing it (P6) is still not
  indicated: the ALU pipe is not saturated, and neither is memory.
- **The 41% points-only half** carries the 16 KB/thread local frame and 64 B of local load/store
  per key. That traffic is real — removing it entirely is worth 4.13% — but it is *not* the wall,
  and no algorithm reachable from here removes it (§P4).

> **Correction.** An earlier revision of this document claimed the opposite — that the kernel is
> latency-bound, and that 3 blocks/SM was worth **+7.76%**. That was wrong, and it was committed
> and pushed before being caught. It came from comparing against a 2-block build that measured
> 10517 MKeys/s and reported 118 registers; no rebuild from the same source reproduces that binary
> (every one gives 122 registers and ~11530 MKeys/s). The anomalous baseline turned a 1.57%
> regression into an apparent 7.76% win. Full detail in §7.

## 3. Ranked levers

Gains are **for the full kernel**. "Free" = runtime flag, no rebuild. Confidence is that the
gain is real and positive.

| # | lever | expected | conf. | cost | how to measure |
|---|---|---:|---:|---|---|
| P1 | ~~3 blocks/SM~~ (`BLOCKS_PER_SM=3`) | **−1.57% MEASURED** | done | — | **REVERTED: regression** |
| P3 | ~~Walk-loop ILP~~ — interleave the ±i point work | **−0.19% MEASURED** | done | — | **done: no gain, reverted** |
| P5 | ~~Host wave-sizing~~ (round threads to a whole wave) | **−0.13% MEASURED** | done | done | **done: neutral, kept for exactness** |
| P4 | ~~Shrink the per-thread `subp` frame~~ (two-level ladder) | **−0.38 … −1.70% MEASURED** | done | — | **done: negative, reverted** |
| P8 | ~~Block size~~ `THREADS_PER_BLOCK` 256 → 128 / 64 / 512 | **−0.17 … −0.22% MEASURED** | done | — | **done: non-dimension** |
| P9 | ~~Lower occupancy~~ (8 / 12 warps/SM, 140 regs, no spill) | **−6.63 / −1.10% MEASURED** | done | — | **done: 16 warps is the peak** |
| P7 | **Hand-written SASS full kernel** (`asm/tk` track) | +8 … +15% | med | weeks | rcasm_test/abtest |
| P6 | ~~Hash micro-opt~~ (pipe-balance adds to IMAD) | ~0 | **very low** | 2–4 d | **demoted: not pipe-bound** |
| P2 | ~~Batch-size sweep~~ B=1024→…→64 | **0 … −4% MEASURED** | — | — | **done: negative, skip** |
| — | ~~Compiler flags~~ | ~0 | — | — | **done: negative, skip** |
| — | ~~Hoist duplicated `c_Gx[i]` load~~ | **worse** | — | — | **done: negative, skip** |

### P1 — occupancy — **REVERTED. `BLOCKS_PER_SM=2` was already optimal.**

Raising occupancy is a **regression**, confirmed over 4 interleaved rounds with nothing else
running on the box:

| blocks/SM | reg ceiling | regs used | spill st / ld | warps/SM | **median MKeys/s** | **delta** |
|---:|---:|---:|---|---:|---:|---:|
| **2 (shipping)** | 128 | 122 | 0 / 0 | 16 | **11533** | — |
| 3 | 85 | 80 | 184 / 300 | 24 | 11352 | **−1.57%** |
| 4 | 64 | 64 | 408 / 796 | 32 | ~10960 | ~−5% |
| 5 | 51 | 48 | 928 / 1496 | 40 | ~10576 | ~−8% |

Warm rounds for the top pair: 2 blocks 11535 / 11504 / 11512, 3 blocks 11357 / 11346 / 11351.
Spreads are 1.51% and 0.55%; the gap sits far outside both.

Two mechanisms compound, both pointing the same way. The 16 KB/thread local frame means 3 blocks
raises the resident footprint per SM by 50%; and the register ceiling falls from 128 to
⌊65536/(256·3)⌋ = 85, so ptxas drops 122 → 80 and starts spilling. There is no register headroom
to reclaim — 80 is already the next step down the 8-register granularity ladder from 85 — so
`-maxrregcount` cannot buy a cheaper 3-block build. The lever simply points the wrong way.

**This was retried with a smaller frame, and it still loses.** The earlier revision of this
section assumed occupancy and footprint were coupled and deferred the question. They are not:
with the frame cut to 256 B and the instruction stream unchanged, 3 blocks/SM is still −1.93%
against its own 2-block build (§P4). Above 16 warps the register ceiling is the whole story, and
it cannot be re-opened by anything that does not first cut registers below 85 — 80 is already the
next step down the 8-register granularity ladder from 85.

**The other direction is closed too, and harder.** Relaxing `__launch_bounds__` to `(256,1)` lets
ptxas take 140 registers with *zero* spill — the cleanest per-thread code of any build measured —
and drops residency to 1 block, 8 warps/SM. It loses **6.63%**. `(128,2)` gives 140 registers at
12 warps and loses 1.10%. So the occupancy curve is not monotone: it peaks at 16 warps and falls
away on both sides, for opposite reasons (§2). **Occupancy is closed in both directions**, and the
shipping setting is the maximum, not a corner.

### P8 — block size (`THREADS_PER_BLOCK`) — **CLOSED, a non-dimension**

The one launch parameter never swept. Holding warps/SM and the register ceiling fixed at the
shipping values (512 threads/SM, ceiling 128, 122 registers, 0 spills in **all four** builds), only
the block shape changes. Grid pinned to 1 566 720 threads for every variant, wave-exact at each
geometry. All four pass `verify.py` 17/17:

| `__launch_bounds__` | threads/block | blocks launched | MKeys/s | delta |
|---|---:|---:|---:|---:|
| **(256, 2) shipping** | 256 | 6 120 | **11547** | — |
| (128, 4) | 128 | 12 240 | 11527 | −0.17% |
| (64, 8) | 64 | 24 480 | 11522 | −0.22% |
| (512, 1) | 512 | 3 060 | 11526 | −0.18% |

A 4× spread in block size and an 8× spread in block count move throughput by 0.22%. Every non-256
variant sits a consistent ~0.2% low, which is at the noise floor and in any case the wrong sign.
Block granularity does not matter to this kernel: the walk is per-thread, the only warp-level
operations are `__ballot_sync`/`__any_sync` within a warp, and there is no `__syncthreads` for a
larger block to amortize. **Leave `THREADS_PER_BLOCK` at 256.**

Two things worth separating, because `--grid A,B` invites confusing them with the launch bounds:
`--grid 128,4` is a *runtime* setting — batch size 128 and a 4-blocks/SM cap, i.e. a 680-block grid
— and measures **−3.73%**, which is P2's known −2.11% for B=128 plus ~−1.6% for a grid too small
(2 waves) to cover its own tail. It is not the same experiment as `__launch_bounds__(128,4)`.

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
B does not shrink the 16 KB frame or improve occupancy at all. It does not even reduce bytes
touched *per key* — the ladder writes and reads one 32-byte entry per two keys at every B, so the
32 B/key of local traffic is invariant. What is left is pure loss: the once-per-batch inversion
amortizes over fewer keys.

§P4 closes the remaining half of this question by rebuilding with a smaller *compile-time*
`MAX_BATCH_SIZE`, which the sweep above could not vary. Shrinking the frame from 16 KB to 8 KB at
identical arithmetic is worth **+0.03%**. **1024 is the right batch size, statically and at
runtime; stop tuning this dimension.**

Larger B is closed too. The gain per doubling is halving (64→128 +2.00%, 128→256 +1.09%,
256→512 +0.72%, 512→1024 +0.32%), so 1024→2048 extrapolates to ~+0.15% — and it does not even
compile: `MAX_BATCH_SIZE` also sizes `c_Gx`/`c_Gy`/`c_GyNeg` at `(B/2)·4·8` = 16 KB each, so 2048
needs 96 KB of `__constant__` against a 64 KB bank (`ptxas error: File uses too much global
constant data (0x18060 bytes, 0x10000 max)`). Buying ~0.15% would cost moving 48 KB of tables to
global memory. **1024 is the right batch size; stop tuning this dimension.**

### P3 — walk-loop ILP — **IMPLEMENTED, MEASURED, REVERTED**

The `+i` and `-i` chains are independent apart from `dx_inv_i`, each a strictly serial 6-deep
sequence (`sub→mul→sqr→sub3→sub→mul`), so interleaving them should hand the scheduler two ready
chains instead of one. It was implemented in full: both chains issued interleaved, `c_Gx[i]` loaded
once instead of twice (safe here, since both uses precede both hash CALLs), and the two filter
checks merged into a single warp vote. It passes 17/17 including batch-boundary, tail-block and
parity cases, and compiles on the `NO_HASH` path.

**It buys nothing.**

| configuration | vs its own control |
|---|---:|
| ILP at 2 blocks/SM (both spill-free) | **−0.19%** |
| ILP at 3 blocks/SM (spill 264/592 vs 184/300) | **−2.60%** |

The equal-occupancy, zero-spill comparison is the honest one, and it says the interleave is
neutral-to-slightly-negative. **The ILP the scheduler needed was already there** — it was
extracting it across the two blocks by itself, and hand-interleaving only added register pressure
(122 → 128 unconstrained; forced spills when squeezed to 80).

What the SASS confirmed did work, without helping: LDC 15 → 13, VOTE 10 → 8. What did not move:
BSSY/BSYNC stayed at 44 pairs, so the reconvergence cost is dominated by something other than the
two filter checks. Instructions went 8456 → 8568.

### P4 — shrink the per-thread `subp` frame — **IMPLEMENTED, MEASURED, REVERTED**

The 16 KB/thread `subp[512][4]` frame was the last untested structural lever, and §2 pointed at
it. It is now closed in three steps: measure the ceiling, try to reach it, and explain the gap.

#### Step 1 — the ceiling is +4.13%, and it is measured, not modelled

Before writing an algorithm, find out what the frame is worth *if the arithmetic to shrink it
were free*. A 12-line probe does that: keep every store and every load, wrap the index, shrink
the array.

```c
#ifdef FRAME_PROBE
#define SUBP_N   (FRAME_PROBE)
#define SUBP(k)  subp[(k) & (FRAME_PROBE - 1)]
#else
#define SUBP_N   (MAX_BATCH_SIZE / 2)
#define SUBP(k)  subp[k]
#endif
```
with `subp[SUBP_N][4]` and every use routed through `SUBP(...)`. The build computes **wrong
keys** and cannot find one — that is the point. It performs all 511 stores and 512 loads into a
small hot window, so the instruction stream is untouched and only the working set moves. ptxas
confirms the isolation is exact:

| build | frame | registers | spill st/ld | SASS instr | **MKeys/s** | delta |
|---|---:|---:|---|---:|---:|---:|
| base | 16384 B | 122 | 0 / 0 | 8304 | 11540 | — |
| `FRAME_PROBE=128` | 4096 B | 120 | 0 / 0 | 8304 | 11697 | +1.38% |
| `FRAME_PROBE=32` | 1024 B | 120 | 0 / 0 | 8304 | 11950 | +3.55% |
| `FRAME_PROBE=8` | 256 B | 120 | 0 / 0 | 8304 | **12018** | **+4.14%** |

Same instruction count, same zero spills, 2 registers apart. **4.13% is the hard ceiling on
every footprint idea in this document**, and it is strongly sub-linear — you have to get under
~1 KB to collect most of it.

#### Step 2 — the occupancy question P1 deferred, answered

§P1 said "do not retry occupancy without first shrinking the frame". Done, with the probe:

| build | frame | blk/SM | registers | spill st/ld | MKeys/s | vs base |
|---|---:|---:|---:|---|---:|---:|
| base | 16384 B | 2 | 122 | 0 / 0 | 11538 | — |
| base | 16496 B | 3 | 80 | 184 / 300 | 11371 | −1.44% |
| probe | 256 B | 2 | 120 | 0 / 0 | **12014** | **+4.13%** |
| probe | 368 B | 3 | 80 | 184 / 300 | 11782 | +2.12% |
| probe | 432 B | 4 | 64 | 408 / 796 | 11366 | −1.49% |

At 3 blocks/SM the 256 B build and the 16 KB build carry *identical* registers and *identical*
spills, so this isolates footprint cleanly. Going 2 → 3 blocks costs **−1.93%** even with a
256 B frame. Footprint was never the reason occupancy failed. **Occupancy is closed.**

#### Step 3 — the real algorithm, and why it cannot reach the ceiling

Implemented in full: a **two-level (checkpointed) batch inversion**. Keep one checkpoint per
chunk of `LADDER_T` instead of all `half` suffix products, and rebuild a chunk's suffixes into a
small buffer immediately before consuming them. The invariant is unchanged —
`subp[i] = d_J · prod_{k>i} d_k` — and a chunk rebuilds downward through
`subp[i] = subp[i+1] · d_{i+1}`. Frame becomes `(half/T + T)` elements instead of `half`.

Every loop needs `#pragma unroll 1`. Without it `LADDER_T` is a compile-time constant, nvcc
unrolls the walk loop — which contains two full hash160 evaluations — and the kernel goes from
8304 to **809,632** instructions with spills. Pinned, all three builds land at 8344 instructions,
120 registers, zero spills: directly comparable to base.

| build | frame | extra `mul_mod`/batch | verify.py | MKeys/s | vs base |
|---|---:|---:|---|---:|---:|
| base | 16384 B | — | 17/17 PASS | 11537 | — |
| ladder `T=8` | 2304 B | 448 | 17/17 PASS | 11493 | **−0.38%** |
| ladder `T=16` | 1536 B | 480 | 17/17 PASS | 11437 | **−0.87%** |
| ladder `T=32` | 1536 B | 496 | 17/17 PASS | 11340 | **−1.70%** |
| probe (free arithmetic) | 256 B | 0 | — | 12013 | +4.13% |

**The ranking tracks the multiply count, not the frame.** `T=8` has the *larger* frame and is the
least bad, because it does 48 fewer multiplies per batch than `T=32`. The rebuild costs
`half − chunks` extra `mul_mod` — ~10% of the batch's ~4600 field multiplies — and that is more
than the memory it buys.

#### Why allocation is irrelevant, and traffic is what matters

One control separates the two things the probe conflates. `subp` is sized by `MAX_BATCH_SIZE`, so
rebuilding with a smaller compile-time bound shrinks the *allocation* while leaving bytes-touched
per key at 32 B — exactly what the P2 runtime-B sweep could not vary:

| build | frame | runtime B | MKeys/s | vs base |
|---|---:|---:|---:|---:|
| base | 16384 B | 1024 | 11536 | — |
| base | 16384 B | 512 | 11495 | −0.36% |
| `MAX_BATCH_SIZE=512` | **8192 B** | 512 | 11498 | −0.34% |
| `MAX_BATCH_SIZE=256` | 4096 B | 256 | 11403 | −1.15% |
| `MAX_BATCH_SIZE=128` | 2048 B | 128 | 11262 | −2.37% |

Halving the allocation at identical arithmetic and identical bytes-touched is worth **+0.03%**.
So the probe's 4.13% is not about allocating less — it is about the working set becoming
*cache-resident*. The probe's 256 B × 512 resident threads is 128 KB per SM, exactly L1; the real
frame is 8 MB per SM against a 128 MB-class L2 shared by 170 SMs, so every entry round-trips to
DRAM. Even the ladder's 1536 B is 768 KB per SM — 6× L1 — so it only thins the traffic, never
makes it resident, and collects nowhere near 4%.

#### Why there is no cheaper scheme

Single-inversion batch inversion needs the total product before it can emit any reciprocal, so
the suffix products are produced in exactly reverse-consumption order: a stack of depth `half`.
That stack is intrinsic. The only two trades are

* **recompute** the suffixes — extra `mul_mod`; cheapest measured variant is −0.38%; or
* **more inversions** — sub-batch into K groups, storage `half/K`, cost `(K−1)` extra `inv_mod`.
  `inv_mod` is a ~20-round divstep chain, order 8000 dynamic instructions, so K=16 adds ~120k
  instructions to a ~1.7M-instruction batch: ~+7%, worse than the ladder and far worse than the
  4.13% ceiling.

Both cost more than the ceiling pays. **P4 is closed. Do not reopen footprint work on this
kernel.** The endomorphism trick that would cut `half` in half does not apply either — λ·k is not
in the scanned range, so its images do not cover a contiguous `--range`.

### P5 — host wave-sizing — **DONE, and the modelled gain does not exist**

`GetThreadsCount` now rounds `threadsTotal` down to a whole number of resident waves
(`multiProcessorCount · BLOCKS_PER_SM · threadsPerBlock` = 130560) instead of merely to a whole
number of blocks. The geometry is now exactly balanced — **7980 → 7650 blocks = 45 per SM = 15
waves of 3, no partial tail** — where before 7980/510 = 15.65 waves left a 65%-full tail.

**Measured: −0.13%, inside the noise floor.** The wave model over-predicts. It assumes an SM waits
for all three resident blocks to retire before starting the next three; in reality the scheduler is
rolling and refills each slot the moment it frees, so a ragged tail overlaps with the previous
blocks' stragglers instead of costing a whole wave-time. The modelled +2.26% was never there to
collect.

The change is kept because it makes the launch geometry exact and costs nothing, but **do not
expect throughput from wave alignment on this architecture** — and treat the same reasoning applied
to other quantization "losses" with suspicion until measured.

Still untested from the original P5: the setup kernel `scalarMulKernelBase` (GpuEc.cu,
double-and-add with one inversion per bit for ~2M threads) delays every `Prepare`. That is latency
before the scan starts, not throughput during it, so it does not show up in MKeys/s at all.

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

## 4. The decision hinge — GET THE PROFILER. The experiment was not a substitute.

An earlier revision of this section claimed the hinge had been settled experimentally, on the
strength of the occupancy ladder. **That reasoning failed**, and the way it failed is the most
useful thing in this document: a single bad baseline inverted the conclusion, and nothing else in
the experiment could catch it, because a throughput A/B produces one number per build with no
internal consistency check. A profiler would have shown immediately that the 2-block build was not
issue-starved.

That hypothesis — a **footprint/cache limit** — has since been tested directly and is **wrong**,
or rather it is right and small. §P4's probe holds the instruction stream byte-identical and moves
only the working set: the entire footprint effect is 4.13%, and the occupancy regression survives
unchanged when the frame is 64× smaller. The kernel is register-pressure-limited. That correction
came from a purpose-built probe, not from counters — but it is exactly the kind of question a
profiler answers in one capture instead of six builds and two hours of interleaved runs.

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

**CUDA 12.8 and 13.0 generate near-equivalent code**, so the static analysis transfers between the
two machines — but not identically, and the difference is worth knowing before comparing numbers
taken on different boxes:

| pristine `TestKernel` | CUDA 13.0 (laptop) | CUDA 12.8 (host) |
|---|---:|---:|
| `BLOCKS_PER_SM=2` | 118 regs, 0 spill | 122 regs, 0 spill |
| `BLOCKS_PER_SM=3` | 80 regs, 200 B spill st | 80 regs, 184 B spill st |

Never compare a register count measured on one box against one measured on the other — and see §7
for how much damage a single unreproducible build did to this document's conclusions. Two
host-side gotchas: `python3` has no `ecdsa` (needed
by `verify.py`/`proof.py`) until `pip install ecdsa`, and copying a built tree with `cp -r` then
editing only a `.cu` leaves stale `.o` files that fail to link — `make clean` first.

## 7. Measurement log — 2026-09-05, RTX 5090

Method: each configuration run for 40 s, the binary's own `Speed:` line sampled, first two
samples dropped as warm-up, configurations **interleaved** round-robin (never all of A then all
of B), median over all rounds. Within-side spread is reported next to every number.

Thermal ramp is real and it is why interleaving matters: the first run of a session reads 1–3%
high and settles afterwards. Cross-run drift on an identical binary is ~0.3%, so treat anything
under ~0.5% as noise. Never build on the box while benchmarking it — a run with concurrent
`make -j24` produced a first round of ~5300 MKeys/s across *all four* builds under test.

### The measurement error, and how to avoid repeating it

This log previously reported **+7.76% for 3 blocks/SM**. That number was wrong, and it reached a
pushed commit. The corrected result is **−1.57%**: raising occupancy is a regression.

What happened: the "2 blocks/SM baseline" binary measured 10517 MKeys/s, reported **118 registers**
and disassembled to 8128 instructions with an IADD3-heavy mix. Every rebuild from byte-identical
source on the same host gives **122 registers, 8304 instructions, an IADD-heavy mix, and ~11530
MKeys/s**. The anomalous build was ~9.6% slower, so every configuration measured against it looked
like an improvement.

The source was ruled out (identical md5 across commits, `git archive` and working tree; the only
diff between the two commits is one digit in `Defs.h`). The compiler was ruled out: six consecutive
compiles produce identical SASS opcode sequences, so ptxas is deterministic here.

**Probable cause: a race between two concurrent `make` runs.** The first build was issued over SSH
and the connection was interrupted — but the remote `make -j32` kept running server-side. The
follow-up `make clean && make -j32` then raced it over the same object files. That fits both the
impossible SASS and the lost performance.

**Operational lesson: an interrupted SSH command does not kill the remote process.** After any
interrupted remote build, `pkill -f make` and rebuild from clean before trusting a binary.

Three cheap habits would each have caught this:

1. **Re-measure the baseline at the end**, not only at the start. The 3-block builds reproduced
   across sessions (11333 → 11368) while the 2-block number moved by 9.6%; comparing like with
   like at the end would have exposed it immediately.
2. **Treat an unexplained build-metric change as a stop signal.** The 118-vs-122 register
   discrepancy was visible early and was rationalised as a transcription slip rather than
   investigated. It was the whole story.
3. **Test the full matrix, not a ladder against one fixed reference.** Every rung shared the same
   suspect baseline, so a consistent-looking monotonic curve was produced entirely by one bad
   number.

### Corrected results — grid `1024,512`, interleaved

**Occupancy (P1)** — 4 rounds × 45 s, nothing else running:

| blocks/SM | regs | spill st / ld | warps/SM | median MKeys/s | spread | vs shipping |
|---:|---:|---|---:|---:|---:|---:|
| **2 (shipping)** | 122 | 0 / 0 | 16 | **11533** | 1.51% | — |
| 3 | 80 | 184 / 300 | 24 | 11352 | 0.55% | **−1.57%** |
| 4 | 64 | 408 / 796 | 32 | ~10960 | 0.17% | ~−5% |
| 5 | 48 | 928 / 1496 | 40 | ~10576 | 0.26% | ~−8% |

**Wave sizing (P5)** — 2×2 against occupancy, so the two levers cannot mask each other:

| | no wave rounding | wave rounded |
|---|---:|---:|
| 2 blocks/SM | 11531 | 11539 (+0.07%) |
| 3 blocks/SM | 11368 | 11376 (+0.07%) |

Neutral at both occupancies. Kept for exactness, not for speed.

**Walk-loop ILP (P3)** — −0.19% at 2 blocks/SM (both spill-free), −2.60% at 3. Reverted.

**Batch-size sweep (P2)** — see §3, monotonically negative, 1024 is optimal.

**The duplicated `c_Gx[i]` load is a non-issue.** `load4_const(px_i, &c_Gx[i*4])` appears twice per
walk iteration in the source, once in the `+i` block and once in `−i`. Hoisting it to a single
shared load produces **byte-identical SASS** — 122 registers, 8304 instructions, LDC 40, same
opcode sequence. The compiler already handles it. Do not spend time here.

(An earlier revision claimed hoisting made things *worse*, 118 → 122 registers and LDC 37 → 40.
Those "before" numbers were the bad build described above, not the pristine one. The hoist changed
nothing at all.)

### Where this leaves the plan

Every cheap lever has now been measured, and **all of them are negative or neutral**. The shipping
configuration — `BLOCKS_PER_SM=2`, `MAX_BATCH_SIZE=1024`, no interleave — is the best of everything
tried. Net throughput change from this whole exercise: **zero**, plus a neutral wave-rounding
tidy-up and a much better-mapped search space.

That is a real result: it says the remaining headroom is not in scheduling knobs.

**P4 is now measured too, and it closes the footprint dimension entirely.** The ceiling on all
footprint work is +4.13% (probe, arithmetic free); the cheapest real algorithm that reaches for it
costs more than it returns (−0.38% at best); halving the allocation at fixed arithmetic is worth
+0.03%; and shrinking the frame does not re-open occupancy. Three hypotheses this document was
holding open — footprint as the limiter, occupancy pending a smaller frame, and `subp` work
as the most promising lever — are all refuted. What is left:

- **Get counters** (§4). Every conclusion here still rests on throughput A/Bs plus purpose-built
  probes. That worked, but it cost six builds and two hours per question. Everything remaining is
  expensive enough that guessing wrong costs days.
- **Register pressure — now the best-motivated lever in the document, with a number attached.**
  The occupancy curve peaks at 16 warps because both neighbours are handicapped, and the two
  handicaps are separable. The left side proves the kernel *does* profit from more warps: 8 → 12 →
  16 gains 6.6% with spills held at zero throughout. The right side loses only because ptxas must
  drop 122 → 80 registers and spill 184/300 B. So the −1.44% at 24 warps is a *net* of a real
  latency-hiding gain against a spill cost that currently exceeds it. **Get the walk body under 85
  live registers with no spill and 24 warps/SM should win.** That is a concrete, falsifiable target,
  and it is the only remaining lever whose mechanism is understood.
- Note the tension with P3: interleaving the ±i chains found the scheduler was *not* short of ready
  work at 16 warps. Both can be true — more warps help by hiding memory latency, not by supplying
  ILP — but it means the register work should be tested at 24 warps directly, not justified by ILP
  arguments.
- **P7 (hand-written SASS)** — unchanged, still weeks of work, still gated on the above.
- **P6** stays demoted; the pipe imbalance is real but is not the limiter.

### P4 session addendum — toolchain change and two protocol lessons

**The host toolchain moved under the experiment.** `nvcc` on the GPU host is now **13.3.73**;
the numbers in §P1/§P2/§P3 were taken under 12.8.93. The baseline is unchanged across the move
(11533 → 11537 MKeys/s at `BLOCKS_PER_SM=2`, well inside drift), and every §P4 table above was
re-baselined on 13.3 in the same interleaved run as the variants it is compared against. Do not
mix a pre-13.3 number with a post-13.3 one without re-measuring the baseline alongside.

**Grid pinning.** `--grid B,N` sets the runtime batch size and the blocks/SM cap, and the cap is
what fixes the geometry: `maxThreadsByUser = SMs · N · 256`. Wave-rounding then truncates to a
whole number of resident waves, which differs per `BLOCKS_PER_SM`, so a cap chosen for 2 blocks
silently produces a *different grid* at 3 or 4. For the occupancy tables above the cap is **36**
— 1 566 720 threads, divisible by the wave size at 2, 3 *and* 4 blocks/SM — so every build in
that comparison launches exactly 6120 blocks.

**Two failure modes cost real time in this session, both worth remembering:**

1. **An SSH-carried `make` dies with its connection.** A dropped channel SIGHUPs the build and
   leaves a half-linked tree that the next `make` will happily complete into a mixed-vintage
   binary. This is the same class of fault that produced the wrong P1 number (§ above). Run every
   remote build under `setsid nohup … > log 2>&1` and poll the log for a completion marker; after
   any interruption, `make clean` before rebuilding.
2. **`pgrep -f X` / `pkill -f X` match the shell running them,** because the pattern appears in
   that shell's own command line. A wait-loop written as `while pgrep -f bench; do sleep; done`
   never exits, and `pkill -f build_x` kills the session issuing it. Use `pgrep -f 'benc[h]'` or
   match on a marker file instead.

### Block-size and low-occupancy session — 2026-09-06

Method as above; grid pinned to 1 566 720 threads for every variant by choosing the blocks/SM cap
per build (`cap = 9216 / THREADS_PER_BLOCK`), which is wave-exact at all geometries tested. All six
builds pass `verify.py` 17/17.

Two traps specific to this dimension:

* **`__launch_bounds__(T, B)`'s second argument is a *minimum*, not a cap.** It constrains the
  register ceiling to `65536/(T·B)`; actual residency is then `floor(65536/(T·regs))`. That is why
  `(256,1)` does not simply mean "1 block/SM" — it means "ptxas may use up to 256 registers", it
  takes 140, and residency *falls out* at 1 block. It is also the only lever that lowers occupancy
  without touching the code, which is what made the sub-16-warp measurements possible.
* **`--grid A,B` is unrelated to `__launch_bounds__(A,B)`** despite looking identical. `A` is the
  runtime batch size and `B` the blocks/SM cap used to size the grid. `--grid 128,4` measures
  −3.73%; `__launch_bounds__(128,4)` measures −0.17%. Do not quote one for the other.

The host's SSH daemon dropped connections twice during this session while the machine itself stayed
up (uptime unbroken). Both benchmark runs survived because they were launched with
`setsid nohup`; the polling loops died and were simply restarted. This is the third distinct way
the remote link has corrupted or nearly corrupted a measurement — detach everything.
