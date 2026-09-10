#!/usr/bin/env python3
"""`IADD3.X Rd, P, P, Ra, [~]URb, Rc, P, P` for sm_120 -- the borrow chain with its second
source in a uniform register. Installed in-process by `rc_build.py`, next to `ldcu_sm120`.

Why it is needed: the walk reads `c_Gx`/`c_Gy`/`c_GyNeg` into a subtract, not into the
multiply -- `SubMod256` is `RFirst + ~RSecond + RZ` and `SubMod256_3` is
`RFirst + ~RSecond + ~RThird`. Moving the table into a uniform register therefore means
putting it in the **b** slot, the only slot a UR may occupy, which gives

    SubMod256    Ro = RZ  +  uTab + ~Pnt   + carry
    SubMod256_3  Ro = Sqr + ~uTab + ~Pnt   + carries

Both are `IADD3_R_P_P_R_UR_R_P_P`, a key RCAsm has no record for and no compiler emits.

The encoding is not guessed: RCAsm's own `NewOpsHandler.IADD3_R_P_P_R_R_R_P_P` builds the
register form, and operand b is re-classed as uniform by one measured delta --

    bits 9, 10, 11, 91   b operand is a UR   (XOR of `IADD3 …, R20, …` and `…, UR20, …`)

with the `~` on b staying where the register form already puts it (bit 63, `5_cINV`). The
b index occupies bits 32-39 either way. Everything else -- destination, predicates, the `~`
on a and c, the stall and barrier bits -- is whatever RCAsm already produced.

Self-check, GPU-free: builds a spread of these instructions and hands each to
`nvdisasm --binary SM120`, which is the only independent reader of the encoding.

    python3 iadd3ur_sm120.py
"""
import os
import subprocess
import sys

KEY = "IADD3_R_P_P_R_UR_R_P_P"
REG_KEY = "IADD3_R_P_P_R_R_R_P_P"
D_SRC = (1 << 9) | (1 << 10) | (1 << 11) | (1 << 91)


def encode(ins_key, ins_vals, ins_modi):
    """-> 128-bit code, or -1 to fall through to whatever handled it before."""
    if ins_key != KEY or len(ins_vals) != 9:
        return -1
    if any(m.startswith("5_") and m.endswith("reuse") for m in ins_modi):
        return -1                       # a uniform operand has no reuse slot
    if any("cNEG" in m for m in ins_modi):
        return -1                       # the register form declines these too
    if not (0 <= int(ins_vals[5]) <= 255):
        return -1

    for modname in ("CuAsm.NewOpsHandler", "cuAssembler.CuAsm.NewOpsHandler"):
        try:
            mod = __import__(modname, fromlist=[REG_KEY])
        except Exception:
            continue
        base = getattr(mod, REG_KEY)(REG_KEY, ins_vals, ins_modi)
        return -1 if base < 0 else base ^ D_SRC
    return -1


def install(verbose=True):
    done = []
    for modname in ("CuAsm.NewOpsHandler", "cuAssembler.CuAsm.NewOpsHandler"):
        try:
            mod = __import__(modname, fromlist=["check_new_ops"])
        except Exception:
            continue
        if getattr(mod, "_iadd3ur_sm120_installed", False):
            continue
        orig = mod.check_new_ops

        def wrapped(sm, ins_key, ins_vals, ins_modi, _orig=orig):
            if int(sm) == 120 and ins_key == KEY:
                code = encode(ins_key, ins_vals, ins_modi)
                if code >= 0:
                    return code
            return _orig(sm, ins_key, ins_vals, ins_modi)

        mod.check_new_ops = wrapped
        mod._iadd3ur_sm120_installed = True
        done.append(modname)
    if verbose:
        print("  IADD3-UR sm_120 encoder installed in:", done or "(already installed)")
    return done


# ------------------------------------------------------------------ self-check ----------
def _check():
    rcasm = os.environ.get("RCASM", "/mnt/c/tmp/ai/cProto/RCAsm")
    nvdis = os.environ.get("NVDISASM", "/usr/local/cuda-13.3/bin/nvdisasm")
    sys.path.insert(0, os.path.join(rcasm, "cuAssembler"))
    if os.environ.get("PYDEPS"):
        sys.path.insert(0, os.environ["PYDEPS"])
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from CuAsm.CuInsAssemblerRepos import CuInsAssemblerRepos
    from CuAsm.config import Config
    import ldcu_sm120

    Config.SM_VER = 120
    ldcu_sm120.install(verbose=False)
    install(verbose=False)
    repos = CuInsAssemblerRepos(
        os.path.join(rcasm, "cuAssembler", "CuAsm", "InsAsmRepos",
                     "DefaultInsAsmRepos.sm_120.txt"), arch="sm_120")

    CTRL = 0x000fe20000000000 << 64      # a real control word; a zero one will not decode
    tests = []
    for k in range(8):                   # the eight limbs of SubMod256, as they would be written
        cin = "!PT" if k == 0 else "P0"
        tests.append("IADD3.X R%d, P0, PT, RZ, UR%d, ~R%d, %s, PT" % (48 + k, 20 + k, 8 + k, cin))
    for k in range(8):                   # and of SubMod256_3
        pin = "PT, PT" if k == 0 else "P0, P2"
        tests.append("IADD3.X R%d, P0, P2, R%d, ~UR%d, ~R%d, %s" % (88 + k, 80 + k, 20 + k, 8 + k, pin))
    tests += [                           # corners: high UR index, RZ sources, both ~ off
        "IADD3.X R2, P1, P3, R4, UR63, R6, P2, P4",
        "IADD3.X R2, P1, P3, RZ, ~UR40, RZ, PT, PT",
        "IADD3.X R126, P0, PT, R120, UR2, ~R100, P0, !PT",
    ]

    codes, labels = [], []
    for t in tests:
        try:
            codes.append(repos.assemble(0x1000, "      " + t + " ;"))
            labels.append(t)
        except BaseException as e:
            print("  %-56s ENCODE FAILED: %s" % (t, str(e).splitlines()[0][:50]))

    binp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_iadd3ur_check.bin")
    open(binp, "wb").write(b"".join(int(c | CTRL).to_bytes(16, "little") for c in codes))
    r = subprocess.run([nvdis, "--binary", "SM120", binp], capture_output=True, text=True)
    os.remove(binp)
    back = [l.split("*/", 1)[-1].strip().rstrip(";").strip()
            for l in r.stdout.splitlines() if l.strip().startswith("/*")]

    bad = 0
    for t, b in zip(labels, back + ["(no decode)"] * len(labels)):
        ok = b.replace(" ", "") == t.replace(" ", "")
        bad += not ok
        print("  %-56s %s %s" % (t, "==" if ok else "!=", b if not ok else ""))
    print("\n%d of %d assembled and decoded as written" % (len(labels) - bad, len(tests)))
    if r.stderr.strip():
        print("nvdisasm stderr:", r.stderr.strip()[:300])
    return 1 if (bad or len(labels) != len(tests)) else 0


if __name__ == "__main__":
    sys.exit(_check())
