#!/bin/bash
# Build the manual FULL pipeline WITH the uniform-register table reads (LDCU.128), into
# TestKernel_hash_ur.cubin. This is build_full.sh's kernel plus the UR win from main_ur:
#   MAIN = main_full_ur.asm   (mk_ur.py: main_full.asm with LDCU.128 uGx/uGy/uGyN table loads)
#   INC  = inc_ur.asm + hash + publish   (inc_ur.asm adds SubMod256_UB / SubMod256_3_UB that
#          the UR walk calls; otherwise identical to inc_full.asm)
# Same teach prerequisites and hash-body selection as build_full.sh.
set -e
cd "$(dirname "$0")"
[ -f main_full_ur.asm ] || { echo "main_full_ur.asm missing -- run: python3 mk_ur.py" >&2; exit 1; }
if [ hd_hash_inc.asm -nt hd_hash_inc_param.asm ] || [ ! -f hd_hash_inc_param.asm ] \
   || [ hd_hash33_inc.asm -nt hd_hash33_inc_param.asm ] || [ ! -f hd_hash33_inc_param.asm ]; then
    python3 parametrize_hash.py
fi
HASH_PARAM="${HASH_PARAM:-hd_hash33_inc_133_param.asm}"
echo "build_full_ur: hash body = $HASH_PARAM"
cat inc_ur.asm "$HASH_PARAM" hd_publish_inc.asm > inc_full_ur.asm
sed 's/\r$//' build.sh > _build_lf.sh
MAIN="$(pwd)/main_full_ur.asm" INC="$(pwd)/inc_full_ur.asm" OUTNAME=TestKernel_hash_ur.cubin bash _build_lf.sh
rm -f _build_lf.sh
