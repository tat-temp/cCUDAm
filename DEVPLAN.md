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

## Status — 2026-08-13

**The coverage chain is closed end to end, and the program now reports what it did.** Every key in
the range is assigned to a thread, every thread's count is a whole number of batches so the kernel
loop drains to zero, every provisioned thread actually launches, and the run budget covers exactly
the launches required. When the run ends, the exit code and the console distinguish found,
exhausted, GPU failure and interruption. `proof.py` runs again and now actually checks the answer.

### Verified on real hardware — 2026-08-13

**`proof.py` passed 592/592, and the native cubin loads and launches.** Everything above had been
argued from source and from stub harnesses; this is the first time any of it executed on a device.

592 tests is the default generator at this batch size: 512 edge (128 each of start-A `start+2k`,
start-B `start+1+2k`, end-A `end-2k`, end-B `end-1-2k`) plus 80 quartile randoms, with the
dedicated residue block empty because the edge blocks already span every class mod B on their own.
Two properties make the count mean something rather than just being large:

- **The coverage invariant ran first.** `proof.py:601` computes `{(v - raw_start) % B}` over the
  whole test set and `sys.exit(1)`s if any class is missing, so a partial cover cannot be reported
  as a pass. All B residue classes were tested.
- **A pass requires the *key*, not the banner.** The harness compares the recovered private key
  against the planted one; a `FOUND MATCH` with the wrong key scores `WRONG_KEY`. This is the check
  whose absence let the pre-fix harness report 18/18 on a build that got 17 of them wrong.

What that closes, on device rather than by argument:

| | |
|---|---|
| **C1 / C2 / C3** | The 256 end-of-range keys are the direct C1 witness — they sit in the partial-batch tail the old loop guard dropped. Full mod-B cover exercises every offset within a batch. |
| **H1 / H5** | 592 runs each terminated on their own and returned a distinguishable exit code. |
| **H7** | 592 publications through `publish_found`, none torn — a torn scalar surfaces as a well-formed `WRONG_KEY`, which is exactly what the harness now looks for. |
| **The launch chain** | Constant-table upload, kernel launch, mapped-result read and teardown all work end to end, per GPU, 592 times. |
| **The native cubin path** | `cuModuleLoad` accepts the two-step device-linked `ET_EXEC` image, `cuModuleGetFunction("TestKernel")` resolves, `cuModuleGetGlobal` finds the `-rdc=true`-exported constant tables, `CopyToSymbol` fills them, and `cuLaunchKernel` accepts the 8-entry `args[]` — end to end, correctly, 592 times. The `ArgCnt = 1` and `STB_LOCAL` findings were both real and both correctly fixed. |

**What 592/592 is not evidence for** — worth stating, because a big green number invites the wrong
inference:

- **H4 is structurally excluded.** `proof.py` enforces a power-of-two range length, so
  `batch_cnt ≡ 0 (mod 32)` and `r1 = 0` — the straddling warp never exists. The H4 repro under
  *Targeted repros* remains the only thing that tests it, and it needs a non-power-of-two range.
- **The ragged configurations are untouched.** Every row of the C1 measured-effect table except the
  clean power-of-two one is outside what `proof.py` generates. That table is still host-side.
- **C7, C8/C9/C10** are unreachable here: `range_start ≥ 2·B` in any puzzle range, and the
  canonicalization defects sit at ~2^-224 on pseudorandom operands.
- **H12 is unaffected.** One card, one architecture. The portability defect is a claim about
  *other* cards and no run on this one can speak to it.

**The run was the native-cubin build**, not the default one:

```
make cubin SM=120 && make NATIVE_CUBIN=1 SM=120 -j4
```

That makes the native path the *first* configuration of this program ever shown to be correct on
hardware, and it upgrades several things from "the call returned success" to "the call did the
right thing":

- **`CopyToSymbol` genuinely uploads.** This is the one that could most easily have looked fine and
  been silently empty — a kernel running against a zeroed `c_Gx` launches happily, runs at full
  speed and finds nothing. 592 found keys is the direct refutation; the `-rdc=true` fix for the
  `STB_LOCAL` constant tables works.
- **The 8-entry `args[]` is laid out correctly.** The old hardcoded `ArgCnt = 1` read 56 bytes past
  an 8-byte allocation; anything wrong in the replacement would surface as wrong keys or a fault,
  not as a clean sweep.
- **`-rdc=true` device code is correct code.** The linked cubin is *not* the default build's kernel
  — 159,744 → 161,280 bytes, with `getHash160_33/_w2` moved out of `.text.TestKernel` into their own
  sections. That ABI change is now known not to break anything.

The mirror-image caveat, which matters because `make` with no flags is what anyone else would
build: **the default `<<<>>>` path did not run.** Under `USE_NATIVE_CUBIN` the launch, all five
`CudaCopy*` wrappers and the H15 drain-and-check are compiled out, and the device code that
executed came from the `-rdc` cubin rather than from `GpuCore.o`. Nothing suggests the default
build is broken — same sources, same ptxas, and its device code is byte-identical to the
pre-native-path build — but it is a separate configuration and it has not been proven. Closing that
is one rebuild and one rerun; see *Still to do* item 6.

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
| **H15** | A rejected launch was reported as a completed scan | `GpuCore.cu` — `CallGpuKernel` returns `cudaError_t` instead of `void`, and `Execute()` checks it, sets `Failed` and goes to `LExit` like the synchronize check beside it. The runtime path drains the last-error slot immediately before the launch and returns `cudaGetLastError()` after, so the value read can only describe that launch — which is what keeps H6 item 3's misattribution out while still catching the rejection. `GpuEc.cu`'s `CallGpuMulKernel` already used the launch-then-check half of this pattern and `PrepareCuda` the drain half; `Execute()` had neither. **Found by review, not by me:** my first version returned `cudaSuccess` unconditionally from the runtime path on the argument that a synchronize would catch it. That is false for synchronous rejections, and it left the defect alive on the path `make` actually builds. |
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

Everything below not marked **[FIXED]**. With coverage and reporting now confirmed on hardware
(592/592), the highest-value remainder is **H4's repro** — the one correctness fix the passing run
structurally could not exercise, since `proof.py` only generates power-of-two ranges — then **C7**
(the last silent key-loss path), **P1** (14-27 second kernel launches, which also governs Ctrl-C
latency and therefore how usable exit code 4 is), and **H12** (still one line, and still the reason
the binary runs on exactly one architecture).

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
| **C8** | **`mul_mod`/`sqr_mod` emit "almost reduced" results** — no final conditional subtract of P, and the carry out of `r[3]` is dropped. Deterministic witness: `a=2, b=(p+1)/2` → product is exactly `p+1 < 2^256`, both folds contribute 0, `mul_mod` returns `p+1` verbatim. Consumers need canonical form: `SHA256_33_from_limbs` serializes limbs raw, and `sub_mod_is_odd` derives the 0x02/0x03 prefix from `r[0]&1` (p is odd, so the prefix flips). ~2^-224 on pseudorandom operands. **RCAsm's hand-written `MulMod256` has the same defect** — measured on hardware, it returns `p+1` for `(P-1)²` and for that exact `a=2, b=(p+1)/2` witness — so the SASS route inherits C8 rather than fixing it, and this must be fixed on its own terms either way. | `Math.cuh:279-283`, `401-405` |
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
| **H12** | **Makefile ships SASS-only for sm_120, no PTX fallback.** On any other GPU the first launch fails with `cudaErrorNoKernelImageForDevice`. Contradicts `init_gpus`, which accepts every device with `major >= 6`, and the Makefile's own comment claiming 75/86/89/120 support. **Until H15 was fixed this failure was silent** — the card reported a fully scanned range and exit 2. It is now exit 3 with the error named, which is what makes H12 diagnosable at all. | `Makefile:11-12`, `:16` |
| **H15** **[FIXED]** | **A rejected kernel launch was reported as a completed scan.** A launch the driver refuses enqueues nothing, so `cudaStreamSynchronize` waits on an empty stream and returns `cudaSuccess`; the run loop counted launches that never happened and the program exited **2, "Range exhausted: key not found"**, having computed nothing. Present on both paths for different reasons: `cuLaunchKernel` returns its status directly and never touches the runtime's error slot, while `<<<>>>` expands to `cudaLaunchKernel` and **discards** its return, leaving synchronous rejections (`cudaErrorNoKernelImageForDevice` = H12, `cudaErrorLaunchOutOfResources`, `cudaErrorInvalidConfiguration`, and local-memory allocation failure — TestKernel asks for a 16 KB frame per thread, sized from `totalGlobalMem` rather than free memory) in the per-thread slot that only `cudaGetLastError` reads. A synchronize reports only kernels that actually *started*. | `GpuCore.cu` `CallGpuKernel`, `GpuPuzzle.cpp` `Execute()` |
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

## Hand-written SASS for TestKernel (RCAsm) — toolchain works on CUDA 13.0; the round-trip is dead

An avenue for going past P3/P4, evaluated 2026-08-12, re-measured and re-scoped 2026-08-13. Only
`TestKernel` is in scope; `scalarMulKernelBase` is explicitly out (it is the one-time setup kernel,
i.e. P5, and fixing P1 already shrinks it 12-24×).

**Headline, corrected twice — read this before the sections below, some of which predate it.**

1. *2026-08-12:* "round-trips almost, gated on CUDA 12.8." Drawn from a 24-instruction template.
   Did not survive contact with the real kernel.
2. *2026-08-13, first pass:* "the full `TestKernel` does not reassemble — 12.7% of its instructions
   have no encoder." True in its headline number, wrong in its breakdown, and wrong in what it
   implied. Only **5.1%** genuinely lack an encoder; the other 7.6% are known forms with unlearned
   operand values. More importantly it invited the inference "RCAsm cannot build our kernel,
   therefore RCAsm is not usable" — which does not follow.
3. *2026-08-13, current:* **`asm/GpuCore_sm120.asm` will not round-trip, and that does not block
   hand-written SASS.** Every unencodable form is one ptxas selected and a human author does not
   use: RCAsm's own hand-written sources contain zero `IADD.64`, zero `HFMA2`, zero `ISETP…U64`,
   zero `WARPSYNC`. The round-trip is only needed if the plan is to *edit ptxas output*; it is not
   needed to *write a kernel*.
4. *2026-08-13, measured end to end:* **RCAsm builds working cubins on CUDA 13.0.88** — sm_89 and
   sm_120, three one-line fixes, all in the RCAsm/cuAssembler tree and none in this project — **and
   the driver loads them** (RTX 5090, sm_120). The "12.8 or nothing" framing is dead and nothing is
   blocking the route any more. What remains unproven is that hand-written SASS *computes the right
   answer*, which is the whole of the risk; and the realistic prize is **~15%**, not the 31.2%
   `mul_mod` static share. See *What it would actually take* before planning around it.
5. *2026-08-14:* **the 12.7% encoder gap is not an encoder gap, and the hash layer does not have to
   be hand-written.** Both corrections come from the same measurement and both cut against what the
   two sections below say. cuAssembler *learns* encodings from samples; its shipped sm_120
   repository had never been fed real sm_120 SASS, and its feeder could not even parse sm_120
   (`CuInsFeeder.py:639` gates on `getMajor() in {7,8}`). Feed it our own kernel and 1,265 failures
   become **24**, all one instruction form with a trivial equivalent. Separately: `getHash160_33`
   and `getHash160_w2` touch **no memory at all**, are already out-of-line `CALL`ed functions in
   the shipped cubin, and reassemble **byte-for-byte** — so they can be lifted into an RCAsm
   `FUNCTION` rather than rewritten. Full measurement in
   [`asm/TESTKERNEL_TEMPLATE.md`](asm/TESTKERNEL_TEMPLATE.md) §9. **The ~15% ceiling is unchanged**
   — this removes risk and effort, not the bound.

