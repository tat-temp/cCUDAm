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
//
// THE STALL COUNT IS A CORRECTNESS FIELD, not a performance knob. IADD3, IMAD, ISETP,
// LOP3, MOV, SEL and SHF are FIXED LATENCY: they set no scoreboard barrier, so `Snn` is
// the only thing that makes the next instruction see their result. Too few cycles and it
// reads the previous value -- silently, and with no diagnostic anywhere in the build.
// When the stale value is an address, that is CUDA_ERROR_ILLEGAL_ADDRESS; when it is not,
// it is a wrong answer.
//
// What matters is the CUMULATIVE distance from producer to consumer, not the one stall on
// the producer: issue is in order, so the stall count is exactly how many cycles pass
// before the next instruction issues, and the running sum is the gap. Measured minimum
// that ptxas itself ever leaves, per opcode, over the 9,984 control-coded instructions of
// asm/GpuCore_sm120.asm plus the two compiled kernels in rcasm_test/abtest:
//
//     IMAD 3   IADD3 4   LOP3 4   SEL 4   SHF 4   LEA 4   PRMT 4   MOV 4   ISETP->P 5
//
// So: **four cycles before a result is read, five for a predicate out of ISETP, three for
// IMAD.** asm/tk/stall_check.py enforces it against the built cubin. Spreading a chain out
// counts -- two instructions apart at S02 each is four cycles and is fine -- which is what
// the interleaved rem==0 test below relies on, though at S01 it only reached two and was
// wrong for that reason.
//
// A BRANCH IS DIFFERENT, AND IT IS THE BIGGEST NUMBER HERE: a guarded branch reads its
// predicate far earlier in the pipeline than an ALU instruction reads an operand, and
// wants **THIRTEEN** cycles. Measured, and about as unambiguous as this project gets: over
// 41 predicate-producer -> guarded-branch pairs in the shipped kernel, ptxas never once
// goes below 13, whatever the producer (ISETP, LOP3, R2UR and VOTE all bottom out at
// exactly 13). The same ISETP feeding another ISETP needs 5, which is what makes this easy
// to get wrong -- the loop below was written at S05 and ran a SINGLE iteration, because
// the back-edge tested a P0 that MulMod256 had left behind rather than the loop counter.
//
// **A stall that large needs the YIELD bit set.** `[B------:R-:W-:-:S13]` assembles without
// complaint and produces an instruction cuobjdump cannot decode at all ("undefined value
// 0x1d for table TABLES_opex_8"); `[B------:R-:W-:Y:S13]` is fine. ptxas sets Y on every
// one of its own S13 instructions. This is the one failure in this file that is loud
// rather than silent, and only because the disassembler happens to reject it -- nothing in
// the assembler path objects.
//
// Stage 2a's ladder was written at S01 and died with ILLEGAL_ADDRESS on its first store:
// `IMAD COfs, Half, 0x10, RZ` followed immediately by a read of COfs, which at that point
// had never been written at all.

