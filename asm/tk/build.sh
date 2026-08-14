#!/bin/bash
# Build asm/tk/main.asm into a loadable TestKernel.cubin via RCAsm injection.
#
#   RCASM=/path/to/RCAsm ./build.sh
#
# The RCAsm tree needs the four fixes from asm/TESTKERNEL_TEMPLATE.md §6 applied, and
# most likely the taught sm_120 repository from rcasm_test/encoder/ as well: Kernel02's
# sources have only ever been through RCAsm's front end, never actually assembled, so
# their instruction forms are unproven against the shipped encoder repository.
set -e
cd "$(dirname "$0")"
: "${RCASM:?set RCASM to the RCAsm checkout (the directory containing cuAssembler/)}"
CUDA="${CUDA:-/usr/local/cuda}"
WORK="${WORK:-/tmp/tkbuild}"
ASM="$(cd .. && pwd)"          # repo asm/ -- holds Kernel02's mod_*.asm
OUT="$(pwd)"

rm -rf "$WORK" && mkdir -p "$WORK"

# The project directory is assembled rather than committed: RCAsm concatenates EVERY
# .asm in PROJECT_PATH, and asm/ also holds Kernel02's main.asm/fuse.asm/newKernelB.asm,
# which declare their own KERNELs. Copying just the three arithmetic units keeps
# Kernel02's sources as the single copy instead of duplicating 70 KB into the repo.
cp "$ASM/mod_mul.asm" "$ASM/mod_sub.asm" "$ASM/mod_inv.asm" "$WORK"/
# MAIN selects the kernel source (variants.py generates a bisect ladder); OUTNAME names
# the resulting cubin. Defaults reproduce the committed TestKernel.cubin.
MAIN="${MAIN:-$OUT/main.asm}"
OUTNAME="${OUTNAME:-TestKernel.cubin}"
cp "$MAIN" "$WORK"/main.asm
echo "project: $(cd "$WORK" && ls *.asm | tr '\n' ' ')   (kernel from $MAIN)"

# 1. Template -> cubin. Two-step device link, not `-rdc=true -cubin`: the single-step
#    form emits ELF type REL with undefined symbols and cuModuleLoad takes only EXEC.
#    -rdc is what gives the five __constant__ tables GLOBAL binding so the host can
#    find them with cuModuleGetGlobal; extern "C" alone does not (measured).
F="-O3 -std=c++17 -gencode arch=compute_120,code=sm_120"
"$CUDA/bin/nvcc" $F -rdc=true -c   -o "$WORK/tmpl.o" "$ASM/tmpl_TestKernel.cu"
"$CUDA/bin/nvcc" $F -rdc=true -dlink -cubin -o "$WORK/kernel_sm120.cubin" "$WORK/tmpl.o"
cp -f "$WORK/kernel_sm120.cubin" "$WORK/kernel_sm120.cubin_orig"

echo "--- template ---"
readelf -h "$WORK/kernel_sm120.cubin" 2>/dev/null | grep -E "Type:|Flags:"
"$CUDA/bin/cuobjdump" -res-usage "$WORK/kernel_sm120.cubin" | grep -E "REG:|STACK:"

# 2. cubin -> cuasm, in-process.
#
#    NOT `bin/cuasm.py`: that is a separate process, so it picks up config.py's
#    hardcoded NVDISASM_PATH = /usr/local/cuda-12.8/bin/nvdisasm ("ONLY 12.8 IS
#    TESTED!") and dies with FileNotFoundError before doing anything. Setting Config
#    here instead means this build does not require fix 1 to have been applied to the
#    RCAsm tree -- one less unversioned precondition. Step 4 runs in-process too and
#    sets the same thing.
export PYTHONPATH="$RCASM/cuAssembler${PYDEPS:+:$PYDEPS}"
NVDISASM="${NVDISASM:-$CUDA/bin/nvdisasm}" python3 - "$WORK/kernel_sm120.cubin" "$WORK/kernel_sm120.cuasm" <<'PY'
import os, sys
from CuAsm import CubinFile
from CuAsm.config import Config
Config.NVDISASM_PATH = os.environ["NVDISASM"]
Config.SM_VER = 120
CubinFile(sys.argv[1]).saveAsCuAsm(sys.argv[2])
print("disassembled -> %s" % sys.argv[2])
PY

# 3. Neutralize the bare .tkinfo directive. CUDA 13's nvdisasm emits a directive
#    CuAsmParser has no handler for; the string appears nowhere in cuAssembler. Only
#    the single bare line -- the other matches are comments. Without this, parse()
#    asserts, cuasm2cubin swallows it into False, and create_cubin returns before
#    patch_cubin is ever reached (which is why the .cuver KeyError went unobserved).
python3 - "$WORK/kernel_sm120.cuasm" <<'PY'
import re, sys
p = sys.argv[1]
L = open(p).read().splitlines()
n = 0
for i, ln in enumerate(L):
    if re.match(r"^\s*\.tkinfo\s*$", ln):
        L[i] = "//" + ln; n += 1
open(p, "w").write("\n".join(L) + "\n")
print("neutralized .tkinfo x%d" % n)
PY

# 4. Compile main.asm and inject it, then reassemble and patch the note sections back.
python3 "$OUT/rc_build.py" "$RCASM" "$WORK" 120

# 5. Results.
cp -f "$WORK/kernel_sm120.cubin" "$OUT/$OUTNAME"
echo "--- injected ---"
readelf -h "$OUT/$OUTNAME" 2>/dev/null | grep -E "Type:|Flags:"
"$CUDA/bin/cuobjdump" -res-usage "$OUT/$OUTNAME"
echo "--- instruction count ---"
"$CUDA/bin/cuobjdump" -sass "$OUT/$OUTNAME" | grep -cP '^\s+/\*[0-9a-f]+\*/' || true

# 6. Register alignment. A .128 access needs a register that is a multiple of 4 and a .64
#    needs an even one; nothing in the RCAsm path checks, so a violation assembles fine
#    and dies at LAUNCH with CUDA_ERROR_ILLEGAL_INSTRUCTION. Not fatal to the build --
#    the cubin is still worth having to look at -- but it must be impossible to miss.
echo "--- register alignment ---"
CUDA="$CUDA" "$OUT/align_check.sh" "$OUT/$OUTNAME" || {
    echo "  ^^ THIS WILL FAULT AT LAUNCH. See asm/tk/README.md."
}

# 7. Stall counts. Fixed-latency instructions set no scoreboard barrier, so an
#    under-stalled dependency reads the PREVIOUS value -- an illegal address if it is an
#    address, a wrong answer if it is not. Neither is diagnosable from the listing.
echo "--- stall counts ---"
CUDA="$CUDA" python3 "$OUT/stall_check.py" "$OUT/$OUTNAME" || {
    echo "  ^^ under-stalled dependencies: the consumer may read a STALE value."
}
echo "--- scoreboard barriers ---"
CUDA="$CUDA" python3 "$OUT/barrier_check.py" "$OUT/$OUTNAME" || {
    echo "  ^^ over-subscribed or unwaited barrier: the load may not have LANDED."
}

echo "--- branch and return targets ---"
CUDA="$CUDA" python3 "$OUT/pc_check.py" "$OUT/$OUTNAME" || {
    echo "  ^^ CUDA_ERROR_INVALID_PC at launch. Nothing else in this build will say so."
}
echo
echo "wrote $OUT/$OUTNAME"
echo "NOTE: use cuobjdump, not nvdisasm -- nvdisasm refuses any kernel containing BRXU,"
echo "      which is RCAsm's own call/loop idiom."
