"""Test 2: every W3C document whole vs byte by byte vs split at every byte, through xpact.dll and Expat.

A case is "unstable" for an engine when any chunked parse gives a different
verdict, error code or event list than the whole-document parse.
Usage: python run.py [--dll path] [--tag name] [--max-split-size 4096]
"""
import argparse
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "issue-0154" / "tools" / "harness"))
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
ap.add_argument("--max-split-size", type=int, default=4096)
args = ap.parse_args()
out = HERE / "logs"
out.mkdir(exist_ok=True)

rows, summary = [], {}
with Pool("xpact", timeout=300, dll=args.dll) as xp, Pool("expat", timeout=300) as ex:
    for case, attrs in w3c.cases():
        if not case.path.is_file():
            continue
        job = {"file": str(case.path), "entity_root": str(w3c.SUITE), "namespaces": case.namespaces,
               "compare_splits": args.max_split_size}
        row = {"id": case.id, "lane": case.lane, "size": case.path.stat().st_size}
        for name, pool in (("xpact", xp), ("expat", ex)):
            r = pool.run(job)
            if r["verdict"] in ("CRASH", "TIMEOUT"):
                row[name] = r["verdict"]
            else:
                stable = r["byte_same"] and not r["bad_splits"]
                row[name] = "stable" if stable else "UNSTABLE"
                row[name + "_byte"] = "same" if r["byte_same"] else f"differs ({r['byte_verdict']})"
                row[name + "_bad_splits"] = " ".join(map(str, r["bad_splits"][:20])) + (
                    f" ... ({len(r['bad_splits'])})" if len(r["bad_splits"]) > 20 else "")
        row["status"] = ("ok" if row["xpact"] == "stable" else
                         "both" if row["expat"] != "stable" else "xpact-only")
        summary[row["status"]] = summary.get(row["status"], 0) + 1
        rows.append(row)
        if row["status"] != "ok":
            print(row, flush=True)

fields = ["id", "lane", "size", "status", "xpact", "xpact_byte", "xpact_bad_splits", "expat", "expat_byte", "expat_bad_splits"]
with open(out / f"chunked-{args.tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fields, delimiter="\t", extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
summary["total"] = len(rows)
(out / f"chunked-{args.tag}-summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
