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
    [B------:R-:W-:-:S06]    IADD3.X Ro0, Pt0, Pt2, RFirst0, ~RSecond0, ~RThird0, PT, PT
    [B------:R-:W-:-:S06]    IADD3.X Ro1, Pt0, Pt2, RFirst1, ~RSecond1, ~RThird1, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro2, Pt0, Pt2, RFirst2, ~RSecond2, ~RThird2, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro3, Pt0, Pt2, RFirst3, ~RSecond3, ~RThird3, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro4, Pt0, Pt2, RFirst4, ~RSecond4, ~RThird4, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro5, Pt0, Pt2, RFirst5, ~RSecond5, ~RThird5, Pt0, Pt2
    [B------:R-:W-:-:S06]    IADD3.X Ro6, Pt0, Pt2, RFirst6, ~RSecond6, ~RThird6, Pt0, Pt2
    [B------:R-:W-:-:S06]    MOV Rt1, 0xFFFFFC2F
    [B------:R-:W-:Y:S09]    IADD3.X Ro7, Pt0, Pt2, RFirst7, ~RSecond7, ~RThird7, Pt0, Pt2
    [B------:R-:W-:-:S06]    SEL Rt0, Rt1, 0xFFFFF85E, Pt0
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro0, Pt1, PT, Ro0, Rt0, RZ, !PT, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro1, Pt1, PT, Ro1, 0xFFFFFFFD, RZ, Pt1, Pt0
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro2, Pt1, PT, Ro2, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro3, Pt1, PT, Ro3, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro4, Pt1, PT, Ro4, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro5, Pt1, PT, Ro5, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro6, Pt1, PT, Ro6, 0xFFFFFFFF, RZ, Pt1, !PT
    [B------:R-:W-:-:S06] @!Pt2 IADD3.X Ro7, PT,  PT, Ro7, 0xFFFFFFFF, RZ, Pt1, !PT
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

FUNCTION MulMod256()
{ //Ri_cnt=8+8, Ro_cnt=8, Rt_cnt=20, P=[0..4]
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 Ro0, RFirst0.reuse, RSecond0, RZ
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 Ro2, RFirst0, RSecond2, RZ
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro2, Pt4, RFirst1.reuse, RSecond1, Ro2
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro4, RFirst0, RSecond4, RZ, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro2, Pt4, RFirst2, RSecond0, Ro2
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Ro4, Pt4, RFirst1.reuse, RSecond3, Ro4, Pt4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro6, RFirst0, RSecond6, RZ, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro4, Pt4, RFirst2, RSecond2, Ro4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Ro6, Pt4, RFirst1.reuse, RSecond5, Ro6, Pt4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt12, RFirst1, RSecond7, RZ, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro4, Pt4, RFirst3, RSecond1, Ro4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Ro6, Pt4, RFirst2.reuse, RSecond4, Ro6, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt12, Pt4, RFirst2, RSecond6, Rt12, Pt4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt14, PT, RFirst3.reuse, RSecond7, RZ, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro4, Pt4, RFirst4, RSecond0, Ro4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Ro6, Pt4, RFirst3.reuse, RSecond3, Ro6, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt12, Pt4, RFirst3, RSecond5, Rt12, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt14, Pt4, RFirst4.reuse, RSecond6, Rt14, Pt4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt16, RFirst5, RSecond7, RZ, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro6, Pt4, RFirst4.reuse, RSecond2, Ro6
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt12, Pt4, RFirst4, RSecond4, Rt12, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt14, Pt4, RFirst5, RSecond5, Rt14, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt16, Pt4, RFirst6, RSecond6, Rt16, Pt4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt18, RFirst7, RSecond7, RZ, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro6, Pt4, RFirst5.reuse, RSecond1, Ro6
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt12, Pt4, RFirst5, RSecond3, Rt12, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt14, Pt4, RFirst6.reuse, RSecond4, Rt14, Pt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt16, Pt3, RFirst7, RSecond5, Rt16, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro6, Pt4, RFirst6.reuse, RSecond0, Ro6
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt12, Pt4, RFirst6, RSecond2, Rt12, Pt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt14, Pt2, RFirst7.reuse, RSecond3, Rt14, Pt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt12, Pt1, RFirst7, RSecond1, Rt12
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt0, RFirst0, RSecond1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Rt10, RZ, RZ, RZ, Pt1, !PT
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt0, Pt0, RFirst1, RSecond0, Rt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt2, RFirst0, RSecond3, RZ, Pt0
    [B------:R-:W-:-:S01]    IADD3.X Rt11, RZ, RZ, RZ, Pt2, !PT
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32 Rt2, Pt0, RFirst1, RSecond2, Rt2
    [B------:R-:W-:-:S01]    IADD3.X Rt18, Pt1, PT, Rt18, RZ, RZ, Pt3, !PT
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt4, RFirst0, RSecond5, RZ, Pt0
    [B------:R-:W-:-:S01]    IADD3 Ro1, Pt3, Ro1, Rt0, RZ
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32 Rt2, Pt0, RFirst2, RSecond1, Rt2
    [B------:R-:W-:-:S01]    IADD3.X Ro2, Pt3, Ro2, Rt1, RZ, Pt3, !PT
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt4, Pt0, RFirst1, RSecond4, Rt4, Pt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt0, RFirst0, RSecond7, RZ, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt2, Pt0, RFirst3, RSecond0, Rt2
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt4, Pt0, RFirst2, RSecond3, Rt4, Pt0
    [B------:R-:W-:-:S01]    IADD3.X Ro3, Pt3, Ro3, Rt2, RZ, Pt3, !PT
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32.X Rt0, Pt0, RFirst1, RSecond6, Rt0, Pt0
    [B------:R-:W-:-:S01]    IADD3.X Ro4, Pt3, Ro4, Rt3, RZ, Pt3, !PT
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt2, RFirst2, RSecond7, RZ, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt4, Pt0, RFirst3, RSecond2, Rt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt0, Pt0, RFirst2, RSecond5, Rt0, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt2, Pt0, RFirst3, RSecond6, Rt2, Pt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt6, RFirst4, RSecond7, RZ, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt4, Pt0, RFirst4, RSecond1, Rt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt0, Pt0, RFirst3, RSecond4, Rt0, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt2, Pt0, RFirst4, RSecond5, Rt2, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt6, Pt0, RFirst5, RSecond6, Rt6, Pt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt8, RFirst6, RSecond7, RZ, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt4, Pt0, RFirst5, RSecond0, Rt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt0, Pt0, RFirst4, RSecond3, Rt0, Pt0
    [B------:R-:W-:-:S01]    IADD3.X Ro5, Pt3, Ro5, Rt4, RZ, Pt3, !PT
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt2, Pt0, RFirst5, RSecond4, Rt2, Pt0
    [B------:R-:W-:-:S01]    IADD3.X Ro6, Pt3, Ro6, Rt5, RZ, Pt3, !PT
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt6, Pt0, RFirst6, RSecond5, Rt6, Pt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt8, Pt4, RFirst7, RSecond6, Rt8, Pt0
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32 Rt0, Pt0, RFirst5, RSecond2, Rt0
    [B------:R-:W-:-:S01]    IADD3.X Rt19, PT, PT, Rt19, RZ, RZ, Pt1, Pt4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt2, Pt0, RFirst6, RSecond3, Rt2, Pt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt6, Pt1, RFirst7, RSecond4, Rt6, Pt0
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt0, Pt0, RFirst6, RSecond1, Rt0

    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt2, Pt2, RFirst7, RSecond2, Rt2, Pt0
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt0, Pt4, RFirst7, RSecond0, Rt0
    [B------:R-:W-:-:S01]    IADD3.X Rt4, RZ, RZ, RZ, Pt2, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro7, Pt3, Ro7, Rt0, RZ, Pt3, !PT
    [B------:R-:W-:-:S04]    IADD3.X Rt12, Pt3, Rt12, Rt1, RZ, Pt3, !PT
    [B------:R-:W-:-:S01]    IADD3.X Rt13, Pt3, Pt4, Rt13, Rt2, RZ, Pt3, Pt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt0, Rt12, 0x3D1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Rt14, Pt3, Pt4, Rt14, Rt3, Rt10, Pt3, Pt4
    [B------:R-:W-:-:S01]    IADD3.X Rt10, RZ, RZ, RZ, Pt1, !PT
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt2, Pt2, Rt13, 0x3D1, Rt12, !PT
    [B------:R-:W-:-:S01]    IADD3.X Rt15, Pt3, Pt4, Rt15, Rt6, Rt4, Pt3, Pt4
    [B------:R-:W-:-:S01]    IADD3.X Ro0, Pt0, Pt1, Ro0, Rt0, RZ, !PT, !PT
    [B------:R-:W-:-:S01]    IADD3.X Rt16, Pt3, Pt4, Rt16, Rt7, Rt11, Pt3, Pt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt4, Rt14, 0x3D1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Rt17, Pt3, Pt4, Rt17, Rt8, Rt10, Pt3, Pt4
    [B------:R-:W-:-:S01]    IADD3.X Ro1, Pt0, Pt1, Rt1, Rt2, Ro1, Pt0, Pt1
    [B------:R-:W-:-:S01]    IADD3.X Rt18, Pt3, Pt4, Rt18, Rt9, RZ, Pt3, Pt4
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt6, Pt2, Rt15, 0x3D1, Rt14, Pt2
    [B------:R-:W-:-:S01]    IADD3.X Rt19, Rt19, RZ, RZ, Pt3, Pt4
    [B------:R-:W-:-:S01]    IADD3.X Ro2, Pt0, Pt1, Rt3, Rt4, Ro2, Pt0, Pt1
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt8, Rt16, 0x3D1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Ro3, Pt0, Pt1, Rt5, Rt6, Ro3, Pt0, Pt1
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt4, Pt2, Rt17, 0x3D1, Rt16, Pt2
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 Rt0, Rt18, 0x3D1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Ro4, Pt0, Pt1, Rt7, Rt8, Ro4, Pt0, Pt1
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Rt2, Pt2, Rt19, 0x3D1, Rt18, Pt2
    [B------:R-:W-:-:S04]    IADD3.X Ro5, Pt0, Pt1, Rt9, Rt4, Ro5, Pt0, Pt1
    [B------:R-:W-:-:S04]    IADD3.X Ro6, Pt0, Pt1, Rt5, Rt0, Ro6, Pt0, Pt1
    [B------:R-:W-:-:S04]    IADD3.X Ro7, Pt0, Pt1, Rt1, Rt2, Ro7, Pt0, Pt1
    [B------:R-:W-:-:S04]    IADD3.X Rt8, Pt0, PT, Rt3, RZ, RZ, Pt0, Pt1
    [B------:R-:W-:-:S01]    IADD3.X Rt9, Pt0, Pt1, RZ, RZ, RZ, Pt0, Pt2
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32.X Ro0, Pt3, Rt8, 0x3D1, Ro0, !PT
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32 Rt2, Rt9, 0x3D1, Rt8 //no carry occurs!
    [B------:R-:W-:-:S04]    IADD3.X Ro1, Pt0, PT, Ro1, Rt2, RZ, !PT, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro2, Pt0, Pt1, Rt3, Ro2, RZ, Pt0, Pt3
    [B------:R-:W-:-:S04]    IADD3.X Ro3, Pt0, PT, Ro3, RZ, RZ, Pt0, Pt1
    [B------:R-:W-:-:S04]    IADD3.X Ro4, Pt0, PT, Ro4, RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro5, Pt0, PT, Ro5, RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro6, Pt0, PT, Ro6, RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Ro7, PT, PT, Ro7, RZ, RZ, Pt0, !PT
}