**RCAsm** — <https://github.com/RetiredC/RCAsm>, GPLv3, Python, by RetiredCoder — is a SASS
assembler over a vendored, modified **CuAssembler** (MIT, cloudcores). sm_89 and sm_120 only. It is
a *template-injection* assembler, not a standalone one:

1. Write a dummy `.cu` with the signature you want; `nvcc -cubin` → template cubin, kept as
   `.cubin_orig`.
2. CuAssembler disassembles it to `.cuasm` (the whole ELF as text).
3. RCAsm compiles its own `.asm` dialect and **textually splices** the instruction stream in
   between `.text.<kernel>:` and the `.L_x_N` end label, patching the register count — the
   `EIATTR_REGCOUNT` word in `.nv.info` on sm_120, `SHI_REGISTERS` on sm_89.
4. Reassemble → cubin, then copy `.note.nv.tkinfo`/`.note.nv.cuver` back from `.cubin_orig`.
5. `CallCubin` (driver API, `cuModuleLoad` + `cuLaunchKernel`) loads it at runtime.

What it buys over PTX is real and is what P3/P4 cannot reach: register assignment, **control
codes** (the `[B------:R-:W0:-:S01]` prefix — wait-barrier mask, read/write barrier, yield, stall
count), the uniform datapath, carry-flag control, and calls that are not forced inlines.

**The actual prize is `Kernel02`.** It is a Kangaroo-style secp256k1 solver carrying hand-written
SASS for exactly this project's arithmetic layer — `MulMod256`, `SqrMod256`, `MadMod256`,
`SqrAddMod256`, `SubMod256`, `SubMod256_3` (our `sub_mod3`), `AddMod256`, `NegMod256`, `InvMod256`
— with a claimed 120 G/s `MulMod256` on a 4090. That is a reference implementation of `Math.cuh`,
independent of whether RCAsm itself is ever adopted. Its sources are in `asm/` (`mod_mul.asm`,
`mod_inv.asm`, `mod_sub.asm`, `fuse.asm`, `main.asm`, `newKernelB.asm`).

### Where the arithmetic actually is — `asm/GpuCore_sm120.map`

`asm/GpuCore_sm120.asm` is the CuAssembler-format dump of the shipped kernel (1.47 MB, whole ELF
as text, control codes included). `asm/GpuCore_sm120.map` maps every one of its 9,984 instructions
to the `Math.cuh` function it came from.

**How the map was built, and why it can be trusted:** compile `GpuCore.cu` with `-lineinfo`,
confirm `.text.TestKernel` is **byte-identical** to the plain build (159,744 B — verified, so the
attribution transfers with no drift), then read `nvdisasm -gi` inline call-stacks (max depth 6) and
take the **outermost `Math.cuh` frame**. That folds `mul_256_by_64`/`add_320_to_256` into
`mul_mod`, `add_320_to_256s` into `sqr_mod`, the 288-bit helpers into `inv_mod`, and resolves
`mul_256_by_P0inv` — shared between `mul_mod:261` and `sqr_mod:383` — by real call site rather
than by adjacency. Everything is `__forceinline__`, so there are no labels: what exists is one
region per call site.

| Function | Instrs | Share | Call sites | Per call | RCAsm hand-written |
|---|---:|---:|---:|---:|---:|
| `mul_mod` | 3,113 | 31.2% | 14 | ~222 | `MulMod256` **112** |
| `inv_mod` | 890 | 8.9% | 1 | 890 | `InvMod256` 164 — *not comparable, see below* |
| `sqr_mod` | 844 | 8.5% | 4 | 211 | `SqrMod256` **125** |
| `sub_mod` | 250 | 2.5% | 14 | ~18 | `SubMod256` **16** |
| `sub_mod3` | 125 | 1.3% | 4 | ~31 | `SubMod256_3` **18** |
| `sub_mod_is_odd` | 27 | 0.3% | 3 | 9 | — |
| `neg_mod` | 24 | 0.2% | 2 | 12 | `NegMod256` **8** |
| `add_mod` | 0 | — | 0 | — | `AddMod256` 16 |
| *hash* | 4,066 | 40.7% | (4) | — | — |

Notes that matter before anyone acts on that table:

- **`add_mod` is never called.** Dead in `TestKernel`.
- **The `inv_mod` row is not a fair comparison and should not be quoted as one.** RCAsm's
  `InvMod256` `CALL`s six separate helper `FUNCTION`s, so its 164 excludes work our inlined 890
  includes — real calls instead of forced inlines being exactly what hand-written SASS buys.
- **The hash 40.7% is a *static* count**, not the dynamic ~69% recorded under section C. Both hash
  functions are emitted once, as `__noinline__` bodies inside `.text.TestKernel`
  (`getHash160_33_from_limbs` at 0x171e0, `getHash160_w2_from_limbs` at 0x1f1b0), and called from
  4 sites.
- **`neg_mod` and `sub_mod_is_odd` are shredded** — ptxas scattered their 12 and 9 instructions
  into 1-5 instruction fragments across ~0x250 bytes. There is no contiguous region to lift out;
  they exist only in context.
- Blocks ≥12 instructions cover 92.5% of the kernel; the other 7.5% is ptxas interleaving across
  region boundaries. `mul_mod` at call sites `:157` and `:261` has the lowest density (64.8%,
  92.1%) because `inv_mod`'s prologue is scheduled into it.

### The real kernel does not reassemble — **overturned 2026-08-14, see the correction below**

> **This whole section measured an empty repository, not a missing encoder.** The numbers below
> are reproducible and were correctly obtained; the *conclusion* drawn from them is wrong.
> cuAssembler solves for encodings from disassembly samples, and its shipped sm_120 repository had
> never been fed any. Once it is, **1,265 failures become 24** — one instruction form, with an
> exact one-instruction equivalent — and the kernel reassembles byte-for-byte outside a handful of
> control-transfer instructions. "Group 1 — genuinely no encoder" is the specific claim that does
> not survive: all 444 `IADD.64`s learned, as did `ENDCOLLECTIVE`, `R2UR`, `LDCU` and `WARPSYNC`.
> Kept in place because the shape of the error matters and because the *reason* nobody had found
> this is itself a finding: `CuInsFeeder.py:639` gates the learning path on
> `smversion.getMajor() in {7,8}`, so on sm_120 the repository **could not be taught anything at
> all**. Numbers, method and the two extra one-line fixes are in
> [`asm/TESTKERNEL_TEMPLATE.md`](asm/TESTKERNEL_TEMPLATE.md) §9.3–§9.5.

`asm/GpuCore_sm120.asm` → cubin **fails**. After `.tkinfo` is commented out to get the parser
started, it dies at instruction #12:

```
/*00b0*/ HFMA2 R3, -RZ, RZ, 0, 0 ;   ->  Unknown InsKey(HFMA2_R_R_R_II_FI) in Repos!
```

Sweeping all 9,984 instructions rather than stopping at the first failure:
**1,265 of them (12.7%) fail to assemble.** They split into two groups that need to be kept apart,
because they are different problems with different costs:

**Group 1 — genuinely no encoder (508 instructions, 5.1%), 15 InsKeys:**

| Missing InsKey | Count | Example |
|---|---:|---|
| `IADD_*` — `IADD.64` / `IADD.64.X`, 9 distinct keys | 444 | `IADD.64 R6, R6, -R62` |
| `HFMA2_R_R_R_II_FI` | 24 | `HFMA2 R3, -RZ, RZ, 0x0, 0` — the MOV idiom |
| `WARPSYNC_R_II` + `ENDCOLLECTIVE` | 24 | `WARPSYNC.COLLECTIVE R4, 0x16ad0` |
| `R2UR_P_UR_R` | 8 | `R2UR P1, URZ, R4` |
| `LDCU_UR_cAURI` | 4 | `LDCU.128 UR8, c[0x3][URZ]` |
| `CGAERRBAR` | 4 | `CGAERRBAR` |

**Group 2 — the InsKey *is* known, the operand isn't (757 instructions, 7.6%):**

| Failure | Count | Example |
|---|---:|---|
| `Assembling failed (NewVals): Insufficient…` | 584 | `@!P1 BRA.DIV UR4, 0x16ea0` |
| `Assembling failed (NewModi): Unknown modifier` | 173 | `ISETP.GE.U64.AND P0, PT, R2, UR6, PT` |

**Do not read those two rows as "584 `BRA.DIV`s".** They are bucketed by *error string*, not by
mnemonic, so each aggregates every instruction that failed that way across all mnemonics; the
example is just the first one seen. The kernel contains **8** `BRA.DIV` in total (77 plain `BRA`,
4 `BRA.CONV`) and 18 `ISETP…U64` lines. An earlier version of this table labelled these rows by
their examples and so implied that one `BRA.DIV` encoder would clear 584 instructions. It would
clear at most 8. Group 2 is not an encoder-writing problem at all — cuAssembler *solves* for
encodings from disassembly samples, and "insufficient values" means its repository has not seen
enough variety of that form, which is fed rather than coded.

The shape of Group 1 is the finding. `IADD.64` is the carry-chain backbone of every routine in
`Math.cuh`, and RCAsm's `NewOpsHandler.py` hand-encodes exactly **one** of its ten forms
(`IADD_R_P_R_R_P`). This is not a formatting problem that a toolkit version can fix.

**But every missing form is a ptxas *choice*, not a requirement** — which is why this blocks the
round-trip and not the route. Counting the same mnemonics across RCAsm's own hand-written Kernel02
sources in `asm/` (`mod_mul`, `mod_inv`, `mod_sub`, `fuse`, `main`, `newKernelB`) against our
ptxas-generated `asm/GpuCore_sm120.asm`:

| Form | Hand-written | ptxas-generated |
|---|---:|---:|
| `IADD.64` | **0** | 723 |
| `IADD3` | 754 | 3,757 |
| `HFMA2` | **0** | 24 |
| `ISETP…U64` | **0** | 18 |
| `WARPSYNC` | **0** | 13 |
| `R2UR` | **0** | 8 |
| `CGAERRBAR` | **0** | 4 |

Hand-written SASS carries its carries in the classic `IADD3`/`IADD3.X` chain, which cuAssembler
knows; ptxas prefers the fused 64-bit form, which it does not. Nothing in Group 1 has to be written
by a person authoring a kernel — so the correct conclusion is **"`GpuCore_sm120.asm` will not
round-trip"**, not "RCAsm cannot build a cubin".

### The trap that invalidated the first measurement — worth recording

The first sweep reported 1,569 missing. It was wrong. `Config.SM_VER` **defaults to 89**, and the
only thing that changes it is `CuAsmParser.set_sm()`. A harness that constructs `CuAsmParser()` and
calls `parse()` without `set_sm(120)` silently skips the two sm_120-gated encoders in
`NewOpsHandler.check_new_ops` — `LDCU_UR_cAI` (25 instructions) and `IADD_R_P_R_R_P` (279),
exactly the 304 difference. Anyone driving RCAsm headless will hit this. Set both
`Config.SM_VER = 120` and `cap.set_sm(120)`.

### What the template test got right, and where it misled

The 24-instruction template test (2026-08-12) still stands on its own terms — it is just not
representative. Kept because each item is independently true:

- **`.tkinfo`.** 13.0's nvdisasm emits a directive `CuAsmParser` has no handler for; the string
  appears nowhere in cuAssembler. Must be neutralized before anything parses. Reproduced on the
  real kernel.
- **`.note.nv.cuver` does not exist in CUDA 13.0 cubins** and RCAsm's `patch_cubin` requests it
  unconditionally, so that step `KeyError`s.
