FUNCTION getPublish(hit=Ri0, uGD=URt0, frp=Rt0, czero=Rt8, cret=Rt9, cadr=Rt10, newv=Rt13)
{
    [B------:R-:W-:Y:S13] @!Pt0 BRA `(.gp_done)
    [B------:R-:W0:-:S02]      LDC.64 frp0, c[0x0][0x398]
    [B0-----:R-:W-:-:S02]      IADD3 cadr0, Pt2, PT, frp0, 0x60, RZ
    [B------:R-:W-:-:S04]      IADD3.X cadr1, PT, PT, frp1, RZ, RZ, Pt2, !PT
    [B------:R-:W-:-:S02]      MOV czero, RZ
    [B------:R-:W-:-:S02]      MOV newv, 0x1
    [B------:R-:W5:-:S02]      ATOMG.E.CAS.STRONG.SYS PT, cret, [cadr0], czero, newv
    [B-----5:R-:W-:Y:S13]      ISETP.NE.AND Pt3, PT, cret, RZ, PT
    [B------:R-:W-:Y:S05] @Pt3  BRA `(.gp_done)
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64], hit0
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64+0x8], hit2
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64+0x10], hit4
    [B------:R-:W-:-:S02]      STG.E.64 desc[uGD][frp0.64+0x18], hit6
    [B------:R-:W-:-:S02]      MEMBAR.ALL.CTA
    [B------:R-:W-:-:S02]      MEMBAR.SC.SYS
    [B------:R-:W-:-:S02]      ERRBAR
    [B------:R-:W-:-:S04]      CGAERRBAR
    [B------:R-:W-:-:S06]      STG.E desc[uGD][cadr0.64+0x4], newv
.gp_done:
}
