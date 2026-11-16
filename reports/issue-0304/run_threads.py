"""#304 trial: does a multi-threaded xpact.dll parse faster on several threads, and stay correct?

    python -I reports/issue-0304/run_threads.py [--total 32000] [--threads 1,2,4,8,16] [--repeat 3]

Builds reports/issue-0274/threads.c (whole documents) and threads2.c (7-byte pieces) against
  normal: build/native-eiffel/xpact.dll      (single-threaded runtime, calls take turns, #274)
  mt:     build/native-eiffel-mt/xpact_mt.dll (multi-threaded runtime, no lock, #304 trial)
and runs each with the same TOTAL number of parses split over N threads (median of --repeat runs).
A run counts only if the program reports 0 wrong results and exits 0. Writes results.tsv/results.md here.
"""
import argparse
import hashlib
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
WORK = REPO / "build" / "issue-0304"
DLLS = {"normal": (REPO / "build/native-eiffel", "xpact"), "mt": (REPO / "build/native-eiffel-mt", "xpact_mt")}
TESTS = ("threads", "threads2")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def build(kind, test):
    folder, name = DLLS[kind]
    out = WORK / kind
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(folder / f"{name}.dll", out / f"{name}.dll")
    exe = out / f"{test}.exe"
    script = (f". '{REPO}\\scripts\\import_msvc_environment.ps1'; Set-Location '{out}'; "
              f"cl /nologo /O2 /W3 /I'{REPO}\\include' '{REPO}\\reports\\issue-0274\\{test}.c' /Fe:{test}.exe "
              f"/link /LIBPATH:'{folder}' {name}.lib | Out-Null; exit $LASTEXITCODE")
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True, capture_output=True)
    return exe


def run(exe, threads, rounds, timeout):
    start = time.perf_counter()
    try:
        p = subprocess.run([str(exe), str(threads), str(rounds)], capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, "TIMEOUT"
    seconds = time.perf_counter() - start
    ok = p.returncode == 0 and "wrong 0" in p.stdout
    return (seconds if ok else None), (p.stdout.strip() or f"exit {p.returncode}")[-120:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--total", type=int, default=32000)
    ap.add_argument("--threads", default="1,2,4,8,16")
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=300)
    args = ap.parse_args()
    counts = [int(x) for x in args.threads.split(",")]

    exes = {(k, t): build(k, t) for k in DLLS for t in TESTS}
    for exe in exes.values():  # warm-up: a fresh exe's first start is slow (virus scan)
        run(exe, 1, 10, args.timeout)
    rows = []
    for test in TESTS:
        for n in counts:
            rounds = max(1, args.total // n)
            times = {k: [] for k in DLLS}
            notes = {}
            for _ in range(args.repeat):
                for kind in DLLS:  # alternate normal / mt so neither always runs on a warmer PC
                    seconds, note = run(exes[(kind, test)], n, rounds, args.timeout)
                    if seconds is None:
                        notes[kind] = note
                    else:
                        times[kind].append(seconds)
            med = {k: (statistics.median(v) if len(v) == args.repeat else None) for k, v in times.items()}
            speed = f"{med['normal'] / med['mt']:.2f}" if med["normal"] and med["mt"] else "-"
            rows.append((test, n, rounds * n, med["normal"], med["mt"], speed, notes.get("normal", ""), notes.get("mt", "")))
            print(f"{test:8} threads {n:>2}: normal {med['normal'] or 'FAIL'} s, mt {med['mt'] or 'FAIL'} s, "
                  f"mt speed-up {speed} {notes or ''}", flush=True)

    fmt = lambda v: f"{v:.2f}" if isinstance(v, float) else "❌ " + "FAIL"
    lines = ["# #304 trial: normal vs multi-threaded xpact.dll", "",
             f"- normal `{DLLS['normal'][0].name}/xpact.dll` SHA-256 `{sha(DLLS['normal'][0] / 'xpact.dll')}…` · "
             f"mt `{DLLS['mt'][0].name}/xpact_mt.dll` `{sha(DLLS['mt'][0] / 'xpact_mt.dll')}…`",
             f"- {args.total} parses in total per cell, split over N threads; median of {args.repeat} alternating runs; "
             "a run counts only with 0 wrong results", "",
             "| Test | Threads | Parses | normal (s) | mt (s) | mt speed-up | notes |", "|---|---:|---:|---:|---:|---:|---|"]
    lines += [f"| {t} | {n} | {p} | {fmt(a)} | {fmt(b)} | {s} | {(na + ' ' + nb).strip()} |" for t, n, p, a, b, s, na, nb in rows]
    (HERE / "results.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (HERE / "results.tsv").write_text("test\tthreads\tparses\tnormal_s\tmt_s\tspeedup\n" +
                                      "".join(f"{t}\t{n}\t{p}\t{a}\t{b}\t{s}\n" for t, n, p, a, b, s, _, _ in rows), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