- **`.note.nv.cuinfo` is truncated 0x20 → 0x08 bytes** by the round-trip — data loss, not a
  formatting quibble. **Now fixed**: add it to `patch_cubin`'s copy list, see below.
- ~~ELF header flags degrade `EF_CUDA_SM120 EF_CUDA_VIRTUAL_SM(...)` → `EF_CUDA_SM120
  unrecognized:0`.~~ **Did not reproduce.** On the full end-to-end run the flags come out
  bit-identical to the template — `0x6007802` for sm_120, `0x6005904` for sm_89. Whatever produced
  the degraded flags in the template experiment, it is not inherent to the round-trip.
- **3 of the template's 24 instructions differed**, all **bit 101** on the `desc[UR4]` global
  memory ops (`LDG.E.64.CONSTANT` ×2, `STG.E.64` ×1): cuAssembler's `LDG_R_ARURI_P`/`STG_ARURI_R`
  set it, ptxas leaves it clear. Both decode to identical instruction text.
- `cuobjdump -sass` reads the patched cubin (rc=0) while `nvdisasm` refuses it, so malformed notes
  are not fatal to all tooling.
- **Keep any template body trivial.** The `HFMA2` MOV idiom that broke the first template is not a
  template artifact at all — it occurs **24 times in the real kernel** and is the first thing the
  full round-trip trips over. RCAsm's own sample is one line for this reason.
- **The single-struct signature is free.** `.nv.constant0.TestKernel` is 952 bytes (0x3b8) for
  *both* the 8-argument form and a single by-value struct — params at `0x380`, 56 bytes. Still
  true, but no longer needed: the native path below passes 8 arguments properly.

**Is CUDA 12.8 still worth installing? No — settled 2026-08-13.** It was "the gate", then "one
experiment", and it is now neither: RCAsm builds working cubins on 13.0.88 with three one-line
fixes, measured end to end (next section). The remaining 12.8 hypothesis — that its nvdisasm prints
unfused forms cuAssembler already knows — would only ever have helped the *round-trip*, which is
not the route. Do not install 12.8 for this.

### RCAsm builds cubins on CUDA 13.0 — measured end to end, 2026-08-13

The experiment the previous revision of this section called for. Test vehicle is **Kernel01**, not
Kernel02: Kernel02 ships only `.asm` sources — no `.cu` template, no build scripts, no host code —
and injection is the only route to a cubin, so reconstructing it would mean guessing two 8-byte
parameter fields the SASS never reads. Kernel01 ships `kernel.cu`, `main.asm`, `mul.asm` and the
`a_`/`b_` scripts, and is RCAsm's own working demo.

**Result: `RESULT: SUCCESS` on both sm_89 and sm_120.**

| | template (nvcc 13.0) | RCAsm output |
|---|---:|---:|
| sm_89 | 3,240 B | **5,032 B** |
| sm_120 | 5,336 B | **7,324 B** |

sm_120 output: ELF `Type: EXEC`, flags `0x6007802` (**identical** to the template), `.note.nv.tkinfo`
0xa4 and `.note.nv.cuinfo` 0x20 (**both identical** to the template after the fix below),
`mulKernel` `GLOBAL FUNC` size 2304, `REG:255`, 144 SASS lines via `cuobjdump -sass` against the
template's 24. The injected body is visibly RCAsm's, including sm_120 uniform-datapath forms
(`LDCU.64 UR0, c[0x0][0x358]`). The `REG:255` confirms the `EIATTR_REGCOUNT` patch — the
line-offset hack over nvdisasm's comment text — still lands on **13.0's** output format, which was
the single most-likely-to-break step.

**Three one-line fixes, all in the RCAsm/cuAssembler tree, none in this project:**

1. `cuAssembler/CuAsm/config.py` — `NVDISASM_PATH` is hardcoded to
   `/usr/local/cuda-12.8/bin/nvdisasm` (the source comment reads "ONLY 12.8 IS TESTED!").
   Repoint it, or override `Config.NVDISASM_PATH` at runtime. Without this the cubin→cuasm
   direction dies at `FileNotFoundError` and nothing else can run.
2. **Neutralize the `.tkinfo` directive** — comment out the *single* bare `.tkinfo` line in the
   generated `.cuasm` (the other five matches are comments). Without it, `CuAsmParser.parse`
   asserts `Unknown directive .tkinfo!!!`, `cuasm2cubin` swallows it into `False`, and
   `create_cubin` returns before `patch_cubin` is ever reached — which is why the `.cuver`
   `KeyError` had never actually been observed.
3. `compiler.py replace_sections_data` — wrap the two `section_by_name` calls in
   `try/except KeyError: continue`, **and** add `".note.nv.cuinfo"` to `patch_cubin`'s copy list.
   The first half handles `.note.nv.cuver`; the second repairs the 0x20 → 0x08 truncation by
   copying the section back from `.cubin_orig`.

**`.note.nv.cuver` really is absent from CUDA 13.0 cubins** — verified directly rather than
inferred: a freshly compiled `-arch=sm_120 -cubin` carries exactly `.note.nv.tkinfo` and
`.note.nv.cuinfo`, nothing else. So `patch_cubin`'s unconditional request for it always
`KeyError`s on 13.0. Confirmed at `compiler.py:885` → `compiler.py:803`.

**The control that makes the result interpretable.** `nvdisasm` still refuses the *injected*
cubin, which by itself would be alarming — this document already warns that a hand-written kernel
`nvdisasm` cannot read is indistinguishable from a bug in the assembly. So the round-trip was run
with **no injection at all**: template → `.cuasm` → cubin → notes patched back.

| | `nvdisasm` |
|---|---|
| original template | ACCEPTS, 24 SASS lines |
| round-tripped, notes unpatched | REJECTS — `Invalid note section: '.note.nv.tkinfo'` |
| round-tripped, **notes patched** | **ACCEPTS, 24 SASS lines** |

So cuAssembler's ELF writing is sound on 13.0 once the notes are restored, and the note handling is
the whole of the toolkit-version problem. `.text.mulKernel` round-trips 384 → 384 bytes with
**3 differing bytes**, at offsets 76, 92 and 140 — all byte 12 of an instruction, i.e. bits 96-103.
That is the same **bit 101** `desc[UR4]` discrepancy the template test found, reproduced exactly and
now localized.

