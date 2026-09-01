#!/usr/bin/env python3
"""Dynamic instruction count per scanned key, both kernels.

Method: every instruction is weighted by the product of the trip counts of the loops
containing it, from the back-edge intervals reported by loops.py. Trip counts are exact where
the algorithm fixes them (ladder and walk both run half-1 = 511 times; the batch loop is
normalised out) and simulated where the data fixes them (inv_mod's divstep nest -- invtrips.py,
validated on 3000 operands against both |modp| == 1 and pow(a, -1, P)).

Predicated-off instructions still ISSUE, so every instruction in an interval counts once per
trip. That is the right convention here: the question is what competes for issue slots.

B = 1024 keys per batch, half = 512. The walk handles two points per trip (+i and -i), so the
511 trips plus the centre and the minus-only tail give exactly 1024.
"""

KEYS_PER_BATCH = 1024
LADDER_TRIPS = WALK_TRIPS = 511          # half - 1

# from invtrips.py, mean over 3000 uniform random operands
INV_PRE, INV_OUTER, INV_INNER = 9.03, 17.10, 150.86
INV_NORM_NEG, INV_NORM_POS = 0.50, 0.00

# (label, first, last, trips, parent-or-None) -- indices from loops.py, inclusive
KERNELS = {
    'A  compiled NO_HASH': dict(static=5520, body=(54, 5461), loops=[
        ('ladder',      112,  360, LADDER_TRIPS, None),
        ('walk',       1511, 3463, WALK_TRIPS,   None),
        ('inv pre',     616,  650, INV_PRE,      None),
        ('inv outer',   909, 1399, INV_OUTER,    None),
        ('inv inner',   927,  961, INV_INNER,    'inv outer'),
        ('inv r+=P',   1472, 1482, INV_NORM_NEG, None),
        ('inv r-=P',   1488, 1498, INV_NORM_POS, None),
    ], extra=[]),
    'B  hand-written': dict(static=3248, body=(33, 2638), loops=[
        ('ladder',       65,  211, LADDER_TRIPS, None),
        ('walk',        369, 1488, WALK_TRIPS,   None),
    ], extra=[
        # InvMod256 is a FUNCTION body after the final EXIT, reached once per batch by BRXU
        ('InvMod256 body', 2660, 3247, 1.0, [
            ('inv pre',    2692, 2713, INV_PRE,      None),
            ('inv outer',  2888, 3186, INV_OUTER,    None),
            ('inv inner',  2907, 2928, INV_INNER,    'inv outer'),
            ('inv r+=P',   3222, 3233, INV_NORM_NEG, None),
            ('inv r-=P',   3234, 3245, INV_NORM_POS, None),
        ]),
    ]),
    'w512  = A + identity mask': dict(static=5496, body=(51, 5445), loops=[
        ('ladder',      106,  354, LADDER_TRIPS, None),
        ('walk',       1505, 3452, WALK_TRIPS,   None),
        ('inv pre',     610,  644, INV_PRE,      None),
        ('inv outer',   903, 1393, INV_OUTER,    None),
        ('inv inner',   921,  955, INV_INNER,    'inv outer'),
        ('inv r+=P',   1466, 1476, INV_NORM_NEG, None),
        ('inv r-=P',   1482, 1492, INV_NORM_POS, None),
    ], extra=[]),
    'ml2   = wrap 32 + 1 pass': dict(static=5768, body=(51, 5716), loops=[
        ('ladder',      101,  350, LADDER_TRIPS, None),
        ('EXTRA PASS',  373,  617, LADDER_TRIPS, None),
        ('walk',       1776, 3723, WALK_TRIPS,   None),
        ('inv pre',     871,  905, INV_PRE,      None),
        ('inv outer',  1174, 1664, INV_OUTER,    None),
        ('inv inner',  1192, 1226, INV_INNER,    'inv outer'),
        ('inv r+=P',   1737, 1747, INV_NORM_NEG, None),
        ('inv r-=P',   1753, 1763, INV_NORM_POS, None),
    ], extra=[]),
}


def account(spec):
    """Return (per-batch total, [(label, instrs, trips, dynamic)])."""
    rows, covered = [], 0
    def do(loops):
        nonlocal covered
        out = []
        for label, lo, hi, trips, parent in loops:
            size = hi - lo + 1
            nested = sum(h - l + 1 for lb, l, h, _, p in loops if p == label)
            own = size - nested
            if parent is None:
                covered += size
            out.append((label, own, trips, own * trips))
        return out

    lo, hi = spec['body']
    rows += do(spec['loops'])
    straight = (hi - lo + 1) - covered
    rows.insert(0, ('batch body, straight-line', straight, 1.0, straight))

    for label, elo, ehi, etrips, sub in spec['extra']:
        covered = 0
        sub_rows = do(sub)
        s = (ehi - elo + 1) - covered
        rows.append((f'{label}, straight-line', s, etrips, s * etrips))
        rows += [(f'  {l}', o, t, d) for l, o, t, d in sub_rows]

    return sum(d for _, _, _, d in rows), rows


print(f"{'':<28} {'instrs':>7} {'trips':>8} {'dynamic/batch':>14}")
totals = {}
for name, spec in KERNELS.items():
    total, rows = account(spec)
    totals[name] = total
    print(f"\n--- {name}   ({spec['static']} static)")
    for label, instrs, trips, dyn in rows:
        if dyn == 0 and instrs == 0:
            continue
        print(f"  {label:<26} {instrs:7d} {trips:8.2f} {dyn:14,.0f}")
    print(f"  {'':<26} {'':>7} {'TOTAL':>8} {total:14,.0f}"
          f"   =  {total / KEYS_PER_BATCH:.1f} instructions/key")

print()
a = totals['A  compiled NO_HASH'] / KEYS_PER_BATCH
b = totals['B  hand-written'] / KEYS_PER_BATCH
w = totals['w512  = A + identity mask'] / KEYS_PER_BATCH
m = totals['ml2   = wrap 32 + 1 pass'] / KEYS_PER_BATCH
print(f"A = {a:.1f} instr/key      B = {b:.1f} instr/key")
print(f"  B issues {100 * (1 - b / a):.1f}% fewer instructions than A; "
      f"B measured {100 * (1 - 22.8921 / 29.4246):.1f}% faster "
      f"-> {100 * (1 - 22.8921 / 29.4246) / (100 * (1 - b / a)) * 100:.0f}% conversion")
print()
print(f"w512 = {w:.1f} instr/key   ml2 = {m:.1f} instr/key")
print(f"  one extra pass = +{100 * (m / w - 1):.1f}% dynamic instructions")
print(f"  measured cost  = +10.1% wall clock (median, ml2 vs w32)")
print(f"  -> marginal weight {10.1 / (100 * (m / w - 1)) * 100:.0f}%")
