#!/usr/bin/env python3
"""Simulate the four subtract bodies and check the UR variants against the originals.

A GPU is the only place this kernel can finally be proved, but the one thing the rewrite
actually changes -- which adder operand slot the constant table sits in -- can be settled
here. The bodies are read out of inc.asm / inc_ur.asm and interpreted, not transcribed.

IADD3.X model:  sum = a + b + c + pin0 + pin1;  Ro = sum mod 2^32;
                carry = sum >> 32 (0, 1 or 2);  pout0 = carry >= 1;  pout1 = carry == 2.

The model is not assumed. It is validated first against the COMMITTED bodies, which are
known-correct on hardware: if it were wrong, SubMod256 would not come out as (a-b) mod P
and SubMod256_3 would not come out as (a-b-c) mod P over random inputs. Only then are the
variants run through the same interpreter and compared limb for limb.
"""
import io
import os
import random
import re
import sys

P = (1 << 256) - (1 << 32) - 977
M32 = 0xFFFFFFFF
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = UR_SRC = HERE


def body(path, header):
    text = io.open(path, newline="").read()
    lines = text.split(header)[1].split("\r\n}")[0].split("\r\n")
    while lines and not lines[0].lstrip().startswith("{"):
        lines.pop(0)
    out = []
    for l in lines[1:]:
        l = l.split("//")[0].rstrip()
        if "]" in l:
            out.append(l.split("]", 1)[1].strip())
    return [l for l in out if l]


class Machine:
    """Just enough of the ISA for these four bodies: IADD3.X, MOV, SEL."""

    def __init__(self, arrays):
        self.v = dict(arrays)          # ("Name", index) -> 32-bit value
        self.p = {"PT": True}

    def rd(self, tok):
        neg = tok.startswith("~")
        t = tok[1:] if neg else tok
        if t in ("RZ", "URZ"):
            val = 0
        elif t.startswith("0x") or t.isdigit():
            val = int(t, 0) & M32
        else:
            m = re.match(r"([A-Za-z_]+)(\d+)$", t)
            val = self.v.get((m.group(1), int(m.group(2))), 0)
        return (~val) & M32 if neg else val

    def pred(self, tok):
        neg = tok.startswith("!")
        t = tok[1:] if neg else tok
        val = self.p.get(t, False)
        return (not val) if neg else val

    def wr(self, tok, val):
        if tok in ("RZ", "URZ"):
            return
        m = re.match(r"([A-Za-z_]+)(\d+)$", tok)
        self.v[(m.group(1), int(m.group(2)))] = val & M32

    def wp(self, tok, val):
        if tok not in ("PT", "!PT"):
            self.p[tok] = bool(val)

    def run(self, lines):
        for line in lines:
            guard = True
            if line.startswith("@"):
                g, line = line.split(None, 1)
                guard = self.pred(g[1:])
            op, rest = line.split(None, 1)
            a = [x.strip() for x in rest.split(",")]
            if op.startswith("IADD3"):
                dst, pd0, pd1, s0, s1, s2, pi0, pi1 = a
                if not guard:
                    continue
                total = (self.rd(s0) + self.rd(s1) + self.rd(s2)
                         + int(self.pred(pi0)) + int(self.pred(pi1)))
                self.wr(dst, total)
                carry = total >> 32
                self.wp(pd0, carry >= 1)
                self.wp(pd1, carry == 2)
            elif op == "MOV":
                if guard:
                    self.wr(a[0], self.rd(a[1]))
            elif op == "SEL":
                if guard:
                    self.wr(a[0], self.rd(a[1]) if self.pred(a[3]) else self.rd(a[2]))
            else:
                sys.exit("unmodelled instruction: " + line)


def limbs(x):
    return [(x >> (32 * i)) & M32 for i in range(8)]


def unlimbs(v, name):
    return sum(v.get((name, i), 0) << (32 * i) for i in range(8))


def load(name, x, into):
    for i, w in enumerate(limbs(x)):
        into[(name, i)] = w


def run_case(lines, inputs):
    st = {}
    for name, val in inputs.items():
        load(name, val, st)
    m = Machine(st)
    m.run(lines)
    return unlimbs(m.v, "Ro")


def main():
    sub_old = body(SRC + "/inc.asm", "FUNCTION SubMod256()")
    sub3_old = body(SRC + "/inc.asm", "FUNCTION SubMod256_3()")
    sub_new = body(UR_SRC + "/inc_ur.asm", "FUNCTION SubMod256_UB()")
    sub3_new = body(UR_SRC + "/inc_ur.asm", "FUNCTION SubMod256_3_UB()")
    print("bodies: %d / %d instructions (2-way), %d / %d (3-way)"
          % (len(sub_old), len(sub_new), len(sub3_old), len(sub3_new)))

    rnd = random.Random(20260911)
    cases = [(0, 0), (0, P - 1), (P - 1, 0), (P - 1, P - 1), (1, P - 1)]
    cases += [(rnd.randrange(P), rnd.randrange(P)) for _ in range(4000)]

    bad_model = bad_var = 0
    for a, b in cases:
        want = (a - b) % P
        got_old = run_case(sub_old, {"RFirst": a, "RSecond": b})
        got_new = run_case(sub_new, {"URFirst": a, "RSecond": b})
        bad_model += (got_old % P) != want or got_old >= (P << 1)
        bad_var += got_new != got_old
    print("SubMod256    : model reproduces (a-b) mod P on %d/%d, variant matches bit-for-bit on %d/%d"
          % (len(cases) - bad_model, len(cases), len(cases) - bad_var, len(cases)))

    triples = [(0, 0, 0), (0, P - 1, P - 1), (P - 1, 0, 0), (1, P - 1, P - 1)]
    triples += [(rnd.randrange(P), rnd.randrange(P), rnd.randrange(P)) for _ in range(4000)]
    bad_model3 = bad_var3 = 0
    for a, b, c in triples:
        want = (a - b - c) % P
        got_old = run_case(sub3_old, {"RFirst": a, "RSecond": b, "RThird": c})
        # the variant takes the table as URSecond and the point as RThird: call sites pass
        # the two the other way round, so feed c as the uniform operand and b as the third
        got_new = run_case(sub3_new, {"RFirst": a, "URSecond": c, "RThird": b})
        bad_model3 += (got_old % P) != want
        bad_var3 += got_new != got_old
    print("SubMod256_3  : model reproduces (a-b-c) mod P on %d/%d, variant matches on %d/%d"
          % (len(triples) - bad_model3, len(triples),
             len(triples) - bad_var3, len(triples)))

    return 1 if (bad_model or bad_var or bad_model3 or bad_var3) else 0


sys.exit(main())
