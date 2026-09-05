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

## 2. Bottleneck verdict — footprint-limited, and the shipping setting is already optimal

**More warps make this kernel slower, monotonically.** Measured on the RTX 5090, every occupancy
setting against the others:

| blocks/SM | warps/SM | registers | spill st / ld | MKeys/s |
|---:|---:|---:|---|---:|
| **2 (shipping)** | 16 | 122 | 0 / 0 | **11533** |
| 3 | 24 | 80 | 184 / 300 | 11352 (−1.57%) |
| 4 | 32 | 64 | 408 / 796 | ~10960 |
| 5 | 40 | 48 | 928 / 1496 | ~10576 |

That is the signature of a kernel limited by **per-thread memory footprint, not by latency**.
Every resident thread carries a 16 KB `subp[512][4]` local frame, so 2 → 3 blocks/SM raises the
resident local footprint per SM by 50% *and* forces ptxas from 122 registers down to 80, which
starts spilling. Both effects push the same way, and extra warps never buy back enough latency
hiding to pay for them.

- **Instruction mix is not the limiter.** 78.6% of `TestKernel`'s 8304 SASS instructions are
  ALU-class (IADD 2210, SHF 1422, LOP3 1243, IADD3 597, LEA 584, MOV/SEL/ISETP 425) against 1354
  IMAD (16.3%) on the separate FMA pipe — a 4.8:1 imbalance. Rebalancing it (P6) is still not
  indicated, but for a different reason than this document previously gave: the machine is short
  of cache and memory bandwidth, not of issue slots.
- **The 41% points-only half** is the same story: the 16 KB/thread local frame, 64 B of local
  load/store per key.

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
| P4 | **Field lazy reduction / subp prefetch** | +2 … +5% | med | 3–5 d | abtest oracle + abbench |
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

**Do not retry this without first shrinking the per-thread frame.** Occupancy and footprint are
coupled here; more warps is only worth re-testing once `subp` is smaller.

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

### P4 — field lazy reduction + subp prefetch

`mul_mod`/`sqr_mod` already skip the final conditional subtract (C8, results in `[0,2^256)`).
Extend laziness: keep intermediate field values non-canonical through the ladder and walk, reduce
fully only where canonical form is required (the parity byte and the hashed x-coordinate). Prefetch
`subp[i+1]` one iteration ahead into registers. Both touch only the 41% half; points-only
instruction cuts historically returned 11–16% there. Correctness risk is the parity/prefix byte
(P is odd → a non-canonical value flips bit 0) — gate every variant through `verify.py` and
`proof.py`.

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

What the corrected occupancy ladder actually supports is a **footprint/cache limit** (§2), not a
latency limit — but that is an inference from four throughput numbers, not a measurement of where
the cycles go. Treat it as a hypothesis until counters confirm it.

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

That is a real result: it says the remaining headroom is not in scheduling knobs. What is left:

- **P4 (field lazy reduction + `subp` prefetch)** — untested, and now the most interesting lever,
  because §2 points at footprint rather than issue rate. Anything that shrinks the 16 KB/thread
  frame attacks the actual limiter and would also re-open P1, since occupancy and footprint are
  coupled.
- **Get counters** (§4). Four throughput numbers can only ever support an inference about *why*.
  Every remaining lever is expensive enough that guessing wrong costs days.
- **P7 (hand-written SASS)** — unchanged, still weeks of work, still gated on the above.
- **P6** stays demoted; the pipe imbalance is real but is not the limiter.
