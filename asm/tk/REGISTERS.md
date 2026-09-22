# `TestKernel` register map (compacted)

Actualized register map for the full-pipeline manual kernel
`TestKernel` — hand-source `main_full.asm` → `mk_ur.py` → `main_full_ur.asm` →
`build_full_ur.sh` → `TestKernel_hash_ur.cubin`.

- **Branch:** `f5-ldcu-reg` · **cubin md5:** `c2e09778259ec052ea34fbc26bf1099b`
- **Verified with:** `/usr/local/cuda-13.1/bin/cuobjdump -res-usage` and `-sass`
  (the `/usr/bin` cuobjdump is 12.4 and errors `Cannot decode architecture SM120`;
  never `nvdisasm` — BRXU). SASS register scan on the real cubin.
- **Status:** BUILT + SASS/res-usage-confirmed. **Not yet GPU-proof-validated**
  (`verify.py` + `proof.py(1360)` still owed vs. the `f5` baseline).

## Whole-kernel

| fact | `f5` baseline | compacted (`f5-ldcu-reg`) |
|---|---|---|
| `regcnt` | 128 | **123** |
| spills / `LOCAL` | 0 | 0 |
| `STACK` | 16384 | 16384 (intentional local `subp[]` buffer) |
| max register | R124 (InvMod nested mul) | **R122** (COfs, a persistent scalar) |
| scratch ceiling | R121 (SqrT) | R121 (SqrT) — unchanged |
| InvMod nested-mul ceiling | R124 | **R116** |
| occupancy | 2 blocks/SM | 2 blocks/SM (123 rounds up to the 128 alloc bucket) |

Cutting `regcnt` does **not** help occupancy here (2 blocks/SM holds ≤128; 3 needs
≤85 — infeasible given 3×256-bit persistent point state + 26-wide modmul scratch).
The saving is in-loop headroom, not speed.

## Free registers

- **General-purpose: `R123 R124 R125 R126 R127`** (5 free). All of R0–R122 are live.
- **Uniform: `UR44`–`UR62`** free (walk uses up through `uGyN` at UR36–43).

## Alias → register (256-bit values = 8 regs)

| alias | reg(s) | notes |
|---|---|---|
| BDone | R0 | |
| — | R1 | stack pointer |
| gID | R2 | |
| TmpA | R3 | |
| **TmpB = BpL** | **R4** | was DEAD on `f5`; now holds `BpL` |
| Idx / Half / SAdr | R5 / R6 / R7 | |
| PntX | R8–R15 | persistent point X |
| PntY | R16–R23 | persistent point Y |
| **Inv** (InvMod in, spoiled) | **R24–R32** (9) | |
| ThrID / BlockID | R32 / R33 | prologue temps (overlay inversion) |
| **InvO** (InvMod out) | **R34–R42** (9) | |
| AddrX / AddrY / AddrS | R34–35 / R36–37 / R38–39 | overlay Inv/InvO/Rinv |
| Rinv | R32–R39 | inverse result copy |
| **Scal** (start scalar, epilogue-only) | **R40–R47** | overlays Dxi/AddrC |
| AddrC (= Dxi) | R40–R41 | epilogue dead-write, clobbered by Scal's LDG |
| Thr | R42–R43 | |
| **InvT** (InvMod scratch) | **R44–R116** | Rt0..tvars=Rt64→R108; nested mul → R116 |
| Dxi | R40–R47 | |
| MulB | R48–R55 | |
| MulA | R56–R63 | |
| MulR / Prod | R64–R71 | |
| Lam | R72–R79 | |
| Sqr | R80–R87 | |
| PxN | R88–R95 | |
| Tmp / SqrT / Pt3T | R96 base | Tmp=20→R115, SqrT=26→R121, Pt3T=2→R97 |
| COfs | R122 | |
| *(free)* | R123–R127 | |
| Acc | R128 | INVALID / unused |

**Uniform registers:** uDesc `UR4-5`, uHashSel `UR6`, uCallI `UR8-9`, uInvT `UR10`,
uCallH `UR12-13`, uCallP `UR14-15`, uCOfs `UR16`, uGx `UR20-27`, uGy `UR28-35`,
uGyN `UR36-43` (UR44+ free).

## Per-function (input → internal scratch, physical)

| function | × | inputs | internal scratch |
|---|---|---|---|
| SubMod256 | 8 | RFirst, RSecond → Ro | none (out-of-place) |
| SubMod256_UB | 10 | URFirst(UR), RSecond → Ro | none (operand A in UR) |
| SubMod256_3_UB | 4 | Sqr, uGx(UR), PntX → PxN | Pt3T R96–97 |
| MulMod256 | 15 | RFirst, RSecond → Ro | Tmp R96–115 (20) |
| SqrMod256 | 4 | Lam → Sqr | SqrT R96–121 (26) — kernel scratch ceiling |
| **InvMod256** | 1 | **Inv R24–32** (spoiled) **→ InvO R34–42** | **InvT R44–116**; URt uInvT=UR10 |
| getHash160_33 | 4 | x R54–61, pfx R52 → result R52–56 | MulB region R48–107 (holes) |
| getPublish2 | 4 | R72–75 (ext, BDone, Half, gID) → global | MulB R48–68; URt uDesc |

Only `InvMod256` spoils a formal input; all others are out-of-place. Rt-base binding
places each callee's scratch (MulB=R48 hash/publish, Tmp/SqrT=R96 field, InvT=R44
inversion).

## What the 2026-09-22 compaction changed

Alias-only edits to `main_full.asm` (no raw-register renumber), regenerated via `mk_ur.py`:

| alias | `f5` | compacted |
|---|---|---|
| BpL | R123 | **R4** (into the dead TmpB slot) |
| Scal | R24–31 | **R40–47** (overlay Dxi/AddrC, epilogue-only) |
| Inv | R32–40 | **R24–32** |
| InvO | R42–50 | **R34–42** |
| InvT | R52 (→R124) | **R44 (→R116)** |
| `regcnt` | 128 | **123** |

`getHash160_33` / `getPublish2` bind to **raw** registers (R54/R52/R72), not moved
aliases, so the compaction left them unchanged (confirmed by SASS block scan).
