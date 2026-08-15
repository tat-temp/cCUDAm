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
| 2a | the suffix-product ladder: a real loop, indexed constant loads, `STL` at a computed address | **runs on hardware, A and B agree, 256/256 EXACT** — 256 instructions |
| 2b | the single modular inversion: `call_func InvMod256` | **runs on hardware, A and B agree, 256/256 EXACT** — 976 instructions |
| 2c-i | the inverse chain: an upward loop over every `subp[i]` | **runs on hardware, A and B agree, 256/256 EXACT** — 1,384 instructions |
| 2c-ii | the ± point arithmetic: `SqrMod256`, `SubMod256_3`, `NegMod256` | **runs on hardware, A and B agree, 256/256 EXACT** — 1,888 instructions |
| 2d | the point jump, `Scal += B` / `Rem -= B`, the outer batch loop | **runs on hardware, A and B agree, 256/256 EXACT on both rungs** — 1,800 / 1,832 instructions |

**The points-only kernel is complete and correct on hardware.** Ten rungs, an RTX 5090: `id` and
`local` mismatch by construction, `call` and `full` match the compiled kernel thread for thread,
and `sufp` / `inv` / `walk` / `pts` / `jump` / `loop` are 256 EXACT out of 256 on both sides with
nothing non-canonical. `loop` is the one that closes it — four batches, so batches 2-4 start from
a point the kernel itself produced, and `s1` / `rem` advance by 4·B through the real loop guard.

What that does *not* cover, stated because a green ladder invites the wrong inference: 256 threads
in one block, one launch, and a configuration where every thread takes the same batch count — so
`InvMod256`'s all-active-threads precondition holds by construction and a ragged warp is still
untested. C8 is untouched and still has to be fixed before the hash layer returns. Nothing here is
a speed measurement.

**The bisect accumulator is now gated off by default** (`ACCINIT`, `PACC`, `PACCM`, `PACCT`,
switched on for `pts` alone, the same way `WACC`/`WACCT` are switched on for `walk`). `Acc` is the
product of every candidate x-coordinate — the instrument that lets one 256-bit output stand for
1,023 points — and the default kernel, `jump` and `loop` never read it. It was not cheap: two of
the walk's eight `MulMod256` per iteration, 1,023 calls per batch per thread. Removing the three
call sites took the default from 1,984 to 1,832 instructions, **−152**, which is more than the 38
instructions at the call sites: all three shared one binding (`RFirst=Acc, RSecond=PxN`), so the
whole 112-instruction `MulMod256` body they alone used went with them. That is `call_func`'s
one-body-per-binding rule read backwards, and it is worth knowing in both directions.

`walk` and `pts` came out byte-identical to the cubins that passed on hardware, which is the
check that says the gating moved nothing it should not have.

**Stage 2a matches the compiled kernel on an RTX 5090** — 256 EXACT out of 256 on both the
accumulator and the frame slot, A and B agreeing on every output limb. That covers a real
back edge, 511 iterations of it, dynamically indexed constant loads out of bank 3, `STL`
and `LDL` at a computed address across the whole 16 KB frame, and `SubMod256`/`MulMod256`
called 1,022 times.

It took four bugs to get there, and every one of them produced a cubin that loaded, ran and
returned an answer: an over-subscribed barrier, a two-cycle stall chain, a branch guarded on
a stale predicate, and a store with no read barrier. Each is now a rule in this file and a
check in `barrier_check.py` or `stall_check.py`, and each check was validated against the
broken build before the fix landed.

The write-back deliberately reports two different things — the accumulator `Px` **and** a
slot read back out of local memory as `Py`. That is what separated the last two bugs: `Px`
came back exact while `Py` was wrong, which said the arithmetic was right and the frame
round-trip was not. A write-back that only reported the accumulator would have called that
run a pass.

