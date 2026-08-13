# A hand-written `TestKernel` — what the template looks like, and what it would cost

Companion to the RCAsm section of [`../DEVPLAN.md`](../DEVPLAN.md). Everything below is measured on
CUDA 13.0.88 / sm_120 unless marked otherwise. Nothing here has been executed on a GPU — the
template and the round-trip are static results.

---

## Bottom line

**The template works.** It is written, it compiles, it produces byte-identical parameter metadata
to the shipped kernel, and it has been driven through the full RCAsm inject-and-assemble path
successfully. Constant tables keep `GLOBAL` binding, so `cuModuleGetGlobal` and the existing
`CopyToSymbol` path still work. That was the main open question and it is answered.

**One finding dominates the cost, and it is bad.** A `-rdc` device link that emits a separately
linkable `__device__` function creates a `.nv.prototype` section containing a `str_index@`
expression, which CuAsmParser does not implement. Any cubin with more than one `.text` section
therefore fails to reassemble — including the **shipped `GpuCore.cubin`**, which has three.

The consequence: **you cannot keep the nvcc-compiled hash functions and hand-write only the
arithmetic.** The hybrid that would have made this project tractable is closed. `getHash160_33`
and `getHash160_w2` are 4,066 instructions — 40.7% of the kernel — and DEVPLAN records the hash
pipeline as machine-checked against `hashlib` and essentially at its floor. A hand-written
`TestKernel` means rewriting that too, in SASS, by hand, with no reference implementation to copy
from and with the encoder coverage unverified for exactly the opcodes it needs.

Unless someone implements `str_index@` in CuAsmParser first. That single piece of work is what
separates "rewrite the 31% worth rewriting" from "rewrite everything including the part you were
told not to touch."

---

## 1. The template `.cu`

RCAsm is a template-injection assembler: nvcc compiles a dummy `.cu`, CuAssembler disassembles it,
RCAsm splices its own instruction stream between `.text.TestKernel:` and the `.L_x_N` end label,
patches the register count, and reassembles. The template supplies **the ELF shell, the symbol, the
parameter layout and the constant-bank layout**. Its body is discarded.

```cpp
#include <cstdint>

#define THREADS_PER_BLOCK   256
#define BLOCKS_PER_SM       2
#define MAX_BATCH_SIZE      1024

struct TFindResult {                    // verbatim from Defs.h
    uint64_t scalar[4];
    uint64_t rx[4];
    uint64_t ry[4];
    uint32_t claimed;
    uint32_t found;
};

// verbatim from GpuCore.cu -- these define .nv.constant3 and are what
// cuModuleGetGlobal resolves for the host's CopyToSymbol path.
__device__ __constant__ uint32_t c_target_words[5];
__device__ __constant__ uint64_t c_Gx[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ uint64_t c_Gy[(MAX_BATCH_SIZE/2) * 4];
__device__ __constant__ uint64_t c_Jx[4];
__device__ __constant__ uint64_t c_Jy[4];

extern "C" __launch_bounds__(THREADS_PER_BLOCK, BLOCKS_PER_SM)
__global__ void TestKernel(
    uint64_t* __restrict__ Px,
    uint64_t* __restrict__ Py,
    uint64_t* __restrict__ start_scalars,
    uint64_t* __restrict__ counts256,
    TFindResult* __restrict__ find_result,
    uint64_t threadsTotal,
    uint32_t batch_size,
    uint32_t batches_per_launch)
{
    // Trivial body: touch every parameter and every constant table once, with plain
    // 64-bit adds and stores. No loops, no divergence. Two reasons it must stay this
    // dumb: RCAsm throws it away regardless, and ptxas idioms in a real body (the
    // HFMA2 MOV trick, WARPSYNC.COLLECTIVE) are exactly what the round-trip chokes on.
    const uint64_t t = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (t >= threadsTotal) return;
    const uint64_t v = t + batch_size + batches_per_launch
                     + c_Gx[0] + c_Gy[0] + c_Jx[0] + c_Jy[0] + c_target_words[2];
    Px[t] = v;
    Py[t] = v;
    start_scalars[t] = v;
    counts256[t] = v;
    find_result->scalar[0] = v;
}
```

Three requirements on it, all load-bearing:

- **`extern "C"`** — or the symbol is mangled and `cuModuleGetFunction("TestKernel")` fails.
- **`-rdc=true` + two-step device link** — or the five `__constant__` tables are `STB_LOCAL` and
  `cuModuleGetGlobal` cannot find them. Measured on 13.0.88: plain `-cubin` gives
  `OBJECT LOCAL ... c_Gx`; the device link gives `OBJECT GLOBAL ... c_Gx`.
  Single-step `-rdc=true -cubin` gives ELF `Type: REL`, which `cuModuleLoad` rejects.
- **Exactly one `.text` section** — see §5. No `__noinline__` device functions, no separately
  linkable callees.

The template body's *own* assemblability does not matter. Measured directly: the template cubin
**fails** a plain round-trip (`IADD3 ... -R10`, `Unknown modifiers: {'5_cNEG'}`) yet **succeeds**
under injection, because `inject_kernel` replaces the instruction stream before the assembler sees
it. **This is proof that DEVPLAN's 12.7% encoder gap does not block the injection route** — that
gap only ever blocked re-assembling ptxas output.

---

## 2. Parameter layout

Measured from `cuobjdump -elf` `EIATTR_KPARAM_INFO`, cross-checked against
[`GpuCore_sm120.asm`](GpuCore_sm120.asm). Confirms DEVPLAN's recorded numbers.

`.nv.constant0.TestKernel` = 0x3b8 (952 B); param block at 0x380, size 0x38 (56 B).

| ord | name | size | offset | sm_120 | sm_89 |
|----:|------|-----:|-------:|--------|-------|
| 0 | `Px` | 8 | 0x00 | `c[0x0][0x380]` | `c[0x0][0x160]` |
| 1 | `Py` | 8 | 0x08 | `c[0x0][0x388]` | `c[0x0][0x168]` |
| 2 | `start_scalars` | 8 | 0x10 | `c[0x0][0x390]` | `c[0x0][0x170]` |
| 3 | `counts256` | 8 | 0x18 | `c[0x0][0x398]` | `c[0x0][0x178]` |
| 4 | `find_result` | 8 | 0x20 | `c[0x0][0x3a0]` | `c[0x0][0x180]` |
| 5 | `threadsTotal` | 8 | 0x28 | `c[0x0][0x3a8]` | `c[0x0][0x188]` |
| 6 | `batch_size` | 4 | 0x30 | `c[0x0][0x3b0]` | `c[0x0][0x190]` |
| 7 | `batches_per_launch` | 4 | 0x34 | `c[0x0][0x3b4]` | `c[0x0][0x194]` |

**Rule:** `addr = PARAM_BASE(arch) + align_up(running_offset, alignof(param))`, with
`PARAM_BASE` = 0x380 on sm_120 and 0x160 on sm_89. Verified to reproduce Kernel01's own
`c[0x0][{0x160 + 0x220}]` numbers on both arches.

Pairs are 16-byte aligned, so the 128-bit loads are legal and RCAsm-encodable:

```
LDCU.128 UR8,  c[0x0][0x380]   // Px UR8:9, Py UR10:11
LDCU.128 UR12, c[0x0][0x390]   // start_scalars UR12:13, counts256 UR14:15
LDCU.128 UR16, c[0x0][0x3a0]   // find_result UR16:17, threadsTotal UR18:19
LDCU.64  UR20, c[0x0][0x3b0]   // batch_size UR20, batches_per_launch UR21
```

Driver-provided slots below the params, sm_120 | sm_89:

| what | sm_120 | sm_89 |
|---|---|---|
| global memory descriptor (`desc[URn]` on LDG/STG) | `0x358` | `0x118` |
| `ntid.x/.y/.z` (blockDim) | `0x360/364/368` | `0x0/4/8` |
| `nctaid.x/.y/.z` (gridDim) | `0x370/374/378` | `0xc/10/14` |
| initial stack pointer for R1 | `0x37c` | `0x28` |

### Constant tables — bank 3

At their ELF symbol offsets, no relocation, no base. Byte-identical in the shipped kernel and in
the template:

| symbol | offset | size |
|---|---|---:|
| `c_target_words` | `0x0` | 20 |
| `c_Gx` | `0x18` | 16,384 |
| `c_Gy` | `0x4018` | 16,384 |
| `c_Jx` | `0x8018` | 32 |
| `c_Jy` | `0x8038` | 32 |
| *total* | | `0x8058` |

Addressed as `c[0x3][...]`. Note `LDCU.128 UR, c[0x3][URZ]` is one of the known-missing encoders
(DEVPLAN Group 1), so the uniform 128-bit form of a bank-3 load is unavailable; 16 of 17 probed
`c[0x0]`/`c[0x3]` forms encode.

