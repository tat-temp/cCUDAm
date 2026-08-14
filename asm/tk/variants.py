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

Regions are `//@@NAME_BEGIN` .. `//@@NAME_END`. A region named in `cut` is deleted; one
named in `on` has its body uncommented; everything else is left as written.

**main.asm is always the CURRENT stage, never a union of stages**, so the earlier rungs
are reconstructed by uncommenting rather than the latest one by cutting. That is not a
stylistic choice: with stage 1b and stage 2a both active the kernel is not a superset, it
is meaningless -- the ladder writes subp[0] to [R1], the same slot 1b's round trip uses,
and its MulMod256 calls overwrite the register Prod aliases. It would assemble, load, and
produce numbers. So the TOP rung needs no edits at all, and the ones below
it get rebuilt.

Exactly one of the STORE* regions writes Px in each variant, and exactly one writes Py.

usage: variants.py <main.asm> <outdir> [name ...]
"""
import re, sys, os

# name  -> (regions to delete, regions to uncomment)
NOSTORE = ["STOREACC", "STOREINV"]
VARIANTS = {
    "id":    (["SUFP", "INV"] + NOSTORE, ["STOREPNTX", "STOREPNTY"]),
    "local": (["SUFP", "INV"] + NOSTORE, ["LOCAL", "STOREPNTX", "STOREPNTY"]),
    "call":  (["SUFP", "INV", "STOREPNTX"] + NOSTORE, ["CALL", "STOREPROD", "STOREPNTY"]),
    "full":  (["SUFP", "INV", "STOREPNTX"] + NOSTORE, ["CALL", "LOCAL", "STOREPROD", "STOREPNTY"]),
    "sufp":  (["INV", "STOREINV"], ["STOREACC"]),
    "inv":   ([], []),                              # == main.asm as committed
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


def build(cut, on):
    out = list(L)
    for name in on:                       # uncomment first: cutting shifts indices
        a, b = region(out, name)
        for i in range(a + 1, b):
            out[i] = re.sub(r"^//", "  ", out[i], count=1)
    for name in cut:                      # one at a time, re-finding each
        a, b = region(out, name)
        out[a:b + 1] = []
    return "\n".join(out) + "\n"


for name in want:
    if name not in VARIANTS:
        sys.exit("unknown variant %s (have: %s)" % (name, " ".join(VARIANTS)))
    cut, on = VARIANTS[name]
    p = os.path.join(outdir, "main_%s.asm" % name)
    open(p, "w").write(build(cut, on))
    n = sum(1 for ln in open(p) if re.match(r"\s*\[B", ln) or ln.startswith("call_func"))
    print("%-6s -> %s   (%d instruction lines)" % (name, p, n))