**Stage 2b matches the compiled kernel too** — 256/256 EXACT, and *zero* non-canonical, so
C9's tail never fired on these operands. It is the single `InvMod256` — one inversion per B
keys, which is the entire reason the ladder above it exists, and the largest routine in
Kernel02's set: 70 temporaries, its own uniform, six inlined helpers and `BRA.CONV`, none of
which had ever been through RCAsm's encoder rather than just its front end. It cost 976
instructions where ptxas spends 1,504 on the same path.

Three things about it shaped the code around it, and all three are the kind that fail
quietly:

- **It requires all active threads in the warp** (`mod_inv.asm:189`). A data-dependent loop
  with a warp-collective step, so a thread that reached it by a different path is a hang or
  a wrong answer for its neighbours. This kernel's two early exits are uniform by
  construction and that is a **precondition**, not an accident — it is H4's straddling warp
  under another name.
- **`Ri` is spoiled** — 9 registers in, destroyed — so `inverse` cannot be built in place
  the way the C++ writes it. Nine, not eight, because `inv_mod` works on 288 bits; the 9th
  word does not need zeroing here because `InvMod256` does it itself, exactly as the C++
  writes `r[8] = 0`.
- **70 temporaries plus a uniform.** That puts the high-water mark at R197 and is the single
  largest allocation in the file.

Non-canonical results are allowed rather than treated as a bug: the tail loop is
`while ((int)res[8] > 0) sub_288_P(res)`, which stops the instant word 8 is zero and can
leave the answer anywhere in `[0, 2^256)`. That is C9, and the C++ `inv_mod` has it
identically — so the two sides agree and the oracle allows the `+P` twin.

The oracle inverts by **Fermat** (`a^(P-2)`), deliberately sharing no structure with the
binary algorithm it judges — the same reason the C8 vectors came from Python rather than
from `EcInt`.

**Stage 2c-i matched on the first run** — the only rung here that has, and worth saying
because the four rules above are why. Nothing new was learned from it, which is the point:
the loop, the frame reads and the call sequence were all built out of mechanisms that had
already been forced to be right by the earlier failures.

It is the inverse chain — the loop the point
arithmetic will live inside — with the point work still absent. On its own it is the last
piece of pure ladder machinery: an *upward* loop where every other one here counts down, a
read of **every** slot of `subp[]` rather than just the two ends, and a second consumer of
the inversion. It gets its own rung because stage 2c-ii brings four vendored routines that
have never been through the encoder (`SqrMod256`, `SubMod256_3`, `NegMod256`, the parity
test), and debugging those on top of an unproven loop is what this ladder exists to avoid.

What it writes back is a **product**, not the last value, and that is the whole design of
the check. The identity the batch inversion exists for is `dx_inv_i == 1/(c_Gx[i] - x1)` at
*every* `i` — that is what lets one inversion serve B keys. Reporting only the last
`dx_inv_i` would leave 511 of the 512 `subp[]` reads untested, so the accumulator takes the
product of all of them, which is `1 / prod_i (c_Gx[i] - x1)`. One wrong slot moves it.

That also keeps the oracle honest: the host needs **one** Fermat inversion of a product it
forms with 512 multiplies, and never reproduces the suffix-product trick it is judging.
Recomputing each `1/(Gx[i]-x1)` directly would have been 512 exponentiations per thread, and
getting them cheaply would have meant running the same algorithm as the kernel — the H14
shape again.

**Stage 2c-ii is written and has not run.** It is the ± point arithmetic — both branches and
the minus-only tail — and it brings the last three vendored routines: `SqrMod256` (125
instructions, 26 temporaries), `SubMod256_3` and `NegMod256`.

The two branches are written out twice but **share every call binding**, so RCAsm emits one
body per routine and both call points jump to it. That is the whole reason the register
names are reused rather than duplicated: a distinct binding would mean a second copy of
`SqrMod256` for no gain. `Lam`/`PxN`/`Sqr`/`SqrT`/`Pt3T` deliberately **overlay** `InvT` —
`InvMod256` has returned and its 70 temporaries are dead, and the alternative was finding 60
more registers that do not exist under a 255 budget.

