#!/bin/bash
# wsl_four_way.sh - Linux half of the four-way comparison (called by run_four_way.ps1 through WSL).
#   wsl_four_way.sh REPO XPACT_META CORE_META CORE_SRC DUAL_W3C_DIR OUT_DIR [DOCS] [REPS]
# Builds the W3C, regression and catalog harnesses with Gobo (gec) and the catalog harness for xpact and
# xpact-core with Linux EiffelStudio, runs W3C + regression for Gobo and Linux expat, and times all four
# parsers on the same catalog workload. Needs /opt/Eiffel_25.12, /opt/gobo, gcc, python3, libexpat1-dev.
set -u
REPO=$1 XMETA=$2 CMETA=$3 CSRC=$4 DUAL=$5 OUT=$6 DOCS=${7:-16000} REPS=${8:-5}
export ISE_EIFFEL=/opt/Eiffel_25.12 ISE_PLATFORM=linux-x86-64
export ISE_LIBRARY=$ISE_EIFFEL GOBO=/opt/gobo GOBO_EIFFEL=ge GOBO_CC=gcc
export PATH=$ISE_EIFFEL/studio/spec/$ISE_PLATFORM/bin:/opt/gobo/bin:$PATH
export XPACT_SOURCE_ROOT=$REPO
B=/root/four-way; mkdir -p $B "$OUT"/w3c "$OUT"/regression "$OUT"/speed-linux-4way
step() { echo "== $*"; }
gobo() { # name ecf target
  mkdir -p $B/$1 && (cd $B/$1 && XPACT_PROBE_METADATA=$XMETA gec --finalize --target=$3 $REPO/benchmarks/four_way/gobo/$2 > build.log 2>&1); echo "gobo $1 exit=$?"; }
step "gec $(gec --version | head -1), $(ec -version 2>&1 | head -1)"
gobo w3c conformance_gobo.ecf conformance_assertions
gobo reg regression_gobo.ecf regression_assertions
gobo cat catalog_gobo.ecf catalog

step "xpact-core copy + Shift-JIS helper, EiffelStudio catalog builds"
rm -rf $B/xpact-core && cp -r "$CSRC" $B/xpact-core
(cd $B/xpact-core/C-tools/shift_jis_subset && mkdir -p lib && gcc -O2 -c -Iinclude src/*.c && ar rcs lib/libshift_jis_subset.a *.o) && echo "helper ok"
export XPACT_CORE=$B/xpact-core XPACT_SHIFT_JIS_OBJECT=$B/xpact-core/C-tools/shift_jis_subset/lib/libshift_jis_subset.a
# the generated C Makefile reads these from the environment (the ECF variables do not reach make)
export XPACT_INCLUDE=$XPACT_CORE/contrib/xpact/include C_SHIFT_JIS_SUBSET=$XPACT_CORE/C-tools/shift_jis_subset
es() { # name ecf metadata
  rm -rf $B/$1 && mkdir -p $B/$1 && (cd $B/$1 && XPACT_PROBE_METADATA=$3 ec -batch -finalize -c_compile -target catalog -config $2 -project_path $B/$1 > build.log 2>&1)
  echo "es $1 exit=$?"; find $B/$1 -path '*F_code*' -type f -perm -u+x ! -name '*.sh' ! -name '*.o' ! -name '*.a' | head -1 > $B/$1/exe.txt; }
es es-xpact $REPO/benchmarks/dual_catalog/xpact/catalog.ecf $XMETA
es es-core $REPO/benchmarks/dual_catalog/xpact_core/catalog.ecf $CMETA

step "libexpat C benchmark"
gcc -O2 -o $B/libexpat_c_benchmark $REPO/benchmarks/libexpat_c_benchmark.c -lexpat && echo "libexpat bench ok"

step "W3C (exact dual case list)"
M=$DUAL/suite-manifest.json R=$DUAL/suite/xmlconf F=$REPO/benchmarks/four_way
python3 $F/run_manifest_engine.py --manifest $M --suite-root $R --name gobo --out "$OUT/w3c/xpact-gobo-linux.tsv" --jobs 8 -- $B/w3c/xpact_w3c_conformance_gobo
python3 $F/run_manifest_engine.py --manifest $M --suite-root $R --name expat_linux --out "$OUT/w3c/expat-linux.tsv" --jobs 8 -- python3 $F/expat_conformance_engine.py

step "Regression"
cd $REPO
python3 $F/run_regression_engine.py --name gobo --lifecycle --out "$OUT/regression/xpact-gobo-linux.tsv" -- $B/reg/xpact_regression_gobo
python3 $F/run_regression_engine.py --name expat_linux --out "$OUT/regression/expat-linux.tsv" -- python3 $F/expat_trace_engine.py

step "Speed: $DOCS documents x $REPS"
python3 - "$OUT/speed-linux-4way/speed-linux-4way.json" $DOCS $REPS <<'PY'
import json, os, statistics, subprocess, sys, time
out, n, reps = sys.argv[1], sys.argv[2], int(sys.argv[3]); B = "/root/four-way"; rows = []
def exe(d):
    p = f"{B}/{d}/exe.txt"
    return open(p).read().strip() if os.path.exists(p) else ""
engines = {"libexpat C (callbacks)": [f"{B}/libexpat_c_benchmark", "--iterations", n, "--mode", "callbacks"],
           "xpact via Gobo": [f"{B}/cat/xpact_catalog_gobo", "--iterations", n],
           "xpact-core via EiffelStudio": [exe("es-core"), "--iterations", n],
           "xpact via EiffelStudio": [exe("es-xpact"), "--iterations", n]}
for name, cmd in engines.items():
    if not cmd[0] or not os.path.exists(cmd[0]): rows.append(dict(engine=name, error="not built")); continue
    times, ok = [], True
    for _ in range(reps):
        t = time.perf_counter(); r = subprocess.run(cmd, capture_output=True); times.append((time.perf_counter() - t) * 1000); ok &= r.returncode == 0
    med = statistics.median(times)
    rows.append(dict(engine=name, docs=int(n), median_ms=round(med, 1), us_per_doc=round(med * 1000 / int(n), 2),
                     mib_s=round(int(n) * 2611 / 1048576 / (med / 1000), 1), all_exit_0=ok, runs_ms=[round(x, 1) for x in times]))
    print(json.dumps(rows[-1]))
json.dump(rows, open(out, "w"), indent=2)
PY
step "done"
