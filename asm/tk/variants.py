#!/usr/bin/env python3
"""Generate a bisect ladder from main.asm.

The full stage-1b kernel faults with CUDA_ERROR_ILLEGAL_INSTRUCTION. It contains
exactly two constructs the identity kernel does not -- an out-of-line call_func and a
local-memory round trip -- so building all four combinations turns "something in here is
illegal" into a single named cause. Reading the disassembly does not: it decodes
cleanly, and the call target and return displacement were both verified correct by hand.

  id     identity only            (no call, no local memory)
  local  identity + STL/LDL       (local memory alone)
  call   identity + call_func     (the call alone)
  full   both                     == main.asm as committed

usage: variants.py <main.asm> <outdir>
"""
import re, sys, os

src, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
L = open(src).read().splitlines()


def region(lines, name):
    """Return (begin, end) line indices of //@@NAME_BEGIN .. //@@NAME_END, inclusive."""
    b = e = None
    for i, ln in enumerate(lines):
        if ln.strip() == "//@@%s_BEGIN" % name:
            b = i
        elif ln.strip() == "//@@%s_END" % name:
            e = i
    if b is None or e is None:
        sys.exit("marker %s not found in %s" % (name, src))
    return b, e


def build(keep_call, keep_local):
    out = list(L)
    # Storing Prod is only meaningful when the call ran; otherwise store PntX so the
    # variant is a clean identity kernel rather than one reading uninitialised registers.
    a, b = region(out, "STOREPROD")
    c, d = region(out, "STOREPNTX")
    if keep_call:
        out[c + 1:d] = []                                   # drop the PntX block
    else:
        out[a + 1:b] = []                                   # drop the Prod block
        c, d = region(out, "STOREPNTX")
        for i in range(c + 1, d):                           # uncomment the PntX block
            out[i] = re.sub(r"^//", "  ", out[i], count=1)
    if not keep_local:
        a, b = region(out, "LOCAL")
        out[a:b + 1] = []
    if not keep_call:
        a, b = region(out, "CALL")
        out[a:b + 1] = []
    return "\n".join(out) + "\n"


for name, kc, kl in (("id", False, False), ("local", False, True),
                     ("call", True, False), ("full", True, True)):
    p = os.path.join(outdir, "main_%s.asm" % name)
    open(p, "w").write(build(kc, kl))
    n = sum(1 for ln in open(p) if re.match(r"\s*\[B", ln) or ln.startswith("call_func"))
    print("%-6s -> %s   (%d instruction lines)" % (name, p, n))
