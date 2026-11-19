"""Compare two fair-speed result files (old vs new xpact, each against Expat, run the same way).

    python -I reports/perf-allocations/compare_speed.py build/speed/results-old.tsv build/speed/results-new.tsv

Prints: overall median xpact/Expat ratio for both, median new-vs-old speed-up overall and per shape and per piece size,
checksum mismatches and cells that were not measured (timeout, crash, reject).
"""
import csv
import statistics
import sys
from collections import defaultdict

CHUNK = {"0": "whole", "65536": "64 KB", "4096": "4 KB", "256": "256 B", "16": "16 B", "1": "1 B"}


def load(path):
    cells = defaultdict(dict)
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            cells[(r["file"], r["chunk"], r["callbacks"])][r["engine"]] = r
    return cells


def ratio(cell):
    x, e = cell.get("xpact"), cell.get("expat")
    if x and e and x["status"] == "1" and e["status"] == "1" and x["median_ms"] and e["median_ms"]:
        return float(x["median_ms"]) / float(e["median_ms"])
    return None


def mismatches(cells):
    return [k for k, c in cells.items() if k[2] == "1" and ratio(c) and c["xpact"]["checksum"] != c["expat"]["checksum"]]


def main(old_path, new_path):
    old, new = load(old_path), load(new_path)
    r_old = {k: ratio(c) for k, c in old.items()}
    r_new = {k: ratio(c) for k, c in new.items()}
    both = [k for k in r_old if r_old[k] and r_new.get(k)]
    speed = {k: r_old[k] / r_new[k] for k in both}  # >1 = new is faster (relative to Expat in the same cell)
    med = statistics.median
    print(f"cells measured in both: {len(both)} of {len(old)}")
    print(f"median xpact/Expat ratio: old {med(r_old[k] for k in both):.2f}x slower, new {med(r_new[k] for k in both):.2f}x slower")
    print(f"median new-vs-old speed-up: {med(speed.values()):.2f}x (best {max(speed.values()):.2f}x, worst {min(speed.values()):.2f}x)")
    print(f"checksum mismatches: old {len(mismatches(old))}, new {len(mismatches(new))}")
    for label, data in (("old", old), ("new", new)):
        bad = [(k, c["xpact"]["status"]) for k, c in data.items() if "xpact" in c and c["xpact"]["status"] != "1"]
        print(f"not measured ({label}): {len(bad)} " + ", ".join(sorted({f'{k[0][:-4]} {CHUNK[k[1]]} {s}' for k, s in bad}))[:300])
    groups = defaultdict(list)
    for k, s in speed.items():
        groups["shape " + k[0].split("-")[0]].append(s)
        groups["piece " + CHUNK[k[1]]].append(s)
    print("\nmedian new-vs-old speed-up by group:")
    for g in sorted(groups):
        print(f"  {g:22} {med(groups[g]):.2f}x  ({len(groups[g])} cells)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
