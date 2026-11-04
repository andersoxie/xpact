#!/bin/sh
# Paired GC-stress batch (#20): four builds at the same time, 3 loops x 4 runs each = 12 runs in parallel, so all share one load.
#   baseline = student-Mass @ 253c81e with -keep; nokeep = + #16; fix20 = student-Mass + fix/20-seen-name-tables without -keep;
#   chain = perf/resume-text-runs (#4 + #8 + #13) with -keep.
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
B=C:/xpact/xpact-student-Mass/build
mkdir -p "$S/probe/out"
for d in baseline nokeep fix20-nokeep chain-keep; do
  for t in a b c; do
    powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-probe.ps1")" -Dir "$B/$d/native-eiffel" -Runs 4 -Tag p-$d-$t > "$S/probe/p-$d-$t.txt" 2>&1 &
  done
done
wait
cat "$S"/probe/p-*.txt; ls "$S/probe/out"
