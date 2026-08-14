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
| 1 | prologue, parameter loads, gid, bounds bail, 64-bit global I/O, 16 KB frame | **runs on hardware** — 64 instructions |
| 1b | `call_func MulMod256` + a local-frame round trip | **runs, and the arithmetic is right** — 184 instructions |
| 2a | the suffix-product ladder: a real loop, indexed constant loads, `STL` at a computed address | **builds, alignment-clean** — 256 instructions, not yet run |
| 2b–2d | `InvMod256`, the ± walk, the point jump, the outer batch loop | not written |

**Stage 1b matches the compiled kernel exactly on an RTX 5090** — 253 EXACT, 3 non-canonical,
0 wrong out of 256 threads, which is *the same verdict side A gets*. That is the first
hand-written SASS in this project shown to compute the right answer on a device, and it
settles the two things the whole route rests on: `call_func` really calls and returns, and
`MulMod256` really multiplies. The 3 non-canonical are C8, present identically in both
implementations — see below.

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

Stage 2a is the suffix-product ladder from `GpuCore.cu:224-233`, and it adds three
mechanisms at once: a real backward-branch loop, a dynamically indexed constant load
(`LDC.64 Rd, c[0x3][Rofs+imm]` — warp-uniform, so it broadcasts), and `STL` at a computed
address rather than a constant offset off `R1`. All four new instruction forms assembled
first try. It writes `Px = acc` and `Py = subp[half-1]`; the second is deliberately *not*
`acc` — it is the value stored before the loop at the top of the frame, so reading it back
after 511 stores is what says the ladder wrote where it meant to. A ladder walking off the
end of the frame could still produce the right `acc`.

**Two aliasing rules the call ABI exists to enforce**, both found by reading the routines
rather than by testing:

- **`MulMod256`'s `Ro` must not alias `RFirst` or `RSecond`.** Its first instruction writes
  `Ro0` and its second writes `Ro2`, while `RFirst2` is not read until the fifth. The C++
  this mirrors is `mul_mod(acc, acc, tmp)` — in-place, and recorded in DEVPLAN as safe — so
  a direct transcription would have been silently wrong.
- **`SubMod256` *is* alias-safe** and is used that way (`Ro=RFirst`) to save eight copies:
  it is a straight elementwise pass in increasing index order, so instruction *k* writes
  `Ro_k` in the same instruction that reads both inputs at *k*, and the second half touches
  only `Ro`.

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

## Five things that cost time here

- **The stall count is a correctness field, not a performance knob.** `IADD3`, `IMAD`,
  `ISETP`, `LOP3`, `MOV`, `SEL` and `SHF` are fixed-latency: they set no scoreboard
  barrier, so `Snn` is the only thing that makes the next instruction see their result.
  Too short and it reads the *previous* value — silently, with no diagnostic anywhere in
  the build. When the stale value is an address that is `CUDA_ERROR_ILLEGAL_ADDRESS`;
  when it is not, it is a wrong answer. Stage 2a was written at S01 and died on its first
  store, because `IMAD COfs, Half, 0x10, RZ` was followed immediately by a read of `COfs`,
  which at that point had never been written at all. **Rule: S05 whenever the next
  instruction reads what this one wrote**, enforced by `./stall_check.py`. The threshold
  is measured, not assumed — the minimum ptxas itself ever emits over the ~4k
  control-coded instructions of `asm/GpuCore_sm120.asm`:

  | | IMAD | IADD3 | LOP3 | SEL | ISETP | MOV | SHF |
  |---|---|---|---|---|---|---|---|
  | min stall | S03 | S04 | S04 | S04 | S05 | S05 | S05 |

  S05 covers all of them with one number. It is what ptxas *chooses*, though, not where
  the hardware breaks: RCAsm's own `MulMod256` chains back-to-back `IMAD.WIDE.U32` into
  one accumulator at S01 and is correct on this card, so a same-pipe dependent pair
  evidently forwards faster than a cross-pipe one. `stall_check.py` therefore fails only
  on the kernel body and reports the vendored `FUNCTION` bodies as a note.
- **Register alignment is a hardware rule and nothing in this path checks it.** A `.128`
  access needs its *data* register operand to be a multiple of 4; a `.64` access needs it
  even. The dialect, cuAssembler and the ELF writer all encode whatever number is written,
  so a violation is invisible until the launch dies with `CUDA_ERROR_ILLEGAL_INSTRUCTION`
  — from a cubin that loads, reports the right register and frame usage, and disassembles
  cleanly. Stage 1b put `Prod` at R50 and `STL.128 [R1], R50` cost a GPU round trip and a
  four-variant bisect ladder to localise. Kernel02 never trips this because every one of
  its `.128` bases is 4-aligned by construction (`jPntX=R28`, `TmpTmp=R84`, `rx=R84`), and
  so is ptxas's own local traffic. **Run `./align_check.sh *.cubin` after every build** —
  it exits non-zero on a violation and it names the register.
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
./align_check.sh TestKernel.cubin       # register alignment; exits 1 on a violation
./stall_check.py TestKernel.cubin       # fixed-latency stalls; exits 1 on a violation
```

Both run automatically at the end of `build.sh`. They are the cheap ones, and between them
they cover the two failure modes that produce a *loadable, clean-looking* cubin that dies
or lies at run time — which is the whole class that reading the disassembly cannot find,
because in both cases the listing is correct.

Each was checked against a known-broken build rather than only against a passing one.
`align_check.sh` flags the pre-fix cubins (`R50, R54`) and clears the shipped ptxas kernel,
whose own `subp[]` traffic — `STL.128 [R9], R4`, `LDL.128 R32, [R1]` — is 4-aligned
throughout. `stall_check.py` named all eleven under-stalled pairs in the faulting stage-2a
cubin, including the two on the loop-exit test.

`STACK:16384` is the one to watch. The frame comes from the *template*, not from the
injected code, so a template without it yields a kernel whose `IADD3 R1, R1, -0x4000`
points into local memory the driver never reserved — no fault, just corruption.
