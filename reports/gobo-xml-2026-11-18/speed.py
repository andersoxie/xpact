"""Speed: xpact (EiffelStudio exe, in-process Eiffel) vs Gobo XML (gx_engine.exe) vs Expat (pyexpat, no handlers).

Both Eiffel programs are timed the same way: wall time of a process doing N parses minus a process doing 1,
divided by N-1 (removes start-up and file read). Runs alternate xpact/Gobo; median of 3. Run on an idle PC.
Output: speed.json + a Markdown table on stdout.
"""
import json
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
XP = REPO / "build/gobo-xml-cmp/es-bench/EIFGENs/xpact_benchmarks/F_code/xpact_benchmarks.exe"
GX = REPO / "build/gobo-xml-cmp/engine/gx_engine.exe"
INPUTS = REPO / "build/perf-inputs"
SIZES = {"10KB": 2000, "1MB": 20, "10MB": 3}


def wall(cmd):
    t = time.perf_counter()
    done = subprocess.run(cmd, capture_output=True)
    return time.perf_counter() - t, done


def per_doc(make_cmd, n):
    base, _ = wall(make_cmd(1))
    full, done = wall(make_cmd(n))
    return (full - base) / (n - 1), done


def expat_per_doc(data, n):
    import pyexpat
    t = time.perf_counter()
    for _ in range(n):
        pyexpat.ParserCreate().Parse(data, True)
    return (time.perf_counter() - t) / n


rows = []
for f in sorted(INPUTS.glob("*.xml")):
    size = next((s for s in SIZES if f"-{s}-" in f.name), None)
    if size is None:
        continue
    n = SIZES[size]
    xs, gs, gok = [], [], ""
    for _ in range(3):
        x, xd = per_doc(lambda k: [str(XP), "--file", str(f), "--iterations", str(k)], n)
        g, gd = per_doc(lambda k: [str(GX), "--bench", str(f), str(k)], n)
        xs.append(x)
        gs.append(g)
        out = gd.stdout.decode(errors="replace").split("\t")
        gok = "ok" if len(out) == 4 and out[3].strip() == str(n + 1) else f"REJECT ({gd.stdout[:60]!r})"
    data = f.read_bytes()
    try:
        e = statistics.median(expat_per_doc(data, n) for _ in range(3))
    except Exception as exc:  # noqa: BLE001
        e = float("nan")
    x, g = statistics.median(xs), statistics.median(gs)
    mb = len(data) / 2**20
    rows.append({"file": f.name, "bytes": len(data), "n": n, "xpact_ms": round(x * 1000, 3), "gobo_ms": round(g * 1000, 3),
                 "expat_ms": round(e * 1000, 3), "xpact_MBps": round(mb / x, 1) if x > 0 else None,
                 "gobo_MBps": round(mb / g, 1) if g > 0 else None, "gobo_over_xpact": round(g / x, 2) if x > 0 else None,
                 "gobo_verdict": gok})
    print(rows[-1], file=sys.stderr, flush=True)
(HERE / "speed.json").write_text(json.dumps(rows, indent=1))
print("| File | xpact ms | Gobo ms | Expat ms | Gobo / xpact | Gobo verdict |")
print("|---|---:|---:|---:|---:|---|")
for r in rows:
    print(f"| {r['file']} | {r['xpact_ms']} | {r['gobo_ms']} | {r['expat_ms']} | {r['gobo_over_xpact']}x | {r['gobo_verdict']} |")
