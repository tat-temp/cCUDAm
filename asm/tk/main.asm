//====================================================================================
// TestKernel -- points-only, hand-written SASS. sm_120.
//
// Mirrors GpuCore.cu TestKernel with the hash layer removed, i.e. the `make NO_HASH=1`
// build, which is the reference this must reproduce exactly.
//
// STAGE 1 (this file): prologue + per-thread I/O only -- an IDENTITY kernel. It reads
// x1/y1/s1/rem for its thread and writes them straight back. That is deliberately the
// first artifact: it exercises every part of the carrier the arithmetic sits on top of
// -- parameter offsets, gid, the threadsTotal bail, 64-bit global addressing, the
// 16 KB local frame -- and a diff against the C++ reference launched with
// batches_per_launch=0 must come out byte-identical. If it does not, no amount of
// correct field arithmetic would show up.
//
// Preconditions, both of which bite silently if violated:
//   * All threads in a warp must run the SAME number of batch iterations. InvMod256
//     "requires all active threads in warp!" (mod_inv.asm:189) and a thread whose rem
//     runs out early leaves the loop while its neighbours are still inside -- exactly
//     H4's straddling warp. Use a power-of-two range so every thread gets an equal
//     batch count.
//   * blockDim.x is assumed to be 256 (see the gid comment).
//
// Constant bank 3 -- the DEVICE-LINKED (-rdc) layout, which is NOT declaration order:
//     c_Jy 0x0    c_Jx 0x20    c_Gy 0x40    c_Gx 0x4040    c_target_words 0x8040
// Confirmed against emitted code: the shipped kernel reads c[0x3][URZ] for c_Jy,
// c[0x3][0x20] for c_Jx and c[0x3][0x8040] for c_target_words. Writing against the
// plain -cubin offsets would read c_Jy where c_target_words lives.
//
// Parameters, c[0x0], sm_120 (PARAM_BASE 0x380 = the sm_89 0x160 + 0x220):
//     0x380 Px          0x388 Py           0x390 start_scalars  0x398 counts256
//     0x3a0 find_result 0x3a8 threadsTotal 0x3b0 batch_size     0x3b4 batches_per_launch
//
// Every idiom below is copied from what ptxas actually emits for THIS kernel rather
// than invented: global access is `LDG.E.64 Rd, desc[UR][Raddr.64+off]` with the
// memory descriptor from c[0x0][0x358] and a full 64-bit address in a register pair,
// built with `IMAD.WIDE.U32 Rd, Rofs, imm, Rbase`. Pointer parameters go into regular
// registers via LDC.64 rather than uniform registers, which also keeps every compare
// in the R,R operand forms the encoder repository actually has -- the UR-first form
// (ISETP_P_P_UR_R_P) is not in it.
//====================================================================================

// Register names must NOT end in a digit: RCAsm resolves `name<N>` to `R<base+N>` by
// stripping trailing digits, so `x1` is ambiguous with `x` index 1 and is rejected
// ("digits at the end of var are not allowed"). Hence PntX/PntY/Scal/Rem, which is
// also what Kernel02 does.
//
// Control codes: [Bnnnnnn:Rn:Wn:Y:Snn] = wait-barrier mask, read barrier, write
// barrier, yield, stall count. In the mask, barrier N occupies SLOT N -- waiting on
// barrier 1 is `B-1----`, not `B1-----`, which is rejected as "Illegal control code
// text". Every one of these is written by hand; there is no scheduler.

