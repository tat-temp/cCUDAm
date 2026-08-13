# `asm/tk` — a hand-written SASS `TestKernel`

Points-only: the EC walk with the hash layer removed, which is what `make NO_HASH=1`
builds on the C++ side and what this has to reproduce exactly.

```bash
RCASM=/path/to/RCAsm ./build.sh
```

`PYDEPS=<dir>` adds `pyelftools`/`sympy` if they are not installed; `CUDA=<root>`,
`WORK=<scratch>`, `NVDISASM=<path>` are also honoured. Output: `TestKernel.cubin`.

## Status

| stage | what | state |
|---|---|---|
| 1 | prologue, parameter loads, gid, bounds bail, 64-bit global I/O, 16 KB frame | **builds** — 64 instructions |
| 1b | `call_func MulMod256` + a local-frame round trip | **builds** — 184 instructions |
| 2 | suffix products, `InvMod256`, the ± walk, the point jump | not written |

Stage 1 is deliberately an *identity* kernel: it loads `x1`/`y1`/`s1`/`rem` and writes
them straight back, so it proves every part of the carrier the arithmetic sits on top of
and nothing else.

Stage 1b adds exactly one real field operation — `Px = MulMod256(x1, y1)`, through a real
out-of-line **call**, with the result round-tripped through the local frame. `y1`, `s1`
and `rem` stay identity. That makes the two remaining unknowns falsifiable on their own:

- **`call_func` works, and the offsets are right.** Verified in the emitted SASS rather
  than assumed: the call at `0x300` is `BRXU URZ 0x160` → `0x310 + 0x160 = 0x470`, which
  is where RCAsm appended the `MulMod256` body; the return address it patched into the
  caller is `UR6 = 0xfffff790`, and `0xB80 + (-0x870) = 0x310` is precisely the
  instruction after the call. `UR7 = 0xffffffff` is the sign-extension half.
  This is the mechanism the hash-layer lift depends on.
- **The local frame is real.** `STL.128 [R1]` / `LDL.128 [R1]` against the 16 KB the
  template declares.
- **Register bindings resolve.** The body opens with
  `IMAD.WIDE.U32 R50, R8, R16, RZ` = `Ro0 = RFirst0 * RSecond0` with `Ro=Prod(R50)`,
  `RFirst=PntX(R8)`, `RSecond=PntY(R16)`.

**C8 applies to the check.** `MulMod256` is arithmetically correct but non-canonical — on
hardware it returns `p+1` where `1` is correct. Compare against `EcInt::MulModP`, which
shares the convention, or against Python `(a*b) % P` with that allowance. Do not "fix" it
here; C8 has to be fixed on its own terms for whichever implementation ships.

## What the build does

1. `tmpl_TestKernel.cu` → cubin, two-step device link. `-rdc=true` is what gives the five
   `__constant__` tables `GLOBAL` binding so the host can find them with
   `cuModuleGetGlobal`; `extern "C"` alone does not. The single-step `-rdc=true -cubin`
   emits ELF type `REL`, and `cuModuleLoad` takes only `EXEC`.
2. cubin → cuasm, **in-process**. Not `bin/cuasm.py`: that is a separate process and picks
   up `config.py`'s hardcoded CUDA 12.8 `NVDISASM_PATH`.
3. Comment out the bare `.tkinfo` directive.
4. `rc_build.py` — RCAsm's editor F5 path without the editor: compile `main.asm`, inject,
   reassemble, patch the note sections back.

The project directory is **assembled at build time**, not committed: RCAsm concatenates
every `.asm` in `PROJECT_PATH`, and `asm/` also holds Kernel02's `main.asm`, `fuse.asm`
and `newKernelB.asm`, which declare their own `KERNEL`s. `build.sh` copies only the three
arithmetic units, keeping Kernel02's sources as the single copy.

## Toolchain fixes, and where they live now

Three of the four are applied **in-process by `rc_build.py`**, so this build does not
require anyone to have edited the RCAsm checkout:

| # | fix | where |
|---|---|---|
| 1 | `NVDISASM_PATH` off CUDA 12.8 | `build.sh` step 2 + `rc_build.py` |
| 2 | comment out the bare `.tkinfo` | `build.sh` step 3 |
| 3 | `.note.nv.cuver` is absent in CUDA 13; add `.note.nv.cuinfo` to the copy list | `rc_build.py` `_patch_cubin` |
| 4 | `'@"STT_CUDA_OBJECT"': 13` in the symbol-type table | `rc_build.py` |

Fix 4 is needed because the device linker rewrites `.nv.reservedSmem.offset0`'s type to a
CUDA-specific value the validation table does not know. It is safe: that table is
validation-only, and `__updateSymtab` copies `st_info` verbatim from the source cubin.

## Three things that cost time here

- **Register names must not end in a digit.** RCAsm resolves `name<N>` to `R<base+N>` by
  stripping trailing digits, so `x1` is ambiguous with `x` index 1 and is rejected.
- **In a control code's wait mask, barrier N occupies slot N.** Waiting on barrier 1 is
  `B-1----`; `B1-----` is "Illegal control code text".
- **Use the idioms ptxas actually emits for this kernel**, not plausible ones. Global
  access is `LDG.E.64 Rd, desc[UR][Raddr.64+off]` with the descriptor from `c[0x0][0x358]`
  and a full 64-bit address built by `IMAD.WIDE.U32 Rd, Rofs, imm, Rbase` — not
  `[Rofs.U32 + URbase]`. Pointer parameters go into regular registers via `LDC.64`, which
  also keeps every compare in the `R,R` forms the encoder repository has; the UR-first
  form `ISETP_P_P_UR_R_P` is not in it.

## Checking the output

Use `cuobjdump`, never `nvdisasm` — it refuses any kernel containing `BRXU`, RCAsm's own
call/loop idiom.

```bash
cuobjdump -res-usage TestKernel.cubin   # expect REG:255 STACK:16384 CONSTANT[0]:952
cuobjdump -sass TestKernel.cubin
```

`STACK:16384` is the one to watch. The frame comes from the *template*, not from the
injected code, so a template without it yields a kernel whose `IADD3 R1, R1, -0x4000`
points into local memory the driver never reserved — no fault, just corruption.
