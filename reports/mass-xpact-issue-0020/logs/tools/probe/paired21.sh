#!/bin/sh
# #21: equal-load GC stress, student-Mass @ 8ccf51b vs the static-input branch on top of it; 6 loops x 4 runs each, 12 in parallel.
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
B=C:/xpact/xpact-student-Mass/build
mkdir -p "$S/probe/out"
for d in sm-8ccf51b static-sm; do
  for t in a b c d e f; do
    powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-probe.ps1")" -Dir "$B/$d/native-eiffel" -Runs 4 -Tag q-$d-$t > "$S/probe/q-$d-$t.txt" 2>&1 &
  done
done
wait
cat "$S"/probe/q-*.txt; ls "$S/probe/out"