KERNEL TestKernel(regcnt=255, \
    ThrID=R2, BlockID=R3, gID=R4, TmpA=R5, TmpB=R6, \
    PntX=R8, PntY=R16, Scal=R24, Rem=R32, \
    AddrX=R40, AddrY=R42, AddrS=R44, AddrC=R46, Thr=R48, \
    Prod=R50, Tmp=R58, \
    uDesc=UR4, uCallM=UR6 )
{
//---- frame ------------------------------------------------------------------------
// The driver hands the thread's local-memory base in c[0x0][0x37c]; the kernel carves
// its own frame out of it. 0x4000 = 16384 = (MAX_BATCH_SIZE/2) * 4 * 8, the size of
// subp[] in GpuCore.cu, and it is backed by real storage only because the injection
// template declares the same frame (asm/tmpl_TestKernel.cu).
    [B------:R-:W0:-:S01]    LDC R1, c[0x0][0x37c]
    [B------:R-:W1:-:S01]    S2R ThrID, SR_TID.X
    [B------:R-:W1:-:S01]    S2R BlockID, SR_CTAID.X
// sm_120 has 63 uniform registers, not 255, and URZ has to be materialised first.
    [B------:R-:W-:-:S01]    UMOV URZ, 0x00
// High word of every call_func return "address". BRXU's target is
// next_PC + UR + imm with the UR pair sign-extended, so the high half is all-ones and
// is set once here; the call site only ever writes the low word. Straight from
// Kernel02's prologue (main.asm: UMOV uCallInv1, 0xFFFFFFFF).
    [B------:R-:W-:-:S01]    UMOV uCallM1, 0xFFFFFFFF
    [B------:R-:W2:-:S01]    LDCU.64 uDesc, c[0x0][0x358]
    [B------:R-:W3:-:S01]    LDC.64 AddrX, c[0x0][0x380]
    [B------:R-:W3:-:S01]    LDC.64 AddrY, c[0x0][0x388]
    [B------:R-:W3:-:S01]    LDC.64 AddrS, c[0x0][0x390]
    [B------:R-:W3:-:S01]    LDC.64 AddrC, c[0x0][0x398]
    [B------:R-:W3:-:S02]    LDC.64 Thr,   c[0x0][0x3a8]

    [B0-----:R-:W-:-:S02]    IADD3 R1, PT, PT, R1, -0x4000, RZ

//---- gid = blockIdx.x * 256 + threadIdx.x -----------------------------------------
// blockDim.x is THREADS_PER_BLOCK = 256 under __launch_bounds__, but GetThreadsPerBlock
// can also return 32 or prop.maxThreadsPerBlock (GpuPuzzle.cpp:283-288), so a kernel
// that must survive those has to read ntid.x from c[0x0][0x0] instead of hardcoding
// 0x100. Stage 1 hardcodes it; the harness launches 256-wide.
    [B-1----:R-:W-:-:S02]    IMAD gID, BlockID, 0x100, ThrID

//---- if (gid >= threadsTotal) return ----------------------------------------------
// threadsTotal is 64-bit and gid is < 2^32 by construction, so: exit iff the high word
// is zero AND gid >= the low word. A non-zero high word means threadsTotal > 2^32 > gid,
// i.e. always in range.
    [B---3--:R-:W-:-:S01]    ISETP.GE.U32.AND P0, PT, gID, Thr0, PT
    [B------:R-:W-:-:S01]    ISETP.EQ.U32.AND P0, PT, Thr1, RZ, P0
    [B------:R-:W-:Y:S04] @P0 EXIT

//---- per-thread addresses: base + gid*32 (four u64 per array) ---------------------
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrY, gID, 0x20, AddrY
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrS, gID, 0x20, AddrS
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 AddrC, gID, 0x20, AddrC

//---- load PntX, PntY, Scal, Rem ---------------------------------------------------
    [B------:R-:W0:-:S01]    LDG.E.64 PntX0, desc[uDesc][AddrX.64]
    [B------:R-:W0:-:S01]    LDG.E.64 PntX2, desc[uDesc][AddrX.64+0x8]
    [B------:R-:W0:-:S01]    LDG.E.64 PntX4, desc[uDesc][AddrX.64+0x10]
    [B------:R-:W0:-:S01]    LDG.E.64 PntX6, desc[uDesc][AddrX.64+0x18]
    [B------:R-:W1:-:S01]    LDG.E.64 PntY0, desc[uDesc][AddrY.64]
    [B------:R-:W1:-:S01]    LDG.E.64 PntY2, desc[uDesc][AddrY.64+0x8]
    [B------:R-:W1:-:S01]    LDG.E.64 PntY4, desc[uDesc][AddrY.64+0x10]
    [B------:R-:W1:-:S01]    LDG.E.64 PntY6, desc[uDesc][AddrY.64+0x18]
    [B------:R-:W2:-:S01]    LDG.E.64 Scal0, desc[uDesc][AddrS.64]
    [B------:R-:W2:-:S01]    LDG.E.64 Scal2, desc[uDesc][AddrS.64+0x8]
    [B------:R-:W2:-:S01]    LDG.E.64 Scal4, desc[uDesc][AddrS.64+0x10]
    [B------:R-:W2:-:S01]    LDG.E.64 Scal6, desc[uDesc][AddrS.64+0x18]
    [B------:R-:W3:-:S01]    LDG.E.64 Rem0, desc[uDesc][AddrC.64]
    [B------:R-:W3:-:S01]    LDG.E.64 Rem2, desc[uDesc][AddrC.64+0x8]
    [B------:R-:W3:-:S01]    LDG.E.64 Rem4, desc[uDesc][AddrC.64+0x10]
    [B------:R-:W3:-:S02]    LDG.E.64 Rem6, desc[uDesc][AddrC.64+0x18]

//---- if (rem == 0) return ---------------------------------------------------------
    [B---3--:R-:W-:-:S01]    LOP3.LUT TmpA, Rem0, Rem2, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01]    LOP3.LUT TmpB, Rem4, Rem6, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01]    LOP3.LUT TmpA, TmpA, Rem1, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01]    LOP3.LUT TmpB, TmpB, Rem3, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01]    LOP3.LUT TmpA, TmpA, Rem5, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01]    LOP3.LUT TmpB, TmpB, Rem7, RZ, 0xfc, !PT
    [B------:R-:W-:-:S01]    LOP3.LUT TmpA, TmpA, TmpB, RZ, 0xfc, !PT
    [B------:R-:W-:Y:S04]    ISETP.EQ.U32.AND P0, PT, TmpA, RZ, PT
    [B------:R-:W-:-:S04] @P0 EXIT