// BARRIER HYGIENE: ONE GROUP PER BARRIER, AND DRAIN IT BEFORE REUSING IT.
// A write barrier is not a flag, it is a counter -- every instruction naming it increments
// it and the wait blocks until it reaches zero. That makes it tempting to pile unrelated
// loads onto one barrier and wait once. Do not: stage 2a did exactly that and read stale
// registers. The prologue arms barrier 0 with four PntX loads and, in this variant, never
// drains them (the drain lived in stage 1b's write-back, which is commented out here), so
// the ladder's four constant loads made EIGHT operations outstanding on barrier 0. The
// single wait then let execution through with the last two still in flight, and MulB4..7
// were read stale -- silently, since the constant read itself was perfectly correct.
//
// The give-away in the failing run was that the low 128 bits of the result were exact and
// the high 128 bits were foreign to the whole 32 KB constant image: the two loads that
// landed were the two issued FIRST, i.e. the ones with the most natural latency behind
// them once the wait stopped blocking.
//
// A STORE NEEDS A READ BARRIER IF ITS DATA REGISTERS ARE REWRITTEN LATER. This is the other
// half of the same rule and it is the one that is easy to miss, because a store looks like
// it has no result to wait for. It does not read its data at issue: the LSU reads it later,
// and `R-` means nothing in the control code says when. Rewrite the register first and the
// store writes the NEW value. `R3` on the store arms read barrier 3; a wait on 3 before the
// overwrite is what makes the read have happened.
//
// This is what made the ladder wrong after the loop was fixed. Px was EXACT -- the
// accumulator never leaves registers -- while Py, the one value round-tripped through the
// frame, came back as subp[0].hi ++ subp[511].lo. subp[0] is the accumulator's value 511
// iterations LATER: the high half of a store issued before the loop read its data after the
// loop had finished. The low half read on time. Nothing said either had to.
//
// ptxas puts a read barrier on every one of the four STLs in its own suffix-product loop and
// waits it at the head of the next iteration; across both compiled kernels there is not one
// store whose source is rewritten later and which carries no read barrier.
//
// The ceiling is measured, not guessed: over the compiled kernels ptxas never leaves more
// than SIX outstanding on one barrier, and the prologue's groups of five are correct on
// hardware, so the limit is six or seven. It is not about spacing -- ptxas puts a wait as
// little as two cycles after the arm it covers. Six barriers exist (0..5) and this kernel
// uses five; there is no reason to economise.
// asm/tk/barrier_check.py enforces it against the built cubin.

// REGISTER ALIGNMENT IS A HARDWARE RULE, not a style preference, and getting it wrong
// costs a CUDA_ERROR_ILLEGAL_INSTRUCTION at run time with nothing wrong in the listing:
//   * a .64 access needs its register operand EVEN;
//   * a .128 access needs it a MULTIPLE OF 4.
// The assembler encodes whatever number it is given -- there is no check anywhere in the
// path -- so the first sign of a violation is the launch dying. Every 256-bit value here
// is therefore 4-aligned, which is also why Kernel02 places jPntX at R28, TmpTmp at R84
// and rx at R84: every one of its .128 bases is a multiple of 4. R50/R51 are left unused
// to keep Prod aligned after the 2-register Thr; that is the price and it is worth it.
// CALL ABI. Every field routine is reached through a fixed set of registers -- MulA and
// MulB in, MulR out, MulT scratch -- and callers copy operands in and results out. That
// is not bureaucracy: `call_func` emits ONE shared body per (function, binding) pair, so
// a distinct binding at every call site would give ~14 copies of MulMod256's 112
// instructions. A fixed binding costs at most 8 MOVs per site and keeps one body.
//
// **Ro MUST NOT alias RFirst or RSecond for MulMod256.** Its first instruction writes Ro0
// and its second writes Ro2, while RFirst2 is not read until the fifth -- so the C++ this
// mirrors, `mul_mod(acc, acc, tmp)`, CANNOT be transcribed directly even though in-place
// aliasing is safe in the C++ version. Hence MulR separate from MulA/MulB, and the copy
// back into MulA after each multiply.
//
// SubMod256 *is* alias-safe and is used that way (Ro=RFirst) to save a copy: it is a
// straight elementwise pass in increasing index order, so instruction k writes Ro_k in
// the same instruction that reads RFirst_k and RSecond_k, and nothing later reads either
// input again -- the second half touches only Ro.
KERNEL TestKernel(regcnt=255, \
    ThrID=R2, BlockID=R3, gID=R4, TmpA=R5, TmpB=R6, Idx=R7, \
    PntX=R8, PntY=R16, Scal=R24, Rem=R32, \
    AddrX=R40, AddrY=R42, AddrS=R44, AddrC=R46, Thr=R48, \
    COfs=R50, SAdr=R51, \
    MulA=R52, MulB=R60, MulR=R68, Prod=R68, Half=R76, \
    Tmp=R84, \
    Inv=R104, InvO=R116, InvT=R128, \
    uDesc=UR4, uCallM=UR6, uCallI=UR8, uInvT=UR10 )
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
//
// ONE PER RETURN-ADDRESS PAIR. A second pair is not a second copy of the same thing that
// can be skipped -- uCallI got its low word patched by call_func and no high word at all,
// and stage 2b died at launch with CUDA_ERROR_INVALID_PC. Nothing in the assembler,
// disassembler or any of the three checkers had anything to say about it: the branch
// itself is correct and its target register is simply uninitialised. asm/tk/pc_check.py
// exists for exactly this.
    [B------:R-:W-:-:S01]    UMOV uCallM1, 0xFFFFFFFF
    [B------:R-:W-:-:S01]    UMOV uCallI1, 0xFFFFFFFF
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
    [B-1----:R-:W-:-:S05]    IMAD gID, BlockID, 0x100, ThrID

