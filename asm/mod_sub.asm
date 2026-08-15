FUNCTION SubMod256()
{ //Ri_cnt=8+8, Ro_cnt=8, Pt=[0..1]
    [B------:R-:W-:-:S04]    IADD3.X Ro0, Pt0, PT, RFirst0, ~RSecond0, RZ, !PT, PT
    [B------:R-:W-:-:S04]    IADD3.X Ro1, Pt0, PT, RFirst1, ~RSecond1, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro2, Pt0, PT, RFirst2, ~RSecond2, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro3, Pt0, PT, RFirst3, ~RSecond3, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro4, Pt0, PT, RFirst4, ~RSecond4, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro5, Pt0, PT, RFirst5, ~RSecond5, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro6, Pt0, PT, RFirst6, ~RSecond6, RZ, Pt0, !PT
    [B------:R-:W-:Y:S13]    IADD3.X Ro7, Pt0, PT, RFirst7, ~RSecond7, RZ, Pt0, !PT
//add P if <0
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro0, Pt1, PT, Ro0, 0xFFFFFC2F, RZ, !PT, !PT
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro1, Pt1, PT, Ro1, 0xFFFFFFFE, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro2, Pt1, PT, Ro2, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro3, Pt1, PT, Ro3, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro4, Pt1, PT, Ro4, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro5, Pt1, PT, Ro5, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @!Pt0 IADD3.X Ro6, Pt1, PT, Ro6, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S05] @!Pt0 IADD3.X Ro7, PT, PT, Ro7, 0xFFFFFFFF, RZ, Pt1, !PT
}

FUNCTION SubMod256_3()
{ //Ri_cnt=8+8+8, Ro_cnt=8, Rt_cnt=2, Pt=[0..2]
//reg bank conflict is possible
//
// STALLS WIDENED FROM THE VENDORED VALUES, 2026-08-15. The originals are kept in the
// trailing comment on each changed line.
//
// Kernel02's sources have only ever been through RCAsm's front end -- they have never been
// assembled or executed -- so their stall counts are unverified rather than blessed, and
// this routine is the first thing stage 2c-ii runs that had never run anywhere.
//
// Two dependencies here were the tightest in the routine, and the tail point came back
// wrong by exactly 2^224 + 0x7A1, which decomposes cleanly across the two:
//
//   Ro6 wrote Pt0/Pt2 at S01, and Ro7 read them across only the MOV -- TWO cycles.
//   Simulating Ro7 with the stale pair reproduces +2^224 exactly, the word-7 half.
//
//   SEL wrote Rt0 at S04 and the first correction read it one instruction later. Forcing
//   that word-0 constant to 0xFFFFFFFF instead of 2P's 0xFFFFF85E reproduces +0x7A1
//   exactly, the word-0 half -- and 0xFFFFF85E + 0x7A1 == 0xFFFFFFFF is not a coincidence.
//
// Everything cheaper was eliminated first: the routine is congruent-correct over 20,000
// random triples in simulation, the body emitted into the cubin is byte-for-byte what is
// written here, its three inputs are confirmed on hardware (lam and lam^2 both report ok),
// and no other emitted body writes Ro's registers after this one produces them. The
// arithmetic had nowhere left to be wrong.
//
// CONFIRMED ON HARDWARE, same day: with only this changed, stage 2c-ii's pts rung came back
// EXACT on all 256 threads and the tail chain reports lam ok / lam^2 ok / px3 ok. The
// prediction was falsifiable -- a still-wrong px3 would have killed the timing story and made
// both reproductions above coincidence -- and it held.
//
// WHAT IS CONFIRMED IS THE FIX, NOT THE MECHANISM, and the obvious reading of it is wrong.
// "Two cycles is below the floor for a carry-in predicate" does not survive the cubin:
// MulMod256, SqrMod256 and InvMod256 contain 126 carry-out -> carry-in pairs at two cycles
// between them, and all three are correct on hardware. What separates this routine from those
// 126 is not the distance, it is what sits in the gap -- every one of them spans an IADD3,
// IMAD or SHF, and this was the only two-cycle pair in the kernel spanning a MOV. That is one
// instance, and the widening below changed fifteen lines rather than the one, so it is a
// candidate and not a finding.
//
// NARROWING IT IS ONE RUN, and a sharp one: restore the originals except instruction 7's
// stall. The delta has two halves and they are attributed separately, so if the 2^224 half
// disappears and the 0x7A1 half does not, the run has separated the two claims above by
// itself. Worth doing when a hardware run is being spent anyway; not worth one of its own,
// since this is 18 instructions against 1023 calls per thread.
    [B------:R-:W-:-:S06]    IADD3.X Ro0, Pt0, Pt2, RFirst0, ~RSecond0, ~RThird0, PT, PT
    [B------:R-:W-:-:S06]    IADD3.X Ro1, Pt0, Pt2, RFirst1, ~RSecond1, ~RThird1, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro2, Pt0, Pt2, RFirst2, ~RSecond2, ~RThird2, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro3, Pt0, Pt2, RFirst3, ~RSecond3, ~RThird3, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro4, Pt0, Pt2, RFirst4, ~RSecond4, ~RThird4, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro5, Pt0, Pt2, RFirst5, ~RSecond5, ~RThird5, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro6, Pt0, Pt2, RFirst6, ~RSecond6, ~RThird6, Pt0, Pt2  //was S01
    [B------:R-:W-:-:S06]    MOV Rt1, 0xFFFFFC2F                                            //was S01
    [B------:R-:W-:Y:S09]    IADD3.X Ro7, Pt0, Pt2, RFirst7, ~RSecond7, ~RThird7, Pt0, Pt2
    [B------:R-:W-:-:S06]    SEL Rt0, Rt1, 0xFFFFF85E, Pt0                                  //was S04
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro0, Pt1, PT, Ro0, Rt0, RZ, !PT, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro1, Pt1, PT, Ro1, 0xFFFFFFFD, RZ, Pt1, Pt0
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro2, Pt1, PT, Ro2, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro3, Pt1, PT, Ro3, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro4, Pt1, PT, Ro4, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro5, Pt1, PT, Ro5, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro6, Pt1, PT, Ro6, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro7, PT,  PT, Ro7, 0xFFFFFFFF, RZ, Pt1, !PT         //was S05
}

