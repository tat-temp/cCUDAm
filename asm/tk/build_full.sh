#!/bin/bash
# Build the manual FULL pipeline (EC walk + lifted getHash160_w2) into TestKernel_hash.cubin.
#
#   RCASM=/path/to/RCAsm CUDA=/usr/local/cuda-13.0 ./build_full.sh
#
# main_full.asm is main.asm (the points-only walk) with getHash160_w2 called at the four hash
# sites (seed, +, -, tail). The hash body is the PARAMETRIZED FUNCTION hd_hash_inc_param.asm
# (parametrize_hash.py: R<n>->Rt<n>, UR4->URt0); each call site binds Rt=MulB(R48)/URt=uHashSel(UR6),
# which lands the hash in the walk's dead overlay-C span (persistent R0..R31, Rinv R32-39, Dxi R40-47
# stay clear) at R48..R106 <=R124 (regcnt=128, 2 blocks/SM) -- byte-identical to the old +48 renumber.
# getPublish (hd_publish_inc.asm) is likewise parametrized (Ri=Prod/Rt=MulB/URt=uDesc/Pt=2). See the
# README/memory. inc_full.asm (inc.asm + the hash FUNCTION + getPublish) is generated here and
# gitignored -- RCAsm's build.sh concatenates exactly one INC file.
#
# PREREQUISITES (run ONCE each; all additive, Gate-1 stays byte-identical):
#   ./teach_publish_atomics.sh  -- ATOMG.E.CAS.STRONG.SYS + MEMBAR/ERRBAR/CGAERRBAR (the publish path).
#   ./teach_iadd.sh             -- plain 32-bit IADD (+ .reuse + source-neg), which the DEFAULT hash body
#                                  (the CUDA-13.3 lift) uses; the stock repo only knows IADD.64.
#   ./teach_bssy.sh             -- BSSY/BSYNC convergence barriers (the slices>=2 HANG fix): each hash
#                                  filter's divergent @!P2/@!P3 skip is wrapped in BSSY B0 .. BSYNC B0 so
#                                  a spurious-w2 divergence RECONVERGES before the next InvMod256 instead
#                                  of deadlocking. New opcodes (0 in the stock tree). See the lift note.
#
# HASH BODY: builds the CUDA-13.3-lifted getHash160_33 by default (hd_hash33_inc_133_param.asm) -- it
# schedules with plain IADD + .reuse and runs ~1.1% off the 13.3 compiler / +8% over 13.0, vs the older
# 13.0 lift which trailed the 13.3 compiler by ~9%. Set HASH_PARAM=hd_hash33_inc_param.asm to build the
# 13.0 lift instead (needs no teach_iadd.sh). See the asm-tk-full-pipeline-lift note.
set -e
cd "$(dirname "$0")"
# 1. (re)generate the PARAMETRIZED hash FUNCTIONs (Ri/Rio/Rt/URt slots) from the lifted bodies, if
# stale. parametrize_hash.py writes BOTH hd_hash_inc_param.asm (getHash160_w2) and
# hd_hash33_inc_param.asm (getHash160_33, the FULL 5-word hash). The caller binds Ri=R54/Rio=R52/
# Rt=MulB(R48)/URt=uHashSel(UR6) at each site (main_full.asm) -- byte-for-byte the verified registers.
if [ hd_hash_inc.asm -nt hd_hash_inc_param.asm ] || [ ! -f hd_hash_inc_param.asm ] \
   || [ hd_hash33_inc.asm -nt hd_hash33_inc_param.asm ] || [ ! -f hd_hash33_inc_param.asm ]; then
    python3 parametrize_hash.py
fi
# 2. concatenate the field routines + the FULL-hash FUNCTION + the publish_found FUNCTION into one INC.
# main_full.asm calls getHash160_33 (full 5-word) so full_match can gate publish+EXIT; getHash160_w2
# (hd_hash_inc_param.asm) stays parametrized on disk as the word-2-only sibling but is not linked here.
# HASH_PARAM selects the hash body: default = the CUDA-13.3 lift; override to the 13.0 lift for rollback.
HASH_PARAM="${HASH_PARAM:-hd_hash33_inc_133_param.asm}"
echo "build_full: hash body = $HASH_PARAM"
cat inc.asm "$HASH_PARAM" hd_publish_inc.asm > inc_full.asm
# 3. build (CRLF-safe: run a CR-stripped copy so `dirname "$0"` still resolves).
sed 's/\r$//' build.sh > _build_lf.sh
MAIN="$(pwd)/main_full.asm" INC="$(pwd)/inc_full.asm" OUTNAME=TestKernel_hash.cubin bash _build_lf.sh
rm -f _build_lf.sh
