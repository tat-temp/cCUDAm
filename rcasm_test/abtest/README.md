# A/B — hand-written SASS `TestKernel` vs the ptxas-compiled one

Same signature, same parameter ABI, same constant tables, same inputs, two cubins.

```bash
./build.sh
./abtest ab_compiled.cubin ../../asm/tk/TestKernel.cubin 256
```

`build.sh` builds only side A (the compiled kernel) and the harness. Side B —
`asm/tk/TestKernel.cubin` — is a **committed fixture**, because rebuilding it needs an
RCAsm checkout plus `pyelftools`/`sympy` and the machine that can build it is generally
not the machine with the GPU. `cuModuleLoad` reporting `CUDA_ERROR_FILE_NOT_FOUND (301)`
for side B means the fixture is missing, not that the cubin is bad. Rebuild it with
`RCASM=/path/to/RCAsm ../../asm/tk/build.sh`.

**Speed runs use a different side A**, and it is *not* committed — `*.cubin` is gitignored, so
it is absent from a fresh clone and the same `CUDA_ERROR_FILE_NOT_FOUND (301)` names the file
without saying how to make it:

```bash
make -C ../.. nohash-cubin SM=120
./abtest ../../GpuCore_nohash.cubin ../../asm/tk/TestKernel_loop.cubin 43520 5 loop
```

`ab_compiled*.cubin` are purpose-built bisect counterparts — one per rung, each computing what
that rung computes — and are the right side A for a *correctness* diff. `GpuCore_nohash.cubin`
is the real `TestKernel` with the hash layer compiled out, and is the only honest side A for a
*speed* number: it is the kernel this one is trying to replace. Every ratio in
`asm/tk/README.md` has it on one side.

Arguments: `<cubinA> <cubinB> [threads] [iters|Ns] [mode]`. `threads` must be a multiple of 256
(defaults to 256). `iters` is a launch count, or `180s` for **180 seconds per side**.

**Launches are interleaved A,B,A,B — and that is what makes a long run worth doing.** The
harness used to run every launch of A and then every launch of B, which is a thermal ramp
pointed at exactly one side: A measures a cool card, B measures the card A just heated. At
`iters 5` that is small; the moment anyone runs longer to average out throttling — the obvious
and correct instinct — it grows without bound, and it grows against B. Interleaved, both sides
sit in the same thermal envelope by construction.

It reports **best and median** per side, with the spread. Best-of-N answers "how fast can this
kernel go" and is the wrong statistic for "is this card throttling": it reports the single
least-throttled launch, so a long run and a short one give the same number and the spread that
would have shown the problem never appears. The median moves when the card slows. **The two
ratios agreeing is the evidence the run is thermally clean**; the harness computes the gap and
says so. None of this makes the absolute numbers throttle-proof — nothing can — it makes the
*ratio* fair, and the absolute A column still has to be checked against its own history.

## It answers two questions, and keeps them apart

1. **Do A and B agree with each other?** — the A/B question.
2. **Is each of them right?** — against an independent oracle.

(2) exists because both sides can be wrong the same way, and here they demonstrably are:
this project's `mul_mod` is "almost reduced" (DEVPLAN C8) and RCAsm's `MulMod256` has
been measured on hardware to have the identical defect, returning `p+1` where `1` is
correct. A harness that only diffed A against B would print a clean pass over two
non-canonical implementations — the H14 lesson restated. So every result is classified:

| | |
|---|---|
| `EXACT` | bit-identical to the canonical `(a*b) mod P` |
| `NON-CANON` | congruent but ≥ P, i.e. canonical + k·P — **C8's signature** |
| `WRONG` | not congruent at all |

`NON-CANON` is not a pass and not a failure: it is the expected, known defect. What
matters for a drop-in replacement is that A and B agree *bit for bit*, because
`SHA256_33_from_limbs` serializes limbs raw and `sub_mod_is_odd` derives the
compressed-pubkey prefix from `r[0]&1` — congruence is not enough for either.

## The oracle checks itself first

A wrong oracle would invalidate everything, so `selftest()` runs before any CUDA call and
aborts on failure. Five cases, two of which are exactly the ones C8 turns on:
`(P-1)²  == 1`, `2·(P+1)/2 == 1`, plus `1·1`, `0·x`, `(P-1)·1`.

```bash
./abtest --selftest     # oracle only, no GPU needed
```

It earned its keep immediately: `(P+1)/2`'s low limb carries the bit shifted down out of
limb 1, and the first version of that constant dropped it. The value still looked
plausible, its double was not `P+1`, and the edge case would have silently stopped
testing anything.

## What is under test right now

The SASS kernel is at **stage 1b** (see `asm/tk/README.md`), so `ab_kernel.cu` mirrors
exactly that and nothing more:

```
Px      = mul_mod(x1, y1)     <- the operation being compared
Py      = y1                  <- identity
scalars = s1                  <- identity
counts  = rem                 <- identity
```

The identity fields are checked too. They are not filler: they catch a wrong parameter
offset, a wrong `gid`, or a bad address, which would otherwise look like an arithmetic
failure.

The inputs are deterministic (xorshift, fixed seed) and the first four threads carry
constructed edge cases rather than random operands — `(P-1)²`, `2·(P+1)/2`,
`(P+1)/2·2`, `1·1`. Random 256-bit operands never reach them: a product landing in
`[P, 2^256)` has probability ~2⁻²²⁴, which is precisely how C8 stayed invisible.

## Timing

Reported, and labelled meaningless until both kernels do the same work. The compiled
kernel is `REG:78 STACK:0`; the hand-written one is `REG:255 STACK:16384`, which caps it
at one block per SM. That is a real difference to fix, not a measurement artifact — but
it cannot be read as an arithmetic result either.

## Running it in WSL

There is no driver in WSL, so only `--selftest` works there, and even that needs the stub
under its SONAME:

```bash
mkdir -p /tmp/cudastub
ln -sf /usr/local/cuda/lib64/stubs/libcuda.so /tmp/cudastub/libcuda.so.1
LD_LIBRARY_PATH=/tmp/cudastub ./abtest --selftest
```

Everything else needs the GPU host.
