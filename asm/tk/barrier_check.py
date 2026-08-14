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

  2. A STORE WHOSE DATA REGISTERS ARE REWRITTEN LATER, with no READ barrier. A store does
     not read its data at issue: the LSU reads it later, and `R-` means nothing says when.
     Overwrite the register before that read happens and the store writes the NEW value.
     This is a WAR hazard, and the read barrier is the only thing that closes it -- `R3` on
     the store arms it, and a wait on 3 before the overwrite is what makes the read done.

     This is what made the stage-2a ladder's subp[half-1] wrong AFTER the loop was fixed.
     Px was exact, because the accumulator never leaves registers -- but Py, which is the
     one value round-tripped through the frame, came back as subp[0].hi ++ subp[511].lo.
     subp[0] is the accumulator's LAST value, 511 iterations after that store issued: the
     high half of the store read its data at the end of the loop rather than at the top.
     The low half read on time. Nothing in the control code said either had to.

     THE RULE IS MEASURED. ptxas's own suffix-product loop (rcasm_test/abtest, compiled)
     puts a read barrier on every one of its four ladder STLs and waits it at the head of
     the next iteration; over both compiled kernels there is not one store whose source is
     rewritten later and which carries no read barrier. Ours had four.

  3. OVER-SUBSCRIPTION -- too many operations outstanding on one barrier at once. This is
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


STORES = ("STL", "STG", "STS", "ST", "RED", "ATOM", "ATOMG", "ATOMS")


def ctrl(w):
    # write barrier, read barrier, wait mask
    return (w >> 46) & 7, (w >> 49) & 7, (w >> 52) & 0x3F


def width(text):
    """How many consecutive registers the destination covers."""
    op = text.split()[0]
    if ".128" in op: return 4
    if ".64" in op or ".WIDE" in op: return 2
    return 1


def opcode(text):
    """The mnemonic, with any predicate guard removed. `@P0 BRA.U 0x3b0` -> `BRA.U`; a
    plain .split()[0] returns the GUARD there, which silently hid every guarded branch."""
    return re.sub(r"^@!?\w+\s+", "", text).split()[0]


def store_data(text):
    """A store's DATA operand -- the last register named -- widened by the access size."""
    t = re.sub(r"^@!?\w+\s+", "", text)
    if opcode(t).split(".")[0] not in STORES:
        return set()
    nums = re.findall(r"\bR(\d+)\b", t)
    if not nums or int(nums[-1]) == 255:
        return set()
    k = int(nums[-1])
    return {("R", k + i) for i in range(width(t))}


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
            wbar, rbar, wait = ctrl(int(w.group(1), 16))
            out.append((pend[0], pend[1], wbar, rbar, wait))
            pend = None
    return out


def defined(text):
    """Registers this instruction writes, as (prefix, number) pairs."""
    d = dst(text)
    if not d:
        return set()
    pfx, base, n = d
    return {(pfx, base + i) for i in range(n)}


def check(path):
    rows = rows_of(path)
    # No instructions means cuobjdump could not read the cubin. That is a failure, not a
    # clean run -- an undecodable instruction once slipped through both checkers reporting
    # "OK (0 instructions)".
    if not rows:
        print("BAD   %s   cuobjdump produced NO instructions -- the cubin does not "
              "disassemble" % path)
        return 1
    kend = max((i for i, r in enumerate(rows) if opcode(r[1]) == "EXIT"),
               default=len(rows) - 1)

    live = {b: [] for b in range(6)}     # barrier -> outstanding arming instructions
    pending = {}                         # (prefix, regnum) -> (barrier, addr, text)
    bad, note = [], []

    def flag(k, msg):
        (bad if k <= kend else note).append(msg)

    # Backward branches, so the loop-carried case is visible. Without this the check sees
    # only the store that sits ABOVE its overwrite in program order -- a loop whose stores
    # are all below the copy block would pass while being wrong on every iteration but the
    # first. BRXU is excluded: its operand is a return offset, not a label.
    at = {int(r[0], 16): i for i, r in enumerate(rows)}
    backedges = []
    for i, r in enumerate(rows[:kend + 1]):
        if not opcode(r[1]).startswith("BRA"):
            continue
        m = re.search(r"0x([0-9a-f]+)\s*$", r[1])
        if m and int(m.group(1), 16) < int(r[0], 16) and int(m.group(1), 16) in at:
            backedges.append((i, at[int(m.group(1), 16)]))

    # Pass 1 -- stores whose data registers are rewritten later (see item 2 in the
    # docstring). Only the kernel body is walked; the vendored FUNCTION bodies below the
    # last EXIT reuse the same numbers and would produce nothing but false positives.
    for k, (addr, text, wbar, rbar, wait) in enumerate(rows[:kend + 1]):
        data = store_data(text)
        if not data:
            continue
        window = list(range(k + 1, kend + 1))
        hit = next((j for j in window if defined(rows[j][1]) & data), None)
        if hit is None:
            # Nothing below it -- but the back edge may carry execution to something above.
            for bi, ti in backedges:
                if ti <= k <= bi:
                    w2 = list(range(k + 1, bi + 1)) + list(range(ti, k))
                    h2 = next((j for j in w2 if defined(rows[j][1]) & data), None)
                    if h2 is not None:
                        window, hit = w2, h2
                        break
        if hit is None:
            continue
        window = window[:window.index(hit) + 1]
        j_text, j_addr = rows[hit][1], rows[hit][0]
        if rbar == 7:
            flag(k, "        /*%s*/ stores %s with NO read barrier, and /*%s*/ rewrites it\n"
                    "            %s\n"
                    "            rewritten by: %s" % (
                        addr, ",".join("%s%d" % r for r in sorted(data, key=lambda x: x[1])),
                        j_addr, text, j_text))
            continue
        if not any(rows[i][4] & (1 << rbar) for i in window):
            flag(k, "        /*%s*/ arms read barrier %d but nothing waits it before\n"
                    "            /*%s*/ rewrites the data register\n"
                    "            %s\n"
                    "            rewritten by: %s"
                    % (addr, rbar, j_addr, text, j_text))

    # Pass 2 -- use before wait, and barrier over-subscription.
    for k, (addr, text, wbar, rbar, wait) in enumerate(rows):
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
