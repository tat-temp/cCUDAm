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
# PREREQUISITE for the publish_found path (hd_publish_inc.asm): run ./teach_publish_atomics.sh ONCE
# first -- the default RCAsm sm_120 InsAsmRepos cannot encode ATOMG.E.CAS.STRONG.SYS or the
# MEMBAR/ERRBAR/CGAERRBAR fence, and that script teaches them (additively; Gate-1 stays byte-identical).
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
cat inc.asm hd_hash33_inc_param.asm hd_publish_inc.asm > inc_full.asm
# 3. build (CRLF-safe: run a CR-stripped copy so `dirname "$0"` still resolves).
sed 's/\r$//' build.sh > _build_lf.sh
MAIN="$(pwd)/main_full.asm" INC="$(pwd)/inc_full.asm" OUTNAME=TestKernel_hash.cubin bash _build_lf.sh
rm -f _build_lf.sh
