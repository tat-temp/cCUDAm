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
// ("digits at the end of var are not allowed"). Hence PntX/PntY/Scal, which is
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
// A CARRY-OUT PREDICATE IS FINE AT TWO CYCLES -- EXCEPT ACROSS A MOV, WHERE IT WAS NOT.
// Stage 2c-ii's tail point came back wrong by exactly 2^224 + 0x7A1 and widening every stall
// in SubMod256_3 to S06 made the rung EXACT on all 256 threads, so a timing fix is confirmed.
// The tempting generalisation -- "two cycles is below the floor for a carry-in" -- is FALSE,
// and the cubin says so directly. Over the emitted bodies:
//
//   MulMod256, SqrMod256 and InvMod256 contain 126 carry-out -> carry-in pairs at TWO
//   cycles, and all three are correct on hardware. In every one of those 126 the intervening
//   instruction is IADD3, IMAD or SHF.
//
//   SubMod256_3 held the only two-cycle pair in the kernel with a **MOV** between producer
//   and consumer. It is also the only routine that computed a wrong answer, and a stale
//   read at exactly that pair reproduces the 2^224 half of the delta.
//
// One instance is not a rule, and the widening changed fifteen lines rather than that one, so
// what is established is the fix and not the mechanism. Treat "same-pipe forwarding is faster
// than cross-pipe, and MOV is the odd one out" as the surviving candidate, not as fact.
//
// The method matters more than either number. A first pass took one GLOBAL minimum per
// routine, found nothing tighter than what already runs, and read as an acquittal. That is
// the wrong comparison twice over: a predicate consumed as a branch guard (13), as a SEL
// selector, and as a carry-in are three different consumers with three different floors, and
// even within one consumer the surrounding instructions are part of the shape. Compare like
// against like, and when the like-for-like comparison exonerates the suspect, say so.
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
// REGISTER ALLOCATION -- read this before moving anything.
//
// RCAsm has no allocator: this table IS the allocation, and a name owns its span for the
// whole kernel whether it is live there or not. The first version of it spent 226 registers
// (R2..R225) on a peak live set of 185, declared regcnt=255, and therefore got ONE resident
// block per SM where the compiled kernel gets two -- 128 * 256 = 32768 is exactly half the
// 65536-register file, so 128 is a cliff and 129 costs a whole block. Measured, that block is
// worth having: the points-only half of the program scales 10.4% better than linear when
// occupancy doubles, against the full kernel's 1.7%, so the half this kernel replaces is
// exactly the half that wants the second block.
//
// The layout is now three OVERLAYS over one span, mirroring the lexical scopes of
// GpuCore.cu:221-407 -- which is not a coincidence and not a guess: those scopes are a
// live-range partition ptxas already proved fits in 126 registers, on this same algorithm,
// with inv_mod fully inlined. Names deliberately collide, exactly as MulR/Prod always have.
//
//   persistent  R0..R33   live entry to exit
//   overlay A   R34..R45  prologue and epilogue ONLY -- tid/ctaid, the four base pointers
//                         and threadsTotal. The pointers are REBUILT before the write-back
//                         rather than held across the ladder, which is what frees this span.
//   overlay B   R34..R126 the inversion: Inv (9, SPOILED), InvO (9), InvT (73)
//   overlay C   R36..R125 suffix products, walk and jump: eight 256-bit values plus ONE
//                         26-register scratch block shared by MulMod256 (Rt 20),
//                         SqrMod256 (Rt 26) and SubMod256_3 (Rt 2). They never nest, so
//                         Tmp/SqrT/Pt3T are three names for one block and every existing
//                         `Rt=` binding keeps working unchanged.
//
// B tops at R126 and C at R125, so regcnt = 127 -- one under the cliff, which is the whole
// point and leaves no room to be careless.
//
// TWO NUMBERS IN THAT TABLE ARE NOT THE ONES mod_inv.asm ADVERTISES, and both were found by
// measuring the emitted cubin rather than by reading the header:
//
//   * InvMod256's Ro is NINE registers, not eight. It is a 288-bit intermediate (Ro8 is the
//     overflow word the `while ((int)res[8] > 0)` normalisation loop tests), and it is only
//     the low eight that are the answer. The first version of this table gave InvO eight and
//     put InvT immediately after, which landed Ro8 exactly on Rt0. That build assembled, both
//     alignment and barrier checks passed, and it would have corrupted the inversion.
//   * InvMod256's Rt is 73, not the "Rt_cnt = 70" in its own header. `tvars=Rt64` is handed
//     to inlined helpers that need nine, so the body reaches Rt72. Invisible at regcnt=255,
//     fatal at 127.
//
// Ro CANNOT alias Ri, which would have saved nine more: `_mul_P_by_32_add_shift(Ro=Ro0,...)`
// writes the output while `val` is still read by later `_mul_256_by_i32(Rval=val,...)` calls.
// Checked in the source, not assumed from the in-place C++ call.
//
// ALIGNMENT IS PART OF THE ALLOCATION, not a detail: `.64` needs an even base, `.128` a
// multiple of 4. There is no `.128` anywhere in mod_inv/mod_mul/mod_sub, so the vendored
// blocks need only be even -- which is what lets InvT start at R54 and fit. In THIS file the
// `.128` bases are MulA/MulB/MulR (the subp[] round trip), so those three are on multiples
// of 4. Moving one by two registers produces a cubin that loads, disassembles cleanly and
// returns wrong numbers.
//
// Acc is the bisect accumulator and sits ABOVE regcnt on purpose. It is referenced only
// inside gated regions (ACCINIT/PACC/PACCM/PACCT/WACC/WACCT), so the production kernel never
// names R128..R135 and declaring them costs nothing; variants.py raises regcnt to 136 for the
// variants that switch those regions on. Keeping it inside 127 is not possible -- persistent
// 34 + Inv 9 + InvO 9 + InvT 73 + Acc 8 already exceeds it -- and deleting the instrument to
// hit a number would be trading a check for a benchmark.
KERNEL TestKernel(regcnt=127, \
    BDone=R0, gID=R2, TmpA=R3, TmpB=R4, Idx=R5, Half=R6, SAdr=R7, \
    PntX=R8, PntY=R16, Scal=R24, \
    COfs=R32, BpL=R33, \
    ThrID=R34, BlockID=R35, AddrX=R36, AddrY=R38, AddrS=R40, AddrC=R42, Thr=R44, \
    Inv=R34, InvO=R44, InvT=R54, \
    Rinv=R36, Dxi=R44, MulB=R52, MulA=R60, MulR=R68, Prod=R68, \
    Lam=R76, Sqr=R84, PxN=R92, \
    Tmp=R100, SqrT=R100, Pt3T=R100, \
    Acc=R128, \
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
    [B------:R-:W-:-:S02]    IMAD.WIDE.U32 AddrS, gID, 0x20, AddrS
// AddrC is deliberately NOT built here. counts256 is no longer read or written by this
// kernel (see the batch loop below), and AddrX/AddrY/AddrS are rebuilt from scratch at the
// write-back rather than held -- which is what lets overlay B put InvT's 70 temporaries in
// this span. Rebuilding costs one LDC.64 and one IMAD.WIDE.U32 each, once per kernel.

//---- load PntX, PntY, Scal --------------------------------------------------------
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

//---- rem is gone, and the `if (rem == 0) return` with it --------------------------
// GpuCore.cu:162 bails on a zero count and :200 makes `ge256_u64(rem, B)` half the loop
// guard. Both are removed here, and the reason is not the instruction count: the whole of
// rem cost about 16 instructions per batch against a batch's ~76,000, i.e. 0.02%, which is
// nothing. Two other things make it worth doing.
//
// IT IS WHAT PAYS FOR 126 REGISTERS. rem is 8 registers held live from the prologue to the
// write-back, straight through the inversion -- and persistent + Inv + InvO + InvT lands at
// 135 with it and 127 without. There is no version of this allocation that keeps rem and
// reaches two blocks per SM.
//
// AND IT REMOVES THE RAGGED-WARP EXIT BY CONSTRUCTION. A rem-driven guard lets threads leave
// the batch loop at DIFFERENT iterations -- that is exactly H4's straddling warp, and it is
// the one thing that can silently break InvMod256's "requires all active threads in warp!"
// precondition (mod_inv.asm:189), which this file has declared in its header since stage 1
// and has never had enforced. With BDone < BpL as the only guard, every thread in the launch
// runs the same number of batches because the count is a kernel PARAMETER, not per-thread
// state. The precondition stops being a comment and becomes the control flow.
//
// THE HOST NOW OWNS THE TAIL. GpuPuzzle.cpp must size batches_per_launch so no thread is
// asked for more batches than it has left, including on the final launch. That is a host
// change, it is not done yet, and until it is this kernel is correct only under the
// harness's uniform seeding. Recorded in DEVPLAN rather than left to be discovered.

//====================================================================================
// STAGE 2d, part 1 -- the head of the outer batch loop, GpuCore.cu:199-202.
//
//     while (true) {
//         live = (batches_done < batches_per_launch) && ge256_u64(rem, B);
//         if (!live) break;
//
// PRECONDITION, and it is the same one the plan states for InvMod256: every active thread
// in a warp must take the same number of batches. InvMod256 requires all active threads in
// the warp (mod_inv.asm:189), and a thread that leaves this loop early leaves the ones still
// inside it running an inversion on a partial warp -- which is H4's straddling warp wearing
// different clothes. The harness gives all 256 threads the same rem and the same
// batches_per_launch, so the two branches below are warp-uniform in every configuration this
// kernel is currently run in. Making it safe for a ragged warp is separate work and it needs
// a ballot, exactly as GpuCore.cu:201 has one.
//
// TWO BRANCHES, NOT ONE OR'd PREDICATE. `ISETP...OR` would fold them, and ptxas emits that
// form, but nothing in this project has ever assembled one: the encoder repository is taught
// from samples and an untaught form fails at build time at best. Every ISETP here is a
// `.AND` because every ISETP already in this file is.
//
// B is read into Half rather than being recomputed -- the name is a historical dent: the
// register holds batch_size, and `half` only ever appears as `Half*0x10 == half*32`. It is
// loaded HERE as well as inside the ladder because the ladder has to keep its own copy for
// the rungs below this one, which cut this region entirely. One redundant constant load per
// batch against 1023 points is not worth a third register.
//@@LOOPTOP_BEGIN
    [B------:R-:W5:-:S01]    LDC BpL, c[0x0][0x3b4]
    [B------:R-:W5:-:S02]    LDC Half, c[0x0][0x3b0]
    [B-----5:R-:W-:-:S05]    IMAD BDone, RZ, RZ, RZ
.label_batch_loop:
// ONE guard, where there used to be two. The `rem >= B` half is gone with rem itself -- see
// the note in the prologue -- leaving the batch counter, which is warp-uniform by
// construction because BpL is a kernel parameter. Every lane of the warp takes this branch
// together, which is the property InvMod256 needs and the property the rem-driven guard
// could not offer.
//
// S13 and the yield bit, not S05: a branch reads its guard predicate far earlier in the
// pipeline than an ALU instruction reads an operand, and a guarded branch needs 13 cycles
// with the yield set. This is the rule that produced a cubin which loaded, disassembled
// cleanly and took the wrong branch.
    [B------:R-:W-:Y:S13]    ISETP.GE.U32.AND P1, PT, BDone, BpL, PT
    [B------:R-:W-:Y:S05] @P1 BRA.U `(.label_batch_end)
//@@LOOPTOP_END

//====================================================================================
// STAGE 1b -- prove the last two pieces of the carrier with ONE real field operation.
//
// Prod = MulMod256(PntX, PntY), through a real out-of-line CALL rather than an inline
// expansion, then round-tripped through the local frame and written to Px. Py and Scal
// stay identity. Checkable directly: the host computes MulModP(x, y) over the same
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
    [B0---4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulA, Pt=0)

// COfs = half*32 = B*16 -- the multiply by 16 is where `half = B >> 1` gets absorbed, so
// no shift instruction is needed. SAdr = R1 + COfs, putting subp[half-1] at [SAdr-0x20].
    [B-----5:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
// R3, and this is the bug that made subp[half-1] wrong while the accumulator was exact. A
// store does not read its data registers at issue -- the LSU reads them later, and with no
// read barrier nothing says when. MulA is rewritten by the copy block inside the loop, and
// the high half of THIS store read its data after the loop had finished: Py came back as
// subp[0].hi ++ subp[511].lo, subp[0] being the accumulator 511 iterations later. Barrier 3
// is free from here on -- the prologue's LDCs armed it and the threadsTotal test drained it.
// (It used to be the rem==0 test that drained it; that test is gone with rem, and the
// threadsTotal test sits earlier and does the same job.)
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
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)
// MulR = MulA * MulB. Ro is deliberately NOT MulA -- MulMod256 clobbers Ro while still
// reading its inputs.
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)
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
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)

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
    [B0-----:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulB, RSecond=MulA, Ro=MulR, Rt=Tmp, Pt=0)

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
// STAGE 2c-i -- the inverse chain. GpuCore.cu:240-331 with the point arithmetic left out:
//
//     for (i = 0; i < half-1; ++i) {
//         mul_mod(dx_inv_i, subp[i], inverse);      <- the per-key inverse
//         ... the +/- point work, stage 2c-ii ...
//         sub_mod(gxmi, &c_Gx[i*4], x1);
//         mul_mod(inverse, inverse, gxmi);          <- advance the chain
//     }
//     { i = half-1; mul_mod(dx_inv_i, subp[i], inverse); ... }
//
// This is the loop the point arithmetic will live inside, and on its own it is the last
// piece of pure ladder machinery: an UPWARD loop (every other one here counts down), a read
// of EVERY slot of subp[] rather than just the two ends, and a second consumer of the
// inversion. Splitting it out is worth a rung because stage 2c-ii brings four vendored
// routines this file has never assembled -- SqrMod256, SubMod256_3, NegMod256 and the
// parity test -- and debugging those on top of an unproven loop is the thing this ladder
// exists to avoid.
//
// WHAT IS WRITTEN BACK, and why it is a product rather than the last value. The identity
// the whole batch-inversion scheme rests on is dx_inv_i == 1/(c_Gx[i] - x1) at EVERY i --
// that is what makes one inversion serve B keys. Reporting only the last dx_inv_i would
// leave 511 of the 512 subp[] reads untested, so Acc accumulates the PRODUCT of all of
// them, which is 1 / prod_i (c_Gx[i] - x1). One wrong slot moves it.
//
// That also keeps the oracle independent, which the XOR alternative did not: the host needs
// ONE Fermat inversion of a product it can form with 512 multiplies, and never has to
// reproduce the suffix-product trick it is judging. Recomputing each 1/(Gx[i]-x1) directly
// would have been 512 inversions per thread, and doing it the cheap way would have meant
// the oracle running the same algorithm as the kernel -- the H14 shape.
//
// C8 NOTE: Acc is 512 MulMod256 results deep, so any of them may be non-canonical and the
// product carries that. Congruent is still congruent -- (a+P)*b == a*b (mod P) and the fold
// reduces below 2^256 either way -- so the answer is right and may land in [P, 2^256). The
// oracle allows the twin. SubMod256 is the one that needs canonical inputs, and both of
// its operands here are: the harness canonicalises c_Gx, and x1 comes from it.
//@@WALK_BEGIN
// Rinv = the running inverse, seeded from InvMod256's output. A separate copy because the
// chain rewrites it every iteration and MulMod256 cannot write its own input.
    [B------:R-:W-:-:S01]    IMAD Rinv0, RZ, RZ, InvO0
    [B------:R-:W-:-:S01]    MOV Rinv1, InvO1
    [B------:R-:W-:-:S01]    IMAD Rinv2, RZ, RZ, InvO2
    [B------:R-:W-:-:S01]    MOV Rinv3, InvO3
    [B------:R-:W-:-:S01]    IMAD Rinv4, RZ, RZ, InvO4
    [B------:R-:W-:-:S01]    MOV Rinv5, InvO5
    [B------:R-:W-:-:S01]    IMAD Rinv6, RZ, RZ, InvO6
    [B------:R-:W-:-:S01]    MOV Rinv7, InvO7
// Acc = 1. THE ACCUMULATOR IS BISECT SCAFFOLDING AND IS OFF BY DEFAULT -- see PACC below.
// It is seeded here rather than inside the loop, so its gate is separate from theirs and both
// the walk rung (WACC/WACCT) and the pts rung (PACC/PACCM/PACCT) have to switch it on.
//@@ACCINIT_BEGIN
//  [B------:R-:W-:-:S01]    MOV Acc0, 0x1
//  [B------:R-:W-:-:S01]    IMAD Acc1, RZ, RZ, RZ
//  [B------:R-:W-:-:S01]    MOV Acc2, RZ
//  [B------:R-:W-:-:S01]    IMAD Acc3, RZ, RZ, RZ
//  [B------:R-:W-:-:S01]    MOV Acc4, RZ
//  [B------:R-:W-:-:S01]    IMAD Acc5, RZ, RZ, RZ
//  [B------:R-:W-:-:S01]    MOV Acc6, RZ
//  [B------:R-:W-:-:S01]    IMAD Acc7, RZ, RZ, RZ
//@@ACCINIT_END
// COfs walks UP in byte offsets, 0 .. (half-1)*32, and Idx holds the limit. Same trick as
// the ladder: the loop variable is the byte offset, so it indexes subp[] and c_Gx[] with no
// shift and no multiply, and the test stays an unsigned compare.
    [B------:R-:W-:-:S01]    MOV COfs, RZ
    [B------:R-:W-:-:S05]    IMAD Idx, Half, 0x10, RZ
    [B------:R-:W-:-:S05]    IADD3 Idx, PT, PT, Idx, -0x20, RZ

.label_walk_loop:
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W0:-:S01]    LDL.128 MulA0, [SAdr]
    [B------:R-:W0:-:S02]    LDL.128 MulA4, [SAdr+0x10]
// Dxi = subp[i] * inverse  == 1/(c_Gx[i] - x1)
    [B0-----:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=Rinv, Ro=Dxi, Rt=Tmp, Pt=0)
// Stage 2c-i accumulated dx_inv_i itself. Stage 2c-ii accumulates px3 instead, which
// depends on dx_inv_i through lam, so the coverage carries and this becomes the earlier
// rung's contribution rather than a second one.
//@@WACC_BEGIN
//  [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointH
//call_func MulMod256(RFirst=Acc, RSecond=Dxi, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointH
//  [B------:R-:W-:-:S01]    IMAD Acc0, RZ, RZ, MulR0
//  [B------:R-:W-:-:S01]    MOV Acc1, MulR1
//  [B------:R-:W-:-:S01]    IMAD Acc2, RZ, RZ, MulR2
//  [B------:R-:W-:-:S01]    MOV Acc3, MulR3
//  [B------:R-:W-:-:S01]    IMAD Acc4, RZ, RZ, MulR4
//  [B------:R-:W-:-:S01]    MOV Acc5, MulR5
//  [B------:R-:W-:-:S01]    IMAD Acc6, RZ, RZ, MulR6
//  [B------:R-:W-:-:S01]    MOV Acc7, MulR7
//@@WACC_END

//====================================================================================
// STAGE 2c-ii -- the +/- point arithmetic, GpuCore.cu:244-327. Both branches, and the
// tail below is the minus branch on its own, exactly as the C++ has it:
//
//     px_i = c_Gx[i]; py_i = c_Gy[i];        (minus branch: neg_mod(py_i) first)
//     sub_mod(s, py_i, y1);
//     mul_mod(lam, s, dx_inv_i);
//     sqr_mod(px3, lam);
//     sub_mod3(px3, px3, x1, px_i);          // lam^2 - x1 - px_i, one reduction
//     sub_mod(s, x1, px3);
//     mul_mod(s, s, lam);
//     sub_mod_is_odd(&odd, s, y1);
//
// The two branches are written out twice but share every call BINDING, so RCAsm emits one
// body per routine and both call points jump to it. That is the whole reason the register
// names are reused rather than duplicated -- a distinct binding would mean a second copy of
// SqrMod256's 125 instructions for no gain.
//
// Lam/PxN/Sqr/SqrT/Pt3T deliberately OVERLAY InvT. InvMod256 has returned by the time any
// of this runs and its 70 temporaries are dead; the alternative was to find 60 more
// registers above R216, which do not exist under a 255 budget.
//
// THE PARITY IS COMPUTED AND NOT CHECKED, and the reason is C8 rather than laziness.
// `odd` is the low bit of (s - y1), and s comes out of MulMod256, which is non-canonical --
// it can be the true value plus P. P is ODD, so a non-canonical s has the OPPOSITE low bit,
// and the parity is therefore not a well-defined function of the inputs until C8 is fixed.
// Any oracle for it would be comparing against a coin flip. It is computed anyway so the
// instruction mix matches the C++ reference for the eventual speed comparison, and it is
// what selects the 0x02/0x03 compressed-pubkey prefix once the hash layer returns -- which
// is exactly why DEVPLAN lists C8 as a silently-missed-key defect and not a cosmetic one.
//
// What IS checked is the product of every px3. That is safe under C8 in a way the parity is
// not: a non-canonical factor is congruent, (a+P)*b == a*b (mod P), so the product is right
// and may itself land in [P, 2^256), which the oracle allows as NON-CANON.
//@@PLUS_BEGIN
//---- the + branch ------------------------------------------------------------------
// c_Gy is at c[0x3][0x40]; element i starts at 0x40 + i*32, and COfs is already i*32.
//
// B1 IS NOT DECORATION. This is the first thing in the whole kernel that READS y1: every
// rung before this one either wrote it straight back through STOREPNTY, which waits barrier
// 1, or never touched it at all. The prologue's four PntY loads arm barrier 1 and nothing
// else has ever drained it. barrier_check.py did flag this -- and reported it as a note
// about the vendored bodies, because the READ happens inside SubMod256 while the load that
// needs waiting is ours. That split was wrong and is fixed; a finding belongs to whoever
// issued the load, not to whoever consumes it. Waiting once per iteration on an
// already-empty barrier costs nothing.
    [B-1----:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x40]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x48]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x50]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x58]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, MulA0, 0x1, RZ, 0xc0, !PT
// Acc *= px3 -- THE PTS RUNG'S INSTRUMENT, AND NOTHING ELSE'S. It is the product of every
// candidate x-coordinate, which is what lets one 256-bit output stand for 1,023 points; the
// default kernel, jump and loop store nothing from it and it is dead weight there.
//
// It is not small dead weight, which is why it is gated rather than left alone: the walk does
// EIGHT MulMod256 per iteration and two of them are this, here and in the minus branch. At 112
// instructions each that is ~17% of the walk's dynamic instruction count, and the walk is
// essentially the whole kernel. No speed number taken with these on means anything.
//@@PACC_BEGIN
//  [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointT
//call_func MulMod256(RFirst=Acc, RSecond=PxN, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointT
//  [B------:R-:W-:-:S01]    IMAD Acc0, RZ, RZ, MulR0
//  [B------:R-:W-:-:S01]    MOV Acc1, MulR1
//  [B------:R-:W-:-:S01]    IMAD Acc2, RZ, RZ, MulR2
//  [B------:R-:W-:-:S01]    MOV Acc3, MulR3
//  [B------:R-:W-:-:S01]    IMAD Acc4, RZ, RZ, MulR4
//  [B------:R-:W-:-:S01]    MOV Acc5, MulR5
//  [B------:R-:W-:-:S01]    IMAD Acc6, RZ, RZ, MulR6
//  [B------:R-:W-:-:S01]    MOV Acc7, MulR7
//@@PACC_END

//---- the - branch: identical, on -c_Gy[i]. x(-Q) == x(Q), so dx_inv_i is reused --------
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x40]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x48]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x50]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x58]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func NegMod256(Rio=MulB, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, MulA0, 0x1, RZ, 0xc0, !PT
// Acc *= px3, the minus branch's half. Same gate as PACC, separate region only because the
// two are not contiguous.
//@@PACCM_BEGIN
//  [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointAC
//call_func MulMod256(RFirst=Acc, RSecond=PxN, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointAC
//  [B------:R-:W-:-:S01]    IMAD Acc0, RZ, RZ, MulR0
//  [B------:R-:W-:-:S01]    MOV Acc1, MulR1
//  [B------:R-:W-:-:S01]    IMAD Acc2, RZ, RZ, MulR2
//  [B------:R-:W-:-:S01]    MOV Acc3, MulR3
//  [B------:R-:W-:-:S01]    IMAD Acc4, RZ, RZ, MulR4
//  [B------:R-:W-:-:S01]    MOV Acc5, MulR5
//  [B------:R-:W-:-:S01]    IMAD Acc6, RZ, RZ, MulR6
//  [B------:R-:W-:-:S01]    MOV Acc7, MulR7
//@@PACCM_END
//@@PLUS_END

// gxmi = c_Gx[i] - x1, in place into MulB
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)
// inverse *= gxmi
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=Rinv, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    IMAD Rinv0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV Rinv1, MulR1
    [B------:R-:W-:-:S01]    IMAD Rinv2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV Rinv3, MulR3
    [B------:R-:W-:-:S01]    IMAD Rinv4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV Rinv5, MulR5
    [B------:R-:W-:-:S01]    IMAD Rinv6, RZ, RZ, MulR6
    [B------:R-:W-:-:S02]    MOV Rinv7, MulR7

    [B------:R-:W-:-:S05]    IADD3 COfs, PT, PT, COfs, 0x20, RZ
    [B------:R-:W-:Y:S13]    ISETP.NE.U32.AND P0, PT, COfs, Idx, PT
    [B------:R-:W-:Y:S05] @P0 BRA.U `(.label_walk_loop)

// Tail, i = half-1: the last dx_inv_i, with no chain update after it. COfs is already
// (half-1)*32 -- the loop leaves it at the limit, which is exactly the tail's index.
    [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
    [B------:R-:W0:-:S01]    LDL.128 MulA0, [SAdr]
    [B------:R-:W0:-:S02]    LDL.128 MulA4, [SAdr+0x10]
    [B0-----:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=Rinv, Ro=Dxi, Rt=Tmp, Pt=0)
//@@WACCT_BEGIN
//  [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointL
//call_func MulMod256(RFirst=Acc, RSecond=Dxi, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointL
//  [B------:R-:W-:-:S01]    IMAD Acc0, RZ, RZ, MulR0
//  [B------:R-:W-:-:S01]    MOV Acc1, MulR1
//  [B------:R-:W-:-:S01]    IMAD Acc2, RZ, RZ, MulR2
//  [B------:R-:W-:-:S01]    MOV Acc3, MulR3
//  [B------:R-:W-:-:S01]    IMAD Acc4, RZ, RZ, MulR4
//  [B------:R-:W-:-:S01]    MOV Acc5, MulR5
//  [B------:R-:W-:-:S01]    IMAD Acc6, RZ, RZ, MulR6
//  [B------:R-:W-:-:S05]    MOV Acc7, MulR7
//@@WACCT_END
// The tail is the MINUS branch alone -- GpuCore.cu:333-378. Offsets `s1 - half` rather than
// `s1 + half`, which is what makes consecutive batches abut with no gap and no duplicate.
// Every call binding here is one the loop above already used, so this costs no new bodies.
//@@PLUST_BEGIN
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x40]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x48]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x50]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x58]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func NegMod256(Rio=MulB, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S05]    LOP3.LUT TmpA, MulA0, 0x1, RZ, 0xc0, !PT
// Acc *= px3, the tail's. Once per batch rather than per point, so this one is not about speed
// -- it is gated with the other two because the accumulator has to be all on or all off to mean
// anything, and a product missing one of its 1,023 factors is worse than no product at all.
//@@PACCT_BEGIN
//  [B------:R-:W-:-:S01]    UMOV uCallM0, `(.relN_end_MulMod256) //RCASM:CallPointAL
//call_func MulMod256(RFirst=Acc, RSecond=PxN, Ro=MulR, Rt=Tmp, Pt=0, Ret="[B------:R-:W-:-:S01] BRXU.U uCallM, 0x00") //RCASM:CallPointAL
//  [B------:R-:W-:-:S01]    IMAD Acc0, RZ, RZ, MulR0
//  [B------:R-:W-:-:S01]    MOV Acc1, MulR1
//  [B------:R-:W-:-:S01]    IMAD Acc2, RZ, RZ, MulR2
//  [B------:R-:W-:-:S01]    MOV Acc3, MulR3
//  [B------:R-:W-:-:S01]    IMAD Acc4, RZ, RZ, MulR4
//  [B------:R-:W-:-:S01]    MOV Acc5, MulR5
//  [B------:R-:W-:-:S01]    IMAD Acc6, RZ, RZ, MulR6
//  [B------:R-:W-:-:S05]    MOV Acc7, MulR7
//@@PACCT_END
//@@PLUST_END
//@@WALK_END

