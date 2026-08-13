# Can cuAssembler encode our kernel? — and can the hash layer be lifted rather than rewritten?

Three probes behind one question: **if `getHash160_33` and `getHash160_w2` were pulled out of the
shipped cubin and used as RCAsm `FUNCTION`s, would the assembler reproduce them?**

The answer is yes, byte-for-byte. See [`../../asm/TESTKERNEL_TEMPLATE.md`](../../asm/TESTKERNEL_TEMPLATE.md)
§9 for the write-up; this directory is how it was measured.

```bash
RCASM=/path/to/RCAsm ./run.sh
```

`PYDEPS=<dir>` adds `pyelftools`/`sympy` to `sys.path` if they are not installed;
`WORK=<dir>` moves the scratch directory (default `/tmp/rcenc`); `CUDA=<root>` picks the toolkit.

## What each script does

| | |
|---|---|
| `env.py` | Paths, the two hash-body address ranges, and `Config.SM_VER = 120`. Import it first. |
| `gaphash.py` | Attempts every one of the kernel's 9,984 instructions and reports failures **bucketed by region** — the two hash bodies against everything else. Patches `CuInsAssemblerRepos.assemble` to record instead of raise, so one run sees all of them rather than stopping at the first. |
| `learn.py` | Feeds the kernel's own SASS — instructions *with their real binary codes* — through `CuInsAssemblerRepos.update`, then saves the repository. |
| `rtfull.py` | Assembles the whole kernel and byte-compares `.text.TestKernel` against the cubin the `.cuasm` came from. This is the check that matters: "assemble() did not raise" is not "assemble() produced the right code". |

## Expected result

| region | instrs | fail before | fail after | unexplained bytes after |
|---|---:|---:|---:|---:|
| `getHash160_33` | 2,045 | 291 | **1** | **0** |
| `getHash160_w2` | 2,021 | 283 | **1** | **1** |
| rest of `TestKernel` | 5,918 | 691 | 22 | 160 |
| **total** | **9,984** | **1,265 (12.7%)** | **24 (0.24%)** | 161 |

The 24 are all one form — `HFMA2 Rd, -RZ, RZ, hi, lo`, ptxas loading a small integer constant on
the FP16 pipe, exactly equivalent to `MOV Rd, imm`. `rtfull.py` performs that substitution, so
those 24 slots are expected to differ.

`getHash160_w2`'s single unexplained difference is its closing `RET.REL.NODEC` — and that is the
one instruction an RCAsm `FUNCTION` does not have, because `call_func` ends a body with the
caller's `Ret=` string instead.

## Two prerequisites in the RCAsm tree

Neither is optional and neither is in this repository.

1. **`cuAssembler/CuAsm/config.py`** — `NVDISASM_PATH` is hardcoded to CUDA 12.8. Repoint it.
2. **`cuAssembler/CuAsm/CuInsFeeder.py:639`** — `smversion.getMajor() in {7,8}` → `>= 7`.
   Without this the feeder raises `No implemented state machine for arch CuSMVersion(120)` and the
   repository **cannot be taught anything about sm_120 at all**. This is why the gap looked like
   missing encoders for so long: the learning path was unreachable on Blackwell.

`run.sh` overwrites `InsAsmRepos/DefaultInsAsmRepos.sm_120.txt` in the tree you point `RCASM` at.
**Back that file up first** — it is not restored automatically.

## Why the corpus is our own kernel

`"Assembling failed (NewVals): Insufficient basis, try CuAsming more instructions!"` is not a
missing encoder. cuAssembler *solves* for encodings from samples of real instructions paired with
their real codes, and the shipped sm_120 repository looks converted from sm_89 rather than built
from Blackwell output — 1,211,212 B against sm_89's 1,210,806 B, with a `sm_89_orig.txt` beside it.
The samples it needs for the forms ptxas actually emits are sitting in our own cubin. Feeding
9,984 of them takes about five seconds and learns 184 new records, 405 → 426 InsKeys.

## One caveat, measured

Feeding control-transfer instructions creates conflicts the solver cannot resolve: `nvdisasm`
prints a branch/return target as an **absolute address** while the encoding holds a **PC-relative
offset**, so two `RET.REL.NODEC R6` at different addresses are indistinguishable to it. It keeps
the first encoding and reuses it, which is the origin of the single hash-body difference.

Filtering `BRA`/`RET` out of the corpus is **not** the fix — `BRA.DIV UR4` and
`BSSY.RECONVERGENT` get their operand forms and modifiers only from that corpus, so excluding them
just moves the failure. Both were tried. The proper fix belongs in CuAsmParser's `` `(label) ``
fixup path, which should overwrite the offset field after layout regardless of what the repository
encoded.

## The plain build, not the `-rdc` one

`run.sh` compiles `-cubin` without `-rdc=true` on purpose: `asm/GpuCore_sm120.asm` came from that
build, and `-rdc` changes codegen (159,744 → 161,280 B, and it moves the hash bodies into their own
`.text` sections). Step 1 prints `.text.TestKernel`'s size so a mismatch is visible immediately.