FUNCTION SqrMod256(First=Ri0)
{ //Ri_cnt=8, Ro_cnt=8, Rt_cnt=26 (SqrT=R96..R121), P=[0..6]. Z+V square core + F/G/M fold:
  // compute the 28 cross products once (12 even, 16 odd), double, add the 8 squares, then
  // fold by C=2^32+977 as MulMod256 does. -33 instr / -49 wslots vs the compute-twice form.
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt14, First0, First3, RZ                     // O3  = a0a3
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt12, First0, First1, RZ                     // O1  = a0a1
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 Rt14, Pt0, First1, First2, Rt14              // O3 += a1a2            ->d1
    [B------:R-:W-:-:S03]    IADD3 Rt12, Pt1, Rt12, Rt12, RZ                            // v1 = 2*o1   (in place)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt0, First0, First2, RZ                      // E2  = a0a2
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt2, First0, First4, RZ                      // E4  = a0a4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Ro0, First0, First0, RZ                      // Z0  = a0^2
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt16, First0, First5, RZ, Pt0              // O5  = a0a5 +d1
    [B------:R-:W-:-:S03]    IADD3 Ro1, Pt0, Ro1, Rt12, RZ                              // S1 = z1 + v1
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt2, Pt2, First1, First3, Rt2                // E4 += a1a3            ->c1
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 Ro2, Pt3, First1, First1, Rt0                // Z1  = a1^2 + E2        ->z1
    [B------:R-:W-:-:S03]    IADD3.X Rt0, Pt1, Pt4, Rt0, Rt13, Rt13, Pt1, !PT           // v2 = e2 + 2*o2
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 Rt16, Pt5, First1, First4, Rt16              // O5 += a1a4            ->d2
    [B------:R-:W-:-:S02]    IADD3.X Rt1, Pt1, Pt4, Rt1, Rt14, Rt14, Pt1, Pt4           // v3 = e3 + 2*o3
    [B------:R-:W-:-:S01]    IADD3.X Ro2, Pt0, Ro2, Rt0, RZ, Pt0, !PT                   // S[2:3] = Z1 + V[2:3] (lo)
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32.X Rt4, First0, First6, RZ, Pt2               // E6  = a0a6 +c1
    [B------:R-:W-:-:S01]    IADD3.X Ro3, Pt0, Ro3, Rt1, RZ, Pt0, !PT                   // S[2:3] = Z1 + V[2:3] (hi)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt16, Pt2, First2, First3, Rt16              // O5 += a2a3            ->d3
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt18, First0, First7, RZ, Pt5              // O7  = a0a7 +d2
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt4, Pt5, First1, First5, Rt4                // E6 += a1a5            ->c2
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro4, Pt3, First2, First2, Rt2, Pt3         // Z2  = a2^2 + E4 +z1    ->z2
    [B------:R-:W-:-:S03]    IADD3.X Rt2, Pt1, Pt4, Rt2, Rt15, Rt15, Pt1, Pt4           // v4 = e4 + 2*o4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt18, Pt2, First1, First6, Rt18, Pt2       // O7 += a1a6 +d3        ->d3b
    [B------:R-:W-:-:S02]    IADD3.X Rt3, Pt1, Pt4, Rt3, Rt16, Rt16, Pt1, Pt4           // v5 = e5 + 2*o5
    [B------:R-:W-:-:S01]    IADD3.X Ro4, Pt0, Ro4, Rt2, RZ, Pt0, !PT                   // S[4:5] = Z2 + V[4:5] (lo)
    [B------:R-:W-:-:S03]    IMAD.WIDE.U32 Rt4, Pt6, First2, First4, Rt4                // E6 += a2a4            ->c3
    [B------:R-:W-:-:S01]    IADD3.X Ro5, Pt0, Ro5, Rt3, RZ, Pt0, !PT                   // S[4:5] = Z2 + V[4:5] (hi)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt6, First1, First7, RZ, Pt5               // E8  = a1a7 +c2
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt18, Pt5, First2, First5, Rt18              // O7 += a2a5            ->d4
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt6, Pt6, First2, First6, Rt6, Pt6         // E8 += a2a6 +c3        ->c3b
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro6, Pt3, First3, First3, Rt4, Pt3         // Z3  = a3^2 + E6 +z2    ->z3
    [B------:R-:W-:-:S03]    IADD3.X Rt4, Pt1, Pt4, Rt4, Rt17, Rt17, Pt1, Pt4           // v6 = e6 + 2*o6
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt20, First2, First7, RZ, Pt2              // O9  = a2a7 +d3b
    [B------:R-:W-:-:S03]    IADD3.X Ro6, Pt0, Ro6, Rt4, RZ, Pt0, !PT                   // S[6:7] = Z3 + V[6:7] (lo)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt18, Pt2, First3, First4, Rt18              // O7 += a3a4            ->d5
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt20, Pt5, First3, First6, Rt20, Pt5       // O9 += a3a6 +d4        ->d4b
    [B------:R-:W-:-:S03]    IADD3.X Rt5, Pt1, Pt4, Rt5, Rt18, Rt18, Pt1, Pt4           // v7 = e7 + 2*o7
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt8, First3, First7, RZ, Pt6               // E10 = a3a7 +c3b
    [B------:R-:W-:-:S03]    IADD3.X Ro7, Pt0, Ro7, Rt5, RZ, Pt0, !PT                   // S[6:7] = Z3 + V[6:7] (hi)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32 Rt6, Pt6, First3, First5, Rt6                // E8 += a3a5            ->c4
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt12, Pt3, First4, First4, Rt6, Pt3        // Z4  = a4^2 + E8 +z3    ->z4
    [B------:R-:W-:-:S03]    IADD3.X Rt6, Pt1, Pt4, Rt6, Rt19, Rt19, Pt1, Pt4           // v8 = e8 + 2*o8
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt20, Pt2, First4, First5, Rt20, Pt2       // O9 += a4a5 +d5        ->d5b
    [B------:R-:W-:-:S03]    IADD3.X Rt6, Pt0, Rt12, Rt6, RZ, Pt0, !PT                  // H[0:1] = S[8:9] = Z4 + V[8:9] (lo)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt8, Pt6, First4, First6, Rt8, Pt6         // E10+= a4a6 +c4        ->c4b
    [B------:R-:W-:-:S03]    IADD3.X Rt7, Pt1, Pt4, Rt7, Rt20, Rt20, Pt1, Pt4           // v9 = e9 + 2*o9
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt22, First4, First7, RZ, Pt5              // O11 = a4a7 +d4b
    [B------:R-:W-:-:S03]    IADD3.X Rt7, Pt0, Rt13, Rt7, RZ, Pt0, !PT                  // H[0:1] = S[8:9] = Z4 + V[8:9] (hi)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt14, Pt3, First5, First5, Rt8, Pt3        // Z5  = a5^2 + E10 +z4   ->z5
    [B------:R-:W-:-:S03]    IADD3.X Rt8, Pt1, Pt4, Rt8, Rt21, Rt21, Pt1, Pt4           // v10= e10 + 2*o10
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt22, Pt2, First5, First6, Rt22, Pt2       // O11+= a5a6 +d5b       ->d5c
    [B------:R-:W-:-:S03]    IADD3.X Rt8, Pt0, Rt14, Rt8, RZ, Pt0, !PT                  // H[2:3] = S[10:11] = Z5 + V[10:11] (lo)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt10, First5, First7, RZ, Pt6              // E12 = a5a7 +c4b
    [B------:R-:W-:-:S03]    IADD3.X Rt9, Pt1, Pt4, Rt9, Rt22, Rt22, Pt1, Pt4           // v11= e11 + 2*o11
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro0, Pt5, Rt6, 0x3D1, Ro0, !PT             // F0: {Ro1:Ro0} += h0*977          ->f
    [B------:R-:W-:-:S03]    IADD3.X Rt9, Pt0, Rt15, Rt9, RZ, Pt0, !PT                  // H[2:3] = S[10:11] = Z5 + V[10:11] (hi)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Rt0, Pt6, Rt7, 0x3D1, Rt6, !PT             // G0: {Rt1:Rt0} = h1*977 + {h1:h0} ->g
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt16, Pt3, First6, First6, Rt10, Pt3       // Z6  = a6^2 + E12 +z5   ->z6
    [B------:R-:W-:-:S03]    IADD3.X Rt10, Pt1, Pt4, Rt10, Rt23, Rt23, Pt1, Pt4         // v12= e12 + 2*o12
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt24, First6, First7, RZ, Pt2              // O13 = a6a7 +d5c
    [B------:R-:W-:-:S02]    IADD3 Ro1, Pt2, Ro1, Rt0, RZ                               // M1: Ro1 += G0lo
    [B------:R-:W-:-:S01]    IADD3.X Rt10, Pt0, Rt16, Rt10, RZ, Pt0, !PT                // H[4:5] = S[12:13] = Z6 + V[12:13] (lo)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro2, Pt5, Rt8, 0x3D1, Ro2, Pt5             // F1: {Ro3:Ro2} += h2*977 +f      ->f
    [B------:R-:W-:-:S03]    IADD3.X Rt11, Pt1, Pt4, Rt11, Rt24, Rt24, Pt1, Pt4         // v13= e13 + 2*o13
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt2, Pt6, Rt9, 0x3D1, Rt8, Pt6             // G1: {Rt3:Rt2} = h3*977 + {h3:h2} +g
    [B------:R-:W-:-:S02]    IADD3.X Ro2, Pt2, Ro2, Rt1, RZ, Pt2, !PT                   // M2: Ro2 += G0hi
    [B------:R-:W-:-:S01]    IADD3.X Rt24, Pt1, PT, Rt25, Rt25, RZ, Pt1, Pt4            // v14= 2*o14 (+carry<=1)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt18, First7, First7, RZ, Pt3              // Z7  = a7^2 +z6
    [B------:R-:W-:-:S02]    IADD3.X Rt11, Pt0, Rt17, Rt11, RZ, Pt0, !PT                // H[4:5] = S[12:13] = Z6 + V[12:13] (hi)
    [B------:R-:W-:-:S01]    IADD3.X Ro3, Pt2, Ro3, Rt2, RZ, Pt2, !PT                   // M3: Ro3 += G1lo
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro4, Pt3, Rt10, 0x3D1, Ro4, Pt5            // F2: {Ro5:Ro4} += h4*977 +f      ->f
    [B------:R-:W-:-:S02]    IADD3.X Rt25, RZ, RZ, RZ, Pt1, !PT                         // v15= carry
    [B------:R-:W-:-:S01]    IADD3.X Rt18, Pt0, Rt18, Rt24, RZ, Pt0, !PT                // H[6:7] = S[14:15] = Z7 + V[14:15] (lo)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt4, Pt1, Rt11, 0x3D1, Rt10, Pt6           // G2: {Rt5:Rt4} = h5*977 + {h5:h4} +g
    [B------:R-:W-:-:S02]    IADD3.X Ro4, Pt2, Ro4, Rt3, RZ, Pt2, !PT                   // M4: Ro4 += G1hi
    [B------:R-:W-:-:S01]    IADD3.X Rt19, Rt19, Rt25, RZ, Pt0, !PT                     // H[6:7] = S[14:15] = Z7 + V[14:15] (hi)
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Ro6, Pt0, Rt18, 0x3D1, Ro6, Pt3            // F3: {Ro7:Ro6} += h6*977 +f      ->f(word 8)
    [B------:R-:W-:-:S03]    IADD3.X Ro5, Pt2, Ro5, Rt4, RZ, Pt2, !PT                   // M5: Ro5 += G2lo
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32.X Rt12, Pt1, Rt19, 0x3D1, Rt18, Pt1          // G3: {Rt13:Rt12} = h7*977 + {h7:h6} +g ->g(word 9)
    [B------:R-:W-:-:S04]    IADD3.X Ro6, Pt2, Ro6, Rt5, RZ, Pt2, !PT                   // M6: Ro6 += G2hi
    [B------:R-:W-:-:S04]    IADD3.X Ro7, Pt2, Ro7, Rt12, RZ, Pt2, !PT                  // M7: Ro7 += G3lo
    [B------:R-:W-:-:S04]    IADD3.X Rt14, Pt0, Rt13, RZ, RZ, Pt2, Pt0                  // OVlo = G3hi + m + f
    [B------:R-:W-:-:S01]    IADD3.X Rt15, RZ, RZ, RZ, Pt1, Pt0                         // OVhi = g + x  (<=2)
    [B------:R-:W-:-:S04]    IMAD.WIDE.U32.X Ro0, Pt0, Rt14, 0x3D1, Ro0, !PT            // {Ro1:Ro0} += OVlo*977          ->t (word 2)
    [B------:R-:W-:-:S05]    IMAD.WIDE.U32 Rt16, Rt15, 0x3D1, Rt14                      // {Rt17:Rt16} = OVhi*977 + {OVhi:OVlo} (no carry)
    [B------:R-:W-:-:S04]    IADD3 Ro1, Pt1, Ro1, Rt16, RZ                              // Ro1 += lo
    [B------:R-:W-:-:S04]    IADD3.X Ro2, Pt0, Ro2, Rt17, RZ, Pt1, Pt0                  // Ro2 += hi + r + t (carry<=1)
    [B------:R-:W-:-:S04]    IADD3.X Ro3, Pt0, Ro3, RZ, RZ, Pt0, !PT                    // Ro3 += r
    [B------:R-:W-:-:S04]    IADD3.X Ro4, Pt0, Ro4, RZ, RZ, Pt0, !PT                    // {Ro5:Ro4} += r (lo)
    [B------:R-:W-:-:S04]    IADD3.X Ro5, Pt0, Ro5, RZ, RZ, Pt0, !PT                    // {Ro5:Ro4} += r (hi)
    [B------:R-:W-:-:S04]    IADD3.X Ro6, Pt0, Ro6, RZ, RZ, Pt0, !PT                    // {Ro7:Ro6} += r, final carry dropped (= Math.cuh) (lo)
    [B------:R-:W-:-:S06]    IADD3.X Ro7, Ro7, RZ, RZ, Pt0, !PT                         // {Ro7:Ro6} += r, final carry dropped (= Math.cuh) (hi)
}

