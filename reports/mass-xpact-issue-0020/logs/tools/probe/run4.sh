#!/bin/sh
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
rm -f "$S"/probe/out/*
for t in a b c d; do
  powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-probe.ps1")" -Dir "$(cygpath -w "$S/dbg")" -Runs 3 -Tag $t > "$S/probe/run-$t.txt" 2>&1 &
done
wait
cat "$S"/probe/run-*.txt; ls "$S/probe/out"