FUNCTION AddMod256()
{ //Ri_cnt=8+8, Ro_cnt=8, Pt=[0..1]
    [B------:R-:W-:-:S04]    IADD3.X Ro0, Pt0, PT, RFirst0, RSecond0, RZ, !PT, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro1, Pt0, PT, RFirst1, RSecond1, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro2, Pt0, PT, RFirst2, RSecond2, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro3, Pt0, PT, RFirst3, RSecond3, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro4, Pt0, PT, RFirst4, RSecond4, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro5, Pt0, PT, RFirst5, RSecond5, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro6, Pt0, PT, RFirst6, RSecond6, RZ, Pt0, !PT
    [B------:R-:W-:Y:S13]    IADD3.X Ro7, Pt0, PT, RFirst7, RSecond7, RZ, Pt0, !PT
//sub P if carry
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro0, Pt1, PT, Ro0, 0x000003D1, RZ, !PT, !PT
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro1, Pt1, PT, Ro1, 0x00000001, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro2, Pt1, PT, Ro2, 0x00000000, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro3, Pt1, PT, Ro3, 0x00000000, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro4, Pt1, PT, Ro4, 0x00000000, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro5, Pt1, PT, Ro5, 0x00000000, RZ, Pt1, !PT
    [B------:R-:W-:-:S04] @Pt0 IADD3.X Ro6, Pt1, PT, Ro6, 0x00000000, RZ, Pt1, !PT
    [B------:R-:W-:-:S05] @Pt0 IADD3.X Ro7, PT,  PT, Ro7, 0x00000000, RZ, Pt1, !PT
}

FUNCTION NegMod256()
{
    [B------:R-:W-:-:S04]    IADD3.X Rio0, Pt0, PT, RZ, 0xFFFFFC2F, ~Rio0, !PT, PT
    [B------:R-:W-:-:S04]    IADD3.X Rio1, Pt0, PT, RZ, 0xFFFFFFFE, ~Rio1, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Rio2, Pt0, PT, RZ, 0xFFFFFFFF, ~Rio2, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Rio3, Pt0, PT, RZ, 0xFFFFFFFF, ~Rio3, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Rio4, Pt0, PT, RZ, 0xFFFFFFFF, ~Rio4, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Rio5, Pt0, PT, RZ, 0xFFFFFFFF, ~Rio5, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Rio6, Pt0, PT, RZ, 0xFFFFFFFF, ~Rio6, Pt0, !PT
    [B------:R-:W-:-:S05]    IADD3.X Rio7, PT, PT, RZ, 0xFFFFFFFF, ~Rio7, Pt0, !PT
}

FUNCTION Copy256()
{
    [B------:R-:W-:-:S01]    IMAD Ro0, RZ, RZ, Ri0
    [B------:R-:W-:-:S01]    MOV Ro1, Ri1
    [B------:R-:W-:-:S01]    IMAD Ro2, RZ, RZ, Ri2
    [B------:R-:W-:-:S01]    MOV Ro3, Ri3
    [B------:R-:W-:-:S01]    IMAD Ro4, RZ, RZ, Ri4
    [B------:R-:W-:-:S01]    MOV Ro5, Ri5
    [B------:R-:W-:-:S01]    IMAD Ro6, RZ, RZ, Ri6
    [B------:R-:W-:-:S05]    MOV Ro7, Ri7
}

FUNCTION Zero256()
{
    [B------:R-:W-:-:S01]    IMAD Ro0, RZ, RZ, RZ
    [B------:R-:W-:-:S01]    MOV Ro1, RZ
    [B------:R-:W-:-:S01]    IMAD Ro2, RZ, RZ, RZ
    [B------:R-:W-:-:S01]    MOV Ro3, RZ
    [B------:R-:W-:-:S01]    IMAD Ro4, RZ, RZ, RZ
    [B------:R-:W-:-:S01]    MOV Ro5, RZ
    [B------:R-:W-:-:S01]    IMAD Ro6, RZ, RZ, RZ
    [B------:R-:W-:-:S06]    MOV Ro7, RZ
}