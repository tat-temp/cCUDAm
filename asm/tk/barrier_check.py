#!/usr/bin/env python3
"""Check scoreboard-barrier hygiene in a cubin's SASS.

  ./barrier_check.py TestKernel.cubin [more.cubin ...]

Variable-latency instructions (LDG, LDC, LDL, STL, S2R, ...) name a write barrier in their
control code. The barrier is a COUNTER: every instruction naming it increments it, and a
wait blocks until it reaches zero. Two things go wrong with that, both silently, and
neither is visible to align_check.sh or stall_check.py because the instruction stream is
perfectly correct in each case:

  1. USE BEFORE WAIT -- a register produced by a barrier-carrying load is read without the
     barrier ever being waited. The read gets whatever was in the register before.

  2. OVER-SUBSCRIPTION -- too many operations outstanding on one barrier at once. This is
     what made the stage-2a ladder wrong. The prologue arms barrier 0 with four PntX loads
     and, in the sufp variant, never drains them -- the drain lived in stage 1b's
     write-back, which that variant comments out -- so the ladder's four constant loads
     brought barrier 0 to EIGHT outstanding operations. The single wait then let execution
     through with the last two still in flight, and MulB4..MulB7 were read stale. The
     give-away on hardware was that the low 128 bits of the result were exact and the high
     128 bits were foreign to the entire constant image: the two loads that landed were the
     two issued first.

THE THRESHOLD IS MEASURED, NOT GUESSED, and it is ptxas's ceiling rather than a known
hardware limit. Over the compiled kernels the most ptxas ever leaves outstanding on one
barrier is SIX; this kernel ran EIGHT and read stale registers, while its groups of five
(barriers 2 and 3 in the prologue) are correct on hardware. So the true limit is six or
seven, and MAX_OUTSTANDING is set to 6 -- the largest value the compiler itself relies on.

A first version of this check used 4 and flagged three groups that demonstrably work. A
checker that cries wolf on known-good code is one that gets ignored, so the number has to
come from measurement.

What the count does NOT appear to be about is spacing: ptxas puts a wait as little as TWO
cycles after the arm it covers (`LDC R5, c[0x0][0x360]` followed immediately by an IMAD
that waits on it), so an insufficient arm-to-wait gap is not the mechanism here.

Rule: ONE GROUP PER BARRIER, AND DRAIN IT BEFORE REUSING IT.

Approximation worth knowing: this walks the instruction stream linearly and does not model
branches, so a wait that is reachable only on one path is credited on all of them. That is
the right bias for a build gate -- it under-reports rather than crying wolf -- but it means
a clean run is not a proof. Like stall_check.py, only the kernel body can fail; the
appended FUNCTION bodies are vendored and are reported as a note.

Exit 1 if anything in the KERNEL BODY is flagged, so it can gate a build.
"""
import re, subprocess, sys, os

MAX_OUTSTANDING = 6
CUDA = os.environ.get("CUDA", "/usr/local/cuda")

INSN = re.compile(r"/\*([0-9a-f]{4,})\*/\s+(.*?);\s*/\* (0x[0-9a-f]+) \*/")
WORD2 = re.compile(r"^\s*/\* (0x[0-9a-f]+) \*/\s*$")


def ctrl(w):
    return (w >> 46) & 7, (w >> 52) & 0x3F      # write barrier, wait mask


def width(text):
    """How many consecutive registers the destination covers."""
    op = text.split()[0]
    if ".128" in op: return 4
    if ".64" in op:  return 2
    return 1


def dst(text):
    """(prefix, number, count) of the destination register, or None."""
    t = re.sub(r"^@!?\w+\s+", "", text)
    m = re.match(r"[\w.]+\s+(U?R)(\d+)\s*,", t)
    if not m or m.group(2) == "Z":
        return None
    return m.group(1), int(m.group(2)), width(t)


def reads(text):
    """Every register named after the destination, as (prefix, number) pairs."""
    t = re.sub(r"^@!?\w+\s+", "", text)
    parts = t.split(",", 1)
    if len(parts) < 2:
        return set()
    return {(m.group(1), int(m.group(2)))
            for m in re.finditer(r"\b(U?R)(\d+)\b", parts[1])}


def rows_of(path):
    sass = subprocess.run([CUDA + "/bin/cuobjdump", "-sass", path],
                          capture_output=True, text=True).stdout
    out, pend = [], None
    for ln in sass.splitlines():
        i = INSN.search(ln)
        if i:
            pend = (i.group(1), i.group(2).strip())
            continue
        w = WORD2.match(ln)
        if w and pend:
            wbar, wait = ctrl(int(w.group(1), 16))
            out.append((pend[0], pend[1], wbar, wait))
            pend = None
    return out


def check(path):
    rows = rows_of(path)
    kend = max((i for i, r in enumerate(rows) if r[1].split()[0].lstrip("@!") == "EXIT"),
               default=len(rows) - 1)

    live = {b: [] for b in range(6)}     # barrier -> outstanding arming instructions
    pending = {}                         # (prefix, regnum) -> (barrier, addr, text)
    bad, note = [], []

    def flag(k, msg):
        (bad if k <= kend else note).append(msg)

    for k, (addr, text, wbar, wait) in enumerate(rows):
        for b in range(6):
            if wait & (1 << b):
                live[b] = []
                for key, (bb, _, _) in list(pending.items()):
                    if bb == b:
                        del pending[key]

        for pfx, num in reads(text):
            hit = pending.get((pfx, num))
            if hit:
                flag(k, "        /*%s*/ reads %s%d before barrier %d is waited\n"
                        "            produced by /*%s*/ %s\n"
                        "            %s" % (addr, pfx, num, hit[0], hit[1], hit[2], text))
                del pending[(pfx, num)]

        if wbar != 7:
            live[wbar].append(addr)
            if len(live[wbar]) > MAX_OUTSTANDING:
                flag(k, "        /*%s*/ makes %d operations outstanding on barrier %d\n"
                        "            armed at %s\n"
                        "            %s" % (addr, len(live[wbar]), wbar,
                                            " ".join(live[wbar]), text))
            d = dst(text)
            if d:
                pfx, base, n = d
                for j in range(n):
                    pending[(pfx, base + j)] = (wbar, addr, text)

    tail = "   (%d in the vendored FUNCTION bodies -- expected)" % len(note) if note else ""
    if not bad:
        print("OK    %s   (%d instructions, kernel body %d)%s"
              % (path, len(rows), kend + 1, tail))
        return 0
    print("BAD   %s%s" % (path, tail))
    for m in bad:
        print(m)
    return 1


sys.exit(max(check(p) for p in sys.argv[1:]) if len(sys.argv) > 1 else
         (print(__doc__.strip().splitlines()[2]) or 1))
