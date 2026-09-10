#!/bin/bash
# Teach the RCAsm sm_120 InsAsmRepos plain 32-bit IADD (keys IADD_R_R_R / IADD_R_R_II) in the forms the
# CUDA-13.3-lifted getHash160 uses: IADD Rd,Ra,Rb / Rd,Ra,imm / Rd,-Ra,imm, with .reuse on sources and
# source negation. The stock repo trained IADD only on IADD.64 samples (0_64 folded into the base; no
# 2_reuse/2_cNEG columns) so plain IADD is a HARD error ("Unknown modifiers: {2_reuse}"). Samples are the
# real nvcc-13.3 encodings in GpuCore_133.cubin (committed; 13.3 codegen can't be reproduced on the 13.0
# dev box). ADDITIVE + verify()-gated. Run ONCE (with teach_publish_atomics.sh) before build_full.sh.
#
#   RCASM=/path/to/RCAsm CUDA=/usr/local/cuda-13.0 ./teach_iadd.sh
#
# GOTCHA (do not widen the filter): feeding the FULL IADD set (incl. IADD.64.X ~R carry chains) re-solves
# those keys and DROPS the complement bit -> corrupts the walk (verify() catches it). The NARROW filter
# 'IADD R\d+, -?R' (plain, non-predicate) touches ONLY IADD_R_R_R / IADD_R_R_II; the existing IADD.64
# records stay in the repo so the 0_64 bit still separates. CuInsFeeder needs the COMPLETE -sass (not a
# grep of instruction lines), so we disassemble the committed cubin here rather than ship a samples file.
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
FILT = r'IADD R\d+, -?R'   # plain non-predicate IADD only; excludes .64/.X (dot) and IADD3 (no space)
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
print("taught + verified: plain IADD (IADD_R_R_R / IADD_R_R_II) + .reuse + source-neg")
PY
rm -rf "$W"
echo "teach_iadd done"
