# Split-column field math

`mul_mod`/`sqr_mod`'s 512-bit product cores in `Math.cuh` are GENERATED. Do not hand-edit them.

Blackwell fuses an adjacent `mad.lo.cc.u32` / `madc.hi.cc.u32` pair into one `IMAD.WIDE.U32.X`
(multiply + 64-bit accumulate + carry in/out), but only when the accumulator pair is 64-bit
aligned. Splitting the limb products by column parity makes every pair aligned, so every fusion
sticks: 9,776 -> 8,176 SASS instructions with the wide-multiply count unchanged.

    python3 gen.py    > split.inc      # mul512_split
    python3 gensqr.py > sqrsplit.inc   # sqr512_split
    python3 verify_split.py            # replays the emitted stream against Python bignums
    python3 verify_sqr.py

Then paste the two `.inc` bodies into `Math.cuh`. The oracles cover 0, 2^256-1 squared, and
random pairs; the reduction tail is not generated and is unchanged.

After any toolkit bump, re-check that `IMAD.WIDE.U32.X` still appears in the SASS -- the fusion
is a ptxas peephole, verified on CUDA 13.0 / sm_120.