---

## 3. The `.asm` structural model

RCAsm is a **textual macro-assembler with no ABI, no register allocator and no linker**. Worth
internalising before estimating anything.

- A "project" is every `.asm` in `PROJECT_PATH` concatenated into one flat unit list —
  `main.asm` forced first, the rest alphabetical.
- **A KERNEL's header line *is* the register allocation table.** `name=R<base>` declares a block;
  `name<N>` resolves to `R<base+N>`. You allocate by hand, all of it.
- **FUNCTIONs are macros** whose formal parameters are register-array *bases*. A call site rebinds
  those bases and the compiler rewrites every identifier by string substitution. Hence the
  `MulMod256(Ri=8, Ro=Output, Rt=TmpArr, Pt=0, Ret=…)` convention seen in comments.
- `inc_func` / `include` **paste the body inline**. Only `call_func` emits a real branch: a forward
  ``BRXU URZ, `(.begin_<F>_<n>)`` into a copy of the function appended after the kernel's `EXIT`,
  returning through a caller-nominated uniform register loaded by a
  ``UMOV uX0, `(.relN_end_<F>) //RCASM:CallPointA`` line that RCAsm patches.
- **There is no stack and no save/restore.** Nesting works only because the programmer hand-assigns
  a different UR pair per nesting level — Kernel02 uses `uRetA=UR24`, `uRetB=UR26`, `uCallInv=UR32`.
- Templating: `#IF {SM_VER} == 89` / `#ENDIF`, and brace substitution like `{STRIDE * INT_SIZE}`.
- Control codes `[B------:R-:W0:-:S01]` are written by hand per instruction — wait-barrier mask,
  read/write barrier, yield, stall count. This is the part that buys the performance and the part
  with no tooling.

---

## 4. What exists, and what does not

Kernel02's sources in this directory already contain the entire 256-bit modular arithmetic layer,
hand-written, roughly 2× denser than ptxas output:

| function | RCAsm | nvcc equivalent | in `TestKernel`? |
|---|---:|---:|---|
| `MulMod256` | 112 | ~222 | yes — 14 sites, 31.2% |
| `SqrAddMod256` | 126 | 211 (`sqr_mod`) | yes — 4 sites |
| `InvMod256` | 586 expanded | 890 | yes — 1 site |
| `SubMod256` | 16 | ~18 | yes — 14 sites |
| `SubMod256_3` | 18 | ~31 | yes — 4 sites |
| `AddMod256` | 16 | — | **never called** |
| `NegMod256` | 8 | 12 | yes — 2 sites |

**Missing entirely:**

- **The hash layer — 4,066 instructions, 40.7% of the kernel.** SHA-256 and RIPEMD-160. No RCAsm
  equivalent exists anywhere. DEVPLAN records this code as machine-checked against `hashlib`, with
  a provably minimal 153-of-160-round trim, and at its performance floor. Rewriting it is maximum
  risk for zero expected gain.
- **`sub_mod_is_odd`** — no equivalent. Small (27 instructions) but it is the parity/prefix
  derivation, i.e. exactly where C8 bites.
- **The kernel body itself** — the batch loop, the Montgomery batch-inversion ladder, the ± walk,
  the point jump, the publication path. Roughly 1,000 instructions, all bespoke.

---

## 5. The blocker: `str_index@` and the one-`.text` rule

Measured: the full RCAsm path succeeds on a **single**-`.text` device-linked template, producing
`ET_EXEC`, flags `0x6007802` unchanged, all five constant tables `GLOBAL` at correct offsets,
`.nv.constant3` / `.nv.constant0.TestKernel` / `.nv.info.TestKernel` / `.note.nv.tkinfo` /
`.note.nv.cuinfo` **byte-identical** to the template, only `.text.TestKernel` changed, both
`cuobjdump` and `nvdisasm` rc=0, and `REG:32` matching the `.asm`'s declared `regcnt=32`.

It fails as soon as there is a second `.text` section. The device linker emits a `.nv.prototype`
section whose second word nvdisasm prints as `.word str_index@("#lll")`. CuAsmParser implements
`index@` only, so `__evalFixups` raises `Unknown expression str_index@` before anything can be
saved. The **shipped `GpuCore.cubin` has three `.text` sections and two `str_index@`** — it cannot
round-trip today.

