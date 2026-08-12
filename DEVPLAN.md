# cCUDAHurricane — deep code analysis and remediation plan

## Context

This repository is **CUDAHurricane**, a CUDA/C++ brute-force solver for Bitcoin puzzle
addresses. It scans a contiguous range of secp256k1 private scalars, derives each public key,
computes `HASH160 = RIPEMD160(SHA256(compressed_pubkey))`, and compares against a target.

The request was a deep analysis. It was carried out as a six-dimension audit (device field
arithmetic, hash pipeline, kernel control flow, host orchestration, host EC/bignum, GPU
performance), each dimension independently reviewed and then adversarially re-checked, with the
load-bearing claims re-verified by hand against the source. 64 raw findings, 57 survived
refutation.

**Original verdict: the cryptography is correct; the range partitioning and run control are not.**
The program silently failed to scan part of every range it was given, and could never report that
it had finished. All 81 commits are titled "fixes" and the recent churn was concentrated in
`GpuPuzzle.cpp` — which is exactly where the defects were. The math and hash layers are inherited,
machine-checked, and sound.

### How to use this document

It is a working document, not a report: **update it as fixes land.** Each defect keeps its ID
(C = silently loses keys, H = hang/crash/UB/leak, P = performance) for the life of the project, so
"C7" means the same thing in a commit message, in a test name and here. When a defect is fixed,
mark it **[FIXED]** in the Defects table *and* add a row to the Fixed table naming where the fix
landed — the second one is what makes the first one checkable a month later. When a fix turns out
to be bigger than its entry (H3, H6), write the note; those notes are the parts that have actually
been re-read.

### Where the fixes are

C1–C6, H1, H2, H5 and H14 landed inside the owner's own commits, all titled `fixes`, so they are
not individually recoverable from history. Everything after that is one commit per defect:

| Commit | Defect |
|---|---|
| `c482a7d` | H4 — re-derive the warp mask each iteration |
| `9a7d16f` | H3 — count worker threads that actually started |
| `2c78cbc` | (cleanup) dead commented-out `px`/`py` frees in `ClearHParams` |
| `706dd26` | H7 — fence between the payload and the flag |
| `187efe2` | H6 — correct deallocators, single ownership, idempotent `Release()` |
| `425243d` | H11 — `DEBUG_MODE` path removed |

---

## Status — 2026-08-12

**The coverage chain is closed end to end, and the program now reports what it did.** Every key in
the range is assigned to a thread, every thread's count is a whole number of batches so the kernel
loop drains to zero, every provisioned thread actually launches, and the run budget covers exactly
the launches required. When the run ends, the exit code and the console distinguish found,
exhausted, GPU failure and interruption. `proof.py` runs again and now actually checks the answer.

### Fixed

| ID | What | Where the fix landed |
|----|------|----------------------|
| **C1** | Missing partial-batch tail | `GpuPuzzle.cpp` `PrepareHost` — distributes whole **batches** rather than raw keys: `ceil(range/B)` batches split across threads, multiplied back to keys. Remainder threads get one extra *batch*. No kernel change needed. |
| **C2** | Small ranges scanned zero keys | Resolved as a side effect of C1 — batch distribution gives the first `ceil(range/B)` threads one batch each instead of leaving everyone below the loop threshold. |
| **C3** | `block_count` truncation | `GpuPuzzle.cpp` `GetThreadsCount` — `result -= result % threadsPerBlock;` as the final step, after the `max(result, minThreads)` clamp. |
| **C4** | Range length wrapped to 0 | `cCUDAHurricane.cpp` `validate_params` — the `sub_256` borrow and `add_256` carry are now both checked; reversed ranges and the full 2^256 keyspace are rejected with distinct messages. |
| **C5** | `sub_256` dropped the borrow | `Math.h` — each limb goes through a 128-bit intermediate and takes the borrow from the high word. |
| **C6** | Hex parsing truncated at bad characters | `Utils.h` — new `hex_digit_val`/`hex_to_u64`; `std::stoull`/`stoul` removed from both `hexToLE64` and `hexToHash160`. |
| **H2** | Malformed hex aborted the process | Resolved by C6 — nothing calls a throwing parser any more. |
| **H1** | Search never terminated | `GpuPuzzle.cpp` `Execute()`: `while (!m_stopFlag && runs_done < runs_total)`. **Now fully closed** — the reporting half was H5, below. |
| **H5** | Every outcome exited 0 | `GpuPuzzle.cpp` `Execute()` sets `Failed = true` on all three failure exits (`cudaSetDevice`, `Start()`, and the per-launch `cudaStreamSynchronize`). `cCUDAHurricane.cpp` gains the `EXIT_*` codes, `find_key` returns an `int` instead of an unconditional `true`, and `main`'s call site — previously `if (!find_key(…)) { }`, an empty body — assigns it. |
| **H14** | `proof.py`'s batch probe could never match | `proof.py` — `CALC_HDR_RE`/`BATCH_RE`/`RUNS_RE`. The probe gates on the `Calculated` header, so it reads the kernel's *effective* batch (`GpuPuzzle.cpp:166`) and not the input echo of the user's request (`:94`), and bails on `Runs` rather than the `"Phase-1"` sentinel that exists in no source file. |
| **H4** | Stale `__activemask()` reused across the loop exit | `GpuCore.cu` `TestKernel` — the single captured `full_mask` is gone. The batch loop is now `while (true) { live = …; mask = __ballot_sync(mask, live); if (!live) break; … }`, so the mask is re-derived every iteration and names exactly the lanes entering the body. Seeded `0xFFFFFFFFu`, **not** `__activemask()`. All 12 mask consumers take the per-iteration `mask`. |
| **H7** | Hit publication was unordered and unguarded | `GpuCore.cu` — new `publish_found`, used by all four found paths. `atomicCAS_system` picks one publisher, the scalar is written, `__threadfence_system()` fires, and only then does `atomicExch_system` set `found`. Offset arithmetic moved into registers, so the mapped struct is written once. `TFindResult.found` is now `uint32_t` (CUDA atomics have no `bool` overload) plus a new `claimed`; host reads in `GpuPuzzle.cpp` updated. |
| **H3** | Unchecked thread creation → unkillable hang | `cCUDAHurricane.cpp` `find_key` — `g_threadcnt` is charged per create, and only for one that succeeded; the `g_threadcnt++` in the prepare loop is gone. Both create calls now have their return checked; a failure refunds the counter, marks that GPU `Failed`, and is reported. New `!started` early-out. New `thr_started[]` replaces the non-portable `!thr_handles[i]` join test. `handle_sigint` escalates: a second Ctrl+C calls `std::_Exit`. **Fixed without touching H10** — see below. |
| **H11** | `DEBUG_MODE > 0` was undefined behaviour | **Deleted rather than repaired.** `Defs.h` no longer defines `DEBUG_MODE`; all eleven `#if DEBUG_MODE > 0` blocks are gone from `GpuPuzzle.cpp`, along with the `//`-commented one and the now-unused `<cinttypes>`. A repair had landed first (a `cudaMemcpy` D2H staging helper, a `formatHexBytes` in `Utils.h`, an `#ifndef` guard on the macro) and was rolled back on the call that the debug path is not worth carrying. `grep DEBUG_MODE` over the tree now returns nothing. |
| **H6** | Wrong deallocator, and an allocation with no owner | `GpuPuzzle.cpp` — new `free_host_pinned`/`free_device` helpers replace every bare `cudaFree`/`cudaFreeHost`/`free`. `ClearKParams` uses `cudaFreeHost` for `h_find_result` and leaves `d_find_result` alone (a mapping, not an allocation). `ClearHParams` frees `find_result` too, and `Prepare` nulls `hParams.find_result` at the handoff, so exactly one owner exists at every point. Both cleanups null what they free, which makes `Release()` idempotent and lets `~GpuPuzzle()` call it. Frees report instead of discarding. See the note below. |

