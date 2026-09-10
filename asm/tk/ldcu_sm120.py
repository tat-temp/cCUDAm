#!/usr/bin/env python3
"""A correct sm_120 LDCU encoder for RCAsm, installed in-process by `rc_build.py`.

Two problems it fixes, both in `NewOpsHandler`:

1. **`LDCU.128` is silently encoded as 32-bit.** `NewOpsHandler.LDCU_UR_cAI` knows only a
   `.64` branch and ignores any other size modifier, and `check_new_ops` claims every
   `LDCU_UR_cAI` on sm_120 before the matrix ever sees it. The result assembles, passes
   `cuobjdump`, loads, runs -- and has loaded a quarter of the data. Latent today only
   because the one `LDCU.128` in the template (`c[0x0][0x380]`) sits in the very kernel
   body `build.sh` replaces.

2. **UR-indexed LDCU cannot be encoded at all.** `LDCU_UR_cAURI` falls through to the
   matrix, which answers `Insufficient basis` for any non-zero immediate -- and no amount
   of teaching fixes it: on sm_120 `URZ` encodes as **255** while numbered URs encode as
   themselves, and `CuInsParser` still reports `URZ` as 63. A linear fit cannot represent
   that step, which is why `LDCU_UR_cAURI` belongs here rather than in the repository.
   `NewOpsHandler` says as much itself, above its own sm_120 block.

Field map, measured off real encodings and validated by `nvdisasm --binary SM120`:

    bits  0-11  opcode 0x7ac          bits 24-31  index UR (255 = none, and = URZ)
    bits 12-14  guard predicate       bits 37-53  immediate offset
    bits 16-23  destination UR        bits 54-58  constant bank
    bits 73-75  size: 4=32, 5=64, 6=128           bit 91  fixed, set on every LDCU

Anything outside what has been verified -- an unknown modifier, a negative immediate --
returns -1 and falls through untouched, so no instruction that assembles today changes.

Self-check (26 real LDCU encodings out of the shipped cubins, stock vs this):

    python3 ldcu_sm120.py a.sass b.sass ...
"""
import re
import sys

CTRL = ((1 << 23) - 1) << 105          # control codes, added later; never part of the code

KEYS = ("LDCU_UR_cAI", "LDCU_UR_cAURI")


def encode(ins_key, ins_vals, ins_modi):
    """-> 128-bit code, or -1 to leave the instruction to whoever handled it before."""
    if ins_key == "LDCU_UR_cAI" and len(ins_vals) == 4:
        pred, dest, bank, imm = (int(v) for v in ins_vals)
        idx = 255                                   # this form carries no index register
    elif ins_key == "LDCU_UR_cAURI" and len(ins_vals) == 5:
        pred, dest, bank, idx, imm = (int(v) for v in ins_vals)
        if idx == 63:                               # CuInsParser's URZ; the hardware's is 255
            idx = 255
    else:
        return -1

    sizes = frozenset(m for m in ins_modi if m in ("0_64", "0_128"))
    size = {frozenset(): 4, frozenset({"0_64"}): 5, frozenset({"0_128"}): 6}.get(sizes)
    unknown = [m for m in ins_modi if m not in ("0_LDCU", "0_64", "0_128")]
    if size is None or unknown or imm < 0 or not (0 <= idx <= 255):
        return -1
    if size == 6 and dest % 4:                      # .128 needs a UR quad
        return -1
    if size == 5 and dest % 2:
        return -1

    inst = 0x7ac
    inst |= pred << 12
    inst |= dest << 16
    inst |= idx << 24
    inst |= imm << 37
    inst |= bank << 54
    inst |= size << 73
    inst |= 1 << 91
    return inst