**The parity is computed and not checked, and the reason is C8.** `odd` is the low bit of
`s − y1`, and `s` comes out of `MulMod256`, which is non-canonical — it can be the true value
plus `P`. **`P` is odd**, so a non-canonical `s` has the *opposite* low bit. The parity is
therefore not a well-defined function of the inputs until C8 is fixed, and any oracle for it
would be comparing against a coin flip. It is computed anyway so the instruction mix matches
the reference, and it is what selects the 0x02/0x03 compressed-pubkey prefix once the hash
layer returns — which is precisely why DEVPLAN files C8 as a silently-missed-key defect
rather than a cosmetic one.

What *is* checked is the product of every `px3`, and that is safe under C8 in a way the
parity is not: a non-canonical factor is still congruent, `(a+P)·b ≡ a·b (mod P)`, so the
product is right and may itself land in `[P, 2^256)`, which the oracle allows.

The oracle inverts **each** `Gx[i] − x1` by Fermat rather than deriving them all from one
inversion — 512 exponentiations per thread, and that is the point: deriving them cheaply
means running the suffix-product ladder, which is the thing stages 2a–2c-i were verifying.
The expectation is now computed **once per thread instead of once per side**, which is what
keeps that affordable.

Two costs worth naming rather than discovering later: each `MulMod256` **binding** gets its
own copy of the 112-instruction body, and there are five of them now (976 → 1,384
instructions); and the loop spends 16 register copies an iteration moving `MulR` into the
accumulator and the running inverse, because a call point's `Ro` is fixed and cannot
ping-pong. Both are size and speed, not correctness, and both are cheaper to fix once the
walk is known to be right.

**Stage 2d ran, A and B agreed, and both were wrong** — which is the outcome this harness was
built to be able to report, and the first time it has had to.

`jump` and `loop` both came back `A and B agree on every output limb` with `s1 ok  rem ok`, and
both at `WRONG 256` against the oracle on `x1` *and* `y1`. So the outer batch loop, its guard,
the `Scal += B` / `Rem -= B` carry chains and the whole of the hand-written jump reproduce the
compiled kernel exactly; what they reproduce is a defect.

**`GpuCore.cu:378-380` had no counterpart on either side.** The walk's tail forms its
`dx_inv_i` and then, in the shipped kernel, does one more chain update —
`inverse *= (c_Gx[half-1] - x1)` — which is what turns `1/((Jx-x1)·(Gx[half-1]-x1))` into the
`1/(Jx-x1)` the jump consumes. Without it `lam` is off by that factor. Not congruent, so it
classifies `WRONG` rather than `NON-CANON`, and it moves `x3` as well as `y3` — a sign error or
a swapped subtract would have left `lam²` and therefore `x3` intact, which is what said early
that the *inverse* was wrong rather than the jump's own arithmetic.

Three things about how it survived this long are worth keeping:

- **The comment above the tail said "no chain update after it", and it was true when written.**
  On every rung up to `pts`, `inverse` is dead once the tail's `dx_inv_i` exists. Stage 2d added
  the first consumer of it after the walk and turned a true statement into a defect. A correct
  comment is not a permanent one.
- **No earlier rung could have caught it.** `walk` checks the product of the `dx_inv_i` and
  `pts` checks the tail *point*; this multiply feeds neither. It is the one link in the ladder
  whose only observable effect is on the jump, which is exactly why the jump is its own rung.
- **A and B agreeing proved nothing, because one person wrote both.** Both are transcriptions of
  the same misreading, so the A/B half of the harness reported agreement on a defect. What
  caught it is the oracle — which inverts `Jx - x1` by Fermat and shares no structure with the
  suffix-product ladder it judges. That is the H14 lesson with the signs reversed: a harness
  comparing two implementations that share an author is a harness comparing an implementation
  against itself.

The fix is at the head of the `JUMP` region rather than at the end of `WALK`, so every rung
below `jump` keeps the cubin it already passed on hardware with — verified byte-identical after
the rebuild. Both call bindings are ones the walk loop already uses, so it adds no function
bodies: +16 instructions, being 4 loads, 2 calls and 8 copies.

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

