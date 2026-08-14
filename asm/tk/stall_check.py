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

The thresholds are MEASURED, not assumed -- the least ptxas itself ever leaves between a
producer and its first consumer, per opcode, over the 9,984 control-coded instructions of
asm/GpuCore_sm120.asm plus the two compiled kernels in rcasm_test/abtest:

    IMAD 3   IADD3 4   LOP3 4   SEL 4   SHF 4   LEA 4   PRMT 4   MOV 4   ISETP->P 5

so: 3 for IMAD, 5 for an ISETP writing a predicate, 4 for everything else.

An earlier version of this file used a single threshold of 5, taken from the same sweep but
counting only ADJACENT pairs. That number is an upper bound on the requirement rather than
the requirement -- it is the least ptxas puts on a producer whose very NEXT instruction
consumes it, not the least it leaves in total -- and enforcing it flagged eight sequences
in ptxas's own output, including `IMAD.WIDE.U32 R40, R3, 0x3d1, RZ` consumed three cycles
later. It also condemned a `MOV` here at four cycles that is exactly at the compiler's own
limit. A threshold that fails the compiler is not a threshold.

The distance to the consumer is the SUM of the stalls between them: an in-order issue means
the stall count is exactly how many cycles pass before the next instruction issues, so the
running total is the producer-to-consumer distance directly. The scan stops at a barrier
wait (the consumer is then parked on a load, which outlasts any fixed latency), at a
branch, and at a redefinition of the register.

An earlier version compared only ADJACENT pairs, on the argument that summing correctly
would mean modelling issue rates. It does not, and the gap was not academic: it missed the
`rem == 0` test in the prologue, where two interleaved LOP3 chains sat at S01 each, giving
every dependency in them TWO cycles against a measured requirement of four. That one is in
every variant of this kernel and is invisible to the A/B harness, because the failure mode
is a garbage R5 that would have to be exactly zero to change what the kernel does.

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

# Minimum cumulative producer-to-consumer distance, in cycles. MEASURED, per opcode, over
# ptxas's own output: the 9,984 control-coded instructions of asm/GpuCore_sm120.asm plus
# the two compiled kernels in rcasm_test/abtest. Anything stricter flags code the compiler
# ships, which is the fastest way to make a checker worthless.
MIN_CYCLES = {"IMAD": 3, "ISETP": 5}
MIN_DEFAULT = 4
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


# A register operand is often WIDER than the one name printed for it, and the width is not
# optional detail -- it is how `STL.128 [addr], R56` reads R56..R59 while naming only R56.
# Missing that is how an earlier version of this file passed a build whose second .128
# store read a register written four cycles earlier.
def span(base, n):
    k = int(base[1:])
    return {"R%d" % (k + i) for i in range(n)}


def dwidth(op):
    return 4 if ".128" in op else 2 if (".64" in op or ".WIDE" in op) else 1


def dst(t):
    """The destination and every register it covers, or an empty set."""
    t = re.sub(r"^@!?\w+\s+", "", t)
    m = re.match(r"([\w.]+)\s+(R\d+|P\d)\s*,", t)
    if not m:
        return set()                      # stores have no register destination
    r = m.group(2)
    return {r} if (r.startswith("P") or r == "RZ") else span(r, dwidth(m.group(1)))


def srcs(t):
    """Everything read: the guard predicate, every operand after the destination, and the
    registers those operands implicitly cover."""
    g = re.match(r"^@!?(\w+)\s+", t)
    out = {g.group(1)} if g else set()
    t = re.sub(r"^@!?\w+\s+", "", t)
    op = t.split()[0]
    # A store names its address first and its data last, so nothing is "after the
    # destination" to split on -- take the whole operand list.
    body = t if re.match(r"ST[LGS]", op) else (t.split(",", 1) + [""])[1]
    out |= set(re.findall(r"\b[RP]\d+\b", body))
    # `[R40.64]` addresses cover a pair; a store's data operand covers the access width.
    for m in re.finditer(r"\bR(\d+)\.64\b", body):
        out.add("R%d" % (int(m.group(1)) + 1))
    if re.match(r"ST[LGS]", op):
        m = re.search(r",\s*(R\d+)\s*$", t)
        if m:
            out |= span(m.group(1), dwidth(op))
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
            rows.append((c["stall"], c["wbar"] != 7, pend[0], pend[1], c["wait"]))
            pend = None

    # The kernel body ends at the last EXIT; everything after it is an appended FUNCTION
    # body, each of which ends with BRXU.U rather than EXIT.
    kend = max((i for i, r in enumerate(rows) if r[3].split()[0].lstrip("@!") == "EXIT"),
               default=len(rows) - 1)

    bad, note = [], []
    for k in range(len(rows) - 1):
        stall, haswrite, addr, t, _ = rows[k]
        if haswrite:                     # variable latency: a write barrier covers it
            continue
        op = t.split()[0].split(".")[0].lstrip("@!")
        if op not in FIXED:
            continue
        ds = dst(t) - {"RZ", "PT"}
        if not ds:
            continue
        # Walk forward to the first instruction that READS d, summing issue cycles. The
        # stall count is exactly how many cycles pass before the next instruction issues,
        # so the running total IS the producer-to-consumer distance; no issue-rate model is
        # needed. An earlier version only compared adjacent pairs and so missed the case
        # that motivated this: `MOV MulA7, MulR7` at S02, then an STL at S02, then a second
        # STL reading MulA7 -- four cycles where five are needed, one instruction out of
        # reach.
        need = MIN_CYCLES.get(op, MIN_DEFAULT)
        cyc = stall
        for j in range(k + 1, len(rows)):
            sj, _, _, tj, wj = rows[j]
            hit = ds & srcs(tj)
            if hit:
                if cyc < need:
                    (bad if k < kend else note).append(
                        (addr, cyc, need, sorted(hit)[0], t, tj))
                break
            # A barrier wait parks the consumer until a load lands, which is longer than
            # any fixed latency, so anything past it is covered. Branches end the straight
            # line this can reason about, and a redefinition ends the dependency.
            if wj or (ds & dst(tj)) or tj.split()[0].lstrip("@!") in ("BRA", "BRA.U",
                                                                     "BRXU", "BRXU.U",
                                                                     "EXIT"):
                break
            cyc += sj
            if cyc >= need:
                break

    def show(rs):
        for addr, cyc, need, d, a, b in rs:
            print("        /*%s*/ writes %s, read %d cycle(s) later (need %d)"
                  % (addr, d, cyc, need))
            print("            %s" % a)
            print("            %s" % b)

    tail = ""
    if note:
        tail = "   (%d under-stalled in the vendored FUNCTION bodies -- expected)" \
               % len(note)
    if not bad:
        print("OK    %s   (%d instructions, kernel body %d)%s"
              % (path, len(rows), kend + 1, tail))
        return 0
    print("BAD   %s%s" % (path, tail))
    show(bad)
    return 1


sys.exit(max(check(p) for p in sys.argv[1:]) if len(sys.argv) > 1 else
         (print(__doc__.strip().splitlines()[2]) or 1))
