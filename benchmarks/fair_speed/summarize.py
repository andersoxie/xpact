"""Summarize the fair speed results (andersoxie#275): results.tsv -> summary.md with xpact / Expat ratios.

Usage: python -I benchmarks/fair_speed/summarize.py <results.tsv> <summary.md>
"""
import csv
import statistics
import sys
from collections import defaultdict

CHUNK_NAMES = {"0": "whole", "65536": "64 KB", "4096": "4 KB", "256": "256 B", "16": "16 B", "1": "1 B"}
CHUNKS = list(CHUNK_NAMES)


def read_cells(path):
    """{(file, chunk, callbacks): {engine: row}}"""
    cell = defaultdict(dict)
    with open(path, encoding="utf-8") as source:
        for r in csv.DictReader(source, delimiter="\t"):
            cell[(r["file"], r["chunk"], r["callbacks"])][r["engine"]] = r
    return cell


def compare(cell):
    """(ratios xpact/Expat, cells whose checksums differ, cells not compared)."""
    ratios, mismatch, problems = {}, [], []
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
    return ratios, mismatch, problems


def ratio_cell(cell, ratios, key):
    """The ratio, else xpact's status, else empty."""
    if key in ratios:
        return f"{ratios[key]:.2f}"
    if key in cell and "xpact" in cell[key]:
        return cell[key]["xpact"]["status"]
    return ""


def ratio_tables(cell, ratios, files):
    lines = []
    for cb in ("0", "1"):
        lines += [f"\n## Callbacks {'on' if cb == '1' else 'off'}\n",
                  "| Input | " + " | ".join(CHUNK_NAMES[c] for c in CHUNKS) + " |",
                  "|---|" + "---:|" * len(CHUNKS)]
        lines += [f"| `{f[:-4]}` | " + " | ".join(ratio_cell(cell, ratios, (f, c, cb)) for c in CHUNKS) + " |"
                  for f in files]
    return lines


def absolute_table(cell, files):
    def value(f, chunk, engine):
        row = cell.get((f, chunk, "1"), {}).get(engine, {})
        return row.get("median_ms") or row.get("status", "")

    lines = ["\n## Absolute times (ms per parse), callbacks on, whole and 1 byte\n",
             "| Input | xpact whole | Expat whole | xpact 1 B | Expat 1 B |", "|---|---:|---:|---:|---:|"]
    return lines + [f"| `{f[:-4]}` | {value(f, '0', 'xpact')} | {value(f, '0', 'expat')} | "
                    f"{value(f, '1', 'xpact')} | {value(f, '1', 'expat')} |" for f in files]


def assertions_table(cell):
    a = [(k, e["assertions"], e.get("xpact")) for k, e in cell.items() if "assertions" in e]
    if not a:
        return []
    lines = ["\n## Assertions build (subset), ms per parse\n",
             "| Input | Piece | assertions | production | ratio |", "|---|---|---:|---:|---:|"]
    return lines + [f"| `{k[0][:-4]}` | {CHUNK_NAMES[k[1]]} | {s['median_ms']} | {p['median_ms']} | "
                    f"{float(s['median_ms']) / float(p['median_ms']):.1f} |"
                    for k, s, p in sorted(a) if s.get("median_ms") and p and p.get("median_ms")]


def main():
    cell = read_cells(sys.argv[1])
    ratios, mismatch, problems = compare(cell)
    files = sorted({k[0] for k in cell})
    lines = ["# Fair speed test: xpact vs native Expat 2.8.1\n",
             "Median time per parse, xpact / Expat (1.0 = as fast; 2.0 = xpact twice as slow). "
             "Same harness, same `expat.h` API, both DLLs loaded with `LoadLibrary`.\n"]
    allr = list(ratios.values())
    if allr:
        lines.append(f"**Cells measured:** {len(allr)} · **median ratio** {statistics.median(allr):.2f} · "
                     f"best {min(allr):.2f} · worst {max(allr):.2f} · checksum mismatches {len(mismatch)} · "
                     f"not compared (timeout/crash/reject) {len(problems)}\n")
    lines += ratio_tables(cell, ratios, files) + absolute_table(cell, files) + assertions_table(cell)
    if mismatch or problems:
        lines.append("\n## Not compared or different\n")
        lines += [f"- checksum differs: `{k}`" for k in mismatch]
        lines += [f"- `{k}`: xpact {xs} {note}, Expat {es}" for k, xs, note, es in problems]
    with open(sys.argv[2], "w", encoding="utf-8") as target:
        target.write("\n".join(lines) + "\n")
    print("\n".join(lines[:4]))


if __name__ == "__main__":
    main()