Also added:

- `mul_256_u64` in `Math.h` (needed by C1).
- **`proof.py` now compares the recovered key against the expected one.** It previously counted any
  `FOUND MATCH` banner as a pass without reading the private key line — on a scenario where the
  binary announces a match and prints the *wrong* key, the old harness reported 18/18 PASS; the new
  one reports 1 pass / 17 `WRONG_KEY`. This is not part of H14; it is the second reason `proof.py`
  proved nothing.
- **`proof.py` timeouts are real**: `run_and_watch` takes `timeout` (default 1800 s, `--timeout 0`
  disables), enforced by a `threading.Timer` watchdog; the `select.select()` call — which does not
  work on Windows pipes — is gone, replaced by a bounded `readline` loop.
- **`proof.py` no longer requires a power-of-two batch size.** Both that check and the
  `raw_len % B != 0` check it hid behind were dropped/downgraded to notes; the batch-aligned
  partition from C1 no longer needs either to hold.
- **`.gitignore`** — `*.o`, `cCUDAHurricane`, `tests_results.txt`, `__pycache__/`.

### Exit codes (H5)

| Code | Meaning | Console |
|---|---|---|
| **0** | Key found | the `FOUND MATCH` block |
| **1** | Usage / parse error | the existing `Error: …` messages |
| **2** | Range scanned to the end, no match | `Range exhausted: key not found.` |
| **3** | No usable GPU, or one failed to prepare or died mid-run | one of three distinct messages |
| **4** | Ctrl+C before the range finished | `Interrupted before the range was fully scanned.` |

`find_key` reads each worker's `Failed` only *after* the drain loop. That is safe despite H10:
each worker writes `Failed` inside `Execute()` and then does `g_threadcnt.fetch_sub(release)`,
which the main thread observes reaching zero — a real happens-before edge, not luck. It stays
correct if H10 later makes `Failed` atomic.

### Measured effect of the C1 + C3 fixes

Keys previously lost per run, by configuration:

| Range | Threads | B | Was scanned | Lost | Now |
|---|---|---|---|---|---|
| 2^36 | 1,048,576 | 1024 | 68,719,476,736 | 0 | full |
| 2^36 | 1,000,003 | 1024 | 68,608,205,824 | 111,270,912 | full |
| 2^40 | 1,562,663 | 1024 | 1,099,314,668,544 | 196,959,232 | full |
| 1,000,000,007 | 65,536 | 1024 | 939,524,096 | 60,475,911 | full |
| 4,096 | 65,536 | 1024 | **0** | 4,096 | full |
| 1,023 | 65,536 | 1024 | **0** | 1,023 | full |

The only case that lost nothing was the clean power-of-two, 2^20-thread configuration — which is
exactly the shape `proof.py` restricts itself to. That is why this never surfaced in testing.

C3 separately dropped whole threads, card-dependently: 16 on a 170-SM/32 GB device, 40 on an
A100-80, 0 on a 128-SM/24 GB device. On puzzle 71 each thread owns ~5.7e14 keys, so 16 dropped
threads was ~9e15 keys silently skipped.

### H3 was fixed *without* the planned timeout — and that was the point

The original plan said "add `&& !g_sigint` and a timeout to the drain loop", bundled with H10. H10 was
explicitly out of scope, so that route was closed: a drain loop that can exit early stops supplying
the release/acquire edge that makes `find_key`'s `Failed` reads legal, and it would also let `main`
tear down `g_GpuPuzzles` while workers are still touching them.

