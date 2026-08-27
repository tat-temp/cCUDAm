#!/usr/bin/env python3
"""Find every loop in a SASS dump by back edge, and report its body size and nesting.

A back edge is any branch whose target address is <= its own address. The natural loop it
closes is [target, branch]. Nesting is containment of those intervals. Instruction counts are
ISSUE counts: predicated-off instructions still issue, so every instruction in the interval
counts once per trip.

Deliberately NOT a general CFG builder -- this kernel's loops are single-entry contiguous
intervals (checked: every back-edge target is a label the disassembler names), so intervals
are exact here and a dominator computation would add machinery without adding truth.
"""
import re
import sys

INS = re.compile(r'^\s+/\*([0-9a-f]+)\*/\s+(.*?);')
# Branch with a hex immediate target. BRXU/CALL/RET are indirect or inter-procedural.
BR = re.compile(r'\b(BRA|BRX|JMP|BSSY|CALL|RET|EXIT|BRXU)\b')
TARGET = re.compile(r'0x([0-9a-f]+)\s*;?\s*$')


def parse(path):
    out = []
    for line in open(path):
        m = INS.match(line)
        if m:
            out.append((int(m.group(1), 16), m.group(2).strip()))
    return out


def main(path):
    ins = parse(path)
    addr2idx = {a: i for i, (a, _) in enumerate(ins)}
    n = len(ins)
    print(f"=== {path}   {n} static instructions   "
          f"0x{ins[0][0]:x}..0x{ins[-1][0]:x}")

    # every EXIT: the kernel body ends at the last one; vendored FUNCTION bodies follow it
    exits = [i for i, (a, t) in enumerate(ins) if re.search(r'\bEXIT\b', t)]
    if exits:
        print(f"    EXIT at index {exits} (last = {exits[-1]}), "
              f"so {n - exits[-1] - 1} instructions follow the final EXIT")

    edges = []
    for i, (a, t) in enumerate(ins):
        if not BR.search(t):
            continue
        m = TARGET.search(t)
        if not m:
            continue
        tgt = int(m.group(1), 16)
        if tgt <= a and tgt in addr2idx:
            edges.append((addr2idx[tgt], i, t))

    if not edges:
        print("    no back edges")
        return

    edges.sort(key=lambda e: (e[0], -e[1]))
    print(f"\n    {len(edges)} back edge(s):\n")
    print(f"    {'head':>6} {'tail':>6} {'body':>6}  {'depth':>5}  contents")
    for h, t, txt in edges:
        depth = sum(1 for h2, t2, _ in edges if h2 < h and t2 > t)
        body = ins[h:t + 1]
        kinds = []
        for pat, name in (('STL', 'STL'), ('LDL', 'LDL'), ('LDC', 'LDC'),
                          ('LDG', 'LDG'), ('STG', 'STG'), ('BRXU', 'BRXU'),
                          ('IMAD', 'IMAD'), ('IADD3', 'IADD3')):
            c = sum(1 for _, s in body if re.search(r'\b' + pat, s))
            if c:
                kinds.append(f"{name}x{c}")
        print(f"    {h:6d} {t:6d} {t - h + 1:6d}  {depth:5d}  {' '.join(kinds)}")
        print(f"           back edge: {txt}")


if __name__ == '__main__':
    for p in sys.argv[1:]:
        main(p)
        print()
