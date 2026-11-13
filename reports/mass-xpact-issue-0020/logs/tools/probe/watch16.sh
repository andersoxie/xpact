#!/bin/sh
# Watchpoint runs of student-Mass + #16 relinked with a map (probe/nokeep-map), 4 loops x 4, GC stress (#20).
S="/c/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/a1df27f3-4bcf-4e06-b574-128daf781d5b/scratchpad"
for t in a b c d; do
  powershell.exe -NoProfile -File "$(cygpath -w "$S/probe/stress-watch.ps1")" -Dir "$(cygpath -w "$S/probe/nokeep-map")" -Runs 4 -Tag watch-$t > "$S/probe/watch-$t.txt" 2>&1 &
done
wait
cat "$S"/probe/watch-*.txt; ls "$S/probe/wout" | grep -v "^watch-" ; grep -l "^ONE" "$S"/probe/wout/watch-*.txt
