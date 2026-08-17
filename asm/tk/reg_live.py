#!/usr/bin/env python3
"""Check main.asm's hand-allocated register table, and report where the registers go.

  reg_live.py [main.asm] [cubin ...]

RCAsm has no register allocator: the KERNEL header IS the allocation. Every name owns a fixed
span of physical registers for the whole kernel, and nothing anywhere in the toolchain checks
that two names which are live at the same time were given different ones. A collision
assembles, passes align/barrier/pc, loads, runs, and returns wrong numbers.

That is not hypothetical. Getting this kernel from 255 registers to 127 produced exactly one
such collision on the first attempt, and this script exists because of it:

    InvO was given 8 registers and InvT placed immediately after. But InvMod256's Ro is NINE
    registers -- it is a 288-bit intermediate, Ro8 being the overflow word its normalisation
    loop tests -- so Ro8 landed precisely on Rt0 and the inversion would have been scribbling
    on its own scratch. Every existing check passed.

So the widths below are DECLARED, not inferred from the distance to the next name. Inferring
is what hid the bug: the table said InvO..InvT was 8 registers, and the table was the thing
being checked.

Two of them disagree with the vendored source's own header comment, and the emitted cubin is
what settled it:

    InvMod256   Ri  9      Ro  9      Rt 73     (mod_inv.asm:190-192 says "Rt_cnt = 70";
                                                 tvars=Rt64 feeds helpers needing nine, so
                                                 the body reaches Rt72)

Run it with one or more cubins to also check that nothing in the emitted code names a register
at or above the declared regcnt -- the other half of the same class of failure, and the one
that catches Acc leaking out of a gated region.
"""
import re
import subprocess
import sys
from collections import defaultdict

# Width of each name in physical registers. 8 = a 256-bit field element. Anything not listed
# is a scalar or an address pair and is taken from ADDR/SCALAR below.
WIDTH = {
    # 256-bit field elements and running state
    "PntX": 8, "PntY": 8, "Scal": 8, "Rinv": 8, "Dxi": 8, "MulA": 8, "MulB": 8,
    "MulR": 8, "Prod": 8, "Lam": 8, "Sqr": 8, "PxN": 8, "Acc": 8,
    # vendored contracts -- MEASURED against the cubin, not copied from the headers
    "Inv": 9,       # InvMod256 Ri, 9 and SPOILED
    "InvO": 9,      # InvMod256 Ro, 288-bit: 9, of which only the low 8 are the answer
    "InvT": 73,     # InvMod256 Rt, NOT the 70 its header claims
    "Tmp": 26,      # one block shared by MulMod256 (20), SqrMod256 (26), SubMod256_3 (2)
    "SqrT": 26, "Pt3T": 26,
    # 64-bit address pairs
    "AddrX": 2, "AddrY": 2, "AddrS": 2, "AddrC": 2, "Thr": 2,
}
DEFAULT_WIDTH = 1       # scalars

# Which phase each name is live in. Names in DIFFERENT groups may share registers -- that is
# the whole design. Names in the SAME group may not, and that is what gets checked.
OVERLAY = {
    "persistent": ["BDone", "gID", "TmpA", "TmpB", "Idx", "Half", "SAdr",
                   "PntX", "PntY", "Scal"],
    "A-prologue": ["ThrID", "BlockID", "AddrX", "AddrY", "AddrS", "AddrC", "Thr"],
    "B-inversion": ["Inv", "InvO", "InvT"],
    # COfs is reset by `MOV COfs, RZ` at the head of the walk and computed fresh in the
    # ladder; BpL is reloaded at the top of every batch. Neither survives the inversion, so
    # both belong here rather than in persistent -- which is what got the top to R124.
    "C-walk": ["Rinv", "Dxi", "MulB", "MulA", "MulR", "Prod", "Lam", "Sqr", "PxN",
               "Tmp", "SqrT", "Pt3T", "COfs", "BpL"],
    "acc-variants": ["Acc"],
}

