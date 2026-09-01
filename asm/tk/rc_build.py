#!/usr/bin/env python3
"""Headless equivalent of RCAsm's editor F5 handler (editor.py on_run_clicked).

argv: <rcasm_root> <project_path> <sm_ver>

Reproduces editor.collect_all_lines() -> compiler.compile_code(liness, is_inject=True)
and nothing else -- it never touches compiler.run_exe. RCAsm ships no batch entry
point: rcasm.py only opens the Qt editor, and compile_code is reachable solely from
the editor's F5 handler.

The project directory must already contain kernel_sm120.cuasm (disassembled template,
with the bare .tkinfo directive commented out) and kernel_sm120.cubin_orig. build.sh
produces both.
"""
import sys, os, types, traceback
from pathlib import Path

ROOT, PROJ, SM = sys.argv[1], sys.argv[2], int(sys.argv[3])

# utils.py imports PyQt5 at module scope (QByteArray/QWidget/QFileDialog) but the
# headless path never calls into any of it, so three empty classes are enough and no
# RCAsm file needs editing.
qtcore = types.ModuleType("PyQt5.QtCore")
qtcore.QByteArray = type("QByteArray", (), {"__init__": lambda self, *a, **k: None})
qtwid = types.ModuleType("PyQt5.QtWidgets")
qtwid.QWidget = type("QWidget", (), {"__init__": lambda self, *a, **k: None})
qtwid.QFileDialog = type("QFileDialog", (), {})
pyqt5 = types.ModuleType("PyQt5"); pyqt5.QtCore = qtcore; pyqt5.QtWidgets = qtwid
sys.modules.update({"PyQt5": pyqt5, "PyQt5.QtCore": qtcore, "PyQt5.QtWidgets": qtwid})

# cuAssembler/CuAsm/__init__.py does `from CuAsm.X import Y`, so cuAssembler/ has to be
# on sys.path for CuAsm to resolve as a TOP-LEVEL package -- importing it only as
# cuAssembler.CuAsm.* fails. This is what RCAsm/cuasm.py does.
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "cuAssembler"))
os.chdir(ROOT)

import defs
defs.SM_VER = SM
defs.PROJECT_PATH = PROJ
defs.AUTO_RUN = False
defs.KERNELS_TO_PROCESS = []
defs.VERBOSE = True

import utils, compiler

# Fix 4 (asm/TESTKERNEL_TEMPLATE.md §6), applied in-process so this build does not
# require the RCAsm checkout to have been edited.
#
# The device linker rewrites .nv.reservedSmem.offset0's symbol type from STT_OBJECT(1)
# to the CUDA-specific STT_CUDA_OBJECT(13), and CuAsmParser's validation table knows
# only four types -- so ANY -rdc device-linked template dies at reassembly with
# "Unknown symbol type". Safe: the table is validation-only. __updateSymtab writes
# st_value and st_size and copies st_info verbatim from the source cubin, so the
# number here is never used to construct anything.
_added = []
for _modname in ("CuAsm.CuAsmParser", "cuAssembler.CuAsm.CuAsmParser"):
    try:
        _m = __import__(_modname, fromlist=["CuAsmSymbol"])
        if '@"STT_CUDA_OBJECT"' not in _m.CuAsmSymbol.SymbolTypes:
            _m.CuAsmSymbol.SymbolTypes['@"STT_CUDA_OBJECT"'] = 13
            _added.append(_modname)
    except Exception:
        pass
print("  STT_CUDA_OBJECT registered in:", _added or "(already present)")

# Fix 3, likewise in-process. patch_cubin restores note sections from the original
# cubin after reassembly, but it asks for .note.nv.cuver unconditionally and that
# section DOES NOT EXIST in CUDA 13.0 cubins -- verified directly: a fresh
# -arch=sm_120 -cubin carries exactly .note.nv.tkinfo and .note.nv.cuinfo, nothing
# else. So it raises KeyError after a fully successful assembly.
#
# The second half matters as much: .note.nv.cuinfo has to be ADDED to the copy list.
# The round-trip truncates it 0x20 -> 0x08 bytes, which is data loss rather than a
# formatting quibble, and restoring it is what makes nvdisasm accept the result.
from elftools.elf.elffile import ELFFile as _ELF

def _sections(path):
    with open(str(path), "rb") as f:
        return {s.name for s in _ELF(f).iter_sections()}

def _patch_cubin(cubin_orig, cubin_new, cubin_out):
    want = [".note.nv.tkinfo", ".note.nv.cuver", ".note.nv.cuinfo"]
    have = _sections(cubin_orig) & _sections(cubin_new)
    names = [n for n in want if n in have]
    print("  patch_cubin: copying %s (skipped %s)"
          % (names, [n for n in want if n not in names]))
    return compiler.replace_sections_data(cubin_orig, cubin_new, names, cubin_out)

compiler.patch_cubin = _patch_cubin

# Two traps, both silent. config.py hardcodes NVDISASM_PATH to CUDA 12.8. And
# Config.SM_VER defaults to 89, which gates the two sm_120-only encoders in
# NewOpsHandler.check_new_ops -- that alone accounted for 304 phantom "missing"
# instructions in an earlier measurement. The package is reachable under two names
# whose Config objects have been measured to be DISTINCT, so set both and say which.
import CuAsm.config as c1
c1.Config.NVDISASM_PATH = os.environ.get("NVDISASM", "/usr/local/cuda/bin/nvdisasm")
c1.Config.SM_VER = SM
try:
    import cuAssembler.CuAsm.config as c2
    c2.Config.NVDISASM_PATH = c1.Config.NVDISASM_PATH
    c2.Config.SM_VER = SM
    print("  Config identity: CuAsm.config is cuAssembler.CuAsm.config ->", c1.Config is c2.Config)
except Exception as e:
    print("  Config identity: second import failed:", e)

# Surface everything RCAsm would have shown in the GUI log pane.
_orig_log = utils.to_log
def loud(*a, **k):
    try:
        print("  [rcasm]", " ".join(str(x) for x in a))
    except Exception:
        pass
    return _orig_log(*a, **k)
utils.to_log = loud
compiler.utils.to_log = loud

files = utils.get_project_files(defs.PROJECT_PATH)
print("  sources:", [Path(f).name for f in files])
if not files:
    sys.exit("  no .asm sources found in " + PROJ)

liness = [(utils.PreprocessLines(utils.load_list_from_file(f)), Path(f).name) for f in files]

try:
    ok = compiler.compile_code(liness, True)
except Exception as e:
    print("  EXCEPTION %s: %s" % (type(e).__name__, str(e)[:600]))
    traceback.print_exc()
    sys.exit(2)

print("  RESULT:", "SUCCESS" if ok else "FAILED")
sys.exit(0 if ok else 1)
