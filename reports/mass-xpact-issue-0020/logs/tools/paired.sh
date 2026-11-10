#!/bin/sh
# Stress the previous build and the static builds at the same time, so they share the same machine load.
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
cd /c/xpact/xpact-student-Mass
for d in textrun static static-noinline; do
  powershell.exe -NoProfile -File "$(cygpath -w "$S/stress-path.ps1")" -Dir "C:/xpact/xpact-student-Mass/build/$d/native-eiffel" -Runs 4 > "$S/paired-$d.txt" 2>&1 &
done
wait
cat "$S"/paired-*.txt
