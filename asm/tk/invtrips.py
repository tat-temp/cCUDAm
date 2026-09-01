#!/usr/bin/env python3
"""Trip counts for inv_mod (Math.cuh:538), the one data-dependent loop nest in either kernel.

It is a 30-bit-batched divstep (Pornin-style binary GCD): an inner `while (cnt > 0)` builds a
2x2 transition matrix over 30 divsteps, the outer `while (1)` applies it to the 288-bit val/modp
pair and shifts right 30. Trip counts depend on the operand, so they are simulated rather than
assumed.

VALIDATED ON TWO PROPERTIES THE TRIP COUNT CANNOT FAKE, per the vsim lesson in DEVPLAN --
a model calibrated against the quantity under suspicion proves whatever it was built to prove:
  1. the recursion must terminate with |modp| == 1   (gcd(val, P) == 1, P prime)
  2. r must be the true modular inverse             (checked against Python's pow(a, -1, P))
Either one breaks immediately if the matrix/shift logic is wrong.

Both kernels run the SAME algorithm on the SAME inputs -- the SASS loop nests are structurally
identical (pre-loop, outer with one nested inner, two normalisation loops) and differ only in
body size -- so one trip-count model serves both.
"""
import random
import statistics
import sys

P = (1 << 256) - (1 << 32) - 977
M288 = 1 << 288
P_INV30 = 0xD2253531


def s32(x):
    x &= 0xFFFFFFFF
    return x - (1 << 32) if x & 0x80000000 else x


def s288(x):
    x &= M288 - 1
    return x - M288 if x & (1 << 287) else x


def ffs(x):
    """__ffs: 1 + index of lowest set bit, 0 if zero."""
    x &= 0xFFFFFFFF
    return (x & -x).bit_length() if x else 0


def word(v, i):
    """word i of the 288-bit two's-complement representation of v"""
    return ((v & (M288 - 1)) >> (32 * i)) & 0xFFFFFFFF


def inv_mod(a):
    """Faithful port of Math.cuh inv_mod. Returns (r, stats)."""
    st = dict(pre_inner=0, outer=0, inner=0, norm_neg=0, norm_pos=0)

    modp, val = P, a
    r, acc = 0, 1                       # `r` and `a` in the C source
    m0, m1, m2, m3 = 1, 0, 0, 1
    kbnt = -1
    _val, _modp = s32(a & 0xFFFFFFFF), s32(P & 0xFFFFFFFF)

    def divstep_round(m0, m1, m2, m3, kbnt, _val, _modp, counter):
        index = ffs(_val & 0xFFFFFFFF | 0x40000000) - 1
        m0 = s32(m0 << index); m1 = s32(m1 << index)
        kbnt -= index; _val = s32(_val) >> index
        cnt = 30 - index
        while cnt > 0:
            st[counter] += 1
            if kbnt < 0:
                kbnt = -kbnt
                _modp, _val = _val, s32(-_modp)
                m0, m2 = m2, s32(-m0)
                m1, m3 = m3, s32(-m1)
            mx = 31 - kbnt if kbnt + 1 < cnt else 32 - cnt
            mul = s32(-_modp * _val) & 7
            mul &= (0xFFFFFFFF >> mx) if mx < 32 else 0xFFFFFFFF
            _val = s32(_val + _modp * mul)
            m2 = s32(m2 + m0 * mul)
            m3 = s32(m3 + m1 * mul)
            index = ffs((_val & 0xFFFFFFFF) | (1 << cnt)) - 1
            m0 = s32(m0 << index); m1 = s32(m1 << index)
            kbnt -= index; _val = s32(_val) >> index
            cnt -= index
        return m0, m1, m2, m3, kbnt, _val, _modp

    m0, m1, m2, m3, kbnt, _val, _modp = divstep_round(
        m0, m1, m2, m3, kbnt, _val, _modp, 'pre_inner')

    new_modp = s288(s288(modp * m0) + s288(val * m1)) >> 30
    new_val = s288(s288(modp * m2) + s288(val * m3)) >> 30
    modp, val = new_modp, new_val
    t1, t3 = s288(m1), s288(m3)
    r = s288(P * ((word(t1, 0) * P_INV30) & 0x3FFFFFFF) + t1) >> 30
    acc = s288(P * ((word(t3, 0) * P_INV30) & 0x3FFFFFFF) + t3) >> 30

    while True:
        st['outer'] += 1
        m0, m1, m2, m3 = 1, 0, 0, 1
        _val, _modp = s32(word(val, 0)), s32(word(modp, 0))
        m0, m1, m2, m3, kbnt, _val, _modp = divstep_round(
            m0, m1, m2, m3, kbnt, _val, _modp, 'inner')

        new_modp = s288(s288(modp * m0) + s288(val * m1)) >> 30
        new_val = s288(s288(modp * m2) + s288(val * m3)) >> 30
        t0, t1 = s288(r * m0), s288(acc * m1)
        modp, val = new_modp, new_val

        if (val & ((1 << 256) - 1)) == 0:
            break

        t2, t3 = s288(r * m2), s288(acc * m3)
        r = s288(P * (((word(t0, 0) + word(t1, 0)) * P_INV30) & 0x3FFFFFFF)
                 + t0 + t1) >> 30
        acc = s288(P * (((word(t2, 0) + word(t3, 0)) * P_INV30) & 0x3FFFFFFF)
                   + t2 + t3) >> 30

    r = s288(P * (((word(t0, 0) + word(t1, 0)) * P_INV30) & 0x3FFFFFFF)
             + t0 + t1) >> 30
    if s32(word(modp, 8)) < 0:
        r = s288(-r)
    while s32(word(r, 8)) < 0:
        r = s288(r + P); st['norm_neg'] += 1
    while s32(word(r, 8)) > 0:
        r = s288(r - P); st['norm_pos'] += 1
    return r, modp, st


