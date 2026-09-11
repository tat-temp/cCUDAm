KERNEL TestKernel(regcnt=40, \
    gID=R2, ThrID=R3, BlockID=R4, \
    AddrX=R6, AddrO=R8, Thr=R10, \
    Xin=R12, Res=R16, \
    uDesc=UR4, uCallH=UR6 )
{
    [B------:R-:W0:-:S01]    LDC R1, c[0x0][0x37c]
    [B------:R-:W1:-:S01]    S2R ThrID, SR_TID.X
    [B------:R-:W1:-:S01]    S2R BlockID, SR_CTAID.X
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00
    [B------:R-:W-:-:S01]    UMOV uCallH1, 0xFFFFFFFF
    [B------:R-:W2:-:S01]    LDCU.64 uDesc, c[0x0][0x358]
    [B------:R-:W3:-:S01]    LDC.64 AddrX, c[0x0][0x380]
    [B------:R-:W3:-:S01]    LDC.64 AddrO, c[0x0][0x390]
    [B------:R-:W3:-:S02]    LDC.64 Thr,   c[0x0][0x3a0]

    [B-1----:R-:W-:-:S05]    IMAD gID, BlockID, 0x100, ThrID
    [B---3--:R-:W-:-:S05]    ISETP.GE.U32.AND P0, PT, gID, Thr0, PT
    [B------:R-:W-:Y:S13]    ISETP.EQ.U32.AND P0, PT, Thr1, RZ, P0
    [B------:R-:W-:Y:S05] @P0 EXIT

    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrO, gID, 0x04, AddrO
    [B--2---:R4:W0:-:S01]    LDG.E.64 Xin0, desc[uDesc][AddrX.64]

    [B------:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_stubhash) //RCASM:CallPointH
call_func stubhash(Rin=Xin, Rout=Res, Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH
    [B------:R-:W-:-:S02]    STG.E desc[uDesc][AddrO.64], Res0
    [B------:R-:W-:-:S05]    EXIT
}