//====================================================================================
// STAGE 1b -- prove the last two pieces of the carrier with ONE real field operation.
//
// Prod = MulMod256(PntX, PntY), through a real out-of-line CALL rather than an inline
// expansion, then round-tripped through the local frame and written to Px. Py, Scal and
// Rem stay identity. Checkable directly: the host computes MulModP(x, y) over the same
// inputs, so a wrong carry chain, a wrong register binding or a bad frame all surface
// as a mismatch rather than as something subtle three stages later.
//
// What this exercises that stage 1 does not:
//   * call_func -- the whole reason the hash layer can be LIFTED instead of rewritten.
//     The caller loads the return address into a uniform pair and the callee ends with
//     the Ret= string; RCAsm appends the body after the kernel and patches the label
//     index and the byte offset (16 per instruction) into the UMOV below.
//   * the 16 KB local frame, via an STL/LDL round trip. If the template's declared
//     frame were wrong this writes into memory the driver never reserved.
//
// NOTE the C8 caveat: MulMod256 is arithmetically correct but NON-CANONICAL -- measured
// on hardware, it returns p+1 where 1 is correct. The host side of this check must
// compare against EcInt::MulModP, which shares the convention, or against Python
// (a*b) % P with the same allowance. Do not "fix" it here.
// The regions below are delimited so variants.py can cut them out and build a bisect
// ladder -- identity / +local memory / +call / both. A fault that only appears in one
// variant names its own cause; guessing at an ILLEGAL_INSTRUCTION from the disassembly
// does not.
//@@CALL_BEGIN
    [B0-----:R-:W-:-:S01]    NOP
    [B-1----:R-:W-:-:S02]    NOP
    [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointA
call_func MulMod256(RFirst=PntX, RSecond=PntY, Ro=Prod, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointA
//@@CALL_END

// Local-frame round trip. R1 is the frame pointer set up above.
//@@LOCAL_BEGIN
    [B------:R-:W-:-:S02]    STL.128 [R1], Prod0
    [B------:R-:W-:-:S02]    STL.128 [R1+0x10], Prod4
    [B------:R-:W0:-:S01]    LDL.128 Prod0, [R1]
    [B------:R-:W0:-:S02]    LDL.128 Prod4, [R1+0x10]
    [B0-----:R-:W-:-:S02]    NOP
//@@LOCAL_END

//====================================================================================
// STAGE 2 GOES HERE: the batch loop.
//   suffix products -> STL subp[]      (SubMod256, MulMod256)
//   one inversion                      (call_func InvMod256)
//   the +/- walk    -> LDL subp[]      (SubMod256, MulMod256, SqrAddMod256,
//                                       SubMod256_3, NegMod256)
//   the point jump
//   Scal += B ; Rem -= B
// Stage 1 falls straight through to the write-back, which makes it an identity kernel.
//====================================================================================

//---- write back -------------------------------------------------------------------
// Px carries the MulMod256 result (stage 1b); the other three are identity. In the
// no-call variants Prod is never written, so those store PntX instead and stay a pure
// identity kernel.
//@@STOREPROD_BEGIN
    [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], Prod0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], Prod2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], Prod4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], Prod6
//@@STOREPROD_END
//@@STOREPNTX_BEGIN
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], PntX0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], PntX2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], PntX4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], PntX6
//@@STOREPNTX_END
    [B-1----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], PntY0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], PntY2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], PntY4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], PntY6
    [B--2---:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64], Scal0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x8], Scal2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x10], Scal4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x18], Scal6
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrC.64], Rem0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrC.64+0x8], Rem2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrC.64+0x10], Rem4
    [B------:R-:W-:-:S05]    STG.E.64 desc[uDesc][AddrC.64+0x18], Rem6

    [B------:R-:W-:Y:S05]    EXIT
}
