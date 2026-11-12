"""Run the fair speed matrix (andersoxie#275): every cell for xpact.dll and libexpat.dll, alternating.

Per cell and engine: one warm-up run (iterations = 1) that also sets the iteration count so a measured run takes
about 0.25 s; then 5 measured rounds, the engine order alternating (AB, BA, ...); each round is its own process.
A cell whose single parse takes longer than SLOW_S is measured once ("1 run"); a process that takes longer than
TIMEOUT_S is recorded as TIMEOUT. Finished cells are appended to the TSV, so a stopped run resumes.

Usage: python -I benchmarks/fair_speed/run_matrix.py <fair_speed.exe> <inputs dir> <results.tsv>
          --xpact <xpact.dll> --expat <libexpat.dll> [--assertions <xpact_assertions.dll>] [--only <substring>]
"""
import argparse
import csv
import statistics
import subprocess
from pathlib import Path

CHUNKS = [0, 65536, 4096, 256, 16, 1]
ROUNDS, TARGET_S, SLOW_S, TIMEOUT_S = 5, 0.25, 20.0, 900
FIELDS = ["file", "shape", "size", "encoding", "chunk", "callbacks", "engine", "status", "code", "checksum",
          "iterations", "median_ms", "min_ms", "max_ms", "runs", "note"]


def run(exe, dll, file, chunk, cb, ns, iterations):
    try:
        out = subprocess.run([exe, dll, str(file), str(chunk), str(cb), str(ns), str(iterations)],
                             capture_output=True, text=True, timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return None
    parts = out.stdout.split()
    if out.returncode != 0 or len(parts) != 4:
        return ("CRASH", str(out.returncode), "", 0.0)
    return parts[0], parts[1], parts[3], float(parts[2])


def cells(inputs, with_assertions):
    for f in sorted(inputs.glob("*.xml")):
        shape, size, enc = f.stem.split("-")
        ns = 1 if shape == "namespaces" else 0
        for chunk in CHUNKS:
            for cb in (0, 1):
                engines = ["xpact", "expat"]
                if with_assertions and size == "1MB" and enc == "utf8" and shape in ("elements", "text") and cb == 1:
                    engines.append("assertions")
                yield f, shape, size, enc, chunk, cb, ns, engines


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("exe"); ap.add_argument("inputs", type=Path); ap.add_argument("tsv", type=Path)
    ap.add_argument("--xpact", required=True); ap.add_argument("--expat", required=True); ap.add_argument("--assertions")
    ap.add_argument("--only", default="")
    return ap.parse_args()


def finished_cells(tsv):
    """(file, chunk, callbacks, engine) already in the TSV: a stopped run resumes after them."""
    if not tsv.exists():
        return set()
    with tsv.open(encoding="utf-8") as source:
        return {(r["file"], r["chunk"], r["callbacks"], r["engine"]) for r in csv.DictReader(source, delimiter="\t")}


def calibrate(run_cell, todo):
    """Warm-up run per engine: (plan {engine: (iterations, warm-up result)}, rows of engines that failed)."""
    plan, rows = {}, {}
    for e in todo:
        r = run_cell(e, 1)
        if r is None:
            rows[e] = {"status": "TIMEOUT", "note": f"warm-up over {TIMEOUT_S} s"}
        elif r[0] == "CRASH":
            rows[e] = {"status": "CRASH", "code": r[1], "note": "warm-up"}
        else:
            single = r[3] / 1000
            plan[e] = (1 if single > SLOW_S else max(1, round(TARGET_S / max(single, 1e-6))), r)
    return plan, rows


def measure(run_cell, plan):
    """ROUNDS rounds, the engine order alternating; a slow engine's warm-up is its one measurement."""
    times = {e: [] for e in plan}
    for k in range(ROUNDS):
        order = list(plan) if k % 2 == 0 else list(reversed(plan))
        for e in order:
            sample = one_sample(run_cell, e, plan[e], times[e])
            if sample is not None:
                times[e].append(sample)
    return times


def one_sample(run_cell, engine, plan_entry, samples):
    """(result, iterations) of one measured round, or None when nothing is recorded this round."""
    it, first = plan_entry
    if it == 1 and first[3] / 1000 > SLOW_S:  # slow: the warm-up is the measurement, recorded once
        return None if samples else (first, 1)
    r = run_cell(engine, it)
    return (r, it) if r is not None and r[0] != "CRASH" else None


def result_row(plan_entry, samples):
    ms = [t[0][3] for t in samples]
    last = samples[-1][0] if samples else plan_entry[1]
    return {"status": last[0], "code": last[1], "checksum": last[2], "iterations": plan_entry[0],
            "median_ms": f"{statistics.median(ms):.4f}" if ms else "", "min_ms": f"{min(ms):.4f}" if ms else "",
            "max_ms": f"{max(ms):.4f}" if ms else "", "runs": len(ms),
            "note": "1 run (slow)" if len(ms) == 1 else ""}


def main():
    a = parse_args()
    dlls = {"xpact": a.xpact, "expat": a.expat, "assertions": a.assertions}
    done = finished_cells(a.tsv)
    new = not a.tsv.exists()
    out = a.tsv.open("a", newline="", encoding="utf-8")
    w = csv.DictWriter(out, FIELDS, delimiter="\t")
    if new:
        w.writeheader()
    for f, shape, size, enc, chunk, cb, ns, engines in cells(a.inputs, bool(a.assertions)):
        todo = [e for e in engines if (f.name, str(chunk), str(cb), e) not in done]
        if (a.only and a.only not in f.name) or not todo:
            continue

        def run_cell(engine, iterations, f=f, chunk=chunk, cb=cb, ns=ns):
            return run(a.exe, dlls[engine], f, chunk, cb, ns, iterations)

        plan, rows = calibrate(run_cell, todo)
        times = measure(run_cell, plan)
        rows.update({e: result_row(plan[e], times[e]) for e in plan})
        for e in todo:
            w.writerow({"file": f.name, "shape": shape, "size": size, "encoding": enc, "chunk": chunk,
                        "callbacks": cb, "engine": e, **rows[e]})
        out.flush()
        xs = {e: rows[e].get("median_ms", rows[e].get("status")) for e in todo}
        print(f"{f.name} chunk={chunk} cb={cb} {xs}", flush=True)
    out.close()


if __name__ == "__main__":
    main()
