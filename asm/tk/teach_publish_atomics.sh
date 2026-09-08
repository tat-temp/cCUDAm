#!/bin/bash
# Teach the RCAsm sm_120 InsAsmRepos the instructions publish_found needs, which its default basis
# cannot encode ("Insufficient basis"): ATOMG.E.CAS.STRONG.SYS and the MEMBAR/ERRBAR/CGAERRBAR fence.
# Correct-by-construction: samples are real nvcc-emitted encodings. ADDITIVE -- verified by Gate-1
# (points-only TestKernel.cubin rebuilds byte-identical, md5 683667b228313cafa97a5f2f6a323508).
# Run this ONCE before build_full.sh; the repo edit persists in the RCAsm checkout.
#
#   RCASM=/path/to/RCAsm CUDA=/usr/local/cuda-13.0 ./teach_publish_atomics.sh
#
# Sources: GpuCore.cubin (the compiled full kernel -> the fence ops, correct register set) and
# cas_train2.cu (a 40x chained atomicCAS_system microbench under __launch_bounds__(64,1) -> the
# REGISTER VARIETY the CAS encoding needs; GpuCore's 4 CAS all reuse one register set). The
# atomicExch SYS form is intentionally NOT taught (its desc+offset operand does not verify-round-
# trip); publish uses a fence-ordered STG.E for the found flag instead.
set -e
: "${RCASM:?set RCASM to the RCAsm checkout}"
CUDA="${CUDA:-/usr/local/cuda}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$RCASM/cuAssembler/CuAsm/InsAsmRepos/DefaultInsAsmRepos.sm_120.txt"
ROOT="$(cd "$HERE/../.." && pwd)"
export PYTHONPATH="$RCASM/cuAssembler${PYDEPS:+:$PYDEPS}"
W="$(mktemp -d)"

# GpuCore.cubin (full kernel) -- build if absent (gitignored)
[ -f "$ROOT/GpuCore.cubin" ] || ( cd "$ROOT" && make cubin SM=120 CUBIN_FILE=GpuCore.cubin >/dev/null )
"$CUDA/bin/cuobjdump" -sass "$ROOT/GpuCore.cubin" 2>/dev/null > "$W/gc.sass"

# CAS register-variety microbench
"$CUDA/bin/nvcc" -O3 -std=c++17 -gencode arch=compute_120,code=sm_120 -rdc=true -c -o "$W/mb.o" "$HERE/cas_train2.cu"
"$CUDA/bin/nvcc" -rdc=true -dlink -cubin -gencode arch=compute_120,code=sm_120 -o "$W/mb.cubin" "$W/mb.o"
"$CUDA/bin/cuobjdump" -sass "$W/mb.cubin" 2>/dev/null > "$W/mb.sass"

[ -f "$REPO.orig.bak" ] || cp "$REPO" "$REPO.orig.bak"
python3 - "$REPO" "$W/gc.sass" "$W/mb.sass" <<'PY'
import sys
from CuAsm.CuInsAssemblerRepos import CuInsAssemblerRepos
from CuAsm.CuInsFeeder import CuInsFeeder
from CuAsm.config import Config
Config.SM_VER = 120
repo, gc, mb = sys.argv[1:4]
r = CuInsAssemblerRepos(repo, arch='sm_120')
r.update(CuInsFeeder(gc, insfilter=r'(MEMBAR|ERRBAR|CGAERRBAR)'))
r.update(CuInsFeeder(mb, insfilter=r'ATOMG\.E\.CAS\.STRONG\.SYS'))
r.verify(CuInsFeeder(gc, insfilter=r'(MEMBAR|ERRBAR|CGAERRBAR)'))
r.verify(CuInsFeeder(mb, insfilter=r'ATOMG\.E\.CAS\.STRONG\.SYS'))
r.save2file(repo)
print("taught + verified: ATOMG.E.CAS.STRONG.SYS + MEMBAR/ERRBAR/CGAERRBAR")
PY
rm -rf "$W"
