"""#172: did the fix move the C# DLL test results towards Expat 2.8.1 or away from it?

    python -I reports/issue-0172/tools/csharp_vs_expat.py <expat dir> <before dir> <after dir> [out.tsv]

Each dir is an `XpactDllTests --out` folder with `results.tsv`. Per field, counts
the cases where xpact equals Expat before and after the fix, and lists every case
that went from equal to different (a regression).
"""
import csv
import sys
from collections import Counter

FIELDS = ["verdict", "error_code", "line", "column", "byte_index", "failed_call", "calls", "events"]


def load(d):
    with open(f"{d}/results.tsv", encoding="utf-8") as f:
        return {r["id"]: r for r in csv.DictReader(f, delimiter="\t")}


def main():
    ex, before, after = (load(d) for d in sys.argv[1:4])
    out = sys.argv[4] if len(sys.argv) > 4 else None
    same_before, same_after, better, worse = Counter(), Counter(), Counter(), Counter()
    regressions = []
    changed = set()
    for cid, e in ex.items():
        b, a = before[cid], after[cid]
        for f in FIELDS:
            sb, sa = b[f] == e[f], a[f] == e[f]
            same_before[f] += sb
            same_after[f] += sa
            if b[f] != a[f]:
                changed.add(cid)
            if sa and not sb:
                better[f] += 1
            elif sb and not sa:
                worse[f] += 1
                regressions.append((cid, f, e[f], b[f], a[f]))
    all_before = sum(all(before[c][f] == ex[c][f] for f in FIELDS) for c in ex)
    all_after = sum(all(after[c][f] == ex[c][f] for f in FIELDS) for c in ex)
    print(f"cases: {len(ex)}; changed by the fix: {len(changed)}")
    print(f"{'field':12} {'= Expat before':>15} {'= Expat after':>14} {'better':>7} {'worse':>6}")
    for f in FIELDS:
        print(f"{f:12} {same_before[f]:15} {same_after[f]:14} {better[f]:7} {worse[f]:6}")
    print(f"{'all fields':12} {all_before:15} {all_after:14}")
    print(f"regressions (equal to Expat before, different after): {len(regressions)}")
    groups = Counter((cid.split('/')[0], f) for cid, f, *_ in regressions)
    for (g, f), n in groups.most_common(20):
        print(f"   {g} / {f}: {n}")
    if out:
        with open(out, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh, delimiter="\t")
            w.writerow(["id", "field", "expat", "before", "after"])
            w.writerows(regressions)


if __name__ == "__main__":
    main()