So the fix attacks the **cause** instead of the symptom. The loop only ever spun forever because
`g_threadcnt` counted threads that were never created. With the counter charged per create and
refunded on failure, it counts exactly the threads that exist, every one of which decrements on the
way out of `puzzle_thr_proc` — so the loop is bounded by construction (at most one kernel launch,
since `Stop()` has already cleared the workers' loop guard). No timeout needed, and the H5 edge is
untouched.

The one case a counter fix cannot bound is a genuinely wedged GPU, where the driver never returns
from a launch. Nothing host-side can safely reclaim that, so the answer there is to stop making the
user hunt for SIGKILL: **a second Ctrl+C now calls `std::_Exit(EXIT_INTERRUPTED)`** (async-signal-safe,
unlike `std::exit`), and the drain loop says what it is waiting for every `STOP_WARN_SECS`.

**When H10 lands**, the `&& !g_sigint` half of the original plan becomes available and is still worth
having — but it must come with skipping the `Failed` scan on that path, or the race just moves.

### H4 reachability (measured)

The trigger is exactly `batch_cnt % 32 != 0` **AND** `(batch_cnt / T) % S != 0`, where
`batch_cnt = ceil(range/B)`, `T = threadsTotal`, `S = batches_per_launch`. `T` is always a multiple
of 256, so `r1 = batch_cnt % T ≡ batch_cnt (mod 32)`. It fires on the **last launch only**, in the
**single warp** straddling the `r1` boundary — but that warp then has up to 31 live lanes named in
a mask they never arrive at.

The canonical power-of-two single-GPU invocation is immune (`batch_cnt = 2^m`, so `r1 ≡ 0 mod 32`)
— the same blind spot that hid C1. Any hand-specified `--range`, or multi-GPU chunking, breaks it.
Roughly 95% of arbitrary configurations trigger it.

Concrete: `--range 1:0x204000400 --grid 1024,2 --slices 64` on a 128-SM device gives `T = 65536`,
`batch_cnt = 8,454,145`, `k = 129`, `r1 = 1`, `runs_total = 3`. On launch 3, lane 0 of warp 0 has
two batches left and lanes 1-31 have one; those 31 exit the loop live and fall into the write-back
while lane 0 votes with a mask still naming all 32.

### H6 was bigger than "one wrong deallocator"

Three things, only the first of which the original entry names:

1. **`ClearKParams` freed pinned memory with `cudaFree`.** Rejected, frees nothing, return
   discarded. `d_find_result` was correctly left alone — the author knew which pointer was a
   mapping and then applied the wrong free to the one that was an allocation.
2. **`find_result` was freed on *no* path** once `PrepareHost` returned true: `ClearHParams`
   never touched it, so every failure exit before the `Kparams` handoff orphaned it outright,
   and after the handoff the `cudaFree` above no-op'd it. The only correct free in the tree was
   `PrepareHost`'s own `LExit`, reachable only when `PrepareHost` itself failed.
3. **A discarded `cudaFree` error is not inert.** `cudaGetLastError` returns the last error from
   any runtime call *in that host thread* and resets it; successful calls do not clear it.
   `Prepare` runs for every GPU on the main thread, so a `cudaErrorInvalidValue` latched by GPU 0's
   cleanup was picked up by GPU 1's post-launch check inside `PrepareCuda` and reported as
   `gpuMulKernel launch: invalid argument` — a healthy card lost to another card's cleanup bug.
   Measured, not theorised: with two GPUs and GPU 0 failing late, the pre-fix build loses both and
   the fixed build keeps GPU 1.

That last one has a **cause independent of H6**: `PrepareCuda`'s `cudaGetLastError()` is used as a
launch check without draining the slot first, so *any* earlier failure anywhere in the thread lands
on it. Fixed with a drain immediately before the setup launch. Without it, H6's own fix is
invisible — the misattribution just carries a different error code.

Blast radius today is small either way (≈4 KB of pinned memory per GPU per process, reclaimed at
exit) — apart from item 3, which costs a whole GPU. What makes it worth fixing now is P1: auto-tuning
`slices` means calling `Prepare` more than once, and `Prepare` memsets `Kparams` on entry, so the
leak becomes per-attempt the moment that lands.

The destructor is the one piece not named in the original entry. `Release()` only ever ran at the
end of `Execute()`, so a GPU that prepared but never ran — the H3 thread-create failure — carried
its four device buffers to process exit (measured: 512 KB at 4,096 threads, and it scales with
`threadsTotal`). Safe only because the cleanups now null what they free; a control build with the
destructor but without the nulling double-frees all four.

### Still open

Everything below not marked **[FIXED]**. With coverage, reporting and warp-sync correctness now
settled, the highest-value remainder is **C7** (the last silent key-loss path), **P1** (14-27 second
kernel launches, which also governs Ctrl-C latency and therefore how usable exit code 4 is), and
**H12** (the binary will not launch on anything but sm_120, so none of this has run on real
hardware yet).

---

## What the code gets right (do not "fix" these)

These were verified, not assumed:

- **Montgomery batch inversion is correct.** [GpuCore.cu:85-104,183-185,229-231] The suffix-product
  ladder gives `subp[i]·inverse = 1/(Gx[i]-x1)` at every step, and after the tail block
  `inverse == 1/(Jx-x1)`, exactly what the point jump at `:240` consumes. One inversion per B keys.
- **The ± symmetric walk covers exactly B distinct scalars, no gap, no duplicate.** Offsets from
  centre `s1` are `0`, `±(i+1)` for `i∈[0,half-2]`, and `-half` — i.e. `{-half … +half-1}`. The
  negative branch correctly reuses the same `dx_inv_i` because `x(-Q) = x(Q)`.
- **Consecutive batches abut exactly.** `s1 += B` makes batch *k+1* start at `s1_k + half`; the
  `+half` offset is deliberately not hashed and is picked up as the next batch's `-half`.
  `PrepareHost` pre-biases each start scalar by `+half` so a thread's first batch covers exactly
  `[base, base+B-1]`.
- **The jump constant tracks the *effective* batch**, not the user's — an easy thing to get wrong.
- **The hash pipeline is machine-checked.** SHA-256 rounds/schedule validated against `hashlib`;
  all four RIPEMD-160 permutation tables and both rotate tables match spec; the 153-of-160-round
  trim for word 2 is provably minimal and endianness is consistent end to end. A 32-bit prefix
  false positive can never produce a false key — the gate is `pref && hash160_full_match(...)`.
- **`sub_mod3` and `sub_mod_is_odd` are exactly equivalent to their unfused forms**, including
  canonicalization. The parity trick works because `K = 0x1000003D1` is odd.
- **In-place aliasing is safe** everywhere it is used, and `inv_mod`'s partially-uninitialized 5th
  limb is safe — it writes `r[8]=0` as its second statement and never reads `r[9]`.
- Good GPU hygiene: `__restrict__` on all `TestKernel` pointers, warp-uniform constant-memory
  indexing (broadcast, no serialization), zero-copy mapped result with the device alias correctly
  never `cudaFree`'d, and a `ptxinfo` target already in the Makefile.

---

## Defects

### A. Silently loses keys

| ID | Defect | Location |
|----|--------|----------|
| **C1** **[FIXED]** | **No partial-batch tail.** The loop guard `while (… && ge256_u64(rem, B))` exited the moment `rem < B`, and nothing after it hashed the remainder. Nothing rounded `per_thread_cnt` to a multiple of `B`. Lost up to `(B-1) × threadsTotal` keys per GPU. | `GpuCore.cu:65`; host side `GpuPuzzle.cpp` |
| **C2** **[FIXED]** | **Small ranges scanned ZERO keys.** `GetThreadsCount` lifts `threadsTotal` to `minThreads` even when the range is smaller; `CalcEffectiveBatchSize` then floors B at 2 while `per_thread_cnt` is 0 or 1. | `GpuPuzzle.cpp` |
| **C3** **[FIXED]** | **`block_count` truncation.** `block_count = threadsTotal / threadsPerBlock` with no ceiling, while `PrepareHost` provisioned all `threadsTotal`. Threads past `block_count*block_size` got a sub-range and a start point and were never launched. | `GpuPuzzle.cpp:148` |
| **C4** **[FIXED]** | **Range length could wrap to 0.** `sub_256`/`add_256` return values both discarded. `--range 100:FF` → `2^256-1 + 1 = 0`; the full keyspace → also 0. A zero range survived every downstream guard. | `cCUDAHurricane.cpp` |
| **C5** **[FIXED]** | **`sub_256` lost the borrow.** `uint64_t bi = b[i] + borrow;` wrapped to 0 when `b[i] == 0xFFFF…FFFF`. | `Math.h` |
| **C6** **[FIXED]** | **Hex parsing silently truncated.** `--target-hash160 1z…` yielded `hash160[0]=0x01` and returned **true** — the GPU scanned the whole range against a fabricated target. | `Utils.h` |
| **C7** | **`inv_mod(0)` returns 0 instead of trapping.** If any factor of the Montgomery product is zero, every `dx_inv_i` is wrong **and the jump reuses the same `inverse`**, so `x1/y1` become garbage and every subsequent batch of that thread hashes nonsense. **Concretely reachable:** `--range 200:…` with B=1024 → thread 0's first centre is `s1 = 1024 = B`, so `c_Jx - x1 == 0`. Unreachable for canonical `2^(k-1)`-aligned ranges. | `GpuCore.cu:85-100`, `Math.cuh:538` |
| **C8** | **`mul_mod`/`sqr_mod` emit "almost reduced" results** — no final conditional subtract of P, and the carry out of `r[3]` is dropped. Deterministic witness: `a=2, b=(p+1)/2` → product is exactly `p+1 < 2^256`, both folds contribute 0, `mul_mod` returns `p+1` verbatim. Consumers need canonical form: `SHA256_33_from_limbs` serializes limbs raw, and `sub_mod_is_odd` derives the 0x02/0x03 prefix from `r[0]&1` (p is odd, so the prefix flips). ~2^-224 on pseudorandom operands. | `Math.cuh:279-283`, `401-405` |
| **C9** | **`inv_mod` normalizes only to `[0, 2^256)`.** The `while ((int)r[8] > 0) sub_288_P(r);` loop stops the instant word 8 is zero; the last subtract maps `[2^256, 2^256+p)` → `[K, 2^256)`, which contains `[p, 2^256)`. | `Math.cuh:645-650` |
| **C10** | **Host `MulModP`/`AddModP` leave results in `[P, 2^256)`.** Matters most because `init_g_points` memcpy's `p.x.data`/`p.y.data` straight into the Gx/Gy table uploaded to constant memory for **every thread on every GPU**. Deterministic per build — always or never wrong. | `EcInt.cpp:264-265`, `187-192` |
| **C11** | A match makes the whole warp `return`, skipping the state write-back. Benign today. | `GpuCore.cu:79/139/179/226` |
| **C12/C13** | **Statistics lie in both directions.** ETA uses only `range[0]` (for puzzle 71, `range[0]==0` → ETA prints `0d:0h:0m.0s`). `cur_speed = pnt_cnt/(1000*tm)` is integer division → 0 for small configs; `pnt_cnt` is credited in full every iteration regardless of work done; it also uses `threadsTotal` rather than `block_count*block_size`. | `cCUDAHurricane.cpp`, `GpuPuzzle.cpp` |

### B. Hangs, crashes, UB, leaks

| ID | Defect | Location |
|----|--------|----------|
| **H1** **[FIXED]** | **Search never terminated.** Now bounded by `runs_done < runs_total`, and H5 supplies the reporting half. | `GpuPuzzle.cpp` `Execute()` |
| **H2** **[FIXED]** | **Malformed CLI hex aborted the process** via uncaught `std::invalid_argument`; there are zero `try`/`catch` in the tree. Closed by C6. | `Utils.h` |
| **H5** **[FIXED]** | **Exit code was 0 for found, not-found, GPU crash, and no-GPU alike.** The `ck` macro never set `Failed`; `find_key` returned `true` unconditionally and `main`'s call site was `if (!find_key(…)) { }` — an empty body. Now four distinct codes, with `Failed` set at every failure exit. | `GpuPuzzle.cpp` `Execute()`, `cCUDAHurricane.cpp` `main`/`find_key` |
| **H3** **[FIXED]** | **Unchecked `pthread_create` → unkillable hang.** `g_threadcnt` was incremented before any thread was created and the create return was discarded; the drain loop had no stop flag, no `g_sigint` check, no timeout. Only SIGKILL ended it. Fixed by making the counter exact rather than by adding a timeout — see the note below. | `cCUDAHurricane.cpp` `find_key` |
| **H4** **[FIXED]** | **Stale `__activemask()` reused across a loop exit.** The `rem==0` early return and found-path returns are fine (exited threads are exempt). The non-conforming case was the loop exit: such a thread is still *live* executing the write-back, named in `full_mask`, and never reaches the matching `__any_sync`. Documented consequence on Volta+ is a **kernel hang**; on sm_60/61 the mask is a convergence precondition rather than a wait, so the failure mode there is silent wrong data instead. `compute-sanitizer synccheck` does **not** catch this case. | `GpuCore.cu` `TestKernel` |
| **H6** **[FIXED]** | **`cudaFree` on `cudaHostAlloc`'d pinned memory** — rejected with `cudaErrorInvalidValue`, frees nothing, return discarded. Separate leak on the `PrepareCuda`-failure path. In fact `find_result` was freed on **no** path once `PrepareHost` returned true: orphaned on failure, no-op'd on success. | `GpuPuzzle.cpp` `ClearKParams`/`ClearHParams` |
| **H7** **[FIXED]** | **Misplaced `__threadfence_system`** — it followed *both* the scalar store and `found=true`, so nothing ordered scalar-before-flag; `Copy_u64_x4` is four independent stores into one shared mapped struct. A host that saw the flag early would hand a torn scalar to `DumpFound`, which multiplies it out and prints a **well-formed but wrong key** — there is no host-side hash160 recheck to catch it. Latent only because the sole host read follows `cudaStreamSynchronize`. Three of the four sites also did the offset arithmetic as a read-modify-write straight over PCIe. | `GpuCore.cu` `publish_found` + 4 call sites |
| **H8** | **Carry-chain inline asm declares no CC clobber.** Chains communicate through PTX `CC.CF`, never declared as output/input/clobber. Works on the current toolchain; undefined by the PTX contract. | `Math.cuh:7-25` and all users |
| **H9** | Strict-aliasing violation: `uint64_t[5]` written through `uint32_t*`. Pervasive, not just `inv_mod`. | `Math.cuh:538`, callers |
| **H10** | Data races on `Failed`, `m_speed_stat[]`, `m_stat_idx`. **`Failed` is now load-bearing** (H5 turns it into exit code 3), so this moved up in priority. Currently sound only because `find_key` reads it after the `g_threadcnt` drain, which supplies a release/acquire edge; making it `std::atomic<bool>` removes the reliance on that argument. | `GpuPuzzle.h:19-20,30` |
| **H11** **[FIXED — by deletion]** | `DEBUG_MODE > 0` dereferences `cudaMalloc`'d device pointers on the host (segfault) and over-reads `hash160` by 12 bytes. Dead today; one config token away — and the token did not work either, since `DEBUG_MODE` was defined unguarded, so a command-line `-D` collided with the header and lost. The whole path is now removed; there is no debug build to keep correct. **If a debug dump is ever wanted back, it must stage device memory through `cudaMemcpy` — a `cudaMalloc` pointer is not host-readable.** | `GpuPuzzle.cpp`, `Defs.h` |
| **H12** | **Makefile ships SASS-only for sm_120, no PTX fallback.** On any other GPU the first launch fails with `cudaErrorNoKernelImageForDevice`. Contradicts `init_gpus`, which accepts every device with `major >= 6`, and the Makefile's own comment claiming 75/86/89/120 support. | `Makefile:11-12`, `:16` |
| **H13** | **The `_WIN32` branch cannot compile** — the `#ifdef _WIN32` in `Defs.h:55` has an empty body; zero `windows.h`/`process.h` includes tree-wide, yet the path uses `HANDLE`, `_beginthreadex`, `CloseHandle`; both wait loops call POSIX `sleep()` unguarded. The banner still prints "Windows version". | `Defs.h:55-57`, `cCUDAHurricane.cpp` |
| **H14** **[FIXED]** | **`proof.py`'s batch probe could never match.** The regex was `r"\s*Points batch size\s*:\s*(\d+)"`; the binary prints `" Points/Batch        : N"`, and the `"Phase-1"` sentinel appears in no source file. Compounded by the harness never comparing the recovered key. **The one guarantee proof.py exists to provide was never delivered.** Both halves now fixed. | `proof.py` |

### C. Performance (secondary)

Instruction split per scanned key is ~2707 hashing + ~1207 field math; hashing is **69%** and is
essentially at its floor. The headroom is in configuration, not arithmetic.

- **P1 — launch length.** `runtime_batches_per_sm = 512` makes `points_per_run ≈ 1.37e11` →
  **14-27 s per launch**. Governs Ctrl-C latency, found-key latency, WDDM TDR, the 5 s stat
  interval mismatch, and P5's setup cost (12-24× for free). Default to 4-8 and auto-tune `slices`
  for ~50-200 ms launches.
- **P2 — `subp` local frame.** 16 KB/thread, sized by `MAX_BATCH_SIZE` regardless of the runtime
  batch. *Not the dominant cost* — traffic is 32 B/key. Its real cost is a **4.28 GB driver-side
  local reservation**. Cheapest fix: build `-DMAX_BATCH_SIZE=256` (≈ +0.35% arithmetic).
- **P3 — drop `__noinline__`** on the hot `getHash160_w2_from_limbs` and hoist the inverse-chain
  update. 5-15%, unmeasured. **Gate on `make ptxinfo SM=120`.**
- **P4 — template the kernel on batch size.** 2-5%; composes with P2/P3.
- **P5 — setup kernel** does ~200-380 affine inversions per thread. ~30-70 ms one-time; fixing P1
  shrinks it 12-24× for free.

**Verified non-wins — do not chase:** stream overlap, L2 persistence, the duplicated `c_Gx/c_Gy`
loads, `-use_fast_math` (zero FP ops in device code), `cudaFuncSetCacheConfig(PreferL1)`.

---

## Remaining fix plan

### Next up

1. **H10 — make `Failed`/`Found`/`m_speed_stat`/`m_stat_idx` atomic.** The loose end H5 left behind
   and H3 had to work around: the exit code depends on a plain `bool` written by worker threads. It
   is currently sound, but only by an argument about the `g_threadcnt` drain edge —
   `std::atomic<bool>` with `release`/`acquire` makes it sound by construction, and unblocks adding
   `&& !g_sigint` to the drain loop (see the H3 note above).

2. **C7** — reject `range_start < 2·batch_size` in `validate_params`, or zero-check `inverse`
   after `GpuCore.cu:100`. The last remaining "silently skips the rest of a thread's range" path.

3. **H12 — add `-gencode arch=compute_120,code=compute_120`.** One line, and it is what stands
   between all of the above and ever running on real hardware; today anything but sm_120 dies at
   the first launch with `cudaErrorNoKernelImageForDevice`. Promoted out of item 8.

### Then

4. **P1** — default `runtime_batches_per_sm` to 4-8, auto-tune `slices`, poll
   `h_find_result->found` during the launch. Also the gate on exit code 4 being usable: at 14-27 s
   per launch, Ctrl-C takes that long to be noticed. **The mid-launch poll must read through a
   `volatile TFindResult*`** — H7 makes the device side publish correctly, but nothing stops the
   compiler hoisting a non-volatile load of `found` out of a poll loop. H7 had to land first;
   without it that poll would have been the reader that turns the ordering bug into wrong keys.
5. **C12 + C13** — fix the statistics. Pass the full 256-bit range to `show_stat`; report keys/sec
   as a wide u64; use `block_count*block_size`; fix `GetStatsSpeed`'s slot-0 seed.
6. **C11** (`break` not
   `return`). A few lines. **C11 composes cleanly with the H4 fix**: `__any_sync` is uniform
   among participants, so all four found-path exits are already all-or-nothing across the
   participating set — turning them into `break` keeps the mask correct, because the whole set
   leaves together.
7. **Dead warp scaffolding** — `__syncwarp(mask)` at the four found-path exits does nothing:
   `WARP_FLUSH_HASHES()` expands to empty (`GpuCore.cu:25`), each call immediately follows a
   converging `__any_sync` and immediately precedes a `return`, and visibility is already covered
   by the preceding `__threadfence_system()`. `FLUSH_THRESHOLD`, `MAYBE_WARP_FLUSH`,
   `warp_reduce_add_ull`, `local_hashes` and `hashes_accum` do not exist anywhere in the tree.
   Delete the lot. (Left in place by the H4 fix, which only had to make the mask correct.)

### Hardening

9. **C8 + C9 + C10 — canonicalization, all three together.** A partial fix leaves the
   non-canonical value free to propagate through the untouched routine. `MulModP` matters most
   despite the lowest probability, because it feeds the shared Gx/Gy constant table.
10. **`make ptxinfo SM=120`** — record registers, spill stores/loads, stack frame. **Gates 11/12.**
11. **P2** — build `-DMAX_BATCH_SIZE=256`. Correct `BYTES_PER_THREAD` to the real 128 B/thread
    **only together with a real `threadsTotal` cap** — the current 128× over-reservation is the
    only thing bounding thread count today.
12. **P3 then P4**, measuring after each.
13. **H8 + H9** — fuse carry chains into single `asm volatile` blocks with declared operands; give
    `inv_mod` a `uint64_t*` signature. Add a startup self-test kernel regardless — it converts
    H8's failure mode from "silently wrong keys" into "refuses to start".
14. **Housekeeping** — H13, dead `TFindResult::rx/ry`, dead host EC surface, `Utils.h`'s
    missing includes and signed-`char`-to-`toupper` UB, drop inert `-use_fast_math`.

---

## Verification

### Build environment (dev machine)

**Windows host** — MSYS2 ucrt64 g++ 16.1.0 at `/c/tmp/msys2/ucrt64/bin/g++`. No CUDA. This is
what every host-side harness below is built with.

**WSL — `wsl -d Ubuntu-22.04`** — CUDA Toolkit **13.0.88**, `nvcc` at `/usr/local/cuda/bin/nvcc`.
**Compiles, does not run.** `/usr/lib/wsl/lib` carries only the D3D12 shims: there is no
`libcuda.so.1`, no `nvidia-smi`, no device. A built binary starts and parses arguments, then
reports `No suitable CUDA devices found.` and exits 3.

So on this machine nvcc gives **codegen** — which the g++ harnesses explicitly cannot give — and
nothing else. That covers: the whole tree actually compiling as CUDA rather than as g++-with-stubs,
H12's gencode question, `make ptxinfo` register/spill/stack-frame numbers (item 10 of Hardening,
which gates P2/P3/P4), and `make sass`. It does not cover any claim that needs a kernel to execute.

