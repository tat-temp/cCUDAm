#!/usr/bin/env python3
"""Generate the LDCU.128 (uniform-register) variants of the walk kernels:
  main.asm      -> main_ur.asm        (points-only)
  main_full.asm -> main_full_ur.asm   (full pipeline: walk + hash + publish)
  inc.asm       -> inc_ur.asm         (+ SubMod256_UB / SubMod256_3_UB)

Produced by explicit, counted edits -- every one asserts how many times it must match -- so the
diff is exactly what is described here and nothing else. The SAME transform runs on both main
files (transform_main): the full kernel has the identical walk structure (1 c_Gy, 3 c_Gx, 1
c_GyNeg per trip) with getHash160_33/getPublish2 inserted between sites, and those calls use only
UR4/6/8/10/12/14 -- they never touch UR16..43, so uGx/uGy/uGyN survive across the hash.

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

main_ur.asm / main_full_ur.asm:
  * declare uCOfs/uGx/uGy/uGyN, and zero UR63 in the prologue -- RCAsm encodes URZ as UR63
    in uniform ALU ops, and UR63 is a real register on Blackwell.
  * keep a uniform copy of the byte offset beside COfs: LDCU+USHF seeds it in the ladder,
    UMOV zeroes it in the walk, and a UIADD3 sits beside every IADD3 that steps COfs.
  * ladder: four LDC.64 -> two LDCU.128 into uGx.
  * walk: five table sites -> one block of six LDCU.128 at the top of the trip. The three
    c_Gx reads collapse into one, because a uniform register survives the multiplies (and, in
    the full kernel, the hash+publish) that used to clobber MulB, and four now-redundant
    barrier-wait NOPs go with them.

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


# ================================================================ main_*_ur.asm ==========
# ---- load-site helpers ------------------------------------------------------------------
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


GYN_BASE = "IADD3 SAdr, PT, PT, COfs, 0x8000, RZ"


def blocks_gyn(lines):
    """c_GyNeg starts at 0x8040, past the signed 16-bit LDC offset, so its sites index from
    SAdr = COfs + 0x8000, formed on the line before. First LDC line of every such site."""
    hits = []
    for i, l in enumerate(lines):
        if "LDC.64 MulB0, c[0x3][SAdr+0x40]" in l and l.startswith("    [B"):
            assert GYN_BASE in lines[i - 1], lines[i - 1]
            for k in range(1, 4):
                assert "LDC.64 MulB%d, c[0x3][SAdr+%#x]" % (2 * k, 0x40 + 8 * k) in lines[i + k], lines[i + k]
            hits.append(i)
    return hits


def region(text, start, end):
    i = text.index(start)
    return i, text.index(end, i)


def transform_main(m, hdr_old, hdr_new):
    # ---- 1. uniform register allocation ------------------------------------------------
    m = sub(m, hdr_old, hdr_new, 1, "KERNEL header")

    # ---- 2. UR63 must hold zero before any uniform ALU op uses URZ. Both main.asm and
    #    main_full.asm already zero it in the prologue, so ASSERT that rather than inserting a
    #    second (redundant) UMOV URZ, 0x00. RCAsm encodes URZ as UR63, a real Blackwell register.
    if m.count("    [B------:R-:W-:-:S01]    UMOV URZ, 0x00") < 1:
        sys.exit("source does not zero URZ (UR63) in the prologue")

    # ---- 3. seed the uniform offset in the ladder --------------------------------------
    seed = [l for l in m.split(NL)
            if "IMAD COfs, Half, 0x10, RZ" in l and l.startswith("    [B")]
    if len(seed) != 1:
        sys.exit("expected exactly one ladder seed instruction, found %d" % len(seed))
    m = sub(m, seed[0], seed[0] + NL +
            "    [B------:R-:W5:-:S02]    LDCU uCOfs, c[0x0][0x3a8]" + NL +
            "    [B-----5:R-:W-:-:S05]    USHF.L.U32 uCOfs, uCOfs, 0x4, URZ", 1, "ladder seed")

    # ---- 4. every step of COfs gets a uniform twin -------------------------------------
    down = "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ"
    m = sub(m, down, down + NL +
            "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, -0x20, URZ", 2, "ladder step")
    up = "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, 0x20, RZ"
    m = sub(m, up, up + NL +
            "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, 0x20, URZ", 1, "walk step")
    zero = "    [B------:R-:W-:-:S01]    MOV COfs, RZ"
    m = sub(m, zero, zero + NL +
            "    [B------:R-:W-:-:S01]    UMOV uCOfs, 0x00", 1, "walk seed")

    # ---- 5. the load sites, one loop region at a time ----------------------------------
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
    gy, gx, gyn = blocks(lines, 0x40), blocks(lines, 0x4040), blocks_gyn(lines)
    if (len(gy), len(gx), len(gyn)) != (1, 3, 1):
        sys.exit("walk sites: expected 1 c_Gy, 3 c_Gx, 1 c_GyNeg, found %d/%d/%d"
                 % (len(gy), len(gx), len(gyn)))

    # every site but the first also owns the barrier-wait NOP that follows it, and the c_GyNeg
    # site the SAdr base line before it
    for i in sorted(gx + gyn, reverse=True):
        if lines[i + 4] != NOP4:
            sys.exit("expected a barrier-wait NOP after the site at line %d, found %r"
                     % (i, lines[i + 4]))
        lines = lines[:i - (i in gyn)] + lines[i + 5:]

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
    return m


def once_per_batch(m):
    """Full kernel only: convert the seven once-per-batch bank-3 table loads (SUFP c_Jx,
    INV c_Gx[0], PLUST c_GyNeg + c_Gx, JUMP c_Gx + c_Jy + c_Jx) from 4x LDC.64 to
    2x LDCU.128 + a _UB subtract -- the same win the walk/ladder already take, but for the
    prologue/tail that runs once per batch. These sites sit outside the loop regions
    transform_main rewrites, so they are still LDC.64 here.

      * uCOfs == COfs across the whole tail: both step from 0 in the walk and neither is
        touched afterward, so the COfs-indexed tail loads (PLUST/JUMP c_Gx, PLUST c_GyNeg)
        reindex directly on uCOfs.
      * the three fixed loads (c_Jx at 0x0, c_Gx[0] at 0x4040, c_Jy at 0x20) use LDCU's
        no-index form c[0x3][imm] (LDCU_UR_cAI), which needs no index register.
      * PLUST's c_GyNeg drops its `IADD3 SAdr, COfs, 0x8000` wrap-workaround: LDCU's
        immediate reaches 0x8040 directly, unlike LDC.64's signed 16-bit offset.

    uGx/uGy/uGyN are dead outside a walk trip, so they are reused as the scratch table reg
    at each site; each load's W4 + drain NOP is kept exactly as the LDC.64 block had it.
    """
    E = [
        # SUFP c_Jx (fixed 0x0) -> uGx; the LDC Half + Ro=MulA make the block unique
        ("    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x0]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x8]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x10]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB6, c[0x3][0x18]" + NL +
         "    [B------:R-:W5:-:S02]    LDC Half, c[0x0][0x3a8]" + NL +
         "    [B0---4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulA, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][0x0]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][0x10]" + NL +
         "    [B------:R-:W5:-:S02]    LDC Half, c[0x0][0x3a8]" + NL +
         "    [B0---4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulA, Pt=0)", "SUFP c_Jx"),
        # INV c_Gx[0] (fixed 0x4040) -> uGx
        ("    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x4040]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x4048]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x4050]" + NL +
         "    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x4058]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][0x4040]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][0x4050]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)", "INV c_Gx[0]"),
        # PLUST c_GyNeg (SAdr+0x40) -> uGyN, dropping the IADD3 SAdr wrap line
        ("    [B------:R-:W-:-:S04]    IADD3 SAdr, PT, PT, COfs, 0x8000, RZ //c_GyNeg is past the signed 16-bit LDC offset" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][SAdr+0x40]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][SAdr+0x48]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][SAdr+0x50]" + NL +
         "    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][SAdr+0x58]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGyN0, c[0x3][uCOfs+0x8040]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGyN4, c[0x3][uCOfs+0x8050]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_UB(URFirst=uGyN, RSecond=PntY, Ro=MulB, Pt=0)", "PLUST c_GyNeg"),
        # PLUST c_Gx (COfs+0x4040 -> uCOfs) -> uGx; SubMod256_3 makes it unique vs JUMP c_Gx
        ("    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]" + NL +
         "    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][uCOfs+0x4040]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][uCOfs+0x4050]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_3_UB(RFirst=Sqr, URSecond=uGx, RThird=PntX, Ro=PxN, Rt=Pt3T, Pt=0)", "PLUST c_Gx"),
        # JUMP c_Gx (COfs+0x4040 -> uCOfs) -> uGx; the trailing MulMod(Rinv,..) makes it unique
        ("    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]" + NL +
         "    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)" + NL +
         "inc_func MulMod256(RFirst=Rinv, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][uCOfs+0x4040]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][uCOfs+0x4050]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)" + NL +
         "inc_func MulMod256(RFirst=Rinv, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)", "JUMP c_Gx"),
        # JUMP c_Jy (fixed 0x20) -> uGy
        ("    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x20]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x28]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x30]" + NL +
         "    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x38]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGy0, c[0x3][0x20]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGy4, c[0x3][0x30]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_UB(URFirst=uGy, RSecond=PntY, Ro=MulB, Pt=0)", "JUMP c_Jy"),
        # JUMP c_Jx (fixed 0x0, MulB6 at S02) -> uGx; SubMod256_3 makes it unique vs SUFP c_Jx
        ("    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x0]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x8]" + NL +
         "    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x10]" + NL +
         "    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x18]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)",
         "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][0x0]" + NL +
         "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][0x10]" + NL +
         "    [B----4-:R-:W-:-:S01]    NOP" + NL +
         "inc_func SubMod256_3_UB(RFirst=Sqr, URSecond=uGx, RThird=PntX, Ro=PxN, Rt=Pt3T, Pt=0)", "JUMP c_Jx"),
    ]
    for old, new, what in E:
        m = sub(m, old, new, 1, what)
    return m


def ping_pong_sufp(m):
    """Full kernel only: eliminate the 8-instruction MulR->MulA copy in the sufp ladder by
    ping-ponging the running product between MulA and MulR across an unroll-by-2.

    The ladder builds subp[i] = subp[i+1] * (c_Gx[i+1]-x1). Each trip's MulMod cannot write
    its result in place over its RFirst input (aliasing), so the committed loop writes MulR
    then copies MulR->MulA for the next trip and the store. Instead:
      * trip A: MulMod(RFirst=MulA -> Ro=MulR), store MulR
      * trip B: MulMod(RFirst=MulR -> Ro=MulA), store MulA        (R64 read, R56 written: safe)
    No copy; the accumulator just alternates registers. The loop back-edge lands on trip A,
    which reads MulA -- so trip B leaves the accumulator in MulA, trip A in MulR.

    Runtime parity: the trip count (half-1) is a runtime value, so the pair can end on either
    trip. Each trip keeps its own COfs==0 test and exit branch; whichever trip hits COfs==0
    exits. The accumulator's final register is dead (INV reloads subp[0] from [R1]), so the
    odd/even landing does not matter -- only that every subp[i] was stored, which both trips do.

    Scheduling: MulMod's last Ro limbs are written by IADD3.X (needs ~5 cumulative stall before
    a consumer). The copies used to be that gap; here the COfs/uCOfs updates are moved ahead of
    the STL to supply it. The [B---3--]/R3 SAdr scoreboard is kept on every IADD3 SAdr / STL,
    so the chain still reaches INV's `LDL.128 MulA0, [R1]` wait.
    """
    old = (
        ".label_sufp_loop:" + NL +
        "    [B---3--:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ" + NL +
        "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][uCOfs+0x4040]" + NL +
        "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][uCOfs+0x4050]" + NL +
        "    [B----4-:R-:W-:-:S01]    NOP" + NL +
        "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)" + NL +
        "inc_func MulMod256(RFirst=MulA, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)" + NL +
        "    [B------:R-:W-:-:S01]    IMAD MulA0, RZ, RZ, MulR0" + NL +
        "    [B------:R-:W-:-:S01]    MOV MulA1, MulR1" + NL +
        "    [B------:R-:W-:-:S01]    IMAD MulA2, RZ, RZ, MulR2" + NL +
        "    [B------:R-:W-:-:S01]    MOV MulA3, MulR3" + NL +
        "    [B------:R-:W-:-:S01]    IMAD MulA4, RZ, RZ, MulR4" + NL +
        "    [B------:R-:W-:-:S01]    MOV MulA5, MulR5" + NL +
        "    [B------:R-:W-:-:S01]    IMAD MulA6, RZ, RZ, MulR6" + NL +
        "    [B------:R-:W-:-:S02]    MOV MulA7, MulR7" + NL +
        "    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulA0" + NL +
        "    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulA4" + NL +
        "" + NL +
        "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ" + NL +
        "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, -0x20, URZ" + NL +
        "    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT" + NL +
        "    [B------:R-:W-:Y:S05] @P0 BRA.U `(.label_sufp_loop)")
    new = (
        ".label_sufp_loop:" + NL +
        "    [B---3--:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ" + NL +
        "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][uCOfs+0x4040]" + NL +
        "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][uCOfs+0x4050]" + NL +
        "    [B----4-:R-:W-:-:S01]    NOP" + NL +
        "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)" + NL +
        "inc_func MulMod256(RFirst=MulA, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)" + NL +
        "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ" + NL +
        "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, -0x20, URZ" + NL +
        "    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulR0" + NL +
        "    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulR4" + NL +
        "    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT" + NL +
        "    [B------:R-:W-:Y:S05] @!P0 BRA.U `(.label_sufp_end)" + NL +
        "    [B---3--:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ" + NL +
        "    [B------:R-:W4:-:S01]    LDCU.128 uGx0, c[0x3][uCOfs+0x4040]" + NL +
        "    [B------:R-:W4:-:S02]    LDCU.128 uGx4, c[0x3][uCOfs+0x4050]" + NL +
        "    [B----4-:R-:W-:-:S01]    NOP" + NL +
        "inc_func SubMod256_UB(URFirst=uGx, RSecond=PntX, Ro=MulB, Pt=0)" + NL +
        "inc_func MulMod256(RFirst=MulR, RSecond=MulB, Ro=MulA, Rt=Tmp, Pt=0)" + NL +
        "    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ" + NL +
        "    [B------:R-:W-:-:S05]    UIADD3 uCOfs, uCOfs, -0x20, URZ" + NL +
        "    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulA0" + NL +
        "    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulA4" + NL +
        "    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT" + NL +
        "    [B------:R-:W-:Y:S05] @P0 BRA.U `(.label_sufp_loop)")
    return sub(m, old, new, 1, "ping-pong sufp ladder")


MAIN_HDR_OLD = "    uDesc=UR4, uCallI=UR8, uInvT=UR10 )"
MAIN_HDR_NEW = ("    uDesc=UR4, uCallI=UR8, uInvT=UR10, \\" + NL +
                "    uCOfs=UR16, uGx=UR20, uGy=UR28, uGyN=UR36 )")
FULL_HDR_OLD = "    uDesc=UR4, uHashSel=UR6, uCallI=UR8, uInvT=UR10, uCallH=UR12, uCallP=UR14 )"
FULL_HDR_NEW = ("    uDesc=UR4, uHashSel=UR6, uCallI=UR8, uInvT=UR10, uCallH=UR12, uCallP=UR14, \\" + NL +
                "    uCOfs=UR16, uGx=UR20, uGy=UR28, uGyN=UR36 )")

# Compute both transforms BEFORE opening any output file: "w" truncates on open, so a crash
# mid-transform must not be able to leave a committed *_ur.asm empty.
main_ur = transform_main(load("main.asm"), MAIN_HDR_OLD, MAIN_HDR_NEW)
main_full_ur = ping_pong_sufp(once_per_batch(transform_main(load("main_full.asm"), FULL_HDR_OLD, FULL_HDR_NEW)))
io.open(os.path.join(DST, "main_ur.asm"), "w", newline="").write(main_ur)
io.open(os.path.join(DST, "main_full_ur.asm"), "w", newline="").write(main_full_ur)
