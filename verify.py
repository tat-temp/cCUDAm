#!/usr/bin/env python3
"""Fast correctness gate: does THIS binary still find planted keys, and only those?

proof.py is the exhaustive suite -- every residue class mod B, hundreds of full-range scans,
a 1800 s per-run cap. That is the right thing to run before believing a kernel, and the wrong
thing to run between two builds you are A/B-ing: it takes hours, so in practice it gets
skipped, and a speed win gets adopted without anyone re-proving correctness.

This is the gate for that loop. It runs in minutes because every test uses a SMALL aligned
range and plants its key where the kernel's structure actually bends:

  * offset 0, 1                 -- first key of the first batch, both parities
  * half-1, half, half+1        -- the batch CENTRE. PrepareHost seeds each thread's scalar at
                                   range_start + half (GpuPuzzle.cpp), so the centre is the one
                                   offset reached by neither the +(i+1) nor the -(i+1) walk but
                                   by the x1 test at the top of the batch loop. A kernel that
                                   drops it scans at full speed and silently misses 1 key in B.
  * B-1, B, B+1                 -- the batch boundary, and the first key of the second batch
  * end-1, end                  -- the final batch, where the per-thread count runs out
  * the tail block              -- i == half-1, the one walk trip written outside the loop

and it adds the test proof.py structurally cannot make: a NEGATIVE. Every proof.py test plants
a key and asserts it is found, so a kernel that reported a match for everything would pass the
entire suite. Here one run searches for a hash160 that is in no key's image and must exit
EXIT_NOT_FOUND (2) having printed no FOUND banner.

Exit status is the gate: 0 = every test passed, 1 = something failed or could not be run.

  python verify.py --path ./cCUDAHurricane
  python verify.py --path ./cCUDAHurricane --range 1000000:100FFFF --grid 1024,512

Crypto helpers come from proof.py when it imports (it needs `ecdsa`); the secp256k1 scalar
multiply below is self-contained so the common path needs no third-party package at all.
"""
import argparse
import hashlib
import os
import random
import subprocess
import sys
from typing import List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# probe_batch_size and run_and_watch are reused verbatim: both are already hardened against
# the failure modes that bite here -- block-buffered banners arriving in one write, a child
# that hangs before printing anything, select() not accepting pipe handles on Windows.
try:
    from proof import probe_batch_size, run_and_watch
except ImportError as ex:  # pragma: no cover
    print(f"cannot import proof.py: {ex}\n"
          "verify.py reuses proof.py's process handling, and proof.py imports `ecdsa` at\n"
          "module scope, so that package has to be present even though nothing below uses\n"
          "it (the secp256k1 here is self-contained):\n"
          "    python3 -m pip install ecdsa", file=sys.stderr)
    sys.exit(1)

P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

BASE58_ALPH = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


# ---- secp256k1, Jacobian so the whole run costs one inversion per key ----------------------
def _jac_double(pt):
    x, y, z = pt
    if y == 0:
        return (0, 0, 0)
    ysq = (y * y) % P
    s = (4 * x * ysq) % P
    m = (3 * x * x) % P
    nx = (m * m - 2 * s) % P
    ny = (m * (s - nx) - 8 * ysq * ysq) % P
    nz = (2 * y * z) % P
    return (nx, ny, nz)


def _jac_add(p1, p2):
    x1, y1, z1 = p1
    if z1 == 0:
        return p2
    x2, y2, z2 = p2
    if z2 == 0:
        return p1
    z1sq, z2sq = (z1 * z1) % P, (z2 * z2) % P
    u1, u2 = (x1 * z2sq) % P, (x2 * z1sq) % P
    s1, s2 = (y1 * z2sq * z2) % P, (y2 * z1sq * z1) % P
    if u1 == u2:
        return _jac_double(p1) if s1 == s2 else (0, 0, 0)
    h, r = (u2 - u1) % P, (s2 - s1) % P
    h2 = (h * h) % P
    h3 = (h2 * h) % P
    nx = (r * r - h3 - 2 * u1 * h2) % P
    ny = (r * (u1 * h2 - nx) - s1 * h3) % P
    nz = (h * z1 * z2) % P
    return (nx, ny, nz)


def scalar_mul_g(k: int) -> Tuple[int, int]:
    """k*G in affine coordinates. Pure Python -- no `ecdsa` needed on this path."""
    if k % N == 0:
        raise ValueError("scalar is a multiple of the group order")
    acc = (0, 0, 0)
    add = (GX, GY, 1)
    while k:
        if k & 1:
            acc = _jac_add(acc, add)
        add = _jac_double(add)
        k >>= 1
    x, y, z = acc
    zi = pow(z, P - 2, P)
    zi2 = (zi * zi) % P
    return (x * zi2) % P, (y * zi2 % P * zi) % P