//====================================================================================
// STAGE 2d, part 2 -- the point jump, GpuCore.cu:383-402. The batch's centre advances by
// the jump constant J = half*G, using the SAME `inverse` the walk finished with:
//
//     sub_mod(s,  c_Jy, y1);      mul_mod(lam, s, inverse);
//     sqr_mod(x3, lam);           sub_mod3(x3, x3, x1, c_Jx);
//     sub_mod(s,  x1, x3);        mul_mod(y3, s, lam);      sub_mod(y3, y3, y1);
//     x1 = x3;  y1 = y3;
//
// This is the one place the inverse chain's final value is CONSUMED rather than accumulated,
// which is why it can be right for 1023 points and still be wrong here -- and why the walk
// rung passing did not already prove it.
//
// EVERY CALL REUSES A BINDING THE WALK ALREADY USED, so this adds no new function bodies.
// That is what the copy below is for: MulMod256 is bound with RSecond=Dxi in the walk, so
// `lam = s * inverse` copies inverse into Dxi rather than binding MulMod256 to RSecond=Rinv.
// Eight register copies against a ninth 112-instruction body, once per batch.
//@@JUMP_BEGIN
// THE TAIL'S OWN CHAIN UPDATE -- GpuCore.cu:378-380, and it was missing from both this file and
// the compiled reference until the jump rung ran on hardware. The walk leaves
// Rinv = 1/((Jx-x1) * (Gx[half-1]-x1)); one more multiply by (Gx[half-1]-x1) is what makes it
// 1/(Jx-x1), which is what the jump below consumes.
//
// It is worth being precise about why nothing caught this earlier, because the comment above the
// tail at .label_walk_loop's exit said "no chain update after it" and was CORRECT when written:
// on every rung up to pts, `inverse` is dead once the tail's dx_inv_i has been formed. Stage 2d
// added the first consumer of it after the walk and turned a true statement into a defect. The
// walk rung checks the product of the dx_inv_i and the pts rung checks the tail POINT, and this
// multiply feeds neither -- it is the one link in the ladder whose only observable effect is on
// the jump.
//
// A and B were wrong IDENTICALLY, since both are transcriptions of the same misreading, so the
// A/B half of the harness said "agree" on both rungs. The oracle is what caught it: it inverts
// (Jx - x1) by Fermat and shares no structure with the ladder. That is the entire reason it
// exists, and it is the H14 lesson with the signs reversed -- two implementations agreeing is
// not evidence when one person wrote both.
//
// It lives HERE rather than at the end of WALK so that every rung below jump keeps the cubin it
// already passed on hardware with. Both call bindings are ones the walk loop already uses
// (CallPointI, CallPointJ), so this adds no function bodies -- 4 loads, 2 calls, 8 copies.
// COfs is still (half-1)*32: the loop leaves it at the limit and the tail only reads it.
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][COfs+0x4040]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][COfs+0x4048]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][COfs+0x4050]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][COfs+0x4058]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntX, Ro=MulB, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=Rinv, RSecond=MulB, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    IMAD Rinv0, RZ, RZ, MulR0
    [B------:R-:W-:-:S01]    MOV Rinv1, MulR1
    [B------:R-:W-:-:S01]    IMAD Rinv2, RZ, RZ, MulR2
    [B------:R-:W-:-:S01]    MOV Rinv3, MulR3
    [B------:R-:W-:-:S01]    IMAD Rinv4, RZ, RZ, MulR4
    [B------:R-:W-:-:S01]    MOV Rinv5, MulR5
    [B------:R-:W-:-:S01]    IMAD Rinv6, RZ, RZ, MulR6
    [B------:R-:W-:-:S02]    MOV Rinv7, MulR7

    [B------:R-:W-:-:S01]    IMAD Dxi0, RZ, RZ, Rinv0
    [B------:R-:W-:-:S01]    MOV Dxi1, Rinv1
    [B------:R-:W-:-:S01]    IMAD Dxi2, RZ, RZ, Rinv2
    [B------:R-:W-:-:S01]    MOV Dxi3, Rinv3
    [B------:R-:W-:-:S01]    IMAD Dxi4, RZ, RZ, Rinv4
    [B------:R-:W-:-:S01]    MOV Dxi5, Rinv5
    [B------:R-:W-:-:S01]    IMAD Dxi6, RZ, RZ, Rinv6
    [B------:R-:W-:-:S02]    MOV Dxi7, Rinv7