# The declared count must exceed the highest register used by MORE THAN ONE. Measured on an
# RTX 5090 with identical instructions and only regcnt changing: top R126 faults with
# ILLEGAL_INSTRUCTION at regcnt 127 and 128, and passes at 130 and above. ptxas leaves the
# same margin in its own output for this kernel -- REG 122 declared, R119 the highest used.
# Three is the observed requirement; the check uses it because a build that violates it does
# not fail to assemble, it faults at launch after every other checker has passed.
REG_HEADROOM = 3
# Deliberate same-group aliases: two names for one block, never live at once.
ALIAS_OK = {frozenset(("MulR", "Prod")), frozenset(("Tmp", "SqrT")),
            frozenset(("Tmp", "Pt3T")), frozenset(("SqrT", "Pt3T"))}

# persistent must not collide with ANY overlay; the overlays may collide with each other.
ALWAYS_LIVE = "persistent"


def parse(src):
    lines, inhdr = [], False
    for ln in open(src).read().splitlines():
        if ln.startswith("KERNEL "):
            inhdr = True
        if inhdr:
            lines.append(ln)
            if not ln.rstrip().endswith("\\"):
                break
    hdr = " ".join(lines)
    m = re.search(r"regcnt\s*=\s*(\d+)", hdr)
    if not m:
        sys.exit("no regcnt in the KERNEL header")
    alloc = {n: int(r) for n, r in re.findall(r"(\w+)\s*=\s*R(\d+)", hdr)}
    return int(m.group(1)), alloc


