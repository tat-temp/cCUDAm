#!/bin/bash
set -u
N=/usr/local/cuda/bin
S=/mnt/c/Users/User/AppData/Local/Temp/claude/C--tmp-ai-cCUDAm/c101080c-5f2c-40a1-9cd6-f6c2bcacab3c/scratchpad
cd /tmp && cp "$S/kara.cu" .
$N/nvcc -O3 --ptxas-options=-O3 -arch=sm_120 -cubin -o kara.cubin kara.cu 2>&1 | head -5
echo
printf '  %-10s %6s %11s %7s %7s %5s %7s\n' KERNEL TOTAL IMAD.WIDE IADD3 LOGIC MEM 'COST*'
for pair in "schoolbook:_Z7kSchoolPKjS0_Pj" "karatsuba:_Z6kKaratPKjS0_Pj"; do
    nm=${pair%%:*}; k=${pair##*:}
    $N/cuobjdump -sass -fun "$k" kara.cubin > "$nm.sass" 2>/dev/null
    tot=$(grep -cP '^\s+/\*[0-9a-f]+\*/' "$nm.sass")
    wide=$(grep -cE 'IMAD\.WIDE' "$nm.sass")
    iadd=$(grep -cE '\bIADD3?\b' "$nm.sass")
    logic=$(grep -cE '\bLOP3|\bSEL|\bISETP|\bSHF|\bPRMT' "$nm.sass")
    mem=$(grep -cE '\bLDG|\bSTG|\bLDL|\bSTL' "$nm.sass")
    cost=$(( wide * 4 + (tot - wide) ))
    printf '  %-10s %6s %11s %7s %7s %5s %7s\n' "$nm" "$tot" "$wide" "$iadd" "$logic" "$mem" "$cost"
done
echo
echo "  * COST = 4 x IMAD.WIDE + 1 x everything else -- the model that reproduced the measured"
echo "    hand-written/compiled ratio to 0.8% (predicted 0.790 against measured 0.784)."