FUNCTION _fast_find_first_bit()
{ //Ro_cnt=1, Rt_cnt=2, Rval, Rone, Rbc
    [B------:R-:W-:-:S04]    SHF.L.U32 Rt0, Rone, Rbc, RZ
    [B------:R-:W-:-:S04]    LOP3.LUT Rt0, Rt0, Rval, RZ, 0xfc, !PT
    [B------:R-:W-:-:S04]    IADD3 Rt1, -Rt0, RZ, RZ
    [B------:R-:W-:-:S04]    LOP3.LUT Rt0, Rt0, Rt1, RZ, 0xc0, !PT //(z & -z)
    [B------:R-:W-:-:S04]    I2FP.F32.S32 Rt0, Rt0
    [B------:R-:W-:-:S04]    LEA.HI Ro0, Rt0, 0xffffff81, RZ, 9 //(int >> 23) - 127
}

FUNCTION _mul_256_by_i32(val=Rt8)
{ //Ro_cnt=9, Rt_cnt=6, Pt=[0..2]  Rval, Ri
    [B------:R-:W-:-:S04] @Pt3 IABS val, Ri
    [B------:R-:W-:-:S01]    ISETP.LT.AND Pt1, PT, Ri, RZ, Pt3
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro0, Rval, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt0, Rval1, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro2, Rval2, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3 Ro1, Pt2, Ro1, Rt0, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt2, Rval3, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro2, Pt2, Ro2, Rt1, RZ, Pt2, !PT
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro0, Pt0, PT, RZ, ~Ro0, RZ, PT, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro4, Rval4, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro3, Pt2, Ro3, Rt2, RZ, Pt2, !PT
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro1, Pt0, PT, RZ, ~Ro1, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt4, Rval5, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro4, Pt2, Ro4, Rt3, RZ, Pt2, !PT
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro2, Pt0, PT, RZ, ~Ro2, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro6, Rval6, val.reuse, RZ
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro3, Pt0, PT, RZ, ~Ro3, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro5, Pt2, Ro5, Rt4, RZ, Pt2, !PT
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro4, Pt0, PT, RZ, ~Ro4, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt0, Rval7, val, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro6, Pt2, Ro6, Rt5, RZ, Pt2, !PT
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro5, Pt0, PT, RZ, ~Ro5, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro7, Pt2, Ro7, Rt0, RZ, Pt2, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro6, Pt0, PT, RZ, ~Ro6, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.X.U32 Ro8, Rval8, val, Rt1, Pt2
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro7, Pt0, PT, RZ, ~Ro7, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt1 IADD3.X Ro8, PT, PT, RZ, ~Ro8, RZ, Pt0, !PT
}

