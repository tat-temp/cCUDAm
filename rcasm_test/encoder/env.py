#!/usr/bin/env python3
"""Shared setup for the three encoder probes. Import first, before any CuAsm.

Environment:
  RCASM       path to the RCAsm checkout (the one containing cuAssembler/).  required
  PYDEPS      extra sys.path entry for pyelftools/sympy, if they are not installed.
  WORK        scratch directory for generated files.  default /tmp/rcenc
  KERNEL_ASM  the cuasm dump of TestKernel.  default <repo>/asm/GpuCore_sm120.asm
  NVDISASM    default /usr/local/cuda/bin/nvdisasm

Two fixes must already be applied to the RCAsm tree or nothing here runs:
  config.py     NVDISASM_PATH repointed off CUDA 12.8   (fix 1)
  CuInsFeeder.py:639  getMajor() in {7,8}  ->  >= 7     (fix 6, learn.py only)
"""
import sys, os

RCASM = os.environ.get("RCASM")
if not RCASM:
    sys.exit("set RCASM to the RCAsm checkout (the directory containing cuAssembler/)")
sys.path.insert(0, os.path.join(RCASM, "cuAssembler"))
if os.environ.get("PYDEPS"):
    sys.path.insert(0, os.environ["PYDEPS"])

WORK = os.environ.get("WORK", "/tmp/rcenc")
os.makedirs(WORK, exist_ok=True)

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KERNEL_ASM = os.environ.get("KERNEL_ASM", os.path.join(REPO, "asm", "GpuCore_sm120.asm"))
NVDISASM = os.environ.get("NVDISASM", "/usr/local/cuda/bin/nvdisasm")

SASS = os.path.join(WORK, "plain.sass")      # cuobjdump -sass of the plain cubin
CUBIN = os.path.join(WORK, "plain.cubin")    # the plain (non -rdc) sm_120 cubin
REPOS_OUT = os.path.join(WORK, "DefaultInsAsmRepos.sm_120.txt")

# The two __noinline__ hash bodies inside .text.TestKernel, first..last address.
# Read off the symbol table: getHash160_33 st_value 94688 size 32720,
# getHash160_w2 st_value 127408 size 32336.
H33 = (0x171e0, 0x1f1a0)
HW2 = (0x1f1b0, 0x26ff0)


def region(addr):
    if H33[0] <= addr <= H33[1]:
        return "getHash160_33"
    if HW2[0] <= addr <= HW2[1]:
        return "getHash160_w2"
    return "rest of TestKernel"


def configure():
    from CuAsm.config import Config
    Config.NVDISASM_PATH = NVDISASM
    Config.SM_VER = 120          # defaults to 89; gates the sm_120 encoders
    return Config