//---- if (gid >= threadsTotal) return ----------------------------------------------
// threadsTotal is 64-bit and gid is < 2^32 by construction, so: exit iff the high word
// is zero AND gid >= the low word. A non-zero high word means threadsTotal > 2^32 > gid,
// i.e. always in range.
// S13 on the ISETP, not S05: a branch reads its guard predicate far earlier in the
// pipeline than an ALU instruction reads an operand. See the note on predicates at the
// top of this file -- five cycles is right for an ISETP feeding another ISETP and badly
// wrong for one feeding a branch.
    [B---3--:R-:W-:-:S05]    ISETP.GE.U32.AND P0, PT, gID, Thr0, PT
    [B------:R-:W-:Y:S13]    ISETP.EQ.U32.AND P0, PT, Thr1, RZ, P0
    [B------:R-:W-:Y:S05] @P0 EXIT

//---- per-thread addresses: base + gid*32 (four u64 per array) ---------------------
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrY, gID, 0x20, AddrY
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrS, gID, 0x20, AddrS
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 AddrC, gID, 0x20, AddrC

//---- load PntX, PntY, Scal, Rem ---------------------------------------------------
// One barrier per group of four, and the B2 wait below is not decoration: uDesc is loaded
// on barrier 2 and read HERE, so without it this reads the descriptor before the LDCU has
// landed. It happens to work -- the LDCU is fifteen instructions back -- which is exactly
// what makes it worth writing down rather than leaving to luck. Barrier 2 is re-armed by
// the Scal loads immediately below and drained again at the Scal write-back.
    [B--2---:R-:W0:-:S01]    LDG.E.64 PntX0, desc[uDesc][AddrX.64]
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
// S03, not S01. Interleaving the two chains buys each dependency TWO cycles instead of
// one, which is the right idea and not enough: a LOP3 needs FOUR before its result can be
// read, measured over ptxas's own output. At S03 each chain gets 3+3=6. This was wrong in
// every variant from stage 1 onward and no test could see it -- the failure mode is a
// garbage TmpA, which would have to come out exactly zero to make a thread wrongly exit.
// Found by stall_check.py only once it started summing across instructions.
    [B---3--:R-:W-:-:S03]    LOP3.LUT TmpA, Rem0, Rem2, RZ, 0xfc, !PT
    [B------:R-:W-:-:S03]    LOP3.LUT TmpB, Rem4, Rem6, RZ, 0xfc, !PT
    [B------:R-:W-:-:S03]    LOP3.LUT TmpA, TmpA, Rem1, RZ, 0xfc, !PT
    [B------:R-:W-:-:S03]    LOP3.LUT TmpB, TmpB, Rem3, RZ, 0xfc, !PT
    [B------:R-:W-:-:S03]    LOP3.LUT TmpA, TmpA, Rem5, RZ, 0xfc, !PT
    [B------:R-:W-:-:S05]    LOP3.LUT TmpB, TmpB, Rem7, RZ, 0xfc, !PT
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, TmpA, TmpB, RZ, 0xfc, !PT
    [B------:R-:W-:Y:S13]    ISETP.EQ.U32.AND P0, PT, TmpA, RZ, PT
    [B------:R-:W-:-:S05] @P0 EXIT

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
// STAGE 1b IS COMMENTED OUT, and that is the convention for this file: **main.asm is
// always the CURRENT stage, never a union of stages.** variants.py reconstructs the
// earlier rungs by uncommenting these regions and cutting the later ones. Leaving both
// active would not be a superset kernel, it would be a meaningless one -- stage 2a's
// ladder writes subp[0] to [R1], the exact slot the round trip below uses, and its
// MulMod256 calls overwrite MulR, which is where Prod lives. It would still assemble,
// still load, and still produce numbers.
//@@CALL_BEGIN
//  [B0-----:R-:W-:-:S01]    NOP
//  [B-1----:R-:W-:-:S02]    NOP
//  [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointA
//call_func MulMod256(RFirst=PntX, RSecond=PntY, Ro=Prod, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointA
//@@CALL_END

