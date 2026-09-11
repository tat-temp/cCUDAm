FUNCTION getHash160_w2()
{
    [B------:R-:W-:-:S01]    PRMT R52, R52, 0x7770, RZ
    [B------:R-:W-:Y:S03]    UMOV UR6, 0x455
    [B------:R-:W-:-:S02]    PRMT R52, R61, 0x4321, R52
    [B------:R-:W-:-:S02]    PRMT R61, R60, 0x4321, R61
    [B------:R-:W-:-:S02]    PRMT R60, R59, 0x4321, R60
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R52.reuse, 0x3587272b, RZ
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R52, -0x67381d5e, RZ
    [B------:R-:W-:Y:S02]    PRMT R59, R58, 0x4321, R59
    [B------:R-:W-:-:S02]    PRMT R58, R57, 0x4321, R58
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, -R48, -0x6340bb78, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R53, 0x510e527f, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R58, R53, RZ
    [B------:R-:W-:-:S02]    PRMT R57, R56, 0x4321, R57
    [B------:R-:W-:Y:S02]    LOP3.LUT R62, R48, 0x9b05688c, R51, 0xf8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R53.reuse, 0x5, R53.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R53, 0x13, R53
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R61, R62, RZ
    [B------:R-:W-:-:S02]    PRMT R56, R55, 0x4321, R56
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R53, R48, R51, 0x96, !PT
    [B------:R-:W-:Y:S02]    PRMT R55, R54, 0x4321, R55
    [B------:R-:W-:-:S02]    LEA.HI R51, R48, R63, R48, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R52, -0x3f777b3, RZ
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R51.reuse, -0x32d5ee52, RZ
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, -R51, -0x4d2a11af, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R63.reuse, 0xb, R63.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R80, R63, 0x14, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R48.reuse, 0x5, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R48.reuse, 0x13, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R48.reuse, R53, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R48, R82, R81, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R88, 0x510e527f, R89, 0xf8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R83, R83, R60, R83, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R63.reuse, R62, R80, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R63, 0xd16e48e2, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R88, R83, RZ
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R57, R48, RZ
    [B------:R-:W-:-:S02]    LEA.HI R62, R62, R81, R62, 0x1e
    [B------:R-:W-:Y:S02]    IADD3 R89, PT, PT, -R83, -0xc2e12e1, RZ
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R51, -0x45433bbf, R62
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R83, 0xc2e12e0, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R80.reuse, 0xb, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R80, 0x14, R80
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R51.reuse, 0x5, R51.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R88, R51, 0x13, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R80, R81, R62, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R63, 0x6a09e667, R80, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R51.reuse, R88, R82, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R51, R48, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    LEA.HI R62, R62, R81, R62, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R88, R88, R89, R53, 0xf8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R81, R82, R59, R82, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R83, 0x50c6645b, R62
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R88, R81, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R83.reuse, 0xb, R83.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R83, 0x14, R83
    [B------:R-:W-:Y:S02]    IADD3 R62, PT, PT, R81, -0x5b31eb75, RZ
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, -R81, 0x5b31eb74, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R83, R82, R88, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R80, R63, R83, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R62.reuse, 0x5, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R62.reuse, 0x13, R62
    [B------:R-:W-:Y:S02]    LOP3.LUT R91, R62, R51, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R62, R88, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R91, R90, R48, 0xf8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R97, R88, R97, R88, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R53, R82, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R97, 0x3956c25b, R90
    [B------:R-:W-:Y:S02]    IADD3 R82, PT, PT, R81, 0x3ac42e24, R82
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R56, R51, RZ
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R63, R90, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R82.reuse, 0xb, R82.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R82, 0x14, R82
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R53.reuse, 0x5, R53.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R63, R53, 0x13, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R51, R53, R62, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R53, R63, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R82, R81, R88, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R63, R63, R98, R63, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R83, R80, R82, 0xe8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, 0x59f111f1, R48
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R88, R81, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R55, R62, RZ
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R80, R63, RZ
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R90, R81, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R48.reuse, 0x5, R48.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R80, R48, 0x13, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R81.reuse, 0xb, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R81.reuse, 0x14, R81
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R48, R80, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R81, R88, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R82, R83, R81, 0xe8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R51, R62, R48, R53, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R80, R80, R97, R80, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R89, R88, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, -0x6dc07d5c, R51
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R63, R88, RZ
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R83, R80, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R51, R88, 0xb, R88
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R63.reuse, 0x5, R63.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R63.reuse, 0x13, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R88.reuse, 0x14, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R63, R83, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R88, R51, R89, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R90, R81, R82, R88, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R53, R63, R48, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R89, R83, R98, R83, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R51, R51, R90, R51, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, -0x54e3a12b, R62
    [B------:R-:W-:-:S01]    IADD3 R83, PT, PT, R80, R51, RZ
    [B------:R-:W-:-:S01]    MOV R51, UR6
    [B------:R-:W-:Y:S02]    IADD3 R62, PT, PT, R82, R89, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R83.reuse, 0xb, R83.reuse
    [B------:R-:W-:-:S02]    PRMT R54, R54, R51, 0x80
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R83.reuse, 0x14, R83
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R62.reuse, 0x5, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R62, 0x13, R62
    [B------:R-:W-:Y:S02]    LOP3.LUT R80, R83, R80, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R88, R81, R83, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R54, R53, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R62, R82, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R80, R80, R51, R80, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R48, R62, R63, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R82, R82, R53, R82, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R89, R80, RZ
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, -0x27f85568, R51
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R80.reuse, 0xb, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R80, 0x14, R80.reuse
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R82, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R90, R83, R88, R80, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R80, R51, R53, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R81.reuse, 0x5, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R81, 0x13, R81
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R63, R81, R62, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R81, R53, R96, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R51, R51, R90, R51, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R48, R53, R48, R53, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R82, R51, RZ
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R48, 0x12835b01, R89
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R51.reuse, 0xb, R51.reuse
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R89, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R53, R51, 0x14, R51
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R88.reuse, 0x5, R88.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R88, 0x13, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R51, R48, R53, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R80, R83, R51, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R88, R91, R82, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R48, R48, R53, R48, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R62, R88, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R90, R82, R63, R82, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R89, R48, RZ
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, 0x243185be, R53
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R82, 0xb, R82
    [B------:R-:W-:Y:S02]    IADD3 R83, PT, PT, R83, R90, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R82.reuse, 0x14, R82
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R83.reuse, 0x5, R83.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R83, 0x13, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R82, R53, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R51, R80, R82, 0xe8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R63, R83, R96, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R53, R48, R53, R48, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R81, R83, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R89, R63, R62, R63, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R90, R53, RZ
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, 0x550c7dc3, R48
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R48, R63, 0xb, R63
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R80, R89, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R63.reuse, 0x14, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R62.reuse, 0x5, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R62, 0x13, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R63, R48, R53, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R53, R82, R51, R63, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R62, R91, R80, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R48, R48, R53, R48, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R88, R62, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R80, R80, R81, R80, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R89, R48, RZ
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R91, RZ, 0x3, R61
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, 0x72be5d74, R53
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R90.reuse, 0xb, R90.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R90.reuse, 0x14, R90.reuse
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R51, R80, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R63, R82, R90, 0xe8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R53, R90, R53, R81, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R48.reuse, 0x5, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R48.reuse, 0x13, R48
    [B------:R-:W-:-:S02]    LEA.HI R53, R53, R96, R53, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R48, R51, R81, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R83, R48, R62, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R96, R51, R88, R51, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R80, R53, RZ
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R96, -0x7f214e02, R81
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R88, 0xb, R88.reuse
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R82, R81, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R88, 0x14, R88
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R82, R51, 0x5, R51
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R51.reuse, 0x13, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R88, R53, R80, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R90, R63, R88, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R51, R82, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R80, R53, R80, R53, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R89, R62, R51, R48, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R83, R82, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R81, R80, RZ
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, -0x6423f959, R89
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R61, 0x7, R61
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R53.reuse, 0xb, R53.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R81, R53, 0x14, R53
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R63, R82, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R88, R90, R53, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R53, R96, R81, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R80.reuse, 0x5, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R80, 0x13, R80
    [B------:R-:W-:Y:S02]    LEA.HI R81, R81, R98, R81, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R80, R63, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R81, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R48, R80, R51, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R62, R63, R62, R63, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R82, 0xb, R82
    [B------:R-:W-:Y:S02]    IADD3 R81, PT, PT, R62, -0x3e640d84, R81
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R82, 0x14, R82
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R90, R81, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R61, 0x12, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R82, R83, R62, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R51, R63, R80, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R96, R63, 0x5, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R63, 0x13, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R53, R88, R82, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R90, R89, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R48, R99, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R63, R96, R97, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R90, R62, R83, R62, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R52, R89, RZ
    [B------:R-:W-:-:S02]    LEA.HI R99, R96, R99, R96, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R90, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R60, 0x7, R60
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, -0x1b64963f, R62
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R52, R81, 0xb, R81
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R81, 0x14, R81
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R88, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R60, 0x12, R60.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0x3, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R80, R48, R63, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R48, 0x5, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R48, 0x13, R48
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R51, R98, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R52, R81, R52, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R88, R89, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R48, R91, R96, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R83, R82, R53, R81, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R88, 0xa50000, R61
    [B------:R-:W-:-:S02]    LEA.HI R98, R91, R98, R91, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R52, R52, R83, R52, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R98, -0x1041b87a, R61
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R59, 0x7, R59
    [B------:R-:W-:Y:S02]    IADD3 R52, PT, PT, R99, R52, RZ
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R53, R98, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R59, 0x12, R59.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0x3, R59
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R52.reuse, 0xb, R52.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R52, 0x14, R52
    [B------:R-:W-:Y:S02]    LOP3.LUT R99, R63, R53, R48, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R52, R51, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R62.reuse, 0x11, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R62, 0x13, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R89, RZ, 0xa, R62
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R96, R53, 0x5, R53
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R53.reuse, 0x13, R53
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R80, R99, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R90, R83, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R53, R96, R97, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R91, R83, R60
    [B------:R-:W-:Y:S02]    LEA.HI R99, R96, R99, R96, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R81, R82, R52, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, 0xfc19dc6, R60
    [B------:R-:W-:-:S02]    LEA.HI R51, R51, R88, R51, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R58, 0x7, R58
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R98, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R58, 0x12, R58.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0x3, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R48, R82, R53, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R51.reuse, 0xb, R51.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R83, R51, 0x14, R51
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R61.reuse, 0x11, R61.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R61, 0x13, R61.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0xa, R61
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R82.reuse, 0x5, R82.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R82, 0x13, R82
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, R98, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R51, R80, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R82, R97, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R52, R81, R51, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R91, R88, R59
    [B------:R-:W-:Y:S02]    LEA.HI R96, R96, R63, R96, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R80, R80, R83, R80, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, 0x240ca1cc, R59
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R57, 0x7, R57.reuse
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R99, R80, RZ
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R96, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R89, R57, 0x12, R57
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0x3, R57
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R80.reuse, 0xb, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R80.reuse, 0x14, R80
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R53, R81, R82, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R63, R80, R63, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R60.reuse, 0x11, R60.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R60, 0x13, R60.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R89, RZ, 0xa, R60
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R81.reuse, 0x5, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R81, 0x13, R81
    [B------:R-:W-:Y:S02]    IADD3 R48, PT, PT, R48, R99, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R90, R83, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R81, R98, R97, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R51, R52, R80, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R91, R89, R58
    [B------:R-:W-:-:S02]    LEA.HI R97, R97, R48, R97, 0x1a
    [B------:R-:W-:Y:S02]    LEA.HI R83, R63, R88, R63, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R97, 0x2de92c6f, R58
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R56, 0x7, R56.reuse
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R96, R83, RZ
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R52, R97, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R56, 0x12, R56.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R90, RZ, 0x3, R56
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R83.reuse, 0xb, R83.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R83, 0x14, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R82, R52, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R59.reuse, 0x11, R59.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R89, R59, 0x13, R59
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0xa, R59
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R52.reuse, 0x5, R52.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R52, 0x13, R52
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R83, R48, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R80, R51, R83, 0xe8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R53, PT, PT, R53, R98, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R52, R99, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R48, R48, R63, R48, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R91, R88, R57
    [B------:R-:W-:-:S02]    LEA.HI R96, R96, R53, R96, 0x1a
    [B------:R-:W-:Y:S02]    IADD3 R48, PT, PT, R97, R48, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R55.reuse, 0x7, R55
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, 0x4a7484aa, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R55, 0x12, R55.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R97, RZ, 0x3, R55
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, R96, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R88, R58, 0x11, R58
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R58, 0x13, R58.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0xa, R58
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R48.reuse, 0xb, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R48, 0x14, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R98, R91, R97, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R89, R89, R88, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R81, R51, R52, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R48, R53, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R51.reuse, 0x5, R51.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R51, 0x13, R51
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R91, R56, R89
    [B------:R-:W-:Y:S02]    IADD3 R56, PT, PT, R82, R97, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R51, R90, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R89, 0x108, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R83, R80, R48, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R57, R57, R56, R57, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R53, R53, R88, R53, 0x1e
    [B------:R-:W-:Y:S02]    IADD3 R57, PT, PT, R57, 0x5cb0a9dc, R82
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R54, 0x7, R54.reuse
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R96, R53, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R54, 0x12, R54.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R54
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R80, R57, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R90, R63, 0x11, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R63, 0x13, R63.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R96, RZ, 0xa, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R98, R97, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R91, R90, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R52, R56, R51, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R56, 0x5, R56
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R56, 0x13, R56
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R90, R62, R55
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R53.reuse, 0xb, R53.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R53, 0x14, R53
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R81, R98, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R91, R56, R91, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R53, R88, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R97, R80, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R48, R83, R53, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R98, R91, R98, R91, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R90, R88, R89, R88, 0x1e
    [B------:R-:W-:Y:S02]    IADD3 R98, PT, PT, R98, 0x76f988da, R81
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R82.reuse, 0x11, R82.reuse
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R57, R90, RZ
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R83, R98, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R82, 0x13, R82.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R89, RZ, 0xa, R82
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R57, R90, 0xb, R90
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R90.reuse, 0x14, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R51, R55, R56, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R55.reuse, 0x5, R55.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R55, 0x13, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R90, R57, R80, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R80, R53, R48, R90, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R52, R97, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R83, R88, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R55, R96, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R57, R57, R80, R57, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R83, R61, R54
    [B------:R-:W-:Y:S02]    LEA.HI R91, R91, R52, R91, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R98, R57, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R52, R81.reuse, 0x11, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R81, 0x13, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R54, RZ, 0xa, R81
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, -0x67c1aeae, R80
    [B------:R-:W-:Y:S02]    LOP3.LUT R83, R83, R52, R54, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R54, R57.reuse, 0xb, R57.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R57.reuse, 0x14, R57.reuse
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R48, R91, RZ
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R60, R83, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R54, R57, R54, R88, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R89, R90, R53, R57, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R56, R52, R55, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R52.reuse, 0x5, R52.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R52.reuse, 0x13, R52
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R83, R51, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R52, R97, R48, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R54, R54, R89, R54, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R51, R48, R51, R48, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R80.reuse, 0x11, R80.reuse
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R91, R54, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R80, 0x13, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R91, RZ, 0xa, R80
    [B------:R-:W-:Y:S02]    IADD3 R48, PT, PT, R51, -0x57ce3993, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R54.reuse, 0xb, R54.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R89, R88, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R54.reuse, 0x14, R54
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R53, R48, RZ
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R59, R88, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R51, R54, R51, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R57, R90, R54, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R55, R53, R52, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R53.reuse, 0x5, R53.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R53.reuse, 0x13, R53
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R88, R56, R97
    [B------:R-:W-:Y:S02]    LOP3.LUT R89, R53, R98, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R91, R51, R96, R51, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R56, R89, R56, R89, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R83.reuse, 0x11, R83.reuse
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R48, R91, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R83, 0x13, R83.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R48, RZ, 0xa, R83
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R56, -0x4ffcd838, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R91, 0x14, R91.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R89, R96, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R91, 0xb, R91
    [B------:R-:W-:Y:S02]    IADD3 R89, PT, PT, R58, R89, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R54, R57, R91, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R52, R90, R53, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R90.reuse, 0x5, R90.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R90, 0x13, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R91, R48, R56, 0x96, !PT
    [B------:R-:W-:Y:S02]    IADD3 R55, PT, PT, R89, R55, R98
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R90, R99, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R56, R48, R97, R48, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R55, R96, R55, R96, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R88.reuse, 0x11, R88.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R51, R56, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R51, R88, 0x13, R88
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R97, RZ, 0xa, R88
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R55, -0x40a68039, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R56.reuse, 0x14, R56.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R51, R48, R97, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R57, R96, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R51, R56, 0xb, R56
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R63, R48, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R91, R54, R56, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R56, R51, R55, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R53, R57, R90, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R104, R57.reuse, 0x5, R57.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R97, R57, 0x13, R57
    [B------:R-:W-:-:S02]    LEA.HI R55, R51, R98, R51, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R48, R52, R99
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R57, R104, R97, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R96, R55, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R89, 0x11, R89
    [B------:R-:W-:Y:S02]    LEA.HI R52, R97, R52, R97, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R89, 0x13, R89.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R89
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R52, -0x391ff40d, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R55.reuse, 0xb, R55.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R55, 0x14, R55
    [B------:R-:W-:Y:S02]    LOP3.LUT R105, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R55, R96, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R56, R91, R55, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R54, R97, RZ
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R82, R105, RZ
    [B------:R-:W-:-:S02]    LEA.HI R96, R96, R99, R96, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R98, R90, R54, R57, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R54.reuse, 0x5, R54.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R52, R54.reuse, 0x13, R54
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R51, R53, R98
    [B------:R-:W-:-:S02]    LOP3.LUT R52, R54, R99, R52, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R97, R96, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R97, R48, 0x11, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R48, 0x13, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0xa, R48
    [B------:R-:W-:-:S02]    LEA.HI R53, R52, R53, R52, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R106, R98, R97, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R96, 0xb, R96
    [B------:R-:W-:Y:S02]    IADD3 R98, PT, PT, R53, -0x2a586eb9, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R52, R96.reuse, 0x14, R96.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R104, R55, R56, R96, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R96, R97, R52, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, R98, RZ
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R106, 0x10420023, R81
    [B------:R-:W-:Y:S02]    LEA.HI R97, R97, R104, R97, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R57, R91, R54, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R104, R91.reuse, 0x5, R91.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R91.reuse, 0x13, R91
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R52, R90, R99
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R91, R104, R53, 0x96, !PT
    [B------:R-:W-:Y:S02]    IADD3 R97, PT, PT, R98, R97, RZ
    [B------:R-:W-:-:S02]    LEA.HI R90, R53, R90, R53, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R97.reuse, 0xb, R97.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R97.reuse, 0x14, R97
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R90, 0x6ca6351, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R97, R98, R99, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R99, R96, R55, R97, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R56, R53, RZ
    [B------:R-:W-:-:S02]    LEA.HI R90, R98, R99, R98, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R54, R56, R91, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R53, R90, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R56, 0x5, R56
    [B------:R-:W-:Y:S02]    IADD3 R98, PT, PT, R57, R98, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R56, 0x13, R56
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R90.reuse, 0xb, R90.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R104, R90, 0x14, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R56, R53, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R90, R99, R104, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R104, R53, R98, R53, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R106, R97, R96, R90, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R51.reuse, 0x11, R51.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R51, 0x13, R51.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R57, RZ, 0xa, R51
    [B------:R-:W-:-:S02]    LEA.HI R105, R99, R106, R99, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R53, R98, R53, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R62.reuse, 0x7, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R62, 0x12, R62.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R99, RZ, 0x3, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R98, R57, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R52, 0x13, R52
    [B------:R-:W-:Y:S04]    IADD3 R53, PT, PT, R57, R80, R53
    [B------:R-:W-:Y:S04]    IADD3 R53, PT, PT, R53, 0x108, RZ
    [B------:R-:W-:Y:S04]    IADD3 R104, PT, PT, R104, 0x14292967, R53
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R55, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R104, R105, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R52, 0x11, R52.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R52
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R91, R57, R56, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R55, R98, R55, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R98, RZ, 0x3, R61.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R55, R83, R62
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R61.reuse, 0x7, R61.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R61, 0x12, R61
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R54, R105, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R54, R57, 0x5, R57
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R62, R55, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R57, 0x13, R57
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R53, 0x13, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R57, R54, R62, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R55, R104, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R55, R99, 0x14, R99
    [B------:R-:W-:-:S02]    LEA.HI R105, R62, R105, R62, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R99.reuse, 0xb, R99
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R99, R62, R55, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R90, R97, R99, 0xe8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R105, PT, PT, R105, 0x27b70a85, R54
    [B------:R-:W-:-:S02]    LEA.HI R62, R55, R62, R55, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R53, 0x11, R53
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, R105, RZ
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R105, R62, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R98, R55, R104, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R60, 0x12, R60
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R55, R88, R61
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R60, 0x7, R60.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R61, RZ, 0x3, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R98, R55, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R56, R96, R57, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R61, R96.reuse, 0x5, R96.reuse
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R91, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R96, 0x13, R96
    [B------:R-:W-:-:S02]    LOP3.LUT R104, R99, R90, R62.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R96, R61, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R62.reuse, 0x14, R62.reuse
    [B------:R-:W-:-:S02]    LEA.HI R98, R61, R98, R61, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R61, R62, 0xb, R62
    [B------:R-:W-:Y:S02]    IADD3 R98, PT, PT, R98, 0x2e1b2138, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R62, R61, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R54, 0x11, R54.reuse
    [B------:R-:W-:-:S02]    LEA.HI R61, R61, R104, R61, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R97, R98, RZ
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R54
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R98, R61, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R54, 0x13, R54
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R98, R91, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R98, RZ, 0x3, R59.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R91, R89, R60
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R59.reuse, 0x7, R59.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R59, 0x12, R59
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R104, RZ, 0xa, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R91, R60, R98, 0x96, !PT
    [B------:R-:W-:Y:S04]    LOP3.LUT R91, R57, R97, R96, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R56, R91, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R97.reuse, 0x5, R97.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R91, R97, 0x13, R97
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R97, R56, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R60, R105, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R61, 0xb, R61
    [B------:R-:W-:-:S02]    LEA.HI R91, R91, R98, R91, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R61, 0x14, R61.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R105, R62, R99, R61, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R60, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, 0x4d2c6dfc, R56
    [B------:R-:W-:-:S02]    LEA.HI R98, R60, R105, R60, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R55, 0x11, R55
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, R91, RZ
    [B------:R-:W-:Y:S02]    IADD3 R98, PT, PT, R91, R98, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R91, R55, 0x13, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R91, R60, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R91, RZ, 0x3, R58.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R60, R48, R59
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R58.reuse, 0x7, R58.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R60, R58, 0x12, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R60, R59, R91, 0x96, !PT
    [B------:R-:W-:Y:S04]    LOP3.LUT R60, R96, R90, R97, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R57, R60, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R90.reuse, 0x5, R90.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R60, R90, 0x13, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R90, R57, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R59, R104, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R98, 0xb, R98
    [B------:R-:W-:-:S02]    LEA.HI R60, R60, R91, R60, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R98, 0x14, R98.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R104, R61, R62, R98, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R98, R59, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, 0x53380d13, R57
    [B------:R-:W-:-:S02]    LEA.HI R91, R59, R104, R59, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R56, 0x11, R56
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, R60, RZ
    [B------:R-:W-:Y:S02]    IADD3 R91, PT, PT, R60, R91, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R56, 0x13, R56.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R104, RZ, 0xa, R56
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R60, R59, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R60, RZ, 0x3, R63.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R59, R51, R58
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R63.reuse, 0x7, R63.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R63, 0x12, R63
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R104, RZ, 0xa, R57
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R59, R58, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R97, R99, R90, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R99.reuse, 0x5, R99.reuse
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, R105, RZ
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, R59, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R59, R99, 0x13, R99
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R98, R61, R91, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R99, R60, R59, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R91, 0xb, R91
    [B------:R-:W-:-:S02]    LEA.HI R59, R59, R96, R59, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R91, 0x14, R91
    [B------:R-:W-:Y:S02]    IADD3 R59, PT, PT, R59, 0x650a7354, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R91, R60, R96, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R59, RZ
    [B------:R-:W-:-:S02]    LEA.HI R96, R60, R105, R60, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R57, 0x13, R57.reuse
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R59, R96, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R59, R57, 0x11, R57
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R60, R59, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R82.reuse, 0x12, R82.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R59, R52, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R82, 0x7, R82.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R63, RZ, 0x3, R82
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R60, R59, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R90, R62, R99, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R62.reuse, 0x5, R62.reuse
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R97, R60, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R60, R62, 0x13, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R104, R91, R98, R96, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R62, R63, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R96, 0xb, R96
    [B------:R-:W-:-:S02]    LEA.HI R60, R60, R97, R60, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R97, R96, 0x14, R96
    [B------:R-:W-:Y:S02]    IADD3 R60, PT, PT, R60, 0x766a0abb, R59
    [B------:R-:W-:Y:S04]    LOP3.LUT R63, R96, R63, R97, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R97, R63, R104, R63, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R61, R60, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R61, R58, 0x13, R58.reuse
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R60, R97, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R58, 0x11, R58.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R104, RZ, 0xa, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R60, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R61, R81.reuse, 0x12, R81.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R60, R53, R82
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R81, 0x7, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R82, RZ, 0x3, R81
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R104, RZ, 0xa, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R60, R82, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R99, R63, R62, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R63.reuse, 0x5, R63.reuse
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, R105, RZ
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, R61, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R61, R63, 0x13, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R96, R91, R97, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R63, R82, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R97, 0xb, R97
    [B------:R-:W-:-:S02]    LEA.HI R61, R61, R90, R61, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R97, 0x14, R97
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R61, -0x7e3d36d2, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R97, R82, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R59, 0x13, R59.reuse
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R105, R82, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R98, R61, RZ
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R61, R82, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R61, R59, 0x11, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R90, R61, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R80.reuse, 0x12, R80.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R61, R54, R81
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R61, R80, 0x7, R80.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R81, RZ, 0x3, R80
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R90, R61, R81, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R62, R98, R63, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R98.reuse, 0x5, R98.reuse
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R99, R90, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R90, R98, 0x13, R98
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R60, 0x13, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R98, R81, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R82.reuse, 0x14, R82.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R81, R106, R81, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R81, R82, 0xb, R82
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R104, RZ, 0xa, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R82, R81, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R97, R96, R82, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, -0x6d8dd37b, R61
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R90, R81, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R60, 0x11, R60
    [B------:R-:W-:Y:S02]    IADD3 R91, PT, PT, R91, R106, RZ
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R106, R81, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R99, R90, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R83.reuse, 0x12, R83.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R90, R55, R80
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R83, 0x7, R83.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R90, RZ, 0x3, R83
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R99, R80, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R63, R91, R98, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R91.reuse, 0x13, R91.reuse
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R62, R99, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R62, R91, 0x5, R91
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R91, R62, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R80, R105, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R81.reuse, 0xb, R81.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R90, R99, R90, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R81, 0x14, R81.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R105, R82, R97, R81, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R81, R80, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, -0x5d40175f, R62
    [B------:R-:W-:-:S02]    LEA.HI R90, R80, R105, R80, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R61, 0x11, R61
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R90, PT, PT, R99, R90, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R61, 0x13, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R99, R80, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R104, R98, R96, R91, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R80, R56, R83
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R88.reuse, 0x7, R88.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R88, 0x12, R88.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R99, RZ, 0x3, R88
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R63, R104, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R96.reuse, 0x5, R96.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R83, R80, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R96, 0x13, R96
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R62, 0x13, R62
    [B------:R-:W-:Y:S02]    LOP3.LUT R83, R96, R63, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R80, R105, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R90.reuse, 0x14, R90.reuse
    [B------:R-:W-:-:S02]    LEA.HI R104, R83, R104, R83, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R90, 0xb, R90
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R104, -0x57e599b5, R63
    [B------:R-:W-:Y:S02]    LOP3.LUT R80, R90, R83, R80, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R81, R82, R90, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R97, R104, RZ
    [B------:R-:W-:-:S02]    LEA.HI R83, R80, R83, R80, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R62, 0x11, R62.reuse
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R104, R83, RZ
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R104, RZ, 0xa, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R99, R80, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R89.reuse, 0x12, R89.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R80, R57, R88
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R89, 0x7, R89.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R88, RZ, 0x3, R89
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R104, RZ, 0xa, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R99, R80, R88, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R91, R97, R96, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R97.reuse, 0x5, R97.reuse
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, R105, RZ
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R98, R99, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R97, 0x13, R97
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R90, R81, R83.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R97, R88, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R83.reuse, 0x14, R83.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R88, R99, R88, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R83, 0xb, R83
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R99, -0x3db47490, R80
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R83, R88, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R63, 0x11, R63.reuse
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R105, R88, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R99, RZ
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R99, R88, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R63, 0x13, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R48.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R58, R89
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R48.reuse, 0x7, R48.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R48, 0x12, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R98, R89, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R96, R82, R97, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R80, 0x13, R80
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R91, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R82, 0x5, R82
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R82.reuse, 0x13, R82
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R80
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R82, R91, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R88.reuse, 0x14, R88.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R91, R106, R91, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R88, 0xb, R88
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, -0x3893ae5d, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R88, R91, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R83, R90, R88, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R91, R91, R98, R91, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R80, 0x11, R80
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R106, R91, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R51.reuse, 0x12, R51.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R98, R59, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R51, 0x7, R51.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R98, RZ, 0x3, R51
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R99, R48, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R97, R81, R82, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R81, 0x13, R81
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R105, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R96, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R81.reuse, 0x5, R81
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R88, R83, R91.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R81, R96, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R91.reuse, 0x14, R91.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R96, R99, R96, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R96, R91, 0xb, R91
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, -0x2e6d17e7, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R91, R96, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R89, 0x11, R89
    [B------:R-:W-:-:S02]    LEA.HI R96, R96, R105, R96, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R96, PT, PT, R99, R96, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R89, 0x13, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R52.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R60, R51
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R52.reuse, 0x7, R52.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R52, 0x12, R52
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R98, R51, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R82, R90, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R48, 0x13, R48
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R97, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R97, R90, 0x5, R90
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R90.reuse, 0x13, R90
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R90, R97, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R96.reuse, 0x14, R96.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R97, R106, R97, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R97, R96, 0xb, R96
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, -0x2966f9dc, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R96, R97, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R91, R88, R96, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R83, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R97, R97, R98, R97, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R48, 0x11, R48
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R106, R97, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R53.reuse, 0x12, R53.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R98, R61, R52
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R52, R53, 0x7, R53.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R98, RZ, 0x3, R53
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R52, R99, R52, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R81, R83, R90, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R83, 0x13, R83
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R52, R105, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R82, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R83.reuse, 0x5, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R96, R91, R97.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R83, R82, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R97.reuse, 0x14, R97.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R82, R99, R82, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R82, R97, 0xb, R97
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, -0xbf1ca7b, R52
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R97, R82, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R51, 0x11, R51
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R105, R82, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R82, PT, PT, R99, R82, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R51, 0x13, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R54.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R62, R53
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R54.reuse, 0x7, R54.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R54, 0x12, R54
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R98, R53, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R90, R88, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R52, 0x13, R52
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R53, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R81, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R81, R88, 0x5, R88
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R88.reuse, 0x13, R88
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R52
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R88, R81, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R82.reuse, 0x14, R82.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R81, R106, R81, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R81, R82, 0xb, R82
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, 0x106aa070, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R82, R81, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R97, R96, R82, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R98, R81, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R52, 0x11, R52
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R106, R81, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R55.reuse, 0x12, R55.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R98, R63, R54
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R54, R55, 0x7, R55.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R98, RZ, 0x3, R55
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R54, R99, R54, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R83, R91, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R91, 0x13, R91
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R54, R105, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R90, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R91.reuse, 0x5, R91
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R82, R97, R81.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R91, R90, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R81.reuse, 0x14, R81.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R90, R99, R90, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R90, R81, 0xb, R81
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, 0x19a4c116, R54
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R81, R90, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R53, 0x11, R53
    [B------:R-:W-:-:S02]    LEA.HI R90, R90, R105, R90, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R90, PT, PT, R99, R90, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R53, 0x13, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R56.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R80, R55
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R56.reuse, 0x7, R56.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R56, 0x12, R56
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R98, R55, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R88, R96, R91, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R54, 0x13, R54
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R83, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R83, R96, 0x5, R96
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R96.reuse, 0x13, R96
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R54
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R96, R83, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R90.reuse, 0x14, R90.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R83, R106, R83, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R83, R90, 0xb, R90
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, 0x1e376c08, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R90, R83, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R81, R82, R90, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R97, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R83, R83, R98, R83, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R54, 0x11, R54
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R106, R83, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R57.reuse, 0x12, R57.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R98, R89, R56
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R57, 0x7, R57.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R98, RZ, 0x3, R57
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R99, R56, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R91, R97, R96, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R97, 0x13, R97
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R56, R105, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R88, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R97.reuse, 0x5, R97
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R90, R81, R83.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R97, R88, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R83.reuse, 0x14, R83.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R88, R99, R88, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R88, R83, 0xb, R83
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, 0x2748774c, R56
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R83, R88, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R55, 0x11, R55
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R105, R88, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R88, PT, PT, R99, R88, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R55, 0x13, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R58.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R48, R57
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R58.reuse, 0x7, R58.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R58, 0x12, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R98, R57, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R96, R82, R97, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R56, 0x13, R56
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R57, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R91, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R82, 0x5, R82
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R82.reuse, 0x13, R82
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R56
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R82, R91, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R88.reuse, 0x14, R88.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R91, R106, R91, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R91, R88, 0xb, R88
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, 0x34b0bcb5, R57
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R88, R91, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R83, R90, R88, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R91, R91, R98, R91, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R56, 0x11, R56
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R106, R91, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R59.reuse, 0x12, R59.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R98, R51, R58
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R59, 0x7, R59.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R98, RZ, 0x3, R59
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R57
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R99, R58, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R97, R81, R82, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R81, 0x13, R81
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, R105, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R96, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R96, R81.reuse, 0x5, R81
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R88, R83, R91.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R81, R96, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R91.reuse, 0x14, R91.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R96, R99, R96, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R96, R91, 0xb, R91
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, 0x391c0cb3, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R91, R96, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R57, 0x11, R57
    [B------:R-:W-:-:S02]    LEA.HI R96, R96, R105, R96, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R96, PT, PT, R99, R96, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R57, 0x13, R57
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R60.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R52, R59
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R60.reuse, 0x7, R60.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R60, 0x12, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R98, R59, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R82, R90, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R58, 0x13, R58
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R97, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R97, R90, 0x5, R90
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R90.reuse, 0x13, R90
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R90, R97, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R96.reuse, 0x14, R96.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R97, R106, R97, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R97, R96, 0xb, R96
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, 0x4ed8aa4a, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R97, R96, R97, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R91, R88, R96, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R83, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R97, R97, R98, R97, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R58, 0x11, R58
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R106, R97, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R61.reuse, 0x12, R61.reuse
    [B------:R-:W-:-:S02]    IADD3 R105, PT, PT, R98, R53, R60
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R61, 0x7, R61.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R98, RZ, 0x3, R61
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R99, R60, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R81, R83, R90, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R83, 0x13, R83
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, R105, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R82, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R82, R83.reuse, 0x5, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R105, R96, R91, R97.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R83, R82, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R97.reuse, 0x14, R97.reuse
    [B------:R-:W-:-:S02]    LEA.HI R99, R82, R99, R82, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R82, R97, 0xb, R97
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R99, 0x5b9cca4f, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R97, R82, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R59, 0x11, R59
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R105, R82, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R99, RZ
    [B------:R-:W-:Y:S02]    IADD3 R82, PT, PT, R99, R82, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R99, R59, 0x13, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0x3, R62.reuse
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R98, R54, R61
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R61, R62.reuse, 0x7, R62.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R98, R62, 0x12, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R98, R61, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R90, R88, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R60, 0x13, R60
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R81, R98, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R81, R88, 0x5, R88
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R88.reuse, 0x13, R88
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R88, R81, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R82.reuse, 0x14, R82.reuse
    [B------:R-:W-:-:S02]    LEA.HI R106, R81, R106, R81, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R81, R82, 0xb, R82
    [B------:R-:W-:-:S02]    IADD3 R106, PT, PT, R106, 0x682e6ff3, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R82, R81, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R97, R96, R82, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, R106, RZ
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R98, R81, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R60, 0x11, R60
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R106, R81, RZ
    [B------:R-:W-:Y:S04]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R98, R55, R62
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R55, R63.reuse, 0x7, R63.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R62, R63, 0x12, R63.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R98, RZ, 0x3, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R104, R81, 0xb, R81
    [B------:R-:W-:Y:S02]    LOP3.LUT R62, R62, R55, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R83, R91, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R99, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R81, 0x14, R81
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R90, R55, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R91.reuse, 0x5, R91.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R55, R91, 0x13, R91
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R81, R104, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R91, R90, R55, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R82, R97, R81, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R55, R55, R98, R55, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R90, R99, R90, R99, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R98, R61, 0x11, R61
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R99, R61, 0x13, R61.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R104, RZ, 0xa, R61
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, 0x748f82ee, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R99, R98, R104, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, R55, RZ
    [B------:R-:W-:Y:S02]    IADD3 R99, PT, PT, R98, R56, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R80.reuse, 0x7, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R80, 0x12, R80.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R98, RZ, 0x3, R80
    [B------:R-:W-:-:S02]    LOP3.LUT R104, R88, R96, R91, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R63, R56, R98, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R63, R96, 0x5, R96
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R96, 0x13, R96
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R83, R104, RZ
    [B------:R-:W-:-:S02]    IADD3 R99, PT, PT, R56, R99, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R96, R63, R98, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R62, 0x11, R62
    [B------:R-:W-:Y:S02]    LEA.HI R104, R63, R104, R63, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R62, 0x13, R62.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R83, RZ, 0xa, R62
    [B------:R-:W-:-:S02]    IADD3 R104, PT, PT, R104, 0x78a5636f, R99
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R63, R56, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R89, 0x7, R89
    [B------:R-:W-:Y:S02]    IADD3 R97, PT, PT, R97, R104, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R89, 0x12, R89.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R83, RZ, 0x3, R89
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R56, R57, R80
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R98, R63, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R91, R97, R96, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R80, R97, 0x5, R97
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R97, 0x13, R97
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R83, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R83, R99, 0x13, R99
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R97, R80, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R80, R99, 0x11, R99
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, R56, RZ
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R99, RZ, 0xa, R99
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R55, R90, RZ
    [B------:R-:W-:-:S02]    LEA.HI R88, R57, R88, R57, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R83, R80, R99, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R88, -0x7b3787ec, R63
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R55, R56, 0xb, R56
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R56.reuse, 0x14, R56.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R81, R82, R56, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R56, R55, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R83, RZ
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R99, R58, R89
    [B------:R-:W-:Y:S02]    LEA.HI R55, R55, R80, R55, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R48.reuse, 0x7, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R48, 0x12, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R80, RZ, 0x3, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R98, R96, R82, R97, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R82.reuse, 0x5, R82.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R90, R82, 0x13, R82
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R58, R57, R80, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R98, PT, PT, R91, R98, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R82, R89, R90, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R104, R55, RZ
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R57, R88, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R89, R89, R98, R89, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R63, 0x11, R63
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R55.reuse, 0xb, R55.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R55, 0x14, R55
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R89, -0x7338fdf8, R88
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R63, 0x13, R63
    [B------:R-:W-:Y:S02]    LOP3.LUT R57, R55, R58, R57, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R63, RZ, 0xa, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R56, R81, R55, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R80, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R91, R90, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R58, R57, R58, R57, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R57, R51, 0x7, R51
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R90, R51, 0x12, R51.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R89, RZ, 0x3, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R99, R97, R81, R82, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R98, R81.reuse, 0x5, R81.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R91, R81, 0x13, R81
    [B------:R-:W-:Y:S02]    LOP3.LUT R57, R90, R57, R89, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R63, R59, R48
    [B------:R-:W-:-:S02]    IADD3 R96, PT, PT, R96, R99, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R81, R98, R91, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R83, R58, RZ
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R57, R90, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R91, R91, R96, R91, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R88, 0x11, R88
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R48.reuse, 0xb, R48.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R48.reuse, 0x14, R48
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, -0x6f410006, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R48, R57, R58, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R96, R88, 0x13, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R55, R56, R48, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R88, RZ, 0xa, R88
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R56, R91, RZ
    [B------:R-:W-:-:S02]    LEA.HI R57, R57, R58, R57, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R96, R59, R88, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R58, R52, 0x7, R52
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R52, 0x12, R52.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R83, RZ, 0x3, R52
    [B------:R-:W-:-:S02]    LOP3.LUT R96, R82, R56, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R89, R56.reuse, 0x5, R56.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R88, R56, 0x13, R56
    [B------:R-:W-:Y:S02]    LOP3.LUT R58, R63, R58, R83, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, R60, R51
    [B------:R-:W-:-:S02]    IADD3 R97, PT, PT, R97, R96, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R56, R89, R88, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R80, R57, RZ
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R58, R59, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R88, R88, R97, R88, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R90, 0x11, R90.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R51.reuse, 0xb, R51.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R51.reuse, 0x14, R51
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, -0x5baf9315, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R51, R58, R57, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R63, R90, 0x13, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R48, R55, R51, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R90, RZ, 0xa, R90
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, R88, RZ
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R52, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R63, R60, R90, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R52, R57, R58, R57, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R53.reuse, 0x7, R53.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R53, 0x12, R53.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R61, RZ, 0x3, R53
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R81, R55, R56, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R91, R52, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R61, R58, R57, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R63, R82, R60
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R55.reuse, 0x5, R55.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R55, 0x13, R55
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R57, R52.reuse, 0xb, R52.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R58, R52, 0x14, R52
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R61, R82, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R55, R60, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R52, R57, R58, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R51, R48, R52, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R61, R60, R61, R60, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R60, R54.reuse, 0x7, R54.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R63, R54, 0x12, R54
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R54, RZ, 0x3, R54
    [B------:R-:W-:-:S02]    LEA.HI R57, R57, R58, R57, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, -0x41065c09, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R63, R60, R54, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R88, R57, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R60, R59, 0x11, R59
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R63, R59, 0x13, R59.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R59, RZ, 0xa, R59
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R48, R61, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R57.reuse, 0xb, R57.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R54, R57, 0x14, R57
    [B------:R-:W-:Y:S02]    LOP3.LUT R59, R63, R60, R59, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R81, R53, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R56, R58, R55, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R54, R57, R48, R54, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R52, R51, R57, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R59, R53, R60
    [B------:R-:W-:Y:S02]    IADD3 R62, PT, PT, R58, -0x64fa9774, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R53, R58.reuse, 0x5, R58.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R59, R58, 0x13, R58
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R48, RZ
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, R63, RZ
    [B------:R-:W-:-:S02]    PRMT R48, R62, 0x123, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R53, R58, R53, R59, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R61, R54, R61, R54, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R80, R53, R80, R53, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R48, -0x37e5fca3, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R57, R52, R61.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, -0x398e870e, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R53, R61, 0x14, R61
    [B------:R-:W-:-:S02]    LEA.HI R60, R54, 0xc3d2e1f0, R54, 0x8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R54, R61.reuse, 0xb, R61
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R80, R59, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R60.reuse, 0xffcdaf9d, RZ, 0x3c, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R61, R54, R53, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R82, R60, 0xa, R60
    [B------:R-:W-:-:S02]    LEA.HI R58, R53, R58, R53, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x14756ed6, RZ
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R56, 0x5be0cd19, RZ
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R57, 0x3c6ef372, RZ
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R58, 0x6a09e667, RZ
    [B------:R-:W-:Y:S02]    IADD3 R52, PT, PT, R52, -0x5ab00ac6, RZ
    [B------:R-:W-:-:S02]    LEA.HI R63, R62, 0x10325476, R62, 0x9
    [B------:R-:W-:-:S02]    PRMT R53, R53, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R63, 0xc951d840, R60, 0x1e, !PT
    [B------:R-:W-:-:S02]    PRMT R54, R54, 0x123, RZ
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R53, 0x60d4e05c, R56
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R83, R63, 0xa, R63
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R54, -0x3175b9fe, RZ
    [B------:R-:W-:-:S02]    LEA.HI R62, R56, 0xeb73fa62, R56, 0x9
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R61, -0x4498517b, RZ
    [B------:R-:W-:-:S02]    PRMT R57, R57, 0x123, RZ
    [B------:R-:W-:-:S02]    LEA.HI R58, R58, 0xc3d2e1f0, R58, 0xb
    [B------:R-:W-:Y:S02]    LOP3.LUT R61, R62, R63, R82, 0x2d, !PT
    [B------:R-:W-:-:S02]    PRMT R56, R56, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R58, 0x4be51eb, RZ, 0x3c, !PT
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x3c168648, R54
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R56, -0x3c2d1e10, R59
    [B------:R-:W-:-:S02]    LEA.HI R81, R61, 0x36ae27bf, R61, 0xb
    [B------:R-:W-:Y:S02]    LEA.HI R59, R59, 0x10325476, R59, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R81, R62, R83, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R58, 0x36ae27bf, R59, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R90, R62, 0xa, R62
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R61, -0x78af4c5b, RZ
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R57, 0x10325476, R60
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R61, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R60, R60, 0xeb73fa62, R60, 0xf
    [B------:R-:W-:-:S02]    LEA.HI R88, R63, R82, R63, 0xd
    [B------:R-:W-:-:S02]    PRMT R52, R52, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R60, R59, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R88, R81, R90, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R52, -0x148c059e, R63
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R58, R57, R82
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, 0x510e527f, R80
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R58, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R63, R63, 0x36ae27bf, R63, 0xc
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, 0x50a28be6, RZ
    [B------:R-:W-:Y:S02]    PRMT R51, R51, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R63, R60, R58, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R81, R82, R83, R82, 0xf
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R51, 0x36ae27bf, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R81, R88, R80, 0x2d, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R60, R60, 0xa, R60
    [B------:R-:W-:-:S02]    LEA.HI R62, R62, R61, R62, 0x5
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R83, 0x50a28be6, R82
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R62, R63, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R88, 0xa, R88
    [B------:R-:W-:-:S02]    LEA.HI R82, R83, R90, R83, 0xf
    [B------:R-:W-:Y:S02]    IADD3 R59, PT, PT, R59, R61, R48
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, 0x1f83d9ab, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R82, R81, R88, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R59, R59, R58, R59, 0x8
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R61, R51, R90
    [B------:R-:W-:Y:S02]    PRMT R55, R55, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R59, R62, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R62, 0xa, R62
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R58, R55
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R90, 0x50a28be6, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R81, 0xa, R81
    [B------:R-:W-:Y:S02]    LEA.HI R58, R61, R60, R61, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R83, R83, R80, R83, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R58, R59, R62, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R83, R82, R81, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R61, R60, R53
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R59, 0xa, R59
    [B------:R-:W-:Y:S02]    LEA.HI R59, R60, R63, R60, 0x9
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R80, 0x50a28be6, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R59, R58, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R82, 0xa, R82
    [B------:R-:W-:-:S02]    LEA.HI R80, R89, R88, R89, 0x7
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, 0x80, R60
    [B------:R-:W-:Y:S02]    LOP3.LUT R89, R80, R83, R82, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R58, R63, R62, R63, 0xb
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, R55, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R58, R59, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R89, 0x50a28be6, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R89, R83, 0xa, R83
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R63, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R83, R88, R81, R88, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R61, R62, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R83, R80, R89, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R62, R59, R58, R63, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, 0x50a28be6, R88
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R80, 0xa, R80
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R62, RZ
    [B------:R-:W-:-:S02]    LEA.HI R80, R81, R82, R81, 0x8
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:Y:S02]    LEA.HI R58, R61, R60, R61, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R80, R83, R88, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R58, R59, R62, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, 0x50a28c66, R81
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R83, 0xa, R83
    [B------:R-:W-:-:S02]    LEA.HI R81, R82, R89, R82, 0xb
    [B------:R-:W-:Y:S02]    IADD3 R60, PT, PT, R60, R61, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R81, R80, R83, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R59, R60, R63, R60, 0xf
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R56, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R59, R58, R61, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R90, R81, 0xa, R81
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R82, 0x50a28be6, RZ
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, R60, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R80, 0xa, R80
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R80, R89, R88, R89, 0xe
    [B------:R-:W-:Y:S02]    LEA.HI R58, R63, R62, R63, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R80, R81, R82, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R58, R59, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, 0x50a28be6, R89
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R63, RZ
    [B------:R-:W-:-:S02]    LEA.HI R63, R88, R83, R88, 0xe
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R88, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R61, R62, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R63, R80, R90, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R59, R58, R88, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R52, R83
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x100, R62
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, 0x50a28be6, RZ
    [B------:R-:W-:-:S02]    LEA.HI R58, R61, R60, R61, 0x9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R80, R81, R82, R81, 0xc
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R58, R59, R62, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R83, R80, R63, R61, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R60, R81, RZ
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R82, 0x50a28be6, R83
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R88, R81, 0x8
    [B------:R-:W-:Y:S02]    LEA.HI R83, R83, R90, R83, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R59, R81, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R80, R63, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, R53, R88
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R55, R90
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R91, R58, 0xa, R58
    [B------:R-:W-:Y:S02]    IADD3 R89, PT, PT, R60, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R58, R89, R62, R89, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R61, R82, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R91, R58, R81, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R88, R83, R80, R82, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, R51, R62
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R61, 0x5c4dd124, R88
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R83, 0xa, R83
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R81, 0xa, R81
    [B------:R-:W-:Y:S02]    LEA.HI R83, R88, R63, R88, 0xd
    [B------:R-:W-:-:S02]    LEA.HI R61, R60, R59, R60, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R82, R89, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R81, R61, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R52, R63
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R59, 0x5a827999, R60
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R58, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R60, R60, R91, R60, 0x8
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R62, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R82, 0xa, R82
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R58, R60, R61, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R62, R59, R80, R59, 0xf
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, R56, R91
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R83, R82, R62, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R61, 0xa, R61
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R63, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R59, R53, R80
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R83, 0xa, R83
    [B------:R-:W-:Y:S02]    LEA.HI R59, R88, R81, R88, 0xd
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R91, R60, 0xa, R60.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R61, R59, R60, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R63, R80, R89, R80, 0x7
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, 0x5a827999, R88
    [B------:R-:W-:Y:S02]    LOP3.LUT R80, R62, R83, R63, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R60, R81, R58, R81, 0xb
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, R54, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R91, R60, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R62, 0xa, R62
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R80, 0x5c4dd124, RZ
    [B------:R-:W-:Y:S02]    IADD3 R88, PT, PT, R88, R55, R58
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R58, R81, R82, R81, 0xc
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R63, R62, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R59, R88, R61, R88, 0x9
    [B------:R-:W-:Y:S02]    IADD3 R82, PT, PT, R82, 0x5c4dd124, R81
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R80, R59, R60, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R63, R82, R83, R82, 0x8
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R61, 0x5a827999, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R58, R81, R63, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R61, R60, 0xa, R60
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R91, R88, 0x7
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R48, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R88, R59.reuse, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R82, 0x5c4dd124, RZ
    [B------:R-:W-:Y:S02]    IADD3 R91, PT, PT, R60, R52, R91
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R58, R83, R62, R83, 0x9
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R91, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R63.reuse, 0xa, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R63, R60, R58, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R91, R91, R80, R91, 0xf
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x5c4dd124, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R59, R91, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R63, R62, R81, R62, 0xb
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, 0x5a827999, R83
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R88, 0xa, R88
    [B------:R-:W-:Y:S02]    LEA.HI R80, R80, R61, R80, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R58.reuse, R82, R63, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R83, R80, R91, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, 0x5c4dd224, R62
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R54, R61
    [B------:R-:W-:Y:S02]    LEA.HI R58, R81, R60, R81, 0x7
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R90, R91, 0xa, R91
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R63.reuse, R62, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R60, 0x5c4dd124, R61
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R63, 0xa, R63
    [B------:R-:W-:Y:S02]    LEA.HI R61, R88, R59, R88, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R82, R81, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R90, R61, R80, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R58, R60, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R59, 0x5a827999, R88
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R82, 0x5c4dd1a4, R63
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R80, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R83, R88, 0xf
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R59, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R58, R63, R62, R63, 0xc
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R80, R88, R61, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R81, R59, R58, 0xb8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, R48, R83
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R62, 0x5c4dd124, R89
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R61, 0xa, R61
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R89, R89, R60, R89, 0x7
    [B------:R-:W-:Y:S02]    LEA.HI R63, R63, R90, R63, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R58, R81, R89, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R61, R63, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R51, R60
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R57, R90
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:Y:S02]    IADD3 R82, PT, PT, R82, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R62, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R88, 0xa, R88
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R59, R82, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R58, R83, R80, R83, 0xb
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R89, R60, R82, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R83, R88, R58, R63, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R59, 0x5c4dd124, R62
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, 0x5a827a99, R83
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R59, R80, R61, R80, 0x7
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R89, 0xa, R89
    [B------:R-:W-:Y:S02]    LEA.HI R83, R62, R81, R62, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R63, R59, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R82, R89, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x5a827999, R62
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, R56, R81
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:Y:S02]    LEA.HI R58, R61, R88, R61, 0xd
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R80, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R82, 0xa, R82
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R62, R58, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R80, R61, R60, R61, 0xd
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, 0x5a827a19, R91
    [B------:R-:W-:Y:S02]    LOP3.LUT R82, R83, R81, R80, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R59, R88, R63, R88, 0xc
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R57, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R59, R58, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R83, 0xa, R83
    [B------:R-:W-:Y:S02]    IADD3 R60, PT, PT, R60, R52, R63
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    IADD3 R91, PT, PT, R60, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R63, R82, R89, R82, 0xb
    [B------:R-:W-:-:S02]    LEA.HI R58, R91, R62, R91, 0xb
    [B------:R-:W-:Y:S02]    LOP3.LUT R82, R83, R63, R80, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R60, R58, R59, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R89, 0x6d703ef3, R82
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x6ed9eba1, R91
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R81, R82, 0x9
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R80, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R61, R62, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R89, R82, R63, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R80, R59, R58, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R48, R81
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x6ed9eca1, R62
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R81, R58, 0xa, R58
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    LEA.HI R62, R61, R60, R61, 0x6
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R58, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R61, R88, R83, R88, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R81, R62, R59, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R63, R58, R61, R82, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, R51, R60
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, R56, R83
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R88, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R63, 0x6d703ef3, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R82, R82, 0xa, R82
    [B------:R-:W-:-:S02]    LEA.HI R83, R83, R80, R83, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R60, R60, R89, R60, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R91, R59, R83, R62, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R82, R60, R61, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, 0x6ed9eba1, R91
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, R52, R89
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R62, 0xa, R62
    [B------:R-:W-:-:S02]    LEA.HI R80, R80, R81, R80, 0xe
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R61, 0xa, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R89, R80, R83, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R63, R63, R58, R63, 0xb
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R81, 0x6ed9eba1, R88
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R90, R83, 0xa, R83
    [B------:R-:W-:-:S02]    LEA.HI R81, R88, R59, R88, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R62, R63, R60, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R90, R81, R80, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R61, R53, R58
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R59, 0x6ed9ec21, R88
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R80, 0xa, R80
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R89, R88, 0xd
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R60, 0xa, R60
    [B------:R-:W-:Y:S02]    LEA.HI R58, R61, R82, R61, 0x8
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R80, R88, R81, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R60, R58, R63, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R56, R89
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R81, 0xa, R81
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R82, 0x6d703ff3, R59
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R61, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R59, R59, R62, R59, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R81, R61, R90, R61, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R63, R59, R58, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R83, R81, R88, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R61, R55, R62
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R57, R90
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R88, 0xa, R88
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R82, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:Y:S02]    LEA.HI R58, R61, R60, R61, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R82, R89, R80, R89, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R62, R58, R59, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R88, R82, R81, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, 0x6d703ef3, R61
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, R53, R80
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R61, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R59, R60, R63, R60, 0xe
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R89, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R59, R58, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R81, R80, R83, R80, 0x8
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R63, 0x6d703ef3, R60
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R89, R81, R82, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, R54, R83
    [B------:R-:W-:-:S02]    LEA.HI R58, R63, R62, R63, 0xc
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R82, 0xa, R82
    [B------:R-:W-:Y:S02]    IADD3 R83, PT, PT, R80, 0x6ed9eba1, RZ
    [B------:R-:W-:Y:S04]    LOP3.LUT R63, R60, R58, R59, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x6d703f73, R63
    [B------:R-:W-:-:S02]    LEA.HI R80, R83, R88, R83, 0xd
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R61, R62, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R82, R80, R81, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R62, R63, R59, R58, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R83, R55, R88
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x6d703ef3, R62
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R81, 0xa, R81
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R83, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R58, 0xa, R58
    [B------:R-:W-:Y:S02]    LEA.HI R58, R61, R60, R61, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R61, R62, R89, R62, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R83, R58, R59, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R81, R61, R80, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R57, R60
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, 0x6ed9eba1, R88
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R88, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R80, R89, R82, R89, 0x5
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R88, R80, R61, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R63, R62, 0xe
    [B------:R-:W-:Y:S02]    IADD3 R82, PT, PT, R82, 0x6ed9eba1, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R60, R59, R58, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R61, 0xa, R61
    [B------:R-:W-:-:S02]    LEA.HI R61, R82, R81, R82, 0xc
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R63, 0x6d703ef3, R62
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R89, R61, R80, 0x2d, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R58, R58, 0xa, R58
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R63, R48, R81
    [B------:R-:W-:-:S02]    LEA.HI R62, R62, R83, R62, 0xd
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R80, 0xa, R80
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R58, R62, R59.reuse, 0x2d, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R80, R81, R88, R81, 0x7
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, R54, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R82, R80, R61.reuse, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R61, 0xa, R61
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, 0x6d703ef3, RZ
    [B------:R-:W-:Y:S02]    IADD3 R88, PT, PT, R88, 0x6ed9eba1, R81
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R90, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R81, R88, R89, R88, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R63, R63, R60, R63, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R88, R80, R83, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R59, R63, R62, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R88, PT, PT, R88, R56, R89
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R51, R60
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R62, 0xa, R62
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R88, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R63, 0xa, R63
    [B------:R-:W-:Y:S02]    LEA.HI R88, R89, R82, R89, 0xb
    [B------:R-:W-:-:S02]    LEA.HI R60, R61, R58, R61, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R89, R81.reuse, R90, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R62, R60, R63, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, -0x70e44324, R89
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x6d703ef3, R61
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R89, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R81, R82, R83, R82, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R61, R58, R59, R58, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R82, R88, R89, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R80, R61, R60, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R83, -0x70e44324, R82
    [B------:R-:W-:Y:S02]    IADD3 R59, PT, PT, R59, 0x7a6d7769, R58
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R60, 0xa, R60
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R88, 0xa, R88
    [B------:R-:W-:-:S02]    LEA.HI R60, R83, R90, R83, 0xe
    [B------:R-:W-:-:S02]    LEA.HI R58, R59, R62, R59, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R81, R88, R60, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R59, R63, R58, R61, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, -0x70e44324, R83
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, R55, R62
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R81, R90, R89, R90, 0xf
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, 0x7a6d76e9, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R61, R61, 0xa, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R60, R82, R81, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R59, R59, R80, R59, 0x5
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R62, R54, R89
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R61, R59, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R90, R60, 0xa, R60
    [B------:R-:W-:Y:S02]    IADD3 R89, PT, PT, R89, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R51, R80
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R58, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R80, R89, R88, R89, 0xe
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R83, R81, R90, R80.reuse, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R89, R80, 0xa, R80
    [B------:R-:W-:-:S02]    LEA.HI R62, R62, R63, R62, 0x8
    [B------:R-:W-:-:S02]    IADD3 R83, PT, PT, R88, -0x70e442a4, R83
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R58, R62, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R83, R83, R82, R83, 0xf
    [B------:R-:W-:Y:S02]    IADD3 R60, PT, PT, R60, R56, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R80, R88, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R82, -0x70e44324, R63
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R83, 0xa, R83
    [B------:R-:W-:-:S02]    LEA.HI R80, R63, R90, R63, 0x9
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R63, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LEA.HI R59, R60, R61, R60, 0xb
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R83, R89, R80, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R63, R59, R62, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R51, R90
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R60, R52, R61
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R90, R80, 0xa, R80
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R60, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    LEA.HI R83, R81, R88, R81, 0x8
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R62, 0xa, R62
    [B------:R-:W-:-:S02]    LEA.HI R60, R61, R58, R61, 0xe
    [B------:R-:W-:Y:S02]    LOP3.LUT R91, R80, R82, R83, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R81, R60, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R88, PT, PT, R88, -0x70e44324, R91
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x7a6d76e9, R61
    [B------:R-:W-:-:S02]    LEA.HI R88, R88, R89, R88, 0x9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R59, 0xa, R59
    [B------:R-:W-:Y:S02]    LEA.HI R59, R58, R63, R58, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R83, R90, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R61, R59, R60, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R52, R89
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R63, 0x7a6d76e9, R58
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R83, 0xa, R83
    [B------:R-:W-:Y:S02]    IADD3 R63, PT, PT, R62, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R60, 0xa, R60
    [B------:R-:W-:-:S02]    LEA.HI R58, R58, R81, R58, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R63, R63, R82, R63, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R60, R58, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R88, R83, R63, 0xb8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R62, PT, PT, R62, R54, R81
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, R53, R82
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R88, 0xa, R88
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R80, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R59, 0xa, R59
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R88, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R82, R81, R90, R81, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R61, R62, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R63, R89, R82, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R80, R59, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R90, PT, PT, R90, -0x70e44324, R81
    [B------:R-:W-:Y:S02]    IADD3 R62, PT, PT, R62, R48, R61
    [B------:R-:W-:-:S02]    LEA.HI R63, R90, R83, R90, 0x6
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R62, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R90, R82, R88, R63, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R58, R61, R60, R61, 0x6
    [B------:R-:W-:Y:S02]    IADD3 R90, PT, PT, R83, -0x70e44224, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R62, R58, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R82, 0xa, R82
    [B------:R-:W-:-:S02]    LEA.HI R90, R90, R89, R90, 0x8
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R60, 0x7a6d76e9, R61
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R63, R82, R90, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R60, R48, R89
    [B------:R-:W-:-:S02]    LEA.HI R61, R61, R80, R61, 0x9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R90, 0xa, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R59, R61, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R89, PT, PT, R89, -0x70e44324, RZ
    [B------:R-:W-:Y:S02]    IADD3 R60, PT, PT, R60, R57, R80
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R89, R89, R88, R89, 0x6
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R60, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R90, R80, R89, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R58, R63, R62, R63, 0xc
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R55, R88
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R60, R58, R61, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x7a6d76e9, R63
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R61, 0xa, R61
    [B------:R-:W-:Y:S02]    LEA.HI R88, R81, R82, R81, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R61, R62, R59, R62, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R89, R83, R88, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R63, R61, R58, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R57, R82
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, 0x7a6d76e9, R62
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R62, R58, 0xa, R58
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R89, R89, 0xa, R89
    [B------:R-:W-:-:S02]    LEA.HI R58, R59, R60, R59, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R81, R81, R80, R81, 0xc
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R62, R58, R61, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R82, R81, R88, R89, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R59, R53, R60
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, R51, R80
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R88, 0xa, R88
    [B------:R-:W-:-:S02]    IADD3 R60, PT, PT, R59, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    IADD3 R82, PT, PT, R82, -0x56ac02b2, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R61, R61, 0xa, R61
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R90, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R82, R82, R83, R82, 0x9
    [B------:R-:W-:-:S02]    LEA.HI R59, R60, R63, R60, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R82, R81, R88, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R60, R61, R59, R58, 0xb8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R80, PT, PT, R80, R54, R83
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, 0x7a6d76e9, R60
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R58, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R54, R63, R62, R63, 0xf
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R59, 0xa, R59.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R63, R58, R54, R59, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R81, R80, R89, R80, 0xf
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, 0x7a6d77e9, R63
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R81, R82, R90, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R59, R62, R61, R62, 0x8
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, R48, R89
    [B------:R-:W-:Y:S02]    LOP3.LUT R62, R59, R54, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R82, R82, 0xa, R82
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R63, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, R62, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R54, 0xa, R54
    [B------:R-:W-:-:S02]    LEA.HI R80, R63, R88, R63, 0x5
    [B------:R-:W-:Y:S02]    LEA.HI R54, R61, R58, R61, 0x8
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R80, R81, R82, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R54, R59, R62, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R88, -0x56ac02b2, R63
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R88, R81, 0xa, R81
    [B------:R-:W-:-:S02]    LEA.HI R83, R63, R90, R63, 0xb
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R58, R61, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R83, R80, R88, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R61, R61, R60, R61, 0x5
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, R53, R90
    [B------:R-:W-:-:S02]    LOP3.LUT R63, R61, R54, R59, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R80, R80, 0xa, R80
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R58, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R60, R63, RZ
    [B------:R-:W-:-:S02]    LEA.HI R60, R81, R82, R81, 0x6
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R81, R54, 0xa, R54
    [B------:R-:W-:-:S02]    LEA.HI R54, R63, R62, R63, 0xc
    [B------:R-:W-:Y:S02]    LOP3.LUT R63, R60, R83, R80, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R54, R61, R81, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R63, PT, PT, R82, -0x56ac02b2, R63
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, R62, R51
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R83, R83, 0xa, R83
    [B------:R-:W-:-:S02]    LEA.HI R63, R63, R88, R63, 0x8
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R61, R61, 0xa, R61
    [B------:R-:W-:-:S02]    LEA.HI R51, R58, R59, R58, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R62, R63, R60, R83, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R51, R54, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R62, PT, PT, R62, R57, R88
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, R59, R56
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R89, R60, 0xa, R60
    [B------:R-:W-:-:S02]    IADD3 R59, PT, PT, R62, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R54, R54, 0xa, R54
    [B------:R-:W-:-:S02]    LEA.HI R58, R58, R81, R58, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R62, R59, R80, R59, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R59, R58, R51, R54, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R91, R62, R63, R89, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R59, R81, R48
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R80, -0x56ac02b2, R91
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R60, R51, 0xa, R51
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R63, R63, 0xa, R63
    [B------:R-:W-:-:S02]    LEA.HI R59, R80, R83, R80, 0xc
    [B------:R-:W-:Y:S02]    LEA.HI R51, R48, R61, R48, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R80, R59, R62, R63, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R51, R58, R60, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R80, PT, PT, R83, -0x56ac01b2, R80
    [B------:R-:W-:-:S02]    IADD3 R61, PT, PT, R61, 0x80, R48
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R62, R62, 0xa, R62
    [B------:R-:W-:Y:S02]    LEA.HI R80, R80, R89, R80, 0x5
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R58, R58, 0xa, R58
    [B------:R-:W-:-:S02]    LEA.HI R48, R61, R54, R61, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R81, R80, R59, R62, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R61, R48, R51, R58, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R81, PT, PT, R81, R56, R89
    [B------:R-:W-:Y:S02]    IADD3 R61, PT, PT, R61, R54, R53
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R51, R51, 0xa, R51
    [B------:R-:W-:-:S02]    LEA.HI R61, R61, R60, R61, 0x6
    [B------:R-:W-:-:S02]    IADD3 R54, PT, PT, R81, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R56, R59, 0xa, R59
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R61, R48, R51, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R59, R54, R63, R54, 0xc
    [B------:R-:W-:-:S02]    IADD3 R53, PT, PT, R53, R60, R55
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R59, R80, R56, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R54, R48, 0xa, R48
    [B------:R-:W-:-:S02]    LEA.HI R48, R53, R58, R53, 0x8
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, R52, R63
    [B------:R-:W-:Y:S02]    LOP3.LUT R52, R48, R61, R54, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R80, R80, 0xa, R80
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R55, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    IADD3 R52, PT, PT, R52, R58, R57
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R61, R61, 0xa, R61
    [B------:R-:W-:-:S02]    LEA.HI R58, R55, R62, R55, 0xd
    [B------:R-:W-:Y:S02]    LEA.HI R53, R52, R51, R52, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R58, R59, R80, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R52, R53, R48, R61, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R62, -0x56ac0232, R55
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R59, R59, 0xa, R59
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, R52, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R55, R55, R56, R55, 0xe
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R52, R48, 0xa, R48
    [B------:R-:W-:-:S02]    LEA.HI R48, R51, R54, R51, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R55, R55, R58, R59, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R53, R53, R52, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R55, PT, PT, R56, -0x56ac02b2, R55
    [B------:R-:W-:Y:S02]    IADD3 R54, PT, PT, R54, 0x100, R53
    [B------:R-:W-:-:S02]    LEA.HI R55, R55, R80, R55, 0xb
    [B------:R-:W-:-:S02]    LEA.HI R52, R54, R61, R54, 0x5
    [B------:R-:W-:Y:S04]    SHF.L.W.U32.HI R55, R55, 0xa, R55
    [B------:R-:W-:Y:S04]    LEA.HI R52, R52, R55, R52, 0xa
    [B------:R-:W-:-:S01]    IADD3 R52, PT, PT, R52, 0x10325476, RZ
}