This is what closes the hybrid. Under `-rdc`, `getHash160_33` and `getHash160_w2` become separately
linkable functions in their own sections — precisely the shape that triggers it. And inlining them
instead does not help: injection discards the whole template body regardless, so inlined hash code
would be thrown away and would still have to be hand-written.

**Implementing `str_index@` is therefore the highest-leverage single piece of work on this route.**
It is not a one-line fix like the other four — it is an expression form in the fixup evaluator — but
it would reopen the hybrid and remove ~4,000 instructions of hand-written hash code from the
estimate.

---

## 6. Toolchain fixes required

Three were already known; the fourth is new and specific to device-linked templates.

| # | where | fix |
|---|---|---|
| 1 | `cuAssembler/CuAsm/config.py` | `NVDISASM_PATH` hardcoded to CUDA 12.8 — repoint |
| 2 | generated `.cuasm` | comment out the single bare `.tkinfo` line |
| 3 | `compiler.py replace_sections_data` | skip absent sections (`.note.nv.cuver` is gone in CUDA 13); add `.note.nv.cuinfo` to the copy list |
| 4 | `CuAsmParser.py:104` | add `'@"STT_CUDA_OBJECT"': 13` to `CuAsmSymbol.SymbolTypes` |
| 5 | `CuAsmParser.py:1589` | *(not done)* implement `str_index@` — the hybrid unlock, §5 |

Fix 4 is needed because the device linker rewrites `.nv.reservedSmem.offset0`'s type from
`STT_OBJECT(1)` to the CUDA-specific `STT_CUDA_OBJECT(13)`, and the validation table knows only
four types. It is safe: `SymbolTypes` is validation-only — `__updateSymtab` writes `st_value` and
`st_size` and takes `st_info` verbatim from the source cubin.

---

## 7. Honest cost

Against DEVPLAN's **~15% ceiling** (hashing is 69% of the dynamic instruction count and untouchable,
so halving the field math at RCAsm's 2× ratio is the whole prize):

**Already written:** ~880 instructions of modular arithmetic, in Kernel02, proven only through
RCAsm's front end — never injected, never assembled, never run.

**To write:** ~1,000 instructions of kernel body, plus — unless `str_index@` lands — ~4,000
instructions of SHA-256 and RIPEMD-160, by hand, with hand-assigned registers and hand-written
control codes, replacing code that is currently machine-checked and at its floor.

**Then subtract:** `MulMod256` is non-canonical (measured — it returns `P+1` for `(P-1)²`), so C8
comes across with it and the final conditional subtract has to be added back, costing an unmeasured
fraction of the 112-vs-222 advantage the entire case rests on.

**And note what is unverified:** cuAssembler's encoder coverage has only ever been exercised over
the opcodes Kernel01 and Kernel02 use. The hash layer needs `PRMT`, `SHF` funnel shifts and `LOP3`
variants. Whether those encode is unknown, and finding out costs a day.

The recommendation in DEVPLAN stands and is now better supported: **do P1–P4 and measure first.**
P3 (5–15%) and P4 (2–5%) are days of work against the same ceiling. P1 is worth more than its
percentage in wall-clock terms it does not even appear in, because it governs Ctrl-C latency,
found-key latency and TDR risk.

If the appetite is there anyway, the ordering that de-risks fastest is: implement `str_index@` →
confirm the hybrid injects → port `MulMod256` alone with the final subtract restored → measure it
against `proof.py`'s known-good 592/592. Each step is falsifiable and the first one that fails
ends the route cheaply.

---

## 8. Open questions

- `BRXU` semantics (`target = next_PC + UR + imm`) are **inferred** from `CuInsParser.py:611-621`
  and an author comment, never executed.
- Kernel02's sources compile through RCAsm's front end but have **never been injected or
  assembled** — it ships no template.
- `InvMod256` carries "requires all active threads in warp!" (`mod_inv.asm:189`). `TestKernel`'s
  divergence structure has not been checked against that.
- Register bank conflicts are tracked by hand upstream (`mod_sub.asm:24`) with no tooling.
- Control codes in every probe so far were copied from Kernel01 and are almost certainly wrong for
  a real kernel — they assemble, which says nothing about whether they schedule correctly.
- `__launch_bounds__(256,2)` implies ≤128 registers/thread arithmetically; not measured. RCAsm
  accepted `regcnt=40` without complaint and would presumably accept an over-budget value.
