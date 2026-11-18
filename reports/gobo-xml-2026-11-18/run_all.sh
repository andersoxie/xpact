#!/usr/bin/env bash
# xpact vs Gobo XML (vs Expat as reference) over the AlotOfTests areas + the W3C runner + speed.
# Usage: bash run_all.sh A|B|C|W|S     (A correctness, B fuzz+differential, C limits+large files, W W3C runner, S speed)
# Engines: XP_ENGINE=xpact (xpact.dll, fresh build) or XP_ENGINE=gobo (gx_engine.exe); Expat = Python's pyexpat.
# XP_CONTENT_ONLY=1: events compared on start/end/chars/pi/comment only (Gobo reports no other kinds).
set -u
D="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$D/../.." && pwd)"
PY="${XPACT_PYTHON:-/c/Users/masou/AppData/Roaming/uv/python/cpython-3.15.0-windows-x86_64-none/python.exe}"
DLL="$(cygpath -w "$R/build/gobo-xml-cmp/es-dll/xpact.dll")"
GX="$R/build/gobo-xml-cmp/engine/gx_engine.exe"
SECS="${SECS:-600}"
export XP_CONTENT_ONLY=1
LOG="$D/console"; mkdir -p "$LOG"
step() {  # step <name> <engine> <dir> <command...>
  local name=$1 eng=$2 dir=$3; shift 3
  local t0=$(date +%s)
  ( cd "$D/$dir" && XP_ENGINE=$eng "$@" ) > "$LOG/$name.txt" 2>&1
  echo "$name rc=$? seconds=$(( $(date +%s) - t0 ))" | tee -a "$LOG/summary.txt"
}
case "${1:-}" in
A)
  step 01-verdicts-xpact xpact 01-w3c-output-comparison "$PY" verdicts_all.py "$DLL" xpact &
  step 01-verdicts-gobo  gobo  01-w3c-output-comparison "$PY" verdicts_all.py "$DLL" gobo &
  step 01-output-xpact   xpact 01-w3c-output-comparison "$PY" run.py --dll "$DLL" --out logs/xpact &
  step 01-output-gobo    gobo  01-w3c-output-comparison "$PY" run.py --dll "$DLL" --out logs/gobo &
  wait
  step 08-enc-xpact xpact 08-encodings "$PY" run.py "$DLL" xpact &
  step 08-enc-gobo  gobo  08-encodings "$PY" run.py "$DLL" gobo &
  step 07-libxml2-xpact xpact 07-libxml2-corpus "$PY" run.py --dll "$DLL" --tag xpact &
  step 07-libxml2-gobo  gobo  07-libxml2-corpus "$PY" run.py --dll "$DLL" --tag gobo &
  wait ;;
B)
  step 03-fuzz-xpact xpact 03-fuzzing "$PY" fuzz.py --seconds "$SECS" --seed 1 --dll "$DLL" --tag xpact &
  step 03-fuzz-gobo  gobo  03-fuzzing "$PY" fuzz.py --seconds "$SECS" --seed 1 --dll "$DLL" --tag gobo &
  step 04-diff-xpact xpact 04-differential-vs-expat "$PY" diff.py --seconds "$SECS" --seed 1 --dll "$DLL" --tag xpact &
  step 04-diff-gobo  gobo  04-differential-vs-expat "$PY" diff.py --seconds "$SECS" --seed 1 --dll "$DLL" --tag gobo &
  wait ;;
C)  # alone: memory/time limits are measured
  step 05-limits-xpact xpact 05-security-limits "$PY" run.py --dll "$DLL" --tag xpact
  step 05-limits-gobo  gobo  05-security-limits "$PY" run.py --dll "$DLL" --tag gobo
  step 11-large-xpact xpact 11-large-real-files "$PY" run.py --dll "$DLL" --tag xpact
  step 11-large-gobo  gobo  11-large-real-files "$PY" run.py --dll "$DLL" --tag gobo ;;
W)  # project W3C runner, all 2,585 cases in lanes; xpact = fresh ES exe + fresh DLL entity checker
  XP="$R/build/gobo-xml-cmp/es-bench/EIFGENs/xpact_benchmarks/F_code/xpact_benchmarks.exe"
  XE="$R/build/gobo-xml-cmp/w3c-xpact/xpact_w3c_case.exe"
  ( cd "$R" && "$PY" scripts/run_w3c_conformance.py --all-cases --jobs 12 --output-dir "build/gobo-xml-cmp/w3c" \
      --engine "xpact=$XP" --entity-engine "xpact=$XE" --engine "gobo=$GX" --entity-engine "gobo=$GX" ) > "$LOG/w3c.txt" 2>&1
  echo "w3c rc=$?" | tee -a "$LOG/summary.txt"
  cp "$R/build/gobo-xml-cmp/w3c/summary.md" "$R/build/gobo-xml-cmp/w3c/results.tsv" "$D/w3c/" 2>/dev/null ;;
S)  # alone, idle PC: see speed.py
  "$PY" "$D/speed.py" > "$LOG/speed.txt" 2>&1; echo "speed rc=$?" | tee -a "$LOG/summary.txt" ;;
*) echo "usage: $0 A|B|C|W|S"; exit 2 ;;
esac
