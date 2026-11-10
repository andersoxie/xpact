#!/bin/sh
# 16 stressed runs of the previous build (textrun DLL), 4 loops in parallel, through the probe runner (#20).
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
mkdir -p "$S/probe/prev-out"
for t in a b c d; do
  XPACT_CRASH_DIR_OVERRIDE=1 powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-probe.ps1")" -Dir "C:/xpact/xpact-student-Mass/build/textrun/native-eiffel" -Runs 4 -Tag prev-$t > "$S/probe/prev-$t.txt" 2>&1 &
done
wait
cat "$S"/probe/prev-*.txt; ls "$S/probe/out"
