#!/usr/bin/env python3
"""Branch-level A/B: build two revisions, run them interleaved, compare MKeys/s.

  A = main (the baseline)          B = the current branch (the change under test)

rcasm_test/abtest is the KERNEL-level A/B -- two cubins in one harness. This is the
whole-binary one: it answers "is the branch faster than main", which is the question a
rung has to answer before it is adopted.

Three things this does on purpose, each because the naive version is wrong:

1. **git worktrees, not `git switch`.** Both revisions are checked out side by side into a
   scratch directory. Your working tree, your branch and your untracked build output are
   never touched, and an interrupted run cannot leave you on the wrong branch.

2. **Interleaved A,B,A,B -- never all of A then all of B.** rcasm_test/abtest/README.md
   records why: running one side to completion first is a thermal ramp pointed at exactly one
   side. A measures a cool card, B measures the card A just heated, and the bias grows with
   run length -- so it grows precisely when someone lengthens the run to be more careful.

3. **A noise floor, reported next to the delta.** Each side is measured over several rounds
   and the within-side spread is printed. A 0.4% delta against a 2% spread is not a result,
   and the script says so rather than leaving the ratio to speak for itself.

Speed comes from the binary's own `Speed: N MKeys/s` line (show_stat, every 5 s). The first
samples are discarded: GetStatsSpeed averages a 16-slot window that starts zeroed and counts
slot 0 even when it is zero (GpuPuzzle.cpp), so early samples under-report.

  python abbench.py                          # main vs current branch, default 60s x 3 rounds
  python abbench.py --seconds 120 --rounds 5
  python abbench.py --base main --head f1 --verify
"""
import argparse
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
from typing import List, Optional, Tuple

SPEED_RE = re.compile(r"Speed:\s*(\d+)\s*MKeys/s")
# A range big enough that no run finishes it: 2^63 keys, aligned to its own length, which is
# what validate_params requires. The target hash is one no key maps to, so the scan never
# short-circuits on a find and both sides do identical work.
BENCH_RANGE = "8000000000000000:FFFFFFFFFFFFFFFF"
BENCH_HASH = "3a1f9c2e7b4d8065af13e29c5d7b06e84c2f19ab"

IS_WIN = os.name == "nt"


def win_to_wsl(path: str) -> str:
    p = os.path.abspath(path).replace("\\", "/")
    if len(p) > 1 and p[1] == ":":
        return f"/mnt/{p[0].lower()}{p[2:]}"
    return p


class Runner:
    """Runs shell commands where the CUDA toolchain and the GPU actually are.

    On Windows that is WSL: nvcc and the CUDA driver are not reachable from Win32, so both
    the build and the run have to cross over. On Linux it is just bash.
    """

    def __init__(self, distro: Optional[str]):
        self.distro = distro

    def path(self, p: str) -> str:
        return win_to_wsl(p) if self.distro else os.path.abspath(p)

    def argv(self, script: str) -> List[str]:
        if self.distro:
            return ["wsl", "-d", self.distro, "-e", "bash", "-lc", script]
        return ["bash", "-lc", script]

    def run(self, script: str, timeout: Optional[int] = None) -> subprocess.CompletedProcess:
        return subprocess.run(self.argv(script), stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, universal_newlines=True,
                              timeout=timeout, errors="replace")


def list_distros() -> List[str]:
    try:
        out = subprocess.run(["wsl", "-l", "-q"], stdout=subprocess.PIPE,
                             universal_newlines=True, timeout=30, errors="replace").stdout
    except Exception:
        return []
    return [n.strip() for n in out.replace("\x00", "").splitlines() if n.strip()]


