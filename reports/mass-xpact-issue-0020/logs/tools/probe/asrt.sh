#!/bin/sh
# Stressed runs of the static-input ASSERTIONS build, 4 loops in parallel, through the probe runner (#20).
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
for t in a b c d; do
  powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-probe.ps1")" -Dir "C:/xpact/xpact-student-Mass/build/static-asrt/as-xpact" -Runs 3 -Tag asrt-$t > "$S/probe/asrt-$t.txt" 2>&1 &
done
wait
cat "$S"/probe/asrt-*.txt
