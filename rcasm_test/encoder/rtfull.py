#!/usr/bin/env python3
"""Does the learned sm_120 repos assemble the REAL kernel to the REAL bytes?

"assemble() did not raise" is not "assemble() produced the right code" -- the
learning pass logged verification conflicts for BRA_II and RET_R_II, so the
only honest check is a byte compare of .text.TestKernel against the cubin the
cuasm was disassembled from.

The 24 `HFMA2 Rd, -RZ, RZ, hi, lo` (the one form with no encoder) are rewritten
to the equivalent `MOV Rd, imm` first. Those 24 slots are EXPECTED to differ;
every other differing byte is a real defect.
"""
import sys, os, re, shutil, collections
import env

from CuAsm import CuAsmParser
from CuAsm.CuAsmLogger import CuAsmLogger
env.configure()
try:
    CuAsmLogger.disable()
except Exception:
    pass

from elftools.elf.elffile import ELFFile

SRC = env.KERNEL_ASM
ORIG = env.CUBIN
ASM = os.path.join(env.WORK, "rt.cuasm")
OUT = os.path.join(env.WORK, "rt.cubin")

# ---- prepare the cuasm -------------------------------------------------
L = open(SRC).read().splitlines()
n_tk = 0
for i, ln in enumerate(L):
    if re.match(r"^\s*\.tkinfo\s*$", ln):
        L[i] = "//" + ln
        n_tk += 1

# The one form with no encoder. Every occurrence is ptxas's "load a small
# integer constant on the FP16 pipe" idiom: HFMA2 Rd, -RZ, RZ, hi, lo puts the
# packed half2 (hi,lo) into Rd. The values seen are all subnormal halves, so
# bits = value * 2**24, and the equivalent is a plain MOV of the packed word.
HFMA2 = re.compile(r"^(?P<pre>.*/\*(?P<addr>[0-9a-f]+)\*/\s+)HFMA2\s+(?P<rd>R\d+),"
                   r"\s*-RZ,\s*RZ,\s*(?P<hi>[-\w.+e]+),\s*(?P<lo>[-\w.+e]+)\s*;(?P<post>.*)$")

def half_bits(t):
    v = float(t)
    b = int(round(v * (1 << 24)))          # subnormal halves only
    assert 0 <= b < 0x400 and abs(v - b * 2.0 ** -24) < 1e-20, "not a subnormal half: %s" % t
    return b

subbed = []
consts = collections.Counter()
for i, ln in enumerate(L):
    m = HFMA2.match(ln)
    if m:
        imm = (half_bits(m.group("hi")) << 16) | half_bits(m.group("lo"))
        consts[imm] += 1
        L[i] = "%sMOV %s, %s ;%s" % (m.group("pre"), m.group("rd"), hex(imm), m.group("post"))
        subbed.append(int(m.group("addr"), 16))
open(ASM, "w").write("\n".join(L) + "\n")
print("neutralized .tkinfo x%d;  HFMA2 const-load -> MOV imm: %d sites  %s"
      % (n_tk, len(subbed),
         ", ".join("%s x%d" % (hex(k), v) for k, v in sorted(consts.items()))))

# ---- assemble ----------------------------------------------------------
cap = CuAsmParser()
cap.set_sm(120)
cap.parse(ASM)
cap.saveAsCubin(OUT)
print("assembled -> %s (%d bytes; original %d)"
      % (OUT, os.path.getsize(OUT), os.path.getsize(ORIG)))

# ---- byte compare .text.TestKernel -------------------------------------
def text(p):
    with open(p, "rb") as f:
        e = ELFFile(f)
        s = e.get_section_by_name(".text.TestKernel")
        return s.data()

a, b = text(ORIG), text(OUT)
print("\n.text.TestKernel: original %d B, rebuilt %d B" % (len(a), len(b)))
if len(a) != len(b):
    print("!! SIZE MISMATCH -- stopping")
    sys.exit(1)

subset = set(subbed)
bad_ins = collections.OrderedDict()      # addr -> list of differing byte indices
for off in range(0, len(a), 16):
    d = [j for j in range(16) if a[off + j] != b[off + j]]
    if d:
        bad_ins[off] = d

expected = [o for o in bad_ins if o in subset]
unexpected = [o for o in bad_ins if o not in subset]
missing = [o for o in subbed if o not in bad_ins]

print("differing 16-byte instruction slots: %d of %d" % (len(bad_ins), len(a) // 16))
print("  of which are the %d HFMA2->MOV substitutions : %d" % (len(subbed), len(expected)))
print("  substitutions that came out byte-IDENTICAL   : %d" % len(missing))
print("  UNEXPLAINED differences                      : %d" % len(unexpected))

region = env.region

print("\n%-22s %8s %10s %10s" % ("region", "instrs", "HFMA2 sub", "UNEXPLAINED"))
print("-" * 56)
rt_ = collections.Counter(); ru_ = collections.Counter(); rs_ = collections.Counter()
for off in range(0, len(a), 16):
    rt_[region(off)] += 1
for off in unexpected:
    ru_[region(off)] += 1
for off in expected:
    rs_[region(off)] += 1
for r_ in ("getHash160_33", "getHash160_w2", "rest of TestKernel"):
    print("%-22s %8d %10d %10d" % (r_, rt_[r_], rs_[r_], ru_[r_]))

hashbad = [o for o in unexpected if region(o) != "rest of TestKernel"]
print("\n=== unexplained differences INSIDE the two hash bodies: %d ===" % len(hashbad))
src = open(ASM).read().splitlines()
for o in hashbad:
    print("  /*%05x*/ %s   bytes %s" % (o, region(o), bad_ins[o]))
    print("      orig: %s" % " ".join("%02x" % x for x in a[o:o + 16]))
    print("      rebd: %s" % " ".join("%02x" % x for x in b[o:o + 16]))
    pat = re.compile(r"/\*0*%x\*/" % o)
    for ln in src:
        if pat.search(ln):
            print("      asm : %s" % ln.strip())
            break

if unexpected:
    print("\n=== unexplained differing instructions ===")
    bybyte = collections.Counter()
    for off in unexpected[:40]:
        print("  /*%05x*/  bytes %s" % (off, bad_ins[off]))
        for j in bad_ins[off]:
            bybyte[j] += 1
    if len(unexpected) > 40:
        print("  ... and %d more" % (len(unexpected) - 40))
    print("\n  differing byte positions within the instruction: %s"
          % dict(sorted(bybyte.items())))
else:
    print("\nEVERY instruction outside the 24 substitutions is byte-identical.")
