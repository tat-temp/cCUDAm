#!/bin/bash
# Print EVERY stall violation (not just kernel-body ones) for the call build and the inline
# build, reduced to (distance, need) signatures, so the two can be compared. If inlining only
# RELOCATED known-tolerated vendored violations, the inline build's multiset is the call
# build's with the per-copy counts scaled up and nothing new in it.
cd "$(dirname "$0")"
python3 - <<'PY' > /tmp/sc_all.py
import re
src = open("stall_check.py").read()
# Force every violation into `bad` so show() prints it, regardless of where it sits.
src = src.replace("    bad, note = [], []", "    bad, note = [], []\n    kend = len(rows) + 1")
open("/dev/stdout", "w").write(src)
PY
for c in TestKernel_loop TestKernel_inline; do
    python3 /tmp/sc_all.py "$c.cubin" 2>&1 \
        | grep -oE 'read [0-9]+ cycle\(s\) later \(need [0-9]+\)' \
        | sed -E 's/read ([0-9]+) cycle.* \(need ([0-9]+)\)/dist \1 need \2/' \
        | sort | uniq -c > "/tmp/sig_$c.txt"
    tot=$(awk '{s+=$1} END {print s+0}' "/tmp/sig_$c.txt")
    echo "=== $c : $tot violations total"
    cat "/tmp/sig_$c.txt"
    echo
done
echo "=== signatures present in inline but NOT in call (should be empty) ==="
comm -13 <(awk '{$1=""; print}' /tmp/sig_TestKernel_loop.txt | sort -u) \
         <(awk '{$1=""; print}' /tmp/sig_TestKernel_inline.txt | sort -u)
echo "(end)"