**What `nvdisasm` is actually complaining about in the injected cubin is not a defect.** With the
notes fixed the error changes to `Could not establish the target of 'BRXU' branch operation`.
`BRXU` is an indirect branch through a uniform register — it appears once in the assembled cubin,
zero times in the template, and three times in RCAsm's own `main.asm`
(``BRXU LoopAdr0, `(.label_loop_beg)``). It is RCAsm's loop/call idiom, and `nvdisasm` cannot
statically resolve an indirect target. `cuobjdump -sass` reads all 144 lines. **This does mean
`nvdisasm` is not a usable check on hand-written RCAsm output — use `cuobjdump`.**

### The driver accepts it — RTX 5090, 2026-08-13

`rcasm_test/rcasm_load_test.cpp` against `rcasm_test/kernel_sm120.cubin`:

```
  device: NVIDIA GeForce RTX 5090 (sm_120)
  OK    cuModuleLoad
  OK    cuModuleGetFunction
    NUM_REGS        255
    MAX_THREADS     256
    SHARED_BYTES    0
    LOCAL_BYTES     0
    CONST_BYTES     0
    BINARY_VERSION  120
```

**The RCAsm carrier is proven end to end.** Assemble → load → resolve, on CUDA 13.0.88 hardware.
Combined with the native cubin path's 592/592, every piece of machinery between "hand-written
`.asm`" and "a kernel this program launches" is now measured rather than assumed.

Two details in that dump are worth more than the verdict line:

- **`MAX_THREADS 256` is derived, not echoed.** The driver computed it from `NUM_REGS 255` against
  the register file — so it did not merely tolerate the injected `EIATTR_REGCOUNT`, it *acted* on
  it. That is the strongest available evidence that RCAsm's regcount patch — a line-offset hack
  over nvdisasm's comment text, and the step most likely to break silently on a new toolkit —
  produces metadata the driver genuinely consumes.
- **`BINARY_VERSION 120`** — the driver classifies the round-tripped image as a native sm_120
  binary, despite the note sections having been rebuilt and patched.

**What this does *not* establish: that an RCAsm-built kernel computes the right answer.** Nothing
has been launched. Load and resolve are necessary, not sufficient, and the probe stops there
deliberately — `mulKernel` takes a by-value struct, so a wrong launch is a hang, not a diagnostic.
Correctness of hand-written SASS remains entirely unproven and is the whole of the risk in this
route.

**A constraint to design around, visible here for the first time:** 255 registers per thread caps
the block at 256 threads and holds occupancy very low. That is presumably deliberate in Kernel01,
which is a `MulMod256` throughput benchmark. `TestKernel` is not that shape — it needs occupancy to
hide memory latency, and it already carries a 16 KB local frame (P2). RCAsm also supports only 63
uniform registers on sm_120 per its README. Any hand-written `TestKernel` has to live inside that
budget, and `make ptxinfo SM=120` (Hardening item 10, still not run) is what says how much room
there actually is.

### Native cubin path — implemented and **verified on hardware**, `make NATIVE_CUBIN=1`

Independent of whether RCAsm is ever adopted, the host can now load `TestKernel` from a `.cubin`
through the driver API instead of the runtime `<<<>>>` launch, so a hand-written kernel can be
swapped in without rebuilding anything. **This is the build that passed `proof.py` 592/592** — see
*Verified on real hardware* at the top; the path is not merely wired up, it is the one configuration
of this program with a known-good result on a device:

```
make cubin SM=120 && make NATIVE_CUBIN=1 SM=120 -j4
```

`NATIVE_CUBIN=<path>` names the file (default `GpuCore.cubin`); the path is resolved at **run**
time relative to the working directory. Unset, the build is unchanged — verified byte-identical
device code (159,744 B). The hook is `CallGpuKernel` in `GpuCore.cu`, plus the five `CudaCopy*`
wrappers, all behind `#if USE_NATIVE_CUBIN`.

Two things found while building it that dictated the design:

1. **The `__constant__` tables are `STB_LOCAL`.** `c_Gx`/`c_Gy`/`c_Jx`/`c_Jy`/`c_target_words` are
   local symbols in a normal cubin, so `cuModuleGetGlobal` cannot find them and the kernel would
   run against an empty constant bank. `extern "C"` does **not** help — measured. Only
   `-rdc=true` does.
2. **`-rdc=true -cubin` produces an unloadable file** — ELF `Type: REL` with 10 undefined symbols,
   and `cuModuleLoad` requires `ET_EXEC`. The `cubin` target therefore does a two-step device link
   (`-rdc=true -c`, then `-dlink -cubin`), giving `Type: EXEC`, 219,240 B, 0 undefined symbols, all
   five tables `GLOBAL`.

**`-rdc` is not free, and this matters for any benchmark.** It stops `getHash160_33/_w2` being
emitted inside `.text.TestKernel` and gives them their own sections: 0x27000 → 0x17700 + 0x8080 +
0x7e80, i.e. **159,744 → 161,280 bytes, +96 instructions (+0.96%)**. The native-cubin kernel is
therefore *not* the same code as the default build. Diff against `make sass` before reading
anything into a timing difference.

The 592/592 run settles the *correctness* half of that — out-of-lining the two hash bodies changes
nothing about the answers — but says nothing about the cost half. It also means the two builds are
now asymmetric in what has been proven about them, in the direction nobody would guess: the
**non**-default build is the verified one. Keep both honest — `make sass` on each, and run
`proof.py` against whichever one a timing claim is about.

`NativeCubin()` keys one `CUmodule` per **GPU**, not per thread: `Prepare` uploads the constants
from the main thread while `Execute` launches from the worker thread, and both must reach the same
module. A `CUmodule` belongs to a context, and the runtime primary context is per-device and shared
across threads, so per-device is the correct granularity.

### `CallCubin.cpp` / `CallCubin.h` — the five issues, now fixed

Copied from RCAsm's `Kernel01`, with `CopyToSymbol` and a `cuFuncSetAttribute` call added by the
owner. All five findings from 2026-08-12 have been addressed:

1. **`ArgCnt` was hardcoded to 1** — correct for RCAsm's one-struct convention, wrong for
   `TestKernel`'s 8 arguments: `cuLaunchKernel` reads as many `kernelParams` entries as the
   signature declares, so it read 56 bytes past an 8-byte allocation and passed the garbage as
   `Px`/`Py`/`find_result`. **Fixed:** `TCallKernelParams` gained `kernel_args`/`kernel_arg_cnt`;
   supply them for a multi-argument kernel, leave them zero and the old single-struct behaviour is
   unchanged. The `malloc` is gone with them.
2. **`~TCubinCall()` never called `cuModuleUnload`** and a second `LoadCubin` leaked the first
   module. **Fixed:** new `Unload()`, called from the destructor and at the head of `LoadCubin`;
   copy ctor and assignment deleted.
3. **Context.** `cuModuleLoad` needs a current context and `cudaSetDevice` alone does not create
   one (the primary context is lazy). **Fixed:** `cudaFree(0)` in `LoadCubin`.
4. **Build.** `#pragma comment(lib, "cuda.lib")` is MSVC-only. **Fixed:** wrapped in
   `#ifdef _MSC_VER`; the Makefile adds `CallCubin.cpp` to `CPU_SRC` and
   `-L$(CUDA_PATH)/lib64/stubs -lcuda` under `NATIVE_CUBIN`.
5. **Two `res != cudaSuccess` comparisons mixed `CUresult` with `cudaError_t`** — working only
   because both enums are 0. **Fixed** to `CUDA_SUCCESS`.

Also: `cuFuncSetAttribute` is now skipped when `sharedSize == 0` (the case here), every error
message names the symbol or function it failed on, `CopyToSymbol` bounds-checks against the
symbol's real size, and a `CUDA_ERROR_NOT_FOUND` from `cuModuleGetGlobal` says outright that the
cubin needs `-rdc=true`.

### Licensing — decide before this goes further

RCAsm is **GPLv3**; the CuAssembler underneath is MIT. `CallCubin.cpp/h` are RCAsm's files and the
copy in this tree has the `// (c) RetiredCoder, 2026` line removed. This repository has no LICENSE
file at all. GPLv3 is copyleft; adopting RCAsm's runtime helper is a licensing decision, and the
dropped notice is a separate matter from the licence choice.

### Blocked on, in order

1. **Nothing, if the goal is a hand-written kernel.** This item used to read "the 17 missing
   InsKeys, and it is the expensive one." That was the right blocker for the wrong goal. The
   missing encoders block *re-assembling ptxas output*; they do not block *authoring* SASS, because
   every one of them is a form ptxas chose and a hand-writer does not use — see the two comparison
   tables above. Writing the `IADD.64` family into `NewOpsHandler.py` is only worth doing if the
   round-trip itself is the goal (e.g. to diff a modified kernel against the original), and it buys
   444 of 9,984 instructions, not the 584 the old table implied.
   **Superseded 2026-08-14 — nobody has to write any encoder.** Feeding `CuInsAssemblerRepos.update`
   the shipped kernel's own SASS learns all 444 `IADD.64`s and everything else bar one form, in
   about five seconds. The round-trip *is* available after all, which matters because it is what
   lets a lifted function be diffed against the original bytes. Requires
   `CuInsFeeder.py:639` to accept sm_120 first — see `asm/TESTKERNEL_TEMPLATE.md` §9.3–§9.5.
2. ~~**Does RCAsm work on CUDA 13.0 at all?**~~ **Settled 2026-08-13 — yes.** Kernel01 assembles
   for both sm_89 and sm_120, with three one-line fixes and no GPU required to get that far. See
   *RCAsm builds cubins on CUDA 13.0* above for the fixes, the output, and the un-injected control
   that proves the ELF writing is sound. ~~CUDA 12.8~~ is not needed and should not be installed
   for this.
2c. ~~**Run the probe on the GPU.**~~ **Cleared 2026-08-13 — the driver accepts it.** RTX 5090,
   sm_120: `cuModuleLoad` and `cuModuleGetFunction` both succeed, and `MAX_THREADS 256` shows the
   driver acted on the injected register count rather than merely tolerating it. `rcasm_test/`
   carries the probe and its fixtures. Note `nvdisasm` is *not* a usable pre-check on RCAsm output
   — it refuses any kernel containing `BRXU`, RCAsm's own loop idiom — so use `cuobjdump -sass`.

**Nothing is blocking any more.** The route is open and the remaining work is the work itself:
writing `TestKernel`'s body in RCAsm's dialect and proving it computes the right answer. See
*What it would actually take* below before committing to that.
3. ~~**A real GPU.**~~ **Cleared 2026-08-13, and more completely than this item asked for.** The
   native cubin path did not merely load — `proof.py` passed **592/592 through it**, so
   `cuModuleLoad`, `cuModuleGetGlobal`, `CopyToSymbol` and `cuLaunchKernel` are all verified to do
   the right thing, not just to return success. **The carrier is proven.** Whatever instruction
   stream item 1 eventually produces has a loading path that is known-good and a known-good
   reference result to be diffed against — which is worth more here than it sounds, because it
   turns "the hand-written kernel is wrong" and "the harness around it is wrong" into separable
   questions. What a GPU is still needed for is judging the assembly itself: a hand-written-SASS
   kernel whose cubin `nvdisasm` will not read is a failure mode indistinguishable from a bug in
   the assembly.
4. ~~`pip install PyQt5 QScintilla` even for batch builds.~~ **Not needed.** RCAsm's `compiler.py`
   imports `utils.py`, which imports `QByteArray`/`QFileDialog`/`QWidget` at module scope — but
   only *at import time*; the headless path never calls into them. Three empty classes injected
   into `sys.modules` are enough, and no RCAsm file needs editing. There is also **no batch entry
   point at all** — `rcasm.py` only opens the Qt editor, and `compiler.compile_code` is reached
   solely from the editor's F5 handler, so a driver has to be written. That driver is
   `scratchpad/rc_drive.py` (~40 lines: stub Qt, set `defs.SM_VER`/`PROJECT_PATH`/`AUTO_RUN=False`,
   reproduce `editor.collect_all_lines`, call `compile_code(liness, True)`, never `run_exe`).
5. **Two traps worth keeping**, both of which cost time here:
   - `cuAssembler/CuAsm/__init__.py` does `from CuAsm.X import Y`, so `cuAssembler/` must be on
     `sys.path` for `CuAsm` to resolve as a *top-level* package — importing it as
     `cuAssembler.CuAsm.*` alone fails.
   - Worse, the package is reachable under **two names that are distinct module objects**:
     measured, `CuAsm.config.Config is cuAssembler.CuAsm.config.Config` → **False**. Setting
     `Config.SM_VER` on the wrong one is a silent no-op, and `Config.SM_VER` defaults to 89 —
     the same trap that invalidated the first gap measurement. Set both.

### RCAsm's `MulMod256` is "almost reduced" too — measured on hardware 2026-08-13

The correctness question, answered. RCAsm's Kernel01 *is* a `MulMod256` benchmark whose host
harness already cross-checks every GPU result against `EcInt::MulModP`, so the test was mostly a
build. Run on the RTX 5090:

```
KAT mismatch at vector 6
  expected: 0000000000000000 0000000000000000 0000000000000000 0000000000000001
  got     : FFFFFFFFFFFFFFFF FFFFFFFFFFFFFFFF FFFFFFFFFFFFFFFF FFFFFFFEFFFFFC30
KAT FAILED: 3 of 256 vectors wrong, first at 6
CHECKRES OK
```

`got - P == 1` exactly. **It returned `P+1` where `1` is correct** — congruent, not canonical.
That is **C8, in RCAsm's implementation**: no final conditional subtract of P. The multiply itself
is right; 253 of 256 vectors are exact and the 3 failures are all the same congruent value.

Failing vectors are `(P-1)²`, `2·(P+1)/2` and `(P+1)/2·2` — every one of them a product that lands
exactly on `P+1`. Seven of the 18 edge vectors *could* have exposed this; the other four have
products small enough that the computation never overshoots.

Three things follow, in ascending order of importance:

1. **Hand-written SASS does not fix C8 — it inherits it.** Adopting `MulMod256` gets ~2× on the
   instruction count and the *same* canonicalization defect. C8 has to be fixed on its own terms
   whichever implementation is used, and Hardening item 9 stays exactly where it is.
2. **This is a legitimate choice upstream, and a dangerous one here.** For a Kangaroo solver a
   non-canonical intermediate is usually harmless because the next operation re-reduces. This
   project has two consumers that cannot tolerate it: `SHA256_33_from_limbs` serializes limbs raw,
   and `sub_mod_is_odd` derives the 0x02/0x03 compressed-pubkey prefix from `r[0]&1`. P is odd, so
   `P+1` versus `1` **flips the parity**, which flips the prefix, which changes the hash — a
   silently missed key. Same reasoning as C8's own entry.
3. **`CHECKRES OK` printed on the same run.** RCAsm's shipped check compares the SASS against
   `EcInt::MulModP`, and that C++ produces the identical `P+1`. Both sides share the convention, so
   the self-consistency check passes while both are non-canonical. **This is the H14 lesson
   again**: a harness that compares an implementation against a reference sharing its bug reports
   success and proves nothing. The only reason this was caught is that the known-answer vectors
   come from Python arbitrary-precision `(a*b) % P` and share nothing with either side.

**And it would have been missed by a random-operand test.** All 238 random vectors passed —
a random product landing in `[P, 2^256)` has probability ~2^-224. Only the deliberately
constructed edge cases found it. Whatever else is built here, the edge vectors are the part that
earns its keep.

### What a hand-written `TestKernel` template looks like — [`asm/TESTKERNEL_TEMPLATE.md`](asm/TESTKERNEL_TEMPLATE.md)

Written up separately because it is long. The template exists, compiles, produces byte-identical
parameter metadata to the shipped kernel, and has been driven through the full RCAsm inject path
successfully with the constant tables keeping `GLOBAL` binding — so `cuModuleGetGlobal` and the
existing `CopyToSymbol` path survive. It needs a **fourth** one-line fix beyond the three above:
`'@"STT_CUDA_OBJECT"': 13` in `CuAsmParser.py:104`, because the device linker rewrites
`.nv.reservedSmem.offset0`'s symbol type to a CUDA-specific value the validation table does not know.

Two results from that work matter here.

**The encoder gap does not block this route — proven.** The template cubin *fails* a plain
round-trip (`IADD3 ... -R10`, `Unknown modifiers: {'5_cNEG'}`) and *succeeds* under injection,
because `inject_kernel` replaces the instruction stream before the assembler sees it. The 12.7%
measured above only ever blocked re-assembling ptxas output, which is not what anyone would do.

**But the hybrid is closed, and that is expensive.** A device link emitting a separately linkable
`__device__` function creates a `.nv.prototype` section carrying a `str_index@` expression that
CuAsmParser does not implement, so *any* cubin with more than one `.text` section fails to
reassemble — including the shipped `GpuCore.cubin`, which has three. Under `-rdc` that is exactly
what `getHash160_33`/`_w2` become. So the hash layer cannot be kept as nvcc-compiled callees and
must be hand-written too: **4,066 instructions, 40.7% of the kernel**, replacing code recorded here
as machine-checked against `hashlib` and at its floor. Inlining them instead does not help —
injection discards the whole template body regardless.

Implementing `str_index@` is therefore the highest-leverage single item on this route. It is not a
one-liner like the other four, but it removes ~4,000 instructions of hand-written hash code from
the estimate and is the difference between rewriting the 31% worth rewriting and rewriting
everything including the part this document says not to touch.

### The hash layer is a lift, not a rewrite — measured 2026-08-14

The paragraph immediately above is superseded. `str_index@` is no longer the unlock, and the
~4,000 instructions never have to be written by hand.

`getHash160_33` and `getHash160_w2` **touch no memory whatsoever** — the entire opcode inventory of
both bodies is `SHF`, `IADD3`, `LOP3`, `LEA`, `PRMT`, `UMOV`, `MOV`, `HFMA2`, `RET`, `BRA`, `NOP`.
No `LDG`/`STG`, no `LDL`/`STL`, no `LDS`/`STS`, not even an `LDC`: `GpuHash.cu`'s
`static constexpr uint32_t K[64]` really does fold into immediates, as its own comment claims. And
ptxas has **already made them out-of-line functions** — `STT_FUNC` symbols at 0x171e0 and 0x1f1b0,
each reached by 4 × `CALL.REL.NOINC`, each ending in `RET.REL.NODEC R6`. That is the shape of an
RCAsm `call_func` target already.

With the sm_120 repository taught from our own SASS, both bodies **reassemble byte-for-byte**:

| region | instrs | `HFMA2`→`MOV` | unexplained byte differences |
|---|---:|---:|---:|
| `getHash160_33` | 2,045 | 1 | **0** |
| `getHash160_w2` | 2,021 | 1 | **1** |

The `HFMA2` is ptxas loading a small integer constant on the FP16 pipe (`MOV Rd, imm` is exact).
The single remaining difference is `getHash160_w2`'s closing `RET.REL.NODEC` — a PC-relative
target that `nvdisasm` prints as an absolute address, so the solver cannot tell the two `RET`s
apart and reuses one encoding for both. **That is the one instruction the conversion deletes**:
`call_func` ends a `FUNCTION` with the caller's `Ret=` string (``BRXU.U uCallX, 0x00``), never with
`RET.REL.NODEC`.

So the hash moves *into* the injected instruction stream instead of living outside it in a second
`.text` section, and the one-`.text` rule stops binding. What is left is real but much smaller:
renaming ptxas's `R0..R104` allocation into RCAsm's `Ri`/`Ro`/`Rt` scheme, one internal label in
`_w2`, and whether ptxas's control codes still schedule correctly after RCAsm relocates the body.
Method, tables and caveats: [`asm/TESTKERNEL_TEMPLATE.md`](asm/TESTKERNEL_TEMPLATE.md) §9.

**This does not move the ~15% ceiling** — lifting the hash verbatim makes it exactly as fast as it
is now. It removes risk and effort, not the bound, and the next section still applies.

### Hand-written SASS computes the right answer — RTX 5090, 2026-08-14

The load-bearing unknown, closed. Everything before this establishes that RCAsm *builds* something
the driver *accepts*; none of it says the instruction stream is correct. `asm/tk/` stage 1b is one
real field operation — `Px = MulMod256(x1, y1)` through a real out-of-line `call_func`, the result
round-tripped through the 16 KB local frame — run side by side with a compiled kernel doing
`Px = mul_mod(x1, y1)` over identical inputs (`rcasm_test/abtest/`):

| | EXACT | non-canonical | WRONG |
|---|---:|---:|---:|
| A — compiled `mul_mod` | 253 | 3 | 0 |
| B — hand-written `MulMod256` | **253** | **3** | **0** |

Identical, thread for thread, over 256 threads. `call_func` calls and returns correctly, the
register bindings resolve, the local frame is real storage, and the multiply is a multiply. The
3 non-canonical are **C8 in both implementations** — the harness classifies against an independent
oracle (schoolbook 256×256→512 then fold by K, cross-checked by a 5-case selftest that runs before
any CUDA call), so "congruent but ≥ P" is reported as its own verdict rather than as a pass or a
failure. First 4 threads carry constructed edge cases including `(P-1)²` and `2·(P+1)/2`.

**What this does not say:** stage 2 is the batch loop, and none of it is written. This is one
multiply, not a walk.

### The walk computes the right answer too — RTX 5090, 2026-08-15

The batch loop the previous section said was unwritten. `asm/tk/variants.py` builds an eight-rung
ladder out of one `main.asm`, each rung one construct away from its neighbour, and **all eight now
pass**:

| rung | what it adds | result |
|---|---|---|
| `id` / `local` / `call` / `full` | prologue, local round trip, `call_func`, both | 253 EXACT / 3 NON-CANON, identical to the compiled kernel |
| `sufp` | stage 2a — the suffix-product ladder: a real loop, dynamically indexed constant loads, `STL` at a computed address | 256 EXACT |
| `inv` | stage 2b — `call_func InvMod256`: 70 temporaries, a uniform of its own, all active threads in the warp | 256 EXACT |
| `walk` | stage 2c-i — the upward loop that reads every `subp[]` slot and advances the inverse | 256 EXACT |
| `pts` | stage 2c-ii — `SqrMod256`, `SubMod256_3`, `NegMod256`, both branches and the minus-only tail | **256 EXACT** |

`id` and `local` compute something different from the compiled kernel by construction, so their
mismatch is the expected reading; the other six are held to their answers against an independent
oracle.

**Stage 2d ran, and it is the first time the oracle has convicted both sides at once.** Both rungs
reported `A and B agree on every output limb` with `s1 ok  rem ok`, and both `WRONG 256` on `x1`
and `y1`. The outer batch loop, its guard and the two 256-bit bookkeeping chains are therefore
correct, and the hand-written jump reproduces the compiled one exactly — reproducing a defect
present in both.

**The defect: `GpuCore.cu:378-380` was transcribed onto neither side.** The walk's tail forms its
`dx_inv_i` and then, in the shipped kernel, updates the chain once more —
`inverse *= (c_Gx[half-1] - x1)` — which is what makes `inverse` equal `1/(Jx - x1)` at the jump
rather than `1/((Jx - x1)·(Gx[half-1] - x1))`. `lam` was off by that factor: not congruent, hence
`WRONG` and not `NON-CANON`, and it moves `x3` as well as `y3`, which is what ruled out a sign
error or a swapped subtract before anything was read. Fixed at the head of the `JUMP` region on the
hand-written side and under `#if STAGE_JUMP` on the reference, so the eight rungs already verified
on hardware keep their exact cubins — checked byte-identical after the rebuild. The reference grew
by exactly 240 instructions (one `sub_mod` + one `mul_mod`) and the SASS by exactly 16, reusing two
existing call bindings so no function body was duplicated. **The re-run passes: `jump` and `loop`
are both 256 EXACT / 0 NON-CANON / 0 WRONG on both sides, with `y1 ok  s1 ok  rem ok` and four
batches.**

**That completes the points-only kernel.** Every rung of the ladder is now green on an RTX 5090 —
prologue, both early exits, the suffix-product ladder, `InvMod256`, the ± walk over 1,023 points,
the minus-only tail, the point jump, the two 256-bit bookkeeping chains and the outer batch loop —
hand-written SASS matching the compiled kernel limb for limb, and both matching an oracle that
shares no structure with either. `loop` is the rung that closes it: four batches means batches 2-4
start from a point the kernel itself produced, so the jump's output is proven good enough to be its
own next input.

**What it is not evidence for.** 256 threads, one block, one launch, and a configuration where every
thread takes the same batch count — so `InvMod256`'s all-active-threads requirement holds by
construction and the ragged warp (H4's shape, and the precondition written at the head of
`main.asm`) remains untested. C8 is untouched: nothing here consumes a parity, and it has to be
fixed before the hash layer returns. And no timing claim can be made from this kernel as it stands
— that needed the `Acc` accumulator out first, which is the next entry.

**The bisect accumulator is gated off by default.** `Acc` is the product of every candidate
x-coordinate, the instrument that lets one 256-bit output stand for 1,023 points, and only the
`pts` rung reads it; the default kernel, `jump` and `loop` stored nothing from it and paid for it
anyway — two of the walk's eight `MulMod256` per iteration, 1,023 calls per batch per thread. It
now sits in `ACCINIT`/`PACC`/`PACCM`/`PACCT` regions switched on for `pts` alone, exactly as
`WACC`/`WACCT` are switched on for `walk`. The default went 1,984 → **1,832** instructions, −152
against the 38 at the call sites: all three shared the binding `RFirst=Acc, RSecond=PxN`, so
`call_func`'s one-body-per-binding rule deleted the 112-instruction `MulMod256` body that only
they used. `walk` and `pts` rebuilt byte-identical to the cubins already verified on hardware,
and all four checkers pass on all eleven. **The re-run passes**: all ten rungs read exactly as they
did before the gating, `pts` still reporting `lam ok  lam^2 ok  px3 ok` — so the accumulator still
works where it is read — and `jump` and `loop` still 256 EXACT with it gone.

### What no run has touched yet: more than one block

Every hardware run in this whole ladder has been **256 threads, i.e. a single block**, so
`IMAD gID, BlockID, 0x100, ThrID` has only ever been evaluated with `BlockID == 0`. The block term
has never contributed, which means per-thread addressing above `gid 255`, the `gid >= threadsTotal`
bail against a real bound, and the whole grid dimension are untested. That is not a speed caveat,
it is a correctness gap, and a multi-block run closes it as a side effect of the first speed
measurement. `abtest` now says so when `grid == 1` rather than leaving it to be remembered.

**The speed measurement needs two configurations, not one.** The hand-written kernel runs at
`REG 255` and the compiled one at `REG 128`, which at a 256-thread block is **1 resident block per
SM against 2** — so a raw wall-clock ratio carries a 2× latency-hiding handicap that has nothing to
do with instruction count. Running at exactly one block per SM (grid = SM count) neutralises it and
measures instruction throughput; running several waves deep measures what the program would
actually get. `abtest` now prints `BLOCKS/SM` and the wave count from
`cuOccupancyMaxActiveBlocksPerMultiprocessor` beside `REG`, so the two numbers cannot be quoted
apart from the occupancy that produced them.

### Measured — RTX 5090, 170 SMs, 2026-08-16

**Correct at scale and across blocks.** 43,520 threads (170 blocks) and 174,080 threads (680
blocks), `loop` mode, four batches each: every output limb agrees between the two kernels and every
thread is EXACT against the oracle — 174,080 and 696,320 limbs compared. That closes the
single-block gap above; the block term of the gid arithmetic, per-thread addressing past `gid 255`
and the `threadsTotal` bail against a real bound are all now exercised.

**And the hand-written kernel is faster, in both configurations:**

| grid | A blocks/SM | B blocks/SM | A | B | B/A |
|---|---:|---:|---:|---:|---:|
| 170 — matched, only 170 blocks exist so A cannot use its second slot | 1 | 1 | 8.02 ms | 7.16 ms | **0.893** |
| 680 — A runs 2 waves, B needs 4 | 2 | 1 | 28.95 ms | 27.19 ms | **0.939** |

So `REG 255` costs about half the lead, which is hazard 3 with a number on it at last: 11% at
matched occupancy, 6% once the compiled kernel is allowed the second resident block it fits in and
this one does not.

**The 11% is the finding, and it is not the good news it looks like.** Dynamically the
hand-written walk does about half the field-math instructions of the compiled one — six
`MulMod256` at 112 instructions against six inlined `mul_mod` at ~222, which is the 2× ratio this
entire route is premised on. Halving the instruction count bought **11% of wall clock**. This
kernel is therefore *not instruction-issue bound*, and the obvious suspect is the one thing both
sides carry identically: the 16 KB local frame, and 32 KB of `subp[]` traffic per thread per batch
(512 slots written, 512 read, 32 B each).

That reframes the prize, and it does so in the direction this document keeps warning about.
**The ~15% ceiling recorded above assumed halving field-math instructions halves field-math time,
and this measurement refutes that assumption directly.** Points-only is *entirely* field math and
returned 11%; with the hash layer restored at ~69% of the dynamic instruction count, the same win
lands on ~31% of the program and the whole-program gain is nearer **3-4%** — the same order as P4
alone, for a rewrite of the entire arithmetic layer in hand-scheduled SASS.

Two things follow, and neither is "abandon it":

- **P2 just became the most interesting item in this document.** If `subp[]` traffic is the
  binding constraint, then `-DMAX_BATCH_SIZE=256` — a build flag, costing ~0.35% arithmetic — is
  attacking the thing that actually limits this kernel, and it helps *both* implementations.
  It should be measured before anything else, and this harness can now measure it.
- **The register budget is worth real money here.** Going from `REG 255` to ≤128 would give the
  hand-written kernel the second resident block and, on the evidence of the two rows above, most
  of the 5 points of lead that the deep grid gives away. That is a bigger and much cheaper win
  than any further instruction-count work.

What has *not* been established: that local memory is the bottleneck. It is the leading hypothesis
and it is untested — the direct experiment is a build at a smaller `MAX_BATCH_SIZE` on both sides,
and until that runs, "not instruction bound" is the measured claim and the cause is a guess.

### The calls were not it — inlining measured, RTX 5090, 2026-08-16

The 11% above had two candidate explanations and they are separable, so they were separated.
`asm/tk/inline.py` rewrites 41 of the kernel's 42 `call_func` sites as `inc_func` — same bindings,
same bodies, no branch and no return — leaving only `InvMod256` as a call, since it runs once per
1,023 points and inlining it would test nothing at the cost of the whole rest of the kernel again.
The result is 3,304 instructions against 1,832, kernel body 2,713 against 326, and a **`BRXU` count
of 2**: every indirect branch on the per-point path is gone. Hypothesis 1 is untouched by it —
identical frame, identical `subp[]` traffic, identical arithmetic.

The reference side changed too, and for the better: **A is now `GpuCore.cubin`** from
`make cubin SM=120 NO_HASH=1` — the shipped kernel with hashing compiled out — instead of
`ab_kernel.cu`'s staged transcription. The two come out within 1.3% on instruction count (5,520
against 5,448), which is a late, free check that the staged reference was faithful.