def detect_distro() -> Optional[str]:
    """Pick a WSL distro that can actually build this, not just the first one listed.

    Taking the first (or the newest) is wrong, and fails in a way that looks like a bug in
    the project rather than a toolchain mismatch: CUDA rejects a host g++ newer than it
    knows, so on a box with Ubuntu 26.04 (g++ 15) beside Ubuntu 22.04 (g++ 11), the newer
    distro dies inside glibc's own mathcalls.h -- "exception specification is incompatible
    with that of previous function rsqrtf" -- before a single line of this repo is compiled,
    while the older one builds clean. So probe for nvcc plus a host compiler CUDA accepts.
    """
    if not IS_WIN:
        return None
    probe = (r"""printf '%s|%s\n' """
             r""""$(ls /usr/local/cuda/bin/nvcc 2>/dev/null || command -v nvcc 2>/dev/null)" """
             r""""$(g++ -dumpversion 2>/dev/null)" """)
    candidates = list_distros()
    fallback: Optional[str] = None
    for name in candidates:
        try:
            out = subprocess.run(["wsl", "-d", name, "-e", "bash", "-lc", probe],
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                 universal_newlines=True, timeout=60, errors="replace").stdout
        except Exception:
            continue
        line = next((l for l in out.splitlines() if "|" in l), "")
        nvcc, _, gxx = line.partition("|")
        if not nvcc.strip():
            continue
        fallback = fallback or name
        major = int(gxx.strip().split(".")[0]) if gxx.strip().split(".")[0].isdigit() else 99
        if major <= 13:                       # the newest host g++ CUDA 12.x/13.x accepts
            return name
    return fallback or (candidates[0] if candidates else None)


def git(*a: str, cwd: Optional[str] = None) -> str:
    return subprocess.run(["git", *a], cwd=cwd, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, universal_newlines=True,
                          check=True, errors="replace").stdout.strip()


def add_worktree(repo: str, rev: str, dest: str) -> str:
    # --detach: a worktree may not check out a branch that is already checked out elsewhere,
    # and HEAD is by definition checked out in the repo you are running from.
    git("worktree", "add", "--detach", dest, rev, cwd=repo)
    return dest


def build(runner: Runner, wt: str, sm: str, extra: str) -> Tuple[bool, str]:
    script = (f"cd {runner.path(wt)} && make -j\"$(nproc)\" SM={sm} {extra} 2>&1 | tail -25")
    try:
        cp = runner.run(script, timeout=1800)
    except subprocess.TimeoutExpired:
        return False, "build timed out after 1800 s"
    ok = os.path.exists(os.path.join(wt, "cCUDAHurricane"))
    return ok, cp.stdout


def measure(runner: Runner, wt: str, seconds: int, grid: Optional[str],
            warmup_samples: int) -> Tuple[List[int], str]:
    """One timed run. Returns (speed samples after warm-up, raw tail for diagnosis).

    `timeout -s INT` is what stops it: the binary installs a SIGINT handler and unwinds
    cleanly (EXIT_INTERRUPTED). Killing the `wsl` process from Windows would not reliably
    reap the Linux child, so the deadline is enforced on the far side.
    """
    grid_arg = f" --grid {grid}" if grid else ""
    script = (f"cd {runner.path(wt)} && timeout -s INT {seconds}s "
              f"./cCUDAHurricane --range {BENCH_RANGE} "
              f"--target-hash160 {BENCH_HASH}{grid_arg} 2>&1")
    try:
        cp = runner.run(script, timeout=seconds + 180)
    except subprocess.TimeoutExpired:
        return [], "run exceeded its own deadline by 180 s (hung?)"
    samples = [int(m) for m in SPEED_RE.findall(cp.stdout)]
    tail = "\n".join(cp.stdout.strip().splitlines()[-6:])
    return samples[warmup_samples:], tail