// Local-frame round trip. R1 is the frame pointer set up above. Prod MUST be 4-aligned
// for these four -- see the note on the KERNEL line. This block is what found that rule:
// with Prod at R50 the kernel loaded, reported its 16 KB frame, launched, and died with
// CUDA_ERROR_ILLEGAL_INSTRUCTION, while the identical stream minus these four
// instructions ran clean.
// R3 on the two stores is the read barrier, and it is not optional here even though this
// variant has always passed: the LDLs rewrite the very registers the STLs are storing, so
// without it the load can land before the store has read them and the round trip returns
// its own destination. It works today by latency alone. See the store-read-barrier note at
// the top of this file -- the same omission in the stage-2a ladder produced a wrong answer.
//@@LOCAL_BEGIN
//  [B------:R3:W-:-:S02]    STL.128 [R1], Prod0
//  [B------:R3:W-:-:S02]    STL.128 [R1+0x10], Prod4
//  [B---3--:R-:W0:-:S01]    LDL.128 Prod0, [R1]
//  [B------:R-:W0:-:S02]    LDL.128 Prod4, [R1+0x10]
//  [B0-----:R-:W-:-:S02]    NOP
//@@LOCAL_END

//====================================================================================
// STAGE 2a -- the suffix-product ladder. Mirrors GpuCore.cu:224-233:
//
//     sub_mod(acc, c_Jx, x1);
//     subp[half-1] = acc;
//     for (i = half-2; i >= 0; --i) {
//         sub_mod(tmp, &c_Gx[(i+1)*4], x1);
//         mul_mod(acc, acc, tmp);
//         subp[i] = acc;
//     }
//
// Three mechanisms appear here for the first time, and each is the kind of thing that
// fails silently rather than loudly:
//   * a real loop -- backward `BRA.U` to a label, Kernel02's own idiom (main.asm:92);
//   * a dynamically indexed constant load, `LDC.64 Rd, c[0x3][Rofs+imm]`, which is what
//     ptxas emits for exactly this access (GpuCore_sm120.asm:1534) -- warp-uniform, so
//     it broadcasts and does not serialise;
//   * STL at a COMPUTED address rather than a constant offset off R1.
//
// The loop variable is the BYTE OFFSET, not the index. That kills three instructions per
// iteration -- no shift to get half from B, and no IMAD to turn an index back into an
// offset -- and it also keeps the exit test on an UNSIGNED compare against RZ. Writing
// the C++ loop literally as `i >= 0` would need a signed `ISETP.GE`, one more instruction
// form to be unsure of in the encoder repository, where `ISETP.NE.U32` is already used
// above. COfs counts down j = half-1 .. 1 in units of 32 bytes; at j the constant index
// is j and the store index is j-1, which is exactly the C++ (i+1) and i.
//@@SUFP_BEGIN
//---- acc = SubMod256(c_Jx, x1) ; subp[half-1] = acc ---------------------------------
// c_Jx is at c[0x3][0x20] in the -rdc layout. Loaded into MulB and reduced in place,
// straight into MulA, which is where the accumulator lives for the rest of the ladder.
// Barriers 4 and 5, NOT 0 and 1. Barrier 0 already carries the four PntX loads from the
// prologue and is not drained until this point, so arming it four more times here put
// EIGHT operations on one barrier -- and the wait below then cleared with the last two
// still in flight, so MulB4..MulB7 were read stale. That is what made the ladder wrong:
// see the note on barrier hygiene at the top of this file. The wait covers both groups,
// because the call reads MulB (barrier 4) and PntX (barrier 0).
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x20]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x28]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x30]
    [B------:R-:W4:-:S01]    LDC.64 MulB6, c[0x3][0x38]
    [B------:R-:W5:-:S02]    LDC Half, c[0x0][0x3b0]
    [B0---4-:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_SubMod256) //RCASM:CallPointA