These are the clean numbers, re-measured after the throttled session below. The two A columns agree
to **0.03%** — same reference binary in both runs — which is what licenses comparing the two B
columns to each other across separate invocations:

| A — `GpuCore.cu`, NO_HASH | B | B/A |
|---|---|---:|
| 8.0572 ms | `TestKernel_loop` — 42 calls — 7.1556 ms | **0.888** |
| 8.0596 ms | `TestKernel_inline` — 2 calls — 6.8022 ms | **0.844** |

**Removing 36 indirect branches per walk iteration — about 18,400 per batch per thread, through
29 KB of scattered code — bought 4.9%**, and took the lead over the compiled kernel from 11.2% to
15.6%.

So hypothesis 2 is **not** refuted, it is sized: the calls are about a third of the total lead and
about 5% of this kernel's time. Real, worth having, and still nowhere near enough. Even with every
per-point branch gone, issuing *half* the field-math instructions buys 15.6% where an issue-bound
kernel would give something approaching 50%. **Hypothesis 1 remains the residual**, now as the
explanation for a 15.6% result rather than an 11% one.

Both runs also came back **EXACT 43,520 of 43,520** against the oracle on both sides, with A and B
agreeing on every output limb. That is the other half of what the A/B was for — inlining ought to be
semantically inert, and this is what says it is, rather than the transform merely looking correct.

