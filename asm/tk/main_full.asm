KERNEL TestKernel(regcnt=128, \
    BDone=R0, gID=R2, TmpA=R3, TmpB=R4, Idx=R5, Half=R6, SAdr=R7, \
    PntX=R8, PntY=R16, Scal=R24, \
    ThrID=R32, BlockID=R33, AddrX=R34, AddrY=R36, AddrS=R38, AddrC=R40, Thr=R42, \
    Inv=R32, InvO=R42, InvT=R52, \
    Rinv=R32, Dxi=R40, MulB=R48, MulA=R56, MulR=R64, Prod=R64, \
    Lam=R72, Sqr=R80, PxN=R88, \
    Tmp=R96, SqrT=R96, Pt3T=R96, COfs=R122, BpL=R123, \
    Acc=R128, \
    uDesc=UR4, uHashSel=UR6, uCallI=UR8, uInvT=UR10, uCallH=UR12, uCallP=UR14 )
{
    [B------:R-:W0:-:S01]    LDC R1, c[0x0][0x37c]
    [B------:R-:W1:-:S01]    S2R ThrID, SR_TID.X
    [B------:R-:W1:-:S01]    S2R BlockID, SR_CTAID.X
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00
    [B------:R-:W-:-:S01]    UMOV uCallI1, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    UMOV uCallH1, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    UMOV uCallP1, 0xFFFFFFFF
    [B------:R-:W2:-:S01]    LDCU.64 uDesc, c[0x0][0x358]
    [B------:R-:W3:-:S01]    LDC.64 AddrX, c[0x0][0x380]
    [B------:R-:W3:-:S01]    LDC.64 AddrY, c[0x0][0x388]
    [B------:R-:W3:-:S01]    LDC.64 AddrS, c[0x0][0x390]
    [B------:R-:W3:-:S02]    LDC.64 Thr,   c[0x0][0x3a0]

    [B0-----:R-:W-:-:S02]    IADD3 R1, PT, PT, R1, -0x4000, RZ

    [B-1----:R-:W-:-:S05]    IMAD gID, BlockID, 0x100, ThrID

    [B---3--:R-:W-:-:S05]    ISETP.GE.U32.AND P0, PT, gID, Thr0, PT
    [B------:R-:W-:Y:S13]    ISETP.EQ.U32.AND P0, PT, Thr1, RZ, P0
    [B------:R-:W-:Y:S05] @P0 EXIT

    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrY, gID, 0x20, AddrY
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 AddrS, gID, 0x20, AddrS

    [B--2---:R4:W0:-:S01]    LDG.E.128 PntX0, desc[uDesc][AddrX.64]
    [B------:R4:W0:-:S01]    LDG.E.128 PntX4, desc[uDesc][AddrX.64+0x10]
    [B------:R4:W1:-:S01]    LDG.E.128 PntY0, desc[uDesc][AddrY.64]
    [B------:R4:W1:-:S01]    LDG.E.128 PntY4, desc[uDesc][AddrY.64+0x10]
    [B----4-:R-:W-:-:S01]    NOP

    [B------:R-:W5:-:S02]    LDC Half, c[0x0][0x3a8]
    [B-----5:R-:W-:-:S05]    IMAD BDone, RZ, RZ, RZ
//@@LOOPTOP_BEGIN
.label_batch_loop:
    [B------:R-:W5:-:S02]    LDC BpL, c[0x0][0x3ac]
    [B-----5:R-:W-:Y:S13]    ISETP.GE.U32.AND P1, PT, BDone, BpL, PT
    [B------:R-:W-:Y:S05] @P1 BRA.U `(.label_batch_end)
//@@LOOPTOP_END

//@@HASHS_BEGIN
    [B01----:R-:W-:-:S04]    LOP3.LUT R52, PntY0, 0x1, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    IADD3 R52, R52, 0x2, RZ
    [B------:R-:W-:-:S02]    IMAD R54, RZ, RZ, PntX0
    [B------:R-:W-:-:S02]    MOV  R55, PntX1
    [B------:R-:W-:-:S02]    IMAD R56, RZ, RZ, PntX2
    [B------:R-:W-:-:S02]    MOV  R57, PntX3
    [B------:R-:W-:-:S02]    IMAD R58, RZ, RZ, PntX4
    [B------:R-:W-:-:S02]    MOV  R59, PntX5
    [B------:R-:W-:-:S02]    IMAD R60, RZ, RZ, PntX6
    [B------:R-:W-:-:S06]    MOV  R61, PntX7
    [B------:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_getHash160_33) //RCASM:CallPointH0
call_func getHash160_33(Ri=R54, Rio=R52, Rt=MulB, URt=uHashSel, Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH0
    [B------:R-:W-:-:S06]    MOV R60, 0xc040
    [B------:R-:W5:-:S02]    LDC.64 R62, c[0x3][R60+0x8]
    [B------:R-:W-:-:S04]    BSSY B0, `(.hsrc_s)
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P2, PT, R54, R62, PT
    [B------:R-:W-:Y:S05] @!P2 BRA `(.hskip_s)
    [B------:R-:W5:-:S02]    LDC.64 R48, c[0x3][R60+0x0]
    [B-----5:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R52, R48, P2
    [B------:R-:W5:-:S02]    LDC    R50, c[0x3][R60+0x10]
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R53, R49, P3
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R55, R63, P3
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P3, PT, R56, R50, P3
    [B------:R-:W-:Y:S05] @!P3 BRA `(.hskip_s)
    [B------:R-:W-:-:S02]    MOV R72, RZ //extra = 0
    [B------:R-:W-:-:S02]    MOV R73, BDone
    [B------:R-:W-:-:S02]    MOV R74, Half
    [B------:R-:W-:-:S04]    MOV R75, gID
    [B------:R-:W-:-:S01]    UMOV uCallP0, `(.relN_end_getPublish2) //RCASM:CallPointP0
call_func getPublish2(Ri=R72, Rt=MulB, URt=uDesc, Pt=3, Ret="[B------:R-:W-:-:S06] BRXU.U uCallP, 0x00") //RCASM:CallPointP0
    [B------:R-:W-:Y:S05] @P3 EXIT
.hskip_s:
    [B------:R-:W-:-:S05]    BSYNC B0
.hsrc_s:
//@@HASHS_END

//@@CALL_BEGIN
//@@CALL_END

//@@LOCAL_BEGIN
//@@LOCAL_END

//@@SUFP_BEGIN
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x0]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x8]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x10]
    [B------:R-:W4:-:S01]    LDC.64 MulB6, c[0x3][0x18]
    [B------:R-:W5:-:S02]    LDC Half, c[0x0][0x3a8]
    [B0---4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulA, Pt=0)

    [B-----5:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulA0
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulA4

    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ
    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT
    [B------:R-:W-:Y:S05] @!P0 BRA.U `(.label_sufp_end)

.label_sufp_loop:
    [B---3--:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=MulA, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    IMAD MulA0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV MulA1, MulR1
    [B------:R-:W-:-:S01]    IMAD MulA2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV MulA3, MulR3
    [B------:R-:W-:-:S01]    IMAD MulA4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV MulA5, MulR5
    [B------:R-:W-:-:S01]    IMAD MulA6, RZ, RZ, MulR6
    [B------:R-:W-:-:S02]    MOV MulA7, MulR7
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulA0
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulA4

    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ
    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT
    [B------:R-:W-:Y:S05] @P0 BRA.U `(.label_sufp_loop)
.label_sufp_end:
//@@SUFP_END

//@@INV_BEGIN
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)

    [B---3--:R-:W0:-:S01]    LDL.128 MulA0, [R1]
    [B------:R-:W0:-:S02]    LDL.128 MulA4, [R1+0x10]

    [B0-----:R-:W-:-:S01]    NOP
inc_func MulMod256(RFirst=MulB, RSecond=MulA, Ro=MulR, Rt=Tmp, Pt=0)

    [B------:R-:W-:-:S01]    IMAD Inv0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV Inv1, MulR1
    [B------:R-:W-:-:S01]    IMAD Inv2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV Inv3, MulR3
    [B------:R-:W-:-:S01]    IMAD Inv4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV Inv5, MulR5
    [B------:R-:W-:-:S01]    IMAD Inv6, RZ, RZ, MulR6
    [B------:R-:W-:-:S05]    MOV Inv7, MulR7

    [B------:R-:W-:-:S01]    UMOV uCallI0, `(.relN_end_InvMod256) //RCASM:CallPointF
call_func InvMod256(Ri=Inv, Ro=InvO, Rt=InvT, URt=uInvT, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallI, 0x00") //RCASM:CallPointF
//@@INV_END

//@@WALK_BEGIN
    [B------:R-:W-:-:S01]    IMAD Rinv0, RZ, RZ, InvO0
    [B------:R-:W-:-:S01]    MOV Rinv1, InvO1
    [B------:R-:W-:-:S01]    IMAD Rinv2, RZ, RZ, InvO2
    [B------:R-:W-:-:S01]    MOV Rinv3, InvO3
    [B------:R-:W-:-:S01]    IMAD Rinv4, RZ, RZ, InvO4
    [B------:R-:W-:-:S01]    MOV Rinv5, InvO5
    [B------:R-:W-:-:S01]    IMAD Rinv6, RZ, RZ, InvO6
    [B------:R-:W-:-:S01]    MOV Rinv7, InvO7
//@@ACCINIT_BEGIN
//@@ACCINIT_END
    [B------:R-:W-:-:S01]    MOV COfs, RZ
    [B------:R-:W-:-:S05]    IMAD Idx, Half, 0x10, RZ
    [B------:R-:W-:-:S05]    IADD3 Idx, PT, PT, Idx, -0x20, RZ

.label_walk_loop:
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W0:-:S01]    LDL.128 MulA0, [SAdr]
    [B------:R-:W0:-:S02]    LDL.128 MulA4, [SAdr+0x10]
    [B0-----:R-:W-:-:S01]    NOP
inc_func MulMod256(RFirst=MulA, RSecond=Rinv, Ro=Dxi, Rt=Tmp, Pt=0)
//@@WACC_BEGIN
//@@WACC_END

//@@PLUS_BEGIN
    [B-1----:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x40]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x48]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x50]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x58]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, MulA0, 0x1, RZ, 0xc0, !PT