FUNCTION _mul_256_by_u31()
{ //Ro_cnt=9, Rt_cnt=6, Pt=[0]  Rval, Ri
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro0, Rval, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt0, Rval1, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro2, Rval2, Ri, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3 Ro1, Pt0, Ro1, Rt0, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt2, Rval3, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro2, Pt0, Ro2, Rt1, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro4, Rval4, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro3, Pt0, Ro3, Rt2, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt4, Rval5, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro4, Pt0, Ro4, Rt3, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Ro6, Rval6, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro5, Pt0, Ro5, Rt4, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt0, Rval7, Ri.reuse, RZ
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro6, Pt0, Ro6, Rt5, RZ, Pt0, !PT
    [B------:R-:W-:Y:S05] @Pt3 IADD3.X Ro7, Pt0, Ro7, Rt0, RZ, Pt0, !PT
    [B------:R-:W-:Y:S01] @Pt3 IMAD.X.U32 Ro8, Rval8, Ri, Rt1, Pt0
}

FUNCTION _mul_256_by_u31_add_shift(tmp=Rt6)
{ //Ro_cnt=9, Rt_cnt=15, Pt=[0,1]  Rval, Ri, Radd
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 tmp0, Rval, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt0, Rval1, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3 tmp0, Pt0, PT, tmp0, RZ, Radd0, !PT, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 tmp2, Rval2, Ri, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3 tmp1, Pt0, Pt1, tmp1, Rt0, Radd1, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt2, Rval3, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp2, Pt0, Pt1, tmp2, Rt1, Radd2, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 tmp4, Rval4, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp3, Pt0, Pt1, tmp3, Rt2, Radd3, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt4, Rval5, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp4, Pt0, Pt1, tmp4, Rt3, Radd4, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 tmp6, Rval6, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp5, Pt0, Pt1, tmp5, Rt4, Radd5, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 IMAD.WIDE.U32 Rt0, Rval7, Ri.reuse, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp6, Pt0, Pt1, tmp6, Rt5, Radd6, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro0, tmp0, 30, tmp1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro1, tmp1, 30, tmp2
    [B------:R-:W-:-:S01] @Pt3 IMAD.U32 tmp8, Rval8, Ri, Rt1
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp7, Pt0, Pt1, tmp7, Rt0, Radd7, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro2, tmp2, 30, tmp3
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro3, tmp3, 30, tmp4
    [B------:R-:W-:-:S01] @Pt3 IADD3.X tmp8, PT, PT, tmp8, RZ, Radd8, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro4, tmp4, 30, tmp5
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro5, tmp5, 30, tmp6
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro6, tmp6, 30, tmp7
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro7, tmp7, 30, tmp8
    [B------:R-:W-:-:S01] @Pt3 SHF.R.S32.HI Ro8, RZ, 30, tmp8
}

