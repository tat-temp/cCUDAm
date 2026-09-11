#!/usr/bin/env python3
# Turn the lifted hash bodies (raw registers) into parametrized RCAsm FUNCTIONs (Ri/Rio/Rt/URt).
# Pure register-name remap -- every physical register number is preserved; verify by SASS diff.
# getHash160_w2 and getHash160_33 share ONE input ABI, so ONE map:
#   R6..R13  -> Ri0..Ri7   the 8 little-endian SHA input words
#   R4       -> Rio0        prefix byte IN; also an output word
#   UR4      -> URt0        a PRMT-select uniform temp, set inside the body
#   every other R<n> -> Rt<n>
# Example bind reproducing the verified registers (Rt=MulB=R48):
#   call_func getHash160_33(Ri=R54, Rio=R52, Rt=MulB, URt=uHashSel, Ret="...BRXU.U uCallH,0x00")
# Regenerate; do NOT hand-edit the outputs.
import re

r_re  = re.compile(r'(?<![A-Za-z0-9_])R(\d+)\b')
ur_re = re.compile(r'\bUR4\b')

def mapreg(n):
    if n == 4:        return 'Rio0'           # prefix in / word0 out (shared register -> in/out class)
    if 6 <= n <= 13:  return 'Ri%d' % (n - 6) # the 8 SHA input words
    return 'Rt%d' % n                          # bulk temps

def xform(line):
    line = r_re.sub(lambda m: mapreg(int(m.group(1))), line)
    line = ur_re.sub('URt0', line)
    return line

def parametrize(src, dst, header, tag):
    lines = open(src).read().splitlines()
    body, depth, seen_open = [], 0, False
    for ln in lines:
        s = ln.strip()
        if s == '{':
            depth += 1; seen_open = True; continue
        if s == '}':
            depth -= 1; continue
        if seen_open and depth >= 1:
            body.append(xform(ln))
    body_joined = "".join(b + "\n" for b in body)
    assert not r_re.search(body_joined), "unmapped R<n> remains in " + src
    assert not ur_re.search(body_joined), "unmapped UR4 remains in " + src
    with open(dst, "w", newline="\n") as f:
        f.write(header + "{\n" + body_joined + "}\n")
    def rng(cls):
        ns = [int(m.group(1)) for m in re.finditer(r'\b%s(\d+)\b' % cls, body_joined)]
        return "%s0..%s%d" % (cls, cls, max(ns)) if ns else "-"
    n = sum(1 for b in body if b.lstrip().startswith('['))
    print("wrote %-24s instrs=%-4d Ri=%-9s Rio=%-5s Rt=%-9s URt=%s"
          % (dst.split('/')[-1], n, rng('Ri'), rng('Rio'), rng('Rt'), rng('URt')))

W2_HEADER = """\
FUNCTION getHash160_w2(x=Ri0, pfx=Rio0, tmp=Rt0, sel=URt0)
"""

H33_HEADER = """\
FUNCTION getHash160_33(x=Ri0, pfx=Rio0, tmp=Rt0, sel=URt0)
"""

if __name__ == "__main__":
    parametrize("hd_hash_inc.asm",   "hd_hash_inc_param.asm",   W2_HEADER,  "w2")
    parametrize("hd_hash33_inc.asm", "hd_hash33_inc_param.asm", H33_HEADER, "h33")
