#!/bin/bash
# Reproduce the encoder-coverage measurement end to end.
#
#   RCASM=/path/to/RCAsm ./run.sh
#
# Optional: PYDEPS=<dir with pyelftools+sympy>, WORK=<scratch>, CUDA=<toolkit root>.
# The RCAsm tree needs fixes 1 and 6 applied first (see env.py).
set -e
cd "$(dirname "$0")"
: "${RCASM:?set RCASM to the RCAsm checkout}"
export WORK="${WORK:-/tmp/rcenc}"
CUDA="${CUDA:-/usr/local/cuda}"
REPO="$(cd ../.. && pwd)"
mkdir -p "$WORK"

echo "=== 1/4  build the plain (non -rdc) sm_120 cubin ==="
# Must be the plain build: asm/GpuCore_sm120.asm came from it, and -rdc changes
# codegen (159744 -> 161280 B, hash bodies moved into their own sections).
B="$WORK/build"
rm -rf "$B" && mkdir -p "$B"
cp "$REPO"/*.cu "$REPO"/*.cuh "$REPO"/*.h "$B"/
( cd "$B" && "$CUDA/bin/nvcc" -O3 -use_fast_math --ptxas-options=-O3 -std=c++17 \
      -gencode arch=compute_120,code=sm_120 -cubin -o "$WORK/plain.cubin" GpuCore.cu )
sz=$(readelf -S "$WORK/plain.cubin" 2>/dev/null | grep -A1 'text.TestKernel' | tr -s ' ' | cut -d' ' -f2 | sed -n 2p)
echo "    .text.TestKernel = 0x$sz  (expect 27000 = 159744 B, matching asm/GpuCore_sm120.asm)"
"$CUDA/bin/cuobjdump" -sass "$WORK/plain.cubin" > "$WORK/plain.sass"

echo
echo "=== 2/4  encodability BEFORE teaching the repository ==="
python3 gaphash.py 2>&1 | grep -v '^20[0-9][0-9]-' | sed -n '/^region/,$p'

echo
echo "=== 3/4  teach the sm_120 repository from our own SASS ==="
python3 learn.py 2>&1 | grep -E 'loaded|new records|repos now|saved'
cp "$WORK/DefaultInsAsmRepos.sm_120.txt" \
   "$RCASM/cuAssembler/CuAsm/InsAsmRepos/DefaultInsAsmRepos.sm_120.txt"
echo "    installed into the RCAsm tree (keep a backup of the shipped file first)"

echo
echo "=== 4/4  encodability AFTER, then the round-trip byte compare ==="
python3 gaphash.py 2>&1 | grep -v '^20[0-9][0-9]-' | sed -n '/^region/,$p'
python3 rtfull.py 2>&1 | grep -v '^20[0-9][0-9]-' | sed -n '/^neutralized/,/^=== unexplained differing/p'
