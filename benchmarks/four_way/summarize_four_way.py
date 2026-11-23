"""Merge the dual-W3C comparison (xpact, xpact-core) with the four-way engine runs (Gobo, expat) into one report.

  python summarize_four_way.py DUAL_RUN_DIR W3C_RESULTS_DIR OUT.md
Writes OUT.md (tables) and OUT.tsv (one row per case with every engine's verdict).
"""
import csv, sys
from collections import Counter, defaultdict
from pathlib import Path

dual_dir, res_dir, out_md = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
engines = {}   # name -> {case_id: (status, actual)}
meta = {}
with (dual_dir / "comparison.tsv").open(encoding="utf-8") as f:
    for row in csv.DictReader(f, delimiter="\t"):
        meta[row["case_id"]] = row
        engines.setdefault("xpact (EiffelStudio, Windows)", {})[row["case_id"]] = (row["xpact_status"], row["xpact_actual"])
        engines.setdefault("xpact-core (pinned)", {})[row["case_id"]] = (row["core_status"], row["core_actual"])
labels = {"xpact-gobo-26.11.14-linux": "xpact (Gobo gec, Linux)", "expat-2.8.5-windows": "expat 2.8.5 (Windows)",
          "expat-2.6.1-linux": "expat 2.6.1 (Linux)", "xpact-gobo-linux": "xpact (Gobo gec, Linux)",
          "expat-windows": "expat 2.8.5 (Windows)", "expat-linux": "expat 2.6.1 (Linux)"}
for tsv in sorted(res_dir.glob("*.tsv")):
    name = labels.get(tsv.stem, tsv.stem)
    with tsv.open(encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            st = next(v for k, v in row.items() if k.endswith("_status"))
            ac = next(v for k, v in row.items() if k.endswith("_actual"))
            engines.setdefault(name, {})[row["case_id"]] = (st, ac)

order = ["xpact (EiffelStudio, Windows)", "xpact (Gobo gec, Linux)", "expat 2.8.5 (Windows)", "expat 2.6.1 (Linux)", "xpact-core (pinned)"]
order = [e for e in order if e in engines] + [e for e in engines if e not in order]
cases = list(meta)
L = ["# Four-way W3C XML conformance", "",
     f"Suite: W3C xmlts 20130923, {len(cases)} cases, profile and exclusions of dual-W3C run `{dual_dir.name}` (same case list, same expected verdicts for every engine).", "",
     "| Parser | Passed | Failed | Errors | Excluded | Pass rate | Accepts not-wf (too lenient) | Rejects valid/invalid (too strict) |",
     "|---|---:|---:|---:|---:|---:|---:|---:|"]
for e in order:
    c = Counter(s for s, _ in engines[e].values())
    lenient = sum(1 for cid, (s, a) in engines[e].items() if s == "failed" and meta[cid]["expected"] == "REJECT")
    strict = sum(1 for cid, (s, a) in engines[e].items() if s == "failed" and meta[cid]["expected"] == "ACCEPT")
    run = c["passed"] + c["failed"] + c["error"]
    excluded = sum(1 for cid in cases if meta[cid]["skip_reason"])   # same profile exclusions for every engine
    L.append(f"| {e} | {c['passed']} | {c['failed']} | {c['error']} | {excluded} | {100 * c['passed'] / run:.1f}% | {lenient} | {strict} |")

L += ["", "## Failures by test collection", "", "| Collection | Cases run | " + " | ".join(order) + " |", "|---|---:|" + "---:|" * len(order)]
coll = defaultdict(list)
for cid in cases:
    if meta[cid]["skip_reason"]: continue
    key = cid.split("-")[0] if cid[0].isalpha() else cid
    for p in ("not-wf", "valid", "invalid", "error"):
        if cid.startswith(p): key = cid.split("-")[0] + "-" + cid.split("-")[1] if p == "not" else p
    coll[meta[cid]["kind"]].append(cid)
for kind, ids in sorted(coll.items()):
    L.append(f"| {kind} | {len(ids)} | " + " | ".join(str(sum(engines[e][i][0] != 'passed' for i in ids)) for e in order) + " |")

L += ["", "## Agreement between parsers (cases run by all)", "", "| | " + " | ".join(order) + " |", "|---|" + "---:|" * len(order)]
run_ids = [c for c in cases if not meta[c]["skip_reason"]]
for a in order:
    L.append(f"| {a} | " + " | ".join(f"{100 * sum(engines[a][i][1] == engines[b][i][1] for i in run_ids) / len(run_ids):.1f}%" for b in order) + " |")

only = Counter()
for i in run_ids:
    failing = tuple(e for e in order if engines[e][i][0] != "passed")
    if failing: only[failing] += 1
L += ["", "## Who fails which cases (top patterns)", "", "| Failing parsers | Cases |", "|---|---:|"]
for pat, n in only.most_common(8):
    L.append(f"| {', '.join(pat)} | {n} |")
out_md.write_text("\n".join(L) + "\n", encoding="utf-8")

with out_md.with_suffix(".tsv").open("w", encoding="utf-8", newline="\n") as f:
    f.write("case_id\tkind\texpected\tskip_reason\t" + "\t".join(order) + "\n")
    for cid in cases:
        m = meta[cid]
        f.write(f"{cid}\t{m['kind']}\t{m['expected']}\t{m['skip_reason']}\t" + "\t".join(f"{engines[e][cid][0]}:{engines[e][cid][1]}" for e in order) + "\n")
print(out_md)
