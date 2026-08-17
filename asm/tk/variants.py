#!/usr/bin/env python3
"""Generate a bisect ladder from main.asm.

Each variant is main.asm with some marked regions cut and others uncommented, so every
rung differs from its neighbour by ONE construct. That turns "something in here is
illegal" into a single named cause, which reading the disassembly does not: the stage-1b
fault decoded cleanly, and the call target and return displacement were both verified
correct by hand before the ladder found the real problem (a .128 op on R50).

  id     identity only                     -- no call, no local memory, no ladder
  local  identity + STL/LDL                -- the local round trip alone
  call   identity + call_func              -- the call alone
  full   both                              == stage 1b
  sufp   identity + the suffix-product ladder (stage 2a): a real loop, dynamically
         indexed constant loads, and STL at a computed address
  inv    stage 2a + the single modular inversion (stage 2b): call_func InvMod256, which
         needs 70 temporaries, a uniform of its own, and all active threads in the warp
  walk   stage 2b + the inverse chain (stage 2c-i): an UPWARD loop that reads every slot
         of subp[] and advances the inverse, with the point arithmetic still absent
  pts    stage 2c-i + the +/- point arithmetic (stage 2c-ii): SqrMod256, SubMod256_3 and
         NegMod256, both branches and the minus-only tail
  jump   stage 2c-ii + the point jump (stage 2d, part 1): one batch, then x1/y1 advance by
         J = half*G through the inverse the walk finished with
  loop   jump + s1 += B, rem -= B and the outer batch loop (stage 2d, part 2) -- the whole
         points-only kernel, and main.asm exactly as written

Regions are `//@@NAME_BEGIN` .. `//@@NAME_END`. A region named in `cut` is deleted; one
named in `on` has its body uncommented; everything else is left as written.

**main.asm is always the CURRENT stage, never a union of stages**, so the earlier rungs
are reconstructed by uncommenting rather than the latest one by cutting. That is not a
stylistic choice: with stage 1b and stage 2a both active the kernel is not a superset, it
is meaningless -- the ladder writes subp[0] to [R1], the same slot 1b's round trip uses,
and its MulMod256 calls overwrite the register Prod aliases. It would assemble, load, and
produce numbers. So the TOP rung needs no edits at all, and the ones below
it get rebuilt.

**`loop` is the rung with no edits, and that is the invariant to check after a rebuild:**
`TestKernel_loop.cubin` must come out byte-identical to `TestKernel.cubin`. Every other rung
now differs from main.asm, `pts` most of all -- it swaps STOREID for STORELAM and STOREPNTX/Y
for STOREPTS, spending all four output arrays on the tail point's chain rather than on the
kernel's actual results. That costs `pts` its identity guard, which is exactly why the swap
lives here and not in main.asm: the eight other rungs keep it.

Exactly one of the STORE* regions writes Px in each variant, and exactly one writes Py.

usage: variants.py <main.asm> <outdir> [name ...]
"""
import re, sys, os

# name  -> (regions to delete, regions to uncomment)
#
# LOOPTOP and LOOPEND are the outer batch loop's two halves and they are ONE construct: the
# label lives in the first and the back edge in the second, so a rung that cuts one must cut
# the other or the assembler is handed a branch to a label that no longer exists.
NOSTORE = ["STOREACC", "STOREINV", "STOREWALK", "STOREPTS"]
NOLOOP = ["JUMP", "LOOPTOP", "LOOPEND"]
NOPNT = ["STOREPNTX", "STOREPNTY"]
VARIANTS = {
    "id":    (["SUFP", "INV", "WALK"] + NOLOOP + NOSTORE, []),
    "local": (["SUFP", "INV", "WALK"] + NOLOOP + NOSTORE, ["LOCAL"]),
    "call":  (["SUFP", "INV", "WALK", "STOREPNTX"] + NOLOOP + NOSTORE, ["CALL", "STOREPROD"]),
    "full":  (["SUFP", "INV", "WALK", "STOREPNTX"] + NOLOOP + NOSTORE,
              ["CALL", "LOCAL", "STOREPROD"]),
    "sufp":  (["INV", "WALK", "STOREINV", "STOREWALK"] + NOLOOP + NOPNT, ["STOREACC"]),
    "inv":   (["WALK", "STOREWALK"] + NOLOOP + NOPNT, ["STOREINV"]),
    # PLUS/PLUST and WACC/WACCT are nested INSIDE the WALK region, so the rungs above that
    # cut WALK must not name them -- the marker is already gone by the time they are looked
    # up, and region() exits rather than shrugging.
    "walk":  (["PLUS", "PLUST"] + NOLOOP + NOPNT,
              ["ACCINIT", "WACC", "WACCT", "STOREWALK"]),
    # pts spends start_scalars/counts256 on the tail point's Lam and Sqr instead of on the
    # identity copy, and Px/Py on the accumulated product and the tail's px3. It is the only
    # rung that does either.
    #
    # PACC/PACCM/PACCT are the px3 accumulator, and they are OFF in main.asm because they are
    # this rung's instrument and no one else's: two of the walk's eight MulMod256 per iteration,
    # about 17% of its dynamic instruction count, storing into a register the default kernel,
    # jump and loop never read. Leaving them on would have put that in every speed measurement
    # of a kernel that does not need them. ACCINIT comes with them -- the seed is gated
    # separately so the walk rung, which cuts PLUS/PLUST entirely, can still have it.
    "pts":   (NOLOOP + NOPNT + ["STOREID"],
              ["ACCINIT", "PACC", "PACCM", "PACCT", "STOREPTS", "STORELAM"]),
    # Stage 2d in two rungs, because it is two constructs. `jump` is one batch with the point
    # jump on the end -- the first time the inverse chain's final value is CONSUMED rather
    # than accumulated, which is why the walk rung passing did not already cover it. `loop`
    # adds s1 += B, rem -= B and the back edge, and is main.asm verbatim: no edits at all, so
    # its cubin must come out byte-identical to TestKernel.cubin and the rebuild checks that.
    "jump":  (["LOOPTOP", "LOOPEND"], []),
    "loop":  ([], []),
}