call_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulA, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointA

// COfs = half*32 = B*16 -- the multiply by 16 is where `half = B >> 1` gets absorbed, so
// no shift instruction is needed. SAdr = R1 + COfs, putting subp[half-1] at [SAdr-0x20].
    [B-----5:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
// R3, and this is the bug that made subp[half-1] wrong while the accumulator was exact. A
// store does not read its data registers at issue -- the LSU reads them later, and with no
// read barrier nothing says when. MulA is rewritten by the copy block inside the loop, and
// the high half of THIS store read its data after the loop had finished: Py came back as
// subp[0].hi ++ subp[511].lo, subp[0] being the accumulator 511 iterations later. Barrier 3
// is free from here on -- the Rem loads that used it are drained by the rem==0 test.
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulA0
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulA4

//---- for (j = half-1; j >= 1; --j) --------------------------------------------------
    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ
    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT
    [B------:R-:W-:Y:S05] @!P0 BRA.U `(.label_sufp_end)

.label_sufp_loop:
// c_Gx is at c[0x3][0x4040]; element j starts at 0x4040 + j*32. The store goes to
// subp[j-1] = R1 + (j-1)*32 = (R1 + j*32) - 0x20.
// The B3 wait is the other half of the store read barrier: it drains the PREVIOUS
// iteration's two STLs before the copy block below rewrites MulA. ptxas puts its own wait
// in exactly this position -- at the loop head, not next to the overwrite.
    [B---3--:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
// MulB = c_Gx[j] - x1, in place (SubMod256 is alias-safe; see the KERNEL note).
// Barrier 4 again, and it is drained on every iteration by the wait below, so the loop
// never accumulates. PntX is already resolved by the pre-loop wait and stays live.
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_SubMod256) //RCASM:CallPointB
call_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointB
// MulR = MulA * MulB. Ro is deliberately NOT MulA -- MulMod256 clobbers Ro while still
// reading its inputs.
    [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointC
call_func MulMod256(RFirst=MulA, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointC
// acc = MulR
    [B------:R-:W-:-:S01]    IMAD MulA0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV MulA1, MulR1
    [B------:R-:W-:-:S01]    IMAD MulA2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV MulA3, MulR3
    [B------:R-:W-:-:S01]    IMAD MulA4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV MulA5, MulR5
    [B------:R-:W-:-:S01]    IMAD MulA6, RZ, RZ, MulR6
    [B------:R-:W-:-:S02]    MOV MulA7, MulR7
// subp[j-1] = acc -- read barrier 3, waited at the loop head above.
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x20], MulA0
    [B------:R3:W-:-:S02]    STL.128 [SAdr+-0x10], MulA4

    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, -0x20, RZ
// This one is why the ladder ran a SINGLE iteration and stopped. At S05 the back-edge
// read a stale P0 -- and MulMod256 clobbers P0..P4 earlier in the same iteration, so the
// stale value was whatever its carry chain happened to leave, not the loop test.
    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, RZ, PT
    [B------:R-:W-:Y:S05] @P0 BRA.U `(.label_sufp_loop)
.label_sufp_end:
//@@SUFP_END

//====================================================================================
// STAGE 2b -- the single modular inversion. Mirrors GpuCore.cu:236-239:
//
//     uint64_t inverse[5];
//     sub_mod((uint64_t*)inverse, &c_Gx[0], x1);
//     mul_mod(inverse, inverse, subp[0]);
//     inv_mod((uint32_t*)inverse);
//
// so inverse = 1 / ((Jx - x1) * prod_{j=0..half-1}(c_Gx[j] - x1)). One inversion per B
// keys is the entire point of the ladder above it.
//
// Three things about InvMod256 that shape the code around it:
//
//   * IT REQUIRES ALL ACTIVE THREADS IN THE WARP (mod_inv.asm:189). It is a data-dependent
//     loop with a warp-collective step, so a thread that took a different path to get here
//     is not merely slow, it is a hang or a wrong answer for the others. This kernel's two
//     early exits are both taken uniformly by construction -- the harness gives every
//     thread the same rem -- and that is a PRECONDITION, not an accident. Making it safe in
//     general is separate work, and it is H4's straddling warp under a different name.
//   * Ri is SPOILED. The 9-register input is destroyed, so `inverse` cannot be built in
//     place the way the C++ writes it; Inv holds the argument, InvO the result.
//   * It costs 70 temporaries plus a uniform. Inv/InvO/InvT put the high-water mark at
//     R197, still inside the 255 this kernel declares, but it is the single largest
//     allocation in the file and it is why the register budget cannot come down until the
//     hash layer's needs are known.
//
// Ri_cnt is 9, not 8: inv_mod works on 288 bits. The 9th word does NOT need zeroing here --
// InvMod256 does it itself (`IMAD val8, RZ, RZ, RZ`, mod_inv.asm:203), exactly as the C++
// inv_mod writes r[8] = 0 as its second statement.
//
// uCallI, not uCallM: InvMod256 takes a uniform temporary of its own, so the return address
// gets a separate pair. Kernel02 does the same at both of its call sites.
//
// C9 CAVEAT, and it is the reason a non-canonical result is expected rather than a bug: the
// tail loop is `while ((int)res[8] > 0) sub_288_P(res)`, which stops the instant word 8 is
// zero and can leave the result anywhere in [0, 2^256) rather than [0, P). The C++ inv_mod
// has the identical defect -- same entry in DEVPLAN -- so the two sides agree and the
// oracle must allow the +P twin.
//@@INV_BEGIN
// d0 = c_Gx[0] - x1, in place into MulB. c_Gx[0] is the base of the table at 0x4040.
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x4058]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_SubMod256) //RCASM:CallPointD
call_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointD

// subp[0] out of the frame rather than out of MulA, which still holds the same value. The
// C++ reads subp[0], and taking it from memory is the only thing that ever reads the
// BOTTOM of subp[] -- every check so far has read slot half-1 at the top.
//
// The B3 wait is load-bearing and barrier_check.py caught it the first time this block was
// built: THIS LDL is what rewrites MulA, and the loop's last pair of STLs is still holding
// those registers on the read barrier. Without the wait the ladder's subp[0] would be
// overwritten by the value being loaded out of subp[0] -- the store racing its own reader.
// Stage 2a's own drain sits further down in the write-back, which is too late.
    [B---3--:R-:W0:-:S01]    LDL.128 MulA0, [R1]
    [B------:R-:W0:-:S02]    LDL.128 MulA4, [R1+0x10]

// MulR = d0 * subp[0]
    [B0-----:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointE
call_func MulMod256(RFirst=MulB, RSecond=MulA, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointE

// Inv = MulR. Alternating IMAD/MOV is Kernel02's copy idiom -- two different pipes, so the
// pairs dual-issue instead of queueing behind one another.
    [B------:R-:W-:-:S01]    IMAD Inv0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV Inv1, MulR1
    [B------:R-:W-:-:S01]    IMAD Inv2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV Inv3, MulR3
    [B------:R-:W-:-:S01]    IMAD Inv4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV Inv5, MulR5
    [B------:R-:W-:-:S01]    IMAD Inv6, RZ, RZ, MulR6
    [B------:R-:W-:-:S05]    MOV Inv7, MulR7

    [B------:R-:W-:-:S01]    UMOV uCallI0, `(.relN_end_InvMod256) //RCASM:CallPointF
call_func InvMod256(Ri=Inv, Ro=InvO, Rt=InvT, URt=uInvT, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallI, 0x00") //RCASM:CallPointF
//@@INV_END

//====================================================================================
// STAGE 2c-2d GO HERE:
//   the +/- walk    -> LDL subp[]      (SubMod256, MulMod256, SqrAddMod256,
//                                       SubMod256_3, NegMod256)
//   the point jump
//   Scal += B ; Rem -= B  and the outer batch loop
//====================================================================================

//---- write back -------------------------------------------------------------------
// Px carries the MulMod256 result (stage 1b); the other three are identity. In the
// no-call variants Prod is never written, so those store PntX instead and stay a pure
// identity kernel.
//@@STOREPROD_BEGIN
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], Prod0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], Prod2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], Prod4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], Prod6
//@@STOREPROD_END
//@@STOREPNTX_BEGIN
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], PntX0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], PntX2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], PntX4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], PntX6
//@@STOREPNTX_END
// Stage 2a's write-back: Px = acc (the whole suffix product) and Py = subp[half-1] read
// back out of the frame. Py is deliberately NOT acc -- it is the value stored BEFORE the
// loop, at the highest address in subp[], so reading it back after 511 stores is what
// says the ladder wrote where it meant to. If STL had been walking off the end of the
// frame, acc could still come out right while this came out wrong.
// B3 as well as B0 on the first store: the loop's last pair of STLs is still outstanding on
// the read barrier when the loop exits, and draining it here keeps "one group per barrier,
// drained before reuse" true on every path out rather than only inside the loop.
//
// A REGION BODY HOLDS INSTRUCTION LINES ONLY. variants.py uncomments a region by stripping
// the leading `//` from every line between the markers, so a prose line inside one comes
// back as garbage the assembler is asked to parse. That is why this paragraph sits above
// the marker and why the two blocks below are duplicated rather than sharing their tail.
//@@STOREACC_BEGIN
//  [B0--3--:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], MulA0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], MulA2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], MulA4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], MulA6
//  [B------:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
//  [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
//  [B------:R-:W0:-:S01]    LDL.128 MulB0, [SAdr+-0x20]
//  [B------:R-:W0:-:S02]    LDL.128 MulB4, [SAdr+-0x10]
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], MulB0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], MulB2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], MulB4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], MulB6
//@@STOREACC_END
// Stage 2b's write-back: Px = the inverse, Py = subp[half-1] exactly as above. Keeping Py
// unchanged across the two stages is deliberate -- it means a stage-2b failure that is
// really a stage-2a regression shows up on Py rather than being blamed on InvMod256.
//@@STOREINV_BEGIN
    [B0--3--:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], InvO0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], InvO2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], InvO4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], InvO6
    [B------:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W0:-:S01]    LDL.128 MulB0, [SAdr+-0x20]
    [B------:R-:W0:-:S02]    LDL.128 MulB4, [SAdr+-0x10]
    [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], MulB0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], MulB2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], MulB4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], MulB6
//@@STOREINV_END
//@@STOREPNTY_BEGIN
//  [B-1----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], PntY0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], PntY2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], PntY4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], PntY6
//@@STOREPNTY_END
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
