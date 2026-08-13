#!/usr/bin/env python3
"""Same sweep as gap.py, but bucketed by address region.

Question: if getHash160_33 / getHash160_w2 are lifted verbatim out of the
shipped kernel and used as RCAsm FUNCTIONs, how many of THEIR instructions
does cuAssembler fail to encode?

  getHash160_33  0x171e0 .. 0x1f1a0   (2045 instrs, 32720 B)
  getHash160_w2  0x1f1b0 .. 0x26ff0   (2021 instrs, 32336 B)
  everything else = the rest of TestKernel
"""
import sys, os, re, collections, shutil
import env

from CuAsm import CuAsmParser
from CuAsm.CuAsmLogger import CuAsmLogger
from CuAsm.CuInsAssemblerRepos import CuInsAssemblerRepos
env.configure()
try:
    CuAsmLogger.disable()
except Exception:
    pass

region = env.region

fails = collections.defaultdict(collections.Counter)   # region -> InsKey -> n
oks   = collections.Counter()                          # region -> n
tot   = collections.Counter()
sample = {}
seen_addr = collections.defaultdict(list)
orig = CuInsAssemblerRepos.assemble

def patched(self, addr, ins, *a, **kw):
    r_ = region(addr)
    tot[r_] += 1
    try:
        v = orig(self, addr, ins, *a, **kw)
        oks[r_] += 1
        return v
    except Exception as e:
        m = re.search(r"InsKey\((\w+)\)", str(e))
        k = m.group(1) if m else "?" + str(e)[:40]
        fails[r_][k] += 1
        sample.setdefault((r_, k), (addr, ins.strip() if isinstance(ins, str) else str(ins)))
        if len(seen_addr[(r_, k)]) < 8:
            seen_addr[(r_, k)].append(addr)
        return 0

CuInsAssemblerRepos.assemble = patched

ASM = os.path.join(env.WORK, "gaphash.cuasm")
shutil.copyfile(env.KERNEL_ASM, ASM)
UNK = re.compile(r"Unknown directive (\.\S+?)!")
for _ in range(10):
    try:
        cap = CuAsmParser()
        cap.set_sm(120)
        cap.parse(ASM)
        break
    except Exception as e:
        m = UNK.search(str(e))
        if not m:
            print("parse stopped: %s: %s" % (type(e).__name__, str(e)[:160]))
            break
        d = m.group(1)
        L = open(ASM).read().splitlines()
        p = re.compile(r"^(\s*)" + re.escape(d) + r"\s*$")
        n = 0
        for i, ln in enumerate(L):
            if p.match(ln):
                L[i] = "//" + ln; n += 1
        print("neutralized %s x%d" % (d, n))
        open(ASM, "w").write("\n".join(L) + "\n")

print()
print("%-22s %8s %10s %8s   %s" % ("region", "instrs", "encodable", "FAIL", "fail %"))
print("-" * 72)
for r_ in ("getHash160_33", "getHash160_w2", "rest of TestKernel"):
    n = tot[r_]
    bad = sum(fails[r_].values())
    if n:
        print("%-22s %8d %10d %8d   %5.2f%%" % (r_, n, oks[r_], bad, 100.0 * bad / n))
n = sum(tot.values()); bad = sum(sum(c.values()) for c in fails.values())
print("-" * 72)
print("%-22s %8d %10d %8d   %5.2f%%" % ("TOTAL", n, n - bad, bad, 100.0 * bad / max(1, n)))

for r_ in ("getHash160_33", "getHash160_w2", "rest of TestKernel"):
    print()
    print("=== %s: every instruction cuAssembler cannot encode ===" % r_)
    if not fails[r_]:
        print("  (none)")
        continue
    for k, c in fails[r_].most_common():
        a, s = sample[(r_, k)]
        print("  %-28s x%-5d  @0x%05x  %s" % (k, c, a, s[:60]))
        print("       addrs: %s" % ", ".join("0x%05x" % x for x in seen_addr[(r_, k)]))
