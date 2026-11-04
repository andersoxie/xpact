#!/bin/sh
# #20: merged student-Mass (8ccf51b) production DLL, DEFAULT GC settings, 12 loops x 6 runs in parallel (heavy load).
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
mkdir -p "$S/probe/out"
for t in a b c d e f g h i j k l; do
  powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-nogc.ps1")" -Dir "C:/xpact/xpact-student-Mass/build/sm-8ccf51b/native-eiffel" -Runs 6 -Tag nogc-$t > "$S/probe/nogc-$t.txt" 2>&1 &
done
wait
cat "$S"/probe/nogc-*.txt; ls "$S/probe/out"