Verified working, whole tree, 4.3 s:

```
wsl -d Ubuntu-22.04 -- bash -lc 'rm -rf /tmp/hb && mkdir -p /tmp/hb \
  && cp /mnt/c/tmp/ai/cCUDAm/*.cpp /mnt/c/tmp/ai/cCUDAm/*.h /mnt/c/tmp/ai/cCUDAm/*.cu \
        /mnt/c/tmp/ai/cCUDAm/*.cuh /mnt/c/tmp/ai/cCUDAm/Makefile /tmp/hb/ \
  && cd /tmp/hb && make SM=120 -j4'
```

Build out of tree as above rather than in `/mnt/c`: the Makefile drops `.o` files next to the
sources, and `/mnt/c` is slow. Note CUDA 13 has dropped some older SASS targets, so `SM=` values
from the Makefile comment are not all still valid — check before trusting that list (H12).

### What exists now

Host-side harnesses were built against the real project headers with g++. They are stub-based by
necessity — until the WSL nvcc route above was found there was no CUDA toolchain at all, and there
is still no GPU, so **nothing below has ever executed on a device**:

- **`fixtest.cpp`** — `sub_256` over 200k randomized definitional checks (`r + b == a` with
  `carry == borrow`) plus targeted all-ones cases; hex parsing accept/reject; range-length
  validation (C4); and the batch-aligned partition (coverage, alignment, contiguous tiling,
  sub-one-batch over-scan).