def _ripemd160(data: bytes) -> bytes:
    try:
        h = hashlib.new("ripemd160")
        h.update(data)
        return h.digest()
    except (ValueError, TypeError):
        # OpenSSL 3 without the legacy provider (Ubuntu 22.04+, Debian 12+) has no ripemd160.
        # proof.py carries a pure-Python one; borrow it rather than keep a second copy here.
        from proof import _ripemd160_py
        return _ripemd160_py(data)


def hash160_of(data: bytes) -> bytes:
    return _ripemd160(hashlib.sha256(data).digest())


def base58_encode(b: bytes) -> str:
    zeros = len(b) - len(b.lstrip(b"\x00"))
    num = int.from_bytes(b, "big")
    enc = bytearray()
    while num > 0:
        num, rem = divmod(num, 58)
        enc.append(BASE58_ALPH[rem])
    return ("1" * zeros) + bytes(reversed(enc)).decode("ascii")


def address_of_priv(priv: int) -> Tuple[str, str]:
    """-> (P2PKH address, 64-hex private key) for the compressed pubkey of `priv`."""
    x, y = scalar_mul_g(priv)
    pub = (b"\x03" if (y & 1) else b"\x02") + x.to_bytes(32, "big")
    payload = b"\x00" + hash160_of(pub)
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    return base58_encode(payload + checksum), priv.to_bytes(32, "big").hex()


def parse_range(s: str) -> Tuple[int, int]:
    if ":" not in s:
        raise ValueError("range must be HEX_START:HEX_END")
    a, b = (p.strip().removeprefix("0x").removeprefix("0X") or "0" for p in s.split(":", 1))
    lo, hi = int(a, 16), int(b, 16)
    if lo > hi:
        raise ValueError("start > end")
    # Mirror validate_params in cCUDAHurricane.cpp: a range that is not a power of two, or not
    # aligned to its own length, is rejected by the binary. Catching it here turns one clear
    # message into the alternative of N identical unexplained failures.
    length = hi - lo + 1
    if length & (length - 1):
        raise ValueError(f"range length {length:#x} must be a power of two")
    if lo & (length - 1):
        raise ValueError(f"range start {lo:#x} must be aligned to its length {length:#x}")
    return lo, hi


def plan_offsets(B: int, span: int) -> List[Tuple[str, int]]:
    """Offsets from range start, labelled by the kernel structure each one exercises."""
    half = B >> 1
    want = [
        ("first key of batch 0",        0),
        ("first key, odd parity",       1),
        ("batch centre - 1",            half - 1),
        ("batch centre (thread seed)",  half),
        ("batch centre + 1",            half + 1),
        ("tail block (i == half-1)",    B - 2),
        ("last key of batch 0",         B - 1),
        ("first key of batch 1",        B),
        ("batch 1, odd parity",         B + 1),
        ("batch 1 centre",              B + half),
    ]
    # The final batch: where a thread's count runs out and the loop drops it while it is still
    # live for the write-back. That is the exact lane the H4 warp-mask fix exists for, so it is
    # worth a planted key rather than trust.
    want += [("last key in range", span - 1), ("second-to-last key in range", span - 2)]
    rnd = random.Random(20260901)
    for i in range(4):
        want.append((f"random interior #{i + 1}", rnd.randrange(0, span)))

    seen, out = set(), []
    for label, off in want:
        if 0 <= off < span and off not in seen:
            seen.add(off)
            out.append((label, off))
    return out


FOUND_MARKER = "======== FOUND MATCH! ================================="


