#!/bin/bash
# Build the four-variant bisect ladder for the ILLEGAL_INSTRUCTION fault.
#
#   RCASM=/path/to/RCAsm ./bisect.sh
#
# Produces TestKernel_{id,local,call,full}.cubin. Run each on the GPU; the first one
# that faults names the construct responsible.
set -e
cd "$(dirname "$0")"
: "${RCASM:?set RCASM to the RCAsm checkout}"
V="${WORK:-/tmp/tkbuild}/variants"
mkdir -p "$V"
python3 variants.py main.asm "$V"
echo
for n in id local call full; do
    echo "######## $n ########"
    MAIN="$V/main_$n.asm" OUTNAME="TestKernel_$n.cubin" WORK="${WORK:-/tmp/tkbuild}/b_$n" \
        ./build.sh 2>&1 | grep -E "^wrote|REG:|instruction count" -A1 | grep -vE '^--$' || true
    echo
done
echo "Run each against the compiled kernel; the first fault names the cause:"
for n in id local call full; do
    echo "  ./abtest ab_compiled.cubin ../../asm/tk/TestKernel_$n.cubin 256"
done
