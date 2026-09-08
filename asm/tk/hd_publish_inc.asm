// getPublish -- publish_found(find_result, hit) as a PARAMETRIZED call_func callee (branch f2m).
// Faithful to GpuCore.cu publish_found: atomicCAS_system(claimed,0,1); if won, store the 256-bit
// scalar; threadfence_system; then set found. Reached only when a lane matched the hw2 filter (the
// caller's `@!P2 BRA skip` gates it), so all cost here is cold. Only the matching lane (Pt0) that
// WINS the CAS writes find_result; others branch out. It does NOT early-exit -- the walk continues,
// keeping the points A/B clean on a spurious hw2 collision. full_match + early-return are deferred.
//
// PARAMETERS (bound at the call site, RCAsm-style):
//   Ri  = hit   : the 256-bit scalar to publish (hit0..hit7, LSB word hit0)          [input]
//   URt = uGD   : the global-memory descriptor (kernel uDesc=UR4)                     [input]
//   Pt         : Pt0 = "this lane matched" [input]; Pt2, Pt3 = scratch predicates
//   Rt  = frp  : scratch. frp0:frp1 = find_result ptr; czero(Rt8)=CAS cmp;
//                cret(Rt9)=CAS old; cadr0:cadr1(Rt10:11)=&claimed; newv(Rt13)=new/found=1
//
// CAS-BASIS CONSTRAINT: the taught ATOMG.E.CAS.STRONG.SYS basis only covers specific register
// indices, so Rt must be bound so the CAS operands land on covered registers -- Rt=MulB(R48) puts
// addr=cadr0=R58, dst=cret=R57, cmp=czero=R56, new=newv=R61, all covered. The CAS/STGs are
// UNPREDICATED and gated by BRANCHES (a predicated CAS is "Insufficient basis").
//
// Global stores MUST go through the descriptor (uGD) -- a plain generic STG.E [Rn] does NOT reach
// global memory on sm_120 (verified: generic store left found=0; the identical desc store set it).
// The CAS stays generic [cadr0] because the .SYS atomic takes the raw pointer as a generic address
// (how GpuCore encodes its system CAS). found = c[0x0][0x398]+0x60+0x4; struct: scalar@0,
// claimed@0x60, found@0x64. found uses STG.E (not atomicExch -- SYS-EXCH desc form does not
// verify-round-trip), safe because the CAS elected a single writer and MEMBAR.SC.SYS orders it.
FUNCTION getPublish(hit=Ri0, uGD=URt0, frp=Rt0, czero=Rt8, cret=Rt9, cadr=Rt10, newv=Rt13)
{
    [B------:R-:W-:Y:S13] @!Pt0 BRA `(.gp_done)
    // LDC.64 is variable-latency: it MUST arm a write scoreboard and the first consumer of frp must
    // wait on it (W-/S02 alone read the find_result pointer stale). Same rule the walk's param LDCs use.
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