def run_negative(path: str, range_arg: str, grid: Optional[str], timeout: int) -> Tuple[bool, str]:
    """Search for a hash160 no key maps to. Must exit 2 (EXIT_NOT_FOUND), no FOUND banner.

    This is the half proof.py cannot cover: every one of its tests plants a real key and
    asserts a find, so a kernel whose comparison always said "match" would pass all of them.
    """
    # A random 20-byte value. The chance any key in a range this small hashes to it is ~2^-160.
    bogus = hashlib.sha256(b"cCUDAm/verify.py/no-such-key").digest()[:20].hex()
    argv = [path, "--range", range_arg, "--target-hash160", bogus]
    if grid:
        argv += ["--grid", grid]
    try:
        p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           universal_newlines=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout}s without finishing the range"
    except OSError as ex:
        return False, f"could not launch: {ex}"
    if FOUND_MARKER in p.stdout:
        return False, "reported a FOUND MATCH for a hash160 that is in no key's image"
    if p.returncode != 2:                       # EXIT_NOT_FOUND
        tail = " | ".join(p.stdout.strip().splitlines()[-3:])
        return False, f"exit code {p.returncode}, expected 2 (EXIT_NOT_FOUND). tail: {tail}"
    return True, "exit 2, no false match"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--path", "-c", default="./cCUDAHurricane", help="binary to test")
    # 2^32 keys: large enough that CalcEffectiveBatchSize keeps B=1024 on a big card. A 2^16 range
    # shrank it to 2, and at half=1 the ladder and walk loops never run.
    ap.add_argument("--range", "-r", dest="range_arg", default="100000000:1FFFFFFFF",
                    help="HEX START:END, power-of-two length, start aligned (default: 2^32 keys)")
    ap.add_argument("--min-batch", type=int, default=64,
                    help="refuse to run if the kernel's effective batch is below this (default 64). "
                         "A small B means the host shrank it to fit the range, and the batch "
                         "machinery under test then barely executes -- grow --range instead.")
    ap.add_argument("--grid", default=None, help='"A,B" passed through to the binary')
    ap.add_argument("--timeout", type=int, default=300,
                    help="per-run cap in seconds (default 300). A miss scans the whole range, "
                         "so this must exceed a full scan or a pass is reported as a failure.")
    ap.add_argument("--no-negative", action="store_true", help="skip the false-match test")
    ap.add_argument("--quiet", action="store_true", help="only print failures and the summary")
    args = ap.parse_args()

    try:
        lo, hi = parse_range(args.range_arg)
    except ValueError as ex:
        print(f"--range: {ex}", file=sys.stderr)
        return 1
    span = hi - lo + 1

    if not os.path.exists(args.path):
        print(f"binary not found: {args.path}", file=sys.stderr)
        return 1

    # B must come from the binary's own banner. A guessed B would put the "batch centre" tests
    # at offsets that are not the centre -- they would still pass, while testing nothing.
    B, status, tail = probe_batch_size(args.path, args.range_arg, args.grid)
    if B is None:
        print(f"cannot determine the kernel's batch size (probe: {status}).", file=sys.stderr)
        for ln in tail[-8:]:
            print(f"    | {ln}", file=sys.stderr)
        return 1
    if B <= 0 or B & 1:
        print(f"binary reported an invalid batch size {B}", file=sys.stderr)
        return 1
    if B < args.min_batch:
        # A degenerate B is a config error, not a result: it must never read as PASS.
        print(f"REFUSING: effective batch {B} (half = {B >> 1}) is below --min-batch {args.min_batch}.\n"
              f"  The range ({span} keys) is too small for this card; the host shrank the batch.\n"
              f"  Use a larger --range, or lower --min-batch to test a small batch on purpose.",
              file=sys.stderr)
        return 1

    offsets = plan_offsets(B, span)
    print("======== verify configuration ========================")
    print(f"  binary   : {args.path}")
    print(f"  range    : {args.range_arg}  ({span} keys)")
    print(f"  batch B  : {B}  (half = {B >> 1}, read from the binary's banner)")
    print(f"  tests    : {len(offsets)} planted + {0 if args.no_negative else 1} negative")
    print("-------------------------------------------------------")

    failures: List[str] = []
    passed = 0
    for i, (label, off) in enumerate(offsets, 1):
        priv = lo + off
        addr, priv_hex = address_of_priv(priv)
        found, reported = run_and_watch(args.path, args.range_arg, addr, args.grid,
                                        timeout=args.timeout or None)
        if not found:
            msg = f"{label} (offset {off}): NOT FOUND"
            failures.append(msg)
            print(f"[{i:2d}/{len(offsets)}] FAIL  {msg}")
            continue
        # A FOUND banner is not a correct answer. An off-by-one in the +/-(i+1) offset, or a
        # torn write into the mapped find_result, announces a match and prints the wrong key.
        # formatHex256 emits uppercase, priv_hex lowercase, so fold case before comparing.
        if (reported or "").strip().lower() != priv_hex.lower():
            msg = (f"{label} (offset {off}): WRONG KEY -- "
                   f"expected {priv_hex}, got {(reported or '(none printed)').strip().lower()}")
            failures.append(msg)
            print(f"[{i:2d}/{len(offsets)}] FAIL  {msg}")
            continue
        passed += 1
        if not args.quiet:
            print(f"[{i:2d}/{len(offsets)}] pass  {label} (offset {off})")

    if not args.no_negative:
        ok, detail = run_negative(args.path, args.range_arg, args.grid, args.timeout or 300)
        if ok:
            passed += 1
            if not args.quiet:
                print(f"[neg  ] pass  no false match ({detail})")
        else:
            failures.append(f"negative test: {detail}")
            print(f"[neg  ] FAIL  negative test: {detail}")

    total = len(offsets) + (0 if args.no_negative else 1)
    print("-------------------------------------------------------")
    print(f"  {passed}/{total} passed")
    if failures:
        print(f"  {len(failures)} FAILED:")
        for f in failures:
            print(f"    - {f}")
        print("\nVERDICT: FAIL -- this build must not be adopted on a speed number.")
        return 1
    print("\nVERDICT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