**Stage 2a launched cleanly and computed the wrong answer** (2026-08-14) — all 256 threads,
`Px` and `Py` alike — and the cause was an **over-subscribed scoreboard barrier**. It is
worth reading the diagnosis, because none of the three checkers that existed could see it
and the instruction stream was correct throughout.

`Py` localised it. It is `subp[half-1] = Jx - x1`, stored *before* the loop and read back
*after* it, and the loop only ever writes below that slot — so the pre-loop step was wrong
and `Px` merely inherited it. Then the arithmetic named the exact registers: thread 0's
`x1` is `P-1`, whose words 2..7 are all `0xFFFFFFFF`, so `SubMod256` passes those words
through unchanged. The low 128 bits came back exact and the high 128 bits did not, which
made `got` limbs 2-3 *literally* the bytes `LDC.64 c[0x3][0x30]` and `[0x38]` returned.

Rebuilding the harness's deterministic input set offline showed those bytes were **not
anywhere in the 32 KB constant image** — so the loads had not read the wrong address, they
had not landed at all. The prologue arms barrier 0 with four `PntX` loads and never drains
them in this variant (the drain lived in stage 1b's write-back, which `sufp` comments out),
so the ladder's four constant loads brought barrier 0 to **eight** outstanding operations.
The single wait then let execution through with the last two still in flight. The two that
survived were the two issued *first* — the ones with the most natural latency behind them.

Fixed by giving the constant loads their own barrier (4) and `batch_size` another (5).
`barrier_check.py` now enforces it, and the same run exposed a second defect of the class:
`uDesc` was read at the first `LDG` without barrier 2 ever being waited — correct only
because the `LDCU` was fifteen instructions back.

**That fix was correct and the answer was still wrong, for a second reason: the ladder ran
exactly one iteration.** Which is not a guess — with the inputs reproduced offline, `Px`
came out *equal to `subp[510]`*, the accumulator after a single multiply by `Gx[511]`. So
the barrier fix had worked: `SubMod256`, `MulMod256` and the constant reads were all
correct, and the loop was leaving after one pass.

The cause is the largest number in this file. **A guarded branch reads its predicate about
thirteen cycles after the producer writes it**, not five: over 41 predicate-producer →
guarded-branch pairs in the shipped kernel, ptxas never once goes below 13, whatever the
producer. The loop's `ISETP.NE` → `@P0 BRA.U` was written at S05, so the back-edge tested a
`P0` that `MulMod256` had left behind — it clobbers `P0..P4` earlier in the same iteration
— rather than the loop counter. The same ISETP feeding another *ISETP* needs only 5, which
is what makes this easy to get wrong.

Fixing it turned up one more trap worth knowing: **`S13` requires the yield bit.**
`[B------:R-:W-:-:S13]` assembles without complaint and yields an instruction nothing can
decode (`undefined value 0x1d for table TABLES_opex_8`), while `[B------:R-:W-:Y:S13]` is
fine — and ptxas sets `Y` on every one of its own S13 instructions. Worse, both checkers
reported `OK (0 instructions)` on that unreadable cubin, so they now fail when `cuobjdump`
returns nothing.

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

## Nine things that cost time here

- **A `BRXU` return address is a uniform PAIR, and `call_func` patches only the low word.**
  The high word is the caller's, `0xFFFFFFFF` for the backward jump from an appended body
  back into the kernel, set once in the prologue — and **one line covers one pair**. Stage
  2b added a second pair so `InvMod256`'s temporaries could not collide with the return
  address, gave it a low word from `call_func` and no high word from anywhere, and died at
  launch with `CUDA_ERROR_INVALID_PC`. Nothing had anything to say about it: the assembler
  was happy, `cuobjdump` disassembled it cleanly, and alignment, stalls and barriers all
  passed. Every instruction was right; a register was uninitialised. `./pc_check.py` is
  that rule.
- **A store needs a READ barrier if its data registers are rewritten later.** A store does
  not read its data at issue — the LSU reads it later, and `R-` says nothing about when.
  Rewrite the register first and the store writes the *new* value. This is the one that
  broke the ladder after the loop was fixed, and the shape of the failure is worth keeping:
  `Px` was **exact** while `Py` was wrong, because the accumulator never leaves registers
  and `Py` is the only value round-tripped through the frame. It came back as
  `subp[0].hi ++ subp[511].lo` — `subp[0]` being the accumulator **511 iterations later**,
  so the high half of a store issued *before* the loop read its data *after* the loop
  finished. The low half read on time; nothing said either had to. ptxas puts a read
  barrier on all four `STL`s of its own suffix-product loop and waits it at the head of the
  next iteration, and across both compiled kernels there is not one store whose source is
  rewritten later and which carries none. Enforced by `./barrier_check.py`, which also
  found the same omission in the **passing** `local` variant, where the `LDL` pair rewrites
  the registers the `STL` pair is storing.
- **A guarded branch needs THIRTEEN cycles after its predicate is written.** Not the five
  an ALU consumer needs — a branch reads its guard far earlier in the pipeline. Measured,
  and about as clean as evidence gets here: across 41 predicate-producer → guarded-branch
  pairs in the shipped kernel, ptxas never goes below 13, and `ISETP`, `LOP3`, `R2UR` and
  `VOTE` all bottom out at exactly 13. Stage 2a's loop was written at S05 and ran a
  **single iteration**, because the back-edge tested a `P0` that `MulMod256` had left
  behind. Two corollaries: `@P0 EXIT` is a guarded branch and wants the same 13, and a
  stall that large **requires the yield bit** — `[B...:R-:W-:-:S13]` produces an
  instruction that will not decode, `[B...:R-:W-:Y:S13]` is correct.
- **One group per barrier, and drain it before reusing it.** A write barrier is a counter,
  not a flag: every instruction naming it increments it and the wait blocks until it hits
  zero. That invites piling unrelated loads onto one barrier and waiting once, which is
  what made stage 2a wrong — eight operations outstanding on barrier 0, and the wait let
  execution through with the last two still in flight. The ceiling is **measured**: over
  the compiled kernels ptxas never leaves more than **six** outstanding on one barrier, and
  this kernel's groups of five are correct on hardware, so the limit is six or seven. It is
  not about spacing — ptxas puts a wait as little as **two** cycles after the arm it covers.
  Enforced by `./barrier_check.py`, whose first version used a threshold of 4 and flagged
  three groups that demonstrably work; the number has to come from measurement or the
  checker gets ignored.
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
./barrier_check.py TestKernel.cubin     # scoreboard + store read barriers; exits 1
./pc_check.py TestKernel.cubin          # branch and return targets; exits 1
```

Both run automatically at the end of `build.sh`. They are the cheap ones, and between them
they cover the two failure modes that produce a *loadable, clean-looking* cubin that dies
or lies at run time — which is the whole class that reading the disassembly cannot find,
because in both cases the listing is correct.

Each was checked against a known-broken build rather than only against a passing one.
`align_check.sh` flags the pre-fix cubins (`R50, R54`) and clears the shipped ptxas kernel,
whose own `subp[]` traffic — `STL.128 [R9], R4`, `LDL.128 R32, [R1]` — is 4-aligned
throughout. `stall_check.py` named all eleven under-stalled pairs in the faulting stage-2a
cubin, including the two on the loop-exit test, and later named all four predicate-to-branch
violations in the cubin whose ladder ran one iteration. `barrier_check.py` was run against the
wrong-answer cubin before anything was changed, and named barrier 0 climbing 5→6→7→8 with
the two over-limit arms being exactly `c[0x3][0x30]` and `c[0x3][0x38]` — the two loads the
hardware had returned stale — while staying clean on both compiled ptxas kernels.

`STACK:16384` is the one to watch. The frame comes from the *template*, not from the
injected code, so a template without it yields a kernel whose `IADD3 R1, R1, -0x4000`
points into local memory the driver never reserved — no fault, just corruption.
