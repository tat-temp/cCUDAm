KERNEL TestKernel(regcnt=112, \
    gID=R0, ThrID=R1, BlockID=R2, \
    AddrX=R4, AddrP=R8, AddrO=R12, Thr=R16, \
    uDesc=UR10, uCallH=UR12 )
{
    [B------:R-:W1:-:S01]    S2R ThrID, SR_TID.X
    [B------:R-:W1:-:S01]    S2R BlockID, SR_CTAID.X
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00
    [B------:R-:W-:-:S01]    UMOV uCallH1, 0xFFFFFFFF
    [B------:R-:W2:-:S01]    LDCU.64 uDesc, c[0x0][0x358]
    [B------:R-:W3:-:S01]    LDC.64 AddrX, c[0x0][0x380]
    [B------:R-:W3:-:S01]    LDC.64 AddrP, c[0x0][0x388]
    [B------:R-:W3:-:S01]    LDC.64 AddrO, c[0x0][0x390]
    [B------:R-:W3:-:S02]    LDC.64 Thr,   c[0x0][0x3a0]

    [B-1----:R-:W-:-:S05]    IMAD gID, BlockID, 0x100, ThrID
    [B---3--:R-:W-:-:S05]    ISETP.GE.U32.AND P0, PT, gID, Thr0, PT
    [B------:R-:W-:Y:S13]    ISETP.EQ.U32.AND P0, PT, Thr1, RZ, P0
    [B------:R-:W-:Y:S05] @P0 EXIT

    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrP, gID, 0x08, AddrP
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrO, gID, 0x04, AddrO

    [B--2---:R-:W0:-:S01]    LDG.E.64 R54, desc[uDesc][AddrX.64]
    [B------:R-:W0:-:S01]    LDG.E.64 R56, desc[uDesc][AddrX.64+0x8]
    [B------:R-:W0:-:S01]    LDG.E.64 R58, desc[uDesc][AddrX.64+0x10]
    [B------:R-:W0:-:S01]    LDG.E.64 R60, desc[uDesc][AddrX.64+0x18]
    [B------:R-:W1:-:S01]    LDG.E R52, desc[uDesc][AddrP.64]

    [B01----:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_getHash160_w2) //RCASM:CallPointH
call_func getHash160_w2(Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH

    [B------:R-:W-:-:S02]    STG.E desc[uDesc][AddrO.64], R52
    [B------:R-:W-:-:S05]    EXIT
}