def summarize(name: str, rounds: List[List[int]]) -> Optional[dict]:
    per_round = [statistics.median(r) for r in rounds if r]
    if not per_round:
        return None
    flat = [s for r in rounds for s in r]
    return {
        "name": name,
        "rounds": per_round,
        "median": statistics.median(per_round),
        "spread_pct": (100.0 * (max(per_round) - min(per_round)) / statistics.median(per_round)
                       if len(per_round) > 1 else 0.0),
        "samples": len(flat),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default="main", help="side A revision (default: main)")
    ap.add_argument("--head", default="HEAD", help="side B revision (default: HEAD)")
    ap.add_argument("--seconds", type=int, default=60, help="seconds per side per round")
    ap.add_argument("--rounds", type=int, default=3, help="interleaved A,B rounds (default 3)")
    ap.add_argument("--warmup", type=int, default=2,
                    help="leading Speed samples to discard per run (default 2 = ~10 s)")
    ap.add_argument("--warmup-rounds", type=int, default=1,
                    help="A,B passes to run and discard before round 1 (default 1); the first "
                         "launch on a cold card is faster and always lands on A")
    ap.add_argument("--sm", default="120", help="compute capability to build for")
    ap.add_argument("--grid", default=None, help='"A,B" passed to both sides')
    ap.add_argument("--make-args", default="", help="extra args appended to make")
    ap.add_argument("--workdir", default=None, help="where to put the worktrees")
    ap.add_argument("--distro", default=None, help="WSL distro (default: first listed)")
    ap.add_argument("--verify", action="store_true",
                    help="run verify.py against side B before benchmarking, and abort if it fails")
    ap.add_argument("--no-build", action="store_true", help="reuse binaries already in the worktrees")
    ap.add_argument("--keep", action="store_true", help="leave the worktrees in place afterwards")
    args = ap.parse_args()

    repo = git("rev-parse", "--show-toplevel")
    try:
        sha_a, sha_b = git("rev-parse", args.base), git("rev-parse", args.head)
    except subprocess.CalledProcessError:
        print(f"cannot resolve {args.base!r} or {args.head!r} as revisions", file=sys.stderr)
        return 1
    if sha_a == sha_b:
        print(f"side A ({args.base}) and side B ({args.head}) are the same commit {sha_a[:12]}.\n"
              "There is nothing to compare -- commit the change on the branch first.",
              file=sys.stderr)
        return 1

    runner = Runner(args.distro or detect_distro())
    if IS_WIN and not runner.distro:
        print("no WSL distro found. nvcc and the CUDA driver are not reachable from Win32, "
              "so the build and the run must happen in WSL.", file=sys.stderr)
        return 1

    work = args.workdir or os.path.join(tempfile.gettempdir(), "ccudam-ab")
    os.makedirs(work, exist_ok=True)
    wt_a, wt_b = os.path.join(work, "A"), os.path.join(work, "B")

    print("======== A/B configuration ===========================")
    print(f"  A (base) : {args.base:12s} {sha_a[:12]}")
    print(f"  B (head) : {args.head:12s} {sha_b[:12]}")
    print(f"  schedule : {args.rounds} rounds x {args.seconds}s per side, INTERLEAVED A,B"
          f"  (+{args.warmup_rounds} discarded warm-up pass{'es' if args.warmup_rounds != 1 else ''})")
    print(f"  build    : SM={args.sm} {args.make_args}".rstrip())
    print(f"  runner   : {'WSL ' + runner.distro if runner.distro else 'native bash'}")
    print(f"  worktrees: {work}")
    print("-------------------------------------------------------")

    created: List[str] = []
    try:
        for rev, dest in ((sha_a, wt_a), (sha_b, wt_b)):
            if os.path.exists(dest):
                git("worktree", "remove", "--force", dest, cwd=repo)
            add_worktree(repo, rev, dest)
            created.append(dest)

        if not args.no_build:
            for name, wt in (("A", wt_a), ("B", wt_b)):
                print(f"building {name} ...", flush=True)
                ok, log = build(runner, wt, args.sm, args.make_args)
                if not ok:
                    print(f"\nside {name} FAILED TO BUILD:\n{log}", file=sys.stderr)
                    return 1

        if args.verify:
            print("verifying B for correctness before measuring it ...", flush=True)
            # Must run where the binary runs. On Windows the worktree binary is an ELF built
            # in WSL, so invoking it from Win32 Python fails with a format error that reads
            # like a broken build. Copy verify.py in (it may still be uncommitted, in which
            # case the worktree does not have it) and drive it through the same runner.
            shutil.copy2(os.path.join(repo, "verify.py"), os.path.join(wt_b, "verify.py"))
            script = (f"cd {runner.path(wt_b)} && "
                      f"python3 verify.py --path ./cCUDAHurricane --quiet 2>&1")
            cp = runner.run(script, timeout=3600)
            print(cp.stdout, flush=True)
            if cp.returncode != 0:
                print("side B failed verification. A speed number for an incorrect kernel is "
                      "worth nothing -- refusing to benchmark it.", flush=True)
                return 1

        # Discarded warm-up: the first launch runs cold at boost clocks and always lands on A.
        for w in range(1, args.warmup_rounds + 1):
            for name, wt in (("A", wt_a), ("B", wt_b)):
                print(f"warm-up {w}/{args.warmup_rounds}  side {name} ...", end=" ", flush=True)
                samples, tail = measure(runner, wt, args.seconds, args.grid, args.warmup)
                if not samples:
                    print("NO SPEED SAMPLES", flush=True)
                    print(f"\nside {name} produced no 'Speed:' line. Tail:\n{tail}", flush=True)
                    if "No usable CUDA device" in tail or "CUDA init error" in tail:
                        print("\nThis machine has no usable NVIDIA GPU -- the A/B has to run "
                              "on the card.", flush=True)
                    return 1
                print(f"median {statistics.median(samples):,.0f} MKeys/s  (discarded)")

        rounds_a: List[List[int]] = []
        rounds_b: List[List[int]] = []
        for r in range(1, args.rounds + 1):
            for name, wt, bucket in (("A", wt_a, rounds_a), ("B", wt_b, rounds_b)):
                print(f"round {r}/{args.rounds}  side {name} ...", end=" ", flush=True)
                samples, tail = measure(runner, wt, args.seconds, args.grid, args.warmup)
                if not samples:
                    # One stream, flushed in order: split across stdout and stderr these
                    # arrive interleaved and the diagnosis reads back-to-front.
                    print("NO SPEED SAMPLES", flush=True)
                    print(f"\nside {name} produced no 'Speed:' line. Tail:\n{tail}", flush=True)
                    if "No usable CUDA device" in tail or "CUDA init error" in tail:
                        print("\nThis machine has no usable NVIDIA GPU -- the A/B has to run "
                              "on the card.", flush=True)
                    return 1
                bucket.append(samples)
                print(f"median {statistics.median(samples):,.0f} MKeys/s  ({len(samples)} samples)")

        sa, sb = summarize("A", rounds_a), summarize("B", rounds_b)
        if not sa or not sb:
            print("not enough samples to compare", file=sys.stderr)
            return 1

        delta = 100.0 * (sb["median"] - sa["median"]) / sa["median"]
        noise = max(sa["spread_pct"], sb["spread_pct"])

        print("-------------------------------------------------------")
        print(f"  A ({args.base:>10s})  median {sa['median']:>10,.0f} MKeys/s   "
              f"spread {sa['spread_pct']:5.2f}%   rounds {[f'{x:,.0f}' for x in sa['rounds']]}")
        print(f"  B ({args.head:>10s})  median {sb['median']:>10,.0f} MKeys/s   "
              f"spread {sb['spread_pct']:5.2f}%   rounds {[f'{x:,.0f}' for x in sb['rounds']]}")
        print("-------------------------------------------------------")
        print(f"  B vs A   : {delta:+.2f}%")
        print(f"  noise    : +/-{noise:.2f}%  (largest within-side spread across rounds)")
        if abs(delta) <= noise:
            print(f"\nVERDICT: NO RESULT. The {abs(delta):.2f}% delta is inside the {noise:.2f}% "
                  f"noise floor.\n         Raise --rounds or --seconds, or the change is null.")
        elif delta > 0:
            print(f"\nVERDICT: B is FASTER by {delta:.2f}% (noise {noise:.2f}%).")
        else:
            print(f"\nVERDICT: B is SLOWER by {abs(delta):.2f}% (noise {noise:.2f}%).")
        # Speed alone is not adoption. The repo's own gate is registers AND spill AND
        # correctness; say so rather than let a green number stand in for all three.
        if not args.verify:
            print("\nNote: correctness was not checked. Re-run with --verify, or run "
                  "verify.py against B, before adopting this.")
        return 0
    finally:
        if not args.keep:
            for dest in created:
                try:
                    git("worktree", "remove", "--force", dest, cwd=repo)
                except Exception:
                    shutil.rmtree(dest, ignore_errors=True)
            try:
                git("worktree", "prune", cwd=repo)
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())