//@@HASHP_BEGIN
    [B------:R-:W-:-:S02]    IADD3 R52, TmpA, 0x2, RZ
    [B------:R-:W-:-:S02]    IMAD R54, RZ, RZ, PxN0
    [B------:R-:W-:-:S02]    MOV  R55, PxN1
    [B------:R-:W-:-:S02]    IMAD R56, RZ, RZ, PxN2
    [B------:R-:W-:-:S02]    MOV  R57, PxN3
    [B------:R-:W-:-:S02]    IMAD R58, RZ, RZ, PxN4
    [B------:R-:W-:-:S02]    MOV  R59, PxN5
    [B------:R-:W-:-:S02]    IMAD R60, RZ, RZ, PxN6
    [B------:R-:W-:-:S06]    MOV  R61, PxN7
    [B------:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_getHash160_33) //RCASM:CallPointH1
call_func getHash160_33(Ri=R54, Rio=R52, Rt=MulB, URt=uHashSel, Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH1
    [B------:R-:W-:-:S06]    MOV R60, 0xc040
    [B------:R-:W5:-:S02]    LDC.64 R62, c[0x3][R60+0x8]
    [B------:R-:W-:-:S04]    BSSY B0, `(.hsrc_p)
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P2, PT, R54, R62, PT
    [B------:R-:W-:Y:S05] @!P2 BRA `(.hskip_p)
    [B------:R-:W5:-:S02]    LDC.64 R48, c[0x3][R60+0x0]
    [B-----5:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R52, R48, P2
    [B------:R-:W5:-:S02]    LDC    R50, c[0x3][R60+0x10]
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R53, R49, P3
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R55, R63, P3
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P3, PT, R56, R50, P3
    [B------:R-:W-:Y:S05] @!P3 BRA `(.hskip_p)
    [B------:R-:W-:-:S04]    SHF.R.U32 R72, COfs, 0x5, RZ
    [B------:R-:W-:-:S04]    IADD3 R72, R72, 0x1, RZ //extra = i+1
    [B------:R-:W-:-:S02]    MOV R73, BDone
    [B------:R-:W-:-:S02]    MOV R74, Half
    [B------:R-:W-:-:S04]    MOV R75, gID
    [B------:R-:W-:-:S01]    UMOV uCallP0, `(.relN_end_getPublish2) //RCASM:CallPointP1
call_func getPublish2(Ri=R72, Rt=MulB, URt=uDesc, Pt=3, Ret="[B------:R-:W-:-:S06] BRXU.U uCallP, 0x00") //RCASM:CallPointP1
    [B------:R-:W-:Y:S05] @P3 EXIT
.hskip_p:
    [B------:R-:W-:-:S05]    BSYNC B0
.hsrc_p:
//@@HASHP_END
//@@PACC_BEGIN
//@@PACC_END
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x8040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x8048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x8050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x8058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, MulA0, 0x1, RZ, 0xc0, !PT
//@@HASHM_BEGIN
    [B------:R-:W-:-:S02]    IADD3 R52, TmpA, 0x2, RZ
    [B------:R-:W-:-:S02]    IMAD R54, RZ, RZ, PxN0
    [B------:R-:W-:-:S02]    MOV  R55, PxN1
    [B------:R-:W-:-:S02]    IMAD R56, RZ, RZ, PxN2
    [B------:R-:W-:-:S02]    MOV  R57, PxN3
    [B------:R-:W-:-:S02]    IMAD R58, RZ, RZ, PxN4
    [B------:R-:W-:-:S02]    MOV  R59, PxN5
    [B------:R-:W-:-:S02]    IMAD R60, RZ, RZ, PxN6
    [B------:R-:W-:-:S06]    MOV  R61, PxN7
    [B------:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_getHash160_33) //RCASM:CallPointH2
call_func getHash160_33(Ri=R54, Rio=R52, Rt=MulB, URt=uHashSel, Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH2
    [B------:R-:W-:-:S06]    MOV R60, 0xc040
    [B------:R-:W5:-:S02]    LDC.64 R62, c[0x3][R60+0x8]
    [B------:R-:W-:-:S04]    BSSY B0, `(.hsrc_m)
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P2, PT, R54, R62, PT
    [B------:R-:W-:Y:S05] @!P2 BRA `(.hskip_m)
    [B------:R-:W5:-:S02]    LDC.64 R48, c[0x3][R60+0x0]
    [B-----5:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R52, R48, P2
    [B------:R-:W5:-:S02]    LDC    R50, c[0x3][R60+0x10]
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R53, R49, P3
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R55, R63, P3
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P3, PT, R56, R50, P3
    [B------:R-:W-:Y:S05] @!P3 BRA `(.hskip_m)
    [B------:R-:W-:-:S04]    SHF.R.U32 R72, COfs, 0x5, RZ
    [B------:R-:W-:-:S04]    IADD3.X R72, PT, PT, RZ, ~R72, RZ, !PT, !PT //extra = ~i = -(i+1)
    [B------:R-:W-:-:S02]    MOV R73, BDone
    [B------:R-:W-:-:S02]    MOV R74, Half
    [B------:R-:W-:-:S04]    MOV R75, gID
    [B------:R-:W-:-:S01]    UMOV uCallP0, `(.relN_end_getPublish2) //RCASM:CallPointP2
call_func getPublish2(Ri=R72, Rt=MulB, URt=uDesc, Pt=3, Ret="[B------:R-:W-:-:S06] BRXU.U uCallP, 0x00") //RCASM:CallPointP2
    [B------:R-:W-:Y:S05] @P3 EXIT
.hskip_m:
    [B------:R-:W-:-:S05]    BSYNC B0
.hsrc_m:
//@@HASHM_END
//@@PACCM_BEGIN
//@@PACCM_END
//@@PLUS_END
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=Rinv, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    IMAD Rinv0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV Rinv1, MulR1
    [B------:R-:W-:-:S01]    IMAD Rinv2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV Rinv3, MulR3
    [B------:R-:W-:-:S01]    IMAD Rinv4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV Rinv5, MulR5
    [B------:R-:W-:-:S01]    IMAD Rinv6, RZ, RZ, MulR6
    [B------:R-:W-:-:S02]    MOV Rinv7, MulR7

    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, 0x20, RZ
    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, Idx, PT
    [B------:R-:W-:Y:S05] @P0 BRA.U `(.label_walk_loop)

    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W0:-:S01]    LDL.128 MulA0, [SAdr]
    [B------:R-:W0:-:S02]    LDL.128 MulA4, [SAdr+0x10]
    [B0-----:R-:W-:-:S01]    NOP
inc_func MulMod256(RFirst=MulA, RSecond=Rinv, Ro=Dxi, Rt=Tmp, Pt=0)
//@@WACCT_BEGIN
//@@WACCT_END
//@@PLUST_BEGIN
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x8040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x8048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x8050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x8058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, MulA0, 0x1, RZ, 0xc0, !PT
//@@HASHT_BEGIN
    [B------:R-:W-:-:S02]    IADD3 R52, TmpA, 0x2, RZ
    [B------:R-:W-:-:S02]    IMAD R54, RZ, RZ, PxN0
    [B------:R-:W-:-:S02]    MOV  R55, PxN1
    [B------:R-:W-:-:S02]    IMAD R56, RZ, RZ, PxN2
    [B------:R-:W-:-:S02]    MOV  R57, PxN3
    [B------:R-:W-:-:S02]    IMAD R58, RZ, RZ, PxN4
    [B------:R-:W-:-:S02]    MOV  R59, PxN5
    [B------:R-:W-:-:S02]    IMAD R60, RZ, RZ, PxN6
    [B------:R-:W-:-:S06]    MOV  R61, PxN7
    [B------:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_getHash160_33) //RCASM:CallPointH3
call_func getHash160_33(Ri=R54, Rio=R52, Rt=MulB, URt=uHashSel, Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH3
    [B------:R-:W-:-:S06]    MOV R60, 0xc040
    [B------:R-:W5:-:S02]    LDC.64 R62, c[0x3][R60+0x8]
    [B------:R-:W-:-:S04]    BSSY B0, `(.hsrc_t)
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P2, PT, R54, R62, PT
    [B------:R-:W-:Y:S05] @!P2 BRA `(.hskip_t)
    [B------:R-:W5:-:S02]    LDC.64 R48, c[0x3][R60+0x0]
    [B-----5:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R52, R48, P2
    [B------:R-:W5:-:S02]    LDC    R50, c[0x3][R60+0x10]
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R53, R49, P3
    [B------:R-:W-:-:S05]    ISETP.EQ.U32.AND P3, PT, R55, R63, P3
    [B-----5:R-:W-:Y:S13]    ISETP.EQ.U32.AND P3, PT, R56, R50, P3
    [B------:R-:W-:Y:S05] @!P3 BRA `(.hskip_t)
    [B------:R-:W-:-:S04]    SHF.R.U32 R72, COfs, 0x5, RZ
    [B------:R-:W-:-:S04]    IADD3.X R72, PT, PT, RZ, ~R72, RZ, !PT, !PT //extra = ~i = -(i+1)
    [B------:R-:W-:-:S02]    MOV R73, BDone
    [B------:R-:W-:-:S02]    MOV R74, Half
    [B------:R-:W-:-:S04]    MOV R75, gID
    [B------:R-:W-:-:S01]    UMOV uCallP0, `(.relN_end_getPublish2) //RCASM:CallPointP3
call_func getPublish2(Ri=R72, Rt=MulB, URt=uDesc, Pt=3, Ret="[B------:R-:W-:-:S06] BRXU.U uCallP, 0x00") //RCASM:CallPointP3
    [B------:R-:W-:Y:S05] @P3 EXIT
.hskip_t:
    [B------:R-:W-:-:S05]    BSYNC B0
.hsrc_t:
//@@HASHT_END
//@@PACCT_BEGIN
//@@PACCT_END
//@@PLUST_END
//@@WALK_END

//@@JUMP_BEGIN
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=Rinv, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    IMAD Rinv0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV Rinv1, MulR1
    [B------:R-:W-:-:S01]    IMAD Rinv2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV Rinv3, MulR3
    [B------:R-:W-:-:S01]    IMAD Rinv4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV Rinv5, MulR5
    [B------:R-:W-:-:S01]    IMAD Rinv6, RZ, RZ, MulR6
    [B------:R-:W-:-:S02]    MOV Rinv7, MulR7

    [B------:R-:W-:-:S01]    IMAD Dxi0, RZ, RZ, Rinv0
    [B------:R-:W-:-:S01]    MOV Dxi1, Rinv1
    [B------:R-:W-:-:S01]    IMAD Dxi2, RZ, RZ, Rinv2
    [B------:R-:W-:-:S01]    MOV Dxi3, Rinv3
    [B------:R-:W-:-:S01]    IMAD Dxi4, RZ, RZ, Rinv4
    [B------:R-:W-:-:S01]    MOV Dxi5, Rinv5
    [B------:R-:W-:-:S01]    IMAD Dxi6, RZ, RZ, Rinv6
    [B------:R-:W-:-:S02]    MOV Dxi7, Rinv7
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x20]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x28]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x30]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x38]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x0]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x8]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x10]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x18]
    [B----4-:R-:W-:-:S01]    NOP
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S01]    IMAD PntX0, RZ, RZ, PxN0
    [B------:R-:W-:-:S01]    MOV PntX1, PxN1
    [B------:R-:W-:-:S01]    IMAD PntX2, RZ, RZ, PxN2
    [B------:R-:W-:-:S01]    MOV PntX3, PxN3
    [B------:R-:W-:-:S01]    IMAD PntX4, RZ, RZ, PxN4
    [B------:R-:W-:-:S01]    MOV PntX5, PxN5
    [B------:R-:W-:-:S01]    IMAD PntX6, RZ, RZ, PxN6
    [B------:R-:W-:-:S01]    MOV PntX7, PxN7
    [B------:R-:W-:-:S01]    IMAD PntY0, RZ, RZ, MulA0
    [B------:R-:W-:-:S01]    MOV PntY1, MulA1
    [B------:R-:W-:-:S01]    IMAD PntY2, RZ, RZ, MulA2
    [B------:R-:W-:-:S01]    MOV PntY3, MulA3
    [B------:R-:W-:-:S01]    IMAD PntY4, RZ, RZ, MulA4
    [B------:R-:W-:-:S01]    MOV PntY5, MulA5
    [B------:R-:W-:-:S01]    IMAD PntY6, RZ, RZ, MulA6
    [B------:R-:W-:-:S05]    MOV PntY7, MulA7
//@@JUMP_END

//@@LOOPEND_BEGIN
    [B------:R-:W-:-:S05]    IADD3 BDone, PT, PT, BDone, 0x1, RZ
    [B------:R-:W-:Y:S05]    BRA.U `(.label_batch_loop)
.label_batch_end:
//@@LOOPEND_END

    [B------:R-:W3:-:S01]    LDC.64 AddrX, c[0x0][0x380]
    [B------:R-:W3:-:S01]    LDC.64 AddrY, c[0x0][0x388]
    [B------:R-:W3:-:S01]    LDC.64 AddrS, c[0x0][0x390]
    [B------:R-:W3:-:S02]    LDC.64 AddrC, c[0x0][0x398]
    [B---3--:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrY, gID, 0x20, AddrY
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrS, gID, 0x20, AddrS
    [B------:R-:W-:-:S05]    IMAD.WIDE.U32 AddrC, gID, 0x20, AddrC

//@@STOREPROD_BEGIN
//@@STOREPROD_END
//@@STOREPNTX_BEGIN
    [B0-----:R-:W-:-:S01]    STG.E.128 desc[uDesc][AddrX.64], PntX0
    [B------:R-:W-:-:S01]    STG.E.128 desc[uDesc][AddrX.64+0x10], PntX4
//@@STOREPNTX_END
//@@STOREACC_BEGIN
//@@STOREACC_END
//@@STOREINV_BEGIN
//@@STOREINV_END
//@@STOREPTS_BEGIN
//@@STOREPTS_END
//@@STOREWALK_BEGIN
//@@STOREWALK_END
//@@STOREPNTY_BEGIN
    [B-1----:R-:W-:-:S01]    STG.E.128 desc[uDesc][AddrY.64], PntY0
    [B------:R-:W-:-:S01]    STG.E.128 desc[uDesc][AddrY.64+0x10], PntY4
//@@STOREPNTY_END
//@@STOREID_BEGIN
    [B------:R-:W2:-:S01]    LDG.E.128 Scal0, desc[uDesc][AddrS.64] //s1 = start_scalars + BDone*B
    [B------:R-:W2:-:S01]    LDG.E.128 Scal4, desc[uDesc][AddrS.64+0x10]
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Tmp0, BDone, Half, RZ
    [B--2---:R-:W-:-:S04]    IADD3 Scal0, P0, PT, Scal0, Tmp0, RZ
    [B------:R-:W-:-:S04]    IADD3.X Scal1, P0, PT, Scal1, Tmp1, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal2, P0, PT, Scal2, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal3, P0, PT, Scal3, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal4, P0, PT, Scal4, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal5, P0, PT, Scal5, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal6, P0, PT, Scal6, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal7, PT, PT, Scal7, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S01]    STG.E.128 desc[uDesc][AddrS.64], Scal0
    [B------:R-:W-:-:S05]    STG.E.128 desc[uDesc][AddrS.64+0x10], Scal4
//@@STOREID_END
//@@STORELAM_BEGIN
//@@STORELAM_END

    [B------:R-:W-:Y:S05]    EXIT
}