// s = c_Jy - y1. c_Jy is at c[0x3][0x0] in the -rdc layout, c_Jx at 0x20.
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x0]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x8]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x10]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x18]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulB, RSecond=PntY, Ro=MulB, Pt=0)
// lam = s * inverse
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulB, RSecond=Dxi, Ro=Lam, Rt=Tmp, Pt=0)
// x3 = lam^2 - x1 - Jx, one reduction
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SqrMod256(Ri=Lam, Ro=Sqr, Rt=SqrT, Pt=0)
    [B------:R-:W4:-:S01]    LDC.64 MulB0, c[0x3][0x20]
    [B------:R-:W4:-:S01]    LDC.64 MulB2, c[0x3][0x28]
    [B------:R-:W4:-:S01]    LDC.64 MulB4, c[0x3][0x30]
    [B------:R-:W4:-:S02]    LDC.64 MulB6, c[0x3][0x38]
    [B----4-:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256_3(RFirst=Sqr, RSecond=PntX, RThird=MulB, Ro=PxN, Rt=Pt3T, Pt=0)
// y3 = (x1 - x3)*lam - y1
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=PntX, RSecond=PxN, Ro=MulA, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func MulMod256(RFirst=MulA, RSecond=Lam, Ro=MulR, Rt=Tmp, Pt=0)
    [B------:R-:W-:-:S01]    UMOV uCallM0, 0x0
inc_func SubMod256(RFirst=MulR, RSecond=PntY, Ro=MulA, Pt=0)
// x1 = x3 ; y1 = y3. PntY is read by the SubMod256 immediately above, so it cannot be
// overwritten before that call returns -- which is why both copies live here and not one
// beside each producer.
    [B------:R-:W-:-:S01]    IMAD PntX0, RZ, RZ, PxN0
    [B------:R-:W-:-:S01]    MOV PntX1, PxN1
    [B------:R-:W-:-:S01]    IMAD PntX2, RZ, RZ, PxN2
    [B------:R-:W-:-:S01]    MOV PntX3, PxN3
    [B------:R-:W-:-:S01]    IMAD PntX4, RZ, RZ, PxN4
    [B------:R-:W-:-:S01]    MOV PntX5, PxN5
    [B------:R-:W-:-:S01]    IMAD PntX6, RZ, RZ, PxN6
    [B------:R-:W-:-:S01]    MOV PntX7, PxN7
    [B------:R-:W-:-:S01]    IMAD PntY0, RZ, RZ, MulA0
    [B------:R-:W-:-:S01]    MOV PntY1, MulA1
    [B------:R-:W-:-:S01]    IMAD PntY2, RZ, RZ, MulA2
    [B------:R-:W-:-:S01]    MOV PntY3, MulA3
    [B------:R-:W-:-:S01]    IMAD PntY4, RZ, RZ, MulA4
    [B------:R-:W-:-:S01]    MOV PntY5, MulA5
    [B------:R-:W-:-:S01]    IMAD PntY6, RZ, RZ, MulA6
    [B------:R-:W-:-:S05]    MOV PntY7, MulA7
//@@JUMP_END

//====================================================================================
// STAGE 2d, part 3 -- the bookkeeping and the back edge, GpuCore.cu:404-410.
//
//     s1  += B;      rem -= B;      batches_done++;
//
// Both are 256-bit against a value that fits in word 0, so word 0 does the arithmetic and
// the seven above it only propagate. The subtract is `rem + ~B + 1` in the two's-complement
// idiom SubMod256 uses -- `!PT, PT` as the carry-in pair is where the +1 comes from, and
// 0xFFFFFFFF is ~0 for the high words. A negated register operand (`-Half`) would read
// better and is exactly the form cuAssembler rejected on the template round trip, so it is
// spelled the way the vendored bodies spell it.
//
// No borrow can escape word 7: the loop head has already established rem >= B.
// B2, and this is the first instruction in the kernel that READS Scal. The four Scal loads
// were armed on barrier 2 in the prologue and, until this region existed, were not waited
// until the write-back -- which was correct only because nothing touched the registers in
// between. barrier_check.py caught it on the first build. The wait stays on the write-back
// too: it costs nothing on an already-drained barrier and the rungs below this one have no
// LOOPEND to carry it.
//@@LOOPEND_BEGIN
    [B--2---:R-:W-:-:S04]    IADD3 Scal0, P0, PT, Scal0, Half, RZ
    [B------:R-:W-:-:S04]    IADD3.X Scal1, P0, PT, Scal1, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal2, P0, PT, Scal2, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal3, P0, PT, Scal3, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal4, P0, PT, Scal4, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal5, P0, PT, Scal5, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal6, P0, PT, Scal6, RZ, RZ, P0, !PT
    [B------:R-:W-:-:S04]    IADD3.X Scal7, PT, PT, Scal7, RZ, RZ, P0, !PT
// The eight-limb `rem -= B` that used to sit here is gone; BDone is the whole of the
// bookkeeping now. Note P0 is still the carry chain of the Scal add above and must not be
// read after this point.
    [B------:R-:W-:-:S05]    IADD3 BDone, PT, PT, BDone, 0x1, RZ
    [B------:R-:W-:Y:S05]    BRA.U `(.label_batch_loop)
.label_batch_end:
//@@LOOPEND_END

//---- rebuild the per-thread addresses ---------------------------------------------
// AddrX/AddrY/AddrS/AddrC live in overlay A, which the ladder, the inversion and the walk
// have all been using for other things since the prologue -- InvT's 70 temporaries sit on
// top of this span. So they are rebuilt here rather than held, which is the trade that pays
// for the register count: eight instructions once per kernel against eight registers held
// live across ~76,000 instructions per batch.
//
// AddrC is built here and NOT in the prologue: counts256 is write-only in this kernel now,
// and only the gated STORELAM region actually uses it. Building it unconditionally is one
// instruction and keeps the gated regions from having to carry their own setup.
//
// Barrier 3 is free at this point -- the prologue's LDCs were drained by the threadsTotal
// test, and the suffix-product STL uses it only as a READ barrier, which the ladder has long
// since passed. The S02/S05 pairing is the same as the prologue's.
    [B------:R-:W3:-:S01]    LDC.64 AddrX, c[0x0][0x380]
    [B------:R-:W3:-:S01]    LDC.64 AddrY, c[0x0][0x388]
    [B------:R-:W3:-:S01]    LDC.64 AddrS, c[0x0][0x390]
    [B------:R-:W3:-:S02]    LDC.64 AddrC, c[0x0][0x398]
    [B---3--:R-:W-:-:S01]    IMAD.WIDE.U32 AddrX, gID, 0x20, AddrX
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrY, gID, 0x20, AddrY
    [B------:R-:W-:-:S01]    IMAD.WIDE.U32 AddrS, gID, 0x20, AddrS
    [B------:R-:W-:-:S05]    IMAD.WIDE.U32 AddrC, gID, 0x20, AddrC

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
    [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], PntX0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], PntX2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], PntX4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], PntX6
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
// unchanged across the stages is deliberate -- it means a later failure that is really a
// stage-2a regression shows up on Py rather than being blamed on the newest thing added.
//@@STOREINV_BEGIN
//  [B0--3--:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], InvO0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], InvO2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], InvO4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], InvO6
//  [B------:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
//  [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
//  [B------:R-:W0:-:S01]    LDL.128 MulB0, [SAdr+-0x20]
//  [B------:R-:W0:-:S02]    LDL.128 MulB4, [SAdr+-0x10]
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], MulB0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], MulB2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], MulB4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], MulB6
//@@STOREINV_END
// Stage 2c-ii: Px = the product of every px3, Py = the LAST px3 on its own -- the tail's
// point, i = half-1, minus branch.
//
// Py stops being subp[half-1] here, and that is the whole point of this build. The product
// came back wrong with every structural hypothesis eliminated offline: it is not a missing
// branch, a missing tail, an off-by-one index or a sign, because none of those reproduce
// the value, and got/want is not a single field element either, so more than one point
// differs. A product of 1023 points cannot say WHICH. One point can: if this comes back
// right, the point arithmetic is correct and the accumulation is not; if it comes back
// wrong, every intermediate behind it -- lam, s, the square, the three-way subtract -- is
// computable offline for that one i and the wrong one names itself.
//@@STOREPTS_BEGIN
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], Acc0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], Acc2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], Acc4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], Acc6
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], PxN0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], PxN2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], PxN4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], PxN6
//@@STOREPTS_END
// Stage 2c-i: Px = the product of every dx_inv_i.
//@@STOREWALK_BEGIN
//  [B0--3--:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64], Acc0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x8], Acc2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x10], Acc4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrX.64+0x18], Acc6
//  [B------:R-:W-:-:S05]    IMAD COfs, Half, 0x10, RZ
//  [B------:R-:W-:-:S05]    IADD3 SAdr, PT, PT, R1, COfs, RZ
//  [B------:R-:W0:-:S01]    LDL.128 MulB0, [SAdr+-0x20]
//  [B------:R-:W0:-:S02]    LDL.128 MulB4, [SAdr+-0x10]
//  [B0-----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], MulB0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], MulB2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], MulB4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], MulB6
//@@STOREWALK_END
//@@STOREPNTY_BEGIN
    [B-1----:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64], PntY0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x8], PntY2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x10], PntY4
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrY.64+0x18], PntY6
//@@STOREPNTY_END
// Scal, which is an identity copy on every rung below `jump` and the real advanced state on
// `jump` and `loop` -- the same four stores either way, because `s1 += B` happens in
// registers. The pts rung is the one that spends this array on something else entirely; see
// STORELAM below.
//
// counts256 IS NO LONGER WRITTEN. It used to take the matching four stores from Rem here,
// and the harness compared it as a fourth output array. It does not any more: the kernel
// neither reads nor tracks it, so whatever the host seeded stays there. abtest.cpp drops it
// from both the A/B limb diff and the oracle check -- and that is a real reduction in what
// the harness proves, taken deliberately: Px and Py after the batch completes are what carry
// the walk, the jump and the loop, and rem was only ever an identity copy plus a subtract.
//@@STOREID_BEGIN
    [B--2---:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64], Scal0
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x8], Scal2
    [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x10], Scal4
    [B------:R-:W-:-:S05]    STG.E.64 desc[uDesc][AddrS.64+0x18], Scal6
//@@STOREID_END
// The tail point's two intermediates, so one launch says WHERE the tail diverges rather
// than only that it does:
//
//     Lam = MulMod256(-c_Gy[511] - y1, dx_inv)   -> start_scalars
//     Sqr = SqrMod256(Lam)                       -> counts256
//
// with Py already carrying PxN = SubMod256_3(Sqr, x1, c_Gx[511]). Together with Px those
// are the whole tail chain, and the first one that disagrees names the call that is wrong.
//
// This is worth doing precisely because the offline simulation of that chain reproduces the
// oracle EXACTLY -- source and emitted body alike. So a divergence here cannot be an
// arithmetic error in the routine; it is a hazard around the call, and knowing which call
// is most of the answer. Both registers are still live at PLUST_END: SqrMod256 does not
// write Ri, and nothing after SubMod256_3 touches Sqr.
//
// B2 is kept on the first store even though Scal is no longer written. The barrier belongs
// to Scal's load and draining it here costs nothing, where dropping it would leave a load
// armed at EXIT for no reason other than that this rung stopped using the value.
//@@STORELAM_BEGIN
//  [B--2---:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64], Lam0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x8], Lam2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x10], Lam4
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrS.64+0x18], Lam6
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrC.64], Sqr0
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrC.64+0x8], Sqr2
//  [B------:R-:W-:-:S01]    STG.E.64 desc[uDesc][AddrC.64+0x10], Sqr4
//  [B------:R-:W-:-:S05]    STG.E.64 desc[uDesc][AddrC.64+0x18], Sqr6
//@@STORELAM_END

    [B------:R-:W-:Y:S05]    EXIT
}