- **`c3test.cpp`** — links the **real** `GetThreadsCount` out of `GpuPuzzle.cpp` and sweeps 80,645
  configurations asserting `block_count * threadsPerBlock == threadsTotal` exactly.
- **`runstest.cpp`** — asserts the host launch budget (`runs_total`) covers the launches the
  batch-aligned partition actually needs, across 1024 swept configurations.
- **`hurricane_stub.exe`** (`prelude_run.h` + `stubs_host.cpp`) — the **real** `cCUDAHurricane.cpp`,
  `GpuPuzzle.cpp` and `Ec*.cpp` linked against a stubbed CUDA runtime and Win32 threading surface,
  so `main`/`find_key`/`Execute` actually run. Env vars `STUB_DEVICES`, `STUB_FAIL_MALLOC`,
  `STUB_FAIL_SYNC`, `STUB_FOUND` provoke each failure. This is what verified H5.
- **`fake_gpu.cpp`** — reproduces the binary's banner and `DumpFound` output byte for byte, with
  modes for shrunk/absent/silent batch lines and for wrong-key and no-key hits. Drives `proof.py`'s
  probe and key comparison without a GPU.
- **`h4test.cpp`** — a 32-lane warp simulator that models the CUDA mask-participation rule
  (`(mask \ exited) == arrivals`) and runs both the old and new kernel control flow over 3,432
  swept configurations plus five concrete ones derived exactly as `PrepareHost` does. It also
  checks loop equivalence (7,445 launches, identical batch counts and final `rem`) and seed
  determinism. This is what verified H4.
