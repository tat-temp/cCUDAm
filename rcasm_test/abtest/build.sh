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
"$CUDA/bin/nvcc" $F -rdc=true -c     -o ab_kernel.o     ab_kernel.cu
"$CUDA/bin/nvcc" $F -rdc=true -dlink -cubin -o ab_compiled.cubin ab_kernel.o
rm -f ab_kernel.o
echo "--- compiled kernel ---"
"$CUDA/bin/cuobjdump" -res-usage ab_compiled.cubin | grep -E "REG:|STACK:"

g++ -O2 -std=c++17 -I"$CUDA/include" -o abtest abtest.cpp \
    -L"$CUDA/lib64" -L"$CUDA/lib64/stubs" -lcuda
echo
echo "built: ab_compiled.cubin, abtest"
echo
echo "run:  ./abtest ab_compiled.cubin ../../asm/tk/TestKernel.cubin 256"
