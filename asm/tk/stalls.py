#!/usr/bin/env python3
"""Trip-count-weighted mean stall for both kernels, decoded from the cubin control words.

On Volta+ each 128-bit instruction carries its own scheduling control. The stall count -- how
many cycles the warp waits before issuing its NEXT instruction -- sits at bits 105..108, i.e.
bits 41..44 of the high 64-bit word that cuobjdump prints on the continuation line.

WHY THIS MATTERS: a warp issues one instruction every `stall` cycles, so W warps per scheduler
offer W/mean_stall instructions per cycle against a capacity of 1. Above 1 the scheduler is
oversubscribed and instruction COUNT binds; below 1 it starves and LATENCY binds. Both kernels
run 2 blocks/SM x 256 threads = 16 warps/SM = 4 warps/scheduler, so W is the same for both and
the mean stall is the whole of the difference.

The decoder is validated, not assumed: the hand-written kernel's stalls are written by hand in
asm/tk/main.asm and asm/tk/inc.asm, where S01 dominates, so a correct decode must reproduce that
spike and a wrong bit range will not.
"""
import re
import sys
from collections import Counter

INS = re.compile(r'^\s+/\*([0-9a-f]+)\*/\s+(.*?);\s*/\* (0x[0-9a-f]+) \*/')
CTRL = re.compile(r'^\s+/\* (0x[0-9a-f]+) \*/')


def parse(path):
    """-> [(addr, text, hi_word)]"""
    out, pending = [], None
    for line in open(path):
        m = INS.match(line)
        if m:
            pending = (int(m.group(1), 16), m.group(2).strip())
            continue
        m = CTRL.match(line)
        if m and pending:
            out.append((pending[0], pending[1], int(m.group(1), 16)))
            pending = None
    return out


def stall(hi):
    return (hi >> 41) & 0xF


LOOPS = {
    'A_nohash.sass': dict(body=(54, 5461), loops=[
        (112, 360, 511.0, None), (1511, 3463, 511.0, None),
        (616, 650, 9.03, None), (909, 1399, 17.10, None),
        (927, 961, 8.82, 'inner'), (1472, 1482, 0.50, None), (1488, 1498, 0.00, None)]),
    'B_manual.sass': dict(body=(33, 2638), loops=[
        (65, 211, 511.0, None), (369, 1488, 511.0, None)],
        extra=(2660, 3247, 1.0, [
            (2692, 2713, 9.03, None), (2888, 3186, 17.10, None),
            (2907, 2928, 8.82, 'inner'), (3222, 3233, 0.50, None),
            (3234, 3245, 0.00, None)])),
}


def weights(spec, n):
    """weight[i] = product of trip counts of the loops containing instruction i"""
    w = [0.0] * n
    lo, hi = spec['body']
    for i in range(lo, hi + 1):
        w[i] = 1.0
    for a, b, t, tag in spec['loops']:
        for i in range(a, b + 1):
            w[i] *= t
    if 'extra' in spec:
        a, b, t, subs = spec['extra']
        for i in range(a, b + 1):
            w[i] = t
        for sa, sb, st, tag in subs:
            for i in range(sa, sb + 1):
                w[i] *= st
    return w


for path in sys.argv[1:]:
    ins = parse(path)
    print(f"=== {path}   {len(ins)} instructions with control words")
    hist = Counter(stall(h) for _, _, h in ins)
    tot = sum(hist.values())
    print("    static stall histogram:  " + "  ".join(
        f"S{k:02d}:{v} ({100*v/tot:.0f}%)" for k, v in sorted(hist.items())[:8]))

    spec = LOOPS.get(path.split('/')[-1])
    if not spec:
        continue
    w = weights(spec, len(ins))
    num = sum(w[i] * stall(ins[i][2]) for i in range(len(ins)))
    den = sum(w)
    print(f"    dynamic instructions/batch : {den:,.0f}")
    print(f"    TRIP-WEIGHTED MEAN STALL   : {num/den:.3f} cycles")
    print(f"    4 warps/scheduler offer    : {4/(num/den):.3f} instr/cycle "
          f"against a capacity of 1  ->  "
          f"{'ISSUE-bound' if 4/(num/den) > 1 else 'LATENCY-bound (scheduler starves)'}")
    print()

# --- the local model -----------------------------------------------------------------
# The aggregate mean above compares one number against capacity, which assumes the surplus in
# a low-stall phase can pay for the deficit in a high-stall one. It cannot: the scheduler is
# work-conserving but not clairvoyant.
#
# Per instruction, 4 warps each take one issue slot (4 cycles) and each then waits `stall`
# cycles from its own issue. If stall <= 4 the slots fill and nothing idles; if stall > 4 the
# scheduler idles stall-4. So one warp's stream costs sum(max(4, stall)) cycles per scheduler,
# and the ratio of that sum is the prediction to hold against the measured 0.778.
print("=== the local model: cycles = sum over instructions of max(4 warps, stall) ===")
res = {}
for path in sys.argv[1:]:
    ins = parse(path)
    spec = LOOPS.get(path.split('/')[-1])
    if not spec:
        continue
    w = weights(spec, len(ins))
    n = sum(w)
    ge4 = sum(w[i] for i in range(len(ins)) if stall(ins[i][2]) > 4)
    cyc = sum(w[i] * max(4, stall(ins[i][2])) for i in range(len(ins)))
    res[path] = (n, cyc, ge4)
    print(f"  {path:<16} instrs/batch {n:>10,.0f}   cycles {cyc:>12,.0f}"
          f"   stall>4: {100*ge4/n:5.1f}% of dynamic instructions")
if len(res) == 2:
    (na, ca, _), (nb, cb, _) = res.values()
    print()
    print(f"  pure instruction count predicts   B/A = {nb/na:.3f}")
    print(f"  the local stall model predicts    B/A = {cb/ca:.3f}")
    print(f"  MEASURED                          B/A = 0.778")