**P2 is still the experiment for the residual**, and it is a build flag on both sides.

Two things the numbers say in passing:

- **`REG 255` is now the largest single lever, not instruction count.** B wins 11-16% while running
  at *half* A's occupancy — 1 resident block per SM against 2. Getting under 128 registers is worth
  more than anything remaining on the arithmetic, and it is the one item that the 2.3% result makes
  *more* attractive rather than less.
- **Do not quote absolute milliseconds across sessions.** `TestKernel_loop.cubin` is byte-identical
  to the run three commits ago and measured 7.16 ms there against 16.16 ms here, with the A side
  moving by a similar factor. Both sides moved together, so every within-run ratio in this document
  stands; the machine state that produced the shift is unidentified and no cross-session wall-clock
  comparison should be made until it is. Same-session, same-process, back-to-back is the only
  comparison this harness supports.

**And one thing about the checkers, because it looks like a regression and is not.** `stall_check.py`
reports **BAD** on the inline cubin. It separates authored code from vendored code by *position* —
the kernel body ends at the last `EXIT`, appended `FUNCTION` bodies follow it — because the vendored
routines deliberately run below the measured stall floor and are correct on hardware. Inlining moves
exactly that code to the near side of the `EXIT`, so the positional rule can no longer tell them
apart. `asm/tk/sigcmp.sh` forces every violation to print in both builds and reduces them to
`(distance, need)` signatures: the signature *set* is identical, nothing new appears, and 105 → 278
is accounted for exactly by copy multiplicity (10 per `MulMod256` body, 31 per
`SqrMod256`+`SubMod256_3` pair, reproducing both totals with nothing left over). The checker was
**not** weakened to make the build green — a checker relaxed to pass a build it correctly flagged is
worth less than no checker.

### The hash/field split, measured at last — RTX 5090, 2026-08-16

Everything above sizes the SASS route against a **~69% hashing / ~31% field math** split that was
never a time measurement — it is a *dynamic instruction count*, and it has been carried through this
document as if it were a share of the clock. `GpuCore.cubin` built twice, full and `NO_HASH=1`, and
run against each other in the same harness, replaces it with the real thing. Registers are 120 and
128, so both sides hold 2 blocks/SM and the comparison is occupancy-matched at *every* grid.

| grid | blocks/SM | A — full | B — points-only | B/A | **hashing** |
|---|---:|---:|---:|---:|---:|
| 170 — 1 wave | 2 / 2 | 18.8218 ms | 8.1294 ms | 0.432 | **56.8%** |
| 680 — 2 waves | 2 / 2 | 74.0192 ms | 29.1436 ms | 0.394 | **60.6%** |

Both EXACT on every thread and limb-identical to each other, which is the check that says `NO_HASH`
is a faithful subset of the shipped kernel rather than a differently-behaving stand-in — worth
having, since every points-only measurement in this document rests on it.

**Field math is 39-43% of wall clock, not 31%.** The instruction-share proxy understated it,
because the two hash bodies are `__noinline__` — emitted once, called from four sites — so a static
count under-represents them and a *dynamic* count over-represents their cost relative to field math
that is waiting on memory. Every estimate in this document built on the 31% figure is therefore low
by about a third, in the route's favour.

**The scaling behaviour is the more interesting half, and it corroborates hypothesis 1 for free.**
Going from 1 wave to 2 quadruples the work and doubles the resident blocks per SM:

| | 1 wave | 2 waves | vs 4× linear |
|---|---:|---:|---:|
| full | 18.8218 | 74.0192 | 3.93× — **1.7% better than linear** |
| points-only | 8.1294 | 29.1436 | 3.59× — **10.4% better than linear** |

Doubling occupancy buys the points-only kernel five times what it buys the full one. That is the
signature of latency-bound work against issue-bound work: hashing is a dense dependent chain of
`LOP3`/`SHF` that gains almost nothing from another resident block, while the field math has
somewhere to hide. **The thing it is hiding is the 16 KB frame and the `subp[]` round trip**, which
is hypothesis 1 arriving from a direction that has nothing to do with instruction counts.

Two consequences, and they point in opposite directions from where this document has been looking:

- **P3 is now the highest-value performance item in the project, by a wide margin.** 57-61% of wall
  clock is hashing, and P3 — dropping `__noinline__` on the hot `getHash160_w2_from_limbs` and
  hoisting the inverse-chain update — is the only item that touches it. It is filed at 5-15%
  unmeasured, against a share of the clock more than half again the size of what the entire SASS
  rewrite addresses.
- **`REG 255` is worse for the hand-written kernel than the raw occupancy argument suggested.** The
  part it replaces is precisely the part that gains from a second resident block, and it is the part
  that cannot have one.

### 255 -> 127 registers, and `rem` out of the kernel — 2026-08-16

The occupancy item above, done. `asm/tk/main.asm` is now inline-native (`inc_func` everywhere but
`InvMod256`) and allocates **127 registers**, so at 256 threads it gets **two resident blocks per
SM** — the same as the compiled kernel, where it previously got one. All ten ladder variants
build, `align`/`barrier`/`pc` pass on every one, and the default build is byte-identical to the
`loop` variant as it must be. **Verified on hardware 2026-08-17** — see the section below; the
final count is **128**, not the 127 written here, and the two defects the ladder found were both
in the instruments rather than in this allocation.

The allocation is three overlays over one span, mirroring the lexical scopes of
`GpuCore.cu:221-407` — a live-range partition ptxas already proved fits in 126 registers on this
same algorithm with `inv_mod` fully inlined, so a known-good answer rather than a guess.
`persistent` R0..R33; overlay A R34..R45 (prologue/epilogue only); overlay B R34..R126 (the
inversion); overlay C R36..R125 (ladder, walk, jump).

**`rem` is gone, and that is what made 127 reachable** — 8 registers held live straight through
the inversion, worth the difference between 127 and 135. The instruction saving is *not* the
reason: about 16 per batch against a batch's ~76,000, i.e. 0.02%. The second reason is
correctness: a `rem`-driven loop guard lets threads leave the batch loop at different iterations,
which is H4's straddling warp and the one thing that can silently break `InvMod256`'s
all-active-threads precondition. With `BDone < BpL` as the only guard, the trip count is a kernel
*parameter*, so the precondition stops being a comment and becomes the control flow.

**Two vendored contracts turned out to be wrong, and only the emitted cubin said so.** Both are
invisible at `regcnt=255`:

- **`InvMod256`'s `Ro` is nine registers, not eight** — a 288-bit intermediate whose `Ro8` is the
  overflow word its normalisation loop tests. The first version of the table gave `InvO` eight
  and placed `InvT` immediately after, landing `Ro8` exactly on `Rt0`. **That build assembled and
  passed align, barrier and pc.** It would have corrupted every inversion.
- **`InvMod256`'s `Rt` is 73, not the "Rt_cnt = 70" in its own header** — `tvars=Rt64` feeds
  inlined helpers needing nine, so the body reaches `Rt72`.

That near-miss produced `asm/tk/reg_live.py`, which is the missing checker in this family: nothing
else verifies that two names live at the same time were given different registers, and a collision
assembles, passes everything, loads, runs and returns wrong numbers. Widths in it are **declared,
not inferred from the distance to the next name** — inferring is exactly what hid the bug, since
the table said eight and the table was the thing being checked. Validated against three
deliberately broken tables (the collision, a `regcnt` below the allocation, a 256-bit value on an
odd base); all three reported with the right diagnosis.

**New host item, and this kernel is not production-ready without it.** `GpuPuzzle.cpp` must own
the remaining-batch count and size `batches_per_launch` so no thread is asked for more batches
than it has left, including on the final launch. Until then the hand-written kernel is correct
only under the harness's uniform seeding. It interacts with C1's batch-aligned partition and with
H4, and it has its own test surface. `GpuCore.cu` is unchanged and still writes `counts256`;
`abtest` simply stops comparing that array — except on the `pts` rung, where it carries
`SqrMod256`'s output rather than `rem` and both sides still write it. That **is** a reduction in
what the harness proves, taken deliberately: `rem` was an identity copy plus a subtract, and what
carries the walk, the jump and the back edge is `Px`/`Py` after the batch completes.