- **`h3test.sh`** — drives the real `main`/`find_key` through `hurricane_stub.exe` for eight
  thread-creation scenarios, each under `timeout` so a hang surfaces as rc=124 instead of blocking.
  `STUB_FAIL_THREAD=N` makes the Nth create return 0; `STUB_HANG_SYNC=1` wedges a worker inside
  `cudaStreamSynchronize`. Comes with a negative control built from `git show HEAD:cCUDAHurricane.cpp`
  — the pre-fix binary **hangs** in all four create-failure cases, the fixed one returns 3.
- **`h7test.cpp`** — extracts the **real** `publish_found` text out of `GpuCore.cu` at build time
  (`awk` into `publish_found.inc`) and runs it against host atomics with matching semantics. Three
  checks: a deterministic second-publish test (fixed holds the first scalar, pre-fix control
  overwrites), a 16-thread contention run asserting no mixed scalar, and an exhaustive store-order
  model (pre-fix: 96 of 120 observable orders expose a torn scalar; post-fix: 0 of 24). The
  contention check is deliberately **not** run against the pre-fix sequence — x86-64 is strongly
  ordered and the window is four adjacent stores, so it would pass there and prove nothing.
- **`h6test.sh`** + the upgraded `stubs_host.cpp` — the stubs now model the two things plain
  `malloc`/`free` cannot, which is why H6 was invisible to the earlier harnesses. (a) Allocation
  **kind**: every block is tagged device / pinned / mapped-alias, and the wrong deallocator is a
  recorded violation that frees nothing, exactly as the driver behaves. (b) The **latched error
  slot**: failures set a thread-local error, `cudaGetLastError` returns and clears it, successful
  calls do not — the mechanism behind the cross-GPU misattribution. An `atexit` report prints
  violations and anything still allocated. Seven scenarios, each run against the fixed build and
  against `git archive HEAD`; a third build (HEAD sources + the fixed header) is the control for
  the nulling, and reproduces the double free. New knob `STUB_FAIL_STREAM=N` fails the Nth stream
  create — that is what makes a GPU fail *after* `PrepareCuda` succeeded. **Build each tree
  separately**: a quoted `#include` resolves against the including file's directory first, so
  `-I` order cannot swap a header out; doing it that way silently produced a hybrid with an ODR
  violation and a control that had the fix half-applied.