FUNCTION _mul_P_by_32_add_shift(val=Rt0)
{ //Ro_cnt=9, Rt_cnt=1, Pt=[0,1],  Rval, RaddA
    [B------:R-:W-:-:S05] @Pt3 IMAD.U32 val, Rval, 0xD2253531, RZ
    [B------:R-:W-:-:S05] @Pt3 LOP3.LUT val, val, 0x3fffffff, RZ, 0xc0, !PT
    [B------:R-:W-:-:S03] @Pt3 IMAD.WIDE.U32 Ro0, val, 0x000003D1, RZ
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro0, Pt0, PT, RaddA0, ~Ro0, RZ, !PT, PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro1, Pt0, Pt1, RaddA1, ~Ro1, ~val, Pt0, PT
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro2, Pt0, PT, RaddA2, 0xFFFFFFFE, RZ, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro0, Ro0, 30, Ro1
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro3, Pt0, PT, RaddA3, ~RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro1, Ro1, 30, Ro2
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro4, Pt0, PT, RaddA4, ~RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro2, Ro2, 30, Ro3
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro5, Pt0, PT, RaddA5, ~RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro3, Ro3, 30, Ro4
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro6, Pt0, PT, RaddA6, ~RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro4, Ro4, 30, Ro5
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro7, Pt0, PT, RaddA7, ~RZ, RZ, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro5, Ro5, 30, Ro6
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro8, PT, PT, val, ~RZ, RaddA8, Pt0, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro6, Ro6, 30, Ro7
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro7, Ro7, 30, Ro8
    [B------:R-:W-:-:S01] @Pt3 SHF.R.S32.HI Ro8, RZ, 30, Ro8
}

FUNCTION _mul_P_by_32_add3_shift(val=Rt0)
{ //Ro_cnt=9, Rt_cnt=1, Pt=[0..2],  Rval
    [B------:R-:W-:-:S05] @Pt3 IMAD.U32 val, Rval, 0xD2253531, RZ
    [B------:R-:W-:-:S05] @Pt3 LOP3.LUT val, val, 0x3fffffff, RZ, 0xc0, !PT
    [B------:R-:W-:-:S05] @Pt3 IMAD.WIDE.U32 Ro0, val, 0x000003D1, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro0, Pt0, Pt1, RaddA0, ~Ro0, RaddB0, !PT, PT
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro1, Pt2, PT, Ro1, val, RZ, !PT, !PT
    [B------:R-:W-:-:S01] @Pt3 IADD3 val, val, -0x1, RZ
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro1, Pt0, Pt1, RaddA1, ~Ro1, RaddB1, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro2, PT, PT, RZ, RZ, RZ, Pt2, !PT
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro0, Ro0, 30, Ro1
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro2, Pt0, Pt1, RaddA2, ~Ro2, RaddB2, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro3, Pt0, Pt1, RaddA3, ~RZ, RaddB3, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro1, Ro1, 30, Ro2
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro4, Pt0, Pt1, RaddA4, ~RZ, RaddB4, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro2, Ro2, 30, Ro3
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro5, Pt0, Pt1, RaddA5, ~RZ, RaddB5, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro3, Ro3, 30, Ro4
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro6, Pt0, Pt1, RaddA6, ~RZ, RaddB6, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro4, Ro4, 30, Ro5
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro7, Pt0, Pt1, RaddA7, ~RZ, RaddB7, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro5, Ro5, 30, Ro6
    [B------:R-:W-:-:S01] @Pt3 IADD3.X Ro8, PT, PT, val, RaddA8, RaddB8, Pt0, Pt1
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro6, Ro6, 30, Ro7
    [B------:R-:W-:-:S01] @Pt3 SHF.R.U32 Ro7, Ro7, 30, Ro8
    [B------:R-:W-:-:S01] @Pt3 SHF.R.S32.HI Ro8, RZ, 30, Ro8
}

