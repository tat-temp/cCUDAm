#!/usr/bin/env python3
"""Trip-weighted OPCODE MIX. Instruction count is not a resource; issue slots on a particular
pipe are. Two kernels computing the same thing in different instruction counts can still put
the same load on one pipe -- and if that pipe is the limit, the count advantage is not real."""
import re, sys
from collections import Counter
_args = sys.argv[2:]
sys.path.insert(0, sys.argv[1])
sys.argv = sys.argv[:1]          # stalls.py runs its report at import; silence it
from stalls import parse, LOOPS, weights          # noqa: E402

for path in _args:
    ins = parse(path)
    spec = LOOPS[path.split('/')[-1]]
    w = weights(spec, len(ins))
    mix = Counter()
    for i, (_, txt, _) in enumerate(ins):
        op = re.sub(r'^@!?U?P[T0-9]+\s+', '', txt).split()[0].split('.')[0]
        mix[op] += w[i]
    tot = sum(w)
    print(f"=== {path}   {tot:,.0f} dynamic instructions/batch")
    for op, c in mix.most_common(9):
        print(f"    {op:<10} {c:12,.0f}  {100*c/tot:5.1f}%")
    print()
