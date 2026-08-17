#!/usr/bin/env python3
"""Check scoreboard-barrier hygiene in a cubin's SASS.

  ./barrier_check.py TestKernel.cubin [more.cubin ...]

Variable-latency instructions (LDG, LDC, LDL, STL, S2R, ...) name a write barrier in their
control code. The barrier is a COUNTER: every instruction naming it increments it, and a
wait blocks until it reaches zero. Two things go wrong with that, both silently, and
neither is visible to align_check.sh or stall_check.py because the instruction stream is
perfectly correct in each case:

  1. USE BEFORE WAIT -- a register produced by a barrier-carrying load is read without the
     barrier ever being waited. The read gets whatever was in the register before. Reported
     against the instruction that ISSUED THE LOAD rather than the one that reads it: the
     missing wait belongs to the caller, and a load of ours consumed inside a vendored body
     is still ours. Getting that backwards is how stage 2c-ii's unwaited y1 was dismissed as
     "8 in the vendored FUNCTION bodies -- expected".

  2. A MEMORY OP WHOSE SOURCE REGISTERS ARE REWRITTEN LATER, with no READ barrier. Such an
     instruction does not read its operands at issue: the LSU reads them later, and `R-`
     means nothing says when. Overwrite the register before that read happens and the
     instruction uses the NEW value. This is a WAR hazard, and the read barrier is the only
     thing that closes it -- `R3` on the op arms it, and a wait on 3 before the overwrite is
     what makes the read done.

     SOURCES, NOT DATA. This check read only a store's DATA operand until 2026-08-17, and
     the gap cost a wrong answer: the ADDRESS operand of a LOAD is read exactly as late.
     The prologue's twelve LDGs carried `R-` and the write-back rebuilds AddrX/AddrY/AddrS
     into the very registers they addressed through, so on the shortest rung -- `id`, 56
     instructions, three of them between the last Scal load and the LDC that overwrote its
     address -- the loads read a rewritten address and start_scalars came back wrong on 255
     of 256 threads. `local` is the same kernel plus five instructions in that gap and it
     passed; every larger rung has thousands there and passed. A hazard that only the
     shortest rung is short enough to expose is exactly the kind this file exists to catch
     statically, and this one walked past the checker because the checker looked at half of
     each instruction.

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

**CHECK 3 IS A NOTE, NOT A FAILURE, AND ITS THRESHOLD IS KNOWN TO BE WRONG.** It used to
read: "over the compiled kernels the most ptxas ever leaves outstanding on one barrier is
SIX; this kernel ran EIGHT and read stale registers, so the true limit is six or seven."
That was measured over the kernels that existed at the time. The stage-2d compiled kernels
put **TWELVE** LDGs on barrier 5 and are correct by construction -- they are ptxas's output.

So the count cannot be the mechanism. Both observations stand: 6 was really the corpus
maximum, and the stage-2a ladder really did read MulB4..MulB7 stale with eight outstanding.
What is refuted is the inference joining them. Whatever went wrong in stage 2a, it was not
"more than six on one barrier", and the fix that worked -- one group per barrier, drained
before reuse -- is good practice whether or not the count explains anything.

The number is kept at 6 as an advisory because a group that large is still worth looking at,
and the check still prints. It cannot fail a build: a gate that rejects the compiler's own
output is a gate that gets switched off, and this is the second threshold in this directory
to be falsified by simply looking at a larger corpus (see stall_check.py's note on the
two-cycle carry pairs). Measure the corpus you have; do not promote it to a limit.

What the count does NOT appear to be about is spacing: ptxas puts a wait as little as TWO
cycles after the arm it covers (`LDC R5, c[0x0][0x360]` followed immediately by an IMAD
that waits on it), so an insufficient arm-to-wait gap is not the mechanism here.

Rule: ONE GROUP PER BARRIER, AND DRAIN IT BEFORE REUSING IT.

Approximation worth knowing: this walks the instruction stream linearly and does not model
branches, so a wait that is reachable only on one path is credited on all of them. That is
the right bias for a build gate -- it under-reports rather than crying wolf -- but it means
a clean run is not a proof. Like stall_check.py, only the kernel body can fail; the
appended FUNCTION bodies are vendored and are reported as a note.

The approximation costs exactly one false positive over the whole compiled corpus, recorded
here so the next person does not have to rediscover that it is not a real defect:
ab_compiled_inv.cubin, `LDL.128 R20, [R2]` at 0x55c0 against `IADD3.X R2` at 0x57a0. A
`BSSY.RECONVERGENT` opens three instructions after the load and the rewrite is inside the
divergent region, so the two are not on one straight path. Four of the five compiled kernels
come out clean and all ten hand-written rungs do. THE CHECK IS NOT TUNED TO SWALLOW THIS ONE:
a threshold moved to make a known-good input pass is a threshold that stops meaning anything,
and this directory has already had two of those falsified by looking at a larger corpus.

Exit 1 if anything in the KERNEL BODY is flagged, so it can gate a build.
"""
import re, subprocess, sys, os

MAX_OUTSTANDING = 6
CUDA = os.environ.get("CUDA", "/usr/local/cuda")

INSN = re.compile(r"/\*([0-9a-f]{4,})\*/\s+(.*?);\s*/\* (0x[0-9a-f]+) \*/")
WORD2 = re.compile(r"^\s*/\* (0x[0-9a-f]+) \*/\s*$")


