FUNCTION getHash160_w2()
{
    [B------:R-:W-:-:S01]    PRMT R4, R4, 0x7770, RZ
    [B------:R-:W-:Y:S03]    UMOV UR4, 0x455
    [B------:R-:W-:-:S02]    PRMT R4, R13, 0x4321, R4
    [B------:R-:W-:-:S02]    PRMT R13, R12, 0x4321, R13
    [B------:R-:W-:-:S02]    PRMT R12, R11, 0x4321, R12
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R4.reuse, 0x3587272b, RZ
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R4, -0x67381d5e, RZ
    [B------:R-:W-:Y:S02]    PRMT R11, R10, 0x4321, R11
    [B------:R-:W-:-:S02]    PRMT R10, R9, 0x4321, R10
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, -R0, -0x6340bb78, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R5, 0x510e527f, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R10, R5, RZ
    [B------:R-:W-:-:S02]    PRMT R9, R8, 0x4321, R9
    [B------:R-:W-:Y:S02]    LOP3.LUT R14, R0, 0x9b05688c, R3, 0xf8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R5.reuse, 0x5, R5.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R5, 0x13, R5
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R13, R14, RZ
    [B------:R-:W-:-:S02]    PRMT R8, R7, 0x4321, R8
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R5, R0, R3, 0x96, !PT
    [B------:R-:W-:Y:S02]    PRMT R7, R6, 0x4321, R7
    [B------:R-:W-:-:S02]    LEA.HI R3, R0, R15, R0, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R4, -0x3f777b3, RZ
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R3.reuse, -0x32d5ee52, RZ
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, -R3, -0x4d2a11af, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R15.reuse, 0xb, R15.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R32, R15, 0x14, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R0.reuse, 0x5, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R0.reuse, 0x13, R0
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R0.reuse, R5, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R0, R34, R33, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R40, 0x510e527f, R41, 0xf8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R35, R35, R12, R35, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R15.reuse, R14, R32, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R15, 0xd16e48e2, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R40, R35, RZ
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R9, R0, RZ
    [B------:R-:W-:-:S02]    LEA.HI R14, R14, R33, R14, 0x1e
    [B------:R-:W-:Y:S02]    IADD3 R41, PT, PT, -R35, -0xc2e12e1, RZ
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R3, -0x45433bbf, R14
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R35, 0xc2e12e0, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R32.reuse, 0xb, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R32, 0x14, R32
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R3.reuse, 0x5, R3.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R40, R3, 0x13, R3
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R32, R33, R14, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R15, 0x6a09e667, R32, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R3.reuse, R40, R34, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R3, R0, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    LEA.HI R14, R14, R33, R14, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R40, R40, R41, R5, 0xf8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R33, R34, R11, R34, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R35, 0x50c6645b, R14
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R40, R33, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R35.reuse, 0xb, R35.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R35, 0x14, R35
    [B------:R-:W-:Y:S02]    IADD3 R14, PT, PT, R33, -0x5b31eb75, RZ
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, -R33, 0x5b31eb74, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R35, R34, R40, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R32, R15, R35, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R14.reuse, 0x5, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R14.reuse, 0x13, R14
    [B------:R-:W-:Y:S02]    LOP3.LUT R43, R14, R3, RZ, 0xc0, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R14, R40, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R43, R42, R0, 0xf8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R49, R40, R49, R40, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R5, R34, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R49, 0x3956c25b, R42
    [B------:R-:W-:Y:S02]    IADD3 R34, PT, PT, R33, 0x3ac42e24, R34
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R8, R3, RZ
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R15, R42, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R34.reuse, 0xb, R34.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R34, 0x14, R34
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R5.reuse, 0x5, R5.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R15, R5, 0x13, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R3, R5, R14, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R5, R15, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R34, R33, R40, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R15, R15, R50, R15, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R35, R32, R34, 0xe8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, 0x59f111f1, R0
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R40, R33, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R7, R14, RZ
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R32, R15, RZ
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R42, R33, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R0.reuse, 0x5, R0.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R32, R0, 0x13, R0
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R33.reuse, 0xb, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R33.reuse, 0x14, R33
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R0, R32, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R33, R40, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R34, R35, R33, 0xe8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R3, R14, R0, R5, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R32, R32, R49, R32, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R41, R40, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, -0x6dc07d5c, R3
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R15, R40, RZ
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R35, R32, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R3, R40, 0xb, R40
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R15.reuse, 0x5, R15.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R15.reuse, 0x13, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R40.reuse, 0x14, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R15, R35, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R40, R3, R41, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R42, R33, R34, R40, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R5, R15, R0, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R41, R35, R50, R35, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R3, R3, R42, R3, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, -0x54e3a12b, R14
    [B------:R-:W-:-:S01]    IADD3 R35, PT, PT, R32, R3, RZ
    [B------:R-:W-:-:S01]    MOV R3, UR4
    [B------:R-:W-:Y:S02]    IADD3 R14, PT, PT, R34, R41, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R35.reuse, 0xb, R35.reuse
    [B------:R-:W-:-:S02]    PRMT R6, R6, R3, 0x80
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R35.reuse, 0x14, R35
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R14.reuse, 0x5, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R14, 0x13, R14
    [B------:R-:W-:Y:S02]    LOP3.LUT R32, R35, R32, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R40, R33, R35, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R6, R5, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R14, R34, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R32, R32, R3, R32, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R0, R14, R15, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R34, R34, R5, R34, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R41, R32, RZ
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, -0x27f85568, R3
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R32.reuse, 0xb, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R32, 0x14, R32.reuse
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R34, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R42, R35, R40, R32, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R32, R3, R5, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R33.reuse, 0x5, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R33, 0x13, R33
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R15, R33, R14, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R33, R5, R48, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R3, R3, R42, R3, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R0, R5, R0, R5, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R34, R3, RZ
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R0, 0x12835b01, R41
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R3.reuse, 0xb, R3.reuse
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R41, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R5, R3, 0x14, R3
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R40.reuse, 0x5, R40.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R40, 0x13, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R3, R0, R5, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R32, R35, R3, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R40, R43, R34, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R0, R0, R5, R0, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R14, R40, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R42, R34, R15, R34, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R41, R0, RZ
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, 0x243185be, R5
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R34, 0xb, R34
    [B------:R-:W-:Y:S02]    IADD3 R35, PT, PT, R35, R42, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R34.reuse, 0x14, R34
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R35.reuse, 0x5, R35.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R35, 0x13, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R34, R5, R0, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R3, R32, R34, 0xe8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R15, R35, R48, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R5, R0, R5, R0, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R33, R35, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R41, R15, R14, R15, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R42, R5, RZ
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, 0x550c7dc3, R0
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R0, R15, 0xb, R15
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R32, R41, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R15.reuse, 0x14, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R14.reuse, 0x5, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R14, 0x13, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R15, R0, R5, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R5, R34, R3, R15, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R14, R43, R32, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R0, R0, R5, R0, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R40, R14, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R32, R32, R33, R32, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R41, R0, RZ
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R43, RZ, 0x3, R13
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, 0x72be5d74, R5
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R42.reuse, 0xb, R42.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R42.reuse, 0x14, R42.reuse
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R3, R32, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R15, R34, R42, 0xe8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R5, R42, R5, R33, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R0.reuse, 0x5, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R0.reuse, 0x13, R0
    [B------:R-:W-:-:S02]    LEA.HI R5, R5, R48, R5, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R0, R3, R33, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R35, R0, R14, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R48, R3, R40, R3, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R32, R5, RZ
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R48, -0x7f214e02, R33
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R40, 0xb, R40.reuse
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R34, R33, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R40, 0x14, R40
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R34, R3, 0x5, R3
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R3.reuse, 0x13, R3
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R40, R5, R32, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R42, R15, R40, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R3, R34, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R32, R5, R32, R5, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R41, R14, R3, R0, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R35, R34, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R33, R32, RZ
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, -0x6423f959, R41
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R13, 0x7, R13
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R5.reuse, 0xb, R5.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R33, R5, 0x14, R5
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R15, R34, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R40, R42, R5, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R5, R48, R33, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R32.reuse, 0x5, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R32, 0x13, R32
    [B------:R-:W-:Y:S02]    LEA.HI R33, R33, R50, R33, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R32, R15, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R33, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R0, R32, R3, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R14, R15, R14, R15, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R34, 0xb, R34
    [B------:R-:W-:Y:S02]    IADD3 R33, PT, PT, R14, -0x3e640d84, R33
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R34, 0x14, R34
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R42, R33, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R13, 0x12, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R34, R35, R14, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R3, R15, R32, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R48, R15, 0x5, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R15, 0x13, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R5, R40, R34, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R42, R41, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R0, R51, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R15, R48, R49, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R42, R14, R35, R14, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R4, R41, RZ
    [B------:R-:W-:-:S02]    LEA.HI R51, R48, R51, R48, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R42, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R12, 0x7, R12
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, -0x1b64963f, R14
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R4, R33, 0xb, R33
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R33, 0x14, R33
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R40, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R12, 0x12, R12.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0x3, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R32, R0, R15, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R0, 0x5, R0
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R0, 0x13, R0
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R3, R50, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R4, R33, R4, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R40, R41, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R0, R43, R48, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R35, R34, R5, R33, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R40, 0xa50000, R13
    [B------:R-:W-:-:S02]    LEA.HI R50, R43, R50, R43, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R4, R4, R35, R4, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R50, -0x1041b87a, R13
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R11, 0x7, R11
    [B------:R-:W-:Y:S02]    IADD3 R4, PT, PT, R51, R4, RZ
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R5, R50, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R11, 0x12, R11.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0x3, R11
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R4.reuse, 0xb, R4.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R4, 0x14, R4
    [B------:R-:W-:Y:S02]    LOP3.LUT R51, R15, R5, R0, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R4, R3, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R14.reuse, 0x11, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R14, 0x13, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R41, RZ, 0xa, R14
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R48, R5, 0x5, R5
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R5.reuse, 0x13, R5
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R32, R51, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R42, R35, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R5, R48, R49, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R43, R35, R12
    [B------:R-:W-:Y:S02]    LEA.HI R51, R48, R51, R48, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R33, R34, R4, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, 0xfc19dc6, R12
    [B------:R-:W-:-:S02]    LEA.HI R3, R3, R40, R3, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R10, 0x7, R10
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R3, PT, PT, R50, R3, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R10, 0x12, R10.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0x3, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R0, R34, R5, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R3.reuse, 0xb, R3.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R35, R3, 0x14, R3
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R13.reuse, 0x11, R13.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R13, 0x13, R13.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0xa, R13
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R34.reuse, 0x5, R34.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R34, 0x13, R34
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, R50, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R3, R32, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R34, R49, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R4, R33, R3, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R43, R40, R11
    [B------:R-:W-:Y:S02]    LEA.HI R48, R48, R15, R48, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R32, R32, R35, R32, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, 0x240ca1cc, R11
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R9, 0x7, R9.reuse
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R51, R32, RZ
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R48, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R41, R9, 0x12, R9
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0x3, R9
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R32.reuse, 0xb, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R32.reuse, 0x14, R32
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R5, R33, R34, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R15, R32, R15, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R12.reuse, 0x11, R12.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R12, 0x13, R12.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R41, RZ, 0xa, R12
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R33.reuse, 0x5, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R33, 0x13, R33
    [B------:R-:W-:Y:S02]    IADD3 R0, PT, PT, R0, R51, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R42, R35, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R33, R50, R49, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R3, R4, R32, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R43, R41, R10
    [B------:R-:W-:-:S02]    LEA.HI R49, R49, R0, R49, 0x1a
    [B------:R-:W-:Y:S02]    LEA.HI R35, R15, R40, R15, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R49, 0x2de92c6f, R10
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R8, 0x7, R8.reuse
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R48, R35, RZ
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R4, R49, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R8, 0x12, R8.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R42, RZ, 0x3, R8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R35.reuse, 0xb, R35.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R35, 0x14, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R34, R4, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R11.reuse, 0x11, R11.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R41, R11, 0x13, R11
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0xa, R11
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R4.reuse, 0x5, R4.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R4, 0x13, R4
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R35, R0, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R32, R3, R35, 0xe8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R5, PT, PT, R5, R50, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R4, R51, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R0, R0, R15, R0, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R43, R40, R9
    [B------:R-:W-:-:S02]    LEA.HI R48, R48, R5, R48, 0x1a
    [B------:R-:W-:Y:S02]    IADD3 R0, PT, PT, R49, R0, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R7.reuse, 0x7, R7
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, 0x4a7484aa, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R7, 0x12, R7.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R49, RZ, 0x3, R7
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R3, R48, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R40, R10, 0x11, R10
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R10, 0x13, R10.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0xa, R10
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R0.reuse, 0xb, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R0, 0x14, R0
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R50, R43, R49, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R41, R41, R40, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R33, R3, R4, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R0, R5, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R3.reuse, 0x5, R3.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R3, 0x13, R3
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R43, R8, R41
    [B------:R-:W-:Y:S02]    IADD3 R8, PT, PT, R34, R49, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R3, R42, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R41, 0x108, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R35, R32, R0, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R9, R9, R8, R9, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R5, R5, R40, R5, 0x1e
    [B------:R-:W-:Y:S02]    IADD3 R9, PT, PT, R9, 0x5cb0a9dc, R34
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R6, 0x7, R6.reuse
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R48, R5, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R6, 0x12, R6.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R6
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R32, R9, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R42, R15, 0x11, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R15, 0x13, R15.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R48, RZ, 0xa, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R50, R49, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R43, R42, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R4, R8, R3, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R8, 0x5, R8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R8, 0x13, R8
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R42, R14, R7
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R5.reuse, 0xb, R5.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R5, 0x14, R5
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R33, R50, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R43, R8, R43, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R5, R40, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R49, R32, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R0, R35, R5, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R50, R43, R50, R43, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R42, R40, R41, R40, 0x1e
    [B------:R-:W-:Y:S02]    IADD3 R50, PT, PT, R50, 0x76f988da, R33
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R34.reuse, 0x11, R34.reuse
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R9, R42, RZ
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R35, R50, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R34, 0x13, R34.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R41, RZ, 0xa, R34
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R9, R42, 0xb, R42
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R42.reuse, 0x14, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R3, R7, R8, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R7.reuse, 0x5, R7.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R7, 0x13, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R42, R9, R32, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R32, R5, R0, R42, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R4, R49, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R35, R40, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R7, R48, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R9, R9, R32, R9, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R35, R13, R6
    [B------:R-:W-:Y:S02]    LEA.HI R43, R43, R4, R43, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R50, R9, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R4, R33.reuse, 0x11, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R33, 0x13, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R6, RZ, 0xa, R33
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, -0x67c1aeae, R32
    [B------:R-:W-:Y:S02]    LOP3.LUT R35, R35, R4, R6, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R6, R9.reuse, 0xb, R9.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R9.reuse, 0x14, R9.reuse
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R0, R43, RZ
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R12, R35, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R6, R9, R6, R40, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R41, R42, R5, R9, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R8, R4, R7, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R4.reuse, 0x5, R4.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R4.reuse, 0x13, R4
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R35, R3, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R4, R49, R0, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R6, R6, R41, R6, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R3, R0, R3, R0, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R32.reuse, 0x11, R32.reuse
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R43, R6, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R32, 0x13, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R43, RZ, 0xa, R32
    [B------:R-:W-:Y:S02]    IADD3 R0, PT, PT, R3, -0x57ce3993, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R6.reuse, 0xb, R6.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R41, R40, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R6.reuse, 0x14, R6
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R5, R0, RZ
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R11, R40, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R3, R6, R3, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R9, R42, R6, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R7, R5, R4, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R5.reuse, 0x5, R5.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R5.reuse, 0x13, R5
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R40, R8, R49
    [B------:R-:W-:Y:S02]    LOP3.LUT R41, R5, R50, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R43, R3, R48, R3, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R8, R41, R8, R41, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R35.reuse, 0x11, R35.reuse
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R0, R43, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R35, 0x13, R35.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R0, RZ, 0xa, R35
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R8, -0x4ffcd838, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R8, R43, 0x14, R43.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R41, R48, R0, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, R3, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R43, 0xb, R43
    [B------:R-:W-:Y:S02]    IADD3 R41, PT, PT, R10, R41, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R6, R9, R43, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R4, R42, R5, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R42.reuse, 0x5, R42.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R42, 0x13, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R43, R0, R8, 0x96, !PT
    [B------:R-:W-:Y:S02]    IADD3 R7, PT, PT, R41, R7, R50
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R42, R51, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R8, R0, R49, R0, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R7, R48, R7, R48, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R40.reuse, 0x11, R40.reuse
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R3, R8, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R3, R40, 0x13, R40
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R49, RZ, 0xa, R40
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R7, -0x40a68039, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R8.reuse, 0x14, R8.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R3, R0, R49, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R9, R48, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R3, R8, 0xb, R8
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R15, R0, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R43, R6, R8, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R8, R3, R7, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R5, R9, R42, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R9.reuse, 0x5, R9.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R49, R9, 0x13, R9
    [B------:R-:W-:-:S02]    LEA.HI R7, R3, R50, R3, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R0, R4, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R9, R56, R49, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R48, R7, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R41, 0x11, R41
    [B------:R-:W-:Y:S02]    LEA.HI R4, R49, R4, R49, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R41, 0x13, R41.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R41
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R4, -0x391ff40d, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R7.reuse, 0xb, R7.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R7, 0x14, R7
    [B------:R-:W-:Y:S02]    LOP3.LUT R57, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R7, R48, R3, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R8, R43, R7, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R6, R49, RZ
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R34, R57, RZ
    [B------:R-:W-:-:S02]    LEA.HI R48, R48, R51, R48, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R50, R42, R6, R9, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R6.reuse, 0x5, R6.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R4, R6.reuse, 0x13, R6
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R3, R5, R50
    [B------:R-:W-:-:S02]    LOP3.LUT R4, R6, R51, R4, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R49, R48, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R49, R0, 0x11, R0
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R0, 0x13, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0xa, R0
    [B------:R-:W-:-:S02]    LEA.HI R5, R4, R5, R4, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R50, R49, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R48, 0xb, R48
    [B------:R-:W-:Y:S02]    IADD3 R50, PT, PT, R5, -0x2a586eb9, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R4, R48.reuse, 0x14, R48.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R7, R8, R48, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R48, R49, R4, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, R50, RZ
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R58, 0x10420023, R33
    [B------:R-:W-:Y:S02]    LEA.HI R49, R49, R56, R49, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R9, R43, R6, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R43.reuse, 0x5, R43.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R43.reuse, 0x13, R43
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R4, R42, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R43, R56, R5, 0x96, !PT
    [B------:R-:W-:Y:S02]    IADD3 R49, PT, PT, R50, R49, RZ
    [B------:R-:W-:-:S02]    LEA.HI R42, R5, R42, R5, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R49.reuse, 0xb, R49.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R49.reuse, 0x14, R49
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R42, 0x6ca6351, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R49, R50, R51, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R51, R48, R7, R49, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R8, R5, RZ
    [B------:R-:W-:-:S02]    LEA.HI R42, R50, R51, R50, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R6, R8, R43, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R5, R42, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R8, 0x5, R8
    [B------:R-:W-:Y:S02]    IADD3 R50, PT, PT, R9, R50, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R8, 0x13, R8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R42.reuse, 0xb, R42.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R42, 0x14, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R8, R5, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R42, R51, R56, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R56, R5, R50, R5, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R58, R49, R48, R42, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R3.reuse, 0x11, R3.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R3, 0x13, R3.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R9, RZ, 0xa, R3
    [B------:R-:W-:-:S02]    LEA.HI R57, R51, R58, R51, 0x1e
    [B------:R-:W-:Y:S02]    LOP3.LUT R5, R50, R5, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R14.reuse, 0x7, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R14, 0x12, R14.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R51, RZ, 0x3, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R50, R9, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R4, 0x13, R4
    [B------:R-:W-:Y:S04]    IADD3 R5, PT, PT, R9, R32, R5
    [B------:R-:W-:Y:S04]    IADD3 R5, PT, PT, R5, 0x108, RZ
    [B------:R-:W-:Y:S04]    IADD3 R56, PT, PT, R56, 0x14292967, R5
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R7, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R56, R57, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R4, 0x11, R4.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R4
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R43, R9, R8, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R7, R50, R7, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R50, RZ, 0x3, R13.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R7, R35, R14
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R13.reuse, 0x7, R13.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R13, 0x12, R13
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R6, R57, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R6, R9, 0x5, R9
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R14, R7, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R9, 0x13, R9
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R5, 0x13, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R9, R6, R14, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R7, R56, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R7, R51, 0x14, R51
    [B------:R-:W-:-:S02]    LEA.HI R57, R14, R57, R14, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R51.reuse, 0xb, R51
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R51, R14, R7, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R42, R49, R51, 0xe8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R57, PT, PT, R57, 0x27b70a85, R6
    [B------:R-:W-:-:S02]    LEA.HI R14, R7, R14, R7, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R5, 0x11, R5
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R57, RZ
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R57, R14, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R50, R7, R56, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R12, 0x12, R12
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R7, R40, R13
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R12, 0x7, R12.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R13, RZ, 0x3, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R50, R7, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R8, R48, R9, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R13, R48.reuse, 0x5, R48.reuse
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R43, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R48, 0x13, R48
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R51, R42, R14.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R48, R13, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R14.reuse, 0x14, R14.reuse
    [B------:R-:W-:-:S02]    LEA.HI R50, R13, R50, R13, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R13, R14, 0xb, R14
    [B------:R-:W-:Y:S02]    IADD3 R50, PT, PT, R50, 0x2e1b2138, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R14, R13, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R6, 0x11, R6.reuse
    [B------:R-:W-:-:S02]    LEA.HI R13, R13, R56, R13, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R49, R50, RZ
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R6
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R50, R13, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R6, 0x13, R6
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R50, R43, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R50, RZ, 0x3, R11.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R43, R41, R12
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R11.reuse, 0x7, R11.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R11, 0x12, R11
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R56, RZ, 0xa, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R43, R12, R50, 0x96, !PT
    [B------:R-:W-:Y:S04]    LOP3.LUT R43, R9, R49, R48, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R8, R43, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R8, R49.reuse, 0x5, R49.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R43, R49, 0x13, R49
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R49, R8, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R12, R57, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R13, 0xb, R13
    [B------:R-:W-:-:S02]    LEA.HI R43, R43, R50, R43, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R13, 0x14, R13.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R57, R14, R51, R13, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R12, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, 0x4d2c6dfc, R8
    [B------:R-:W-:-:S02]    LEA.HI R50, R12, R57, R12, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R7, 0x11, R7
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, R43, RZ
    [B------:R-:W-:Y:S02]    IADD3 R50, PT, PT, R43, R50, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R43, R7, 0x13, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R43, R12, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R43, RZ, 0x3, R10.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R12, R0, R11
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R10.reuse, 0x7, R10.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R12, R10, 0x12, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R12, R11, R43, 0x96, !PT
    [B------:R-:W-:Y:S04]    LOP3.LUT R12, R48, R42, R49, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R9, R12, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R42.reuse, 0x5, R42.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R12, R42, 0x13, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R42, R9, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R11, R56, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R50, 0xb, R50
    [B------:R-:W-:-:S02]    LEA.HI R12, R12, R43, R12, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R50, 0x14, R50.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R56, R13, R14, R50, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R50, R11, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, 0x53380d13, R9
    [B------:R-:W-:-:S02]    LEA.HI R43, R11, R56, R11, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R8, 0x11, R8
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, R12, RZ
    [B------:R-:W-:Y:S02]    IADD3 R43, PT, PT, R12, R43, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R8, 0x13, R8.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R56, RZ, 0xa, R8
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R12, R11, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R12, RZ, 0x3, R15.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R11, R3, R10
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R15.reuse, 0x7, R15.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R15, 0x12, R15
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R56, RZ, 0xa, R9
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R11, R10, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R49, R51, R42, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R51.reuse, 0x5, R51.reuse
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, R57, RZ
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R11, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R11, R51, 0x13, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R50, R13, R43, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R51, R12, R11, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R43, 0xb, R43
    [B------:R-:W-:-:S02]    LEA.HI R11, R11, R48, R11, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R43, 0x14, R43
    [B------:R-:W-:Y:S02]    IADD3 R11, PT, PT, R11, 0x650a7354, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R43, R12, R48, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R11, RZ
    [B------:R-:W-:-:S02]    LEA.HI R48, R12, R57, R12, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R9, 0x13, R9.reuse
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R11, R48, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R11, R9, 0x11, R9
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R12, R11, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R34.reuse, 0x12, R34.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R11, R4, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R34, 0x7, R34.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R15, RZ, 0x3, R34
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R12, R11, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R42, R14, R51, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R14.reuse, 0x5, R14.reuse
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R49, R12, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R12, R14, 0x13, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R43, R50, R48, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R14, R15, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R48, 0xb, R48
    [B------:R-:W-:-:S02]    LEA.HI R12, R12, R49, R12, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R49, R48, 0x14, R48
    [B------:R-:W-:Y:S02]    IADD3 R12, PT, PT, R12, 0x766a0abb, R11
    [B------:R-:W-:Y:S04]    LOP3.LUT R15, R48, R15, R49, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R49, R15, R56, R15, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R13, R12, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R13, R10, 0x13, R10.reuse
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R12, R49, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R10, 0x11, R10.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R56, RZ, 0xa, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R12, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R13, R33.reuse, 0x12, R33.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R12, R5, R34
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R33, 0x7, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R34, RZ, 0x3, R33
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R56, RZ, 0xa, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R12, R34, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R51, R15, R14, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R15.reuse, 0x5, R15.reuse
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, R57, RZ
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, R13, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R13, R15, 0x13, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R48, R43, R49, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R15, R34, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R49, 0xb, R49
    [B------:R-:W-:-:S02]    LEA.HI R13, R13, R42, R13, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R49, 0x14, R49
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R13, -0x7e3d36d2, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R49, R34, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R11, 0x13, R11.reuse
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R57, R34, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R50, R13, RZ
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R13, R34, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R13, R11, 0x11, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R42, R13, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R32.reuse, 0x12, R32.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R13, R6, R33
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R13, R32, 0x7, R32.reuse
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R33, RZ, 0x3, R32
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R42, R13, R33, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R14, R50, R15, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R50.reuse, 0x5, R50.reuse
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R51, R42, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R42, R50, 0x13, R50
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R12, 0x13, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R50, R33, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R34.reuse, 0x14, R34.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R33, R58, R33, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R33, R34, 0xb, R34
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R56, RZ, 0xa, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R34, R33, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R49, R48, R34, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, -0x6d8dd37b, R13
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R42, R33, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R12, 0x11, R12
    [B------:R-:W-:Y:S02]    IADD3 R43, PT, PT, R43, R58, RZ
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R58, R33, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R51, R42, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R35.reuse, 0x12, R35.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R42, R7, R32
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R35, 0x7, R35.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R42, RZ, 0x3, R35
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R51, R32, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R15, R43, R50, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R43.reuse, 0x13, R43.reuse
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R14, R51, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R14, R43, 0x5, R43
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R43, R14, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R32, R57, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R33.reuse, 0xb, R33.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R42, R51, R42, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R33, 0x14, R33.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R57, R34, R49, R33, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R33, R32, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, -0x5d40175f, R14
    [B------:R-:W-:-:S02]    LEA.HI R42, R32, R57, R32, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R13, 0x11, R13
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R42, PT, PT, R51, R42, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R13, 0x13, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R51, R32, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R50, R48, R43, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R32, R8, R35
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R40.reuse, 0x7, R40.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R40, 0x12, R40.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R51, RZ, 0x3, R40
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R15, R56, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R48.reuse, 0x5, R48.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R35, R32, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R48, 0x13, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R14, 0x13, R14
    [B------:R-:W-:Y:S02]    LOP3.LUT R35, R48, R15, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R32, R57, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R42.reuse, 0x14, R42.reuse
    [B------:R-:W-:-:S02]    LEA.HI R56, R35, R56, R35, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R42, 0xb, R42
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R56, -0x57e599b5, R15
    [B------:R-:W-:Y:S02]    LOP3.LUT R32, R42, R35, R32, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R33, R34, R42, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R49, R56, RZ
    [B------:R-:W-:-:S02]    LEA.HI R35, R32, R35, R32, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R14, 0x11, R14.reuse
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R56, R35, RZ
    [B------:R-:W-:Y:S04]    SHF.R.U32.HI R56, RZ, 0xa, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R51, R32, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R41.reuse, 0x12, R41.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R32, R9, R40
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R41, 0x7, R41.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R40, RZ, 0x3, R41
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R56, RZ, 0xa, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R51, R32, R40, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R43, R49, R48, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R49.reuse, 0x5, R49.reuse
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, R57, RZ
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R50, R51, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R49, 0x13, R49
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R42, R33, R35.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R49, R40, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R35.reuse, 0x14, R35.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R40, R51, R40, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R35, 0xb, R35
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R51, -0x3db47490, R32
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R35, R40, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R15, 0x11, R15.reuse
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R57, R40, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R51, RZ
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R51, R40, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R15, 0x13, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R0.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R10, R41
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R0.reuse, 0x7, R0.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R0, 0x12, R0
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R50, R41, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R48, R34, R49, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R32, 0x13, R32
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R43, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R34, 0x5, R34
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R34.reuse, 0x13, R34
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R32
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R34, R43, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R40.reuse, 0x14, R40.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R43, R58, R43, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R40, 0xb, R40
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, -0x3893ae5d, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R40, R43, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R35, R42, R40, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R43, R43, R50, R43, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R32, 0x11, R32
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R58, R43, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R3.reuse, 0x12, R3.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R50, R11, R0
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R3, 0x7, R3.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R50, RZ, 0x3, R3
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R51, R0, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R49, R33, R34, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R33, 0x13, R33
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R0, R57, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R48, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R33.reuse, 0x5, R33
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R40, R35, R43.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R33, R48, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R43.reuse, 0x14, R43.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R48, R51, R48, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R48, R43, 0xb, R43
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, -0x2e6d17e7, R0
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R43, R48, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R41, 0x11, R41
    [B------:R-:W-:-:S02]    LEA.HI R48, R48, R57, R48, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R48, PT, PT, R51, R48, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R41, 0x13, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R4.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R12, R3
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R3, R4.reuse, 0x7, R4.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R4, 0x12, R4
    [B------:R-:W-:-:S02]    LOP3.LUT R3, R50, R3, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R34, R42, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R0, 0x13, R0
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R3, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R49, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R49, R42, 0x5, R42
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R42.reuse, 0x13, R42
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R0
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R42, R49, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R48.reuse, 0x14, R48.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R49, R58, R49, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R49, R48, 0xb, R48
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, -0x2966f9dc, R3
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R48, R49, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R43, R40, R48, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R35, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R49, R49, R50, R49, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R0, 0x11, R0
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R58, R49, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R5.reuse, 0x12, R5.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R50, R13, R4
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R4, R5, 0x7, R5.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R50, RZ, 0x3, R5
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R3
    [B------:R-:W-:-:S02]    LOP3.LUT R4, R51, R4, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R33, R35, R42, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R35, 0x13, R35
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R4, R57, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R34, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R35.reuse, 0x5, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R48, R43, R49.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R35, R34, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R49.reuse, 0x14, R49.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R34, R51, R34, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R34, R49, 0xb, R49
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, -0xbf1ca7b, R4
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R49, R34, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R3, 0x11, R3
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R57, R34, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R34, PT, PT, R51, R34, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R3, 0x13, R3
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R6.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R14, R5
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R6.reuse, 0x7, R6.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R6, 0x12, R6
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R50, R5, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R42, R40, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R4, 0x13, R4
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R5, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R33, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R33, R40, 0x5, R40
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R40.reuse, 0x13, R40
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R4
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R40, R33, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R34.reuse, 0x14, R34.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R33, R58, R33, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R33, R34, 0xb, R34
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x106aa070, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R34, R33, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R49, R48, R34, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R50, R33, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R4, 0x11, R4
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R58, R33, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R7.reuse, 0x12, R7.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R50, R15, R6
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R6, R7, 0x7, R7.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R50, RZ, 0x3, R7
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R6, R51, R6, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R35, R43, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R43, 0x13, R43
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R6, R57, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R42, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R43.reuse, 0x5, R43
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R34, R49, R33.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R43, R42, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R33.reuse, 0x14, R33.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R42, R51, R42, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R42, R33, 0xb, R33
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, 0x19a4c116, R6
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R33, R42, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R5, 0x11, R5
    [B------:R-:W-:-:S02]    LEA.HI R42, R42, R57, R42, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R42, PT, PT, R51, R42, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R5, 0x13, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R8.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R32, R7
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R8.reuse, 0x7, R8.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R8, 0x12, R8
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R50, R7, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R40, R48, R43, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R6, 0x13, R6
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R35, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R35, R48, 0x5, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R48.reuse, 0x13, R48
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R6
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R48, R35, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R42.reuse, 0x14, R42.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R35, R58, R35, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R35, R42, 0xb, R42
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x1e376c08, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R42, R35, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R33, R34, R42, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R49, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R35, R35, R50, R35, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R6, 0x11, R6
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R58, R35, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R9.reuse, 0x12, R9.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R50, R41, R8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R8, R9, 0x7, R9.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R50, RZ, 0x3, R9
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R8, R51, R8, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R43, R49, R48, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R49, 0x13, R49
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R8, R57, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R40, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R49.reuse, 0x5, R49
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R42, R33, R35.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R49, R40, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R35.reuse, 0x14, R35.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R40, R51, R40, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R40, R35, 0xb, R35
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, 0x2748774c, R8
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R35, R40, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R7, 0x11, R7
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R57, R40, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R40, PT, PT, R51, R40, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R7, 0x13, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R10.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R0, R9
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R10.reuse, 0x7, R10.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R10, 0x12, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R50, R9, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R48, R34, R49, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R8, 0x13, R8
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R9, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R43, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R34, 0x5, R34
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R34.reuse, 0x13, R34
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R8
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R34, R43, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R40.reuse, 0x14, R40.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R43, R58, R43, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R43, R40, 0xb, R40
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x34b0bcb5, R9
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R40, R43, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R35, R42, R40, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R43, R43, R50, R43, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R8, 0x11, R8
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R58, R43, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R11.reuse, 0x12, R11.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R50, R3, R10
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R11, 0x7, R11.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R50, RZ, 0x3, R11
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R9
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R51, R10, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R49, R33, R34, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R33, 0x13, R33
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, R57, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R48, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R48, R33.reuse, 0x5, R33
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R40, R35, R43.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R33, R48, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R43.reuse, 0x14, R43.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R48, R51, R48, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R48, R43, 0xb, R43
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, 0x391c0cb3, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R43, R48, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R9, 0x11, R9
    [B------:R-:W-:-:S02]    LEA.HI R48, R48, R57, R48, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R48, PT, PT, R51, R48, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R9, 0x13, R9
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R12.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R4, R11
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R12.reuse, 0x7, R12.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R12, 0x12, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R50, R11, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R34, R42, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R10, 0x13, R10
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R49, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R49, R42, 0x5, R42
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R42.reuse, 0x13, R42
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R42, R49, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R48.reuse, 0x14, R48.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R49, R58, R49, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R49, R48, 0xb, R48
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x4ed8aa4a, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R49, R48, R49, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R43, R40, R48, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R35, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R49, R49, R50, R49, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R10, 0x11, R10
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R58, R49, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R13.reuse, 0x12, R13.reuse
    [B------:R-:W-:-:S02]    IADD3 R57, PT, PT, R50, R5, R12
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R13, 0x7, R13.reuse
    [B------:R-:W-:Y:S02]    SHF.R.U32.HI R50, RZ, 0x3, R13
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R51, R12, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R33, R35, R42, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R35, 0x13, R35
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, R57, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R34, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R34, R35.reuse, 0x5, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R57, R48, R43, R49.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R35, R34, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R49.reuse, 0x14, R49.reuse
    [B------:R-:W-:-:S02]    LEA.HI R51, R34, R51, R34, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R34, R49, 0xb, R49
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R51, 0x5b9cca4f, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R49, R34, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R11, 0x11, R11
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R57, R34, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R51, RZ
    [B------:R-:W-:Y:S02]    IADD3 R34, PT, PT, R51, R34, RZ
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R51, R11, 0x13, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0x3, R14.reuse
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R50, R6, R13
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R13, R14.reuse, 0x7, R14.reuse
    [B------:R-:W-:Y:S04]    SHF.R.W.U32 R50, R14, 0x12, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R50, R13, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R42, R40, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R12, 0x13, R12
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R33, R50, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R33, R40, 0x5, R40
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R40.reuse, 0x13, R40
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R40, R33, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R34.reuse, 0x14, R34.reuse
    [B------:R-:W-:-:S02]    LEA.HI R58, R33, R58, R33, 0x1a
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R33, R34, 0xb, R34
    [B------:R-:W-:-:S02]    IADD3 R58, PT, PT, R58, 0x682e6ff3, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R34, R33, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R49, R48, R34, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, R58, RZ
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R50, R33, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R12, 0x11, R12
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R58, R33, RZ
    [B------:R-:W-:Y:S04]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R50, R7, R14
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R7, R15.reuse, 0x7, R15.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R14, R15, 0x12, R15.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R50, RZ, 0x3, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R56, R33, 0xb, R33
    [B------:R-:W-:Y:S02]    LOP3.LUT R14, R14, R7, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R35, R43, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R51, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R33, 0x14, R33
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R42, R7, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R43.reuse, 0x5, R43.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R7, R43, 0x13, R43
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R33, R56, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R43, R42, R7, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R34, R49, R33, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R7, R7, R50, R7, 0x1a
    [B------:R-:W-:-:S02]    LEA.HI R42, R51, R42, R51, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R50, R13, 0x11, R13
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R51, R13, 0x13, R13.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R56, RZ, 0xa, R13
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, 0x748f82ee, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R51, R50, R56, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R7, RZ
    [B------:R-:W-:Y:S02]    IADD3 R51, PT, PT, R50, R8, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R8, R32.reuse, 0x7, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R32, 0x12, R32.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R50, RZ, 0x3, R32
    [B------:R-:W-:-:S02]    LOP3.LUT R56, R40, R48, R43, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R8, R15, R8, R50, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R15, R48, 0x5, R48
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R48, 0x13, R48
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R35, R56, RZ
    [B------:R-:W-:-:S02]    IADD3 R51, PT, PT, R8, R51, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R48, R15, R50, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R8, R14, 0x11, R14
    [B------:R-:W-:Y:S02]    LEA.HI R56, R15, R56, R15, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R14, 0x13, R14.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R35, RZ, 0xa, R14
    [B------:R-:W-:-:S02]    IADD3 R56, PT, PT, R56, 0x78a5636f, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R8, R15, R8, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R41, 0x7, R41
    [B------:R-:W-:Y:S02]    IADD3 R49, PT, PT, R49, R56, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R41, 0x12, R41.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R35, RZ, 0x3, R41
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R8, R9, R32
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R50, R15, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R43, R49, R48, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R32, R49, 0x5, R49
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R49, 0x13, R49
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R35, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R35, R51, 0x13, R51
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R49, R32, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R32, R51, 0x11, R51
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, R8, RZ
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R51, RZ, 0xa, R51
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R7, R42, RZ
    [B------:R-:W-:-:S02]    LEA.HI R40, R9, R40, R9, 0x1a
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R35, R32, R51, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R40, -0x7b3787ec, R15
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R7, R8, 0xb, R8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R8.reuse, 0x14, R8.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R33, R34, R8, 0xe8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R8, R7, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R35, RZ
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R51, R10, R41
    [B------:R-:W-:Y:S02]    LEA.HI R7, R7, R32, R7, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R0.reuse, 0x7, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R0, 0x12, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R32, RZ, 0x3, R0
    [B------:R-:W-:-:S02]    LOP3.LUT R50, R48, R34, R49, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R34.reuse, 0x5, R34.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R42, R34, 0x13, R34
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R10, R9, R32, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R50, PT, PT, R43, R50, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R34, R41, R42, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R56, R7, RZ
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R9, R40, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R41, R41, R50, R41, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R15, 0x11, R15
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R7.reuse, 0xb, R7.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R7, 0x14, R7
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R41, -0x7338fdf8, R40
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R15, 0x13, R15
    [B------:R-:W-:Y:S02]    LOP3.LUT R9, R7, R10, R9, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R15, RZ, 0xa, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R8, R33, R7, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R32, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R43, R42, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R10, R9, R10, R9, 0x1e
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R9, R3, 0x7, R3
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R42, R3, 0x12, R3.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R41, RZ, 0x3, R3
    [B------:R-:W-:-:S02]    LOP3.LUT R51, R49, R33, R34, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R50, R33.reuse, 0x5, R33.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R43, R33, 0x13, R33
    [B------:R-:W-:Y:S02]    LOP3.LUT R9, R42, R9, R41, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R15, R11, R0
    [B------:R-:W-:-:S02]    IADD3 R48, PT, PT, R48, R51, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R33, R50, R43, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R35, R10, RZ
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R9, R42, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R43, R43, R48, R43, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R40, 0x11, R40
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R0.reuse, 0xb, R0.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R0.reuse, 0x14, R0
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, -0x6f410006, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R0, R9, R10, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R48, R40, 0x13, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R7, R8, R0, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R40, RZ, 0xa, R40
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R8, R43, RZ
    [B------:R-:W-:-:S02]    LEA.HI R9, R9, R10, R9, 0x1e
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R48, R11, R40, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R10, R4, 0x7, R4
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R4, 0x12, R4.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R35, RZ, 0x3, R4
    [B------:R-:W-:-:S02]    LOP3.LUT R48, R34, R8, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R41, R8.reuse, 0x5, R8.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R40, R8, 0x13, R8
    [B------:R-:W-:Y:S02]    LOP3.LUT R10, R15, R10, R35, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, R12, R3
    [B------:R-:W-:-:S02]    IADD3 R49, PT, PT, R49, R48, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R8, R41, R40, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R32, R9, RZ
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R10, R11, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R40, R40, R49, R40, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R42, 0x11, R42.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R3.reuse, 0xb, R3.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R3.reuse, 0x14, R3
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, -0x5baf9315, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R3, R10, R9, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R15, R42, 0x13, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R0, R7, R3, 0xe8, !PT
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R42, RZ, 0xa, R42
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, R40, RZ
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R4, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R15, R12, R42, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R4, R9, R10, R9, 0x1e
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R5.reuse, 0x7, R5.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R5, 0x12, R5.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R13, RZ, 0x3, R5
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R33, R7, R8, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R43, R4, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R13, R10, R9, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R15, R34, R12
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R7.reuse, 0x5, R7.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R7, 0x13, R7
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R9, R4.reuse, 0xb, R4.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R10, R4, 0x14, R4
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R13, R34, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R7, R12, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R9, R4, R9, R10, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R3, R0, R4, 0xe8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R13, R12, R13, R12, 0x1a
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R12, R6.reuse, 0x7, R6.reuse
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R15, R6, 0x12, R6
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R6, RZ, 0x3, R6
    [B------:R-:W-:-:S02]    LEA.HI R9, R9, R10, R9, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, -0x41065c09, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R15, R12, R6, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R40, R9, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R12, R11, 0x11, R11
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R15, R11, 0x13, R11.reuse
    [B------:R-:W-:-:S02]    SHF.R.U32.HI R11, RZ, 0xa, R11
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R0, R13, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R0, R9.reuse, 0xb, R9.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R6, R9, 0x14, R9
    [B------:R-:W-:Y:S02]    LOP3.LUT R11, R15, R12, R11, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R33, R5, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R8, R10, R7, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R6, R9, R0, R6, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R4, R3, R9, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R11, R5, R12
    [B------:R-:W-:Y:S02]    IADD3 R14, PT, PT, R10, -0x64fa9774, RZ
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R5, R10.reuse, 0x5, R10.reuse
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R11, R10, 0x13, R10
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R0, RZ
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, R15, RZ
    [B------:R-:W-:-:S02]    PRMT R0, R14, 0x123, RZ
    [B------:R-:W-:Y:S02]    LOP3.LUT R5, R10, R5, R11, 0x96, !PT
    [B------:R-:W-:-:S02]    LEA.HI R13, R6, R13, R6, 0x1e
    [B------:R-:W-:-:S02]    LEA.HI R32, R5, R32, R5, 0x1a
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R0, -0x37e5fca3, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R9, R4, R13.reuse, 0xe8, !PT
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, -0x398e870e, RZ
    [B------:R-:W-:Y:S02]    SHF.R.W.U32 R5, R13, 0x14, R13
    [B------:R-:W-:-:S02]    LEA.HI R12, R6, 0xc3d2e1f0, R6, 0x8
    [B------:R-:W-:-:S02]    SHF.R.W.U32 R6, R13.reuse, 0xb, R13
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R32, R11, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R12.reuse, 0xffcdaf9d, RZ, 0x3c, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R13, R6, R5, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R34, R12, 0xa, R12
    [B------:R-:W-:-:S02]    LEA.HI R10, R5, R10, R5, 0x1e
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x14756ed6, RZ
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R8, 0x5be0cd19, RZ
    [B------:R-:W-:-:S02]    IADD3 R9, PT, PT, R9, 0x3c6ef372, RZ
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R10, 0x6a09e667, RZ
    [B------:R-:W-:Y:S02]    IADD3 R4, PT, PT, R4, -0x5ab00ac6, RZ
    [B------:R-:W-:-:S02]    LEA.HI R15, R14, 0x10325476, R14, 0x9
    [B------:R-:W-:-:S02]    PRMT R5, R5, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R8, R15, 0xc951d840, R12, 0x1e, !PT
    [B------:R-:W-:-:S02]    PRMT R6, R6, 0x123, RZ
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R5, 0x60d4e05c, R8
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R35, R15, 0xa, R15
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R6, -0x3175b9fe, RZ
    [B------:R-:W-:-:S02]    LEA.HI R14, R8, 0xeb73fa62, R8, 0x9
    [B------:R-:W-:-:S02]    IADD3 R8, PT, PT, R13, -0x4498517b, RZ
    [B------:R-:W-:-:S02]    PRMT R9, R9, 0x123, RZ
    [B------:R-:W-:-:S02]    LEA.HI R10, R10, 0xc3d2e1f0, R10, 0xb
    [B------:R-:W-:Y:S02]    LOP3.LUT R13, R14, R15, R34, 0x2d, !PT
    [B------:R-:W-:-:S02]    PRMT R8, R8, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R10, 0x4be51eb, RZ, 0x3c, !PT
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x3c168648, R6
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R8, -0x3c2d1e10, R11
    [B------:R-:W-:-:S02]    LEA.HI R33, R13, 0x36ae27bf, R13, 0xb
    [B------:R-:W-:Y:S02]    LEA.HI R11, R11, 0x10325476, R11, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R33, R14, R35, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R10, 0x36ae27bf, R11, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R42, R14, 0xa, R14
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R13, -0x78af4c5b, RZ
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R9, 0x10325476, R12
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R13, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R12, R12, 0xeb73fa62, R12, 0xf
    [B------:R-:W-:-:S02]    LEA.HI R40, R15, R34, R15, 0xd
    [B------:R-:W-:-:S02]    PRMT R4, R4, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R12, R11, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R40, R33, R42, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R4, -0x148c059e, R15
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R10, R9, R34
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R3, 0x510e527f, R32
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R10, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R15, R15, 0x36ae27bf, R15, 0xc
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, 0x50a28be6, RZ
    [B------:R-:W-:Y:S02]    PRMT R3, R3, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R15, R12, R10, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R33, R34, R35, R34, 0xf
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R3, 0x36ae27bf, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R33, R40, R32, 0x2d, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R12, R12, 0xa, R12
    [B------:R-:W-:-:S02]    LEA.HI R14, R14, R13, R14, 0x5
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R35, 0x50a28be6, R34
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R14, R15, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R40, 0xa, R40
    [B------:R-:W-:-:S02]    LEA.HI R34, R35, R42, R35, 0xf
    [B------:R-:W-:Y:S02]    IADD3 R11, PT, PT, R11, R13, R0
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, 0x1f83d9ab, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R34, R33, R40, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R11, R11, R10, R11, 0x8
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R13, R3, R42
    [B------:R-:W-:Y:S02]    PRMT R7, R7, 0x123, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R11, R14, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R14, 0xa, R14
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R10, R7
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R42, 0x50a28be6, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R33, 0xa, R33
    [B------:R-:W-:Y:S02]    LEA.HI R10, R13, R12, R13, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R35, R35, R32, R35, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R10, R11, R14, 0x96, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R35, R34, R33, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R13, R12, R5
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R11, 0xa, R11
    [B------:R-:W-:Y:S02]    LEA.HI R11, R12, R15, R12, 0x9
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R32, 0x50a28be6, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R11, R10, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R34, 0xa, R34
    [B------:R-:W-:-:S02]    LEA.HI R32, R41, R40, R41, 0x7
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, 0x80, R12
    [B------:R-:W-:Y:S02]    LOP3.LUT R41, R32, R35, R34, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R10, R15, R14, R15, 0xb
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, R7, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R10, R11, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R41, 0x50a28be6, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R41, R35, 0xa, R35
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R15, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R35, R40, R33, R40, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R13, R14, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R35, R32, R41, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R14, R11, R10, R15, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, 0x50a28be6, R40
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R32, 0xa, R32
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R14, RZ
    [B------:R-:W-:-:S02]    LEA.HI R32, R33, R34, R33, 0x8
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:Y:S02]    LEA.HI R10, R13, R12, R13, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R32, R35, R40, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R10, R11, R14, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, 0x50a28c66, R33
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R35, 0xa, R35
    [B------:R-:W-:-:S02]    LEA.HI R33, R34, R41, R34, 0xb
    [B------:R-:W-:Y:S02]    IADD3 R12, PT, PT, R12, R13, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R33, R32, R35, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R11, R12, R15, R12, 0xf
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R8, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R11, R10, R13, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R42, R33, 0xa, R33
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R34, 0x50a28be6, RZ
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, R12, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R32, 0xa, R32
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R32, R41, R40, R41, 0xe
    [B------:R-:W-:Y:S02]    LEA.HI R10, R15, R14, R15, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R32, R33, R34, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R10, R11, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, 0x50a28be6, R41
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R15, RZ
    [B------:R-:W-:-:S02]    LEA.HI R15, R40, R35, R40, 0xe
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R40, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R13, R14, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R15, R32, R42, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R11, R10, R40, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R4, R35
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x100, R14
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, 0x50a28be6, RZ
    [B------:R-:W-:-:S02]    LEA.HI R10, R13, R12, R13, 0x9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R32, R33, R34, R33, 0xc
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R10, R11, R14, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R35, R32, R15, R13, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R12, R33, RZ
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R34, 0x50a28be6, R35
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R40, R33, 0x8
    [B------:R-:W-:Y:S02]    LEA.HI R35, R35, R42, R35, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R11, R33, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R32, R15, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, R5, R40
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R7, R42
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R43, R10, 0xa, R10
    [B------:R-:W-:Y:S02]    IADD3 R41, PT, PT, R12, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R10, R41, R14, R41, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R13, R34, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R43, R10, R33, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R40, R35, R32, R34, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, R3, R14
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R13, 0x5c4dd124, R40
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R35, 0xa, R35
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R33, 0xa, R33
    [B------:R-:W-:Y:S02]    LEA.HI R35, R40, R15, R40, 0xd
    [B------:R-:W-:-:S02]    LEA.HI R13, R12, R11, R12, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R34, R41, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R33, R13, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R4, R15
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R11, 0x5a827999, R12
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R10, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R12, R12, R43, R12, 0x8
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R14, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R34, 0xa, R34
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R10, R12, R13, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R14, R11, R32, R11, 0xf
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, R8, R43
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R35, R34, R14, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R13, 0xa, R13
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R15, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R11, R5, R32
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R35, 0xa, R35
    [B------:R-:W-:Y:S02]    LEA.HI R11, R40, R33, R40, 0xd
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R43, R12, 0xa, R12.reuse
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R13, R11, R12, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R15, R32, R41, R32, 0x7
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, 0x5a827999, R40
    [B------:R-:W-:Y:S02]    LOP3.LUT R32, R14, R35, R15, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R12, R33, R10, R33, 0xb
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, R6, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R43, R12, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R14, 0xa, R14
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R32, 0x5c4dd124, RZ
    [B------:R-:W-:Y:S02]    IADD3 R40, PT, PT, R40, R7, R10
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R10, R33, R34, R33, 0xc
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R15, R14, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R11, R40, R13, R40, 0x9
    [B------:R-:W-:Y:S02]    IADD3 R34, PT, PT, R34, 0x5c4dd124, R33
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R32, R11, R12, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R15, R34, R35, R34, 0x8
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R13, 0x5a827999, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R10, R33, R15, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R13, R12, 0xa, R12
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R43, R40, 0x7
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R0, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R40, R11.reuse, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R34, 0x5c4dd124, RZ
    [B------:R-:W-:Y:S02]    IADD3 R43, PT, PT, R12, R4, R43
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R10, R35, R14, R35, 0x9
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R43, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R15.reuse, 0xa, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R15, R12, R10, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R43, R43, R32, R43, 0xf
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x5c4dd124, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R11, R43, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R15, R14, R33, R14, 0xb
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, 0x5a827999, R35
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R40, 0xa, R40
    [B------:R-:W-:Y:S02]    LEA.HI R32, R32, R13, R32, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R10.reuse, R34, R15, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R35, R32, R43, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, 0x5c4dd224, R14
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R6, R13
    [B------:R-:W-:Y:S02]    LEA.HI R10, R33, R12, R33, 0x7
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R42, R43, 0xa, R43
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R15.reuse, R14, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R12, 0x5c4dd124, R13
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R15, 0xa, R15
    [B------:R-:W-:Y:S02]    LEA.HI R13, R40, R11, R40, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R34, R33, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R42, R13, R32, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R10, R12, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R11, 0x5a827999, R40
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R34, 0x5c4dd1a4, R15
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R32, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R35, R40, 0xf
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R11, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R10, R15, R14, R15, 0xc
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R32, R40, R13, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R33, R11, R10, 0xb8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, R0, R35
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R14, 0x5c4dd124, R41
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R13, 0xa, R13
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R41, R41, R12, R41, 0x7
    [B------:R-:W-:Y:S02]    LEA.HI R15, R15, R42, R15, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R10, R33, R41, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R13, R15, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R3, R12
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R9, R42
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:Y:S02]    IADD3 R34, PT, PT, R34, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R14, 0x5a827999, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R40, 0xa, R40
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R11, R34, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R10, R35, R32, R35, 0xb
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R41, R12, R34, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R35, R40, R10, R15, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R11, 0x5c4dd124, R14
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, 0x5a827a99, R35
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R11, R32, R13, R32, 0x7
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R41, 0xa, R41
    [B------:R-:W-:Y:S02]    LEA.HI R35, R14, R33, R14, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R15, R11, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R34, R41, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x5a827999, R14
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, R8, R33
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:Y:S02]    LEA.HI R10, R13, R40, R13, 0xd
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R32, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R34, 0xa, R34
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R14, R10, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R32, R13, R12, R13, 0xd
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, 0x5a827a19, R43
    [B------:R-:W-:Y:S02]    LOP3.LUT R34, R35, R33, R32, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R11, R40, R15, R40, 0xc
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R9, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R11, R10, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R35, 0xa, R35
    [B------:R-:W-:Y:S02]    IADD3 R12, PT, PT, R12, R4, R15
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, 0x5c4dd124, RZ
    [B------:R-:W-:-:S02]    IADD3 R43, PT, PT, R12, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R15, R34, R41, R34, 0xb
    [B------:R-:W-:-:S02]    LEA.HI R10, R43, R14, R43, 0xb
    [B------:R-:W-:Y:S02]    LOP3.LUT R34, R35, R15, R32, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R12, R10, R11, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R41, 0x6d703ef3, R34
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x6ed9eba1, R43
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R33, R34, 0x9
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R32, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R13, R14, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R41, R34, R15, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R32, R11, R10, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R0, R33
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x6ed9eca1, R14
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R33, R10, 0xa, R10
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    LEA.HI R14, R13, R12, R13, 0x6
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R10, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R13, R40, R35, R40, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R33, R14, R11, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R15, R10, R13, R34, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, R3, R12
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, R8, R35
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R40, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R15, 0x6d703ef3, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R34, R34, 0xa, R34
    [B------:R-:W-:-:S02]    LEA.HI R35, R35, R32, R35, 0x7
    [B------:R-:W-:-:S02]    LEA.HI R12, R12, R41, R12, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R43, R11, R35, R14, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R34, R12, R13, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, 0x6ed9eba1, R43
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, R4, R41
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R14, 0xa, R14
    [B------:R-:W-:-:S02]    LEA.HI R32, R32, R33, R32, 0xe
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R13, 0xa, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R41, R32, R35, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R15, R15, R10, R15, 0xb
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R33, 0x6ed9eba1, R40
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R42, R35, 0xa, R35
    [B------:R-:W-:-:S02]    LEA.HI R33, R40, R11, R40, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R14, R15, R12, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R42, R33, R32, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R13, R5, R10
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R11, 0x6ed9ec21, R40
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R32, 0xa, R32
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R41, R40, 0xd
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R12, 0xa, R12
    [B------:R-:W-:Y:S02]    LEA.HI R10, R13, R34, R13, 0x8
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R32, R40, R33, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R12, R10, R15, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R8, R41
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R33, 0xa, R33
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R34, 0x6d703ff3, R11
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R13, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R11, R11, R14, R11, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R33, R13, R42, R13, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R15, R11, R10, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R35, R33, R40, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R13, R7, R14
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R9, R42
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R40, 0xa, R40
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R34, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:Y:S02]    LEA.HI R10, R13, R12, R13, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R34, R41, R32, R41, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R14, R10, R11, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R40, R34, R33, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, 0x6d703ef3, R13
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, R5, R32
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R13, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R11, R12, R15, R12, 0xe
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R41, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R11, R10, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R33, R32, R35, R32, 0x8
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R15, 0x6d703ef3, R12
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R41, R33, R34, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, R6, R35
    [B------:R-:W-:-:S02]    LEA.HI R10, R15, R14, R15, 0xc
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R34, 0xa, R34
    [B------:R-:W-:Y:S02]    IADD3 R35, PT, PT, R32, 0x6ed9eba1, RZ
    [B------:R-:W-:Y:S04]    LOP3.LUT R15, R12, R10, R11, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x6d703f73, R15
    [B------:R-:W-:-:S02]    LEA.HI R32, R35, R40, R35, 0xd
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R13, R14, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R34, R32, R33, 0x2d, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R14, R15, R11, R10, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R35, R7, R40
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x6d703ef3, R14
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R33, 0xa, R33
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R35, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R10, 0xa, R10
    [B------:R-:W-:Y:S02]    LEA.HI R10, R13, R12, R13, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R13, R14, R41, R14, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R35, R10, R11, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R33, R13, R32, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R9, R12
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, 0x6ed9eba1, R40
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R40, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R32, R41, R34, R41, 0x5
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R40, R32, R13, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R15, R14, 0xe
    [B------:R-:W-:Y:S02]    IADD3 R34, PT, PT, R34, 0x6ed9eba1, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R12, R11, R10, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R13, 0xa, R13
    [B------:R-:W-:-:S02]    LEA.HI R13, R34, R33, R34, 0xc
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R15, 0x6d703ef3, R14
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R41, R13, R32, 0x2d, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R10, R10, 0xa, R10
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R15, R0, R33
    [B------:R-:W-:-:S02]    LEA.HI R14, R14, R35, R14, 0xd
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R32, 0xa, R32
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, 0x6ed9eba1, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R10, R14, R11.reuse, 0x2d, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R32, R33, R40, R33, 0x7
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, R6, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R34, R32, R13.reuse, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R13, 0xa, R13
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, 0x6d703ef3, RZ
    [B------:R-:W-:Y:S02]    IADD3 R40, PT, PT, R40, 0x6ed9eba1, R33
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R42, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R33, R40, R41, R40, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R15, R15, R12, R15, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R40, R32, R35, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R11, R15, R14, 0x2d, !PT
    [B------:R-:W-:Y:S02]    IADD3 R40, PT, PT, R40, R8, R41
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R3, R12
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R14, 0xa, R14
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R40, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x6d703ef3, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R15, 0xa, R15
    [B------:R-:W-:Y:S02]    LEA.HI R40, R41, R34, R41, 0xb
    [B------:R-:W-:-:S02]    LEA.HI R12, R13, R10, R13, 0x7
    [B------:R-:W-:-:S02]    LOP3.LUT R41, R33.reuse, R42, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R14, R12, R15, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, -0x70e44324, R41
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, 0x6d703ef3, R13
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R41, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R33, R34, R35, R34, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R13, R10, R11, R10, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R34, R40, R41, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R32, R13, R12, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R35, -0x70e44324, R34
    [B------:R-:W-:Y:S02]    IADD3 R11, PT, PT, R11, 0x7a6d7769, R10
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R12, 0xa, R12
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R40, 0xa, R40
    [B------:R-:W-:-:S02]    LEA.HI R12, R35, R42, R35, 0xe
    [B------:R-:W-:-:S02]    LEA.HI R10, R11, R14, R11, 0xf
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R33, R40, R12, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R11, R15, R10, R13, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, -0x70e44324, R35
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, R7, R14
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R33, R42, R41, R42, 0xf
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, 0x7a6d76e9, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R13, R13, 0xa, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R12, R34, R33, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R11, R11, R32, R11, 0x5
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R14, R6, R41
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R13, R11, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R42, R12, 0xa, R12
    [B------:R-:W-:Y:S02]    IADD3 R41, PT, PT, R41, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R3, R32
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R10, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R32, R41, R40, R41, 0xe
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R35, R33, R42, R32.reuse, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R41, R32, 0xa, R32
    [B------:R-:W-:-:S02]    LEA.HI R14, R14, R15, R14, 0x8
    [B------:R-:W-:-:S02]    IADD3 R35, PT, PT, R40, -0x70e442a4, R35
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R10, R14, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R35, R35, R34, R35, 0xf
    [B------:R-:W-:Y:S02]    IADD3 R12, PT, PT, R12, R8, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R32, R40, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R34, -0x70e44324, R15
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R35, 0xa, R35
    [B------:R-:W-:-:S02]    LEA.HI R32, R15, R42, R15, 0x9
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R15, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LEA.HI R11, R12, R13, R12, 0xb
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R35, R41, R32, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R15, R11, R14, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R3, R42
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R12, R4, R13
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R42, R32, 0xa, R32
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R12, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    LEA.HI R35, R33, R40, R33, 0x8
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R14, 0xa, R14
    [B------:R-:W-:-:S02]    LEA.HI R12, R13, R10, R13, 0xe
    [B------:R-:W-:Y:S02]    LOP3.LUT R43, R32, R34, R35, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R33, R12, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R40, PT, PT, R40, -0x70e44324, R43
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, 0x7a6d76e9, R13
    [B------:R-:W-:-:S02]    LEA.HI R40, R40, R41, R40, 0x9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R11, 0xa, R11
    [B------:R-:W-:Y:S02]    LEA.HI R11, R10, R15, R10, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R35, R42, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R13, R11, R12, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R4, R41
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R15, 0x7a6d76e9, R10
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R35, 0xa, R35
    [B------:R-:W-:Y:S02]    IADD3 R15, PT, PT, R14, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R12, 0xa, R12
    [B------:R-:W-:-:S02]    LEA.HI R10, R10, R33, R10, 0x6
    [B------:R-:W-:-:S02]    LEA.HI R15, R15, R34, R15, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R12, R10, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R40, R35, R15, 0xb8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R14, PT, PT, R14, R6, R33
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, R5, R34
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R40, 0xa, R40
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R32, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R11, 0xa, R11
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R40, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R34, R33, R42, R33, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R13, R14, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R15, R41, R34, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R32, R11, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R42, PT, PT, R42, -0x70e44324, R33
    [B------:R-:W-:Y:S02]    IADD3 R14, PT, PT, R14, R0, R13
    [B------:R-:W-:-:S02]    LEA.HI R15, R42, R35, R42, 0x6
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R14, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    LOP3.LUT R42, R34, R40, R15, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R10, R13, R12, R13, 0x6
    [B------:R-:W-:Y:S02]    IADD3 R42, PT, PT, R35, -0x70e44224, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R14, R10, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R34, 0xa, R34
    [B------:R-:W-:-:S02]    LEA.HI R42, R42, R41, R42, 0x8
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R12, 0x7a6d76e9, R13
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R15, R34, R42, 0xb8, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R12, R0, R41
    [B------:R-:W-:-:S02]    LEA.HI R13, R13, R32, R13, 0x9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R42, 0xa, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R11, R13, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R41, PT, PT, R41, -0x70e44324, RZ
    [B------:R-:W-:Y:S02]    IADD3 R12, PT, PT, R12, R9, R32
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R41, R41, R40, R41, 0x6
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R12, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R42, R32, R41, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R10, R15, R14, R15, 0xc
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R7, R40
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R12, R10, R13, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x7a6d76e9, R15
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R13, 0xa, R13
    [B------:R-:W-:Y:S02]    LEA.HI R40, R33, R34, R33, 0x5
    [B------:R-:W-:-:S02]    LEA.HI R13, R14, R11, R14, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R41, R35, R40, 0xb8, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R15, R13, R10, 0xb8, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R9, R34
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, 0x7a6d76e9, R14
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R14, R10, 0xa, R10
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, -0x70e44324, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R41, R41, 0xa, R41
    [B------:R-:W-:-:S02]    LEA.HI R10, R11, R12, R11, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R33, R33, R32, R33, 0xc
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R14, R10, R13, 0xb8, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R34, R33, R40, R41, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R11, R5, R12
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, R3, R32
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R40, 0xa, R40
    [B------:R-:W-:-:S02]    IADD3 R12, PT, PT, R11, 0x7a6d76e9, RZ
    [B------:R-:W-:-:S02]    IADD3 R34, PT, PT, R34, -0x56ac02b2, RZ
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R13, R13, 0xa, R13
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R42, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R34, R34, R35, R34, 0x9
    [B------:R-:W-:-:S02]    LEA.HI R11, R12, R15, R12, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R34, R33, R40, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R12, R13, R11, R10, 0xb8, !PT
    [B------:R-:W-:Y:S02]    IADD3 R32, PT, PT, R32, R6, R35
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, 0x7a6d76e9, R12
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R10, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R6, R15, R14, R15, 0xf
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R11, 0xa, R11.reuse
    [B------:R-:W-:Y:S02]    LOP3.LUT R15, R10, R6, R11, 0xb8, !PT
    [B------:R-:W-:-:S02]    LEA.HI R33, R32, R41, R32, 0xf
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, 0x7a6d77e9, R15
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R33, R34, R42, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R11, R14, R13, R14, 0x8
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, R0, R41
    [B------:R-:W-:Y:S02]    LOP3.LUT R14, R11, R6, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R34, R34, 0xa, R34
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R15, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, R14, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R6, 0xa, R6
    [B------:R-:W-:-:S02]    LEA.HI R32, R15, R40, R15, 0x5
    [B------:R-:W-:Y:S02]    LEA.HI R6, R13, R10, R13, 0x8
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R32, R33, R34, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R6, R11, R14, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R40, -0x56ac02b2, R15
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R40, R33, 0xa, R33
    [B------:R-:W-:-:S02]    LEA.HI R35, R15, R42, R15, 0xb
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R10, R13, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R35, R32, R40, 0x2d, !PT
    [B------:R-:W-:-:S02]    LEA.HI R13, R13, R12, R13, 0x5
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, R5, R42
    [B------:R-:W-:-:S02]    LOP3.LUT R15, R13, R6, R11, 0x96, !PT
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R32, R32, 0xa, R32
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R10, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R12, R15, RZ
    [B------:R-:W-:-:S02]    LEA.HI R12, R33, R34, R33, 0x6
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R33, R6, 0xa, R6
    [B------:R-:W-:-:S02]    LEA.HI R6, R15, R14, R15, 0xc
    [B------:R-:W-:Y:S02]    LOP3.LUT R15, R12, R35, R32, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R6, R13, R33, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R15, PT, PT, R34, -0x56ac02b2, R15
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, R14, R3
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R35, R35, 0xa, R35
    [B------:R-:W-:-:S02]    LEA.HI R15, R15, R40, R15, 0x8
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R13, R13, 0xa, R13
    [B------:R-:W-:-:S02]    LEA.HI R3, R10, R11, R10, 0x9
    [B------:R-:W-:-:S02]    LOP3.LUT R14, R15, R12, R35, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R10, R3, R6, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R14, PT, PT, R14, R9, R40
    [B------:R-:W-:-:S02]    IADD3 R10, PT, PT, R10, R11, R8
    [B------:R-:W-:Y:S02]    SHF.L.W.U32.HI R41, R12, 0xa, R12
    [B------:R-:W-:-:S02]    IADD3 R11, PT, PT, R14, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R6, R6, 0xa, R6
    [B------:R-:W-:-:S02]    LEA.HI R10, R10, R33, R10, 0xc
    [B------:R-:W-:-:S02]    LEA.HI R14, R11, R32, R11, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R11, R10, R3, R6, 0x96, !PT
    [B------:R-:W-:Y:S02]    LOP3.LUT R43, R14, R15, R41, 0x2d, !PT
    [B------:R-:W-:-:S02]    IADD3 R0, PT, PT, R11, R33, R0
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R32, -0x56ac02b2, R43
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R12, R3, 0xa, R3
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R15, R15, 0xa, R15
    [B------:R-:W-:-:S02]    LEA.HI R11, R32, R35, R32, 0xc
    [B------:R-:W-:Y:S02]    LEA.HI R3, R0, R13, R0, 0x5
    [B------:R-:W-:-:S02]    LOP3.LUT R32, R11, R14, R15, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R0, R3, R10, R12, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R32, PT, PT, R35, -0x56ac01b2, R32
    [B------:R-:W-:-:S02]    IADD3 R13, PT, PT, R13, 0x80, R0
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R14, R14, 0xa, R14
    [B------:R-:W-:Y:S02]    LEA.HI R32, R32, R41, R32, 0x5
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R10, R10, 0xa, R10
    [B------:R-:W-:-:S02]    LEA.HI R0, R13, R6, R13, 0xe
    [B------:R-:W-:-:S02]    LOP3.LUT R33, R32, R11, R14, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R13, R0, R3, R10, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R33, PT, PT, R33, R8, R41
    [B------:R-:W-:Y:S02]    IADD3 R13, PT, PT, R13, R6, R5
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R3, R3, 0xa, R3
    [B------:R-:W-:-:S02]    LEA.HI R13, R13, R12, R13, 0x6
    [B------:R-:W-:-:S02]    IADD3 R6, PT, PT, R33, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R8, R11, 0xa, R11
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R13, R0, R3, 0x96, !PT
    [B------:R-:W-:Y:S02]    LEA.HI R11, R6, R15, R6, 0xc
    [B------:R-:W-:-:S02]    IADD3 R5, PT, PT, R5, R12, R7
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R11, R32, R8, 0x2d, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R6, R0, 0xa, R0
    [B------:R-:W-:-:S02]    LEA.HI R0, R5, R10, R5, 0x8
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, R4, R15
    [B------:R-:W-:Y:S02]    LOP3.LUT R4, R0, R13, R6, 0x96, !PT
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R32, R32, 0xa, R32
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R7, -0x56ac02b2, RZ
    [B------:R-:W-:-:S02]    IADD3 R4, PT, PT, R4, R10, R9
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R13, R13, 0xa, R13
    [B------:R-:W-:-:S02]    LEA.HI R10, R7, R14, R7, 0xd
    [B------:R-:W-:Y:S02]    LEA.HI R5, R4, R3, R4, 0xd
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R10, R11, R32, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R4, R5, R0, R13, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R14, -0x56ac0232, R7
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R11, R11, 0xa, R11
    [B------:R-:W-:-:S02]    IADD3 R3, PT, PT, R3, R4, RZ
    [B------:R-:W-:Y:S02]    LEA.HI R7, R7, R8, R7, 0xe
    [B------:R-:W-:-:S02]    SHF.L.W.U32.HI R4, R0, 0xa, R0
    [B------:R-:W-:-:S02]    LEA.HI R0, R3, R6, R3, 0x6
    [B------:R-:W-:-:S02]    LOP3.LUT R7, R7, R10, R11, 0x2d, !PT
    [B------:R-:W-:-:S02]    LOP3.LUT R5, R5, R4, R0, 0x96, !PT
    [B------:R-:W-:-:S02]    IADD3 R7, PT, PT, R8, -0x56ac02b2, R7
    [B------:R-:W-:Y:S02]    IADD3 R6, PT, PT, R6, 0x100, R5
    [B------:R-:W-:-:S02]    LEA.HI R7, R7, R32, R7, 0xb
    [B------:R-:W-:-:S02]    LEA.HI R4, R6, R13, R6, 0x5
    [B------:R-:W-:Y:S04]    SHF.L.W.U32.HI R7, R7, 0xa, R7
    [B------:R-:W-:Y:S04]    LEA.HI R4, R4, R7, R4, 0xa
    [B------:R-:W-:-:S01]    IADD3 R4, PT, PT, R4, 0x10325476, RZ
}
