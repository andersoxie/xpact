"""Test 1: compare xpact's parsed output with the W3C suite's expected OUTPUT files.

For every catalog case with an OUTPUT attribute: parse the input (no namespace
processing, external entities from the suite folder), write canonical XML from
the events, compare byte for byte with the OUTPUT file. Expat (pyexpat) runs the
same way as a control: a case both engines miss points at the harness or the
non-validating profile, a case only xpact misses points at xpact.

Usage: python run.py [--dll path] [--out logs]
"""
import argparse
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "harness"))
from canonical import canonical  # noqa: E402
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--dll")
ap.add_argument("--out", default=str(HERE / "logs"))
args = ap.parse_args()
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)

rows = []
with Pool("xpact", dll=args.dll) as xp, Pool("expat") as ex:
    for case, attrs in w3c.cases():
        if "OUTPUT" not in attrs:
            continue
        expected_path = case.path.parent / attrs["OUTPUT"]
        # OUTPUT is relative to the test's xml:base, like URI
        expected_path = Path(str(case.path)[: -len(attrs["URI"])] + attrs["OUTPUT"]) if str(case.path).endswith(attrs["URI"].replace("/", "\\")) else expected_path
        if not expected_path.is_file():
            rows.append({"id": case.id, "status": "missing-output", "file": str(expected_path)})
            continue
        expected = expected_path.read_bytes().decode("utf-8")
        job = {"file": str(case.path), "entity_root": str(w3c.SUITE), "namespaces": False}
        row = {"id": case.id, "type": case.kind, "lane": case.lane, "entities": attrs.get("ENTITIES", "none")}
        for name, pool in (("xpact", xp), ("expat", ex)):
            r = pool.run(job)
            got = canonical(r["events"]) if r["verdict"] == "ACCEPT" else None
            row[name] = "match" if got == expected else r["verdict"] if got is None else "differs"
            if got is not None and got != expected:
                (out / "diffs").mkdir(exist_ok=True)
                (out / "diffs" / f"{case.id}.{name}.txt").write_text(
                    f"EXPECTED {expected_path}\n{expected!r}\n\nGOT ({name})\n{got!r}\n", encoding="utf-8")
            elif got is None:
                row[name + "_message"] = r.get("message", r.get("exit_hex", ""))
        row["status"] = ("pass" if row["xpact"] == "match" else
                         "both-differ" if row["expat"] != "match" else "xpact-only")
        rows.append(row)

fields = ["id", "type", "lane", "entities", "status", "xpact", "expat", "xpact_message", "expat_message", "file"]
with open(out / "results.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fields, delimiter="\t", extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
summary = {}
for r in rows:
    summary[r["status"]] = summary.get(r["status"], 0) + 1
summary["total"] = len(rows)
(out / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