FUNCTION _mul_P_by_32_add3_shift_nopredicate(val=Rt0)
{ //Ro_cnt=9, Rt_cnt=1, Pt=[0..2],  Rval
    [B------:R-:W-:-:S05]    IMAD.U32 val, Rval, 0xD2253531, RZ
    [B------:R-:W-:-:S05]    LOP3.LUT val, val, 0x3fffffff, RZ, 0xc0, !PT
    [B------:R-:W-:-:S05]    IMAD.WIDE.U32 Ro0, val, 0x000003D1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Ro0, Pt0, Pt1, RaddA0, ~Ro0, RaddB0, !PT, PT
    [B------:R-:W-:-:S01]    IADD3.X Ro1, Pt2, PT, Ro1, val, RZ, !PT, !PT
    [B------:R-:W-:-:S01]    IADD3 val, val, -0x1, RZ
    [B------:R-:W-:-:S01]    IADD3.X Ro1, Pt0, Pt1, RaddA1, ~Ro1, RaddB1, Pt0, Pt1
    [B------:R-:W-:-:S01]    IADD3.X Ro2, PT, PT, RZ, RZ, RZ, Pt2, !PT
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro0, Ro0, 30, Ro1
    [B------:R-:W-:-:S04]    IADD3.X Ro2, Pt0, Pt1, RaddA2, ~Ro2, RaddB2, Pt0, Pt1
    [B------:R-:W-:-:S01]    IADD3.X Ro3, Pt0, Pt1, RaddA3, ~RZ, RaddB3, Pt0, Pt1
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro1, Ro1, 30, Ro2
    [B------:R-:W-:-:S01]    IADD3.X Ro4, Pt0, Pt1, RaddA4, ~RZ, RaddB4, Pt0, Pt1
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro2, Ro2, 30, Ro3
    [B------:R-:W-:-:S01]    IADD3.X Ro5, Pt0, Pt1, RaddA5, ~RZ, RaddB5, Pt0, Pt1
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro3, Ro3, 30, Ro4
    [B------:R-:W-:-:S01]    IADD3.X Ro6, Pt0, Pt1, RaddA6, ~RZ, RaddB6, Pt0, Pt1
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro4, Ro4, 30, Ro5
    [B------:R-:W-:-:S01]    IADD3.X Ro7, Pt0, Pt1, RaddA7, ~RZ, RaddB7, Pt0, Pt1
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro5, Ro5, 30, Ro6
    [B------:R-:W-:-:S01]    IADD3.X Ro8, PT, PT, val, RaddA8, RaddB8, Pt0, Pt1
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro6, Ro6, 30, Ro7
    [B------:R-:W-:-:S01]    SHF.R.U32 Ro7, Ro7, 30, Ro8
    [B------:R-:W-:-:S01]    SHF.R.S32.HI Ro8, RZ, 30, Ro8
}

