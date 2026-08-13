#!/bin/bash
# Check the hardware register-alignment rule on every memory op in a cubin.
#
#   ./align_check.sh TestKernel.cubin [more.cubin ...]
#
# A .128 access needs its DATA register operand to be a multiple of 4; a .64 access needs
# it even. Nothing in the RCAsm path enforces this -- not the dialect, not cuAssembler,
# not the ELF writer. The register number is encoded exactly as written and the first
# sign of a violation is CUDA_ERROR_ILLEGAL_INSTRUCTION at launch, from a kernel that
# loads, reports the right register and frame usage, and disassembles cleanly.
#
# That is how it was found: stage 1b put Prod at R50, so `STL.128 [R1], R50` assembled
# and killed the launch, while the identical stream with those four instructions removed
# ran fine. Costs a rebuild to check, costs a GPU round trip and a bisect ladder not to.
#
# Address registers are excluded -- the [R1] in `STL.128 [R1], R52` carries no alignment
# requirement on the register NUMBER (the address VALUE must be 16-byte aligned, which is
# a separate property this cannot see). So the bracketed part is stripped first.
#
# Exit 1 if anything is misaligned, so it can gate a build.
CUDA="${CUDA:-/usr/local/cuda}"
rc=0

scan() {   # scan <cubin> <width> <divisor>
    "$CUDA/bin/cuobjdump" -sass "$1" \
        | grep -oP "^\s+/\*[0-9a-f]+\*/\s+\K[^;]*\.$2\b[^;]*" \
        | grep -P '^\s*@?!?P?T?\s*(LDL|STL|LDS|STS|LDG|STG|LDC)' \
        | sed 's/\[[^]]*\]//g' \
        | grep -oP '\bR\d+' | tr -d 'R' | awk -v d="$3" '$1 % d != 0' | sort -un | tr '\n' ' '
}

for f in "$@"; do
    if [ ! -f "$f" ]; then echo "$f: MISSING"; rc=1; continue; fi
    b128=$(scan "$f" 128 4)
    b64=$(scan "$f" 64 2)
    if [ -z "$b128" ] && [ -z "$b64" ]; then
        printf 'OK    %s\n' "$f"
    else
        rc=1
        printf 'BAD   %s\n' "$f"
        [ -n "$b128" ] && printf '        .128 ops on non-multiple-of-4 registers: R%s\n' \
            "$(echo $b128 | sed 's/ /, R/g')"
        [ -n "$b64" ]  && printf '        .64  ops on odd registers: R%s\n' \
            "$(echo $b64 | sed 's/ /, R/g')"
    fi
done
exit $rc
