#!/bin/bash
# Build the A/B pair: the compiled TestKernel cubin and the host harness.
# The hand-written side comes from asm/tk/build.sh and is not rebuilt here.
set -e
cd "$(dirname "$0")"
CUDA="${CUDA:-/usr/local/cuda}"
F="-O3 -use_fast_math --ptxas-options=-O3 -std=c++17 -gencode arch=compute_120,code=sm_120"

# Two-step device link, matching how the injection template is built: -rdc=true is what
# gives the five __constant__ tables GLOBAL binding so cuModuleGetGlobal can find them,
# and the single-step -rdc=true -cubin emits ELF type REL, which cuModuleLoad rejects.
build_one() {   # build_one <out.cubin> [extra nvcc flags]
    local out="$1"; shift
    "$CUDA/bin/nvcc" $F "$@" -rdc=true -c     -o ab_kernel.o "$PWD/ab_kernel.cu"
    "$CUDA/bin/nvcc" $F      -rdc=true -dlink -cubin -o "$out" ab_kernel.o
    rm -f ab_kernel.o
    printf '  %-22s ' "$out"
    "$CUDA/bin/cuobjdump" -res-usage "$out" | grep -oE "REG:[0-9]+ STACK:[0-9]+"
}

echo "--- compiled kernels ---"
build_one ab_compiled.cubin                      # stage 1b: one mul_mod
build_one ab_compiled_sufp.cubin -DSTAGE_SUFP=1  # stage 2a: the suffix-product ladder
build_one ab_compiled_inv.cubin  -DSTAGE_INV=1   # stage 2b: the ladder plus one inv_mod
build_one ab_compiled_walk.cubin -DSTAGE_WALK=1  # stage 2c-i: the inverse chain

g++ -O2 -std=c++17 -I"$CUDA/include" -o abtest abtest.cpp \
    -L"$CUDA/lib64" -L"$CUDA/lib64/stubs" -lcuda

# The oracle decides right from wrong, so check it here rather than on the GPU host --
# and it does not need a driver to run. On a machine without one (WSL), the loader still
# wants libcuda.so.1; the stub that -lcuda linked against supplies every symbol, and
# --selftest returns before the first cuInit, so pointing the loader at a symlinked copy
# is enough to run the whole oracle with no GPU present.
echo
if ! ./abtest --selftest 2>/dev/null; then
    D=$(mktemp -d); ln -sf "$CUDA/lib64/stubs/libcuda.so" "$D/libcuda.so.1"
    LD_LIBRARY_PATH="$D" ./abtest --selftest || { echo "ORACLE SELFTEST FAILED"; exit 1; }
    rm -rf "$D"
fi

echo
echo "built: ab_compiled{,_sufp,_inv,_walk}.cubin, abtest"
echo
echo "run:  ./abtest ab_compiled.cubin      ../../asm/tk/TestKernel.cubin      256 1 mul"
echo "      ./abtest ab_compiled_sufp.cubin ../../asm/tk/TestKernel_sufp.cubin 256 1 sufp"
echo "      ./abtest ab_compiled_inv.cubin  ../../asm/tk/TestKernel_inv.cubin  256 1 inv"
echo "      ./abtest ab_compiled_walk.cubin ../../asm/tk/TestKernel_walk.cubin 256 1 walk"
