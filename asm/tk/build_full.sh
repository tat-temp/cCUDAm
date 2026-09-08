#!/bin/bash
# Build the manual FULL pipeline (EC walk + lifted getHash160_w2) into TestKernel_hash.cubin.
#
#   RCASM=/path/to/RCAsm CUDA=/usr/local/cuda-13.0 ./build_full.sh
#
# main_full.asm is main.asm (the points-only walk) with getHash160_w2 called at the four hash
# sites (seed, +, -, tail). The hash body is hd_hash_inc.asm renumbered +48 (R0..R58 -> R48..R106,
# UR4 -> UR6) so it sits in the walk's dead overlay-C span clear of the live set (persistent
# R0..R31, Rinv R32-39, Dxi R40-47) and stays <=R124 (regcnt=128, 2 blocks/SM). See
# renumber_hash.py and the README/memory. inc_full.asm (inc.asm + the hash FUNCTION) is generated
# here and gitignored -- RCAsm's build.sh concatenates exactly one INC file.
#
# PREREQUISITE for the publish_found path (hd_publish_inc.asm): run ./teach_publish_atomics.sh ONCE
# first -- the default RCAsm sm_120 InsAsmRepos cannot encode ATOMG.E.CAS.STRONG.SYS or the
# MEMBAR/ERRBAR/CGAERRBAR fence, and that script teaches them (additively; Gate-1 stays byte-identical).
set -e
cd "$(dirname "$0")"
# 1. (re)generate the +48-renumbered hash body from the committed lifted hash, if stale.
if [ hd_hash_inc.asm -nt hd_hash_inc_rn.asm ] || [ ! -f hd_hash_inc_rn.asm ]; then
    python3 renumber_hash.py
fi
# 2. concatenate the field routines + the hash FUNCTION + the publish_found FUNCTION into one INC.
cat inc.asm hd_hash_inc_rn.asm hd_publish_inc.asm > inc_full.asm
# 3. build (CRLF-safe: run a CR-stripped copy so `dirname "$0"` still resolves).
sed 's/\r$//' build.sh > _build_lf.sh
MAIN="$(pwd)/main_full.asm" INC="$(pwd)/inc_full.asm" OUTNAME=TestKernel_hash.cubin bash _build_lf.sh
rm -f _build_lf.sh