STORES = ("STL", "STG", "STS", "ST", "RED", "ATOM", "ATOMG", "ATOMS")
LOADS = ("LDL", "LDG", "LDS", "LDC", "LDCU", "LD", "LDGSTS")


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


def mem_sources(text):
    """Every register a variable-latency memory op reads LATE, as (prefix, number) pairs.

    For a store that is the DATA operand (the last register named, widened by the access
    size) and the ADDRESS; for a load it is the address alone. Both are the same hazard --
    `R-` says nothing about when the LSU reads the operand, so an overwrite before that read
    substitutes a different value: a different datum for a store, a different ADDRESS for a
    load, which is the half this function used to miss.

    An address inside `[...]` is a register PAIR when it carries `.64` (global and the
    descriptor form) and a single register otherwise (local and shared)."""
    t = re.sub(r"^@!?\w+\s+", "", text)
    op = opcode(t).split(".")[0]
    src = set()
    if op in STORES:
        nums = re.findall(r"\bR(\d+)\b", t)
        if nums and int(nums[-1]) != 255:
            k = int(nums[-1])
            src |= {("R", k + i) for i in range(width(t))}
    elif op not in LOADS:
        return set()
    for m in re.finditer(r"\[(U?R)(\d+)(\.64)?", t):
        src |= {(m.group(1), int(m.group(2)) + i) for i in range(2 if m.group(3) else 1)}
    return src


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
    bad, note, over = [], [], []

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

    # Pass 1 -- memory ops whose SOURCE registers are rewritten later (see item 2 in the
    # docstring). Only the kernel body is walked; the vendored FUNCTION bodies below the
    # last EXIT reuse the same numbers and would produce nothing but false positives.
    for k, (addr, text, wbar, rbar, wait) in enumerate(rows[:kend + 1]):
        data = mem_sources(text)
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
        # A WAIT ON THE WRITE BARRIER CLEARS IT TOO, and leaving that out is what made the
        # first version of this check fail ptxas's own output. If the data has come back, the
        # address was necessarily read: waiting the barrier the load armed for its DESTINATION
        # is a stronger guarantee than the read barrier, not a weaker one. Measured over the
        # compiled corpus -- 54 LDC, 12 LDG and 8 LDL rewrite a source with no read barrier
        # anywhere, and every one of them waits the write barrier first.
        if wbar != 7 and any(rows[i][4] & (1 << wbar) for i in window):
            continue
        if rbar == 7:
            flag(k, "        /*%s*/ reads %s late with NO read barrier, and /*%s*/ rewrites it\n"
                    "            %s\n"
                    "            rewritten by: %s" % (
                        addr, ",".join("%s%d" % r for r in sorted(data, key=lambda x: x[1])),
                        j_addr, text, j_text))
            continue
        if not any(rows[i][4] & (1 << rbar) for i in window):
            flag(k, "        /*%s*/ arms read barrier %d but nothing waits it before\n"
                    "            /*%s*/ rewrites the source register\n"
                    "            %s\n"
                    "            rewritten by: %s"
                    % (addr, rbar, j_addr, text, j_text))

    # Pass 2 -- use before wait, and barrier over-subscription.
    for k, (addr, text, wbar, rbar, wait) in enumerate(rows):
        for b in range(6):
            if wait & (1 << b):
                live[b] = []
                for key, (bb, _, _, _) in list(pending.items()):
                    if bb == b:
                        del pending[key]

        for pfx, num in reads(text):
            hit = pending.get((pfx, num))
            if hit:
                # Attributed to the PRODUCER, not the consumer. A load issued by the kernel
                # and consumed inside a vendored body is the kernel's bug -- the missing
                # wait is at the call site -- and reporting it as a note about someone
                # else's code is how it gets dismissed. It was: stage 2c-ii is the first
                # rung that reads y1 at all, its four prologue loads were never waited, and
                # this printed as "8 in the vendored FUNCTION bodies -- expected".
                flag(hit[3], "        /*%s*/ reads %s%d before barrier %d is waited\n"
                             "            produced by /*%s*/ %s\n"
                             "            %s" % (addr, pfx, num, hit[0], hit[1], hit[2], text))
                del pending[(pfx, num)]

        if wbar != 7:
            live[wbar].append(addr)
            if len(live[wbar]) > MAX_OUTSTANDING:
                # A NOTE, never a failure -- see the docstring. ptxas puts twelve on one
                # barrier in the stage-2d compiled kernels, so this count cannot be the
                # mechanism it was thought to be, and a gate that fails the compiler's own
                # output is a gate that gets switched off.
                over.append("        /*%s*/ makes %d operations outstanding on barrier %d\n"
                            "            armed at %s\n"
                            "            %s" % (addr, len(live[wbar]), wbar,
                                                " ".join(live[wbar]), text))
            d = dst(text)
            if d:
                pfx, base, n = d
                for j in range(n):
                    pending[(pfx, base + j)] = (wbar, addr, text, k)

    tail = "   (%d in the vendored FUNCTION bodies -- expected)" % len(note) if note else ""
    if over:
        tail += "   (%d over %d outstanding -- note only)" % (len(over), MAX_OUTSTANDING)
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
