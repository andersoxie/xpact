#!/bin/sh
# 24 stressed runs of student-Mass + #4 + #8 + #13 with -keep (perf/resume-text-runs @ 10c8b66, build/chain-keep), 4 loops x 6, probe runner (#20).
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
mkdir -p "$S/probe/out"
for t in a b c d; do
  powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-probe.ps1")" -Dir "C:/xpact/xpact-student-Mass/build/chain-keep/native-eiffel" -Runs 6 -Tag chain-$t > "$S/probe/chain-$t.txt" 2>&1 &
done
wait
cat "$S"/probe/chain-*.txt; ls "$S/probe/out"
