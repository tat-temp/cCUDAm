#!/bin/bash
# Build the four-variant bisect ladder for the ILLEGAL_INSTRUCTION fault.
#
#   RCASM=/path/to/RCAsm ./bisect.sh
#
# Produces TestKernel_{id,local,call,full,sufp,inv}.cubin. Run each on the GPU; the first one
# that faults names the construct responsible.
set -e
cd "$(dirname "$0")"
# See build.sh: this REBUILDS the ladder from source and is not what you run to exercise it.
# The cubins are committed. To run the ladder:
#     cd rcasm_test/abtest && ./build.sh && ./bisect_run.sh
if [ -z "$RCASM" ]; then
    echo "RCASM is not set. This script re-assembles the .asm sources; you do not need it to" >&2
    echo "run the ladder -- the cubins are committed:" >&2
    echo "    cd rcasm_test/abtest && ./build.sh && ./bisect_run.sh" >&2
    exit 1
fi
V="${WORK:-/tmp/tkbuild}/variants"
mkdir -p "$V"
VARIANTS="${VARIANTS:-id local call full sufp inv walk pts jump loop}"
python3 variants.py main.asm "$V" $VARIANTS
echo
for n in $VARIANTS; do
    echo "######## $n ########"
    MAIN="$V/main_$n.asm" OUTNAME="TestKernel_$n.cubin" WORK="${WORK:-/tmp/tkbuild}/b_$n" \
        ./build.sh 2>&1 | grep -E "^wrote|REG:|instruction count" -A1 | grep -vE '^--$' || true
    echo
done
echo "Run each against the compiled kernel; the first fault names the cause:"
for n in $VARIANTS; do
    case "$n" in
        sufp|inv|walk|pts|jump|loop) echo "  ./abtest ab_compiled_$n.cubin ../../asm/tk/TestKernel_$n.cubin 256 1 $n" ;;
        *)        echo "  ./abtest ab_compiled.cubin ../../asm/tk/TestKernel_$n.cubin 256" ;;
    esac
done
