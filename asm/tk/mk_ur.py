#!/usr/bin/env python3
"""Generate the LDCU.128 variant of the points kernel: main_ur.asm + inc_ur.asm.

Produced from main.asm / inc.asm by explicit, counted edits -- every one asserts how many
times it must match -- so the diff is exactly what is described here and nothing else.

inc_ur.asm adds two FUNCTIONs. Both are the committed bodies with one operand moved into the
b slot, the only slot a uniform register may occupy:

  SubMod256_UB    was  IADD3.X Ro, Pt0, PT, RFirst, ~RSecond, RZ, c, !PT
                  now  IADD3.X Ro, Pt0, PT, ~RSecond, URFirst, RZ, c, !PT
        a and b feed the same adder stage, so swapping them cannot move a carry, and c stays
        RZ so the discarded second carry-out stays zero.

  SubMod256_3_UB  was  IADD3.X Ro, Pt0, Pt2, RFirst, ~RSecond, ~RThird, p, p
                  now  IADD3.X Ro, Pt0, Pt2, RFirst, ~URSecond, ~RThird, p, p
        identical text, one operand renamed: call sites now pass the TABLE as URSecond and
        the point as RThird. a-b-c is symmetric in b and c, and the correction reads Pt0 as
        "borrowed at most once" and Pt2 as "did not borrow" -- which is what a+~b+~c+2 gives
        for a total carry of 1 and of 2: a function of the sum, not of the operand order.

main_ur.asm:
  * declares uCOfs/uGx/uGy/uGyN, and zeroes UR63 in the prologue -- RCAsm encodes URZ as UR63
    in uniform ALU ops, and UR63 is a real register on Blackwell.
  * keeps a uniform copy of the byte offset beside COfs: LDCU+USHF seeds it in the ladder,
    UMOV zeroes it in the walk, and a UIADD3 sits beside every IADD3 that steps COfs.
  * ladder: four LDC.64 -> two LDCU.128 into uGx.
  * walk: five table sites -> one block of six LDCU.128 at the top of the trip. The three
    c_Gx reads collapse into one, because a uniform register survives the multiplies that
    used to clobber MulB, and four now-redundant barrier-wait NOPs go with them.

The tail after the walk loop repeats the same patterns, runs once per batch, and is left
alone: it still reads COfs, which is still maintained.
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = DST = HERE
NL = "\r\n"
NOP4 = "    [B----4-:R-:W-:-:S01]    NOP"


def load(name):
    return io.open(os.path.join(SRC, name), newline="").read()


def sub(text, old, new, count=1, what=""):
    n = text.count(old)
    if n != count:
        sys.exit("edit %r: expected %d match(es), found %d" % (what or old[:50], count, n))
    return text.replace(old, new, count)


# ================================================================ inc_ur.asm =============
inc = load("inc.asm")


def body_of(header):
    """The instruction lines of a FUNCTION -- without its header or its opening brace.

    Splitting on the header leaves the rest of that line plus the `{ //Ri_cnt=...` line,
    and pasting those into a second FUNCTION puts a stray brace in the instruction stream,
    which RCAsm reports much later as "Unrecognized code text".
    """
    lines = inc.split(header)[1].split(NL + "}")[0].split(NL)
    while lines and not lines[0].lstrip().startswith("{"):
        lines.pop(0)
    return lines[1:]


body_sub = body_of("FUNCTION SubMod256()")
body_sub3 = body_of("FUNCTION SubMod256_3()")

ub = []
for line in body_sub:
    if "IADD3.X" in line and "RFirst" in line and "~RSecond" in line:
        head, rest = line.split("IADD3.X", 1)
        parts = [p.strip() for p in rest.split(",")]
        # Ro_k, Pt0, PT, RFirst_k, ~RSecond_k, RZ, carry, !PT
        assert parts[3].startswith("RFirst") and parts[4].startswith("~RSecond"), parts
        idx = parts[3][len("RFirst"):]
        parts[3], parts[4] = parts[4], "URFirst" + idx
        line = head + "IADD3.X " + ", ".join(parts)
    ub.append(line)

ub3 = [l.replace("~RSecond", "~URSecond") for l in body_sub3]

inc_ur = inc.rstrip(NL) + NL + NL.join([
    "",
    "FUNCTION SubMod256_UB()",
    "{ //Ri_cnt=8(UR)+8, Ro_cnt=8, Pt=[0..1]",
] + ub + [
    "}",
    "",
    "FUNCTION SubMod256_3_UB()",
    "{ //Ri_cnt=8+8(UR)+8, Ro_cnt=8, Rt_cnt=2, Pt=[0..2]",
] + ub3 + [
    "}",
    "",
])
io.open(os.path.join(DST, "inc_ur.asm"), "w", newline="").write(inc_ur)

# ================================================================ main_ur.asm ============
m = load("main.asm")

# ---- 1. uniform register allocation ----------------------------------------------------
m = sub(m, "    uDesc=UR4, uCallI=UR8, uInvT=UR10 )",
        "    uDesc=UR4, uCallI=UR8, uInvT=UR10, \\" + NL +
        "    uCOfs=UR16, uGx=UR20, uGy=UR28, uGyN=UR36 )", 1, "KERNEL header")

# ---- 2. UR63 must hold zero before any uniform ALU op uses URZ -------------------------
anchor = "    [B------:R-:W1:-:S01]    S2R BlockID, SR_CTAID.X"
m = sub(m, anchor, anchor + NL +
        "    [B------:R-:W-:-:S01]    UMOV URZ, 0x00", 1, "URZ zeroing")

# ---- 3. seed the uniform offset in the ladder ------------------------------------------
seed = [l for l in m.split(NL)
        if "IMAD COfs, Half, 0x10, RZ" in l and l.startswith("    [B")]
if len(seed) != 1:
    sys.exit("expected exactly one ladder seed instruction, found %d" % len(seed))
m = sub(m, seed[0], seed[0] + NL +
        "    [B------:R-:W5:-:S02]    LDCU uCOfs, c[0x0][0x3a8]" + NL +
        "    [B-----5:R-:W-:-:S05]    USHF.L.U32 uCOfs, uCOfs, 0x4, URZ", 1, "ladder seed")

# ---- 4. every step of COfs gets a uniform twin -----------------------------------------
down = "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ"
m = sub(m, down, down + NL +
        "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, -0x20, URZ", 2, "ladder step")
up = "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, 0x20, RZ"
m = sub(m, up, up + NL +
        "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, 0x20, URZ", 1, "walk step")
zero = "    [B------:R-:W-:-:S01]    MOV COfs, RZ"
m = sub(m, zero, zero + NL +
        "    [B------:R-:W-:-:S01]    UMOV uCOfs, 0x00", 1, "walk seed")


# ---- 5. the load sites, one loop region at a time ---------------------------------------
def ldcu(pairs, first_ctrl="    [B------:R-:W4:-:S01]"):
    """LDCU.128 pairs: [(ur_name, table byte offset), ...]; two loads cover four limbs."""
    out = []
    for n, (ur, ofs) in enumerate(pairs):
        for half in (0, 4):
            last = (n == len(pairs) - 1 and half == 4)
            ctrl = first_ctrl if (n == 0 and half == 0) else (
                "    [B------:R-:W4:-:S02]" if last else "    [B------:R-:W4:-:S01]")
            out.append("%s    LDCU.128 %s%d, c[0x3][uCOfs+%#x]"
                       % (ctrl, ur, half, ofs + 4 * half))
    return out


def blocks(lines, ofs):
    """Indices of the first line of every four-line LDC.64 site for table `ofs`."""
    tag = "LDC.64 MulB0, c[0x3][COfs+%#x]" % ofs
    hits = []
    for i, l in enumerate(lines):
        if tag in l and l.startswith("    [B"):
            for k in range(1, 4):
                assert "LDC.64 MulB%d" % (2 * k) in lines[i + k], lines[i + k]
            hits.append(i)
    return hits


def region(text, start, end):
    i = text.index(start)
    return i, text.index(end, i)


# ladder: the single c_Gx site
li, lj = region(m, ".label_sufp_loop:", "@P0 BRA.U `(.label_sufp_loop)")
lines = m[li:lj].split(NL)
hits = blocks(lines, 0x4040)
if len(hits) != 1:
    sys.exit("ladder: expected 1 c_Gx site, found %d" % len(hits))
lines[hits[0]:hits[0] + 4] = ldcu([("uGx", 0x4040)])
ladder = sub(NL.join(lines),
             "inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)",
             "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)", 1,
             "ladder call site")
m = m[:li] + ladder + m[lj:]

# walk: five sites -> one block of six loads at the first of them
wi, wj = region(m, ".label_walk_loop:", "@P0 BRA.U `(.label_walk_loop)")
lines = m[wi:wj].split(NL)
gy, gx, gyn = blocks(lines, 0x40), blocks(lines, 0x4040), blocks(lines, 0x8040)
if (len(gy), len(gx), len(gyn)) != (1, 3, 1):
    sys.exit("walk sites: expected 1 c_Gy, 3 c_Gx, 1 c_GyNeg, found %d/%d/%d"
             % (len(gy), len(gx), len(gyn)))

# every site but the first also owns the barrier-wait NOP that follows it
for i in sorted(gx + gyn, reverse=True):
    if lines[i + 4] != NOP4:
        sys.exit("expected a barrier-wait NOP after the site at line %d, found %r"
                 % (i, lines[i + 4]))
    lines = lines[:i] + lines[i + 5:]

# the first site becomes all three tables; its own NOP stays and drains them all
a = blocks(lines, 0x40)[0]
if lines[a + 4] != NOP4:
    sys.exit("expected a barrier-wait NOP after the c_Gy site, found %r" % lines[a + 4])
lines[a:a + 4] = (ldcu([("uGy", 0x40), ("uGx", 0x4040), ("uGyN", 0x8040)],
         "    [B-1----:R-:W4:-:S01]"))

# the two y-subtracts, in program order: the + branch reads c_Gy, the - branch c_GyNeg
seen = [i for i, l in enumerate(lines)
        if "inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)" in l]
if len(seen) != 2:
    sys.exit("expected 2 y-subtracts in the walk, found %d" % len(seen))
for i, ur in zip(seen, ("uGy", "uGyN")):
    lines[i] = "inc_func SubMod256_UB(URFirst=%s, RSecond=PntY, Ro=MulB, Pt=0)" % ur

body = NL.join(lines)
body = sub(body,
           "inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)",
           "inc_func SubMod256_3_UB(RFirst=Sqr, URSecond=uGx, RThird=PntX, Ro=PxN, Rt=Pt3T, Pt=0)",
           2, "walk three-way subtracts")
body = sub(body, "inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)",
           "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)", 1, "walk site E")
m = m[:wi] + body + m[wj:]

io.open(os.path.join(DST, "main_ur.asm"), "w", newline="").write(m)

old, new = load("main.asm").split(NL), m.split(NL)
print("inc_ur.asm : %d lines (+%d)"
      % (len(inc_ur.split(NL)), len(inc_ur.split(NL)) - len(inc.split(NL))))
print("main_ur.asm: %d lines (%+d)" % (len(new), len(new) - len(old)))
