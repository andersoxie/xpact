#!/usr/bin/env bash
# Rerun of AlotOfTests (11 areas) on andersoxie/xpact incremental-test.
# Usage: bash run-all-incremental.sh A|B|C
#   A = correctness (W3C output, chunked, libxml2, encodings, leaks)
#   B = time-boxed (fuzzing 30 min, differential 20 min)
#   C = timing-sensitive, run alone (security/limits, large files, Expat runtests, CPython)
set -u
D="$(cd "$(dirname "$0")" && pwd)"
N='C:\Users\masou\Desktop\Lia\xpact\w13-incremental\build\native-eiffel'
NORM="$N\\xpact.dll"; ASRT="$N\\xpact_assertions.dll"
STAMP="$D/stamps"; mkdir -p "$STAMP"
step() {  # step <name> <dir> <command...>
  local name=$1 dir=$2; shift 2
  echo "[$(date +%H:%M:%S)] START $name"
  local t0=$(date +%s)
  ( cd "$D/$dir" && "$@" ) > "$STAMP/$name.txt" 2>&1
  local rc=$? t1=$(date +%s)
  echo "[$(date +%H:%M:%S)] END   $name rc=$rc $((t1-t0))s"
  echo "$name rc=$rc seconds=$((t1-t0))" >> "$STAMP/summary.txt"
}
case "${1:-}" in
A)
  step 01-normal     01-w3c-output-comparison python run.py --dll "$NORM" --out logs-it/normal
  step 01-assertions 01-w3c-output-comparison python run.py --dll "$ASRT" --out logs-it/assertions
  step 01-verdicts-normal     01-w3c-output-comparison python verdicts_all.py "$NORM" it
  step 01-verdicts-assertions 01-w3c-output-comparison python verdicts_all.py "$ASRT" it_assertions
  step 07-normal     07-libxml2-corpus python run.py --dll "$NORM" --tag it
  step 08-normal     08-encodings python run.py "$NORM" it
  step 08-assertions 08-encodings python run.py "$ASRT" it_assertions
  step 09-normal     09-memory-checks python leak.py --dll "$NORM" --tag it
  step 02-normal     02-w3c-chunked python run.py --dll "$NORM" --tag it
  step 02-analyze    02-w3c-chunked python analyze.py it
  step 02-assertions 02-w3c-chunked python run.py --dll "$ASRT" --tag it_assertions
  ;;
B)
  step 03-fuzz 03-fuzzing python fuzz.py --seconds 1800 --seed 1 --dll "$NORM" --tag it
  step 04-diff 04-differential-vs-expat python diff.py --seconds 1200 --seed 1 --dll "$NORM" --tag it
  ;;
C)
  step 05-run-normal     05-security-limits python run.py --dll "$NORM" --tag it
  step 05-run-assertions 05-security-limits python run.py --dll "$ASRT" --tag it_assertions
  step 05-scaling        05-security-limits env XPACT_DLL="$NORM" python scaling.py
  step 11-normal         11-large-real-files python run.py --dll "$NORM" --tag it
  step 06-normal     06-expat-runtests-parity powershell -NoProfile -ExecutionPolicy Bypass -File run-native-suite.ps1 -Tag it
  step 06-assertions 06-expat-runtests-parity powershell -NoProfile -ExecutionPolicy Bypass -File run-native-suite.ps1 -Library 'build\native-eiffel\xpact_assertions.lib' -Tag it_assertions
  step 10-build      10-python-xml-tests powershell -NoProfile -ExecutionPolicy Bypass -File build-pyexpat.ps1
  step 10-xpact      10-python-xml-tests sh run-tests.sh xpact
  ;;
*) echo "usage: $0 A|B|C"; exit 2;;
esac
echo "[$(date +%H:%M:%S)] QUEUE $1 DONE"
