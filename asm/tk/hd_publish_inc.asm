// getPublish -- publish_found(find_result, hit) as a call_func callee (branch f2m, Stage 3b).
// Faithful to GpuCore.cu publish_found: atomicCAS_system(claimed,0,1); if won, store the 256-bit
// scalar; threadfence_system; then set found. Reached only when some warp lane matched the hw2
// filter (the caller's `@!P3 BRA skip` gates it), so ALL cost here is cold. Only the matching lane
// (P2) that WINS the CAS writes find_result; others branch out. It does NOT early-exit -- the walk
// continues, keeping the points A/B clean on a spurious hw2 collision (abtest uses a random
// c_target_words). full_match + early-return are deferred (a cold getHash160_33 lift).
//
// The CAS/STGs are UNPREDICATED and gated by BRANCHES (`@!P2 BRA`/`@P5 BRA`) rather than per-inst
// predication, because the taught ATOMG.E.CAS.STRONG.SYS basis (from nvcc-emitted samples) only
// covers unpredicated atomics -- a predicated CAS is "Insufficient basis". CAS operands addr R58,
// dst R57, cmp R56, new R61 are register indices the taught basis covers.
//
// Contract: hit = R64..R71 (256-bit, LSB word R64); P2 = this lane matched. Scratch R48..R61, P4/P5
// (hash dead span, clear of walk live R0..R47). uDesc=UR4. find_result = c[0x0][0x398]; struct:
// scalar@0, claimed@96(0x60), found@100(=claimed+0x4). found uses STG.E (not atomicExch_system --
// the SYS-EXCH desc+offset operand does not verify-round-trip in the encoder), safe because the CAS
// elected a single writer and MEMBAR.SC.SYS is the system release ordering scalar before flag.
FUNCTION getPublish()
{
    [B------:R-:W-:Y:S13] @!P2 BRA `(.gp_done)
    [B------:R-:W-:-:S02]      LDC.64 R48, c[0x0][0x398]
    [B------:R-:W-:-:S02]      IADD3 R58, P4, PT, R48, 0x60, RZ
    [B------:R-:W-:-:S04]      IADD3.X R59, PT, PT, R49, RZ, RZ, P4, !PT
    [B------:R-:W-:-:S02]      MOV R56, RZ
    [B------:R-:W-:-:S02]      MOV R61, 0x1
    [B------:R-:W5:-:S02]      ATOMG.E.CAS.STRONG.SYS PT, R57, [R58], R56, R61
    [B-----5:R-:W-:Y:S13]      ISETP.NE.AND P5, PT, R57, RZ, PT
    [B------:R-:W-:Y:S05] @P5  BRA `(.gp_done)
    [B------:R-:W-:-:S02]      STG.E.64 [R48], R64
    [B------:R-:W-:-:S02]      STG.E.64 [R48+0x8], R66
    [B------:R-:W-:-:S02]      STG.E.64 [R48+0x10], R68
    [B------:R-:W-:-:S02]      STG.E.64 [R48+0x18], R70
    [B------:R-:W-:-:S02]      MEMBAR.ALL.CTA
    [B------:R-:W-:-:S02]      MEMBAR.SC.SYS
    [B------:R-:W-:-:S02]      ERRBAR
    [B------:R-:W-:-:S04]      CGAERRBAR
    [B------:R-:W-:-:S06]      STG.E [R58+0x4], R61
.gp_done:
}
