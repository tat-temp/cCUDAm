#!/bin/bash
# Run the four-variant ladder and say which construct faults.
#
#   ./bisect_run.sh
#
# The full stage-1b kernel dies with CUDA_ERROR_ILLEGAL_INSTRUCTION. It contains exactly
# two things the identity kernel does not, so:
#
#   id     identity only         -- if this faults, the fault is in the prologue/IO
#   local  + STL/LDL             -- if only this and full fault, it is local memory
#   call   + call_func           -- if only this and full fault, it is the call
#   full   both
#
# A mismatch verdict is EXPECTED for id/local/call: they compute different things from
# the compiled kernel by construction. The only thing being read here is whether the
# LAUNCH completes.
cd "$(dirname "$0")"
[ -x ./abtest ] || { echo "build first: ./build.sh"; exit 1; }

fault=""
for n in id local call full; do
    f="../../asm/tk/TestKernel_$n.cubin"
    printf '######## %-5s ' "$n"
    if [ ! -f "$f" ]; then echo "-- MISSING $f"; continue; fi
    out=$(./abtest ab_compiled.cubin "$f" 256 2>&1)
    err=$(echo "$out" | grep -E 'cuCtxSynchronize \(kernel\)|cuModuleLoad|cuLaunchKernel' | head -1)
    if [ -n "$err" ]; then
        echo "########"
        echo "  KERNEL FAULTED:$err"
        [ -z "$fault" ] && fault="$n"
    else
        echo "########"
        echo "  launch completed"
        echo "$out" | grep -E 'EXACT|NON-CANON|identity check' | sed 's/^/  /'
    fi
done

echo
if [ -z "$fault" ]; then
    echo "No variant faulted."
else
    echo "First fault: $fault"
    case "$fault" in
      id)    echo "  -> prologue / parameter offsets / global addressing / frame setup" ;;
      local) echo "  -> the local-memory round trip (STL/LDL against R1)" ;;
      call)  echo "  -> call_func: the BRXU call/return idiom or MulMod256's body" ;;
      full)  echo "  -> only the combination fails, which points at register or"
             echo "     barrier interference between the call and the local access" ;;
    esac
fi
