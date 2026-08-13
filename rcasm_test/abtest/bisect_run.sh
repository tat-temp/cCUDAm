#!/bin/bash
# Run the four-variant ladder and say which construct faults.
#
#   ./bisect_run.sh
#
#   id     identity only         -- if this faults, the fault is in the prologue/IO
#   local  + STL/LDL             -- if only this and full fault, it is local memory
#   call   + call_func           -- if only this and full fault, it is the call
#   full   both                  == stage 1b
#   sufp   + the suffix-product ladder (stage 2a): a real loop, dynamically indexed
#          constant loads, STL at a computed address. Run against its OWN compiled
#          counterpart and its own oracle, so unlike the rungs below it a mismatch here
#          is a real failure rather than an expected one.
#
# A mismatch verdict is EXPECTED for id/local: they compute different things from the
# compiled kernel by construction. The only thing being read on those rungs is whether
# the LAUNCH completes. call, full and sufp are held to the answers.
#
# ANSWERED 2026-08-14. local and full faulted, id and call did not, which named the
# .128 local access -- Prod was bound to R50 and a .128 op needs a register that is a
# multiple of 4. Fixed by moving Prod to R52; asm/tk/align_check.sh now catches the whole
# class without a GPU. Kept because stage 2 adds far more of both constructs, and because
# the run also produced the first real result: `call` matched the compiled kernel EXACTLY
# (253 EXACT / 3 non-canonical / 0 wrong, same as side A), so call_func and MulMod256 are
# both correct on hardware.
cd "$(dirname "$0")"
[ -x ./abtest ] || { echo "build first: ./build.sh"; exit 1; }

fault=""
for n in id local call full sufp; do
    f="../../asm/tk/TestKernel_$n.cubin"
    printf '######## %-5s ' "$n"
    if [ ! -f "$f" ]; then echo "-- MISSING $f"; continue; fi
    if [ "$n" = sufp ]; then
        out=$(./abtest ab_compiled_sufp.cubin "$f" 256 1 sufp 2>&1)
    else
        out=$(./abtest ab_compiled.cubin "$f" 256 1 mul 2>&1)
    fi
    err=$(echo "$out" | grep -E 'cuCtxSynchronize \(kernel\)|cuModuleLoad|cuLaunchKernel' | head -1)
    if [ -n "$err" ]; then
        echo "########"
        echo "  KERNEL FAULTED:$err"
        [ -z "$fault" ] && fault="$n"
    else
        echo "########"
        echo "  launch completed"
        echo "$out" | grep -E 'EXACT|identity check|subp\[half-1\]|A and B' | sed 's/^/  /'
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