FUNCTION InvMod256(val=Ri0, modp=Rt0, uu=Rt9, aa=Rt10, vv=Rt19, tmpA=Rt20, uv=Rt29, tmpB=Rt30, vu=Rt39, tmpC=Rt40, zeros=Rt20, _val=Rt49, _modp=Rt50, bc=Rt21, mulA=Rt22, mulB=Rt23, one=Rt51, two=URt0, tempA=Rt52, tempB=Rt53, tmpD=Rt54, tvars=Rt64)
{ //Ri_cnt=9(will be spoiled!), Ro_cnt=9, P=[0..3]
    [B------:R-:W-:-:S01]    MOV modp0, 0xFFFFFC2F
    [B------:R-:W-:-:S01]    IMAD modp1, RZ, RZ, 0xFFFFFFFE
    [B------:R-:W-:-:S01]    MOV modp2, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    IMAD modp3, RZ, RZ, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    MOV modp4, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    IMAD modp5, RZ, RZ, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    MOV modp6, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    IMAD modp7, RZ, RZ, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    MOV modp8, 0x00
    [B------:R-:W-:-:S01]    IMAD val8, RZ, RZ, RZ
    [B------:R-:W-:-:S01]    MOV one, 0x01
    [B------:R-:W-:-:S01]    UMOV two, 0x02
    [B------:R-:W-:-:S01]    MOV bc, 30
    [B------:R-:W-:-:S01]    MOV uu, 0x01
    [B------:R-:W-:-:S01]    IMAD vv, RZ, RZ, 0x01
    [B------:R-:W-:-:S01]    MOV uv, 0x00
    [B------:R-:W-:-:S01]    IMAD vu, RZ, RZ, 0x00
    [B------:R-:W-:-:S01]    MOV _val, val0
    [B------:R-:W-:-:S01]    IMAD _modp, RZ, RZ, modp0

inc_func _fast_find_first_bit(Ro=zeros, Rt=tvars, Rval=_val, Rone=one, Rbc=bc)

    [B------:R-:W-:-:S01]    ISETP.EQ.AND Pt3, PT, RZ, RZ, PT

    [B------:R-:W-:-:S01]    IADD3 bc, bc, -zeros, RZ
    [B------:R-:W-:-:S01]    SHF.L.U32 uu, uu, zeros, RZ
    [B------:R-:W-:-:S03]    ISETP.GT.AND Pt0, PT, bc, RZ, PT
    [B------:R-:W-:-:S01]    SHF.L.U32 uv, uv, zeros, RZ
    [B------:R-:W-:-:S04]    SHF.R.S32.HI _val, RZ, zeros, _val
    [B------:R-:W-:-:S05]    LOP3.LUT tvars, _val, two, _modp, 0x48, !PT
.label_Start0:
    [B------:R-:W-:-:S02] @Pt0 IMAD mulA, tvars, one, -0x1
    [B------:R-:W-:-:S01] @Pt0 SHF.L.U32 tempA, one, bc, RZ
    [B------:R-:W-:-:S01]    BRA.CONV !Pt0, ~URZ `(.label_Done0)
    [B------:R-:W-:-:S01] @Pt0 IMAD _val, mulA, _modp, _val
    [B------:R-:W-:-:S04] @Pt0 IADD3 mulB, -mulA, RZ, RZ
    [B------:R-:W-:-:S01] @Pt0 LOP3.LUT tempA, tempA, _val, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01] @Pt0 IMAD _modp, mulB, _val, _modp
    [B------:R-:W-:-:S01] @Pt0 IMAD vu, mulA, uu, vu
    [B------:R-:W-:-:S03] @Pt0 IADD3 tempB, -tempA, RZ, RZ
    [B------:R-:W-:-:S01] @Pt0 IMAD vv, mulA, uv, vv
    [B------:R-:W-:-:S03] @Pt0 LOP3.LUT tempA, tempA, tempB, RZ, 0xc0, !PT
    [B------:R-:W-:-:S01] @Pt0 IMAD uu, mulB, vu, uu
    [B------:R-:W-:-:S03] @Pt0 I2FP.F32.S32 tempA, tempA
    [B------:R-:W-:-:S01] @Pt0 IMAD uv, mulB, vv, uv
    [B------:R-:W-:-:S04] @Pt0 LEA.HI zeros, tempA, 0xffffff81, RZ, 9
    [B------:R-:W-:-:S01] @Pt0 IADD3 bc, bc, -zeros, RZ
    [B------:R-:W-:-:S01] @Pt0 SHF.L.U32 uu, uu, zeros, RZ
    [B------:R-:W-:-:S01] @Pt0 SHF.L.U32 uv, uv, zeros, RZ
    [B------:R-:W-:-:S01] @Pt0 SHF.R.S32.HI _val, RZ, zeros, _val
    [B------:R-:W-:-:S01]    ISETP.GT.AND Pt0, PT, bc, RZ, Pt0
    [B------:R-:W-:-:S01] @Pt0 LOP3.LUT tvars, _val, two, _modp, 0x48, !PT // Rt = (Rv ^ Rm) & 0x2
    [B------:R-:W-:Y:S01]    BRA `(.label_Start0)
.label_Done0:

    [B------:R-:W-:Y:S04]    ISETP.LT.AND Pt0, PT, uu, RZ, PT
    [B------:R-:W-:Y:S09]    ISETP.LT.AND Pt1, PT, vv, RZ, PT
    [B------:R-:W-:-:S01] @Pt0 IADD3 uv, RZ, RZ, -uv
    [B------:R-:W-:-:S01] @Pt0 IADD3 uu, RZ, RZ, -uu
    [B------:R-:W-:-:S01] @Pt1 IADD3 vv, RZ, RZ, -vv
    [B------:R-:W-:-:S01] @Pt1 IMAD vu, RZ, RZ, -vu

inc_func _mul_256_by_i32(Ro=tmpB, Pt=0, Rval=val, Ri=uv, Rt=tvars)
inc_func _mul_256_by_i32(Ro=tmpC, Pt=0, Rval=modp, Ri=vu, Rt=tvars)
inc_func _mul_256_by_u31_add_shift(Ro=val, Pt=0, Rval=val, Ri=vv, Radd=tmpC, Rt=tmpD)
inc_func _mul_256_by_u31_add_shift(Ro=modp, Pt=0, Rval=modp, Ri=uu, Radd=tmpB, Rt=tmpD)

    [B------:R-:W-:-:S04]    SHF.R.S32.HI tmpB1, RZ, 0x1f, uv
    [B------:R-:W-:-:S01]    MOV tmpB0, uv
    [B------:R-:W-:-:S01]    MOV tmpB2, tmpB1
    [B------:R-:W-:-:S01]    IMAD tmpB3, RZ, RZ, tmpB1
    [B------:R-:W-:-:S01]    MOV tmpB4, tmpB1
    [B------:R-:W-:-:S01]    IMAD tmpB5, RZ, RZ, tmpB1
    [B------:R-:W-:-:S01]    MOV tmpB6, tmpB1
    [B------:R-:W-:-:S01]    IMAD tmpB7, RZ, RZ, tmpB1
    [B------:R-:W-:-:S01]    MOV tmpB8, tmpB1
    [B------:R-:W-:-:S01]    IMAD tmpD0, RZ, RZ, vv
    [B------:R-:W-:-:S01]    MOV tmpD1, 0x00
    [B------:R-:W-:-:S01]    IMAD tmpD2, RZ, RZ, 0x00
    [B------:R-:W-:-:S01]    MOV tmpD3, 0x00
    [B------:R-:W-:-:S01]    IMAD tmpD4, RZ, RZ, 0x00
    [B------:R-:W-:-:S01]    MOV tmpD5, 0x00
    [B------:R-:W-:-:S01]    IMAD tmpD6, RZ, RZ, 0x00
    [B------:R-:W-:-:S01]    MOV tmpD7, 0x00
    [B------:R-:W-:-:S01]    MOV tmpD8, 0x00

inc_func _mul_P_by_32_add_shift(Ro=Ro0, Pt=0, Rval=tmpB, RaddA=tmpB, Rt=tvars)
inc_func _mul_P_by_32_add_shift(Ro=aa, Pt=0, Rval=tmpD, , RaddA=tmpD, Rt=tvars)

.label_Start2:
    [B------:R-:W-:-:S02] @Pt3 MOV tvars0, 0x40000000
    [B------:R-:W-:-:S01] @Pt3 IMAD bc, RZ, RZ, 30
    [B------:R-:W-:-:S01] @Pt3 IMAD _modp, modp0, 0x01, RZ
    [B------:R-:W-:-:S03] @Pt3 LOP3.LUT tvars0, tvars0, val0, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01] @Pt3 IMAD vu, RZ, RZ, RZ
    [B------:R-:W-:-:S03] @Pt3 IADD3 tvars1, -tvars0, RZ, RZ
    [B------:R-:W-:-:S01] @Pt3 IMAD uv, RZ, RZ, RZ
    [B------:R-:W-:-:S02] @Pt3 LOP3.LUT tvars0, tvars0, tvars1, RZ, 0xc0, !PT
    [B------:R-:W-:-:S04] @Pt3 MOV uu, 0x01
    [B------:R-:W-:-:S02] @Pt3 I2FP.F32.S32 tvars0, tvars0
    [B------:R-:W-:-:S04] @Pt3 MOV vv, 0x01
    [B------:R-:W-:-:S02] @Pt3 LEA.HI zeros, tvars0, 0xffffff81, RZ, 9
    [B------:R-:W-:-:S04] @Pt3 MOV _val, val0
    [B------:R-:W-:-:S01] @Pt3 IADD3 bc, bc, -zeros, RZ
    [B------:R-:W-:-:S01] @Pt3 SHF.R.S32.HI _val, RZ, zeros, _val
    [B------:R-:W-:-:S01]    ISETP.GT.AND Pt0, PT, bc, RZ, Pt3
    [B------:R-:W-:-:S03] @Pt3 SHF.L.U32 uu, uu, zeros, RZ
    [B------:R-:W-:-:S04] @Pt3 LOP3.LUT tvars, _val, two, _modp, 0x48, !PT
    [B------:R-:W-:-:S05] @Pt3 SHF.L.U32 uv, uv, zeros, RZ
.label_Start1:
    [B------:R-:W-:-:S02] @Pt0 IMAD mulA, tvars, one, -0x1
    [B------:R-:W-:-:S01] @Pt0 SHF.L.U32 tempA, one, bc, RZ
    [B------:R-:W-:-:S01]    BRA.CONV !Pt0, ~URZ `(.label_Done1)
    [B------:R-:W-:-:S01] @Pt0 IMAD _val, mulA, _modp, _val
    [B------:R-:W-:-:S04] @Pt0 IADD3 mulB, -mulA, RZ, RZ
    [B------:R-:W-:-:S01] @Pt0 LOP3.LUT tempA, tempA, _val, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01] @Pt0 IMAD _modp, mulB, _val, _modp
    [B------:R-:W-:-:S01] @Pt0 IMAD vu, mulA, uu, vu
    [B------:R-:W-:-:S03] @Pt0 IADD3 tempB, -tempA, RZ, RZ
    [B------:R-:W-:-:S01] @Pt0 IMAD vv, mulA, uv, vv
    [B------:R-:W-:-:S03] @Pt0 LOP3.LUT tempA, tempA, tempB, RZ, 0xc0, !PT
    [B------:R-:W-:-:S01] @Pt0 IMAD uu, mulB, vu, uu
    [B------:R-:W-:-:S03] @Pt0 I2FP.F32.S32 tempA, tempA
    [B------:R-:W-:-:S01] @Pt0 IMAD uv, mulB, vv, uv
    [B------:R-:W-:-:S04] @Pt0 LEA.HI zeros, tempA, 0xffffff81, RZ, 9
    [B------:R-:W-:-:S01] @Pt0 IADD3 bc, bc, -zeros, RZ
    [B------:R-:W-:-:S01] @Pt0 SHF.L.U32 uu, uu, zeros, RZ
    [B------:R-:W-:-:S01] @Pt0 SHF.L.U32 uv, uv, zeros, RZ
    [B------:R-:W-:-:S01] @Pt0 SHF.R.S32.HI _val, RZ, zeros, _val
    [B------:R-:W-:-:S01]    ISETP.GT.AND Pt0, PT, bc, RZ, Pt0
    [B------:R-:W-:-:S01] @Pt0 LOP3.LUT tvars, _val, two, _modp, 0x48, !PT
    [B------:R-:W-:Y:S01]    BRA `(.label_Start1)
