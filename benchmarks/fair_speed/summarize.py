"""Summarize the fair speed results (andersoxie#275): results.tsv -> summary.md with xpact / Expat ratios.

Usage: python -I benchmarks/fair_speed/summarize.py <results.tsv> <summary.md>
"""
import csv
import statistics
import sys
from collections import defaultdict

CHUNK_NAMES = {"0": "whole", "65536": "64 KB", "4096": "4 KB", "256": "256 B", "16": "16 B", "1": "1 B"}
CHUNKS = list(CHUNK_NAMES)


def main():
    rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8"), delimiter="\t"))
    cell = defaultdict(dict)
    for r in rows:
        cell[(r["file"], r["chunk"], r["callbacks"])][r["engine"]] = r
    lines, ratios, mismatch, problems = [], defaultdict(list), [], []
    for key, e in cell.items():
        x, ex = e.get("xpact"), e.get("expat")
        if not x or not ex:
            continue
        if x["status"] != "1" or ex["status"] != "1":
            problems.append((key, x["status"], x.get("note", ""), ex["status"]))
            continue
        if key[2] == "1" and x["checksum"] != ex["checksum"]:
            mismatch.append(key)
        if x["median_ms"] and ex["median_ms"]:
            ratios[key] = float(x["median_ms"]) / float(ex["median_ms"])
    files = sorted({k[0] for k in cell})
    lines.append("# Fair speed test: xpact vs native Expat 2.8.1\n")
    lines.append("Median time per parse, xpact / Expat (1.0 = as fast; 2.0 = xpact twice as slow). "
                 "Same harness, same `expat.h` API, both DLLs loaded with `LoadLibrary`.\n")
    allr = list(ratios.values())
    if allr:
        lines.append(f"**Cells measured:** {len(allr)} · **median ratio** {statistics.median(allr):.2f} · "
                     f"best {min(allr):.2f} · worst {max(allr):.2f} · checksum mismatches {len(mismatch)} · "
                     f"not compared (timeout/crash/reject) {len(problems)}\n")
    for cb in ("0", "1"):
        lines.append(f"\n## Callbacks {'on' if cb == '1' else 'off'}\n")
        lines.append("| Input | " + " | ".join(CHUNK_NAMES[c] for c in CHUNKS) + " |")
        lines.append("|---|" + "---:|" * len(CHUNKS))
        for f in files:
            vals = []
            for c in CHUNKS:
                k = (f, c, cb)
                if k in ratios:
                    vals.append(f"{ratios[k]:.2f}")
                elif k in cell and "xpact" in cell[k]:
                    vals.append(cell[k]["xpact"]["status"])
                else:
                    vals.append("")
            lines.append(f"| `{f[:-4]}` | " + " | ".join(vals) + " |")
    lines.append("\n## Absolute times (ms per parse), callbacks on, whole and 1 byte\n")
    lines.append("| Input | xpact whole | Expat whole | xpact 1 B | Expat 1 B |")
    lines.append("|---|---:|---:|---:|---:|")
    for f in files:
        g = lambda c, e: cell.get((f, c, "1"), {}).get(e, {}).get("median_ms") or cell.get((f, c, "1"), {}).get(e, {}).get("status", "")
        lines.append(f"| `{f[:-4]}` | {g('0', 'xpact')} | {g('0', 'expat')} | {g('1', 'xpact')} | {g('1', 'expat')} |")
    a = [(k, e["assertions"], e.get("xpact")) for k, e in cell.items() if "assertions" in e]
    if a:
        lines.append("\n## Assertions build (subset), ms per parse\n")
        lines.append("| Input | Piece | assertions | production | ratio |")
        lines.append("|---|---|---:|---:|---:|")
        for k, s, p in sorted(a):
            if s.get("median_ms") and p and p.get("median_ms"):
                lines.append(f"| `{k[0][:-4]}` | {CHUNK_NAMES[k[1]]} | {s['median_ms']} | {p['median_ms']} | "
                             f"{float(s['median_ms']) / float(p['median_ms']):.1f} |")
    if mismatch or problems:
        lines.append("\n## Not compared or different\n")
        for k in mismatch:
            lines.append(f"- checksum differs: `{k}`")
        for k, xs, note, es in problems:
            lines.append(f"- `{k}`: xpact {xs} {note}, Expat {es}")
    open(sys.argv[2], "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines[:4]))


if __name__ == "__main__":
    main()
