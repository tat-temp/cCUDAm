#!/usr/bin/env python3
"""Check fixed-latency stall counts in a cubin's SASS.

  ./stall_check.py TestKernel.cubin [more.cubin ...]

Fixed-latency instructions (IADD3, IMAD, ISETP, LOP3, MOV, SEL, SHF, PRMT, LEA) carry no
scoreboard barrier. The `Snn` field of the control code is the ONLY thing enforcing a
register or predicate dependency on them, so a stall that is too short means the consumer
reads the previous value. Nothing in the RCAsm path checks this either: it assembles, it
loads, and it computes with stale operands -- which, when the operand is an address, is
CUDA_ERROR_ILLEGAL_ADDRESS, and when it is not, is a silently wrong answer.

That is how the stage-2a ladder failed. `IADD3 COfs, COfs, -0x20` followed immediately by
`ISETP.NE COfs, RZ` at S01 read the pre-decrement value, so the loop ran one iteration too
many and stored below the frame.

The thresholds are MEASURED, not assumed -- the minimum stall ptxas itself ever emits for
each opcode when the very next instruction consumes its result, taken over the ~4k
control-coded instructions of asm/GpuCore_sm120.asm (this same kernel, compiled):

    IMAD S03   IADD3 S04   LOP3 S04   SEL S04   ISETP S05   MOV S05   SHF S05

A single threshold of S05 covers all of them, and that is what this enforces. It is a
touch conservative for IMAD and IADD3; at ~20 scheduling slots per loop iteration against
two ~120-instruction calls, that is not worth optimising. Kernel02 uses S04 or more
throughout for the same reason.

Only ADJACENT pairs are checked -- a dependency two instructions later has the
intervening instruction's stall to cover it as well, and summing that correctly means
modelling issue rates. Adjacency is where the danger is and where it is unambiguous.

**Only the kernel body is a failure.** RCAsm's appended FUNCTION bodies (mod_mul.asm and
friends) go below this threshold deliberately -- MulMod256 chains back-to-back
IMAD.WIDE.U32 into the same accumulator at S01 -- and they are correct on hardware: the
`call` and `full` rungs match the compiled kernel thread for thread on an RTX 5090. Which
means S05 is what ptxas CHOOSES, not the point at which the hardware breaks; a same-pipe
dependent pair evidently forwards faster than a cross-pipe one. So those are reported as a
note and do not fail the run. A checker that cries wolf on known-good vendored code is one
that gets ignored. The split is the last EXIT: the kernel ends there, and every appended
body ends with BRXU.U instead.

Exit 1 if anything in the KERNEL BODY is under-stalled, so it can gate a build.
"""
import re, subprocess, sys, os

MIN_STALL = 5
FIXED = ("IADD3", "IMAD", "ISETP", "LOP3", "MOV", "SEL", "SHF", "PRMT", "LEA")
CUDA = os.environ.get("CUDA", "/usr/local/cuda")

# cuobjdump prints two encoding words per instruction; the control field lives in the
# high half of the SECOND one. Verified against main.asm's own hand-written codes:
#   LDC  [B------:R-:W0:-:S01] -> 0x000e220000000800   stall 1, wbar 0, rbar 7, wait 0
#   S2R  [B------:R-:W1:-:S01] -> 0x000e620000002100   stall 1, wbar 1
#   UMOV [B------:R-:W-:-:S01] -> 0x000fe20000000000   stall 1, wbar 7 (none)
# This is the only route: nvdisasm would print the codes directly but refuses any kernel
# containing BRXU, which is every kernel this project builds.
INSN = re.compile(r"/\*([0-9a-f]{4,})\*/\s+(.*?);\s*/\* (0x[0-9a-f]+) \*/")
WORD2 = re.compile(r"^\s*/\* (0x[0-9a-f]+) \*/\s*$")


def ctrl(w):
    return {"stall": (w >> 41) & 0xF, "wbar": (w >> 46) & 7,
            "rbar": (w >> 49) & 7, "wait": (w >> 52) & 0x3F}


def dst(t):
    t = re.sub(r"^@!?\w+\s+", "", t)
    m = re.match(r"[\w.]+\s+(R\d+|P\d)\s*,", t)
    return m.group(1) if m else None


def srcs(t):
    """Everything read: the guard predicate plus every operand after the destination."""
    g = re.match(r"^@!?(\w+)\s+", t)
    out = {g.group(1)} if g else set()
    t = re.sub(r"^@!?\w+\s+", "", t)
    parts = t.split(",", 1)
    if len(parts) > 1:
        out |= set(re.findall(r"\b[RP]\d+\b", parts[1]))
    return out


def check(path):
    sass = subprocess.run([CUDA + "/bin/cuobjdump", "-sass", path],
                          capture_output=True, text=True).stdout
    rows, pend = [], None
    for ln in sass.splitlines():
        i = INSN.search(ln)
        if i:
            pend = (i.group(1), i.group(2).strip())
            continue
        w = WORD2.match(ln)
        if w and pend:
            c = ctrl(int(w.group(1), 16))
            rows.append((c["stall"], c["wbar"] != 7, pend[0], pend[1]))
            pend = None

    # The kernel body ends at the last EXIT; everything after it is an appended FUNCTION
    # body, each of which ends with BRXU.U rather than EXIT.
    kend = max((i for i, r in enumerate(rows) if r[3].split()[0].lstrip("@!") == "EXIT"),
               default=len(rows) - 1)

    bad, note = [], []
    for k in range(len(rows) - 1):
        stall, haswrite, addr, t = rows[k]
        if haswrite:                     # variable latency: a write barrier covers it
            continue
        op = t.split()[0].split(".")[0].lstrip("@!")
        if op not in FIXED:
            continue
        d = dst(t)
        if not d or d == "RZ" or d == "PT":
            continue
        if d in srcs(rows[k + 1][3]) and stall < MIN_STALL:
            (bad if k < kend else note).append((addr, stall, d, t, rows[k + 1][3]))

    def show(rs):
        for addr, stall, d, a, b in rs:
            print("        /*%s*/ S%02d writes %s, next instruction reads it (need S%02d)"
                  % (addr, stall, d, MIN_STALL))
            print("            %s" % a)
            print("            %s" % b)

    tail = ""
    if note:
        tail = "   (%d under S%02d in the vendored FUNCTION bodies -- expected)" \
               % (len(note), MIN_STALL)
    if not bad:
        print("OK    %s   (%d instructions, kernel body %d)%s"
              % (path, len(rows), kend + 1, tail))
        return 0
    print("BAD   %s%s" % (path, tail))
    show(bad)
    return 1


sys.exit(max(check(p) for p in sys.argv[1:]) if len(sys.argv) > 1 else
         (print(__doc__.strip().splitlines()[2]) or 1))