- **A second `stubs_host.cpp` upgrade — device memory the host cannot read.** Device allocations
  now come from `VirtualAlloc` + `PAGE_NOACCESS`, with the stubbed runtime and kernel entry points
  opening a window for the duration of a call. That models unified addressing: a `cudaMalloc`
  pointer is in the process's address space but unmapped for host access, so reading one **faults**.
  `calloc` handed back readable memory, which is why every earlier harness ran the H11 code and saw
  nothing. Kept even though H11 was resolved by deletion — it is the only thing standing between a
  future host-side read of a `d_*` pointer and a clean-looking test run. `h11test.sh` itself is
  obsolete and gone; the record of what it measured is worth keeping: HEAD with `DEBUG_MODE` forced
  to 1 died with SIGSEGV mid-dump, and the `hash160` print emitted 64 hex characters for a 20-byte
  object, the extra 12 being `TOutParams`'s padding and its `Gx` pointer — so it was also leaking an
  ASLR'd heap address to stdout.
- **`cu_prelude.h`** — stubs for the CUDA device language (`__device__`, `__constant__`,
  `blockIdx`, `__activemask`, `__ballot_sync`, `__any_sync`, `__byte_perm`, `__funnelshift_r`, …)
  so `g++ -fsyntax-only` can parse `GpuCore.cu`. `-fsyntax-only` stops before assembling, so the
  PTX inline asm in `Math.cuh` passes through as an opaque string. Strip the `<<<>>>` launch line
  first (g++ cannot parse it). Validates declarations, types and control flow — **not** codegen.

