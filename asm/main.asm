CONST GROUP_SIZE = 24

CONST JMP_CNT = 512
CONST JMP_MASK = (JMP_CNT - 1)
CONST JMP_MASK_ADV = (2048 - 1)

CONST DPTABLE_MAX_CNT = 16
CONST DP_FLAG = 0x0800
CONST INV_FLAG = 0x0200
CONST JMP2_FLAG = 0x0400
CONST MD_LEN = 10

KERNEL KernelA(regcnt=255, TmpNineA=R0, jmp_ind=R9, ThrID=R10, BlockID=R11, invNine=R12, LaneID=R21, gID=R22, TmpA=R23, \
xOfs=R24, yOfs=R25, cOfs=R26, dOfs=R27, TmpTmpMax=R28, jPntX=R28, jPntY=R36, PntX=R44, PntY=R52, TmpEightA=R60, dxEight=R68, \
nxtPntX=R76, TmpTmp=R84, bMask=R113, NineTen=R114, TmpB=R114, TmpC=R115, TmpEightB=R116, EightSaveA=R124, \
EightSaveB=R132, EightSaveC=R140, SaveRegs=R148, EightD=R148, EightE=R156, EightF=R164, EightG=R172, EightH=R180, \
TmpTmpB=R188, nxtPntY=R244, LS=R252, \
CPolicy=UR0, IterCnt=UR2, BlockCnt=UR3, L2Base=UR4, j12Base=UR6, DbgBase=UR8, \
uGrStride=UR10, uPartStride=UR11, uGrLoopPnt=UR12, uGrLoopHlp=UR14, uGrLoopCnt=UR15, \
uItLoopPnt=UR16, uItLoopHlp=UR18, uItLoopInd=UR19, InvBase=UR20, uStopThr=UR22, uHalfPartStride=UR23, \
uRetA=UR24, uRetB=UR26, uCallB=UR28, uTmpA=UR30, uCallInv=UR32, DPTableBase=UR34, L1S2Base=UR36, \
LastPntsBase=UR38, uDP_Mask=UR40, JumpsListBase=UR42, uThrCnt=UR44, uKangGrInd=UR45, uKangCnt=UR46, \
DPTableBaseB=UR48, uBlockID=UR50, uGrInd=UR51, uOne=UR52, uPartStrideDouble=UR53, uIterCntOrig=UR54, \
uLastPntInd=UR55, uTmpTmp=UR56 )
{
    [B------:R-:W0:-:S01]    S2R ThrID, SR_TID.X
    [B------:R-:W0:-:S01]    S2R BlockID, SR_CTAID.X
    [B------:R-:W0:-:S01]    S2UR uBlockID, SR_CTAID.X
#IF {SM_VER} == 89
    [B------:R-:W-:-:S01]    ULDC.64 CPolicy, c[0x0][0x118]
    [B------:R-:W-:-:S01]    ULDC.64 L2Base, c[0x0][0x160]
    [B------:R-:W-:-:S01]    ULDC.64 j12Base, c[0x0][0x168]
    [B------:R-:W-:-:S01]    ULDC.64 DPTableBase, c[0x0][0x170]
    [B------:R-:W-:-:S01]    ULDC.64 JumpsListBase, c[0x0][0x180]
    [B------:R-:W-:-:S01]    ULDC.64 LastPntsBase, c[0x0][0x188]
    [B------:R-:W-:-:S01]    ULDC.64 DbgBase, c[0x0][0x190]
    [B------:R-:W-:-:S01]    ULDC.64 L1S2Base, c[0x0][0x198]
    [B------:R-:W-:-:S01]    ULDC IterCnt, c[0x0][0x1A8]
    [B------:R-:W-:-:S01]    ULDC uIterCntOrig, c[0x0][0x1A8]
    [B------:R-:W-:-:S01]    ULDC BlockCnt, c[0x0][0x1AC]
    [B------:R-:W-:-:S01]    ULDC uStopThr, c[0x0][0x1B0]
    [B------:R-:W-:-:S01]    ULDC uDP_Mask, c[0x0][0x1B4]
#ELSE
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00 //sm_120: URZ is UR63 (not UR255), so it must be zeroed
    [B------:R-:W0:-:S01]    LDCU.64 CPolicy, c[0x0][0x358] //zero cache policy
    [B------:R-:W0:-:S01]    LDCU.64 L2Base, c[0x0][{0x160 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU.64 j12Base, c[0x0][{0x168 + 0x220}] //JmpTable1
    [B------:R-:W0:-:S01]    LDCU.64 DPTableBase, c[0x0][{0x170 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU.64 JumpsListBase, c[0x0][{0x180 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU.64 LastPntsBase, c[0x0][{0x188 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU.64 DbgBase, c[0x0][{0x190 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU.64 L1S2Base, c[0x0][{0x198 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU IterCnt, c[0x0][{0x1A8 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU uIterCntOrig, c[0x0][{0x1A8 + 0x220}]
    [B------:R-:W0:-:S01]    LDCU BlockCnt, c[0x0][{0x1AC + 0x220}] //blocks that work on points (SM_Total-SM_INV_CNT)
    [B------:R-:W0:-:S01]    LDCU uStopThr, c[0x0][{0x1B0 + 0x220}] //min number of live producers when work must be stopped; must be >=32
    [B------:R-:W0:-:S02]    LDCU uDP_Mask, c[0x0][{0x1B4 + 0x220}]
#ENDIF
    [B0-----:R-:W-:-:S03]    IMAD gID, BlockID, 0x100, ThrID
    [B------:R-:W-:-:S04]    UIMAD uThrCnt, BlockCnt, 0x100, URZ
    [B------:R-:W-:-:S04]    UIMAD uKangCnt, uThrCnt, {GROUP_SIZE}, URZ
    [B------:R-:W-:-:S04]    UIMAD uGrStride, BlockCnt, {256 * 32}, URZ //gr0: X for 256*BlockCnt threads, then gr1, etc
    [B------:R-:W-:-:S04]    UIMAD uPartStride, uGrStride, {GROUP_SIZE}, URZ //distance between X, Y, C
    [B------:R-:W-:-:S04]    UIMAD uPartStrideDouble, uGrStride, {2 * GROUP_SIZE}, URZ
    [B------:R-:W-:-:S04]    UIMAD uHalfPartStride, uGrStride, {GROUP_SIZE / 2}, URZ
    [B------:R-:W-:-:S04]    UIMAD.WIDE.U32 InvBase, uPartStride, 0x03, L2Base
    [B------:R-:W-:-:S05]    LOP3.LUT LaneID, ThrID, 0x1F, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    UMOV uCallInv1, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    UMOV uOne, 0x01
    [B------:R-:W-:-:S06]    UIADD3 uTmpTmp1, IterCnt, {MD_LEN}, URZ
    [B------:R-:W-:-:S03]    UIMAD uTmpTmp0, uTmpTmp1, {GROUP_SIZE * 256 * 2}, URZ
    [B------:R-:W-:-:S01]    UIMAD.WIDE DPTableBaseB, uKangCnt, 0x04, DPTableBase
    [B------:R-:W-:-:S01]    UIMAD.WIDE  JumpsListBase, uBlockID, uTmpTmp0, JumpsListBase

    [B------:R-:W-:Y:S13]    ISETP.GE.AND P0, PT, BlockID, BlockCnt, PT
    [B------:R-:W-:-:S01] @P0 BRA.CONV `(.inv_sm_begin)

    [B------:R-:W-:-:S01]    MOV TmpA, {12 - 1}
    [B------:R-:W-:-:S01]    IMAD xOfs, ThrID, 0x20, RZ
    [B------:R-:W-:-:S02]    IMAD dOfs, ThrID, 0x2, RZ
.label_lds_loop:
    [B------:R-:W-:-:S01]    ISETP.EQ.AND P0, PT, TmpA, 0x00, PT
    [B------:R4:W0:-:S02]    LDG.E.NA.EFL2.256.STRONG_GPU jPntX4, jPntX0, [xOfs.U32 + j12Base], 0xFF
    [B------:R-:W-:-:S01]    IADD3 TmpA, TmpA, -0x01, RZ
    [B----4-:R-:W-:-:S02]    IADD3 xOfs, xOfs, 0x2000, RZ
    [B0-----:R5:W-:-:S02]    STS.128 [dOfs.X16], jPntX0
    [B------:R5:W-:-:S02]    STS.128 [dOfs.X16 + 0x10], jPntX4
    [B-----5:R-:W-:-:S02]    IADD3 dOfs, dOfs, 0x200, RZ
    [B------:R-:W-:Y:S01] @!P0 BRA.U `(.label_lds_loop)
.label_lds_end:
    [B------:R-:W-:-:S05]    IMAD yOfs, gID, 0x04, RZ
    [B------:R-:W0:-:S02]    LDG.E LS, [yOfs.U32 + L1S2Base]
    [B------:R-:W-:Y:S06]    BAR.SYNC.DEFER_BLOCKING 0x0
    [B------:R-:W-:-:S01]    UMOV uRetB1, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    UMOV uCallB1, 0x00
    [B------:R-:W-:-:S01]    MOV NineTen1, 0x00
    [B------:R-:W-:-:S01]    UMOV uRetA1, 0xFFFFFFFF

    [B------:R-:W-:-:S05]    IMAD xOfs, gID, 0x20, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs4, SaveRegs0, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs12, SaveRegs8, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs20, SaveRegs16, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs28, SaveRegs24, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs36, SaveRegs32, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs44, SaveRegs40, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs52, SaveRegs48, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs60, SaveRegs56, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs68, SaveRegs64, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs76, SaveRegs72, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs84, SaveRegs80, [xOfs.U32 + L2Base], 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W0:-:S02]    LDG.E.NA.ELL2.256.STRONG_GPU SaveRegs92, SaveRegs88, [xOfs.U32 + L2Base], 0xFF
    [B0-----:R-:W-:-:S03]    NOP

    [B------:R-:W-:-:S05]    IMAD xOfs, gID, 0x20, RZ
    [B------:R-:W-:-:S05]    IADD3 cOfs, xOfs, uPartStride, RZ
    [B------:R-:W-:-:S05]    IADD3 cOfs, cOfs, uPartStride, RZ
    [B------:R-:W-:-:S05]    ISETP.NE.AND P6, PT, RZ, RZ, PT
    [B------:R-:W-:-:S01]    UMOV uRetA0, `(.relN_Calc_ToInv_end) + 0x10 //+0x10: the return skips the next line
    [B------:R-:W-:-:S01]    BRXU.U URZ, `(.Calc_ToInv_begin)
    [B012345:R-:W-:-:S02]    NOP

    [B------:R-:W-:-:S01]    UMOV uRetA0, `(.relN_Send_ToInv_end) + 0x10
    [B------:R-:W-:-:S01]    BRXU.U URZ, `(.Send_ToInv_begin)
    [B012345:R-:W-:-:S02]    NOP

    [B------:R-:W-:-:S01]    UIADD3 uLastPntInd, -IterCnt, {MD_LEN}, URZ
    [B------:R-:W-:-:S01]    UMOV uItLoopInd, 0x00
    [B------:R-:W-:-:S05]    UIMAD IterCnt, IterCnt, 0x02, URZ //one iteration covers a half-group
    [B------:R-:W-:-:S01]    UIADD3 IterCnt, IterCnt, -0x1, URZ
    [B------:R-:W-:-:S01]    UMOV uItLoopPnt0, 0x00
    [B------:R-:W-:-:S01]    UMOV uItLoopPnt1, 0x00
    [B------:R-:W-:-:S01]    UMOV uItLoopHlp, `(.relP_iter_loop_end) - 0x10

.iter_loop_beg:
    [B------:R-:W-:Y:S05]    MOV TmpA, uItLoopInd
    [B------:R-:W-:Y:S05]    LOP3.LUT TmpA, TmpA, 0x01, RZ, 0xC0, !PT
    [B------:R-:W-:Y:S08]    ISETP.EQ.AND P6, PT, TmpA, RZ, PT //even iteration: P6=True (first half-group)
    [B------:R-:W-:-:S05]    IMAD xOfs, gID, 0x20, RZ
    [B------:R-:W-:-:S05] @P6 IADD3 xOfs, xOfs, uHalfPartStride, RZ
    [B------:R-:W-:-:S05]    IADD3 cOfs, xOfs, uPartStride, RZ
    [B------:R-:W-:-:S05]    IADD3 cOfs, cOfs, uPartStride, RZ

    [B------:R-:W-:-:S01]    UMOV uRetA0, `(.relN_Calc_ToInv_end) + 0x10
    [B------:R-:W-:-:S01]    BRXU.U URZ, `(.Calc_ToInv_begin)
    [B012345:R-:W-:-:S02]    NOP

    [B------:R-:W-:-:S01]    UMOV uRetA0, `(.relN_Recv_Inv_end) + 0x10
    [B------:R-:W-:-:S01]    BRXU.U URZ, `(.Recv_Inv_begin)
    [B012345:R-:W-:-:S02]    NOP

    [B------:R-:W-:-:S01]    UMOV uRetA0, `(.relN_Send_ToInv_end) + 0x10
    [B------:R-:W-:-:S01]    BRXU.U URZ, `(.Send_ToInv_begin)
    [B012345:R-:W-:-:S02]    NOP

    [B------:R-:W-:-:S05]    IMAD xOfs, gID, 0x20, RZ
    [B------:R-:W-:-:S04] @!P6 IADD3 xOfs, xOfs, uHalfPartStride, RZ
    [B------:R-:W-:-:S04]    IADD3 xOfs, xOfs, uHalfPartStride, RZ
    [B------:R-:W-:-:S04]    IADD3 xOfs, xOfs, -uGrStride, RZ
    [B------:R-:W-:-:S04]    IADD3 yOfs, xOfs, uPartStride, RZ
    [B------:R-:W-:-:S04]    IADD3 cOfs, yOfs, uPartStride, RZ
    [B------:R-:W-:-:S04]    IADD3 cOfs, cOfs, -uGrStride, RZ
    [B------:R-:W-:-:S01]    UMOV uRetA0, `(.relN_Calc_NewPoints_end) + 0x10
    [B------:R-:W-:Y:S01]    BRXU.U URZ, `(.Calc_NewPoints_begin)
    [B012345:R-:W-:-:S02]    NOP

    [B------:R-:W-:-:S01]    UISETP.GE.AND UP0, UPT, uItLoopInd, IterCnt, UPT
    [B------:R-:W-:-:S01]    ULOP3.LUT UP1, URZ, uItLoopInd, 0x01, URZ, 0xC0, !UPT

    [B------:R-:W-:-:S05]    SHF.R.U32.HI TmpEightA2, RZ, 0x05, gID
    [B------:R-:W-:-:S03]    ISETP.EQ.AND P0, PT, LaneID, RZ, PT
    [B------:R-:W-:-:S05]    MOV TmpA, 0x01
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00 //restore URZ (UR63) for sm_120
    [B------:R-:W-:-:S05]    IMAD TmpTmp0, TmpEightA2, 0x04, RZ
    [B------:R4:W-:-:S02] @P0 RED.E.EL.ADD.STRONG_GPU [TmpTmp0.U32+InvBase + 0x400], TmpA
    [B----4-:R-:W-:Y:S02]    NOP

    [B------:R-:W-:-:S01] @UP0 UMOV uItLoopPnt0, uItLoopHlp
    [B------:R-:W-:-:S01] @UP1 UIADD3 uLastPntInd, uLastPntInd, 0x01, URZ
    [B------:R-:W-:-:S01]    UIADD3 uItLoopInd, uItLoopInd, 0x01, URZ
    [B------:R-:W-:-:S01]    BRXU.U uItLoopPnt, `(.iter_loop_beg)
.relP_iter_loop_end:
.label_main_end:
    [B------:R-:W-:Y:S08]    ISETP.EQ.AND P0, PT, LaneID, RZ, PT
    [B------:R-:W-:Y:S05]    MOV TmpA, 0x01
    [B------:R4:W-:-:S02] @P0 RED.E.EL.ADD.STRONG_GPU [RZ.U32+InvBase + 0x100], TmpA
    [B----4-:R-:W-:Y:S02]    NOP

    [B------:R-:W-:-:S05]    IMAD xOfs, gID, 0x20, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs0, SaveRegs4, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs8, SaveRegs12, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs16, SaveRegs20, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs24, SaveRegs28, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs32, SaveRegs36, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs40, SaveRegs44, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs48, SaveRegs52, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs56, SaveRegs60, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs64, SaveRegs68, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs72, SaveRegs76, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs80, SaveRegs84, 0xFF
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R4:W-:-:S02]    STG.E.NA.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], SaveRegs88, SaveRegs92, 0xFF

    [B------:R-:W-:-:S05]    IMAD yOfs, gID, 0x04, RZ
    [B------:R4:W-:-:S02]    STG.E [yOfs.U32 + L1S2Base], LS

    [B----4-:R-:W-:-:S05]    EXIT

.Calc_ToInv_begin: //anti-phase: P6=True means Calc_ToInv computes the second half-group
    [B------:R-:W-:-:S01] @!P6 MOV bMask, 0x01
    [B------:R-:W-:-:S01] @P6 MOV bMask, {1 << (GROUP_SIZE/2)}
    [B------:R4:W0:-:S02] @P6 LDG.E.EL.ELL2.256.STRONG_GPU PntX4, PntX0, [xOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01] @!P6 IMAD PntX0, RZ, RZ, SaveRegs0
    [B------:R-:W-:-:S01] @!P6 MOV PntX1, SaveRegs1
    [B------:R-:W-:-:S01] @!P6 IMAD PntX2, RZ, RZ, SaveRegs2
    [B------:R-:W-:-:S01] @!P6 MOV PntX3, SaveRegs3
    [B------:R-:W-:-:S01] @!P6 IMAD PntX4, RZ, RZ, SaveRegs4
    [B------:R-:W-:-:S01] @!P6 MOV PntX5, SaveRegs5
    [B------:R-:W-:-:S01] @!P6 IMAD PntX6, RZ, RZ, SaveRegs6
    [B------:R-:W-:-:S01] @!P6 MOV PntX7, SaveRegs7
    [B----4-:R-:W-:-:S05]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R-:W-:-:S01]    LOP3.LUT P0, RZ, LS, bMask, RZ, 0xC0, !PT
    [B------:R5:W1:-:S02] @P6 LDG.E.EL.ELL2.256.STRONG_GPU nxtPntX4, nxtPntX0, [xOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01] @!P6 IMAD nxtPntX0, RZ, RZ, SaveRegs8
    [B------:R-:W-:-:S01] @!P6 MOV nxtPntX1, SaveRegs9
    [B------:R-:W-:-:S01] @!P6 IMAD nxtPntX2, RZ, RZ, SaveRegs10
    [B------:R-:W-:-:S01] @!P6 MOV nxtPntX3, SaveRegs11
    [B------:R-:W-:-:S01] @!P6 IMAD nxtPntX4, RZ, RZ, SaveRegs12
    [B------:R-:W-:-:S01] @!P6 MOV nxtPntX5, SaveRegs13
    [B------:R-:W-:-:S01] @!P6 IMAD nxtPntX6, RZ, RZ, SaveRegs14
    [B------:R-:W-:-:S01] @!P6 MOV nxtPntX7, SaveRegs15

    [B0-----:R-:W-:Y:S05]    LOP3.LUT jmp_ind, PntX0, {JMP_MASK}, RZ, 0xC0, !PT
    [B------:R-:W3:-:S02] @!P0 LDS.128 jPntX0, [jmp_ind.X16]
    [B------:R-:W3:-:S02] @P0 LDS.128 jPntX0, [jmp_ind.X16 + {48 * 1024}]
    [B------:R-:W3:-:S02] @!P0 LDS.128 jPntX4, [jmp_ind.X16 + {16 * JMP_CNT}]
    [B------:R-:W3:-:S02] @P0 LDS.128 jPntX4, [jmp_ind.X16 + {16 * JMP_CNT + 48 * 1024}]

    [B---3--:R-:W-:-:S01]    SHF.L.U32 bMask, bMask, 0x01, RZ
inc_func SubMod256(RFirst=jPntX, RSecond=PntX, Ro=TmpEightB, Pt=0)
    [B------:R4:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + L2Base], TmpEightB0, TmpEightB4, 0xFF
    [B------:R-:W-:-:S01]    MOV TmpA, {GROUP_SIZE/2}
    [B------:R-:W-:-:S01]    UMOV uGrLoopCnt, 0x02
    [B------:R-:W-:-:S01]    UMOV uGrLoopPnt0, 0x00
    [B------:R-:W-:-:S01]    UMOV uGrLoopPnt1, 0x00
    [B------:R-:W-:-:S01]    UMOV uGrLoopHlp, `(.relP_group_loop1_end) - 0x10
.group_loop1_beg:
    [B------:R-:W-:-:S01]    LOP3.LUT P0, RZ, LS, bMask, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    UISETP.EQ.AND UP0, UPT, uGrLoopCnt, {GROUP_SIZE/2}, UPT

    [B-----5:R-:W-:-:S01]    IADD3 xOfs, xOfs, uGrStride, RZ
    [B------:R-:W-:-:S01]    ISETP.NE.AND P5, PT, TmpA, uGrLoopCnt, PT
    [B------:R-:W-:-:S01]    ISETP.NE.AND P4, PT, TmpA, uGrLoopCnt, !P6
    [B------:R-:W-:-:S01]    ISETP.NE.AND P3, PT, TmpA, uGrLoopCnt, P6

    [B-1----:R-:W-:Y:S05]    LOP3.LUT  jmp_ind, nxtPntX0, {JMP_MASK}, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    SHF.L.U32 bMask, bMask, 0x01, RZ
    [B------:R-:W-:-:S01]    UIMAD uCallB0, uGrLoopCnt, 0x90, URZ
    [B------:R-:W3:-:S02] @!P0 LDS.128 jPntX0, [jmp_ind.X16]
    [B------:R-:W3:-:S02] @P0 LDS.128 jPntX0, [jmp_ind.X16 + {48 * 1024}]
    [B------:R-:W3:-:S02] @!P0 LDS.128 jPntX4, [jmp_ind.X16 + {16 * JMP_CNT}]
    [B------:R-:W3:-:S02] @P0 LDS.128 jPntX4, [jmp_ind.X16 + {16 * JMP_CNT + 48 * 1024}]

    [B------:R-:W-:-:S01]    IMAD PntX0, RZ, RZ, nxtPntX0
    [B------:R-:W-:-:S01]    MOV PntX1, nxtPntX1
    [B------:R-:W-:-:S01]    IMAD PntX2, RZ, RZ, nxtPntX2
    [B------:R-:W-:-:S01]    MOV PntX3, nxtPntX3
    [B------:R-:W-:-:S01]    IMAD PntX4, RZ, RZ, nxtPntX4
    [B------:R-:W-:-:S01]    MOV PntX5, nxtPntX5
    [B------:R-:W-:-:S01]    IMAD PntX6, RZ, RZ, nxtPntX6
    [B------:R-:W-:-:S01]    MOV PntX7, nxtPntX7
    [B------:R5:W1:-:S01] @P3 LDG.E.EL.ELL2.256.STRONG_GPU nxtPntX4, nxtPntX0, [xOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01]    UIADD3 uRetB0, -uCallB0, `(.relN_LoadX_begin) + {0x10 - 0x80}, URZ
    [B------:R-:W-:Y:S01] @P4 BRXU.U uCallB, `(.LoadX_begin)
    [B---34-:R-:W-:-:S01]    IADD3 cOfs, cOfs, uGrStride, RZ //wait lds

inc_func CalcToInv_FusedA(RFirst=jPntX, RSub=PntX, RSecond=TmpEightB, Ro=TmpEightA, RCopy=TmpEightB, Rt=TmpTmp, Pt=P0)

    [B------:R4:W-:-:S02] @P5 STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + L2Base], TmpEightB0, TmpEightB4, 0xFF
    [B------:R-:W-:-:S01] @UP0 UMOV uGrLoopPnt0, uGrLoopHlp
    [B------:R-:W-:-:S01]    UIADD3 uGrLoopCnt, uGrLoopCnt, 0x01, URZ
    [B------:R-:W-:-:S01]    BRXU.U uGrLoopPnt, `(.group_loop1_beg)
.relP_group_loop1_end:
.relN_Calc_ToInv_end:
    [B------:R-:W-:-:S01] BRXU.U uRetA, 0x00

.Calc_NewPoints_begin:
    [B------:R-:W-:-:S03]    ULOP3.LUT UP1, URZ, uItLoopInd, 0x01, URZ, 0xC0, !UPT
    [B------:R-:W-:-:S01]    UMOV uCallB0, {0x90 * (GROUP_SIZE/2 - 1)}
    [B------:R5:W1:-:S01] @!P6 LDG.E.EL.ELL2.256.STRONG_GPU nxtPntX4, nxtPntX0, [xOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01]    UIADD3 uRetB0, -uCallB0, `(.relN_LoadX_begin) + {0x10 - 0x80}, URZ
    [B------:R-:W-:Y:S01] @P6 BRXU.U uCallB, `(.LoadX_begin)

    [B------:R5:W0:-:S01]    LDG.E.EL.ELL2.256.STRONG_GPU nxtPntY4, nxtPntY0, [yOfs.U32 + L2Base], 0xFF
    [B------:R4:W2:-:S01]    LDG.E.EL.ELL2.256.STRONG_GPU TmpEightB4, TmpEightB0, [cOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00 //restore URZ (UR63) for sm_120
    [B------:R-:W-:-:S01]    UIMAD uKangGrInd, uThrCnt, {GROUP_SIZE/2 - 1}, URZ
    [B------:R-:W-:-:S01]    UMOV uTmpA, 0x90
    [B------:R-:W-:-:S01]    UMOV uGrLoopCnt, {GROUP_SIZE/2 - 2}
    [B------:R-:W-:-:S01]    UMOV uGrLoopPnt0, 0x00
    [B------:R-:W-:-:S01]    UMOV uGrLoopPnt1, 0x00
    [B------:R-:W-:-:S01]    UMOV uGrInd, {(GROUP_SIZE/2 - 1) * (2 * 256)}

    [B------:R-:W-:-:S01] @UP1 UIMAD uKangGrInd, uThrCnt, {GROUP_SIZE/2}, uKangGrInd
    [B------:R-:W-:-:S01] @P6 MOV bMask, {1 << (GROUP_SIZE/2 - 1)}
    [B------:R-:W-:-:S01] @!P6 MOV bMask, {1 << (GROUP_SIZE - 1)}
    [B----4-:R-:W-:-:S01]    IADD3 cOfs, cOfs, -uGrStride, RZ

    [B------:R-:W-:-:S04]    UMOV uGrLoopHlp, `(.relP_group_loop2_end) - 0x10
.group_loop2_beg:
    [B------:R-:W-:-:S01]    LOP3.LUT P0, RZ, LS, bMask, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    ISETP.LE.AND P5, PT, RZ, uGrLoopCnt, PT
    [B------:R-:W-:-:S01]    ISETP.LE.AND P4, PT, RZ, uGrLoopCnt, !P6
    [B------:R-:W-:-:S01]    ISETP.LE.AND P3, PT, RZ, uGrLoopCnt, P6
    [B------:R-:W-:-:S01]    ISETP.LT.AND P2, PT, RZ, uGrLoopCnt, PT

    [B-----5:R-:W-:-:S01]    IADD3 xOfs, xOfs, -uGrStride, RZ //imitate next Pnt ofs
    [B------:R-:W-:-:S01]    IADD3 yOfs, yOfs, -uGrStride, RZ

    [B-1----:R-:W-:Y:S04]    LOP3.LUT  jmp_ind, nxtPntX0, {JMP_MASK}, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    UIMAD uCallB0, uGrLoopCnt, 0x90, URZ
    [B------:R-:W3:-:S02] @!P0 LDS.128 jPntX0, [jmp_ind.X16]
    [B------:R-:W3:-:S02] @P0 LDS.128 jPntX0, [jmp_ind.X16 + {48 * 1024}]
    [B------:R-:W3:-:S02] @!P0 LDS.128 jPntX4, [jmp_ind.X16 + {16 * JMP_CNT}]
    [B------:R-:W3:-:S02] @P0 LDS.128 jPntX4, [jmp_ind.X16 + {16 * JMP_CNT + 48 * 1024}]

    [B------:R-:W-:-:S01]    IMAD PntX0, RZ, RZ, nxtPntX0
    [B------:R-:W-:-:S01]    MOV PntX1, nxtPntX1
    [B------:R-:W-:-:S01]    IMAD PntX2, RZ, RZ, nxtPntX2
    [B------:R-:W-:-:S01]    MOV PntX3, nxtPntX3
    [B------:R-:W-:-:S01]    IMAD PntX4, RZ, RZ, nxtPntX4
    [B------:R-:W-:-:S01]    MOV PntX5, nxtPntX5
    [B------:R-:W-:-:S01]    IMAD PntX6, RZ, RZ, nxtPntX6
    [B------:R-:W-:-:S01]    MOV PntX7, nxtPntX7

    [B------:R4:W1:-:S01] @P4 LDG.E.EL.ELL2.256.STRONG_GPU nxtPntX4, nxtPntX0, [xOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01]    UIADD3 uRetB0, -uCallB0, `(.relN_LoadX_begin) + {0x10 - 0x80}, URZ
    [B------:R-:W-:Y:S01] @P3 BRXU.U uCallB, `(.LoadX_begin)

    [B--2---:R-:W-:Y:S03]    IMAD TmpEightA0, RZ, RZ, TmpEightB0
    [B------:R-:W-:-:S01]    MOV TmpEightA1, TmpEightB1
    [B------:R-:W-:-:S01]    IMAD TmpEightA2, RZ, RZ, TmpEightB2
    [B------:R-:W-:-:S01]    MOV TmpEightA3, TmpEightB3
    [B------:R-:W-:-:S01]    IMAD TmpEightA4, RZ, RZ, TmpEightB4
    [B------:R-:W-:-:S01]    MOV TmpEightA5, TmpEightB5
    [B------:R-:W-:-:S01]    IMAD TmpEightA6, RZ, RZ, TmpEightB6
    [B------:R-:W-:-:S01]    MOV TmpEightA7, TmpEightB7
    [B------:R-:W-:-:S01]    UISETP.GT.AND UP0, UPT, URZ, uGrLoopCnt, UPT

    [B------:R4:W2:-:S01] @P2 LDG.E.EL.ELL2.256.STRONG_GPU TmpEightB4, TmpEightB0, [cOfs.U32 + L2Base], 0xFF

    [B------:R-:W-:-:S01]    MOV TmpB, jmp_ind
    [B------:R-:W-:-:S01]    MOV TmpC, jmp_ind
    [B0-----:R-:W-:-:S03]    LOP3.LUT P1, RZ, nxtPntY0, 0x01, RZ, 0xC0, !PT //inv_flag
    [B------:R-:W-:-:S01]    IMAD PntY0, RZ, RZ, nxtPntY0
    [B------:R-:W-:-:S01]    MOV PntY1, nxtPntY1
    [B------:R-:W-:-:S01]    IMAD PntY2, RZ, RZ, nxtPntY2
    [B------:R-:W-:-:S01]    MOV PntY3, nxtPntY3
    [B------:R-:W-:-:S01]    IMAD PntY4, RZ, RZ, nxtPntY4
    [B------:R-:W-:-:S01]    MOV PntY5, nxtPntY5
    [B------:R-:W-:-:S01]    IMAD PntY6, RZ, RZ, nxtPntY6
    [B------:R-:W-:-:S01]    MOV PntY7, nxtPntY7
    [B------:R4:W0:-:S01]    LDG.E.EL.ELL2.256.STRONG_GPU nxtPntY4, nxtPntY0, [yOfs.U32 + L2Base], 0xFF
    [B------:R-:W-:-:S01] @P0 IADD3 TmpB, TmpB, {(48 * 1024) / 16}, RZ
    [B------:R-:W-:-:S01] @P0 IADD3 TmpC, TmpC, {(48 * 1024) / 16}, RZ
    [B------:R-:W-:-:S04] @P1 IADD3 TmpB, TmpB, {32 * JMP_CNT / 16}, RZ //inverted
    [B------:R-:W-:-:S01] @!P1 IADD3 TmpC, TmpC, {32 * JMP_CNT / 16}, RZ
    [B------:R-:W4:-:S02]    LDS.128 jPntY0, [TmpB.X16 + {32 * JMP_CNT}]
    [B------:R-:W4:-:S02]    LDS.128 jPntY4, [TmpB.X16 + {48 * JMP_CNT}]
    [B------:R-:W-:-:S01] @P1 IADD3 jmp_ind, jmp_ind, {INV_FLAG}, RZ

    [B------:R-:W-:-:S01]    BRA.CONV !P5, ~URZ `(.last_gr)

    [B---3--:R-:W-:Y:S01]    NOP //get lds (jPntX)
inc_func CalcNewPoints_FusedA(RFirst=TmpEightA, RSecond=invNine, Ro=TmpNineA, Rt=TmpTmp, Pt=P0, RSubFirst=jPntX, \
RSubSecond=PntX, RSubOut=dxEight, Rpreout=TmpEightA, Rout=invNine)

    [B----4-:R-:W-:-:S01]    IADD3 cOfs, cOfs, -uGrStride, RZ
.last_gr:
    [B------:R-:W-:-:S01] @!P5 IMAD TmpNineA0, RZ, RZ, invNine0
    [B------:R-:W-:-:S01] @!P5 MOV TmpNineA1, invNine1
    [B------:R-:W-:-:S01] @!P5 IMAD TmpNineA2, RZ, RZ, invNine2
    [B------:R-:W-:-:S01] @!P5 MOV TmpNineA3, invNine3
    [B------:R-:W-:-:S01] @!P5 IMAD TmpNineA4, RZ, RZ, invNine4
    [B------:R-:W-:-:S01] @!P5 MOV TmpNineA5, invNine5
    [B------:R-:W-:-:S01] @!P5 IMAD TmpNineA6, RZ, RZ, invNine6
    [B------:R-:W-:-:S01] @!P5 MOV TmpNineA7, invNine7

    [B----4-:R-:W-:-:S01]    IADD3 yOfs, yOfs, uGrStride, RZ //return after imitating
    [B------:R-:W-:-:S01]    IADD3 xOfs, xOfs, uGrStride, RZ

inc_func CalcNewPoints_FusedB(RSubFirst=jPntY, RSubSecond=PntY, RSubOut=dxEight, RFirst=dxEight, RSecond=TmpNineA, \
Ro=TmpEightA, Rt=TmpTmp, Pt=P0)

    [B------:R4:W3:-:S02]    LDS.128 jPntY0, [TmpC.X16 + {32 * JMP_CNT}]
    [B------:R4:W3:-:S02]    LDS.128 jPntY4, [TmpC.X16 + {48 * JMP_CNT}]

    [B------:R-:W-:-:S04]    IADD3.X dxEight0, P0, P2, ~PntX0, 0xFFFFF85E, ~jPntX0, PT, PT
    [B------:R-:W-:-:S04]    IADD3.X dxEight1, P0, P2, ~PntX1, 0xFFFFFFFD, ~jPntX1, P0, P2
    [B------:R-:W-:-:S04]    IADD3.X dxEight2, P0, P2, ~PntX2, 0xFFFFFFFF, ~jPntX2, P0, P2
    [B------:R-:W-:-:S04]    IADD3.X dxEight3, P0, P2, ~PntX3, 0xFFFFFFFF, ~jPntX3, P0, P2
    [B------:R-:W-:-:S04]    IADD3.X dxEight4, P0, P2, ~PntX4, 0xFFFFFFFF, ~jPntX4, P0, P2
    [B------:R-:W-:-:S04]    IADD3.X dxEight5, P0, P2, ~PntX5, 0xFFFFFFFF, ~jPntX5, P0, P2
    [B------:R-:W-:-:S04]    IADD3.X dxEight6, P0, P2, ~PntX6, 0xFFFFFFFF, ~jPntX6, P0, P2
    [B------:R-:W-:-:S02]    IADD3.X dxEight7, P0, P2, ~PntX7, 0xFFFFFFFF, ~jPntX7, P0, P2
    [B----4-:R-:W-:-:S02]    MOV NineTen1, 0x00 //TmpB and NineTen are the same registers
    [B------:R-:W-:-:S01]    IADD3.X NineTen0, PT, PT, ~RZ,    0x00000001, ~RZ,     P0, P2
inc_func SqrAddMod256(Ri=TmpEightA, Ro=PntX, Rt=TmpTmp, Pt=0, Radd=dxEight, RNineTen=NineTen) //spoils NineTen0, NineTen1=0

    [B---3--:R-:W-:-:S01]    NOP //wait lds(jPntY)

inc_func CalcNewPoints_FusedC(RFirst=TmpNineA, RSecond=TmpEightA, Ro=PntY, Rt=TmpTmp, Pt=P0, \
RSubFirst=jPntX, RSubSecond=PntX, Radd=jPntY, Rout=PntY)

    [B------:R-:W-:-:S01]    LOP3.LUT P0, RZ, LS, bMask, RZ, 0xC0, !PT //P0==1 means loop mode, 0 - normal mode
    [B------:R-:W-:-:S01]    ISETP.LE.AND P1, PT, RZ, uLastPntInd, PT //signed, if (step_ind + MD_LEN >= STEP_CNT)
    [B------:R-:W-:-:S02]    UIMAD uTmpTmp0, uLastPntInd, uPartStrideDouble, URZ
    [B------:R-:W-:-:S01]    MOV TmpA, 0xFF000000 //some unreal value
    [B------:R-:W-:-:S01]    LOP3.LUT P2, RZ, PntY0, 0x01, RZ, 0xC0, !PT //inv_flag, inverted (to detect loop)
    [B------:R-:W-:-:S01]    LOP3.LUT P4, RZ, PntX7, uDP_Mask, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    UIMAD uCallB0, uGrLoopCnt, 0x90, uTmpA
    [B------:R5:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [yOfs.U32 + L2Base], PntY0, PntY4, 0xFF
    [B------:R-:W-:-:S02]    IADD3 TmpTmpMax0, xOfs, uTmpTmp0, RZ
    [B------:R-:W-:-:S02]    IADD3 TmpTmpMax1, yOfs, uTmpTmp0, RZ
    [B------:R4:W-:-:S02] @!P6 STG.E.EL.ELL2.256.STRONG_GPU [xOfs.U32 + L2Base], PntX0, PntX4, 0xFF
    [B------:R-:W-:-:S01] @!P0 LOP3.LUT TmpA, PntX0, {JMP_MASK}, RZ, 0xC0, !PT
    [B------:R-:W-:-:S01]    UIADD3 uRetB0, -uCallB0, `(.relN_SaveX_begin) + {0x10 - 0x80}, URZ
    [B------:R-:W-:Y:S01] @P6 BRXU.U uCallB, `(.SaveX_begin)

    [B------:R5:W-:-:S02] @P1 STG.E.NA.0_EFL2.256.STRONG_GPU [TmpTmpMax0.U32 + LastPntsBase], PntX0, PntX4, 0xFF
    [B------:R5:W-:-:S02] @P1 STG.E.NA.0_EFL2.256.STRONG_GPU [TmpTmpMax1.U32 + LastPntsBase], PntY0, PntY4, 0xFF

    [B------:R-:W-:-:S04] @!P2 IADD3 TmpA, TmpA, {INV_FLAG}, RZ
    [B------:R-:W-:-:S01]    IADD3 TmpB, gID, uKangGrInd, RZ
    [B------:R-:W-:-:S01]    ISETP.EQ.AND P3, PT, TmpA, jmp_ind, PT //P3=True loop is detected
    [B------:R-:W-:-:S01] @P0 LOP3.LUT LS, LS, bMask, RZ, 0x30, !PT
    [B------:R-:W-:-:S01] @P0 IADD3 jmp_ind, jmp_ind, {JMP2_FLAG}, RZ

    [B------:R-:W-:-:S01]    MOV TmpA, 0x01
    [B------:R-:W-:-:S05]    IMAD TmpC, TmpB, 0x04, RZ
    [B------:R-:W3:-:S02] @!P4 ATOMG.E.EL.ADD.STRONG_GPU PT, TmpC, [TmpC.U32 + DPTableBase], TmpA
    [B---3--:R-:W-:-:S05] @!P4 IMNMX.U32 TmpC, TmpC, {DPTABLE_MAX_CNT - 1}, PT
    [B------:R-:W-:-:S04] @!P4 IMAD TmpB, TmpB, {DPTABLE_MAX_CNT}, TmpC
    [B------:R-:W-:-:S05] @!P4 IMAD TmpB, TmpB, 0x10, RZ
    [B------:R3:W-:-:S02] @!P4 STG.E.NA.128.STRONG_GPU [TmpB.U32 + DPTableBaseB], PntX0
    [B---3--:R-:W-:-:S01] @!P4 IADD3 jmp_ind, jmp_ind, {DP_FLAG}, RZ

    [B------:R-:W-:-:S01] @P3 LOP3.LUT LS, LS, bMask, RZ, 0xFC, !PT //L1S2 |= (1u << group), loop detected

    [B------:R-:W-:-:S01]    IADD3 TmpB, ThrID, uGrInd, ThrID
    [B-----5:R-:W-:-:S02]    IADD3 yOfs, yOfs, -uGrStride, RZ
    [B------:R5:W-:-:S02]    STG.E.NA.U16.STRONG_GPU [TmpB.U32 + JumpsListBase], jmp_ind
    [B----4-:R-:W-:-:S02]    IADD3 xOfs, xOfs, -uGrStride, RZ

    [B------:R-:W-:-:S01]    SHF.R.S32.HI bMask, RZ, 0x01, bMask
    [B------:R-:W-:-:S01]    UIADD3 uKangGrInd, uKangGrInd, -uThrCnt, URZ
    [B------:R-:W-:-:S01] @UP0 UMOV uGrLoopPnt0, uGrLoopHlp
    [B------:R-:W-:-:S01]    UIADD3 uGrLoopCnt, uGrLoopCnt, -0x1, URZ
    [B------:R-:W-:-:S01]    UIADD3 uGrInd, uGrInd, {-2 * 256}, URZ
    [B------:R-:W-:-:S01]    BRXU.U uGrLoopPnt, `(.group_loop2_beg)
.relP_group_loop2_end:
    [B------:R-:W-:-:S01]    UIMAD.WIDE  JumpsListBase, uOne, {(GROUP_SIZE / 2) * 256 * 2}, JumpsListBase
.relN_Calc_NewPoints_end:
    [B------:R-:W-:-:S01] BRXU.U uRetA, 0x00

.Send_ToInv_begin:
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC0, TmpEightB0, 0x1, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC1, TmpEightB1, 0x1, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC2, TmpEightB2, 0x1, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC3, TmpEightB3, 0x1, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC4, TmpEightB4, 0x1, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC5, TmpEightB5, 0x1, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveC6, TmpEightB6, 0x1, 0x1f
    [B------:R-:W0:-:S02]    SHFL.BFLY PT, EightSaveC7, TmpEightB7, 0x1, 0x1f
    [B0-----:R-:W-:Y:S01]    NOP
inc_func MulMod256(RFirst=EightSaveC, RSecond=TmpEightB, Ro=jPntY, Rt=TmpTmp, Pt=P0)

    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB0, jPntY0, 0x2, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB1, jPntY1, 0x2, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB2, jPntY2, 0x2, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB3, jPntY3, 0x2, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB4, jPntY4, 0x2, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB5, jPntY5, 0x2, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveB6, jPntY6, 0x2, 0x1f
    [B------:R-:W0:-:S02]    SHFL.BFLY PT, EightSaveB7, jPntY7, 0x2, 0x1f
    [B0-----:R-:W-:Y:S01]    NOP
inc_func MulMod256(RFirst=EightSaveB, RSecond=jPntY, Ro=dxEight, Rt=TmpTmp, Pt=P0)

    [B------:R-:W-:-:S01]    ISETP.EQ.AND P5, PT, LaneID, RZ, PT
    [B------:R-:W-:-:S01]    MOV TmpA, 0x01
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA0, dxEight0, 0x4, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA1, dxEight1, 0x4, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA2, dxEight2, 0x4, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA3, dxEight3, 0x4, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA4, dxEight4, 0x4, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA5, dxEight5, 0x4, 0x1f
    [B------:R-:W0:-:S01]    SHFL.BFLY PT, EightSaveA6, dxEight6, 0x4, 0x1f
    [B------:R-:W0:-:S02]    SHFL.BFLY PT, EightSaveA7, dxEight7, 0x4, 0x1f
    [B0-----:R-:W-:Y:S01]    NOP

    [B------:R-:W0:-:S02] @P5 ATOMG.E.EL.ADD.STRONG_GPU PT, TmpEightA0, [RZ.U32+InvBase + 0x80], TmpA //move tail, TmpEightA0=tail

inc_func MulMod256(RFirst=EightSaveA, RSecond=dxEight, Ro=TmpNineA, Rt=TmpTmp, Pt=P0)

    [B------:R-:W-:-:S01]    LOP3.LUT TmpTmp0, LaneID, 0x7, RZ, 0xC0, !PT
    [B------:R-:W-:-:S03]    SHF.R.U32.HI TmpEightA2, RZ, 0x05, gID //CID = warp id
    [B------:R-:W-:-:S05]    ISETP.EQ.AND P1, PT, TmpTmp0, RZ, PT
    [B------:R-:W-:-:S01]    IMAD TmpEightA6, TmpEightA2, 0x04, RZ //ReadyFlag takes 4 bytes
    [B------:R-:W-:-:S04]    IMAD TmpEightA5, TmpEightA2, 0x80, RZ
    [B------:R-:W-:-:S04]    IMAD TmpEightA5, LaneID, 0x04, TmpEightA5
    [B------:R4:W-:-:S02] @P1 STG.E.EL.ELL2.256.STRONG_GPU [TmpEightA5.U32 + InvBase + {0x2400 + 4*32768}], TmpNineA0, TmpNineA4, 0xFF
    [B----4-:R-:W-:Y:S03]    NOP
    [B0-----:R-:W-:-:S03] @P5 SHF.R.U32.HI TmpEightA1, RZ, 0x0f, TmpEightA0 //current generation
    [B------:R-:W-:-:S05] @P5 LOP3.LUT TmpEightA0, TmpEightA0, {32768 - 1}, RZ, 0xC0, !PT //ring, 32K cells
    [B------:R-:W-:-:S01] @P5 IMAD TmpEightA0, TmpEightA0, 0x04, RZ
    [B------:R-:W-:-:S04] @P5 SHF.L.U32 TmpEightA3, TmpEightA1, 0x0c, RZ
    [B------:R-:W-:-:S05] @P5 IADD3 TmpEightA3, TmpEightA3, 0x01, TmpEightA2 //add CID+1
    [B------:R-:W-:Y:S06]    MEMBAR.SC.GPU //INV worker must see the mailbox written before the filled slot
    [B------:R4:W-:-:S02] @P5 STG.E.EL.STRONG_GPU [TmpEightA0.U32 + InvBase + 0x2400], TmpEightA3
    [B----4-:R-:W-:Y:S01]    NOP
.relN_Send_ToInv_end:
    [B------:R-:W-:-:S01] BRXU.U uRetA, 0x00

.Recv_Inv_begin:
    [B------:R-:W-:-:S05]    SHF.R.U32.HI TmpEightA2, RZ, 0x05, gID //CID = warp id
    [B------:R-:W-:-:S01]    IMAD TmpEightA6, TmpEightA2, 0x04, RZ
    [B------:R-:W-:-:S01]    LOP3.LUT TmpA, LaneID, 0x7, RZ, 0xC0, !PT
    [B------:R-:W-:Y:S10]    ISETP.EQ.AND P0, PT, LaneID, RZ, PT
    [B------:R-:W-:-:S01]    ISETP.EQ.AND P1, PT, TmpA, RZ, PT
    [B------:R-:W-:-:S01]    ISETP.EQ.AND P2, PT, LaneID, RZ, PT
    [B------:R-:W-:-:S01]    MOV TmpEightA4, 0x100 //mask to reset readyflag
.wait_rf_loop:
    [B------:R-:W0:-:S02] @P0 LDG.E.EL.STRONG_GPU TmpEightA7, [TmpEightA6.U32 + InvBase + {0x2400 + 4*32768 + 2*2048*128}], PT
    [B0-----:R-:W-:Y:S13]    ISETP.EQ.AND P0, PT, TmpEightA7, RZ, P0
    [B------:R-:W-:-:S01]    BRA.CONV !P0, ~URZ `(.wait_rf_end)
    [B------:R-:W-:Y:S01]    BRA.U `(.wait_rf_loop)
.wait_rf_end:
    [B------:R-:W0:-:S02]    SHFL.IDX PT, TmpEightA7, TmpEightA7, RZ, 0x1f
    [B0-----:R-:W-:-:S03]    ISETP.GE.U32.AND P0, PT, TmpEightA7, 0x100, PT //if we got stopflag - calc inv locally

    [B------:R4:W-:-:S02] @P2 RED.E.EL.AND.STRONG_GPU [TmpEightA6.U32 + InvBase + {0x2400 + 4*32768 + 2*2048*128}], TmpEightA4
    [B----4-:R-:W-:Y:S01]    NOP

    [B------:R-:W-:-:S05]    IMAD TmpEightA5, TmpEightA2, 0x80, RZ
    [B------:R-:W-:-:S05]    IMAD TmpEightA5, LaneID, 0x04, TmpEightA5

    [B------:R-:W-:-:S05] @!P0 IADD3 TmpEightA5, TmpEightA5, {2048*128}, RZ //out mailbox
    [B------:R-:W0:-:S02] @P1 LDG.E.EL.ELL2.256.STRONG_GPU invNine4, invNine0, [TmpEightA5.U32 + InvBase + {0x2400 + 4*32768}], 0xFF
    [B0-----:R-:W-:Y:S01]    NOP

    [B------:R-:W-:-:S05]    BRA.CONV P0, ~URZ `(.label_local_inv)
.label_local_inv_ret:

    [B------:R-:W-:-:S04]    LOP3.LUT  TmpA, ThrID, 0x18, RZ, 0xC0, !PT
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine0, invNine0, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine1, invNine1, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine2, invNine2, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine3, invNine3, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine4, invNine4, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine5, invNine5, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, invNine6, invNine6, TmpA, 0x1f
    [B------:R-:W0:-:S02]    SHFL.IDX PT, invNine7, invNine7, TmpA, 0x1f
    [B0-----:R-:W-:Y:S01]    NOP
inc_func MulMod256(RFirst=invNine0, RSecond=EightSaveA, Ro=TmpNineA, Rt=TmpTmp, Pt=P0)

    [B------:R-:W-:-:S04]    LOP3.LUT  TmpA, ThrID, 0x1C, RZ, 0xC0, !PT
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA0, TmpNineA0, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA1, TmpNineA1, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA2, TmpNineA2, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA3, TmpNineA3, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA4, TmpNineA4, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA5, TmpNineA5, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, TmpNineA6, TmpNineA6, TmpA, 0x1f
    [B------:R-:W0:-:S02]    SHFL.IDX PT, TmpNineA7, TmpNineA7, TmpA, 0x1f
    [B0-----:R-:W-:Y:S01]    NOP
inc_func MulMod256(RFirst=TmpNineA, RSecond=EightSaveB, Ro=jPntY, Rt=TmpTmp, Pt=P0)

    [B------:R-:W-:-:S04]    LOP3.LUT  TmpA, ThrID, 0x1E, RZ, 0xC0, !PT
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY0, jPntY0, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY1, jPntY1, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY2, jPntY2, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY3, jPntY3, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY4, jPntY4, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY5, jPntY5, TmpA, 0x1f
    [B------:R-:W0:-:S01]    SHFL.IDX PT, jPntY6, jPntY6, TmpA, 0x1f
    [B------:R-:W0:-:S02]    SHFL.IDX PT, jPntY7, jPntY7, TmpA, 0x1f
    [B0-----:R-:W-:Y:S01]    NOP
inc_func MulMod256(RFirst=jPntY, RSecond=EightSaveC, Ro=invNine, Rt=TmpTmp, Pt=P0)

.relN_Recv_Inv_end:
    [B------:R-:W-:-:S01] BRXU.U uRetA, 0x00

.label_local_inv:
    [B------:R-:W-:-:S01]    IMAD TmpNineA0, RZ, RZ, invNine0
    [B------:R-:W-:-:S01]    MOV TmpNineA1, invNine1
    [B------:R-:W-:-:S01]    IMAD TmpNineA2, RZ, RZ, invNine2
    [B------:R-:W-:-:S01]    MOV TmpNineA3, invNine3
    [B------:R-:W-:-:S01]    IMAD TmpNineA4, RZ, RZ, invNine4
    [B------:R-:W-:-:S01]    MOV TmpNineA5, invNine5
    [B------:R-:W-:-:S01]    IMAD TmpNineA6, RZ, RZ, invNine6
    [B------:R-:W-:-:S01]    MOV TmpNineA7, invNine7
    [B------:R-:W-:-:S01]    UMOV uCallInv0, `(.relN_end_InvMod256) //RCASM:CallPointA
call_func InvMod256(Ri=TmpNineA, Ro=invNine, Rt=TmpTmpMax, URt=uTmpTmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallInv, 0x00") //RCASM:CallPointA

    [B------:R-:W-:-:S01]    BRA.U `(.label_local_inv_ret)

.LoadX_begin:
.relN_LoadX_begin:
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs0
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs1
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs2
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs3
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs4
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs5
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs6
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs8
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs9
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs10
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs11
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs12
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs13
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs14
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs15
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs16
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs17
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs18
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs19
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs20
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs21
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs22
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs23
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs24
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs25
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs26
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs27
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs28
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs29
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs30
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs31
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs32
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs33
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs34
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs35
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs36
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs37
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs38
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs39
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs40
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs41
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs42
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs43
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs44
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs45
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs46
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs47
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs48
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs49
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs50
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs51
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs52
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs53
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs54
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs55
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs56
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs57
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs58
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs59
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs60
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs61
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs62
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs63
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs64
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs65
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs66
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs67
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs68
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs69
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs70
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs71
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs72
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs73
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs74
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs75
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs76
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs77
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs78
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs79
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs80
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs81
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs82
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs83
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs84
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs85
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs86
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs87
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD nxtPntX0, RZ, RZ, SaveRegs88
    [B------:R-:W-:-:S01]    MOV nxtPntX1, SaveRegs89
    [B------:R-:W-:-:S01]    IMAD nxtPntX2, RZ, RZ, SaveRegs90
    [B------:R-:W-:-:S01]    MOV nxtPntX3, SaveRegs91
    [B------:R-:W-:-:S01]    IMAD nxtPntX4, RZ, RZ, SaveRegs92
    [B------:R-:W-:-:S01]    MOV nxtPntX5, SaveRegs93
    [B------:R-:W-:-:S01]    IMAD nxtPntX6, RZ, RZ, SaveRegs94
    [B------:R-:W-:-:S01]    MOV nxtPntX7, SaveRegs95
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00

.SaveX_begin:
.relN_SaveX_begin:
    [B------:R-:W-:-:S01]    IMAD SaveRegs0, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs1, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs2, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs3, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs4, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs5, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs6, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs7, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs8, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs9, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs10, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs11, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs12, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs13, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs14, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs15, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs16, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs17, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs18, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs19, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs20, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs21, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs22, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs23, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs24, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs25, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs26, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs27, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs28, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs29, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs30, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs31, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs32, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs33, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs34, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs35, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs36, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs37, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs38, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs39, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs40, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs41, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs42, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs43, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs44, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs45, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs46, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs47, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs48, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs49, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs50, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs51, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs52, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs53, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs54, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs55, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs56, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs57, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs58, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs59, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs60, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs61, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs62, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs63, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs64, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs65, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs66, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs67, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs68, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs69, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs70, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs71, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs72, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs73, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs74, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs75, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs76, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs77, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs78, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs79, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs80, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs81, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs82, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs83, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs84, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs85, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs86, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs87, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00
    [B------:R-:W-:-:S01]    IMAD SaveRegs88, RZ, RZ, PntX0
    [B------:R-:W-:-:S01]    MOV SaveRegs89, PntX1
    [B------:R-:W-:-:S01]    IMAD SaveRegs90, RZ, RZ, PntX2
    [B------:R-:W-:-:S01]    MOV SaveRegs91, PntX3
    [B------:R-:W-:-:S01]    IMAD SaveRegs92, RZ, RZ, PntX4
    [B------:R-:W-:-:S01]    MOV SaveRegs93, PntX5
    [B------:R-:W-:-:S01]    IMAD SaveRegs94, RZ, RZ, PntX6
    [B------:R-:W-:-:S01]    MOV SaveRegs95, PntX7
    [B------:R-:W-:-:S01]    BRXU.U uRetB, 0x00

.inv_sm_begin:
    [B------:R-:W-:Y:S09]    ISETP.EQ.AND P6, PT, LaneID, RZ, PT
    [B------:R-:W-:-:S05]    MOV TmpA, 0x01
.inv_main_loop:
    [B------:R-:W0:-:S02] @P6 ATOMG.E.EL.ADD.STRONG_GPU PT, xOfs, [RZ.U32+InvBase + 0x00], TmpA //move head, xOfs=head
    [B------:R-:W-:-:S01]    ISETP.EQ.AND P0, PT, RZ, RZ, PT
    [B0-----:R-:W0:-:S03]    SHFL.IDX PT, xOfs, xOfs, RZ, 0x1f
    [B0-----:R-:W-:-:S03]    SHF.R.U32.HI yOfs, RZ, 0x0a, xOfs //current generation
    [B------:R-:W-:-:S05]    LOP3.LUT xOfs, xOfs, {1024 - 1}, RZ, 0xC0, !PT //ring, 32K cells, 1024 batches
    [B------:R-:W-:-:S05]    IMAD xOfs, xOfs, {4*32}, RZ
    [B------:R-:W-:-:S05]    IMAD xOfs, LaneID, 0x4, xOfs
.inv_wait32_loop:
    [B------:R-:W0:-:S02] @P0 LDG.E.EL.STRONG_GPU EightSaveA0, [xOfs.U32 + InvBase + 0x2400], PT
    [B0-----:R-:W-:-:S03]    SHF.R.U32.HI EightSaveA1, RZ, 0x0c, EightSaveA0 //generation
    [B------:R-:W-:-:S05]    LOP3.LUT EightSaveA2, EightSaveA0, {4096 - 1}, RZ, 0xC0, !PT //CID+1
    [B------:R-:W-:Y:S13]    ISETP.NE.AND P1, PT, EightSaveA2, RZ, PT //CID+1 must be non-zero if slot is filled
    [B------:R-:W-:Y:S13]    ISETP.EQ.AND P1, PT, EightSaveA1, yOfs, P1
    [B------:R-:W-:Y:S13]    PLOP3.LUT   P0, PT, P0, P1, PT, 0x20, 0x0
    [B------:R-:W-:-:S01]    BRA.CONV !P0, ~URZ `(.inv_wait32_end)
    [B------:R-:W0:-:S02] @P6 ATOMG.E.EL.OR.STRONG_GPU PT, cOfs, [RZ.U32+InvBase + 0x100], RZ //get ProducerCnt
    [B0-----:R-:W0:-:S03]    SHFL.IDX PT, cOfs, cOfs, RZ, 0x1f
    [B0-----:R-:W-:Y:S13]    ISETP.GT.AND P1, PT, cOfs, uStopThr, PT
    [B------:R-:W-:-:S01]    BRA.CONV P1, ~URZ `(.inv_end)
    [B------:R-:W-:Y:S01]    BRA.U `(.inv_wait32_loop)
.inv_wait32_end:

    [B------:R-:W-:-:S05]    IADD3 yOfs, yOfs, 0x01, RZ
    [B------:R-:W-:-:S05]    SHF.L.U32 yOfs, yOfs, 0x0c, RZ
    [B----4-:R-:W-:-:S05]    IADD3 EightSaveA2, EightSaveA2, -0x01, RZ

    [B------:R-:W-:-:S05]    IMAD cOfs, EightSaveA2, {4*32}, RZ
    [B------:R-:W0:-:S02]    LDG.E.EL.ELL2.256.STRONG_GPU EightSaveB4, EightSaveB0, [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 0x00}], 0xFF
    [B------:R-:W0:-:S02]    LDG.E.EL.ELL2.256.STRONG_GPU EightSaveC4, EightSaveC0, [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 0x20}], 0xFF
    [B------:R-:W1:-:S02]    LDG.E.EL.ELL2.256.STRONG_GPU EightD4, EightD0, [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 0x40}], 0xFF
    [B------:R-:W2:-:S02]    LDG.E.EL.ELL2.256.STRONG_GPU EightE4, EightE0, [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 0x60}], 0xFF
    [B0-----:R-:W-:Y:S01]    NOP
inc_func MulMod256(RFirst=EightSaveB, RSecond=EightSaveC, Ro=EightF, Rt=TmpTmpB, Pt=P0)
    [B-1----:R-:W-:-:S01]    NOP
inc_func MulMod256(RFirst=EightF, RSecond=EightD, Ro=EightH, Rt=TmpTmpB, Pt=P0)
    [B--2---:R-:W-:-:S01]    NOP
inc_func MulMod256(RFirst=EightH, RSecond=EightE, Ro=TmpNineA, Rt=TmpTmpB, Pt=P0)

    [B------:R-:W-:-:S01]   UMOV uCallInv0, `(.relN_end_InvMod256) //RCASM:CallPointB
call_func InvMod256(Ri=TmpNineA, Ro=invNine, Rt=TmpTmpMax, URt=uTmpTmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallInv, 0x00") //RCASM:CallPointB

inc_func MulMod256(RFirst=invNine, RSecond=EightH, Ro=TmpTmpB24, Rt=TmpTmpB32, Pt=P0)
inc_func MulMod256(RFirst=invNine, RSecond=EightE, Ro=EightG, Rt=TmpTmpB32, Pt=P0)
inc_func MulMod256(RFirst=EightG, RSecond=EightF, Ro=TmpTmpB16, Rt=TmpTmpB32, Pt=P0)
inc_func MulMod256(RFirst=EightG, RSecond=EightD, Ro=invNine, Rt=TmpTmpB32, Pt=P0)
inc_func MulMod256(RFirst=invNine, RSecond=EightSaveB, Ro=TmpTmpB8, Rt=TmpTmpB32, Pt=P0)
inc_func MulMod256(RFirst=invNine, RSecond=EightSaveC, Ro=TmpTmpB0, Rt=TmpTmpB32, Pt=P0)

    [B------:R4:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 2048*128 + 0x00}], TmpTmpB0, TmpTmpB4, 0xFF
    [B------:R4:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 2048*128 + 0x20}], TmpTmpB8, TmpTmpB12, 0xFF
    [B------:R4:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 2048*128 + 0x40}], TmpTmpB16, TmpTmpB20, 0xFF
    [B------:R4:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + {0x2400 + 4*32768 + 2048*128 + 0x60}], TmpTmpB24, TmpTmpB28, 0xFF
    [B------:R-:W-:-:S01]    IMAD yOfs, EightSaveA2, 0x04, RZ
    [B----4-:R-:W-:Y:S06]    MEMBAR.SC.GPU

    [B------:R4:W-:-:S02]    RED.E.EL.OR.STRONG_GPU [yOfs.U32 + InvBase + {0x2400 + 4*32768 + 2*2048*128}], TmpA //0x01

    [B----4-:R-:W-:-:S01]    BRA.U `(.inv_main_loop)
.inv_end:
    [B------:R-:W-:-:S01]    MOV cOfs, {0x2400 + 4*32768 + 2*2048*128}
    [B------:R-:W-:-:S01]    MOV PntX0, 0x100
    [B------:R-:W-:-:S01]    MOV PntX1, 0x100
    [B------:R-:W-:-:S01]    MOV PntX2, 0x100
    [B------:R-:W-:-:S01]    MOV PntX3, 0x100
    [B------:R-:W-:-:S05]    IMAD cOfs, LaneID, 0x20, cOfs
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x0000], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x0400], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x0800], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x0C00], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x1000], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x1400], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S01]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x1800], PntX0, PntX0, 0xFF
    [B------:R4:W-:-:S02]    STG.E.EL.ELL2.256.STRONG_GPU [cOfs.U32 + InvBase + 0x1C00], PntX0, PntX0, 0xFF
    [B----4-:R-:W-:-:S05]    EXIT
}