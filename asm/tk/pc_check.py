#!/usr/bin/env python3
"""Check every control transfer in a cubin can reach a real instruction.

  ./pc_check.py TestKernel.cubin [more.cubin ...]

CUDA_ERROR_INVALID_PC is what a kernel returns when it branches somewhere that is not an
instruction. It is a launch-time death with no line number and nothing in the listing to
look at, because the instruction that causes it is CORRECT -- what is wrong is a register
it reads.

Two things are checked, and only the second one has ever fired:

  1. A direct branch's target is an instruction address. This has never been wrong; RCAsm
     resolves its own labels. It is here because it costs nothing.

  2. EVERY UNIFORM PAIR USED AS A BRXU RETURN ADDRESS HAS BOTH WORDS LOADED. This is the
     one. `BRXU.U UR8` computes next_PC + sign_extend(UR9:UR8), a 64-bit pair, and
     call_func patches only the LOW word -- the caller owns the high word, which is
     0xffffffff for the backward jump from an appended body back into the kernel. The
     kernel sets it once in the prologue and one line covers one pair.

     Stage 2b added a second return-address pair, uCallI, so InvMod256's temporaries would
     not collide with the return address the way Kernel02 avoids at its own two call sites.
     It got a low word from call_func and no high word from anywhere, and the kernel died at
     launch. The assembler was happy, cuobjdump disassembled it cleanly, and the alignment,
     stall and barrier checks all passed: every instruction was right and a register was
     uninitialised.

WHAT IS NOT CHECKED, and why: where a BRXU.U actually lands. The low word is written by
whichever call site jumped to the shared body, so the live value at the return depends on
the caller and a linear scan cannot know it. An earlier version of this did compute a target
from the last UMOV it had seen and reported "NOT AN INSTRUCTION" on the known-good stage-2a
cubin -- a checker that cries wolf on passing code gets ignored, so that half is gone.

Note the operand shapes: cuobjdump prints `BRXU URZ 0x460` with no comma and omits the
immediate entirely on `BRXU.U UR6`. A first cut of this matched neither and reported a clean
run on the cubin that was dying.

Exit 1 if anything is flagged, so it can gate a build.
"""
import re, subprocess, sys, os

CUDA = os.environ.get("CUDA", "/usr/local/cuda")
INSN = re.compile(r"/\*([0-9a-f]{4,})\*/\s+(.*?);\s*/\* (0x[0-9a-f]+) \*/")


def rows_of(path):
    sass = subprocess.run([CUDA + "/bin/cuobjdump", "-sass", path],
                          capture_output=True, text=True).stdout
    out = []
    for ln in sass.splitlines():
        m = INSN.search(ln)
        if m:
            out.append((int(m.group(1), 16), m.group(2).strip()))
    return out


def check(path):
    rows = rows_of(path)
    if not rows:
        print("BAD   %s   cuobjdump produced NO instructions -- the cubin does not "
              "disassemble" % path)
        return 1
    addrs = {a for a, _ in rows}
    loaded = set()          # uniform registers written by a UMOV anywhere in the image
    for _, t in rows:
        m = re.match(r"UMOV\s+UR(\d+)", re.sub(r"^@!?\w+\s+", "", t))
        if m:
            loaded.add(int(m.group(1)))
        # A .64 uniform load fills the pair.
        m = re.match(r"LDCU\.64\s+UR(\d+)", re.sub(r"^@!?\w+\s+", "", t))
        if m:
            loaded.update((int(m.group(1)), int(m.group(1)) + 1))

    bad = []
    for a, t in rows:
        body = re.sub(r"^@!?\w+\s+", "", t)

        m = re.match(r"BRXU\.U\s+UR(\d+)", body)
        if m:
            n = int(m.group(1))
            missing = [r for r in (n, n + 1) if r not in loaded]
            if missing:
                bad.append("        /*%04x*/ %s\n"
                           "            returns through the pair UR%d:UR%d and %s never "
                           "loaded\n"
                           "            call_func patches the LOW word only -- the caller "
                           "owes the high one,\n"
                           "            `UMOV <pair>1, 0xFFFFFFFF` in the prologue"
                           % (a, t, n + 1, n,
                              " and ".join("UR%d is" % r for r in missing)))
            continue

        m = re.match(r"BRXU\s+URZ\s+(0x[0-9a-f]+)", body)
        if m:
            tgt = a + 16 + int(m.group(1), 16)
            if tgt not in addrs:
                bad.append("        /*%04x*/ %s -> 0x%x is not an instruction" % (a, t, tgt))
            continue

        m = re.match(r"(BRA|BRX|JMP|CALL)[\w.]*\s+.*?(0x[0-9a-f]+)\s*$", body)
        if m and int(m.group(2), 16) not in addrs:
            bad.append("        /*%04x*/ %s -> 0x%x is not an instruction"
                       % (a, t, int(m.group(2), 16)))

    if not bad:
        print("OK    %s   (%d instructions)" % (path, len(rows)))
        return 0
    print("BAD   %s" % path)
    for m in bad:
        print(m)
    return 1


sys.exit(max(check(p) for p in sys.argv[1:]) if len(sys.argv) > 1 else
         (print(__doc__.strip().splitlines()[2]) or 1))