H5 was verified against `hurricane_stub.exe` — seven cases, all correct: scan completes with no
match → 2; kernel reports a match → 0; no CUDA devices → 3; all GPUs fail to prepare → 3; kernel
dies mid-run (1 GPU and 2 GPUs) → 3; reversed range → 1. **Exit code 4 (`EXIT_INTERRUPTED`) is
implemented but not empirically tested** — delivering a signal mid-scan to a child process is
awkward on Windows and the stubbed runs finish in milliseconds. It is a single `g_sigint` check
placed ahead of the failure and not-found checks.

One trap worth recording: the first mid-run-death run returned 2, not 3. That was the *test*, not
the code — the configuration only performed one launch (`Runs : 1`), so a failure scheduled for
launch #2 never fired. With the failure on launch #1 it correctly returns 3. Any future test of a
mid-run failure must confirm `runs_total` exceeds the launch it targets.

These live in the session scratchpad and will not survive. **Worth moving into the repo as a
`tests/` target** — `proof.py` needs a GPU and a built binary, so these remain the only coverage
that runs on the dev machine. (This plan document itself is now carried in the repo as
`DEVPLAN.md`; the harnesses are not, yet.)

### Still to do

1. **Build on the real target:** `make SM=<your arch>` — and address H12, or the binary will not
   launch on anything but sm_120. The WSL nvcc route above already answers the *compile* half for
   any arch CUDA 13 still emits SASS for; what it cannot answer is whether the resulting image
   loads on the card in front of you.
2. **Device-side canonicalization test:** the hash file is already host-compilable
   (`-D__device__= -D__forceinline__=inline -D__noinline__=` plus `__byte_perm`/`__funnelshift_r`
   stubs, per the comment at `GpuHash.cu:282`). Give `Math.cuh` the same treatment and assert
   `mul_mod`/`sqr_mod`/`inv_mod` outputs are `< p` — the direct test for C8/C9.
3. **Coverage regression on real hardware:** `proof.py` works again and generates the right cases —
   dual-parity keys at range start *and end*, full mod-B residue cover, per-quartile random keys
   with mod-B diversity. The end-of-range and full-mod-B blocks are the ones that would have failed
   before the C1 fix. **This has not yet been run against a real GPU** — it is the single highest-
   value outstanding verification step, and it is blocked on H12 for any card that is not sm_120.
4. **Targeted repros:**
   - C2: `--range 1000:1FFF` must scan and terminate.
   - C4: `--range 100:FF` and `--range 0:FFFF…FF` must be rejected with a clear message.
   - C6/H2: `--target-hash160 1z…` must be rejected, not truncated and not an abort.
   - C7: `--range 200:…` with `--grid 1024,B` must not produce a degenerate inversion.
   - H5: exit code 4 — Ctrl-C a real scan mid-range and confirm it reports interruption rather
     than exhaustion. The only H5 path not yet exercised. Do this **after** P1, or the signal will
     take up to 27 s to be observed and the test will look like a hang.
   - H4: `--range 1:0x204000400 --grid 1024,2 --slices 64` (see the reachability note above) must
     complete rather than hang. Note `compute-sanitizer --tool synccheck` will **not** flag the
     original defect — its "Invalid Arguments" check does not cover a named thread that never
     arrives — so a clean synccheck run is not evidence either way.
   - H3: the **second Ctrl+C** must terminate the process. Not empirically tested — MSYS2 cannot
     deliver SIGINT to a native ucrt64 binary, so the stub harness cannot exercise it. The reasoning
     is platform-split and worth confirming on both: on Windows the UCRT resets SIGINT to `SIG_DFL`
     before invoking the handler, so the second press terminates by default and the `_Exit` is
     belt-and-braces; on POSIX, glibc's `signal()` keeps the handler installed, so the second press
     is what actually reaches `std::_Exit`. Test with a wedged GPU, not a healthy one.
5. **Known-answer end-to-end:** a solved low puzzle (e.g. #30) with the key placed at the very
   last scalar of the range — the single case that distinguishes "fixed C1" from "still broken".