src, outdir = sys.argv[1], sys.argv[2]
want = sys.argv[3:] or list(VARIANTS)
os.makedirs(outdir, exist_ok=True)
L = open(src).read().splitlines()


def region(lines, name):
    """(begin, end) line indices of //@@NAME_BEGIN .. //@@NAME_END, inclusive."""
    b = e = None
    for i, ln in enumerate(lines):
        if ln.strip() == "//@@%s_BEGIN" % name:
            b = i
        elif ln.strip() == "//@@%s_END" % name:
            e = i
    if b is None or e is None:
        sys.exit("marker %s not found in %s" % (name, src))
    return b, e


# Acc sits at R128..R135, ABOVE the kernel's declared regcnt of 126, because keeping it
# inside is arithmetically impossible: persistent 36 + Inv 9 + InvO 8 + InvT 70 + Acc 8 is
# already 131. That is safe only because Acc is named exclusively inside these regions --
# a variant that switches any of them on genuinely touches R128+ and must say so, or the
# hardware will let it scribble on another thread's registers with nothing to report it.
#
# So: enabling any of these raises regcnt. Getting this wrong is not a build error, it is a
# kernel that runs and corrupts a neighbour, which is why it is derived from the region list
# rather than set per variant by hand.
#
# THE +1 WAS WRONG AND IT FAULTED. This read `ACC_REGCNT = 136  # R135 is the top of Acc, +1`
# and it was written before the rule existed: the declared count must clear the highest
# register used by MORE THAN ONE. At 136 the walk and pts rungs ran with a headroom of 1 and
# both died with CUDA_ERROR_ILLEGAL_INSTRUCTION, while every other rung -- headroom 4 or more
# -- passed, on the very run that confirmed the production kernel at 128. Same defect as the
# one 9455fde fixed in main.asm, in the one place reg_live.py was not looking.
#
# 139 gives the same headroom of 4 the production allocation runs at, which is the value
# actually measured to pass. These two rungs are instruments and already sit above the
# 128-register occupancy cliff, so the margin costs nothing here.
ACC_REGIONS = {"ACCINIT", "PACC", "PACCM", "PACCT", "WACC", "WACCT"}
ACC_TOP = 135                             # the top of Acc
ACC_REGCNT = ACC_TOP + 4                  # + headroom, NOT + 1 -- see above


def build(cut, on):
    out = list(L)
    for name in on:                       # uncomment first: cutting shifts indices
        a, b = region(out, name)
        for i in range(a + 1, b):
            out[i] = re.sub(r"^//", "  ", out[i], count=1)
    for name in cut:                      # one at a time, re-finding each
        a, b = region(out, name)
        out[a:b + 1] = []
    if ACC_REGIONS & set(on):
        for i, ln in enumerate(out):
            if ln.startswith("KERNEL "):
                out[i] = re.sub(r"regcnt=\d+", "regcnt=%d" % ACC_REGCNT, ln)
                break
        else:
            sys.exit("no KERNEL line to raise regcnt on")
    return "\n".join(out) + "\n"


for name in want:
    if name not in VARIANTS:
        sys.exit("unknown variant %s (have: %s)" % (name, " ".join(VARIANTS)))
    cut, on = VARIANTS[name]
    p = os.path.join(outdir, "main_%s.asm" % name)
    open(p, "w").write(build(cut, on))
    n = sum(1 for ln in open(p) if re.match(r"\s*\[B", ln) or ln.strip().startswith("call_func"))
    print("%-6s -> %s   (%d instruction lines)" % (name, p, n))