def install(verbose=True):
    """Wrap NewOpsHandler.check_new_ops on every module identity CuAsm is reachable under."""
    done = []
    for modname in ("CuAsm.NewOpsHandler", "cuAssembler.CuAsm.NewOpsHandler"):
        try:
            mod = __import__(modname, fromlist=["check_new_ops"])
        except Exception:
            continue
        if getattr(mod, "_ldcu_sm120_installed", False):
            continue
        orig = mod.check_new_ops

        def wrapped(sm, ins_key, ins_vals, ins_modi, _orig=orig):
            if int(sm) == 120 and ins_key in KEYS:
                code = encode(ins_key, ins_vals, ins_modi)
                if code >= 0:
                    return code
            return _orig(sm, ins_key, ins_vals, ins_modi)

        mod.check_new_ops = wrapped
        mod._ldcu_sm120_installed = True
        done.append(modname)

    # CuInsAssemblerRepos holds its own reference to the module object; if the two names
    # turned out to be distinct modules, make sure the one it uses is the patched one.
    for modname in ("CuAsm.CuInsAssemblerRepos", "cuAssembler.CuAsm.CuInsAssemblerRepos"):
        try:
            rep = __import__(modname, fromlist=["NewOpsHandler"])
            noh = __import__(done[0], fromlist=["check_new_ops"]) if done else None
            if noh is not None and getattr(rep, "NewOpsHandler", None) is not noh:
                rep.NewOpsHandler = noh
        except Exception:
            pass

    if verbose:
        print("  LDCU sm_120 encoder installed in:", done or "(already installed)")
    return done


# ------------------------------------------------------------------ self-check ----------
_INSTR = re.compile(r"^\s+/\*[0-9a-f]{4,6}\*/\s+(.*?);\s+/\* (0x[0-9a-f]+) \*/")
_CONT = re.compile(r"^\s+/\* (0x[0-9a-f]+) \*/")


def _parse(path):
    out, pend = [], None
    for line in open(path):
        m = _INSTR.match(line)
        if m:
            pend = [m.group(1).strip(), int(m.group(2), 16)]
            continue
        m = _CONT.match(line)
        if m and pend:
            out.append((pend[0], (int(m.group(1), 16) << 64) | pend[1]))
            pend = None
    return out


def _check(files):
    import os
    rcasm = os.environ.get("RCASM", "/mnt/c/tmp/ai/cProto/RCAsm")
    sys.path.insert(0, os.path.join(rcasm, "cuAssembler"))
    if os.environ.get("PYDEPS"):
        sys.path.insert(0, os.environ["PYDEPS"])
    from CuAsm.CuInsAssemblerRepos import CuInsAssemblerRepos
    from CuAsm.config import Config
    Config.SM_VER = 120
    repos = CuInsAssemblerRepos(
        os.path.join(rcasm, "cuAssembler", "CuAsm", "InsAsmRepos",
                     "DefaultInsAsmRepos.sm_120.txt"), arch="sm_120")
    parser = repos.m_InsParser

    corpus = {}
    for f in files:
        for text, code in _parse(f):
            if text.startswith("LDCU"):
                corpus.setdefault(text, code & ~CTRL)
    if not corpus:
        sys.exit("no LDCU instructions in: " + " ".join(files))

    print("%-38s %-12s %s" % ("instruction", "stock", "this encoder"))
    print("-" * 66)
    bad_stock = bad_new = 0
    for text, real in sorted(corpus.items()):
        key, vals, modi = parser.parse("      " + text + " ;", 0x1000, 0)
        try:
            s = "OK" if repos.assemble(0x1000, "      " + text + " ;") & ~CTRL == real \
                else "WRONG"
        except BaseException as e:
            s = type(e).__name__
        code = encode(key, vals, modi)
        n = "OK" if code >= 0 and (code & ~CTRL) == real else \
            ("declined" if code < 0 else "WRONG")
        bad_stock += s != "OK"
        bad_new += n != "OK"
        print("%-38s %-12s %s" % (text, s, n))
    print("\nstock: %d of %d wrong        this encoder: %d of %d wrong"
          % (bad_stock, len(corpus), bad_new, len(corpus)))
    return 1 if bad_new else 0


if __name__ == "__main__":
    sys.exit(_check(sys.argv[1:]))