### The register work on hardware — two defects, neither of them the allocation — 2026-08-17

The ladder run the section above was waiting for. First pass: **eight of ten rungs, including
`jump` and `loop`** — the production kernel, at 128 registers and two resident blocks per SM,
agreeing with the compiled reference on every output limb and EXACT on all 256 threads. So the
allocation, the three overlays, the corrected `Ro`=9 / `Rt`=73 contracts and dropping `rem` were
confirmed on a device immediately. The two failures were elsewhere, and both were instrument
defects rather than kernel ones.

**After the two fixes below: all ten rungs pass, no variant faults.** `id` and `local` report
`scalars ok`; `sufp`, `inv`, `walk`, `pts`, `jump` and `loop` are 256 EXACT on both sides with
every output limb agreeing; `call` and `full` are 253/3/0 on both sides, the three non-canonical
being C8 and identical between them. `id`/`local` keep their `A and B DISAGREE`, which is by
construction — those rungs compute an identity copy while side A computes `a*b mod P`.

**This is the first fully green ladder, and it is what closes the register work.** `walk` and
`pts` had never launched in this configuration at all.

**1. `walk` and `pts` faulted with `ILLEGAL_INSTRUCTION` — the headroom rule again, in the one
file that carries its own register count.** `variants.py` raises `regcnt` for the accumulator
rungs and had it at `ACC_TOP + 1` = 136 with R135 used: headroom 1. Every other rung has 4 or
more and every other rung passed. This is the same defect `9455fde` fixed in `main.asm`, written
before the rule existed and surviving in a second file. `reg_live.py` reported OK throughout,
because it checked headroom against the *source table* — where the production top is R124 at a
declared 128 — and the table does not contain the number `variants.py` substitutes. It now checks
headroom **per cubin, from `-res-usage`**, which needs no knowledge of where the count came from
and is the check that would have caught this. `ACC_REGCNT` is `ACC_TOP + 4`.

**2. `id` returned wrong scalars on 255 of 256 threads — a load's ADDRESS is read as late as a
store's data, and the checker only knew about the store.** The prologue's twelve `LDG`s carried
`R-`, and overlay A is reused by everything below: the ladder's `Rinv` sits on R32..R39 and the
write-back rebuilds `AddrX`/`AddrY`/`AddrS` from scratch, which is what pays for the register
count. On `id` — 56 instructions, the shortest rung — **three** instructions separate the last
`Scal` load from the `LDC` that overwrites its address, and the loads resolved against an address
written after they issued. `local` is the identical kernel plus five instructions in that gap and
passed. Every longer rung has thousands there and passed. Fixed with a read barrier on all twelve
and one `NOP` draining it, placed outside every region marker so no variant can cut it; the drain
is nearly free, since a read barrier signals when operands were *collected*, not when data returns.

Two things about widening `barrier_check.py` to cover it are worth keeping:

- **A wait on the WRITE barrier clears the hazard too**, and omitting that made the widened check
  fail ptxas's own output on its first run. If the data came back, the address was read. Measured:
  54 `LDC`, 12 `LDG` and 8 `LDL` in the compiled corpus rewrite a source with no read barrier
  anywhere, and every one waits the write barrier first.
- **Distance is not the discriminator**, which was the obvious hypothesis and is refuted by the
  corpus: unprotected loads go down to **6 cycles / 4 instructions** and protected ones up to
  **117**. The populations overlap almost entirely. Stores remain the unambiguous case at 28 of 28.

One residual false positive is recorded rather than tuned away — `ab_compiled_inv.cubin`, an `LDL`
whose rewrite sits inside a `BSSY.RECONVERGENT` region three instructions later, i.e. the linear
walk crediting a path it never takes. Four of five compiled kernels and all ten hand-written rungs
come out clean.

**The remaining `id`/`local` "A and B DISAGREE" is by construction and not a defect**: those rungs
compute an identity copy while side A computes `a*b mod P`, and `bisect_run.sh` has always said the
only thing read on them is whether the launch completes. What was *not* by construction was the
scalar identity sub-check, which is what caught defect 2 — the one rung short enough to expose it.

### The throttle — and what it voids

`GpuCore.cubin` built `NO_HASH=1` measured **19.5350 ms** at grid 170 in the run three commits ago
and **8.1294 ms** here. Same flags, same reported `REG 128` / `LOCAL 16416`, same harness, same
grid — the same binary, 2.40× apart. A run two sessions before that put the equivalent kernel at
8.0244 ms, so *this* session and the earliest one agree and the middle one is the outlier. The
machine was in a degraded state — thermal or power throttling, or the card was shared — for the
whole of that session.

Every number taken in that session is superseded by the re-run recorded above: the lead over the
compiled kernel was **17.3% / 19.1%** throttled and is **11.2% / 15.6%** clean, and the cost of the
calls was **2.3%** throttled and is **4.9%** clean.

**And that last pair is the finding, because it kills the rule I reached for first.** "Ratios taken
within one run survive, only absolute times are affected" is the natural response to a throttled
session, it is what this document said for one commit, and it is **false**. Throttling did not scale
both kernels by one factor — it changed the *mix*. Slowing the core clock while memory keeps its own
pace makes every kernel relatively more memory-bound, which compresses exactly the differences that
come from issue and branch behaviour: the call overhead measured **less than half its true size**
under throttle. A ratio between two kernels that differ in *what they are bound by* is not protected
by having been measured back to back.

So the rule is narrower and less comfortable than the one it replaces:

- **A wall-clock number is comparable only to one taken in the same run** — still true, still the
  reason the harness must never be handed a single kernel.
- **A ratio is trustworthy only if the machine was in a known state**, and "both sides ran back to
  back" does not establish that. The cheap guard is an *absolute* anchor: the reference side should
  land where it has landed before. `GpuCore` NO_HASH at grid 170 is 8.03-8.13 ms across three clean
  sessions and was 19.52-19.54 ms in the bad one. A reference 2.4× off its own history is the signal,
  and it was sitting in the output the whole time.

Whole-program, at a 39-43% field share and a 15.6% points-only lead, the hand-written route is worth
about **6-7%** — provided the hash layer costs the same, which it cannot be assumed to, since it
would have to be hand-written too.

Two lessons, both of which this document already contains under other names. **A correct comment is
not a permanent one**: the tail carried "no chain update after it", which was true on every rung up
to `pts`, where `inverse` is dead after the tail — stage 2d added the first consumer of it and made
the comment a defect. And **A/B agreement is worth nothing when one person wrote both sides**: both
are transcriptions of the same misreading, so the A/B half reported a clean pass. The oracle is what
caught it, precisely because it inverts `Jx - x1` by Fermat and shares no structure with the ladder
— H14 with the signs reversed. The A/B comparison and the independent oracle are two checks, not
one check written twice, and this run is the evidence.

Two more rungs, because it is two constructs: `jump` adds
the point jump — the first and only consumer of the inverse chain's *final* value, which is why
`walk` passing did not already cover it — and `loop` adds `s1 += B`, `rem -= B` and the back edge,
running four batches so the third and fourth start from a point the kernel itself produced.
`loop` is main.asm verbatim, so its cubin must come out byte-identical to `TestKernel.cubin` and
the rebuild fails if it does not. Everything offline passes: alignment, stalls, barriers and
branch/return targets on all eleven cubins, and the two the checkers caught while it was being
written are recorded at the point of the fix (a fold reading its operand three cycles after it was
written, and `Scal` read in the loop body before the barrier its load armed was ever waited).

The jump's oracle is worth noting for how little it computes: after the walk's last chain update
`inverse` is exactly `1/(Jx - x1)` — every factor the ladder multiplied in has been multiplied back
out — so the expectation is one affine point addition, one inversion per batch, and no suffix
products anywhere. The oracle still does not run the algorithm it is judging.

The `pts` rung took three hardware runs and cost a seventh hardware rule; the rule and the
correction to it are recorded at the head of `asm/tk/main.asm` and in `asm/mod_sub.asm`. In short:
`SubMod256_3` came back wrong by exactly `2^224 + 0x7A1` on all 256 threads, widening its stalls
fixed it, and the obvious generalisation from that — "a carry-out predicate needs more than two
cycles" — is **false**, refuted by 126 two-cycle carry pairs in `MulMod256`/`SqrMod256`/`InvMod256`
that are all correct on hardware. The surviving candidate is much narrower (that pair was the
kernel's only two-cycle carry spanning a `MOV`), and it is recorded as a candidate.

Two things worth carrying forward from how it was found. The diagnostic was **lying** for a full
run — a stale `want` printed beside a live `got` — and the harness reported "matches no simple
hypothesis" about a hypothesis nobody had made; that is the fourth silent-clean-report of this
project's class. And the host simulator built to settle it (`asm/tk/vsim.py`, which runs the
vendored `FUNCTION` bodies directly out of `asm/mod_*.asm`) first had to be **calibrated against
routines whose behaviour was already known** — under a plausible-but-wrong reading of `IADD3.X`'s
two carry-out predicates it accused `SubMod256_3` of an arithmetic bug it does not have. A model
chosen against the code under suspicion proves whatever it was built to prove.

### The alignment rule that nothing in the toolchain enforces — 2026-08-14

Getting to that result cost a GPU round trip, and the reason is worth its own entry because it will
recur throughout stage 2.

**A `.128` access needs its data register operand to be a multiple of 4; a `.64` access needs it
even.** Nothing checks this. The RCAsm dialect encodes the register number exactly as written,
cuAssembler does not validate it, and the ELF writer does not either — so a violation produces a
cubin that loads, resolves every constant table, reports `REG:255 STACK:16384`, disassembles
cleanly under `cuobjdump`, and then dies at launch with `CUDA_ERROR_ILLEGAL_INSTRUCTION (715)`.

Stage 1b bound `Prod` to R50, so `STL.128 [R1], R50` was emitted and the launch died. Reading the
disassembly did not find it: it decodes correctly and the call arithmetic checks out by hand. What
found it was a **four-variant bisect ladder** (`asm/tk/variants.py`, `rcasm_test/abtest/bisect_run.sh`)
cutting the two constructs stage 1b adds over stage 1:

| variant | STL/LDL | BRXU | result |
|---|---|---|---|
| `id` | — | — | launched |
| `local` | 2/2 | — | **faulted** |
| `call` | — | 2 | launched, and matched A exactly |
| `full` | 2/2 | 2 | **faulted** |

Exactly the variants containing a `.128` op faulted. Fix: `Prod` R50 → R52, `Tmp` R58 → R60,
leaving R50/R51 unused so `Prod` clears the 2-register `Thr`.

Neither reference implementation trips this, which is why it never showed up in the sources this
work was modelled on: **every `.128` base in Kernel02 is 4-aligned** (`jPntX=R28`, `TmpTmp=R84`,
`rx=R84`, `jmpSixA=R88`, `jmpSixB=R96`), and so is ptxas's own `subp[]` traffic in the shipped
kernel (`STL.128 [R9], R4`, `LDL.128 R32, [R1]` — R4/R8/R12/R32 throughout). RetiredCoder aligns
every 256-bit value to 4 as a matter of course.

`asm/tk/align_check.sh` is the guard — it strips bracketed address operands (the `[R1]` in
`STL.128 [R1], R52` carries no requirement on the register *number*), reports every violating
register and exits non-zero. Verified to **discriminate**, not merely to pass: it flags the pre-fix
cubins with `R50, R54`, clears the rebuilt ones, and clears the shipped ptxas kernel. Run it after
every build; it costs nothing and it catches a whole class of launch faults without a GPU.

### What it would actually take — read before committing to this

