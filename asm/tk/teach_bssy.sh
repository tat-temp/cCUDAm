#!/bin/bash
# Teach the RCAsm sm_120 InsAsmRepos the convergence-barrier ops BSSY (`BSSY Bn, TARGET`, opcode 0x7945)
# and BSYNC (`BSYNC Bn`, opcode 0x7941), plain and .RECONVERGENT. The manual FULL kernel wraps each hash
# filter's divergent @!P2/@!P3 skip in a BSSY..BSYNC pair (the HANG fix -- mirrors nvcc's own
# if(__any_sync) publish block, which uses `BSSY B7,tgt`/`BSYNC B7`) so the spurious-w2 divergence
# RECONVERGES at .hskip before the next batch's InvMod256 (BRA.CONV ~URZ), instead of deadlocking.
# BSSY/BSYNC were NEW opcodes (0 in the tree) -> teach or NewOpsHandler silently mis-encodes
# ([[sm120-ldc-64bit-cap]]). Samples are the real nvcc encodings in GpuCore_133.cubin (committed);
# they vary barrier reg (B0/B1/B6/B7/B9), the .RECONVERGENT bit, and the BSSY target offset, so the
# linear basis spans those fields (incl. the plain BSSY B0 / BSYNC B0 combos this kernel uses).
# ADDITIVE + verify()-gated. Convergence barriers `B#` are a native RCAsm operand type (UserGuide).
set -e
: "${RCASM:?set RCASM to the RCAsm checkout}"
CUDA="${CUDA:-/usr/local/cuda}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$RCASM/cuAssembler/CuAsm/InsAsmRepos/DefaultInsAsmRepos.sm_120.txt"
export PYTHONPATH="$RCASM/cuAssembler${PYDEPS:+:$PYDEPS}"
CUBIN="$HERE/GpuCore_133.cubin"
[ -f "$CUBIN" ] || { echo "missing $CUBIN (the CUDA-13.3 teaching source)"; exit 1; }
W="$(mktemp -d)"; "$CUDA/bin/cuobjdump" -sass "$CUBIN" 2>/dev/null > "$W/gc133.sass"

[ -f "$REPO.orig.bak" ] || cp "$REPO" "$REPO.orig.bak"
python3 - "$REPO" "$W/gc133.sass" <<'PY'
import sys, logging
from CuAsm.CuInsAssemblerRepos import CuInsAssemblerRepos
from CuAsm.CuInsFeeder import CuInsFeeder
from CuAsm.config import Config
Config.SM_VER = 120
repo, sass = sys.argv[1], sys.argv[2]
FILT = r'\bBS(SY|YNC)\b'   # BSSY (0x7945) and BSYNC (0x7941), plain + .RECONVERGENT
r = CuInsAssemblerRepos(repo, arch='sm_120')
r.update(CuInsFeeder(sass, insfilter=FILT))
errs = {'n': 0}
_e = logging.getLogger().error
logging.getLogger().error = lambda *a, **k: errs.__setitem__('n', errs['n'] + 1)
r.verify(CuInsFeeder(sass, insfilter=FILT))
logging.getLogger().error = _e
if errs['n']:
    print("*** verify FAILED (%d errors) -- NOT saving ***" % errs['n']); sys.exit(3)
r.save2file(repo)
print("taught + verified: BSSY Bn,TARGET + BSYNC Bn (plain + .RECONVERGENT)")
PY
rm -rf "$W"
echo "teach_bssy done"