.label_Done1:

    [B------:R-:W-:Y:S04]    ISETP.LT.AND Pt0, PT, uu, RZ, Pt3
    [B------:R-:W-:Y:S09]    ISETP.LT.AND Pt1, PT, vv, RZ, Pt3
    [B------:R-:W-:-:S01] @Pt0 IADD3 uu, -uu, RZ, RZ
    [B------:R-:W-:-:S01] @Pt0 IADD3 uv, -uv, RZ, RZ
    [B------:R-:W-:-:S01] @Pt1 IADD3 vv, -vv, RZ, RZ
    [B------:R-:W-:-:S01] @Pt1 IADD3 vu, -vu, RZ, RZ

inc_func _mul_256_by_i32(Ro=tmpB, Pt=0, Rval=val, Ri=uv, Rt=tvars)
inc_func _mul_256_by_i32(Ro=tmpC, Pt=0, Rval=modp, Ri=vu, Rt=tvars)
inc_func _mul_256_by_u31_add_shift(Ro=val, Pt=0, Rval=val, Ri=vv, Radd=tmpC, Rt=tmpD)
    [B------:R-:W-:-:S01] @Pt3 LOP3.LUT tempA, val0, val1, val2,  0xFE, !PT
    [B------:R-:W-:-:S01] @Pt3 LOP3.LUT tempB, val3, val4, val5,  0xFE, !PT
    [B------:R-:W-:-:S01] @Pt3 LOP3.LUT zeros, val6, val7, val8,  0xFE, !PT
inc_func _mul_256_by_u31_add_shift(Ro=modp, Pt=0, Rval=modp, Ri=uu, Radd=tmpB, Rt=tmpD)
    [B------:R-:W-:-:S01] @Pt3 LOP3.LUT tempA, tempA, tempB, zeros, 0xFE, !PT
inc_func _mul_256_by_i32(Ro=tmpB, Pt=0, Rval=aa, Ri=uv, Rt=tvars)
    [B------:R-:W-:-:S01]    ISETP.NE.AND Pt1, PT, tempA, RZ, Pt3
inc_func _mul_256_by_u31(Ro=tmpA, Pt=0, Rval=Ro0, Ri=uu, Rt=tvars)

    [B------:R-:W-:-:S01]    BRA.CONV !Pt1, ~URZ `(.label_Done2)
    [B------:R-:W-:-:S01]    ISETP.EQ.AND Pt3, PT, RZ, RZ, Pt1

inc_func _mul_256_by_i32(Ro=tmpC, Pt=0, Rval=Ro0, Ri=vu, Rt=tvars)
    [B------:R-:W-:-:S01] @Pt3 IADD3 tempA, tmpA0, tmpB0, RZ
inc_func _mul_256_by_u31(Ro=tmpD, Pt=0, Rval=aa, Ri=vv, Rt=tvars)
    [B------:R-:W-:-:S01] @Pt3 IADD3 tempB, tmpC0, tmpD0, RZ

inc_func _mul_P_by_32_add3_shift(Ro=Ro0, Pt=0, Rval=tempA, RaddA=tmpA, RaddB=tmpB, Rt=tvars)
inc_func _mul_P_by_32_add3_shift(Ro=aa, Pt=0, Rval=tempB, RaddA=tmpC, RaddB=tmpD, Rt=tvars)
    [B------:R-:W-:Y:S01]    BRA `(.label_Start2)
.label_Done2:

    [B------:R-:W-:Y:S04]    IADD3 tempA, tmpA0, tmpB0, RZ
    [B------:R-:W-:-:S01]    ISETP.LT.AND Pt3, PT, modp8, RZ, PT

inc_func _mul_P_by_32_add3_shift_nopredicate(Ro=Ro0, Pt=0, Rval=tempA, RaddA=tmpA, RaddB=tmpB, Rt=tvars)

    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro0, Pt0, PT, RZ, ~Ro0, RZ, PT, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro1, Pt0, PT, RZ, ~Ro1, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro2, Pt0, PT, RZ, ~Ro2, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro3, Pt0, PT, RZ, ~Ro3, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro4, Pt0, PT, RZ, ~Ro4, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro5, Pt0, PT, RZ, ~Ro5, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro6, Pt0, PT, RZ, ~Ro6, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt3 IADD3.X Ro7, Pt0, PT, RZ, ~Ro7, RZ, Pt0, !PT
    [B------:R-:W-:-:S05] @Pt3 IADD3.X Ro8, PT, PT, RZ, ~Ro8, RZ, Pt0, !PT

.label_Start3:
    [B------:R-:W-:Y:S13]    ISETP.LT.AND Pt1, PT, Ro8, RZ, PT
    [B------:R-:W-:-:S01]    BRA.CONV !Pt1, ~URZ `(.label_Done3)
    [B------:R-:W-:-:S04] @Pt1 IADD3 Ro0, Pt0, Ro0, 0xFFFFFC2F, RZ
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro1, Pt0, PT, Ro1, 0xFFFFFFFE, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro2, Pt0, PT, Ro2, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro3, Pt0, PT, Ro3, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro4, Pt0, PT, Ro4, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro5, Pt0, PT, Ro5, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro6, Pt0, PT, Ro6, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro7, Pt0, PT, Ro7, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro8, Pt0, PT, Ro8, RZ, RZ, Pt0, !PT
    [B------:R-:W-:Y:S01]    BRA `(.label_Start3)
.label_Done3:

.label_Start4:
    [B------:R-:W-:Y:S13]    ISETP.GT.AND Pt1, PT, Ro8, RZ, PT
    [B------:R-:W-:-:S01]    BRA.CONV !Pt1, ~URZ `(.label_Done4)
    [B------:R-:W-:-:S04] @Pt1 IADD3   Ro0, Pt0, Ro0, 0x000003D1, RZ
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro1, Pt0, PT, Ro1, 0x00000001, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro2, Pt0, PT, Ro2, 0x00000000, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro3, Pt0, PT, Ro3, 0x00000000, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro4, Pt0, PT, Ro4, 0x00000000, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro5, Pt0, PT, Ro5, 0x00000000, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro6, Pt0, PT, Ro6, 0x00000000, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro7, Pt0, PT, Ro7, 0x00000000, RZ, Pt0, !PT
    [B------:R-:W-:-:S04] @Pt1 IADD3.X Ro8, PT, PT, Ro8, 0xFFFFFFFF, RZ, Pt0, !PT
    [B------:R-:W-:Y:S01]    BRA `(.label_Start4)
.label_Done4:
}