def main(n=3000):
    assert (P * P_INV30) & 0x3FFFFFFF == 0x3FFFFFFF, "P_INV30 is not -P^-1 mod 2^30"
    rnd = random.Random(20260827)
    agg = dict(pre_inner=[], outer=[], inner=[], norm_neg=[], norm_pos=[])
    bad_gcd = bad_inv = 0
    for _ in range(n):
        a = rnd.randrange(1, P)
        r, modp, st = inv_mod(a)
        if abs(modp) != 1:
            bad_gcd += 1
        if r % P != pow(a, -1, P):
            bad_inv += 1
        for k in agg:
            agg[k].append(st[k])

    print(f"validation over {n} uniform random operands in [1, P):")
    print(f"  |modp| == 1 at termination : {n - bad_gcd}/{n}"
          f"{'   <<< FAIL' if bad_gcd else '   OK'}")
    print(f"  r == a^-1 mod P            : {n - bad_inv}/{n}"
          f"{'   <<< FAIL' if bad_inv else '   OK'}")
    if bad_gcd or bad_inv:
        print("  model is not faithful -- trip counts below are meaningless")
        return 1
    print()
    print(f"  {'loop':<12} {'mean':>8} {'min':>6} {'max':>6}  SASS body (A / B)")
    rows = [('pre_inner', 'pre-loop', '35 / 22'),
            ('outer', 'outer while', '491 / 299'),
            ('inner', 'inner total', '35 / 22'),
            ('norm_neg', 'r += P', '11 / 12'),
            ('norm_pos', 'r -= P', '11 / 12')]
    for key, label, body in rows:
        v = agg[key]
        print(f"  {label:<12} {statistics.mean(v):8.2f} {min(v):6d} {max(v):6d}  {body}")
    print()
    print(f"  inner trips per outer round: "
          f"{statistics.mean(agg['inner']) / statistics.mean(agg['outer']):.2f}")
    return 0


if __name__ == '__main__':
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 3000))
