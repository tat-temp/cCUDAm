// Stage-2 hashdump (branch f2m): load X[gid] + prefix, call the LIFTED getHash160_w2, store hw2.
// Verifies the lifted hash bit-exact vs hashgolden.bin (run: ./hd_runner hd_hash.cubin golden).
//
// Register discipline: the lifted hash owns R0..R58 (inputs R4=prefix, R6..R13=x-words e7..e0;
// output hw2=R4; UR4 = its uniform temp). The kernel keeps everything live across the call at R60+
// and uDesc/uCallH off UR4, so the hash body needs no renumbering. Template: Px=X, Py=prefix, Scal=out.
KERNEL TestKernel(regcnt=80, \
    gID=R60, ThrID=R61, BlockID=R62, \
    AddrX=R64, AddrP=R66, AddrO=R68, Thr=R70, \
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

// load X[gid] as four u64 straight into R6..R13 (v0=R6:R7, v1=R8:R9, v2=R10:R11, v3=R12:R13)
    [B--2---:R-:W0:-:S01]    LDG.E.64 R6,  desc[uDesc][AddrX.64]
    [B------:R-:W0:-:S01]    LDG.E.64 R8,  desc[uDesc][AddrX.64+0x8]
    [B------:R-:W0:-:S01]    LDG.E.64 R10, desc[uDesc][AddrX.64+0x10]
    [B------:R-:W0:-:S01]    LDG.E.64 R12, desc[uDesc][AddrX.64+0x18]
// prefix byte (0x02/0x03) -> R4 low word
    [B------:R-:W1:-:S01]    LDG.E R4, desc[uDesc][AddrP.64]

// call the lifted hash (drain the input loads first). hw2 returns in R4.
    [B01----:R-:W-:-:S01]    UMOV uCallH0, `(.relN_end_getHash160_w2) //RCASM:CallPointH
call_func getHash160_w2(Ret="[B------:R-:W-:-:S06] BRXU.U uCallH, 0x00") //RCASM:CallPointH

    [B------:R-:W-:-:S02]    STG.E desc[uDesc][AddrO.64], R4
    [B------:R-:W-:-:S05]    EXIT
}
