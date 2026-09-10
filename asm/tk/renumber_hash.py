#!/usr/bin/env python3
# Renumber the lifted getHash160_w2 body by a uniform +OFF on every R register, and remap
# the single uniform temp UR4 -> UR6. All ops are 32-bit ALU (no .64/.128, no memory), so a
# uniform shift needs no alignment care; verified bit-exact via the hashdump golden oracle.
import re, sys

OFF = 48
src = "hd_hash_inc.asm"
dst = "hd_hash_inc_rn.asm"

# Shift a standalone R<num> (not URn, not RZ) by OFF. Lookbehind rejects a preceding
# letter/digit/_ so the R of "UR4" and "PRMT" is never touched; RZ has no digit so it never matches.
r_re = re.compile(r'(?<![A-Za-z0-9_])R(\d+)\b')
ur_re = re.compile(r'\bUR4\b')

def shift(line):
    line = r_re.sub(lambda m: 'R' + str(int(m.group(1)) + OFF), line)
    line = ur_re.sub('UR6', line)
    return line

before, after = set(), set()
out = []
with open(src) as f:
    for line in f:
        for m in re.finditer(r'(?<![A-Za-z0-9_])R(\d+)\b', line):
            before.add(int(m.group(1)))
        nl = shift(line)
        for m in re.finditer(r'(?<![A-Za-z0-9_])R(\d+)\b', nl):
            after.add(int(m.group(1)))
        out.append(nl)

with open(dst, 'w', newline='\n') as f:
    f.writelines(out)

print("before R regs :", sorted(before))
print("after  R regs :", sorted(after))
print("max after     :", max(after), "(must be <=124)")
print("bijective     :", len(before) == len(after) and all(b + OFF in after for b in before))
# UR audit
urs = set()
with open(dst) as f:
    for line in f:
        for m in re.finditer(r'\bUR(\d+)\b', line):
            urs.add(int(m.group(1)))
print("after UR regs :", sorted(urs), "(expect just [6])")
print("instr lines   :", sum(1 for l in out if re.match(r'\s*\[', l)))
