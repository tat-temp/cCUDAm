FUNCTION getPublish2(ext=Ri0, bdone=Ri1, bsz=Ri2, gid=Ri3, uGD=URt0, frp=Rt0, sadr=Rt2, scal=Rt4, czero=Rt12, cret=Rt13, cadr=Rt14, newv=Rt16, prod=Rt18, sgn=Rt20)
{
    [B------:R-:W-:Y:S13] @!Pt0 BRA `(.gp_done)
    [B------:R-:W0:-:S01]      LDC.64 frp0, c[0x0][0x398]
    [B------:R-:W1:-:S02]      LDC.64 sadr0, c[0x0][0x390]
    [B0-----:R-:W-:-:S05]      IADD3 cadr0, Pt2, PT, frp0, 0x60, RZ //S02 read a stale Pt2: CAS at &claimed+4GB, "invalid address space"
    [B------:R-:W-:-:S04]      IADD3.X cadr1, PT, PT, frp1, RZ, RZ, Pt2, !PT
    [B------:R-:W-:-:S02]      MOV czero, RZ
    [B------:R-:W-:-:S05]      MOV newv, 0x1
    [B------:R-:W5:-:S02]      ATOMG.E.CAS.STRONG.SYS PT, cret, [cadr0], czero, newv
    [B-----5:R-:W-:Y:S13]      ISETP.NE.AND Pt3, PT, cret, RZ, PT
    [B------:R-:W-:Y:S05] @Pt3  BRA `(.gp_done)
    [B-1----:R-:W-:-:S06]      IMAD.WIDE.U32 sadr0, gid, 0x20, sadr0
    [B------:R-:W2:-:S01]      LDG.E.128 scal0, desc[uGD][sadr0.64] //start_scalars[gid]
    [B------:R-:W2:-:S01]      LDG.E.128 scal4, desc[uGD][sadr0.64+0x10]
    [B------:R-:W-:-:S04]      IMAD.WIDE.U32 prod0, bdone, bsz, RZ //delta = (int64)bdone*bsz + ext
    [B------:R-:W-:-:S04]      SHF.R.S32.HI sgn, RZ, 0x1f, ext
    [B------:R-:W-:-:S05]      IADD3 prod0, Pt2, PT, prod0, ext, RZ
    [B------:R-:W-:-:S05]      IADD3.X prod1, PT, PT, prod1, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S04]      SHF.R.S32.HI sgn, RZ, 0x1f, prod1 //scal += sign-extended delta
    [B--2---:R-:W-:-:S05]      IADD3 scal0, Pt2, PT, scal0, prod0, RZ
    [B------:R-:W-:-:S05]      IADD3.X scal1, Pt2, PT, scal1, prod1, RZ, Pt2, !PT
    [B------:R-:W-:-:S05]      IADD3.X scal2, Pt2, PT, scal2, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S05]      IADD3.X scal3, Pt2, PT, scal3, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S05]      IADD3.X scal4, Pt2, PT, scal4, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S05]      IADD3.X scal5, Pt2, PT, scal5, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S05]      IADD3.X scal6, Pt2, PT, scal6, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S04]      IADD3.X scal7, PT, PT, scal7, sgn, RZ, Pt2, !PT
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64], scal0
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64+0x8], scal2
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64+0x10], scal4
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64+0x18], scal6
    [B------:R-:W-:-:S02]      MEMBAR.ALL.CTA
    [B------:R-:W-:-:S02]      MEMBAR.SC.SYS
    [B------:R-:W-:-:S02]      ERRBAR
    [B------:R-:W-:-:S04]      CGAERRBAR
    [B------:R-:W-:-:S06]      STG.E desc[uGD][cadr0.64+0x4], newv
.gp_done:
}