The question has flipped. It was "is this possible?"; it is now "is it worth it?", and the honest
answer is that the ceiling is lower than the 31.2% `mul_mod` figure suggests.

**Size the prize dynamically, not statically.** Per scanned key the split is ~2,707 hashing +
~1,207 field-math instructions — hashing is **69%** and is essentially at its floor. Hand-written
SASS addresses the other 31%. RCAsm's `MulMod256` is 112 instructions where ptxas spends ~222, so
call it a 2× improvement on the addressable part:

| | now | field math halved |
|---|---:|---:|
| hashing | 2,707 | 2,707 |
| field math | 1,207 | ~603 |
| **total** | **3,914** | **~3,310** |

That is **~15%**, and it assumes every field routine is rewritten and every one hits the 2× ratio.
It is a real number and worth having, but it is the same order as P3 (5-15%, unmeasured) and P4
(2-5%) combined — and those are days of work against a rewrite of 4,000+ instructions of hand-
scheduled SASS. **Do P1/P2/P3/P4 and measure before starting this.** P1 in particular is worth more
than 15% in wall-clock terms it does not even show up in, because it governs Ctrl-C latency,
found-key latency and TDR risk.

**Four things that are known to need solving:**

1. **The template.** A `.cu` declaring `TestKernel` with a matching signature, to inject into.
   Already scouted: `.nv.constant0.TestKernel` is 952 bytes (0x3b8) for *both* the 8-argument form
   and a single by-value struct, params at `0x380`, 56 bytes — so either shape works and the
   8-argument form is already what `CallCubin` passes.
2. **The structure mismatch.** `Math.cuh` is `__forceinline__` throughout, so the shipped kernel
   has one *region per call site* and no labels — 14 separate `mul_mod` regions. RCAsm's Kernel02
   instead `CALL`s real `FUNCTION`s. That is the more sensible structure and it is what makes 112
   instructions reusable 14 times, but it means the rewrite is a restructure, not a transcription.
3. **The register budget.** Kernel01 runs at 255 registers, which caps the block at 256 threads.
   `TestKernel` needs occupancy and already carries a 16 KB local frame. Run
   `make ptxinfo SM=120` first — it is Hardening item 10 and it gates this as much as it gates
   P2/P3/P4.
4. **Correctness.** No reference test exists for a hand-written kernel *except* end-to-end, and
   that is precisely what is now available and known-good: `proof.py` at 592/592 through the native
   cubin path. A hand-written `TestKernel` dropped into the same harness either reproduces 592/592
   or it does not. **That is the single most valuable thing this route inherited** — it did not
   exist a day ago, and without it a subtly wrong carry chain would surface as silently missed
   keys, which is the failure mode this entire document exists to eliminate.
   **Partially answered, and not in RCAsm's favour:** `MulMod256` is arithmetically correct but
   non-canonical — see the measured section above. It computes `a·b mod P` and returns it in
   `[0, 2^256)` rather than `[0, P)`, exactly like our own `mul_mod`. So the 2× instruction win
   comes with C8 attached, and any adoption has to add the final conditional subtract back —
   which costs some of the 112-vs-222 advantage the whole case rests on. **Nobody has measured
   how much.** Do that before believing the ~15%.

**The cheapest real experiment**, if the appetite is there: implement `MulMod256` alone as an RCAsm
`FUNCTION`, call it from a template kernel, and check its output against the host `MulModP` over
random operands. It settles whether hand-written SASS is maintainable *here* — by the people who
would maintain it — at a cost of one function rather than one kernel.

### If the route is abandoned

The `asm/GpuCore_sm120.map` work stands on its own and is worth keeping either way: it is the only
thing that says where `mul_mod`'s 31.2% actually sits, and the `Kernel02` reference implementations
in `asm/` are readable regardless of whether RCAsm can assemble anything. The realistic near-term
use of the table above is as a **target for P3/P4**, not as a plan to hand-assemble: ptxas emits
~222 instructions where `MulMod256` uses 112, and that ratio is the size of the prize whichever way
it is claimed.

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
10. **`make ptxinfo SM=120`** **[DONE — 2026-08-14]** No GPU needed; nvcc alone. Recorded:

    | build | registers | stack frame | spill st / ld |
    |---|---:|---:|---:|
    | plain (`make`) | **122** | 16,384 B | **0 / 0** |
    | `-rdc` (what `NATIVE_CUBIN` loads) | **126** | 16,384 B | **0 / 0** |
    | `-rdc`, hash bodies force-inlined | 128 | 16,544 B | **208 / 272** |

    `getHash160_33` and `getHash160_w2` each report 0 stack frame and 0 spills, consistent with
    §9.1 of `asm/TESTKERNEL_TEMPLATE.md` finding zero memory instructions in either.

    **What this gates.** `__launch_bounds__(256, 2)` asks for 512 threads/SM, which on sm_120's
    64K-register file allows 128 registers/thread. The shipped kernel sits at 122 — inside the
    budget, with 6 to spare, and **no spilling at all today**. So P2/P3/P4 are not fighting spills;
    they are fighting the 512-thread occupancy cap that 122 registers already implies.

    **And it is a warning about P3.** Forcing both hash bodies inline pushes registers to the 128
    ceiling and introduces 208/272 bytes of spill traffic that does not exist now. That is the
    aggressive upper bound rather than P3 as specified (which drops `__noinline__` from
    `getHash160_w2_from_limbs` only, leaving the decision to the compiler) — but it says plainly
    that the inlining direction has a cliff, and P3 must be measured, not assumed.

    **One unrelated result from the same run, and it matters for the SASS route:** with the hash
    bodies inlined the `-rdc` cubin has **one** `.text` section instead of three. That is the
    condition `str_index@` keys on, so a `-rdc` build in that shape should round-trip — which is
    what would allow a cuAssembler-rebuilt `TestKernel` to be loaded through `NATIVE_CUBIN` and
    checked against `proof.py`. Untested; see *Still to do*.
11. **P2** — build `-DMAX_BATCH_SIZE=256`. Correct `BYTES_PER_THREAD` to the real 128 B/thread
    **only together with a real `threadsTotal` cap** — the current 128× over-reservation is the
    only thing bounding thread count today.
12. **P3 then P4**, measuring after each. Size the prize from `asm/GpuCore_sm120.map` first: ptxas
    spends ~222 instructions per `mul_mod` where RCAsm's hand-written `MulMod256` uses 112, and
    `mul_mod` is 31.2% of the kernel. Past P3/P4 the remaining headroom is hand-written SASS — see
    the parked RCAsm section above, now blocked on 17 missing InsKeys rather than on a toolkit
    version.
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

**CUDA 12.8** is worth having for the parked RCAsm/SASS work only, and is no longer the gate it was
described as: on 13.0 the cubin↔cuasm round-trip mangles three `.note.*` sections *and* — the
larger problem — 12.7% of the real kernel's instructions have no encoder at all. See that section.
Nothing else in this project needs 12.8, and cubins built by it run under any recent CUDA.

**nvcc `-lineinfo` does not change codegen here** — verified, `.text.TestKernel` byte-identical at
159,744 B with and without. That is what makes `nvdisasm -gi` usable to attribute SASS back to
`Math.cuh` (`asm/GpuCore_sm120.map`). `-rdc=true` **does** change codegen; see the native-cubin
notes.

**Python in WSL has no pip** (`ensurepip` is stripped and `sudo` needs a password). The round-trip
harness got its `pyelftools`/`sympy` by installing them with Windows' Python
(`C:\python39\python.exe`, 3.14.3) via `pip install --target <dir>` and putting that directory on
`PYTHONPATH` — both are pure Python, so this works across the platform and version gap.

### What exists now

Host-side harnesses were built against the real project headers with g++. They are stub-based by
necessity — until the WSL nvcc route above was found there was no CUDA toolchain at all, and there
is no GPU *on this dev machine*, so **nothing below has ever executed on a device**. They are still
the only coverage that runs here, and they remain the only coverage for the ragged configurations
`proof.py` does not generate — but they are no longer the only evidence in the project: see
*Verified on real hardware* at the top.

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

1. ~~**Build on the real target.**~~ **Done** — the image builds, loads and runs on the card in
   hand. H12 is untouched by that: it is a claim about every *other* card, and one line
   (`-gencode arch=compute_120,code=compute_120`) still stands between this and running anywhere
   else. Note CUDA 13 has dropped some older SASS targets, so the Makefile comment's list of
   supported `SM=` values is not to be trusted without checking.
2. **Device-side canonicalization test:** the hash file is already host-compilable
   (`-D__device__= -D__forceinline__=inline -D__noinline__=` plus `__byte_perm`/`__funnelshift_r`
   stubs, per the comment at `GpuHash.cu:282`). Give `Math.cuh` the same treatment and assert
   `mul_mod`/`sqr_mod`/`inv_mod` outputs are `< p` — the direct test for C8/C9.
3. ~~**Coverage regression on real hardware.**~~ **Done — 592/592**, see *Verified on real
   hardware*. This also subsumes what was item 5 (known-answer end-to-end with the key at the very
   last scalar): the 128 end-A and 128 end-B tests are that case, run 256 times at both parities.
   What it leaves open is everything `proof.py` structurally cannot generate — a **non-power-of-two
   range**, which is both the H4 trigger and every losing row of the C1 measured-effect table.
   A single run of `--range 1:0x204000400 --grid 1024,2 --slices 64` covers both at once and is the
   highest-value outstanding verification step now.
4. **Targeted repros:**
   - C2: `--range 1000:1FFF` must scan and terminate.
   - C4: `--range 100:FF` and `--range 0:FFFF…FF` must be rejected with a clear message.
   - C6/H2: `--target-hash160 1z…` must be rejected, not truncated and not an abort.
   - C7: `--range 200:…` with `--grid 1024,B` must not produce a degenerate inversion.
   - H5: exit code 4 — Ctrl-C a real scan mid-range and confirm it reports interruption rather
     than exhaustion. The only H5 path not yet exercised. Do this **after** P1, or the signal will
     take up to 27 s to be observed and the test will look like a hang.
   - H4 — **now the top verification item, promoted into item 3**:
     `--range 1:0x204000400 --grid 1024,2 --slices 64` (see the reachability note above) must
     complete rather than hang. The 592/592 run says nothing here — a power-of-two range gives
     `r1 = 0`, so the straddling warp the fix exists for is never created. Note `compute-sanitizer --tool synccheck` will **not** flag the
     original defect — its "Invalid Arguments" check does not cover a named thread that never
     arrives — so a clean synccheck run is not evidence either way.
   - H3: the **second Ctrl+C** must terminate the process. Not empirically tested — MSYS2 cannot
     deliver SIGINT to a native ucrt64 binary, so the stub harness cannot exercise it. The reasoning
     is platform-split and worth confirming on both: on Windows the UCRT resets SIGINT to `SIG_DFL`
     before invoking the handler, so the second press terminates by default and the `_Exit` is
     belt-and-braces; on POSIX, glibc's `signal()` keeps the handler installed, so the second press
     is what actually reaches `std::_Exit`. Test with a wedged GPU, not a healthy one.
5. ~~**Known-answer end-to-end.**~~ **Done** — folded into item 3; the end-A/end-B blocks place the
   key at the last scalars of the range and the harness compares the recovered key, which is the
   pair of properties this item was asking for.
6. **Re-run `proof.py` against the plain build** — `make clean && make SM=120 -j4`. The 592/592 was
   `NATIVE_CUBIN=1`, which compiles out the `<<<>>>` launch, all five `CudaCopy*` wrappers and the
   H15 drain-and-check, and substitutes `-rdc` device code for `GpuCore.o`'s. So the configuration
   `make` produces by default is the *unverified* one. Expected to pass — but "expected to pass" is
   what this whole document exists to distrust, and it is one rebuild.
