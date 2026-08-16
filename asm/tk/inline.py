#!/usr/bin/env python3
"""Turn the out-of-line calls in a kernel .asm into inlined bodies.

  inline.py <in.asm> <out.asm>

WHY THIS EXISTS. The hand-written kernel reaches every field routine through `call_func`,
which emits one shared body per (function, binding) pair and a real branch at each site.
That is what buys the ~2x instruction density over ptxas, which inlines everything. But the
first speed measurement (DEVPLAN, 2026-08-16) found the hand-written kernel only 11% faster
at matched occupancy while issuing about HALF the field-math instructions -- so the density
is not translating, and there are two candidate explanations:

    1. the 16 KB local frame and 32 KB of subp[] traffic per thread per batch, which both
       implementations carry identically; or
    2. the calls themselves -- 18 live call sites in the walk loop body, each costing a UMOV
       to plant a return address, a BRXU out and a BRXU.U back, so 36 indirect branches per
       iteration and ~18,400 per batch, jumping around 29 KB of code that the inlined C++
       runs straight through.

This script separates them. It produces the same kernel with (2) removed and (1) untouched.
If the ratio moves, it was the calls; if it does not, it is memory, and the instruction-count
case for hand-written SASS is weaker than it looks either way.

WHAT IT DOES, and the one part that is not a search-and-replace:

    call_func F(args, Ret="...")   ->   inc_func F(args)

`inc_func` compiles the body with the same bindings and pastes it, with no branch and no
return: RCAsm appends the `Ret=` string only when walking called_func_list, which only
call_func populates (compiler.py:563). So Ret has to go, or it would be carried as an
argument that means nothing.

THE UMOV IS NOT DELETED, AND THAT IS THE POINT. Each call site is preceded by

    [B----4-:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_SubMod256) //RCASM:CallPointI

and it is tempting to drop the line along with the call, since an inlined body needs no
return address. Several of them carry a BARRIER WAIT -- `[B----4-]` above is what makes the
four LDCs that loaded this call's operand have landed. Delete the line and the wait goes with
it, and the inlined body reads a register the load has not written yet: silently, and exactly
the class of failure asm/tk/barrier_check.py exists to catch. So the line is kept, with its
control code untouched, and only its operand is neutralised:

    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0

One dead uniform write per site, 41 in total, in exchange for not having to reason about
which of them were load-bearing. The alternative -- moving each wait onto the first
instruction of the pasted body -- means editing text this file does not own.

EXPECT stall_check.py TO REPORT **BAD** ON THE RESULT, AND DO NOT "FIX" IT. That checker
separates code you wrote from code RCAsm pasted by POSITION -- the kernel body ends at the last
EXIT and appended FUNCTION bodies follow it -- because the vendored routines deliberately run
below the measured stall floor (MulMod256 chains back-to-back IMAD.WIDE.U32 at S01) and are
correct on hardware. Inlining moves exactly that code to the near side of the EXIT, so the
positional rule can no longer tell the two apart and the notes become failures.

That this is relocation rather than a new hazard was checked rather than assumed. Forcing every
violation to print in both builds and reducing them to (distance, need) signatures:

    TestKernel_loop     105 violations   6x dist1/need3, 3x dist1/need5, 5x dist2/need3,
                                         42x dist2/need4, 49x dist3/need4
    TestKernel_inline   278 violations   14x,            3x,             20x,
                                         118x,           123x

The signature SET is identical -- nothing appears in the inline build that is absent from the
call build -- and the counts are explained exactly by how many copies of each body now exist.
Subtracting InvMod256's 14 (still appended in both) and solving the two totals against the copy
counts gives 10 violations per MulMod256 body and 31 per SqrMod256+SubMod256_3 pair, which
reproduces 105 and 278 with nothing left over. Reproduce with scratchpad/sigcmp.sh.

BUILD IT LIKE THIS -- it is an experiment, not a rung, so it is not in bisect.sh:

    python3 inline.py main.asm /tmp/main_inline.asm
    MAIN=/tmp/main_inline.asm OUTNAME=TestKernel_inline.cubin RCASM=... ./build.sh

InvMod256 is deliberately LEFT AS A CALL. It is 586 instructions and runs once per batch
against 1,023 points, so inlining it tests nothing and costs the size of the whole rest of
the kernel again. The hypothesis is about the per-point calls in the walk.
"""
import re, sys

# Everything on the per-point path. InvMod256 is absent on purpose -- see the docstring.
INLINE = {"MulMod256", "SqrMod256", "SubMod256", "SubMod256_3", "NegMod256"}

CALL = re.compile(r"^call_func\s+(\w+)\s*\((.*)\)\s*(//.*)?$")
TAG = re.compile(r"//RCASM:(CallPoint\w+)")


def strip_ret(args):
    """Drop the Ret="..." argument. It is a quoted string holding commas and an = sign, so
    this cuts at `Ret=` and takes everything after the closing quote rather than splitting."""
    i = args.find("Ret=")
    if i < 0:
        return args.rstrip().rstrip(",")
    head = args[:i].rstrip().rstrip(",")
    rest = args[i + 4:]
    if rest.startswith('"'):
        j = rest.find('"', 1)
        tail = rest[j + 1:] if j >= 0 else ""
    else:
        tail = ""
    tail = tail.lstrip().lstrip(",").strip()
    return (head + ", " + tail).rstrip().rstrip(",") if tail else head


def main():
    src, dst = sys.argv[1], sys.argv[2]
    L = open(src).read().splitlines()
    inlined = kept = neutralised = 0

    for i, ln in enumerate(L):
        m = CALL.match(ln)
        if not m:
            continue
        fname, args, trail = m.group(1), m.group(2), m.group(3) or ""
        if fname not in INLINE:
            kept += 1
            continue

        L[i] = "inc_func %s(%s)" % (fname, strip_ret(args))
        inlined += 1

        # Neutralise the matching UMOV. Search backwards by TAG rather than assuming it is
        # the previous line: comments sit between them in places.
        t = TAG.search(trail)
        if not t:
            sys.exit("call to %s at line %d has no //RCASM:CallPoint tag" % (fname, i + 1))
        tag, found = t.group(1), False
        for j in range(i - 1, -1, -1):
            u = TAG.search(L[j])
            if u and u.group(1) == tag:
                if "UMOV" not in L[j]:
                    sys.exit("line %d carries %s but is not a UMOV" % (j + 1, tag))
                # Keep everything up to and including the mnemonic and destination; replace
                # the label operand and drop the tag. The control code is untouched.
                L[j] = re.sub(r"(UMOV\s+\w+\s*,\s*).*$", r"\g<1>0x0", L[j])
                neutralised += 1
                found = True
                break
        if not found:
            sys.exit("no UMOV found for %s (call at line %d)" % (tag, i + 1))

    open(dst, "w").write("\n".join(L) + "\n")
    print("  inlined %d call sites (%d UMOVs neutralised), left %d as calls -> %s"
          % (inlined, neutralised, kept, dst))
    if inlined != neutralised:
        sys.exit("inlined %d but neutralised %d -- these must match" % (inlined, neutralised))


main()
