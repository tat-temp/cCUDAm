#!/usr/bin/env python3
"""Teach cuAssembler's sm_120 repository the encodings it is missing, using the
shipped kernel's own SASS as the corpus.

"Assembling failed (NewVals): Insufficient basis, try CuAsming more
instructions!" is not a missing encoder -- it means the solver has not seen
enough independent samples of that operand form to solve for its encoding.
The samples it needs are sitting in our own cubin, with their real binary
codes next to them.
"""
import sys, os, re, time, collections
import env

from CuAsm.CuAsmLogger import CuAsmLogger
from CuAsm.CuInsAssemblerRepos import CuInsAssemblerRepos
from CuAsm.CuInsFeeder import CuInsFeeder
env.configure()
CuAsmLogger.initLogger(os.path.join(env.WORK, "learn.log"), file_level=25, stdout_level=25)

SASS = env.SASS
OUT = env.REPOS_OUT

repos = CuInsAssemblerRepos.getDefaultRepos("sm_120")
print("loaded default sm_120 repos: %d InsKeys" % len(repos))

# Everything is fed, including control transfers.
#
# Measured caveat, recorded because it looks like an encoder bug and is not:
# nvdisasm prints a branch/return target as an ABSOLUTE address while the
# encoding holds a PC-RELATIVE offset. Two RETs at different addresses therefore
# look identical to the solver and disagree on the code -- the "Error when
# verifying for RET_R_II / BRA_II" lines below. The solver keeps the first and
# reuses it, so the second one assembles to the first one's offset.
#
# Filtering them out is NOT the fix: BRA.DIV UR4 and BSSY.RECONVERGENT only get
# their modifiers/operand forms from this corpus, so excluding them just moves
# the failure. The real fix belongs in CuAsmParser's `(label) fixup path, which
# should overwrite the offset field after layout regardless of what the repos
# encoded. Out of scope here; the affected instructions are enumerated by the
# round-trip in rtfull.py.
t0 = time.time()
feeder = CuInsFeeder(SASS)
ncnt = repos.update(feeder)
t1 = time.time()
print("fed %s" % SASS)
print("new records learned: %d      (%.1f s)" % (ncnt, t1 - t0))
print("repos now: %d InsKeys" % len(repos))

repos.save2file(OUT)
print("saved -> %s  (%d bytes)" % (OUT, os.path.getsize(OUT)))
