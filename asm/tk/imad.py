#!/usr/bin/env python3
"""Which IMAD? A fitted cost of ~3.7x a bookkeeping instruction cannot be issue slots -- a
scheduler issues one instruction per cycle whatever the pipe. It CAN be pipe occupancy: a
64-bit-result multiply occupies the multiplier for several passes. IMAD.WIDE is the suspect."""
import re, sys
from collections import Counter
_args = sys.argv[2:]
sys.path.insert(0, sys.argv[1]); sys.argv = sys.argv[:1]
from stalls import parse, LOOPS, weights          # noqa: E402

for path in _args:
    ins = parse(path)
    w = weights(LOOPS[path.split('/')[-1]], len(ins))
    tot = sum(w)
    imad, other = Counter(), 0.0
    for i, (_, txt, _) in enumerate(ins):
        t = re.sub(r'^@!?U?P[T0-9]+\s+', '', txt)
        op = t.split()[0]
        if op.split('.')[0] == 'IMAD':
            mods = set(op.split('.')[1:])
            if 'MOV' in mods:      kind = 'IMAD.MOV  (a MOV in disguise, not a multiply)'
            elif 'WIDE' in mods:   kind = 'IMAD.WIDE (32x32 -> 64, multi-pass)'
            elif 'HI' in mods:     kind = 'IMAD.HI   (upper half)'
            elif not mods:         kind = 'IMAD      (plain 32x32 -> 32)'
            else:                  kind = 'IMAD.' + '.'.join(sorted(mods))
            imad[kind] += w[i]
        else:
            other += w[i]
    print(f"=== {path}   {tot:,.0f} dynamic instructions/batch")
    real = 0.0
    for k, c in sorted(imad.items(), key=lambda kv: -kv[1]):
        print(f"    {k:<46} {c:12,.0f}   {100*c/tot:5.1f}%")
        if 'disguise' not in k:
            real += c
    print(f"    {'-> REAL multiplies':<46} {real:12,.0f}   {100*real/tot:5.1f}%")
    print()