def check_table(regcnt, alloc):
    bad = []
    group = {n: g for g, ns in OVERLAY.items() for n in ns}
    unknown = sorted(set(alloc) - set(group))
    if unknown:
        bad.append("names in the table with no overlay assigned: %s" % " ".join(unknown))
    missing = sorted(set(group) - set(alloc))
    if missing:
        bad.append("names assigned to an overlay but absent from the table: %s" % " ".join(missing))

    span = {n: (r, r + WIDTH.get(n, DEFAULT_WIDTH) - 1) for n, r in alloc.items()}

    print("%-10s %-13s %6s %8s   %s" % ("name", "overlay", "width", "span", "alignment"))
    for n in sorted(alloc, key=lambda x: (alloc[x], x)):
        lo, hi = span[n]
        w = hi - lo + 1
        note = "ok" if w == 1 else ("4-aligned" if lo % 4 == 0 else
                                    ("even" if lo % 2 == 0 else "** ODD BASE **"))
        if w > 1 and lo % 2:
            bad.append("%s starts at R%d, odd, but is %d registers wide" % (n, lo, w))
        print("%-10s %-13s %6d %8s   %s"
              % (n, group.get(n, "?"), w, "R%d..R%d" % (lo, hi), note))

    names = sorted(alloc)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if not (span[a][0] <= span[b][1] and span[b][0] <= span[a][1]):
                continue
            ga, gb = group.get(a), group.get(b)
            if frozenset((a, b)) in ALIAS_OK:
                continue
            if ga == gb or ALWAYS_LIVE in (ga, gb):
                bad.append("%s (%s, R%d..R%d) OVERLAPS %s (%s, R%d..R%d)"
                           % (a, ga, span[a][0], span[a][1], b, gb, span[b][0], span[b][1]))

    top = max(hi for lo, hi in span.values())
    prod = max(hi for n, (lo, hi) in span.items()
               if group.get(n) != "acc-variants")
    print("\ndeclared regcnt              : %d" % regcnt)
    print("top register, production     : R%d" % prod)
    print("top register, incl. Acc      : R%d  (acc variants raise regcnt -- see variants.py)" % top)
    print("headroom above top           : %d  (needs >= %d)" % (regcnt - prod, REG_HEADROOM))
    if regcnt - prod < REG_HEADROOM:
        bad.append("regcnt %d leaves only %d above R%d; needs %d -- this FAULTS at launch "
                   "with ILLEGAL_INSTRUCTION and every other checker passes"
                   % (regcnt, regcnt - prod, prod, REG_HEADROOM))
    # THE ACC VARIANTS TOO. variants.py raises regcnt for the accumulator rungs, and that
    # number was set to top+1 before the headroom rule existed -- so walk and pts faulted at
    # launch on the same run that confirmed the production kernel at 128, with this script
    # reporting OK because it only ever looked at the production top.
    try:
        acc = int(re.search(r"ACC_REGCNT\s*=\s*ACC_TOP\s*\+\s*(\d+)",
                            open("variants.py").read()).group(1)) + top
    except Exception:                           # noqa: BLE001 -- absent or restructured
        acc = None
    if acc is not None:
        print("acc-variant regcnt           : %d  (headroom %d above R%d)"
              % (acc, acc - top, top))
        if acc - top < REG_HEADROOM:
            bad.append("variants.py raises regcnt to %d for the acc rungs, only %d above R%d; "
                       "needs %d -- walk and pts FAULT at launch" % (acc, acc - top, top,
                                                                     REG_HEADROOM))
    print("blocks/SM at 256 threads     : %d  (needs regcnt <= 128)" % (65536 // (regcnt * 256)))
    return bad


def check_cubin(path, _unused_regcnt):
    """Check a cubin against ITS OWN declared register count, not main.asm's.

    Reading the count from the source would be wrong for exactly the variants that matter:
    variants.py raises regcnt to 136 for the accumulator rungs, so checking TestKernel_pts
    against main.asm's 127 reports the eight Acc registers as an overflow when they are the
    whole point. The cubin carries the number the driver will actually act on -- that is the
    one worth checking against.
    """
    try:
        sass = subprocess.run(["cuobjdump", "-sass", path], capture_output=True,
                              text=True, check=True).stdout
        usage = subprocess.run(["cuobjdump", "-res-usage", path], capture_output=True,
                               text=True, check=True).stdout
    except Exception as e:                      # noqa: BLE001 -- any failure is "cannot check"
        return ["%s: could not disassemble (%s)" % (path, e)]
    if not re.search(r"^\s+/\*[0-9a-f]+\*/", sass, re.M):
        return ["%s: disassembly is empty -- treating as a failure, not a pass" % path]
    regs = [int(x) for x in re.findall(r"REG:(\d+)", usage)]
    declared = max(regs) if regs else 0
    if not declared:
        return ["%s: no REG in -res-usage -- cannot check" % path]
    used = {int(x) for x in re.findall(r"\bR(\d+)\b", sass)}
    over = sorted(r for r in used if r >= declared)
    # HEADROOM AGAINST THE CUBIN'S OWN NUMBERS, not against the source table. This is the
    # check that does not need to know where the count came from -- main.asm's KERNEL line,
    # variants.py's ACC_REGCNT, or a sweep script's sed -- and it is the one that would have
    # caught the walk/pts fault. Everything the table check knows can be true while the cubin
    # that actually launches is built at a different number.
    head = declared - max(used)
    print("%-28s max R%-4d declared %-4d headroom %-3d %2d blk/SM  %s"
          % (path, max(used), declared, head, 65536 // (declared * 256),
             "OK" if not over and head >= REG_HEADROOM else
             "OVER: " + str(over) if over else "HEADROOM %d" % head))
    if over:
        return ["%s names %s at or above its declared regcnt %d" % (path, over, declared)]
    if head < REG_HEADROOM:
        return ["%s declares %d with R%d used -- headroom %d, needs %d. This LOADS, "
                "DISASSEMBLES and FAULTS at launch with ILLEGAL_INSTRUCTION"
                % (path, declared, max(used), head, REG_HEADROOM)]
    return []


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "main.asm"
    regcnt, alloc = parse(src)
    bad = check_table(regcnt, alloc)
    if len(sys.argv) > 2:
        print()
        for c in sys.argv[2:]:
            bad += check_cubin(c, regcnt)
    print()
    if bad:
        print("BAD  %s" % src)
        for b in bad:
            print("       %s" % b)
        sys.exit(1)
    print("OK   %s" % src)


main()
